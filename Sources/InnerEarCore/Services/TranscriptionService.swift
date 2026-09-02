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
    ///
    /// `progressHandler` is an optional live-progress callback. When non-nil,
    /// implementations should invoke it from their underlying engine's own
    /// progress hook (e.g. WhisperKit's `TranscriptionCallback`) with a
    /// running, monotonically-nondecreasing WORD COUNT (not a percentage —
    /// most on-device engines do not expose a fraction-complete value, only
    /// accumulating decoded text/tokens). The callback may be invoked many
    /// times per second and from arbitrary threads; it must be safe to call
    /// from any thread and must not assume actor isolation. Callers that
    /// don't need live progress should pass `nil` (or use the convenience
    /// 3-argument overload below).
    func transcribe(
        recording: Recording,
        model: TranscriptionModel,
        languageCode: String?,
        progressHandler: (@Sendable (Int) -> Void)?
    ) async throws -> Transcript

    /// Re-run transcription on an existing recording with a different model,
    /// preserving prior speaker diarization if `preserveSpeakers` is true.
    func retranscribe(
        recording: Recording,
        model: TranscriptionModel,
        preserveSpeakers: Bool
    ) async throws -> Transcript
}

extension TranscriptionService {
    /// Shared "this model isn't supported" error, factored out of any one
    /// implementation. `.parakeet` is a real case on `TranscriptionModel`
    /// (the domain enum intentionally mirrors Thoth's accuracy-vs-speed
    /// tradeoff) but has no implementation anywhere yet —
    /// `WhisperKitTranscriptionService` rejects it at runtime rather than
    /// letting it silently no-op or crash into a nonexistent WhisperKit
    /// API. That rejection previously lived only inside
    /// `WhisperKitTranscriptionService`'s own `switch`; a future second
    /// `TranscriptionService` implementation would have had to remember to
    /// replicate the exact same check. Call this from any implementation's
    /// `transcribe(...)` for a model it doesn't support, so the failure
    /// message and error case are consistent everywhere rather than
    /// per-implementation copy-paste.
    public static func unsupportedModelError(_ model: TranscriptionModel) -> TranscriptionError {
        .transcriptionFailed(reason: "\(model.rawValue) model not yet supported")
    }

    /// Convenience overload for callers that don't need live progress — this
    /// is what makes the existing 3-argument call sites (ChannelBasedDiarizationService,
    /// TranscribeCommand) keep compiling unchanged. `progressHandler` reports a
    /// running WORD COUNT (not a percentage — WhisperKit's own callback doesn't
    /// expose a fraction-complete value, only accumulating decoded text/tokens).
    public func transcribe(
        recording: Recording,
        model: TranscriptionModel,
        languageCode: String?
    ) async throws -> Transcript {
        try await transcribe(recording: recording, model: model, languageCode: languageCode, progressHandler: nil)
    }
}
