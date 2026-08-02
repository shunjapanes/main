# コードレビューレポート 2026-08-02 — shunjapanes/main

## サマリー

- 実行日時: 2026-08-02 16:09 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 7件 (App.tsx, bridge.ts, FileTabBar.tsx, SearchBar.tsx, editor.html, sw.js)
- 発見件数: 🔴 Critical 0 / 🟠 High 4 / 🟡 Medium 9 / 🟢 Low 15 = 計28件
- うち新規 [NEW]: **8件** / 継続 [継続]: **20件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下に console.log / debugger 文なし）

### 前回比較（2026-08-01）

- 前回: 🔴 0 / 🟠 4 / 🟡 6 / 🟢 10 = 20件
- 今回: 🔴 0 / 🟠 4 / 🟡 9 / 🟢 15 = 28件
- High 4件は全て継続・未修正。新規指摘 8件（全て Medium/Low）を追加発見。

---

## セキュリティ所見（Agent A）

### 🟠 High

**[継続] S-PM: postMessage の origin 検証なし**
- 場所: `client/src/App.tsx:77`（受信側）、`client/src/lib/bridge.ts:3`（送信側）
- App.tsx の message ハンドラが `e.origin` を検証していない。任意のオリジンから status・stateSync・focusSearch 等のメッセージを注入可能。bridge.ts の `targetOrigin='*'` により、`openContent` 送信時にファイル内容が外部オリジンに漏洩する恐れがある。
- **修正案:** 送信側: `postMessage(data, window.location.origin)`。受信側: `if (e.origin !== window.location.origin) return` を先頭に追加。

**[継続] S-XSS: `javascript:` プロトコルが HTML プレビューの href を通過**
- 場所: `client/public/editor.html`（`renderHtmlValue` 関数）
- 備考列等の HTML レンダリング機能で `<a href="javascript:alert(1)">` がクリック可能なリンクとして挿入される。`escHtml()` は HTML 特殊文字をエスケープするが `javascript:` プロトコル自体は無害化しない。
- **修正案:** href 挿入前に `url.startsWith('http://') || url.startsWith('https://')` のホワイトリスト検証を追加。

### 🟡 Medium

**[継続] S-CSS: CSS インジェクション（`<font color>` のカラー値が style 属性に直接挿入）**
- 場所: `client/public/editor.html`（`renderHtmlValue` 関数）
- `<font color="red; position:fixed;top:0;left:0;width:100%;height:100%">` のような値が style 属性に展開され、任意の CSS プロパティを追記可能（UI 偽装・クリックジャッキング相当）。
- **修正案:** `CSS.supports('color', value)` でホワイトリスト検証してから style に挿入。

**[継続] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`、`client/public/editor.html`
- XSS が発生した場合の緩和層がゼロ。
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self';">` を追加。

**[NEW] S-SBX: editor iframe に sandbox 属性が未設定**
- 場所: `client/src/App.tsx:141-147`
- S-XSS が成立した場合、`window.parent` 経由で親フレームの DOM 操作・ナビゲーション（フレームハイジャック）・ステート読み取りが無制限に可能。sandbox は被害範囲を iframe 内に封じ込める多層防御として有効。
- **修正案:** `<iframe sandbox="allow-scripts allow-same-origin allow-downloads allow-modals" allow="clipboard-read; clipboard-write" ...>`

### 🟢 Low

**[継続] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html`（blob プレビュー内リンク）

**[継続] S-CI: deploy.yml の `permissions: contents: write` がワークフロー全体に適用**
- 場所: `.github/workflows/deploy.yml`

**[継続] S-SW: SW キャッシュバージョン固定（セキュリティパッチ不達リスク）**
- 場所: `client/public/sw.js:1`

**[NEW] S-POP: iframe に popups 権限を付与**
- 場所: `client/src/App.tsx:146`
- `allow="clipboard-read; clipboard-write; popups"` の `popups` が S-XSS と組み合わさるとタブナッピング攻撃に利用可能。
- **修正案:** 機能要件を確認の上、不要であれば `popups` を削除。

**[NEW] S-FT: ファイル種別検証がクライアントの accept 属性のみに依存**
- 場所: `client/src/App.tsx:105-115`
- drag-and-drop 等で accept 属性を迂回でき、任意のファイルを `readAsText` で読み込める。巨大ファイルや HTML ファイルを editor に渡すと S-XSS と連鎖する可能性がある。
- **修正案:** JS 側でも拡張子・MIME タイプ・ファイルサイズ（50MB 上限推奨）を検証。

---

## コード品質所見（Agent B）

### 🟡 Medium

**[継続] Q-ESL: SearchBar.tsx:24 の eslint-disable-next-line react-hooks/exhaustive-deps**
- 場所: `client/src/components/SearchBar.tsx:24`
- Q-HYBRID（下記 NEW）の修正により根本的に解消できる。

**[NEW] Q-HYBRID: SearchBar の「半制御」状態パターンが Q-ESL の根本原因**
- 場所: `client/src/components/SearchBar.tsx:13,20-24`
- 内部 `query` state と外部 `externalQuery` prop の両方を保持する半制御パターン。`useEffect` の deps から `query` を除外せざるを得ず Q-ESL の根本原因になっている。
- **修正案:** 完全制御（fully-controlled）パターンに統一。`value={externalQuery ?? ''}` + `onChange` で親が全状態を保持すれば Q-ESL も同時解消。

### 🟢 Low

**[継続] Q-CMD: App.tsx:68,70 — 冗長な `cmd &&` チェック**
- 場所: `client/src/App.tsx:68,70`
- L65 の `if (!cmd) return` で early return 済みなのに再確認している。

**[継続] Q-KEY: FileTabBar.tsx:19 — 配列インデックスを React key に使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- タブ中間削除時に React の reconciliation が誤動作する可能性。`tab.name` 等の安定したキー推奨。

**[継続] Q-DUP: Tab インターフェース重複定義**
- 場所: `client/src/App.tsx:8`、`client/src/components/FileTabBar.tsx:4`
- 同一の `interface Tab { name: string; dirty: boolean }` が 2 ファイルに存在。`types.ts` に切り出し推奨。

**[継続] Q-SORT: editor.html — sortAsc/sortDesc ブリッジの意図不明なプリセット**
- 場所: `client/public/editor.html`

**[継続] Q-SS: editor.html — save/saveAs が同一関数を呼ぶ**
- 場所: `client/public/editor.html`

**[継続] Q-ECH: bridge.ts:10 — 空の catch ブロック**
- 場所: `client/src/lib/bridge.ts:10`
- エラーを握りつぶしデバッグが困難。`// cross-origin focus may throw; intentionally ignored` 等のコメント追加推奨。

**[NEW] Q-ORIGIN: postMessage のワイルドカードオリジン（品質観点）**
- 場所: `client/src/lib/bridge.ts:3`、`client/src/App.tsx:72`
- S-PM と同根。品質観点でも `'*'` の使用は意図の明確化が必要。

---

## バグ・ロジックリスク（Agent C）

### 🟠 High

**[継続] B-FR: App.tsx の FileReader に onerror ハンドラなし**
- 場所: `client/src/App.tsx`（`handleFileSelected` 内）
- ファイル読み込み失敗時にユーザーへのフィードバックなしにサイレント失敗。
- **修正案:** `reader.onerror = () => send('status', { text: 'ファイルの読み込みに失敗しました' })` を追加。

**[継続] B-SORT: コンテキストメニューソートの `headerMode` チェック欠落（バグ確定）**
- 場所: `client/public/editor.html`（昇順/降順コンテキストメニューハンドラ）
- `sortByColumn` は `headerMode === "numbered"` でヘッダー行保護を正しく判定するが、コンテキストメニュー直接実装では `headerMode` チェックなしで `state.data[0]` を先頭固定にする。firstRow モード + 2行以上でデータ行が誤って先頭固定されたままソートされる。
- **修正案:** コンテキストメニューハンドラでも `state.headerMode === "numbered"` のチェックを使用するか `sortByColumn` へ一本化。

### 🟡 Medium

**[継続] B-PM: App.tsx の message ハンドラで origin を検証していない**
- 場所: `client/src/App.tsx:77`
- S-PM と同根（バグ観点での再掲）。editor.html 側は `e.source !== window.parent` チェック済みだが App.tsx 側は未対応。

**[継続] B-FRE: editor.html の FileReader に onerror なし（3箇所）**
- 場所: `client/public/editor.html`（`loadSejMasterFile`、`loadPriceRefFile`、画像ペーストハンドラ）
- 4インスタンス中1つ（2986行）は onerror 追加済み（前回比較で改善）。残り3箇所は未対応。

**[継続] B-SW: sw.js — キャッシュ未ヒット＋ネットワーク失敗時に undefined を返す**
- 場所: `client/public/sw.js:14`
- `.catch(() => cached)` が `undefined` を返し `respondWith` が TypeError を発生させる。オフライン時に新規リソースへアクセスするとアプリ全体がクラッシュする恐れがある。
- **修正案:** `.catch(() => cached || new Response('Offline', { status: 503 }))` に変更。

**[NEW] B-PO: bridge.ts が openContent（ファイル全内容）を `'*'` ターゲットで送信**
- 場所: `client/src/lib/bridge.ts:3`
- S-PM のバグ観点での具体的リスク明示。第三者ページに埋め込まれた場合、`payload.content` のファイル内容が外部オリジンに漏洩する。

### 🟢 Low

**[継続] B-SWC: SW キャッシュバージョン固定**
- 場所: `client/public/sw.js:1`

**[NEW] B-ROW: SearchBar.tsx の gotoRow が rowNum を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx`（`doGotoRow` 関数）
- エディタ側が数値として処理する場合、型強制の結果が実装依存。辞書順ソートリスク（`"10" < "9"` 等）。
- **修正案:** `send('gotoRow', parseInt(rowNum, 10))` に変更。

**[NEW] B-SB: SearchBar マウント時に空クエリ検索コマンドが自動送信される**
- 場所: `client/src/components/SearchBar.tsx`（query 依存 useEffect）
- 初期 `query=''` の場合、マウント後 180ms で `send('search', '')` が発火する。
- **修正案:** `query.length > 0` の場合のみ `send` を呼ぶか、初回マウントを useRef でスキップ。

---

## 適用済み自動修正

```diff
（なし）
```

src/ 配下・editor.html に `console.log` / `debugger` は存在しない。  
`console.warn` / `console.error` は全て operational なため変更しない。

---

## 推奨アクション（優先度順）

1. **[HIGH/継続] S-PM / B-PM / B-PO** — `bridge.ts:3` の targetOrigin を `window.location.origin` に変更、`App.tsx:77` に origin チェックを追加
2. **[HIGH/継続] S-XSS** — `editor.html` の `renderHtmlValue` で href URL をホワイトリスト検証（http/https のみ許可）
3. **[HIGH/継続] B-FR** — `App.tsx` の FileReader に `onerror` ハンドラ追加
4. **[HIGH/継続] B-SORT** — コンテキストメニューソートに `headerMode` チェックを追加（バグ確定）
5. **[MEDIUM/NEW] S-SBX** — `<iframe sandbox="allow-scripts allow-same-origin ...">` を追加（S-XSS の多層防御）
6. **[MEDIUM/継続] S-CSS** — `editor.html` の `<font color>` カラー値をホワイトリスト検証
7. **[MEDIUM/継続] S-CSP** — `index.html` / `editor.html` に CSP meta タグ追加
8. **[MEDIUM/継続] B-SW** — sw.js の `.catch(() => cached)` を `.catch(() => cached || Response.error())` に修正
9. **[MEDIUM/継続] B-FRE** — editor.html 残り3箇所の FileReader に `onerror` 追加
10. **[MEDIUM/NEW] Q-HYBRID** — SearchBar を完全制御パターンに統一（Q-ESL も同時解消）
