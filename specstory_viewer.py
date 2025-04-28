#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SpecStory Log to HTML Converter
# 作成日: 2025-04-24

import re
import sys
import os
import yaml
from datetime import datetime
import argparse

def convert_specstory_to_html(markdown_path, output_path=None):
    """SpecStoryのマークダウンログをHTML吹き出しビューアに変換する"""
    
    # 出力パスが指定されていない場合はデフォルト設定
    if output_path is None:
        basename = os.path.basename(markdown_path)
        output_path = f"{os.path.splitext(basename)[0]}.html"
    
    # マークダウンファイル読み込み
    try:
        with open(markdown_path, 'r', encoding='utf-8') as file:
            content = file.read()
    except Exception as e:
        print(f"エラー: ファイル読み込み失敗 - {e}")
        return None
    
    # タイトル情報を抽出
    title_match = re.search(r'# (.*?) \((.*?)\)', content)
    if title_match:
        title = title_match.group(1)
        date = title_match.group(2)
    else:
        title = os.path.basename(markdown_path)
        date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # 会話セクションに分割
    sections = re.split(r'\n---\n', content)
    
    # HTML構築開始
    html_parts = []
    html_parts.append(f'''<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/styles/vs2015.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.7.0/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>
    <style>
        :root {{
            --user-color: #e3f2fd;
            --assistant-color: #f1f8e9;
            --system-color: #f5f5f5;
            --yaml-bg: #fffde7;
            --code-bg: #263238;
            --diff-add: #e6ffed;
            --diff-del: #ffdce0;
        }}
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            max-width: 1000px;
            margin: 0 auto;
            padding: 20px;
            background-color: #fafafa;
            color: #333;
        }}
        header {{
            background-color: #2196f3;
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }}
        .chat-container {{
            display: flex;
            flex-direction: column;
            gap: 20px;
        }}
        .message {{
            max-width: 80%;
            padding: 10px 15px;
            border-radius: 12px;
            position: relative;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        .user-message {{
            align-self: flex-end;
            background-color: var(--user-color);
            border-bottom-right-radius: 2px;
            margin-left: auto;
        }}
        .assistant-message {{
            align-self: flex-start;
            background-color: var(--assistant-color);
            border-bottom-left-radius: 2px;
            margin-right: auto;
        }}
        .system-message {{
            align-self: center;
            background-color: var(--system-color);
            width: 90%;
            border-radius: 6px;
            font-family: monospace;
            white-space: pre-wrap;
        }}
        .avatar {{
            width: 40px;
            height: 40px;
            border-radius: 50%;
            position: absolute;
            bottom: -5px;
            background-size: cover;
            background-position: center;
            box-shadow: 0 1px 3px rgba(0,0,0,0.2);
        }}
        .user-avatar {{
            right: -10px;
            background-color: #2196f3;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }}
        .assistant-avatar {{
            left: -10px;
            background-color: #4caf50;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }}
        .message-content {{
            padding: 5px;
        }}
        pre {{
            background-color: var(--code-bg);
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            margin: 10px 0;
        }}
        code {{
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }}
        .yaml-block {{
            background-color: var(--yaml-bg);
            padding: 10px;
            border-radius: 5px;
            font-family: monospace;
            white-space: pre-wrap;
        }}
        .diff-add {{
            background-color: var(--diff-add);
            display: block;
        }}
        .diff-del {{
            background-color: var(--diff-del);
            display: block;
        }}
        .timestamp {{
            font-size: 0.7em;
            color: #888;
            text-align: center;
            margin: 5px 0;
        }}
        .section-divider {{
            border-top: 1px dashed #ccc;
            margin: 15px 0;
        }}
    </style>
</head>
<body>
    <header>
        <h1>{title}</h1>
        <p>作成日時: {date}</p>
    </header>
    <div class="chat-container">
''')

    # マークダウン→HTML変換の簡易実装
    def md_to_html(text):
        # コードブロック処理
        code_block_pattern = r'```(\w*)\n(.*?)\n```'
        code_blocks = re.finditer(code_block_pattern, text, re.DOTALL)
        for block in code_blocks:
            lang = block.group(1) or ""
            code = block.group(2)
            
            if lang == "diff":
                # Diff形式のコード処理
                diff_lines = []
                for line in code.split('\n'):
                    if line.startswith('+'):
                        diff_lines.append(f'<span class="diff-add">{line}</span>')
                    elif line.startswith('-'):
                        diff_lines.append(f'<span class="diff-del">{line}</span>')
                    else:
                        diff_lines.append(line)
                
                html_code = '<pre class="language-diff"><code>' + '\n'.join(diff_lines) + '</code></pre>'
            else:
                # 通常のコード処理
                lang_class = f" class=\"language-{lang}\"" if lang else ""
                html_code = f'<pre><code{lang_class}>{code}</code></pre>'
                
            text = text.replace(block.group(0), html_code)
            
        # インラインコード処理
        text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
        
        # 見出し処理
        text = re.sub(r'^# (.+)$', r'<h1>\1</h1>', text, flags=re.MULTILINE)
        text = re.sub(r'^## (.+)$', r'<h2>\1</h2>', text, flags=re.MULTILINE)
        text = re.sub(r'^### (.+)$', r'<h3>\1</h3>', text, flags=re.MULTILINE)
        
        # リスト処理
        text = re.sub(r'^- (.+)$', r'<li>\1</li>', text, flags=re.MULTILINE)
        
        # 段落処理 (空行区切り)
        text = re.sub(r'\n\n([^<].*?)\n\n', r'\n\n<p>\1</p>\n\n', text, flags=re.DOTALL)
        
        # テーブル処理はシンプルな実装は難しいので省略
        
        # 改行処理
        text = text.replace('\n', '<br>')
        
        return text
    
    # セクション処理
    for i, section in enumerate(sections):
        section = section.strip()
        if not section:
            continue
            
        # 発言者を識別
        if "_**User**_" in section:
            speaker = "user"
            content_start = section.find("_**User**_") + len("_**User**_")
            message_content = section[content_start:].strip()
        elif "_**Assistant**_" in section:
            speaker = "assistant"
            content_start = section.find("_**Assistant**_") + len("_**Assistant**_")
            message_content = section[content_start:].strip()
        else:
            # システムメッセージまたはコマンド出力
            html_parts.append(f'''
    <div class="system-message message">
        <div class="message-content">{md_to_html(section)}</div>
    </div>
    <div class="section-divider"></div>
''')
            continue
            
        # YAMLフロントマターを処理
        if message_content.startswith("---") and "---" in message_content[3:]:
            yaml_block_match = re.match(r'---\n(.*?)\n---', message_content, re.DOTALL)
            if yaml_block_match:
                yaml_content = yaml_block_match.group(1)
                try:
                    yaml_data = yaml.safe_load(yaml_content)
                    yaml_html = f'<div class="yaml-block"><pre>{yaml_content}</pre></div>'
                    message_content = message_content.replace(f"---\n{yaml_content}\n---", yaml_html)
                except Exception:
                    # YAML解析エラー時は何もしない
                    pass
        
        # メッセージをHTML化
        avatar_text = "U" if speaker == "user" else "A"
        message_class = "user-message" if speaker == "user" else "assistant-message"
        avatar_class = "user-avatar" if speaker == "user" else "assistant-avatar"
        
        processed_html = md_to_html(message_content)
        
        html_parts.append(f'''
    <div class="{message_class} message">
        <div class="message-content">{processed_html}</div>
        <div class="{avatar_class} avatar">{avatar_text}</div>
    </div>
''')
    
    # HTMLを閉じる
    html_parts.append('''
    </div>
    <script>
        document.addEventListener('DOMContentLoaded', (event) => {
            document.querySelectorAll('pre code').forEach((block) => {
                hljs.highlightBlock(block);
            });
        });
    </script>
</body>
</html>
''')
    
    # 最終的なHTMLを書き込む
    try:
        with open(output_path, 'w', encoding='utf-8') as file:
            file.write(''.join(html_parts))
        print(f"変換完了: {output_path}")
        return output_path
    except Exception as e:
        print(f"エラー: ファイル書き込み失敗 - {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description='SpecStory ログを HTML 吹き出しビューに変換')
    parser.add_argument('input', help='変換する SpecStory ログファイルパス')
    parser.add_argument('-o', '--output', help='出力先 HTML ファイルパス')
    parser.add_argument('-d', '--dir', help='出力先ディレクトリ')
    
    args = parser.parse_args()
    
    input_path = args.input
    if not os.path.exists(input_path):
        print(f"エラー: 入力ファイル '{input_path}' が見つかりません")
        return 1
    
    output_path = args.output
    if not output_path and args.dir:
        if not os.path.exists(args.dir):
            os.makedirs(args.dir)
        basename = os.path.basename(input_path)
        output_path = os.path.join(args.dir, f"{os.path.splitext(basename)[0]}.html")
    
    result = convert_specstory_to_html(input_path, output_path)
    return 0 if result else 1

if __name__ == "__main__":
    sys.exit(main()) 