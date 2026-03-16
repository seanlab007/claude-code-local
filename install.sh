#!/usr/bin/env bash
# ============================================================
# Claude Code Local Proxy — Quick Install Script
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$REPO_DIR/.venv"

echo "╔══════════════════════════════════════════════╗"
echo "║   Claude Code Local Proxy — Installer        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ─── Check Python ─────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "❌ Python 3 not found. Please install Python 3.11+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "✅ Python $PYTHON_VERSION found"

# ─── Create virtual environment ───────────────────────────────
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# ─── Install dependencies ─────────────────────────────────────
echo "📥 Installing dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r "$REPO_DIR/requirements.txt"
echo "✅ Dependencies installed"

# ─── Configure .env ───────────────────────────────────────────
if [ ! -f "$REPO_DIR/.env" ]; then
    echo ""
    echo "⚙️  Creating .env from template..."
    cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
    echo "📝 Please edit $REPO_DIR/.env with your API keys"
fi

# ─── Check Claude Code CLI ────────────────────────────────────
echo ""
if command -v claude &>/dev/null; then
    echo "✅ Claude Code CLI found: $(claude --version 2>&1 | head -1)"
else
    echo "⚠️  Claude Code CLI not found. Installing..."
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
        echo "✅ Claude Code CLI installed"
    else
        echo "❌ npm not found. Please install Node.js and run:"
        echo "   npm install -g @anthropic-ai/claude-code"
    fi
fi

# ─── Done ─────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Installation Complete!                     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your API keys"
echo "  2. Start the proxy:  ./start.sh"
echo "  3. Use Claude Code:  ANTHROPIC_BASE_URL=http://localhost:8082 claude"
echo ""
