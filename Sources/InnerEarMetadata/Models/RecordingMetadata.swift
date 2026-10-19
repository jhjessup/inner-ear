import Foundation

/// The metadata context captured for one recording — linked by
/// `recordingID: UUID` only (never an actual `Recording`), the same
/// linkage pattern `Transcript`/`Summary` already use, so this target
/// never needs to depend on `InnerEarRecording` for anything beyond that
/// id type.
public struct RecordingMetadata: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let calendarContext: CalendarContext?
    public let windowContext: WindowContext?
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        calendarContext: CalendarContext?,
        windowContext: WindowContext?,
        capturedAt: Date
    ) {
        self.id = id
        self.recordingID = recordingID
        self.calendarContext = calendarContext
        self.windowContext = windowContext
        self.capturedAt = capturedAt
    }
}
