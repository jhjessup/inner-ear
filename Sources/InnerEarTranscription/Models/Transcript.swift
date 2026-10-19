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
    /// Wall-clock time the underlying recording started. Used by export
    /// formats to render absolute UTC timestamps for each segment
    /// (in addition to the segment's own relative `startTime`). No default
    /// value — this used to default to `Date()` "for convenience," but that
    /// default is silently wrong for any transcript describing a past
    /// recording: a caller that forgets to pass the real
    /// `recording.createdAt` would get the moment the `Transcript` object
    /// happened to be constructed instead, corrupting every exported
    /// absolute timestamp with no error or warning. Requiring it explicitly
    /// pushes that mistake to a compile error at the one production call
    /// site that matters (`WhisperKitTranscriptionService`) instead of a
    /// silent data-correctness bug discovered later in an export file.
    public let recordingStartedAt: Date

    public init(
        id: UUID = UUID(),
        recordingID: UUID,
        languageCode: String,
        modelUsed: String,
        speakers: [Speaker],
        segments: [TranscriptSegment],
        generatedAt: Date,
        recordingStartedAt: Date
    ) {
        self.id = id
        self.recordingID = recordingID
        self.languageCode = languageCode
        self.modelUsed = modelUsed
        self.speakers = speakers
        self.segments = segments
        self.generatedAt = generatedAt
        self.recordingStartedAt = recordingStartedAt
    }

    public var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }

    public func speaker(for segment: TranscriptSegment) -> Speaker? {
        guard let speakerID = segment.speakerID else { return nil }
        return speakers.first { $0.id == speakerID }
    }
}
