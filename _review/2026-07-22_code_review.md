# コードレビューレポート 2026-07-22 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-22 16:09 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, RibbonButton.tsx, sw.js, StatusBar.tsx, editor.html)
- 発見件数: 🔴 Critical 0 / 🟠 High 6 / 🟡 Medium 17 / 🟢 Low 27 = 計50件
- うち新規 [NEW]: **1件** / 継続 [継続]: 49件 / 解消 [FIXED]: **3件**
- 適用済み自動修正: **0件**（src配下に console.log / console.error / debugger 文なし）

### 今回の主な変化
| 変化 | 内容 |
|------|------|
| ✅ FIXED S-1 (Critical) | PAT を sessionStorage に移行（localStorage + btoa 廃止） |
| ✅ FIXED S-17 (High) | vite 6.4.3 へ更新、CVE 2件解消 |
| ✅ FIXED B-1 (High) | Ctrl+Shift+Z の redo keybinding 修正（`e.key === 'Z'`） |
| ⚠️ NEW S-24 (Low) | editor.html で `new RegExp(q)` を無制限実行 → ReDoS リスク |

---

## セキュリティ所見

### 🔴 Critical

**（なし — S-1 が本日修正済み）**

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子、editor.html 子→親 双方向）**
- 場所: `client/src/lib/bridge.ts:3` / `client/public/editor.html` 複数箇所
- ファイル内容・PAT・UI状態が任意オリジンに傍受される。
- **修正案:** `postMessage(msg, window.location.origin)` で明示オリジン指定。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html` — `renderHtmlValue` の isHtml セル処理
- `escHtml()` は HTML 実体を変換するが `javascript:` は通過し、`innerHTML` に注入される。
- **修正案:** `if (!/^https?:\/\//i.test(url)) return escHtml(text)` を追加、`rel="noopener noreferrer"` 付与。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx` / `client/public/editor.html`
- Shift-JIS/EUC-JP ファイルで文字化け・データ破損。
- **修正案:** ArrayBuffer + TextDecoder + BOM 検出でエンコーディング自動判定。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx:196-198`
- `import.meta.env.DEV` ガードなしに常時表示。S-1 修正後も PAT 入力 UI は本番から利用可能。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx`
- sandbox 未指定のため iframe 内 XSS → 親フレームへのリダイレクト・任意ポップアップが可能。S-11・S-16 も同時解決。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` を追加（`allow-top-navigation` は除外）。

**[継続] B-13: Ctrl+Z/Y が検索 INPUT 欄フォーカス中も editor.html に送信される**
- 場所: `client/src/App.tsx:64` — `if (tag === 'IFRAME') return` のみ（INPUT/TEXTAREA ガードなし）
- 検索バーで Ctrl+Z を押すと入力テキストの undo ではなくエディタへ undo が転送される。
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

---

### 🟡 Medium

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html` — isHtml セル `renderHtmlValue`
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{2,30})$/.test(color)` で検証。

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx` — `window.addEventListener('message', handler)`
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx`
- **修正案:** `searchCount` 応答受信後に replace を発行するコールバック方式に変更。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/index.html` / `client/public/editor.html`
- **修正案:** `default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;` を設定。

**[継続] S-11: allow="popups" による iframe へのポップアップ権限付与**
- S-7 の sandbox 追加で同時解決。

**[継続] S-12: editor.html の postMessage ハンドラが `e.source` のみ検証し `e.origin` を未確認**
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
- 場所: `client/src/App.tsx:110` (`ev.target?.result as string`)
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

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない**
- 場所: `client/src/components/SearchBar.tsx`
- Escape/X ボタンが `handleQueryChange('')` → debounce → 180ms 後に `send('search', '')` が後追い送信。
- **修正案:** `clearTimeout(debounceRef.current)` を `send('clearSearch')` 前に追加。

**[継続] B-12: SearchBar で IME コンポジション中に検索が発火（日本語入力が壊れる）**
- 場所: `client/src/components/SearchBar.tsx:54`
- **修正案:**
  ```typescript
  onChange={e => { if (e.nativeEvent.isComposing) return; handleQueryChange(e.target.value) }}
  onCompositionEnd={e => handleQueryChange((e.target as HTMLInputElement).value)}
  ```

---

### 🟢 Low

**[NEW] S-24: editor.html の regex モードで `new RegExp(q)` が無制限実行 → ReDoS**
- 場所: `client/public/editor.html` — 検索・置換の regex モード処理（複数箇所）
- `(a+)+$` 等の pathological パターンをユーザーが入力・ペーストするとブラウザタブがフリーズ。`try/catch` はパースエラーのみ補足し実行時の計算複雑性はガードしない。
- **修正案:** 入力長上限（例: 200文字）を設ける、または Worker + `terminate()` でタイムアウト制御。

**[継続] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**
- 場所: `client/public/sw.js:14` — `.catch(() => cached)` where `cached` may be `undefined`
- **修正案:** `.catch(() => cached ?? new Response('Offline', { status: 503 }))`

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- **修正案:** `if (file.size > 100 * 1024 * 1024) { setStatus('ファイルが大きすぎます (上限100MB)'); return; }`

**[継続] S-18: @babel/core 7.29.0 — GHSA-4x5r-pxfx-6jf8**
- **修正案:** `cd client && npm audit fix`

**[継続] S-20: SW activate ハンドラが旧バージョンキャッシュを削除しない**
- **修正案:** `caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))` を追加。

**[継続] S-21: サニタイズされていない file.name が postMessage 経由で editor.html に転送される**
- **修正案:** `file.name.replace(/[<>&"']/g, '_')` でサニタイズ。

**[継続] S-22: SW が GitHub API の GET レスポンスを無制限にキャッシュ**
- **修正案:** `if (!e.request.url.startsWith(self.location.origin)) { e.respondWith(fetch(e.request)); return; }`

**[継続] S-23: replaceText が未サニタイズのまま postMessage で editor.html に転送される**
- **修正案:** S-21 と同じサニタイズ処理を replaceText にも適用。

**[継続] B-4: FileTabBar タブ本体が `<div>` でキーボード操作不可**
- **修正案:** `<button type="button">` に変更。

**[継続] B-11: FileTabBar key={i} — タブ削除時に React 差分アルゴリズムが誤認**
- **修正案:** `key={tab.name}` またはユニーク ID を使用。

**[継続] B-14: マウント直後に空検索クエリが editor.html に送信される**
- **修正案:** debounce 内で `if (!query) return;` を先頭に追加。

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- **修正案:** `catch (e) { /* cross-origin restriction — intentional */ }` でコメント明示。

**[継続] Q-3: message ハンドラの型判別に switch が使われていない**
- **修正案:** `switch (msg.type) { ... }` に変更。

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**
- **修正案:** `query` state を App.tsx に一元化。

**[継続] Q-6: FileTabBar がタブのキーに配列インデックスを使用**
- **修正案:** `key={tab.id}` に変更。

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

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応・1行] S-5 (High):** RibbonToolbar のデバッググループを `{import.meta.env.DEV && ...}` でガード。S-1 修正後も本番から PAT ダイアログにアクセス可能。
2. **[即対応・1行] B-13 (High):** `handleKeyDown` に `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。検索欄 Ctrl+Z 問題を修正。
3. **[今週] S-7 (High):** iframe に `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` 追加。S-11・S-16 も同時解決。
4. **[今週・1行] S-8 (Medium):** `App.tsx` メッセージハンドラ先頭に `if (e.origin !== window.location.origin) return;` を追加。
5. **[今週] B-12 (Medium):** SearchBar に `isComposing` チェック追加。日本語 IME 入力中の無効な検索を防止。
6. **[今週] B-8 (Medium):** FileReader に `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。
7. **[今週] S-2 (High):** `bridge.ts` と `editor.html` の `postMessage` targetOrigin を `window.location.origin` に変更。
8. **[来週・1コマンド] S-18 (Low):** `cd client && npm audit fix` で @babel/core 更新。
9. **[来週] S-22 (Low):** SW fetch ハンドラでクロスオリジンリクエストをキャッシュスキップ。PAT 失効検知に影響。
10. **[来週] S-24 (Low) [NEW]:** regex モードに入力長上限を追加して ReDoS を緩和。
11. **[来週] B-7 (Medium):** `doGotoRow` で `Number(rowNum)` を送信。
12. **[来週] B-10 (Low):** Escape/X ハンドラで `clearTimeout(debounceRef.current)` を追加。
13. **[来週] S-3 (High):** isHtml セルの URL を `https?://` ホワイトリストで検証。
14. **[来週] S-12 (Medium):** `editor.html` メッセージハンドラに `e.origin` チェックを追加。
15. **[来週] S-13 (Medium):** sw.js を stale-while-revalidate 戦略に変更。
16. **[来週] S-20 (Low):** sw.js activate ハンドラに旧キャッシュ削除処理を追加。
17. **[来週] S-14 (Low):** SW catch ブランチで `cached ?? new Response(...)` を返す。
18. **[来週] S-15 (Low):** `handleFileSelected` にファイルサイズ上限チェック (100MB) を追加。
19. **[来週] B-14 (Low):** SearchBar debounce に `if (!query) return;` を追加。
20. **[来週] Q-N-10 (Low):** `ToggleStates` 型を共有型ファイルに移動し子→親インポートを解消。

> 詳細な過去経緯は `_review/2026-07-21_code_review.md` を参照
