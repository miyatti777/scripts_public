#!/bin/bash

# flow_to_stock.sh
# Flow→Stock同期処理のメインスクリプト

# 現在の日付を取得 (YYYY-MM-DD形式)
TODAY=$(date +"%Y-%m-%d")

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 設定ファイルを読み込む
source "${SCRIPT_DIR}/flow_to_stock_config.sh"

# ログディレクトリがなければ作成
mkdir -p "$(dirname "${LOG_FILE}")"

# ログ出力関数
log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "${LOG_FILE}"
}

# エラーログ出力関数
error_log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] [ERROR] $1" | tee -a "${LOG_FILE}"
}

# ファイルのバックアップを作成
backup_file() {
  local source_file="$1"
  local backup_dir="${ARCHIVE_ROOT}/$(date +"%Y%m%d")"
  
  if [ -f "$source_file" ]; then
    # バックアップディレクトリがなければ作成
    mkdir -p "$backup_dir"
    
    # ファイル名のみを取得
    local filename=$(basename "$source_file")
    
    # タイムスタンプ付きでコピー
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    cp "$source_file" "${backup_dir}/${filename%.md}_${timestamp}.md"
    
    log "バックアップ作成: ${backup_dir}/${filename%.md}_${timestamp}.md"
    return 0
  else
    error_log "バックアップ失敗: ファイル '$source_file' が存在しません"
    return 1
  fi
}

# Flowフォルダから最新のファイルを見つける
find_latest_flow_file() {
  local filename_pattern="$1"
  local latest_file=""
  
  # Flowフォルダ内の日付フォルダを降順で検索
  for date_dir in $(find "${FLOW_ROOT}/Private" "${FLOW_ROOT}/Public" -maxdepth 1 -type d -name "20*" | sort -r); do
    # 指定パターンのファイルを検索
    local found_file=$(find "${date_dir}" -type f -name "${filename_pattern}" | head -n 1)
    
    if [ -n "$found_file" ]; then
      latest_file="$found_file"
      break
    fi
  done
  
  echo "$latest_file"
}

# バックログディレクトリを探す
find_latest_backlog_dir() {
  local latest_dir=""
  
  # Flowフォルダ内の日付フォルダを降順で検索
  for date_dir in $(find "${FLOW_ROOT}/Private" "${FLOW_ROOT}/Public" -maxdepth 1 -type d -name "20*" | sort -r); do
    # バックログディレクトリを検索
    if [ -d "${date_dir}/backlog" ]; then
      latest_dir="${date_dir}/backlog"
      break
    fi
  done
  
  echo "$latest_dir"
}

# FlowからStockへファイルをコピー
sync_file() {
  local file_pattern="$1"
  local stock_path="$2"
  local stock_dir=$(dirname "$stock_path")
  
  # ストックディレクトリがなければ作成
  mkdir -p "$stock_dir"
  
  # 最新のフローファイルを見つける
  local latest_flow_file=$(find_latest_flow_file "$file_pattern")
  
  if [ -n "$latest_flow_file" ] && [ -f "$latest_flow_file" ]; then
    # 既存のファイルがあればバックアップ
    if [ -f "$stock_path" ]; then
      backup_file "$stock_path"
    fi
    
    # ファイルをコピー
    cp "$latest_flow_file" "$stock_path"
    log "同期完了: $latest_flow_file → $stock_path"
    return 0
  else
    error_log "同期失敗: パターン '$file_pattern' の最新ファイルが見つかりません"
    return 1
  fi
}

# バックログ同期関数
sync_backlog() {
  log "バックログの同期を開始します..."
  
  # 最新のバックログディレクトリを見つける
  local latest_backlog_dir=$(find_latest_backlog_dir)
  
  if [ -z "$latest_backlog_dir" ]; then
    error_log "バックログディレクトリが見つかりません"
    return 1
  fi
  
  # バックログディレクトリがなければ作成
  mkdir -p "${BACKLOG_STOCK_DIR}"
  mkdir -p "${STORIES_STOCK_DIR}"
  
  # エピックYAMLの同期
  if [ -f "${latest_backlog_dir}/epics.yaml" ]; then
    cp "${latest_backlog_dir}/epics.yaml" "${BACKLOG_STOCK_DIR}/epics.yaml"
    log "エピックファイルを同期しました: epics.yaml"
  else
    error_log "エピックファイルが見つかりません: ${latest_backlog_dir}/epics.yaml"
  fi
  
  # ストーリーファイルの同期
  if [ -d "${latest_backlog_dir}/stories" ]; then
    # 各ストーリーファイルをコピー
    find "${latest_backlog_dir}/stories" -name "*.md" -type f | while read story_file; do
      story_filename=$(basename "$story_file")
      cp "$story_file" "${STORIES_STOCK_DIR}/$story_filename"
      log "ストーリーファイルを同期しました: $story_filename"
    done
    log "ストーリーファイルの同期が完了しました"
  else
    error_log "ストーリーディレクトリが見つかりません: ${latest_backlog_dir}/stories"
    return 1
  fi
  
  log "バックログの同期が完了しました"
  return 0
}

# メイン処理
main() {
  log "Flow→Stock同期処理を開始します..."
  
  # 同期対象のリスト
  local sync_list=(
    "project_charter*.md:${PROJECT_CHARTER_STOCK}"
    "*stakeholder*register*.md:${STAKEHOLDER_REGISTER_STOCK}"
    "*wbs*.md:${WBS_STOCK}"
    "*risk_plan*.md:${RISK_PLAN_STOCK}"
    "lessons_learned*.md:${LESSONS_LEARNED_STOCK}"
    "*product_backlog*.md:${PRODUCT_BACKLOG_STOCK}"
    "draft_release_roadmap*.md:${RELEASE_ROADMAP_STOCK}"
  )
  
  # エラーカウント
  local error_count=0
  
  # ファイル同期の実行
  for sync_item in "${sync_list[@]}"; do
    IFS=':' read -r pattern destination <<< "$sync_item"
    log "同期処理: パターン '$pattern' → '$destination'"
    
    if ! sync_file "$pattern" "$destination"; then
      ((error_count++))
    fi
  done
  
  # バックログの同期（特殊処理）
  if ! sync_backlog; then
    ((error_count++))
  fi
  
  # 会議議事録の同期（特殊処理）
  local meeting_pattern="meeting_*.md"
  local latest_meeting=$(find_latest_flow_file "$meeting_pattern")
  
  if [ -n "$latest_meeting" ] && [ -f "$latest_meeting" ]; then
    local meeting_filename=$(basename "$latest_meeting")
    mkdir -p "${MEETINGS_DIR}"
    
    # 会議議事録は日付付きでコピー（上書きではなく追加）
    cp "$latest_meeting" "${MEETINGS_DIR}/${meeting_filename}"
    log "会議議事録を同期: $latest_meeting → ${MEETINGS_DIR}/${meeting_filename}"
  fi
  
  # 結果出力
  if [ $error_count -eq 0 ]; then
    log "Flow→Stock同期処理が正常に完了しました。"
    return 0
  else
    error_log "Flow→Stock同期処理が完了しましたが、${error_count}件のエラーがありました。"
    return 1
  fi
}

# メイン処理の実行
main
exit $? 