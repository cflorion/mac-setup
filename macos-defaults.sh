#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/macos/finder.sh"
source "$SCRIPT_DIR/macos/dock.sh"
source "$SCRIPT_DIR/macos/keyboard.sh"
source "$SCRIPT_DIR/macos/trackpad.sh"
source "$SCRIPT_DIR/macos/mission-control.sh"
source "$SCRIPT_DIR/macos/desktop.sh"
source "$SCRIPT_DIR/macos/control-center.sh"
source "$SCRIPT_DIR/macos/pointer.sh"

echo "==> Restarting system services"
killall Finder || true
killall SystemUIServer || true
killall Dock || true

# -----------------------------------------------------------------------------
# TODO
# -----------------------------------------------------------------------------

# Security
# - Allow apps from identified developers / external sources

# Apps to install
# - SwitchResX (display resolution)
# - DisplayBuddy
# - Adobe Acrobat Reader
