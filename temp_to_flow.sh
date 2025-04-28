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
    local backup_dir="backup_temp_migration_$(date +%Y%m%d_%H%M%S)"
    
    log_info "バックアップを作成しています..."
    mkdir -p "$backup_dir"
    
    # Temp ディレクトリをバックアップ
    cp -r /Users/daisukemiyata/aipm_v3/temp "$backup_dir/"
    
    log_info "バックアップを作成しました: $backup_dir"
    echo "$backup_dir"
}

# プロジェクト名を抽出
extract_project_name() {
    local folder_name="$1"
    
    if [[ "$folder_name" =~ "AIPM" || "$folder_name" =~ "aipm" ]]; then
        echo "kakakucom"  # AIPMはkakakucomに変換
    elif [[ "$folder_name" =~ "kakakucom" ]]; then
        echo "kakakucom"
    elif [[ "$folder_name" =~ "tokyo_asset" || "$folder_name" =~ "東京アセット" ]]; then
        echo "tokyo_asset"
    else
        echo "other"  # その他
    fi
}

# 日付を抽出
extract_date() {
    local folder_name="$1"
    local date_pattern="([0-9]{8})"
    
    if [[ "$folder_name" =~ $date_pattern ]]; then
        local raw_date="${BASH_REMATCH[1]}"
        # 形式変換: YYYYMMDD -> YYYY-MM-DD
        echo "${raw_date:0:4}-${raw_date:4:2}-${raw_date:6:2}"
    else
        # 日付がフォルダ名から抽出できない場合は本日の日付を使用
        date +%Y-%m-%d
    fi
}

# temp内のフォルダをFlowに移動
migrate_temp_folders() {
    local temp_dir="/Users/daisukemiyata/aipm_v3/temp"
    local flow_root="/Users/daisukemiyata/aipm_v3/Flow"
    local count=0
    
    # すべてのフォルダを処理
    for folder in "$temp_dir"/*; do
        if [ -d "$folder" ]; then
            local folder_name=$(basename "$folder")
            local project_name=$(extract_project_name "$folder_name")
            local folder_date=$(extract_date "$folder_name")
            
            # 処理内容をログ表示
            log_info "処理: $folder_name"
            log_info "  プロジェクト: $project_name"
            log_info "  日付: $folder_date"
            
            # すべてPrivateに入れる（必要に応じて条件付けでPublicにも可能）
            local target_dir="$flow_root/Private/$folder_date/$project_name"
            
            # 対象ディレクトリを作成
            mkdir -p "$target_dir"
            
            # ファイルをコピー
            for file in "$folder"/*; do
                if [ -f "$file" ]; then
                    cp "$file" "$target_dir/"
                    log_info "  コピー: $(basename "$file") -> $target_dir/"
                    count=$((count + 1))
                fi
            done
        fi
    done
    
    log_info "合計 $count 個のファイルを移動しました"
}

# メイン処理
main() {
    # ディレクトリ存在確認
    check_dir "/Users/daisukemiyata/aipm_v3/temp"
    check_dir "/Users/daisukemiyata/aipm_v3/Flow"
    check_dir "/Users/daisukemiyata/aipm_v3/Flow/Private"
    check_dir "/Users/daisukemiyata/aipm_v3/Flow/Public"
    
    # バックアップ作成
    local backup_dir=$(create_backup)
    
    # ファイル移動
    migrate_temp_folders
    
    log_info "tempからFlowへの移行が完了しました"
    log_warn "問題があれば次のコマンドでバックアップから復元できます: cp -r $backup_dir/temp /Users/daisukemiyata/aipm_v3/"
    log_info "元のtempディレクトリは手動で削除してください"
}

# スクリプト実行
main 