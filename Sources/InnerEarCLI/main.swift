import ArgumentParser
import Foundation
import InnerEarCore

/// Top-level command for the `innerear` CLI.
struct InnerEarCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "innerear",
        abstract: "Local-only meeting recorder/transcriber CLI",
        discussion: """
        All processing runs on-device. No cloud, no accounts, no uploads.
        """,
        version: "0.1.0",
        subcommands: [
            RecordCommand.self,
            TranscribeCommand.self,
            ExportCommand.self
        ],
        defaultSubcommand: nil
    )
}

/// `innerear record` — Start a new recording session.
struct RecordCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Start a new recording session"
    )

    @Flag(name: .long, help: "Disable system audio capture (microphone only)")
    var noSystemAudio: Bool = false

    func run() async throws {
        print("record (system audio: \(!noSystemAudio)) — not yet implemented.")
        print("Real AudioCaptureService implementation is pending — see docs/XCODE_SETUP.md.")
        throw ExitCode(1)
    }
}

/// `innerear transcribe` — Transcribe an audio file.
struct TranscribeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transcribe",
        abstract: "Transcribe an audio file"
    )

    @Argument(help: "Path to the audio file to transcribe")
    var audioFile: String

    @Option(name: .long, help: "Transcription model to use (whisperLargeV3Turbo, parakeet)")
    var model: String?

    func run() async throws {
        print("transcribe '\(audioFile)' (model: \(model ?? "default")) — not yet implemented.")
        print("Real TranscriptionService implementation is pending — see docs/XCODE_SETUP.md.")
        throw ExitCode(1)
    }
}

/// Export format for CLI (matches ExportFormat from InnerEarCore).
enum ExportFormatCLI: String, ExpressibleByArgument, CaseIterable {
    case pdf
    case markdown
    case plainText = "text"
    case rtf
    case json
    case subtitles

    var coreFormat: ExportFormat {
        switch self {
        case .pdf: return .pdf
        case .markdown: return .markdown
        case .plainText: return .plainText
        case .rtf: return .rtf
        case .json: return .json
        case .subtitles: return .subtitles
        }
    }
}

/// `innerear export` — Export a transcript to a file.
struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export a transcript to a file"
    )

    @Argument(help: "Recording/transcript UUID to export")
    var recordingID: String

    @Option(name: .long, help: "Export format")
    var format: ExportFormatCLI = .markdown

    func run() async throws {
        guard let uuid = UUID(uuidString: recordingID) else {
            print("Error: '\(recordingID)' is not a valid UUID")
            throw ExitCode(1)
        }

        let store = try RecordingStore()
        let exportService = FileExportService()

        // Load transcript by treating the recording-id argument AS the transcript's own UUID
        let transcript: Transcript
        do {
            transcript = try store.loadTranscript(id: uuid)
        } catch RecordingStoreError.notFound(_) {
            print("Error: No transcript found with ID \(uuid)")
            throw ExitCode(1)
        } catch {
            print("Error loading transcript: \(error)")
            throw ExitCode(1)
        }

        // Load summary if it exists (optional)
        let summary = try? store.loadSummary(id: uuid)

        // Determine output file extension
        let ext: String
        switch format {
        case .pdf: ext = "pdf"
        case .markdown: ext = "md"
        case .plainText: ext = "txt"
        case .rtf: ext = "rtf"
        case .json: ext = "json"
        case .subtitles: ext = "srt"
        }

        let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("\(uuid.uuidString).\(ext)")

        _ = try await exportService.export(
            transcript: transcript,
            summary: summary,
            format: format.coreFormat,
            to: outputURL
        )

        print("Exported to: \(outputURL.path)")
    }
}

// Entry point
InnerEarCLI.main()