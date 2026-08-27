import Testing
@testable import InnerEarCore

// @unit — pure orchestration logic against fakes; no real audio/Core ML/filesystem I/O.
//
// Swift Testing (not XCTest): XCTest.framework is bundled only with full Xcode, not
// Command Line Tools, so `swift test` fails with "no such module 'XCTest'" on a
// CLT-only machine. Swift Testing ships with the open-source Swift toolchain itself
// and works without Xcode — see MAC_VERIFY_RESULTS.md for the failure that prompted this.
@MainActor
struct RecordingViewModelTests {

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

    @Test
    func startRecording_whenSucceeds_updatesCaptureStateToRecording() async {
        let (vm, capture, _, _, _) = makeViewModel()

        await vm.startRecording(captureSystemAudio: true)

        #expect(capture.startCaptureCalls == [true])
        if case .recording = vm.captureState {
            // expected
        } else {
            Issue.record("Expected .recording state, got \(vm.captureState)")
        }
        #expect(vm.errorMessage == nil)
    }

    @Test
    func startRecording_whenPermissionDenied_setsErrorMessageAndLeavesStateIdle() async {
        let capture = FakeAudioCaptureService()
        capture.startCaptureError = AudioCaptureError.microphonePermissionDenied
        let (vm, _, _, _, _) = makeViewModel(audioCapture: capture)

        await vm.startRecording(captureSystemAudio: false)

        #expect(vm.errorMessage != nil)
        #expect(vm.captureState == .idle)
    }

    @Test
    func stopRecordingAndProcess_runsFullPipeline_andPublishesFinalSummary() async {
        let (vm, _, transcription, _, summarization) = makeViewModel()

        await vm.startRecording(captureSystemAudio: false)
        await vm.stopRecordingAndProcess(model: .parakeet)

        #expect(transcription.transcribeCallCount == 1)
        #expect(vm.transcript != nil)
        #expect(vm.summary?.overview == summarization.stubbedSummary.overview)
        #expect(vm.errorMessage == nil)
    }

    @Test
    func stopRecordingAndProcess_whenTranscriptionFails_setsErrorAndDoesNotProduceSummary() async {
        let transcription = FakeTranscriptionService(stubbedTranscript: TestFixtures.transcript())
        transcription.transcribeError = TranscriptionError.transcriptionFailed(reason: "boom")
        let (vm, _, _, _, _) = makeViewModel(transcription: transcription)

        await vm.startRecording(captureSystemAudio: false)
        await vm.stopRecordingAndProcess(model: .whisperLargeV3Turbo)

        #expect(vm.errorMessage != nil)
        #expect(vm.summary == nil)
    }
}
