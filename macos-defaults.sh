#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuring Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

echo "==> Configuring Dock settings"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock tilesize -int 60

echo "==> Hiding menu bar"
defaults write NSGlobalDomain _HIHideMenuBar -bool true

echo "==> Configuring keyboard"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

echo "==> Enabling tap to click"
# Built-in trackpad
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Magic Trackpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Current user
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Login screen
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

echo "==> Rebuilding Dock"
if command -v dockutil >/dev/null 2>&1; then
  dockutil --no-restart --remove all
  dockutil --no-restart --add "$HOME/Downloads" --view grid --display folder
else
  echo "dockutil not installed, skipping Dock configuration"
fi

echo "==> Hiding Finder tags in sidebar"
defaults write com.apple.finder ShowRecentTags -bool false

echo "==> Setting wallpaper"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
osascript <<EOF
tell application "System Events"
  tell every desktop
    set picture to "$SCRIPT_DIR/wallpapers/black-white-dynamic.heic"
  end tell
end tell
EOF

echo "==> Configuring accessibility"
defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess increaseContrast -bool true

echo "==> Restarting system services"
killall Finder || true
killall SystemUIServer || true
killall Dock || true

# -----------------------------------------------------------------------------
# TODO
# -----------------------------------------------------------------------------

# Security
# - Allow apps from identified developers / external sources

# Accessibility
# - Grayscale color filter (100%)
# - Reduce transparency
# - Slightly increase pointer size
# - Differentiate without color

# Apps to install
# - DisplayBuddy
# - Zoom
# - Obsidian
# - StillColor
# - Adobe Acrobat Reader
