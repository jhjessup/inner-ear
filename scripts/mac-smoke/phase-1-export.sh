#!/usr/bin/env bash
# =============================================================================
# phase-1-export.sh — Phase 1 Export CLI smoke test
# =============================================================================
# This is a THIN smoke check for the export subcommand. It attempts to run
# `innerear export` with various formats against a well-formed but
# non-existent recording UUID. The command is expected to fail (no
# transcript exists yet), but we verify the CLI parsing and
# FileExportService wiring works without crashing.
#
# Full round-trip testing (record → transcribe → export) will happen once
# Phase 2 lands real recording capture and transcription pipeline.
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."

# A syntactically valid UUID that (almost certainly) has no transcript on
# disk — exercises the "not found" path rather than UUID-format validation.
TEST_ID="00000000-0000-0000-0000-000000000000"
EXIT_CODE=0

echo "=== Phase 1 Export Smoke Test ==="
echo "Testing CLI export subcommand with various formats..."
echo "Note: This uses a nonexistent UUID ($TEST_ID) — no transcript exists"
echo "yet, so commands are expected to fail with 'not found' errors."
echo ""

check_expected_failure() {
  local description="$1"; shift
  echo "--- Testing $description ---"
  local output
  output="$("$@" 2>&1)"
  local code=$?
  if [[ $code -eq 0 ]]; then
    echo "UNEXPECTED: succeeded (should have failed)"
    echo "$output"
    EXIT_CODE=1
  else
    echo "Expected failure (exit code $code)"
    if echo "$output" | grep -q "No transcript found"; then
      echo "  correctly indicates missing transcript"
    fi
  fi
  echo ""
}

check_expected_failure "--format markdown" swift run innerear export "$TEST_ID" --format markdown
check_expected_failure "--format json" swift run innerear export "$TEST_ID" --format json
check_expected_failure "--format text" swift run innerear export "$TEST_ID" --format text
check_expected_failure "invalid format (ArgumentParser should reject)" swift run innerear export "$TEST_ID" --format invalidformat
check_expected_failure "invalid UUID (ArgumentParser should reject)" swift run innerear export "not-a-uuid" --format markdown

echo "=== Phase 1 Export Smoke Test Complete ==="
exit $EXIT_CODE
