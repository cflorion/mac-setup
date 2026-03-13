#!/usr/bin/env bash
#
# bootstrap.sh - First-time setup for a new Mac.
# For ongoing updates, use: make update
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Checking sudo access"
sudo -v

# Optional: uncomment to run macOS software updates
# echo "==> Updating macOS"
# sudo softwareupdate --install --all || true

echo "==> Installing Command Line Tools if missing"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "Command Line Tools may require graphical confirmation."
  echo "Run this script again after installation if needed."
  exit 1
fi

echo "==> Installing Homebrew if missing"
if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "==> Loading Homebrew into the shell"
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "==> Creating code workspace"
mkdir -p "$HOME/code"

echo "==> Running full install via Makefile"
make install

echo "==> Done. Some changes may require logging out or restarting."