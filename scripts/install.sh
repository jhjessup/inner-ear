#!/usr/bin/env bash
# =============================================================================
# install.sh — Build a release binary and install it as `innerear` on PATH.
# =============================================================================
# Run once after cloning (and again after pulling updates you want to pick
# up). Afterwards, just run `innerear` from anywhere — no more `swift run`.
#
# Usage:
#   scripts/install.sh                  # installs to /usr/local/bin
#   INSTALL_DIR=~/.local/bin scripts/install.sh   # installs somewhere else
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
BINARY_NAME="innerear"

echo "Building release binary (this can take a while the first time)..."
swift build -c release

BUILT_BINARY="$(swift build -c release --show-bin-path)/$BINARY_NAME"
if [[ ! -f "$BUILT_BINARY" ]]; then
  echo "Error: expected binary not found at $BUILT_BINARY" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

DEST="$INSTALL_DIR/$BINARY_NAME"
if [[ -w "$INSTALL_DIR" ]]; then
  cp "$BUILT_BINARY" "$DEST"
else
  echo "No write access to $INSTALL_DIR — using sudo to copy the binary."
  sudo cp "$BUILT_BINARY" "$DEST"
fi

echo ""
echo "Installed: $DEST"

if ! command -v "$BINARY_NAME" >/dev/null 2>&1; then
  echo ""
  echo "Note: $INSTALL_DIR doesn't appear to be on your PATH yet."
  echo "Add this to your shell profile (~/.zshrc, ~/.bash_profile, etc.):"
  echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
else
  echo "Run 'innerear' from anywhere to launch the TUI."
fi
