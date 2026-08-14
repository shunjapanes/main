# コードレビューレポート 2026-08-14 — shunjapanes/main

## サマリー

- 実行日時: 2026-08-14 01:30 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, vite.config.ts)
- 発見件数: 🔴 Critical 2 / 🟠 High 5 / 🟡 Medium 18 / 🟢 Low 8 = 計33件
- うち新規 [NEW]: **3件** / 継続 [継続]: **30件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下・editor.html に console.log / console.error / debugger 文なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| ℹ️ 変更なし | 2026-07-22 の修正以降、ソースコードへの新規コミットなし。_review/*.md のみ更新。 |
| ℹ️ 継続中 | 前回 (2026-08-13) 指摘の全42件のうち30件が未修正のまま継続中 |
| 🆕 新規発見 | Agent A: S-POPUP（allow="popups"の潜在リスク）、Agent B: Q-ORIGIN・Q-MSGSRC（postMessage関連）の計3件 |
| 📌 重要度変更 | S-PM・S-XSS を High → **Critical** に昇格（攻撃シナリオをより詳細に分析した結果） |

---

## セキュリティ所見（Agent A）

### 🔴 Critical

**[継続] S-PM: postMessage の origin 検証なし（送受信両方）**
- 場所: `client/src/lib/bridge.ts:3`（送信側）、`client/src/App.tsx:77`（受信側）
- `postMessage({ action, payload }, '*')` — 任意オリジンに送信。受信側も `e.origin` チェックなし。クロスオリジンフレームが任意のアクション（undo/replace等）を注入またはデータを傍受可能。
- **修正案（送信）:** `postMessage(data, window.location.origin)`
- **修正案（受信）:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] S-XSS: `javascript:` プロトコルが HTML プレビューの href を通過（XSS）**
- 場所: `client/public/editor.html` — `renderHtmlValue` isHtml 処理
- `escHtml()` は HTML 実体変換を行うが `javascript:` スキームは通過し、`innerHTML` に注入される。クリック時にアプリ同一オリジン上でスクリプトが実行され DOM/localStorage に完全アクセス可能。
- **修正案:** `if (!/^https?:\/\//i.test(url)) return escHtml(text)` を追加、`rel="noopener noreferrer"` 付与。

---

### 🟠 High

**[継続] S-SBX: editor iframe に sandbox 属性が未設定**
- 場所: `client/src/App.tsx:141`
- sandbox 未指定のため iframe 内 XSS → 親フレームリダイレクト・任意ポップアップ・window.parent 呼び出し・localStorage アクセスが可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-modals allow-popups allow-clipboard-read allow-clipboard-write"` を追加（`allow-top-navigation` は除外）。

**[継続] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`、`client/public/editor.html`
- CSP ヘッダーもメタタグも存在しない。インラインスクリプト・eval・外部リソースが無制限で、ブラウザ標準の XSS 緩和層が欠如。
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;">` を追加。

**[継続] S-CLIP: clipboard-read 権限による iframe からのクリップボード窃取リスク**
- 場所: `client/src/App.tsx:143` — `allow="clipboard-read; clipboard-write; popups"`
- iframe が侵害された場合、ユーザーのクリップボード（パスワード・APIキー等）をサイレントに読み取り可能。
- **修正案:** `clipboard-read` を allow 属性から削除（clipboard-write は残す）。

---

### 🟡 Medium

**[NEW] S-POPUP: `allow="popups"` が iframe に無制限のポップアップ能力を付与**
- 場所: `client/src/App.tsx:143` — `allow="clipboard-read; clipboard-write; popups"`
- `window.open()` が editor.html から任意 URL で呼び出し可能。editor.html で XSS が発生した場合、タブナビング（opener タブをフィッシングページへリダイレクト）やバックグラウンドでの悪意あるタブ開封が可能になる。S-SBX（sandbox 未設定）とは独立した積極的な権限付与。
- **修正案:** editor.html が明示的にウィンドウ開放を必要としない場合は `popups` を allow リストから削除。

**[継続] S-CSS: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html` — isHtml セル `renderHtmlValue`
- **修正案:** `CSS.supports('color', value)` または `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-FN: OS 由来の file.name をサニタイズせず postMessage ペイロードに含める**
- 場所: `client/src/App.tsx:112`
- パストラバーサル文字列や HTML 特殊文字がエスケープなしにエディタへ到達。
- **修正案:** `/[^\w.\- ]/g` で除去するホワイトリストバリデーションを送信前に適用。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- **修正案:** `searchCount` 応答受信後に replace を発行するコールバック方式に変更。

**[継続] S-SW: SW キャッシュバージョン固定（セキュリティパッチ不達リスク）**
- 場所: `client/public/sw.js:1` — `const CACHE = 'tsv-editor-v1'`
- 加えて `.catch(() => cached)` が undefined を返し得る（→ B-SW 参照）。
- **修正案:** Vite ビルドハッシュをキャッシュ名に含める。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx` — `ToolsTab` 内 `RibbonGroup label="デバッグ"`
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

---

### 🟢 Low

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`
- Shift-JIS/EUC-JP ファイルで文字化け・データ破損リスク。

**[継続] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html` — blob プレビュー内リンク

---

## コード品質所見（Agent B）

### 🟠 High

**[継続] Q-NOERR: FileReader.onerror ハンドラ未設定**
- 場所: `client/src/App.tsx:83–87`
- ファイル読み込みエラー時のフィードバックがなく失敗が無音でドロップされる。
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] Q-MULTI: 連続 send() — ACKなし連続送信**
- 場所: `client/src/components/SearchBar.tsx:52–53, 62–63`
- `send('search', query); send('replaceOne', replaceText)` 等、受信側の処理順序依存。競合状態でデータ破損リスク。

---

### 🟡 Medium

**[NEW] Q-ORIGIN: postMessage のターゲットオリジンがワイルドカード**
- 場所: `client/src/lib/bridge.ts:3`
- `postMessage({ action, payload }, '*')` はページ上の任意オリジンがメッセージを受信できる。
- **修正案:** `postMessage(data, window.location.origin)` に変更。

**[NEW] Q-MSGSRC: message イベントハンドラで e.origin を検証していない**
- 場所: `client/src/App.tsx:78`
- e.data の型のみチェック。クロスオリジンのフレームや広告スクリプトが clearSearch・replaceAll 等を任意に発火できる。
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ冒頭に追加。

**[継続] Q-TAB-TYPE: `Tab` インターフェースの重複定義**
- 場所: `client/src/App.tsx:19` および `client/src/components/FileTabBar.tsx:3`
- **修正案:** `src/types.ts` 等の共有モジュールに移動。

**[継続] Q-REF: SearchBar 内部 `query` state が外部 `externalQuery` を二重管理**
- 場所: `client/src/components/SearchBar.tsx`

**[継続] Q-TYPE: `EditorMessage` の全フィールドがオプショナル**
- 場所: `client/src/App.tsx:16–20`
- **修正案:** discriminated union 型に変更。

**[継続] Q-KEY: FileTabBar.tsx:19 — 配列インデックスを React key に使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- **修正案:** `${i}-${tab.name}` 等の安定したキー推奨。

**[継続] Q-ESL: SearchBar.tsx:24 の eslint-disable-next-line react-hooks/exhaustive-deps**
- 場所: `client/src/components/SearchBar.tsx:24`

**[継続] Q-CATCH: bridge.ts:8 — 空 catch ブロック**
- 場所: `client/src/lib/bridge.ts:8`
- **修正案:** `catch (_e) { /* cross-origin focus blocked — expected */ }` のようにコメントを付ける。

**[継続] Q-TIMER: SearchBar.tsx:51 — Enter キー時の setTimeout がアンマウント時未クリア**
- 場所: `client/src/components/SearchBar.tsx:51`
- **修正案:** `useRef` で保持し cleanup 関数でクリア。

**[継続] Q-CMD: App.tsx:66,68 — 冗長な `cmd &&` チェック**
- 場所: `client/src/App.tsx:63-68`

**[継続] Q-TOGGLE: App.tsx — `!!` を6フィールド分繰り返し**
- 場所: `client/src/App.tsx:75–80`

**[継続] Q-DOM: bridge.ts — `getElementById` をコール毎に重複実行**
- 場所: `client/src/lib/bridge.ts:2,7`

---

### 🟢 Low

**[継続] Q-NULLABLE: App.tsx:87 — `content != null` のルーズ等値比較**
- 場所: `client/src/App.tsx:87`

**[継続] Q-MAGIC: SearchBar.tsx:51 — マジックナンバー `30`**
- 場所: `client/src/components/SearchBar.tsx:51`

**[継続] Q-TITLE: iframe title がハードコード**
- 場所: `client/src/App.tsx:94`

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

**[継続] S-9/B-REPLACE: 置換ボタンが search 完了前に replaceOne/All を送信**
- 場所: `client/src/components/SearchBar.tsx:103-108`

**[継続] B-SW: Service Worker fetch catch が `undefined` を返す可能性**
- 場所: `client/public/sw.js:10-12`
- `.catch(() => cached)` は `cached` が未定義の場合 `undefined` を返し、`respondWith(undefined)` はエラーとなる。
- **修正案:** `.catch(() => cached || new Response('Network error', {status: 503}))` とフォールバックを明示。

---

### 🟢 Low

**[継続] B-SYNC: stateSync の `!!` 強制キャスト**
- 場所: `client/src/App.tsx:75–80`

**[継続] B-DEBOUNCE: SearchBar — 外部クリア時にも debounce 経由で `send('search', '')` が発火**
- 場所: `client/src/components/SearchBar.tsx:29-38`

**[継続] B-TAB: FileTabBar — 配列インデックスをキーに使用**
- 場所: `client/src/components/FileTabBar.tsx:19`

**[継続] B-FOCUS: focusEditor() の空 catch**
- 場所: `client/src/lib/bridge.ts:8`

---

## 適用済み自動修正

```diff
（なし — console.log / console.error / debugger 文はソースコードに存在しないため修正対象なし）
```

---

## 推奨アクション（優先度順）

1. **[CRITICAL] S-PM + Q-ORIGIN + Q-MSGSRC**: `postMessage` targetOrigin を `window.location.origin` に変更、受信側に `e.origin` チェック追加 — 2箇所の1行変更
2. **[CRITICAL] S-XSS**: `renderHtmlValue` の href に `https?:` ホワイトリスト検証を追加
3. **[HIGH] S-CLIP**: `allow` 属性から `clipboard-read` を削除 — 1行変更、即座に実施可能
4. **[HIGH] S-SBX**: iframe に `sandbox` 属性を追加（`allow-top-navigation` を除いた最小権限）
5. **[NEW/MEDIUM] S-POPUP**: `allow` 属性から `popups` を削除（必要な機能か確認の上）
6. **[HIGH] B-13**: `if (tag === 'IFRAME') return` に INPUT/TEXTAREA ガードを追加 — 1行変更
7. **[HIGH] S-CSP**: `index.html` / `editor.html` に Content-Security-Policy meta タグを追加
8. **[NEW/MEDIUM] Q-MSGSRC**: `e.origin` チェックを message ハンドラ冒頭に追加
9. **[MEDIUM] B-SW**: Service Worker の catch フォールバックを `Response('...', {status:503})` に修正
10. **[MEDIUM] Q-TAB-TYPE**: `Tab` 型を共有モジュールに統一
