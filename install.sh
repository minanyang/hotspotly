#!/bin/bash
# Installs the latest Hotspotly.app from GitHub Releases:
#   curl -fsSL https://raw.githubusercontent.com/minanyang/hotspotly/main/install.sh | bash
set -euo pipefail

REPO=${REPO:-minanyang/hotspotly}
DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

tmp=$(mktemp -d)
trap 'rm -r -f "$tmp"' EXIT
echo "Downloading Hotspotly…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/Hotspotly.zip" -o "$tmp/Hotspotly.zip"
ditto -x -k "$tmp/Hotspotly.zip" "$tmp"

pkill -x HotspotlyBar 2>/dev/null || true
rm -r -f "$DEST/Hotspotly.app"
mv "$tmp/Hotspotly.app" "$DEST/"
# Not notarized yet: drop the quarantine flag so Gatekeeper does not block it.
xattr -dr com.apple.quarantine "$DEST/Hotspotly.app" 2>/dev/null || true

open "$DEST/Hotspotly.app"
echo "Installed to $DEST/Hotspotly.app. Finish setup from the menu bar icon."
