import Foundation
// SpeakerKit's own types (e.g. the SpeakerKit pipeline class itself)
// aren't yet Sendable-audited, which trips Swift 6 strict concurrency when
// they cross this actor's isolation boundary — same situation as WhisperKit
// in WhisperKitTranscriptionService, same fix.
@preconcurrency import SpeakerKit
// Imported solely for `AudioProcessor.loadAudioAsFloatArray(fromPath:)`,
// which is how we decode an audio file into the raw mono float array the
// SpeakerKit diarize pipeline expects. AudioProcessor is a static utility
// re-exported from WhisperKit's decoding path; no WhisperKit instance
// state crosses this actor's isolation boundary.
import WhisperKit

/// On-device speaker diarization backed by SpeakerKit (pyannote audio
/// embedding pipeline running on Core ML). Fully local — no network access
/// is performed beyond SpeakerKit's one-time model download during
/// initialization.
///
/// An actor, not a class + NSLock: the pipeline cache needs to be safely
/// read/written from async contexts (loading SpeakerKit is itself async),
/// and NSLock.lock()/.unlock() are `noasync` under Swift 6 strict
/// concurrency — actor isolation is the correct tool here, same pattern
/// as WhisperKitTranscriptionService.
public actor SpeakerKitSpeakerSeparationService: SpeakerSeparationService {

    /// Cached SpeakerKit pipeline instance. Holding it across calls avoids
    /// re-downloading and re-compiling the Core ML model on every
    /// `separateSpeakers(audioFileURL:)` invocation. No explicit locking
    /// needed — actor isolation already serializes access.
    private var pipeline: SpeakerKit?

    public init() {}

    // MARK: - SpeakerSeparationService

    public func separateSpeakers(audioFileURL: URL) async throws -> [SpeakerTurn] {
        // Decode the audio file into a mono float array via WhisperKit's
        // AudioProcessor — SpeakerKit's diarize(audioArray:) expects
        // exactly this shape. AudioProcessor.loadAudioAsFloatArray is a
        // static, throwing (not async) call, so we wrap any decode
        // failure into our domain error type.
        let audioArray: [Float]
        do {
            audioArray = try AudioProcessor.loadAudioAsFloatArray(fromPath: audioFileURL.path)
        } catch {
            throw SpeakerSeparationError.separationFailed(
                reason: "Failed to load audio for speaker separation: \(error.localizedDescription)"
            )
        }

        let pipeline = try await loadPipeline()

        let result: DiarizationResult
        do {
            result = try await pipeline.diarize(audioArray: audioArray)
        } catch {
            throw SpeakerSeparationError.separationFailed(reason: error.localizedDescription)
        }

        // Map SpeakerKit's segments to our domain `SpeakerTurn`. Segments
        // whose `SpeakerInfo` carries no single concrete speakerId (the
        // `.multiple`/`.noMatch` cases) are dropped — we only surface turns
        // we can confidently attribute to one specific speaker cluster.
        return result.segments.compactMap { segment in
            guard let speakerID = segment.speaker.speakerId else { return nil }
            return SpeakerTurn(
                clusterID: speakerID,
                startTime: TimeInterval(segment.startTime),
                endTime: TimeInterval(segment.endTime)
            )
        }
    }

    // MARK: - Pipeline management

    /// Return a cached `SpeakerKit` pipeline, initializing it on first use.
    /// Subsequent calls reuse the loaded pipeline.
    private func loadPipeline() async throws -> SpeakerKit {
        if let existing = pipeline {
            return existing
        }

        // SpeakerKit's initializer is `async throws` (downloads + Core ML
        // compilation on first run). The default config
        // (`PyannoteConfig()`) selects the pyannote-backed embedding
        // model — call the no-arg form `try await SpeakerKit()` to get it.
        let instance: SpeakerKit
        do {
            instance = try await SpeakerKit()
        } catch {
            throw SpeakerSeparationError.separationFailed(
                reason: "Failed to initialize SpeakerKit pipeline: \(error.localizedDescription)"
            )
        }

        pipeline = instance
        return instance
    }
}