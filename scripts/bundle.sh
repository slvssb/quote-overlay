#!/bin/bash
# Builds QuoteOverlay.app next to Package.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/QuoteOverlay"

APP="QuoteOverlay.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/QuoteOverlay"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"
echo "Built $(pwd)/$APP"
