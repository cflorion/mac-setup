#!/bin/sh
# Invoked by dark-notify (see ~/Library/LaunchAgents/com.user.sketchybar-theme.plist)
# with the new appearance ("light" or "dark") as $1. Ignored — we just reload so
# sketchybar re-evaluates its Lua palette.
exec /opt/homebrew/bin/sketchybar --reload
