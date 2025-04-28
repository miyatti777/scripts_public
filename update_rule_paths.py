#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ルールファイル内のパス参照を更新するスクリプト
使用方法: python update_rule_paths.py
"""

import os
import re
import glob

# 設定
ROOT_DIR = "/Users/daisukemiyata/aipm_v3"
RULES_DIR = os.path.join(ROOT_DIR, ".cursor/rules")
BASIC_DIR = os.path.join(RULES_DIR, "basic")
REAL_ESTATE_DIR = os.path.join(RULES_DIR, "real_estate")

def update_file_references(file_path):
    """ファイル内の参照パスを更新する"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 基本ルールへの参照を更新 (例: pmbok_*.mdc => basic/pmbok_*.mdc)
    basic_patterns = [
        (r'call\s+(pmbok_[a-zA-Z0-9_]+\.mdc)', r'call basic/\1'),
        (r'template_reference:\s+"(pmbok_[a-zA-Z0-9_]+\.mdc)', r'template_reference: "basic/\1'),
        (r'call\s+(flow_to_stock_rules\.mdc)', r'call basic/\1'),
        (r'call\s+(00_master_rules\.mdc)', r'call basic/\1'),
        (r'call\s+(0[1-9]_pmbok_[a-zA-Z0-9_]+\.mdc)', r'call basic/\1'),
        (r'call\s+(90_rule_maintenance\.mdc)', r'call basic/\1'),
        (r'call\s+(07_task_management\.mdc)', r'call basic/\1'),
        (r'call\s+(08_pmbok_flow_assist\.mdc)', r'call basic/\1'),
    ]
    
    # 不動産ルールへの参照を更新
    real_estate_patterns = [
        (r'call\s+(pmbok_discovery_real_estate\.mdc)', r'call real_estate/\1'),
        (r'call\s+(insight_analysis\.mdc)', r'call real_estate/\1'),
        (r'call\s+(ideation_module\.mdc)', r'call real_estate/\1'),
        (r'template_reference:\s+"(pmbok_discovery_real_estate\.mdc)', r'template_reference: "real_estate/\1'),
        (r'template_reference:\s+"(insight_analysis\.mdc)', r'template_reference: "real_estate/\1'),
        (r'template_reference:\s+"(ideation_module\.mdc)', r'template_reference: "real_estate/\1'),
    ]
    
    # パスの参照更新
    for pattern, replacement in basic_patterns + real_estate_patterns:
        content = re.sub(pattern, replacement, content)
    
    # 実際にファイルを保存
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"更新しました: {os.path.basename(file_path)}")

def main():
    """メイン処理：全てのルールファイルのパス参照を更新"""
    # 基本ルールファイルのパス参照を更新
    for file_path in glob.glob(os.path.join(BASIC_DIR, "*.mdc")):
        update_file_references(file_path)
    
    # 不動産ルールファイルのパス参照を更新
    for file_path in glob.glob(os.path.join(REAL_ESTATE_DIR, "*.mdc")):
        update_file_references(file_path)
    
    # メインディレクトリに残ったルールファイルも更新
    for file_path in glob.glob(os.path.join(RULES_DIR, "*.mdc")):
        update_file_references(file_path)
    
    print("全てのルールファイルのパス参照を更新しました")

if __name__ == "__main__":
    main() 