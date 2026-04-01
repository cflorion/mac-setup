#!/usr/bin/env bash
#
# bootstrap.sh - First-time setup for a new Mac.
# Can be run standalone via:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/cflorion/mac-setup/main/bootstrap.sh)"
#
# For ongoing updates, use: make update
#
set -euo pipefail

REPO_URL="https://github.com/cflorion/mac-setup.git"
REPO_DIR="$HOME/code/mac-setup"

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

# Clone the repo if not already present (e.g. running via curl one-liner)
if [ ! -d "$REPO_DIR" ]; then
  echo "==> Cloning mac-setup repo..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

echo "==> Running full install via Makefile"
make install

echo "==> Done. Some changes may require logging out or restarting."
