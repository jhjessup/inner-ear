import Foundation

/// Which on-device transcription model to use. Mirrors the tradeoff Thoth
/// exposes: Whisper Large V3 Turbo (accuracy) vs. Parakeet (speed).
public enum TranscriptionModel: String, CaseIterable, Codable, Sendable {
    case whisperLargeV3Turbo
    case parakeet
}

public enum TranscriptionError: Error, Equatable, Sendable {
    case audioFileUnreadable
    case modelNotDownloaded(TranscriptionModel)
    case transcriptionFailed(reason: String)
}

/// Transcribes a recording entirely on-device via WhisperKit/Core ML. No
/// network access is permitted in any conforming implementation — see
/// ORACLE.md CONSTRAINT_1 and TEST_DOCTRINE.md MTM-2.
public protocol TranscriptionService: AnyObject, Sendable {
    /// Transcribe the given recording's microphone (and, if present, system
    /// audio) files using `model`. `languageCode` is nil for auto-detection.
    func transcribe(
        recording: Recording,
        model: TranscriptionModel,
        languageCode: String?
    ) async throws -> Transcript

    /// Re-run transcription on an existing recording with a different model,
    /// preserving prior speaker diarization if `preserveSpeakers` is true.
    func retranscribe(
        recording: Recording,
        model: TranscriptionModel,
        preserveSpeakers: Bool
    ) async throws -> Transcript
}
