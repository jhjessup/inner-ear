import Foundation
import InnerEarCore
import InnerEarTUIKit

/// The TUI run loop: bridges the pure `TUIController.reduce` state machine
/// with the real async service implementations and terminal I/O.
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

        var state: TUIState = .mainMenu

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
                // recordPrompt, or the "Starting..." processing screen)
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
                            state = .recordingSaved(recording)
                            renderNow()

                        case .loadRecordings:
                            let recordings = try store.listRecordings()
                            state = .browsing(recordings: recordings, selectedIndex: 0)
                            renderNow()

                        case .runPipeline(let recording):
                            // Transcribe
                            state = .processing(recording: recording, statusLine: "Transcribing...")
                            renderNow()
                            let transcript = try await transcription.transcribe(
                                recording: recording,
                                model: .whisperLargeV3Turbo,
                                languageCode: nil
                            )

                            // Diarize
                            state = .processing(recording: recording, statusLine: "Diarizing...")
                            renderNow()
                            let diarizedTranscript = try await diarization.diarize(
                                transcript: transcript,
                                recording: recording
                            )

                            // Summarize
                            state = .processing(recording: recording, statusLine: "Summarizing...")
                            renderNow()
                            let summary = try await summarization.summarize(transcript: diarizedTranscript)

                            // Persist results
                            try store.save(diarizedTranscript)
                            try store.save(summary)

                            // Transition to results view
                            state = .viewingResults(
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

                            _ = try await export.export(
                                transcript: transcript,
                                summary: summary,
                                format: format,
                                to: outputURL
                            )
                            // Optionally show a brief confirmation — for now just stay in viewingResults

                        case .quit:
                            rawMode.restore()
                            return
                        }
                    } catch {
                        state = .errorMessage("\(error)")
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
}