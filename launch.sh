#!/bin/bash
# ============================================================
# Claude Code Local - 一键启动脚本 (Mac)
# 双击此文件即可启动所有服务
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.claude-code-local/logs"
mkdir -p "$LOG_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── 停止旧进程 ───────────────────────────────────────────────
echo -e "${YELLOW}🔄 停止旧进程...${NC}"
pkill -f "openclaw-gateway" 2>/dev/null || true
pkill -f "python3 server.py" 2>/dev/null || true
sleep 1

# ── 检查依赖 ─────────────────────────────────────────────────
if ! command -v openclaw &>/dev/null; then
    echo -e "${RED}❌ OpenClaw 未安装，请先运行: bash setup-mac.sh${NC}"
    exit 1
fi
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}❌ Python3 未安装，请先运行: bash setup-mac.sh${NC}"
    exit 1
fi

# ── 启动 OpenClaw Gateway ────────────────────────────────────
echo -e "${CYAN}🦞 启动 OpenClaw Gateway (端口 18789)...${NC}"
nohup openclaw gateway run --bind loopback --port 18789 --force \
    > "$LOG_DIR/openclaw.log" 2>&1 &
OPENCLAW_PID=$!
echo $OPENCLAW_PID > "$LOG_DIR/openclaw.pid"

# 等待 Gateway 启动
for i in {1..10}; do
    if nc -z 127.0.0.1 18789 2>/dev/null; then
        echo -e "${GREEN}  ✅ OpenClaw Gateway 已就绪 (PID: $OPENCLAW_PID)${NC}"
        break
    fi
    sleep 1
done

# ── 启动代理服务器 ───────────────────────────────────────────
echo -e "${CYAN}🚀 启动 Claude Code 代理服务器 (端口 8082)...${NC}"
cd "$SCRIPT_DIR"
nohup python3 server.py > "$LOG_DIR/proxy.log" 2>&1 &
PROXY_PID=$!
echo $PROXY_PID > "$LOG_DIR/proxy.pid"

# 等待代理启动
for i in {1..10}; do
    if curl -s http://localhost:8082/health &>/dev/null; then
        echo -e "${GREEN}  ✅ 代理服务器已就绪 (PID: $PROXY_PID)${NC}"
        break
    fi
    sleep 1
done

# ── 健康检查 ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
HEALTH=$(curl -s http://localhost:8082/health 2>/dev/null)
if echo "$HEALTH" | grep -q '"status"'; then
    echo -e "${GREEN}${BOLD}  🎉 所有服务运行正常！${NC}"
    PROVIDER=$(echo "$HEALTH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('provider','?'))" 2>/dev/null)
    echo -e "  当前提供商: ${CYAN}$PROVIDER${NC}"
else
    echo -e "${RED}  ⚠️  服务可能未完全就绪，请查看日志: $LOG_DIR${NC}"
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}现在可以使用 Claude Code：${NC}"
echo ""
echo -e "  ${YELLOW}export ANTHROPIC_BASE_URL=http://localhost:8082${NC}"
echo -e "  ${YELLOW}claude${NC}"
echo ""
echo -e "${BOLD}或者直接运行（已配置环境变量）：${NC}"
echo ""
echo -e "  ${CYAN}source ~/.claude-code-local/env.sh && claude${NC}"
echo ""

# ── 写入环境变量文件 ─────────────────────────────────────────
mkdir -p ~/.claude-code-local
cat > ~/.claude-code-local/env.sh << 'ENVEOF'
export ANTHROPIC_BASE_URL=http://localhost:8082
export ANTHROPIC_API_KEY=dummy
echo "✅ Claude Code 环境变量已设置"
echo "   ANTHROPIC_BASE_URL=http://localhost:8082"
echo "   现在运行: claude"
ENVEOF

echo -e "${BOLD}日志文件：${NC}"
echo -e "  OpenClaw: ${CYAN}$LOG_DIR/openclaw.log${NC}"
echo -e "  代理服务: ${CYAN}$LOG_DIR/proxy.log${NC}"
echo ""
echo -e "${BOLD}停止所有服务：${NC} ${CYAN}bash stop.sh${NC}"
echo ""
