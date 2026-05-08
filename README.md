# Codex Desktop macOS Patched 🍎

> **为 macOS API Key 用户开启 Plugins + Fast Mode 的 Codex Desktop 增强版**
>
> Forked from [Haleclipse/CodexDesktop-Rebuild](https://github.com/Haleclipse/CodexDesktop-Rebuild) · Patches from [junfuchang/CodexRebuild](https://github.com/junfuchang/CodexRebuild)

---

## ✨ 特性 / Features

| Feature | Description |
|---------|-------------|
| **🔌 Plugins for API Key** | 使用 API key 登录也能显示 Plugins 入口，且导航到 Plugins 页面而非 Skills |
| **⚡ Fast Mode for API Key** | 为 API key 用户开启 Fast Mode 快速模式 |
| **📦 Pre-built DMG** | 提供开箱即用的 DMG 安装包 |
| **🛠 Relay Config Tool** | 一键配置中转站地址和模型提供商（仅需填入 API Key） |

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

### 方式二：从源码构建

```bash
# 1. 克隆仓库
git clone https://github.com/chelsea-Qian/CodexDesktop-macOS-Patched.git
cd CodexDesktop-macOS-Patched

# 2. 安装依赖（国内用户建议使用镜像）
npm install
# 或使用国内镜像：
# ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/" npm install

# 3. 一键补丁 + 构建
bash scripts/patch-and-build.sh

# 4. 安装
bash scripts/install.sh
```

---

## 🛠 构建脚本说明 / Scripts

### `scripts/patch-and-build.sh`

一键完成所有操作，适合 Codex 更新后重新构建：

```
步骤 1/6 — 同步上游 Codex（从 OpenAI CDN 下载最新版）
步骤 2/6 — 应用补丁（Plugins + Fast Mode）
步骤 3/6 — 构建 macOS arm64 应用
步骤 4/6 — 修复缺失的 Frameworks / Info.plist
步骤 5/6 — 更新 ASAR integrity hash + 重新签名
步骤 6/6 — 创建 DMG 安装包
```

### `scripts/install.sh`

将构建产物安装到 `/Applications`。

```bash
bash scripts/install.sh
```

### `scripts/setup-relay.sh`

一键配置中转站（API 代理），写入中转站地址和模型提供商，只需填入 API Key 即可使用。

```bash
# 使用默认中转站 (BoLu_AI)
bash scripts/setup-relay.sh

# 或指定自定义地址
bash scripts/setup-relay.sh https://your-relay-server.com
```

---

## 🌐 国内用户使用指南 / China Users Guide

国内用户如无法直接访问 OpenAI API，可以使用 API 中转站（代理服务）。

完整教程 👉 **[API 中转站接入教程](docs/中转站接入教程.md)**

**快速配置（一键脚本，仅需填入 API Key）：**

```bash
# 1. 配置中转站地址和模型提供商
bash scripts/setup-relay.sh

# 2. 打开 Codex 填入 API Key 即可使用
open /Applications/Codex.app
```

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
