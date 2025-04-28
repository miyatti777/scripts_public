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

# ディレクトリ存在確認
check_dir() {
    if [ ! -d "$1" ]; then
        log_error "ディレクトリが存在しません: $1"
        exit 1
    fi
}

# バックアップ作成
create_backup() {
    local backup_dir="backup_aipm_rename_$(date +%Y%m%d_%H%M%S)"
    
    log_info "バックアップを作成しています..."
    mkdir -p "$backup_dir"
    
    # Flow ディレクトリをバックアップ
    cp -r Flow "$backup_dir/"
    
    log_info "バックアップを作成しました: $backup_dir"
    echo "$backup_dir"
}

# aipmからkakakucomへの変更
convert_aipm_to_kakakucom() {
    local flow_type="$1"  # "Private" または "Public"
    local base_dir="Flow/$flow_type"
    local count=0
    
    log_info "$flow_type ディレクトリ内のaipmフォルダを処理中..."
    
    # 日付フォルダをリストアップ
    for date_dir in "$base_dir"/*; do
        if [ -d "$date_dir" ] && [[ $(basename "$date_dir") =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            local date_folder=$(basename "$date_dir")
            local aipm_dir="$date_dir/aipm"
            
            # aipmフォルダが存在する場合
            if [ -d "$aipm_dir" ]; then
                log_info "変換中: $aipm_dir → $date_dir/kakakucom"
                
                # kakakucomフォルダが既に存在するか確認
                if [ -d "$date_dir/kakakucom" ]; then
                    # 既存のkakakucomフォルダがある場合、ファイルを移動
                    for file in "$aipm_dir"/*; do
                        if [ -f "$file" ]; then
                            mv "$file" "$date_dir/kakakucom/"
                            count=$((count + 1))
                        fi
                    done
                    # 空になったaipmフォルダを削除
                    rmdir "$aipm_dir" 2>/dev/null
                else
                    # kakakucomフォルダがない場合は、単純にリネーム
                    mv "$aipm_dir" "$date_dir/kakakucom"
                    count=$((count + 1))
                fi
            fi
        fi
    done
    
    log_info "$flow_type ディレクトリ内で $count 件の変更を行いました"
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
    convert_aipm_to_kakakucom "Private"
    convert_aipm_to_kakakucom "Public"
    
    log_info "aipmからkakakucomへの変換が完了しました"
    log_warn "問題があれば次のコマンドでバックアップから復元できます: cp -r $backup_dir/Flow ."
}

# スクリプト実行
main 