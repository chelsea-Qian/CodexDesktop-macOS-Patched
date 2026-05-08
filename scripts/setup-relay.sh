#!/bin/bash
# setup-relay.sh — 一键配置 Codex 接入 API 中转站（含 API Key）
# 用法: bash scripts/setup-relay.sh [中转站地址]
# 示例:
#   bash scripts/setup-relay.sh
#   bash scripts/setup-relay.sh https://boluotoken.com
#
# 此脚本会:
#   1. 配置中转站信息到 ~/.codex/config.toml
#   2. 写入 API Key 到 ~/.codex/auth.json
# 完成后重启 Codex 即可使用，无需手动设置。
#
# 前置条件: 需要 Python 3.11+ (macOS 自带)

set -euo pipefail

# 检查 Python 3.11+
if ! python3 -c "import tomllib" 2>/dev/null; then
    echo "❌ 需要 Python 3.11+，当前版本: $(python3 --version 2>&1)"
    exit 1
fi

# 默认中转站
DEFAULT_RELAY="https://boluotoken.com"
RELAY_URL="${1:-$DEFAULT_RELAY}"
RELAY_NAME="relay"
CONFIG_FILE="$HOME/.codex/config.toml"
AUTH_FILE="$HOME/.codex/auth.json"

echo "== Codex 中转站配置工具 =="
echo ""
echo "中转站地址: $RELAY_URL"
echo ""

# 确保 ~/.codex 目录存在
mkdir -p "$HOME/.codex"

# ─── 读取或输入 API Key ─────────────────────────────────────────
AUTH_KEY=""
if [ -f "$AUTH_FILE" ]; then
    EXISTING_KEY=$(python3 -c "
import json
try:
    with open('$AUTH_FILE') as f:
        d = json.load(f)
    print(d.get('OPENAI_API_KEY', ''))
except:
    print('')
" 2>/dev/null || echo "")
    if [ -n "$EXISTING_KEY" ]; then
        echo "🔑 检测到已有 API Key: ${EXISTING_KEY:0:8}..."
        read -p "   是否使用此 Key？(Y/n): " USE_EXISTING
        if [[ "$USE_EXISTING" =~ ^[Nn] ]]; then
            read -p "   请输入新的 API Key (留空跳过): " AUTH_KEY
        else
            AUTH_KEY="$EXISTING_KEY"
        fi
    fi
fi

if [ -z "$AUTH_KEY" ] && [ ! -f "$AUTH_FILE" ]; then
    echo "🔑 请输入你的中转站 API Key（从 boluotoken 控制台 → 令牌 获取）"
    echo "   留空则跳过，后续可手动编辑 ~/.codex/auth.json"
    read -p "   API Key: " AUTH_KEY
fi

# ─── 写入 API Key ────────────────────────────────────────────────
if [ -n "$AUTH_KEY" ]; then
    # 备份旧的 auth.json
    if [ -f "$AUTH_FILE" ]; then
        cp "$AUTH_FILE" "$AUTH_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    fi
    python3 -c "
import json
with open('$AUTH_FILE', 'w') as f:
    json.dump({'OPENAI_API_KEY': '$AUTH_KEY'}, f)
" 2>/dev/null
    chmod 600 "$AUTH_FILE"
    echo "✅ API Key 已保存到: $AUTH_FILE"
fi

# ─── 备份旧 config.toml ──────────────────────────────────────────
if [ -f "$CONFIG_FILE" ]; then
    BACKUP="$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    echo "📦 已备份旧配置到: $BACKUP"
fi

# ─── 写入中转站配置到 config.toml ───────────────────────────────
python3 << PYEOF
import os, json

config_path = os.path.expanduser("$CONFIG_FILE")
relay_url = "$RELAY_URL"
relay_name = "$RELAY_NAME"

# 读取现有配置
config = {}
if os.path.exists(config_path):
    try:
        import tomllib
        with open(config_path, 'rb') as f:
            config = tomllib.load(f)
    except Exception as e:
        print(f"⚠  读取配置失败: {e}，将创建新配置")
        config = {}

# 确保 model_providers 是一个字典
if 'model_providers' not in config or not isinstance(config['model_providers'], dict):
    config['model_providers'] = {}

# 设置中转站提供商
config['model_providers'][relay_name] = {
    'base_url': relay_url.rstrip('/') + '/v1',
    'name': 'OpenAI',
    'wire_api': 'responses',
    'requires_openai_auth': True,
    'personality': 'pragmatic',
}

# 设置默认模型提供商
config['model_provider'] = relay_name

# TOML 写入
def toml_val(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, str):
        if any(c in v for c in ' "#=\'') or v == '':
            return json.dumps(v)
        return v
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        items = ', '.join(toml_val(x) for x in v)
        return f'[{items}]'
    if isinstance(v, dict):
        return json.dumps(v)
    return json.dumps(v)

lines = []
for section, values in sorted(config.items()):
    if not isinstance(values, dict):
        lines.append(f'{section} = {toml_val(values)}')
        continue
    lines.append(f'\n[{section}]')
    for k, v in sorted(values.items()):
        if isinstance(v, dict):
            lines.append(f'[{section}.{k}]')
            for sk, sv in sorted(v.items()):
                lines.append(f'{sk} = {toml_val(sv)}')
        else:
            lines.append(f'{k} = {toml_val(v)}')

with open(config_path, 'w') as f:
    f.write('\n'.join(lines) + '\n')

print(f'✅ 中转站配置已写入: {config_path}')
print(f'   模型提供商: {relay_name}')
print(f'   API 地址:   {relay_url}/v1')
PYEOF

echo ""
echo "🎉 全部配置完成！"
echo ""
echo "现在重启 Codex 即可使用:"
echo "  pkill -f Codex; open /Applications/Codex.app"
echo ""
echo "如果 Model 没有自动选择 'relay'，手动设置:"
echo "  Settings → Model → 选 relay → 选模型"
echo ""
echo "如需恢复旧配置:"
echo "  cp \"$BACKUP\" \"$CONFIG_FILE\""
