# Architecture

InnerEar is decomposed as **subject-verb-object**, not classic noun-centric
OOP: data types are inert nouns, and behavior lives in separate,
protocol-named verb types that act on them. This is deliberate and applies
uniformly across the codebase. Read this before adding a new
service/effect/model — it's the convention every existing piece of code
follows, and new code (including anything written by a dispatched
agent/operative) is expected to follow it too.

## The pattern

**Nouns (`Sources/InnerEarCore/Models/`) are pure data. They do nothing.**

`Recording`, `Transcript`, `Summary`, `Speaker`, `TranscriptSegment` are
`struct`s — `Codable`, `Equatable`, `Sendable`. Their only non-trivial
members are pure queries (`Transcript.fullText`, `Transcript.speaker(for:)`),
never verbs. Nothing transcribes itself, summarizes itself, or exports
itself. This is intentional — it's what Fowler calls an "anemic domain
model," and here that's a feature, not a smell:

- Platform types (AVFoundation, ScreenCaptureKit, WhisperKit) never leak
  into a model. Models stay trivially `Codable` and portable.
- A model's meaning doesn't depend on which service produced it, so
  services can be swapped without touching models at all (see
  `docs/adr/phase-4-diarization-approach.md` for a case where this mattered).

**Verbs live in protocols, one capability each, one implementation each:**

| Protocol | Verb | Implementation |
|---|---|---|
| `AudioCaptureService` | `startCapture` / `stopCapture` | `AVFoundationAudioCaptureService` |
| `TranscriptionService` | `transcribe` | `WhisperKitTranscriptionService` |
| `DiarizationService` | `diarize` | `ChannelBasedDiarizationService` |
| `SummarizationService` | `summarize` / `chat` | `ExtractiveSummarizationService` |
| `ExportService` | `export` | `FileExportService` |

Every method reads as literal SVO grammar:
`transcriptionService.transcribe(recording) -> Transcript`. That shape —
Subject.Verb(Object) → new Object — is the organizing principle, not an
accident of naming.

Two direct consequences, both required, not optional:

1. **Protocol-first.** A new capability is a new protocol before it's an
   implementation. Callers (ViewModels, the TUI run loop, CLI commands)
   depend on the protocol, never the concrete type.
2. **Every verb is fakeable.** `Tests/InnerEarCoreTests/TestSupport/Fakes.swift`
   has one `Fake*Service` per protocol. Unit/Service-tier tests use fakes;
   no real audio hardware, Core ML, or network in that tier (see
   `TEST_DOCTRINE.md`).

## The same shape, one level up: the TUI

`Sources/InnerEarTUIKit/` applies the identical pattern to the presentation
layer, via an Elm/Redux-style reducer:

- `TUIState` — a noun: an immutable snapshot of everything on screen.
- `TUIEvent` — a trigger (`.key`, `.tick`).
- `TUIController.reduce(state, event) -> (State, [TUIEffect])` — a pure
  verb. No I/O, no `async`, fully unit-tested.
- `TUIEffect` — a list of verb-intents (`startRecording`, `runPipeline`,
  `deleteAudio`, `saveDataDirectory`, ...) that `reduce` *declares* but does
  not perform.
- `Sources/InnerEarCLI/TUIRunLoop.swift` — the impure shell. It's the
  subject that actually executes each `TUIEffect` against the real Core
  services, then folds the result back into `state`.

This is "functional core, imperative shell": `InnerEarTUIKit` never touches
a file, a socket, or a clock (beyond reading `Date()` for display). Every
side effect crosses into `TUIRunLoop` through an explicit, named
`TUIEffect` case. This is why `TUIControllerTests`/`TUIRendererTests` can
be exhaustive and fast with zero mocking.

## What this means when adding something new

- **New capability (record, transcribe, export, ...)** → new protocol in
  `Sources/InnerEarCore/Services/`, named after the verb, plus one
  concrete implementation. Don't add a method to a model.
- **New TUI behavior** → extend `TUIState`/`TUIEvent`/`TUIEffect` and
  `TUIController.reduce`. `reduce` stays pure — if it needs to touch the
  filesystem or a service, that's a new `TUIEffect` case handled in
  `TUIRunLoop`, not inline logic in the reducer.
- **New model field** → fine, as long as it stays inert data. If you're
  reaching to add a method that *does* something (not just computes a
  query from existing fields), that behavior almost certainly belongs in a
  service instead.
- **Read-only derived data needed by the pure layer** (e.g. "does this
  recording have a transcript") → resolve it once in the impure shell
  (`TUIRunLoop`) into a plain value the pure layer can pattern-match on
  (see `RecordingListEntry`), not by giving the pure layer a way to ask a
  service itself.

## Why write this down

This project's implementation work is mostly done by dispatching detailed
prompts to stateless model instances that have no memory of prior sessions
— they only know this pattern if it's re-explained every time, or if it's
written down once, here, and referenced. Point future dispatch prompts and
reviews at this file instead of re-deriving the rationale from scratch.
