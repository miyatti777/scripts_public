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

# バックアップ作成
create_backup() {
    local backup_dir="backup_flow_projects_$(date +%Y%m%d_%H%M%S)"
    
    log_info "バックアップを作成しています..."
    mkdir -p "$backup_dir"
    
    # Flow ディレクトリをバックアップ
    cp -r Flow "$backup_dir/"
    
    log_info "バックアップを作成しました: $backup_dir"
    echo "$backup_dir"
}

# プロジェクト検出ルール（ファイル名からプロジェクト名を判別）
detect_project() {
    local filename="$1"
    local file_content="$2"
    
    # ファイル名からプロジェクト判別
    if [[ "$filename" =~ kakaku|価格|カカク ]]; then
        echo "kakakucom"
        return
    elif [[ "$filename" =~ yaotti|ヤオッティ|バティスカフ ]]; then
        echo "bathyscaphe"
        return
    elif [[ "$filename" =~ tokyo_asset|東京アセット|不動産投資 ]]; then
        echo "tokyo_asset"
        return
    elif [[ "$filename" =~ AIPM|pmbok|PMBOK ]]; then
        echo "aipm"
        return
    fi
    
    # ファイル内容からプロジェクト判別（最初の10行を確認）
    if [[ -n "$file_content" ]]; then
        if [[ "$file_content" =~ kakaku|価格|カカク|価格コム ]]; then
            echo "kakakucom"
            return
        elif [[ "$file_content" =~ yaotti|ヤオッティ|バティスカフ ]]; then
            echo "bathyscaphe"
            return
        elif [[ "$file_content" =~ tokyo_asset|東京アセット|不動産投資 ]]; then
            echo "tokyo_asset"
            return
        elif [[ "$file_content" =~ AIPM|pmbok|PMBOK ]]; then
            echo "aipm"
            return
        fi
    fi
    
    # 判別できない場合はその他
    echo "other"
}

# プロジェクトフォルダ作成と整理
organize_flow_dir() {
    local flow_type="$1"  # "Private" または "Public"
    local base_dir="Flow/$flow_type"
    
    # 日付フォルダをリストアップ
    for date_dir in "$base_dir"/*; do
        if [ -d "$date_dir" ] && [[ $(basename "$date_dir") =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            local date_folder=$(basename "$date_dir")
            log_info "処理中: $date_dir"
            
            # 各ファイルを処理
            for file_path in "$date_dir"/*; do
                if [ -f "$file_path" ]; then
                    local filename=$(basename "$file_path")
                    
                    # ファイルの内容を取得（最初の10行）
                    local file_content=""
                    if [[ "$filename" =~ .md$ ]]; then
                        file_content=$(head -n 10 "$file_path" 2>/dev/null)
                    fi
                    
                    # プロジェクト名を検出
                    local project=$(detect_project "$filename" "$file_content")
                    
                    # プロジェクトフォルダを作成
                    mkdir -p "$date_dir/$project"
                    
                    # ファイルを移動
                    mv "$file_path" "$date_dir/$project/"
                    log_info "ファイルを整理: $filename → $flow_type/$date_folder/$project/"
                fi
            done
        fi
    done
}

# 空フォルダ削除
cleanup_empty_dirs() {
    # find コマンドで空のディレクトリを検索して削除
    log_info "空のディレクトリを削除しています..."
    find Flow -type d -empty -not -path "*/\.*" -delete 2>/dev/null
    log_info "空ディレクトリの削除が完了しました"
}

# メイン処理
main() {
    # Flow ディレクトリの存在確認
    check_dir "Flow"
    check_dir "Flow/Private"
    check_dir "Flow/Public"
    
    # バックアップ作成
    local backup_dir=$(create_backup)
    
    # Private と Public ディレクトリを処理
    organize_flow_dir "Private"
    organize_flow_dir "Public"
    
    # 空フォルダ削除
    cleanup_empty_dirs
    
    log_info "プロジェクト別整理が完了しました"
    log_warn "問題があれば次のコマンドでバックアップから復元できます: cp -r $backup_dir/Flow ."
}

# スクリプト実行
main 