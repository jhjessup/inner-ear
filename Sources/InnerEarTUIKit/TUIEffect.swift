import Foundation
import InnerEarCore

/// Side effects that the TUI state machine can request. The run loop (in
/// `InnerEarCLI/TUIRunLoop.swift`) is responsible for executing each effect
/// and then updating state based on the async result. `reduce()` itself is
/// pure and synchronous — it never awaits.
public enum TUIEffect: Equatable, Sendable {
    /// Start a new audio capture session. `captureSystemAudio` comes from
    /// the user's choice at the record prompt.
    case startRecording(captureSystemAudio: Bool)

    /// Stop the active capture. The run loop will call
    /// `audioCapture.stopCapture()`, persist the returned `Recording`, and
    /// then transition to `.recordingSaved`.
    case stopRecording

    /// Load all persisted recordings from `RecordingStore`. The run loop
    /// will call `store.listRecordings()` and then transition to
    /// `.browsing(recordings:result, selectedIndex:0)`.
    case loadRecordings

    /// Run the full pipeline (transcribe → diarize → summarize) for the
    /// given recording. The run loop executes this async sequence and
    /// transitions to `.viewingResults` on success (or `.errorMessage` on
    /// failure).
    case runPipeline(Recording)

    /// Export the transcript (and optional summary) to a file. `format` is
    /// hardcoded to `.markdown` for v1; the run loop calls
    /// `export.export(...)` and may briefly show a confirmation.
    case exportResult(transcript: Transcript, summary: Summary?, format: ExportFormat)

    /// Quit the application cleanly.
    case quit
}