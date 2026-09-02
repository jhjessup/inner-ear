# Test Doctrine

This is the project's actual testing specification — what every `TEST_DOCTRINE.md` reference in this codebase's comments points at. It's a Swift-specific extraction of the axioms and mandatory behaviors this project holds itself to; the generic multi-project governance template it started from (HTTP endpoints, database sessions, pytest marks — none of which apply here) has been dropped rather than reproduced.

## Test Types

Two categories, matching what this codebase actually has (no HTTP layer, no server-side database):

- **`@unit` / `@service`** — pure logic or a single service protocol implementation, tested against a real or fake backend (e.g. `RecordingStoreTests` against a real temp directory, since `RecordingStore` itself is what's under test), asserting on persisted/output state. No real Core ML, audio hardware, or network access.
- **`@integration`** — crosses two or more services end-to-end (e.g. capture → transcribe → diarize → summarize → export). May use real on-device models and real audio fixtures; these are slow and macOS-only, and are what `scripts/mac-smoke/*.sh` and `scripts/verify-on-mac.sh` cover, not the default `swift test` run.

## Axioms

Structural contracts that keep every service independently testable — architectural rules, not style preferences.

**AX-P1 — Protocol Independence.** Every service type (`AudioCaptureService`, `TranscriptionService`, `DiarizationService`, `SpeakerSeparationService`, `SummarizationService`, `ExportService`) is defined behind a protocol. Callers (the TUI run loop, CLI commands) depend on the protocol, never the concrete Core ML/AVFoundation/WhisperKit-backed implementation, so tests can inject a fake without touching real hardware, models, or the filesystem.

**AX-P2 — No Real Audio/Model Execution in Unit Tests.** Unit and service-tier tests never record real audio, invoke a real WhisperKit/SpeakerKit model, or run real Core ML inference. Anything that does is at minimum an integration test, run separately (see `scripts/mac-smoke/`), not in the default `swift test` suite.

**AX-P3 — Explicit Side Effect Declaration.** Every service method that writes to local persistence or the filesystem (recording files, exports, the JSON store) as a side effect documents that in a doc comment.

**AX-P4 — Direct Testability Requirement.** Every new service method has at least one test that calls it directly through its protocol — without routing through the TUI. A new service method with no direct test is a real gap regardless of how much the TUI layer happens to exercise it.

**AX-P5 — No Fixture Duplication.** Shared test doubles (`Fake*Service` types, fixture transcripts/recordings) live in `Tests/InnerEarCoreTests/TestSupport/Fakes.swift`, not duplicated across test files.

## Mandatory Test Matrix

Behaviors this project considers non-negotiable regardless of overall test coverage — each needs a named test that explicitly validates it, not just incidental coverage from testing something else. Status reflects what's actually asserted today, not aspiration:

| # | Behavior | Status |
|---|---|---|
| MTM-1 | Recording never begins writing to disk before microphone (and, if requested, screen-recording) permission is granted. | Not yet a named test — enforced by `AVFoundationAudioCaptureService`'s real permission-request flow, which is macOS-hardware-dependent and not exercised by the fake-backed unit suite. |
| MTM-2 | No code path in `AudioCaptureService`, `TranscriptionService`, `DiarizationService`, or `SummarizationService` issues a network request when using on-device/local models. | ✅ `NoNetworkAccessTests.fullPipeline_withFakeServices_makesNoNetworkRequests` |
| MTM-3 | Any cloud-AI path redacts PII before sending, restores it after. | N/A — no cloud-AI path exists in this project. Everything is on-device only; see [Privacy](README.md#privacy). |
| MTM-4 | Speaker diarization output is deterministic and stable for a given input across repeated runs. | Not yet a named test. `ChannelBasedDiarizationService`'s matching logic (time-overlap, deterministic tie-break) is deterministic by construction, but that determinism isn't asserted directly yet. |
| MTM-5 | Every export format produces a non-empty, well-formed output for a representative multi-speaker transcript. | Partially covered — `ExportServiceTests` covers most formats individually; not consolidated into one matrix-style test per format. |
| MTM-6 | Deleting a recording removes both its audio file and its persisted metadata/transcript — no orphaned files remain on disk. | ✅ `RecordingStoreTests.fullDeleteFlow_recordingAudioTranscriptSummary_leavesNoOrphans` (plus narrower per-step tests in the same file) |
| MTM-7 | App launch and idle state perform no network calls. | Covered indirectly by MTM-2's pipeline-level guard; no separate idle-state-specific test yet. |

Gaps in this table are real and open, not hidden — if you're picking up work on this project, closing one of the "not yet"/"partially" rows above is a legitimate, well-scoped contribution.

## Naming

Test functions describe behavior, condition, and expected result — e.g. `diarize_withSystemAudio_transcribesSystemChannel_mergesSegments_sortedByStartTime`, `esc_whileViewingResults_fromDetail_popsToList_staysInDetail`. Fixture helpers are descriptive nouns with no `test`/`make` ambiguity — `makeRecording`, `makeTranscript`, `TestFixtures.speaker()`.
