#!/bin/bash
# Claude Code Local - 停止所有服务

LOG_DIR="$HOME/.claude-code-local/logs"

echo "🛑 停止 Claude Code 本地服务..."

# 通过 PID 文件停止
if [ -f "$LOG_DIR/openclaw.pid" ]; then
    kill -9 $(cat "$LOG_DIR/openclaw.pid") 2>/dev/null && echo "  ✅ OpenClaw Gateway 已停止"
    rm -f "$LOG_DIR/openclaw.pid"
fi

if [ -f "$LOG_DIR/proxy.pid" ]; then
    kill -9 $(cat "$LOG_DIR/proxy.pid") 2>/dev/null && echo "  ✅ 代理服务器已停止"
    rm -f "$LOG_DIR/proxy.pid"
fi

# 兜底：按进程名停止
pkill -f "openclaw-gateway" 2>/dev/null || true
pkill -f "python3 server.py" 2>/dev/null || true

echo "✅ 所有服务已停止"
