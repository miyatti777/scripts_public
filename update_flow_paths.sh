#!/usr/bin/env bash
#===========================================================
# update_flow_paths.sh - Flow/Private, Flow/Publicパス構造に対応するスクリプト
#===========================================================
# Flow配下にPrivateとPublicが追加された構造変更に対応するため、
# 関連ファイルのパス参照を更新します
#
# 使い方: ./scripts/update_flow_paths.sh
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

# バックアップディレクトリ
BACKUP_DIR="${ROOT_DIR}/backup_flowpaths_$(date +%Y%m%d_%H%M%S)"
mkdir -p "${BACKUP_DIR}"
log_info "バックアップディレクトリを作成しました: ${BACKUP_DIR}"

# 1. flow_to_stock.sh の更新
log_step "flow_to_stock.sh を更新しています..."

if [ -f "scripts/flow_to_stock.sh" ]; then
  cp "scripts/flow_to_stock.sh" "${BACKUP_DIR}/flow_to_stock.sh.bak"
  
  # macOS対応のため、簡易的な置換を使用
  # find_latest_flow_file関数の更新
  grep -n "find \"\${FLOW_ROOT}\" -maxdepth 1 -type d -name \"20\*\"" "scripts/flow_to_stock.sh" | while read -r line; do
    line_num=$(echo "$line" | cut -d':' -f1)
    sed -i.bak "${line_num}s|find \"\${FLOW_ROOT}\" -maxdepth 1 -type d -name \"20\*\"|find \"\${FLOW_ROOT}/Private\" \"\${FLOW_ROOT}/Public\" -maxdepth 1 -type d -name \"20\*\"|" "scripts/flow_to_stock.sh"
  done
  
  # バックアップファイルの削除
  rm -f "scripts/flow_to_stock.sh.bak"
  log_info "flow_to_stock.sh を更新しました"
else
  log_warn "scripts/flow_to_stock.sh が見つかりません"
fi

# 2. flow_to_stock_config.sh の更新
log_step "flow_to_stock_config.sh を更新しています..."

if [ -f "scripts/flow_to_stock_config.sh" ]; then
  cp "scripts/flow_to_stock_config.sh" "${BACKUP_DIR}/flow_to_stock_config.sh.bak"
  
  # FLOW_ROOT定義の行番号を取得
  flow_root_line=$(grep -n "FLOW_ROOT=" "scripts/flow_to_stock_config.sh" | cut -d':' -f1)
  
  if [ -n "$flow_root_line" ]; then
    # 次の行に新しい定義を挿入
    next_line=$((flow_root_line + 1))
    sed -i.bak "${next_line}i\\
FLOW_PRIVATE=\"\${FLOW_ROOT}/Private\"\\
FLOW_PUBLIC=\"\${FLOW_ROOT}/Public\"" "scripts/flow_to_stock_config.sh"
  fi
  
  # BACKLOG_FLOW_DIRの更新
  sed -i.bak "s|BACKLOG_FLOW_DIR=\"\${FLOW_ROOT}/\$(date +\"%Y-%m-%d\")/backlog\"|BACKLOG_FLOW_DIR=\"\${FLOW_PRIVATE}/\$(date +\"%Y-%m-%d\")/backlog\"|g" "scripts/flow_to_stock_config.sh"
  
  # 出力メッセージの行を取得
  echo_line=$(grep -n "^echo \"- Flowディレクトリ: \${FLOW_ROOT}\"" "scripts/flow_to_stock_config.sh" | cut -d':' -f1)
  
  if [ -n "$echo_line" ]; then
    # 次の行に新しい出力を挿入
    next_line=$((echo_line + 1))
    sed -i.bak "${next_line}i\\
echo \"- Flow Private: \${FLOW_PRIVATE}\"\\
echo \"- Flow Public: \${FLOW_PUBLIC}\"" "scripts/flow_to_stock_config.sh"
  fi
  
  rm -f "scripts/flow_to_stock_config.sh.bak"
  log_info "flow_to_stock_config.sh を更新しました"
else
  log_warn "scripts/flow_to_stock_config.sh が見つかりません"
fi

# 3. pmbok_paths.mdc の未更新パスを修正
log_step ".cursor/rules/pmbok_paths.mdc を更新しています..."

if [ -f ".cursor/rules/pmbok_paths.mdc" ]; then
  cp ".cursor/rules/pmbok_paths.mdc" "${BACKUP_DIR}/pmbok_paths.mdc.bak"
  
  # 古いパターンを検出
  old_paths=$(grep -n "Flow/{{today}}" .cursor/rules/pmbok_paths.mdc || true)
  
  if [ -n "$old_paths" ]; then
    log_info "以下の古いパスパターンを検出しました:"
    echo "$old_paths"
    
    # Flow/{{today}} を Flow/Private/{{today}} に更新
    sed -i.bak "s|Flow/{{today}}|Flow/Private/{{today}}|g" .cursor/rules/pmbok_paths.mdc
    log_info "pmbok_paths.mdc の古いパスを更新しました"
  else
    log_info "pmbok_paths.mdc は既に更新済みです"
  fi
  
  rm -f ".cursor/rules/pmbok_paths.mdc.bak"
else
  log_warn ".cursor/rules/pmbok_paths.mdc が見つかりません"
fi

# 4. 00_master_rules.mdc の更新
log_step ".cursor/rules/00_master_rules.mdc を更新しています..."

if [ -f ".cursor/rules/00_master_rules.mdc" ]; then
  cp ".cursor/rules/00_master_rules.mdc" "${BACKUP_DIR}/00_master_rules.mdc.bak"
  
  # Flow/{{today}} パターンを Flow/Private/{{today}} に更新
  sed -i.bak "s|Flow/{{today}}|Flow/Private/{{today}}|g" .cursor/rules/00_master_rules.mdc
  
  # 会議議事録など共有文書は Flow/Public/{{today}} を使うように更新
  sed -i.bak "s|path: \"Flow/Private/{{today}}/meeting_|path: \"Flow/Public/{{today}}/meeting_|g" .cursor/rules/00_master_rules.mdc
  
  rm -f ".cursor/rules/00_master_rules.mdc.bak"
  log_info "00_master_rules.mdc を更新しました"
else
  log_warn ".cursor/rules/00_master_rules.mdc が見つかりません"
fi

# 5. README.md の更新
log_step "README.md を更新しています..."

if [ -f "README.md" ]; then
  cp "README.md" "${BACKUP_DIR}/README.md.bak"
  
  # Flow/YYYY-MM-DD パターンを Flow/Private/YYYY-MM-DD に更新
  sed -i.bak "s|Flow/YYYY-MM-DD|Flow/Private/YYYY-MM-DD|g" "README.md"
  
  # ディレクトリ構造の説明部分を更新
  flow_line=$(grep -n "^├── Flow/" "README.md" | cut -d':' -f1)
  if [ -n "$flow_line" ]; then
    sed -i.bak "${flow_line}c\\
├── Flow/              # ドラフト文書ディレクトリ\\
│   ├── Private/      # 個人的な作業用ドキュメント\\
│   └── Public/       # 共有・会議議事録など" "README.md"
  fi
  
  rm -f "README.md.bak"
  log_info "README.md を更新しました"
else
  log_warn "README.md が見つかりません"
fi

# 処理完了
log_step "Flow パス更新が完了しました！"
log_info "以下のファイルを更新しました:"
log_info "- scripts/flow_to_stock.sh"
log_info "- scripts/flow_to_stock_config.sh"
log_info "- .cursor/rules/pmbok_paths.mdc"
log_info "- .cursor/rules/00_master_rules.mdc"
log_info "- README.md"
log_info "バックアップは以下に保存されています: ${BACKUP_DIR}"
log_warn "変更を確認し、問題がなければバックアップを削除してください: rm -rf ${BACKUP_DIR}" 