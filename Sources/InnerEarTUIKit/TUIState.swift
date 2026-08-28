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
        recordings: RecordingsSectionState = .list(recordings: [], selectedIndex: 0),
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
    case list(recordings: [Recording], selectedIndex: Int)
    case processing(recording: Recording, statusLine: String)
    case viewingResults(transcript: Transcript, summary: Summary?, scrollOffset: Int)
}

public enum SettingsSectionState: Equatable, Sendable {
    case viewing(resolvedPath: String, source: DataDirectorySource)
    case editing(currentInput: String)
}

public enum DataDirectorySource: Equatable, Sendable { case envVar, configFile, defaultLocation }

public enum Modal: Equatable, Sendable { case error(String) }

/// Human-readable names for the 3 nav-pane sections, in order (index 0, 1, 2).
public let tuiSectionNames = ["Record", "Recordings", "Settings"]
