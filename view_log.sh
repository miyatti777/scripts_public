#!/bin/bash
# SpecStory ログビューアショートカット
# 使い方: ./view_log.sh <SpecStory_LOG_PATH>

set -e

# 引数チェック
if [ $# -lt 1 ]; then
  echo "使用方法: $0 <SpecStory_LOG_PATH>"
  echo "例: $0 .specstory/history/2025-04-23_09-00-kakakucomプロジェクト憲章作成.md"
  exit 1
fi

INPUT_PATH="$1"
BASENAME=$(basename "$INPUT_PATH")
FILENAME="${BASENAME%.*}"
OUTPUT_DIR="temp/html"
OUTPUT_PATH="$OUTPUT_DIR/$FILENAME.html"

# 出力ディレクトリを作成
mkdir -p "$OUTPUT_DIR"

# HTMLに変換
echo "変換中: $INPUT_PATH -> $OUTPUT_PATH"
./scripts/specstory_viewer.py "$INPUT_PATH" -o "$OUTPUT_PATH"

# ブラウザで開く
if [ -f "$OUTPUT_PATH" ]; then
  echo "ブラウザで開いています..."
  open "$OUTPUT_PATH"
else
  echo "エラー: HTML ファイルが生成されませんでした。"
  exit 1
fi 