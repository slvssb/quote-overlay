#!/bin/bash
# Builds QuoteOverlay.app, installs it to ~/Applications, and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle.sh

DEST="$HOME/Applications/QuoteOverlay.app"
pkill -x QuoteOverlay || true
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R QuoteOverlay.app "$DEST"
open "$DEST"
echo "Installed $DEST"
