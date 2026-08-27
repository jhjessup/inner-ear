#!/usr/bin/env bash
# =============================================================================
# verify-on-mac.sh — One-shot macOS verification for InnerEar
# =============================================================================
# Run this on a real Mac after pulling a branch. It batches every
# Mac-only step (toolchain repair, build, test, CLI smoke checks) into a
# single script, writes a results file, and commits + pushes it back to the
# current branch so the results can be reviewed from anywhere else.
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

REPAIR_LOG="$LOG_DIR/toolchain-repair.log"
: > "$REPAIR_LOG"

# ---------------------------------------------------------------------------
# Toolchain repair: full Xcode is NOT required for `swift build`/`test`/`run`
# on a plain SPM package in principle — Command Line Tools alone is a
# normal, supported setup for `swift build`/`run`. `swift test` is a
# separate story: it needs either XCTest.framework or the `Testing` module,
# and on at least one observed CLT/macOS combo, CLT ships neither — both
# are otherwise only guaranteed bundled with full Xcode. Probing with
# `swift test` (a superset of `swift build`) catches that in addition to
# the known manifest/PackageDescription-link failure, and both are worth
# trying the same automatic fixes on before giving up.
# ---------------------------------------------------------------------------
probe_swift_test() {
  swift test > "$1" 2>&1
}

is_known_toolchain_failure() {
  grep -qE "Package\.__allocating_init|Invalid manifest|no such module 'Testing'|no such module 'XCTest'" "$1" 2>/dev/null
}

ensure_working_toolchain() {
  local probe_log="$LOG_DIR/toolchain-probe.log"

  if probe_swift_test "$probe_log"; then
    echo "Toolchain OK — swift test succeeds." | tee -a "$REPAIR_LOG"
    return 0
  fi

  if ! is_known_toolchain_failure "$probe_log"; then
    {
      echo "Initial swift test failed, but not with a known CLT toolchain-gap"
      echo "signature (manifest-link failure, or missing Testing/XCTest module)."
      echo "Likely a real build/test failure rather than a toolchain problem —"
      echo "proceeding to the normal step-by-step run so it's captured with full"
      echo "detail in the results file rather than treated as a toolchain abort."
    } | tee -a "$REPAIR_LOG"
    return 0
  fi

  {
    echo "Detected known CLT/manifest-link toolchain issue. Attempting automatic fixes."
    echo ""
    echo "--- Attempt 1: install/switch to an official Swift.org toolchain via swiftly (no sudo) ---"
  } | tee -a "$REPAIR_LOG"

  if ! command -v swiftly >/dev/null 2>&1; then
    # Official swift.org-documented macOS install: a signed .pkg installed to
    # the user's home directory (no sudo). A prior raw-script URL used here
    # 404'd — this is the documented method from https://swift.org/install.
    if curl -sL -o "$LOG_DIR/swiftly.pkg" https://download.swift.org/swiftly/darwin/swiftly.pkg >> "$REPAIR_LOG" 2>&1; then
      installer -pkg "$LOG_DIR/swiftly.pkg" -target CurrentUserHomeDirectory >> "$REPAIR_LOG" 2>&1 || true
      [[ -x "$HOME/.swiftly/bin/swiftly" ]] && "$HOME/.swiftly/bin/swiftly" init --quiet-shell-followup --assume-yes >> "$REPAIR_LOG" 2>&1 || true
    else
      echo "Could not download swiftly.pkg from download.swift.org." | tee -a "$REPAIR_LOG"
    fi
  fi
  [[ -f "$HOME/.swiftly/env.sh" ]] && source "$HOME/.swiftly/env.sh"
  export PATH="$HOME/.swiftly/bin:$PATH"

  if command -v swiftly >/dev/null 2>&1; then
    swiftly install latest --assume-yes >> "$REPAIR_LOG" 2>&1 || true
    swiftly use latest >> "$REPAIR_LOG" 2>&1 || true
  else
    {
      echo "swiftly installation itself failed — skipping to next fix attempt."
      echo "Manual fallback, if this keeps failing (run yourself, then re-run this script):"
      echo "  curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg"
      echo "  installer -pkg swiftly.pkg -target CurrentUserHomeDirectory"
      echo "  ~/.swiftly/bin/swiftly init --quiet-shell-followup --assume-yes"
      echo "  . ~/.swiftly/env.sh"
      echo "  swiftly install latest && swiftly use latest"
    } | tee -a "$REPAIR_LOG"
  fi

  if probe_swift_test "$probe_log"; then
    echo "FIXED via swiftly toolchain: $(swift --version 2>&1 | head -1)" | tee -a "$REPAIR_LOG"
    return 0
  fi

  {
    echo ""
    echo "--- Attempt 2: reinstall Command Line Tools (needs sudo; best effort) ---"
  } | tee -a "$REPAIR_LOG"

  if sudo -n true 2>/dev/null; then
    sudo rm -rf /Library/Developer/CommandLineTools
    xcode-select --install >> "$REPAIR_LOG" 2>&1 || true
    {
      echo "Triggered a fresh Command Line Tools install. If a GUI 'Install' prompt"
      echo "appeared, this will only complete once it's clicked through. Waiting up"
      echo "to 10 minutes for the tools to reappear as installed..."
    } | tee -a "$REPAIR_LOG"
    for _ in $(seq 1 60); do
      [[ -d /Library/Developer/CommandLineTools/usr ]] && break
      sleep 10
    done
    if probe_swift_test "$probe_log"; then
      echo "FIXED via Command Line Tools reinstall." | tee -a "$REPAIR_LOG"
      return 0
    fi
  else
    {
      echo "Passwordless sudo not available — cannot automate the CLT reinstall"
      echo "(needs your password and a GUI 'Install' click). Run manually:"
      echo "  sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install"
    } | tee -a "$REPAIR_LOG"
  fi

  {
    echo ""
    echo "Automatic fixes did not resolve the toolchain issue. Last probe log:"
    cat "$probe_log"
  } | tee -a "$REPAIR_LOG"
  return 1
}

if ! ensure_working_toolchain; then
  echo ""
  echo "Aborting before build/test — toolchain is not in a working state."
  echo "See $REPAIR_LOG contents (also written into $RESULTS_FILE below)."
  {
    echo "# Mac Verification Results — TOOLCHAIN REPAIR FAILED"
    echo ""
    echo "- **Branch:** \`$BRANCH\`"
    echo "- **Commit:** \`$(git rev-parse HEAD)\`"
    echo "- **Timestamp (UTC):** $TIMESTAMP"
    echo ""
    echo "swift build/test were not attempted — the toolchain itself is broken."
    echo "See repair log below."
    echo ""
    echo '```'
    cat "$REPAIR_LOG"
    echo '```'
  } > "$RESULTS_FILE"
  git add "$RESULTS_FILE"
  git commit -m "chore: mac verification — toolchain repair failed ($TIMESTAMP)"
  git push origin "$BRANCH"
  exit 1
fi

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
  echo "## Toolchain Repair Log"
  echo '```'
  cat "$REPAIR_LOG"
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
