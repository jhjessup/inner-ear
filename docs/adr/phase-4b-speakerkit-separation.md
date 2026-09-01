# Phase 4b decision: voice-based remote-speaker separation via SpeakerKit

## Context

`docs/adr/phase-4-diarization-approach.md` chose channel-based diarization
for Phase 4 and explicitly deferred one piece of real diarization:
distinguishing multiple distinct remote speakers within the system-audio
channel (Alice and Bob on the far end of a call were both labeled a single
"Speaker 2 (Remote)"). The reason given at the time was that WhisperKit's
diarization support was experimental and unverified, and guessing at an
unstable third-party API for a feature the architecture didn't strictly
need yet was a worse risk/value trade than shipping the simpler two-channel
case first.

That constraint no longer holds. In May 2026, WhisperKit graduated to
v1.0.0 and was restructured as the Argmax Open-Source SDK
(`argmaxinc/argmax-oss-swift`), a single Swift package now bundling
WhisperKit, **SpeakerKit** (pyannote-based, on-device speaker diarization),
and TTSKit together. SpeakerKit is a stable, documented product — not an
experimental flag on WhisperKit — with a straightforward API
(`SpeakerKit.diarize(audioArray:) -> DiarizationResult`) and reported
accuracy comparable to state-of-the-art systems like pyannote across
published benchmarks.

## Decision

Add a new lower-level verb service, `SpeakerSeparationService`
(`Sources/InnerEarCore/Services/SpeakerSeparationService.swift`), distinct
from `DiarizationService`: it takes a single audio file and returns
`[SpeakerTurn]` — per-cluster voice segments — without any knowledge of
`Transcript`/`Speaker` domain types. `SpeakerKitSpeakerSeparationService`
implements it by loading the audio via WhisperKit's
`AudioProcessor.loadAudioAsFloatArray` and running it through SpeakerKit's
`diarize(audioArray:)`.

`ChannelBasedDiarizationService` composes with this via a new optional
constructor parameter, `speakerSeparationService: SpeakerSeparationService?
= nil`:

- **`nil` (default):** unchanged from Phase 4 — every system-audio segment
  is attributed to one shared "Speaker 2 (Remote)". All existing tests and
  call sites are unaffected.
- **Provided:** the system-audio channel is run through
  `separateSpeakers(audioFileURL:)`, and each transcribed segment is
  attributed to whichever returned turn overlaps it most (by time
  intersection), splitting the single bucket into "Speaker 2 (Remote)",
  "Speaker 3 (Remote)", etc. — one per distinct voice cluster SpeakerKit
  finds. A segment with no overlapping turn (a gap in the diarization
  output) is attributed to the nearest turn by midpoint distance rather
  than left unattributed.

`maxSupportedSpeakers` now honestly reflects which mode is active: `1`
when no separation service is injected, `8` when one is — matching the
ceiling `DiarizationService`'s protocol doc comment always described.

Voice-based separation is treated as a **best-effort enhancement, not a
hard dependency**: if `speakerSeparationService` is `nil`, throws, or
returns no turns, `diarize()` falls back to the original single-bucket
behavior rather than failing the whole call. A worse remote-speaker
labeling is better than no transcript at all.

## What this still doesn't do

- `clusterID` values from `SpeakerSeparationService` are only stable
  *within one call* — they are not a persistent cross-recording speaker
  identity. Two separate recordings of the same person will not share a
  `clusterID`, and nothing here attempts to link them.
- The overlap-matching heuristic (max-intersection, nearest-midpoint
  fallback) is a reasonable segment-to-turn attribution, not a
  frame-accurate alignment. SpeakerKit's own `DiarizationResult` exposes
  word-level/subsegment strategies for tighter alignment
  (`SpeakerInfoStrategy`); this project uses the simpler segment-level
  overlap because `TranscriptionService`'s existing contract doesn't
  expose word-level timing to this layer, and adding that is out of scope
  for this phase.
- The local user's own microphone channel is still never voice-diarized —
  it's always exactly one speaker by construction (Phase 4's original,
  still-correct insight: we know which channel is the local user without
  needing to guess from voice characteristics at all).

## Why this composition, not a replacement service

`ChannelBasedDiarizationService` already owns the mic-vs-remote channel
split, the transcription-service injection, and the segment-merge/sort
logic — none of that changes. `SpeakerSeparationService` is deliberately a
separate, narrower verb (audio file in, speaker turns out) rather than
folding SpeakerKit calls directly into `ChannelBasedDiarizationService` or
replacing it outright, so it can be faked independently in tests
(`FakeSpeakerSeparationService`) without needing a real Core ML pipeline,
consistent with this project's SVO/protocol-first convention
(`ARCHITECTURE.md`) and `AX-P1`/`AX-P2` in `TEST_DOCTRINE.md`.
