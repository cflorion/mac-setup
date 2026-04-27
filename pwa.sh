#!/usr/bin/env bash
# pwa.sh — Recreate Chrome PWA .app shortcuts in ~/Applications/Chrome Apps.localized/.
# The PWA must already be registered in the Chrome profile (Chrome sync brings
# this in once the user signs into Chrome with their Google account). Launching
# Chrome with --app-id triggers it to regenerate the missing shortcut on disk.
set -euo pipefail

CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROME_DATA="$HOME/Library/Application Support/Google/Chrome"
SHORTCUTS_DIR="$HOME/Applications/Chrome Apps.localized"

install_pwa() {
  local name="$1" app_id="$2" profile="$3"
  local app_path="$SHORTCUTS_DIR/${name}.app"

  if [ -d "$app_path" ]; then
    echo "  ${name}.app already present, skipping."
    return 0
  fi

  if [ ! -x "$CHROME_BIN" ]; then
    echo "  Google Chrome not found, skipping ${name}."
    return 0
  fi

  local prefs="$CHROME_DATA/$profile/Preferences"
  if [ ! -f "$prefs" ] || ! grep -q "$app_id" "$prefs"; then
    echo "  ${name} (id=${app_id}) not registered in Chrome profile '${profile}'."
    echo "    Sign into Chrome with sync, wait for PWAs to sync, then re-run 'make pwa'."
    return 0
  fi

  echo "  Recreating ${name}.app via Chrome --app-id..."
  "$CHROME_BIN" --profile-directory="$profile" --app-id="$app_id" >/dev/null 2>&1 &

  for _ in $(seq 1 30); do
    [ -d "$app_path" ] && break
    sleep 0.5
  done

  if [ -d "$app_path" ]; then
    echo "  ✓ ${name}.app created."
  else
    echo "  ✗ Failed to create ${name}.app within 15s."
  fi
}

echo "==> Installing Chrome PWAs..."
install_pwa "Google Chat" "pommaclcbfghclhalboakcipcmmndhcj" "Profile 1"
