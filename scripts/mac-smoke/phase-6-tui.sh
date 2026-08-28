#!/usr/bin/env bash
# =============================================================================
# phase-6-tui.sh — TUI dashboard smoke test (automated portion)
# =============================================================================
# Verifies the InnerEarTUIKit pure logic layer (TUIController/TUIRenderer)
# by running its Swift Testing suite via `swift test --filter`. These tests
# use only in-memory model fixtures (no real audio hardware, no Core ML, no
# terminal I/O), so this script can run on any Mac with a working Swift
# toolchain.
#
# This is a thin smoke check — it proves the InnerEarTUIKit target compiles,
# and that the state machine / renderer behave as specified. It does NOT
# exercise TerminalIO.swift (termios/ioctl/signal handling) or the real
# service wiring in TUICommand/TUIRunLoop — those require a live terminal
# and a human at the keyboard, and are covered instead by
# scripts/mac-smoke/tui-manual-check.sh.
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."

EXIT_CODE=0

echo "=== TUI Dashboard Smoke Test (automated) ==="
echo "Runs InnerEarTUIKitTests via swift test. These use pure in-memory"
echo "fixtures only, so no audio hardware, Core ML, terminal, or network"
echo "is required."
echo ""

echo "--- Testing InnerEarTUIKitTests ---"
TEST_OUTPUT="$(swift test --filter InnerEarTUIKitTests 2>&1)"
TEST_CODE=$?
echo "$TEST_OUTPUT"
if [[ $TEST_CODE -eq 0 ]]; then
  echo "InnerEarTUIKitTests passed."
else
  echo "InnerEarTUIKitTests FAILED (exit code $TEST_CODE)."
  EXIT_CODE=1
fi
echo ""

echo "--- Building innerear CLI (includes TerminalIO/TUICommand/TUIRunLoop) ---"
BUILD_OUTPUT="$(swift build 2>&1)"
BUILD_CODE=$?
echo "$BUILD_OUTPUT"
if [[ $BUILD_CODE -eq 0 ]]; then
  echo "swift build passed."
else
  echo "swift build FAILED (exit code $BUILD_CODE)."
  EXIT_CODE=1
fi
echo ""

echo "=== TUI Dashboard Smoke Test (automated) Complete ==="
echo "NOTE: run scripts/mac-smoke/tui-manual-check.sh interactively to verify"
echo "the actual terminal experience (raw mode, signal handling, live flow)."
exit $EXIT_CODE
