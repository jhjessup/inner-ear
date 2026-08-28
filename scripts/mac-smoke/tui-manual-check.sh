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
   - Confirm a progress bar ("[████░░░░░░...]") and a "Step N of 3" line
     appear alongside each status update, and that the bar visibly fills
     further at each of the 3 steps (Transcribing = 1/3 filled,
     Diarizing = 2/3, Summarizing = full). The BAR itself does NOT animate
     smoothly within a step (it only jumps between steps) — that part is
     expected, not a bug.
   - During the Transcribing step specifically, confirm the STATUS LINE
     (not the bar) updates live and repeatedly: "Transcribing... (12
     words so far)" -> "Transcribing... (37 words so far)" -> etc.,
     genuinely increasing roughly every 0.2-1s while WhisperKit is
     decoding, not just frozen at one number until the step completes.
     This comes from a real WhisperKit progress callback that can fire
     from a background thread — if the app hangs, crashes, or the
     terminal display corrupts/garbles specifically during this step
     (as opposed to just not updating), that's the concurrency risk this
     feature was reviewed for; report the exact symptom. Diarizing and
     Summarizing do NOT get live word counts (out of scope for this
     pass) — only their static status line + bar-step-jump is expected.

6. Scroll and export results:
   - Confirm each line of the transcript is RENDERED, not echoed: every
     segment shows its own "[MM:SS] SpeakerLabel: text" prefix, not just
     a flat wall of concatenated text.
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

6a. Recordings list: attributes, browsing an existing recording, delete:
   - Press Esc from the results screen, then Esc again to return to nav,
     then Enter back into Recordings. Confirm your just-processed
     recording now shows an "[AT]" marker (both audio and transcript
     present) next to its title.
   - Confirm the attribute bar below the list shows "Captured: ...", an
     "Audio: <full path>" line, and a "Transcript: <full path>" line for
     whichever row is currently highlighted — move the j/k selection and
     confirm the attribute bar updates live to match.
   - Record a SECOND short clip (Tab to nav, k to Record, Enter, n, wait
     a couple seconds, s to stop) but do NOT process it — press Esc
     instead of Enter on the "Recording saved" screen. Navigate to
     Recordings: confirm this second entry shows an "[A-]" marker (audio
     only, no transcript yet).
   - Select the "[A-]" entry and press Enter. Confirm a prompt appears:
     "<title>" has no transcript yet. Generate one now? [y/n]" — NOT an
     immediate pipeline run. Press n (or Esc): confirm it returns to the
     list unchanged. Press Enter again, then y this time: confirm the
     pipeline now runs (Transcribing.../Diarizing.../Summarizing...) and
     lands on the results screen, exactly like the already-transcribed
     path.
   - Back in the list, select any entry and press d. Confirm a prompt
     appears: "Delete for "<title>": [a] Audio only  [t] Transcript
     only  [b] Both  [Esc] Cancel". Press Esc: confirm nothing was
     deleted and you're back at the list. Press d again, then t: confirm
     the entry's marker changes to "[A-]" (transcript gone, audio still
     present) and the attribute bar's Transcript line now reads "not yet
     generated". Press d, then a: confirm the marker changes to "[--]"
     and — since NEITHER audio nor transcript remains — the entry
     disappears from the list entirely on the next reload (this is the
     "orphaned catalog entry" cleanup; if it doesn't disappear, that's a
     bug to report).

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
   - From any screen NOT actively recording, press Ctrl-C.
   - Confirm the program exits immediately AND your terminal is left in
     a normal, usable state: typed characters echo again, and a plain
     `ls` afterward produces normally-formatted output (not run
     together on one line, not silently swallowing keystrokes).
   - Repeat once more, this time sending SIGTERM instead: run
     `swift run innerear tui &` then `kill %1` from another terminal
     tab, and confirm the same clean-terminal-restoration result.
   - Now start a recording (Record -> Enter -> n) and, WHILE it's
     actively recording, press Ctrl-C. Confirm the terminal still
     restores cleanly (same checks as above — this may take up to ~3
     seconds since it now tries to save the in-progress recording
     first, rather than exiting instantly). Relaunch `swift run innerear
     tui` and check the Recordings list: the recording you were making
     when you hit Ctrl-C should now appear in the list with an audio
     file (the "[A-]" marker) — confirm it is NOT silently lost.

9a. Arrow keys:
   - At the main menu (nav focused), press the Down arrow and Up arrow.
     Confirm they move the selection exactly like j/k.
   - Inside the Recordings list, press Down/Up. Confirm they move the
     row selection like j/k.
   - Inside a viewed transcript, press Down/Up. Confirm they scroll like
     j/k.
   - Press a bare Esc (not part of an arrow sequence) somewhere it's
     meaningful (e.g. Settings editing). Confirm Esc still behaves
     normally and isn't misinterpreted as part of an arrow sequence.

9b. Scrollback:
   - After using the TUI for a while (several screen changes), quit with
     q from the main menu. Scroll UP in your terminal's normal
     scrollback (mouse wheel or Shift+PageUp). Confirm you do NOT see a
     stream of old TUI frames in scrollback — scrollback should show
     whatever was in your terminal BEFORE you launched `innerear tui`,
     with no TUI redraw frames mixed in.

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

If all steps pass, the TUI is verified. Note any failures with the
exact step number and what you observed when reporting back.
EOF
