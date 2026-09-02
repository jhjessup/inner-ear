import Foundation

public struct SpeakerTurn: Equatable, Sendable {
    public let clusterID: Int
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(clusterID: Int, startTime: TimeInterval, endTime: TimeInterval) {
        self.clusterID = clusterID
        self.startTime = startTime
        self.endTime = endTime
    }
}

public enum SpeakerSeparationError: Error, Equatable, Sendable {
    case separationFailed(reason: String)
}

/// Identifies distinct speakers in an audio file and returns the time
/// ranges during which each one is active. Implementation runs fully
/// on-device via SpeakerKit (pyannote-backed Core ML pipeline); no network
/// access is performed beyond the one-time model download during
/// initialization.
public protocol SpeakerSeparationService: AnyObject, Sendable {
    func separateSpeakers(audioFileURL: URL) async throws -> [SpeakerTurn]
}