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
/// By default this does NOT do full multi-speaker separation within the
/// system-audio channel (Alice vs. Bob on the far end are both "Speaker 2
/// (Remote)") — see the ADR for the original reasoning and what was
/// deferred. Real voice-based separation is now available by injecting a
/// `SpeakerSeparationService` (e.g. `SpeakerKitSpeakerSeparationService`):
/// when present, distinct remote speakers are split into "Speaker 2
/// (Remote)", "Speaker 3 (Remote)", etc. instead of one shared bucket. It
/// still does NOT depend on WhisperKit's experimental diarization API,
/// keeping the mic-channel transcription surface limited to the stable
/// `TranscriptionService` we already have working end-to-end in Phase 3.
public final class ChannelBasedDiarizationService: DiarizationService, @unchecked Sendable {
    private let transcriptionService: TranscriptionService
    private let model: TranscriptionModel
    private let speakerSeparationService: SpeakerSeparationService?

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
    ///   - speakerSeparationService: Optional voice-based speaker separator
    ///     for the system-audio channel. When `nil` (the default), behavior
    ///     is unchanged from the original implementation — every
    ///     system-audio segment is attributed to one shared "Speaker 2
    ///     (Remote)". When provided, it's used to split system-audio into
    ///     multiple distinct remote speakers.
    public init(
        transcriptionService: TranscriptionService,
        model: TranscriptionModel = .whisperLargeV3Turbo,
        speakerSeparationService: SpeakerSeparationService? = nil
    ) {
        self.transcriptionService = transcriptionService
        self.model = model
        self.speakerSeparationService = speakerSeparationService
    }

    /// `1` when no `speakerSeparationService` is injected — this
    /// implementation then only distinguishes the local-user channel from a
    /// single "remote" bucket, and reporting 1 (not the 8 the protocol doc
    /// comment mentions) is the honest value: callers building UI that
    /// promises "8 distinct remote speakers" would be misleading users. `8`
    /// when a `speakerSeparationService` is injected — real voice-based
    /// separation is then in play, matching the protocol's stated ceiling.
    /// See `docs/adr/phase-4-diarization-approach.md` for the original
    /// reasoning.
    public var maxSupportedSpeakers: Int {
        speakerSeparationService != nil ? 8 : 1
    }

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

        // Attempt real voice-based multi-speaker separation within the
        // system-audio channel. This is a best-effort enhancement over the
        // single-"Speaker 2 (Remote)" baseline: if no SpeakerSeparationService
        // is injected, it fails, or it returns no turns, fall back to the
        // original single-remote-speaker behavior rather than failing the
        // whole diarize() call — a worse remote-speaker labeling is better
        // than no transcript at all.
        var turns: [SpeakerTurn] = []
        if let speakerSeparationService {
            turns = (try? await speakerSeparationService.separateSpeakers(audioFileURL: systemAudioURL)) ?? []
        }

        let (remoteSpeakers, remoteSegments) = Self.makeRemoteSpeakersAndSegments(
            from: systemAudioTranscript.segments,
            turns: turns
        )

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
            speakers: transcript.speakers + remoteSpeakers,
            segments: mergedSegments,
            generatedAt: Date(),
            recordingStartedAt: transcript.recordingStartedAt
        )
    }

    /// Fixed color palette cycled across distinct remote speakers, in order.
    private static let remoteSpeakerColors = [
        "#FF9500", "#AF52DE", "#FF3B30", "#34C759",
        "#5AC8FA", "#FFCC00", "#FF2D55", "#8E8E93",
    ]

    /// Builds the remote `Speaker` list and re-attributed segments for the
    /// system-audio channel.
    ///
    /// - If `turns` is empty (no separation service injected, it failed, or
    ///   it found no distinct turns), returns the original single-"Speaker 2
    ///   (Remote)" behavior: one speaker, every segment attributed to it.
    /// - Otherwise, one `Speaker` is created per distinct `clusterID` present
    ///   in `turns` (ascending clusterID order → "Speaker 2 (Remote)",
    ///   "Speaker 3 (Remote)", ...), and each transcript segment is
    ///   attributed to whichever turn overlaps it most (by time
    ///   intersection). A segment with zero overlap against every turn (a
    ///   gap in the diarization output) is attributed to the turn whose
    ///   midpoint is nearest instead of being dropped or left unattributed.
    private static func makeRemoteSpeakersAndSegments(
        from segments: [TranscriptSegment],
        turns: [SpeakerTurn]
    ) -> (speakers: [Speaker], segments: [TranscriptSegment]) {
        guard !turns.isEmpty else {
            let remoteSpeaker = Speaker(label: "Speaker 2 (Remote)", colorHex: remoteSpeakerColors[0], isLocalUser: false)
            let remoteSegments = segments.map { segment in
                TranscriptSegment(
                    speakerID: remoteSpeaker.id,
                    text: segment.text,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )
            }
            return ([remoteSpeaker], remoteSegments)
        }

        let distinctClusterIDs = Set(turns.map(\.clusterID)).sorted()
        var speakerByClusterID: [Int: Speaker] = [:]
        var speakers: [Speaker] = []
        for (index, clusterID) in distinctClusterIDs.enumerated() {
            let speakerNumber = index + 2 // local user is always "Speaker 1"
            let speaker = Speaker(
                label: "Speaker \(speakerNumber) (Remote)",
                colorHex: remoteSpeakerColors[index % remoteSpeakerColors.count],
                isLocalUser: false
            )
            speakerByClusterID[clusterID] = speaker
            speakers.append(speaker)
        }

        let remoteSegments = segments.map { segment -> TranscriptSegment in
            let clusterID = Self.bestMatchingClusterID(for: segment, turns: turns)
            let speaker = speakerByClusterID[clusterID] ?? speakers[0]
            return TranscriptSegment(
                speakerID: speaker.id,
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        return (speakers, remoteSegments)
    }

    /// The `clusterID` of whichever `turn` overlaps `segment` the most (by
    /// time intersection in seconds). Falls back to the turn whose midpoint
    /// is closest to the segment's midpoint when there is no overlap at all
    /// — deterministic tie-break: lowest `clusterID`, then earliest
    /// `startTime`.
    private static func bestMatchingClusterID(for segment: TranscriptSegment, turns: [SpeakerTurn]) -> Int {
        var bestOverlap: TimeInterval = 0
        var bestTurn: SpeakerTurn?
        for turn in turns {
            let overlap = min(segment.endTime, turn.endTime) - max(segment.startTime, turn.startTime)
            guard overlap > 0 else { continue }
            if bestTurn == nil || overlap > bestOverlap
                || (overlap == bestOverlap && isBetterTieBreak(turn, than: bestTurn!)) {
                bestOverlap = overlap
                bestTurn = turn
            }
        }
        if let bestTurn { return bestTurn.clusterID }

        // No overlapping turn — nearest by midpoint distance.
        let segmentMid = (segment.startTime + segment.endTime) / 2
        var nearestTurn: SpeakerTurn?
        var nearestDistance = TimeInterval.greatestFiniteMagnitude
        for turn in turns {
            let turnMid = (turn.startTime + turn.endTime) / 2
            let distance = abs(segmentMid - turnMid)
            if nearestTurn == nil || distance < nearestDistance
                || (distance == nearestDistance && isBetterTieBreak(turn, than: nearestTurn!)) {
                nearestDistance = distance
                nearestTurn = turn
            }
        }
        return nearestTurn?.clusterID ?? turns[0].clusterID
    }

    private static func isBetterTieBreak(_ candidate: SpeakerTurn, than current: SpeakerTurn) -> Bool {
        if candidate.clusterID != current.clusterID { return candidate.clusterID < current.clusterID }
        return candidate.startTime < current.startTime
    }
}
