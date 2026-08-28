import Foundation
import InnerEarCore

/// The complete state of the TUI dashboard. All cases carry only value types
/// (Recording, Transcript, Summary are Sendable/Equatable/Hashable per their
/// model definitions), making this enum itself Equatable and Sendable.
public enum TUIState: Equatable, Sendable {
    /// Initial landing screen — shows the main menu options.
    case mainMenu

    /// Prompt asking whether to include system audio in the new recording.
    case recordPrompt

    /// An active recording session. `startedAt` is the wall-clock time when
    /// capture began; `captureSystemAudio` records the user's choice from
    /// `recordPrompt` so the renderer can display it.
    case recording(startedAt: Date, captureSystemAudio: Bool)

    /// The recording has been stopped and saved to disk. The `Recording`
    /// value contains the real persisted metadata (UUID, duration, file
    /// URLs, etc.) which the run loop obtained from `stopCapture()` +
    /// `store.save()`.
    case recordingSaved(Recording)

    /// Browsing the list of saved recordings. `selectedIndex` is the
    /// zero-based index of the currently highlighted row.
    case browsing(recordings: [Recording], selectedIndex: Int)

    /// The full pipeline (transcribe → diarize → summarize) is running for
    /// `recording`. `statusLine` is a human-readable description of the
    /// current step (e.g. "Transcribing…", "Diarizing…", "Summarizing…").
    case processing(recording: Recording, statusLine: String)

    /// Pipeline completed. Shows the transcript (and optional summary) in a
    /// scrollable viewport. `scrollOffset` is the zero-based line index of
    /// the first visible line in the rendered text block.
    case viewingResults(transcript: Transcript, summary: Summary?, scrollOffset: Int)

    /// An error occurred. `message` is a user-facing description.
    case errorMessage(String)
}