# コードレビューレポート 2026-07-27 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-27 16:12 UTC 自動レビュー・3エージェント並列
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 6件 (App.tsx, bridge.ts, SearchBar.tsx, RibbonToolbar.tsx, FileTabBar.tsx, RibbonButton.tsx)
- 発見件数: 🔴 Critical 0 / 🟠 High 6 / 🟡 Medium 21 / 🟢 Low 34 = 計61件
- うち新規 [NEW]: **0件** / 継続 [継続]: **61件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下に console.log / console.error / debugger 文なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| ℹ️ src変更なし | 2026-07-25以降、src/ への新規コミットなし |
| 🔄 Q-N-18 [継続] | 昨日 [NEW]→本日 [継続] 転換：stateSync で省略フィールドが `false` に上書き |
| 🔄 B-21 [継続] | 昨日 [NEW]→本日 [継続] 転換：`msg.activeTab` 境界チェックなし |

---

## セキュリティ所見

### 🔴 Critical

**（なし）**

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子）**
- 場所: `client/src/lib/bridge.ts:2`
- `iframe?.contentWindow?.postMessage({ action, payload }, '*')` — ファイル内容・UI状態が任意オリジンに傍受される。
- **修正案:** `postMessage(msg, window.location.origin)`

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html` — `renderHtmlValue` の isHtml セル処理
- S-3 + sessionStorage PAT → 細工した TSV の isHtml セルに `<a href="javascript:fetch('...')"` を仕込むとクリック1回で PAT 漏洩。
- **修正案:** `if (!/^https?:\/\//i.test(url)) return escHtml(text)` を追加。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx` — `handleFileSelected`
- `reader.readAsText(file)` — Shift-JIS/EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** ArrayBuffer + TextDecoder + BOM 検出でエンコーディング自動判定。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx` — `ToolsTab`
- `<RibbonGroup label="デバッグ">` が `import.meta.env.DEV` ガードなしに常時表示。PAT ダイアログに本番から到達可能。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx` — `<iframe id="editor-frame" ...>`
- sandbox 未指定のため iframe 内 XSS → 親フレームへのリダイレクト・任意ポップアップが可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups allow-clipboard-read allow-clipboard-write"` を追加。

**[継続] B-13: Ctrl+Z/Y が検索 INPUT 欄フォーカス中も editor.html に送信される**
- 場所: `client/src/App.tsx:65` — `if (tag === 'IFRAME') return` のみ（INPUT/TEXTAREA ガードなし）
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

---

### 🟡 Medium

**[継続] Q-N-18: stateSync で省略フィールドが `false` に上書きされる**
- 場所: `client/src/App.tsx` — `stateSync` メッセージハンドラ
- `!!(undefined)` = `false` となり、`DEFAULT_TOGGLES` の `verticalHeaderActive: true` が `false` に上書きされる可能性。
- **修正案:** `verticalHeaderActive: msg.verticalHeaderActive ?? DEFAULT_TOGGLES.verticalHeaderActive`

**[継続] S-25: editor.html の window.parent.postMessage が全て `'*'`**
- 場所: `client/public/editor.html` — editor→parent 方向の全 postMessage 呼び出し
- **修正案:** `window.parent.postMessage(msg, location.origin)` に統一。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html` — isHtml セル `renderHtmlValue`
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx` — message ハンドラ
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx` — replace ボタン onClick

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/index.html` / `client/public/editor.html`

**[継続] S-12: editor.html の postMessage ハンドラが `e.origin` を未確認**
- 場所: `client/public/editor.html`

**[継続] S-13: Service Worker がキャッシュファーストのためセキュリティパッチを配信不可**
- 場所: `client/public/sw.js`

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:61`

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx` — `ev.target?.result as string`

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**
- 場所: `client/src/components/SearchBar.tsx:20-25`

**[継続] B-7: doGotoRow が行番号を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41`
- **修正案:** `send('gotoRow', Number(rowNum))`

**[継続] B-8: FileReader に onerror ハンドラなし**
- 場所: `client/src/App.tsx`
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない（X ボタン）**
- 場所: `client/src/components/SearchBar.tsx:69`

**[継続] B-12: SearchBar で IME コンポジション中に検索が発火（日本語入力が壊れる）**
- 場所: `client/src/components/SearchBar.tsx:54` — onChange で `e.nativeEvent.isComposing` 未チェック

**[継続] B-16: Escape キーがデバウンスタイマーをキャンセルしない**
- 場所: `client/src/components/SearchBar.tsx:63`

**[継続] B-17: Enter キーが IME コンポジション中に searchNext を発火**
- 場所: `client/src/components/SearchBar.tsx:57` — onKeyDown

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- 場所: `client/src/lib/bridge.ts` — `catch {}`

**[継続] Q-3: message ハンドラの型判別に switch が使われていない**
- 場所: `client/src/App.tsx` — 連続 `if` 文

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**
- 場所: `client/src/components/SearchBar.tsx:25`

**[継続] Q-N-13: EditorMessage が全フィールド任意の平坦インターフェース（判別共用体ではない）**
- 場所: `client/src/App.tsx` — `interface EditorMessage`

---

### 🟢 Low

**[継続] B-21: `msg.activeTab` の境界チェックなし**
- 場所: `client/src/App.tsx` — `tabs` メッセージハンドラ
- `msg.activeTab >= msg.tabs.length` の場合、存在しないタブインデックスがセットされる。
- **修正案:** `setActiveTab(Math.min(msg.activeTab, msg.tabs.length - 1))`

**[継続] S-26: `target="_blank"` に `rel="noopener noreferrer"` がない（タブナッピング）**
- 場所: `client/public/editor.html` — renderHtmlValue

**[継続] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- **修正案:** `if (file.size > 100 * 1024 * 1024) { setStatus('ファイルが大きすぎます'); return; }`

**[継続] S-18: @babel/core 7.x — GHSA-4x5r-pxfx-6jf8**
- **修正案:** `cd client && npm audit fix`

**[継続] S-20: SW activate ハンドラが旧バージョンキャッシュを削除しない**

**[継続] S-21: サニタイズされていない file.name が postMessage 経由で editor.html に転送される**

**[継続] S-22: SW が GitHub API の GET レスポンスを無制限にキャッシュ**

**[継続] S-23: replaceText が未サニタイズのまま postMessage で editor.html に転送される**

**[継続] S-24: editor.html の regex モードで `new RegExp(q)` が無制限実行 → ReDoS**

**[継続] B-4: FileTabBar タブ本体が `<div>` でキーボード操作不可**

**[継続] B-11: FileTabBar key={i} — タブ削除時に React 差分アルゴリズムが誤認**

**[継続] B-14: マウント直後に空検索クエリが editor.html に送信される**

**[継続] B-15: SearchPrev/Next ボタンがデバウンスをフラッシュせずにナビゲートを送信**

**[継続] B-18: 置換ボタンがデバウンスタイマーをキャンセルせずに置換を送信**

**[継続] Q-N-1: handleKeyDown 内で早期 return 後も `cmd &&` を再チェック（冗長）**

**[継続] Q-N-2: FileTabBar タブ本体が `<div>` で実装されキーボード操作不可**

**[継続] Q-N-3: FileTabBar 閉じる・追加ボタンに aria-label がない**

**[継続] Q-N-4: RibbonButton の `size='large'` オプションがデッドコード**

**[継続] Q-N-5: SearchBar の Enter キー後に setTimeout の魔法の数値 30ms**

**[継続] Q-N-6: FileTabBar と StatusBar でインラインスタイルに魔法の数値**

**[継続] Q-N-7: RibbonButton の onClick に冗長な disabled ガードが存在**

**[継続] Q-N-8: FileReader onload で緩やかな等値演算子 `!= null` を使用**

**[継続] Q-N-9: `type Tab` の命名衝突（RibbonToolbar と App/FileTabBar で同名の異なる型）**

**[継続] Q-N-10: ToggleStates 型を子コンポーネント RibbonToolbar が親 App.tsx からインポート**

**[継続] Q-N-11: debounce 遅延 180ms が未ドキュメントの魔法の数値**

**[継続] Q-N-12: doGotoRow() 実行後に rowNum state がクリアされない**

**[継続] Q-N-15: SearchBar の X（クリア）ボタンに aria-label も title もなし**

**[継続] Q-N-16: 置換「1件」「全て」ボタンに title / aria-label なし**

**[継続] Q-N-17: onOpenFile フォールバック `send('open')` がデッドコード**

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応・1行] B-13 (High):** `handleKeyDown` に `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。
2. **[即対応・1行] S-5 (High):** RibbonToolbar の ToolsTab デバッググループを `{import.meta.env.DEV && ...}` でガード。
3. **[即対応] Q-N-18 (Medium):** `stateSync` ハンドラで `msg.xxx ?? DEFAULT_TOGGLES.xxx` を使用し undefined→false の誤変換を防ぐ。
4. **[即対応・1行] B-17 (Medium):** `if (e.key === 'Enter')` に `&& !e.nativeEvent.isComposing` を追加。
5. **[即対応・1行] B-16 (Medium):** Escape ハンドラ先頭に `clearTimeout(debounceRef.current)` を追加。
6. **[今週] S-7 (High):** iframe に `sandbox` 属性を追加（S-11・S-16 も同時解決）。
7. **[今週] S-3 (High):** isHtml セルの URL を `https?://` ホワイトリストで検証。
8. **[今週] S-25 (Medium):** editor.html の `window.parent.postMessage` の targetOrigin を `location.origin` に変更。
9. **[今週] S-8 (Medium):** `App.tsx` メッセージハンドラ先頭に `if (e.origin !== window.location.origin) return;` を追加。
10. **[今週] B-12 (Medium):** SearchBar onChange に `isComposing` チェック追加。
11. **[今週] B-8 (Medium):** FileReader に `reader.onerror` ハンドラを追加。
12. **[今週] B-21 (Low):** `setActiveTab(Math.min(msg.activeTab, msg.tabs.length - 1))` に変更。
13. **[今週] S-2 (High):** `bridge.ts` の `postMessage` targetOrigin を `window.location.origin` に変更。
14. **[来週・1コマンド] S-18 (Low):** `cd client && npm audit fix` で @babel/core 更新。
15. **[来週] S-24 (Low):** regex モードに入力長上限を追加して ReDoS を緩和。
16. **[来週] B-7 (Medium):** `doGotoRow` で `Number(rowNum)` を送信。
17. **[来週] S-26 (Low):** renderHtmlValue の auto-link に `rel="noopener noreferrer"` を追加。
18. **[来週] Q-N-16 (Low):** 置換ボタンに `title` / `aria-label` を追加。
19. **[来週] S-12 (Medium):** `editor.html` メッセージハンドラに `e.origin` チェックを追加。

> 詳細な過去経緯は `_review/2026-07-26_code_review.md` を参照
