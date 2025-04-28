# バックログYAMLフォーマット検証ツール

このドキュメントは、バックログYAMLファイルの正しいフォーマットとその検証方法について説明します。

## 1. バックログYAMLの正しい形式

バックログYAMLファイルは以下の構造に従う必要があります：

```yaml
project_id: PROJECT-ID
backlog_version: v1.0
last_updated: YYYY-MM-DD
created_by: 作成者名

epics:
  - epic_id: E001
    title: エピックタイトル
    description: エピックの説明
    owner: 担当者
    priority: high|medium|low
    status: in_progress|not_started|completed
    stories:
      - story_id: US-001
        title: ストーリータイトル
        description: ストーリーの説明
        acceptance_criteria:
          - 受け入れ基準1
          - 受け入れ基準2
        story_points: 3
        priority: high|medium|low
        status: in_progress|not_started|completed
        assignee: 担当者
```

### 重要なルール

1. **エピックとストーリーの関係**：
   - 各ストーリーは対応するエピックの `stories` 配列内に配置する必要があります
   - トップレベルの `user_stories` フィールドは使用しません

2. **フィールド名**：
   - エピックIDは `epic_id` を使用（`id` ではなく）
   - ストーリーIDは `story_id` を使用（`id` ではなく）
   - 見積もりは `story_points` を使用（`estimate` ではなく）
   - 担当者は `assignee` を使用（`assigned_to` ではなく）

3. **必須フィールド**：
   - トップレベル: `project_id`, `epics`
   - エピック: `epic_id`, `title`, `stories`
   - ストーリー: `story_id`, `title`, `description`

4. **推奨フィールド**（オプション）：
   - トップレベル: `backlog_version`, `last_updated`, `created_by`

## 2. 検証スクリプトの使い方

バックログYAMLが正しいフォーマットかどうか確認するには、`validate_backlog_yaml.py` スクリプトを使用します。

### 基本的な使い方

```bash
python scripts/validate_backlog_yaml.py /path/to/backlog.yaml
```

### 結果の見方

- 検証成功の場合：
  ```
  ✅ 検証に成功しました！YAMLは想定フォーマットに準拠しています。
  ```

- 検証失敗の場合：
  ```
  ❌ 検証に失敗しました。以下の問題が検出されました：

  ❌ [エラーメッセージ]
  ...

  修正案:
  🔧 [修正提案]
  ...
  ```

## 3. 推奨ワークフロー

1. **バックログ作成/更新時**：
   ```bash
   # バックログYAMLを編集
   vim Flow/Private/YYYY-MM-DD/backlog/backlog.yaml

   # フォーマット検証
   python scripts/validate_backlog_yaml.py Flow/Private/YYYY-MM-DD/backlog/backlog.yaml

   # 問題があれば修正
   vim Flow/Private/YYYY-MM-DD/backlog/backlog.yaml

   # 問題なければストーリー生成
   python scripts/yaml_to_stories.py Flow/Private/YYYY-MM-DD/backlog/backlog.yaml Flow/Private/YYYY-MM-DD/backlog/stories
   ```

2. **CI/CRプロセスでの使用**：
   - プルリクエスト時にバックログYAMLファイルをこのスクリプトで検証することをお勧めします
   - エラーがある場合は、修正案を参考に修正してください

## 4. 注意事項

- 検証スクリプトはバックログYAMLの形式のみを検証し、内容の妥当性は検証しません
- エピックIDやストーリーIDの一貫性、表記ルールは別途プロジェクトで定める必要があります
- ストーリーポイントや優先度の値域についても、プロジェクトルールに従ってください

## 5. トラブルシューティング

- **スクリプト実行時のエラー**：
  - Python 3系が必要です
  - `pyyaml` パッケージがインストールされていることを確認してください: `pip install pyyaml`

- **YAMLフォーマットエラー**：
  - インデントに注意してください。YAMLはスペースの数で階層を表現します
  - コロン(`:`)の後にはスペースが必要です
  - 特殊文字がある場合はクォーテーション(`"` or `'`)で囲ってください 