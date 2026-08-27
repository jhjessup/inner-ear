import Foundation

/// A single contiguous span of transcribed speech, attributed to one speaker.
public struct TranscriptSegment: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let speakerID: UUID?
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    /// Per-word confidence, when the transcription engine provides it. Empty if unavailable.
    public let lowConfidenceWordRanges: [Range<String.Index>]

    public init(
        id: UUID = UUID(),
        speakerID: UUID?,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        lowConfidenceWordRanges: [Range<String.Index>] = []
    ) {
        self.id = id
        self.speakerID = speakerID
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.lowConfidenceWordRanges = lowConfidenceWordRanges
    }

    // Range<String.Index> isn't directly Codable — encode/decode as UTF-8 offsets instead.
    private enum CodingKeys: String, CodingKey {
        case id, speakerID, text, startTime, endTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        speakerID = try container.decodeIfPresent(UUID.self, forKey: .speakerID)
        text = try container.decode(String.self, forKey: .text)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        lowConfidenceWordRanges = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(speakerID, forKey: .speakerID)
        try container.encode(text, forKey: .text)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
    }
}
