#!/usr/bin/env bash
#===========================================================
# batch_rename.sh - フォルダ名とファイル内のワードを一括変更するスクリプト
#===========================================================
# 以下の変更を一括で行います：
# 3_planning -> 3_planning
# 4_executing -> 4_executing
# 5_monitoring -> 5_monitoring
# 6_closing -> 6_closing
# 
# 使い方: ./scripts/batch_rename.sh
#===========================================================

set -euo pipefail

ROOT_DIR="$(pwd)"

# 出力用のカラー
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 変換マップ定義（逆順で処理することで競合を避ける）
FOLDER_CONVERSIONS=(
  "6_closing:6_closing"
  "5_monitoring:5_monitoring"
  "4_executing:4_executing"
  "3_planning:3_planning"
)

TEXT_CONVERSIONS=(
  "6_closing:6_closing"
  "5_monitoring:5_monitoring"
  "4_executing:4_executing"
  "3_planning:3_planning"
)

# バックアップディレクトリ
BACKUP_DIR="${ROOT_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"
log_info "バックアップディレクトリを作成しました: ${BACKUP_DIR}"

# バックアップの作成
log_step "ワークスペースのバックアップを作成しています..."
find "${ROOT_DIR}" -type d -name "*_planning" -o -name "*_executing" -o -name "*_monitoring" -o -name "*_closing" | while read dir; do
  rel_path="${dir#${ROOT_DIR}/}"
  backup_path="${BACKUP_DIR}/${rel_path}"
  mkdir -p "$(dirname "${backup_path}")"
  cp -r "$dir" "$(dirname "${backup_path}")"
  log_info "バックアップ完了: ${rel_path}"
done

# フォルダ名の変更処理
log_step "フォルダ名を変更しています..."
for conversion in "${FOLDER_CONVERSIONS[@]}"; do
  old="${conversion%%:*}"
  new="${conversion##*:}"
  
  log_info "検索: ${old} → ${new}"
  
  # ディレクトリを検索して名前変更
  find "${ROOT_DIR}" -type d -name "*${old}" | while read dir; do
    if [[ "${dir}" != *"${BACKUP_DIR}"* ]]; then
      new_dir="${dir/${old}/${new}}"
      log_info "フォルダ名変更: ${dir} → ${new_dir}"
      
      # 親ディレクトリに新しい名前のディレクトリが既に存在するか確認
      if [[ -d "${new_dir}" ]]; then
        log_warn "ターゲットディレクトリが既に存在します: ${new_dir}"
        log_warn "コンテンツのみコピーします..."
        # 既存ディレクトリにコンテンツをコピー
        cp -r "${dir}"/* "${new_dir}/" 2>/dev/null || true
        rm -rf "${dir}"
      else
        # 通常の名前変更
        mkdir -p "$(dirname "${new_dir}")"
        mv "${dir}" "${new_dir}"
      fi
    fi
  done
done

# ファイル内のテキスト置換
log_step "ファイル内のテキストを置換しています..."
for conversion in "${TEXT_CONVERSIONS[@]}"; do
  old="${conversion%%:*}"
  new="${conversion##*:}"
  
  log_info "検索と置換: ${old} → ${new}"
  
  # テキストファイルを検索して内容置換
  find "${ROOT_DIR}" -type f -not -path "${BACKUP_DIR}/*" -not -path "*/\.*" -not -path "*/node_modules/*" | while read file; do
    # バイナリファイルを除外
    if file "$file" | grep -q "text"; then
      # ファイル内に置換対象のテキストがあるか確認
      if grep -q "${old}" "$file" 2>/dev/null; then
        log_info "ファイル内置換: ${file}"
        sed -i.bak "s/${old}/${new}/g" "$file"
        rm -f "${file}.bak"
      fi
    fi
  done
done

# 結果の概要
log_step "一括変更完了!"
log_info "3_planning → 3_planning"
log_info "4_executing → 4_executing"
log_info "5_monitoring → 5_monitoring"
log_info "6_closing → 6_closing"
log_info "バックアップは以下に保存されています: ${BACKUP_DIR}"
log_warn "変更を確認し、問題がなければバックアップを削除してください: rm -rf ${BACKUP_DIR}" 