#!/bin/bash

# GitHub ProjectsとIssuesを連携し、スプリントごとのストーリー管理を行うスクリプト
# 使用方法: ./sync_sprint_stories_to_projects.sh [プロジェクト番号] [スプリント番号]

set -e

# 色付きの出力関数
function echo_info() { echo -e "\033[0;34m$1\033[0m"; }
function echo_success() { echo -e "\033[0;32m$1\033[0m"; }
function echo_warning() { echo -e "\033[0;33m$1\033[0m"; }
function echo_error() { echo -e "\033[0;31m$1\033[0m"; }

# 引数チェック
if [ $# -lt 2 ]; then
  echo_error "エラー: プロジェクト番号とスプリント番号を指定してください"
  echo "使用方法: $0 [プロジェクト番号] [スプリント番号]"
  exit 1
fi

PROJECT_NUMBER=$1
SPRINT_NUMBER=$2

# 環境変数の確認
GITHUB_OWNER="miyatti777"
GITHUB_REPO="aipm_v3"
STORIES_DIR="/Users/daisukemiyata/aipm_v3/Stock/projects/tokyo_asset/documents/4_executing/sprint_stories/sprint_${SPRINT_NUMBER}"

# ドライランモードの確認
DRY_RUN=false
if [ "$3" == "--dry-run" ]; then
  DRY_RUN=true
  echo_warning "ドライランモード: 実際の変更は行われません"
fi

# スプリントフォルダの存在確認
if [ ! -d "$STORIES_DIR" ]; then
  echo_error "エラー: スプリント${SPRINT_NUMBER}のフォルダが見つかりません: $STORIES_DIR"
  exit 1
fi

echo_info "==== GitHub ProjectsとIssuesにスプリント${SPRINT_NUMBER}のストーリーを同期 ===="
echo_info "プロジェクト番号: $PROJECT_NUMBER"
echo_info "スプリントフォルダ: $STORIES_DIR"
echo_info "GitHub リポジトリ: $GITHUB_OWNER/$GITHUB_REPO"
echo ""

# スプリント用のラベルを作成（まだ存在しない場合）
SPRINT_LABEL="Sprint ${SPRINT_NUMBER}"
STORY_LABEL="Story"
ACCEPTANCE_LABEL="Acceptance Criteria"

# ラベル作成関数
create_label_if_not_exists() {
  local label_name="$1"
  local color="$2"
  local description="$3"
  
  if ! gh label list --repo "$GITHUB_OWNER/$GITHUB_REPO" | grep -q "$label_name"; then
    echo_info "ラベル '$label_name' を作成します..."
    if [ "$DRY_RUN" = false ]; then
      gh label create "$label_name" --repo "$GITHUB_OWNER/$GITHUB_REPO" --color "$color" --description "$description"
    fi
  else
    echo_info "ラベル '$label_name' は既に存在します"
  fi
}

create_label_if_not_exists "$SPRINT_LABEL" "0366d6" "スプリント${SPRINT_NUMBER}のストーリー"
create_label_if_not_exists "$STORY_LABEL" "1d76db" "ユーザーストーリー"
create_label_if_not_exists "$ACCEPTANCE_LABEL" "8250df" "アクセプタンス基準"

# ストーリーファイル一覧を取得
STORY_FILES=$(find "$STORIES_DIR" -name "*.md" -type f)
STORY_COUNT=$(echo "$STORY_FILES" | wc -l | tr -d '[:space:]')
echo_info "処理するストーリー数: $STORY_COUNT"

# カウンター初期化
SUCCESS_COUNT=0
AC_COUNT=0

for STORY_FILE in $STORY_FILES; do
  # ファイル名からストーリーIDを抽出
  STORY_ID=$(basename "$STORY_FILE" .md | cut -d'_' -f1)
  
  echo_info "処理中: ${STORY_ID} - ${STORY_FILE}"
  
  # ストーリータイトルを抽出
  STORY_TITLE=$(grep -m 1 "^# " "$STORY_FILE" | sed 's/^# //')
  if [ -z "$STORY_TITLE" ]; then
    # ファイル名からタイトルを生成
    STORY_TITLE=$(basename "$STORY_FILE" .md | sed 's/_/ /g')
  fi
  
  # ストーリー内容全体を取得
  STORY_CONTENT=$(<"$STORY_FILE")
  
  # 基本情報セクションを抽出 (## 基本情報 から次の ## までの内容)
  BASIC_INFO=$(awk '/^## 基本情報/,/^##/' "$STORY_FILE" | grep -v "^##" | sed '/^$/d')
  
  # 説明を抽出 (## 説明 から次の ## までの内容)
  DESCRIPTION=$(awk '/^## 説明/,/^##/' "$STORY_FILE" | grep -v "^##" | sed '/^$/d')
  if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="スプリント${SPRINT_NUMBER}のストーリー: ${STORY_ID}"
  fi
  
  # ユーザーストーリーを抽出
  USER_STORY=$(awk '/^## ユーザーストーリー/,/^##/' "$STORY_FILE" | grep -v "^##" | sed '/^$/d')
  
  # アクセプタンス基準を抽出 (## 受け入れ基準 または ## アクセプタンス基準 から次の ## までの内容)
  ACCEPTANCE_CRITERIA=$(awk '/^## 受け入れ基準/,/^##/' "$STORY_FILE" | grep -v "^##" | sed '/^$/d')
  if [ -z "$ACCEPTANCE_CRITERIA" ]; then
    ACCEPTANCE_CRITERIA=$(awk '/^## アクセプタンス基準/,/^##/' "$STORY_FILE" | grep -v "^##" | sed '/^$/d')
  fi
  
  # 技術的な詳細を抽出
  TECHNICAL_DETAILS=$(awk '/^## 技術的な詳細/,/^##/' "$STORY_FILE" | grep -v "^##" | sed '/^$/d')
  
  # 備考を抽出
  NOTES=$(awk '/^## 備考/,/^##/' "$STORY_FILE" | grep -v "^##" | sed '/^$/d')
  
  # プロジェクトアイテムの説明を構築
  PROJECT_DESCRIPTION=$(cat << EOF
# ${STORY_ID}: ${STORY_TITLE}

## 基本情報
${BASIC_INFO}

## 説明
${DESCRIPTION}

## ユーザーストーリー
${USER_STORY}

## 受け入れ基準
${ACCEPTANCE_CRITERIA}

## 技術的な詳細
${TECHNICAL_DETAILS}

## 備考
${NOTES}

---
スプリント${SPRINT_NUMBER}のストーリー
EOF
)

  # GitHub Projectsにアイテムを作成・更新
  PROJECT_ITEM_ID=""
  
  echo_info "GitHub Projectsにアイテム作成: ${STORY_ID} - ${STORY_TITLE}"
  if [ "$DRY_RUN" = false ]; then
    # PROJECT_ITEMの作成コマンド
    # 注: GitHub CLIには現在、直接Projectsにアイテムを作成する機能がないため、
    # まずドラフトIssueを作成し、それをプロジェクトに追加する必要があります
    
    # ドラフトアイテムをプロジェクトに追加
    PROJECT_ITEM_RESPONSE=$(gh project item-add "$PROJECT_NUMBER" --owner "$GITHUB_OWNER" --format json)
    
    # レスポンスからプロジェクトアイテムIDを取得
    PROJECT_ITEM_ID=$(echo "$PROJECT_ITEM_RESPONSE" | grep -o '"id": "[^"]*' | head -1 | cut -d'"' -f4)
    
    # プロジェクトアイテムのタイトルと説明を更新
    gh api graphql -f query='
      mutation {
        updateProjectV2ItemFieldValue(
          input: {
            projectId: "'"$(gh project view "$PROJECT_NUMBER" --owner "$GITHUB_OWNER" --format json | grep -o '"id": "[^"]*' | head -1 | cut -d'"' -f4)"'"
            itemId: "'"$PROJECT_ITEM_ID"'"
            fieldId: "'"$(gh api graphql -f query='\''query{projV2:projectV2(number:'"$PROJECT_NUMBER"') {fields(first:20) {nodes {... on ProjectV2FieldCommon {id name}}}}}'\'' | grep -o '\''"id": "[^"]*[tT]itle[^"]*' | head -1 | cut -d'\''"'\'' -f4)"'"
            value: {
              text: "'"${STORY_ID}: ${STORY_TITLE}"'"
            }
          }
        ) {
          projectV2Item {
            id
          }
        }
      }
    '
  else
    echo_warning "  [ドライラン] GitHub Projectsにアイテムを作成します: ${STORY_ID} - ${STORY_TITLE}"
    PROJECT_ITEM_ID="dummy_project_item_id"
  fi
  
  # アクセプタンス基準を個別のIssuesとして作成
  echo_info "アクセプタンス基準を個別のIssuesとして作成します"
  
  # アクセプタンス基準の行ごとに処理
  AC_ISSUES=()
  
  while IFS= read -r line || [[ -n "$line" ]]; do
    # 空行や数字だけの行をスキップ
    [[ -z "$line" || "$line" =~ ^[0-9.]+$ ]] && continue
    
    # 行頭の番号やビュレットを削除
    AC_TEXT=$(echo "$line" | sed -E 's/^[0-9]+\.\s*|-\s*|[0-9]+\)\s*//')
    
    # アクセプタンス基準の内容が存在する場合のみ処理
    if [[ -n "$AC_TEXT" ]]; then
      AC_TITLE="${STORY_ID} - ${AC_TEXT}"
      
      echo_info "  アクセプタンス基準: $AC_TEXT"
      
      # 既存のIssueを確認
      EXISTING_AC_ISSUE=""
      if [ "$DRY_RUN" = false ]; then
        EXISTING_AC_ISSUE=$(gh issue list --repo "$GITHUB_OWNER/$GITHUB_REPO" --label "$ACCEPTANCE_LABEL" --label "$SPRINT_LABEL" --json number,title | grep -i "$AC_TITLE" | head -1 | awk '{print $1}')
      fi
      
      AC_ISSUE_URL=""
      if [ -n "$EXISTING_AC_ISSUE" ]; then
        echo_warning "    既存のIssue (#$EXISTING_AC_ISSUE) を更新します"
        if [ "$DRY_RUN" = false ]; then
          gh issue edit "$EXISTING_AC_ISSUE" --repo "$GITHUB_OWNER/$GITHUB_REPO" \
            --title "$AC_TITLE" \
            --body "## アクセプタンス基準\n${AC_TEXT}\n\n## 親ストーリー\n${STORY_ID}: ${STORY_TITLE}\n\n_スプリント${SPRINT_NUMBER}のタスク_"
          
          AC_ISSUE_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/issues/$EXISTING_AC_ISSUE"
        fi
      else
        echo_info "    新しいIssueを作成します: $AC_TITLE"
        if [ "$DRY_RUN" = false ]; then
          AC_ISSUE_URL=$(gh issue create --repo "$GITHUB_OWNER/$GITHUB_REPO" \
            --title "$AC_TITLE" \
            --body "## アクセプタンス基準\n${AC_TEXT}\n\n## 親ストーリー\n${STORY_ID}: ${STORY_TITLE}\n\n_スプリント${SPRINT_NUMBER}のタスク_" \
            --label "$ACCEPTANCE_LABEL" \
            --label "$SPRINT_LABEL")
          
          # IssueをProjectsのアイテムにリンク
          # この部分はGraphQL APIを使用して、プロジェクトアイテムのカスタムフィールドを更新することで実現可能
        fi
      fi
      
      # URLがある場合のみ配列に追加
      if [ -n "$AC_ISSUE_URL" ]; then
        AC_ISSUES+=("$AC_ISSUE_URL")
        AC_COUNT=$((AC_COUNT+1))
      elif [ "$DRY_RUN" = true ]; then
        # ドライランモードの場合はダミーURLを追加
        AC_ISSUES+=("https://github.com/$GITHUB_OWNER/$GITHUB_REPO/issues/dummy_$AC_COUNT")
        AC_COUNT=$((AC_COUNT+1))
      fi
    fi
  done < <(echo "$ACCEPTANCE_CRITERIA")
  
  # アクセプタンス基準のIssueへのリンクを含めたプロジェクトアイテムの説明を更新
  if [ ${#AC_ISSUES[@]} -gt 0 ] && [ "$DRY_RUN" = false ]; then
    AC_LINKS="## アクセプタンス基準のIssues\n"
    for ac_url in "${AC_ISSUES[@]}"; do
      AC_ISSUE_NUMBER=$(echo "$ac_url" | grep -o '[0-9]*$')
      if [ -n "$AC_ISSUE_NUMBER" ]; then
        AC_LINKS+="- [#$AC_ISSUE_NUMBER]($ac_url)\n"
      fi
    done
    
    # プロジェクトの説明フィールドを更新（GraphQL APIを使用）
    # 注: 説明フィールドのIDを動的に取得する部分が実際の環境では必要
    if [ -n "$PROJECT_ITEM_ID" ]; then
      echo_info "  プロジェクトアイテムの説明を更新しています..."
      
      # 説明フィールドを見つけるための検索
      DESCRIPTION_FIELD_ID=$(gh api graphql -f query='
        query {
          projV2:projectV2(number:'$PROJECT_NUMBER', owner:"'$GITHUB_OWNER'") {
            fields(first:20) {
              nodes {
                ... on ProjectV2FieldCommon {
                  id
                  name
                }
              }
            }
          }
        }
      ' | grep -o '"id": "[^"]*[dD]escription[^"]*' | head -1 | cut -d'"' -f4)
      
      if [ -n "$DESCRIPTION_FIELD_ID" ]; then
        # プロジェクトアイテムの説明フィールドを更新
        gh api graphql -f query='
          mutation {
            updateProjectV2ItemFieldValue(
              input: {
                projectId: "'"$(gh project view "$PROJECT_NUMBER" --owner "$GITHUB_OWNER" --format json | grep -o '"id": "[^"]*' | head -1 | cut -d'"' -f4)"'"
                itemId: "'"$PROJECT_ITEM_ID"'"
                fieldId: "'"$DESCRIPTION_FIELD_ID"'"
                value: {
                  text: "'"${PROJECT_DESCRIPTION//$'\n'/\\n}\\n\\n${AC_LINKS}"'"
                }
              }
            ) {
              projectV2Item {
                id
              }
            }
          }
        '
      else
        echo_warning "  説明フィールドのIDが見つかりません"
      fi
    fi
  elif [ "$DRY_RUN" = true ]; then
    echo_warning "  [ドライラン] プロジェクトアイテムの説明を更新します"
  fi
  
  SUCCESS_COUNT=$((SUCCESS_COUNT+1))
  echo_success "  ${STORY_ID} の処理が完了しました"
  echo ""
done

echo_success "==== 同期完了 ===="
echo_success "処理されたストーリー: ${SUCCESS_COUNT}/${STORY_COUNT}"
echo_success "作成されたアクセプタンス基準Issues: ${AC_COUNT}"
echo_success "GitHub Projectで確認: https://github.com/users/${GITHUB_OWNER}/projects/${PROJECT_NUMBER}" 