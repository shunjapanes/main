# コードレビューレポート 2026-07-09 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-09 UTC（自動レビュー）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 7件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, client/package.json)
- 発見件数: 🔴 Critical 1 / 🟠 High 6 / 🟡 Medium 9 / 🟢 Low 8
- うち新規 [NEW]: 2件 / 継続 [継続]: 23件
- 適用済み自動修正: **0件**（自動修正対象なし）
- ⚠️ **最終コード変更: 2026-07-02。S-1 Critical は約1週間以上未対応。B-1（Ctrl+Shift+Z redo 不動作）は1行修正で解決可能なまま放置中。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存**
- 場所: `client/public/editor.html:9057-9061` — `dbmGetPat()` / `dbmSavePat()`
- `btoa` はエンコードであり暗号化ではない。`atob(localStorage.getItem(key))` で即座に PAT を取得可能。XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。
- **修正案:** Web Crypto API (AES-GCM) で暗号化してから保存。またはセッション限りのメモリ保持に変更し localStorage への永続化を廃止。

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（親→子）**
- 場所: `client/src/lib/bridge.ts:3`
- `postMessage({ action, payload }, '*')` により、ファイル内容やユーザーデータを含むメッセージが任意オリジンに傍受されうる。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に固定。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html:7790`
- `escHtml()` は `&<>"'` をエスケープするが `javascript:` スキームを通過させる。
- **修正案:** `/^https?:\/\//i.test(url)` でホワイトリスト検証。`rel="noopener noreferrer"` を追加。

**[継続] S-4: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx` — `reader.readAsText(file)` （エンコーディング引数なし = UTF-8 固定）
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM 検出で自動判定。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — PAT入力UI含む**
- 場所: `client/src/components/RibbonToolbar.tsx` — `ToolsTab` 関数内の「デバッグ」グループに `import.meta.env.DEV` ガードなし
- S-1 と組み合わさり PAT 漏洩の入口になる。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html:7794` — `<span style="color:${escHtml(q || nq || "")}">`
- `escHtml` はセミコロン・コロン・スラッシュを変換しないため CSS exfiltration が可能。
- **修正案:** `const safeColor = /^(#[0-9a-fA-F]{3,8}|[a-zA-Z]+|rgb\(\d+,\s*\d+,\s*\d+\))$/.test(color) ? color : 'inherit';`

**[継続] S-7: iframe に sandbox 属性なし → XSS 時に親フレームをリダイレクト可能**
- 場所: `client/src/App.tsx`（`<iframe id="editor-frame" ...>`）
- `sandbox` 属性がないため iframe 内から `window.parent.location` による強制リダイレクトが可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads"` を最小許可セットで追加（`allow-top-navigation` は除外）。

---

### 🟡 Medium

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx`（message イベントハンドラ）
- 悪意あるオリジンからのメッセージで UI 状態が操作される可能性。
- **修正案:** ハンドラ冒頭に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合（レースコンディション）**
- 場所: `client/src/components/SearchBar.tsx` 置換ボタン onClick
- `search` 完了前に `replaceOne` が実行され置換対象がずれる可能性。
- **修正案:** エディタ側から searchReady 応答を受け取ってから replace を送信するコールバック方式に変更。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/public/editor.html` / `client/index.html`
- CSP ヘッダー・メタタグが存在しない。S-3・S-6 成功時に外部スクリプト・データ送信が無制限。
- **修正案:** `default-src 'self'; script-src 'self'; connect-src 'self' https://api.github.com; object-src 'none';`

**[NEW] S-11: allow="popups" による iframe へのポップアップ権限付与（sandbox なしと組み合わせ）**
- 場所: `client/src/App.tsx` — `<iframe allow="clipboard-read; clipboard-write; popups">`
- sandbox による制限がなく、かつ popups が許可されているため、editor.html 内で XSS が発生した場合に `window.open()` で任意 URL のフィッシングウィンドウを開ける具体的な攻撃経路が形成される。S-7（sandbox なし）単独より実害リスクが増大。
- **修正案:** 業務上不要であれば allow 属性から `popups` を削除。必要な場合は sandbox 側で `allow-popups` として明示し allow= 側の重複を除去。

---

## コード品質所見

**[継続] Q-1: console.warn / console.error 8件が本番コードに残存**
- 場所: `client/public/editor.html:7891,7893,9031,9048,9524,9557` 等
- 内部状態が本番コンソールに漏洩する。
- **修正案:** Vite の `build.drop: ['console']` オプション適用。

**[継続] Q-2: focusEditor() が空の catch で失敗を握りつぶす**
- 場所: `client/src/lib/bridge.ts:7-11` — `catch {}`
- focus() が SecurityError 等で失敗しても完全に無視される。
- **修正案:** `catch (e) { if (import.meta.env.DEV) console.warn('[bridge] focusEditor failed:', e) }`

**[継続] Q-3: message ハンドラの型判別に `else if` が使われていない**
- 場所: `client/src/App.tsx` — message イベントハンドラ
- マッチ後も全条件を評価し続ける不要な処理。
- **修正案:** `else if` チェーンまたは `switch` 文に変更。

**[継続] Q-4: SearchBar の externalQuery 同期エフェクトにスタレクロージャーリスク**
- 場所: `client/src/components/SearchBar.tsx:22-27` — `query` が deps 配列に含まれていない
- externalQuery の変化タイミングにより古い query との比較が誤ってスキップされる恐れ。
- **修正案:** `setQuery` を関数形式 `setQuery(prev => externalQuery !== prev ? externalQuery : prev)` に変更し query を依存配列から除外。

**[継続] Q-5: `unescape()` 使用（非推奨 API）**
- 場所: `client/public/editor.html:9264` — `const mdBase64 = btoa(unescape(encodeURIComponent(md)));`
- `unescape()` は ECMAScript 仕様で deprecated。将来の JS エンジンで削除リスク。
- **修正案:** `const bytes = new TextEncoder().encode(md); const mdBase64 = btoa(String.fromCharCode(...bytes));`

---

## バグ・ロジックリスク

**[継続] B-1: Ctrl+Shift+Z redo が動作しない（`e.key` 大文字小文字バグ）**
- 場所: `client/src/App.tsx`
  ```tsx
  } else if (cmd && ((e.key === 'z' && e.shiftKey) || e.key === 'y' || e.key === 'Y')) {
  ```
- Shift 押下時はブラウザが `e.key = 'Z'`（大文字）を返す。`e.key === 'z' && e.shiftKey` は常に false。
- **修正案:** `(e.key === 'z' && e.shiftKey)` → `((e.key === 'z' || e.key === 'Z') && e.shiftKey)` に変更（1〜2文字修正）。

**[継続] B-2: `handleKeyDown` 内で `cmd &&` の冗長な二重チェック**
- 場所: `client/src/App.tsx`
- `if (!cmd) return` による早期リターン後も `if (cmd && ...)` と再評価。

**[継続] B-3: FileReader の `onerror` ハンドラが未定義**
- 場所: `client/src/App.tsx` — `handleFileSelected`
- ファイル読み込み失敗時に UI 側で何も通知されない。
- **修正案:** `reader.onerror = () => setStatus('ファイルの読み込みに失敗しました');` を追加。

**[継続] B-4: SearchBar 初期マウント時に不要な `search('')` が 180ms 後に送信される**
- 場所: `client/src/components/SearchBar.tsx`
- **修正案:** `isMounted` フラグで初回実行をスキップ。

**[継続] B-5: clearSearch が折り返し postMessage でデバウンスを二重発火させる**
- 場所: `client/public/editor.html` / `client/src/components/SearchBar.tsx`
- **修正案:** `{ type: 'clearSearch', fromParent: true }` で起点を区別しループを抑制。

**[継続] B-6: FileTabBar のタブに配列インデックスを key として使用**
- 場所: `client/src/components/FileTabBar.tsx` — `key={i}`
- タブ削除時に React が誤ったノードを再利用する可能性。
- **修正案:** `Tab` に `id: string` を追加し `key={tab.id}` に変更。

**[継続] B-7: Service Worker のキャッシュバージョンが固定 → セキュリティ修正が既存ユーザーに届かない**
- 場所: `client/public/sw.js:1` — `CACHE = 'tsv-editor-v1'`
- **修正案:** ビルド時コンテンツハッシュで自動インクリメント。

**[継続] B-8: gotoRow に行番号の上限値チェックなし**
- 場所: `client/src/components/SearchBar.tsx` — `doGotoRow()`
- `if (rowNum)` は falsy チェックのみで上限バリデーションなし。
- **修正案:** `const num = Math.min(parseInt(rowNum, 10), MAX_ROWS_LIMIT); if (!isNaN(num)) send('gotoRow', num);`

**[NEW] B-9: Enter キー後の `searchNext/Prev` を 30ms 固定遅延で送信するレース条件**
- 場所: `client/src/components/SearchBar.tsx` — Enter キーハンドラ
  ```tsx
  send('search', query)
  setTimeout(() => send(e.shiftKey ? 'searchPrev' : 'searchNext'), 30)
  ```
- 30ms はエディタ側（iframe内）が検索インデックスを確定させるのを保証しない任意値。大きな CSV ではナビゲーションが「ヒットなし」と誤判定される。
- **修正案:** エディタ側から `searchReady` 応答を受け取ってから `searchNext/Prev` を送信するコールバック方式に変更。

---

## 適用済み自動修正

```diff
（なし）
```

前回レビューまでに console.log は削除済み。残存する console.warn/error は editor.html 内の意図的なエラーハンドラと判断し、ロジック変更を避けるため自動修正対象外とした。

---

## 推奨アクション（優先度順）

1. **🔴 即対応** — **S-1**: PAT の btoa 保存を廃止し Web Crypto (AES-GCM) またはセッション変数に移行
2. **🟡 1行修正** — **B-1**: `e.key === 'z' && e.shiftKey` → `(e.key === 'z' || e.key === 'Z') && e.shiftKey` に変更
3. **🟠 早期対応** — **S-2**: `bridge.ts` の `postMessage` targetOrigin を `window.location.origin` に変更
4. **🟠 早期対応** — **S-3**: `javascript:` URL をホワイトリスト検証（1行修正）
5. **🟠 早期対応** — **S-5**: `ToolsTab` の「デバッグ」グループを `import.meta.env.DEV` でガード
6. **🟠 早期対応** — **S-7**: `App.tsx` の iframe に `sandbox` 属性を追加（+ allow="popups" を削除: S-11）
7. **🟡 今週中** — **S-8**: postMessage handler に `e.origin` チェックを追加
8. **🟡 今週中** — **S-10**: CSP ヘッダーを追加
9. **🟡 今週中** — **B-3**: `reader.onerror` ハンドラを追加
10. **🟡 今週中** — **B-9**: searchNext/Prev の 30ms 固定遅延を応答駆動コールバックに変更 [NEW]
11. **🟢 余裕時** — **Q-4**: externalQuery 同期を関数形式 setQuery に変更
12. **🟢 余裕時** — **Q-5**: `unescape()` を `TextEncoder` ベースに置換

---

## 依存パッケージ状況

```json
"react": "^19.0.0"           // 最新メジャー — OK
"vite": "^6.0.5"             // 最新安定版 — OK
"@playwright/test": "1.56.1" // ピン留め — 更新確認推奨
"typescript": "~5.6.2"       // 5.x系 — OK
```

特筆すべき脆弱パッケージなし（2026-07-09 時点）。
