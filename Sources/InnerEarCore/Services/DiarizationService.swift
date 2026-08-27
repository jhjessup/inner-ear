import Foundation

public enum DiarizationError: Error, Equatable, Sendable {
    case tooManySpeakers(detected: Int, maxSupported: Int)
    case diarizationFailed(reason: String)
}

/// Assigns speaker identity to each transcript segment on-device. The
/// microphone channel is always resolved to a single "local user" speaker;
/// the system-audio channel (when present) is diarized into up to 8 distinct
/// remote speakers.
public protocol DiarizationService: AnyObject, Sendable {
    /// Maximum distinct remote speakers this implementation supports.
    var maxSupportedSpeakers: Int { get }

    /// Returns a new Transcript with `speakers` populated and each segment's
    /// `speakerID` assigned. Must be deterministic for a given input
    /// recording — see TEST_DOCTRINE.md MTM-4.
    func diarize(transcript: Transcript, recording: Recording) async throws -> Transcript
}
