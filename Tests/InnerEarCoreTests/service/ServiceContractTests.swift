import Testing
@testable import InnerEarCore

// @service — exercises each service protocol directly (not through the ViewModel/UI),
// per TEST_DOCTRINE.md AX-P4. These use fakes now; once real WhisperKit/Core ML-backed
// implementations land, the same test shapes apply against the concrete types.
//
// Swift Testing, not XCTest — see RecordingViewModelTests.swift for why.
struct ServiceContractTests {

    @Test
    func audioCaptureService_stopCapture_returnsRecordingWithMicrophoneURL() async throws {
        let service = FakeAudioCaptureService()

        try await service.startCapture(captureSystemAudio: false)
        let recording = try await service.stopCapture()

        #expect(recording.microphoneFileURL == service.stubbedRecording.microphoneFileURL)
        #expect(!recording.hasSystemAudio)
    }

    @Test
    func transcriptionService_transcribe_returnsSegmentsForRecording() async throws {
        let expected = TestFixtures.transcript()
        let service = FakeTranscriptionService(stubbedTranscript: expected)
        let recording = Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 1,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/r.caf")
        )

        let result = try await service.transcribe(recording: recording, model: .whisperLargeV3Turbo, languageCode: "en")

        #expect(result.id == expected.id)
        #expect(!result.segments.isEmpty)
    }

    @Test
    func diarizationService_diarize_assignsSpeakerToEverySegment() async throws {
        let namedSpeaker = TestFixtures.speaker(label: "Speaker 1")
        var transcript = TestFixtures.transcript(speakers: [namedSpeaker])
        let service = FakeDiarizationService()
        service.diarizeResult = { $0 } // identity — already has speakerIDs assigned in fixture
        let recording = Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 1,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/r.caf")
        )

        transcript = try await service.diarize(transcript: transcript, recording: recording)

        #expect(transcript.segments.allSatisfy { $0.speakerID != nil })
    }

    @Test
    func summarizationService_summarize_returnsSummaryLinkedToTranscript() async throws {
        let transcript = TestFixtures.transcript()
        let service = FakeSummarizationService(stubbedSummary: TestFixtures.summary(transcriptID: transcript.id))

        let summary = try await service.summarize(transcript: transcript)

        #expect(summary.transcriptID == transcript.id)
        #expect(!summary.overview.isEmpty)
    }

    @Test
    func exportService_export_writesRequestedFormatToDestination() async throws {
        let service = FakeExportService()
        let transcript = TestFixtures.transcript()
        let destination = URL(fileURLWithPath: "/tmp/export.md")

        let resultURL = try await service.export(transcript: transcript, summary: nil, format: .markdown, to: destination)

        #expect(resultURL == destination)
        #expect(service.lastExportedFormat == .markdown)
    }
}
