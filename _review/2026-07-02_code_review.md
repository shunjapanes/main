# コードレビューレポート 2026-07-02 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-02 (UTC)
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (editor.html, App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, RibbonButton/Group.tsx)
- 発見件数: 🔴 Critical 1 / 🟠 High 7 / 🟡 Medium 10 / 🟢 Low 2
- うち新規 [NEW]: 6件 / 継続 [継続]: 14件
- 適用済み自動修正: 2件（SEJ debug console.log 削除）
- ⚠️ **前回レビュー(2026-07-01)からコード変更なし。Critical/High指摘が1ヶ月以上継続未対応。**
- ✅ **改善: editor.html の postMessage 受信ハンドラに `e.source !== window.parent` チェックが追加（部分的改善）**

---

## セキュリティ所見

### 🔴 Critical

**[継続] H-1: GitHub PAT を btoa() のみで localStorage に保存 — 1ヶ月超未対応**
- 場所: `client/public/editor.html:9065-9069` — `dbmGetPat()` / `dbmSavePat()`
- `btoa` はエンコードであり暗号化ではない。`atob(localStorage.getItem(key))` で即座に PAT を取得可能。XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。
- **修正案:** Web Crypto API (AES-GCM) で暗号化、またはセッション限りのメモリ保持に変更し localStorage への永続化を廃止。

---

### 🟠 High

**[継続] H-2: postMessage targetOrigin が `'*'`（親→子・子→親とも）**
- 場所: `client/src/lib/bridge.ts:3`、`editor.html` 複数箇所（9513, 9547, 9597, 9634, 9638, 9661 等）
- 任意オリジンの悪意あるページがメッセージを受信可能。
- ✅ 改善: editor.html 受信側に `if (e.source !== window.parent) return;` が追加（部分的改善。`e.origin` 検証の追加が引き続き必要）
- **修正案:** `postMessage` 第2引数を `window.location.origin` に変更。受信側に `e.origin !== 'https://shunjapanes.github.io'` 検証を追加。

**[継続] H-3/H-5: `<a href>` の URL に `javascript:` スキームを検証しない**
- 場所: `editor.html:7787-7790`（リッチレンダリングの `<a href>` 復元処理）
- `escHtml()` は `<>&"` をエスケープするが `javascript:` を含まないため XSS が成立。セル値 `<a href="javascript:alert(1)">click</a>` が実行可能。
- **修正案:** `const safeUrl = /^https?:/i.test(url) ? url : '#';` でホワイトリスト検証、`rel="noopener noreferrer"` を追加。

**[NEW] N-1: アンカーテキストが escHtml 未適用（XSS）**
- 場所: `editor.html:7790`
- `<a href="URL">TEXT</a>` の TEXT 部分が escHtml() を通らずそのままDOMに注入される。
  ```js
  return `<a href="${escHtml(url)}" ...>${text}</a>`;  // text が未サニタイズ
  ```
- セル値に `<a href="http://x.com"><img src=x onerror=alert(1)></a>` を入れると XSS が成立。
- **修正案:** `${escHtml(text)}` に変更する。

**[継続] H-4: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`（エンコーディング引数なし = UTF-8固定）
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM 検出で自動判定、またはUIでエンコーディング選択を提供。

**[継続] M-3（High相当）: デバッグ機能 (debugMemo) が本番 UI に露出**
- 場所: `client/src/components/RibbonToolbar.tsx`（「デバッグ」グループ、Bug アイコン）
- GitHub PAT 入力 UI を含むデバッグ機能が全ユーザーに公開。本番ビルドに含まれる。
- **修正案:** `if (import.meta.env.DEV)` ガードまたは別ビルドターゲットへ分離。

**[継続] B-2: 置換ボタンが search と replaceOne を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-104`
- `search` 完了前に `replaceOne` / `replaceAll` が実行され置換対象がずれる。
- **修正案:** iframe から `searchDone` ACK を受け取ってから置換を送るイベント駆動方式に変更。

**[NEW] B-3: 置換ボタン押下時に debounce タイマーが未キャンセル**
- 場所: `client/src/components/SearchBar.tsx`
- クエリ入力後 180ms 以内に置換ボタンを押すと、ボタンの `search → replaceOne` 送出後に残存 debounce タイマーが追加の `search` を送出し、置換後の状態を上書きする。
- **修正案:** onClick ハンドラ先頭で `clearTimeout(debounceRef.current)` を呼ぶ。

---

### 🟡 Medium

**[継続] M-1: App.tsx の message ハンドラに e.origin 検証なし**
- 場所: `client/src/App.tsx:77`
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] M-2: iframe に sandbox 属性なし**
- 場所: `client/src/App.tsx:141-147`
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-popups allow-downloads"` を追加。

**[継続] M-4: CSP (Content-Security-Policy) なし**
- 場所: `client/index.html` head 部分
- **修正案:** `default-src 'self'; script-src 'self'; frame-src 'self'` を最低限設定。

**[継続] M-5: Service Worker が Cache-first 戦略でセキュリティ更新が遅延**
- 場所: `client/public/sw.js`
- **修正案:** stale-while-revalidate 戦略に変更、またはビルドハッシュをキャッシュ名に含める。

**[継続] M-6: ファイル読み込みの reader.onerror なし**
- 場所: `client/src/App.tsx:113` — `handleFileSelected`
- 読込失敗時にユーザー通知なし（サイレント失敗）。
- **修正案:** `reader.onerror = () => send('status', 'ファイル読み込みに失敗しました');` を追加。

**[継続] M-7: dbmUpload 画像アップロードエラー時にリンク切れ Markdown がコミットされる**
- 場所: `editor.html`（dbmUpload 処理）
- **修正案:** 画像アップロード成功を確認してから本文アップロードを実行するよう順序制御。

**[継続] M-8: colStats エラーがステータスバーのみに通知されサイレント障害**
- 場所: `editor.html`（colStats ハンドラ）

**[NEW] M-9: 未知の bridge action で TypeError が発信元に伝播しない**
- 場所: `editor.html:9565`
  ```js
  try { dispatch[action](); } catch(err) { console.warn('[bridge]', action, err); }
  ```
- 未定義アクションや型エラーが `console.warn` のみで React 側には返らず、サイレント障害になる。
- **修正案:** 未知アクション検出 (`typeof dispatch[action] !== 'function'`) と React へのエラー返送を追加。

**[NEW] M-10: ファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx:113` — `handleFileSelected`
- 数百MB のファイルを選択すると `readAsText` が全量展開後 postMessage でコピーされ、実メモリ使用量が 2〜3 倍になりタブクラッシュのリスク。
- **修正案:** `if (file.size > 50 * 1024 * 1024) { send('status', 'ファイルサイズが大きすぎます (上限 50MB)'); return; }` を追加。

---

## バグ・ロジックリスク

（B-2, B-3 は High セクションに記載済み）

---

## コード品質所見

**[NEW] N-2: CSS プロパティインジェクション（font color 経由）**
- 場所: `editor.html:7795`
  ```js
  `<span style="color:${escHtml(q || nq || "")}">`
  ```
- `escHtml` は `;` や `:` をエスケープしないため、`red; background-image: url(x)` のような CSS インジェクションが可能。UI 偽装に悪用できる（スクリプト実行は現代ブラウザでは困難）。
- **重要度:** 🟢 Low
- **修正案:** `/^[a-zA-Z0-9#(),. %]+$/` でカラー値を検証しホワイトリスト制御。

**[NEW] L-1: stateSync メッセージのフィールドが型検証なしで state に反映**
- 場所: `client/src/App.tsx`（stateSync ハンドラ）
- `MessageEvent.data` 由来で実質 `any`。`!!undefined === false` で現状クラッシュはしないが、悪意ある postMessage で toggle 状態が書き換わる（M-1 と組み合わさると攻撃経路になる）。
- **重要度:** 🟢 Low

---

## 適用済み自動修正

```diff
--- a/client/public/editor.html
+++ b/client/public/editor.html
@@ -7877,13 +7877,6 @@
               .find(i => i !== -1);
             const grpKey = grpKeyIdx != null ? headers[grpKeyIdx] : null;
-            console.log("[SEJ] 仮想列追加チェック:", {
-              curCodeIdx,
-              masterHeaders: normHeaders,
-              grpKey,
-              hasExistingVirtual: !!state.sejVirtualCols,
-              dataRows: state.data.length,
-            });
             if (curCodeIdx !== -1 && grpKey && !state.sejVirtualCols) {
@@ -7894,7 +7887,6 @@
               state.sejVirtualCols = { indices: [vIdx], keys: [grpKey] };
               if (state.displayHeaders) state.displayHeaders.push("グループ名");
-              console.log("[SEJ] 仮想列追加完了 index=" + vIdx);
             } else if (!grpKey) {
```

- 削除: `console.log("[SEJ] 仮想列追加チェック:", {...})` (editor.html:7880-7886)
- 削除: `console.log("[SEJ] 仮想列追加完了 index=" + vIdx)` (editor.html:7897)

---

## 推奨アクション（優先度順）

1. **[最優先] H-1: PAT の localStorage 保存廃止** — セキュリティリスク最大。XSS から PAT 窃取・リポジトリ書き込みの攻撃チェーンを断つ。
2. **[新規・要即対応] N-1: アンカーテキストを `escHtml(text)` でサニタイズ** — 1行修正で XSS を防止。`editor.html:7790` の `${text}` を `${escHtml(text)}` に変更。
3. **[新規・要即対応] B-3: 置換ボタンの debounce キャンセル** — `onClick` 先頭に `clearTimeout(debounceRef.current)` を追加。
4. **H-3/H-5: `javascript:` スキーム検証** — `safeUrl` ホワイトリストを追加（1行修正）。
5. **M-10: ファイルサイズ上限チェック** — `handleFileSelected` に 50MB ガード追加（3行修正）。
6. **H-2: postMessage targetOrigin を `window.location.origin` に変更** — bridge.ts と editor.html 全 `postMessage` 呼び出しを修正。
7. **M-2: iframe sandbox 属性追加** — App.tsx に `sandbox="allow-scripts allow-same-origin allow-popups allow-downloads"` を追加。
8. **M-4: CSP ヘッダ追加** — `client/index.html` head に meta タグで最小限 CSP を設定。
9. **M-3: デバッグ機能を DEV ビルドのみに制限** — `import.meta.env.DEV` ガードを追加。
10. **M-6: reader.onerror ハンドラ追加** — ファイル読み込みエラー時のユーザー通知を追加。
