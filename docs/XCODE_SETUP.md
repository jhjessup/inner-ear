# Wrapping ScribeCore in a macOS App (do this in Xcode, on your Mac)

This repo's `Package.swift` builds `ScribeCore` as a Swift Package — protocols,
models, view models, and SwiftUI views, all unit-testable with `swift test`
(no Xcode required for that part). To get an actual runnable, App
Store-shippable app, you need a real App target with an Info.plist,
entitlements, and app icon. SPM alone can't produce that.

## 1. Verify the package builds and tests pass

```bash
cd scribe
swift build
swift test
```

## 2. Create the App target in Xcode

1. Xcode → File → New → Project → macOS → App.
2. Product Name: `Scribe`. Interface: SwiftUI. Language: Swift.
3. Save it as a sibling folder, e.g. `scribe/App/`, or anywhere convenient —
   it does not need to be inside `Sources/`.
4. In the new project, File → Add Package Dependencies → Add Local... → select
   the `scribe/` directory (the one with `Package.swift`). Add `ScribeCore` as
   a dependency of the App target.
5. Replace the generated `ScribeApp.swift` with something like:

   ```swift
   import SwiftUI
   import ScribeCore

   @main
   struct ScribeApp: App {
       var body: some Scene {
           WindowGroup {
               // Wire real service implementations here once they exist.
               // Until then, RecordingView can be previewed with fakes from
               // ScribeCoreTests/TestSupport (copy what you need into a
               // throwaway preview provider — don't ship test code).
               Text("Wire real services here")
           }
       }
   }
   ```

## 3. Add WhisperKit

File → Add Package Dependencies → `https://github.com/argmaxinc/WhisperKit` →
add to the App target (or to `ScribeCore` directly in `Package.swift` once
you're ready to write the real `TranscriptionService` implementation).

## 4. Entitlements & Info.plist

In the App target's Signing & Capabilities:

- **App Sandbox**: enable. Under it, check **Hardware → Audio Input**.
- If you want system-audio capture (the Channel 2 / remote-participant
  path): add the **Audio Recording (ScreenCaptureKit)** capability, which
  requires the **Screen Recording** permission at runtime — macOS will
  prompt the user; there is no Info.plist key that suppresses this prompt.

Add these Info.plist keys (Xcode's target editor → Info tab):

| Key | Purpose |
|---|---|
| `NSMicrophoneUsageDescription` | Required for `AVAudioEngine`/`AVCaptureDevice` microphone access. Explain why (on-device transcription). |
| `NSSpeechRecognitionUsageDescription` | Only needed if you use Apple's `Speech` framework anywhere alongside WhisperKit. |

## 5. Implement the real services

Write concrete types conforming to the five protocols in
`Sources/ScribeCore/Services/`:

- `AudioCaptureService` → back with `AVAudioEngine` (microphone) +
  `ScreenCaptureKit` (system audio).
- `TranscriptionService` → back with WhisperKit's `WhisperKit` pipeline.
- `DiarizationService` → on-device diarization (WhisperKit has experimental
  diarization support; evaluate against Core ML alternatives).
- `SummarizationService` → local Core ML LLM to start; cloud backend is a
  separate future mission per ORACLE.md CONSTRAINT_2.
- `ExportService` → `PDFKit` for PDF, plain string writers for
  Markdown/text/RTF, `JSONEncoder` for JSON.

Keep each implementation in its own file next to the protocol, e.g.
`WhisperKitTranscriptionService.swift`, so the protocol file stays a pure
contract.

## 6. Run it

Cmd+R in Xcode. Grant the microphone (and, if used, screen recording) prompt
when it appears.
