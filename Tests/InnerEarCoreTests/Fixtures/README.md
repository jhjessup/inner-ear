# Test Fixtures

This directory holds binary/audio fixtures used by tests and smoke scripts.

`sample-3s.wav` is generated on demand by `scripts/generate-fixtures/generate-sample-audio.swift`
(ran automatically as the first step of `scripts/mac-smoke/phase-3-transcription.sh`).
It is not checked into source control because it is reproducible and re-creatable
on the operator's Mac.
