import Foundation
@testable import InnerEarCore

// Shared test doubles for all InnerEarCoreTests targets — see TEST_DOCTRINE.md AX-P5.
// None of these touch real audio hardware, Core ML, the network, or the filesystem.

final class FakeAudioCaptureService: AudioCaptureService, @unchecked Sendable {
    var startCaptureCalls: [Bool] = []
    var stubbedState: CaptureState = .idle
    var stubbedRecording = Recording(
        title: "Fake Recording",
        createdAt: Date(timeIntervalSince1970: 0),
        duration: 12,
        microphoneFileURL: URL(fileURLWithPath: "/tmp/fake-mic.caf")
    )
    var startCaptureError: Error?
    var stopCaptureError: Error?

    func startCapture(captureSystemAudio: Bool) async throws {
        startCaptureCalls.append(captureSystemAudio)
        if let startCaptureError { throw startCaptureError }
        stubbedState = .recording(elapsed: 0)
    }

    func stopCapture() async throws -> Recording {
        if let stopCaptureError { throw stopCaptureError }
        stubbedState = .idle
        return stubbedRecording
    }

    var state: CaptureState {
        get async { stubbedState }
    }
}

final class FakeTranscriptionService: TranscriptionService, @unchecked Sendable {
    var stubbedTranscript: Transcript
    var transcribeError: Error?
    var transcribeCallCount = 0

    init(stubbedTranscript: Transcript) {
        self.stubbedTranscript = stubbedTranscript
    }

    func transcribe(
        recording: Recording,
        model: TranscriptionModel,
        languageCode: String?,
        progressHandler: (@Sendable (Int) -> Void)?
    ) async throws -> Transcript {
        transcribeCallCount += 1
        if let transcribeError { throw transcribeError }
        return stubbedTranscript
    }

    func retranscribe(recording: Recording, model: TranscriptionModel, preserveSpeakers: Bool) async throws -> Transcript {
        stubbedTranscript
    }
}

final class FakeDiarizationService: DiarizationService, @unchecked Sendable {
    let maxSupportedSpeakers = 8
    var diarizeResult: (Transcript) -> Transcript = { $0 }
    var diarizeError: Error?

    func diarize(transcript: Transcript, recording: Recording) async throws -> Transcript {
        if let diarizeError { throw diarizeError }
        return diarizeResult(transcript)
    }
}

final class FakeSpeakerSeparationService: SpeakerSeparationService, @unchecked Sendable {
    var separateResult: [SpeakerTurn] = []
    var separateError: Error?

    func separateSpeakers(audioFileURL: URL) async throws -> [SpeakerTurn] {
        if let separateError { throw separateError }
        return separateResult
    }
}

final class FakeSummarizationService: SummarizationService, @unchecked Sendable {
    let backend: SummarizationBackend = .local(modelName: "fake-model")
    var stubbedSummary: Summary
    var summarizeError: Error?
    var chatResponse = "fake chat response"

    init(stubbedSummary: Summary) {
        self.stubbedSummary = stubbedSummary
    }

    func summarize(transcript: Transcript) async throws -> Summary {
        if let summarizeError { throw summarizeError }
        return stubbedSummary
    }

    func chat(transcript: Transcript, question: String) async throws -> String {
        chatResponse
    }
}

final class FakeExportService: ExportService, @unchecked Sendable {
    var lastExportedFormat: ExportFormat?
    var exportError: Error?

    func export(transcript: Transcript, summary: Summary?, format: ExportFormat, to destinationURL: URL) async throws -> URL {
        lastExportedFormat = format
        if let exportError { throw exportError }
        return destinationURL
    }
}

enum TestFixtures {
    static func speaker(label: String = "Speaker 1", isLocalUser: Bool = true) -> Speaker {
        Speaker(label: label, colorHex: "#3366FF", isLocalUser: isLocalUser)
    }

    static func transcript(speakers: [Speaker] = [speaker()]) -> Transcript {
        Transcript(
            recordingID: UUID(),
            languageCode: "en",
            modelUsed: TranscriptionModel.whisperLargeV3Turbo.rawValue,
            speakers: speakers,
            segments: [
                TranscriptSegment(speakerID: speakers.first?.id, text: "Hello world", startTime: 0, endTime: 1.2)
            ],
            generatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    static func summary(transcriptID: UUID) -> Summary {
        Summary(
            transcriptID: transcriptID,
            overview: "A short meeting.",
            keyPoints: ["Point one"],
            decisions: [],
            actionItems: [],
            generatedByModel: "fake-model",
            generatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
