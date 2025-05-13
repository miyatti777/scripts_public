#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
カレンダー予定と日次タスクのマージスクリプト

1. get_calendar_events.shを直接実行してカレンダー予定を取得
2. 日次タスクマークダウンファイルを読み込む
3. カレンダー予定を「今日の予定」セクションに挿入
4. マージした結果を日次タスクファイルに書き戻す
"""

import os
import json
import re
import sys
import subprocess
from datetime import datetime
from pathlib import Path


def get_root_dir():
    """
    環境変数またはデフォルト値からルートディレクトリを取得
    """
    # 環境変数 AIPM_ROOT が設定されていれば使用
    root_dir = os.environ.get('AIPM_ROOT')
    
    # 環境変数が設定されていない場合はデフォルトパスを使用
    if not root_dir:
        root_dir = os.path.expanduser("~/aipm_v3")
        print(f"環境変数 AIPM_ROOT が設定されていません。デフォルトパス {root_dir} を使用します。", file=sys.stderr)
    
    return root_dir


def get_todays_flow_dir(root_dir, date=None):
    """
    今日の日付のFlowディレクトリパスを取得
    """
    if date is None:
        date = datetime.now().date()
    
    # 日付文字列を作成
    date_str = date.strftime("%Y-%m-%d")
    yearmonth = date.strftime("%Y%m")
    
    # Flowディレクトリパスを生成
    flow_dir = os.path.join(root_dir, "Flow", yearmonth, date_str)
    
    return flow_dir, date_str


def execute_calendar_events_script(root_dir, flow_dir):
    """
    get_calendar_events.shスクリプトを実行してカレンダー予定を取得
    """
    script_path = os.path.join(root_dir, "scripts", "calendar_app", "get_calendar_events.sh")
    json_output_path = os.path.join(flow_dir, "calendar_events.json")
    
    # スクリプトの存在確認
    if not os.path.exists(script_path):
        print(f"カレンダー予定取得スクリプトが見つかりません: {script_path}", file=sys.stderr)
        return False
    
    try:
        # スクリプト実行前にFlowディレクトリが存在することを確認
        os.makedirs(flow_dir, exist_ok=True)
        
        # スクリプトを実行
        print(f"カレンダー予定取得スクリプトを実行中: {script_path}")
        result = subprocess.run(
            [script_path],
            capture_output=True,
            text=True,
            check=False
        )
        
        # 実行結果を確認
        if result.returncode != 0:
            print(f"カレンダー予定取得スクリプトの実行に失敗しました: {result.stderr}", file=sys.stderr)
            return False
        
        # JSONファイルが生成されたか確認
        if not os.path.exists(json_output_path):
            print(f"カレンダー予定JSONファイルが生成されませんでした: {json_output_path}", file=sys.stderr)
            return False
        
        return True
    except Exception as e:
        print(f"カレンダー予定取得スクリプト実行エラー: {e}", file=sys.stderr)
        return False


def get_calendar_events_direct(root_dir, flow_dir):
    """
    get_calendar_events.shを実行して直接カレンダーイベントを取得
    """
    script_path = os.path.join(root_dir, "scripts", "calendar_app", "get_calendar_events.sh")
    
    # スクリプトの存在確認
    if not os.path.exists(script_path):
        print(f"カレンダー予定取得スクリプトが見つかりません: {script_path}", file=sys.stderr)
        return None
    
    try:
        # スクリプト実行前にFlowディレクトリが存在することを確認
        os.makedirs(flow_dir, exist_ok=True)
        
        # スクリプトを実行
        print(f"カレンダー予定取得スクリプトを実行中: {script_path}")
        result = subprocess.run(
            [script_path],
            capture_output=True,
            text=True,
            check=False
        )
        
        # 実行結果を確認
        if result.returncode != 0:
            print(f"カレンダー予定取得スクリプトの実行に失敗しました: {result.stderr}", file=sys.stderr)
            return None
        
        output = result.stdout
        
        # スクリプトからの出力をパースしてカレンダーイベントを取得
        try:
            # 手動でカレンダーイベントを抽出
            events = extract_calendar_events_from_output(output)
            
            if events:
                # 取得したカレンダーデータを保存
                events_json_path = os.path.join(flow_dir, "calendar_events.json")
                with open(events_json_path, 'w', encoding='utf-8') as f:
                    json.dump(events, f, ensure_ascii=False, indent=2)
                
                return events
            else:
                print("カレンダーデータの抽出に失敗しました。")
                return None
        except Exception as e:
            print(f"カレンダーデータのパースに失敗しました: {e}", file=sys.stderr)
            print("カレンダー出力内容:", output)
            return None
    except Exception as e:
        print(f"カレンダー予定取得スクリプト実行エラー: {e}", file=sys.stderr)
        return None


def extract_calendar_events_from_output(output):
    """
    カレンダーイベント出力からイベントを抽出する
    """
    events = []
    
    # "Running in dev mode" などのデバッグ出力を除去
    output_lines = [line for line in output.split("\n") if not line.strip().startswith("Running")]
    output = "\n".join(output_lines)
    
    # 手動でイベントデータを抽出
    try:
        # カレンダー出力からタイトルと時間を正規表現で抽出
        title_pattern = r'title: [\'"](.+?)[\'"]'
        start_pattern = r'startTime: [\'"](.+?)[\'"]'
        end_pattern = r'endTime: [\'"](.+?)[\'"]'
        
        title_matches = re.findall(title_pattern, output)
        start_matches = re.findall(start_pattern, output)
        end_matches = re.findall(end_pattern, output)
        
        # 抽出成功
        if title_matches and len(title_matches) == len(start_matches):
            extracted_events = []
            for i in range(len(title_matches)):
                event = {
                    "title": title_matches[i],
                    "startTime": start_matches[i] if i < len(start_matches) else "",
                    "endTime": end_matches[i] if i < len(end_matches) else ""
                }
                extracted_events.append(event)
            
            if extracted_events:
                return extracted_events
        
        # 出力を行ごとに分割し、空行で区切られた各イベントを抽出
        event_blocks = re.split(r'\n\s*\n', output)
        for block in event_blocks:
            if 'title' in block and ('startTime' in block or 'start' in block):
                # タイトルを抽出
                title_match = re.search(r'title: [\'"](.+?)[\'"]', block)
                if title_match:
                    title = title_match.group(1)
                else:
                    continue
                
                # 開始時間を抽出 (異なる形式に対応)
                start_time = ""
                start_match = re.search(r'startTime: [\'"](.+?)[\'"]', block)
                if start_match:
                    start_time = start_match.group(1)
                else:
                    # 別の形式での開始時間
                    alt_start_match = re.search(r'start.*time.*[\'"](.+?)[\'"]', block, re.IGNORECASE)
                    if alt_start_match:
                        start_time = alt_start_match.group(1)
                
                # 終了時間を抽出
                end_time = ""
                end_match = re.search(r'endTime: [\'"](.+?)[\'"]', block)
                if end_match:
                    end_time = end_match.group(1)
                else:
                    # 別の形式での終了時間
                    alt_end_match = re.search(r'end.*time.*[\'"](.+?)[\'"]', block, re.IGNORECASE)
                    if alt_end_match:
                        end_time = alt_end_match.group(1)
                
                events.append({
                    "title": title,
                    "startTime": start_time,
                    "endTime": end_time
                })
        
        if events:
            return events
        else:
            print("エラー: カレンダー予定を抽出できませんでした。")
            print("calendar_appがインストールされているか確認してください。")
            print("インストール方法: npm install -g gcalcli")
            return []
    except Exception as e:
        print(f"カレンダー予定抽出エラー: {e}", file=sys.stderr)
        print("calendar_appがインストールされているか確認してください。")
        print("インストール方法: npm install -g gcalcli")
        return []


def read_calendar_events(flow_dir):
    """
    カレンダー予定JSONファイルを読み込む
    """
    calendar_file = os.path.join(flow_dir, "calendar_events.json")
    
    if not os.path.exists(calendar_file):
        print(f"カレンダー予定ファイルが見つかりません: {calendar_file}", file=sys.stderr)
        return []
    
    try:
        with open(calendar_file, 'r', encoding='utf-8') as f:
            content = f.read()
            # "Running in dev mode" などのデバッグ出力を除去
            content_lines = [line for line in content.split("\n") if not line.strip().startswith("Running")]
            content = "\n".join(content_lines)
            
            # JavaScriptオブジェクト形式をJSON形式に変換
            try:
                # 非標準のJSONを修正する（シングルクォート、末尾カンマ、プロパティ名のクォートなし）
                cleaned_content = content
                
                # 行ごとに処理
                lines = cleaned_content.split('\n')
                fixed_lines = []
                
                for line in lines:
                    # プロパティ名のクォートなしをダブルクォートに
                    line = re.sub(r'(\s*)([a-zA-Z0-9_]+)(\s*):(\s*)', r'\1"\2"\3:\4', line)
                    
                    # シングルクォートをダブルクォートに
                    line = line.replace("'", '"')
                    
                    # 末尾のカンマを修正
                    line = re.sub(r',(\s*)(\]|\})', r'\1\2', line)
                    
                    fixed_lines.append(line)
                
                cleaned_content = '\n'.join(fixed_lines)
                
                # 修正したJSONを解析
                events = json.loads(cleaned_content)
                return events
            except json.JSONDecodeError:
                # それでも失敗した場合は元のJSONを解析
                events = json.loads(content)
                return events
    except json.JSONDecodeError as e:
        print(f"カレンダー予定ファイルのJSON解析エラー: {e}", file=sys.stderr)
        # ファイルの内容を表示して調査
        try:
            with open(calendar_file, 'r', encoding='utf-8') as f:
                print(f"ファイル内容: {f.read()}", file=sys.stderr)
        except Exception:
            pass
        return []
    except Exception as e:
        print(f"カレンダー予定ファイル読み込みエラー: {e}", file=sys.stderr)
        return []


def read_daily_tasks(flow_dir):
    """
    日次タスクマークダウンファイルを読み込む
    """
    daily_tasks_file = os.path.join(flow_dir, "daily_tasks.md")
    
    if not os.path.exists(daily_tasks_file):
        print(f"日次タスクファイルが見つかりません: {daily_tasks_file}", file=sys.stderr)
        return None
    
    try:
        with open(daily_tasks_file, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        print(f"日次タスクファイル読み込みエラー: {e}", file=sys.stderr)
        return None


def format_calendar_events(events):
    """
    カレンダー予定を日次タスクのマークダウン形式にフォーマット
    """
    if not events:
        return "カレンダー予定はありません\n"
    
    formatted_events = []
    
    for event in events:
        # イベントから時間とタイトルを取得
        start_time = None
        end_time = None
        title = event.get('title', 'タイトルなし')
        
        # 時間情報の取得 (異なる形式に対応)
        if 'start' in event:
            if isinstance(event['start'], dict):
                start_time = event['start'].get('time', '')
            else:
                start_time = event.get('startTime', '')
        else:
            start_time = event.get('startTime', '')
        
        if 'end' in event:
            if isinstance(event['end'], dict):
                end_time = event['end'].get('time', '')
            else:
                end_time = event.get('endTime', '')
        else:
            end_time = event.get('endTime', '')
        
        # 時間の表示形式を調整（HH:MMまたは終日予定）
        time_str = ""
        if start_time:
            # 時間部分のみを抽出 (ISO 8601形式をHH:MM形式に)
            start_match = re.search(r'T(\d{2}:\d{2})', start_time)
            if start_match:
                time_str = start_match.group(1)
            else:
                time_str = start_time  # 元の形式をそのまま使用
            
            # 終了時間も同様に処理
            if end_time:
                end_match = re.search(r'T(\d{2}:\d{2})', end_time)
                if end_match:
                    time_str += f"-{end_match.group(1)}"
                else:
                    time_str += f"-{end_time}"
        else:
            time_str = "終日"
        
        formatted_events.append(f"- [ ] {time_str}: {title}")
    
    return "\n".join(formatted_events) + "\n"


def extract_existing_schedule_items(section_content):
    """
    既存の今日の予定セクションからタスク項目を抽出
    """
    if not section_content:
        return []
    
    # ヘッダー行を除外
    lines = section_content.strip().split('\n')[1:]
    
    # カレンダー予定の行を除外（タイムスタンプがHH:MM-HH:MM形式のものは通常カレンダー予定）
    task_lines = []
    for line in lines:
        # カレンダー予定パターンにマッチするか
        if re.search(r'- \[ \] \d{2}:\d{2}(-\d{2}:\d{2})?:', line):
            continue
        # 空行や「カレンダー予定はありません」のような行を除外
        if line.strip() and not "カレンダー予定はありません" in line:
            task_lines.append(line)
    
    return task_lines


def merge_calendar_to_tasks(daily_tasks_content, calendar_events_md):
    """
    日次タスク内の今日の予定セクションにカレンダー予定を挿入
    既存の日常タスクは保持し、カレンダー予定のみを更新
    """
    if not daily_tasks_content:
        print("日次タスクの内容が空です。マージを中止します。", file=sys.stderr)
        return None
    
    # 今日の予定セクションを見つける
    schedule_section_pattern = r'(## 📋 今日の予定\n)([^\n]*\n)*?(?=\n##|\Z)'
    schedule_section_match = re.search(schedule_section_pattern, daily_tasks_content)
    
    if not schedule_section_match:
        print("日次タスク内に「今日の予定」セクションが見つかりません。", file=sys.stderr)
        return daily_tasks_content
    
    # 既存のセクション内容
    existing_section = daily_tasks_content[schedule_section_match.start():schedule_section_match.end()]
    
    # 既存のスプリントタスクやルーチンタスクを抽出（カレンダー予定以外の項目）
    existing_tasks = extract_existing_schedule_items(existing_section)
    
    # 新しい予定セクションを作成
    new_schedule_section = "## 📋 今日の予定\n"
    
    # カレンダー予定が「カレンダー予定はありません」でない場合のみ追加
    if not "カレンダー予定はありません" in calendar_events_md:
        new_schedule_section += calendar_events_md
    
    # 既存のタスクも追加（空でない場合）
    if existing_tasks:
        new_schedule_section += "\n".join(existing_tasks) + "\n"
    
    # 旧セクションを新セクションに置き換え
    new_content = daily_tasks_content[:schedule_section_match.start()] + new_schedule_section + daily_tasks_content[schedule_section_match.end():]
    
    return new_content


def write_merged_tasks(flow_dir, content):
    """
    マージした日次タスクファイルを書き戻す
    """
    daily_tasks_file = os.path.join(flow_dir, "daily_tasks.md")
    
    try:
        with open(daily_tasks_file, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    except Exception as e:
        print(f"日次タスクファイル書き込みエラー: {e}", file=sys.stderr)
        return False


def main():
    # ルートディレクトリを取得
    root_dir = get_root_dir()
    
    # 今日の日付のFlowディレクトリを取得
    flow_dir, date_str = get_todays_flow_dir(root_dir)
    
    print(f"処理対象日: {date_str}")
    print(f"Flowディレクトリ: {flow_dir}")
    
    # 直接カレンダーイベントを取得
    events = get_calendar_events_direct(root_dir, flow_dir)
    
    # 直接取得に失敗した場合は既存のJSONファイルから読み込み
    if events is None:
        print("カレンダー予定の直接取得に失敗しました。既存のJSONファイルから読み込みます。")
        events = read_calendar_events(flow_dir)
    
    if events is None or len(events) == 0:
        print("エラー: カレンダー予定が取得できませんでした。")
        print("calendar_appがインストールされているか確認してください。")
        print("インストール方法: npm install -g gcalcli")
        return 1
    
    print(f"{len(events)}件のカレンダー予定を読み込みました。")
    
    # カレンダー予定をマークダウン形式に整形
    calendar_events_md = format_calendar_events(events)
    
    # 日次タスクを読み込み
    daily_tasks_content = read_daily_tasks(flow_dir)
    if not daily_tasks_content:
        print("日次タスクファイルが読み込めないため、マージをスキップします。")
        return 0  # 失敗をエラーとして扱わない
    
    # カレンダー予定と日次タスクをマージ
    merged_content = merge_calendar_to_tasks(daily_tasks_content, calendar_events_md)
    if not merged_content:
        print("マージに失敗しました。")
        return 0  # 失敗をエラーとして扱わない
    
    # マージした結果を書き戻し
    if write_merged_tasks(flow_dir, merged_content):
        print(f"✅ カレンダー予定を日次タスクにマージしました: {os.path.join(flow_dir, 'daily_tasks.md')}")
        return 0
    else:
        print("❌ マージした日次タスクの書き込みに失敗しました。")
        return 0  # 失敗をエラーとして扱わない


if __name__ == "__main__":
    sys.exit(main()) 