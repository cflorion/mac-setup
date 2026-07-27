#!/usr/bin/env bash
# pwa-helium.sh — Recreate Helium PWA .app shortcuts in ~/Applications/Chromium Apps.localized/.
#
# These are *native* Helium PWAs (installed once via Helium's "Install app" menu,
# same as Google Meet), not launcher-script wrappers. Helium stores them in
# ~/Applications/Chromium Apps.localized/ with an app_mode_loader + app-id.
#
# Why Helium and not Chrome: Google web apps like Google Chat open their external
# links via the parent browser process, bypassing the system default browser — so
# Finicky never sees those clicks and can't route them to Helium. Running the app
# *inside* Helium makes its links open in Helium, which is what we want.
#
# The PWA must already be registered in the Helium profile (it is once you install
# it once via the Helium menu, or via Chrome sync). Launching Helium with --app-id
# then regenerates the missing shortcut on disk — no manual step needed on re-runs.
set -euo pipefail

HELIUM_BIN="/Applications/Helium.app/Contents/MacOS/Helium"
HELIUM_DATA="$HOME/Library/Application Support/net.imput.helium"
SHORTCUTS_DIR="$HOME/Applications/Chromium Apps.localized"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

register_pwa() {
  local name="$1" app_path="$2"

  # Helium can recreate the bundle without registering it with LaunchServices.
  # In that state `open -a /path/to/App.app` fails with kLSNoExecutableErr even
  # though app_mode_loader exists and the bundle signature is valid.
  "$LSREGISTER" -f "$app_path"
  echo "  ✓ ${name}.app registered with LaunchServices."
}

install_pwa() {
  local name="$1" app_id="$2"
  local app_path="$SHORTCUTS_DIR/${name}.app"

  if [ -d "$app_path" ]; then
    echo "  ${name}.app already present."
    register_pwa "$name" "$app_path"
    return 0
  fi

  if [ ! -x "$HELIUM_BIN" ]; then
    echo "  Helium not found, skipping ${name}."
    return 0
  fi

  local prefs="$HELIUM_DATA/Default/Preferences"
  if [ ! -f "$prefs" ] || ! grep -q "$app_id" "$prefs"; then
    echo "  ${name} (id=${app_id}) not registered in Helium profile."
    echo "    Open the URL in Helium, install it via the ⋮ menu > 'Install app…',"
    echo "    then re-run 'make pwa-helium'."
    return 0
  fi

  echo "  Recreating ${name}.app via Helium --app-id..."
  "$HELIUM_BIN" --app-id="$app_id" >/dev/null 2>&1 &
  local helium_pid=$!

  for _ in $(seq 1 30); do
    [ -d "$app_path" ] && break
    sleep 0.5
  done

  # Close the app window Helium opened to regenerate the shortcut.
  kill "$helium_pid" >/dev/null 2>&1 || true

  if [ -d "$app_path" ]; then
    echo "  ✓ ${name}.app created."
    register_pwa "$name" "$app_path"
  else
    echo "  ✗ Failed to create ${name}.app within 15s."
  fi
}

echo "==> Installing Helium PWAs..."
install_pwa "Google Chat" "pommaclcbfghclhalboakcipcmmndhcj"
install_pwa "Google Meet" "kjgfgldnnfoeklkmfkjfagphfepbbdan"
