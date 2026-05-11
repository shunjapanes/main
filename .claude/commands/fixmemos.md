`debug-memos/` 以下の未対応メモを順番に確認・修正し、完了後に `done/` へ移動します。

## Step 1: メモ一覧取得

GitHub MCP で `debug-memos/` 以下のファイルを列挙：

```
mcp__github__get_file_contents: path="debug-memos", repo="shunjapanes/main"
```

- `done/` サブディレクトリは除外
- `images/` サブディレクトリは除外
- `.md` ファイルのみを処理対象とする
- 古い順（ファイル名の日時部分で並べる）に処理

## Step 2: 各メモを順番に処理

For each `.md` file:

1. **内容取得**: `mcp__github__get_file_contents` でファイル本文を取得
2. **分類**: バグ報告 / 機能要望 / 質問 のいずれか判断
3. **コード特定**: `client/public/editor.html` または `client/src/` の該当箇所を探す
4. **修正**: 問題があれば修正を実施
5. **テスト実行**:
   ```bash
   cd /home/user/main/client && PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers npx playwright test --timeout=30000 2>&1
   ```
6. **コミット＆プッシュ**:
   ```bash
   git add -A && git commit -m "fix: <メモタイトルから要約>" && git push -u origin claude/check-github-Pbro4
   ```

## Step 3: 対応済みメモを done/ に移動

処理が完了したメモをそれぞれ移動：

```
# 1. done/ に同内容でファイルを作成
mcp__github__create_or_update_file:
  path="debug-memos/done/{元ファイル名}"
  content=（元ファイルの内容＋末尾に対応記録を追記）

# 追記フォーマット:
---
## 対応記録
- 対応日: YYYY-MM-DD
- 対応内容: （修正の要約）
- コミット: （コミットハッシュ）

# 2. 元ファイルを削除
mcp__github__delete_file:
  path="debug-memos/{元ファイル名}"
```

関連画像は移動しない（`debug-memos/images/` に残す）。

## Step 4: 報告

以下の形式でまとめる：

```
## 処理結果
- 対応済み: N件
- 対応不要（スキップ）: N件

## 修正内容サマリー
- [ファイル名]: 修正内容の1行説明

## 未対応メモ
- なし / またはファイル名＋理由
```

バグ以外（機能要望・質問）のメモは内容を確認してから、実装するか確認を取る。
