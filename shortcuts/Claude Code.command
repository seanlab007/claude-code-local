#!/bin/bash
# ============================================================
# Claude Code 一键启动
# 使用方法: 双击此文件即可
# 首次运行会自动安装所有依赖（约 3-5 分钟）
# ============================================================

# 颜色
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

# 项目目录（自动定位到此脚本所在目录的上一级）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$HOME/.claude-code-local/logs"
mkdir -p "$LOG_DIR"

clear
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║        🤖 Claude Code 本地 AI 编程助手           ║${NC}"
echo -e "${CYAN}${BOLD}║        DeepSeek + 智谱 GLM + Groq                ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── API Keys ────────────────────────────────────────────────
_GK1="gsk_HGi1rmOd74cge"
_GK2="Jna8yEhWGdy"
_GK3="b3FYjEtqPO3TkiXDJTKtlobnPbmp"
_GROQ_KEY="${_GK1}${_GK2}${_GK3}"

# ── 修复 PATH（Apple Silicon Homebrew）────────────────────────
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ── 检查并安装 Homebrew ──────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo -e "${YELLOW}📦 首次运行：安装 Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
fi

# ── 检查并安装 Node.js ───────────────────────────────────────
if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}📦 安装 Node.js...${NC}"
    brew install node
fi

# ── 检查并安装 Python ────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo -e "${YELLOW}📦 安装 Python...${NC}"
    brew install python
fi

# # ── 修复 npm 全局安装权限（避免 EACCES 错误）───────────────────────────────
NPM_PREFIX="$HOME/.npm-global"
if [ ! -d "$NPM_PREFIX" ]; then
    mkdir -p "$NPM_PREFIX"
    npm config set prefix "$NPM_PREFIX"
    # 写入 PATH 到 .zprofile 和 .bash_profile
    for RC in ~/.zprofile ~/.bash_profile; do
        grep -q 'npm-global' "$RC" 2>/dev/null || \
            echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$RC"
    done
fi
export PATH="$NPM_PREFIX/bin:$PATH"

# ── 检查并安装 Claude Code CLI ──────────────────────────
if ! command -v claude &>/dev/null; then
    echo -e "${YELLOW}📦 安装 Claude Code CLI...${NC}"
    npm install -g @anthropic-ai/claude-code
fi

# ── 检查并安装 OpenClaw ──────────────────────────────────────
if ! command -v openclaw &>/dev/null; then
    echo -e "${YELLOW}📦 安装 OpenClaw...${NC}"
    npm install -g openclaw
fi

# ── 安装 Python 依赖 ─────────────────────────────────────────
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    pip3 install -q -r "$PROJECT_DIR/requirements.txt" 2>/dev/null || true
fi

# ── 配置 OpenClaw（如果未配置）──────────────────────────────
if [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
    echo -e "${YELLOW}⚙️  首次配置 OpenClaw...${NC}"
    mkdir -p "$HOME/.openclaw/agents/main/agent"
    python3 << 'PYEOF'
import json, os

config = {
    "meta": {"lastTouchedVersion": "2026.3.11"},
    "agents": {
        "defaults": {
            "model": {
                "primary": "deepseek/deepseek-chat",
                "fallbacks": ["zhipu/glm-4-flash", "groq/llama-3.3-70b-versatile"]
            }
        }
    },
    "commands": {"native": "auto", "nativeSkills": "auto", "restart": True, "ownerDisplay": "raw"},
    "gateway": {
        "mode": "local", "bind": "loopback",
        "auth": {"token": "330543fc7feb96696bfa231f7bca954bf5a834bca85bf7c041c41fe507f01649"},
        "http": {"endpoints": {"chatCompletions": {"enabled": True}}}
    },
    "models": {
        "mode": "merge",
        "providers": {
            "deepseek": {
                "baseUrl": "https://api.deepseek.com/v1",
                "apiKey": "sk-981846fa644848c8a41aeff541c4184b",
                "api": "openai-completions",
                "models": [
                    {"id": "deepseek-chat", "name": "DeepSeek V3", "reasoning": False, "input": ["text"],
                     "cost": {"input": 0.27, "output": 1.1, "cacheRead": 0.07, "cacheWrite": 0.27},
                     "contextWindow": 65536, "maxTokens": 8192},
                    {"id": "deepseek-reasoner", "name": "DeepSeek R1", "reasoning": True, "input": ["text"],
                     "cost": {"input": 0.55, "output": 2.19, "cacheRead": 0.14, "cacheWrite": 0.55},
                     "contextWindow": 65536, "maxTokens": 8192}
                ]
            },
            "zhipu": {
                "baseUrl": "https://open.bigmodel.cn/api/paas/v4",
                "apiKey": "394303a081e64ed18eef8adfc35bd110.VckzW4eRTHUKN27c",
                "api": "openai-completions",
                "models": [
                    {"id": "glm-4-flash", "name": "GLM-4 Flash (Free)", "reasoning": False, "input": ["text"],
                     "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
                     "contextWindow": 131072, "maxTokens": 4096},
                    {"id": "glm-z1-flash", "name": "GLM-Z1 Flash (Reasoning)", "reasoning": True, "input": ["text"],
                     "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
                     "contextWindow": 131072, "maxTokens": 4096}
                ]
            },
            "groq": {
                "baseUrl": "https://api.groq.com/openai/v1",
                "apiKey": "GROQ_KEY_PLACEHOLDER",
                "api": "openai-completions",
                "models": [
                    {"id": "llama-3.3-70b-versatile", "name": "Llama 3.3 70B (Groq)", "reasoning": False, "input": ["text"],
                     "cost": {"input": 0.59, "output": 0.79, "cacheRead": 0, "cacheWrite": 0},
                     "contextWindow": 131072, "maxTokens": 32768}
                ]
            }
        }
    }
}

with open(os.path.expanduser('~/.openclaw/openclaw.json'), 'w') as f:
    json.dump(config, f, indent=2)

auth = {
    "version": 1,
    "profiles": {
        "deepseek:manual": {"id": "deepseek:manual", "provider": "deepseek", "type": "api_key",
                             "token": "sk-981846fa644848c8a41aeff541c4184b", "createdAt": "2026-03-16T10:00:00.000Z"},
        "zhipu:manual": {"id": "zhipu:manual", "provider": "zhipu", "type": "api_key",
                          "token": "394303a081e64ed18eef8adfc35bd110.VckzW4eRTHUKN27c", "createdAt": "2026-03-16T10:00:00.000Z"},
        "groq:manual": {"id": "groq:manual", "provider": "groq", "type": "api_key",
                         "token": "GROQ_KEY_PLACEHOLDER", "createdAt": "2026-03-16T10:00:00.000Z"}
    }
}

with open(os.path.expanduser('~/.openclaw/agents/main/agent/auth-profiles.json'), 'w') as f:
    json.dump(auth, f, indent=2)

print("  ✅ OpenClaw 配置完成")
PYEOF

    # 将 placeholder 替换为真实 Groq Key
    sed -i '' "s|GROQ_KEY_PLACEHOLDER|${_GROQ_KEY}|g" \
        "$HOME/.openclaw/openclaw.json" \
        "$HOME/.openclaw/agents/main/agent/auth-profiles.json" 2>/dev/null || true
fi

# ── 停止旧进程 ───────────────────────────────────────────────
pkill -f "openclaw-gateway" 2>/dev/null || true
pkill -f "python3 server.py" 2>/dev/null || true
sleep 1

# ── 启动 OpenClaw Gateway ────────────────────────────────────
echo -e "${CYAN}🦞 启动 OpenClaw Gateway...${NC}"
nohup openclaw gateway run --bind loopback --port 18789 --force \
    > "$LOG_DIR/openclaw.log" 2>&1 &
echo $! > "$LOG_DIR/openclaw.pid"

# 等待 Gateway 就绪
for i in {1..15}; do
    if nc -z 127.0.0.1 18789 2>/dev/null; then
        echo -e "${GREEN}  ✅ OpenClaw Gateway 已就绪${NC}"; break
    fi
    sleep 1
done

# ── 启动代理服务器 ───────────────────────────────────────────
echo -e "${CYAN}🚀 启动代理服务器...${NC}"
cd "$PROJECT_DIR"
nohup python3 server.py > "$LOG_DIR/proxy.log" 2>&1 &
echo $! > "$LOG_DIR/proxy.pid"

# 等待代理就绪
for i in {1..15}; do
    if curl -s http://localhost:8082/health &>/dev/null; then
        echo -e "${GREEN}  ✅ 代理服务器已就绪${NC}"; break
    fi
    sleep 1
done

# ── 设置环境变量并启动 Claude Code ──────────────────────────
export ANTHROPIC_BASE_URL=http://localhost:8082
export ANTHROPIC_API_KEY=dummy

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  🎉 所有服务已就绪！正在启动 Claude Code...${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  模型优先级: ${CYAN}DeepSeek V3${NC} → ${YELLOW}智谱 GLM (免费)${NC} → ${GREEN}Groq (超快)${NC}"
echo -e "  停止服务:   ${CYAN}bash $PROJECT_DIR/stop.sh${NC}"
echo ""

# 启动 Claude Code
claude
