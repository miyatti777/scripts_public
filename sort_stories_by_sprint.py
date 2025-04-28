#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import shutil
from pathlib import Path
import yaml

# パス設定
workspace = Path("/Users/daisukemiyata/aipm_v3")
stories_dir = workspace / "Stock/projects/tokyo_asset/documents/3_planning/backlog/stories"
target_base_dir = workspace / "Stock/projects/tokyo_asset/documents/4_executing/sprint_stories"

# roadmapからスプリント情報を取得
roadmap_file = workspace / "Stock/projects/tokyo_asset/documents/3_planning/release_roadmap.md"

def extract_yaml_from_markdown(file_path):
    """Markdownファイルから最初のYAMLブロックを抽出する"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # YAMLブロックを検索（```yaml と ``` の間）
    yaml_match = re.search(r'```yaml\s+(.*?)\s+```', content, re.DOTALL)
    if yaml_match:
        return yaml_match.group(1)
    return None

def get_sprint_stories_mapping():
    """リリースロードマップからスプリントごとのストーリーIDマッピングを取得"""
    yaml_content = extract_yaml_from_markdown(roadmap_file)
    if not yaml_content:
        print("リリースロードマップからYAMLブロックを抽出できませんでした")
        return {}
    
    # YAMLをパース
    try:
        roadmap_data = yaml.safe_load(yaml_content)
        sprint_stories = {}
        
        for sprint in roadmap_data.get('sprints', []):
            sprint_num = sprint.get('number')
            backlog_items = [item.get('id') for item in sprint.get('backlog_items', [])]
            
            # スプリント番号をキー、ストーリーIDのリストを値とする辞書を作成
            sprint_stories[sprint_num] = backlog_items
            
        return sprint_stories
    except Exception as e:
        print(f"YAMLのパースエラー: {e}")
        return {}

def get_story_id_from_filename(filename):
    """ファイル名からストーリーIDを抽出する"""
    # 正規表現でファイル名の先頭からストーリーIDを抽出（例: C-01, A-04, PB-001など）
    match = re.match(r'([A-Z]+-\d+)_.*', filename)
    if match:
        return match.group(1)
    return None

def setup_target_directories():
    """出力先ディレクトリ構造をセットアップする"""
    # 既存のディレクトリがあれば削除
    if target_base_dir.exists():
        shutil.rmtree(target_base_dir)
    
    # ベースディレクトリを作成
    target_base_dir.mkdir(parents=True, exist_ok=True)
    
    # スプリントごとのディレクトリを作成
    for sprint_num in range(1, 8):  # Sprint 1-7
        sprint_dir = target_base_dir / f"sprint_{sprint_num}"
        sprint_dir.mkdir(exist_ok=True)
    
    # 未割り当てストーリー用のディレクトリ
    other_dir = target_base_dir / "other"
    other_dir.mkdir(exist_ok=True)

def main():
    # スプリントごとのストーリーマッピングを取得
    sprint_stories = get_sprint_stories_mapping()
    if not sprint_stories:
        print("スプリント情報が取得できませんでした。処理を中止します。")
        return
    
    # 出力先ディレクトリ構造をセットアップ
    setup_target_directories()
    
    # ストーリーID -> スプリント番号の逆マッピングを作成
    story_to_sprint = {}
    for sprint_num, stories in sprint_stories.items():
        for story_id in stories:
            story_to_sprint[story_id] = sprint_num
    
    # 各ストーリーファイルを処理
    unassigned_stories = []
    assigned_count = 0
    
    print("ストーリーファイルの処理を開始します...")
    
    for story_file in stories_dir.glob("*.md"):
        story_id = get_story_id_from_filename(story_file.name)
        if not story_id:
            print(f"  警告: ファイル {story_file.name} からストーリーIDを抽出できませんでした")
            unassigned_stories.append(story_file)
            continue
        
        # ストーリーIDに対応するスプリントを検索
        sprint_num = story_to_sprint.get(story_id)
        
        if sprint_num:
            # スプリントが特定できた場合、対応するフォルダにシンボリックリンクを作成
            target_dir = target_base_dir / f"sprint_{sprint_num}"
            symlink_path = target_dir / story_file.name
            
            # 絶対パスでシンボリックリンクを作成
            os.symlink(story_file.absolute(), symlink_path)
            print(f"  {story_id} -> Sprint {sprint_num} に割り当てました")
            assigned_count += 1
        else:
            # スプリントが特定できない場合は other フォルダに配置
            unassigned_stories.append(story_file)
    
    # 未割り当てストーリーを other フォルダに配置
    other_dir = target_base_dir / "other"
    for story_file in unassigned_stories:
        symlink_path = other_dir / story_file.name
        os.symlink(story_file.absolute(), symlink_path)
        print(f"  {story_file.name} -> other フォルダに配置しました")
    
    print("\n処理完了:")
    print(f"  {assigned_count} 件のストーリーをスプリントフォルダに割り当てました")
    print(f"  {len(unassigned_stories)} 件のストーリーを other フォルダに配置しました")

if __name__ == "__main__":
    main() 