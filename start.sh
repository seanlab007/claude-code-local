#!/usr/bin/env bash
# ============================================================
# Claude Code Local Proxy — Start Script
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$REPO_DIR/.venv"

# Load .env if exists
if [ -f "$REPO_DIR/.env" ]; then
    export $(grep -v '^#' "$REPO_DIR/.env" | xargs -d '\n' 2>/dev/null || true)
fi

PORT="${PROXY_PORT:-8082}"
HOST="${PROXY_HOST:-0.0.0.0}"
PROVIDER="${PREFERRED_PROVIDER:-anthropic}"

echo "🦞 Claude Code Local Proxy"
echo "   Provider : $PROVIDER"
echo "   Address  : http://$HOST:$PORT"
echo ""
echo "Use Claude Code with:"
echo "   ANTHROPIC_BASE_URL=http://localhost:$PORT claude"
echo ""

# Activate venv if exists
if [ -d "$VENV_DIR" ]; then
    source "$VENV_DIR/bin/activate"
fi

# Start server
exec python3 "$REPO_DIR/server.py"
