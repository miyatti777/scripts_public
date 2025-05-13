#!/usr/bin/env python3
import json
import sys
import re
from datetime import datetime

def format_time(time_str):
    """ISO 8601 形式の時間文字列から時刻部分だけを抽出"""
    match = re.search(r'T(\d{2}:\d{2}):\d{2}', time_str)
    if match:
        return match.group(1)
    return time_str

def main():
    if len(sys.argv) != 2:
        print(f"使用法: {sys.argv[0]} <calendar_events.json>", file=sys.stderr)
        sys.exit(1)
    
    json_file = sys.argv[1]
    
    try:
        with open(json_file, 'r') as f:
            content = f.read()
            # "Running in dev mode." などのヘッダーを削除
            json_content = re.sub(r'^Running in dev mode\.', '', content, flags=re.MULTILINE).strip()
            data = json.loads(json_content)
    except Exception as e:
        print(f"エラー: JSONファイルの読み込みに失敗しました - {e}", file=sys.stderr)
        sys.exit(1)
    
    # 日付を取得 (ファイル名から推測するか、現在の日付を使用)
    today = datetime.now().strftime('%Y-%m-%d')
    match = re.search(r'(\d{4}-\d{2}-\d{2})', json_file)
    if match:
        today = match.group(1)
    
    # マークダウンヘッダーを出力
    print(f"# {today} カレンダー予定\n")
    print("## 本日の予定\n")
    
    # 予定がない場合
    if not data or len(data) == 0:
        print("予定はありません。")
        return
    
    # イベントをソート (開始時間順)
    sorted_events = sorted(data, key=lambda x: x.get('startTime', ''))
    
    # 各予定の出力
    for event in sorted_events:
        title = event.get('title', '(タイトルなし)')
        start_time = format_time(event.get('startTime', ''))
        end_time = format_time(event.get('endTime', ''))
        location = event.get('location', '')
        description = event.get('description', '')
        
        if event.get('allDay', False):
            print(f"### 終日: {title}")
        else:
            print(f"### {start_time}-{end_time} {title}")
        
        if location:
            print(f"**場所**: {location}")
        
        if description:
            # 説明文を1行1段落にフォーマット
            formatted_description = "\n".join([f"> {line}" for line in description.strip().split("\n") if line.strip()])
            if formatted_description:
                print(f"\n{formatted_description}\n")
        
        print()  # 予定間の空行

if __name__ == "__main__":
    main() 