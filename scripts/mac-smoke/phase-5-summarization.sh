#!/usr/bin/env bash
# =============================================================================
# phase-5-summarization.sh — Phase 5 Summarization smoke test
# =============================================================================
# Verifies the Phase 5 ExtractiveSummarizationService implementation by
# running the Swift Testing suite for it via `swift test --filter`. These
# tests use only the pure-Swift implementation (no real audio hardware,
# no Core ML, no network), so this script can run on any Mac with a
# working Swift toolchain.
#
# This is a thin smoke check — it proves the test target compiles, the
# ExtractiveSummarizationService satisfies the SummarizationService
# protocol contract, and the extractive logic behaves as specified.
# Detailed behavioral assertions live in the Swift tests themselves
# (Tests/InnerEarCoreTests/service/ExtractiveSummarizationServiceTests.swift).
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."

EXIT_CODE=0

echo "=== Phase 5 Summarization Smoke Test ==="
echo "Runs ExtractiveSummarizationServiceTests via swift test. These use"
echo "the pure-Swift implementation only, so no audio hardware, Core ML,"
echo "or network is required."
echo ""

# -----------------------------------------------------------------------------
# Run the ExtractiveSummarizationServiceTests test target.
# -----------------------------------------------------------------------------
echo "--- Testing ExtractiveSummarizationServiceTests ---"
TEST_OUTPUT="$(swift test --filter ExtractiveSummarizationServiceTests 2>&1)"
TEST_CODE=$?
echo "$TEST_OUTPUT"
if [[ $TEST_CODE -eq 0 ]]; then
  echo "ExtractiveSummarizationServiceTests passed."
else
  echo "ExtractiveSummarizationServiceTests FAILED (exit code $TEST_CODE)."
  EXIT_CODE=1
fi
echo ""

echo "=== Phase 5 Summarization Smoke Test Complete ==="
exit $EXIT_CODE