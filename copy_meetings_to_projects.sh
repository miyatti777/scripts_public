#!/bin/bash
#=============================================================
# copy_meetings_to_projects.sh
# 目的: 会議議事録をプロジェクトごとのMeetingsフォルダにコピーする
#=============================================================

set -e

ROOT_DIR="/Users/daisukemiyata/aipm_v3"
FLOW_DIR="${ROOT_DIR}/Flow"
PROGRAMS_DIR="${ROOT_DIR}/Stock/programs"

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

# ディレクトリ存在確認
if [[ ! -d "$FLOW_DIR" ]]; then
  echo "エラー: ${FLOW_DIR} が見つかりません"
  exit 1
fi

if [[ ! -d "$PROGRAMS_DIR" ]]; then
  echo "エラー: ${PROGRAMS_DIR} が見つかりません"
  echo "先に migrate_program_structure.sh を実行してください"
  exit 1
fi

echo "=== 会議議事録の移行を開始します ==="

# 各プログラムとプロジェクトの処理
find "$PROGRAMS_DIR" -type d -path "*/projects/*" | while read -r project_dir; do
  # プロジェクト名とプログラム名を抽出
  project_name=$(basename "$project_dir")
  program_name=$(basename "$(dirname "$(dirname "$project_dir")")")
  
  # 実行フェーズのMeetingsディレクトリパス
  meetings_dir="${project_dir}/documents/4_executing/Meetings"
  
  if [[ "$VERBOSE" = true ]]; then
    echo "プロジェクト処理中: ${program_name}/${project_name}"
  fi
  
  # Meetingsディレクトリ作成
  if [[ "$DRY_RUN" = false ]]; then
    mkdir -p "$meetings_dir"
    if [[ "$VERBOSE" = true ]]; then
      echo "  作成: ${meetings_dir}"
    fi
  else
    echo "[DRY RUN] 作成: ${meetings_dir}"
  fi
  
  # 会議議事録ファイルを探して移動
  meeting_files_found=0
  
  # Flow内の日付ディレクトリを検索
  for date_dir in "$FLOW_DIR"/*; do
    if [[ -d "$date_dir" && "$(basename "$date_dir")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      # 会議議事録ファイルを検索
      find "$date_dir" -type f -name "*.md" | while read -r file; do
        filename=$(basename "$file")
        file_content=$(<"$file")
        
        # プロジェクト関連の会議議事録を特定
        # 1. ファイル名に "meeting" か "議事録" を含む
        # 2. ファイル内容にプログラム名かプロジェクト名を含む
        if [[ "$filename" =~ meeting|議事録 ]] && \
           ( [[ "$file_content" =~ $program_name ]] || [[ "$file_content" =~ $project_name ]] ); then
          
          meeting_date=$(basename "$date_dir")
          target_file="${meetings_dir}/${meeting_date}_${filename}"
          
          if [[ "$DRY_RUN" = false ]]; then
            echo "  コピー: ${file} → ${target_file}"
            cp "$file" "$target_file"
            meeting_files_found=1
          else
            echo "[DRY RUN] コピー: ${file} → ${target_file}"
            meeting_files_found=1
          fi
        fi
      done
    fi
  done
  
  if [[ "$meeting_files_found" -eq 0 && "$VERBOSE" = true ]]; then
    echo "  ${program_name}/${project_name} に関連する会議議事録は見つかりませんでした"
  fi
done

echo "=== 会議議事録の移行が完了しました ==="
echo "各プロジェクトの documents/4_executing/Meetings フォルダに会議議事録がコピーされました"

exit 0 