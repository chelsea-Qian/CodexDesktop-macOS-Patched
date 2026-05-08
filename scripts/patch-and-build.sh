#!/bin/bash
# patch-and-build.sh — Patch Codex for API key users (Plugins + Fast Mode) and build
# Usage: bash scripts/patch-and-build.sh
#
# This script integrates the original project's AST-based patch system
# (patch-fast-mode.js, patch-plugin-auth.js, etc.) into the build pipeline.

set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT_ROOT="$PWD"

echo "== Codex Patch & Build for macOS arm64 =="
echo ""

# ─── Prerequisite checks ────────────────────────────────────────
echo "[0/6] Checking prerequisites..."

# Check Node.js
if ! command -v node &>/dev/null; then
    echo "❌ Node.js not found. Please install Node.js 18+ from https://nodejs.org"
    exit 1
fi
NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
    echo "❌ Node.js 18+ required. Current: $(node -v)"
    echo "   Download from https://nodejs.org"
    exit 1
fi
echo "  ✓ Node.js $(node -v)"

# Check npm
if ! command -v npm &>/dev/null; then
    echo "❌ npm not found. Please install Node.js 18+ from https://nodejs.org"
    exit 1
fi
echo "  ✓ npm $(npm -v)"

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "  → Installing dependencies..."
    npm install 2>&1 || {
        echo "❌ npm install failed."
        echo "   If you're in China, try: ELECTRON_MIRROR=\"https://npmmirror.com/mirrors/electron/\" npm install"
        exit 1
    }
fi
echo "  ✓ Dependencies installed"
echo ""

# ─── Step 1: Sync upstream (if needed) ─────────────────────────
if [ ! -d "src/mac-arm64/_asar" ]; then
    echo "[1/6] Syncing upstream Codex..."
    npm run sync 2>&1 || {
        echo "⚠ Sync via script failed. Trying manual download..."
        mkdir -p /tmp/codex-sync
        ZIP="/tmp/codex-sync/Codex-arm64-26.506.21252.zip"
        if [ ! -f "$ZIP" ]; then
            echo "  Downloading Codex macOS arm64 (~307MB)..."
            curl -L --retry 3 --retry-delay 5 -o "$ZIP" \
                "https://persistent.oaistatic.com/codex-app-prod/Codex-darwin-arm64-26.506.21252.zip"
        fi
        echo "  Extracting..."
        ditto -xk "$ZIP" "/tmp/codex-sync/arm64-extract"
        RESOURCES="/tmp/codex-sync/arm64-extract/Codex.app/Contents/Resources"
        mkdir -p src/mac-arm64
        npx asar extract "$RESOURCES/app.asar" src/mac-arm64/_asar
        cp -R "$RESOURCES/app.asar.unpacked" src/mac-arm64/ 2>/dev/null || true
        for f in "$RESOURCES"/*; do
            name=$(basename "$f")
            [ "$name" = "app.asar" ] || [ "$name" = "app.asar.unpacked" ] && continue
            [[ "$name" == *.lproj ]] && continue
            cp -R "$f" src/mac-arm64/
        done
        echo "  ✓ Manual sync done"
    }
else
    echo "[1/6] Upstream already synced."
fi

# ─── Step 2: Apply AST-based patches ───────────────────────────
echo "[2/6] Applying patches (AST-based)..."
# Uses the original project's patch system:
#   - patch-plugin-auth.js:  Plugin auth gate (e !== 'chatgpt' → !1)
#   - patch-fast-mode.js:    Fast mode auth gate → !1
#   - patch-i18n.js:         i18n fixes
#   - patch-copyright.js:    Copyright fixes
#   - patch-devtools.js:     DevTools fixes
#   - patch-gpu.js:          GPU fixes
npm run patch 2>&1 || echo "  ⚠ Some patches may have warnings (non-critical)"

# ─── Step 3: Build ──────────────────────────────────────────────
echo "[3/6] Building Codex..."
rm -rf out
npm run build:mac-arm64 2>&1

# ─── Step 4: Fix missing Frameworks / Info.plist ────────────────
echo "[4/6] Fixing missing bundle files (build script workaround)..."
ORIG_APP="/tmp/codex-sync/arm64-extract/Codex.app/Contents"
OUT_APP="out/mac-arm64/Codex.app/Contents"

if [ -d "$ORIG_APP" ]; then
    # Info.plist and PkgInfo are not copied by ditto in the build script
    cp "$ORIG_APP/Info.plist" "$OUT_APP/" 2>/dev/null && echo "  ✓ Info.plist restored"
    cp "$ORIG_APP/PkgInfo" "$OUT_APP/" 2>/dev/null || true

    # Frameworks directory is not copied by ditto when out/ dir is recreated
    if [ ! -d "$OUT_APP/Frameworks" ] || [ -z "$(ls -A "$OUT_APP/Frameworks" 2>/dev/null)" ]; then
        cp -Rf "$ORIG_APP/Frameworks" "$OUT_APP/" && echo "  ✓ Frameworks restored"
    else
        echo "  ✓ Frameworks already present"
    fi
else
    echo "  ⚠ Original app temp directory missing - Frameworks may be incomplete"
    echo "  Run sync first to restore original app cache."
fi

# ─── Step 5: Update integrity hash & re-sign ────────────────────
echo "[5/6] Updating integrity hash and re-signing..."
APP="out/mac-arm64/Codex.app"
ASAR_PATH="$APP/Contents/Resources/app.asar"
INFO_PLIST="$APP/Contents/Info.plist"

if [ -f "$INFO_PLIST" ]; then
    NEW_HASH=$(node -e "
        const crypto = require('crypto');
        const fs = require('fs');
        const buf = fs.readFileSync('$ASAR_PATH');
        const headerSize = buf.readUInt32LE(12);
        const header = buf.slice(16, 16 + headerSize);
        console.log(crypto.createHash('sha256').update(header).digest('hex'));
    ")
    plutil -replace ElectronAsarIntegrity.Resources/app\\.asar.hash -string "$NEW_HASH" "$INFO_PLIST" 2>&1
    plutil -replace ElectronAsarIntegrity.Resources/app\\.asar.algorithm -string "SHA256" "$INFO_PLIST" 2>&1
    echo "  ✓ Integrity hash updated: ${NEW_HASH:0:16}..."
fi

chmod -R +x "$APP/Contents/MacOS/" 2>/dev/null
chmod -R +x "$APP/Contents/Frameworks/" 2>/dev/null
codesign --sign - --force --deep "$APP" 2>&1 && echo "  ✓ Ad-hoc signed"

# ─── Step 6: Create DMG ─────────────────────────────────────────
echo "[6/6] Creating DMG..."
rm -f out/Codex-mac-arm64-*.dmg
hdiutil create -volname Codex -srcfolder "out/mac-arm64" -ov -format UDZO \
    "out/Codex-mac-arm64-26.506.21252.dmg" 2>&1 | tail -1

SIZE=$(ls -lh out/Codex-mac-arm64-26.506.21252.dmg | awk '{print $5}')
echo ""
echo "== Build complete! =="
echo "  DMG:   out/Codex-mac-arm64-26.506.21252.dmg ($SIZE)"
echo ""
echo "To install:"
echo "  bash scripts/install.sh"
echo "  or open the DMG and drag Codex.app to Applications."
echo ""
echo "After install, configure your API relay/proxy:"
echo "  bash scripts/setup-relay.sh"
echo "  or: bash scripts/setup-relay.sh https://your-relay-server.com"
