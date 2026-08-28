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

        // `store` is mutable because `.saveDataDirectory` may need to
        // rebuild it (a fresh `RecordingStore` reads the (possibly new)
        // config.json from disk on init). Boxed in a class (rather than a
        // plain `var`) so the SIGINT/SIGTERM cleanup closure below can
        // capture a stable reference and always see the latest store,
        // instead of capturing a mutable local var across a concurrency
        // boundary (which Swift 6 strict concurrency disallows).
        let storeBox = StoreBox(store)

        // Ctrl-C/SIGTERM must never silently discard an in-progress
        // recording. `stopCapture()` throws `.noActiveCapture` (caught by
        // `try?`, becoming a harmless no-op) when nothing is recording, so
        // this can run unconditionally on every interrupt without needing
        // to inspect `state` from outside the run loop.
        installSignalHandlers(
            restoreAction: { rawMode.restore() },
            cleanup: {
                if let recording = try? await audioCapture.stopCapture() {
                    try? storeBox.store.save(recording)
                }
            }
        )

        var state = TUIState()

        // Eagerly load the Recordings list once at startup, even though
        // the Recordings section isn't focused yet. The detail pane always
        // previews whichever section is currently highlighted in the nav
        // pane — including while just moving the nav selection with j/k,
        // before Enter is ever pressed — so without this, browsing over
        // to "Recordings" shows a stale, empty `.list(entries: [], ...)`
        // ("No recordings yet.") right up until the user actually presses
        // Enter and `.loadRecordings` fires. `.loadRecordings` itself is
        // still triggered on every nav Enter into this section, so this is
        // purely about the pane's PREVIEW being accurate from frame one,
        // not a substitute for that refresh.
        state.recordings = .list(entries: buildRecordingListEntries(store: storeBox.store), selectedIndex: 0)

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
            // 1. Read key (non-blocking) — includes arrow-key recognition,
            // mapped to the same j/k the controller already understands.
            if let key = readKeyOrArrowNonBlocking() {
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
                            try storeBox.store.save(recording)
                            state.record = .saved(recording)
                            renderNow()

                        case .loadRecordings:
                            let entries = buildRecordingListEntries(store: storeBox.store)
                            state.recordings = .list(entries: entries, selectedIndex: 0)
                            renderNow()

                        case .runPipeline(let recording):
                            // Transcribe
                            state.recordings = .processing(recording: recording, statusLine: "Transcribing...", stepIndex: 1)
                            renderNow()
                            let transcript = try await transcription.transcribe(
                                recording: recording,
                                model: .whisperLargeV3Turbo,
                                languageCode: nil
                            )

                            // Diarize
                            state.recordings = .processing(recording: recording, statusLine: "Diarizing...", stepIndex: 2)
                            renderNow()
                            let diarizedTranscript = try await diarization.diarize(
                                transcript: transcript,
                                recording: recording
                            )

                            // Summarize
                            state.recordings = .processing(recording: recording, statusLine: "Summarizing...", stepIndex: 3)
                            renderNow()
                            let summary = try await summarization.summarize(transcript: diarizedTranscript)

                            // Persist results
                            try storeBox.store.save(diarizedTranscript)
                            try storeBox.store.save(summary)

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
                            while readKeyOrArrowNonBlocking() == nil {}

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
                                storeBox.store = try RecordingStore()
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
                            // directory). If the lookup throws for any
                            // reason, fall back to an empty list rather
                            // than surfacing another error here — the
                            // user can always re-enter the pane to retry.
                            // Reuses the same entry-building helper as
                            // `.loadRecordings` so the per-row audio /
                            // transcript / summary / file-URL resolution
                            // is identical to a fresh nav-Enter.
                            let entries = buildRecordingListEntries(store: storeBox.store)
                            state.recordings = .list(entries: entries, selectedIndex: 0)
                            renderNow()

                        case .deleteAudio(let recording):
                            // Swallow errors with `try?` — a delete failing
                            // (e.g. file already gone) shouldn't surface a
                            // modal and interrupt the flow, since
                            // `.loadRecordings` runs right after (chained
                            // by the controller) and will just reflect
                            // whatever the real on-disk state ends up
                            // being.
                            try? storeBox.store.deleteAudioFiles(for: recording)
                            cleanupOrphanedCatalogEntryIfNeeded(recording.id, store: storeBox.store)

                        case .deleteTranscript(let transcript):
                            // Same `try?` rationale as `.deleteAudio` — a
                            // missing-on-disk transcript is not an error
                            // case for the user, just a no-op that the
                            // follow-up `.loadRecordings` will reflect.
                            try? storeBox.store.deleteTranscript(transcript)
                            cleanupOrphanedCatalogEntryIfNeeded(transcript.recordingID, store: storeBox.store)

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

    /// Build the full `[RecordingListEntry]` array for the Recordings list
    /// by resolving each recording's audio presence, transcript (by
    /// `recordingID`), summary (by `transcriptID`), and the on-disk
    /// transcript JSON URL — all in one pass over the store's contents.
    /// Used by both `.loadRecordings` (initial nav-Enter into the
    /// Recordings section) and the `.saveDataDirectory` success path
    /// (which rebuilds the store with a new data directory and needs the
    /// list re-resolved against the fresh contents).
    ///
    /// Failures are swallowed at the per-field level (e.g. a missing
    /// transcripts directory yields `[]`, not a thrown error) so a
    /// partially-populated store still renders something useful rather
    /// than a hard error in the UI.
    private static func buildRecordingListEntries(store: RecordingStore) -> [RecordingListEntry] {
        let recordings = (try? store.listRecordings()) ?? []
        let allTranscripts = (try? store.listTranscripts()) ?? []
        let allSummaries = (try? store.listSummaries()) ?? []
        return recordings.map { recording in
            let hasAudio = FileManager.default.fileExists(atPath: recording.microphoneFileURL.path)
            let transcript = allTranscripts.first { $0.recordingID == recording.id }
            let summary = transcript.flatMap { t in allSummaries.first { $0.transcriptID == t.id } }
            let transcriptURL = transcript.map { store.transcriptFileURL(for: $0) }
            return RecordingListEntry(
                recording: recording,
                hasAudio: hasAudio,
                transcript: transcript,
                summary: summary,
                transcriptFileURL: transcriptURL
            )
        }
    }

    /// After deleting a recording's audio or transcript, remove the
    /// Recording catalog entry entirely if BOTH are now gone — otherwise a
    /// fully-empty ghost entry (no audio, no transcript) would linger in
    /// the list forever with nothing useful to show or do with it.
    private static func cleanupOrphanedCatalogEntryIfNeeded(_ recordingID: UUID, store: RecordingStore) {
        guard let recording = try? store.loadRecording(id: recordingID) else { return }
        let hasAudio = FileManager.default.fileExists(atPath: recording.microphoneFileURL.path)
        let hasTranscript = (try? store.listTranscripts())?.contains { $0.recordingID == recordingID } ?? false
        if !hasAudio && !hasTranscript {
            try? store.deleteRecordingCatalogEntry(recordingID)
        }
    }
}

/// Mutable-reference holder for `RecordingStore`, so the SIGINT/SIGTERM
/// cleanup closure in `run(...)` can capture a stable reference and always
/// observe the latest store (after a `.saveDataDirectory` reassignment)
/// instead of capturing a `var` local across a concurrency boundary, which
/// Swift 6 strict concurrency disallows. A signal can fire at any moment,
/// including concurrently with the main run loop reassigning `store` mid-
/// `.saveDataDirectory` — so this is genuinely accessed from two contexts
/// at once, not just formally, and needs real synchronization rather than
/// an `@unchecked Sendable` free pass on a plain `var`.
private final class StoreBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _store: RecordingStore

    init(_ store: RecordingStore) {
        self._store = store
    }

    var store: RecordingStore {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _store
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _store = newValue
        }
    }
}
