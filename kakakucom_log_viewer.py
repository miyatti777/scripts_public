#!/usr/bin/env python3
"""
Kakakucom Log Viewer
会話ログをHTML形式の見やすいビューアーに変換するスクリプト
- ユーザーとアシスタントの発言を吹き出し形式で表示
- コードブロックはトグルで開閉可能（初期状態では最初の数行のみ表示）
"""

import os
import re
import sys
import argparse
from pathlib import Path
import markdown
from markdown.extensions.fenced_code import FencedCodeExtension
from markdown.extensions.tables import TableExtension

# HTML テンプレート
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        body {{
            font-family: 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1000px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        
        h1 {{
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }}
        
        h2, h3, h4, h5, h6 {{
            color: #2c3e50;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
        }}
        
        .conversation {{
            margin: 20px 0;
        }}
        
        .message {{
            margin: 25px 0;
            clear: both;
            overflow: hidden;
        }}
        
        .user-message, .assistant-message {{
            max-width: 85%;
            padding: 15px 20px;
            border-radius: 18px;
            position: relative;
            word-wrap: break-word;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }}
        
        .user-message {{
            float: right;
            background-color: #DCF8C6;
            border-bottom-right-radius: 5px;
            margin-left: 15%;
        }}
        
        .assistant-message {{
            float: left;
            background-color: #ECECEC;
            border-bottom-left-radius: 5px;
            margin-right: 15%;
        }}
        
        .code-block {{
            background-color: #272822;
            color: #f8f8f2;
            border-radius: 5px;
            margin: 15px 0;
            overflow: hidden;
            font-size: 14px;
        }}
        
        .code-preview {{
            padding: 12px 15px;
            border-bottom: 1px solid #444;
            cursor: pointer;
            position: relative;
        }}
        
        .toggle-icon {{
            position: absolute;
            right: 15px;
            top: 12px;
            color: #f8f8f2;
            font-weight: bold;
        }}
        
        .code-content {{
            padding: 12px 15px;
            overflow-x: auto;
            display: none;
        }}
        
        .code-content.expanded {{
            display: block;
        }}
        
        .timestamp {{
            font-size: 0.75em;
            color: #888;
            margin: 5px 0;
            clear: both;
        }}
        
        pre {{
            margin: 0;
            white-space: pre-wrap;
        }}
        
        code {{
            font-family: Consolas, Monaco, 'Andale Mono', monospace;
        }}
        
        .speaker-label {{
            font-weight: bold;
            margin-bottom: 8px;
            color: #555;
        }}
        
        .user .speaker-label {{
            text-align: right;
        }}
        
        .assistant .speaker-label {{
            text-align: left;
        }}
        
        /* Markdown 要素のスタイル */
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 15px 0;
        }}
        
        th, td {{
            border: 1px solid #ddd;
            padding: 8px 12px;
            text-align: left;
        }}
        
        th {{
            background-color: #f2f2f2;
        }}
        
        tr:nth-child(even) {{
            background-color: #f9f9f9;
        }}
        
        p {{
            margin: 10px 0;
        }}
        
        ul, ol {{
            margin: 10px 0;
            padding-left: 25px;
        }}
        
        blockquote {{
            border-left: 4px solid #ccc;
            margin: 15px 0;
            padding: 5px 15px;
            background-color: #f9f9f9;
        }}
        
        hr {{
            border: 0;
            height: 1px;
            background: #ddd;
            margin: 20px 0;
        }}
        
        a {{
            color: #3498db;
            text-decoration: none;
        }}
        
        a:hover {{
            text-decoration: underline;
        }}
    </style>
</head>
<body>
    <h1>{title}</h1>
    <div class="conversation">
        {content}
    </div>
    
    <script>
        document.addEventListener('DOMContentLoaded', function() {{
            // コードブロックのトグル機能
            const codeToggles = document.querySelectorAll('.code-preview');
            
            codeToggles.forEach(toggle => {{
                toggle.addEventListener('click', function() {{
                    const content = this.nextElementSibling;
                    content.classList.toggle('expanded');
                    
                    const icon = this.querySelector('.toggle-icon');
                    if (content.classList.contains('expanded')) {{
                        icon.textContent = '▲';
                    }} else {{
                        icon.textContent = '▼';
                    }}
                }});
            }});
            
            // 最初のコードブロックは自動的に開く
            if (codeToggles.length > 0) {{
                codeToggles[0].click();
            }}
        }});
    </script>
</body>
</html>"""

def parse_markdown_log(file_path):
    """
    Markdownログファイルを解析してユーザーとアシスタントのメッセージを抽出
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # タイトルと日付を抽出
    title_match = re.search(r'# (.*?) \((.*?)\)', content)
    title = title_match.group(1) if title_match else "会話ログ"
    date = title_match.group(2) if title_match else ""
    
    # ユーザーとアシスタントのメッセージを識別
    # 特殊なフォーマットに合わせて調整 (_**User**_, _**Assistant**_ など)
    messages = []
    
    # メッセージのパターン (改良版)
    pattern = r'_\*\*(User|Assistant)\*\*_\s*\n\n([\s\S]*?)(?=\n\n_\*\*(User|Assistant)\*\*_|\n\n---|\Z)'
    message_matches = re.finditer(pattern, content, re.DOTALL)
    
    for match in message_matches:
        speaker = match.group(1)
        message_content = match.group(2).strip()
        
        # "---" で区切られたセクションがある場合は処理
        if "---" in message_content:
            # 最初の "---" より前の部分は無視
            sections = message_content.split("---")
            if len(sections) > 1:
                message_content = "\n---\n".join(sections[1:])
        
        messages.append({
            'type': 'user' if speaker.lower() == 'user' else 'assistant',
            'content': message_content
        })
    
    return {
        'title': f"{title} ({date})" if date else title,
        'messages': messages
    }

def process_code_blocks(message_content):
    """
    コードブロックを特定し、トグル可能なHTMLに変換
    """
    # 改良版コードブロックパターン - より一般的なパターンを使用
    code_block_pattern = r'```(.*?)\n([\s\S]*?)```'
    
    def replace_code_block(match):
        language = match.group(1).strip()
        code = match.group(2).strip()
        
        lines = code.split('\n')
        preview_lines = lines[:3]  # 最初の3行をプレビューとして表示
        
        preview_html = '<div class="code-preview">'
        preview_html += f'<code>{html_escape(language)}</code> <span class="toggle-icon">▼</span>'
        if preview_lines:
            preview_html += f'<pre>{html_escape(preview_lines[0]) if len(preview_lines) > 0 else ""}</pre>'
        if len(preview_lines) > 1:
            preview_html += f'<pre>{html_escape(preview_lines[1])}</pre>'
        if len(lines) > 2:
            preview_html += '<pre>...</pre>'
        preview_html += '</div>'
        
        content_html = '<div class="code-content">'
        content_html += f'<pre><code>{html_escape(code)}</code></pre>'
        content_html += '</div>'
        
        return f'<div class="code-block">{preview_html}{content_html}</div>'
    
    # 特殊処理：コードブロックの前に一時的にマーカーを挿入して保護
    # このアプローチにより、markdownの処理がコードブロックを壊すのを防ぐ
    marker_prefix = "__CODE_BLOCK_MARKER_"
    marker_suffix = "__"
    markers = {}
    marker_count = 0
    
    def protect_code_blocks(match):
        nonlocal marker_count
        marker = f"{marker_prefix}{marker_count}{marker_suffix}"
        markers[marker] = replace_code_block(match)
        marker_count += 1
        return marker
    
    # コードブロックを一時的なマーカーに置き換え
    protected_content = re.sub(code_block_pattern, protect_code_blocks, message_content, flags=re.DOTALL)
    
    # Markdown処理
    md = markdown.Markdown(extensions=[
        FencedCodeExtension(),
        TableExtension()
    ])
    html_content = md.convert(protected_content)
    
    # マーカーを元のHTMLに戻す
    for marker, html in markers.items():
        html_content = html_content.replace(marker, html)
    
    return html_content

def html_escape(text):
    """HTML特殊文字をエスケープ"""
    return (text.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace("'", '&#39;'))

def convert_to_html(parsed_data):
    """
    解析したデータをHTML形式に変換
    """
    html_content = ""
    
    for message in parsed_data['messages']:
        message_type = message['type']
        content = process_code_blocks(message['content'])
        
        # 吹き出し形式のメッセージを作成
        message_html = f'<div class="message {message_type}">'
        message_html += f'<div class="speaker-label">{message_type.capitalize()}</div>'
        message_html += f'<div class="{message_type}-message">{content}</div>'
        message_html += f'</div>'
        
        html_content += message_html
    
    return HTML_TEMPLATE.format(title=parsed_data['title'], content=html_content)

def main():
    parser = argparse.ArgumentParser(description='会話ログをHTML形式のビューアーに変換')
    parser.add_argument('input_file', help='入力となる.mdファイルのパス')
    parser.add_argument('-o', '--output', help='出力HTMLファイルのパス（省略時は入力ファイル名.html）')
    parser.add_argument('-d', '--debug', action='store_true', help='デバッグモード（詳細エラー表示）')
    
    args = parser.parse_args()
    
    input_path = Path(args.input_file)
    if not input_path.exists():
        print(f"エラー: 入力ファイル '{input_path}' が見つかりません。", file=sys.stderr)
        return 1
    
    if not args.output:
        output_path = input_path.with_suffix('.html')
    else:
        output_path = Path(args.output)
    
    try:
        parsed_data = parse_markdown_log(input_path)
        html_output = convert_to_html(parsed_data)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html_output)
        
        print(f"変換完了: '{output_path}' に保存しました。")
        return 0
        
    except Exception as e:
        print(f"エラー: 変換中に問題が発生しました: {e}", file=sys.stderr)
        if args.debug:
            import traceback
            traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main()) 