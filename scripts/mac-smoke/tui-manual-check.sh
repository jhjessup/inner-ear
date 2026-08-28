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
=== InnerEar TUI — Manual Verification Checklist (multipane build) ===

This checklist must be run interactively at a real terminal. It cannot be
scripted or piped, because it verifies raw terminal mode, live redraws,
focus/pane transitions, and signal handling — none of which survive
non-interactive input.

1. Build and run:
     swift run innerear tui

2. Initial layout (persistent multipane frame):
   - Confirm the persistent box-drawn frame is visible: top border, title
     bar containing "InnerEar", a top divider, then a left NAV pane
     (Record / Recordings / Settings), a vertical divider, a right DETAIL
     pane, a bottom divider, a key-legend footer, and a bottom border.
   - Confirm the first section ("Record") is initially selected (a `>`
     marker or `[> ]` bracket on that row) and the detail pane shows
     "Press Enter to start a new recording."
   - Confirm no leftover shell echo of your keypresses (raw mode is
     disabling echo).

3. Focus and nav selection:
   - Press Tab. The selection marker on Record should switch to the
     bracket style "[> Record ]" (focused+selected), and the footer
     legend should change to show nav-only hints ([j/k] Select, [Enter]
     Open, [Tab] Detail, [q] Quit).
   - Press j / k. The selection should move between Record, Recordings,
     Settings, clamping at the top (k at Record) and bottom (j at
     Settings).
   - Press Tab again to move focus back into the detail pane. The
     detail-pane footer should now appear (e.g. [Enter] Confirm for the
     Record section).

4. Record a short clip (Record section, in detail pane):
   - With "Record" selected, press Enter. Confirm the detail pane now
     shows the system-audio prompt ("Include system audio? [y/n]").
   - Press n (skip system audio). Confirm the detail pane shows a live
     MM:SS elapsed counter that visibly ticks up about once per second,
     and the footer shows "[s]/[Esc] Stop".
   - While recording, try Tab, j, k, Enter, q. Confirm NOTHING happens
     (state is locked — only s or Esc can stop the recording).
   - Press s to stop. Confirm you land on the "Recording saved: <uuid>"
     screen with the "[Enter] Process now" hint.

5. Process it (Recordings section, pipeline):
   - Press Enter. Confirm the selection jumps to the Recordings section,
     the detail pane shows live status updates "Transcribing..." ->
     "Diarizing..." -> "Summarizing..." that you can actually see
     changing in real time (not just the final state at the end), and
     then the Viewing Results screen with your transcript text.

6. Scroll and export results:
   - Press j repeatedly — confirm the view scrolls down and stops
     cleanly at the end of content (no crash, no garbage lines).
   - Press k repeatedly — confirm it scrolls back up and stops at the
     top.
   - Press e to export. Confirm a "<transcript-uuid>.md" file appears
     in the current directory (check with `ls *.md` after quitting) and
     its content looks like a reasonable markdown transcript/summary.
   - Confirm the "Exporting to ..." / "Exported to: ..." / "[any key]
     Continue" sequence genuinely waits for your keypress — i.e. the
     TUI does NOT resume on its own after a fixed timer.

7. Settings (configurable data directory):
   - Press Tab back to nav, then k until Settings is selected, then
     Enter. Confirm the detail pane shows the current resolved path,
     the "Source: ..." line (env var / config.json / default), and
     "[e] Edit".
   - Press e. The detail pane should switch to an edit prompt with the
     current path prefilled.
   - Type a path (printable ASCII). Confirm characters appear in the
     input.
   - Press Backspace to correct a character; confirm the last character
     is removed (and that backspace on an empty input is a no-op).
   - Press Enter. Confirm the displayed `resolvedPath` updates to the
     new value and the Source line changes to "config.json".
   - Press e to edit again, type a throwaway path, then press Esc
     WITHOUT pressing Enter. Confirm the in-progress edit is discarded
     (the displayed path is unchanged) and the footer returns to the
     Settings viewing legend.
   - Press Esc again from Settings viewing. Confirm the pane focuses
     back to nav, the Settings detail is unchanged (Esc from .viewing
     is a no-op per the plan), and the nav-focused footer is shown.

8. Settings → Recordings cross-section side-effect:
   - After saving a new data directory in step 7, navigate to the
     Recordings section. Confirm the list reloaded from the new
     location (if you pointed it at a fresh dir, it will say "No
     recordings yet.").

9. Signal handling (the part that CANNOT be verified any other way):
   - From any screen, press Ctrl-C.
   - Confirm the program exits immediately AND your terminal is left in
     a normal, usable state: typed characters echo again, and a plain
     `ls` afterward produces normally-formatted output (not run
     together on one line, not silently swallowing keystrokes).
   - Repeat once more, this time sending SIGTERM instead: run
     `swift run innerear tui &` then `kill %1` from another terminal
     tab, and confirm the same clean-terminal-restoration result.

10. Resize (exercises the multipane grid math at non-default sizes):
    - While at any screen, shrink and grow your terminal window
      repeatedly. After each resize, press any key to trigger a
      redraw.
    - Confirm the frame redraws at the new dimensions without leaving
      stale content from the previous size (this is a new risk area
      specific to the multipane layout: nav pane and detail pane must
      stay aligned at every width, and the top/bottom dividers must
      stay flush with the outer borders).
    - At very small sizes (below 60x18), confirm the renderer falls
      back to the single-line "Terminal too small" message and does
      NOT corrupt the screen with a half-rendered multipane frame.

If all 10 steps pass, the TUI is verified. Note any failures with the
exact step number and what you observed when reporting back.
EOF
