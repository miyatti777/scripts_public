#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
日次タスク生成スクリプト

1. extract_tasks.pyを実行してストーリーとタスクを抽出
2. 現在のスプリントに該当するストーリーをフィルタリング
3. 該当する頻度（日次/週次）のルーチンタスクをフィルタリング
4. 必要に応じてassigneeでフィルタリング
5. 日次タスクのマークダウンを生成
"""

import os
import sys
import json
import yaml
import argparse
import subprocess
import tempfile
from datetime import datetime, timedelta
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
        print(f"環境変数 AIPM_ROOT が設定されていません。デフォルトパス {root_dir} を使用します。")
    
    return root_dir


def load_user_config(root_dir):
    """
    ユーザー設定ファイルを読み込む
    """
    config_path = os.path.join(root_dir, "scripts", "config", "user_config.yaml")
    
    # デフォルト設定
    default_config = {
        "user_names": ["宮田", "miyatti"]
    }
    
    if not os.path.exists(config_path):
        print(f"警告: ユーザー設定ファイルが見つかりません: {config_path}")
        print(f"デフォルト設定を使用します: {default_config}")
        return default_config
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
            
        if not config or not isinstance(config, dict):
            print("警告: ユーザー設定ファイルが正しい形式ではありません。デフォルト設定を使用します。")
            return default_config
            
        # user_namesが存在するか確認
        if "user_names" not in config or not config["user_names"]:
            print("警告: user_namesが設定されていません。デフォルト設定を使用します。")
            return default_config
            
        return config
    except Exception as e:
        print(f"ユーザー設定ファイルの読み込み中にエラーが発生しました: {e}")
        print("デフォルト設定を使用します。")
        return default_config


def run_extract_tasks(root_dir, temp_output):
    """
    extract_tasks.pyを実行してストーリーとタスクを抽出
    """
    extract_script = os.path.join(root_dir, "scripts", "extract_tasks.py")
    
    if not os.path.exists(extract_script):
        print(f"Error: Extract tasks script not found at {extract_script}")
        return False
    
    try:
        cmd = [sys.executable, extract_script, "--format", "json", "--output", temp_output]
        print(f"Running command: {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False  # エラーが発生しても例外をスローしない
        )
        
        print(result.stdout)
        
        # エラーチェック
        if result.returncode != 0:
            print(f"Error: Extract tasks script failed with exit code {result.returncode}")
            if result.stderr:
                print(f"stderr: {result.stderr}")
            return False
            
        if result.stderr:
            print(f"Warning: {result.stderr}", file=sys.stderr)
        
        # 出力ファイルが存在するか確認
        if not os.path.exists(temp_output) or os.path.getsize(temp_output) == 0:
            print(f"Error: Output file is empty or does not exist: {temp_output}")
            return False
        
        return True
    except Exception as e:
        print(f"Error running extract_tasks.py: {e}")
        return False


def load_extracted_data(file_path):
    """
    抽出されたJSONデータを読み込む
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading extracted data: {e}")
        return []


def get_current_sprint(extracted_data):
    """
    現在アクティブなスプリントを特定
    
    バックログから全スプリント情報を取得し、日付に基づいて現在のスプリントを判断
    複数のスプリントが現在日付に該当する場合は全て返す
    """
    today = datetime.now().date()
    active_sprints = []
    
    # ストーリーからユニークなファイルパスを取得
    unique_files = set()
    for item in extracted_data:
        if 'file_path' in item and 'type' in item and item['type'] == 'story':
            unique_files.add(item['file_path'])
    
    # 各バックログファイルを解析してスプリント情報を取得
    sprints = []
    for file_path in unique_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = yaml.safe_load(f)
                if data and 'sprints' in data:
                    for sprint in data['sprints']:
                        if all(key in sprint for key in ['sprint_id', 'start_date', 'end_date']):
                            sprints.append(sprint)
        except Exception as e:
            print(f"Warning: Failed to read sprint data from {file_path}: {e}")
    
    # 現在日付がスプリント期間内のものを全て選択
    for sprint in sprints:
        try:
            start_date = datetime.strptime(sprint['start_date'], "%Y-%m-%d").date()
            end_date = datetime.strptime(sprint['end_date'], "%Y-%m-%d").date()
            
            if start_date <= today <= end_date:
                active_sprints.append(sprint['sprint_id'])
        except Exception as e:
            print(f"Warning: Failed to parse sprint dates: {e}")
    
    # 一致するスプリントがない場合、一番近い将来のスプリントを追加
    if not active_sprints:
        future_sprints = []
        for sprint in sprints:
            try:
                start_date = datetime.strptime(sprint['start_date'], "%Y-%m-%d").date()
                if start_date > today:
                    future_sprints.append((sprint['sprint_id'], (start_date - today).days))
            except Exception:
                pass
        
        if future_sprints:
            # 最も近い将来のスプリントを選択
            future_sprints.sort(key=lambda x: x[1])
            active_sprints.append(future_sprints[0][0])
    
    if active_sprints:
        # 重複を削除
        active_sprints = list(set(active_sprints))
        print(f"該当するスプリント: {', '.join(active_sprints)}")
    else:
        print("警告: 現在のスプリントが見つかりませんでした。")
    
    return active_sprints


def filter_current_sprint_stories(extracted_data, current_sprints):
    """
    現在のスプリントに割り当てられたストーリーをフィルタリング
    完了済み(status: completed)のストーリーは除外する
    重複するストーリーIDは除外する
    current_sprintsはスプリントIDのリスト
    """
    if not current_sprints:
        return []
    
    # リストでない場合はリストに変換（後方互換性のため）
    if not isinstance(current_sprints, list):
        current_sprints = [current_sprints]
    
    current_stories = []
    seen_story_ids = set()  # 既に処理したストーリーIDを追跡するセット
    
    for item in extracted_data:
        if item.get('type') == 'story':
            sprint_id = item.get('sprint_id') or item.get('sprint')
            status = item.get('status', '')
            if sprint_id and sprint_id in current_sprints and status != "completed":
                story_id = item.get('id')
                # 同じストーリーIDが既に処理されていない場合のみ追加
                if story_id and story_id not in seen_story_ids:
                    seen_story_ids.add(story_id)
                    current_stories.append(item)
    
    return current_stories


def filter_by_assignee(items, user_names):
    """
    ユーザー名に基づいてアイテム（ストーリーまたはルーチンタスク）をフィルタリング
    
    user_namesに含まれるassigneeが割り当てられたアイテムのみを返す
    user_namesが空の場合は全てのアイテムを返す
    """
    if not user_names:
        return items
    
    # ユーザー名を小文字に変換して比較する
    user_names_lower = [name.lower() for name in user_names]
    
    filtered_items = []
    for item in items:
        matched = False
        
        # 直接アイテムに設定されたassignee（ストーリーの場合）
        assignee = item.get('assignee', '')
        if assignee and (assignee.lower() in user_names_lower or any(name in assignee for name in user_names)):
            matched = True
        
        # ルーチンタスクの場合、routine.tasksのそれぞれのタスクにassigneeがある可能性
        if not matched and item.get('type') == 'routine_task':
            routine = item.get('routine', {})
            if 'tasks' in routine and isinstance(routine['tasks'], list):
                for task in routine['tasks']:
                    task_assignee = task.get('assignee', '')
                    if task_assignee and (task_assignee.lower() in user_names_lower or any(name in task_assignee for name in user_names)):
                        matched = True
                        break
        
        if matched:
            filtered_items.append(item)
    
    return filtered_items


def filter_stories_by_assignee(stories, user_names):
    """
    ユーザー名に基づいてストーリーをフィルタリング（後方互換性のため維持）
    """
    return filter_by_assignee(stories, user_names)


def filter_routine_tasks(extracted_data, today_date=None):
    """
    今日実行すべきルーチンタスクをフィルタリング
    """
    if today_date is None:
        today_date = datetime.now().date()
    
    weekday = today_date.weekday()  # 0=月曜, 1=火曜, ..., 6=日曜
    weekday_names = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    today_weekday = weekday_names[weekday]
    
    today_tasks = []
    
    for item in extracted_data:
        # ルーチンタスクを抽出
        if item.get('type') == 'routine_task':
            routine = item.get('routine', {})
            frequency = routine.get('frequency', '').lower()
            day_of_week = routine.get('day_of_week', '').lower()
            day_of_month = routine.get('day_of_month')
            
            # 日次タスク
            if frequency == 'daily':
                today_tasks.append(item)
            # 週次タスク（指定された曜日）
            elif frequency == 'weekly' and day_of_week == today_weekday:
                today_tasks.append(item)
            # 月次タスク（指定された日付）
            elif frequency == 'monthly' and day_of_month and str(day_of_month) == str(today_date.day):
                today_tasks.append(item)
    
    return today_tasks


def generate_daily_tasks_markdown(sprint_stories, routine_tasks, output_file, today_date=None):
    """
    日次タスクのマークダウンを生成
    """
    if today_date is None:
        today_date = datetime.now().date()
    
    date_str = today_date.strftime("%Y-%m-%d")
    weekday = today_date.weekday()
    is_monday = weekday == 0
    is_friday = weekday == 4
    
    # スプリントタスクセクション（プロジェクト・エピック別に階層化）
    sprint_section = ""
    if sprint_stories:
        sprint_section = "## 🎯 スプリントタスク\n\n"
        
        # プロジェクト別にストーリーをグループ化
        projects = {}
        for story in sprint_stories:
            project_name = story.get('project', 'その他のプロジェクト')
            epic_name = story.get('epic_name', 'その他のエピック')
            
            if project_name not in projects:
                projects[project_name] = {}
            
            if epic_name not in projects[project_name]:
                projects[project_name][epic_name] = []
            
            projects[project_name][epic_name].append(story)
        
        # プロジェクト・エピック別にマークダウンを生成
        for project_name, epics in projects.items():
            sprint_section += f"### {project_name}\n"
            
            for epic_name, stories in epics.items():
                sprint_section += f"#### {epic_name}\n"
                
                for story in stories:
                    story_id = story.get('id', 'Unknown')
                    story_title = story.get('title', 'Untitled Story')
                    sprint_section += f"- [ ] {story_id}: {story_title}\n"
                
                sprint_section += "\n"
            
            sprint_section += "\n"
    
    # ルーチンタスクセクション
    routine_tasks_md = ""
    if routine_tasks:
        for task in routine_tasks:
            task_title = task.get('title', 'Untitled Task')
            routine_info = task.get('routine', {})
            frequency = routine_info.get('frequency', '').capitalize()
            routine_tasks_md += f"- [ ] [{frequency}] {task_title}\n"
    else:
        routine_tasks_md = "- [ ] デイリータスクの確認\n"
    
    # 曜日特有のタスクセクション
    special_day_section = ""
    if is_monday:
        special_day_section = """## 🚀 週初めのタスク


"""
    elif is_friday:
        special_day_section = """## 📊 週末のタスク


"""
    
    # テンプレートの作成
    template = f"""# 日次タスク {date_str}

## 📋 今日の予定


{special_day_section}{sprint_section}## 🔄 ルーチンタスク
{routine_tasks_md}
## 📝 備考・メモ
- 

## 📈 今日の振り返り
- 達成したこと: 
- 障害/課題: 
- 明日のアクション: 
"""
    
    # ファイルに書き込み
    try:
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(template)
        
        print(f"日次タスクを作成しました: {output_file}")
        return True
    except Exception as e:
        print(f"ファイル書き込みエラー: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description='現在のスプリントとルーチンタスクに基づいた日次タスクを生成')
    parser.add_argument('--date', help='対象日付 (YYYY-MM-DD形式、デフォルト: 今日)')
    parser.add_argument('--output', '-o', help='出力ファイルパス (デフォルト: Flow/YYYY-MM-DD/daily_tasks.md)')
    parser.add_argument('--root', help='ルートディレクトリ (デフォルト: 環境変数 AIPM_ROOT または ~/aipm_v3)')
    parser.add_argument('--filter-assignee', action='store_true', help='自分のassigneeでフィルタリングする')
    parser.add_argument('--all-assignees', action='store_true', help='全てのassigneeを表示する (--filter-assigneeより優先)')
    args = parser.parse_args()
    
    # ルートディレクトリの取得
    root_dir = args.root if args.root else get_root_dir()
    
    # 日付の取得
    if args.date:
        try:
            today_date = datetime.strptime(args.date, "%Y-%m-%d").date()
        except ValueError:
            print(f"エラー: 無効な日付形式です。YYYY-MM-DD形式で指定してください: {args.date}")
            return 1
    else:
        today_date = datetime.now().date()
    
    date_str = today_date.strftime("%Y-%m-%d")
    
    # 出力ファイルパスの決定
    if args.output:
        output_file = args.output
    else:
        # 年月フォルダを生成
        yearmonth = today_date.strftime("%Y%m")
        output_file = os.path.join(root_dir, "Flow", yearmonth, date_str, "daily_tasks.md")
    
    print(f"ルートディレクトリ: {root_dir}")
    print(f"対象日付: {date_str}")
    print(f"出力ファイル: {output_file}")
    
    # ユーザー設定の読み込み
    user_config = load_user_config(root_dir)
    user_names = user_config.get("user_names", [])
    
    # 一時ファイルを作成
    with tempfile.NamedTemporaryFile(suffix='.json', delete=False) as temp:
        temp_file = temp.name
    
    try:
        # extract_tasks.pyを実行
        print("ストーリーとタスクデータを抽出中...")
        if not run_extract_tasks(root_dir, temp_file):
            print("エラー: ストーリーとタスクの抽出に失敗しました。")
            return 1
        
        # 抽出データを読み込み
        extracted_data = load_extracted_data(temp_file)
        if not extracted_data:
            print("エラー: 抽出データが空か、読み込みに失敗しました。")
            return 1
        
        # 現在のスプリントを特定
        current_sprints = get_current_sprint(extracted_data)
        if current_sprints:
            print(f"現在のスプリント: {', '.join(current_sprints)}")
        else:
            print("警告: 現在のスプリントが見つかりませんでした。")
        
        # 現在のスプリントのストーリーをフィルタリング
        sprint_stories = filter_current_sprint_stories(extracted_data, current_sprints)
        print(f"{len(sprint_stories)} 件のスプリントストーリーが見つかりました。")
        
        # ルーチンタスクをフィルタリング
        routine_tasks = filter_routine_tasks(extracted_data, today_date)
        print(f"{len(routine_tasks)} 件のルーチンタスクが見つかりました。")
        
        # assigneeでフィルタリング
        if args.filter_assignee and not args.all_assignees:
            if user_names:
                print(f"assigneeフィルタを適用します: {', '.join(user_names)}")
                # ストーリーをフィルタリング
                filtered_stories = filter_stories_by_assignee(sprint_stories, user_names)
                print(f"{len(filtered_stories)} 件のストーリーが自分のassigneeとして見つかりました。")
                sprint_stories = filtered_stories
                
                # ルーチンタスクもフィルタリング
                filtered_routine_tasks = filter_by_assignee(routine_tasks, user_names)
                print(f"{len(filtered_routine_tasks)} 件のルーチンタスクが自分のassigneeとして見つかりました。")
                routine_tasks = filtered_routine_tasks
        
        # 日次タスクのマークダウンを生成
        success = generate_daily_tasks_markdown(sprint_stories, routine_tasks, output_file, today_date)
        
        if success:
            print(f"日次タスクを生成しました。カレンダー予定の統合を続行します...")
            return 0
        else:
            print("❌ 日次タスクの生成に失敗しました。")
            return 1
    
    finally:
        # 一時ファイルを削除
        try:
            os.unlink(temp_file)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main()) 