#!/bin/bash
# Installs the latest SteadyWiFi.app from GitHub Releases:
#   curl -fsSL https://raw.githubusercontent.com/minanyang/steady-wifi/main/install.sh | bash
set -euo pipefail

REPO=${REPO:-minanyang/steady-wifi}
DEST=/Applications
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

tmp=$(mktemp -d)
trap 'rm -r -f "$tmp"' EXIT
echo "Downloading Steady WiFi…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/SteadyWiFi.zip" -o "$tmp/SteadyWiFi.zip"
ditto -x -k "$tmp/SteadyWiFi.zip" "$tmp"

pkill -x SteadyWiFiBar 2>/dev/null || true
rm -r -f "$DEST/SteadyWiFi.app"
mv "$tmp/SteadyWiFi.app" "$DEST/"
# Not notarized yet: drop the quarantine flag so Gatekeeper does not block it.
xattr -dr com.apple.quarantine "$DEST/SteadyWiFi.app" 2>/dev/null || true

open "$DEST/SteadyWiFi.app"
echo "Installed to $DEST/SteadyWiFi.app. Finish setup from the menu bar icon."
