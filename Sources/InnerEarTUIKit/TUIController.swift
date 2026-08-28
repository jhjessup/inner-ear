import Foundation
import InnerEarCore

/// Pure, synchronous state machine for the TUI.
///
/// `reduce(state, event)` returns the next state plus zero or more effects.
/// It does **not** execute effects — it only declares *what* should happen.
/// The run loop (in `InnerEarCLI/TUIRunLoop.swift`) is responsible for:
///   1. Calling `reduce` on each key event.
///   2. Executing each returned effect (async I/O, service calls).
///   3. Updating state *directly* based on the effect's result (e.g. after
///      `.loadRecordings` completes, the run loop sets state to
///      `.browsing(recordings: result, selectedIndex: 0)`; after
///      `.stopRecording` yields a `Recording`, it sets
///      `.recordingSaved(recording)`).
///
/// This division exists because `reduce` cannot know the real `Recording`
/// UUID/duration until `stopCapture()` returns, and cannot know the loaded
/// recordings array until `listRecordings()` returns. Those async boundaries
/// are closed by the run loop, not by re-entering `reduce`.
public enum TUIController {
    /// Apply one event to the current state, returning the new state and any
    /// effects that the run loop should execute.
    ///
    /// - Parameters:
    ///   - state: Current TUI state.
    ///   - event: Incoming event (keypress or tick).
    /// - Returns: `(nextState, effects)` where `effects` may be empty.
    public static func reduce(_ state: TUIState, _ event: TUIEvent) -> (TUIState, [TUIEffect]) {
        switch (state, event) {
        // MARK: - Main Menu
        case (.mainMenu, .key("1")):
            return (.recordPrompt, [])

        case (.mainMenu, .key("2")):
            // Stay on mainMenu; the run loop will execute .loadRecordings
            // and then directly set state to .browsing when it completes.
            return (.mainMenu, [.loadRecordings])

        case (.mainMenu, .key("q")):
            return (.mainMenu, [.quit])

        // MARK: - Record Prompt
        case (.recordPrompt, .key("y")):
            return (.recording(startedAt: Date(), captureSystemAudio: true), [.startRecording(captureSystemAudio: true)])

        case (.recordPrompt, .key("n")):
            return (.recording(startedAt: Date(), captureSystemAudio: false), [.startRecording(captureSystemAudio: false)])

        case (.recordPrompt, .key("b")):
            return (.mainMenu, [])

        // MARK: - Recording
        case (.recording, .key("s")):
            // Emit stopRecording effect; the run loop will call stopCapture(),
            // save the recording, and then set state = .recordingSaved(recording).
            // We return the current state unchanged so the UI keeps showing
            // the recording timer until the async stop completes.
            return (state, [.stopRecording])

        case (.recording, .tick):
            // The renderer computes elapsed = now - startedAt at render time.
            // No state change needed on tick.
            return (state, [])

        // MARK: - Recording Saved
        case (.recordingSaved(let recording), .key("\r")),
             (.recordingSaved(let recording), .key("\n")):
            // User pressed Enter/Return to process the saved recording.
            // The run loop will execute .runPipeline and transition to
            // .processing → .viewingResults.
            return (.processing(recording: recording, statusLine: "Starting..."), [.runPipeline(recording)])

        case (.recordingSaved, .key("b")):
            return (.mainMenu, [])

        // MARK: - Browsing
        case (.browsing(let recordings, let selectedIndex), .key("j")):
            let newIndex = min(selectedIndex + 1, max(0, recordings.count - 1))
            return (.browsing(recordings: recordings, selectedIndex: newIndex), [])

        case (.browsing(let recordings, let selectedIndex), .key("k")):
            let newIndex = max(selectedIndex - 1, 0)
            return (.browsing(recordings: recordings, selectedIndex: newIndex), [])

        case (.browsing(let recordings, let selectedIndex), .key("\r")),
             (.browsing(let recordings, let selectedIndex), .key("\n")):
            if !recordings.isEmpty {
                let recording = recordings[selectedIndex]
                return (.processing(recording: recording, statusLine: "Starting..."), [.runPipeline(recording)])
            }
            return (state, [])

        case (.browsing, .key("b")):
            return (.mainMenu, [])

        // MARK: - Viewing Results
        case (.viewingResults(let transcript, let summary, let scrollOffset), .key("j")):
            // Increment scrollOffset; the renderer clamps against content height.
            return (.viewingResults(transcript: transcript, summary: summary, scrollOffset: scrollOffset + 1), [])

        case (.viewingResults(let transcript, let summary, let scrollOffset), .key("k")):
            let newOffset = max(scrollOffset - 1, 0)
            return (.viewingResults(transcript: transcript, summary: summary, scrollOffset: newOffset), [])

        case (.viewingResults(let transcript, let summary, _), .key("e")):
            // Hardcode markdown format for v1.
            return (state, [.exportResult(transcript: transcript, summary: summary, format: .markdown)])

        case (.viewingResults, .key("b")):
            return (.mainMenu, [])

        // MARK: - Error Message
        case (.errorMessage, .key("b")):
            return (.mainMenu, [])

        // MARK: - Unhandled / Default
        default:
            // Any other (state, event) combination: no-op.
            return (state, [])
        }
    }
}