import Foundation

/// Channel-based `DiarizationService` implementation.
///
/// This is the Phase 4 diarization approach chosen in
/// `docs/adr/phase-4-diarization-approach.md`. The decision rationale is:
/// InnerEar captures two independent audio channels from the start
/// (microphone = local user, system audio = remote participants), so the
/// "who is speaking" problem is partially already solved by the capture
/// architecture. This service finishes the job for the system-audio side
/// by transcribing that channel with the same `TranscriptionService` used
/// for the mic channel and merging the results, labeling all system-audio
/// segments with a single remote "Speaker 2" identity.
///
/// This deliberately does NOT do full multi-speaker separation within the
/// system-audio channel (Alice vs. Bob on the far end are both "Speaker 2
/// (Remote)"). That's explicitly out of scope for this phase — see the
/// ADR for what's deferred. It also does NOT depend on WhisperKit's
/// experimental diarization API, keeping our third-party API surface
/// limited to the stable `TranscriptionService` we already have working
/// end-to-end in Phase 3.
public final class ChannelBasedDiarizationService: DiarizationService, @unchecked Sendable {
    private let transcriptionService: TranscriptionService
    private let model: TranscriptionModel

    /// Creates a new channel-based diarizer.
    ///
    /// - Parameters:
    ///   - transcriptionService: The transcription engine to use for the
    ///     system-audio channel. Constructor-injected (not hardcoded to
    ///     `WhisperKitTranscriptionService`) so this type stays testable
    ///     against a `TranscriptionService` fake and is not coupled to any
    ///     particular on-device engine.
    ///   - model: Which on-device transcription model to use for the
    ///     system-audio channel. Defaults to `.whisperLargeV3Turbo` to
    ///     match the typical mic-channel default.
    public init(transcriptionService: TranscriptionService, model: TranscriptionModel = .whisperLargeV3Turbo) {
        self.transcriptionService = transcriptionService
        self.model = model
    }

    /// Returns `1` — this implementation distinguishes the local-user
    /// channel from a single "remote" bucket for the system-audio channel.
    /// It does NOT distinguish multiple distinct remote speakers within the
    /// system-audio channel itself (Alice and Bob on the far end are both
    /// "Speaker 2 (Remote)" in this first version). Reporting 1 — not the
    /// 8 the protocol doc comment mentions — is the honest value: callers
    /// building UI that promises "8 distinct remote speakers" would be
    /// misleading users. See `docs/adr/phase-4-diarization-approach.md`
    /// for the full reasoning and what's explicitly deferred.
    public var maxSupportedSpeakers: Int { 1 }

    public func diarize(transcript: Transcript, recording: Recording) async throws -> Transcript {
        // Fast path: no system-audio channel captured → input transcript is
        // already a correct single-speaker (local user) result. Return it
        // unchanged so callers can use this service uniformly regardless of
        // whether the recording captured system audio.
        guard recording.hasSystemAudio, let systemAudioURL = recording.systemAudioFileURL else {
            return transcript
        }

        // Reuse the existing `TranscriptionService.transcribe(...)` against
        // the system-audio file by constructing a synthetic `Recording`
        // whose `microphoneFileURL` points at the system-audio file. This
        // is a legitimate reuse of the single-file-transcription capability
        // defined by the `TranscriptionService` contract ("transcribe
        // whatever audio is at this Recording's microphoneFileURL"), not a
        // hack — and crucially it does NOT require extending the
        // `TranscriptionService` protocol or hardcoding a WhisperKit call
        // here, both of which are explicitly off-limits for this phase.
        let syntheticRecording = Recording(
            id: recording.id,
            title: recording.title,
            createdAt: recording.createdAt,
            duration: recording.duration,
            microphoneFileURL: systemAudioURL
        )

        let systemAudioTranscript: Transcript
        do {
            systemAudioTranscript = try await transcriptionService.transcribe(
                recording: syntheticRecording,
                model: model,
                languageCode: transcript.languageCode
            )
        } catch {
            throw DiarizationError.diarizationFailed(
                reason: "System-audio transcription failed: \(error)"
            )
        }

        // Create the single remote speaker that all system-audio segments
        // will be attributed to. Color and label are hard-coded for this
        // first version — a future phase can expose these via user prefs
        // or per-call overrides without changing the service contract.
        let remoteSpeaker = Speaker(
            label: "Speaker 2 (Remote)",
            colorHex: "#FF9500",
            isLocalUser: false
        )

        // Rebind each system-audio segment to the new remote speaker.
        // Keep text/timing; assign the new speakerID.
        let remoteSegments = systemAudioTranscript.segments.map { segment -> TranscriptSegment in
            TranscriptSegment(
                speakerID: remoteSpeaker.id,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                lowConfidenceWordRanges: segment.lowConfidenceWordRanges
            )
        }

        // Merge original mic segments with the new remote segments and sort
        // by start time so callers can render the transcript as a single
        // chronological timeline. Stable sort preserves insertion order for
        // ties (mic-before-remote on the same startTime, matching the
        // intuitive "local user spoke first" expectation when both channels
        // start at 0).
        let mergedSegments = (transcript.segments + remoteSegments).sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime < rhs.startTime }
            // Tie-breaker: mic-channel segments (speakerID == local user)
            // come before remote segments. This is purely a deterministic
            // ordering choice — without it, sort stability alone depends
            // on the platform's implementation.
            let lhsIsLocal = transcript.speaker(for: lhs)?.isLocalUser ?? false
            let rhsIsLocal = transcript.speaker(for: rhs)?.isLocalUser ?? false
            if lhsIsLocal != rhsIsLocal { return lhsIsLocal && !rhsIsLocal }
            return false
        }

        return Transcript(
            id: UUID(),
            recordingID: transcript.recordingID,
            languageCode: transcript.languageCode,
            modelUsed: transcript.modelUsed,
            speakers: transcript.speakers + [remoteSpeaker],
            segments: mergedSegments,
            generatedAt: Date(),
            recordingStartedAt: transcript.recordingStartedAt
        )
    }
}
