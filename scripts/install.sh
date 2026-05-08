#!/bin/bash
# install.sh — Install the built Codex.app to /Applications
set -euo pipefail
cd "$(dirname "$0")/.."

APP="out/mac-arm64/Codex.app"
if [ ! -d "$APP" ]; then
    echo "Error: Build output not found at $APP"
    echo "Run 'bash scripts/patch-and-build.sh' first."
    exit 1
fi

echo "== Installing Codex =="

# Kill running Codex
pkill -f "Codex" 2>/dev/null || true
sleep 1

# Remove old, install new
rm -rf /Applications/Codex.app
cp -Rf "$APP" /Applications/
xattr -cr /Applications/Codex.app 2>/dev/null || true

echo "✓ Installed to /Applications/Codex.app"
echo ""
echo "Open from Launchpad or run: open /Applications/Codex.app"
echo "If macOS shows a security warning:"
echo "  1. System Settings → Privacy & Security"
echo "  2. Click 'Open Anyway'"
