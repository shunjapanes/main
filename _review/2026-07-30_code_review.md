# コードレビューレポート 2026-07-30 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-30 16:10 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 7件 (App.tsx, bridge.ts, SearchBar.tsx, FileTabBar.tsx, RibbonToolbar.tsx, package.json, _review前回比較)
- 発見件数: 🔴 Critical 0 / 🟠 High 9 / 🟡 Medium 20 / 🟢 Low 35 = 計64件
- うち新規 [NEW]: **2件** / 継続 [継続]: **62件** / 解消 [FIXED]: **1件**
- 適用済み自動修正: **0件**（src配下に console.log / console.error / debugger 文なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| ✅ S-18 [FIXED] | @babel/core が 7.29.0 に更新され GHSA-4x5r-pxfx-6jf8 解消（fix threshold: 7.26.10） |
| 🆕 S-28 [NEW] High | iframe の `allow` 属性が sandbox なしで `clipboard-read` と `popups` を許可 — XSS (S-3) と組み合わさるとクリップボード盗取・タブナッピングが成立 |
| 🆕 Q-N-20 [NEW] Low | editor → clearSearch → SearchBar内 query='' → debounce → send('search','') の意図しないラウンドトリップ |
| ℹ️ src変更なし | 2026-07-22 以降、src/ への新規コミットなし（8日間停止中） |

---

## セキュリティ所見

### 🔴 Critical

**（なし）**

---

### 🟠 High

**[NEW] S-28: iframe の `allow` 属性が sandbox なしで `clipboard-read` と `popups` を許可**
- 場所: `client/src/App.tsx` — `<iframe allow="clipboard-read; clipboard-write; popups">`
- `clipboard-read` が許可されているため、S-3 の javascript: XSS が editor.html で実行された場合、攻撃者は `navigator.clipboard.readText()` でユーザーのクリップボード（パスワード・トークン・PII等）を即座に外部送信できる。`popups` は `window.open()` を許可するためタブナッピング（opener の location を差し替えてフィッシングページへ誘導）が可能。いずれも S-7 (sandbox なし) が未修正のため複合的に深刻化。
- **修正案:** `allow` から `clipboard-read` と `popups` を削除し `clipboard-write` のみ残す。同時に S-7 の sandbox 追加（`sandbox="allow-scripts allow-same-origin allow-downloads allow-clipboard-write"`）で popup 権限をデフォルト剥奪。

**[継続] S-27: GitHub PAT (repo スコープ) が sessionStorage に保存されており S-3 の javascript: XSS 経由で1クリック漏洩**
- 場所: `client/public/editor.html:9061` (sessionStorage.setItem), `:7790` (href URL 無検証)
- S-28 が加わったことで攻撃チェーンがより完成に近づいた（XSS → PAT → clipboard → repo 書き込み権限）。
- **修正案:** ①S-3 の javascript: ブロック。②PAT をモジュール変数のみに保持してセッションリロードのたびに再入力。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html:7790` — `renderHtmlValue` の isHtml セル処理
- S-27・S-28 の前提脆弱性。**修正案:** `const u = new URL(url, location.href); if (!['http:','https:'].includes(u.protocol)) return escHtml(text);`

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子）**
- 場所: `client/src/lib/bridge.ts:3`
- **修正案:** `postMessage(msg, new URL(iframe.src, location.href).origin)`

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx` — `ToolsTab` 関数内 `<RibbonGroup label="デバッグ">`
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx`
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-clipboard-write"`

**[継続] B-13: Ctrl+Z/Y が検索 INPUT 欄フォーカス中も editor.html に送信される**
- 場所: `client/src/App.tsx:64–65` — `if (tag === 'IFRAME') return` のみで INPUT/TEXTAREA チェックなし
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

**[継続] S-24: regex モードで `new RegExp(q)` が無制限実行 → ReDoS**
- 場所: `client/public/editor.html:5919`, `:5931`, `:7170`
- **修正案:** 入力長上限（200文字）＋実行タイムアウト追加。

**[継続] S-25: editor.html の window.parent.postMessage が全て `'*'`**
- 場所: `client/public/editor.html` — 9505, 9539, 9589, 9599, 9609, 9615, 9626, 9630, 9653 行
- **修正案:** `window.parent.postMessage(msg, location.origin)` に統一。

---

### 🟡 Medium

**[継続] S-8: App.tsx message ハンドラが `e.origin` を未検証**
- **修正案:** `if (e.origin !== window.location.origin) return;`

**[継続] S-12: editor.html がソースチェックのみで origin 未検証**
- `e.source !== window.parent` チェックはあるが `e.origin` は未検証。親が XSS 経由で乗っ取られると通過する。
- **修正案:** `e.origin` チェックを追加。

**[継続] Q-N-18: stateSync で省略フィールドが `false` に上書きされる**
- 場所: `client/src/App.tsx:90–99` — `!!(msg.xxx)` で全フィールドを再構築、undefined → false 変換が発生
- **修正案:** `setToggles(prev => ({ ...prev, ...(msg.filterActive !== undefined && { filterActive: msg.filterActive }), ... }))`

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html:7794`
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103,107`

**[継続] S-10: Content-Security-Policy (CSP) の欠如**

**[継続] S-13: Service Worker がキャッシュファーストのためセキュリティパッチを配信不可**

**[継続] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**
- **修正案:** `return cached || Response.error()`

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- **修正案:** `if (file.size > 100 * 1024 * 1024) { setStatus('ファイルが大きすぎます'); return; }`

**[継続] S-21: サニタイズされていない file.name が postMessage 経由で editor.html に転送される**

**[継続] S-22: SW が GitHub API の GET レスポンスを無制限にキャッシュ**

**[継続] S-23: replaceText が未サニタイズのまま postMessage で editor.html に転送される**

**[継続] S-26: `target="_blank"` に `rel="noopener noreferrer"` がない（タブナッピング）**

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- 場所: `client/src/lib/bridge.ts:10` — `catch {}`

**[継続] Q-3: message ハンドラの型判別に switch が使われていない**
- 場所: `client/src/App.tsx:70–90` — 8個の連続 `if (msg.type === ...)`

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（stale closure）**
- 場所: `client/src/components/SearchBar.tsx:25`

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:62`

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx:110`

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**
- 場所: `client/src/components/SearchBar.tsx:20–25`

**[継続] B-7: doGotoRow が行番号を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41` — Fix: `send('gotoRow', Number(rowNum))`

**[継続] B-8: FileReader に onerror ハンドラなし**
- 場所: `client/src/App.tsx:108`

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない（X ボタン）**
- 場所: `client/src/components/SearchBar.tsx:69`

**[継続] B-12: SearchBar で IME コンポジション中に検索が発火（日本語入力が壊れる）**
- 場所: `client/src/components/SearchBar.tsx:54` — `onChange` に isComposing ガードなし

**[継続] B-16: Escape キーがデバウンスタイマーをキャンセルしない**
- 場所: `client/src/components/SearchBar.tsx:63`

**[継続] B-17: Enter キーが IME コンポジション中に searchNext を発火**
- 場所: `client/src/components/SearchBar.tsx:57–62`

---

### 🟢 Low

**[NEW] Q-N-20: clearSearch ラウンドトリップ — editor→clearSearch→SearchBar setQuery('')→debounce→send('search','') が180ms後に発火**
- 場所: `client/src/components/SearchBar.tsx` — `useEffect([externalQuery])` → `useEffect([query])` の連鎖
- editor が clearSearch を送信 → App が searchQuery='' に設定 → SearchBar の内部 query が非空だった場合 `setQuery('')` が発火 → debounce effect が 180ms 後に `send('search', '')` を editor に送り返す意図しないラウンドトリップ。editor が `search('')` をクリア済みでも無害な no-op として扱う場合は問題ないが、二重処理による点滅リスクがある。
- **修正案:** `suppressSendRef = useRef(false)` フラグで externalQuery 由来の setQuery をスキップするか、SearchBar を完全制御コンポーネント化。

**[継続] B-4: FileTabBar タブ本体が `<div>` でキーボード操作不可**
- 場所: `client/src/components/FileTabBar.tsx:18`

**[継続] B-11: FileTabBar key={i} — タブ削除時に React 差分アルゴリズムが誤認**
- 場所: `client/src/components/FileTabBar.tsx:19`

**[継続] B-14: マウント直後に空検索クエリが editor.html に送信される**
- 場所: `client/src/components/SearchBar.tsx:27–33` — debounce effect に early-out なし

**[継続] B-15: SearchPrev/Next ボタンがデバウンスをフラッシュせずにナビゲートを送信**
- 場所: `client/src/components/SearchBar.tsx:75–79`

**[継続] B-18: 置換ボタンがデバウンスタイマーをキャンセルせずに置換を送信**
- 場所: `client/src/components/SearchBar.tsx:103–108`

**[継続] B-21: `msg.activeTab` の境界チェックなし**
- 場所: `client/src/App.tsx:83` — Fix: `setActiveTab(Math.min(msg.activeTab, msg.tabs.length - 1))`

**[継続] B-22: Replace ボタンが毎回 hit[0] を置換（searchIdx リセット問題）**
- 場所: `client/src/components/SearchBar.tsx:103,107`

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定（Shift-JIS 文字化け）**
- 場所: `client/src/App.tsx:113`

**[継続] S-20: SW activate ハンドラが旧バージョンキャッシュを削除しない**

**[継続] Q-N-1 〜 Q-N-17:** 命名・マジックナンバー・アクセシビリティ等の軽微な品質指摘（前回から変化なし）

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応] S-28 (High/NEW) + S-7 (High):** `allow` から `clipboard-read` と `popups` を削除、同時に `sandbox` 属性を追加。これだけで S-28 が完全解消し S-7 も解消。
2. **[即対応] S-3 + S-27 (High):** javascript: スキームブロック + PAT をモジュール変数に移動して sessionStorage から削除。
3. **[即対応] S-5 (High):** デバッググループを `{import.meta.env.DEV && ...}` でガード。
4. **[即対応] B-13 (High):** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。
5. **[即対応] Q-N-18 (Medium):** `msg.xxx ?? DEFAULT_TOGGLES.xxx` で undefined→false 誤変換を防ぐ。
6. **[即対応] B-17 / B-12 (Medium):** IME isComposing チェック追加。
7. **[今週] S-25 (High):** editor.html postMessage targetOrigin を `location.origin` に変更。
8. **[今週] S-2 (High):** bridge.ts postMessage targetOrigin を `new URL(iframe.src, location.href).origin` に変更。
9. **[今週] S-8 (Medium):** App.tsx message ハンドラに origin チェック追加。
10. **[今週] S-15 (Medium):** `if (file.size > 100 * 1024 * 1024) return;` を追加。
11. **[今週] B-7 (Medium):** `send('gotoRow', Number(rowNum))`。
12. **[来週] S-24 (High):** ReDoS 対策（入力長上限）。
13. **[来週] S-22 (Medium):** SW の GitHub API キャッシュを無効化。

> 詳細な過去経緯は `_review/2026-07-28_code_review.md` を参照
