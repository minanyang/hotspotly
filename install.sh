#!/bin/bash
# Installs the latest Hotspotly.app from GitHub Releases:
#   curl -fsSL https://raw.githubusercontent.com/minanyang/hotspotly/main/install.sh | bash
set -euo pipefail

# Not `uname -m`, which says x86_64 in a shell running under Rosetta.
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" != 1 ]; then
  echo "Hotspotly needs a Mac with Apple silicon." >&2
  exit 1
fi

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

open "$DEST/Hotspotly.app"
echo "Installed to $DEST/Hotspotly.app. Finish setup from the menu bar icon."
