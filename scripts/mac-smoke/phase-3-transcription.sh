#!/usr/bin/env bash
# =============================================================================
# phase-3-transcription.sh — Phase 3 Transcription smoke test
# =============================================================================
# Verifies the Phase 3 TranscriptionService wiring end-to-end on a real Mac:
#   1. Generates a ~3s synthetic WAV fixture (idempotent) via the standalone
#      AVFoundation script at scripts/generate-fixtures/.
#   2. Runs `innerear transcribe <fixture> --model whisperLargeV3Turbo` and
#      verifies the command exits 0 and prints "Transcript saved:".
#
# This is a thin smoke check — it proves the CLI parses, WhisperKit loads
# the model, the audio is decoded, the resulting Transcript is persisted
# to the store, and the success marker is printed. Detailed content
# assertions live in the Swift tests themselves.
#
# NOTE: The first invocation of `innerear transcribe` will trigger a real
# WhisperKit model download over the network (a few hundred MB) plus
# on-device Core ML compilation. This is expected — subsequent runs reuse
# the cached pipeline. Don't be surprised by the long first-run wall time.
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."

EXIT_CODE=0

echo "=== Phase 3 Transcription Smoke Test ==="
echo "Requires a real Mac with network access (first run downloads a"
echo "WhisperKit model bundle) and a working on-device Core ML stack."
echo ""

# -----------------------------------------------------------------------------
# 1. Generate the synthetic WAV fixture if it isn't already present.
# -----------------------------------------------------------------------------
FIXTURE_PATH="Tests/InnerEarCoreTests/Fixtures/sample-3s.wav"
echo "--- Generating fixture at $FIXTURE_PATH (idempotent) ---"
if [[ -f "$FIXTURE_PATH" ]]; then
  echo "Fixture already exists, skipping generation."
else
  GEN_OUTPUT="$(swift scripts/generate-fixtures/generate-sample-audio.swift 2>&1)"
  GEN_CODE=$?
  echo "$GEN_OUTPUT"
  if [[ $GEN_CODE -ne 0 ]]; then
    echo "Fixture generation FAILED (exit code $GEN_CODE)."
    exit 1
  fi
  if [[ ! -f "$FIXTURE_PATH" ]]; then
    echo "Fixture generation reported success but $FIXTURE_PATH is missing."
    exit 1
  fi
fi
echo ""

# -----------------------------------------------------------------------------
# 2. Run a real `innerear transcribe` invocation and verify the success marker.
# -----------------------------------------------------------------------------
echo "--- Testing 'innerear transcribe $FIXTURE_PATH --model whisperLargeV3Turbo' ---"
echo "(First run will download the WhisperKit model — this can take a few"
echo "minutes. Subsequent runs are much faster.)"
echo ""
TRANSCRIBE_OUTPUT="$(swift run innerear transcribe "$FIXTURE_PATH" --model whisperLargeV3Turbo 2>&1)"
TRANSCRIBE_CODE=$?
echo "$TRANSCRIBE_OUTPUT"
if [[ $TRANSCRIBE_CODE -eq 0 ]]; then
  echo "transcribe command exited 0."
  if echo "$TRANSCRIBE_OUTPUT" | grep -q "Transcript saved:"; then
    echo "  correctly reported 'Transcript saved:'"
  else
    echo "  MISSING expected 'Transcript saved:' output"
    EXIT_CODE=1
  fi
else
  echo "transcribe command FAILED (exit code $TRANSCRIBE_CODE)."
  EXIT_CODE=1
fi
echo ""

echo "=== Phase 3 Transcription Smoke Test Complete ==="
exit $EXIT_CODE
