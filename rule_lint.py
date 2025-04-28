#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
rule_lint.py - ルールファイルの構文チェック

使用方法:
  python rule_lint.py <rules_dir>

例:
  python rule_lint.py .cursor/rules
"""

import sys
import os
import re
import yaml
import glob
from colorama import init, Fore, Style

# カラー表示の初期化
init()

def print_color(text, color=Fore.WHITE, style=Style.NORMAL):
    """色付きテキスト出力"""
    print(f"{style}{color}{text}{Style.RESET_ALL}")

def find_all_mdc_files(rules_dir):
    """指定ディレクトリ内のすべての.mdcファイルを検索"""
    return glob.glob(os.path.join(rules_dir, "*.mdc"))

def parse_yaml_blocks(content):
    """ファイル内のYAMLブロックを解析"""
    yaml_sections = {}
    
    # ブロック名と内容を抽出
    block_pattern = r'([a-zA-Z0-9_]+):\s*\n((?:\s+.+\n)+)'
    for match in re.finditer(block_pattern, content):
        block_name = match.group(1)
        block_content = match.group(2)
        
        try:
            # YAMLとして解析
            parsed = yaml.safe_load(block_content)
            yaml_sections[block_name] = parsed
        except yaml.YAMLError as e:
            # 解析エラー
            yaml_sections[block_name] = {"_error": str(e)}
    
    return yaml_sections

def check_template_variables(template_text, questions):
    """テンプレート内の変数が質問から取得可能か確認"""
    errors = []
    
    # テンプレート内の変数を抽出 {{variable}}
    variables = re.findall(r'\{\{([a-zA-Z0-9_]+)\}\}', template_text)
    
    # 質問キーのリストを作成
    question_keys = set()
    for category in questions:
        if 'items' in category:
            for item in category['items']:
                if 'key' in item:
                    question_keys.add(item['key'])
    
    # システム変数はチェック対象外
    system_vars = {'today', 'project_id', 'patterns', 'dirs', 'meta'}
    
    # 未定義変数をチェック
    for var in variables:
        if var not in question_keys and not any(var.startswith(prefix) for prefix in system_vars):
            errors.append(f"テンプレート変数 '{var}' が質問セットで定義されていません")
    
    return errors

def check_path_references(content, rules_dir):
    """パス参照が正しいかチェック"""
    errors = []
    
    # path_reference を抽出
    ref_match = re.search(r'path_reference:\s*"([^"]+)"', content)
    if not ref_match:
        return ["path_reference が見つかりません"]
    
    ref_file = ref_match.group(1)
    ref_path = os.path.join(rules_dir, ref_file)
    
    if not os.path.exists(ref_path):
        errors.append(f"参照ファイル '{ref_file}' が見つかりません")
    
    return errors

def check_triggers(triggers, all_rules_content):
    """トリガーの重複や構文をチェック"""
    errors = []
    
    # 全てのトリガー正規表現を収集
    all_triggers = []
    for rule_content in all_rules_content.values():
        matches = re.findall(r'trigger:\s*"([^"]+)"', rule_content)
        all_triggers.extend(matches)
    
    # 重複チェック
    for trigger in triggers:
        count = all_triggers.count(trigger)
        if count > 1:
            errors.append(f"トリガー '{trigger}' が {count} 回重複しています")
    
    return errors

def lint_rule_file(file_path, all_rules_content):
    """ルールファイルの構文チェック"""
    errors = []
    warnings = []
    info = []
    
    print_color(f"\n📋 ルールファイル: {os.path.basename(file_path)}", Fore.CYAN, Style.BRIGHT)
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print_color(f"  ❌ ファイルを読み込めません: {e}", Fore.RED)
        return False
    
    # 基本チェック
    rules_dir = os.path.dirname(file_path)
    path_errors = check_path_references(content, rules_dir)
    if path_errors:
        for error in path_errors:
            errors.append(error)
    
    # YAMLブロックの解析
    yaml_sections = parse_yaml_blocks(content)
    
    # セクションごとのチェック
    for section_name, parsed in yaml_sections.items():
        if isinstance(parsed, dict) and "_error" in parsed:
            errors.append(f"セクション '{section_name}' のYAML構文エラー: {parsed['_error']}")
            continue
        
        # 質問セットとテンプレートの対応チェック
        if section_name.endswith('_questions') and parsed:
            # 対応するテンプレートを探す
            template_name = section_name.replace('_questions', '_template')
            template_pattern = rf'{template_name}:\s*\|((?:\s+.+\n)+)'
            template_match = re.search(template_pattern, content)
            
            if template_match:
                template_text = template_match.group(1)
                template_errors = check_template_variables(template_text, parsed)
                errors.extend(template_errors)
            else:
                warnings.append(f"質問セット '{section_name}' に対応するテンプレート '{template_name}' が見つかりません")
    
    # トリガーチェック
    trigger_matches = re.findall(r'trigger:\s*"([^"]+)"', content)
    trigger_errors = check_triggers(trigger_matches, all_rules_content)
    errors.extend(trigger_errors)
    
    # 結果出力
    if errors:
        for error in errors:
            print_color(f"  ❌ エラー: {error}", Fore.RED)
    
    if warnings:
        for warning in warnings:
            print_color(f"  ⚠️ 警告: {warning}", Fore.YELLOW)
    
    if info:
        for i in info:
            print_color(f"  ℹ️ 情報: {i}", Fore.BLUE)
    
    if not errors and not warnings:
        print_color(f"  ✅ チェック成功: 問題は見つかりませんでした", Fore.GREEN)
    
    return len(errors) == 0

def main():
    if len(sys.argv) < 2:
        print("使用法: python rule_lint.py <rules_dir>")
        sys.exit(1)
    
    rules_dir = sys.argv[1]
    
    print_color(f"🔍 ルール構文チェックを開始します: {rules_dir}", Fore.CYAN, Style.BRIGHT)
    
    # すべてのルールファイルを検索
    mdc_files = find_all_mdc_files(rules_dir)
    if not mdc_files:
        print_color("❌ ルールファイル (.mdc) が見つかりません", Fore.RED)
        sys.exit(1)
    
    print_color(f"📚 {len(mdc_files)} ファイルを検査中...", Fore.CYAN)
    
    # すべてのファイル内容を読み込み
    all_rules_content = {}
    for file_path in mdc_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                all_rules_content[file_path] = f.read()
        except Exception:
            all_rules_content[file_path] = ""
    
    # 各ファイルをチェック
    success_count = 0
    for file_path in mdc_files:
        if lint_rule_file(file_path, all_rules_content):
            success_count += 1
    
    # 結果サマリー
    print_color(f"\n===== 結果サマリー =====", Fore.CYAN, Style.BRIGHT)
    print_color(f"検査ファイル数: {len(mdc_files)}", Fore.WHITE)
    print_color(f"成功: {success_count}", Fore.GREEN)
    print_color(f"問題あり: {len(mdc_files) - success_count}", Fore.RED if len(mdc_files) - success_count > 0 else Fore.WHITE)
    
    if success_count == len(mdc_files):
        print_color("\n✅ すべてのルールファイルが問題なく検証されました", Fore.GREEN, Style.BRIGHT)
        sys.exit(0)
    else:
        print_color("\n⚠️ 一部のルールファイルに問題があります。修正してください。", Fore.YELLOW, Style.BRIGHT)
        sys.exit(1)

if __name__ == "__main__":
    main() 