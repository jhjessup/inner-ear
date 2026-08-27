# Building InnerEar (CLI now, GUI App later on your Mac)

This repo's `Package.swift` builds two things entirely via Swift Package
Manager, no Xcode *project* required for either — but you do need full
Xcode.app installed and selected as the active developer directory. With
only the standalone Command Line Tools active, SwiftPM's manifest compiler
fails to link `PackageDescription` and every `swift build`/`test`/`run`
call fails identically at manifest-parsing, before reaching any project
code. Check and fix with:

```bash
xcode-select -p
# If this prints .../CommandLineTools instead of an Xcode.app path:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

The two targets:

- **`InnerEarCLI`** (product name `innerear`) — the CLI front end. First
  target in the package, and the fastest path to exercising the real engine
  once real service implementations exist, since a bare CLI binary needs no
  App Sandbox entitlements or Info.plist to request mic access (macOS still
  prompts once at runtime, tied to the terminal/binary, not to an App target).
- **`InnerEarCore`** — the protocol-based engine (services, models, view
  models, SwiftUI views) both the CLI and the future GUI app depend on.

A GUI App target (for eventual Mac App Store distribution) is a separate,
optional step — see §4 below — and is the only part of this project that
actually requires Xcode.

## 1. Build and test the package

```bash
cd inner-ear
swift build
swift test
swift run innerear --version
swift run innerear --help
```

`record`/`transcribe`/`export` currently print "not yet implemented" — the
CLI's command routing is scaffolded against `InnerEarCore`'s protocols, but
no concrete `AVFoundation`/`ScreenCaptureKit`/`WhisperKit`-backed
implementation exists yet (see ADR-001 in the mission audit log). That's the
next mission, done on macOS where it can actually be compiled and verified.

## 2. Add WhisperKit

```bash
# In Package.swift, add to `dependencies:`
.package(url: "https://github.com/argmaxinc/WhisperKit", from: "<version>")
# and add "WhisperKit" to the InnerEarCore target's dependencies.
```

## 3. Implement the real services

Write concrete types conforming to the five protocols in
`Sources/InnerEarCore/Services/`:

- `AudioCaptureService` → back with `AVAudioEngine` (microphone) +
  `ScreenCaptureKit` (system audio).
- `TranscriptionService` → back with WhisperKit's pipeline.
- `DiarizationService` → on-device diarization (WhisperKit has experimental
  diarization support; evaluate against Core ML alternatives).
- `SummarizationService` → local Core ML LLM to start; cloud backend is a
  separate future mission per ORACLE.md CONSTRAINT_2.
- `ExportService` → `PDFKit` for PDF, plain string writers for
  Markdown/text/RTF, `JSONEncoder` for JSON.

Keep each implementation in its own file next to the protocol, e.g.
`WhisperKitTranscriptionService.swift`, so the protocol file stays a pure
contract. Wire them into `InnerEarCLI/CLI.swift`'s command handlers once they
exist, replacing the "not yet implemented" stubs.

Run the CLI against real audio with `swift run innerear record`; the first
run triggers the standard macOS microphone (and, if `--no-system-audio` is
omitted, Screen Recording) permission prompt.

## 4. Optional: wrap InnerEarCore in a macOS GUI App (Xcode, for App Store distribution)

1. Xcode → File → New → Project → macOS → App.
2. Product Name: `InnerEar`. Interface: SwiftUI. Language: Swift.
3. Save it as a sibling folder, e.g. `inner-ear/App/`, or anywhere convenient
   — it does not need to be inside `Sources/`.
4. File → Add Package Dependencies → Add Local... → select the `inner-ear/`
   directory (the one with `Package.swift`). Add `InnerEarCore` as a
   dependency of the App target (not `InnerEarCLI` — that's terminal-only).
5. Replace the generated `InnerEarApp.swift` with something like:

   ```swift
   import SwiftUI
   import InnerEarCore

   @main
   struct InnerEarApp: App {
       var body: some Scene {
           WindowGroup {
               // Wire the same real service implementations from InnerEarCore
               // used by the CLI.
               Text("Wire real services here")
           }
       }
   }
   ```

6. In the App target's Signing & Capabilities: enable **App Sandbox**, check
   **Hardware → Audio Input**, and add the **Audio Recording
   (ScreenCaptureKit)** capability for system-audio capture (Screen Recording
   permission is requested at runtime — no Info.plist key suppresses it).
7. Add Info.plist key `NSMicrophoneUsageDescription` (required for mic
   access; explain it's for on-device transcription).
8. Cmd+R to run.
