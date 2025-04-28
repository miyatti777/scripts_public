#!/bin/bash

# trigger_flow_to_stock.sh
# AIアシスタントの「確定反映して」トリガーで実行するラッパースクリプト

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# メインスクリプトのパス
MAIN_SCRIPT="${SCRIPT_DIR}/flow_to_stock.sh"

# 実行権限を確認
if [ ! -x "$MAIN_SCRIPT" ]; then
  chmod +x "$MAIN_SCRIPT"
  echo "実行権限を付与しました: $MAIN_SCRIPT"
fi

# 引数を全てメインスクリプトに渡す
echo "Flow→Stock同期処理を開始します..."
"$MAIN_SCRIPT" "$@"

# 処理結果を通知
STATUS=$?
if [ $STATUS -eq 0 ]; then
  echo "処理が正常に完了しました"
else
  echo "エラーが発生しました（終了コード: $STATUS）"
fi

exit $STATUS 