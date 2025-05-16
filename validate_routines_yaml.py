#!/usr/bin/env python3
import sys
import yaml
import json
import re
from pathlib import Path
import datetime

def validate_routines_yaml(file_path):
    """ルーチンタスクYAMLファイルを検証する"""
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
    
    # 基本情報の検証
    if "project" not in data and "program" not in data:
        errors.append("'project' または 'program' が定義されていません")
    
    # ルーチン定義の検証
    routine_count = 0
    task_count = 0
    tasks_with_assignee = 0
    
    # 標準形式のルーチンチェック
    if "routines" in data and isinstance(data["routines"], list):
        for i, routine in enumerate(data["routines"], 1):
            routine_count += 1
            
            # 必須フィールドの検証
            required_fields = ["routine_id", "title", "frequency", "priority"]
            for field in required_fields:
                if field not in routine:
                    errors.append(f"routine #{i} に必須フィールド '{field}' がありません")
            
            # IDフォーマットの検証
            if "routine_id" in routine:
                routine_id = routine["routine_id"]
                if not re.match(r'^RT-\d+$', routine_id):
                    warnings.append(f"routine #{i} の routine_id '{routine_id}' は推奨形式 'RT-数字' に準拠していません")
            
            # 頻度の検証
            if "frequency" in routine:
                frequency = routine["frequency"]
                if frequency not in ["daily", "weekly", "monthly", "quarterly", "yearly"]:
                    errors.append(f"routine #{i} の frequency '{frequency}' は 'daily', 'weekly', 'monthly', 'quarterly', 'yearly' のいずれかである必要があります")
                
                # 曜日の検証
                if frequency == "weekly" and "day_of_week" not in routine:
                    warnings.append(f"routine #{i} は weekly ですが、day_of_week が指定されていません")
                
                if "day_of_week" in routine:
                    day_of_week = routine["day_of_week"]
                    valid_days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
                    if day_of_week not in valid_days:
                        errors.append(f"routine #{i} の day_of_week '{day_of_week}' は {', '.join(valid_days)} のいずれかである必要があります")
                
                # 日付の検証
                if frequency == "monthly" and "day_of_month" not in routine:
                    warnings.append(f"routine #{i} は monthly ですが、day_of_month が指定されていません")
                
                if "day_of_month" in routine:
                    day_of_month = routine["day_of_month"]
                    if not isinstance(day_of_month, int) or day_of_month < 1 or day_of_month > 31:
                        errors.append(f"routine #{i} の day_of_month '{day_of_month}' は 1-31 の整数である必要があります")
            
            # 優先度の検証
            if "priority" in routine:
                priority = routine["priority"]
                if priority not in ["high", "medium", "low"]:
                    errors.append(f"routine #{i} の priority '{priority}' は 'high', 'medium', 'low' のいずれかである必要があります")
            
            # タスクの検証
            if "tasks" in routine and isinstance(routine["tasks"], list):
                for j, task in enumerate(routine["tasks"], 1):
                    task_count += 1
                    
                    # 必須フィールドの検証
                    task_required_fields = ["task_id", "title"]
                    for field in task_required_fields:
                        if field not in task:
                            errors.append(f"routine #{i}, task #{j} に必須フィールド '{field}' がありません")
                    
                    # IDフォーマットの検証
                    if "task_id" in task:
                        task_id = task["task_id"]
                        if not re.match(r'^T-\d+$', task_id):
                            warnings.append(f"routine #{i}, task #{j} の task_id '{task_id}' は推奨形式 'T-数字' に準拠していません")
                    
                    # 見積もり時間の検証
                    if "estimate" in task:
                        estimate = task["estimate"]
                        if not isinstance(estimate, int) or estimate <= 0:
                            errors.append(f"routine #{i}, task #{j} の estimate '{estimate}' は正の整数である必要があります")
                    else:
                        warnings.append(f"routine #{i}, task #{j} に見積もり時間 (estimate) が指定されていません")
                    
                    # 優先度の検証
                    if "priority" in task:
                        priority = task["priority"]
                        if priority not in ["high", "medium", "low"]:
                            errors.append(f"routine #{i}, task #{j} の priority '{priority}' は 'high', 'medium', 'low' のいずれかである必要があります")
                    else:
                        warnings.append(f"routine #{i}, task #{j} に優先度 (priority) が指定されていません")
                    
                    # Assigneeの検証
                    if "assignee" in task and task["assignee"]:
                        tasks_with_assignee += 1
                    else:
                        warnings.append(f"routine #{i}, task #{j} に担当者 (assignee) が指定されていません")
            else:
                warnings.append(f"routine #{i} には tasks が定義されていないか、リスト形式ではありません")
    
    # 代替形式のルーチンチェック（morning_routinesなど）
    alternative_routines = ["morning_routines", "evening_routines", "weekly_routines"]
    for routine_key in alternative_routines:
        if routine_key in data and isinstance(data[routine_key], dict):
            routine_count += 1
            routine_obj = data[routine_key]
            
            # 必須フィールドの検証
            if "name" not in routine_obj:
                errors.append(f"{routine_key} に名前 (name) がありません")
            
            # タスクリストの検証
            if "items" in routine_obj and isinstance(routine_obj["items"], list):
                for j, task in enumerate(routine_obj["items"], 1):
                    task_count += 1
                    
                    # 必須フィールドの検証
                    task_required_fields = ["id", "title"]
                    for field in task_required_fields:
                        if field not in task:
                            errors.append(f"{routine_key}, item #{j} に必須フィールド '{field}' がありません")
                    
                    # IDフォーマットの検証
                    if "id" in task:
                        task_id = task["id"]
                        if not re.match(r'^RT-\d+$', task_id):
                            warnings.append(f"{routine_key}, item #{j} の id '{task_id}' は推奨形式 'RT-数字' に準拠していません")
                    
                    # 見積もり時間の検証
                    if "estimate" in task:
                        estimate = task["estimate"]
                        if not isinstance(estimate, int) or estimate <= 0:
                            errors.append(f"{routine_key}, item #{j} の estimate '{estimate}' は正の整数である必要があります")
                    else:
                        warnings.append(f"{routine_key}, item #{j} に見積もり時間 (estimate) が指定されていません")
                    
                    # 優先度の検証
                    if "priority" in task:
                        priority = task["priority"]
                        if not isinstance(priority, int) or priority < 0:
                            errors.append(f"{routine_key}, item #{j} の priority '{priority}' は 0以上の整数である必要があります")
                    
                    # Assigneeの検証
                    if "assignee" in task and task["assignee"]:
                        tasks_with_assignee += 1
                    else:
                        warnings.append(f"{routine_key}, item #{j} に担当者 (assignee) が指定されていません")
            else:
                errors.append(f"{routine_key} には items が定義されていないか、リスト形式ではありません")
    
    # 最低1つのルーチンがあるか確認
    if routine_count == 0:
        errors.append("ルーチン定義がありません。'routines' リストまたは代替形式のルーチン定義が必要です")
    
    # Assigneeが指定されたタスクの割合をチェック
    if task_count > 0 and tasks_with_assignee == 0:
        warnings.append(f"すべてのタスク ({task_count}件) に担当者 (assignee) が指定されていません")
    elif task_count > 0:
        assignee_percentage = (tasks_with_assignee / task_count) * 100
        if assignee_percentage < 50:
            warnings.append(f"タスクの担当者 (assignee) 指定率が低いです ({tasks_with_assignee}/{task_count}, {assignee_percentage:.1f}%)")
    
    # サマリーを作成
    summary = {
        "routine_count": routine_count,
        "task_count": task_count,
        "tasks_with_assignee": tasks_with_assignee,
        "assignee_coverage": f"{(tasks_with_assignee / task_count) * 100:.1f}%" if task_count > 0 else "N/A"
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
            if key == "routine_count":
                result += f"  - ルーチン数: {value}\n"
            elif key == "task_count":
                result += f"  - タスク数: {value}\n"
            elif key == "tasks_with_assignee":
                result += f"  - 担当者指定タスク数: {value}\n"
            elif key == "assignee_coverage":
                result += f"  - 担当者指定カバレッジ: {value}\n"
    
    if errors:
        result += "\n検証結果: 失敗 - エラーを修正してください\n"
    elif warnings:
        result += "\n検証結果: 成功（警告あり） - 必要に応じて警告を確認してください\n"
    else:
        result += "\n検証結果: 成功\n"
    
    return result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("使用方法: python validate_routines_yaml.py <ルーチンタスクファイルパス>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    errors, warnings, summary = validate_routines_yaml(file_path)
    
    result = format_check_result(errors, warnings, summary)
    print(result)
    
    if errors:
        sys.exit(1)
    else:
        sys.exit(0) 