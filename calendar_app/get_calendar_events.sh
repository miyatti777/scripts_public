#!/bin/bash
# カレンダー予定取得と表示のシンプル版スクリプト
# ルール定義から呼び出し用

TODAY=$(date +%Y-%m-%d)
YEAR_MONTH=$(date +%Y%m)

# 保存先ディレクトリ作成
mkdir -p "Flow/$YEAR_MONTH/$TODAY"

# カレンダーイベント取得
(cd scripts/calendar_app && clasp run getDateEvents -p '["'"$TODAY"'"]' > "../../Flow/$YEAR_MONTH/$TODAY/calendar_events.json")

# JSONファイルの内容を表示
cat "Flow/$YEAR_MONTH/$TODAY/calendar_events.json" | grep -v "Running in dev mode" 