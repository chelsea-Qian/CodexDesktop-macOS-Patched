#!/bin/bash
# setup-relay.sh — 一键配置 Codex 接入 API 中转站
# 用法: bash scripts/setup-relay.sh [中转站地址]
# 示例: bash scripts/setup-relay.sh https://boluotoken.com
#
# 此脚本会配置中转站信息到 ~/.codex/config.toml
# 你仍需要在 Codex 中手动填入 API Key

set -euo pipefail

# 默认中转站
DEFAULT_RELAY="https://boluotoken.com"
RELAY_URL="${1:-$DEFAULT_RELAY}"
RELAY_NAME="relay"
CONFIG_FILE="$HOME/.codex/config.toml"

echo "== Codex 中转站配置工具 =="
echo ""
echo "中转站地址: $RELAY_URL"
echo "配置文件:   $CONFIG_FILE"
echo ""

# 确保 ~/.codex 目录存在
mkdir -p "$HOME/.codex"

# 备份旧配置
if [ -f "$CONFIG_FILE" ]; then
    BACKUP="$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    echo "📦 已备份旧配置到: $BACKUP"
fi

# 使用 Python 的 toml 库来安全修改配置
# (macOS 自带 python3，但需要安装 toml 库)
python3 << PYEOF
import os, json, shutil

config_path = os.path.expanduser("$CONFIG_FILE")
relay_url = "$RELAY_URL"
relay_name = "$RELAY_NAME"

# Try to parse existing TOML
config = {}
if os.path.exists(config_path):
    try:
        import tomllib  # Python 3.11+
        with open(config_path, 'rb') as f:
            config = tomllib.load(f)
    except (ImportError, tomllib.TOMLDecodeError):
        try:
            import tomli
            with open(config_path, 'rb') as f:
                config = tomli.load(f)
        except ImportError:
            # Fallback: parse TOML manually (only for simple values)
            import re
            with open(config_path, 'r') as f:
                content = f.read()
            # Parse [sections]
            current_section = None
            for line in content.split('\n'):
                line = line.strip()
                m = re.match(r'^\[(.+)\]$', line)
                if m:
                    current_section = m.group(1)
                    if current_section not in config:
                        config[current_section] = {}
                elif '=' in line and current_section:
                    k, _, v = line.partition('=')
                    k = k.strip()
                    v = v.strip().strip('"\'')
                    config[current_section][k] = v

# Ensure model_providers section
if 'model_providers' not in config:
    config['model_providers'] = {}

# Set relay provider configuration
config['model_providers'][relay_name] = {
    'base_url': relay_url.rstrip('/') + '/v1',
    'name': 'OpenAI',
    'wire_api': 'responses',
    'requires_openai_auth': True,
    'personality': 'pragmatic',
}

# Also set default model to use this provider
config['model_provider'] = relay_name

# Write back using simple TOML serializer
def toml_val(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, str):
        # Check if it needs quotes
        if any(c in v for c in ' #=\'")]') or v == '':
            return json.dumps(v)
        return v
    if isinstance(v, (int, float)):
        return str(v)
    return json.dumps(v)

lines = []
for section, values in sorted(config.items()):
    if not isinstance(values, dict):
        lines.append(f'{section} = {toml_val(values)}')
        continue
    lines.append(f'\n[{section}]')
    for k, v in sorted(values.items()):
        lines.append(f'{k} = {toml_val(v)}')

with open(config_path, 'w') as f:
    f.write('\n'.join(lines) + '\n')

print(f'✅ 中转站配置已写入: {config_path}')
print(f'   模型提供商: {relay_name}')
print(f'   API 地址:   {relay_url}/v1')
PYEOF

echo ""
echo "🎉 配置完成！"
echo ""
echo "下一步："
echo "  1. 打开 Codex"
echo "  2. 在 Settings 中填入你的中转站 API Key"
echo "  3. 在 model 选择中选择 relay (或你配置的模型)"
echo ""
echo "或者通过命令行启动时指定 API Key:"
echo "  OPENAI_API_KEY=\"sk-你的key\" open /Applications/Codex.app"
