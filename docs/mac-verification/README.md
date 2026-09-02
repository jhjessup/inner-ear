# Mac verification logs

This directory is an append-only log of `scripts/verify-on-mac.sh` runs —
raw output from building, testing, and smoke-checking InnerEar on real Mac
hardware (Core ML / WhisperKit / SpeakerKit only run for real on a Mac, so
this project's CI can't cover that surface; a human runs this script on a
Mac after pulling a branch, see the script header for usage).

These are internal development records, not user-facing documentation —
kept for project history rather than deleted, but you don't need to read
any of this to build, run, or contribute to InnerEar. Start with the root
[`README.md`](../../README.md) instead.

Each file is named `<phase-label>-<UTC timestamp>.md` and is immutable once
written; nothing in here is edited after the fact, only appended to.
`scaffold-20260827T185515Z.md` is the oldest entry (from before the script
moved to this per-run, dated-file convention — it originally lived at the
repo root as `MAC_VERIFY_RESULTS.md`).
