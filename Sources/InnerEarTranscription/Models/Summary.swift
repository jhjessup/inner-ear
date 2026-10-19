import Foundation

/// A structured AI-generated summary of a transcript.
public struct Summary: Identifiable, Hashable, Codable, Sendable {
    public struct ActionItem: Identifiable, Hashable, Codable, Sendable {
        public let id: UUID
        public let text: String
        public let ownerSpeakerID: UUID?

        public init(id: UUID = UUID(), text: String, ownerSpeakerID: UUID? = nil) {
            self.id = id
            self.text = text
            self.ownerSpeakerID = ownerSpeakerID
        }
    }

    public let id: UUID
    public let transcriptID: UUID
    public let overview: String
    public let keyPoints: [String]
    public let decisions: [String]
    public let actionItems: [ActionItem]
    /// Which model produced this summary — a local Core ML model name, or
    /// "cloud:<provider>" when the operator opted into a cloud AI key.
    public let generatedByModel: String
    public let generatedAt: Date

    public init(
        id: UUID = UUID(),
        transcriptID: UUID,
        overview: String,
        keyPoints: [String],
        decisions: [String],
        actionItems: [ActionItem],
        generatedByModel: String,
        generatedAt: Date
    ) {
        self.id = id
        self.transcriptID = transcriptID
        self.overview = overview
        self.keyPoints = keyPoints
        self.decisions = decisions
        self.actionItems = actionItems
        self.generatedByModel = generatedByModel
        self.generatedAt = generatedAt
    }
}
