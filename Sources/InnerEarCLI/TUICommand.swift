import ArgumentParser
import Foundation
import InnerEarCore
import InnerEarTUIKit

/// `innerear tui` — Interactive terminal dashboard for recording,
/// transcribing, diarizing, summarizing, and exporting.
struct TUICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tui",
        abstract: "Interactive terminal dashboard"
    )

    func run() async throws {
        // Instantiate all real services
        let audioCapture = try AVFoundationAudioCaptureService()
        let transcription = WhisperKitTranscriptionService()
        let speakerSeparation = SpeakerKitSpeakerSeparationService()
        let diarization = ChannelBasedDiarizationService(
            transcriptionService: transcription,
            speakerSeparationService: speakerSeparation
        )
        let summarization = ExtractiveSummarizationService()
        let export = FileExportService()
        let store = try RecordingStore()

        // Hand off to the run loop
        try await TUIRunLoop.run(
            audioCapture: audioCapture,
            transcription: transcription,
            diarization: diarization,
            summarization: summarization,
            export: export,
            store: store
        )
    }
}