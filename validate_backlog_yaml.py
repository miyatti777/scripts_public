#!/usr/bin/env python3
import sys
import yaml
import json
import re
from pathlib import Path
import datetime

def validate_backlog_yaml(file_path):
    """バックログYAMLファイルを検証する"""
    errors = []
    warnings = []
    
    # ファイルを読み込む
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            try:
                data = yaml.safe_load(file)
            except yaml.YAMLError as e:
                errors.append(f"YAMLフォーマットエラー: {str(e)}")
                return errors, warnings, None
    except Exception as e:
        errors.append(f"ファイル読み込みエラー: {str(e)}")
        return errors, warnings, None
    
    # データがない場合
    if not data:
        errors.append("空のYAMLファイルです")
        return errors, warnings, None
    
    # 基本構造の検証
    required_sections = ["project", "epics"]
    for section in required_sections:
        if section not in data:
            errors.append(f"必須セクション '{section}' がありません")
    
    # プロジェクト情報の検証
    if "project" in data:
        required_project_fields = ["id", "name", "description"]
        for field in required_project_fields:
            if field not in data["project"]:
                errors.append(f"project セクションに必須フィールド '{field}' がありません")
    
    # スプリント情報の検証
    sprints = {}
    if "sprints" in data:
        for i, sprint in enumerate(data["sprints"], 1):
            # スプリントIDの検証
            if "sprint_id" not in sprint:
                errors.append(f"sprint #{i} にスプリントID (sprint_id) がありません")
            else:
                sprint_id = sprint["sprint_id"]
                sprints[sprint_id] = sprint
                if not re.match(r'^S\d+$', sprint_id):
                    warnings.append(f"sprint #{i} の sprint_id '{sprint_id}' は推奨形式 'S数字' に準拠していません")
            
            # スプリント名の検証
            if "name" not in sprint:
                errors.append(f"sprint #{i} に名前 (name) がありません")
            
            # 日付の検証
            for date_field in ["start_date", "end_date"]:
                if date_field not in sprint:
                    errors.append(f"sprint #{i} に{date_field}がありません")
                else:
                    try:
                        datetime.datetime.strptime(sprint[date_field], "%Y-%m-%d")
                    except ValueError:
                        errors.append(f"sprint #{i} の {date_field} '{sprint[date_field]}' は有効な日付形式 (YYYY-MM-DD) ではありません")
            
            # スプリントゴールの検証
            if "goal" not in sprint:
                warnings.append(f"sprint #{i} にゴール (goal) がありません")
            
            # スプリントステータスの検証
            if "status" in sprint:
                status = sprint["status"]
                if status not in ["planned", "in_progress", "completed"]:
                    warnings.append(f"sprint #{i} の status '{status}' は planned, in_progress, completed のいずれかであるべきです")
            else:
                errors.append(f"sprint #{i} にステータス (status) がありません")
    
    # エピックの検証
    epic_count = 0
    story_count = 0
    
    if "epics" in data:
        for i, epic in enumerate(data["epics"], 1):
            # エピックIDの検証
            if "epic_id" not in epic:
                errors.append(f"epic #{i} にエピックID (epic_id) がありません")
            else:
                epic_id = epic["epic_id"]
                if not re.match(r'^EP-\d+$', epic_id):
                    warnings.append(f"epic #{i} の epic_id '{epic_id}' は推奨形式 'EP-XXX' に準拠していません")
            
            # エピックタイトルの検証
            if "title" not in epic:
                errors.append(f"epic #{i} にタイトル (title) がありません")
            
            # エピック優先度の検証
            if "priority" in epic:
                priority = epic["priority"]
                if priority not in ["high", "medium", "low"]:
                    warnings.append(f"epic #{i} の priority '{priority}' は 'high', 'medium', 'low' のいずれかであるべきです")
            else:
                errors.append(f"epic #{i} に優先度 (priority) がありません")
            
            # エピックステータスの検証
            if "status" in epic:
                status = epic["status"]
                if status not in ["new", "in_progress", "blocked", "completed"]:
                    warnings.append(f"epic #{i} の status '{status}' は new, in_progress, blocked, completed のいずれかであるべきです")
            else:
                errors.append(f"epic #{i} にステータス (status) がありません")
            
            # ストーリーの検証
            if "stories" in epic:
                for j, story in enumerate(epic["stories"], 1):
                    story_count += 1
                    
                    # ストーリーIDの検証
                    if "story_id" not in story:
                        errors.append(f"epic #{i}, story #{j} にストーリーID (story_id) がありません")
                    else:
                        story_id = story["story_id"]
                        if not re.match(r'^(US|S)-\d+$', story_id):
                            warnings.append(f"epic #{i}, story #{j} の story_id '{story_id}' は推奨形式 'US-XXX' または 'S-XXX' に準拠していません")
                    
                    # ストーリータイトルの検証
                    if "title" not in story:
                        errors.append(f"epic #{i}, story #{j} にタイトル (title) がありません")
                    
                    # ストーリー説明の検証
                    if "description" not in story:
                        errors.append(f"epic #{i}, story #{j} に説明 (description) がありません")
                    
                    # ストーリー優先度の検証
                    if "priority" in story:
                        priority = story["priority"]
                        if priority not in ["high", "medium", "low"]:
                            warnings.append(f"epic #{i}, story #{j} の priority '{priority}' は 'high', 'medium', 'low' のいずれかであるべきです")
                    else:
                        errors.append(f"epic #{i}, story #{j} に優先度 (priority) がありません")
                    
                    # ストーリーポイントの検証
                    if "story_points" not in story:
                        errors.append(f"epic #{i}, story #{j} にストーリーポイント (story_points) がありません")
                    
                    # アサイニーの検証
                    if "assignee" not in story:
                        warnings.append(f"epic #{i}, story #{j} に担当者 (assignee) が設定されていません")
                    
                    # ストーリーステータスの検証
                    if "status" in story:
                        status = story["status"]
                        if status not in ["new", "planned", "in_progress", "blocked", "completed"]:
                            warnings.append(f"epic #{i}, story #{j} の status '{status}' は new, planned, in_progress, blocked, completed のいずれかであるべきです")
                    else:
                        errors.append(f"epic #{i}, story #{j} にステータス (status) がありません")
                    
                    # スプリントの検証
                    if "sprint" in story:
                        sprint_id = story["sprint"]
                        if sprint_id not in sprints:
                            errors.append(f"epic #{i}, story #{j} の sprint '{sprint_id}' は定義されていないスプリントです")
                    else:
                        warnings.append(f"epic #{i}, story #{j} にスプリント (sprint) が割り当てられていません")
            
            epic_count += 1
    
    # サマリーを作成
    summary = {
        "epic_count": epic_count,
        "story_count": story_count,
        "sprint_count": len(sprints)
    }
    
    return errors, warnings, summary

def format_check_result(errors, warnings, summary):
    """検証結果を読みやすいフォーマットで返す"""
    result = ""
    
    if errors:
        result += "\n❌ エラー:\n"
        for error in errors:
            result += f"  - {error}\n"
    
    if warnings:
        result += "\n⚠️ 警告:\n"
        for warning in warnings:
            result += f"  - {warning}\n"
    
    if summary:
        result += "\n📊 サマリー:\n"
        for key, value in summary.items():
            if key == "epic_count":
                result += f"  - エピック数: {value}\n"
            elif key == "story_count":
                result += f"  - ストーリー数: {value}\n"
            elif key == "sprint_count":
                result += f"  - スプリント数: {value}\n"
    
    if errors:
        result += "\n検証結果: 失敗 - エラーを修正してください\n"
    elif warnings:
        result += "\n検証結果: 成功（警告あり） - 必要に応じて警告を確認してください\n"
    else:
        result += "\n検証結果: 成功\n"
    
    return result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("使用方法: python validate_backlog_yaml.py <バックログファイルパス>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    errors, warnings, summary = validate_backlog_yaml(file_path)
    
    result = format_check_result(errors, warnings, summary)
    print(result)
    
    if errors:
        sys.exit(1)
    else:
        sys.exit(0) 