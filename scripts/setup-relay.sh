#!/bin/bash
# setup-relay.sh — 一键配置 Codex 接入 API 中转站
# 用法: bash scripts/setup-relay.sh [中转站地址]
# 示例:
#   bash scripts/setup-relay.sh
#   bash scripts/setup-relay.sh https://boluotoken.com
#
# 此脚本会配置中转站信息到 ~/.codex/config.toml
# 你仍需要在 Codex 中手动填入 API Key
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

# 使用 Python tomllib 读写 TOML
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
    """将 Python 值转换为 TOML 格式字符串"""
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, str):
        # 含特殊字符的字符串需要引号
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

# 构建 TOML 内容
lines = []
for section, values in sorted(config.items()):
    if not isinstance(values, dict):
        lines.append(f'{section} = {toml_val(values)}')
        continue
    lines.append(f'\n[{section}]')
    for k, v in sorted(values.items()):
        if isinstance(v, dict):
            # 嵌套字典
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
echo "🎉 配置完成！"
echo ""
echo "下一步："
echo "  1. 打开 Codex"
echo "  2. 在 Settings → Model 中选择 'relay' (或你刚配置的提供商)"
echo "  3. 填入你的中转站 API Key"
echo ""
echo "或者通过命令行启动时指定 API Key:"
echo "  OPENAI_API_KEY=\"sk-你的key\" open /Applications/Codex.app"
echo ""
echo "如需恢复旧配置:"
echo "  cp \"$BACKUP\" \"$CONFIG_FILE\""
