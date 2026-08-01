# コードレビューレポート 2026-08-01 — shunjapanes/main

## サマリー

- 実行日時: 2026-08-01 16:08 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite 6.4.3 + Tailwind)
- レビューファイル数: 10件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, RibbonButton.tsx, sw.js, StatusBar.tsx, editor.html, sw.js)
- 発見件数: 🔴 Critical 0 / 🟠 High 4 / 🟡 Medium 6 / 🟢 Low 10 = 計20件
- うち新規 [NEW]: **12件** / 継続 [継続]: **5件** / 部分修正 [部分修正]: **1件** / 解消 [FIXED]: **2件**
- 適用済み自動修正: **0件**（src配下・editor.html に console.log / debugger 文なし、console.warn/error は全て operational）

### 解消（FIXED）
- **S-1（Critical）**: GitHub PAT の localStorage 保存 → sessionStorage に変更済み ✅（約51日間の指摘、解消）
- **S-17（High）**: vite 6.4.2 の既知 CVE → 6.4.3 にアップグレード済み ✅

---

## セキュリティ所見

### 🟠 High

**[継続] S-PM: postMessage の origin 検証なし**
- 場所: `client/src/App.tsx:77` (受信側), `client/src/lib/bridge.ts:3` (送信側)
- `App.tsx` の message ハンドラは `e.origin` も `e.source` も確認せず、任意の外部ウィンドウからタブ情報・ステータス・検索状態を偽装可能
- editor.html 側は `e.source !== window.parent` チェックが追加されたが、origin 検証ではない
- **修正案:** 送信側: `postMessage(data, location.origin)` に変更。受信側: `if (e.origin !== location.origin) return` を先頭に追加。

**[NEW] S-XSS: `javascript:` プロトコルが HTML プレビューの href を通過**
- 場所: `client/public/editor.html` 約 L7787-7790（`renderHtmlValue` 関数）
- 備考列等の HTML レンダリング機能で `<a href="javascript:alert(1)">text</a>` のようなセルデータが、blob プレビュー内にクリック可能なリンクとして挿入される
- `escHtml()` は HTML 特殊文字をエスケープするが `javascript:` プロトコル自体は無害化しない
- **修正案:** URL を `href` に挿入する前に `url.startsWith('http://') || url.startsWith('https://')` のホワイトリスト検証を追加。

### 🟡 Medium

**[NEW] S-CSS: CSS インジェクション（`<font color>` のカラー値が style 属性に直接挿入）**
- 場所: `client/public/editor.html` 約 L7793-7794（`renderHtmlValue` 関数）
- `<font color="red; position:fixed;top:0;left:0;width:100%;height:100%">` のような値が style 属性に展開され、任意の CSS プロパティを追記可能（UI 偽装・クリックジャッキング相当）
- **修正案:** カラー値を `/#[0-9a-fA-F]{3,6}/` または `/^[a-z]+$/` で検証してから style に挿入。

**[NEW] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`, `client/public/editor.html`（共に CSP meta タグなし）
- 上記 XSS が発生した場合の緩和層がゼロ
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src https://api.github.com;">` を追加（`unsafe-inline` は段階的に除去）

### 🟢 Low

**[NEW] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html` L7790, L7803（blob プレビュー内リンク）
- 現代ブラウザは implicit noopener を付与するが明示が推奨
- **修正案:** `rel="noopener noreferrer"` を追加

**[NEW] S-CI: deploy.yml の `permissions: contents: write` がワークフロー全体に適用**
- 場所: `.github/workflows/deploy.yml` L7 相当
- gh-pages 用途なら適切だが、ジョブレベルで絞れるとリスクが下がる

**[継続] S-SW: SW キャッシュバージョン固定（セキュリティパッチ不達リスク）**
- 場所: `client/public/sw.js:1` — `const CACHE = 'tsv-editor-v1'`
- **修正案:** Vite ビルドハッシュをキャッシュ名に含める

---

## コード品質所見

### 🟡 Medium

**[継続] Q-ESL: SearchBar.tsx:24 の eslint-disable-next-line react-hooks/exhaustive-deps**
- 場所: `client/src/components/SearchBar.tsx:24`
- `useRef` で前回の `externalQuery` を追跡すれば suppress なしで記述可能

### 🟢 Low

**[NEW] Q-CMD: App.tsx:66,68 — 冗長な `cmd &&` チェック**
- 場所: `client/src/App.tsx:63-68`
- L63 で `if (!cmd) return` により早期リターン済みなのに L66/68 で再度 `if (cmd && ...)` を確認している

**[NEW] Q-KEY: FileTabBar.tsx:19 — 配列インデックスを React key に使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- タブ中間削除時に React の reconciliation が誤動作する可能性。`${i}-${tab.name}` 等の安定したキー推奨

**[NEW] Q-DUP: Tab インターフェース重複定義**
- 場所: `client/src/App.tsx:8`, `client/src/components/FileTabBar.tsx:4`
- 同一の `interface Tab { name: string; dirty: boolean }` が 2 ファイルに存在。共通 types.ts に切り出し推奨

**[NEW] Q-SORT: editor.html — sortAsc/sortDesc ブリッジの意図が不明なプリセット**
- 場所: `client/public/editor.html` L9431-9444
- `sortAsc` で `state.sortAsc = false` をセット後 `sortByColumn` を呼ぶと内部トグルにより昇順になる。意図が読めず変更耐性がゼロ
- **修正案:** コメントで明記するか `sortByColumn(col, { force: 'asc' })` のような明示 API に変更

**[NEW] Q-SS: editor.html — save/saveAs が同一関数を呼ぶ**
- 場所: `client/public/editor.html` L9418-9419
- `save` と `saveAs` が共に `saveFile()` を呼ぶ（ダウンロードダイアログで別名保存可能という設計）。意図をコメントで明記推奨

**[NEW] Q-ECH: bridge.ts:10 — 空の catch ブロック**
- 場所: `client/src/lib/bridge.ts:10`
- クロスオリジン iframe フォーカス失敗を意図的に無視しているなら `// cross-origin focus may throw; intentionally ignored` 等のコメント追加推奨

---

## バグ・ロジックリスク

### 🟠 High

**[継続] B-FR: FileReader に onerror ハンドラがない（App.tsx）**
- 場所: `client/src/App.tsx:108-115` の `handleFileSelected`
- ファイル読み込み失敗時にユーザーへのフィードバックなしにサイレント失敗
- **修正案:** `reader.onerror = () => send('status', 'ファイルの読み込みに失敗しました')` を追加

**[NEW] B-SORT: sortAsc/sortDesc の暗黙的二重否定ロジック**
- 場所: `client/public/editor.html` L9431-9444
- `sortByColumn` の「同列ならトグル」ロジックに完全依存しており、`sortByColumn` 内部変更で昇順・降順が即逆転するリスク。現状は動作するが変更耐性がゼロ

### 🟡 Medium

**[部分修正] B-PM: App.tsx message ハンドラの origin 未検証**
- 場所: `client/src/App.tsx:77`
- editor.html 側は `e.source !== window.parent` チェックに改善済み（前回指摘より改善）。App.tsx 側は未対応

**[NEW] B-FRE: editor.html の FileReader に onerror なし（3箇所）**
- 場所: `editor.html` L7835（`loadSejMasterFile`）、L8004（`loadPriceRefFile`）、L9131（dbm 画像ペースト）
- いずれもファイル読み込み失敗でサイレント失敗

**[NEW] B-SW: sw.js — キャッシュ未ヒット時にネットワーク失敗で undefined を respondWith に渡す**
- 場所: `client/public/sw.js:13`
- `cached = undefined` かつネットワーク失敗時、`.catch(() => cached)` が `undefined` を返し意図と齟齬
- **修正案:** `.catch(() => cached || Response.error())`

### 🟢 Low

**[継続] B-SWC: SW キャッシュバージョン固定**
- 場所: `client/public/sw.js:1`
- 前出 S-SW と同一

---

## 適用済み自動修正

```diff
（なし）
```

src/ 配下・editor.html に `console.log` / `debugger` は存在しない。  
`console.warn` / `console.error` は全て operational（SW 登録失敗、ファイル読み込み失敗、SEJ マスタ異常、bridge エラー）なため変更しない。

---

## 推奨アクション（優先度順）

1. **[HIGH/NEW] S-XSS** — `editor.html` の `renderHtmlValue` で href URL をホワイトリスト検証（http/https のみ許可）
2. **[HIGH/継続] S-PM / B-PM** — `App.tsx:77` に `if (e.origin !== location.origin) return` を追加、`bridge.ts:3` の targetOrigin を `location.origin` に変更
3. **[HIGH/NEW] B-SORT** — sortAsc/sortDesc ブリッジに明示的なコメントを追加（または force 引数対応）
4. **[HIGH/継続] B-FR** — `App.tsx:108` の FileReader に `onerror` ハンドラ追加
5. **[MEDIUM/NEW] S-CSS** — `editor.html` の `<font color>` カラー値をホワイトリスト検証
6. **[MEDIUM/NEW] S-CSP** — `index.html` / `editor.html` に CSP meta タグ追加
7. **[MEDIUM/NEW] B-FRE** — editor.html 3箇所の FileReader に `onerror` 追加
8. **[MEDIUM/NEW] B-SW** — sw.js の `.catch(() => cached)` を `.catch(() => cached || Response.error())` に修正
9. **[LOW] Q-KEY** — FileTabBar.tsx の key を安定したキーに変更
10. **[LOW] Q-DUP** — Tab インターフェースを types.ts に統一
