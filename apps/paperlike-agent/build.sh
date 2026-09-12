#!/bin/bash
set -euo pipefail

PAPERLIKE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PAPERLIKE_CACHE="$PAPERLIKE_ROOT/cache/paperlike-agent"
PAPERLIKE_PACKAGE="$PAPERLIKE_ROOT/apps/paperlike-agent"
export CLANG_MODULE_CACHE_PATH="$PAPERLIKE_CACHE/modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$PAPERLIKE_CACHE/modules"
mkdir -p "$PAPERLIKE_CACHE/modules"

if [[ "${1:-build}" == test ]]; then
    swift test --package-path "$PAPERLIKE_PACKAGE" --scratch-path "$PAPERLIKE_CACHE/swift" \
        --cache-path "$PAPERLIKE_CACHE/packages" --manifest-cache local --disable-sandbox
    exit
fi

swift build --package-path "$PAPERLIKE_PACKAGE" --scratch-path "$PAPERLIKE_CACHE/swift" \
    --cache-path "$PAPERLIKE_CACHE/packages" --manifest-cache local --disable-sandbox -c release

PAPERLIKE_APP="$PAPERLIKE_CACHE/PaperlikeAgent.app"
mkdir -p "$PAPERLIKE_APP/Contents/MacOS"
cp "$PAPERLIKE_CACHE/swift/release/PaperlikeAgent" "$PAPERLIKE_APP/Contents/MacOS/PaperlikeAgent"
cp "$PAPERLIKE_PACKAGE/Info.plist" "$PAPERLIKE_APP/Contents/Info.plist"
codesign --force --sign - "$PAPERLIKE_APP"
codesign --verify --strict "$PAPERLIKE_APP"
plutil -lint "$PAPERLIKE_APP/Contents/Info.plist"
echo "Application : $PAPERLIKE_APP"
