#!/bin/bash
#=============================================================
# migrate_program_structure.sh
# 目的: 既存の Stock/projects 構造をプログラム階層を含む新構造に移行する
#=============================================================

set -e

ROOT_DIR="/Users/daisukemiyata/aipm_v3"
STOCK_DIR="${ROOT_DIR}/Stock"
OLD_PROJECTS_DIR="${STOCK_DIR}/projects"
NEW_PROGRAMS_DIR="${STOCK_DIR}/programs"

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
if [[ ! -d "$OLD_PROJECTS_DIR" ]]; then
  echo "エラー: ${OLD_PROJECTS_DIR} が見つかりません"
  exit 1
fi

# プログラムディレクトリ作成
if [[ "$DRY_RUN" = false ]]; then
  mkdir -p "$NEW_PROGRAMS_DIR"
  echo "作成: ${NEW_PROGRAMS_DIR}"
else
  echo "[DRY RUN] 作成: ${NEW_PROGRAMS_DIR}"
fi

# bashのバージョンを確認
bash_version=$(bash --version | head -n 1 | awk '{print $4}' | cut -d '.' -f 1)
if [[ "$bash_version" -ge 4 ]]; then
  # bash 4以上では連想配列を使用
  declare -A project_to_program
  project_to_program["kakakucom"]="kakakucom"
  project_to_program["tokyo_asset"]="tokyo_asset"
  project_to_program["AI-EVANGELIST"]="AI-EVANGELIST"
  project_to_program["AIPM-PMBOK"]="AIPM"
  project_to_program["PJA"]="PJA"

  declare -A project_mapping
  project_mapping["kakakucom"]="aipm_for_kc"
  project_mapping["tokyo_asset"]="tas_ai_system"
  project_mapping["AI-EVANGELIST"]="kouza_2"
  project_mapping["AIPM-PMBOK"]="pmbok_impl"
  project_mapping["PJA"]="pja_project"
else
  # より古いbashバージョンではケースで対応
  echo "警告: Bash 4未満のバージョンを検出しました。簡易マッピングを使用します。"
  get_program_for_project() {
    local project="$1"
    case "$project" in
      "kakakucom") echo "kakakucom" ;;
      "tokyo_asset") echo "tokyo_asset" ;;
      "AI-EVANGELIST") echo "AI-EVANGELIST" ;;
      "AIPM-PMBOK") echo "AIPM" ;;
      "PJA") echo "PJA" ;;
      *) echo "$project" ;;
    esac
  }
  
  get_new_project_name() {
    local project="$1"
    case "$project" in
      "kakakucom") echo "aipm_for_kc" ;;
      "tokyo_asset") echo "tas_ai_system" ;;
      "AI-EVANGELIST") echo "kouza_2" ;;
      "AIPM-PMBOK") echo "pmbok_impl" ;;
      "PJA") echo "pja_project" ;;
      *) echo "$project" ;;
    esac
  }
fi

# 例外ケース: Sample プログラム
hongo_chintai_program="Sample"
hongo_chintai_project="Hongo_Chintai"

echo "=== プログラム構造への移行を開始します ==="

# 既存プロジェクトの変換
for project_dir in "${OLD_PROJECTS_DIR}"/*; do
  if [[ ! -d "$project_dir" ]]; then
    continue
  fi
  
  project_name=$(basename "$project_dir")
  
  # 特殊ケース: Hongo_Chintai
  if [[ "$project_name" == "Hongo_Chintai" ]]; then
    program_name="$hongo_chintai_program"
    new_project_name="$hongo_chintai_project"
  else
    # 通常のマッピング
    if [[ "$bash_version" -ge 4 ]]; then
      program_name="${project_to_program[$project_name]:-$project_name}"
      new_project_name="${project_mapping[$project_name]:-$project_name}"
    else
      program_name=$(get_program_for_project "$project_name")
      new_project_name=$(get_new_project_name "$project_name")
    fi
  fi
  
  # 新しいプログラムとプロジェクトの場所
  new_program_dir="${NEW_PROGRAMS_DIR}/${program_name}"
  new_project_dir="${new_program_dir}/projects/${new_project_name}"
  
  if [[ "$VERBOSE" = true ]]; then
    echo "プロジェクト: $project_name → プログラム: $program_name, 新プロジェクト: $new_project_name"
  fi
  
  if [[ "$DRY_RUN" = false ]]; then
    # プログラムディレクトリ作成
    mkdir -p "$new_program_dir/projects"
    
    # プロジェクトディレクトリ移動
    echo "移行: ${project_dir} → ${new_project_dir}"
    cp -r "$project_dir" "$new_project_dir"
  else
    echo "[DRY RUN] 作成: ${new_program_dir}/projects"
    echo "[DRY RUN] 移行: ${project_dir} → ${new_project_dir}"
  fi
done

echo "=== プログラム構造への移行が完了しました ==="
echo "注意: 元のプロジェクトディレクトリはバックアップとして残されています。"
echo "問題がなければ手動で削除してください: ${OLD_PROJECTS_DIR}"

exit 0 