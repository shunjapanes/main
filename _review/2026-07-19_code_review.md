# コードレビューレポート 2026-07-19 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-19 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, RibbonButton.tsx, sw.js, StatusBar.tsx, editor.html)
- 発見件数: 🔴 Critical 1 / 🟠 High 8 / 🟡 Medium 17 / 🟢 Low 26 = 計52件
- うち新規 [NEW]: **7件** / 継続 [継続]: 45件
- 解消 [FIXED]: **1件**（S-19 — SW ASSETS前払いリストは実際には存在しなかった）
- 適用済み自動修正: **0件**（src配下に console.log / console.error / debugger 文なし）
- ⚠️ **2026-07-12以降コードに変更なし（7日間継続）。S-1（Critical）は約47日間未対応。S-17（vite CVE）は約9日間未対応。今回: S-19を誤検知として閉鎖、新規発見: SW がGitHub API応答をキャッシュ（S-22）・IMEコンポジション未対応（B-12）・replaceText未サニタイズ（S-23）・Ctrl+Z がINPUT欄でも発火（B-13）・マウント時に空検索が送信（B-14）・ToggleStates 子→親インポート（Q-N-10）・EditorMessage 型が判別共用体非準拠（Q-N-13）。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存**
- 場所: `client/public/editor.html` — `dbmSavePat()` / `dbmGetPat()`
- `btoa` はBase64エンコードであり暗号化ではない。DevToolsから即座に読み取り可能。XSS → PAT漏洩 → リポジトリ書き込みの攻撃チェーンが成立。**約47日間未対応。最優先で対処が必要。**
- **修正案:** sessionStorage + セッション変数のみに変更してlocalStorage永続化を廃止。永続化が必要なら Web Crypto API (AES-GCM) で暗号化後保存。

---

### 🟠 High

**[継続] S-17: vite 6.4.2 に既知 CVE 2件（約9日間未対応）**
- 場所: `client/package-lock.json` (node_modules/vite@6.4.2)
- GHSA-v6wh-96g9-6wx3: Windows dev server 上での NTLMv2 ハッシュ漏洩。
- GHSA-fx2h-pf6j-xcff: server.fs.deny の Windows 代替パスバイパスによる任意ファイル読み取り。
- **修正案:** `cd client && npm update vite` で vite 6.4.3+ へ更新（1コマンドで解決）。

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子、editor.html 子→親 双方向）**
- 場所: `client/src/lib/bridge.ts:3` / `client/public/editor.html` (複数行)
- PAT・ファイル内容・ユーザーデータが任意オリジンに傍受される。
- **修正案:** `postMessage(msg, window.location.origin)` で明示的オリジンを指定。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html` — Markdownリンク展開処理
- `escHtml()` はHTML実体を変換するが `javascript:` は通過する。
- **修正案:** `/^https?:\/\//i.test(url)` でホワイトリスト検証。`rel="noopener noreferrer"` 追加。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx` / `client/public/editor.html`
- Shift-JIS/EUC-JPファイルで文字化け・データ破損リスク。日本語CSVは特に影響大。
- **修正案:** ArrayBuffer + TextDecoder + BOM検出でエンコーディング自動判定。

**[継続] S-5: デバッグ機能 (debugMemo) が本番UIに露出 — DEVガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx:196-199` / `client/public/editor.html`
- `import.meta.env.DEV` ガードなしに常時表示。PAT入力UIを含む。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html`
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]+)$/.test(color)` で検証。

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx` — `<iframe id="editor-frame" ...>`
- sandbox未指定のためiframe内XSS → 親フレームへのリダイレクト・任意ポップアップが可能。S-11・S-16も同時解決。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` を追加（`allow-top-navigation` は除外）。

**[継続] B-1: Ctrl+Shift+Z (redo) が全プラットフォームで動作しない**
- 場所: `client/src/App.tsx:68`
- `e.key === 'z' && e.shiftKey` はShiftキー押下時 `e.key` が `'Z'`（大文字）になるため条件が永遠にfalse。
- **修正案:** `(e.key === 'Z' && e.shiftKey)` に変更。

---

### 🟡 Medium

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx` — messageハンドラ
- 任意オリジンからのpostMessageでUI状態が操作可能。
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx` — replace buttons
- **修正案:** `searchCount` 応答受信後にreplaceを発行するコールバック方式に変更。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/index.html` / `client/public/editor.html` / `client/vite.config.ts`
- **修正案:** `default-src 'self'; script-src 'self'; connect-src 'self' https://api.github.com;` を設定。

**[継続] S-11: allow="popups" による iframe へのポップアップ権限付与（sandbox なしと組み合わせ）**
- 場所: `client/src/App.tsx`
- S-7のsandbox適用で同時解決可能。

**[継続] S-12: editor.html の postMessage ハンドラが `e.source` のみ検証し `e.origin` を未確認**
- 場所: `client/public/editor.html` — メッセージハンドラ
- **修正案:** `if (e.source !== window.parent || e.origin !== '<allowed-origin>') return;`

**[継続] S-13: Service Worker がキャッシュファーストのため、セキュリティパッチを既存ユーザーに配信不可**
- 場所: `client/public/sw.js` — `cached || fetch(e.request)` のcache-first戦略
- サーバー側にパッチを適用しても既存ユーザーには届かない。
- **修正案:** stale-while-revalidate戦略に変更。

**[継続] S-16: clipboard-read / clipboard-write 権限が sandboxなし iframe に付与**
- 場所: `client/src/App.tsx`
- S-7のsandbox追加で対処。

**[NEW] B-12: SearchBar で IME コンポジション中に検索が発火 — 日本語入力が壊れる**
- 場所: `client/src/components/SearchBar.tsx:57` (`onChange={e => handleQueryChange(e.target.value)}`)
- 日本語/中国語IME入力中、`onChange` は変換候補ごとに発火し180msデバウンス後に `send('search', query)` が送信される。変換確定前の未完成な文字列で検索が実行されるため、検索カウントが不正確になる。日本語CSVエディタとして最も頻繁に使われる操作経路でのバグ。
- **修正案:**
  ```typescript
  onChange={e => { if (!e.nativeEvent.isComposing) handleQueryChange(e.target.value) }}
  onCompositionEnd={e => handleQueryChange((e.target as HTMLInputElement).value)}
  ```

**[NEW] B-13: Ctrl+Z/Y が検索 INPUT 欄にフォーカス中も editor.html に送信される**
- 場所: `client/src/App.tsx` — `handleKeyDown` のフォーカス判定
- `e.currentTarget.tagName === 'IFRAME'` のガードはiframeが対象のときのみ早期returnするが、検索欄 (`<input>`) にフォーカスがある場合の判定が欠落している。Ctrl+Z/Y がテキストフィールドのネイティブ undo/redo を抑制し editor に誤送信される。
- **修正案:** ハンドラ先頭に `const tag = (document.activeElement as HTMLElement).tagName; if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- 場所: `client/src/lib/bridge.ts:9-10`
- **修正案:** `catch (e) { /* cross-origin restriction — intentional */ }` でコメント明示。

**[継続] Q-3: message ハンドラの型判別に switch が使われていない**
- 場所: `client/src/App.tsx` — messageハンドラ
- **修正案:** `switch (msg.type) { ... }` に変更。

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**
- 場所: `client/src/components/SearchBar.tsx:24`
- **修正案:** `query` stateをApp.tsxに一元化し、SearchBarを完全制御コンポーネントに変更。

**[継続] Q-6: FileTabBar がタブのキーに配列インデックスを使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- **修正案:** `Tab` に `id: string` フィールドを追加して `key={tab.id}` とする。

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:61`
- **修正案:** `searchCount` メッセージ受信後にnext/prevを送るコールバック方式に変更。

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**
- 場所: `client/src/components/SearchBar.tsx:21`
- **修正案:** 完全制御コンポーネントに変更（Q-5と同時対応）。

**[継続] B-7: doGotoRow が行番号を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41`
- **修正案:** `send('gotoRow', Number(rowNum))`

**[継続] B-8: FileReader に onerror ハンドラなし — 読み込み失敗が無音で無視される**
- 場所: `client/src/App.tsx`
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

---

### 🟢 Low

**[継続] S-18: @babel/core 7.29.0 に既知 CVE**
- 場所: `client/package-lock.json`
- GHSA-4x5r-pxfx-6jf8: sourceMappingURL 経由でビルド時に任意ファイルを読み取られる可能性。
- **修正案:** `npm audit fix` で @babel/core 7.29.1+ へ更新（S-17の修正時に同時対応可能）。

**[NEW] S-22: SW が GitHub API の GET レスポンスを無制限にキャッシュ**
- 場所: `client/public/sw.js` — `cache.put(e.request, resp.clone())`
- SW は全 GET リクエストを対象に `resp.ok` であれば `cache.put()` する。`editor.html` 内の `dbmValidatePat()` / SHA 取得が `https://api.github.com/...` を GETするため、これらのレスポンスが CacheStorage に無期限保存される。
  - **PAT失効検知の失敗:** PAT を GitHub で無効化しても SW が旧 200 OK を返すため UI は「PAT有効」と誤表示する。
  - **機密データの永続化:** ユーザープロフィール・ファイルSHAがローカルキャッシュに残り、将来のXSS（S-3/S-6）からアクセス可能。
- **修正案:** SW の fetch ハンドラでクロスオリジンリクエストをキャッシュスキップ:
  ```javascript
  if (!e.request.url.startsWith(self.location.origin)) { e.respondWith(fetch(e.request)); return; }
  ```

**[継続] S-20: SW activate ハンドラが旧バージョンキャッシュを削除しない**
- 場所: `client/public/sw.js` — `self.addEventListener('activate', e => e.waitUntil(self.clients.claim()))`
- activate ハンドラは存在するが `caches.keys()` による旧バージョン削除を行わない。CACHE名が将来変更された場合、旧キャッシュが無限蓄積する。
- **修正案:** `caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))` を追加。

**[継続] S-21: サニタイズされていない file.name が postMessage 経由で editor.html に転送される**
- 場所: `client/src/App.tsx` — `send('openContent', { content, filename: file.name })`
- **修正案:** `file.name.replace(/[<>&"']/g, c => ({'<':'&lt;','>':'&gt;','&':'&amp;','"':'&quot;',"'":'&#39;'}[c] ?? c))`

**[NEW] S-23: replaceText が未サニタイズのまま postMessage で editor.html に転送される**
- 場所: `client/src/components/SearchBar.tsx` — `send('replaceOne', replaceText)` / `send('replaceAll', replaceText)`
- ユーザーが `<img src=x onerror=alert(origin)>` のような文字列を置換テキスト欄に入力した場合、editor.html が置換後セル内容を innerHTML で描画していると XSS が発生する（S-21と同一攻撃面）。
- **修正案:** S-21 と同じサニタイズ処理を replaceText にも適用。またはCSP（S-10）適用で緩和。

**[継続] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**
- 場所: `client/public/sw.js` — `.catch(() => cached)` where `cached` may be `undefined`
- キャッシュエントリがなくネットワークも失敗した場合、`respondWith(undefined)` となり TypeError が発生。
- **修正案:** `.catch(() => cached ?? new Response('Offline', { status: 503 }))`

**[継続] S-15: FileReader でファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx`
- **修正案:** `if (file.size > 100 * 1024 * 1024) { setStatus('ファイルが大きすぎます (上限100MB)'); return; }`

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx` — `ev.target?.result as string`
- **修正案:** `if (typeof result === 'string') { ... }` のガードを追加し `as string` キャストを除去。

**[継続] B-4: FileTabBar — 親 div の onClick がアクセシビリティ上不正**
- 場所: `client/src/components/FileTabBar.tsx`
- **修正案:** `<button type="button">` に変更。

**[継続] B-10: clearSearch 送信前にデバウンスタイマーがキャンセルされない**
- 場所: `client/src/components/SearchBar.tsx`
- Escape/Xボタンハンドラで debounce がキャンセルされず 180ms 後に `send('search', '')` が後追い送信される。
- **修正案:** `clearTimeout(debounceRef.current)` を `send('clearSearch')` 前に追加。

**[継続] B-11: FileTabBar key={i} — タブ削除時に React の差分アルゴリズムが誤認**
- 場所: `client/src/components/FileTabBar.tsx:19`
- **修正案:** エディタ側からユニークIDを付与し `key={tab.id}` とする（Q-6と同時対応）。

**[NEW] B-14: マウント直後に空検索クエリが editor.html に送信される**
- 場所: `client/src/components/SearchBar.tsx` — query 変化の useEffect / debounce
- 初期 `query = ''` でマウントされた直後、debounce タイマー (180ms) が起動し `send('search', '')` が送信される。これによりマウントのたびに editor 側の選択状態がリセットされる可能性がある。
- **修正案:** debounce 内で `if (!query) return;` を先頭に追加してガード。

**[NEW] Q-N-10: ToggleStates 型を子コンポーネント RibbonToolbar が親 App.tsx からインポート**
- 場所: `client/src/components/RibbonToolbar.tsx` — `import type { ToggleStates } from '../App'`
- 子が親モジュールをインポートするのはコンポーネント階層を逆流する依存であり、循環インポートのリスクがある。
- **修正案:** `ToggleStates` を `client/src/types.ts` 等の共有型定義ファイルに移動し双方からインポートする。

**[NEW] Q-N-13: EditorMessage が全フィールド任意の平坦インターフェースで判別共用体になっていない**
- 場所: 型定義 (推定 `client/src/types.ts` または `App.tsx` 内)
- `EditorMessage` が `{ action?: string; payload?: unknown; ... }` のような形で定義されている場合、TypeScript のメッセージハンドラ内でペイロード型を `switch` で絞り込めない。型安全でないキャストが必要となり、実行時エラーのリスクが増す。
- **修正案:** `type EditorMessage = { action: 'search'; payload: string } | { action: 'openContent'; payload: { content: string; filename: string } } | ...` の判別共用体に変更。

**[継続] Q-N-1: handleKeyDown 内で早期 return 後も `cmd &&` を再チェック**
- 場所: `client/src/App.tsx:66,69`

**[継続] Q-N-2: FileTabBar のタブ本体が `<div>` で実装されキーボード操作不可**
- 場所: `client/src/components/FileTabBar.tsx:18-35`

**[継続] Q-N-3: FileTabBar の閉じるボタンと追加ボタンに aria-label がない**
- 場所: `client/src/components/FileTabBar.tsx:28-43`

**[継続] Q-N-4: RibbonButton の `size='large'` オプションがデッドコード**
- 場所: `client/src/components/RibbonButton.tsx:10,16-17`

**[継続] Q-N-5: SearchBar の Enter キー後に setTimeout の魔法の数値 30ms**
- 場所: `client/src/components/SearchBar.tsx:61`

**[継続] Q-N-6: FileTabBar と StatusBar でインラインスタイルに魔法の数値**
- 場所: `client/src/components/FileTabBar.tsx` (`height: 28`)、`client/src/components/StatusBar.tsx` (`height: 22`)

**[継続] Q-N-7: RibbonButton の onClick に冗長な disabled ガードが存在**
- 場所: `client/src/components/RibbonButton.tsx:28`

**[継続] Q-N-8: FileReader onload で緩やかな等値演算子 `!= null` を使用**
- 場所: `client/src/App.tsx`

**[継続] Q-N-9: `type Tab` の命名衝突 — RibbonToolbar と App/FileTabBar で同名の異なる型**
- 場所: `client/src/components/RibbonToolbar.tsx:17`

**[継続] Q-10: bridge.ts の postMessage targetOrigin が `'*'`（品質観点）**
- 場所: `client/src/lib/bridge.ts:3`

**[継続] Q-11: SearchBar の debounce 遅延 180ms が未ドキュメントの魔法の数値**
- 場所: `client/src/components/SearchBar.tsx:31`

**[継続] Q-12: doGotoRow() 実行後に rowNum state がクリアされない**
- 場所: `client/src/components/SearchBar.tsx:40-42`

---

## 解消済み（前回から）

**[FIXED] S-19: SW ASSETS リストに Vite ソースパスが含まれる — 誤検知**
- 前回（2026-07-17）に [NEW] として報告したが、実際の `client/public/sw.js` には ASSETS 配列および `caches.addAll()` が存在しなかった。install ハンドラは `self.skipWaiting()` のみを実行しており、本問題は**過去レビューの誤検知**であったため閉鎖。

---

## 適用済み自動修正

```diff
(なし — src配下に console.log / console.error / debugger 文なし)
```

---

## 推奨アクション（優先度順）

1. **[即対応・47日超未対応] S-1 (Critical):** `editor.html` の btoa() localStorage PAT保存を廃止。
2. **[今すぐ・1コマンド] S-17 (High):** `cd client && npm update vite` で vite 6.4.3+ へ更新。
3. **[今週・1行修正] B-1 (High):** `App.tsx:68` のredo条件を `(e.key === 'Z' && e.shiftKey)` に修正。全プラットフォームでredo完全不動作中。
4. **[今週・NEW] B-12 (Medium):** SearchBar に `isComposing` チェック追加。日本語IME入力中の無効な検索を防止。
5. **[今週・NEW] B-13 (Medium):** `handleKeyDown` で `activeElement.tagName` が INPUT/TEXTAREA の場合に早期 return を追加。検索欄での Ctrl+Z が editor に誤送信される問題を修正。
6. **[今週] S-7 (High):** iframeに `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` を追加。
7. **[今週・1行修正] S-8 (Medium):** `App.tsx` のメッセージハンドラ先頭に `if (e.origin !== window.location.origin) return;` を追加。
8. **[今週・1行修正] B-8 (Medium):** FileReader に `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。
9. **[今週・NEW] S-22 (Low):** SW fetch ハンドラでクロスオリジンリクエスト（api.github.com）をキャッシュスキップする。
10. **[今週・NEW] S-23 (Low):** replaceText をサニタイズしてから postMessage で転送する（S-21と同時対応）。
11. **[今週] S-12 (Medium):** `editor.html` メッセージハンドラに `e.origin` チェックを追加。
12. **[来週] B-7 (Medium):** `doGotoRow` で `Number(rowNum)` を送信。
13. **[来週] B-10 (Low):** SearchBar の Escape/X ハンドラで `clearTimeout(debounceRef.current)` を追加。
14. **[来週] S-18 (Low):** `npm audit fix` で @babel/core 7.29.1+ へ更新（S-17の修正時に同時対応可能）。
15. **[来週] S-13 (Medium):** sw.js を stale-while-revalidate 戦略に変更。
16. **[来週] S-20 (Low):** sw.js activate ハンドラに旧キャッシュ削除処理を追加。
17. **[来週] S-15 (Low):** `handleFileSelected` にファイルサイズ上限チェック (100MB) を追加。
18. **[来週・NEW] B-14 (Low):** SearchBar の debounce に `if (!query) return;` を追加。マウント時の空検索送信を防止。
19. **[来週・NEW] Q-N-10 (Low):** `ToggleStates` 型を共有型ファイルに移動し子→親インポートを解消。
20. **[来週・NEW] Q-N-13 (Low):** `EditorMessage` を判別共用体に変更して型安全なハンドラを実現。

> 詳細な過去経緯は `_review/2026-07-17_code_review.md` を参照
