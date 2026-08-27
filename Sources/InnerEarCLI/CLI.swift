import Foundation

/// Command routing for the `innerear` CLI. Kept dependency-free (no
/// swift-argument-parser) for this scaffold — see docs/XCODE_SETUP.md for
/// notes on swapping in a real argument-parsing library once the CLI grows
/// beyond a handful of subcommands.
enum CLICommand {
    case record(captureSystemAudio: Bool)
    case transcribe(path: String, model: String?)
    case export(recordingID: String, format: String)
    case help
    case version

    static func parse(_ arguments: [String]) -> CLICommand {
        guard let first = arguments.first else { return .help }

        switch first {
        case "record":
            let noSystemAudio = arguments.contains("--no-system-audio")
            return .record(captureSystemAudio: !noSystemAudio)

        case "transcribe":
            guard arguments.count > 1 else { return .help }
            let path = arguments[1]
            let model = flagValue(named: "--model", in: arguments)
            return .transcribe(path: path, model: model)

        case "export":
            guard arguments.count > 1 else { return .help }
            let recordingID = arguments[1]
            let format = flagValue(named: "--format", in: arguments) ?? "markdown"
            return .export(recordingID: recordingID, format: format)

        case "--version", "-v":
            return .version

        default:
            return .help
        }
    }

    private static func flagValue(named flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// This is a scaffold: it wires command routing against InnerEarCore's
/// protocols but does not yet inject real AVFoundation/ScreenCaptureKit/
/// WhisperKit-backed implementations (ADR-001 — those are written and
/// verified on macOS in a later mission, not in this Linux-authored scaffold).
enum CLIRunner {
    static func run(arguments: [String]) -> Int32 {
        let command = CLICommand.parse(arguments)

        switch command {
        case .help:
            printUsage()
            return 0

        case .version:
            print("innerear 0.1.0-scaffold")
            return 0

        case .record(let captureSystemAudio):
            print("record (system audio: \(captureSystemAudio)) — not yet implemented.")
            print("Real AudioCaptureService implementation is pending — see docs/XCODE_SETUP.md.")
            return 1

        case .transcribe(let path, let model):
            print("transcribe '\(path)' (model: \(model ?? "default")) — not yet implemented.")
            print("Real TranscriptionService implementation is pending — see docs/XCODE_SETUP.md.")
            return 1

        case .export(let recordingID, let format):
            print("export '\(recordingID)' as \(format) — not yet implemented.")
            print("Real ExportService implementation is pending — see docs/XCODE_SETUP.md.")
            return 1
        }
    }

    private static func printUsage() {
        print("""
        innerear — local-only meeting recorder/transcriber CLI

        USAGE:
          innerear record [--no-system-audio]
          innerear transcribe <audio-file> [--model <name>]
          innerear export <recording-id> [--format markdown|json|text|rtf|pdf]
          innerear --version

        All processing runs on-device. No cloud, no accounts, no uploads.
        """)
    }
}
