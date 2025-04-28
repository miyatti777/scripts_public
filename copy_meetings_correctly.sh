#!/bin/bash
#=============================================================
# copy_meetings_correctly.sh
# 目的: 会議議事録をプロジェクトごとの適切なMeetingsフォルダにコピーする
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

# プロジェクト名の配列とパスの配列を個別に定義
project_names=(
  "tokyo_asset"
  "kakakucom"
  "AI-EVANGELIST"
  "hongo_chintai"
  "Hongo_Chintai"
)

project_paths=(
  "${PROGRAMS_DIR}/tokyo_asset/projects/tas_ai_system/documents/4_executing/Meetings"
  "${PROGRAMS_DIR}/kakakucom/projects/aipm_for_kc/documents/4_executing/Meetings"
  "${PROGRAMS_DIR}/AI-EVANGELIST/projects/kouza_2/documents/4_executing/Meetings"
  "${PROGRAMS_DIR}/Sample/projects/Hongo_Chintai/documents/4_executing/Meetings"
  "${PROGRAMS_DIR}/Sample/projects/Hongo_Chintai/documents/4_executing/Meetings"
)

# Meetingsディレクトリを作成
for ((i=0; i<${#project_names[@]}; i++)); do
  meetings_dir="${project_paths[$i]}"
  
  if [[ "$DRY_RUN" = false ]]; then
    mkdir -p "$meetings_dir"
    if [[ "$VERBOSE" = true ]]; then
      echo "作成: ${meetings_dir}"
    fi
  else
    echo "[DRY RUN] 作成: ${meetings_dir}"
  fi
done

# ファイル総数カウンタ
total_files_copied=0

# Flowディレクトリ内の日付フォルダを走査
for date_dir in $(find "$FLOW_DIR" -maxdepth 1 -type d -name "20??-??-??"); do
  date_name=$(basename "$date_dir")
  
  # 各日付フォルダ内の会議議事録を検索
  for file in $(find "$date_dir" -type f \( -name "*meeting*.md" -o -name "*議事録*.md" \)); do
    filename=$(basename "$file")
    file_content=$(<"$file")
    
    # ファイルの内容からプロジェクトを特定
    for ((i=0; i<${#project_names[@]}; i++)); do
      project_name="${project_names[$i]}"
      if [[ "$file_content" =~ $project_name ]]; then
        meetings_dir="${project_paths[$i]}"
        output_file="${meetings_dir}/${date_name}_${filename}"
        
        if [[ "$DRY_RUN" = false ]]; then
          mkdir -p "$meetings_dir"
          echo "コピー: ${file} → ${output_file}"
          cp "$file" "$output_file"
          total_files_copied=$((total_files_copied + 1))
        else
          echo "[DRY RUN] コピー: ${file} → ${output_file}"
          total_files_copied=$((total_files_copied + 1))
        fi
        
        # 見つかったらこのファイルの処理を終了（重複コピー防止）
        break
      fi
    done
  done
done

if [[ "$total_files_copied" -eq 0 ]]; then
  echo "会議議事録が見つかりませんでした"
else
  echo "合計 ${total_files_copied} 件の会議議事録ファイルを処理しました"
fi

echo "=== 会議議事録の移行が完了しました ==="
echo "各プロジェクトの documents/4_executing/Meetings フォルダに会議議事録がコピーされました"

exit 0 