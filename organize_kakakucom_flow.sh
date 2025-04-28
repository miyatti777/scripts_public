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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# ディレクトリ存在確認
check_dir() {
    if [ ! -d "$1" ]; then
        log_error "ディレクトリが存在しません: $1"
        exit 1
    fi
}

# 日付フォルダ作成
create_date_folders() {
    local base_dir="$1"
    
    # プロジェクトディレクトリから日付を抽出し、対応するFlow内の日付フォルダを作成
    for dir in temp/kakakucom_*/ temp/Kakaku_*; do
        if [ -d "$dir" ]; then
            # ディレクトリ名から日付部分を抽出
            dir_name=$(basename "$dir")
            
            # 日付部分を抽出 (YYYYMMDD形式)
            date_part=""
            if [[ $dir_name =~ ([0-9]{8}) ]]; then
                date_part="${BASH_REMATCH[1]}"
            elif [[ $dir_name =~ ([0-9]{4})([0-9]{2})([0-9]{2}) ]]; then
                date_part="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
            elif [[ $dir_name =~ ([0-9]{6}) ]]; then
                date_part="2025${BASH_REMATCH[1]}"
            elif [[ $dir_name =~ ([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
                date_part="2025${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
            fi
            
            # 日付の形式変換 (YYYYMMDD → YYYY-MM-DD)
            if [ ! -z "$date_part" ]; then
                formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
                
                # 日付フォルダを作成
                mkdir -p "$base_dir/Private/$formatted_date"
                mkdir -p "$base_dir/Public/$formatted_date"
                
                log_info "日付フォルダを作成しました: $formatted_date"
            else
                log_warn "日付を抽出できませんでした: $dir_name"
            fi
        fi
    done
}

# ファイル移動処理
move_files() {
    local base_dir="$1"
    
    # 各プロジェクトディレクトリを処理
    for dir in temp/kakakucom_*/ temp/Kakaku_*; do
        if [ -d "$dir" ]; then
            dir_name=$(basename "$dir")
            
            # 日付部分を抽出して形式変換
            date_part=""
            if [[ $dir_name =~ ([0-9]{8}) ]]; then
                date_part="${BASH_REMATCH[1]}"
            elif [[ $dir_name =~ ([0-9]{4})([0-9]{2})([0-9]{2}) ]]; then
                date_part="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
            elif [[ $dir_name =~ ([0-9]{6}) ]]; then
                date_part="2025${BASH_REMATCH[1]}"
            elif [[ $dir_name =~ ([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
                date_part="2025${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
            fi
            
            if [ ! -z "$date_part" ]; then
                formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
                
                # ファイルをPublicとPrivateに振り分け
                for file in "$dir"/*; do
                    if [ -f "$file" ]; then
                        filename=$(basename "$file")
                        
                        # 会議関連ファイルはPublicへ、それ以外はPrivateへ
                        if [[ "$filename" =~ meeting|mtg|議事録|ミーティング ]]; then
                            # 会議ファイルはPublicへ
                            cp "$file" "$base_dir/Public/$formatted_date/"
                            log_info "会議ファイルをPublicへ移動: $filename → $base_dir/Public/$formatted_date/"
                        else
                            # その他のファイルはPrivateへ
                            cp "$file" "$base_dir/Private/$formatted_date/"
                            log_info "ファイルをPrivateへ移動: $filename → $base_dir/Private/$formatted_date/"
                        fi
                    fi
                done
            else
                log_warn "日付を抽出できませんでした: $dir_name - ファイルは移動されません"
            fi
        fi
    done
}

# メイン処理
main() {
    local base_dir="Flow"
    
    # ベースディレクトリの存在確認
    check_dir "$base_dir"
    
    # Flow/Private と Flow/Public ディレクトリの存在確認と作成
    if [ ! -d "$base_dir/Private" ]; then
        mkdir -p "$base_dir/Private"
        log_info "ディレクトリを作成しました: $base_dir/Private"
    fi
    
    if [ ! -d "$base_dir/Public" ]; then
        mkdir -p "$base_dir/Public"
        log_info "ディレクトリを作成しました: $base_dir/Public"
    fi
    
    # temp ディレクトリの存在確認
    check_dir "temp"
    
    # 日付フォルダの作成
    create_date_folders "$base_dir"
    
    # ファイルの移動
    move_files "$base_dir"
    
    log_info "kakakucomプロジェクトのファイル整理が完了しました"
}

# スクリプト実行
main 