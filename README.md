# 🦞 Claude Code Local Proxy

> **本地 Claude Code 代理服务** — 让 Claude Code CLI 在本地运行，并与 [OpenClaw](https://github.com/seanlab007/open-claw) 和 WorkBuddy 无缝集成。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.11+-green.svg)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688.svg)](https://fastapi.tiangolo.com)

---

## 架构概览

```
Claude Code CLI
      │
      ▼  ANTHROPIC_BASE_URL=http://localhost:8082
┌─────────────────────────────────────────────┐
│         Claude Code Local Proxy             │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  Anthropic API Format Translator    │    │
│  └────────────┬────────────────────────┘    │
│               │                             │
│    ┌──────────┼──────────────┐              │
│    ▼          ▼              ▼              │
│  Anthropic  OpenAI/     OpenClaw            │
│  API        Ollama/     Gateway  WorkBuddy  │
│             LM Studio   :3000    :4000      │
└─────────────────────────────────────────────┘
```

## 🍎 Mac 一键快速开始（推荐）

### 第一次使用：一键安装所有依赖

```bash
# 1. 克隆仓库
git clone https://github.com/seanlab007/claude-code-local.git
cd claude-code-local

# 2. 一键安装（Homebrew / Node.js / Python / Claude Code CLI / OpenClaw / 所有 API Key）
bash setup-mac.sh
```

安装完成后，桌面会自动出现 **Claude Code.command** 快捷方式，**双击即可启动**。

### 日常使用：三种启动方式

**方式 A — 双击桌面快捷方式（最简单）**

```
双击 ~/Desktop/Claude Code.command
```

**方式 B — 创建 .app 应用图标**

```bash
bash create-mac-app.sh
# 桌面出现 Claude Code.app，双击即可
```

**方式 C — 命令行后台启动**

```bash
bash launch.sh                          # 后台启动所有服务
source ~/.claude-code-local/env.sh      # 设置环境变量
claude                                  # 开始使用！
```

**停止所有服务**

```bash
bash stop.sh
```

---

## 快速开始（其他平台）

### 方式一：Python 直接运行

```bash
# 1. 克隆仓库
git clone https://github.com/seanlab007/claude-code-local.git
cd claude-code-local

# 2. 安装
chmod +x install.sh && ./install.sh

# 3. 配置 API Key
cp .env.example .env
# 编辑 .env，填入你的 API Key

# 4. 启动代理
chmod +x start.sh && ./start.sh

# 5. 使用 Claude Code
ANTHROPIC_BASE_URL=http://localhost:8082 claude
```

### 方式二：Docker

```bash
# 1. 配置环境
cp .env.example .env
# 编辑 .env

# 2. 启动
docker compose up -d

# 3. 使用 Claude Code
ANTHROPIC_BASE_URL=http://localhost:8082 claude
```

---

## 配置说明

编辑 `.env` 文件：

```env
# 选择后端提供商
PREFERRED_PROVIDER=anthropic   # anthropic | openai | openclaw | workbuddy

# Anthropic 直连（推荐）
ANTHROPIC_API_KEY=sk-ant-your-key

# OpenAI 或本地模型
OPENAI_API_KEY=sk-your-key
OPENAI_BASE_URL=http://localhost:11434/v1  # Ollama 本地模型

# OpenClaw 集成
OPENCLAW_BASE_URL=http://localhost:3000
OPENCLAW_GATEWAY_TOKEN=your-token

# WorkBuddy 集成
WORKBUDDY_BASE_URL=http://localhost:4000
WORKBUDDY_API_KEY=your-key
```

---

## 支持的后端

| 提供商 | 配置 | 说明 |
|--------|------|------|
| `anthropic` | `ANTHROPIC_API_KEY` | 直连 Anthropic API（默认） |
| `openai` | `OPENAI_API_KEY` | OpenAI 或任何兼容 API |
| `openclaw` | `OPENCLAW_GATEWAY_TOKEN` | 通过 OpenClaw 网关路由 |
| `workbuddy` | `WORKBUDDY_API_KEY` | 通过 WorkBuddy 服务路由 |

### 本地模型（Ollama）

```env
PREFERRED_PROVIDER=openai
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=ollama
BIG_MODEL=qwen2.5-coder:32b
SMALL_MODEL=qwen2.5-coder:7b
```

```bash
# 安装 Ollama 并拉取模型
ollama pull qwen2.5-coder:32b
```

---

## OpenClaw 集成

本代理与 [open-claw](https://github.com/seanlab007/open-claw) 深度集成：

1. **代理模式**：将 Claude Code 请求路由到 OpenClaw 网关
2. **Webhook**：接收 OpenClaw 推送的消息事件
3. **状态检查**：实时监控 OpenClaw 连接状态

```bash
# 检查 OpenClaw 连接状态
curl http://localhost:8082/integrations/openclaw/status
```

详见 [integrations/openclaw.md](integrations/openclaw.md)

---

## WorkBuddy 集成

本代理支持将 Claude Code 请求路由到 WorkBuddy 服务：

```bash
# 检查 WorkBuddy 连接状态
curl http://localhost:8082/integrations/workbuddy/status
```

详见 [integrations/workbuddy.md](integrations/workbuddy.md)

---

## API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v1/messages` | POST | Claude Code 消息（Anthropic 格式） |
| `/v1/models` | GET | 可用模型列表 |
| `/health` | GET | 代理健康检查 |
| `/integrations/openclaw/status` | GET | OpenClaw 连接状态 |
| `/integrations/workbuddy/status` | GET | WorkBuddy 连接状态 |
| `/webhooks/openclaw` | POST | 接收 OpenClaw 事件 |
| `/webhooks/workbuddy` | POST | 接收 WorkBuddy 事件 |

---

## 模型映射

| Claude 模型请求 | 默认映射 |
|----------------|---------|
| `claude-haiku-*` | `SMALL_MODEL`（默认 `claude-haiku-4-5`） |
| `claude-sonnet-*` | `BIG_MODEL`（默认 `claude-sonnet-4-5`） |
| `claude-opus-*` | `claude-opus-4-5` |

---

## 许可证

MIT License — 详见 [LICENSE](LICENSE)

---

## 相关项目

- [open-claw](https://github.com/seanlab007/open-claw) — OpenClaw AI 对话平台
- [openclaw](https://github.com/seanlab007/openclaw) — OpenClaw 个人 AI 助手
- [1rgs/claude-code-proxy](https://github.com/1rgs/claude-code-proxy) — 原始 claude-code-proxy 项目（本项目参考）
