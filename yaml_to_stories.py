#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
YAMLバックログから個別のユーザーストーリーファイルとエピックファイルを生成するスクリプト

使用方法:
python yaml_to_stories.py /path/to/backlog.yaml [project_name] [/path/to/custom/output/directory]

引数:
- /path/to/backlog.yaml: バックログのYAMLファイルパス（必須）
- project_name: プロジェクト名（オプション、デフォルト: "default"）
- /path/to/custom/output/directory: カスタム出力ディレクトリ（オプション）

例:
- 基本: python yaml_to_stories.py backlog.yaml
  → Flow/Private/現在日付/default/backlog/ に出力
- プロジェクト指定: python yaml_to_stories.py backlog.yaml kakakucom
  → Flow/Private/現在日付/kakakucom/backlog/ に出力
- カスタム出力先: python yaml_to_stories.py backlog.yaml kakakucom /custom/path
  → /custom/path に出力

出力先を指定しない場合は Flow/Private/現在日付/{project_name}/backlog/ に出力します。
"""

import os
import sys
import yaml
import datetime
import re
from pathlib import Path

def load_yaml_backlog(yaml_file):
    """YAMLファイルからバックログデータを読み込む"""
    with open(yaml_file, 'r', encoding='utf-8') as f:
        try:
            backlog_data = yaml.safe_load(f)
            return backlog_data
        except yaml.YAMLError as e:
            print(f"YAMLファイルの解析エラー: {e}")
            sys.exit(1)

def create_stories_directory(output_dir):
    """ストーリー保存用ディレクトリを作成"""
    stories_dir = os.path.join(output_dir, 'stories')
    os.makedirs(stories_dir, exist_ok=True)
    return stories_dir

def sanitize_filename(title, max_length=30):
    """ファイル名として使える形式に文字列を整形"""
    # 不正な文字を削除または置換
    title = re.sub(r'[\\/*?:"<>|]', '', title)
    title = re.sub(r'[、。，．！？]', '_', title)
    
    # スペースをアンダースコアに変換
    title = title.replace(' ', '_')
    
    # 末尾の記号を削除
    title = re.sub(r'[_\-\.]+$', '', title)
    
    # 最大文字数に制限
    if len(title) > max_length:
        # 先頭からmax_length文字まで取得
        title = title[:max_length]
        # 末尾が途中で切れないように調整（日本語の場合）
        if len(title.encode('utf-8')) > len(title):  # 日本語を含む場合
            # 文字単位で切り詰める（バイト単位ではなく）
            title = title[:max_length]
    
    return title

def generate_story_file(story, epic_or_category, stories_dir, today_date=None, is_task=False):
    """ユーザーストーリーファイルを生成"""
    if today_date is None:
        today_date = datetime.date.today().strftime('%Y-%m-%d')
    
    # ストーリーIDまたはタスクID
    story_id = story.get('story_id' if not is_task else 'task_id', 'unknown')
    story_title = story.get('title', '')
    
    # ファイル名用にタイトルを整形
    short_title = sanitize_filename(story_title)
    
    # 受け入れ基準またはタスク説明
    if is_task:
        # タスクの場合は説明から受け入れ基準を生成
        description = story.get('description', '')
        acceptance_criteria = [description] if description else []
    else:
        # ストーリーの場合は通常の受け入れ基準を使用
        acceptance_criteria = story.get('acceptance_criteria', [])
        description = story.get('description', f"{story_title}に関する機能を実装します。")
    
    # ストーリーポイント
    story_points = story.get('story_points', 8)
    
    # 優先度
    if isinstance(epic_or_category, dict):
        default_priority = epic_or_category.get('priority', 'Medium')
    else:
        default_priority = 'Medium'
    priority = story.get('priority', default_priority)
    
    # 状態
    if isinstance(epic_or_category, dict):
        default_status = epic_or_category.get('status', 'Open')
    else:
        default_status = 'Open'
    status = story.get('status', default_status)
    
    # タスクかストーリーかで判別
    item_type = "タスク" if is_task else "ストーリー"
    epic_id = epic_or_category.get('epic_id', '') if isinstance(epic_or_category, dict) else ''
    category_name = epic_or_category if not isinstance(epic_or_category, dict) else ''
    
    # ファイルコンテンツの作成
    content = f"""# {story_id}: {story_title}

## 基本情報
- **{item_type}ID**: {story_id}
"""

    # エピックIDまたはカテゴリ名を付与
    if epic_id:
        content += f"- **エピックID**: {epic_id}\n"
    if category_name:
        content += f"- **カテゴリ**: {category_name}\n"

    content += f"""- **タイトル**: {story_title}
- **優先度**: {priority}
- **ストーリーポイント**: {story_points}
- **状態**: {status}
- **担当者**: {story.get('assignee', '')}
- **作成日**: {today_date}
- **更新日**: {today_date}

## 説明
{description}

"""

    # タスクでない場合のみユーザーストーリー形式を追加
    if not is_task:
        content += f"""## ユーザーストーリー
{story_title}
So that プロジェクトの目標達成に貢献します。

"""

    # 受け入れ基準またはタスク内容
    criteria_heading = "受け入れ基準" if not is_task else "タスク内容"
    content += f"## {criteria_heading}\n"
    
    # 受け入れ基準の追加
    for i, criterion in enumerate(acceptance_criteria, 1):
        content += f"{i}. {criterion}\n"
    
    # 技術的な詳細セクション
    content += "\n## 技術的な詳細\n"
    content += "- このストーリーの実装には以下の技術が必要です\n"
    
    # 備考セクション
    content += "\n## 備考\n"
    content += "- 実装時の注意点や関連事項\n"
    
    # ファイルへの書き込み
    file_path = os.path.join(stories_dir, f"{story_id}_{short_title}.md")
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return file_path

def generate_epics_yaml(backlog_data, output_dir):
    """エピック情報をYAMLファイルとして生成"""
    epics = backlog_data.get('epics', [])
    epics_list = []
    
    for epic in epics:
        epic_entry = {
            'epic_id': epic.get('epic_id', ''),
            'title': epic.get('title', ''),
            'priority': epic.get('priority', 'Medium'),
            'status': epic.get('status', 'open'),
            'story_count': len(epic.get('stories', [])),
            'completed_story_count': 0,
            'description': f"{epic.get('title', '')}に関する機能群"
        }
        epics_list.append(epic_entry)
    
    # エピックYAMLファイルの生成
    epics_file_path = os.path.join(output_dir, 'epics.yaml')
    with open(epics_file_path, 'w', encoding='utf-8') as f:
        f.write("# エピック一覧\n")
        yaml.dump(epics_list, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
    
    return epics_file_path

def process_backlog(backlog_data, output_dir, stories_dir):
    """バックログ全体を処理してストーリーファイルとエピックファイルを生成"""
    today_date = datetime.date.today().strftime('%Y-%m-%d')
    generated_files = []
    
    # エピックファイルの生成
    epics_file = generate_epics_yaml(backlog_data, output_dir)
    generated_files.append(epics_file)
    
    # ストーリーファイルの生成
    for epic in backlog_data.get('epics', []):
        for story in epic.get('stories', []):
            file_path = generate_story_file(story, epic, stories_dir, today_date, is_task=False)
            generated_files.append(file_path)
    
    # foundation_tasksの処理
    foundation_tasks = backlog_data.get('foundation_tasks', [])
    for task in foundation_tasks:
        file_path = generate_story_file(task, "基盤タスク", stories_dir, today_date, is_task=True)
        generated_files.append(file_path)
    
    # integration_tasksの処理
    integration_tasks = backlog_data.get('integration_tasks', [])
    for task in integration_tasks:
        file_path = generate_story_file(task, "統合タスク", stories_dir, today_date, is_task=True)
        generated_files.append(file_path)
    
    # future_tasksの処理
    future_tasks = backlog_data.get('future_tasks', [])
    for task in future_tasks:
        file_path = generate_story_file(task, "将来タスク", stories_dir, today_date, is_task=True)
        generated_files.append(file_path)
    
    return generated_files

def main():
    # コマンドライン引数のチェック
    if len(sys.argv) < 2:
        print("""使用方法:
python yaml_to_stories.py /path/to/backlog.yaml [/path/to/custom/output/directory]

例:
- 基本: python yaml_to_stories.py backlog.yaml
  → カレントディレクトリに出力
- カスタム出力先: python yaml_to_stories.py backlog.yaml /custom/path
  → /custom/path に出力""")
        sys.exit(1)
    
    yaml_file = sys.argv[1]
    today_date = datetime.date.today().strftime('%Y-%m-%d')
    
    # 出力先の決定
    output_dir = sys.argv[2] if len(sys.argv) >= 3 else os.path.dirname(yaml_file)
    
    # バックログファイル読み込み
    backlog_data = load_yaml_backlog(yaml_file)
    
    # 出力ディレクトリの作成
    os.makedirs(output_dir, exist_ok=True)
    stories_dir = create_stories_directory(output_dir)
    
    # ストーリーファイルとエピックファイルの生成
    generated_files = process_backlog(backlog_data, output_dir, stories_dir)
    
    print(f"変換完了！ {len(generated_files)}件のファイルを生成しました。")
    print(f"出力ディレクトリ: {output_dir}")
    print(f"エピックファイル: {os.path.join(output_dir, 'epics.yaml')}")
    print(f"ストーリーディレクトリ: {stories_dir}")

if __name__ == "__main__":
    main() 