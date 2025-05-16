# Google Calendar API アプリケーション 使用マニュアル

このアプリケーションはGoogleカレンダーから予定情報を取得するGoogle Apps Script (GAS)です。ローカル環境からClaspを使って各種機能を実行できます。

## 前提条件

- Claspがインストール済みであること
- 認証済みの状態であること（`.clasprc.json`が設定されていること）
- このプロジェクトフォルダにカレントディレクトリが設定されていること

## 基本的な使い方

### 1. 指定フォルダに移動

```bash
cd scripts/calendar_clasp
```

### 2. 関数の実行

Claspで関数を実行する場合は、以下の構文を使用します：

```bash
# パラメータなしの関数を実行
clasp run 関数名

# パラメータありの関数を実行
clasp run 関数名 -p '["パラメータ1", "パラメータ2", ...]'
```

## 利用可能な関数一覧

以下の関数をClaspから実行できます：

### getEvents

今日から7日間の予定を取得します。デフォルトでは主要カレンダー（primary）の予定を取得します。

```bash
clasp run getEvents
```

### getCalendarEventsWithParams

指定したパラメータで予定を取得します。カレンダーID、取得日数、開始日、検索クエリを指定できます。

```bash
# 正しい構文:
clasp run getCalendarEventsWithParams -p '["primary", 14, "2025-05-01", "会議"]'

# または引用符を使用する場合:
clasp run getCalendarEventsWithParams -p "[\"primary\", 14, \"2025-05-01\", \"会議\"]"
```

### getTomorrowEvents

明日の予定だけを取得します。

```bash
clasp run getTomorrowEvents
```

### getNextThreeDaysEvents

今日から3日間の予定を取得します。

```bash
clasp run getNextThreeDaysEvents
```

### getDateEvents（日本時間対応版）

任意の日付の予定を取得します。日付を指定して、その日の予定をすべて取得します。
**日本時間で厳密に指定した日付の予定だけを取得します**（時差による誤差を解消）。

```bash
# 基本的な使い方（日付文字列で指定）
clasp run getDateEvents -p '["2025-05-15"]'

# カレンダーIDも指定する場合
clasp run getDateEvents -p '["2025-05-15", "primary"]'

# 日付をYYYY-MM-DD形式で指定することで、正確に日本時間の該当日の予定だけを取得
```

**注意事項**:
- 日付は必ず「YYYY-MM-DD」形式で指定してください（例: 2025-05-15）
- この関数は日本時間（JST）で指定した日付の0時0分から23時59分までの予定だけを返します
- APIから返ってきたイベントを日本時間基準で厳密にフィルタリングするため、時差の問題は発生しません

### getAllCalendars

利用可能なすべてのカレンダーリストを取得します。

```bash
clasp run getAllCalendars
```

## パラメータ指定の注意点

Claspでパラメータを指定する場合、以下の形式を使います：

```bash
# 単一のパラメータ
clasp run 関数名 -p '["パラメータ値"]' 

# 複数のパラメータ
clasp run 関数名 -p '["値1", "値2", 数値, true]'

# 注意: 文字列はシングルクォートで囲み、
# JSONとして正しい形式にする必要があります
```

**よくある間違い**:
- ❌ `clasp run "getDateEvents('2025-05-15')"` 
- ✅ `clasp run getDateEvents -p '["2025-05-15"]'`

## Webアプリケーションとしての使用

このアプリケーションはWebアプリケーションとしてデプロイすることも可能です。デプロイ後は以下のようなURLパラメータでアクセスできます：

```
https://script.google.com/macros/s/[SCRIPT_ID]/exec?action=events&calendarId=primary&days=7&startDate=2025-05-15
```

### サポートされているURLパラメータ

- `action`: 取得するデータのタイプ（`events`または`calendars`）
- `calendarId`: カレンダーID（デフォルト: `primary`）
  - 複数のカレンダーを指定する場合はカンマ区切り（例: `primary,user@example.com`）
- `days`: 取得する日数（デフォルト: `7`）
- `startDate`: 開始日（YYYY-MM-DD形式、デフォルト: 今日）
- `q`: 検索クエリ（イベントのタイトルや説明に含まれるテキスト）

## トラブルシューティング

- **空の結果が返ってくる場合**: カレンダーアクセス権限が正しく設定されているか確認
- **認証エラー**: `clasp login --creds creds.json`で再認証
- **特定の日付の予定が取得できない**: 日付形式が正しいか確認（YYYY-MM-DD形式）
- **Invalid Date エラー**: `getDateEvents`に渡す日付形式が不正な場合に発生。YYYY-MM-DD形式か有効なDateオブジェクトを使用してください
- **時差問題**: `getDateEvents`関数は時差問題に対応済みですが、他の関数では日本時間とUTC時間の違いにより、予期しない日付の予定が含まれる場合があります

## 開発者向け情報

### コードの構成

- `doGet(e)`: Webアプリケーションとしてのエントリーポイント
- `getEventsResponse(e)`: カレンダーイベントをJSON形式で返す
- `getCalendarsList(e)`: カレンダーリストをJSON形式で返す
- `getCalendarEvents()`: 指定期間の予定を取得する基本関数
- `getDateEvents()`: 指定日の予定を取得する関数（日本時間対応済み）
- その他のヘルパー関数

### 返されるイベント情報

各イベントには以下の情報が含まれます：

```json
{
  "id": "イベントID",
  "title": "イベントタイトル",
  "description": "イベントの説明",
  "location": "場所",
  "startTime": "開始時間",
  "endTime": "終了時間",
  "allDay": "終日イベントかどうか（true/false）",
  "creator": "作成者のメールアドレス",
  "attendees": ["参加者のメールアドレス配列"],
  "status": "イベントのステータス（confirmed等）",
  "htmlLink": "イベントへのリンク",
  "calendarId": "カレンダーID",
  "calendarName": "カレンダー名",
  "colorId": "イベントの色ID"
}
```

### デプロイ方法

新しいバージョンをデプロイするには：

```bash
clasp push    # コードをアップロード
clasp deploy  # デプロイ（Webアプリケーションとして公開）
``` 