#!/usr/bin/env bash
#---
# scaffold_project.sh
#  使い方: ./scaffold_project.sh <ROOT_PATH> <PROJECT_ID>
#  例    : ./scaffold_project.sh ~/ProjectWorkspace WEBPORTAL-X
#---

set -e

# 引数チェック
if [ $# -ne 2 ]; then
  echo "Usage: $0 <ROOT_PATH> <PROJECT_ID>"
  exit 1
fi

ROOT=$(realpath "$1")          # ルートディレクトリ
PID="$2"                       # プロジェクトID

# 変数展開
FLOW="$ROOT/Flow"
STOCK="$ROOT/Stock"
ARCH="$ROOT/Archived"
RULES="$ROOT/.cursor/rules"
PRIVATE="$FLOW/Private"
PUBLIC="$FLOW/Public"
COMPANY_KNOWLEDGE="$STOCK/company_knowledge"

TODAY=$(date +%Y-%m-%d)

# -----
echo "🛠  ディレクトリを生成しています ..."
# Flow
mkdir -p "$FLOW/templates" \
         "$PRIVATE/$TODAY" \
         "$PRIVATE/templates" \
         "$PUBLIC/$TODAY" \
         "$PUBLIC/templates"

# Stock
mkdir -p \
  "$STOCK/projects/$PID/documents/1_initiating" \
  "$STOCK/projects/$PID/documents/2_discovery" \
  "$STOCK/projects/$PID/documents/3_planning" \
  "$STOCK/projects/$PID/documents/4_executing" \
  "$STOCK/projects/$PID/documents/5_monitoring" \
  "$STOCK/projects/$PID/documents/6_closing" \
  "$STOCK/projects/$PID/documents/7_testing" \
  "$STOCK/projects/$PID/documents/8_flow_assist" \
  "$STOCK/shared/templates" \
  "$COMPANY_KNOWLEDGE"

# Archived
mkdir -p "$ARCH/projects"

# ルール置き場
mkdir -p "$RULES"

echo "✅ 完了: ディレクトリ構成を生成しました"
echo "  Root : $ROOT"
echo "  Flow : $PRIVATE/$TODAY および $PUBLIC/$TODAY"
echo "  Stock: $STOCK/projects/$PID" 