#!/usr/bin/env bash
#============================================================
# scaffold_project_folders.sh
#  ── プロジェクト固有フォルダだけを一括生成するスクリプト
#  使い方 : ./scaffold_project_folders.sh <ROOT_PATH> <PROJECT_ID>
#  例     : ./scaffold_project_folders.sh ~/ProjectWorkspace WEBPORTAL-X
#============================================================

set -euo pipefail

# ---------- 0. 引数チェック ----------
if [ $# -ne 2 ]; then
  cat << EOS >&2
Usage : $0 <ROOT_PATH> <PROJECT_ID>
例    : $0 ~/ProjectWorkspace WEBPORTAL-X
EOS
  exit 1
fi

ROOT=$(realpath "$1")      # ルートディレクトリ
PID="$2"                   # プロジェクト ID  (フォルダ名に使用)

STOCK="$ROOT/Stock"        # Stock ルート
PROJ_ROOT="$STOCK/projects/$PID"
DOCS="$PROJ_ROOT/documents"

# ---------- 1. 作るディレクトリ一覧 ----------
DIRS=(
  "$DOCS/1_initiating"
  "$DOCS/3_planning"
  "$DOCS/2_discovery"
  "$DOCS/4_executing"
  "$DOCS/5_monitoring"
  "$DOCS/6_closing"
  "$DOCS/templates"              # 共通テンプレ置き場
)

# ---------- 2. 既存確認 ----------
if [ -d "$PROJ_ROOT" ]; then
  echo "⚠️  既に $PROJ_ROOT が存在します。中身を壊さないようスキップします。" >&2
else
  echo "🛠  新規プロジェクトフォルダを作成します ..."
  for d in "${DIRS[@]}"; do
    mkdir -p "$d"
  done
  echo "✅ 完了: $PROJ_ROOT を生成しました"
fi 