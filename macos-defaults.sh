#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuring Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true

echo "==> Configuring Dock settings"
defaults write com.apple.dock tilesize -int 36
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock orientation -string "bottom"
defaults write com.apple.dock mineffect -string "genie"
defaults write com.apple.dock dblclickbehavior -string "Zoom"
defaults write com.apple.dock minimize-to-application -bool false
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock show-process-indicators -bool false
defaults write com.apple.dock show-recents -bool false

echo "==> Configuring menu bar"
# Auto-hide menu bar: always
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# Recent documents, apps, servers: none (0)
defaults write NSGlobalDomain NSRecentDocumentsLimit -int 0
defaults write com.apple.recentitems RecentDocuments -dict MaxAmount 0
defaults write com.apple.recentitems RecentApplications -dict MaxAmount 0
defaults write com.apple.recentitems RecentServers -dict MaxAmount 0

echo "==> Configuring keyboard"
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

echo "==> Configuring Trackpad (Pointer & Click)"
# Tracking speed (~75% — value range 0-3)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.5

# Click pressure: medium (1)
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 1
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad FirstClickThreshold -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad SecondClickThreshold -int 1

# Silent clicking: ON
defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ActuationStrength -int 0

# Force click and haptic feedback: ON
defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad ForceSuppressed -bool false

# Look up & data detectors: off (0 = disabled)
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0

# Secondary click: click or tap with 2 fingers (1)
defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
defaults write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true

# Tap to click: ON (built-in trackpad)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
# Tap to click: ON (Magic Trackpad)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
# Tap to click: current user
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
# Tap to click: login screen
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

echo "==> Configuring Trackpad (More Gestures)"
# Swipe between pages: disabled (0)
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerHorizSwipeGesture -int 0

# Swipe between full-screen apps: disabled (0)
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture -int 0

# Notification Center: ON (swipe left from right edge with 2 fingers)
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3

# Mission Control gesture: disabled (0)
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerVertSwipeGesture -int 0

# App Exposé gesture: disabled (0)
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerVertSwipeGesture -int 0

# Launchpad (pinch with thumb and 3 fingers): OFF
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFiveFingerPinchGesture -int 0

# Show Desktop (spread with thumb and 3 fingers): ON
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerPinchGesture -int 2
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerPinchGesture -int 2

echo "==> Configuring Mission Control"
# Do not auto-rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false
# Do not switch to a Space with open windows when switching apps
defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool false
# Group windows by application
defaults write com.apple.dock expose-group-apps -bool true
# Displays do not have separate Spaces
defaults write com.apple.spaces spans-displays -bool false
# Do not drag windows to top of screen to trigger Mission Control
defaults write com.apple.dock mcx-expose-disabled -bool true

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

echo "==> Configuring Desktop & Stage Manager"
# Show items on desktop: ON
defaults write com.apple.finder CreateDesktop -bool true
# Show items in Stage Manager: OFF
defaults write com.apple.windowmanager AutoHide -bool false
# Click wallpaper to reveal desktop: only in Stage Manager
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
# Stage Manager: OFF
defaults write com.apple.WindowManager GloballyEnabled -bool false
# Show recent apps in Stage Manager: OFF
defaults write com.apple.WindowManager HideDesktop -bool false
defaults write com.apple.WindowManager ShowRecentApps -bool false
# Show app windows: all at once (En une fois)
defaults write com.apple.WindowManager AppWindowGroupingBehavior -bool false

echo "==> Disabling hot corners"
defaults write com.apple.dock wvous-tl-corner -int 1
defaults write com.apple.dock wvous-tr-corner -int 1
defaults write com.apple.dock wvous-bl-corner -int 1
defaults write com.apple.dock wvous-br-corner -int 1
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-modifier -int 0

echo "==> Configuring Control Center"
# Wi-Fi: show in menu bar
defaults write com.apple.controlcenter NSStatusItem Visible WiFi -bool true

# Bluetooth: do not show in menu bar
defaults write com.apple.controlcenter NSStatusItem Visible Bluetooth -bool false

# AirDrop: do not show in menu bar
defaults write com.apple.controlcenter NSStatusItem Visible AirDrop -bool false

# Focus/Concentration: show when active
defaults write com.apple.controlcenter NSStatusItem Visible FocusModes -bool true
defaults -currentHost write com.apple.controlcenter FocusModes 2

# Stage Manager: do not show in menu bar
defaults write com.apple.controlcenter NSStatusItem Visible StageManager -bool false

# Screen Mirroring: do not show in menu bar
defaults write com.apple.controlcenter NSStatusItem Visible ScreenMirroring -bool false

# Display/Brightness: do not show in menu bar
defaults write com.apple.controlcenter NSStatusItem Visible Display -bool false

# Sound: show when active
defaults write com.apple.controlcenter NSStatusItem Visible Sound -bool true
defaults -currentHost write com.apple.controlcenter Sound 2

# Now Playing: do not show in menu bar
defaults write com.apple.controlcenter NSStatusItem Visible NowPlaying -bool false

# Accessibility Shortcuts: hide from menu bar and control center
defaults -currentHost write com.apple.controlcenter AccessibilityShortcuts 0

# Keyboard Brightness: hide from menu bar and control center
defaults -currentHost write com.apple.controlcenter KeyboardBrightness 0

# Spotlight: do not show in menu bar
defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true

# Siri: do not show in menu bar
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri UserHasDeclinedEnable -bool true

# Time Machine: do not show in menu bar
defaults write com.apple.TimeMachine ShowStatusItem -bool false

# Weather: do not show in menu bar
defaults write com.apple.weather menuBarIconEnabled -bool false

# Battery: show in menu bar, not in control center, show percentage, show energy mode when active
defaults write com.apple.controlcenter NSStatusItem Visible Battery -bool true
defaults -currentHost write com.apple.controlcenter Battery 1
defaults write com.apple.menuextra.battery ShowPercent -bool true
defaults write com.apple.menuextra.battery ShowTime -bool false
defaults write com.apple.menuextra.battery PowerModeShowOnlyOnBattery -bool true

echo "==> Configuring pointer"
# Shake to locate pointer: OFF
defaults write NSGlobalDomain CGDisableCursorLocationMagnification -bool true
# Pointer size: ~1.5 (range 1.0 normal to 4.0 large)
defaults write com.apple.universalaccess mouseDriverCursorSize -float 1.5

echo "==> Accessibility settings (manual)"
echo "    Please configure in System Settings > Accessibility > Display:"
echo "    - Increase contrast: ON"
echo "    - Reduce transparency: ON"
echo "    - Display contrast: 50% (midpoint)"

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
