import Foundation
import WhisperKit

/// On-device transcription backed by WhisperKit (Core ML). Fully local — no
/// network access is performed beyond WhisperKit's one-time model download
/// during initialization.
///
/// NOTE: WhisperKit does not ship a Parakeet model as of common versions, so
/// the `.parakeet` case of `TranscriptionModel` is rejected up-front with a
/// clear `TranscriptionError.transcriptionFailed` rather than attempting a
/// nonexistent model load. If/when WhisperKit (or a separate Parakeet
/// pipeline) gains a Parakeet variant, this is the place to wire it in.
public final class WhisperKitTranscriptionService: TranscriptionService, @unchecked Sendable {

    /// The WhisperKit model variant identifier corresponding to each
    /// `TranscriptionModel` case. Centralized here so the mapping is easy to
    /// audit and update when WhisperKit renames a variant.
    private enum WhisperKitModelID {
        case whisperLargeV3Turbo

        var variant: String {
            switch self {
            // WhisperKit's published large-v3 turbo variant identifier
            // (matches the "openai_whisper-large-v3-v20240930_turbo" repo
            // on the WhisperKit HuggingFace org).
            case .whisperLargeV3Turbo:
                return "openai_whisper-large-v3-v20240930_turbo"
            }
        }
    }

    /// Loaded pipeline, keyed by the `WhisperKitModelID` it was initialized
    /// for. Holding it across calls avoids re-downloading and re-compiling
    /// the Core ML model on every `transcribe()` invocation.
    private var pipelineByModel: [WhisperKitModelID: WhisperKit] = [:]
    private let pipelineLock = NSLock()

    public init() {}

    // MARK: - TranscriptionService

    public func transcribe(
        recording: Recording,
        model: TranscriptionModel,
        languageCode: String?
    ) async throws -> Transcript {
        // Map our domain enum to WhisperKit's model identifier. Reject
        // unsupported models cleanly rather than letting WhisperKit fail
        // with a less informative error.
        let wkModelID: WhisperKitModelID
        switch model {
        case .whisperLargeV3Turbo:
            wkModelID = .whisperLargeV3Turbo
        case .parakeet:
            // WhisperKit itself does not ship a Parakeet model as of
            // common versions. Surface this as a transcription failure
            // with an actionable message rather than fabricating a
            // nonexistent WhisperKit API call.
            throw TranscriptionError.transcriptionFailed(
                reason: "Parakeet model not yet available via WhisperKit"
            )
        }

        // Verify the audio file exists on disk before asking WhisperKit
        // to load it, so we can throw a precise error.
        let audioURL = recording.microphoneFileURL
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileUnreadable
        }

        let pipeline = try await loadPipeline(for: wkModelID)

        // Run the transcription. We pass the file path so WhisperKit can
        // stream-decode the audio itself; passing the language code (when
        // provided) skips auto-detect and improves determinism. We build
        // explicit `DecodingOptions` rather than relying on WhisperKit's
        // convenience overload, which keeps the call site stable across
        // minor API revisions.
        var options = DecodingOptions()
        if let languageCode, !languageCode.isEmpty {
            options.language = languageCode
        }
        // WhisperKit's transcribe(audioPath:) returns [TranscriptionResult],
        // not a single result — long/chunked audio can produce multiple
        // chunks, each with its own segments. Concatenate them in order.
        let results: [TranscriptionResult]
        do {
            results = try await pipeline.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )
        } catch {
            throw TranscriptionError.transcriptionFailed(reason: error.localizedDescription)
        }

        return Self.makeTranscript(
            from: results,
            recording: recording,
            model: model,
            requestedLanguageCode: languageCode
        )
    }

    public func retranscribe(
        recording: Recording,
        model: TranscriptionModel,
        preserveSpeakers: Bool
    ) async throws -> Transcript {
        // TODO: Real speaker-preservation logic is future work — this project
        // does not yet have real diarization (Phase 4). For now, just re-run
        // the transcription with the new model. The `preserveSpeakers`
        // parameter is accepted for API compatibility but ignored.
        return try await transcribe(
            recording: recording,
            model: model,
            languageCode: nil
        )
    }

    // MARK: - Pipeline management

    /// Return a cached `WhisperKit` pipeline for the given model, initializing
    /// it on first use. Subsequent calls reuse the loaded pipeline.
    private func loadPipeline(for modelID: WhisperKitModelID) async throws -> WhisperKit {
        pipelineLock.lock()
        if let existing = pipelineByModel[modelID] {
            pipelineLock.unlock()
            return existing
        }
        pipelineLock.unlock()

        // WhisperKit's initializer is `async throws` (downloads + Core ML
        // compilation on first run) and takes the model identifier via the
        // `model:` parameter, not `variant:`.
        let variant = modelID.variant
        let pipeline: WhisperKit
        do {
            pipeline = try await WhisperKit(model: variant)
        } catch {
            throw TranscriptionError.transcriptionFailed(
                reason: "Failed to initialize WhisperKit pipeline for \(variant): \(error.localizedDescription)"
            )
        }

        pipelineLock.lock()
        // Last-writer-wins is acceptable here: any concurrent initializer
        // will have produced an equivalent pipeline for the same variant.
        pipelineByModel[modelID] = pipeline
        pipelineLock.unlock()

        return pipeline
    }

    // MARK: - Result mapping

    /// Convert WhisperKit's `TranscriptionResult` into our domain `Transcript`.
    /// All segments are attributed to a single default "Speaker 1" (the local
    /// user); real speaker diarization is Phase 4.
    private static func makeTranscript(
        from results: [TranscriptionResult],
        recording: Recording,
        model: TranscriptionModel,
        requestedLanguageCode: String?
    ) -> Transcript {
        // Use the requested language code if provided, otherwise prefer
        // WhisperKit's detected language from the first chunk, falling back
        // to "en" if neither is available.
        let detected = results.first?.language
        let resolvedLanguage: String = {
            if let requested = requestedLanguageCode, !requested.isEmpty {
                return requested
            }
            if let detected, !detected.isEmpty {
                return detected
            }
            return "en"
        }()

        // Build a single default speaker. All segments point at this speaker
        // until real diarization lands in Phase 4.
        let defaultSpeaker = Speaker(label: "Speaker 1", colorHex: "#3478F6", isLocalUser: true)

        // Long/chunked audio can come back as multiple TranscriptionResults —
        // flatten every chunk's segments in order into one segment list.
        let segments: [TranscriptSegment] = results.flatMap { result in
            result.segments.map { seg in
                TranscriptSegment(
                    speakerID: defaultSpeaker.id,
                    text: seg.text,
                    startTime: TimeInterval(seg.start),
                    endTime: TimeInterval(seg.end)
                )
            }
        }

        return Transcript(
            recordingID: recording.id,
            languageCode: resolvedLanguage,
            modelUsed: model.rawValue,
            speakers: [defaultSpeaker],
            segments: segments,
            generatedAt: Date()
        )
    }
}
