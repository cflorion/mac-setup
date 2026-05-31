#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Disable Spotlight keyboard shortcuts (free Cmd+Space for Raycast)
# -----------------------------------------------------------------------------

echo "==> Disabling Spotlight keyboard shortcuts"

HOTKEYS_PLIST="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"

# Spotlight Search (Cmd+Space) — ID 64
/usr/libexec/PlistBuddy -c "Set ':AppleSymbolicHotKeys:64:enabled' false" "$HOTKEYS_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add ':AppleSymbolicHotKeys:64:enabled' bool false" "$HOTKEYS_PLIST"

# Spotlight Finder Search (Cmd+Alt+Space) — ID 65
/usr/libexec/PlistBuddy -c "Set ':AppleSymbolicHotKeys:65:enabled' false" "$HOTKEYS_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add ':AppleSymbolicHotKeys:65:enabled' bool false" "$HOTKEYS_PLIST"

# Apply changes immediately
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null \
  || killall SystemUIServer || true

# -----------------------------------------------------------------------------
# Install Raycast extensions (opens browser → Raycast install prompt)
# -----------------------------------------------------------------------------

echo "==> Opening Raycast extensions for installation..."
echo "   (confirm each install in Raycast when prompted)"

open "https://raycast.com/raycast/github"           # GitHub
open "https://raycast.com/nhojb/brew"               # Brew
open "https://raycast.com/thomas/color-picker"      # Color Picker
open "https://raycast.com/lucaschultz/port-manager" # Port Manager
open "https://raycast.com/rolandleth/kill-process"  # Kill Process
open "https://raycast.com/raycast/google-workspace" # Google Workspace (Calendar, Drive, Mail)

# -----------------------------------------------------------------------------
# Import Raycast settings from dotfiles
# -----------------------------------------------------------------------------

echo "==> Importing Raycast settings..."

# Exports are named "Raycast YYYY-MM-DD HH.MM.SS.rayconfig" — pick the newest
# by lexical sort (date-named, so lexical order == chronological order).
RAYCAST_CONFIG="$(ls "$HOME"/.config/raycast/*.rayconfig 2>/dev/null | sort | tail -1)"

if [[ -n "$RAYCAST_CONFIG" && -f "$RAYCAST_CONFIG" ]]; then
    open "raycast://extensions/raycast/raycast/import-settings-data?path=$(realpath "$RAYCAST_CONFIG")"
    echo "   Settings imported from $RAYCAST_CONFIG"
else
    echo "   No .rayconfig found in ~/.config/raycast — skipping import"
fi

# -----------------------------------------------------------------------------
# TODO (manual steps)
# -----------------------------------------------------------------------------

# - Set Raycast hotkey to Cmd+Space in Raycast Settings > General
# - Theme: "Auto" (follows system) — default, no action needed
