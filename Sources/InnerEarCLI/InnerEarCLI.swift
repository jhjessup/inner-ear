import ArgumentParser
import Foundation
import InnerEarCore

/// Top-level command for the `innerear` CLI.
///
/// Uses `@main` directly on the command struct (this file is deliberately
/// NOT named main.swift — SwiftPM treats that filename as implicit
/// top-level code, which is incompatible with @main). A prior attempt kept
/// main.swift and called `InnerEarCLI.main()` from top-level code, adding
/// `@available(...)` on the struct per ArgumentParser's own runtime error
/// message ("Asynchronous root command needs availability annotation") —
/// that didn't actually fix it; manually bridging into an async command
/// from synchronous top-level code hits this check regardless of
/// annotations. `@main` gives Swift's real compiler-synthesized async
/// entry point instead of ArgumentParser's manual bridge, which is the
/// pattern ArgumentParser's own documentation recommends for async root
/// commands.
@main
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

    @Option(name: .long, help: "Recording duration in seconds")
    var duration: Double = 10

    func run() async throws {
        let service: AVFoundationAudioCaptureService
        do {
            service = try AVFoundationAudioCaptureService()
            try await service.startCapture(captureSystemAudio: !noSystemAudio)
        } catch let error as AudioCaptureError {
            switch error {
            case .microphonePermissionDenied:
                print("Error: Microphone permission denied — grant it in System Settings > Privacy & Security > Microphone")
            case .systemAudioPermissionDenied:
                print("Error: Screen Recording permission denied — grant it in System Settings > Privacy & Security > Screen Recording (needed for system audio capture)")
            case .captureAlreadyInProgress:
                print("Error: A recording is already in progress")
            case .noActiveCapture:
                print("Error: No active recording to stop")
            case .deviceUnavailable:
                print("Error: Audio device unavailable — check that a microphone is connected and not in use by another app")
            }
            throw ExitCode(1)
        } catch {
            print("Error starting recording: \(error)")
            throw ExitCode(1)
        }

        print("Recording for \(duration) seconds...")

        do {
            try await Task.sleep(for: .seconds(duration))
            let recording = try await service.stopCapture()

            do {
                let store = try RecordingStore()
                try store.save(recording)
                print("Recording saved: \(recording.id.uuidString)")
            } catch {
                print("Error saving recording: \(error)")
                throw ExitCode(1)
            }
        } catch let error as AudioCaptureError {
            switch error {
            case .microphonePermissionDenied:
                print("Error: Microphone permission denied — grant it in System Settings > Privacy & Security > Microphone")
            case .systemAudioPermissionDenied:
                print("Error: Screen Recording permission denied — grant it in System Settings > Privacy & Security > Screen Recording (needed for system audio capture)")
            case .captureAlreadyInProgress:
                print("Error: A recording is already in progress")
            case .noActiveCapture:
                print("Error: No active recording to stop")
            case .deviceUnavailable:
                print("Error: Audio device unavailable — check that a microphone is connected and not in use by another app")
            }
            throw ExitCode(1)
        } catch let code as ExitCode {
            // Already handled and printed by the RecordingStore save() catch
            // above — rethrow as-is instead of falling into the generic
            // catch below, which would print a confusing second message.
            throw code
        } catch {
            print("Error during recording: \(error)")
            throw ExitCode(1)
        }
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

    @Option(name: .long, help: "Language code (e.g. en) — omit for auto-detect")
    var language: String?

    func run() async throws {
        // Validate --model against TranscriptionModel's known raw values up
        // front so the operator gets a clear CLI error rather than a
        // generic runtime failure from inside the transcription pipeline.
        let modelRaw = model ?? TranscriptionModel.whisperLargeV3Turbo.rawValue
        guard let selectedModel = TranscriptionModel(rawValue: modelRaw) else {
            let validValues = TranscriptionModel.allCases.map(\.rawValue).joined(separator: ", ")
            print("Error: Unknown model '\(modelRaw)'. Valid options: \(validValues).")
            throw ExitCode(1)
        }

        // Build a minimal Recording from the audio file path. We don't have
        // the real recording metadata (title, duration) here, so derive what
        // we can and stub the rest.
        // TODO: Compute duration by probing the actual audio file in a future
        // pass; for now 0 is a harmless placeholder since the transcription
        // pipeline doesn't depend on it.
        let audioURL = URL(fileURLWithPath: audioFile)
        let title = audioURL.deletingPathExtension().lastPathComponent
        let recording = Recording(
            title: title,
            createdAt: Date(),
            duration: 0,
            microphoneFileURL: audioURL
        )

        let service = WhisperKitTranscriptionService()
        let transcript: Transcript
        do {
            transcript = try await service.transcribe(
                recording: recording,
                model: selectedModel,
                languageCode: language
            )
        } catch let error as TranscriptionError {
            switch error {
            case .audioFileUnreadable:
                print("Error: Could not read audio file at \(audioFile) — check the path and permissions.")
            case .modelNotDownloaded(let m):
                print("Error: Model \(m.rawValue) is not downloaded.")
            case .transcriptionFailed(let reason):
                print("Error: Transcription failed — \(reason)")
            }
            throw ExitCode(1)
        } catch let code as ExitCode {
            // Already handled and printed by the inner catch — rethrow as-is
            // instead of falling into the generic catch below, which would
            // print a confusing second message.
            throw code
        } catch {
            print("Error: \(error)")
            throw ExitCode(1)
        }

        do {
            let store = try RecordingStore()
            try store.save(transcript)
        } catch {
            print("Error saving transcript: \(error)")
            throw ExitCode(1)
        }

        print("Transcript saved: \(transcript.id.uuidString)")
        print(transcript.fullText)
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