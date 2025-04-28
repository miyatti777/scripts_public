#!/bin/bash
# ルールのディレクトリ構造を作成し、ファイルを移動するスクリプト

# 変数定義
RULES_DIR="/Users/daisukemiyata/aipm_v3/.cursor/rules"
BASIC_DIR="${RULES_DIR}/basic"
REAL_ESTATE_DIR="${RULES_DIR}/real_estate"

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}ルールファイルの整理を開始します...${NC}"

# ディレクトリが存在するかチェック
if [ ! -d "$RULES_DIR" ]; then
    echo -e "${RED}エラー: $RULES_DIR が存在しません${NC}"
    exit 1
fi

# basic と real_estate ディレクトリを作成
echo "1. ディレクトリを作成しています..."
mkdir -p "$BASIC_DIR"
mkdir -p "$REAL_ESTATE_DIR"

# ファイルの移動
echo "2. 基本ルールファイルを移動しています..."
# 基本ルールファイル
mv ${RULES_DIR}/00_master_rules.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 00_master_rules.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/01_pmbok_initiating.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 01_pmbok_initiating.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/02_pmbok_discovery.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 02_pmbok_discovery.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/03_pmbok_planning.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 03_pmbok_planning.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/04_pmbok_executing.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 04_pmbok_executing.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/05_pmbok_monitoring.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 05_pmbok_monitoring.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/06_pmbok_closing.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 06_pmbok_closing.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/07_task_management.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 07_task_management.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/08_pmbok_flow_assist.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 08_pmbok_flow_assist.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/90_rule_maintenance.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: 90_rule_maintenance.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/derived-cursor-rules.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: derived-cursor-rules.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/flow_to_stock_rules.mdc ${BASIC_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: flow_to_stock_rules.mdc の移動に失敗しました${NC}"

echo "3. 不動産特化ルールファイルを移動しています..."
# 不動産特化ルールファイル
mv ${RULES_DIR}/ideation_module.mdc ${REAL_ESTATE_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: ideation_module.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/insight_analysis.mdc ${REAL_ESTATE_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: insight_analysis.mdc の移動に失敗しました${NC}"
mv ${RULES_DIR}/pmbok_discovery_real_estate.mdc ${REAL_ESTATE_DIR}/ 2>/dev/null || echo -e "${YELLOW}警告: pmbok_discovery_real_estate.mdc の移動に失敗しました${NC}"

# パス参照を更新するPythonスクリプトを実行
echo "4. パス参照を更新しています..."
python /Users/daisukemiyata/aipm_v3/scripts/update_rule_paths.py

echo -e "${GREEN}完了しました。以下の構造でファイルが整理されました:${NC}"
echo -e "${GREEN}1. 基本ルール: ${BASIC_DIR}${NC}"
echo -e "${GREEN}2. 不動産特化ルール: ${REAL_ESTATE_DIR}${NC}"

# pmbok_paths.mdcのみルートに残すことを確認
echo -e "${YELLOW}注意: pmbok_paths.mdc はルートディレクトリに残しています${NC}" 