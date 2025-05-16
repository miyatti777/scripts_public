#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
ストーリーとタスク抽出スクリプト
バックログYAML（backlog.yaml）とルーチンYAML（routines.yaml）から
すべてのストーリーとタスクを抽出します。
"""

import os
import sys
import yaml
import json
import argparse
import glob
from datetime import datetime
from pathlib import Path


def get_root_dir():
    """
    環境変数またはデフォルト値からルートディレクトリを取得
    """
    # 環境変数 AIPM_ROOT が設定されていれば使用
    root_dir = os.environ.get('AIPM_ROOT')
    
    # 環境変数が設定されていない場合は引数で渡されたパスを使用
    if not root_dir:
        # デフォルトパスを使用
        root_dir = os.path.expanduser("~/aipm_v3")
        print(f"環境変数 AIPM_ROOT が設定されていません。デフォルトパス {root_dir} を使用します。")
    
    return root_dir


def find_yaml_files(root_dir, file_pattern):
    """
    指定されたディレクトリ以下から特定のYAMLファイルを再帰的に検索
    """
    yaml_files = []
    
    # Stockディレクトリ以下を検索
    stock_dir = os.path.join(root_dir, "Stock")
    
    print(f"検索ディレクトリ: {stock_dir}")
    print(f"検索パターン: {file_pattern}")
    
    if os.path.exists(stock_dir):
        # backlog.yamlとbacklog.ymlの両方に対応
        if file_pattern == "backlog.ya?ml":
            pattern1 = os.path.join(stock_dir, "**", "backlog.yaml")
            pattern2 = os.path.join(stock_dir, "**", "backlog.yml")
            yaml_files.extend(glob.glob(pattern1, recursive=True))
            yaml_files.extend(glob.glob(pattern2, recursive=True))
            print(f"バックログファイル検索パターン: {pattern1}, {pattern2}")
        # routines.yamlとroutines.ymlの両方に対応
        elif file_pattern == "routines.ya?ml":
            pattern1 = os.path.join(stock_dir, "**", "routines.yaml")
            pattern2 = os.path.join(stock_dir, "**", "routines.yml")
            yaml_files.extend(glob.glob(pattern1, recursive=True))
            yaml_files.extend(glob.glob(pattern2, recursive=True))
            print(f"ルーチンファイル検索パターン: {pattern1}, {pattern2}")
        else:
            # その他のYAMLファイル
            pattern = os.path.join(stock_dir, "**", file_pattern)
            yaml_files.extend(glob.glob(pattern, recursive=True))
            print(f"その他のファイル検索パターン: {pattern}")
    
    print(f"見つかったファイル数: {len(yaml_files)}")
    for file in yaml_files:
        print(f"  - {file}")
    
    return yaml_files


def load_yaml_file(file_path):
    """
    YAMLファイルを読み込む
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    except Exception as e:
        print(f"エラー: {file_path} の読み込み中にエラーが発生しました: {e}")
        return None


def extract_project_info(file_path):
    """
    ファイルパスからプログラム名とプロジェクト名を抽出
    想定パス構造: .../Stock/programs/[プログラム名]/projects/[プロジェクト名]/...
    """
    path_parts = Path(file_path).parts
    
    program_name = "Unknown Program"
    project_name = "Unknown Project"
    
    # パスを逆順に検索して、プログラム名とプロジェクト名を見つける
    for i, part in enumerate(path_parts):
        if part == "programs" and i + 1 < len(path_parts):
            program_name = path_parts[i + 1]
        if part == "projects" and i + 1 < len(path_parts):
            project_name = path_parts[i + 1]
    
    return program_name, project_name


def extract_stories_from_backlog(backlog_files):
    """
    backlog.yamlからストーリーを抽出
    """
    all_stories = []
    
    for file_path in backlog_files:
        try:
            data = load_yaml_file(file_path)
            if not data:
                continue
                
            # プログラム情報とプロジェクト情報を正しく取得
            program_name, project_name = extract_project_info(file_path)
            
            # エピックとストーリーを抽出
            epics = data.get('epics', [])
            
            for epic in epics:
                epic_id = epic.get('epic_id', '')
                epic_name = epic.get('title', 'Unknown Epic')  # 'name'ではなく'title'を使用
                stories = epic.get('stories', [])
                
                for story in stories:
                    story_info = {
                        'type': 'story',
                        'file_path': file_path,
                        'program': program_name,
                        'project': project_name,
                        'epic_id': epic_id,
                        'epic_name': epic_name,
                        'id': story.get('story_id', ''),
                        'title': story.get('title', 'Unknown Story'),
                        'description': story.get('description', ''),
                        'acceptance_criteria': story.get('acceptance_criteria', ''),
                        'priority': story.get('priority', ''),
                        'status': story.get('status', ''),
                        'sprint_id': story.get('sprint_id', ''),
                        'sprint': story.get('sprint', ''),
                        'estimate': story.get('estimate', ''),
                        'assignee': story.get('assignee', ''),
                        'labels': ','.join(story.get('labels', [])),
                        'dependencies': ','.join(story.get('dependencies', []))
                    }
                    all_stories.append(story_info)
                    
        except Exception as e:
            print(f"エラー: {file_path} の処理中にエラーが発生しました: {e}")
    
    return all_stories


def extract_routine_tasks(file_path):
    """
    指定されたルーチンファイルからタスクを抽出
    """
    print(f"\n解析開始: {file_path}")
    
    # ファイルパスが文字列かどうかチェック
    if not isinstance(file_path, str):
        print(f"Error: file_path must be a string, got {type(file_path)}")
        return []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            print(f"ファイル読み込み成功: {file_path}")
            file_content = file.read()
            print("ファイル内容の先頭部分:")
            print("-" * 40)
            print(file_content[:500] + "..." if len(file_content) > 500 else file_content)
            print("-" * 40)
            
            try:
                data = yaml.safe_load(file_content)
                print(f"YAML解析成功。ルートキー: {list(data.keys()) if data else 'なし'}")
            except yaml.YAMLError as e:
                print(f"Error: Invalid YAML format in {file_path}: {str(e)}")
                return []
    except Exception as e:
        print(f"Error: Failed to read {file_path}: {str(e)}")
        return []
    
    if not data or not isinstance(data, dict):
        print(f"エラー: 有効なYAMLデータがありません: {file_path}")
        return []
    
    tasks = []
    
    # プログラム/プロジェクト情報を取得
    program_id = data.get('project', {}).get('id', 'unknown') if isinstance(data.get('project'), dict) else data.get('program', 'unknown')
    project_name = data.get('project', {}).get('name', 'Unknown Project') if isinstance(data.get('project'), dict) else 'Unknown Project'
    
    print(f"プロジェクト情報: program_id={program_id}, project_name={project_name}")
    
    # ルーチン定義を取得 (2つの異なる形式に対応)
    routines = []
    if 'routines' in data and isinstance(data['routines'], list):
        print("標準ルーチン形式を検出: 'routines' キーがリスト")
        routines = data['routines']
    elif 'morning_routines' in data and isinstance(data['morning_routines'], dict) and 'items' in data['morning_routines']:
        print("代替ルーチン形式を検出: 'morning_routines.items' キー")
        # 朝のルーチンをルーチンリストに変換
        routine = {
            'id': 'morning',
            'title': data['morning_routines'].get('name', 'Morning Routine'),
            'frequency': 'daily',
            'tasks': data['morning_routines'].get('items', [])
        }
        routines = [routine]
    
    print(f"検出されたルーチン数: {len(routines)}")
    
    # 各ルーチンからタスクを抽出
    for routine in routines:
        routine_id = routine.get('id', 'unknown')
        routine_title = routine.get('title', 'Untitled Routine')
        frequency = routine.get('frequency', 'unknown')
        day_of_week = routine.get('day_of_week', '')
        day_of_month = routine.get('day_of_month', '')
        
        print(f"ルーチン処理中: id={routine_id}, title={routine_title}, frequency={frequency}")
        
        # タスクリストを取得 (異なる形式に対応)
        routine_tasks = []
        if 'tasks' in routine and isinstance(routine['tasks'], list):
            routine_tasks = routine['tasks']
        else:
            # タスクが直接ルーチンの配下にある場合
            routine_tasks = [routine]
        
        for task in routine_tasks:
            task_title = task.get('title', 'Untitled Task')
            description = task.get('description', '')
            priority = task.get('priority', 'medium')
            estimate = task.get('estimate', 0)
            assignee = task.get('assignee', '')  # タスクに設定されたassigneeを取得
            
            print(f"  タスク追加: {task_title}")
            if assignee:
                print(f"    Assignee: {assignee}")
            
            # タスク情報を追加
            tasks.append({
                'type': 'routine_task',
                'id': f"{routine_id}",
                'title': task_title,
                'description': description,
                'priority': priority,
                'estimate': estimate,
                'assignee': assignee,  # assigneeフィールドを追加
                'program_id': program_id,
                'project_name': project_name,
                'file_path': file_path,
                'routine': {
                    'id': routine_id,
                    'title': routine_title,
                    'frequency': frequency,
                    'day_of_week': day_of_week,
                    'day_of_month': day_of_month,
                    'tasks': routine_tasks  # タスク配列全体も含めておく
                }
            })
    
    print(f"抽出されたタスク数: {len(tasks)}")
    return tasks


def extract_tasks_from_routines(routines_files):
    """
    すべてのルーチンファイルからタスクを抽出
    """
    all_tasks = []
    
    for file_path in routines_files:
        try:
            print(f"Extracting routine tasks from: {file_path}")
            routine_tasks = extract_routine_tasks(file_path)
            if routine_tasks:
                print(f"Found {len(routine_tasks)} routine tasks in {file_path}")
                all_tasks.extend(routine_tasks)
            else:
                print(f"No routine tasks found in {file_path}")
        except Exception as e:
            print(f"Error extracting tasks from {file_path}: {e}")
    
    return all_tasks


def save_to_json(data, output_file):
    """
    データをJSON形式で保存
    """
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"データを {output_file} に保存しました。")
    except Exception as e:
        print(f"エラー: {output_file} への保存中にエラーが発生しました: {e}")


def save_to_csv(data, output_file):
    """
    データをCSV形式で保存
    """
    if not data:
        print("保存するデータがありません。")
        return
        
    try:
        import csv
        
        # 最初のデータから列名を取得
        fieldnames = list(data[0].keys())
        
        with open(output_file, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for item in data:
                writer.writerow(item)
        
        print(f"データを {output_file} に保存しました。")
    except Exception as e:
        print(f"エラー: {output_file} への保存中にエラーが発生しました: {e}")


def main():
    parser = argparse.ArgumentParser(description='バックログとルーチンからタスクを抽出するスクリプト')
    parser.add_argument('--root', help='プロジェクトのルートディレクトリ')
    parser.add_argument('--format', choices=['json', 'csv'], default='json', help='出力形式 (json または csv)')
    parser.add_argument('--output', '-o', help='出力ファイルパス')
    args = parser.parse_args()
    
    # ルートディレクトリの取得
    root_dir = args.root if args.root else get_root_dir()
    print(f"ルートディレクトリ: {root_dir}")
    
    # 出力ファイルパスの決定
    output_file = args.output if args.output else f"./extracted_tasks_{datetime.now().strftime('%Y%m%d')}.{args.format}"
    print(f"出力ファイル: {output_file}")
    print(f"出力形式: {args.format}")
    
    # バックログファイルを検索
    backlog_files = find_yaml_files(root_dir, "backlog.ya?ml")
    print(f"{len(backlog_files)} 件のバックログファイルが見つかりました。")
    
    # ルーチンファイルを検索
    routines_files = find_yaml_files(root_dir, "routines.ya?ml")
    print(f"{len(routines_files)} 件のルーチンファイルが見つかりました。")
    
    # データを抽出
    stories = extract_stories_from_backlog(backlog_files)
    tasks = extract_tasks_from_routines(routines_files)
    
    print(f"{len(stories)} 件のストーリーが抽出されました。")
    print(f"{len(tasks)} 件のタスクが抽出されました。")
    
    # 結果を保存
    all_items = stories + tasks
    
    if args.format == 'json':
        save_to_json(all_items, output_file)
    else:
        save_to_csv(all_items, output_file)
    
    print(f"データを {output_file} に保存しました。")
    
    return 0


if __name__ == "__main__":
    main() 