#!/bin/bash

# sync_specific_file.sh
# 特定のFlowファイルのみをStockに同期するスクリプト

if [ $# -lt 1 ]; then
  echo "使用方法: $0 <Flowのファイルパス>"
  exit 1
fi

FLOW_FILE="$1"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# ファイル名から種類を判断
FILENAME=$(basename "$FLOW_FILE")

# 設定ファイルを読み込む
source "${SCRIPT_DIR}/flow_to_stock_config.sh"

# ディスカバリーディレクトリ（config.shにない場合は設定）
DISCOVERY_DIR="${PROJECT_DOCS_DIR}/2_discovery"
mkdir -p "${DISCOVERY_DIR}"

# 同期先を決定
if [[ "$FILENAME" == *"project_charter"* ]]; then
  STOCK_PATH="${PROJECT_CHARTER_STOCK}"
elif [[ "$FILENAME" == *"stakeholder"*"register"* ]]; then
  STOCK_PATH="${STAKEHOLDER_REGISTER_STOCK}"
elif [[ "$FILENAME" == *"wbs"* ]]; then
  STOCK_PATH="${WBS_STOCK}"
elif [[ "$FILENAME" == *"risk_plan"* ]]; then
  STOCK_PATH="${RISK_PLAN_STOCK}"
elif [[ "$FILENAME" == *"assumption_map"* ]]; then
  STOCK_PATH="${DISCOVERY_DIR}/assumption_map.md"
elif [[ "$FILENAME" == *"persona"* ]]; then
  STOCK_PATH="${DISCOVERY_DIR}/persona.md"
elif [[ "$FILENAME" == *"problem_statement"* ]]; then
  STOCK_PATH="${DISCOVERY_DIR}/problem_statement.md"
elif [[ "$FILENAME" == *"hypothesis"* ]]; then
  STOCK_PATH="${DISCOVERY_DIR}/hypothesis_backlog.md"
else
  echo "未対応のファイル種類です: $FILENAME"
  exit 1
fi

# ディレクトリ作成
mkdir -p "$(dirname "$STOCK_PATH")"

# アーカイブディレクトリの作成
ARCHIVE_DIR="${ARCHIVE_ROOT}/$(date +"%Y%m%d")"
mkdir -p "$ARCHIVE_DIR"

# 既存ファイルのバックアップ
if [ -f "$STOCK_PATH" ]; then
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  STOCK_FILENAME=$(basename "$STOCK_PATH")
  cp "$STOCK_PATH" "${ARCHIVE_DIR}/${STOCK_FILENAME%.md}_${TIMESTAMP}.md"
  echo "バックアップ作成: ${ARCHIVE_DIR}/${STOCK_FILENAME%.md}_${TIMESTAMP}.md"
fi

# ファイルをコピー
cp "$FLOW_FILE" "$STOCK_PATH"
echo "同期完了: $FLOW_FILE → $STOCK_PATH"

exit 0 