#!/bin/bash
# ============================================================
# Claude Code - Mac 桌面图标安装脚本
# 运行此脚本后，桌面会出现带漂亮图标的 Claude Code.app
# ============================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Claude Code"
APP_PATH="$HOME/Desktop/${APP_NAME}.app"

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║     🎨 Claude Code 图标安装程序          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── 第一步：将 iconset 转换为 .icns ──────────────────────────
echo -e "${YELLOW}▶ 正在生成 .icns 图标文件...${NC}"
ICONSET_DIR="$SCRIPT_DIR/AppIcon.iconset"
ICNS_PATH="$SCRIPT_DIR/AppIcon.icns"

if command -v iconutil &>/dev/null; then
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
    echo -e "${GREEN}✅ .icns 文件生成成功${NC}"
else
    echo -e "${YELLOW}⚠️  iconutil 不可用，使用 PNG 图标替代${NC}"
    cp "$SCRIPT_DIR/icon_v1.png" "$ICNS_PATH" 2>/dev/null || true
fi

# ── 第二步：创建 .app 应用包结构 ─────────────────────────────
echo -e "${YELLOW}▶ 正在创建 Claude Code.app 应用包...${NC}"

# 删除旧版本
rm -rf "$APP_PATH"

# 创建目录结构
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 写入 Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.seanlab007.claude-code-local</string>
    <key>CFBundleName</key>
    <string>Claude Code</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Code</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST

# 复制图标
if [ -f "$ICNS_PATH" ]; then
    cp "$ICNS_PATH" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

# 写入启动器脚本
cat > "$APP_PATH/Contents/MacOS/launcher" << LAUNCHER
#!/bin/bash
# Claude Code Launcher
PROJECT_DIR="${PROJECT_DIR}"
cd "\$PROJECT_DIR"

# 修复 PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\$PATH"
[ -f /opt/homebrew/bin/brew ] && eval "\$(/opt/homebrew/bin/brew shellenv)"

# 打开终端并运行
osascript << 'APPLESCRIPT'
tell application "Terminal"
    activate
    set win1 to do script "echo '🚀 正在启动 OpenClaw Gateway...' && openclaw gateway run 2>&1"
    delay 2
    set win2 to do script "echo '🔧 正在启动代理服务器...' && cd \"${PROJECT_DIR}\" && python3 server.py 2>&1"
    delay 3
    set win3 to do script "echo '🤖 正在启动 Claude Code...' && export ANTHROPIC_BASE_URL=http://localhost:8082 && claude"
end tell
APPLESCRIPT
LAUNCHER

chmod +x "$APP_PATH/Contents/MacOS/launcher"

# ── 第三步：清除隔离属性 ─────────────────────────────────────
xattr -cr "$APP_PATH" 2>/dev/null || true

echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ 安装完成！                           ║"
echo "║                                          ║"
echo "║  桌面已出现 Claude Code 图标             ║"
echo "║  双击即可启动所有服务！                  ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# 在 Finder 中显示
open -R "$APP_PATH" 2>/dev/null || true
