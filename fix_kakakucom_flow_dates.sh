#!/bin/bash

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 不正なフォルダ名の修正
fix_folder() {
    # 2025-25-03 → 2025-03-25 のように修正
    for dir in $(find Flow -type d -name "2025-[0-9][0-9]-[0-9][0-9]" 2>/dev/null); do
        dir_name=$(basename "$dir")
        parent_dir=$(dirname "$dir")
        
        # YYYY-MM-DD形式のチェック
        if [[ "$dir_name" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
            year="${BASH_REMATCH[1]}"
            month="${BASH_REMATCH[2]}"
            day="${BASH_REMATCH[3]}"
            
            # 月が12より大きい場合は日付と月を入れ替え
            if [ "$month" -gt 12 ]; then
                correct_dir_name="${year}-${day}-${month}"
                
                # 修正後の月が12を超える場合はさらに調整
                if [ "$day" -gt 12 ]; then
                    log_warn "異常な日付フォルダ: $dir_name (月日ともに12を超えています)"
                    continue
                fi
                
                # フォルダが既に存在するか確認
                if [ -d "${parent_dir}/${correct_dir_name}" ]; then
                    log_warn "修正先フォルダが既に存在します: ${parent_dir}/${correct_dir_name}"
                    
                    # 既存フォルダにファイルを移動
                    for file in "${dir}"/*; do
                        if [ -f "$file" ]; then
                            mv "$file" "${parent_dir}/${correct_dir_name}/"
                            log_info "ファイルを移動しました: $file → ${parent_dir}/${correct_dir_name}/"
                        fi
                    done
                    
                    # 空のフォルダを削除
                    rmdir "$dir"
                    log_info "空フォルダを削除しました: $dir"
                else
                    # フォルダ名を修正
                    mv "$dir" "${parent_dir}/${correct_dir_name}"
                    log_info "フォルダ名を修正しました: $dir_name → $correct_dir_name"
                fi
            fi
        fi
    done
}

# メイン処理
main() {
    # Flow ディレクトリの存在確認
    if [ ! -d "Flow" ]; then
        log_error "Flow ディレクトリが存在しません"
        exit 1
    fi
    
    # 不正なフォルダ名の修正
    fix_folder
    
    log_info "日付フォルダの修正が完了しました"
}

# スクリプト実行
main 