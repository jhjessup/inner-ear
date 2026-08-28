#!/usr/bin/env bash
# =============================================================================
# phase-4-diarization.sh — Phase 4 Diarization smoke test
# =============================================================================
# Verifies the Phase 4 ChannelBasedDiarizationService implementation by
# running the Swift Testing suite for it via `swift test --filter`. These
# tests use only fakes (no real audio hardware, no Core ML, no network),
# so this script can run on any Mac with a working Swift toolchain —
# no fixture generation step is needed (unlike phase 3 which requires
# a real WhisperKit model load).
#
# This is a thin smoke check — it proves the test target compiles, the
# ChannelBasedDiarizationService satisfies the DiarizationService
# protocol contract, and the merge logic does what the ADR says it
# should. Detailed behavioral assertions live in the Swift tests
# themselves (Tests/InnerEarCoreTests/service/ChannelBasedDiarizationServiceTests.swift).
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."

EXIT_CODE=0

echo "=== Phase 4 Diarization Smoke Test ==="
echo "Runs ChannelBasedDiarizationServiceTests via swift test. These use"
echo "fakes only, so no audio hardware, Core ML, or network is required."
echo ""

# -----------------------------------------------------------------------------
# Run the ChannelBasedDiarizationServiceTests test target.
# -----------------------------------------------------------------------------
echo "--- Testing ChannelBasedDiarizationServiceTests ---"
TEST_OUTPUT="$(swift test --filter ChannelBasedDiarizationServiceTests 2>&1)"
TEST_CODE=$?
echo "$TEST_OUTPUT"
if [[ $TEST_CODE -eq 0 ]]; then
  echo "ChannelBasedDiarizationServiceTests passed."
else
  echo "ChannelBasedDiarizationServiceTests FAILED (exit code $TEST_CODE)."
  EXIT_CODE=1
fi
echo ""

echo "=== Phase 4 Diarization Smoke Test Complete ==="
exit $EXIT_CODE
