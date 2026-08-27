import XCTest
@testable import ScribeCore

// @unit — pure orchestration logic against fakes; no real audio/Core ML/filesystem I/O.
@MainActor
final class RecordingViewModelTests: XCTestCase {

    private func makeViewModel(
        audioCapture: FakeAudioCaptureService = FakeAudioCaptureService(),
        transcription: FakeTranscriptionService? = nil,
        diarization: FakeDiarizationService = FakeDiarizationService(),
        summarization: FakeSummarizationService? = nil
    ) -> (RecordingViewModel, FakeAudioCaptureService, FakeTranscriptionService, FakeDiarizationService, FakeSummarizationService) {
        let baseTranscript = TestFixtures.transcript()
        let transcription = transcription ?? FakeTranscriptionService(stubbedTranscript: baseTranscript)
        let summarization = summarization ?? FakeSummarizationService(stubbedSummary: TestFixtures.summary(transcriptID: baseTranscript.id))
        let vm = RecordingViewModel(
            audioCapture: audioCapture,
            transcription: transcription,
            diarization: diarization,
            summarization: summarization
        )
        return (vm, audioCapture, transcription, diarization, summarization)
    }

    func test_startRecording_whenSucceeds_updatesCaptureStateToRecording() async {
        let (vm, capture, _, _, _) = makeViewModel()

        await vm.startRecording(captureSystemAudio: true)

        XCTAssertEqual(capture.startCaptureCalls, [true])
        if case .recording = vm.captureState {
            // expected
        } else {
            XCTFail("Expected .recording state, got \(vm.captureState)")
        }
        XCTAssertNil(vm.errorMessage)
    }

    func test_startRecording_whenPermissionDenied_setsErrorMessageAndLeavesStateIdle() async {
        let capture = FakeAudioCaptureService()
        capture.startCaptureError = AudioCaptureError.microphonePermissionDenied
        let (vm, _, _, _, _) = makeViewModel(audioCapture: capture)

        await vm.startRecording(captureSystemAudio: false)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.captureState, .idle)
    }

    func test_stopRecordingAndProcess_runsFullPipeline_andPublishesFinalSummary() async {
        let (vm, _, transcription, _, summarization) = makeViewModel()

        await vm.startRecording(captureSystemAudio: false)
        await vm.stopRecordingAndProcess(model: .parakeet)

        XCTAssertEqual(transcription.transcribeCallCount, 1)
        XCTAssertNotNil(vm.transcript)
        XCTAssertEqual(vm.summary?.overview, summarization.stubbedSummary.overview)
        XCTAssertNil(vm.errorMessage)
    }

    func test_stopRecordingAndProcess_whenTranscriptionFails_setsErrorAndDoesNotProduceSummary() async {
        let transcription = FakeTranscriptionService(stubbedTranscript: TestFixtures.transcript())
        transcription.transcribeError = TranscriptionError.transcriptionFailed(reason: "boom")
        let (vm, _, _, _, _) = makeViewModel(transcription: transcription)

        await vm.startRecording(captureSystemAudio: false)
        await vm.stopRecordingAndProcess(model: .whisperLargeV3Turbo)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.summary)
    }
}
