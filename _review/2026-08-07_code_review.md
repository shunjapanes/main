# コードレビューレポート 2026-08-07 — shunjapanes/main（第2回 16:13 UTC）

## サマリー

- 実行日時: 2026-08-07 16:13 UTC（自動レビュー・3エージェント並列・第2回）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 7件 (App.tsx, bridge.ts, SearchBar.tsx, RibbonButton.tsx, RibbonToolbar.tsx, FileTabBar.tsx, client/package.json)
- 発見件数: 🔴 Critical 0 / 🟠 High 5 / 🟡 Medium 13 / 🟢 Low 21 = 計39件
- うち新規 [NEW]: **10件** / 継続 [継続]: **29件**
- 適用済み自動修正: **0件**（src配下に console.log / debugger 文なし）

### 前回比較（2026-08-07 00:27 UTC 第1回）

- 第1回: 🔴 0 / 🟠 4 / 🟡 9 / 🟢 16 = 29件
- 今回: 🔴 0 / 🟠 5 / 🟡 13 / 🟢 21 = 39件
- 新規指摘 10件（High 1件・Medium 4件・Low 5件）を追加発見
- 解消 [FIXED]: 0件

---

## セキュリティ所見（Agent A）

### 🟠 High

**[継続] S-PM: postMessage の origin 検証なし**
- 場所: `client/src/App.tsx:77`（受信側）、`client/src/lib/bridge.ts:3`（送信側）
- `window.addEventListener('message', handler)` が `e.origin` を一切チェックしない。bridge.ts の `postMessage` も引き続き第2引数 `'*'`（ワイルドカード）を使用。任意のオリジンから status・stateSync・focusSearch 等のメッセージを注入可能。
- **修正案:** 送信側: `postMessage(data, window.location.origin)`。受信側: `if (e.origin !== window.location.origin) return` を先頭に追加。

**[継続] S-XSS: `javascript:` プロトコルが HTML プレビューの href を通過**
- 場所: `client/public/editor.html`（`renderHtmlValue` 関数）
- **修正案:** href 挿入前に `url.startsWith('http://') || url.startsWith('https://')` のホワイトリスト検証を追加。

**[NEW] S-CLIP: clipboard-read 権限による iframe からのクリップボード読み取り許可**
- 場所: `client/src/App.tsx:143`
- `allow="clipboard-read; clipboard-write; popups"` の clipboard-read は、iframe コンテンツがユーザーの許可確認なしにクリップボードを読み取れる Permissions Policy を付与する。iframe が XSS 等で侵害された場合、ユーザーがコピーしたパスワード・APIキー・個人情報をサイレントに窃取できる。S-POP（popups 権限）とは独立した脅威。
- **修正案:** clipboard-read を allow 属性から削除する。貼り付け操作が必要な場合は clipboard-write のみ残す。

### 🟡 Medium

**[継続] S-CSS: CSS インジェクション（`<font color>` のカラー値が style 属性に直接挿入）**
- 場所: `client/public/editor.html`（`renderHtmlValue` 関数）
- **修正案:** `CSS.supports('color', value)` でホワイトリスト検証してから style に挿入。

**[継続] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`、`client/public/editor.html`
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self';">` を追加。

**[継続] S-SBX: editor iframe に sandbox 属性が未設定**
- 場所: `client/src/App.tsx:141`
- **修正案:** `<iframe sandbox="allow-scripts allow-same-origin allow-downloads allow-modals" allow="clipboard-read; clipboard-write" ...>`

**[NEW] S-FN: OS 由来の file.name をサニタイズせず postMessage ペイロードに含める**
- 場所: `client/src/App.tsx:112`
- `send('openContent', { content, filename: file.name })` にて、ファイルシステム由来の file.name を無加工で iframe に転送。ファイル名に `<script>alert(1)</script>` のような文字列が含まれる場合、受信側の editor.html が filename をそのまま innerHTML 等で描画すると XSS になる。
- **修正案:** 送信前に filename を英数字・ドット・アンダースコア・ハイフン・スペースに限定するホワイトリストバリデーションを適用（例: `/[^\w.\- ]/g` を除去）。

### 🟢 Low

**[継続] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html`（blob プレビュー内リンク）

**[継続] S-CI: deploy.yml の `permissions: contents: write` がワークフロー全体に適用**
- 場所: `.github/workflows/deploy.yml`

**[継続] S-SW: SW キャッシュバージョン固定（セキュリティパッチ不達リスク）**
- 場所: `client/public/sw.js:1` — `const CACHE = 'tsv-editor-v1'`

**[継続] S-POP: iframe に popups 権限を付与**
- 場所: `client/src/App.tsx:143`

**[継続] S-FT: ファイル種別検証がクライアントの accept 属性のみに依存**
- 場所: `client/src/App.tsx:105-115`

**[継続] S-FSZ: ファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx:104`
- **修正案:** `if (file.size > 10 * 1024 * 1024) { alert('ファイルが大きすぎます'); return; }` を追加。

---

## コード品質所見（Agent B）

### 🟡 Medium

**[継続] Q-ESL: SearchBar.tsx:24 の eslint-disable-next-line react-hooks/exhaustive-deps**
- 場所: `client/src/components/SearchBar.tsx:24`

**[継続] Q-HYBRID: SearchBar の「半制御」状態パターンが Q-ESL の根本原因**
- 場所: `client/src/components/SearchBar.tsx:13,20-24`
- **修正案:** fully-controlled パターンに統一。`value={externalQuery ?? ''}` + `onChange` で親が全状態を保持。

**[継続] Q-CURSOR: RibbonButton.tsx — Tailwind カーソルクラスの競合**
- 場所: `client/src/components/RibbonButton.tsx:15,19`
- `base` クラスに常に `cursor-pointer` が含まれ、disabled 時に `cursor-not-allowed` が追加されるが両方が共存。
- **修正案:** `base` から `cursor-pointer` を除外し、非 disabled パスにのみ追加。

**[NEW] Q-ENCODE: readAsText にエンコーディング指定なし**
- 場所: `client/src/App.tsx:107`
- `reader.readAsText(file)` はデフォルトで UTF-8 として読み込む。日本語 TSV/CSV では Shift-JIS (CP932) ファイルが広く流通しており、エンコーディング未指定のまま読み込むと文字化けが発生する。
- **修正案:** エンコーディング選択 UI を設けるか、少なくとも `reader.readAsText(file, 'UTF-8')` と明記して意図を残す。理想: ドロップダウン等で Shift-JIS / UTF-8 を選択可能にする。

**[NEW] Q-ARIA: トグル状態の RibbonButton に aria-pressed がない**
- 場所: `client/src/components/RibbonButton.tsx:26-34`
- `active` prop によって視覚的なトグル状態（緑背景）が表現されるが、`aria-pressed` 属性が付与されていないため、スクリーンリーダーはオン/オフを識別できない。filterActive・wrapActive 等のトグルボタン全体に影響する。
- **修正案:** `<button ... aria-pressed={active ?? false}>` を追加。

### 🟢 Low

**[継続] Q-CMD: App.tsx:66,68 — 冗長な `cmd &&` チェック**

**[継続] Q-KEY: FileTabBar.tsx:19 — 配列インデックスを React key に使用**

**[継続] Q-DUP: Tab インターフェース重複定義**
- 場所: `client/src/App.tsx:8`、`client/src/components/FileTabBar.tsx:4`

**[継続] Q-ECH: bridge.ts:10 — 空の catch ブロック**

**[継続] Q-ORIGIN: postMessage のワイルドカードオリジン（品質観点）**

**[継続] Q-DBLDIS: RibbonButton.tsx — onClick 条件と disabled 属性の二重ガード**

**[継続] Q-MOUNT: SearchBar.tsx — 初回マウント時に search('') を送信**
- 場所: `client/src/components/SearchBar.tsx:27-33`

**[NEW] Q-ROWTYPE: gotoRow に string 型の rowNum を送信**
- 場所: `client/src/components/SearchBar.tsx:40`
- `rowNum` は `useState('')` で string として管理され、`send('gotoRow', rowNum)` でそのまま送信される。エディタ側が数値型を期待している場合、暗黙の型契約になっている。
- **修正案:** `if (rowNum) send('gotoRow', Number(rowNum))`

**[NEW] Q-EQEQ: `!= null` 緩い等値比較**
- 場所: `client/src/App.tsx:105`
- `if (content != null)` は `eqeqeq` ESLint ルールの対象。意図が不明確。
- **修正案:** `content !== null && content !== undefined` と明示するか、`content !== null` に統一。

**[NEW] Q-ELEMCAST: document.activeElement の不要な HTMLElement キャスト**
- 場所: `client/src/App.tsx:58`
- `(document.activeElement as HTMLElement)?.tagName` の型キャストは不要。`.tagName` は `Element` インターフェースに存在する。
- **修正案:** `const tag = document.activeElement?.tagName`

---

## バグ・ロジックリスク（Agent C）

### 🟠 High

**[継続] B-TAB: tabs メッセージで activeTab が送られない場合、インデックス不整合が発生**
- 場所: `client/src/App.tsx:83`
- **修正案:** `tabs` 更新時は必ず `activeTab` もセットする、またはエディタ側プロトコルで保証する。

**[継続] B-ASYNC: SearchBar.tsx:61 — 30ms の固定遅延で searchNext を送信**
- 場所: `client/src/components/SearchBar.tsx:61`
- **修正案:** editor 側から `searchReady` 応答を受け取ってから送信する応答ドリブン方式に変更。

### 🟡 Medium

**[継続] B-FILE: App.tsx — FileReader の onerror が未設定**
- 場所: `client/src/App.tsx:108-113`
- **修正案:** `reader.onerror = () => setStatus('ファイルの読み込みに失敗しました')` を追加。

**[継続] B-NULL: bridge.ts — iframe が存在しない場合のサイレント失敗**
- 場所: `client/src/lib/bridge.ts:2-3`

**[継続] N-STATESYNC: App.tsx — 部分的な stateSync メッセージが全トグル状態をリセット**
- 場所: `client/src/App.tsx:91-98`
- **修正案:** `setToggles(prev => ({ ...prev, ...(msg.filterActive !== undefined && { filterActive: !!msg.filterActive }), ... }))` のように prev をスプレッドして存在するフィールドのみ上書き。

**[NEW] N-REPLACE-EMPTY: 空クエリのまま replaceOne / replaceAll が送信される**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- query が空文字列の状態で置換ボタンをクリックすると `send('search', '')` → `send('replaceOne'/'replaceAll', replaceText)` が連続送信される。空文字検索はすべてのセルにマッチしうるため、意図せず全セルの内容が replaceText で上書きされる危険がある。
- **修正案:** `onClick={() => { if (!query) return; send('search', query); send('replaceOne', replaceText) }}`

### 🟢 Low

**[継続] N-ENTER-TIMEOUT-LEAK: SearchBar.tsx:61 — Enter キー時 setTimeout の ID が保存されない**

**[継続] N-REPLACE-RACE: SearchBar.tsx:103-108 — search と replaceOne/replaceAll のレース**

**[継続] N-CLEARSEARCH-ECHO: clearSearch メッセージが search('') を誘発**

**[NEW] N-GOTO-ZERO: gotoRow に '0' が送信されうる境界値不正**
- 場所: `client/src/components/SearchBar.tsx` — `doGotoRow` 関数
- onChange で `/[^0-9]/` を除去するため '0' は有効な文字列として残る。`if (rowNum)` は '0' を truthy として通過し `send('gotoRow', '0')` が発行される。エディタが 1-indexed の場合、行 0 は無効インデックスとなる。
- **修正案:** `if (Number(rowNum) > 0)` に強化する。

**[NEW] N-FILEREADER-ABORT: FileReader の onabort ハンドラが未設定**
- 場所: `client/src/App.tsx:100-112`
- FileReader.abort() が呼ばれた場合、onabort が発火するが未設定のためサイレント失敗。UI ステータスが「ファイル読込中」のまま残る可能性がある。
- **修正案:** `reader.onabort = () => setStatus('ファイル読み込みがキャンセルされました')` を追加。

---

## 適用済み自動修正

```diff
（なし — src配下に console.log / console.error / debugger 文なし）
```

---

## 推奨アクション（優先度順）

1. **[最優先] S-CLIP の修正**（High・新規）: `allow` 属性から `clipboard-read` を削除。クリップボード内容の漏洩リスクを即時排除できる最小コスト修正。
2. **[最優先] S-PM + S-XSS の修正**（High × 2・継続）: `postMessage` の origin 検証追加 + `javascript:` href ホワイトリスト化。
3. **N-REPLACE-EMPTY の修正**（Medium・新規）: 空クエリ時の置換ボタン無効化。全セル上書きというデータ破壊につながる操作を防ぐ。
4. **Q-ENCODE の対応**（Medium・新規）: 日本語 Shift-JIS ファイルの文字化けはエンドユーザーへの直接的な影響が大きい。エンコーディング選択 UI の追加を推奨。
5. **B-TAB + N-STATESYNC の修正**（High/Medium・継続）: タブ・トグル状態の不整合を解消。
6. **Q-ARIA の追加**（Medium・新規）: `aria-pressed` 付与でアクセシビリティを改善。
7. **S-SBX の追加**（Medium・継続）: iframe に `sandbox` 属性を付与して XSS の被害範囲を封じ込める。
8. **N-GOTO-ZERO の修正**（Low・新規）: 行ジャンプの境界値チェック強化（`Number(rowNum) > 0`）。一行修正で完了。
9. **S-FN の修正**（Medium・新規）: filename のサニタイズ追加。
10. **B-FILE + N-FILEREADER-ABORT の修正**（Medium/Low・継続/新規）: FileReader の onerror + onabort 追加でユーザーへのエラー通知を実装。
