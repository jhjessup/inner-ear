import Foundation

/// A single identified speaker within a recording.
///
/// Speaker 1 is always the local microphone channel (the user); all other
/// speakers are attributed from the system-audio channel by diarization.
public struct Speaker: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let label: String
    public let colorHex: String
    public let isLocalUser: Bool

    public init(id: UUID = UUID(), label: String, colorHex: String, isLocalUser: Bool = false) {
        self.id = id
        self.label = label
        self.colorHex = colorHex
        self.isLocalUser = isLocalUser
    }
}
