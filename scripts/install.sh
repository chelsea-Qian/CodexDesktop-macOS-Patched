#!/bin/bash
# install.sh — Install the built Codex.app to /Applications
# Usage: bash scripts/install.sh
#
# 如果需要密码，按提示输入管理员密码即可

set -euo pipefail
cd "$(dirname "$0")/.."

APP="out/mac-arm64/Codex.app"
if [ ! -d "$APP" ]; then
    echo "Error: Build output not found at $APP"
    echo "Run 'bash scripts/patch-and-build.sh' first."
    exit 1
fi

echo "== Installing Codex to /Applications =="
echo ""

# Kill running Codex
if pgrep -f "Codex" > /dev/null 2>&1; then
    echo "⏹  Stopping running Codex..."
    pkill -f "Codex" 2>/dev/null || true
    sleep 1
fi

# 检查 /Applications 是否可写
if [ -w /Applications ]; then
    # 可写，直接安装
    rm -rf /Applications/Codex.app
    cp -Rf "$APP" /Applications/
else
    # 需要管理员权限
    echo "🔑 需要管理员权限安装到 /Applications..."
    sudo rm -rf /Applications/Codex.app
    sudo cp -Rf "$APP" /Applications/
fi

# 清除扩展属性
xattr -cr /Applications/Codex.app 2>/dev/null || true

echo ""
echo "✅ 安装成功！"
echo ""
echo "打开 Codex:"
echo "  open /Applications/Codex.app"
echo ""
echo "首次打开如果 macOS 提示无法验证开发者:"
echo "  1. 打开 系统设置 → 隐私与安全性"
echo "  2. 点击「仍要打开」"
echo ""
echo "配置中转站 (可选):"
echo "  bash scripts/setup-relay.sh"
