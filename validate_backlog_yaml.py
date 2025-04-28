#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
バックログYAMLの形式を検証するスクリプト

使用方法:
python validate_backlog_yaml.py /path/to/backlog.yaml

引数:
- /path/to/backlog.yaml: 検証するバックログのYAMLファイルパス（必須）

出力:
- エラーがある場合: 検出された問題点と修正案を表示
- エラーがない場合: 「検証に成功しました」というメッセージを表示
"""

import os
import sys
import yaml
import json
from pprint import pprint
from collections import defaultdict

def load_yaml_file(yaml_file):
    """YAMLファイルを読み込む"""
    try:
        with open(yaml_file, 'r', encoding='utf-8') as f:
            try:
                data = yaml.safe_load(f)
                return data
            except yaml.YAMLError as e:
                print(f"エラー: YAMLの解析に失敗しました: {e}")
                sys.exit(1)
    except FileNotFoundError:
        print(f"エラー: ファイル '{yaml_file}' が見つかりません。")
        sys.exit(1)

def validate_backlog(backlog_data):
    """バックログYAMLが正しい形式かどうかを検証"""
    errors = []
    warnings = []
    repair_actions = []
    
    # 必須トップレベルフィールドのチェック
    required_top_fields = ['project_id', 'epics']
    for field in required_top_fields:
        if field not in backlog_data:
            errors.append(f"必須フィールド '{field}' がトップレベルに存在しません")
            
            if field == 'project_id':
                repair_actions.append("project_id: YOUR_PROJECT_ID を追加してください")
            elif field == 'epics':
                repair_actions.append("epics: [] を追加し、エピック情報を設定してください")
    
    # 推奨トップレベルフィールドのチェック
    recommended_top_fields = ['backlog_version', 'last_updated', 'created_by']
    for field in recommended_top_fields:
        if field not in backlog_data:
            warnings.append(f"推奨フィールド '{field}' がトップレベルに存在しません")
    
    # user_storiesが直接あるかチェック（修正が必要な旧形式の可能性）
    if 'user_stories' in backlog_data:
        errors.append("'user_stories' がトップレベルにあります。各ストーリーは対応するエピックの'stories'配列内に配置する必要があります")
        
        # 修正方法の提案
        repair_actions.append("1. 各エピックに 'stories: []' 配列を追加")
        repair_actions.append("2. 各ストーリーをepic_idに基づいて適切なエピックの配下に移動")
        repair_actions.append("3. ストーリーのIDフィールドを 'id' から 'story_id' に変更")
        repair_actions.append("4. 'estimate' を 'story_points' に、'assigned_to' を 'assignee' に変更")
    
    # epicsフィールドが存在する場合の検証
    if 'epics' in backlog_data:
        epics = backlog_data['epics']
        
        if not isinstance(epics, list):
            errors.append("'epics'はリスト形式である必要があります")
        else:
            for i, epic in enumerate(epics):
                # 各エピックを検証
                if not isinstance(epic, dict):
                    errors.append(f"エピック #{i+1} は辞書形式である必要があります")
                    continue
                
                # エピックの必須フィールドをチェック
                required_epic_fields = ['epic_id', 'title']
                for field in required_epic_fields:
                    if field not in epic:
                        errors.append(f"エピック #{i+1}: 必須フィールド '{field}' がありません")
                        
                        if field == 'epic_id' and 'id' in epic:
                            errors.append(f"エピック #{i+1}: 'id'ではなく'epic_id'を使用してください")
                            repair_actions.append(f"エピック #{i+1}: 'id' を 'epic_id' に変更")
                
                # エピックのstoriesフィールドをチェック
                if 'stories' not in epic:
                    errors.append(f"エピック #{i+1}: 'stories'配列がありません")
                    repair_actions.append(f"エピック #{i+1}: 'stories: []' を追加")
                elif not isinstance(epic['stories'], list):
                    errors.append(f"エピック #{i+1}: 'stories'はリスト形式である必要があります")
                else:
                    # 各ストーリーを検証
                    for j, story in enumerate(epic['stories']):
                        if not isinstance(story, dict):
                            errors.append(f"エピック #{i+1}, ストーリー #{j+1}: ストーリーは辞書形式である必要があります")
                            continue
                        
                        # ストーリーの必須フィールドをチェック
                        required_story_fields = ['story_id', 'title', 'description']
                        for field in required_story_fields:
                            if field not in story:
                                if field == 'story_id' and 'id' in story:
                                    errors.append(f"エピック #{i+1}, ストーリー #{j+1}: 'id'ではなく'story_id'を使用してください")
                                    repair_actions.append(f"エピック #{i+1}, ストーリー #{j+1}: 'id' を 'story_id' に変更")
                                else:
                                    errors.append(f"エピック #{i+1}, ストーリー #{j+1}: 必須フィールド '{field}' がありません")
                        
                        # ポイント表記をチェック
                        if 'estimate' in story and 'story_points' not in story:
                            errors.append(f"エピック #{i+1}, ストーリー #{j+1}: 'estimate'ではなく'story_points'を使用してください")
                            repair_actions.append(f"エピック #{i+1}, ストーリー #{j+1}: 'estimate' を 'story_points' に変更")
                        
                        # 担当者表記をチェック
                        if 'assigned_to' in story and 'assignee' not in story:
                            errors.append(f"エピック #{i+1}, ストーリー #{j+1}: 'assigned_to'ではなく'assignee'を使用してください")
                            repair_actions.append(f"エピック #{i+1}, ストーリー #{j+1}: 'assigned_to' を 'assignee' に変更")
    
    # エピックIDとストーリーIDの一貫性をチェック
    if 'epics' in backlog_data and isinstance(backlog_data['epics'], list):
        # エピックIDの重複チェック
        epic_ids = [epic.get('epic_id') for epic in backlog_data['epics'] if isinstance(epic, dict) and 'epic_id' in epic]
        duplicate_epic_ids = [id for id in set(epic_ids) if epic_ids.count(id) > 1]
        if duplicate_epic_ids:
            errors.append(f"重複するエピックID: {', '.join(duplicate_epic_ids)}")
        
        # ストーリーIDの重複チェック
        story_ids = []
        for epic in backlog_data['epics']:
            if isinstance(epic, dict) and 'stories' in epic and isinstance(epic['stories'], list):
                story_ids.extend([story.get('story_id') for story in epic['stories'] 
                                 if isinstance(story, dict) and 'story_id' in story])
        
        duplicate_story_ids = [id for id in set(story_ids) if story_ids.count(id) > 1]
        if duplicate_story_ids:
            errors.append(f"重複するストーリーID: {', '.join(duplicate_story_ids)}")
    
    # 疑似修正YAMLの生成（user_storiesがある場合）
    if 'user_stories' in backlog_data and 'epics' in backlog_data:
        try:
            # 修正YAML提案
            repaired_data = repair_backlog(backlog_data)
            if repaired_data:
                repair_actions.append("\n修正後のYAML例（最初の一部）:")
                
                # 修正したYAMLの最初の部分だけを文字列化
                repaired_yaml = yaml.dump(repaired_data, allow_unicode=True, sort_keys=False, default_flow_style=False)
                lines = repaired_yaml.split('\n')
                preview_lines = 30  # プレビューする行数
                if len(lines) > preview_lines:
                    repair_actions.append(yaml.dump({
                        'project_id': repaired_data.get('project_id', ''),
                        'backlog_version': repaired_data.get('backlog_version', ''),
                        'epics': repaired_data.get('epics', [])[:1]  # 最初のエピックだけ表示
                    }, allow_unicode=True, sort_keys=False, default_flow_style=False))
                    repair_actions.append("... (省略) ...")
                else:
                    repair_actions.append(repaired_yaml)
        except Exception as e:
            repair_actions.append(f"修正YAML生成中にエラー: {e}")
    
    return {
        'errors': errors,
        'warnings': warnings,
        'repair_actions': repair_actions,
        'is_valid': len(errors) == 0
    }

def repair_backlog(backlog_data):
    """問題のあるバックログYAMLを自動修正する試み"""
    if 'epics' not in backlog_data or 'user_stories' not in backlog_data:
        return None
    
    # コピーを作成して変更
    repaired = backlog_data.copy()
    
    # user_storiesをepic_idごとにグループ化
    stories_by_epic = defaultdict(list)
    for story in backlog_data.get('user_stories', []):
        if isinstance(story, dict) and 'epic_id' in story:
            # ストーリーのコピーを作成
            new_story = story.copy()
            
            # 'id'を'story_id'に変換
            if 'id' in new_story and 'story_id' not in new_story:
                new_story['story_id'] = new_story.pop('id')
            
            # 'estimate'を'story_points'に変換
            if 'estimate' in new_story and 'story_points' not in new_story:
                new_story['story_points'] = new_story.pop('estimate')
            
            # 'assigned_to'を'assignee'に変換
            if 'assigned_to' in new_story and 'assignee' not in new_story:
                new_story['assignee'] = new_story.pop('assigned_to')
            
            stories_by_epic[new_story['epic_id']].append(new_story)
    
    # 修正されたエピックのリストを作成
    repaired_epics = []
    for epic in repaired.get('epics', []):
        if isinstance(epic, dict):
            # エピックのコピーを作成
            new_epic = epic.copy()
            
            # 'id'を'epic_id'に変換
            if 'id' in new_epic and 'epic_id' not in new_epic:
                new_epic['epic_id'] = new_epic.pop('id')
            
            # このエピックに関連するストーリーを追加
            epic_id = new_epic.get('epic_id', '')
            if epic_id:
                new_epic['stories'] = stories_by_epic.get(epic_id, [])
            else:
                new_epic['stories'] = []
            
            repaired_epics.append(new_epic)
    
    # 修正されたエピックリストを設定
    repaired['epics'] = repaired_epics
    
    # user_storiesフィールドを削除
    if 'user_stories' in repaired:
        del repaired['user_stories']
    
    return repaired

def print_validation_results(results):
    """検証結果を表示"""
    if results['is_valid']:
        print("✅ 検証に成功しました！YAMLは想定フォーマットに準拠しています。")
        
        if results['warnings']:
            print("\n警告:")
            for warning in results['warnings']:
                print(f"⚠️ {warning}")
    else:
        print("❌ 検証に失敗しました。以下の問題が検出されました：\n")
        
        for error in results['errors']:
            print(f"❌ {error}")
        
        if results['warnings']:
            print("\n警告:")
            for warning in results['warnings']:
                print(f"⚠️ {warning}")
        
        if results['repair_actions']:
            print("\n修正案:")
            for action in results['repair_actions']:
                print(f"🔧 {action}")

def main():
    if len(sys.argv) < 2:
        print("使用方法: python validate_backlog_yaml.py /path/to/backlog.yaml")
        sys.exit(1)
    
    yaml_file = sys.argv[1]
    backlog_data = load_yaml_file(yaml_file)
    results = validate_backlog(backlog_data)
    print_validation_results(results)
    
    # 検証結果に基づいて終了コードを設定
    if not results['is_valid']:
        sys.exit(1)

if __name__ == "__main__":
    main() 