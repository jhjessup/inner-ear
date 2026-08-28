import Foundation
import InnerEarCore

public enum TUIEffect: Equatable, Sendable {
    case startRecording(captureSystemAudio: Bool)
    case stopRecording
    case loadRecordings
    case runPipeline(Recording)
    case exportResult(transcript: Transcript, summary: Summary?, format: ExportFormat)
    case loadConfigStatus
    case saveDataDirectory(String)
    case deleteAudio(Recording)
    case deleteTranscript(Transcript)
    case quit
}
