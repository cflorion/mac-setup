#!/usr/bin/env bash
#
# amphetamine-power-protect.sh - Install Amphetamine's Power Protect feature.
# Needed for Closed-Display Mode on Apple Silicon Mac laptops.
# https://github.com/x74353/Amphetamine-Power-Protect
#
set -euo pipefail

SCPT_DIR="$HOME/Library/Application Scripts/com.if.Amphetamine"
SUDOERS_FILE="/private/etc/sudoers.d/amphetamine_PowerProtect"

if [ -f "$SCPT_DIR/powerProtect.scpt" ] && [ -f "$SUDOERS_FILE" ]; then
  echo "==> Power Protect is already installed, skipping."
  exit 0
fi

echo "==> Installing Amphetamine Power Protect..."

DMG_URL="https://github.com/x74353/Amphetamine-Power-Protect/raw/main/DMG/Power%20Protect%20for%20Amphetamine.dmg"
DMG_PATH="/tmp/PowerProtect.dmg"
MOUNT_POINT="/Volumes/Power Protect"

echo "  Downloading Power Protect DMG..."
curl -sL "$DMG_URL" -o "$DMG_PATH"

echo "  Mounting DMG..."
hdiutil attach "$DMG_PATH" -nobrowse -quiet

echo "  Installing package (requires sudo)..."
sudo installer -pkg "$MOUNT_POINT/Install Power Protect.pkg" -target /

echo "  Cleaning up..."
hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$DMG_PATH"

echo "==> Power Protect installed successfully!"
