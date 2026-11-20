#!/bin/bash
set -e
cd "$(dirname "$0")"

GODOT_BIN="./_tools/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$GODOT_BIN" ]; then
  echo "找不到 $GODOT_BIN，請確認 Godot.app 位於 _tools/Godot.app"
  exit 1
fi

RAW_AVI="$(pwd)/playtest_raw.avi"
OUT_MP4="$(pwd)/playtest_act1_full_showcase.mp4"

echo "正在啟動 Godot 並執行《補簽遠行》第一幕全 6 區＋摺紙世界地圖自動試玩與錄影..."
"$GODOT_BIN" --path "$(pwd)/game" --write-movie "$RAW_AVI" --fixed-fps 30 -- --autoplay

echo "錄影完成，正在透過 ffmpeg 轉檔為 MP4..."
FFMPEG_BIN="/opt/homebrew/bin/ffmpeg"
if [ ! -x "$FFMPEG_BIN" ]; then
  FFMPEG_BIN="$(which ffmpeg || true)"
fi

if [ -n "$FFMPEG_BIN" ]; then
  "$FFMPEG_BIN" -y -i "$RAW_AVI" -c:v libx264 -pix_fmt yuv420p -crf 20 -preset fast "$OUT_MP4"
  rm -f "$RAW_AVI"
  echo "完成！第一幕全內容試玩影片已輸出至：$OUT_MP4"
  open -R "$OUT_MP4"
else
  echo "找不到 ffmpeg，原始錄影檔保留於：$RAW_AVI"
  open -R "$RAW_AVI"
fi
