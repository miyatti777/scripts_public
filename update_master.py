#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
update_master.py - MasterRulesファイルに新フェーズトリガーを自動挿入

使用方法:
  python update_master.py <phase_name> <trigger_regex> <master_rules_path> <phase_number> <phase_slug>

例:
  python update_master.py Discovery "実験カード作成|Experiment Card" .cursor/rules/00_master_rules.mdc 2 discovery
"""

import sys
import os
import re
from datetime import datetime

def get_next_phase_file_number(master_text):
    """既存のファイル番号から次のファイル番号を推定"""
    pattern = r'call (\d+)_pmbok_'
    matches = re.findall(pattern, master_text)
    if not matches:
        return "01"  # デフォルト
    
    # 最大の番号を探し、+1する
    next_num = max(int(num) for num in matches) + 1
    return f"{next_num:02d}"

def insert_trigger_block(master_path, phase_name, trigger_regex, phase_number, phase_slug):
    """00_master_rules.mdcにトリガーブロックを挿入"""
    
    # ファイル読み込み
    with open(master_path, 'r', encoding='utf-8') as f:
        text = f.read()
    
    # 次のファイル番号を取得
    file_num = get_next_phase_file_number(text)
    
    # 挿入マーカーを探す
    marker = "# === AUTO INSERT PHASES ==="
    if marker not in text:
        marker = "# ----------------"  # フォールバックマーカー
        if marker not in text:
            print("エラー: 挿入ポイントが見つかりません")
            sys.exit(1)
    
    # 挿入するブロック
    block = f"""
  #--------------------------------------------
  # {phase_name} フェーズ
  #--------------------------------------------
  - trigger: "({trigger_regex})"
    priority: high
    steps:
      - call {file_num}_pmbok_{phase_slug}.mdc => {phase_slug}_questions
      - wait_for_all_answers
      - confirm: "{phase_name} ドラフトを作成します。よろしいですか？"
      - create_markdown_file:
          path: "{{{{patterns.flow_date}}}}/draft_{phase_slug}.md"
          template_reference: "{file_num}_pmbok_{phase_slug}.mdc => {phase_slug}_template"
"""

    # マーカーの後にブロックを挿入
    new_text = text.replace(marker, marker + block)
    
    # 更新情報を追加
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    new_text = new_text.replace(
        "# ==========",
        f"# ========== 最終更新: {timestamp} (自動更新: {phase_name}フェーズ追加)"
    )
    
    # 書き戻し
    with open(master_path, 'w', encoding='utf-8') as f:
        f.write(new_text)
    
    print(f"✅ MasterRules({master_path})へ新フェーズ「{phase_name}」のトリガーを挿入しました。")
    return file_num

def main():
    if len(sys.argv) < 6:
        print("使用法: python update_master.py <phase_name> <trigger_regex> <master_rules_path> <phase_number> <phase_slug>")
        sys.exit(1)
    
    phase_name = sys.argv[1]
    trigger_regex = sys.argv[2]
    master_path = sys.argv[3]
    phase_number = sys.argv[4]
    phase_slug = sys.argv[5]
    
    # マスタールールの更新
    file_num = insert_trigger_block(master_path, phase_name, trigger_regex, phase_number, phase_slug)
    
    # 成功メッセージ
    print(f"新フェーズ: {phase_name} (スラグ: {phase_slug}, 番号: {phase_number})")
    print(f"ファイル: {file_num}_pmbok_{phase_slug}.mdc")
    print(f"トリガー: {trigger_regex}")

if __name__ == "__main__":
    main() 