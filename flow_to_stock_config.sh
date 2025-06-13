#!/bin/bash

# flow_to_stock_config.sh
# Flow→Stock同期処理の設定ファイル

# プロジェクトのルートディレクトリ
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"

# プロジェクトID（dinnerなど）
PROJECT_ID="dinner"

# 各種ディレクトリの設定
DOCUMENTS_DIR="${ROOT_DIR}/documents"
FLOW_ROOT="${ROOT_DIR}/Flow"
FLOW_PRIVATE="${FLOW_ROOT}/Private"
FLOW_PUBLIC="${FLOW_ROOT}/Public"
STOCK_ROOT="${ROOT_DIR}/Stock"
ARCHIVE_ROOT="${ROOT_DIR}/archive"

# サブディレクトリの設定
PROJECT_DOCS_DIR="${STOCK_ROOT}/projects/${PROJECT_ID}/documents"
PMBOK_DIR="${PROJECT_DOCS_DIR}/1_initiating"
PLANNING_DIR="${PROJECT_DOCS_DIR}/3_planning"
EXECUTING_DIR="${PROJECT_DOCS_DIR}/4_executing"
MONITORING_DIR="${PROJECT_DOCS_DIR}/5_monitoring"
CLOSING_DIR="${PROJECT_DOCS_DIR}/6_closing"
AGILE_DIR="${STOCK_ROOT}/Agile"
MEETINGS_DIR="${STOCK_ROOT}/Meetings"

# プロジェクト文書の設定
PROJECT_CHARTER_STOCK="${PMBOK_DIR}/project_charter.md"
STAKEHOLDER_REGISTER_STOCK="${PMBOK_DIR}/stakeholder_register.md"
WBS_STOCK="${PLANNING_DIR}/wbs.md"
RISK_PLAN_STOCK="${PLANNING_DIR}/risk_plan.md"
LESSONS_LEARNED_STOCK="${CLOSING_DIR}/lessons_learned.md"
PRODUCT_BACKLOG_STOCK="${AGILE_DIR}/product_backlog.md"
RELEASE_ROADMAP_STOCK="${PLANNING_DIR}/release_roadmap.md"

# バックログ関連のパス設定
BACKLOG_FLOW_DIR="${FLOW_PRIVATE}/$(date +"%Y-%m-%d")/backlog"
BACKLOG_STOCK_DIR="${PLANNING_DIR}/backlog"
BACKLOG_EPICS_STOCK="${BACKLOG_STOCK_DIR}/epics.yaml"
STORIES_STOCK_DIR="${BACKLOG_STOCK_DIR}/stories"

# ログファイルの設定
LOG_DIR="${ROOT_DIR}/logs"
LOG_FILE="${LOG_DIR}/flow_to_stock_$(date +"%Y%m%d").log"

# サブディレクトリ作成
mkdir -p "${PMBOK_DIR}"
mkdir -p "${PLANNING_DIR}"
mkdir -p "${EXECUTING_DIR}"
mkdir -p "${MONITORING_DIR}"
mkdir -p "${CLOSING_DIR}"
mkdir -p "${AGILE_DIR}"
mkdir -p "${MEETINGS_DIR}"
mkdir -p "${LOG_DIR}"
mkdir -p "${BACKLOG_STOCK_DIR}"
mkdir -p "${STORIES_STOCK_DIR}"

# 設定ファイルの読み込み完了メッセージ
echo "Flow→Stock同期設定を読み込みました。"
echo "- ルートディレクトリ: ${ROOT_DIR}"
echo "- Flowディレクトリ: ${FLOW_ROOT}"
echo "- Flow Private: ${FLOW_PRIVATE}"
echo "- Flow Public: ${FLOW_PUBLIC}"
echo "- Stockディレクトリ: ${STOCK_ROOT}"
echo "- アーカイブディレクトリ: ${ARCHIVE_ROOT}"
echo "- プロジェクトID: ${PROJECT_ID}"
echo "- バックログディレクトリ: ${BACKLOG_STOCK_DIR}" 
