#!/bin/bash

# GitHub Issuesとストーリーファイルを同期するスクリプト
# 使用方法: 
#   ./sync_stories_to_github_issues.sh [sprint_number] [オプション]
# オプション:
#   --dry-run: 実際のIssue作成を行わない
#   --sync-back: GitHub上の変更をローカルファイルに反映する

# 設定
STORIES_DIR="/Users/daisukemiyata/aipm_v3/Stock/projects/tokyo_asset/documents/4_executing/sprint_stories"
REPO="miyatti777/aipm_v3"
SPRINT_TO_PROCESS="$1"  # コマンドライン引数から取得

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# フラグ解析
is_dry_run=false
sync_back=false

for arg in "$@"; do
  case $arg in
    --dry-run)
      is_dry_run=true
      echo -e "${YELLOW}ドライランモード: 実際のIssue作成は行いません${NC}"
      ;;
    --sync-back)
      sync_back=true
      echo -e "${BLUE}双方向同期モード: GitHub上の変更をローカルファイルに反映します${NC}"
      ;;
    *)
      # 数字引数はスプリント番号として処理済み
      ;;
  esac
done

# プロジェクト情報をバックログYAMLから取得
BACKLOG_YAML="/Users/daisukemiyata/aipm_v3/Stock/projects/tokyo_asset/documents/3_planning/backlog/backlog.yaml"
# YAML解析のための一時的な方法（本来はYQなどのツールが推奨）
PROJECT_NAME=$(grep -m 1 "name:" "$BACKLOG_YAML" | cut -d ':' -f 2- | sed 's/^[ \t]*//')
START_DATE=$(grep -m 1 "start_date:" "$BACKLOG_YAML" | cut -d ':' -f 2- | sed 's/^[ \t]*//')
END_DATE=$(grep -m 1 "end_date:" "$BACKLOG_YAML" | cut -d ':' -f 2- | sed 's/^[ \t]*//')

# ラベル作成関数
create_labels() {
  echo -e "${YELLOW}ラベルを作成中...${NC}"
  
  # スプリントラベル
  for i in {1..7}; do
    gh label create "Sprint $i" --color "0E8A16" --repo "$REPO" --description "スプリント $i のタスク" 2>/dev/null || echo -e "${YELLOW}ラベル 'Sprint $i' は既に存在します${NC}"
  done
  
  # ストーリーラベル
  gh label create "Story" --color "1D76DB" --repo "$REPO" --description "ユーザーストーリー" 2>/dev/null || echo -e "${YELLOW}ラベル 'Story' は既に存在します${NC}"
  
  # 優先度ラベル
  gh label create "Priority: High" --color "D93F0B" --repo "$REPO" --description "高優先度タスク" 2>/dev/null || echo -e "${YELLOW}ラベル 'Priority: High' は既に存在します${NC}"
  gh label create "Priority: Medium" --color "FBCA04" --repo "$REPO" --description "中優先度タスク" 2>/dev/null || echo -e "${YELLOW}ラベル 'Priority: Medium' は既に存在します${NC}"
  gh label create "Priority: Low" --color "C2E0C6" --repo "$REPO" --description "低優先度タスク" 2>/dev/null || echo -e "${YELLOW}ラベル 'Priority: Low' は既に存在します${NC}"
  
  # ステータスラベル
  gh label create "Status: TODO" --color "D4C5F9" --repo "$REPO" --description "未着手" 2>/dev/null || echo -e "${YELLOW}ラベル 'Status: TODO' は既に存在します${NC}"
  gh label create "Status: WIP" --color "FEF2C0" --repo "$REPO" --description "作業中" 2>/dev/null || echo -e "${YELLOW}ラベル 'Status: WIP' は既に存在します${NC}"
  gh label create "Status: Done" --color "0E8A16" --repo "$REPO" --description "完了" 2>/dev/null || echo -e "${YELLOW}ラベル 'Status: Done' は既に存在します${NC}"
  gh label create "Status: Blocked" --color "B60205" --repo "$REPO" --description "ブロック中" 2>/dev/null || echo -e "${YELLOW}ラベル 'Status: Blocked' は既に存在します${NC}"
  
  echo -e "${GREEN}ラベル作成完了${NC}"
}

# マイルストーン作成関数
create_milestones() {
  echo -e "${YELLOW}マイルストーンを作成中...${NC}"
  
  # プロジェクト全体の期間を取得
  local start_date="$START_DATE"
  local end_date="$END_DATE"
  
  # 単純な例として：スプリント期間を均等に分割（実際には詳細な計画から取得すべき）
  local total_days=$(( ($(date -j -f "%Y-%m-%d" "$end_date" +%s) - $(date -j -f "%Y-%m-%d" "$start_date" +%s)) / 86400 ))
  local sprint_length=$(( total_days / 7 ))  # 7スプリントと仮定
  
  for i in {1..7}; do
    local sprint_start=$(date -j -v+$(( (i-1) * sprint_length ))d -f "%Y-%m-%d" "$start_date" +%Y-%m-%d)
    local sprint_end=$(date -j -v+$(( i * sprint_length - 1 ))d -f "%Y-%m-%d" "$start_date" +%Y-%m-%d)
    
    # 最後のスプリントは終了日をプロジェクト終了日に合わせる
    if [ $i -eq 7 ]; then
      sprint_end="$end_date"
    fi
    
    local milestone_title="Sprint $i ($sprint_start から $sprint_end)"
    local milestone_desc="$PROJECT_NAME スプリント $i"
    
    # 既存のマイルストーンをチェック
    local exists=$(gh api repos/$REPO/milestones --jq ".[] | select(.title == \"$milestone_title\") | .number" 2>/dev/null)
    
    if [ -z "$exists" ]; then
      echo -e "マイルストーン作成: $milestone_title"
      if ! $is_dry_run; then
        gh api repos/$REPO/milestones -f title="$milestone_title" -f state=open -f description="$milestone_desc" -f due_on="${sprint_end}T23:59:59Z" > /dev/null 2>&1 || echo -e "${RED}マイルストーン '$milestone_title' の作成に失敗しました${NC}"
      else
        echo -e "${YELLOW}[ドライラン] マイルストーン作成をシミュレーション: $milestone_title${NC}"
      fi
    else
      echo -e "${YELLOW}マイルストーン '$milestone_title' は既に存在します (ID: $exists)${NC}"
    fi
  done
  
  echo -e "${GREEN}マイルストーン作成完了${NC}"
}

# マイルストーンID取得関数
get_milestone_id() {
  local sprint_num="$1"
  # マイルストーン一覧からスプリント番号に対応するものを検索
  gh api repos/$REPO/milestones --jq ".[] | select(.title | startswith(\"Sprint $sprint_num\")) | .number" 2>/dev/null
}

# ストーリーファイルから情報抽出関数
extract_info_from_file() {
  local file="$1"
  local info=()
  
  # 優先度抽出
  local priority=$(grep -i "priority:" "$file" | head -n 1 | cut -d ':' -f 2- | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
  if [ -z "$priority" ]; then
    priority="Medium" # デフォルト値
  fi
  info+=("priority:$priority")
  
  # ステータス抽出
  local status=$(grep -i "status:" "$file" | head -n 1 | cut -d ':' -f 2- | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
  if [ -z "$status" ]; then
    status="TODO" # デフォルト値
  fi
  info+=("status:$status")
  
  # 担当者抽出
  local assignee=$(grep -i "assignee:" "$file" | head -n 1 | cut -d ':' -f 2- | sed 's/^[ \t]*//' | sed 's/[ \t]*$//')
  if [ -n "$assignee" ]; then
    info+=("assignee:$assignee")
  fi
  
  # スペース区切りで結果を返す
  echo "${info[@]}"
}

# ストーリーファイルからIssue作成関数
create_issue_from_story() {
  local file="$1"
  local sprint_dir="$2"
  local sprint_num="${sprint_dir//[^0-9]/}"
  
  # ファイル名から情報抽出
  filename=$(basename "$file")
  story_id="${filename%%_*}"
  
  # ファイルから詳細情報抽出
  local file_info=($(extract_info_from_file "$file"))
  local priority=""
  local status=""
  local assignee=""
  
  for info in "${file_info[@]}"; do
    key="${info%%:*}"
    value="${info#*:}"
    
    case "$key" in
      priority) priority="$value" ;;
      status) status="$value" ;;
      assignee) assignee="$value" ;;
    esac
  done
  
  # 抽出したステータスをGitHubラベル用に変換
  case "$status" in
    TODO|To\ Do|todo|to\ do) status_label="Status: TODO" ;;
    WIP|In\ Progress|wip|in\ progress|進行中) status_label="Status: WIP" ;;
    Done|完了|done) status_label="Status: Done" ;;
    Blocked|ブロック|blocked) status_label="Status: Blocked" ;;
    *) status_label="Status: TODO" ;; # デフォルト
  esac
  
  # 優先度ラベル設定
  case "$priority" in
    High|high|H|h) priority_label="Priority: High" ;;
    Medium|medium|M|m) priority_label="Priority: Medium" ;;
    Low|low|L|l) priority_label="Priority: Low" ;;
    *) priority_label="Priority: Medium" ;; # デフォルト
  esac
  
  # 既存のIssueをチェック (ストーリーIDを含むタイトル)
  existing_issue=$(gh issue list --repo "$REPO" --json number,title --jq ".[] | select(.title | contains(\"[$story_id]\")) | .number" 2>/dev/null | head -n 1)
  
  # ファイル内容を解析
  title=$(grep -m 1 "^# " "$file" | sed 's/^# [^:]*: //' | sed 's/^# //')
  
  if [ -z "$title" ]; then
    title=$(echo "$filename" | sed 's/^[^_]*_//' | sed 's/\.md$//' | tr '_' ' ')
  fi
  
  # マイルストーンID取得
  milestone_id=$(get_milestone_id "$sprint_num")
  
  # 既存のIssueがある場合は更新、なければ新規作成
  if [ -n "$existing_issue" ]; then
    echo -e "${YELLOW}Issue #$existing_issue を更新: $title ($story_id)${NC}"
    
    if ! $is_dry_run; then
      # ラベル更新
      gh issue edit "$existing_issue" --repo "$REPO" \
        --add-label "$priority_label" \
        --add-label "$status_label" 2>/dev/null
      
      # マイルストーン更新（マイルストーンIDがある場合）
      if [ -n "$milestone_id" ]; then
        gh api -X PATCH repos/$REPO/issues/$existing_issue -f milestone="$milestone_id" > /dev/null 2>&1
      fi
      
      echo -e "${GREEN}Issue #$existing_issue の更新完了${NC}"
    else
      echo -e "${YELLOW}[ドライラン] Issue更新をシミュレーション: #$existing_issue${NC}"
    fi
  else
    # Issue作成
    echo -e "${YELLOW}Issueを作成中: $title ($story_id)${NC}"
    
    if ! $is_dry_run; then
      # Markdown内容全体を使用
      body=$(cat "$file")
      
      # Issue作成コマンド
      local issue_number=$(gh issue create --repo "$REPO" \
        --title "[$story_id] $title" \
        --body "$body" \
        --label "Sprint $sprint_num" \
        --label "Story" \
        --label "$priority_label" \
        --label "$status_label" \
        --json number --jq .number 2>/dev/null)
      
      # マイルストーン設定（マイルストーンIDがある場合）
      if [ -n "$milestone_id" ] && [ -n "$issue_number" ]; then
        gh api -X PATCH repos/$REPO/issues/$issue_number -f milestone="$milestone_id" > /dev/null 2>&1
      fi
      
      if [ -n "$issue_number" ]; then
        echo -e "${GREEN}Issue #$issue_number 作成完了: $story_id${NC}"
      else
        echo -e "${RED}Issue作成に失敗しました: $story_id${NC}"
      fi
    else
      echo -e "${GREEN}[ドライラン] Issue作成をシミュレーション: $story_id${NC}"
    fi
  fi
}

# GitHubからローカルファイルへの同期関数
sync_from_github() {
  if ! $sync_back; then
    return
  fi
  
  echo -e "${BLUE}=== GitHubの変更をローカルファイルに反映します ===${NC}"
  
  # 全スプリントディレクトリを処理
  for sprint_dir in "$STORIES_DIR"/sprint_*/; do
    if [ ! -d "$sprint_dir" ]; then
      continue
    fi
    
    sprint_name=$(basename "$sprint_dir")
    sprint_num="${sprint_name//[^0-9]/}"
    
    # 特定のスプリントのみ処理する場合
    if [ -n "$SPRINT_TO_PROCESS" ] && [ "$sprint_num" != "$SPRINT_TO_PROCESS" ]; then
      continue
    fi
    
    echo -e "${BLUE}スプリント $sprint_num のIssueを同期中...${NC}"
    
    # このスプリントに関連するIssueを取得
    issues=$(gh issue list --repo "$REPO" --json number,title,body,labels --jq '.[] | select(.labels[].name == "Sprint '"$sprint_num"'")' 2>/dev/null)
    
    # 各Issueを処理
    echo "$issues" | while read -r issue; do
      if [ -z "$issue" ]; then
        continue
      fi
      
      # Issueから情報抽出
      issue_number=$(echo "$issue" | jq -r '.number')
      issue_title=$(echo "$issue" | jq -r '.title')
      issue_body=$(echo "$issue" | jq -r '.body')
      
      # タイトルからストーリーID抽出
      if [[ $issue_title =~ \[([A-Za-z0-9\-]+)\] ]]; then
        story_id="${BASH_REMATCH[1]}"
        
        # ストーリーIDに対応するファイルを検索
        story_file=$(find "$sprint_dir" -name "${story_id}_*.md" 2>/dev/null | head -n 1)
        
        if [ -n "$story_file" ]; then
          echo -e "${BLUE}Issue #$issue_number をファイル $story_file に同期中...${NC}"
          
          # 既存ファイルを修正する代わりに、一時ファイルを作成して確認してから置換
          if [ -n "$issue_body" ] && ! $is_dry_run; then
            echo "$issue_body" > "${story_file}.new"
            
            # ファイル内容が異なる場合のみ更新
            if ! cmp -s "${story_file}" "${story_file}.new"; then
              mv "${story_file}.new" "${story_file}"
              echo -e "${GREEN}ファイル $story_file を更新しました${NC}"
            else
              rm "${story_file}.new"
              echo -e "${YELLOW}変更なし: $story_file${NC}"
            fi
          elif $is_dry_run; then
            echo -e "${YELLOW}[ドライラン] ファイル同期をシミュレーション: $story_file${NC}"
          fi
        else
          echo -e "${YELLOW}ストーリーID $story_id に対応するファイルが見つかりません${NC}"
        fi
      fi
    done
  done
  
  echo -e "${BLUE}GitHub→ローカル同期完了${NC}"
}

# メイン処理
main() {
  echo -e "${GREEN}==== GitHub Issuesとストーリーの同期を開始 ====${NC}"
  echo -e "${YELLOW}対象ディレクトリ: $STORIES_DIR${NC}"
  echo -e "${YELLOW}対象リポジトリ: $REPO${NC}"
  
  if [ -n "$SPRINT_TO_PROCESS" ]; then
    echo -e "${YELLOW}スプリント ${SPRINT_TO_PROCESS} のみを処理します${NC}"
  else
    echo -e "${YELLOW}全スプリントを処理します${NC}"
  fi
  
  # ラベルとマイルストーン作成
  create_labels
  create_milestones
  
  # 処理カウンター
  total_stories=0
  processed_stories=0
  
  # 各スプリントディレクトリを処理
  for sprint_dir in "$STORIES_DIR"/sprint_*/; do
    if [ -d "$sprint_dir" ]; then
      sprint_name=$(basename "$sprint_dir")
      sprint_num="${sprint_name//[^0-9]/}"
      
      # 特定のスプリントのみ処理する場合
      if [ -n "$SPRINT_TO_PROCESS" ] && [ "$sprint_num" != "$SPRINT_TO_PROCESS" ]; then
        continue
      fi
      
      echo -e "${GREEN}\n処理中: $sprint_name${NC}"
      
      # ストーリーカウント
      story_count=$(find "$sprint_dir" -name "*.md" | wc -l | tr -d ' ')
      total_stories=$((total_stories + story_count))
      
      # ディレクトリ内の各MDファイルを処理
      for story_file in "$sprint_dir"/*.md; do
        if [ -f "$story_file" ]; then
          create_issue_from_story "$story_file" "$sprint_name"
          processed_stories=$((processed_stories + 1))
          echo -e "${YELLOW}進捗: $processed_stories / $total_stories${NC}"
        fi
      done
    fi
  done
  
  # GitHubからの同期（双方向同期が有効な場合）
  sync_from_github
  
  echo -e "${GREEN}\n==== 同期完了！ ====${NC}"
  echo -e "${GREEN}処理済みストーリー: $processed_stories / $total_stories${NC}"
}

# エラー終了時のメッセージ
handle_error() {
  echo -e "${RED}エラーが発生しました。処理を中断します。${NC}"
  exit 1
}

# エラーハンドリングの設定
trap 'handle_error' ERR

# スクリプト実行
main 