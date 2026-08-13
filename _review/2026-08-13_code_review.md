# コードレビューレポート 2026-08-13 — shunjapanes/main

## サマリー

- 実行日時: 2026-08-13 16:13 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, vite.config.ts)
- 発見件数: 🔴 Critical 0 / 🟠 High 5 / 🟡 Medium 14 / 🟢 Low 23 = 計42件
- うち新規 [NEW]: **9件** / 継続 [継続]: **33件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下・editor.html に console.log / console.error / debugger 文なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| ℹ️ 変更なし | 2026-07-22 の修正以降、ソースコードへの新規コミットなし。_review/*.md のみ更新。 |
| ℹ️ 継続中 | 前回 (2026-08-11) 指摘の全39件が未修正のまま継続中 |
| 🆕 新規発見 | Agent B が品質・バグ領域で9件の新規問題を発見 |

---

## セキュリティ所見（Agent A）

### 🔴 Critical

**（なし）**

---

### 🟠 High

**[継続] S-PM: postMessage の origin 検証なし（送受信両方）**
- 場所: `client/src/lib/bridge.ts:3`（送信側）、`client/src/App.tsx:77`（受信側）
- `postMessage({ action, payload }, '*')` — 任意オリジンに送信。受信側も `e.origin` チェックなし。
- **修正案（送信）:** `postMessage(data, window.location.origin)`
- **修正案（受信）:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] S-XSS: `javascript:` プロトコルが HTML プレビューの href を通過（XSS）**
- 場所: `client/public/editor.html` — `renderHtmlValue` isHtml 処理
- `escHtml()` は HTML 実体変換を行うが `javascript:` スキームは通過し、`innerHTML` に注入される。
- **修正案:** `if (!/^https?:\/\//i.test(url)) return escHtml(text)` を追加、`rel="noopener noreferrer"` 付与。

**[継続] S-CLIP: clipboard-read 権限による iframe からのクリップボード窃取リスク**
- 場所: `client/src/App.tsx:143` — `allow="clipboard-read; clipboard-write; popups"`
- iframe が侵害された場合、ユーザーのクリップボード（パスワード・APIキー等）をサイレントに読み取り可能。
- **修正案:** `clipboard-read` を allow 属性から削除（clipboard-write は残す）。

**[継続] S-SBX: editor iframe に sandbox 属性が未設定**
- 場所: `client/src/App.tsx:141`
- sandbox 未指定のため iframe 内 XSS → 親フレームリダイレクト・任意ポップアップが可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-modals allow-popups allow-clipboard-read allow-clipboard-write"` を追加（`allow-top-navigation` は除外）。

**[継続] B-13: Ctrl+Z/Y が検索 INPUT フォーカス中も editor.html に転送される**
- 場所: `client/src/App.tsx:64-65` — `if (tag === 'IFRAME') return` のみ（INPUT/TEXTAREA ガードなし）
- 検索バーで Ctrl+Z を押すと入力テキストの undo ではなくエディタへ undo が転送される。
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

---

### 🟡 Medium

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx` — `ToolsTab` 内 `RibbonGroup label="デバッグ"`
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`
- Shift-JIS/EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** ArrayBuffer + TextDecoder + BOM 検出でエンコーディング自動判定。

**[継続] S-CSS: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html` — isHtml セル `renderHtmlValue`
- **修正案:** `CSS.supports('color', value)` または `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`、`client/public/editor.html`
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;">` を追加。

**[継続] S-FN: OS 由来の file.name をサニタイズせず postMessage ペイロードに含める**
- 場所: `client/src/App.tsx:112`
- **修正案:** `/[^\w.\- ]/g` で除去するホワイトリストバリデーションを送信前に適用。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- **修正案:** `searchCount` 応答受信後に replace を発行するコールバック方式に変更。

---

### 🟢 Low

**[継続] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html` — blob プレビュー内リンク

**[継続] S-SW: SW キャッシュバージョン固定（セキュリティパッチ不達リスク）**
- 場所: `client/public/sw.js:1` — `const CACHE = 'tsv-editor-v1'`
- **修正案:** Vite ビルドハッシュをキャッシュ名に含める

---

## コード品質所見（Agent B）

### 🟠 High

**（なし）**

---

### 🟡 Medium

**[NEW] Q-TAB-TYPE: `Tab` インターフェースの重複定義**
- 場所: `client/src/App.tsx:19` および `client/src/components/FileTabBar.tsx:3`
- 同一 `Tab` 型が2ファイルに独立定義。変更時に片方の更新漏れが生じる。
- **修正案:** `src/types.ts` 等の共有モジュールに移動し、両ファイルからインポートする。

**[継続] Q-REF: SearchBar 内部 `query` state が外部 `externalQuery` を二重管理**
- 場所: `client/src/components/SearchBar.tsx`
- 単一ソース化が望ましい。

**[継続] Q-TYPE: `EditorMessage` の全フィールドがオプショナル — 判別共用体として型を絞るべき**
- 場所: `client/src/App.tsx:16–20`
- **修正案:** `type EditorMessage = { type: 'status'; text: string } | { type: 'tabs'; tabs: Tab[]; activeTab: number } | ...` の形式で絞る。

**[継続] Q-NOERR: FileReader.onerror ハンドラ未設定**
- 場所: `client/src/App.tsx:83–87`
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] Q-KEY: FileTabBar.tsx:19 — 配列インデックスを React key に使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- タブ中間削除時に React の reconciliation が誤動作する可能性。
- **修正案:** `${i}-${tab.name}` 等の安定したキー推奨。

**[継続] Q-ESL: SearchBar.tsx:24 の eslint-disable-next-line react-hooks/exhaustive-deps**
- 場所: `client/src/components/SearchBar.tsx:24`
- `useRef` で前回の `externalQuery` を追跡すれば suppress なしで記述可能。

**[継続] Q-MULTI: 連続 send() — ACKなし連続送信**
- 場所: `client/src/components/SearchBar.tsx:52–53, 62–63`
- `send('search', query); send('replaceOne', replaceText)` 等、受信側の処理順序依存。

---

### 🟢 Low

**[NEW] Q-NULLABLE: App.tsx:87 — `content != null` のルーズ等値比較**
- 場所: `client/src/App.tsx:87`
- `content !== null && content !== undefined` か、`typeof content === 'string'` ガードに統一。

**[NEW] Q-CATCH: bridge.ts:8 — 空 catch ブロック**
- 場所: `client/src/lib/bridge.ts:8`
- `catch (_e) { /* cross-origin focus blocked — expected */ }` のようにコメントを付けて意図を明示。

**[NEW] Q-TIMER: SearchBar.tsx:51 — Enter キー時の setTimeout がアンマウント時未クリア**
- 場所: `client/src/components/SearchBar.tsx:51`
- `setTimeout(..., 30)` の戻り値が保持されず、アンマウント後も `send` が呼ばれる可能性あり。
- **修正案:** `useRef` で保持し cleanup 関数でクリア。

**[NEW] Q-MAGIC: SearchBar.tsx:51 — マジックナンバー `30`**
- 場所: `client/src/components/SearchBar.tsx:51`
- `const SEARCH_SETTLE_MS = 30` のような定数化+コメントを推奨。

**[継続] Q-CMD: App.tsx:66,68 — 冗長な `cmd &&` チェック**
- 場所: `client/src/App.tsx:63-68`
- L63 で `if (!cmd) return` により早期リターン済みなのに再チェック。

**[継続] Q-TOGGLE: App.tsx — `!!` を6フィールド分繰り返し**
- 場所: `client/src/App.tsx:75–80`
- `Object.fromEntries` 等で簡略化可。

**[継続] Q-TITLE: iframe title がハードコード**
- 場所: `client/src/App.tsx:94`
- アクティブタブ名を反映させるとアクセシビリティが向上。

**[NEW] Q-DOM: bridge.ts — `getElementById` をコール毎に重複実行**
- 場所: `client/src/lib/bridge.ts:2,7`
- モジュールレベルでキャッシュするとDOMクエリを削減できる（HMR環境での注意は必要）。

---

## バグ・ロジックリスク（Agent C）

### 🔴 Critical

**（なし）**

---

### 🟠 High

**[継続] B-13: Ctrl+Z/Y が INPUT/TEXTAREA フォーカス中も editor に転送される（UXバグ）**
- 場所: `client/src/App.tsx:64-65`
- `if (tag === 'IFRAME') return` のみガード。INPUT/TEXTAREAフォーカス中に Ctrl+Z を押すと、ユーザーの入力テキストの undo ではなくエディタの undo が発動する。
- **修正案:** `if (['IFRAME','INPUT','TEXTAREA'].includes(tag)) return;`

---

### 🟡 Medium

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:62`
- 高負荷時に search 処理が30msで完了しない場合、searchPrev/Next が空の結果セットに対して実行される。
- **修正案:** `searchCount` 受信後に next/prev を送るコールバック方式に変更。

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx:110` — `ev.target?.result as string`
- **修正案:** `if (typeof result === 'string') { ... }` ガードを追加。

**[継続] B-8: FileReader に onerror ハンドラなし**
- 場所: `client/src/App.tsx`
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] S-9: 置換ボタンが search 完了前に replaceOne/All を送信（競合）**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- 特に低速端末で、replaceAll が古い検索結果に対して実行される可能性。

**[NEW] B-SW: Service Worker fetch catch が `undefined` を返す可能性**
- 場所: `client/public/sw.js:10-12`
- `.catch(() => cached)` は `cached` が未定義の場合（キャッシュにもネットワークにもない）`undefined` を返し、`respondWith(undefined)` はエラーとなる。
- **修正案:** `.catch(() => cached || new Response('Network error', {status: 503}))` とフォールバックを明示。

---

### 🟢 Low

**[継続] B-SYNC: stateSync の `!!` 強制キャスト**
- 場所: `client/src/App.tsx:75–80`
- エディタが誤った型の値を送った場合（例: 数値）、`!!0 === false` となり意図と異なる可能性。明示的な型チェックを推奨。

**[継続] B-DEBOUNCE: SearchBar — 外部クリア時にも debounce 経由で `send('search', '')` が発火**
- 場所: `client/src/components/SearchBar.tsx:29-38`
- `externalQuery` が `''` に変わると → `setQuery('')` → debounce → `send('search', '')` のラウンドトリップ。
- エディタが `clearSearch` を送った直後に `search('')` が返り、不要な検索実行が発生する。

**[継続] B-TAB: FileTabBar — 配列インデックスをキーに使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- タブ中間削除時に React の reconciliation が誤動作する可能性。

**[継続] B-FOCUS: focusEditor() の空 catch**
- 場所: `client/src/lib/bridge.ts:8`
- クロスオリジン制約以外のエラーも無音で消える。

---

## 適用済み自動修正

```diff
（なし — console.log / console.error / debugger 文はソースコードに存在しないため修正対象なし）
```

---

## 推奨アクション（優先度順）

1. **[HIGH] S-CLIP**: `allow` 属性から `clipboard-read` を削除 — 1行変更、即座に実施可能
2. **[HIGH] B-13**: `if (tag === 'IFRAME') return` に INPUT/TEXTAREA ガードを追加 — 1行変更、検索バー操作の UX バグ修正
3. **[HIGH] S-PM**: `postMessage` targetOrigin を `window.location.origin` に変更、受信側に origin チェック追加
4. **[HIGH] S-SBX**: iframe に `sandbox` 属性を追加（`allow-top-navigation` を除いた最小権限）
5. **[MEDIUM] S-CSP**: `index.html` / `editor.html` に Content-Security-Policy meta タグを追加
6. **[MEDIUM] S-XSS**: `renderHtmlValue` の href に `https?:` ホワイトリスト検証を追加
7. **[MEDIUM] Q-TAB-TYPE**: `Tab` 型を共有モジュールに統一
8. **[MEDIUM] B-SW**: Service Worker の catch フォールバックを `Response('...', {status:503})` に修正
9. **[LOW] S-5**: デバッググループを `import.meta.env.DEV` でゲート
10. **[LOW] Q-NOERR / B-8**: FileReader.onerror ハンドラを追加
