import Foundation

/// A single contiguous span of transcribed speech, attributed to one speaker.
public struct TranscriptSegment: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let speakerID: UUID?
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(
        id: UUID = UUID(),
        speakerID: UUID?,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        self.id = id
        self.speakerID = speakerID
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}
