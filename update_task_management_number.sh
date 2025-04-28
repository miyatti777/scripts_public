#!/usr/bin/env bash
#===========================================================
# update_task_management_number.sh - タスク管理ルールファイル番号更新スクリプト
#===========================================================
# タスク管理ルールファイルの番号を更新し、相互参照も修正します
# 変更内容:
#   06_task_management.mdc → 07_task_management.mdc
#
# 使い方: ./scripts/update_task_management_number.sh
#===========================================================

set -euo pipefail

ROOT_DIR="$(pwd)"
RULES_DIR="${ROOT_DIR}/.cursor/rules"

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

# バックアップディレクトリ
BACKUP_DIR="${ROOT_DIR}/backup_rules_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"
log_info "バックアップディレクトリを作成しました: ${BACKUP_DIR}"

# 1. 各ルールファイルをバックアップ
log_step "ルールファイルをバックアップしています..."

# 対象ファイルをバックアップ
for rule_file in "$RULES_DIR"/*.mdc; do
  if [ -f "$rule_file" ]; then
    filename=$(basename "$rule_file")
    cp "$rule_file" "${BACKUP_DIR}/${filename}.bak"
    log_info "バックアップ: ${filename}"
  fi
done

# 2. ファイル名を変更
log_step "ファイル名を変更しています..."

if [ -f "$RULES_DIR/06_task_management.mdc" ]; then
  mv "$RULES_DIR/06_task_management.mdc" "$RULES_DIR/07_task_management.mdc"
  log_info "ファイル名を変更しました: 06_task_management.mdc → 07_task_management.mdc"
else
  log_warn "06_task_management.mdc が見つかりません"
fi

# 3. 00_master_rules.mdc 内の参照を更新
log_step "00_master_rules.mdc 内の参照を更新しています..."

if [ -f "$RULES_DIR/00_master_rules.mdc" ]; then
  sed -i.tmp "s|06_task_management.mdc|07_task_management.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  rm -f "$RULES_DIR/00_master_rules.mdc.tmp"
  log_info "00_master_rules.mdc 内の参照を更新しました"
else
  log_warn "00_master_rules.mdc が見つかりません"
fi

# 4. derived-cursor-rules.mdc 内の参照を更新
log_step "derived-cursor-rules.mdc 内の参照を更新しています..."

if [ -f "$RULES_DIR/derived-cursor-rules.mdc" ]; then
  sed -i.tmp "s|06_task_management.mdc|07_task_management.mdc|g" "$RULES_DIR/derived-cursor-rules.mdc"
  rm -f "$RULES_DIR/derived-cursor-rules.mdc.tmp"
  log_info "derived-cursor-rules.mdc 内の参照を更新しました"
else
  log_warn "derived-cursor-rules.mdc が見つかりません"
fi

# 5. 変更したファイル内のコメント行を更新
log_step "タスク管理ファイル内のコメント行を更新しています..."

if [ -f "$RULES_DIR/07_task_management.mdc" ]; then
  sed -i.tmp "s|# 06_task_management.mdc|# 07_task_management.mdc|g" "$RULES_DIR/07_task_management.mdc"
  rm -f "$RULES_DIR/07_task_management.mdc.tmp"
  log_info "07_task_management.mdc 内のコメント行を更新しました"
else
  log_warn "07_task_management.mdc が見つかりません"
fi

# 処理完了
log_step "タスク管理ファイル番号の更新が完了しました！"
log_info "ファイル名を変更しました:"
log_info "- 06_task_management.mdc → 07_task_management.mdc"
log_info "ファイル内の参照も更新しました"
log_info "バックアップは以下に保存されています: ${BACKUP_DIR}"
log_warn "変更を確認し、問題がなければバックアップを削除してください: rm -rf ${BACKUP_DIR}" 