#!/bin/bash
# ============================================================
# Claude Code Local - Mac 一键安装脚本
# 运行方式: bash setup-mac.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     Claude Code Local - Mac 一键安装程序         ║${NC}"
echo -e "${CYAN}${BOLD}║     DeepSeek + 智谱 GLM + Groq 多模型支持        ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── 加载 .env 中的 API Keys ──────────────────────────────────
echo -e "${BLUE}[0/6] 加载 API Keys...${NC}"
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs) 2>/dev/null || true
    echo -e "${GREEN}  ✅ 已从 .env 加载 API Keys${NC}"
else
    echo -e "${YELLOW}  ⚠️  未找到 .env 文件，将使用默认配置${NC}"
fi

# ── 1. Homebrew ──────────────────────────────────────────────
echo -e "${BLUE}[1/6] 检查 Homebrew...${NC}"
if ! command -v brew &>/dev/null; then
    echo -e "${YELLOW}  正在安装 Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Apple Silicon 路径修复
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
else
    echo -e "${GREEN}  ✅ Homebrew 已安装${NC}"
fi

# ── 2. Node.js ───────────────────────────────────────────────
echo -e "${BLUE}[2/6] 检查 Node.js...${NC}"
if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}  正在安装 Node.js...${NC}"
    brew install node
else
    NODE_VER=$(node --version)
    echo -e "${GREEN}  ✅ Node.js $NODE_VER 已安装${NC}"
fi

# ── 3. Python ────────────────────────────────────────────────
echo -e "${BLUE}[3/6] 检查 Python...${NC}"
if ! command -v python3 &>/dev/null; then
    echo -e "${YELLOW}  正在安装 Python...${NC}"
    brew install python
else
    PY_VER=$(python3 --version)
    echo -e "${GREEN}  ✅ $PY_VER 已安装${NC}"
fi

# ── 4. Claude Code CLI & OpenClaw ────────────────────────────
echo -e "${BLUE}[4/6] 安装 Claude Code CLI 和 OpenClaw...${NC}"
if ! command -v claude &>/dev/null; then
    echo -e "${YELLOW}  正在安装 Claude Code CLI...${NC}"
    npm install -g @anthropic-ai/claude-code
else
    echo -e "${GREEN}  ✅ Claude Code CLI 已安装 ($(claude --version 2>/dev/null || echo 'ok'))${NC}"
fi

if ! command -v openclaw &>/dev/null; then
    echo -e "${YELLOW}  正在安装 OpenClaw...${NC}"
    npm install -g openclaw
else
    echo -e "${GREEN}  ✅ OpenClaw 已安装 ($(openclaw --version 2>/dev/null || echo 'ok'))${NC}"
fi

# ── 5. Python 依赖 ───────────────────────────────────────────
echo -e "${BLUE}[5/6] 安装 Python 依赖...${NC}"
cd "$SCRIPT_DIR"
pip3 install -q -r requirements.txt
echo -e "${GREEN}  ✅ Python 依赖安装完成${NC}"

# ── 6. 配置 OpenClaw ─────────────────────────────────────────
echo -e "${BLUE}[6/6] 配置 OpenClaw Gateway...${NC}"
mkdir -p ~/.openclaw/agents/main/agent

# 写入 openclaw.json（含三个提供商 + 故障转移）
python3 << 'PYEOF'
import json, os

config = {
    "meta": {"lastTouchedVersion": "2026.3.11"},
    "agents": {
        "defaults": {
            "model": {
                "primary": "deepseek/deepseek-chat",
                "fallbacks": [
                    "zhipu/glm-4-flash",
                    "groq/llama-3.3-70b-versatile"
                ]
            }
        }
    },
    "commands": {"native": "auto", "nativeSkills": "auto", "restart": True, "ownerDisplay": "raw"},
    "gateway": {
        "mode": "local",
        "bind": "loopback",
        "auth": {"token": "${OPENCLAW_GATEWAY_TOKEN}"},
        "http": {"endpoints": {"chatCompletions": {"enabled": True}}}
    },
    "models": {
        "mode": "merge",
        "providers": {
            "deepseek": {
                "baseUrl": "https://api.deepseek.com/v1",
                "apiKey": "${DEEPSEEK_API_KEY}",
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
                "apiKey": "${ZHIPU_API_KEY}",
                "api": "openai-completions",
                "models": [
                    {"id": "glm-4-flash", "name": "GLM-4 Flash (Free)", "reasoning": False, "input": ["text"],
                     "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
                     "contextWindow": 131072, "maxTokens": 4096},
                    {"id": "glm-z1-flash", "name": "GLM-Z1 Flash (Reasoning, Free)", "reasoning": True, "input": ["text"],
                     "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
                     "contextWindow": 131072, "maxTokens": 4096}
                ]
            },
            "groq": {
                "baseUrl": "https://api.groq.com/openai/v1",
                "apiKey": "${GROQ_API_KEY}",
                "api": "openai-completions",
                "models": [
                    {"id": "llama-3.3-70b-versatile", "name": "Llama 3.3 70B (Groq)", "reasoning": False, "input": ["text"],
                     "cost": {"input": 0.59, "output": 0.79, "cacheRead": 0, "cacheWrite": 0},
                     "contextWindow": 131072, "maxTokens": 32768},
                    {"id": "qwen/qwen3-32b", "name": "Qwen3 32B (Groq)", "reasoning": True, "input": ["text"],
                     "cost": {"input": 0.29, "output": 0.59, "cacheRead": 0, "cacheWrite": 0},
                     "contextWindow": 131072, "maxTokens": 40960}
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
                             "token": "${DEEPSEEK_API_KEY}", "createdAt": "2026-03-16T10:00:00.000Z"},
        "zhipu:manual": {"id": "zhipu:manual", "provider": "zhipu", "type": "api_key",
                          "token": "${ZHIPU_API_KEY}", "createdAt": "2026-03-16T10:00:00.000Z"},
        "groq:manual": {"id": "groq:manual", "provider": "groq", "type": "api_key",
                         "token": "${GROQ_API_KEY}", "createdAt": "2026-03-16T10:00:00.000Z"}
    }
}

with open(os.path.expanduser('~/.openclaw/agents/main/agent/auth-profiles.json'), 'w') as f:
    json.dump(auth, f, indent=2)

print("  ✅ OpenClaw 配置完成（DeepSeek + 智谱 + Groq）")
PYEOF

# ── 创建桌面快捷方式 ─────────────────────────────────────────
DESKTOP="$HOME/Desktop"
APP_NAME="Claude Code.command"
LAUNCH_SCRIPT="$DESKTOP/$APP_NAME"

cat > "$LAUNCH_SCRIPT" << APPEOF
#!/bin/bash
# Claude Code 一键启动
SCRIPT_DIR="$SCRIPT_DIR"

osascript -e 'tell application "Terminal"
    activate
    do script "echo \"\" && echo \"🦞 启动 OpenClaw Gateway...\" && openclaw gateway run"
    delay 3
    do script "echo \"\" && echo \"🚀 启动 Claude Code 代理服务器...\" && cd '"'"'$SCRIPT_DIR'"'"' && python3 server.py"
    delay 3
    do script "echo \"\" && echo \"✅ 所有服务已启动！\" && echo \"\" && echo \"使用方式：\" && echo \"  export ANTHROPIC_BASE_URL=http://localhost:8082\" && echo \"  claude\" && echo \"\" && export ANTHROPIC_BASE_URL=http://localhost:8082 && claude"
end tell'
APPEOF

chmod +x "$LAUNCH_SCRIPT"

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║           🎉 安装完成！                          ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}桌面快捷方式已创建：${NC} ${CYAN}~/Desktop/Claude Code.command${NC}"
echo ""
echo -e "${BOLD}使用方法：${NC}"
echo -e "  ${YELLOW}方式一（推荐）：${NC} 双击桌面上的 ${CYAN}Claude Code.command${NC} 图标"
echo -e "  ${YELLOW}方式二（手动）：${NC}"
echo -e "    终端1: ${CYAN}openclaw gateway run${NC}"
echo -e "    终端2: ${CYAN}cd $SCRIPT_DIR && python3 server.py${NC}"
echo -e "    终端3: ${CYAN}export ANTHROPIC_BASE_URL=http://localhost:8082 && claude${NC}"
echo ""
echo -e "${BOLD}已配置的 AI 模型：${NC}"
echo -e "  🥇 DeepSeek V3     (主力，性价比最高)"
echo -e "  🥈 智谱 GLM-4-Flash (备用，中文强，免费)"
echo -e "  🥉 Groq Llama 3.3  (备用，速度最快)"
echo ""
