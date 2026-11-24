#!/usr/bin/env bash
# Build EyeBreak.app from EyeBreak.swift and install it in ~/Applications.
# Needs only the Xcode Command Line Tools (swiftc); no Xcode project.
set -euo pipefail

cd "$(dirname "$0")"
APP="build/EyeBreak.app"
DEST="$HOME/Applications/EyeBreak.app"

rm -rf build
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
swiftc -O -framework AppKit -o "$APP/Contents/MacOS/EyeBreak" EyeBreak.swift
codesign --force --sign - "$APP"

mkdir -p "$HOME/Applications"
pkill -x EyeBreak 2>/dev/null || true
rm -rf "$DEST"
cp -R "$APP" "$DEST"
echo "  Installed $DEST"
