import Foundation
import InnerEarCore

public struct TUIState: Equatable, Sendable {
    public var focusedPane: Pane
    public var selectedSection: Int
    public var record: RecordSectionState
    public var recordings: RecordingsSectionState
    public var settings: SettingsSectionState
    public var modal: Modal?

    public init(
        focusedPane: Pane = .navigation,
        selectedSection: Int = 0,
        record: RecordSectionState = .idle,
        recordings: RecordingsSectionState = .list(entries: [], selectedIndex: 0),
        settings: SettingsSectionState = .viewing(resolvedPath: "", source: .defaultLocation),
        modal: Modal? = nil
    ) {
        self.focusedPane = focusedPane
        self.selectedSection = selectedSection
        self.record = record
        self.recordings = recordings
        self.settings = settings
        self.modal = modal
    }
}

public enum Pane: Equatable, Sendable { case navigation, detail }

public enum RecordSectionState: Equatable, Sendable {
    case idle
    case prompting
    case recording(startedAt: Date, captureSystemAudio: Bool)
    case saved(Recording)
}

public enum RecordingsSectionState: Equatable, Sendable {
    case list(entries: [RecordingListEntry], selectedIndex: Int)
    case confirmGenerateTranscript(entries: [RecordingListEntry], selectedIndex: Int)
    case confirmDelete(entries: [RecordingListEntry], selectedIndex: Int)
    /// `stepIndex` is 0 before the pipeline's first phase begins ("Starting..."),
    /// then 1/2/3 as Transcribing/Diarizing/Summarizing begin — drives the
    /// progress bar in `TUIRenderer`. There are always exactly 3 phases
    /// (transcribe → diarize → summarize), so the total isn't stored here.
    case processing(recording: Recording, statusLine: String, stepIndex: Int)
    case viewingResults(transcript: Transcript, summary: Summary?, scrollOffset: Int)
}

public enum SettingsSectionState: Equatable, Sendable {
    case viewing(resolvedPath: String, source: DataDirectorySource)
    case editing(currentInput: String)
}

public enum DataDirectorySource: Equatable, Sendable { case envVar, configFile, defaultLocation }

public enum Modal: Equatable, Sendable { case error(String) }

/// One row in the Recordings list: a `Recording` plus everything the UI
/// needs to know about its associated audio/transcript/summary WITHOUT
/// further I/O — all of this is resolved once by the run loop when
/// `.loadRecordings` executes, so TUIController/TUIRenderer stay pure.
public struct RecordingListEntry: Equatable, Sendable {
    public let recording: Recording
    public let hasAudio: Bool
    public let transcript: Transcript?
    public let summary: Summary?
    public let transcriptFileURL: URL?

    public init(
        recording: Recording,
        hasAudio: Bool,
        transcript: Transcript?,
        summary: Summary?,
        transcriptFileURL: URL?
    ) {
        self.recording = recording
        self.hasAudio = hasAudio
        self.transcript = transcript
        self.summary = summary
        self.transcriptFileURL = transcriptFileURL
    }

    public var hasTranscript: Bool { transcript != nil }
}

public enum DeleteTarget: Equatable, Sendable { case audio, transcript, both }

/// Human-readable names for the 3 nav-pane sections, in order (index 0, 1, 2).
public let tuiSectionNames = ["Record", "Recordings", "Settings"]
