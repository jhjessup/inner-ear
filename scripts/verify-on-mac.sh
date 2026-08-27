#!/usr/bin/env bash
# =============================================================================
# verify-on-mac.sh — One-shot macOS verification for InnerEar
# =============================================================================
# Run this on a real Mac after pulling a branch. It batches every
# Mac-only step (build, test, CLI smoke checks) into a single script,
# writes a results file, and commits + pushes it back to the current
# branch so the results can be reviewed from anywhere else.
#
# Usage:
#   git checkout <branch>
#   git pull
#   bash scripts/verify-on-mac.sh
# =============================================================================
set -uo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"
RESULTS_FILE="MAC_VERIFY_RESULTS.md"
LOG_DIR="$(mktemp -d)"
BRANCH="$(git branch --show-current)"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

STEPS_RUN=()
STEPS_STATUS=()

run_step() {
  local label="$1"; shift
  local logfile="$LOG_DIR/$(echo "$label" | tr ' /' '__').log"
  echo "== $label =="
  if "$@" > "$logfile" 2>&1; then
    echo "PASS: $label"
    STEPS_RUN+=("$label"); STEPS_STATUS+=("PASS")
  else
    local code=$?
    echo "NON-ZERO EXIT ($code): $label (see log below — some steps, like unimplemented CLI commands, are expected to fail)"
    STEPS_RUN+=("$label"); STEPS_STATUS+=("EXIT_$code")
  fi
  echo "--- log: $label ---" >> "$RESULTS_FILE.tmp"
  cat "$logfile" >> "$RESULTS_FILE.tmp"
  echo "" >> "$RESULTS_FILE.tmp"
}

echo "" > "$RESULTS_FILE.tmp"

echo "Toolchain versions..."
{
  echo "swift: $(swift --version 2>&1 | head -1)"
  echo "xcodebuild: $(xcodebuild -version 2>&1 | head -1)"
  echo "macOS: $(sw_vers -productVersion 2>&1)"
  echo "arch: $(uname -m)"
} > "$LOG_DIR/versions.log"

run_step "swift build" swift build -v
run_step "swift test" swift test -v
run_step "innerear --version" swift run innerear --version
run_step "innerear --help" swift run innerear --help
run_step "innerear record (expect not-yet-implemented)" swift run innerear record
run_step "innerear transcribe (expect not-yet-implemented)" swift run innerear transcribe /tmp/nonexistent.wav
run_step "innerear export (expect not-yet-implemented)" swift run innerear export fake-id --format markdown

{
  echo "# Mac Verification Results"
  echo ""
  echo "- **Branch:** \`$BRANCH\`"
  echo "- **Commit:** \`$(git rev-parse HEAD)\`"
  echo "- **Timestamp (UTC):** $TIMESTAMP"
  echo ""
  echo "## Toolchain"
  echo '```'
  cat "$LOG_DIR/versions.log"
  echo '```'
  echo ""
  echo "## Step Results"
  echo ""
  echo "| Step | Result |"
  echo "|---|---|"
  for i in "${!STEPS_RUN[@]}"; do
    echo "| ${STEPS_RUN[$i]} | ${STEPS_STATUS[$i]} |"
  done
  echo ""
  echo "\`swift build\`/\`swift test\` should be PASS. The three \`innerear\` command"
  echo "steps are expected to show a non-zero exit (EXIT_1) right now — they're"
  echo "stubs pending real service implementations (see docs/XCODE_SETUP.md)."
  echo "Full logs below."
  echo ""
  cat "$RESULTS_FILE.tmp"
} > "$RESULTS_FILE"

rm -f "$RESULTS_FILE.tmp"
rm -rf "$LOG_DIR"

echo ""
echo "Wrote $RESULTS_FILE. Committing and pushing..."

git add "$RESULTS_FILE"
git commit -m "chore: mac verification results ($TIMESTAMP)"
git push origin "$BRANCH"

echo ""
echo "Done. Results pushed to $BRANCH."
