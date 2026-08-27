import XCTest
@testable import ScribeCore

// @service — exercises each service protocol directly (not through the ViewModel/UI),
// per TEST_DOCTRINE.md AX-P4. These use fakes now; once real WhisperKit/Core ML-backed
// implementations land, the same test shapes apply against the concrete types.
final class ServiceContractTests: XCTestCase {

    func test_audioCaptureService_stopCapture_returnsRecordingWithMicrophoneURL() async throws {
        let service = FakeAudioCaptureService()

        try await service.startCapture(captureSystemAudio: false)
        let recording = try await service.stopCapture()

        XCTAssertEqual(recording.microphoneFileURL, service.stubbedRecording.microphoneFileURL)
        XCTAssertFalse(recording.hasSystemAudio)
    }

    func test_transcriptionService_transcribe_returnsSegmentsForRecording() async throws {
        let expected = TestFixtures.transcript()
        let service = FakeTranscriptionService(stubbedTranscript: expected)
        let recording = Recording(
            title: "r",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 1,
            microphoneFileURL: URL(fileURLWithPath: "/tmp/r.caf")
        )

        let result = try await service.transcribe(recording: recording, model: .whisperLargeV3Turbo, languageCode: "en")

        XCTAssertEqual(result.id, expected.id)
        XCTAssertFalse(result.segments.isEmpty)
    }

    func test_diarizationService_diarize_assignsSpeakerToEverySegment() async throws {
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

        XCTAssertTrue(transcript.segments.allSatisfy { $0.speakerID != nil })
    }

    func test_summarizationService_summarize_returnsSummaryLinkedToTranscript() async throws {
        let transcript = TestFixtures.transcript()
        let service = FakeSummarizationService(stubbedSummary: TestFixtures.summary(transcriptID: transcript.id))

        let summary = try await service.summarize(transcript: transcript)

        XCTAssertEqual(summary.transcriptID, transcript.id)
        XCTAssertFalse(summary.overview.isEmpty)
    }

    func test_exportService_export_writesRequestedFormatToDestination() async throws {
        let service = FakeExportService()
        let transcript = TestFixtures.transcript()
        let destination = URL(fileURLWithPath: "/tmp/export.md")

        let resultURL = try await service.export(transcript: transcript, summary: nil, format: .markdown, to: destination)

        XCTAssertEqual(resultURL, destination)
        XCTAssertEqual(service.lastExportedFormat, .markdown)
    }
}
