# エージェントのGoogleカレンダー連携追加機能（MCPを使わない方法）

## Google Calendar APIを使った予定取得機能の設定方法

このドキュメントでは、MCPを使わずにGoogleカレンダーの予定を取得する方法を説明します。設定には少し手間がかかりますが、一度設定すれば安定して動作し、Cursorエージェントが自然な形であなたの予定を確認できるようになります。

### 前提条件

- Google アカウントを持っていること
- ターミナルの基本操作ができること
- 折れない心


## AIエージェントからのカレンダー確認利用おすすめ方法

AIエージェント（Claude、GPT等）との連携を容易にするため、シンプルなシェルスクリプトを用意しています。以下の手順で設定することで、自然言語で予定を確認できるようになります。

### get_calendar_events.shの設置

1. 配布された`get_calendar_events.sh`スクリプトを`scripts/calendar_app/`フォルダに配置します（このレポジトリでは初期から配布済み）
   ```bash
   mkdir -p scripts/calendar_app
   cp get_calendar_events.sh scripts/calendar_app/
   chmod +x scripts/calendar_app/get_calendar_events.sh
   ```

### Master Rulesへの登録方法

Cursorのルールファイル（例：`.cursor/rules/basic/00_master_rules.mdc`）に以下の設定を追加します：

```markdown
#--------------------------------------------
# タスク管理
#--------------------------------------------
  - trigger: "(今日の予定確認|今日の予定|カレンダー確認|Calendar events)"
    command: "{{root}}/scripts/calendar_app/get_calendar_events.sh"
    message: "カレンダーデータを取得しています..."
    instruction: "このコマンドのみを実行し、他の処理は一切行わないこと"
```

### 使用方法

上記の設定を行うと、AIエージェント（Claude、GPT等）に対して以下のように自然言語で予定を確認できるようになります：

```
ユーザー: 今日の予定確認して
エージェント: カレンダーデータを取得しています...
[予定の一覧が表示されます]
```

このように設定することで、AIエージェントはユーザーからの「今日の予定確認」といった指示を受け取ると、自動的にコマンドを実行してGoogleカレンダーから予定を取得し、整形して表示してくれます。

さて、このコマンドを機能させるために、以下の長い準備が必要となります！

## 配布するファイル


1. **Code.js** - アプリケーションのメインコード
2. **appsscript.json** - スクリプト設定ファイル
3. **USAGE.md** - 使用方法マニュアル
4. **README.md** - セットアップ手順書
5. **get_calendar_events.sh** - AIエージェントと連携するためのスクリプト


## カレンダーエージェント機能の初期設定手順


## 初期設定

### 1. レポジトリをClone

   ```bash
   git clone https://github.com/miyatti777/calendar_app.git 
   ```
で、ファイル配置

※ AIPMシステム使っている人はScriptsフォルダのなかにいれるのおすすめ
※自分でフォルダ作る人は以下のコマンドで、ファイルをDLしてきていれてください

アプリフォルダ作成
   ```bash
   mkdir calendar_app
   cd calendar_app
   ```


### 2. 環境セットアップ

1. Node.jsとnpmのインストール（未インストールの場合）
2. claspのグローバルインストール
   ```bash
   npm install -g @google/clasp
   ```



## GCP側の作業

### 1 必要なAPIの有効化

1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス

![alt text](<assets/CleanShot 2025-05-12 at 12.09.52.png>)

2. プロジェクトを作成
![alt text](<assets/CleanShot 2025-05-12 at 12.07.50.png>)
3. プロジェクトを開く
![alt text](<assets/CleanShot 2025-05-12 at 12.11.48.png>)
4. 左側メニューから「APIとサービス」→「ライブラリ」を選択
![alt text](<assets/CleanShot 2025-05-12 at 12.12.54.png>)
**解説**: この手順でApps ScriptプロジェクトをGCPプロジェクトと連携させます。これにより、GoogleのAPIを使用するための基盤が整います。

2. 以下のAPIを検索して有効化：
   - Google Apps Script API（必須）
   - Google Calendar API
  
![alt text](<assets/CleanShot 2025-05-12 at 12.14.10.png>)

**解説**: この手順でGCPプロジェクトが必要なAPIを使えるようになります。Apps Script APIはclaspでの操作に必須で、Calendar APIはカレンダー情報取得に必要です。

### 2 OAuth認証の設定
![alt text](<assets/CleanShot 2025-05-12 at 12.14.55.png>)
1. 左側メニューから「APIとサービス」→「認証情報」を選択
![alt text](<assets/CleanShot 2025-05-12 at 12.15.35.png>)

2. 「認証情報を作成」→「OAuthクライアントID」をクリック

### 3 Google Auth Platform 構成

![alt text](<assets/CleanShot 2025-05-12 at 12.20.35.png>)
1. まずはメニューから概要をタップし、Google Auth Platformの構成の「開始」をタップ
2. アプリ情報で名前と連絡先を入力
3. 対象は「外部」もしくは「内部」を選択し、必要な情報を入力（内部の場合は何も追加入力なし。外部の場合は、あとで色々追加入力必要）
4. サイドレランク先情報おいれて、利用規約にチェック入れたら作成
![alt text](<assets/CleanShot 2025-05-12 at 12.23.09.png>)

※ Enterprise利用の場合は、セキュリティの観点から基本内部を選択。個人利用の場合は外部しか使えないため、テストユーザーとして自分のメアド登録

※　対象を外部にした場合、メニューから対象を選んでテストユーザーに自分のメアドを入れる
![alt text](<assets/CleanShot 2025-05-12 at 12.24.22.png>)



### 4 データアクセスの設定

1. メニューからデータアクセスをタップ

![alt text](<assets/CleanShot 2025-05-12 at 12.25.59.png>)

2. 「スコープを追加」タップで、フィルタでキーワードで絞り込んで、以下を追加：
   - `.../auth/script.external_request`
   - `.../auth/calendar`
   - `.../auth/calendar.readonly`
![alt text](<assets/CleanShot 2025-05-12 at 12.29.18.png>)



### 4. OAuthクライアントIDの作成
![alt text](<assets/CleanShot 2025-05-12 at 12.31.29.png>)
1. メニューからクライアントをタップ
2. クライアントを作成をタップ
3. アプリケーションの種類として「デスクトップアプリケーション」を選択
4. 名前を入力し「作成」をクリック
5. クライアントIDとシークレットが表示されるので、JSONをダウンロード
6. ダウンロードしたJSONファイルを作業ディレクトリに`creds.json`として保存（名前を変更しとく）
   
![alt text](<assets/CleanShot 2025-05-12 at 12.32.04.png>)





**解説**: このステップでローカル開発環境からGoogleのAPIにアクセスするための認証情報を設定します。



## Cursor側の作業

![alt text](<assets/CleanShot 2025-05-12 at 12.33.46@2x.png>)

最初に作ったディレクトリを右クリックして「Open in Integrated terminal」とかしてそのフォルダの場所でターミナル開く

### 1. Google Apps Script プロジェクト作成

1. claspでログイン
   ```bash
   clasp login --creds creds.json
   ```
ブラウザがたがあるので、ログイン

![alt text](<assets/CleanShot 2025-05-12 at 12.35.09.png>)
![alt text](<assets/CleanShot 2025-05-12 at 12.35.45.png>)
スコープの権限もとめてくるので許可
![alt text](<assets/CleanShot 2025-05-12 at 12.36.17@2x.png>)
こんな感じでターミナルで Authorization Succsessfullとでてれば成功。赤背景でびびるが、.clasprc.jsonというファイルは絶対Uploadするなよという警告で赤くなってるだけ


**解説**: このコマンドで認証画面が開き、あなたのGoogleアカウントとclaspを連携します。認証が成功すると、ホームディレクトリに`.clasprc.json`というファイルが作成されます。これは認証情報を保存する一時的なファイルで、アカウントを切り替えるたびに上書きされます。


2. 新しいスタンドアロンスクリプトプロジェクトを作成
   ```bash
   clasp create --type standalone --title "google calendar app new" --rootDir .
   ```
   ※このコマンドで生成された.clasp.jsonファイルは**削除せず**に残しておく


### 2. プロジェクト作成とファイル配置


1. 配布されたファイルを配置
   - Code.js
   - appsscript.json
   （appscript.jsonは前に作られたやつ削除で大丈夫）

2. スクリプトのアップロード

   ```bash
   clasp push
   ```

3. GCPプロジェクトと紐づける
   ```bash
   clasp open
   ```
   - ブラウザでスクリプトエディタが開くので、「⚙️プロジェクト設定」→「GCPプロジェクト」で作成したプロジェクトと紐づける

![alt text](<assets/CleanShot 2025-05-12 at 12.48.05@2x.png>)
![alt text](<assets/CleanShot 2025-05-12 at 12.48.38@2x.png>)
![alt text](<assets/CleanShot 2025-05-12 at 12.49.01@2x.png>)
![alt text](<assets/CleanShot 2025-05-12 at 12.49.27@2x.png>)
![alt text](<assets/CleanShot 2025-05-12 at 12.50.12@2x.png>)
**解説**: ブラウザでApps Scriptエディタが開きます。ここからGCPプロジェクトとの連携設定を行います。


4. もういちどログインして、設定したスコープの承認をおこなう
   ```bash
   clasp login --creds creds.json
   ```
![alt text](<assets/CleanShot 2025-05-12 at 12.50.58.png>)

![alt text](<assets/CleanShot 2025-05-12 at 12.51.16@2x.png>)

ここのプロジェクトIDを入力
また赤背景になるが気にしない

### 4 デプロイとテスト実行

1. `clasp deploy`でウェブアプリやAPIとしてデプロイ

**解説**: デプロイすることで、スクリプトを外部から呼び出し可能なエンドポイントとして公開できます。

2. 関数を実行してテスト
   ```bash
   clasp run getEvents
   ```


## 主なカスタマイズポイント

### カレンダーIDの変更

デフォルトでは`primary`（ユーザーのメインカレンダー）が使用されますが、他のカレンダーを使用する場合は関数呼び出し時にIDを指定します：

```bash
clasp run getCalendarEventsWithParams -p '["your_calendar_id@group.calendar.google.com", 7, "2025-01-01", ""]'
```

### 日付範囲の調整

特定の日付範囲を取得する場合：

```bash
# 特定の日付の予定を取得
clasp run getDateEvents -p '["2025-05-15"]'

# 特定の期間の予定を取得
clasp run getCalendarEventsWithParams -p '["primary", 30, "2025-01-01", ""]'
```

### 検索フィルタの設定

イベント名や説明文に特定のキーワードを含むものだけを取得する場合：

```bash
clasp run getCalendarEventsWithParams -p '["primary", 30, "2025-01-01", "会議"]'
```

## 重要: 認証情報の取り扱いに関する注意事項

このアプリケーションの設定過程で、以下の認証情報ファイルが生成されます：

1. **creds.json** - Google OAuthクライアントIDとシークレットを含むファイル
2. **.clasprc.json** - claspの認証トークンを含むファイル

### セキュリティ上の重要な注意点

これらのファイルには機密情報が含まれており、**絶対に**以下の行為を避けてください：

- GitHubなどの公開リポジトリへのプッシュ
- チームでの共有ドライブへのアップロード
- メールやSlackでの送信

### Gitを使用する場合の設定

リポジトリにこれらのファイルを含めないために、必ず**.gitignore**ファイルを作成してください：

```bash
# .gitignoreファイルを作成または編集
echo ".clasprc.json" >> .gitignore
echo "creds.json" >> .gitignore
```

### 誤って認証情報をコミットしてしまった場合の対処法

もし誤って認証情報をコミットし、リモートリポジトリにプッシュしてしまった場合：

1. **即時に認証情報を無効化する**：
   - Google Cloud Consoleで該当するOAuthクライアントIDを削除または再生成
   - 新しい認証情報で再設定

2. **Gitの履歴から認証情報を削除**：
   ```bash
   git filter-branch --force --index-filter "git rm --cached --ignore-unmatch .clasprc.json creds.json" --prune-empty --tag-name-filter cat -- --all
   git push origin --force
   ```

3. **全てのチームメンバーに通知**：誤ってコミットされた認証情報について通知し、古いブランチを使用しないよう依頼

### ベストプラクティス

- 各開発者は自分自身のOAuth認証情報を作成・使用する
- 本番環境用の認証情報は、安全な認証情報管理サービスを使用して保存・共有する
- 開発環境と本番環境で異なるクライアントIDを使用する

これらの注意事項を守ることで、セキュリティリスクを最小限に抑え、GoogleのAPIを安全に利用できます。

## 免責事項とライセンス

### 免責事項
このアプリケーションは「現状のまま」提供されており、十分なテストが行われていない可能性があります。作者および貢献者は、このアプリケーションの使用によって生じるいかなる直接的、間接的、偶発的、特別、典型的、または結果的な損害についても責任を負いません。自己責任でご利用ください。

### ライセンス
このアプリケーションはMITライセンスの下で提供されています。個人的または商用目的で自由に使用、変更、配布することができますが、著作権表示とこの許可通知をすべてのコピーまたは実質的な部分に含める必要があります。



