#!/usr/bin/env bash
#===========================================================
# cleanup_empty_folders.sh - 空の日付フォルダを削除するスクリプト
#===========================================================
# Flow/PrivateとFlow/Public内の空の日付フォルダを削除します
# 使い方: ./scripts/cleanup_empty_folders.sh
#===========================================================

set -euo pipefail

ROOT_DIR="$(pwd)"
FLOW_DIR="${ROOT_DIR}/Flow"
PRIVATE_DIR="${FLOW_DIR}/Private"
PUBLIC_DIR="${FLOW_DIR}/Public"

# 出力用のカラー
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# ログ関数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ディレクトリが存在するか確認
if [[ ! -d "${PRIVATE_DIR}" ]]; then
  log_error "Privateディレクトリが見つかりません: ${PRIVATE_DIR}"
  exit 1
fi

if [[ ! -d "${PUBLIC_DIR}" ]]; then
  log_error "Publicディレクトリが見つかりません: ${PUBLIC_DIR}"
  exit 1
fi

log_info "Flow/Private内の空の日付フォルダを検索しています..."
private_empty_count=0
private_date_dirs=($(find "${PRIVATE_DIR}" -maxdepth 1 -type d -name "20??-??-??"))

for dir in "${private_date_dirs[@]}"; do
  # ファイル数をカウント（隠しファイルを含む）
  file_count=$(find "$dir" -type f | wc -l | tr -d ' ')
  
  if [[ "$file_count" -eq 0 ]]; then
    log_info "空のフォルダを削除: $(basename "$dir") (Flow/Private)"
    rm -rf "$dir"
    private_empty_count=$((private_empty_count + 1))
  fi
done

log_info "Flow/Public内の空の日付フォルダを検索しています..."
public_empty_count=0
public_date_dirs=($(find "${PUBLIC_DIR}" -maxdepth 1 -type d -name "20??-??-??"))

for dir in "${public_date_dirs[@]}"; do
  # ファイル数をカウント（隠しファイルを含む）
  file_count=$(find "$dir" -type f | wc -l | tr -d ' ')
  
  if [[ "$file_count" -eq 0 ]]; then
    log_info "空のフォルダを削除: $(basename "$dir") (Flow/Public)"
    rm -rf "$dir"
    public_empty_count=$((public_empty_count + 1))
  fi
done

log_info "クリーンアップ完了！"
log_info "Flow/Private内の削除された空フォルダ: $private_empty_count 個"
log_info "Flow/Public内の削除された空フォルダ: $public_empty_count 個"

# 残っているフォルダ数を表示
remaining_private=$(find "${PRIVATE_DIR}" -maxdepth 1 -type d -name "20??-??-??" | wc -l | tr -d ' ')
remaining_public=$(find "${PUBLIC_DIR}" -maxdepth 1 -type d -name "20??-??-??" | wc -l | tr -d ' ')

log_info "残っているフォルダ数:"
log_info "Flow/Private: $remaining_private 個"
log_info "Flow/Public: $remaining_public 個" 