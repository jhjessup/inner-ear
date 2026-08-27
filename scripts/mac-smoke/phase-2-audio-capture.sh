#!/usr/bin/env bash
# =============================================================================
# phase-2-audio-capture.sh — Phase 2 Audio Capture smoke test
# =============================================================================
# Verifies the Phase 2 AudioCaptureService wiring end-to-end on a real Mac:
#   1. Runs the hardware-gated AudioCaptureServiceTests via `swift test`
#      with INNEREAR_HW_TESTS=1 (real microphone required).
#   2. Runs `innerear record --duration 3 --no-system-audio` and verifies
#      the command prints "Recording saved:" and exits 0.
#
# This is a thin smoke check — it proves the CLI parses, the service starts
# and stops, and the resulting Recording persists to the store. Detailed
# audio-content assertions live in the Swift tests themselves.
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."

EXIT_CODE=0

echo "=== Phase 2 Audio Capture Smoke Test ==="
echo "This script requires a real Mac with a working microphone and"
echo "microphone permission granted to the terminal / 'swift' process."
echo ""

# -----------------------------------------------------------------------------
# 1. Run the hardware-gated test suite.
# -----------------------------------------------------------------------------
echo "--- Testing AudioCaptureServiceTests (hardware-gated) ---"
TEST_OUTPUT="$(INNEREAR_HW_TESTS=1 swift test --filter AudioCaptureServiceTests 2>&1)"
TEST_CODE=$?
echo "$TEST_OUTPUT"
if [[ $TEST_CODE -eq 0 ]]; then
  echo "Hardware-gated tests passed."
else
  echo "Hardware-gated tests FAILED (exit code $TEST_CODE)."
  EXIT_CODE=1
fi
echo ""

# -----------------------------------------------------------------------------
# 2. Run a real `innerear record` invocation and verify the success marker.
# -----------------------------------------------------------------------------
echo "--- Testing 'innerear record --duration 3 --no-system-audio' ---"
RECORD_OUTPUT="$(swift run innerear record --duration 3 --no-system-audio 2>&1)"
RECORD_CODE=$?
echo "$RECORD_OUTPUT"
if [[ $RECORD_CODE -eq 0 ]]; then
  echo "record command exited 0."
  if echo "$RECORD_OUTPUT" | grep -q "Recording saved:"; then
    echo "  correctly reported 'Recording saved:'"
  else
    echo "  MISSING expected 'Recording saved:' output"
    EXIT_CODE=1
  fi
else
  echo "record command FAILED (exit code $RECORD_CODE)."
  EXIT_CODE=1
fi
echo ""

echo "=== Phase 2 Audio Capture Smoke Test Complete ==="
exit $EXIT_CODE
