#!/usr/bin/env bash
#===========================================================
# update_rule_numbers.sh - ルールファイル番号更新スクリプト
#===========================================================
# ルールファイルの番号を更新し、相互参照も修正します
# 変更内容:
#   03_pmbok_planning.mdc → 04_pmbok_planning.mdc
#   04_pmbok_executing.mdc → 05_pmbok_executing.mdc
#   05_pmbok_monitoring.mdc → 06_pmbok_monitoring.mdc
#   06_pmbok_closing.mdc → 07_pmbok_closing.mdc
#
# 使い方: ./scripts/update_rule_numbers.sh
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

# 1. 各ルールファイルをバックアップし名前変更
log_step "ルールファイルをバックアップし、名前を変更しています..."

# 既存のルールファイルを全てバックアップ
for rule_file in "$RULES_DIR"/*.mdc; do
  if [ -f "$rule_file" ]; then
    filename=$(basename "$rule_file")
    cp "$rule_file" "${BACKUP_DIR}/${filename}.bak"
    log_info "バックアップ: ${filename}"
  fi
done

# ルールファイルを逆順で名前変更（名前の衝突を避けるため）
if [ -f "$RULES_DIR/06_pmbok_closing.mdc" ]; then
  mv "$RULES_DIR/06_pmbok_closing.mdc" "$RULES_DIR/07_pmbok_closing.mdc"
  log_info "ファイル名を変更しました: 06_pmbok_closing.mdc → 07_pmbok_closing.mdc"
fi

if [ -f "$RULES_DIR/05_pmbok_monitoring.mdc" ]; then
  mv "$RULES_DIR/05_pmbok_monitoring.mdc" "$RULES_DIR/06_pmbok_monitoring.mdc"
  log_info "ファイル名を変更しました: 05_pmbok_monitoring.mdc → 06_pmbok_monitoring.mdc"
fi

if [ -f "$RULES_DIR/04_pmbok_executing.mdc" ]; then
  mv "$RULES_DIR/04_pmbok_executing.mdc" "$RULES_DIR/05_pmbok_executing.mdc"
  log_info "ファイル名を変更しました: 04_pmbok_executing.mdc → 05_pmbok_executing.mdc"
fi

if [ -f "$RULES_DIR/03_pmbok_planning.mdc" ]; then
  mv "$RULES_DIR/03_pmbok_planning.mdc" "$RULES_DIR/04_pmbok_planning.mdc"
  log_info "ファイル名を変更しました: 03_pmbok_planning.mdc → 04_pmbok_planning.mdc"
fi

# 2. ルールファイル内の参照を更新
log_step "ルールファイル内の参照を更新しています..."

# 00_master_rules.mdc 内の参照を更新
if [ -f "$RULES_DIR/00_master_rules.mdc" ]; then
  # ファイル名の参照を更新
  sed -i.tmp "s|03_pmbok_planning.mdc|04_pmbok_planning.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  sed -i.tmp "s|04_pmbok_executing.mdc|05_pmbok_executing.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  sed -i.tmp "s|05_pmbok_monitoring.mdc|06_pmbok_monitoring.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  sed -i.tmp "s|06_pmbok_closing.mdc|07_pmbok_closing.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  
  # テンプレート参照を更新
  sed -i.tmp "s|pmbok_planning.mdc|pmbok_planning.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  sed -i.tmp "s|pmbok_executing.mdc|pmbok_executing.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  sed -i.tmp "s|pmbok_monitoring.mdc|pmbok_monitoring.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  sed -i.tmp "s|pmbok_closing.mdc|pmbok_closing.mdc|g" "$RULES_DIR/00_master_rules.mdc"
  
  rm -f "$RULES_DIR/00_master_rules.mdc.tmp"
  log_info "00_master_rules.mdc 内の参照を更新しました"
fi

# 3. 名前が変更されたファイル内のコメント行を更新
for file in "04_pmbok_planning.mdc" "05_pmbok_executing.mdc" "06_pmbok_monitoring.mdc" "07_pmbok_closing.mdc"; do
  if [ -f "$RULES_DIR/$file" ]; then
    # ファイル内のコメント行を更新
    case "$file" in
      "04_pmbok_planning.mdc")
        sed -i.tmp "s|# 03_pmbok_planning.mdc|# 04_pmbok_planning.mdc|g" "$RULES_DIR/$file"
        ;;
      "05_pmbok_executing.mdc")
        sed -i.tmp "s|# 04_pmbok_executing.mdc|# 05_pmbok_executing.mdc|g" "$RULES_DIR/$file"
        ;;
      "06_pmbok_monitoring.mdc")
        sed -i.tmp "s|# 05_pmbok_monitoring.mdc|# 06_pmbok_monitoring.mdc|g" "$RULES_DIR/$file"
        ;;
      "07_pmbok_closing.mdc")
        sed -i.tmp "s|# 06_pmbok_closing.mdc|# 07_pmbok_closing.mdc|g" "$RULES_DIR/$file"
        ;;
    esac
    
    rm -f "$RULES_DIR/$file.tmp"
    log_info "$file 内のコメント行を更新しました"
  fi
done

# 4. task_management.mdc 内のパス参照を更新
log_step "task_management.mdc 内のパス参照を更新しています..."

if [ -f "$RULES_DIR/06_task_management.mdc" ]; then
  # 古いパス参照を更新
  sed -i.tmp "s|documents/3_planning|documents/4_planning|g" "$RULES_DIR/06_task_management.mdc"
  log_info "06_task_management.mdc 内のパス参照を更新しました"
  rm -f "$RULES_DIR/06_task_management.mdc.tmp"
else
  log_warn "06_task_management.mdc が見つかりません"
fi

# 5. 90_rule_maintenance.mdc 内のパス参照を更新
log_step "90_rule_maintenance.mdc 内のパス参照を更新しています..."

if [ -f "$RULES_DIR/90_rule_maintenance.mdc" ]; then
  # 古いパス参照を更新
  sed -i.tmp "s|documents/6_closing|documents/7_closing|g" "$RULES_DIR/90_rule_maintenance.mdc"
  log_info "90_rule_maintenance.mdc 内のパス参照を更新しました"
  rm -f "$RULES_DIR/90_rule_maintenance.mdc.tmp"
else
  log_warn "90_rule_maintenance.mdc が見つかりません"
fi

# 処理完了
log_step "ルールファイル番号の更新が完了しました！"
log_info "ファイル名を変更しました:"
log_info "- 03_pmbok_planning.mdc → 04_pmbok_planning.mdc"
log_info "- 04_pmbok_executing.mdc → 05_pmbok_executing.mdc"
log_info "- 05_pmbok_monitoring.mdc → 06_pmbok_monitoring.mdc"
log_info "- 06_pmbok_closing.mdc → 07_pmbok_closing.mdc"
log_info "ファイル内の参照も更新しました"
log_info "バックアップは以下に保存されています: ${BACKUP_DIR}"
log_warn "変更を確認し、問題がなければバックアップを削除してください: rm -rf ${BACKUP_DIR}" 