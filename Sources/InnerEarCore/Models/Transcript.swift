import Foundation

/// The full transcription result for a recording: ordered segments plus the
/// speakers referenced by them.
public struct Transcript: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let recordingID: UUID
    public let languageCode: String
    public let modelUsed: String
    public let speakers: [Speaker]
    public let segments: [TranscriptSegment]
    public let generatedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        languageCode: String,
        modelUsed: String,
        speakers: [Speaker],
        segments: [TranscriptSegment],
        generatedAt: Date
    ) {
        self.id = id
        self.recordingID = recordingID
        self.languageCode = languageCode
        self.modelUsed = modelUsed
        self.speakers = speakers
        self.segments = segments
        self.generatedAt = generatedAt
    }

    public var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }

    public func speaker(for segment: TranscriptSegment) -> Speaker? {
        guard let speakerID = segment.speakerID else { return nil }
        return speakers.first { $0.id == speakerID }
    }
}
