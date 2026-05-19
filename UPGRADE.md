# アップグレード方法

このドキュメントでは、本プロジェクト（TSV/CSV Editor）の各コンポーネントのアップグレード手順を説明します。

## 目次

- [前提条件](#前提条件)
- [1. 依存パッケージのアップグレード](#1-依存パッケージのアップグレード)
- [2. Node.js バージョンのアップグレード](#2-nodejs-バージョンのアップグレード)
- [3. メジャーバージョンアップグレード](#3-メジャーバージョンアップグレード)
- [4. デプロイ済みアプリの更新](#4-デプロイ済みアプリの更新)
- [トラブルシューティング](#トラブルシューティング)

---

## 前提条件

- Node.js 20 以上（CI と揃える場合は LTS 推奨）
- npm 10 以上
- Git
- `client/` ディレクトリ配下に Vite + React アプリが配置されています

```bash
node -v   # v20.x.x 以上
npm -v    # 10.x.x 以上
```

---

## 1. 依存パッケージのアップグレード

### 1.1 マイナー／パッチ更新（推奨フロー）

`client/package.json` 内の semver 範囲（`^` 等）に従って更新します。

```bash
cd client
npm outdated          # 更新可能なパッケージを確認
npm update            # semver 範囲内で更新
npm run build         # 型チェック＋ビルドが通ることを確認
npm run dev           # ローカル動作確認
```

### 1.2 個別パッケージの更新

```bash
cd client
npm install <package>@latest
```

例：

```bash
npm install react@latest react-dom@latest
npm install -D vite@latest @vitejs/plugin-react@latest
npm install -D typescript@latest
npm install -D tailwindcss@latest postcss@latest autoprefixer@latest
npm install lucide-react@latest
```

### 1.3 セキュリティ脆弱性の解消

```bash
cd client
npm audit
npm audit fix         # 破壊的変更なしで修正
npm audit fix --force # 破壊的変更を許容（リスクあり）
```

---

## 2. Node.js バージョンのアップグレード

CI 用 Node バージョンは `.github/workflows/deploy.yml` の `node-version` で固定されています。

更新手順：

1. `.github/workflows/deploy.yml` の `node-version: 20` を新しいバージョンに変更
2. ローカルでも同じバージョンに切り替え（`nvm use <version>` 等）
3. `cd client && npm ci && npm run build` でビルドが通ることを確認
4. 変更をコミットし、main ブランチへマージ

```yaml
# .github/workflows/deploy.yml
- uses: actions/setup-node@v4
  with:
    node-version: 22   # ← ここを更新
```

---

## 3. メジャーバージョンアップグレード

破壊的変更を含むため、必ず個別に対応し、各ステップで動作確認します。

### 3.1 React（例：19 → 20）

```bash
cd client
npm install react@20 react-dom@20
npm install -D @types/react@20 @types/react-dom@20
```

- [React 公式アップグレードガイド](https://react.dev/blog) で破壊的変更を確認
- `client/src/main.tsx` の `createRoot` 周辺、`App.tsx` の API 利用箇所をチェック
- `npm run build` で型エラーが出ないか確認

### 3.2 Vite（例：6 → 7）

```bash
cd client
npm install -D vite@7 @vitejs/plugin-react@latest
```

- `client/vite.config.ts` の設定が新バージョンと互換か確認
- 特に `base: '/main/'` の挙動、`server.port` 設定を再確認
- [Vite Migration Guide](https://vite.dev/guide/migration.html) を参照

### 3.3 TypeScript（例：5.6 → 5.7+）

```bash
cd client
npm install -D typescript@latest
```

- `client/tsconfig.json` および `tsconfig.app.json` / `tsconfig.node.json` の互換性を確認
- `npm run build`（`tsc -b && vite build`）が通ることを確認

### 3.4 Tailwind CSS（例：3 → 4）

Tailwind 4 は設定方式が大きく変わるため特に注意：

```bash
cd client
npm install -D tailwindcss@4 @tailwindcss/postcss@latest
```

- `tailwind.config.ts` と `postcss.config.js` を新形式に書き換え
- `client/src/index.css` の `@tailwind` ディレクティブを新仕様に更新
- [Tailwind 4 アップグレードガイド](https://tailwindcss.com/docs/upgrade-guide) を参照

### 3.5 メジャーアップグレードの推奨手順

1. 専用ブランチを作成（例：`upgrade/react-20`）
2. 該当パッケージのみ更新
3. `npm run build` でビルド成功を確認
4. `npm run dev` で起動し、主要機能を手動テスト
   - TSV/CSV のインポート・編集・エクスポート
   - キーボードショートカット
   - 右クリックメニュー
   - ドラッグスクロール
5. デプロイプレビュー（後述）で確認
6. PR を作成しレビュー後にマージ

---

## 4. デプロイ済みアプリの更新

main ブランチへの push で `.github/workflows/deploy.yml` が自動実行され、`gh-pages` ブランチに成果物が反映されます。

### 4.1 通常のデプロイ

```bash
git checkout main
git pull origin main
# 変更をマージ後
git push origin main
```

→ GitHub Actions が自動で `client/dist/` をビルドし `gh-pages` へ反映します。

### 4.2 デプロイ状況の確認

- リポジトリの「Actions」タブで `Deploy to GitHub Pages` ワークフローの実行状況を確認
- 成功後、`gh-pages` ブランチに以下が更新されます：
  - `index.html`
  - `assets/`
  - `editor.html`

### 4.3 ロールバック

問題発生時は `gh-pages` ブランチを直前のコミットに戻します：

```bash
git checkout gh-pages
git reset --hard <previous-commit-sha>
git push origin gh-pages --force   # 要レビュー
```

---

## トラブルシューティング

### ビルドが失敗する

```bash
cd client
rm -rf node_modules package-lock.json
npm install
npm run build
```

### 型エラーが大量に出る

- `@types/react` と `react` のバージョンが揃っているか確認
- `tsconfig.app.json` の `lib` / `target` が新バージョンに対応しているか確認

### GitHub Actions のデプロイが失敗する

- `node-version` と `package.json` の `engines`（あれば）が一致しているか確認
- `npm ci` が失敗する場合は、ローカルで `package-lock.json` を再生成しコミット

### ベースパスが効かない

`vite.config.ts` の `base: '/main/'` はリポジトリ名に依存します。リポジトリ名を変更した場合はここも更新してください。

---

## 参考リンク

- [React](https://react.dev/)
- [Vite](https://vite.dev/)
- [TypeScript](https://www.typescriptlang.org/)
- [Tailwind CSS](https://tailwindcss.com/)
- [GitHub Pages](https://pages.github.com/)

---

## 問い合わせ

アップグレード手順について不明点や問題が発生した場合は、以下の方法でお問い合わせください。

### GitHub Issues

不具合報告・質問・改善提案は GitHub Issues でお願いします。

- リポジトリ: [shunjapanes/main](https://github.com/shunjapanes/main)
- Issues: [shunjapanes/main/issues](https://github.com/shunjapanes/main/issues)

Issue 起票時は以下を含めていただくとスムーズです：

- 実行した手順（コマンド全文）
- 期待した結果と実際の結果
- エラーメッセージ全文
- 環境情報
  - OS とバージョン
  - Node.js バージョン（`node -v`）
  - npm バージョン（`npm -v`）
  - 各依存パッケージのバージョン（`client/package.json` の該当箇所）

### Pull Request

修正案がある場合は、対象ブランチを切って Pull Request を作成してください。

```bash
git checkout -b fix/upgrade-<対象>
# 変更
git commit -m "fix: <修正内容>"
git push -u origin fix/upgrade-<対象>
```

### デバッグメモ

開発時に発見した不具合や調査メモは `debug-memos/` ディレクトリに記録する運用です。アップグレード作業中に気付いた問題も、ここにメモを残すと後の作業者の助けになります。

- 未対応のメモ: `debug-memos/*.md`
- 対応済みのメモ: `debug-memos/done/`
