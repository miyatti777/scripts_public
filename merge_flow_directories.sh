#!/bin/bash
#=============================================================
# merge_flow_directories.sh
# 目的: Flow/PrivateとFlow/Publicディレクトリを統合する
#=============================================================

set -e

ROOT_DIR="/Users/daisukemiyata/aipm_v3"
FLOW_DIR="${ROOT_DIR}/Flow"
PRIVATE_DIR="${FLOW_DIR}/Private"
PUBLIC_DIR="${FLOW_DIR}/Public"
ARCHIVE_DIR="${FLOW_DIR}/archived_structure"

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
if [[ ! -d "$PRIVATE_DIR" || ! -d "$PUBLIC_DIR" ]]; then
  echo "エラー: ${PRIVATE_DIR} または ${PUBLIC_DIR} が見つかりません"
  exit 1
fi

# アーカイブディレクトリ作成(元の構造をバックアップ)
if [[ "$DRY_RUN" = false ]]; then
  mkdir -p "$ARCHIVE_DIR"
  echo "作成: ${ARCHIVE_DIR}"
else
  echo "[DRY RUN] 作成: ${ARCHIVE_DIR}"
fi

echo "=== Flow ディレクトリの統合を開始します ==="

# Private/Public 内の日付ディレクトリをスキャン
all_dates=()
for dir in "$PRIVATE_DIR"/* "$PUBLIC_DIR"/*; do
  if [[ -d "$dir" ]]; then
    date_dir=$(basename "$dir")
    # 日付形式のディレクトリのみ処理（YYYY-MM-DD形式）
    if [[ "$date_dir" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      if [[ ! " ${all_dates[@]} " =~ " ${date_dir} " ]]; then
        all_dates+=("$date_dir")
      fi
    fi
  fi
done

# 各日付ディレクトリを処理
for date_dir in "${all_dates[@]}"; do
  private_date_dir="${PRIVATE_DIR}/${date_dir}"
  public_date_dir="${PUBLIC_DIR}/${date_dir}"
  new_date_dir="${FLOW_DIR}/${date_dir}"
  
  if [[ "$VERBOSE" = true ]]; then
    echo "処理中: ${date_dir}"
  fi
  
  if [[ "$DRY_RUN" = false ]]; then
    # 新日付ディレクトリ作成
    mkdir -p "$new_date_dir"
    
    # Private→新ディレクトリへファイル移動
    if [[ -d "$private_date_dir" ]]; then
      echo "移行: ${private_date_dir}/* → ${new_date_dir}/"
      cp -r "${private_date_dir}/"* "${new_date_dir}/" 2>/dev/null || true
    fi
    
    # Public→新ディレクトリへファイル移動
    if [[ -d "$public_date_dir" ]]; then
      echo "移行: ${public_date_dir}/* → ${new_date_dir}/"
      cp -r "${public_date_dir}/"* "${new_date_dir}/" 2>/dev/null || true
    fi
  else
    echo "[DRY RUN] 作成: ${new_date_dir}"
    [[ -d "$private_date_dir" ]] && echo "[DRY RUN] 移行: ${private_date_dir}/* → ${new_date_dir}/"
    [[ -d "$public_date_dir" ]] && echo "[DRY RUN] 移行: ${public_date_dir}/* → ${new_date_dir}/"
  fi
done

# テンプレートディレクトリをマージ
if [[ -d "${PRIVATE_DIR}/templates" || -d "${PUBLIC_DIR}/templates" ]]; then
  merged_templates_dir="${FLOW_DIR}/templates"
  
  if [[ "$DRY_RUN" = false ]]; then
    mkdir -p "$merged_templates_dir"
    echo "作成: ${merged_templates_dir}"
    
    if [[ -d "${PRIVATE_DIR}/templates" ]]; then
      echo "移行: ${PRIVATE_DIR}/templates/* → ${merged_templates_dir}/"
      cp -r "${PRIVATE_DIR}/templates/"* "${merged_templates_dir}/" 2>/dev/null || true
    fi
    
    if [[ -d "${PUBLIC_DIR}/templates" ]]; then
      echo "移行: ${PUBLIC_DIR}/templates/* → ${merged_templates_dir}/"
      cp -r "${PUBLIC_DIR}/templates/"* "${merged_templates_dir}/" 2>/dev/null || true
    fi
  else
    echo "[DRY RUN] 作成: ${merged_templates_dir}"
    [[ -d "${PRIVATE_DIR}/templates" ]] && echo "[DRY RUN] 移行: ${PRIVATE_DIR}/templates/* → ${merged_templates_dir}/"
    [[ -d "${PUBLIC_DIR}/templates" ]] && echo "[DRY RUN] 移行: ${PUBLIC_DIR}/templates/* → ${merged_templates_dir}/"
  fi
fi

# 元のディレクトリをアーカイブに移動
if [[ "$DRY_RUN" = false ]]; then
  if [[ -d "$PRIVATE_DIR" ]]; then
    echo "アーカイブ: ${PRIVATE_DIR} → ${ARCHIVE_DIR}/Private"
    mv "$PRIVATE_DIR" "${ARCHIVE_DIR}/"
  fi
  
  if [[ -d "$PUBLIC_DIR" ]]; then
    echo "アーカイブ: ${PUBLIC_DIR} → ${ARCHIVE_DIR}/Public"
    mv "$PUBLIC_DIR" "${ARCHIVE_DIR}/"
  fi
else
  echo "[DRY RUN] アーカイブ: ${PRIVATE_DIR} → ${ARCHIVE_DIR}/Private"
  echo "[DRY RUN] アーカイブ: ${PUBLIC_DIR} → ${ARCHIVE_DIR}/Public"
fi

echo "=== Flow ディレクトリの統合が完了しました ==="
echo "元のディレクトリ構造は ${ARCHIVE_DIR} にアーカイブされています。"
echo "問題がなければ手動で削除してください。"

exit 0 