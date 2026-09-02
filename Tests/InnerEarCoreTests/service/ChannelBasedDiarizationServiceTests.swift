import Foundation
import Testing
@testable import InnerEarCore

/// Tests for the concrete `ChannelBasedDiarizationService` implementation
/// (Phase 4 — see `docs/adr/phase-4-diarization-approach.md`).
///
/// Uses Swift Testing (`@Test` / `#expect`) per TEST_DOCTRINE.md and the
/// pattern established in `ServiceContractTests.swift`. No real audio
/// hardware, no Core ML, no network — all dependencies are fakes.
struct ChannelBasedDiarizationServiceTests {

    // MARK: - Helpers

    /// Build a single-speaker (local user) mic transcript with two
    /// segments so the merge-vs-no-merge assertion is meaningful.
    private func makeLocalTranscript() -> Transcript {
        let local = TestFixtures.speaker(label: "Speaker 1", isLocalUser: true)
        return Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [local],
            segments: [
                TranscriptSegment(speakerID: local.id, text: "Hello, can you hear me?", startTime: 0.0, endTime: 1.5),
                TranscriptSegment(speakerID: local.id, text: "I have a question.", startTime: 3.0, endTime: 4.2),
            ],
            generatedAt: Date(timeIntervalSince1970: 1_000_000),
            recordingStartedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    /// System-audio stub transcript (what `FakeTranscriptionService` will
    /// return when the diarization service makes its second call). Has a
    /// distinct speaker and distinct text so the merge assertion is
    /// unambiguous.
    private func makeSystemAudioStub() -> Transcript {
        let remoteStub = TestFixtures.speaker(label: "Far End Original", isLocalUser: false)
        return Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [remoteStub],
            segments: [
                TranscriptSegment(speakerID: remoteStub.id, text: "Yes, I can hear you.", startTime: 1.6, endTime: 2.9),
            ],
            generatedAt: Date(timeIntervalSince1970: 1_000_000),
            recordingStartedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    // MARK: - Tests

    @Test
    func maxSupportedSpeakers_isOne() {
        let service = ChannelBasedDiarizationService(
            transcriptionService: FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub())
        )

        #expect(service.maxSupportedSpeakers == 1)
    }

    @Test
    func diarize_withoutSystemAudio_returnsInputTranscriptUnchanged() async throws {
        // The transcription service is never called in the no-system-audio
        // fast path, but we still inject one so the type system is happy.
        let service = ChannelBasedDiarizationService(
            transcriptionService: FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub())
        )
        let original = makeLocalTranscript()
        let recordingNoSys = Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 5,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/mic.caf")
            // systemAudioFileURL: nil (default) → hasSystemAudio == false
        )

        let result = try await service.diarize(transcript: original, recording: recordingNoSys)

        // Same segments, same speakers, same generatedAt — fast path must
        // be identity for the no-system-audio case.
        #expect(result.segments == original.segments)
        #expect(result.speakers == original.speakers)
        #expect(result.languageCode == original.languageCode)
        #expect(result.recordingID == original.recordingID)
    }

    @Test
    func diarize_withSystemAudio_transcribesSystemChannel_mergesSegments_sortedByStartTime() async throws {
        let fake = FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub())
        let service = ChannelBasedDiarizationService(transcriptionService: fake)
        let original = makeLocalTranscript()
        let recordingWithSys = Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 5,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/mic.caf"),
            systemAudioFileURL: URL(fileURLWithPath: "/tmp/sys.caf")
        )

        let merged = try await service.diarize(transcript: original, recording: recordingWithSys)

        // The second transcribe call (for system audio) must have actually
        // happened exactly once.
        #expect(fake.transcribeCallCount == 1)

        // speakers: original local speaker + new "Speaker 2 (Remote)" = 2.
        #expect(merged.speakers.count == 2)
        let local = merged.speakers.first { $0.isLocalUser }
        let remote = merged.speakers.first { !$0.isLocalUser }
        #expect(local != nil)
        #expect(remote != nil)
        #expect(remote?.label == "Speaker 2 (Remote)")
        #expect(remote?.colorHex == "#FF9500")
        #expect(remote?.isLocalUser == false)

        // 2 mic segments + 1 system-audio segment = 3 merged segments.
        #expect(merged.segments.count == original.segments.count + 1)

        // Sorted by startTime ascending.
        let startTimes = merged.segments.map(\.startTime)
        #expect(startTimes == startTimes.sorted())

        // The system-audio stub text must appear in the merged output,
        // and it must be attributed to the new remote speaker (not the
        // stub's original speaker — that one must not have leaked in).
        let remoteSegments = merged.segments.filter { $0.speakerID == remote?.id }
        #expect(remoteSegments.count == 1)
        #expect(remoteSegments.first?.text == "Yes, I can hear you.")
        #expect(merged.segments.allSatisfy { $0.speakerID != nil })

        // The original local user's segments should be untouched and
        // still attributed to the local speaker.
        let localSegments = merged.segments.filter { $0.speakerID == local?.id }
        #expect(localSegments.count == original.segments.count)
        #expect(localSegments.map(\.text) == original.segments.map(\.text))

        // Other metadata propagated correctly.
        #expect(merged.recordingID == original.recordingID)
        #expect(merged.languageCode == original.languageCode)
        #expect(merged.modelUsed == original.modelUsed)
    }

    // MARK: - recordingStartedAt preservation

    @Test
    func diarize_withoutSystemAudio_preservesRecordingStartedAt() async throws {
        // The no-system-audio path returns the input transcript unchanged,
        // so the `recordingStartedAt` it carries must come back identically.
        let service = ChannelBasedDiarizationService(
            transcriptionService: FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub())
        )
        let original = makeLocalTranscript()
        let recordingNoSys = Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 5,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/mic.caf")
        )

        let result = try await service.diarize(transcript: original, recording: recordingNoSys)

        #expect(result.recordingStartedAt == original.recordingStartedAt)
    }

    // MARK: - SpeakerSeparationService composition

    /// Two-segment system-audio stub (distinct from `makeSystemAudioStub()`,
    /// which only has one segment) — needed so the multi-speaker tests below
    /// have two segments that can be attributed to two different clusters.
    private func makeTwoSegmentSystemAudioStub() -> Transcript {
        let remoteStub = TestFixtures.speaker(label: "Far End Original", isLocalUser: false)
        return Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: [remoteStub],
            segments: [
                TranscriptSegment(speakerID: remoteStub.id, text: "Speaker A text", startTime: 1.0, endTime: 2.0),
                TranscriptSegment(speakerID: remoteStub.id, text: "Speaker B text", startTime: 5.0, endTime: 6.0),
            ],
            generatedAt: Date(timeIntervalSince1970: 1_000_000),
            recordingStartedAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    private func makeRecordingWithSystemAudio() -> Recording {
        Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 8,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/mic.caf"),
            systemAudioFileURL: URL(fileURLWithPath: "/tmp/sys.caf")
        )
    }

    @Test
    func maxSupportedSpeakers_withSpeakerSeparationService_isEight() {
        let service = ChannelBasedDiarizationService(
            transcriptionService: FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub()),
            speakerSeparationService: FakeSpeakerSeparationService()
        )

        #expect(service.maxSupportedSpeakers == 8)
    }

    @Test
    func diarize_withSpeakerSeparationService_splitsIntoMultipleDistinctRemoteSpeakers() async throws {
        let transcriptionFake = FakeTranscriptionService(stubbedTranscript: makeTwoSegmentSystemAudioStub())
        let separationFake = FakeSpeakerSeparationService()
        separationFake.separateResult = [
            SpeakerTurn(clusterID: 0, startTime: 0.5, endTime: 2.5),
            SpeakerTurn(clusterID: 1, startTime: 4.5, endTime: 6.5),
        ]
        let service = ChannelBasedDiarizationService(
            transcriptionService: transcriptionFake,
            speakerSeparationService: separationFake
        )
        let original = makeLocalTranscript()

        let merged = try await service.diarize(transcript: original, recording: makeRecordingWithSystemAudio())

        // 1 local + 2 distinct remote speakers = 3 total.
        #expect(merged.speakers.count == 3)
        let speaker2 = merged.speakers.first { $0.label == "Speaker 2 (Remote)" }
        let speaker3 = merged.speakers.first { $0.label == "Speaker 3 (Remote)" }
        #expect(speaker2 != nil)
        #expect(speaker3 != nil)

        // clusterID 0 (0.5-2.5) overlaps segment A (1.0-2.0) -> Speaker 2.
        // clusterID 1 (4.5-6.5) overlaps segment B (5.0-6.0) -> Speaker 3.
        let segmentA = merged.segments.first { $0.text == "Speaker A text" }
        let segmentB = merged.segments.first { $0.text == "Speaker B text" }
        #expect(segmentA?.speakerID == speaker2?.id)
        #expect(segmentB?.speakerID == speaker3?.id)
    }

    @Test
    func diarize_whenSpeakerSeparationServiceReturnsNoTurns_fallsBackToSingleRemoteSpeaker() async throws {
        let separationFake = FakeSpeakerSeparationService() // separateResult defaults to []
        let service = ChannelBasedDiarizationService(
            transcriptionService: FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub()),
            speakerSeparationService: separationFake
        )
        let original = makeLocalTranscript()

        let merged = try await service.diarize(transcript: original, recording: makeRecordingWithSystemAudio())

        #expect(merged.speakers.count == 2)
        let remote = merged.speakers.first { !$0.isLocalUser }
        #expect(remote?.label == "Speaker 2 (Remote)")
    }

    @Test
    func diarize_whenSpeakerSeparationServiceThrows_fallsBackToSingleRemoteSpeaker() async throws {
        let separationFake = FakeSpeakerSeparationService()
        separationFake.separateError = SpeakerSeparationError.separationFailed(reason: "fake failure")
        let service = ChannelBasedDiarizationService(
            transcriptionService: FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub()),
            speakerSeparationService: separationFake
        )
        let original = makeLocalTranscript()

        // Must NOT throw — separation failures degrade gracefully rather
        // than failing the whole diarize() call.
        let merged = try await service.diarize(transcript: original, recording: makeRecordingWithSystemAudio())

        #expect(merged.speakers.count == 2)
        let remote = merged.speakers.first { !$0.isLocalUser }
        #expect(remote?.label == "Speaker 2 (Remote)")
    }

    @Test
    func diarize_segmentWithNoOverlappingTurn_attributedToNearestTurnByMidpoint() async throws {
        // Only one SpeakerTurn (clusterID 5, 0.0-1.5) — segment B (5.0-6.0)
        // has zero overlap with it. Must still be attributed to the single
        // remote speaker that exists, not dropped or left unattributed.
        let transcriptionFake = FakeTranscriptionService(stubbedTranscript: makeTwoSegmentSystemAudioStub())
        let separationFake = FakeSpeakerSeparationService()
        separationFake.separateResult = [
            SpeakerTurn(clusterID: 5, startTime: 0.0, endTime: 1.5),
        ]
        let service = ChannelBasedDiarizationService(
            transcriptionService: transcriptionFake,
            speakerSeparationService: separationFake
        )
        let original = makeLocalTranscript()

        let merged = try await service.diarize(transcript: original, recording: makeRecordingWithSystemAudio())

        // Only one clusterID present -> exactly one remote speaker.
        let remoteSpeakers = merged.speakers.filter { !$0.isLocalUser }
        #expect(remoteSpeakers.count == 1)

        let segmentA = merged.segments.first { $0.text == "Speaker A text" }
        let segmentB = merged.segments.first { $0.text == "Speaker B text" }
        #expect(segmentA?.speakerID == remoteSpeakers.first?.id)
        #expect(segmentB?.speakerID == remoteSpeakers.first?.id)
    }

    @Test
    func diarize_withSystemAudio_preservesRecordingStartedAt() async throws {
        // On the merge path, the service constructs a brand-new Transcript
        // and must explicitly forward `recordingStartedAt` from the input —
        // a re-default to `Date()` would lose the original recording start
        // time and silently corrupt downstream exports.
        let service = ChannelBasedDiarizationService(
            transcriptionService: FakeTranscriptionService(stubbedTranscript: makeSystemAudioStub())
        )
        let original = makeLocalTranscript()
        let recordingWithSys = Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 5,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/mic.caf"),
            systemAudioFileURL: URL(fileURLWithPath: "/tmp/sys.caf")
        )

        let merged = try await service.diarize(transcript: original, recording: recordingWithSys)

        #expect(merged.recordingStartedAt == original.recordingStartedAt)
    }
}
