# Phase 4 decision: channel-based diarization, not ML speaker separation

## Context

The multiphase plan flagged `DiarizationService` as the highest-uncertainty
phase, expecting a choice between WhisperKit's experimental diarization
support and a "simpler heuristic." Before dispatching any implementation
work, it's worth re-examining what "diarization" actually means for this
project's specific capture architecture.

`AudioCaptureService` (Phase 2) does **not** capture a single mixed audio
stream — it captures two independent channels from the start:
`recording.microphoneFileURL` (the local user, always) and
`recording.systemAudioFileURL` (remote call participants, when
`captureSystemAudio: true`). `TranscriptionService` (Phase 3) currently only
transcribes the microphone channel — the system-audio channel is captured to
disk but never transcribed at all yet.

This means the problem generic diarization tools solve — "given one mixed
audio stream, figure out which spans belong to which unknown speaker" — is
mostly already solved by the capture design itself for the local-user side:
we know with certainty which channel is the local user, because it's a
separate microphone recording, not a guess from voice characteristics.

## Decision

`DiarizationService`'s real job, for this project, is: **transcribe the
system-audio channel (if present) and merge it into the existing
mic-channel transcript, labeling all system-audio segments as a single
"Speaker 2 (Remote)."**

This is not full diarization — it does not distinguish between multiple
different remote participants talking in the same call (Alice and Bob on
the far end are both "Speaker 2" in this first version). It's a real,
correct, fully-local implementation of the part of diarization our
architecture actually needs for its first version, with zero additional
third-party API risk (no WhisperKit experimental diarization, no separate
ML pipeline).

- If `recording.hasSystemAudio` is `false`: return the input transcript
  unchanged (already single-speaker, correct).
- If `true`: transcribe `recording.systemAudioFileURL!` using the same
  `TranscriptionService` + model already used for the mic channel (dependency-
  injected, not hardcoded to WhisperKit directly — keeps `DiarizationService`
  testable against a `TranscriptionService` fake). Create a "Speaker 2
  (Remote)" `Speaker`. Tag every segment from that second transcription with
  that speaker's ID. Merge both segment lists sorted by `startTime`. Return a
  new `Transcript` with `speakers: [existing mic speaker, remote speaker]`
  and the merged, sorted segment list.

## What this defers, deliberately

Distinguishing multiple distinct remote speakers within the system-audio
channel itself (Alice vs. Bob, both on the far end) is real, harder
diarization and is explicitly **out of scope** for this phase — it would be
a natural Phase 4b/stretch item once the simpler two-channel case is
shipped and working. Noting it here so it isn't silently forgotten, not
because it's being solved.

## Why this beats guessing at WhisperKit's diarization API

WhisperKit's diarization support (as of the version pinned in Phase 3) is
described as experimental, and neither this session nor the dispatched
operative has verified access to its exact current API surface. Given
Phase 3 already spent 3 CI round-trips resolving WhisperKit API/concurrency
mismatches for the *transcription* API (which is far more stable/documented
than its diarization support), guessing at a less-stable API for a feature
our own architecture doesn't strictly need yet is a worse risk/value trade
than implementing the channel-based approach, which requires no new
third-party surface at all — only the `TranscriptionService` we already
have working end-to-end.
