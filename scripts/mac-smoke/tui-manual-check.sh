#!/usr/bin/env bash
# =============================================================================
# tui-manual-check.sh — TUI dashboard manual verification instructions
# =============================================================================
# TerminalIO.swift's raw-mode/signal/resize behavior can only be verified by
# a human at a real interactive terminal — canned/piped input can't exercise
# non-canonical mode, live redraws, or Ctrl-C signal handling. This script is
# deliberately NOT named phase-*.sh, so verify-on-mac.sh's automated smoke
# runner will NOT pick it up; run it yourself, by hand, in an actual
# Terminal.app/iTerm session (not over a piped SSH command).
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/../.."

cat <<'EOF'
=== InnerEar TUI — Manual Verification Checklist ===

This checklist must be run interactively at a real terminal. It cannot be
scripted or piped, because it verifies raw terminal mode, live redraws, and
signal handling — none of which survive non-interactive input.

1. Build and run:
     swift run innerear tui

2. Main menu:
   - Confirm you see "InnerEar", "[1] Record", "[2] Browse Recordings", "[q] Quit".
   - Confirm no leftover shell echo of your keypresses (raw mode is disabling echo).

3. Record a short clip:
   - Press "1", then "n" (skip system audio, simplest path).
   - Confirm the elapsed timer (MM:SS) visibly counts up once per second-ish.
   - Press "s" to stop. Confirm you land on "Recording saved: <uuid>".

4. Process it:
   - Press Enter. Confirm status line updates through
     "Transcribing..." -> "Diarizing..." -> "Summarizing..." and then shows
     the Viewing Results screen with your transcript text.

5. Scroll:
   - Press "j" repeatedly — confirm the view scrolls down and stops cleanly
     at the end of content (no crash, no garbage lines).
   - Press "k" repeatedly — confirm it scrolls back up and stops at the top.

6. Export:
   - Press "e". Confirm a "<transcript-uuid>.md" file appears in the current
     directory (check with `ls *.md` after quitting) and its content looks
     like a reasonable markdown transcript/summary.

7. Browse:
   - Press "b" to return to the main menu, then "2" to browse recordings.
     Confirm your just-created recording appears in the list with a "> "
     prefix on the selected row, and that "j"/"k" move the selection.

8. Back navigation:
   - From every screen, confirm "[b] Back" (where shown) returns to the main
     menu without crashing or corrupting the display.

9. Signal handling (the part that CANNOT be verified any other way):
   - From any screen, press Ctrl-C.
   - Confirm the program exits immediately AND your terminal is left in a
     normal, usable state: typed characters echo again, and a plain `ls`
     afterward produces normally-formatted output (not run together on one
     line, not silently swallowing keystrokes).
   - Repeat once more, this time sending SIGTERM instead: run
     `swift run innerear tui &` then `kill %1` from another terminal tab,
     and confirm the same clean-terminal-restoration result.

10. Resize:
    - While at the main menu, resize your terminal window, then press any
      key to trigger a redraw. Confirm the layout adapts to the new
      width/height (no leftover garbage from the old size).

If all 10 steps pass, the TUI is verified. Note any failures with the exact
step number and what you observed when reporting back.
EOF
