#!/bin/bash

# GitHub ProjectsのスプリントラベルをIterationフィールドにマッピングするスクリプト
# 使用方法: ./map_sprint_to_iteration.sh [プロジェクト番号]

set -e

# 色付きの出力関数
function echo_info() { echo -e "\033[0;34m$1\033[0m"; }
function echo_success() { echo -e "\033[0;32m$1\033[0m"; }
function echo_warning() { echo -e "\033[0;33m$1\033[0m"; }
function echo_error() { echo -e "\033[0;31m$1\033[0m"; }

# 引数チェック
if [ $# -lt 1 ]; then
  echo_error "エラー: プロジェクト番号を指定してください"
  echo "使用方法: $0 [プロジェクト番号]"
  exit 1
fi

PROJECT_NUMBER=$1
GITHUB_OWNER="miyatti777"
REPO="aipm_v3"
DRY_RUN=false

if [ "$2" == "--dry-run" ]; then
  DRY_RUN=true
  echo_warning "ドライランモード: 実際の変更は行われません"
fi

# プロジェクトIDを取得
echo_info "プロジェクト情報を取得中..."
PROJECT_JSON=$(gh project list --owner "$GITHUB_OWNER" --format json)
PROJECT_ID=$(echo "$PROJECT_JSON" | jq -r --arg num "$PROJECT_NUMBER" '.projects[] | select(.number | tostring == $num) | .id')

if [ -z "$PROJECT_ID" ]; then
  echo_error "プロジェクト番号 $PROJECT_NUMBER が見つかりませんでした。"
  exit 1
fi

echo_success "プロジェクトID: $PROJECT_ID"

# 必要なフィールドIDを取得
echo_info "プロジェクトフィールド情報を取得中..."
FIELDS_JSON=$(gh api graphql -F query='
  query($project_id: ID!) {
    node(id: $project_id) {
      ... on ProjectV2 {
        fields(first: 20) {
          nodes {
            ... on ProjectV2IterationField {
              id
              name
              configuration {
                iterations {
                  id
                  title
                }
              }
            }
          }
        }
      }
    }
  }
' -F project_id="$PROJECT_ID")

ITERATION_FIELD_ID=$(echo "$FIELDS_JSON" | jq -r '.data.node.fields.nodes[] | select(has("configuration")) | .id')
ITERATIONS_JSON=$(echo "$FIELDS_JSON" | jq -r '.data.node.fields.nodes[] | select(has("configuration")) | .configuration.iterations')

if [ -z "$ITERATION_FIELD_ID" ]; then
  echo_error "プロジェクトからIterationフィールドが見つかりませんでした。"
  exit 1
fi

echo_success "Iterationフィールド ID: $ITERATION_FIELD_ID"

# 利用可能なIteration情報を表示
echo_info "利用可能なIteration情報:"
echo "$ITERATIONS_JSON" | jq -r '.[] | "ID: \(.id), タイトル: \(.title)"'

# プロジェクトのアイテムを取得
echo_info "プロジェクトアイテムを取得中..."
ITEMS_JSON=$(gh project item-list $PROJECT_NUMBER --owner "$GITHUB_OWNER" --limit 100 --format json)
ITEMS_COUNT=$(echo "$ITEMS_JSON" | jq '.totalCount')
echo_success "プロジェクト内のアイテム数: $ITEMS_COUNT"

# 処理カウンター
processed_count=0
updated_count=0

# 一時ファイルを作成
TEMP_ITEMS_FILE=$(mktemp)
echo "$ITEMS_JSON" | jq -c '.items[]' > "$TEMP_ITEMS_FILE"

# 各アイテムを処理
while IFS= read -r item; do
  # アイテムIDを取得
  ITEM_ID=$(echo "$item" | jq -r '.id')
  
  # タイトルを取得
  TITLE=$(echo "$item" | jq -r '.title')
  
  # ラベルを取得
  LABELS=$(echo "$item" | jq -r '.labels[]?' 2>/dev/null || echo "")
  
  # Sprintラベルを検索
  SPRINT_LABEL=$(echo "$LABELS" | grep -E "Sprint [0-9]+" | head -n 1)
  
  processed_count=$((processed_count+1))
  echo_info "[$processed_count/$ITEMS_COUNT] アイテム '$TITLE' を処理中..."
  
  # Sprintラベルがある場合
  if [ -n "$SPRINT_LABEL" ]; then
    # Sprintの番号を抽出（例: "Sprint 3" から "3" を取得）
    SPRINT_NUMBER=$(echo "$SPRINT_LABEL" | grep -oE '[0-9]+')
    
    if [ -n "$SPRINT_NUMBER" ]; then
      echo_info "  Sprint $SPRINT_NUMBER ラベルが見つかりました"
      
      # 対応するIterationのIDを取得
      ITERATION_ID=$(echo "$ITERATIONS_JSON" | jq -r --arg sprint "Sprint $SPRINT_NUMBER" '.[] | select(.title | contains($sprint)) | .id')
      
      if [ -z "$ITERATION_ID" ]; then
        echo_warning "  警告: Sprint $SPRINT_NUMBER に対応するIterationが見つかりませんでした"
        continue
      fi
      
      # Iterationを設定
      if [ "$DRY_RUN" = false ]; then
        echo_info "  Iterationフィールドを更新中..."
        
        # GraphQLでIterationフィールドを更新
        MUTATION_RESULT=$(gh api graphql -F query='
          mutation($project_id: ID!, $item_id: ID!, $field_id: ID!, $iteration_id: String!) {
            updateProjectV2ItemFieldValue(input: {
              projectId: $project_id,
              itemId: $item_id,
              fieldId: $field_id,
              value: { 
                iterationId: $iteration_id
              }
            }) {
              projectV2Item {
                id
              }
            }
          }
        ' -F project_id="$PROJECT_ID" -F item_id="$ITEM_ID" -F field_id="$ITERATION_FIELD_ID" -F iteration_id="$ITERATION_ID")
        
        echo_success "  Iterationフィールドを 'Sprint $SPRINT_NUMBER' に更新しました"
        updated_count=$((updated_count+1))
      else
        echo_warning "  [ドライラン] Iterationフィールドを 'Sprint $SPRINT_NUMBER' に設定します"
        updated_count=$((updated_count+1))
      fi
    else
      echo_warning "  警告: Sprintラベルから番号を抽出できませんでした: $SPRINT_LABEL"
    fi
  else
    echo_info "  Sprintラベルが見つかりませんでした - スキップします"
  fi
  
  echo ""
done < "$TEMP_ITEMS_FILE"

# 一時ファイルを削除
rm -f "$TEMP_ITEMS_FILE"

echo_success "==== 処理完了 ===="
echo_success "処理したアイテム: $processed_count"
echo_success "更新したアイテム: $updated_count"
echo_success "GitHub Projectで確認: https://github.com/users/${GITHUB_OWNER}/projects/${PROJECT_NUMBER}" 