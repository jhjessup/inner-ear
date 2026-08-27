import Foundation

/// Metadata for a single recorded session. The actual audio lives on disk at
/// `microphoneFileURL` / `systemAudioFileURL`; this struct never embeds audio bytes.
public struct Recording: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let duration: TimeInterval
    public let microphoneFileURL: URL
    /// nil if system audio was not captured for this recording.
    public let systemAudioFileURL: URL?

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date,
        duration: TimeInterval,
        microphoneFileURL: URL,
        systemAudioFileURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.microphoneFileURL = microphoneFileURL
        self.systemAudioFileURL = systemAudioFileURL
    }

    public var hasSystemAudio: Bool {
        systemAudioFileURL != nil
    }
}
