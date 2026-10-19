import ArgumentParser
import Foundation
import InnerEarCore
import InnerEarMetadata
import InnerEarRecording
import InnerEarTranscription
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
        // Shares the same transcription/diarization/summarization service
        // instances as the manual pipeline above — not separate ones —
        // so a model WhisperKit already loaded for a manual transcribe
        // isn't redundantly reloaded for an automatic one, or vice versa.
        let backgroundTranscription = BackgroundTranscriptionCoordinator(
            transcriptionService: transcription,
            diarizationService: diarization,
            summarizationService: summarization
        )
        let calendarMetadata = EventKitCalendarMetadataService()
        let windowMetadata = CGWindowListWindowMetadataService()
        let recordingStore = try RecordingStore()
        let transcriptStore = try TranscriptStore()
        let metadataStore = try MetadataStore()

        // Hand off to the run loop
        try await TUIRunLoop.run(
            audioCapture: audioCapture,
            transcription: transcription,
            diarization: diarization,
            summarization: summarization,
            export: export,
            backgroundTranscription: backgroundTranscription,
            calendarMetadata: calendarMetadata,
            windowMetadata: windowMetadata,
            recordingStore: recordingStore,
            transcriptStore: transcriptStore,
            metadataStore: metadataStore
        )
    }
}
