# コードレビューレポート 2026-07-07 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-07 UTC（自動レビュー）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 10件 (App.tsx, bridge.ts, RibbonToolbar.tsx, RibbonButton.tsx, RibbonGroup.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, client/package.json, debug-memos/)
- 発見件数: 🔴 Critical 1 / 🟠 High 6 / 🟡 Medium 7 / 🟢 Low 8
- うち新規 [NEW]: 2件 / 継続 [継続]: 20件
- 適用済み自動修正: **0件**（自動修正対象なし）
- ⚠️ **前回（07-06）から実質的なコード変更なし。S-1 Critical は 2ヶ月超未対応。B-1（Ctrl+Shift+Z redo 不動作）は1行修正で解決可能なまま放置中。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存 — 2ヶ月超未対応**
- 場所: `client/public/editor.html` — `dbmGetPat()` / `dbmSavePat()`
- `btoa` はエンコードであり暗号化ではない。`atob(localStorage.getItem(key))` で即座に PAT を取得可能。XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。`repo` スコープ相当の権限が漏洩リスク。
- **修正案:** Web Crypto API (AES-GCM) で暗号化してから保存。またはセッション限りのメモリ保持に変更し localStorage への永続化を廃止。

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（親→子）**
- 場所: `client/src/lib/bridge.ts:3`
- `iframe?.contentWindow?.postMessage({ action, payload }, '*')` — 任意オリジンに機密データ（ファイル内容 `openContent` 等）を送信。クロスオリジン環境で悪意あるページがメッセージを傍受可能。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に固定。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html`（リッチレンダリング `<a href>` 復元部分）
- `escHtml()` は HTML エンティティをエスケープするが `javascript:` スキームを通過させる。セル値に `javascript:alert(document.cookie)` を書き込みリンクをクリックすると XSS が実行される。
- **修正案:** `/^https?:\/\//i.test(url)` でホワイトリスト検証。`rel="noopener noreferrer"` を追加。

**[継続] S-4: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)` （エンコーディング引数なし = UTF-8 固定）
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。日本語主対象アプリとして影響が大きい。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM 検出で自動判定、またはUIでエンコーディング選択を提供。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — PAT入力UI含む**
- 場所: `client/src/components/RibbonToolbar.tsx` — `ToolsTab` 関数内の「デバッグ」グループ（`<RibbonGroup label="デバッグ">`）が `import.meta.env.DEV` ガードなし
- GitHub PAT 入力 UI を含むデバッグ機能が全ユーザーに公開。S-1 と組み合わさり PAT 漏洩の入口になる。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html`（リッチレンダリング部分）
- `escHtml` はセミコロン・コロン・スラッシュを変換しないため CSS exfiltration が可能。バックグラウンドリクエストでセッション情報が外部に漏洩するリスク。
- **修正案:** `const safeColor = /^(#[0-9a-fA-F]{3,8}|[a-zA-Z]+|rgb\(\d+,\s*\d+,\s*\d+\))$/.test(color) ? color : 'inherit';`

**[継続] S-7: iframe に sandbox 属性なし → XSS 時に親フレームをリダイレクト可能**
- 場所: `client/src/App.tsx:141-147`（`<iframe id="editor-frame" ...>` に sandbox なし）
- `sandbox` 属性がないため iframe 内から `window.parent.location` による強制リダイレクトが可能。XSS + フィッシング誘導の連鎖攻撃チェーン。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-downloads allow-modals"` を追加（`allow-top-navigation` は除外）。

---

### 🟡 Medium

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx:72-93` — `window.addEventListener('message', handler)` に origin チェックなし
- 悪意あるオリジンからのメッセージで UI 状態（`setStatus`・`setTabs` 等）が操作される可能性。
- **修正案:** ハンドラ冒頭に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合（レースコンディション）**
- 場所: `client/src/components/SearchBar.tsx:103-104`
  ```tsx
  onClick={() => { send('search', query); send('replaceOne', replaceText) }}
  ```
- `search` 完了前に `replaceOne` が実行され置換対象がずれる。debounce タイマーも未キャンセル。
- **修正案:** `replaceOne/All` に query を同梱した単一メッセージとして送信し、エディタ側でアトミックに処理。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/public/editor.html` / `client/index.html`
- CSP ヘッダー・メタタグが存在しない。S-3・S-6 が成功した場合、外部スクリプト読み込み・データ送信が無制限に行われる。
- **修正案:** `default-src 'self'; script-src 'self'; connect-src 'self' https://api.github.com; object-src 'none';` を設定。

**[継続] Q-1: console.warn / console.error 6件が本番コードに残存**
- 場所: `client/public/editor.html`（複数箇所）
- ユーザー環境のコンソールに内部状態（列名・オブジェクト構造）が漏洩する。
- **修正案:** Vite の `build.drop: ['console']` オプション適用。

**[継続] Q-2: focusEditor() が空の catch で失敗を握りつぶす**
- 場所: `client/src/lib/bridge.ts:7-12`
  ```ts
  export function focusEditor(): void {
    try {
      const iframe = ...
      iframe?.contentWindow?.focus()
    } catch {}
  }
  ```
- 呼び出し元が成否を知る手段がない。デバッグ困難。
- **修正案:** `catch (e) { if (import.meta.env.DEV) console.warn('[bridge] focusEditor failed:', e) }` を追加。

**[継続] B-1: Ctrl+Shift+Z redo が動作しない（`e.key` 大文字小文字バグ）**
- 場所: `client/src/App.tsx:65`
  ```tsx
  // バグ: ShiftキーでZを押すとブラウザは e.key = 'Z'（大文字）を返す
  } else if (cmd && ((e.key === 'z' && e.shiftKey) || e.key === 'y' || e.key === 'Y')) {
  ```
- `e.key === 'z' && e.shiftKey` は常に false。Ctrl+Shift+Z による redo が機能しない（1文字修正で解決）。
- **修正案:** `e.key === 'Z' && e.shiftKey` に変更。

**[継続] B-3: FileReader の `onerror` ハンドラが未定義**
- 場所: `client/src/App.tsx:109-115`
- ファイル読み込み失敗時（権限エラー・破損ファイル等）に UI 側で何も通知されない。
- **修正案:** `reader.onerror = () => setStatus('ファイルの読み込みに失敗しました');` を追加。

---

## コード品質所見

**[継続] Q-3: message ハンドラの型判別に `else if` が使われていない**
- 場所: `client/src/App.tsx:77-93`
- `msg.type` は判別共用体だが全条件を独立した `if` で評価。マッチ後も全条件を評価し続ける不要な処理が発生する。
- **修正案:** `else if` チェーンまたは `switch` 文に変更する。

**[NEW] Q-4: SearchBar の externalQuery 同期エフェクトにスタレクロージャーリスク**
- 場所: `client/src/components/SearchBar.tsx:22-27`
  ```tsx
  useEffect(() => {
    if (externalQuery !== undefined && externalQuery !== query) {
      setQuery(externalQuery)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [externalQuery]) // query が deps に含まれていない
  ```
- `query` が deps 配列に含まれないため、ユーザーが入力中に `clearSearch` イベントが届いた場合、古い `query` 値で `externalQuery !== query` を評価し同期が誤判定される可能性がある。
- **修正案:** `useRef` で最新の `query` を追跡するか、`externalQuery` を source of truth として `query` ローカル state を廃止し一元管理する。

---

## バグ・ロジックリスク

**[継続] B-2: `handleKeyDown` 内で `cmd &&` の冗長な二重チェック**
- 場所: `client/src/App.tsx:61-67`
- `if (!cmd) return` による早期リターン後も `if (cmd && ...)` と再評価。読み手を混乱させる。
- **修正案:** `cmd &&` 部分を除去。

**[継続] B-4: SearchBar 初期マウント時に不要な `search('')` が 180ms 後に送信される**
- 場所: `client/src/components/SearchBar.tsx:28-33`
- マウント時に debounce effect が `query = ''` で即実行され、editor.html の初期化前に `execSearch('')` が届く可能性がある。
- **修正案:** `isMounted` フラグで初回実行をスキップする。

**[継続] B-5: clearSearch が折り返し postMessage でデバウンスを二重発火させる**
- 場所: `client/public/editor.html` / `client/src/components/SearchBar.tsx:28-33`
- 親が `send('clearSearch')` → editor.html が折り返し postMessage → App.tsx → SearchBar の `setQuery('')` → debounce → `search('')` が再送される。
- **修正案:** `{ type: 'clearSearch', fromParent: true }` で起点を区別しループを抑制。

**[継続] B-6: FileTabBar のタブに配列インデックスを key として使用**
- 場所: `client/src/components/FileTabBar.tsx:20` — `key={i}`
- タブ削除時に React の差分アルゴリズムが誤ったノードを再利用し、フォーカス状態等にずれが生じる可能性がある。
- **修正案:** `Tab` インターフェースに `id: string` を追加し `key={tab.id}` に変更する。

**[継続] B-7: Service Worker のキャッシュバージョンが固定 → セキュリティ修正が既存ユーザーに届かない**
- 場所: `client/public/sw.js:1` — `CACHE = 'tsv-editor-v1'`
- バージョン名を変更しないかぎり既存ユーザーに旧 `editor.html` が配信され続ける。
- **修正案:** ビルド時にコンテンツハッシュで自動インクリメント（例: `tsv-editor-v${BUILD_HASH}`）。

**[NEW] B-8: gotoRow に行番号の上限値チェックなし**
- 場所: `client/src/components/SearchBar.tsx:39`
  ```tsx
  const doGotoRow = () => { if (rowNum) send('gotoRow', rowNum) }
  ```
- 入力は数字のみにフィルタリングされているが（`replace(/[^0-9]/g, '')`）、上限チェックがない。`9999999999` 等の極端に大きな数値をエディタに送信した場合、スクロール処理や配列アクセスで意図しない動作が起きる可能性がある。
- **修正案:** `const num = Math.min(parseInt(rowNum, 10), MAX_ROWS_LIMIT); if (!isNaN(num)) send('gotoRow', num);`

---

## 適用済み自動修正

**なし。** 前回レビューまでに console.log は削除済み。残存する console.warn/error は editor.html 内の意図的なエラーハンドラと判断し、ロジック変更を避けるため自動修正対象外とした。

---

## 推奨アクション（優先度順）

1. **🔴 即対応** — **S-1**: PAT の btoa 保存を廃止し、Web Crypto (AES-GCM) またはセッション変数に移行（2ヶ月超未対応）
2. **🟡 1行修正** — **B-1**: `e.key === 'z' && e.shiftKey` → `e.key === 'Z' && e.shiftKey` に変更（Ctrl+Shift+Z redo 不動作バグ）
3. **🟠 早期対応** — **S-2**: `bridge.ts` の `postMessage` targetOrigin を `window.location.origin` に変更
4. **🟠 早期対応** — **S-3**: `javascript:` URL をホワイトリスト検証（1行修正）
5. **🟠 早期対応** — **S-5**: `ToolsTab` の「デバッグ」グループを `import.meta.env.DEV` でガード
6. **🟠 早期対応** — **S-7**: `App.tsx` の iframe に `sandbox` 属性を追加
7. **🟡 今週中** — **S-8**: `App.tsx` の postMessage handler に `e.origin` チェックを追加
8. **🟡 今週中** — **S-10**: Vite 設定に CSP ヘッダーを追加
9. **🟡 今週中** — **B-3**: `reader.onerror` ハンドラを追加
10. **🟢 余裕時** — **Q-4**: SearchBar の externalQuery 同期を useRef ベースに改善

---

## 依存パッケージ状況

```json
"react": "^19.0.0"      // 最新メジャー — OK
"vite": "^6.0.5"        // 最新安定版 — OK
"@playwright/test": "1.56.1"  // ピン留め — 更新確認推奨
"typescript": "~5.6.2"  // 5.x系 — OK
```

特筆すべき脆弱パッケージなし（2026-07-07 時点）。
