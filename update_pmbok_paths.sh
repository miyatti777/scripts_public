#!/bin/bash
#=============================================================
# update_pmbok_paths.sh
# 目的: pmbok_paths.mdcファイルを新しいプログラム構造とFlowディレクトリ統合に対応させる
#=============================================================

set -e

ROOT_DIR="/Users/daisukemiyata/aipm_v3"
RULES_DIR="${ROOT_DIR}/.cursor/rules"
PATHS_FILE="${RULES_DIR}/pmbok_paths.mdc"
BACKUP_DIR="${RULES_DIR}/backups"
TODAY=$(date +%Y%m%d)

# コマンドライン引数解析
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "不明なオプション: $1"
      echo "使用法: $0 [--dry-run] [-v|--verbose]"
      exit 1
      ;;
  esac
done

# バックアップディレクトリ作成
if [[ "$DRY_RUN" = false ]]; then
  mkdir -p "$BACKUP_DIR"
else
  echo "[DRY RUN] 作成: ${BACKUP_DIR}"
fi

# ファイル存在確認
if [[ ! -f "$PATHS_FILE" ]]; then
  echo "エラー: ${PATHS_FILE} が見つかりません"
  exit 1
fi

# バックアップ作成
BACKUP_FILE="${BACKUP_DIR}/pmbok_paths_${TODAY}.mdc.bak"
if [[ "$DRY_RUN" = false ]]; then
  cp "$PATHS_FILE" "$BACKUP_FILE"
  echo "バックアップ作成: ${BACKUP_FILE}"
else
  echo "[DRY RUN] バックアップ作成: ${BACKUP_FILE}"
fi

echo "=== pmbok_paths.mdc の更新を開始します ==="

# 新しい内容を生成
TEMP_FILE=$(mktemp)

cat > "$TEMP_FILE" << 'EOL'
# ==========================================================
# pmbok_paths.mdc  ―  "すべてのルールが参照するパス辞書"
# ==========================================================
# ・{{ }} 内は Cursor が動的に置換するプレースホルダ変数
# ・必要に応じて root を環境パスに書き換えてください
# ・最終更新: ${TODAY} - プログラム階層化対応

# ----
# 0. ルートディレクトリ
# ----
root: "/Users/daisukemiyata/{{PROJECT_ROOT}}"

# ----
# 1. 主要ディレクトリ（相対パス）
# ----
dirs:
  # ─ Flow（WIP／ドラフト／議事録など）
  flow:           "{{root}}/Flow"
  flow_templates: "{{dirs.flow}}/templates"

  # ─ Stock（確定版ドキュメント）
  stock:          "{{root}}/Stock"
  stock_templates:"{{dirs.stock}}/shared/templates"
  
  # ─ プログラム/プロジェクト構造
  programs:       "{{dirs.stock}}/programs"
  
  # ─ アーカイブ（完了 or 旧バージョン格納）
  archived:       "{{root}}/Archived"

  # ─ ルールファイル
  rules:          "{{root}}/.cursor/rules"

  # ─ 会社全体ナレッジ
  company_knowledge: "{{dirs.stock}}/company_knowledge"

  # ─ スクリプト
  scripts:        "{{root}}/scripts"

# ----
# 2. 動的パターン
# ----
patterns:

  # ---- Flow 側 ----
  # 日付フォルダパス（統合版）
  flow_date:          "{{dirs.flow}}/{{today}}"  # 例) Flow/2025-05-01
  
  # ドラフトファイル
  draft_charter:      "{{patterns.flow_date}}/draft_project_charter.md"
  draft_stakeholder:  "{{patterns.flow_date}}/draft_stakeholder_analysis.md"
  draft_wbs:          "{{patterns.flow_date}}/draft_wbs.md"
  draft_risk_plan:    "{{patterns.flow_date}}/draft_risk_plan.md"
  draft_roadmap:      "{{patterns.flow_date}}/draft_product_roadmap.md"
  
  # ---- Ideation モジュール関連 -----
  ideation_dir:       "{{patterns.flow_date}}/ideation"
  draft_concept:      "{{patterns.ideation_dir}}/draft_concept.md"
  draft_comparison:   "{{patterns.ideation_dir}}/draft_concept_comparison.md"
  draft_refine:       "{{patterns.ideation_dir}}/draft_concept_refined.md"
  draft_presentation: "{{patterns.ideation_dir}}/draft_concept_presentation.md"
  
  # 会議議事録
  draft_minutes:      "{{patterns.flow_date}}/draft_meeting_minutes.md"
  
  # その他
  weekly_review:      "{{patterns.flow_date}}/weekly_review.md"
  daily_tasks:        "{{patterns.flow_date}}/daily_tasks.md"
  flow_archived:      "{{patterns.flow_date}}/archived"
  
  # ---- バックログ関連 ---
  backlog_dir:        "{{patterns.flow_date}}/backlog"
  backlog_yaml:       "{{patterns.backlog_dir}}/backlog.yaml"
  epics_yaml:         "{{patterns.backlog_dir}}/epics.yaml"
  stories_dir:        "{{patterns.backlog_dir}}/stories"
  story_template:     "{{dirs.flow_templates}}/user_story_template.md"
  
  # ---- バックログ関連（スクリプト) ----
  backlog_validate_script: "{{root}}/scripts/validate_backlog_yaml.py"
  
  # ---- Discovery関連 ---
  draft_assumption:   "{{patterns.flow_date}}/draft_assumption_map.md"
  draft_persona:      "{{patterns.flow_date}}/draft_persona.md"
  draft_problem:      "{{patterns.flow_date}}/draft_problem_statement.md"
  draft_hypothesis:   "{{patterns.flow_date}}/draft_hypothesis_backlog.md"
  draft_journey_map:  "{{patterns.flow_date}}/draft_user_journey_map.md"
  
  # ---- タスク管理テンプレート ---
  daily_tasks_template: "{{dirs.flow_templates}}/daily_tasks_template.md"
  weekly_review_template: "{{dirs.flow_templates}}/weekly_review_template.md"

  # ---- プログラム/プロジェクト構造 ---
  program_dir:        "{{dirs.programs}}/{{program_id}}"
  project_dir:        "{{patterns.program_dir}}/projects/{{project_id}}"
  docs_root:          "{{patterns.project_dir}}/documents"
  
  # プロセス別フォルダ
  doc_initiating:     "{{patterns.docs_root}}/1_initiating"
  doc_discovery:      "{{patterns.docs_root}}/2_discovery"
  doc_planning:       "{{patterns.docs_root}}/3_planning"
  doc_executing:      "{{patterns.docs_root}}/4_executing"
  doc_monitoring:     "{{patterns.docs_root}}/5_monitoring"
  doc_closing:        "{{patterns.docs_root}}/6_closing"
  
  # 会議フォルダ
  meetings_dir:       "{{patterns.doc_executing}}/Meetings"

  # ---- Stock: Initiating ----
  stock_charter:          "{{patterns.doc_initiating}}/project_charter.md"
  stakeholder_register:   "{{patterns.doc_initiating}}/stakeholder_register.md"

  # ---- Stock: Discovery -----
  stock_assumption:       "{{patterns.doc_discovery}}/assumption_map.md"
  stock_persona:          "{{patterns.doc_discovery}}/persona.md"
  stock_problem:          "{{patterns.doc_discovery}}/problem_statement.md"
  stock_hypothesis:       "{{patterns.doc_discovery}}/hypothesis_backlog.md"
  stock_journey_map:      "{{patterns.doc_discovery}}/user_journey_map.md"
  stock_validation_plan:  "{{patterns.doc_discovery}}/validation_plan.md"
  stock_ideation_dir:     "{{patterns.doc_discovery}}/ideation"

  # ---- Stock: Planning ---
  stock_wbs:              "{{patterns.doc_planning}}/wbs.md"
  risk_plan:              "{{patterns.doc_planning}}/risk_plan.md"
  comm_plan:              "{{patterns.doc_planning}}/communication_plan.md"
  roadmap:                "{{patterns.doc_planning}}/product_roadmap.md"
  
  # ---- Stock: バックログ関連 -----
  stock_backlog_dir:      "{{patterns.doc_planning}}/backlog"
  stock_backlog_yaml:     "{{patterns.stock_backlog_dir}}/backlog.yaml"
  stock_epics_yaml:       "{{patterns.stock_backlog_dir}}/epics.yaml"
  stock_stories_dir:      "{{patterns.stock_backlog_dir}}/stories"

  # ---- Stock: Executing -----
  sprint_goals_dir:       "{{patterns.doc_executing}}/sprint_goals"
  decision_log:           "{{patterns.doc_executing}}/decision_log.md"
  tests_dir:              "{{patterns.doc_executing}}/tests"
  sprint_root:            "{{patterns.doc_executing}}/sprints/{{sprint_id}}"
  review_md:              "{{patterns.sprint_root}}/sprint_review.md"
  draft_review:           "{{patterns.flow_date}}/draft_sprint_review_{{sprint_id}}.md"
  daily_tasks_glob:       "{{dirs.flow}}/*/daily_tasks.md"

  # ---- Stock: Monitoring ----
  status_reports_dir:     "{{patterns.doc_monitoring}}/status_reports"
  change_requests_dir:    "{{patterns.doc_monitoring}}/change_requests"
  risk_log:               "{{patterns.doc_monitoring}}/risk_log.md"

  # ---- Stock: Closing ----
  lessons_learned_dir:    "{{patterns.doc_closing}}/lessons_learned"
  transition_doc:         "{{patterns.doc_closing}}/transition_document.md"
  benefits_report:        "{{patterns.doc_closing}}/benefits_report.md"

# ----
# 3. 便利変数（任意拡張）
# ----
meta:
  today:         "{{env.NOW:date:YYYY-MM-DD}}"
  week_end_date: "{{env.WEEK_END:date:YYYY-MM-DD}}"
  program_id:    "{{env.PROGRAM_ID}}"    # 実行時に指定するプログラムID
  project_id:    "{{env.PROJECT_ID}}"    # 実行時に指定するプロジェクトID
  
  # ---- 特殊変数 ---
  change_title:  ""      # 変更要求のタイトル
  meeting_title: ""      # 会議タイトル
  version:       "v1.0"  # ドキュメントバージョン
EOL

# ファイル更新
if [[ "$DRY_RUN" = false ]]; then
  # 日付置換を行う
  sed "s/\${TODAY}/$(date +%Y-%m-%d)/g" "$TEMP_FILE" > "$PATHS_FILE"
  echo "更新完了: ${PATHS_FILE}"
else
  echo "[DRY RUN] ファイル更新: ${PATHS_FILE}"
  if [[ "$VERBOSE" = true ]]; then
    echo "=== 更新予定の内容 ==="
    cat "$TEMP_FILE" | sed "s/\${TODAY}/$(date +%Y-%m-%d)/g"
    echo "===================="
  fi
fi

# 一時ファイル削除
rm "$TEMP_FILE"

echo "=== pmbok_paths.mdc の更新が完了しました ==="
echo "元のファイルは ${BACKUP_FILE} にバックアップされています"

exit 0 