# コードレビューレポート 2026-07-15 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-15 UTC（自動レビュー）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonButton.tsx, RibbonToolbar.tsx, SearchBar.tsx, sw.js, editor.html, package.json)
- 発見件数: 🔴 Critical 1 / 🟠 High 7 / 🟡 Medium 15 / 🟢 Low 13 = 計36件
- うち新規 [NEW]: **0件** / 継続 [継続]: 36件
- 解消 [FIXED]: 0件
- 適用済み自動修正: **0件**（console.log / console.error / debugger 文なし）
- ⚠️ **2026-07-12以降コードに変更なし（3日間）。前回(07-13)比で新規指摘・解消ともにゼロ。S-1（Critical）は数週間未対応継続中。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存**
- 場所: `client/public/editor.html` — `dbmSavePat()` / `dbmGetPat()`
- `btoa` はBase64エンコードであり暗号化ではない。DevToolsから即座に読み取り可能。XSS → PAT漏洩 → リポジトリ書き込みの攻撃チェーンが成立。**数週間未対応。最優先で対処が必要。**
- **修正案:** sessionStorage + セッション変数のみに変更してlocalStorage永続化を廃止。永続化が必要なら Web Crypto API (AES-GCM) で暗号化後保存。

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子、editor.html 子→親 双方向）**
- 場所: `client/src/lib/bridge.ts:2` / `client/public/editor.html` (複数行)
- 双方向で `'*'` 使用。PAT・ファイル内容・ユーザーデータが任意オリジンに傍受される。
- **修正案:** `postMessage(msg, window.location.origin)` で明示的オリジンを指定。受信側も `e.origin` で検証。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html` — Markdownリンク展開処理 (line 7787-7790)
- `escHtml()` はHTML実体を変換するが `javascript:` は通過する。
- **修正案:** `/^https?:\/\//i.test(url)` でホワイトリスト検証。`rel="noopener noreferrer"` 追加。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx:113`
- Shift-JIS/EUC-JPファイルで文字化け・データ破損リスク。
- **修正案:** `readAsText(file, 'UTF-8')` を明示。

**[継続] S-5: デバッグ機能 (debugMemo) が本番UIに露出 — DEVガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx:196-199` / `client/public/editor.html:1781`
- `import.meta.env.DEV` ガードなしに常時表示。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html` — `<span style="color:${escHtml(...)}">`
- セミコロン・コロン等を変換しないためCSSインジェクションが可能。
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]+)$/.test(color)` で検証。

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx:141-147`
- sandbox未指定のためiframe内から `window.parent.location` による強制リダイレクト・任意ポップアップ開封が可能。S-11・S-16も同時解決できる最優先修正。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` を追加（`allow-top-navigation` は除外）。

**[継続] B-1: Ctrl+Shift+Z (redo) が全プラットフォームで動作しない**
- 場所: `client/src/App.tsx:68`
- `e.key === 'z' && e.shiftKey` はShiftキー押下時 `e.key` が `'Z'`（大文字）になるため条件が永遠にfalse。undo側は `'z' || 'Z'` 両対応済みなのに対し、redo側が未対応。**1行の修正で解消可能。**
- **修正案:** `(e.key === 'Z' && e.shiftKey)` に変更（大文字Z固定）。

---

### 🟡 Medium

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx:77-103`
- 任意オリジンからのpostMessageでUI状態が操作可能。
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- 検索インデックス確定前に置換が実行されセルがずれる。
- **修正案:** `searchCount` 応答受信後にreplaceを発行するコールバック方式に変更。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/index.html` / `client/public/editor.html` / `client/vite.config.ts`
- **修正案:** `default-src 'self'; script-src 'self'; connect-src 'self' https://api.github.com;` を設定。

**[継続] S-11: allow="popups" による iframe へのポップアップ権限付与（sandbox なしと組み合わせ）**
- 場所: `client/src/App.tsx:146`
- S-7のsandbox適用で同時解決可能。

**[継続] S-12: editor.html の postMessage ハンドラが `e.source` のみ検証し `e.origin` を未確認**
- 場所: `client/public/editor.html` — メッセージハンドラ (line 9340)
- **修正案:** `if (e.source !== window.parent || e.origin !== '<allowed-origin>') return;`

**[継続] S-13: Service Worker がキャッシュファーストのため、セキュリティパッチを既存ユーザーに配信不可**
- 場所: `client/public/sw.js:8-17`
- **修正案:** stale-while-revalidate戦略に変更。`activate` 時に旧バージョンキャッシュを削除。

**[継続] S-16: clipboard-read / clipboard-write 権限が sandboxなし iframe に付与**
- 場所: `client/src/App.tsx:146`
- S-7のsandbox追加（最優先）＋ `e.origin` 検証（S-12）で対処。

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:61`
- **修正案:** `searchCount` メッセージ受信後にnext/prevを送るコールバック方式に変更。

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**
- 場所: `client/src/components/SearchBar.tsx:21`
- **修正案:** `setQuery(prev => externalQuery !== prev ? externalQuery : prev)` の関数形式で更新。

**[継続] B-7: doGotoRow が行番号を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41`
- **修正案:** `send('gotoRow', Number(rowNum))`

**[継続] B-8: FileReader に onerror ハンドラなし — 読み込み失敗が無音で無視される**
- 場所: `client/src/App.tsx:108-114`
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- 場所: `client/src/lib/bridge.ts:9-10`
- **修正案:** `catch { /* cross-origin restriction — intentional no-op */ }` でコメント明示。

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**
- 場所: `client/src/components/SearchBar.tsx:24`

**[継続] Q-6: FileTabBar がタブのキーに配列インデックスを使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- **修正案:** `Tab` インターフェースに `id: string` フィールドを追加して `key={tab.id}` とする。

**[継続] Q-N-2: FileTabBar のタブ本体が `<div>` で実装されキーボード操作不可**
- 場所: `client/src/components/FileTabBar.tsx:18-35`
- **修正案:** `<button type="button">` に変更するか `role="tab" tabIndex={0} onKeyDown={...}` を追加。

---

### 🟢 Low

**[継続] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**
- 場所: `client/public/sw.js:14`
- **修正案:** `.catch(() => cached ?? new Response('Offline', { status: 503 }))`

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx:105`
- **修正案:** `if (file.size > 50 * 1024 * 1024) { setStatus('ファイルが大きすぎます (上限50MB)'); return; }`

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx:110`
- **修正案:** `if (typeof ev.target?.result === 'string') { ... }` のガードを追加。

**[継続] B-4: FileTabBar — 親 div の onClick がアクセシビリティ上不正**
- 場所: `client/src/components/FileTabBar.tsx:18-35`

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない**
- 場所: `client/src/components/SearchBar.tsx:59-63, 69`
- **修正案:** Escape/Xボタンハンドラ内で `clearTimeout(debounceRef.current)` を `send('clearSearch')` 前に追加。

**[継続] Q-3: message ハンドラの型判別に switch が使われていない**
- 場所: `client/src/App.tsx:80-99`
- **修正案:** `switch (msg.type) { ... }` に変更。

**[継続] Q-7: RibbonToolbar の activeTab 比較に文字列リテラルを直接使用**
- 場所: `client/src/components/RibbonToolbar.tsx:49-53`

**[継続] Q-N-1: handleKeyDown 内で早期 return 後も `cmd &&` を再チェック**
- 場所: `client/src/App.tsx:63,66,68`
- **修正案:** `cmd &&` を除去して条件を簡潔にする。

**[継続] Q-N-3: FileTabBar の閉じるボタンと追加ボタンに aria-label がない**
- 場所: `client/src/components/FileTabBar.tsx:28-43`
- **修正案:** `aria-label="タブを閉じる"` および `aria-label="シートを追加"` を追加。

**[継続] Q-N-4: RibbonButton の `size='large'` オプションがデッドコード**
- 場所: `client/src/components/RibbonButton.tsx:16-18,33`
- **修正案:** `size` propと `'large'` 分岐を削除してインターフェースを単純化。

**[継続] Q-N-5: SearchBar の Enter キー後に setTimeout の魔法の数値 30ms**
- 場所: `client/src/components/SearchBar.tsx:61`
- **修正案:** `const SEARCH_DISPATCH_DELAY_MS = 30` のような定数に切り出し、意図をコメントで明記。

**[継続] Q-N-6: FileTabBar と StatusBar でインラインスタイルに魔法の数値**
- 場所: `client/src/components/FileTabBar.tsx:16` (`height: 28`)、`client/src/components/StatusBar.tsx:11` (`height: 22`)
- **修正案:** Tailwind の `h-7` (28px)、`h-[22px]` のユーティリティクラスに統一。

**[継続] Q-N-7: RibbonButton の onClick に冗長な disabled ガードが存在**
- 場所: `client/src/components/RibbonButton.tsx:28`
- **修正案:** `onClick={() => { onClick(); focusEditor() }}` に簡略化。

---

## 解消済み（前回から）

なし（2026-07-12以降コードに変更なし）

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応・数週間未対応] S-1 (Critical):** `editor.html` の btoa() localStorage PAT保存を廃止。sessionStorage + セッション変数のみに変更。
2. **[今週・1行修正] B-1 (High):** `App.tsx:68` のredo条件を `(e.key === 'Z' && e.shiftKey)` に修正。全プラットフォームでredo完全不動作中。
3. **[今週] S-7 (High):** iframeに `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` を追加。S-11・S-16も同時解決。
4. **[今週・1行修正] B-8 (Medium):** `App.tsx` の FileReader に `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。
5. **[今週・1行修正] S-8 (Medium):** `App.tsx` のメッセージハンドラ先頭に `if (e.origin !== window.location.origin) return;` を追加。
6. **[今週] S-12 (Medium):** `editor.html` メッセージハンドラに `e.origin` チェックを追加。
7. **[今週] B-10 (Low):** SearchBar の Escape/X ハンドラで `clearTimeout(debounceRef.current)` を `send('clearSearch')` 前に追加。
8. **[来週] S-13 (Medium):** sw.js を stale-while-revalidate 戦略に変更。
9. **[来週] S-15 (Low):** `App.tsx` の `handleFileSelected` にファイルサイズ上限チェック (50MB) を追加。
10. **[来週] S-14 (Low):** sw.js の `.catch()` で `new Response('Offline', { status: 503 })` フォールバックを返す。

> 詳細な過去経緯は `_review/2026-07-13_code_review.md` を参照
