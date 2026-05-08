# Codex Desktop macOS Patched 🍎

> **为 macOS API Key 用户开启 Plugins + Fast Mode 的 Codex Desktop 增强版**
>
> Forked from [Haleclipse/CodexDesktop-Rebuild](https://github.com/Haleclipse/CodexDesktop-Rebuild) · Patches from [junfuchang/CodexRebuild](https://github.com/junfuchang/CodexRebuild)

---

## ✨ 特性 / Features

| Feature | Description |
|---------|-------------|
| **🔌 Plugins for API Key** | 解除 UI 门控，API Key 用户可见 Plugins 入口并可进入页面（插件能否实际使用取决于中转站/API 是否支持） |
| **⚡ Fast Mode for API Key** | 为 API key 用户开启 Fast Mode 快速模式 |
| **📦 Pre-built DMG** | 提供开箱即用的 DMG 安装包 |
| **🛠 Relay Config Tool** | 一键配置中转站地址、API Key、模型提供商（已配置的跳过即可） |

> 更多补丁（如 True Delete 本地会话永久删除）可根据需求添加。
>
> 📖 **国内用户接入指南**：详见 [API 中转站接入教程](docs/中转站接入教程.md)

---

## 📋 前提条件 / Prerequisites

- **Apple Silicon Mac** (M1/M2/M3/M4) 或 Intel Mac
- **macOS 14+** (Sonoma / Sequoia)
- 已安装 **Node.js 18+** 和 **npm**（仅构建时需要）
- 拥有 **OpenAI API Key** 或 ChatGPT Plus 订阅

---

## 🚀 快速安装 / Quick Install

### 方式一：使用预构建 DMG（推荐）

从 [Releases 页面](https://github.com/chelsea-Qian/CodexDesktop-macOS-Patched/releases) 下载最新的 `Codex-mac-arm64-*.dmg`。

```bash
# 打开 DMG 并拖入 Applications 文件夹
open Codex-mac-arm64-26.506.21252.dmg
```

如果 macOS 显示"无法验证开发者"：

1. 打开 **系统设置 → 隐私与安全性**
2. 向下滚动，在"安全性"部分点击 **"仍要打开"**

### 方式二：从源码构建（完整流程）

```bash
# 1. 克隆仓库
git clone https://github.com/chelsea-Qian/CodexDesktop-macOS-Patched.git
cd CodexDesktop-macOS-Patched

# 2. 一键补丁 + 构建 + 安装（自动检查 npm/node）
bash scripts/patch-and-build.sh

# 3. 安装到 Applications（如需密码会提示）
bash scripts/install.sh

# 4. （可选）如果你还没配中转站，一键配置 API Key + 中转站地址
#    已配置过的跳过这步
bash scripts/setup-relay.sh
```

> **关于 Plugins**：补丁仅解除 UI 入口限制，插件能否实际调用取决于你的 API/中转站是否支持插件所需接口。
>
> **国内用户注意**：如果 `npm install` 下载 Electron 慢，可以先设置镜像：
> ```bash
> ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/" bash scripts/patch-and-build.sh
> ```

---

## 🛠 构建脚本说明 / Scripts

### `scripts/patch-and-build.sh`

一键完成所有操作，自动检查 npm/node → 同步上游 → 应用补丁 → 构建 → 修复 → 签名 → DMG：

```
步骤 0/6 — 检查 Node.js、npm、依赖是否安装 ✓
步骤 1/6 — 同步上游 Codex（从 OpenAI CDN 下载最新版）
步骤 2/6 — 应用 AST 补丁（插件门控 + Fast Mode + i18n + DevTools）
步骤 3/6 — 构建 macOS arm64 应用
步骤 4/6 — 修复缺失的 Frameworks / Info.plist
步骤 5/6 — 更新 ASAR integrity hash + 重新签名
步骤 6/6 — 创建 DMG 安装包
```

> 如果遇到权限错误，确保已安装 Node.js 18+。国内用户建议设置 Electron 镜像。

### `scripts/install.sh`

将构建产物安装到 `/Applications`。

```bash
bash scripts/install.sh
```

### `scripts/setup-relay.sh`

一键配置中转站（API 代理）+ API Key。依次完成：
1. 📝 提示输入 API Key（或检测已有的 `auth.json`）
2. 🔧 写入中转站地址和模型提供商到 `~/.codex/config.toml`
3. 🔑 保存 API Key 到 `~/.codex/auth.json`

完成后重启 Codex 即可，无需任何手动设置。

```bash
# 使用默认中转站 BoLu_AI（注册即得1$，进QQ群得5$，推荐多得1$）
# 推荐注册: https://boluotoken.com/register?aff=SZJR
bash scripts/setup-relay.sh

# 或指定自定义地址
bash scripts/setup-relay.sh https://your-relay-server.com
```

---

## 🌐 国内用户使用指南 / China Users Guide

国内用户如无法直接访问 OpenAI API，可以使用 API 中转站（代理服务）。

完整教程 👉 **[API 中转站接入教程](docs/中转站接入教程.md)**

**快速配置（一键脚本，自动写 API Key 到 auth.json）：**

```bash
# 1. 配置中转站地址 + 模型提供商 + API Key
bash scripts/setup-relay.sh

# 2. 重启 Codex
pkill -f Codex; open /Applications/Codex.app
```

脚本会自动写入 `~/.codex/config.toml`（中转站配置）和 `~/.codex/auth.json`（API Key），重启 Codex 即可使用。

> 中转站将各类模型统一转换为 OpenAI 兼容接口，支持支付宝/微信充值。

---

## 🔧 补丁原理 / How Patches Work

Codex Desktop 是一个 Electron 应用，其前端界面代码打包在 `app.asar` 中。补丁通过 JavaScript AST（抽象语法树）解析来精准定位并修改门控条件。

本项目集成了原项目 [CodexDesktop-Rebuild](https://github.com/Haleclipse/CodexDesktop-Rebuild) 的 AST 补丁系统（[`scripts/patch-all.js`](scripts/patch-all.js)）：

### 补丁列表

| 脚本 | 作用 |
|------|------|
| `patch-plugin-auth.js` | 插件认证门控：`e !== 'chatgpt'` → `!1`，解除 API key 的插件限制 |
| `patch-fast-mode.js` | Fast Mode 门控：`X.authMethod !== "chatgpt"` → `!1` |
| `patch-i18n.js` | i18n 国际化修复 |
| `patch-devtools.js` | 开发者工具补丁 |
| `patch-gpu.js` | GPU 硬件加速补丁 |
| `patch-copyright.js` | 版权声明补丁 |

所有这些补丁都通过 AST 解析（[acorn](https://github.com/acornjs/acorn)）而非字符串替换进行，更加健壮和精确。

---

## ⚠️ 插件兼容性说明 / Plugin Compatibility

部分插件可能在使用 API Key + 中转站时无法正常工作，原因如下：

| 原因 | 说明 |
|------|------|
| **OAuth 依赖** | 部分插件需要 ChatGPT OAuth 登录，API Key 无法替代 |
| **中转站兼容性** | 插件可能调用 Responses API 之外的接口，需要中转站支持 |
| **403 路由** | 部分地区/线路访问插件市场时可能返回 403 |

### 推荐排查步骤

1. **确认 `config.toml` 包含以下配置**（`setup-relay.sh` 已自动写入）：
   ```toml
   preferred_auth_method = "apikey"
   requires_openai_auth = true
   wire_api = "responses"
   ```

2. **如果之前登录过 ChatGPT**，清除缓存后重启：
   ```bash
   rm -rf ~/.codex/.codex-global-state.json
   pkill -f Codex; open /Applications/Codex.app
   ```

3. **部分插件需要手动启用**：进入 Plugins 页面，找到对应插件点击安装/启用。

4. **确认中转站支持 Codex**：联系中转站客服确认是否支持 Codex Responses API。

### 关于插件兼容性

部分插件（如 GitHub 插件）需要 ChatGPT OAuth 授权，API Key 模式下无法使用，这是固有限制。

参考来源：
- [Codex 中转站插件讨论](https://linux.do/t/topic/2073351/4)
- [CC Switch 配置教程](https://juejin.cn/post/7621965789160456207)
- [openclaw v2026.5.6 修复](https://blog.csdn.net/weixin_48502062/article/details/160863668)

---

### 关于构建修复

本仓库还修复了原项目 `build-from-upstream.js` 的一个 Bug：`ditto` 命令在重建 `out/` 目录时未能正确复制 `Codex.app/Contents/Frameworks/` 和 `Info.plist`，导致构建后的应用无法启动。`patch-and-build.sh` 在构建后自动补充这些缺失文件。

---

## 📁 项目结构 / Project Structure

```
CodexDesktop-macOS-Patched/
├── scripts/
│   ├── patch-and-build.sh      # 🆕 一键补丁 + 构建脚本
│   ├── install.sh              # 🆕 安装脚本
│   ├── build-from-upstream.js  # 上游构建脚本（原项目）
│   ├── sync-upstream.js        # 上游同步脚本（原项目）
│   └── patch-all.js            # 补丁脚本（原项目）
├── package.json
├── forge.config.js
├── .gitignore
└── README.md                   # 🆕 本文档
```

> `src/` 目录（上游 Codex 的 ASAR 提取内容）和 `out/` 目录（构建输出）不包含在仓库中。

---

## 🔄 更新 Codex / Updating

当 OpenAI 发布新版 Codex Desktop 时：

```bash
cd CodexDesktop-macOS-Patched

# 清理旧构建
rm -rf src/ out/

# 重新执行补丁 + 构建
bash scripts/patch-and-build.sh

# 安装新版
bash scripts/install.sh
```

---

## 🙏 致谢 / Credits

- **[OpenAI Codex](https://github.com/openai/codex)** — 原始 Codex CLI（Apache-2.0）
- **[Haleclipse/CodexDesktop-Rebuild](https://github.com/Haleclipse/CodexDesktop-Rebuild)** — 跨平台 Electron 重建
- **[junfuchang/CodexRebuild](https://github.com/junfuchang/CodexRebuild)** — Windows 版补丁脚本（本项目的补丁逻辑参考来源）
- **[@cometix/codex](https://www.npmjs.com/package/@cometix/codex)** — Codex CLI 二进制分发

---

## ⚠️ 免责声明 / Disclaimer

本项目仅为技术研究与学习目的。Codex Desktop 是 OpenAI 的产品，其所有知识产权归 OpenAI 所有。本项目不修改 OpenAI 的原始代码，仅通过对前端 JS 的门控条件进行修改来启用已有功能。
