#!/usr/bin/env python3
# classify_flow_files_local.py
"""
Flow ディレクトリを走査して *.md / *.txt に簡易 YAML Front‑Matter を付与
  - doc_targets:  キーワード辞書で判定（複数可）
  - importance:   最大マッチ数を 1‑5 に丸めたスコア
  - autofill:     代表的キーフレーズを抜粋して埋め込み（任意）

cron 例)  0 2 * * *  /usr/bin/python3 /path/to/classify_flow_files_local.py
"""

import os, re, glob, datetime, textwrap
from pathlib import Path

# ========= 設定 ========= #
FLOW_ROOT      = "/Users/daisukemiyata/aipm_v3/Flow"
LOOKBACK_DAYS  = 3650        # さかのぼる日数（10年分＝実質すべて）
MIN_SCORE      = 1           # 1 キーにつき何ヒットで対象とみなすか
FRONTMATTER_RX = re.compile(r"^---\s*\n.*?\n---\s*\n", re.S)   # 既存 YFM 検出
DEBUG          = True        # デバッグメッセージを表示

KEYWORDS = {
    "charter":      ["背景", "目的", "スコープ", "憲章", "charter"],
    "stakeholder":  ["ステークホルダー", "利害関係", "stakeholder"],
    "wbs":          ["WBS", "作業分解", "作業ブレークダウン"],
    "risk_plan":    ["リスク", "影響", "確率", "risk", "回避策"],
    "status_report":["進捗", "バーンダウン", "報告書", "status"],
    "lessons":      ["教訓", "lessons", "振り返り", "retrospective"]
}

# ========= ヘルパ ========= #
def recent_files(root):
    since = datetime.datetime.now() - datetime.timedelta(days=LOOKBACK_DAYS)
    
    # 明示的にマークダウンとテキストファイルのパターンを指定
    patterns = [
        os.path.join(root, "**", "*.md"),
        os.path.join(root, "**", "*.txt")
    ]
    
    files_found = 0
    for pattern in patterns:
        if DEBUG:
            print(f"パターン {pattern} で検索中...")
        for fp in glob.glob(pattern, recursive=True):
            files_found += 1
            file_path = Path(fp)
            if DEBUG and files_found <= 5:  # 最初の5件だけ表示
                print(f"  見つかったファイル: {file_path}")
            if datetime.datetime.fromtimestamp(os.path.getmtime(fp)) > since:
                yield file_path
    
    if DEBUG:
        print(f"検索対象ファイル数: {files_found}")

def score_file(text):
    targets, counts = [], []
    if DEBUG:
        print(f"  スコアリング: 文字数={len(text)}")
    for tgt, words in KEYWORDS.items():
        hit = sum(bool(re.search(re.escape(w), text, re.I)) for w in words)
        if DEBUG and hit > 0:
            print(f"    - {tgt}: {hit}ヒット")
        if hit >= MIN_SCORE:
            targets.append(tgt)
            counts.append(hit)
    if not counts:
        return [], 0
    importance = max(min(max(counts), 5), 1)   # 1‑5 に丸め
    return targets, importance

def insert_frontmatter(path, targets, importance):
    content = path.read_text(encoding="utf-8")
    has_yfm = FRONTMATTER_RX.match(content)

    yfm_lines = [
        "---",
        f"doc_targets: {targets}",
        f"importance: {importance}",
        "---\n"
    ]
    yfm_block = "\n".join(yfm_lines)

    if has_yfm:
        # 既存 Front‑Matter がある → 欠けているキーだけ補完
        fm_end = has_yfm.end()
        head = content[:fm_end]
        body = content[fm_end:]
        if "doc_targets:" not in head:
            head = head.rstrip() + f"\ndoc_targets: {targets}\n"
        if "importance:" not in head:
            head = head.rstrip() + f"importance: {importance}\n"
        new_content = head + body
    else:
        new_content = yfm_block + content

    path.write_text(new_content, encoding="utf-8")
    print(f"📝 updated {path.relative_to(FLOW_ROOT)}   targets={targets}")

# ========= MAIN ========= #
def main():
    print(f"🔍 {FLOW_ROOT} 内のファイルを検索中...")
    found_files = list(recent_files(FLOW_ROOT))
    print(f"最近 {LOOKBACK_DAYS} 日以内に更新された {len(found_files)} 件のファイルを処理します")
    
    for file in found_files:
        if DEBUG:
            print(f"処理中: {file.relative_to(FLOW_ROOT)}")
        try:
            text = file.read_text(encoding="utf-8")[:8000]   # 先頭 8000 文字だけ見て十分
            targets, importance = score_file(text)
            if targets:
                insert_frontmatter(file, targets, importance)
            elif DEBUG:
                print(f"  ⚠️ {file.relative_to(FLOW_ROOT)} は条件に合わず (targets={targets})")
        except Exception as e:
            print(f"❌ エラー ({file}): {str(e)}")
    
    print("✅ 処理完了")

if __name__ == "__main__":
    main() 