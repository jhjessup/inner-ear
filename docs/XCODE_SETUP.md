# Building InnerEar

This repo's `Package.swift` builds entirely via Swift Package Manager —
Command Line Tools alone (no full Xcode.app) is normally enough for
`swift build`/`test`/`run` on a plain SPM package like this one. Xcode.app
is only needed for the optional GUI App wrapper in §2 below (signing,
Info.plist) — not for building/testing/running the CLI/TUI, which is the
primary, fully-implemented interface (`innerear tui`).

If you hit a manifest-compilation failure — `swift build` fails to link
`PackageDescription`, before any project code is even reached, the same
error on every command — that's usually Command Line Tools falling out of
sync with a very new macOS/Swift release, not a hard requirement for full
Xcode. `scripts/verify-on-mac.sh` detects this automatically and tries two
fixes in order: switching to an independent Swift.org toolchain via
`swiftly` (no sudo needed), then reinstalling Command Line Tools. See that
script for the manual commands if you're not running it via the script.

The targets:

- **`InnerEarCLI`** (product name `innerear`) — the CLI/TUI front end.
  `innerear tui` is the primary interface; `record`/`transcribe`/`export`
  are lower-level, non-interactive subcommands for scripting (see the
  root `README.md`).
- **`InnerEarRecording`** — real `AVFoundation`/`ScreenCaptureKit`-backed
  audio capture and the `Recording` model/store, behind protocols with one
  fake each for tests. Deliberately has no dependency on WhisperKit/
  SpeakerKit (see `ARCHITECTURE.md`'s "Module boundaries" section).
- **`InnerEarTranscription`** — `WhisperKit` transcription, `SpeakerKit`
  diarization, extractive summarization, and multi-format export, same
  protocol-per-capability-plus-fake shape.
- **`InnerEarCore`** — just the shared kernel both of the above build on:
  data-directory config resolution and the generic JSON-disk persistence
  helper. No domain models/services live here.
- **`InnerEarTUIKit`** — the pure TUI state machine and renderer
  (functional core), exercised by the impure shell in `InnerEarCLI`.

## 1. Build and test the package

```bash
cd inner-ear
swift build
swift test
swift run innerear tui
```

First launch downloads the WhisperKit/SpeakerKit Core ML models on first
use — expect a real download and a pause the first time you record or
transcribe something. `record`/`transcribe`/`export` also work as
standalone, non-interactive subcommands; see the root `README.md`.

## 2. Optional: wrap InnerEar in a macOS GUI App (Xcode, for App Store distribution)

1. Xcode → File → New → Project → macOS → App.
2. Product Name: `InnerEar`. Interface: SwiftUI. Language: Swift.
3. Save it as a sibling folder, e.g. `inner-ear/App/`, or anywhere convenient
   — it does not need to be inside `Sources/`.
4. File → Add Package Dependencies → Add Local... → select the `inner-ear/`
   directory (the one with `Package.swift`). Add `InnerEarRecording` and
   `InnerEarTranscription` as dependencies of the App target (not
   `InnerEarCLI` — that's terminal-only).
5. Replace the generated `InnerEarApp.swift` with something like:

   ```swift
   import SwiftUI
   import InnerEarRecording
   import InnerEarTranscription

   @main
   struct InnerEarApp: App {
       var body: some Scene {
           WindowGroup {
               // Wire the same real service implementations used by the CLI.
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
