#!/usr/bin/env bash
#===========================================================
# migrate_flow_structure.sh - Flowディレクトリ構造移行スクリプト
#===========================================================
# Flow内のディレクトリを新しいPrivate/Public構造に移行します
# 使い方: ./scripts/migrate_flow_structure.sh
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

# Private/Publicディレクトリの作成確認
if [[ ! -d "${PRIVATE_DIR}" ]]; then
  log_info "Privateディレクトリを作成します"
  mkdir -p "${PRIVATE_DIR}"
fi

if [[ ! -d "${PUBLIC_DIR}" ]]; then
  log_info "Publicディレクトリを作成します"
  mkdir -p "${PUBLIC_DIR}"
fi

# テンプレートディレクトリの処理
if [[ ! -d "${PRIVATE_DIR}/templates" ]]; then
  log_info "Private/templatesディレクトリを作成"
  mkdir -p "${PRIVATE_DIR}/templates"
fi

if [[ ! -d "${PUBLIC_DIR}/templates" ]]; then
  log_info "Public/templatesディレクトリを作成"
  mkdir -p "${PUBLIC_DIR}/templates"
fi

# テンプレートファイルの移動
if [[ -d "${FLOW_DIR}/templates" ]]; then
  log_info "テンプレートファイルの移行を開始..."
  
  # 会議議事録テンプレートは Public に
  for template in "${FLOW_DIR}/templates"/*meeting* "${FLOW_DIR}/templates"/*minutes*; do
    if [[ -f "$template" ]]; then
      log_info "$(basename "$template") を Public/templates に移動"
      cp "$template" "${PUBLIC_DIR}/templates/"
    fi
  done
  
  # それ以外のテンプレートは Private に
  for template in "${FLOW_DIR}/templates"/*; do
    if [[ -f "$template" ]] && ! [[ "$template" == *meeting* || "$template" == *minutes* ]]; then
      log_info "$(basename "$template") を Private/templates に移動"
      cp "$template" "${PRIVATE_DIR}/templates/"
    fi
  done
fi

# 日付ディレクトリのリストを作成
date_dirs=($(find "${FLOW_DIR}" -maxdepth 1 -type d -name "20??-??-??"))
log_info "検出された日付フォルダ: ${#date_dirs[@]} 個"

# 各日付ディレクトリを処理
for date_dir in "${date_dirs[@]}"; do
  date_name=$(basename "$date_dir")
  
  log_info "処理中: $date_name"
  
  # Private側の日付ディレクトリ作成
  if [[ ! -d "${PRIVATE_DIR}/${date_name}" ]]; then
    mkdir -p "${PRIVATE_DIR}/${date_name}"
  fi
  
  # Public側の日付ディレクトリ作成
  if [[ ! -d "${PUBLIC_DIR}/${date_name}" ]]; then
    mkdir -p "${PUBLIC_DIR}/${date_name}"
  fi
  
  # 会議議事録系ファイルを探してPublicに移動
  meeting_files=()
  while IFS= read -r -d '' file; do
    meeting_files+=("$file")
  done < <(find "$date_dir" -type f \( -name "*meeting*" -o -name "*minutes*" \) -print0 2>/dev/null || true)
  
  for file in "${meeting_files[@]:-}"; do
    if [[ -f "$file" ]]; then
      log_info "$(basename "$file") を Public/${date_name}/ に移動"
      cp "$file" "${PUBLIC_DIR}/${date_name}/"
    fi
  done
  
  # その他のファイルをPrivateに移動
  other_files=()
  while IFS= read -r -d '' file; do
    if ! [[ "$file" == *meeting* || "$file" == *minutes* ]]; then
      other_files+=("$file")
    fi
  done < <(find "$date_dir" -type f -print0 2>/dev/null || true)
  
  for file in "${other_files[@]:-}"; do
    if [[ -f "$file" ]]; then
      log_info "$(basename "$file") を Private/${date_name}/ に移動"
      cp "$file" "${PRIVATE_DIR}/${date_name}/"
    fi
  done
done

# 結果表示
private_dirs=$(find "${PRIVATE_DIR}" -maxdepth 1 -type d -name "20??-??-??" | wc -l)
public_dirs=$(find "${PUBLIC_DIR}" -maxdepth 1 -type d -name "20??-??-??" | wc -l)

log_info "移行完了！"
log_info "作成された Private フォルダ: $private_dirs 個"
log_info "作成された Public フォルダ: $public_dirs 個"
log_info "注意: 元のファイルは安全のために残してあります。問題なければ手動で削除してください。"
echo ""
log_warn "新しいパス: ${PRIVATE_DIR}/YYYY-MM-DD および ${PUBLIC_DIR}/YYYY-MM-DD"
echo ""
log_info "pmbok_paths.mdcの更新もお忘れなく！" 