#!/bin/bash
set -euo pipefail

PAPERLIKE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PAPERLIKE_APP="$HOME/Applications/PaperlikeAgent.app"
PAPERLIKE_LABEL="com.user.paperlike-agent"
PAPERLIKE_PLIST="$HOME/Library/LaunchAgents/$PAPERLIKE_LABEL.plist"
PAPERLIKE_DOMAIN="gui/$(id -u)"

check_owned_app() {
    if [[ -e "$PAPERLIKE_APP" ]]; then
        local identifier
        identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PAPERLIKE_APP/Contents/Info.plist")
        [[ "$identifier" == "$PAPERLIKE_LABEL" ]] || { echo "Application existante non reconnue : $PAPERLIKE_APP" >&2; exit 1; }
    fi
}

stop_agent() {
    launchctl disable "$PAPERLIKE_DOMAIN/$PAPERLIKE_LABEL"
    if launchctl print "$PAPERLIKE_DOMAIN/$PAPERLIKE_LABEL" >/dev/null 2>&1; then
        launchctl bootout "$PAPERLIKE_DOMAIN/$PAPERLIKE_LABEL"
    fi
}

case "${1:-install}" in
    install|install-control)
        bash "$PAPERLIKE_ROOT/apps/paperlike-agent/build.sh"
        check_owned_app
        stop_agent
        mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/.local/bin"
        ditto "$PAPERLIKE_ROOT/cache/paperlike-agent/PaperlikeAgent.app" "$PAPERLIKE_APP"
        codesign --verify --strict "$PAPERLIKE_APP"
        python3 - "$PAPERLIKE_ROOT/launchd/$PAPERLIKE_LABEL.plist" "$PAPERLIKE_PLIST" "$HOME" "${1:-install}" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as source:
    config = plistlib.load(source)
config['ProgramArguments'][0] = config['ProgramArguments'][0].replace('__HOME__', sys.argv[3])
if sys.argv[4] == 'install-control':
    config['ProgramArguments'].append('--control')
with open(sys.argv[2], 'wb') as target:
    plistlib.dump(config, target)
PY
        chmod 644 "$PAPERLIKE_PLIST"
        plutil -lint "$PAPERLIKE_PLIST"
        if [[ ! "$HOME/.local/bin/paperlike" -ef "$PAPERLIKE_ROOT/dotfiles/bin/paperlike" ]]; then
            if [[ -e "$HOME/.local/bin/paperlike" || -L "$HOME/.local/bin/paperlike" ]]; then
                echo "Commande paperlike existante conservée ; utiliser $PAPERLIKE_ROOT/dotfiles/bin/paperlike" >&2
            else
                ln -s "$PAPERLIKE_ROOT/dotfiles/bin/paperlike" "$HOME/.local/bin/paperlike"
            fi
        fi
        launchctl enable "$PAPERLIKE_DOMAIN/$PAPERLIKE_LABEL"
        launchctl bootstrap "$PAPERLIKE_DOMAIN" "$PAPERLIKE_PLIST"
        echo "PaperlikeAgent installé et lancé ; démarrage automatique à l’ouverture de session."
        echo "Diagnostic : paperlike status"
        ;;
    stop)
        stop_agent
        echo "PaperlikeAgent arrêté et désactivé à l’ouverture de session."
        echo "Le tramage macOS va revenir sur le DASUNG : lancer PaperLikeClient pour le retirer."
        ;;
    uninstall)
        check_owned_app
        stop_agent
        rm -f "$PAPERLIKE_PLIST"
        rm -rf "$PAPERLIKE_APP"
        echo "Application et LaunchAgent supprimés. Sources et commande du dépôt conservées."
        echo "Retour au client officiel, nécessaire pour l’anti-tramage : open -a PaperLikeClient"
        ;;
    *) echo "Usage : $0 install|install-control|stop|uninstall" >&2; exit 2 ;;
esac
