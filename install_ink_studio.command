#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/_tools"
TARGET_DIR="$TOOLS_DIR/ink-studio"

# Ensure Homebrew / nvm Node.js paths are available when launched from Finder
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if [ -d "$HOME/.nvm/versions/node" ]; then
  LATEST_NVM="$(ls "$HOME/.nvm/versions/node" | sort -V | tail -n 1)"
  [ -n "$LATEST_NVM" ] && export PATH="$HOME/.nvm/versions/node/$LATEST_NVM/bin:$PATH"
fi

echo "=== Ink Studio (@shapeshift-labs/ink-studio) 安裝與驗證腳本 ==="

if ! command -v node >/dev/null 2>&1; then
  echo "❌ 尚未偵測到 Node.js（需要 Node.js 18 或以上版本）。"
  echo "👉 請先執行：brew install node  或至 https://nodejs.org/ 下載安裝 LTS 版本後再重跑此腳本。"
  read -p "按 Enter 鍵關閉視窗..."
  exit 1
fi

NODE_VER="$(node -v)"
echo "✅ 偵測到 Node.js: $NODE_VER"

mkdir -p "$TOOLS_DIR"
if [ -d "$TARGET_DIR/.git" ]; then
  echo "🔄 偵測到既有安裝，正在更新最新程式碼..."
  git -C "$TARGET_DIR" pull --ff-only
else
  rm -rf "$TARGET_DIR"
  echo "⬇️ 正在下載 https://github.com/siliconjungle/shapeshift-labs-ink-studio ..."
  git clone https://github.com/siliconjungle/shapeshift-labs-ink-studio.git "$TARGET_DIR"
fi

cd "$TARGET_DIR"
echo "🔍 驗證 Ink Studio CLI..."
node cli/ink-studio.js help | head -n 18
echo ""
echo "📋 內建範例場景清單："
node cli/ink-studio.js scenes
echo ""
echo "🎨 試算範例圖（watcher）..."
node cli/ink-studio.js render watcher --t 2.6 --colored
echo ""
echo "🎉 安裝與試算完成！輸出目錄：$TARGET_DIR/studio/out/"
read -p "按 Enter 鍵關閉視窗..."
