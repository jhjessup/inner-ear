#!/usr/bin/env bash
# =============================================================================
# audit-fixes-validation.sh — Validates PR #19 (mission/audit-fixes)
# =============================================================================
# Targeted validation for the Fable-audit fix set: RecordingStoreTests,
# NoNetworkAccessTests, the TUIRunLoop idle-render change, RecordingStore's
# decode-failure logging, and the shared parakeet-rejection refactor.
#
# Two of those five (the idle-render change and its resize-while-idle
# corollary) are behavioral, not just compile-and-pass-tests — they need a
# human watching a live terminal, the same reason this project already
# splits phase-6-tui.sh's automated portion from tui-manual-check.sh's
# interactive one. This script follows that same split: an automated part
# you can just run, then printed step-by-step instructions for the two
# checks that can't be scripted.
#
# Usage:
#   git checkout mission/audit-fixes   # or wherever PR #19 landed
#   git pull
#   bash scripts/mac-smoke/audit-fixes-validation.sh
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."
EXIT_CODE=0

echo "=== Audit-Fixes Validation (automated) ==="
echo ""

# -----------------------------------------------------------------------
# 1. Build
# -----------------------------------------------------------------------
echo "--- swift build ---"
if swift build 2>&1 | tee /tmp/audit-fixes-build.log; then
  echo "PASS: swift build"
else
  echo "FAIL: swift build (see /tmp/audit-fixes-build.log)"
  EXIT_CODE=1
fi
echo ""

# -----------------------------------------------------------------------
# 2. The two new test files, run individually first so a failure in one
#    is unambiguous rather than buried in the full suite's output.
# -----------------------------------------------------------------------
echo "--- swift test --filter RecordingStoreTests ---"
echo "(Real filesystem I/O against a temp dir via INNEREAR_DATA_DIR — not"
echo " fake-backed, unlike every other @service test in this project, since"
echo " RecordingStore itself is what's under test.)"
if swift test --filter RecordingStoreTests 2>&1 | tee /tmp/audit-fixes-recordingstore.log; then
  echo "PASS: RecordingStoreTests"
else
  echo "FAIL: RecordingStoreTests (see /tmp/audit-fixes-recordingstore.log)"
  EXIT_CODE=1
fi
echo ""

echo "--- swift test --filter NoNetworkAccessTests ---"
echo "(MTM-2/7 enforcement — fails if any fake-backed pipeline step attempts"
echo " a network request via URLSession's default configuration.)"
if swift test --filter NoNetworkAccessTests 2>&1 | tee /tmp/audit-fixes-nonetwork.log; then
  echo "PASS: NoNetworkAccessTests"
else
  echo "FAIL: NoNetworkAccessTests (see /tmp/audit-fixes-nonetwork.log)"
  EXIT_CODE=1
fi
echo ""

# -----------------------------------------------------------------------
# 3. Full suite — catches anything the two targeted filters above
#    wouldn't (e.g. a regression in an unrelated file from the
#    TranscriptSegment/Transcript signature changes).
# -----------------------------------------------------------------------
echo "--- swift test (full suite) ---"
if swift test 2>&1 | tee /tmp/audit-fixes-fullsuite.log; then
  echo "PASS: full test suite"
else
  echo "FAIL: full test suite (see /tmp/audit-fixes-fullsuite.log)"
  EXIT_CODE=1
fi
echo ""

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "=== Automated checks FAILED — fix before doing the manual checks below ==="
  exit $EXIT_CODE
fi

echo "=== Automated checks PASSED ==="
echo ""
echo "=== Manual checks (need a live terminal — not scriptable) ==="
echo ""
echo "1) IDLE CPU CHECK — validates the TUIRunLoop re-render fix."
echo "   Before this fix, the TUI redrew the ENTIRE screen (including a full"
echo "   transcript re-wrap, if one's open) roughly 6.7x/second forever, even"
echo "   completely idle. After the fix, an idle screen should draw once and"
echo "   then go quiet until you press a key or resize the window."
echo ""
echo "   Steps:"
echo "     a. In THIS terminal: swift run innerear tui"
echo "     b. In a SECOND terminal, find the PID and watch CPU%:"
echo "          pgrep -f 'innerear tui' | xargs -I{} top -pid {} -l 0 -s 1"
echo "        (or: Activity Monitor -> search 'innerear' -> watch % CPU)"
echo "     c. Navigate into Recordings and open any existing transcript in"
echo "        the viewer (press Enter on a row with a transcript). If you"
echo "        don't have one yet, record something short first."
echo "     d. Stop touching the keyboard entirely for ~15 seconds while"
echo "        watching the second terminal's CPU% column."
echo "     e. EXPECT: CPU% for the innerear process drops to near-zero"
echo "        (occasional single-digit blips are fine — that's normal process"
echo "        scheduling noise, not a redraw) within a second or two of you"
echo "        stopping input, and STAYS there while you're not typing."
echo "        Before the fix, CPU% would stay elevated continuously."
echo ""
echo "2) RESIZE-WHILE-IDLE CHECK — validates the fix doesn't over-correct."
echo "   The idle-render skip tracks terminal size separately from app state"
echo "   specifically so a resize is never missed even with zero keystrokes."
echo ""
echo "   Steps (continuing from the same idle session above, still not"
echo "   pressing any key):"
echo "     a. Drag/resize the terminal WINDOW itself (not a keypress —"
echo "        actually grab a window edge, or use your terminal's zoom)."
echo "     b. EXPECT: the TUI's box-drawn borders and layout reflow to the"
echo "        new dimensions immediately, with no keypress needed."
echo "     c. Press 'q' from the nav pane (Tab first if you're in the detail"
echo "        pane) to quit cleanly when done."
echo ""
echo "If both manual checks match EXPECT, PR #19 is good to merge."
