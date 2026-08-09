# コードレビューレポート 2026-08-09 — shunjapanes/main

## サマリー

- 実行日時: 2026-08-09 16:09 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, editor.html [抜粋])
- 発見件数: 🔴 Critical 0 / 🟠 High 5 / 🟡 Medium 12 / 🟢 Low 22 = 計39件
- うち新規 [NEW]: **0件** / 継続 [継続]: **39件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下に console.log / console.error / debugger 文なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| ℹ️ 変更なし | 2026-07-22 の修正以降、ソースコードへの新規コミットなし。_review/*.md のみ更新。 |
| ℹ️ 全件継続 | 前回 (2026-08-08) 指摘の全39件が未修正のまま継続中 |

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
- 場所: `client/src/components/RibbonToolbar.tsx:196` — `ToolsTab` 内 `RibbonGroup label="デバッグ"`
- `import.meta.env.DEV` ガードなしに本番でも常時表示。PAT ダイアログに本番から到達可能。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`
- Shift-JIS/EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** ArrayBuffer + TextDecoder + BOM 検出でエンコーディング自動判定。

**[継続] S-CSS: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html` — isHtml セル `renderHtmlValue`
- `escHtml(color)` はHTML実体化するが CSS プロパティ区切り文字(`;`)は通過する。
- **修正案:** `CSS.supports('color', value)` または `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`、`client/public/editor.html`
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;">` を追加。

**[継続] S-FN: OS 由来の file.name をサニタイズせず postMessage ペイロードに含める**
- 場所: `client/src/App.tsx:112`
- ファイル名に `<script>alert(1)</script>` 等が含まれる場合、editor.html で innerHTML 描画時に XSS。
- **修正案:** `/[^\w.\- ]/g` で除去するホワイトリストバリデーションを送信前に適用。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- **修正案:** `searchCount` 応答受信後に replace を発行するコールバック方式に変更。

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:62`
- **修正案:** `searchCount` 受信後に next/prev を送るコールバック方式に変更。

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx:110` — `ev.target?.result as string`
- **修正案:** `if (typeof result === 'string') { ... }` ガードを追加。

**[継続] B-8: FileReader に onerror ハンドラなし**
- 場所: `client/src/App.tsx`
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] B-12: SearchBar で IME コンポジション中に検索が発火（日本語入力が壊れる）**
- 場所: `client/src/components/SearchBar.tsx:54`
- **修正案:**
  ```typescript
  onChange={e => { if (e.nativeEvent.isComposing) return; handleQueryChange(e.target.value) }}
  onCompositionEnd={e => handleQueryChange((e.target as HTMLInputElement).value)}
  ```

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**
- 場所: `client/src/components/SearchBar.tsx:20-25`
- **修正案:** 完全制御コンポーネントに変更（`query` state を App.tsx に一元化）。

**[継続] B-7: doGotoRow が行番号を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41`
- **修正案:** `send('gotoRow', Number(rowNum))`

---

### 🟢 Low

**[継続] S-13: Service Worker がキャッシュファーストのためセキュリティパッチを配信不可**
- 場所: `client/public/sw.js`
- **修正案:** stale-while-revalidate 戦略に変更。

**[継続] S-14: sw.js フェッチ失敗時に undefined を返しエラーをマスク**
- 場所: `client/public/sw.js:14` — `.catch(() => cached)` where `cached` may be `undefined`
- **修正案:** `.catch(() => cached ?? new Response('Offline', { status: 503 }))`

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- **修正案:** `if (file.size > 100 * 1024 * 1024) { setStatus('ファイルが大きすぎます (上限100MB)'); return; }`

**[継続] S-18: @babel/core 脆弱性 (GHSA-4x5r-pxfx-6jf8)**
- **修正案:** `cd client && npm audit fix`

**[継続] S-20: SW activate ハンドラが旧バージョンキャッシュを削除しない**
- **修正案:** `caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))` を追加。

**[継続] S-21: file.name が postMessage 経由で editor.html に無加工転送（innerHTML リスク）**
- S-FN と重複（Medium に格上げ済み）。

**[継続] S-22: SW が GitHub API GET レスポンスを無制限キャッシュ**
- **修正案:** `if (!e.request.url.startsWith(self.location.origin)) { e.respondWith(fetch(e.request)); return; }`

**[継続] S-23: replaceText が未サニタイズのまま postMessage で転送**
- **修正案:** S-FN と同様のサニタイズ処理を replaceText にも適用。

**[継続] S-24: regex モードで `new RegExp(q)` が無制限実行 → ReDoS**
- 場所: `client/public/editor.html` — 検索・置換の regex モード処理
- `(a+)+$` 等のパターンでブラウザタブがフリーズ。
- **修正案:** 入力長上限（例: 200文字）を設ける、または Worker + `terminate()` でタイムアウト制御。

**[継続] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html` — renderHtmlValue の自動リンク生成
- **修正案:** `rel="noopener noreferrer"` を href と共に追加。

**[継続] B-4: FileTabBar タブ本体が `<div>` でキーボード操作不可（アクセシビリティ）**
- 場所: `client/src/components/FileTabBar.tsx`
- **修正案:** `<button type="button">` に変更し `role="tab"` を付与。

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない**
- 場所: `client/src/components/SearchBar.tsx`
- **修正案:** `clearTimeout(debounceRef.current)` を `send('clearSearch')` 前に追加。

**[継続] B-11: FileTabBar `key={i}` — タブ削除時に React 差分アルゴリズムが誤認**
- 場所: `client/src/components/FileTabBar.tsx`
- **修正案:** `key={tab.name}` またはユニーク ID を使用。

**[継続] B-14: マウント直後に空検索クエリが editor.html に送信される**
- 場所: `client/src/components/SearchBar.tsx`
- **修正案:** debounce 内で `if (!query) return;` を先頭に追加。

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- **修正案:** `catch { /* cross-origin restriction — intentional */ }` でコメント明示。

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**
- **修正案:** `query` state を App.tsx に一元化。

**[継続] Q-N-9: `type Tab` の命名衝突（RibbonToolbar と App/FileTabBar で同名の異なる型）**
- **修正案:** `RibbonTab` 等に改名して衝突を解消。

**[継続] Q-N-10: ToggleStates 型を子コンポーネントが親 App.tsx からインポート**
- **修正案:** `src/types.ts` 等の共有型ファイルに移動。

**[継続] Q-N-12: doGotoRow() 実行後に rowNum state がクリアされない**
- **修正案:** `doGotoRow` 内で `setRowNum('')` を追加。

**[継続] Q-N-13: EditorMessage が全フィールド任意の平坦インターフェース（判別共用体ではない）**
- **修正案:** 判別共用体 (`type EditorMessage = StatusMsg | TabsMsg | ...`) に変更し型安全性を向上。

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応・1行] B-13 (High):** `client/src/App.tsx:65` に `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。検索欄 Ctrl+Z 問題を修正。
2. **[即対応・1行] S-5 (Medium):** `RibbonToolbar.tsx:196` のデバッググループを `{import.meta.env.DEV && ...}` でガード。本番から debugMemo に到達不可にする。
3. **[今週・1行] S-PM (High):** `bridge.ts:3` の targetOrigin を `window.location.origin` に変更。`App.tsx:77` の受信ハンドラ先頭に origin チェックを追加。
4. **[今週] S-SBX (High):** `App.tsx:141` の iframe に `sandbox="allow-scripts allow-same-origin allow-downloads allow-modals allow-popups allow-clipboard-read allow-clipboard-write"` を追加。
5. **[今週] S-CLIP (High):** `App.tsx:143` の `allow` 属性から `clipboard-read` を削除。
6. **[今週] B-12 (Medium):** SearchBar に `isComposing` チェックを追加。日本語 IME 入力中の無効な検索を防止。
7. **[今週] B-8 (Medium):** FileReader に `reader.onerror` ハンドラを追加。
8. **[今週] S-XSS (High):** isHtml セルの URL を `https?://` ホワイトリストで検証 + `rel="noopener noreferrer"` 追加。
9. **[今週] S-FN (Medium):** `App.tsx:112` で `file.name` を送信前にサニタイズ。
10. **[来週・1コマンド] S-18 (Low):** `cd client && npm audit fix` で @babel/core 更新。
11. **[来週] S-24 (Low):** regex モードに入力長上限を追加して ReDoS を緩和。
12. **[来週] S-14 (Low):** SW catch で `cached ?? new Response(...)` を返す。
13. **[来週] S-22 (Low):** SW でクロスオリジンリクエストをキャッシュスキップ。
14. **[来週] S-15 (Low):** `handleFileSelected` にファイルサイズ上限チェック (100MB) を追加。
15. **[来週] B-7 (Medium):** `doGotoRow` で `Number(rowNum)` を送信。
16. **[来週] B-10 (Medium):** Escape/X ハンドラで `clearTimeout(debounceRef.current)` を追加。
17. **[来週] B-14 (Low):** SearchBar debounce に `if (!query) return;` を追加。
18. **[来週] S-13 (Low):** sw.js を stale-while-revalidate 戦略に変更。
19. **[来週] S-20 (Low):** sw.js activate に旧キャッシュ削除処理を追加。
20. **[来週] Q-N-10 (Low):** `ToggleStates` 型を共有型ファイルに移動し子→親インポートを解消。

> 詳細な過去経緯は `_review/2026-08-08_code_review.md` を参照
