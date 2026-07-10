# コードレビューレポート 2026-07-10 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-10 UTC（自動レビュー）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, editor.html抜粋, client/package.json)
- 発見件数: 🔴 Critical 1 / 🟠 High 7 / 🟡 Medium 8 / 🟢 Low 16
- うち新規 [NEW]: 8件 / 継続 [継続]: 24件 / 解消 [FIXED]: 1件 (B-8)
- 適用済み自動修正: **0件**（対象コードなし）
- ⚠️ **S-1 Critical は2026-07-02以降 18日間未対応。B-1（Ctrl+Shift+Z redo不動作）も継続中。今週の新規発見: editor.html 側の origin 未検証(S-12)、window.open noopener 欠如(S-13)、location.href 漏洩(S-14) ほか品質系3件・バグ2件。前回指摘 B-8（gotoRow 上限チェック）は editor.html 側で修正済みと確認。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存**
- 場所: `client/public/editor.html:9057-9061` — `dbmGetPat()` / `dbmSavePat()`
- `btoa` は Base64 エンコードであり暗号化ではない。XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。
- **修正案:** Web Crypto API (AES-GCM) で暗号化後に保存、またはセッション変数のみに保持して localStorage 永続化を廃止。

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子、editor.html 子→親 双方向）**
- 場所: `client/src/lib/bridge.ts:2` および `editor.html:9505,9539,9589,9599` 等
- 双方向で `'*'` を使用。ファイル内容・ユーザーデータが任意オリジンに傍受されうる。
- **修正案:** 送信側 `window.location.origin` を指定。受信側も `e.origin` で検証。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `editor.html:7787-7790`
- `escHtml()` は `&<>"'` をエスケープするが `javascript:` スキームを通過させる。HTML プレビューで XSS が成立。
- **修正案:** `/^https?:\/\//i.test(url)` でホワイトリスト検証。`rel="noopener noreferrer"` を追加。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定（Shift-JIS/EUC-JP 文字化け）**
- 場所: `client/src/App.tsx` — `reader.readAsText(file)` および `editor.html:3061`
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM 検出で自動判定。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — PAT入力UI含む**
- 場所: `client/src/components/RibbonToolbar.tsx:197` — `ToolsTab` 内の「デバッグ」グループに `import.meta.env.DEV` ガードなし
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `editor.html:7793-7794` — `<span style="color:${escHtml(q || nq || "")}">`
- `escHtml` はセミコロン・コロン・スラッシュを変換しないため CSS インジェクションが可能。
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]+|rgb\(\d+,\s*\d+,\s*\d+\))$/.test(color)` で検証。

**[継続] S-7: iframe に sandbox 属性なし → XSS 時に親フレームをリダイレクト可能**
- 場所: `client/src/App.tsx` — `<iframe allow="clipboard-read; clipboard-write; popups">`
- sandbox 属性がないため iframe 内から `window.parent.location` による強制リダイレクトが可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` を追加（`allow-top-navigation` は除外）。

---

### 🟡 Medium

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx` — message イベントハンドラ（origin チェックなし）
- 任意オリジンからの postMessage で UI 状態が操作される可能性。
- **修正案:** `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合（レースコンディション）**
- 場所: `client/src/components/SearchBar.tsx` — 置換ボタン onClick
- `send('search', query); send('replaceOne', replaceText)` を同期的に送信。検索インデックス確定前に置換が実行されセルがずれる。
- **修正案:** `searchCount` 応答受信後に replace を発行するコールバック方式に変更。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `editor.html` / `index.html` — CSP ヘッダー・メタタグなし
- S-3・S-6 成功時の外部スクリプト・データ送信が無制限。
- **修正案:** `default-src 'self'; script-src 'self'; connect-src 'self' https://api.github.com;`

**[継続] S-11: allow="popups" による iframe へのポップアップ権限付与（sandbox なしと組み合わせ）**
- 場所: `client/src/App.tsx` — `<iframe allow="clipboard-read; clipboard-write; popups">`
- S-7 と組み合わせてフィッシングウィンドウの開封が可能。S-7 の sandbox 適用で同時解決可能。

**[NEW] S-12: editor.html の postMessage ハンドラが `e.source` のみ検証し `e.origin` を未確認**
- 場所: `editor.html:9339-9341` — `if (e.source !== window.parent) return;`
- `e.source === window.parent` でウィンドウオブジェクトを照合しているが、親フレームがクロスオリジンへナビゲートされた後も条件を満たす別オリジンのメッセージが `openContent`・`replaceAll` 等の破壊的アクションを実行できる。
- **修正案:** `if (e.source !== window.parent || e.origin !== window.location.origin) return;` に変更。

---

## コード品質所見

**[継続] Q-1: console.warn / console.error 8件が本番コードに残存**
- 場所: `editor.html:7891,7893,9031,9048,9524,9557` 等
- **修正案:** Vite の `build.drop: ['console']` オプション適用。

**[継続] Q-2: focusEditor() が空の catch で失敗を握りつぶす**
- 場所: `client/src/lib/bridge.ts:7-11` — `catch {}`
- **修正案:** `catch (e) { if (import.meta.env.DEV) console.warn('[bridge] focusEditor failed:', e) }`

**[継続] Q-3: message ハンドラの型判別に `else if` が使われていない**
- 場所: `client/src/App.tsx` — message イベントハンドラ（8本の独立 `if` 文）
- **修正案:** `switch` 文または `else if` チェーンに変更。

**[継続] Q-4: SearchBar の externalQuery 同期エフェクトにスタレクロージャーリスク**
- 場所: `client/src/components/SearchBar.tsx:22-27` — `eslint-disable-next-line` で警告抑制のまま放置。
- **修正案:** `setQuery(prev => externalQuery !== prev ? externalQuery : prev)` で関数形式に変更し deps から `query` を除外。

**[継続] Q-5: `unescape()` 使用（非推奨 API）**
- 場所: `editor.html:9264`
- **修正案:** `const bytes = new TextEncoder().encode(md); const mdBase64 = btoa(String.fromCharCode(...bytes));`

**[NEW] Q-6: `FileReader.result` への unsafe type assertion**
- 場所: `client/src/App.tsx` — `const content = ev.target?.result as string`
- `FileReader.result` の型は `string | ArrayBuffer | null`。強制キャストでは将来のリファクタリング時に実行時エラーの原因となる。
- **修正案:** `if (typeof content === 'string') { send('openContent', ...) }` の型ガードに変更。

**[NEW] Q-7: SearchBar の debounce 実装が冗長（ref 不要）**
- 場所: `client/src/components/SearchBar.tsx` — `debounceRef` を使う手動 clearTimeout と cleanup 関数が重複。
- `debounceRef.current` 再代入後に cleanup が読む時点でタイマーIDが更新済みの可能性があり意図しないキャンセルが発生し得る。
- **修正案:** `const timer = setTimeout(() => send('search', query), 180); return () => clearTimeout(timer)` に簡略化。

**[NEW] Q-8: `send()` の `action` 引数が非型安全（タイポ検出不可）**
- 場所: `client/src/lib/bridge.ts` — `send(action: string, ...)`
- 呼び出し側でタイポしてもコンパイルエラーにならない。
- **修正案:** 有効アクション名を union 型で定義: `type EditorAction = 'undo' | 'redo' | 'search' | 'replaceOne' | ...`

---

## バグ・ロジックリスク

**[継続] B-1: Ctrl+Shift+Z redo が動作しない（`e.key` 大文字小文字バグ）**
- 場所: `client/src/App.tsx:65`
  ```tsx
  } else if (cmd && ((e.key === 'z' && e.shiftKey) || e.key === 'y' || e.key === 'Y')) {
  ```
- Shift 押下時ブラウザは `e.key = 'Z'`（大文字）を返す。undo側 `(e.key === 'z' || e.key === 'Z') && !e.shiftKey` は修正済みだが、redo の `e.key === 'z' && e.shiftKey` が未修正のため Ctrl+Shift+Z が常に false。
- **修正案（1文字）:** `e.key === 'z'` → `(e.key === 'z' || e.key === 'Z')`

**[継続] B-2: `handleKeyDown` 内で `cmd &&` の冗長な二重チェック**
- 場所: `client/src/App.tsx:57-66`
- `if (!cmd) return` による早期リターン後も `if (cmd && ...)` と再評価。

**[継続] B-3: FileReader の `onerror` ハンドラが未定義**
- 場所: `client/src/App.tsx` — `handleFileSelected`
- ファイル読み込み失敗時に UI 側で何も通知されない（サイレント失敗）。
- **修正案:** `reader.onerror = () => setStatus('ファイルの読み込みに失敗しました');` を追加。

**[継続] B-4: SearchBar 初期マウント時に不要な `search('')` が 180ms 後に送信される**
- 場所: `client/src/components/SearchBar.tsx` — query useEffect
- **修正案:** `isMounted` フラグで初回実行をスキップ。

**[継続] B-5: clearSearch が折り返し postMessage でデバウンスを二重発火させる**
- 場所: `editor.html` / `SearchBar.tsx`
- **修正案:** `{ type: 'clearSearch', fromParent: true }` で起点を区別しループを抑制。

**[継続] B-6: FileTabBar のタブに配列インデックスを key として使用**
- 場所: `client/src/components/FileTabBar.tsx` — `key={i}`
- タブ削除時に React が誤ったノードを再利用する可能性。
- **修正案:** `Tab` に `id: string` を追加し `key={tab.id}` に変更。

**[継続] B-7: Service Worker のキャッシュバージョンが固定 → セキュリティ修正が既存ユーザーに届かない**
- 場所: `client/public/sw.js:1` — `CACHE = 'tsv-editor-v1'`
- **修正案:** ビルド時コンテンツハッシュで自動インクリメント。

**[FIXED] B-8: gotoRow の行番号上限・下限チェック — 解消確認**
- 場所: `editor.html:7411,7415-7418`
- `n < 1` の下限チェックおよび `n > state.data.length` の上限チェックが実装済みであることを確認。本 finding は解消済み。

**[継続] B-9: Enter キー後の `searchNext/Prev` を 30ms 固定遅延で送信するレース条件**
- 場所: `client/src/components/SearchBar.tsx` — Enter キーハンドラ
- 30ms はエディタ側の検索インデックス確定を保証しない。大きな CSV でナビゲーションが「ヒットなし」と誤判定される。
- **修正案:** `searchReady` 応答を受け取ってから `searchNext/Prev` を送信するコールバック方式に変更。

**[NEW] B-10: Service Worker の `respondWith` がオフライン+キャッシュ未ヒット時に `undefined` に解決**
- 場所: `client/public/sw.js:12-16`
  ```js
  cached || fetch(e.request).then(resp => {
    if (resp.ok) cache.put(e.request, resp.clone());
    return resp;
  }).catch(() => cached)  // cached は undefined
  ```
- キャッシュヒットなし+ネットワーク失敗時、`.catch(() => cached)` が `undefined` を返す。SW 仕様では `respondWith(undefined)` は `TypeError` を発生させコンソールエラーになる。オフライン時のフォールバックが機能しない。
- **修正案:** `.catch(() => cached || new Response('Offline', { status: 503 }))` とする。

**[NEW] B-11: App.tsx の message ハンドラが `e.source` を未検証（e.origin チェック(S-8)と異なる攻撃経路）**
- 場所: `client/src/App.tsx` — message イベントハンドラ
- editor.html 側は `if (e.source !== window.parent) return` でソース検証しているが、親フレーム(App.tsx)は `e.source` も `e.origin` も未検証。ページ上の別スクリプトや意図せず追加された iframe が `{ type: 'tabs', tabs: [] }` 等を送信してUI状態を書き換えられる。
- **修正案:** `if (e.source !== document.getElementById('editor-frame')?.contentWindow) return` を S-8 の origin チェックと合わせて追加。

---

## セキュリティ新規所見（続き）

**[NEW] S-13: `window.open()` に `noopener` を指定せず Reverse Tabnapping が成立**
- 場所: `editor.html:8269,8503` — HTML プレビュー・出力時の `window.open(url, "_blank")`
- 開かれたタブが `window.opener` 経由で親ウィンドウをナビゲートできる（Reverse Tabnapping）。
- **修正案:** `window.open(url, "_blank", "noopener,noreferrer")` に変更（2件）。

**[NEW] S-14: デバッグメモに `location.href` 全体を含めて GitHub にプッシュ（クエリパラメータ漏洩）**
- 場所: `editor.html:9258` — `` md += `- URL: ${location.href}\n\n`; ``
- クエリパラメータやフラグメントに機密情報が含まれる場合、GitHub のコミット履歴に永続残存する。
- **修正案:** `location.origin + location.pathname` のみ記録してクエリ文字列を除外。

---

## 適用済み自動修正

```diff
（なし）
```

TypeScript ソースファイル (App.tsx, bridge.ts, SearchBar.tsx, RibbonToolbar.tsx) に `console.log`・`debugger` 文は確認されず。`editor.html` 内の `console.warn/error` は意図的なエラーハンドラと判断しロジック変更を避けるため自動修正対象外。

---

## 推奨アクション（優先度順）

1. **🔴 即対応** — **S-1**: PAT の btoa/localStorage 保存を廃止し Web Crypto (AES-GCM) またはセッション変数に移行
2. **🟠 早期対応** — **S-7 + S-11**: `App.tsx` の iframe に `sandbox` 属性を追加 + `allow="popups"` を削除
3. **🟠 早期対応** — **S-2 + S-8 + S-12**: postMessage の origin 検証を parent・child 双方向で徹底
4. **🟡 1行修正** — **B-1**: `e.key === 'z' && e.shiftKey` → `(e.key === 'z' || e.key === 'Z') && e.shiftKey` に変更
5. **🟠 早期対応** — **S-5**: `ToolsTab` の「デバッグ」グループを `import.meta.env.DEV` でガード
6. **🟠 早期対応** — **S-3**: `javascript:` URL をホワイトリスト検証（1行修正）
7. **🟡 今週中** — **S-12**: `editor.html` handler に `e.origin` チェック追加 [NEW]
8. **🟡 今週中** — **S-13**: `window.open` に `"noopener,noreferrer"` 追加（2箇所）[NEW]
9. **🟡 今週中** — **S-10**: CSP ヘッダーを追加
10. **🟡 今週中** — **B-3**: `reader.onerror` ハンドラを追加
11. **🟡 今週中** — **B-9**: searchNext/Prev の 30ms 固定遅延を応答駆動コールバックに変更
12. **🟡 今週中** — **S-14**: デバッグメモから `location.href` クエリパラメータを除外 [NEW]
13. **🟢 余裕時** — **B-10**: SW の offline フォールバックを `Response('Offline', {status:503})` に変更 [NEW]
14. **🟢 余裕時** — **B-11**: App.tsx message handler に `e.source` チェック追加（S-8 と同時適用） [NEW]
15. **🟢 余裕時** — **Q-6**: `FileReader.result` の型アサーションを型ガードに変更 [NEW]
16. **🟢 余裕時** — **Q-7**: SearchBar のデバウンス実装を標準パターンに簡略化 [NEW]
17. **🟢 余裕時** — **Q-8**: `send()` の `action` 引数を union 型で型付け [NEW]
18. **🟢 余裕時** — **Q-4 + Q-5**: externalQuery 同期と `unescape()` の改修
19. **🟢 余裕時** — **B-6**: FileTabBar の `key={i}` を安定IDに変更

---

## 依存パッケージ状況

```json
"react": "^19.0.0"           // 最新メジャー — OK
"vite": "^6.0.5"             // 最新安定版 — OK
"lucide-react": "^0.477.0"   // 2025年初頭リリース — 更新確認推奨（2026-07時点で最新でない可能性）
"@playwright/test": "1.56.1" // ピン留め — 更新確認推奨
"typescript": "~5.6.2"       // 5.x系 — OK
```

特筆すべき既知脆弱パッケージなし（2026-07-10 時点）。
