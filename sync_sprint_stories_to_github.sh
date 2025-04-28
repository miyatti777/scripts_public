#!/bin/bash

# GitHub ProjectsとIssuesを連携するスクリプト
# 使用方法: ./sync_sprint_stories_to_github.sh [プロジェクト番号] [スプリント番号] [--dry-run]

set -e

# 色付きの出力関数
function echo_info() { echo -e "\033[0;34m$1\033[0m"; }
function echo_success() { echo -e "\033[0;32m$1\033[0m"; }
function echo_warning() { echo -e "\033[0;33m$1\033[0m"; }
function echo_error() { echo -e "\033[0;31m$1\033[0m"; }

# 引数チェック
if [ $# -lt 2 ]; then
  echo_error "エラー: プロジェクト番号とスプリント番号を指定してください"
  echo "使用方法: $0 [プロジェクト番号] [スプリント番号] [--dry-run]"
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
TEMP_LABEL="Temp"

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
create_label_if_not_exists "$TEMP_LABEL" "ededed" "一時的なIssue（自動生成）"

# ストーリーファイル一覧を取得
STORY_FILES=$(find "$STORIES_DIR" -name "*.md" -type l -o -name "*.md" -type f)
STORY_COUNT=$(echo "$STORY_FILES" | wc -l | tr -d '[:space:]')
echo_info "処理するストーリー数: $STORY_COUNT"

# カウンター初期化
SUCCESS_COUNT=0
AC_COUNT=0

for STORY_FILE in $STORY_FILES; do
  # シンボリックリンクの場合は実際のファイルを参照
  REAL_STORY_FILE="$STORY_FILE"
  if [ -L "$STORY_FILE" ]; then
    REAL_STORY_FILE=$(readlink "$STORY_FILE")
    echo_info "シンボリックリンク: $STORY_FILE -> $REAL_STORY_FILE"
  fi
  
  # ファイル名からストーリーIDを抽出
  STORY_ID=$(basename "$REAL_STORY_FILE" .md | cut -d'_' -f1)
  
  echo_info "処理中: ${STORY_ID} - ${REAL_STORY_FILE}"
  
  # ストーリータイトルを抽出
  STORY_TITLE=$(grep -m 1 "^# " "$REAL_STORY_FILE" | sed 's/^# //')
  if [ -z "$STORY_TITLE" ]; then
    # ファイル名からタイトルを生成
    STORY_TITLE=$(basename "$REAL_STORY_FILE" .md | sed 's/_/ /g')
  fi
  
  # タイトルが既にストーリーIDで始まっているか確認
  if [[ "$STORY_TITLE" == "$STORY_ID:"* || "$STORY_TITLE" == "$STORY_ID "* ]]; then
    # すでにIDがタイトルに含まれている場合はそのまま使用
    FULL_TITLE="$STORY_TITLE"
  else
    # IDがタイトルに含まれていない場合は追加
    FULL_TITLE="${STORY_ID}: ${STORY_TITLE}"
  fi
  
  # 各セクションを抽出
  USER_STORY=""
  if grep -q "^## ユーザーストーリー" "$REAL_STORY_FILE"; then
    USER_STORY=$(sed -n '/^## ユーザーストーリー/,/^##/p' "$REAL_STORY_FILE" | grep -v "^##" | sed '/^$/d')
  fi
  
  DESCRIPTION=""
  if grep -q "^## 説明" "$REAL_STORY_FILE"; then
    DESCRIPTION=$(sed -n '/^## 説明/,/^##/p' "$REAL_STORY_FILE" | grep -v "^##" | sed '/^$/d')
  fi
  
  ACCEPTANCE_CRITERIA=""
  if grep -q "^## 受け入れ基準" "$REAL_STORY_FILE"; then
    ACCEPTANCE_CRITERIA=$(sed -n '/^## 受け入れ基準/,/^##/p' "$REAL_STORY_FILE" | grep -v "^##" | sed '/^$/d')
  elif grep -q "^## アクセプタンス基準" "$REAL_STORY_FILE"; then
    ACCEPTANCE_CRITERIA=$(sed -n '/^## アクセプタンス基準/,/^##/p' "$REAL_STORY_FILE" | grep -v "^##" | sed '/^$/d')
  fi
  
  TECHNICAL_DETAILS=""
  if grep -q "^## 技術的な詳細" "$REAL_STORY_FILE"; then
    TECHNICAL_DETAILS=$(sed -n '/^## 技術的な詳細/,/^##/p' "$REAL_STORY_FILE" | grep -v "^##" | sed '/^$/d')
  fi
  
  NOTES=""
  if grep -q "^## 備考" "$REAL_STORY_FILE"; then
    NOTES=$(sed -n '/^## 備考/,/^##/p' "$REAL_STORY_FILE" | grep -v "^##" | sed '/^$/d')
  fi
  
  # アクセプタンス基準リスト（後でIssue作成後にID参照用）
  AC_LIST=""
  
  # 完全な説明文を作成
  FULL_DESCRIPTION=$(cat << EOF
## ユーザーストーリー
${USER_STORY:-開発者として、このストーリーを実装したい}

## 受け入れ基準
${ACCEPTANCE_CRITERIA:-なし}

## 技術的な詳細
${TECHNICAL_DETAILS:-このストーリーの実装には以下の技術が必要です}

## 備考
${NOTES:-実装時の注意点や関連事項}

---
スプリント${SPRINT_NUMBER}のストーリー
EOF
)
  
  # GitHub Projectsにドラフトアイテムを直接作成
  echo_info "GitHub Projectsにドラフトアイテム作成: ${STORY_ID} - ${STORY_TITLE}"
  
  PROJECT_ITEM_ID=""
  
  if [ "$DRY_RUN" = false ]; then
    # まずIssueを作成し、それをProjectに追加する方法を使用
    # (ドラフトアイテムの直接作成はより複雑なGraphQL APIが必要)
    echo_info "一時的なIssueを作成します..."
    TEMP_ISSUE_URL=$(gh issue create --repo "$GITHUB_OWNER/$GITHUB_REPO" \
      --title "$FULL_TITLE" \
      --body "$FULL_DESCRIPTION" \
      --label "$SPRINT_LABEL" \
      --label "$STORY_LABEL" \
      --label "$TEMP_LABEL")
    
    TEMP_ISSUE_NUMBER=$(echo "$TEMP_ISSUE_URL" | grep -o '[0-9]*$')
    echo_success "一時Issue #${TEMP_ISSUE_NUMBER} を作成しました"
    
    # Issueをプロジェクトに追加
    echo_info "Issueをプロジェクトに追加します..."
    gh project item-add "$PROJECT_NUMBER" --owner "$GITHUB_OWNER" --url "$TEMP_ISSUE_URL"
    echo_success "プロジェクトアイテムを作成しました"
    
    # 作成したIssueのURLを保存
    PARENT_URL="$TEMP_ISSUE_URL"
    PARENT_ISSUE_NUMBER="$TEMP_ISSUE_NUMBER"
    
    # 一時的なIssueをクローズしてIssues一覧に表示されないようにする
    echo_info "一時Issueをクローズします..."
    gh issue close "$TEMP_ISSUE_NUMBER" --repo "$GITHUB_OWNER/$GITHUB_REPO" --comment "このIssueはプロジェクトアイテムとして使用するために作成された一時的なものです。アクセプタンス基準は個別のIssuesを参照してください。"
    echo_success "一時Issue #${TEMP_ISSUE_NUMBER} をクローズしました"
  else
    echo_warning "  [ドライラン] GitHub Projectsにドラフトアイテムを作成します: ${STORY_ID} - ${STORY_TITLE}"
    PARENT_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/issues/999"
    PARENT_ISSUE_NUMBER="999"
  fi
  
  # アクセプタンス基準を個別のIssuesとして作成
  echo_info "アクセプタンス基準を個別のIssuesとして作成します"
  
  # アクセプタンス基準の行ごとに処理
  AC_ISSUES=()
  
  echo "$ACCEPTANCE_CRITERIA" | while read -r line; do
    # 空行や数字だけの行をスキップ
    [ -z "$line" ] && continue
    [[ "$line" =~ ^[0-9.]+$ ]] && continue
    
    # 行頭の番号やビュレットを削除
    AC_TEXT=$(echo "$line" | sed -E 's/^[0-9]+\.\s*//;s/^-\s*//;s/^[0-9]+\)\s*//')
    
    # アクセプタンス基準の内容が存在する場合のみ処理
    if [ -n "$AC_TEXT" ]; then
      AC_TITLE="${STORY_ID}-AC: ${AC_TEXT}"
      
      echo_info "  アクセプタンス基準: $AC_TEXT"
      
      if [ "$DRY_RUN" = false ]; then
        # アクセプタンス基準Issue作成
        CHILD_BODY=$(cat << EOF
## アクセプタンス基準
${AC_TEXT}

## 親ストーリー
${FULL_TITLE} (#${PARENT_ISSUE_NUMBER})

このIssueは [親ストーリー](${PARENT_URL}) のアクセプタンス基準です。

_スプリント${SPRINT_NUMBER}のアクセプタンス基準_
EOF
)
        
        # アクセプタンス基準Issue作成
        ISSUE_URL=$(gh issue create --repo "$GITHUB_OWNER/$GITHUB_REPO" \
          --title "$AC_TITLE" \
          --body "$CHILD_BODY" \
          --label "$ACCEPTANCE_LABEL" \
          --label "$SPRINT_LABEL")
        
        CHILD_ISSUE_NUMBER=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
        echo_success "    アクセプタンス基準Issue #${CHILD_ISSUE_NUMBER} を作成しました: $AC_TEXT"
        
        # アクセプタンス基準リストに追加
        AC_LIST="${AC_LIST}\n- [#${CHILD_ISSUE_NUMBER}](${ISSUE_URL}) ${AC_TEXT}"
        
        AC_ISSUES+=("$ISSUE_URL")
        AC_COUNT=$((AC_COUNT+1))
      else
        echo_warning "    [ドライラン] Issueを作成します: $AC_TITLE"
        AC_COUNT=$((AC_COUNT+1))
      fi
    fi
  done
  
  # 親Issueの説明を更新して子Issueへのリンクを追加
  if [ "$DRY_RUN" = false ] && [ -n "$AC_LIST" ] && [ -n "$PARENT_ISSUE_NUMBER" ]; then
    echo_info "  親Issue #${PARENT_ISSUE_NUMBER} を更新し、アクセプタンス基準Issuesへのリンクを追加します"
    
    # 更新された説明文を作成（アクセプタンス基準Issuesへのリンクを追加）
    UPDATED_BODY="${FULL_DESCRIPTION}

## アクセプタンス基準Issues${AC_LIST}

---
注: このIssueはプロジェクトのみで表示され、Issues一覧には表示されません。"
    
    # 親Issueの本文を更新
    gh issue edit "$PARENT_ISSUE_NUMBER" --repo "$GITHUB_OWNER/$GITHUB_REPO" --body "$UPDATED_BODY"
    echo_success "  親Issueの説明を更新しました"
  fi
  
  SUCCESS_COUNT=$((SUCCESS_COUNT+1))
  echo_success "  ${STORY_ID} の処理が完了しました"
  echo ""
done

echo_success "==== 同期完了 ===="
echo_success "処理されたストーリー: ${SUCCESS_COUNT}/${STORY_COUNT}"
echo_success "作成されたアクセプタンス基準Issues: ${AC_COUNT}"
echo_success "GitHub Projectで確認: https://github.com/users/${GITHUB_OWNER}/projects/${PROJECT_NUMBER}" 