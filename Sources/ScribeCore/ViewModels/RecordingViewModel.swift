import Foundation
import Observation

/// Orchestrates a single record → transcribe → diarize → summarize run for
/// the SwiftUI layer. Depends only on protocols so it can be unit tested
/// with fakes — see Tests/ScribeCoreTests/unit/RecordingViewModelTests.swift.
@Observable
@MainActor
public final class RecordingViewModel {
    public private(set) var captureState: CaptureState = .idle
    public private(set) var transcript: Transcript?
    public private(set) var summary: Summary?
    public private(set) var errorMessage: String?

    private let audioCapture: AudioCaptureService
    private let transcription: TranscriptionService
    private let diarization: DiarizationService
    private let summarization: SummarizationService

    public init(
        audioCapture: AudioCaptureService,
        transcription: TranscriptionService,
        diarization: DiarizationService,
        summarization: SummarizationService
    ) {
        self.audioCapture = audioCapture
        self.transcription = transcription
        self.diarization = diarization
        self.summarization = summarization
    }

    public func startRecording(captureSystemAudio: Bool) async {
        errorMessage = nil
        do {
            try await audioCapture.startCapture(captureSystemAudio: captureSystemAudio)
            captureState = await audioCapture.state
        } catch {
            errorMessage = "\(error)"
        }
    }

    /// Stops capture, then runs transcription, diarization, and
    /// summarization in sequence, publishing state as each stage completes.
    public func stopRecordingAndProcess(model: TranscriptionModel) async {
        do {
            let recording = try await audioCapture.stopCapture()
            captureState = .idle

            var result = try await transcription.transcribe(
                recording: recording,
                model: model,
                languageCode: nil
            )
            transcript = result

            result = try await diarization.diarize(transcript: result, recording: recording)
            transcript = result

            summary = try await summarization.summarize(transcript: result)
        } catch {
            errorMessage = "\(error)"
        }
    }
}
