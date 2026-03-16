#!/bin/bash
# ============================================================
# 创建 Mac 桌面应用图标（.app）
# 运行后桌面会出现一个可双击的 "Claude Code" 应用图标
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Claude Code"
APP_PATH="$HOME/Desktop/$APP_NAME.app"

echo "🔨 创建 Mac 桌面应用: $APP_PATH"

# 创建 .app 目录结构
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 写入 Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launch</string>
    <key>CFBundleIdentifier</key>
    <string>com.seanlab007.claude-code-local</string>
    <key>CFBundleName</key>
    <string>Claude Code</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Code</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLISTEOF

# 写入可执行文件（启动 Terminal 并运行所有服务）
cat > "$APP_PATH/Contents/MacOS/launch" << EXECEOF
#!/bin/bash
SCRIPT_DIR="$SCRIPT_DIR"

# 用 Terminal 打开并运行启动脚本
osascript << 'ASEOF'
tell application "Terminal"
    activate
    -- 窗口1: OpenClaw Gateway
    set w1 to do script "clear; echo '🦞 OpenClaw Gateway 启动中...'; openclaw gateway run --bind loopback --port 18789 --force"
    set custom title of w1 to "OpenClaw Gateway"
    delay 4
    -- 窗口2: 代理服务器
    set w2 to do script "clear; echo '🚀 代理服务器启动中...'; cd '$SCRIPT_DIR' && python3 server.py"
    set custom title of w2 to "Claude Code Proxy"
    delay 4
    -- 窗口3: Claude Code CLI
    set w3 to do script "clear; echo ''; echo '✅ 所有服务已就绪！'; echo ''; echo '═══════════════════════════════════'; echo '  🤖 Claude Code - 本地 AI 编程助手'; echo '═══════════════════════════════════'; echo ''; echo '  模型优先级:'; echo '  1. DeepSeek V3 (主力)'; echo '  2. 智谱 GLM-4-Flash (备用, 免费)'; echo '  3. Groq Llama 3.3 70B (备用)'; echo ''; export ANTHROPIC_BASE_URL=http://localhost:8082; export ANTHROPIC_API_KEY=dummy; claude"
    set custom title of w3 to "Claude Code"
end tell
ASEOF
EXECEOF

chmod +x "$APP_PATH/Contents/MacOS/launch"

# 下载 Claude 图标（如果有网络）
# 使用系统自带终端图标作为备用
cp /System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns \
   "$APP_PATH/Contents/Resources/AppIcon.icns" 2>/dev/null || true

echo ""
echo "✅ 桌面应用已创建: ~/Desktop/Claude Code.app"
echo ""
echo "使用方法: 双击桌面上的 'Claude Code' 图标即可启动"
echo ""
echo "注意: 首次运行时 macOS 可能提示安全警告，请："
echo "  系统设置 → 隐私与安全性 → 点击「仍要打开」"
echo ""
