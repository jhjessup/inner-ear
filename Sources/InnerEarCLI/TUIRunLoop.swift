import Foundation
import InnerEarCore
import InnerEarTUIKit

/// The TUI run loop: bridges the pure `TUIController.reduce` state machine
/// with the real async service implementations and terminal I/O.
///
/// This loop owns the live `TUIState`, applies key events to it via
/// `TUIController.reduce`, and then executes any returned effects
/// (`TUIEffect` values), updating state based on their async results.
enum TUIRunLoop {
    static func run(
        audioCapture: AVFoundationAudioCaptureService,
        transcription: WhisperKitTranscriptionService,
        diarization: ChannelBasedDiarizationService,
        summarization: ExtractiveSummarizationService,
        export: FileExportService,
        store: RecordingStore
    ) async throws {
        let rawMode = try RawTerminalMode()
        defer { rawMode.restore() }

        installSignalHandlers {
            rawMode.restore()
        }

        // `store` is mutable because `.saveDataDirectory` may need to
        // rebuild it (a fresh `RecordingStore` reads the (possibly new)
        // config.json from disk on init).
        var store = store

        var state = TUIState()

        // Renders `state` immediately, using a freshly-queried terminal size.
        // Effects like `.runPipeline` set `state` multiple times in sequence
        // (Transcribing... -> Diarizing... -> Summarizing...) around blocking
        // awaits; without calling this after each intermediate assignment,
        // those status lines are invisible — the loop's single end-of-iteration
        // render would only ever show the LAST state once every await in the
        // effect has already finished, defeating the point of a status line.
        func renderNow() {
            let size = terminalSize()
            let lines = TUIRenderer.render(state: state, width: size.width, height: size.height)
            writeToTerminal(lines)
        }

        while true {
            // 1. Read key (non-blocking)
            if let key = readKeyNonBlocking() {
                let (nextState, effects) = TUIController.reduce(state, .key(key))
                state = nextState

                if effects.contains(.quit) {
                    rawMode.restore()
                    return
                }

                // Show the immediate result of the keypress (e.g. entering
                // .prompting, or the "Starting..." processing screen)
                // before executing any effect, which may block for a while.
                renderNow()

                // Execute effects
                for effect in effects {
                    do {
                        switch effect {
                        case .startRecording(let captureSystemAudio):
                            try await audioCapture.startCapture(captureSystemAudio: captureSystemAudio)

                        case .stopRecording:
                            let recording = try await audioCapture.stopCapture()
                            try store.save(recording)
                            state.record = .saved(recording)
                            renderNow()

                        case .loadRecordings:
                            let recordings = try store.listRecordings()
                            state.recordings = .list(recordings: recordings, selectedIndex: 0)
                            renderNow()

                        case .runPipeline(let recording):
                            // Transcribe
                            state.recordings = .processing(recording: recording, statusLine: "Transcribing...")
                            renderNow()
                            let transcript = try await transcription.transcribe(
                                recording: recording,
                                model: .whisperLargeV3Turbo,
                                languageCode: nil
                            )

                            // Diarize
                            state.recordings = .processing(recording: recording, statusLine: "Diarizing...")
                            renderNow()
                            let diarizedTranscript = try await diarization.diarize(
                                transcript: transcript,
                                recording: recording
                            )

                            // Summarize
                            state.recordings = .processing(recording: recording, statusLine: "Summarizing...")
                            renderNow()
                            let summary = try await summarization.summarize(transcript: diarizedTranscript)

                            // Persist results
                            try store.save(diarizedTranscript)
                            try store.save(summary)

                            // Transition to results view
                            state.recordings = .viewingResults(
                                transcript: diarizedTranscript,
                                summary: summary,
                                scrollOffset: 0
                            )
                            renderNow()

                        case .exportResult(let transcript, let summary, let format):
                            // Build destination URL in CWD with .md extension for markdown
                            let ext = "md"
                            let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                                .appendingPathComponent("\(transcript.id.uuidString).\(ext)")

                            // Export doesn't have its own TUIState case (the
                            // plan scoped it as an optional brief confirmation,
                            // not a full screen), so show progress/result via
                            // direct terminal writes rather than the state
                            // machine — state stays .viewingResults throughout,
                            // and the normal render resumes on the next loop
                            // tick after the confirmation pause below.
                            writeToTerminal(["Exporting to \(outputURL.lastPathComponent)..."])

                            _ = try await export.export(
                                transcript: transcript,
                                summary: summary,
                                format: format,
                                to: outputURL
                            )

                            writeToTerminal([
                                "Exported to: \(outputURL.path)",
                                "",
                                "[any key] Continue"
                            ])
                            // Actually wait for a keypress rather than a fixed
                            // delay — readKeyNonBlocking() already blocks for
                            // up to VTIME's 0.1s per call (see RawTerminalMode),
                            // so this loop is self-pacing without spinning.
                            while readKeyNonBlocking() == nil {}

                        case .loadConfigStatus:
                            let (url, sourceInfo) = InnerEarConfigResolver.resolveDataDirectoryWithSource()
                            state.settings = .viewing(
                                resolvedPath: url.path,
                                source: mapSource(sourceInfo)
                            )
                            renderNow()

                        case .saveDataDirectory(let path):
                            // Two distinct failure/success paths. On write
                            // failure, surface a modal and skip the rest of
                            // this iteration (the `continue` jumps to the
                            // next effect in the `for effect in effects`
                            // loop without trying to refresh state from a
                            // half-rewritten store). On success, recreate
                            // the store (so it picks up the new config),
                            // refresh the status, and invalidate the cached
                            // Recordings list.
                            do {
                                try InnerEarConfigResolver.writeRecordingsDirectory(path)
                            } catch {
                                state.modal = .error("\(error)")
                                renderNow()
                                continue
                            }
                            // Success path.
                            do {
                                store = try RecordingStore()
                            } catch {
                                state.modal = .error("\(error)")
                                renderNow()
                                continue
                            }
                            let (url, sourceInfo) = InnerEarConfigResolver.resolveDataDirectoryWithSource()
                            state.settings = .viewing(
                                resolvedPath: url.path,
                                source: mapSource(sourceInfo)
                            )
                            // Reload the Recordings list from the fresh
                            // store (its contents live under the new data
                            // directory). If the list call throws for any
                            // reason, fall back to an empty list rather
                            // than surfacing another error here — the
                            // user can always re-enter the pane to retry.
                            let recordings = (try? store.listRecordings()) ?? []
                            state.recordings = .list(recordings: recordings, selectedIndex: 0)
                            renderNow()

                        case .quit:
                            rawMode.restore()
                            return
                        }
                    } catch {
                        state.modal = .error("\(error)")
                        renderNow()
                    }
                }
            }

            // 2. Render (covers idle-state updates with no keypress, e.g. the
            // live elapsed-time counter while .recording)
            renderNow()

            // 3. Pace the loop
            try await Task.sleep(for: .milliseconds(150))
        }
    }

    /// Map `InnerEarConfigResolver.DataDirectorySourceInfo` (Core) to
    /// `TUIState.DataDirectorySource` (TUIKit). The two enums are kept
    /// structurally identical precisely so this mapping is mechanical
    /// and total; a switch here keeps the dependency direction Core -> TUIKit
    /// from being violated (the TUIKit enum cannot live in Core).
    private static func mapSource(_ source: InnerEarConfigResolver.DataDirectorySourceInfo) -> DataDirectorySource {
        switch source {
        case .envVar:          return .envVar
        case .configFile:      return .configFile
        case .defaultLocation: return .defaultLocation
        }
    }
}
