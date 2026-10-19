import Foundation
import Testing
@testable import InnerEarRecording
@testable import InnerEarTranscription

/// Tests for `BackgroundTranscriptionCoordinator` — all fake-backed per
/// TEST_DOCTRINE.md AX-P2 (no real WhisperKit/Core ML). Exercises the
/// non-blocking contract directly: `enqueue` must return before the
/// pipeline finishes, and `drainCompleted()`/`drainFailed()` must report
/// results once they do.
struct BackgroundTranscriptionCoordinatorTests {

    private func makeRecording() -> Recording {
        Recording(
            title: "Test",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 10,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/fake-mic.caf")
        )
    }

    @Test
    func enqueue_returnsImmediately_doesNotBlockOnPipeline() async throws {
        let recording = makeRecording()
        let transcription = FakeTranscriptionService(stubbedTranscript: TestFixtures.transcript())
        // A slow-but-finite delay proves `enqueue` itself doesn't await the
        // pipeline — if it did, this test would take >= the delay to
        // return from `enqueue`, which the deadline below would catch.
        transcription.artificialDelay = .milliseconds(200)
        let diarization = FakeDiarizationService()
        let summarization = FakeSummarizationService(stubbedSummary: TestFixtures.summary(transcriptID: UUID()))

        let coordinator = BackgroundTranscriptionCoordinator(
            transcriptionService: transcription,
            diarizationService: diarization,
            summarizationService: summarization
        )

        let start = ContinuousClock.now
        await coordinator.enqueue(recording)
        let elapsed = start.duration(to: .now)

        #expect(elapsed < .milliseconds(100))
    }

    @Test
    func enqueue_onSuccess_reportsViaDrainCompleted() async throws {
        let recording = makeRecording()
        let expectedTranscript = TestFixtures.transcript()
        let expectedSummary = TestFixtures.summary(transcriptID: expectedTranscript.id)
        let transcription = FakeTranscriptionService(stubbedTranscript: expectedTranscript)
        let diarization = FakeDiarizationService()
        let summarization = FakeSummarizationService(stubbedSummary: expectedSummary)

        let coordinator = BackgroundTranscriptionCoordinator(
            transcriptionService: transcription,
            diarizationService: diarization,
            summarizationService: summarization
        )

        await coordinator.enqueue(recording)
        let results = await waitForCompletion(coordinator)

        #expect(results.count == 1)
        #expect(results.first?.recording.id == recording.id)
        #expect(results.first?.summary.id == expectedSummary.id)
        #expect(await coordinator.drainCompleted().isEmpty) // drained, not re-reported
    }

    @Test
    func enqueue_onFailure_reportsViaDrainFailed_notDrainCompleted() async throws {
        let recording = makeRecording()
        let transcription = FakeTranscriptionService(stubbedTranscript: TestFixtures.transcript())
        transcription.transcribeError = TranscriptionError.audioFileUnreadable
        let diarization = FakeDiarizationService()
        let summarization = FakeSummarizationService(stubbedSummary: TestFixtures.summary(transcriptID: UUID()))

        let coordinator = BackgroundTranscriptionCoordinator(
            transcriptionService: transcription,
            diarizationService: diarization,
            summarizationService: summarization
        )

        await coordinator.enqueue(recording)
        let failures = await waitForFailure(coordinator)

        #expect(failures.count == 1)
        #expect(failures.first?.recording.id == recording.id)
        #expect(await coordinator.drainCompleted().isEmpty)
    }

    @Test
    func enqueue_sameRecordingTwiceBeforeCompletion_onlyRunsOnce() async throws {
        let recording = makeRecording()
        let transcription = FakeTranscriptionService(stubbedTranscript: TestFixtures.transcript())
        transcription.artificialDelay = .milliseconds(100)
        let diarization = FakeDiarizationService()
        let summarization = FakeSummarizationService(stubbedSummary: TestFixtures.summary(transcriptID: UUID()))

        let coordinator = BackgroundTranscriptionCoordinator(
            transcriptionService: transcription,
            diarizationService: diarization,
            summarizationService: summarization
        )

        await coordinator.enqueue(recording)
        await coordinator.enqueue(recording) // should be a no-op — still running
        let results = await waitForCompletion(coordinator)

        #expect(results.count == 1)
        #expect(transcription.transcribeCallCount == 1)
    }

    // MARK: - Polling helper

    /// Polls `drainCompleted()` until it has something or a timeout is hit
    /// — the coordinator's whole point is async background work, so tests
    /// can't just synchronously await a result the way they would a direct
    /// service call.
    private func waitForCompletion(
        _ coordinator: BackgroundTranscriptionCoordinator,
        timeout: Duration = .seconds(2)
    ) async -> [BackgroundTranscriptionCoordinator.CompletedPipeline] {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let results = await coordinator.drainCompleted()
            if !results.isEmpty { return results }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return []
    }

    private func waitForFailure(
        _ coordinator: BackgroundTranscriptionCoordinator,
        timeout: Duration = .seconds(2)
    ) async -> [BackgroundTranscriptionCoordinator.FailedPipeline] {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            let results = await coordinator.drainFailed()
            if !results.isEmpty { return results }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return []
    }
}
