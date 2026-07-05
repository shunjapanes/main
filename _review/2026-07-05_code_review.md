# コードレビューレポート 2026-07-05 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-05 00:00 UTC
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (editor.html, App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, RibbonButton/Group.tsx)
- 発見件数: 🔴 Critical 1 / 🟠 High 9 / 🟡 Medium 11 / 🟢 Low 2
- うち新規 [NEW]: 0件 / 継続 [継続]: 23件
- 適用済み自動修正: **0件**（前回修正済み、今回対象なし）
- ⚠️ **前回レビュー(2026-07-04)からコード変更なし。Critical/High指摘が継続未対応（最長 2ヶ月超）。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] H-1: GitHub PAT を btoa() のみで localStorage に保存 — 2ヶ月超未対応**
- 場所: `client/public/editor.html` — `dbmGetPat()` / `dbmSavePat()`
- `btoa` はエンコードであり暗号化ではない。`atob(localStorage.getItem(key))` で即座に PAT を取得可能。XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。
- **修正案:** Web Crypto API (AES-GCM) で暗号化、またはセッション限りのメモリ保持に変更し localStorage への永続化を廃止。

---

### 🟠 High

**[継続] H-2: postMessage targetOrigin が `'*'`（親→子）**
- 場所: `client/src/lib/bridge.ts:3`
- 任意オリジンの悪意あるページがメッセージを受信可能。action や payload に機密情報が含まれる場合に情報漏洩。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に変更。

**[継続] H-3: `<a href>` の URL に `javascript:` スキームを検証しない**
- 場所: `editor.html`（リッチレンダリングの `<a href>` 復元処理）
- `escHtml()` は `<>&"` をエスケープするが `javascript:` を含まないため XSS が成立。
- **修正案:** `/^https?:/i.test(url)` でホワイトリスト検証、`rel="noopener noreferrer"` を追加。

**[継続] H-4: アンカーテキストが escHtml 未適用（XSS）**
- 場所: `editor.html`（リッチレンダリング）
- `<a href="URL">TEXT</a>` の TEXT 部分が escHtml() を通らずそのまま DOM に注入される。
- **修正案:** `${escHtml(text)}` に変更する（1行修正）。

**[継続] H-5: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)` （エンコーディング引数なし = UTF-8固定）
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM 検出で自動判定、またはUIでエンコーディング選択を提供。

**[継続] H-6: デバッグ機能 (debugMemo) が本番 UI に露出**
- 場所: `client/src/components/RibbonToolbar.tsx`（「デバッグ」グループ）
- GitHub PAT 入力 UI を含むデバッグ機能が全ユーザーに公開。本番ビルドに含まれる。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] B-2: 置換ボタンが search と replaceOne を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- `search` 完了前に `replaceOne` / `replaceAll` が実行され置換対象がずれる。
- **修正案:** `replaceOne/All` に query を同梱した単一メッセージとして送信し、エディタ側でアトミックに処理。

**[継続] B-3: 置換ボタン押下時に debounce タイマーが未キャンセル**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- クエリ入力後 180ms 以内に置換ボタンを押すと、残存 debounce タイマーが追加の `search` を送出し置換後の状態を上書きする。
- **修正案:** onClick ハンドラ先頭で `if (debounceRef.current) clearTimeout(debounceRef.current)` を呼ぶ。

**[継続] S-11: editor.html の postMessage 受信側で e.origin 未検証（埋め込み攻撃）**
- 場所: `client/public/editor.html`（postMessage 受信リスナー）
- `if (e.source !== window.parent) return;` のみで検証し `e.origin` を確認しない。攻撃者が editor.html を iframe に埋め込むと全アクション（openContent・replaceAll・debugMemo）がリモートから実行可能。H-3/H-4 の XSS と連鎖して任意スクリプト実行に至る。
- **修正案:** `if (e.source !== window.parent || e.origin !== location.origin) return;` に変更する（1行修正）。

**[継続] Q-8: Enter キー検索の 30ms 固定遅延が競合防止として不十分**
- 場所: `client/src/components/SearchBar.tsx:61`
- 大規模ファイル検索時は 30ms では search 完了が保証されず、searchNext が空の検索結果に対して実行される。
- **修正案:** `searchAndNext` アトミックメッセージをエディタ側で実装し、タイミング依存を排除。

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
- 場所: `client/src/App.tsx:108-113`
- **修正案:** `reader.onerror = () => { send('status', 'ファイルの読み込みに失敗しました') }` を追加。

**[継続] M-7: dbmUpload 画像アップロードエラー時にリンク切れ Markdown がコミットされる**
- 場所: `editor.html`（dbmUpload 処理）
- **修正案:** 画像アップロード成功を確認してから本文アップロードを実行するよう順序制御。

**[継続] M-8: colStats エラーがステータスバーのみに通知されサイレント障害**
- 場所: `editor.html`（colStats ハンドラ）

**[継続] M-9: 未知の bridge action で TypeError が発信元に伝播しない**
- 場所: `editor.html`（dispatch ハンドラ）
- **修正案:** 未知アクション検出と React へのエラー返送を追加。

**[継続] M-10: ファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx:105-115`
- 数百MB のファイルでタブクラッシュリスク。
- **修正案:** `if (file.size > 50 * 1024 * 1024) { send('status', 'ファイルサイズが大きすぎます (上限 50MB)'); return }` を追加。

**[継続] N-1: focus() がユーザージェスチャー外の postMessage から呼ばれる**
- 場所: `client/src/App.tsx:82`
- Chrome 92+ の Focus-Without-User-Activation ポリシーで focus() が無視されるケースがある。
- **修正案:** `scrollIntoView()` フォールバックを追加。

**[継続] N-2: 早期リターン後の条件式に冗長な `cmd &&` が残存**
- 場所: `client/src/App.tsx:50-54`
- **修正案:** 早期リターン以降の `if` 文内の `cmd &&` を削除。

---

## バグ・ロジックリスク

**[継続] L-1: stateSync メッセージのフィールドが undefined 時にデフォルト値を上書き**
- 場所: `client/src/App.tsx:84-92`
- **修正案:** `msg.verticalHeaderActive ?? DEFAULT_TOGGLES.verticalHeaderActive` に変更。

**[継続] L-2: EditorMessage の type union 拡張時にハンドラ追加漏れがサイレント**
- 場所: `client/src/App.tsx:17-30`
- **修正案:** ハンドラ末尾に `else { console.warn('[App] unknown message type:', msg.type) }` を追加（DEV のみ）。

---

## コード品質所見

**[継続] S-12: dispatch アクション名を hasOwnProperty で検証しない**
- 場所: `client/public/editor.html`（dispatch テーブル参照部分）
- `'constructor'` や `'toString'` 等のプロトタイプ継承メソッド名を action に渡すと呼び出しが成立する。S-11 と相互影響。
- **修正案:** `Object.prototype.hasOwnProperty.call(dispatch, action) && typeof dispatch[action] === 'function'` で検証。

**[継続] CQ-1: CSS プロパティインジェクション（font color 経由）**
- 場所: `editor.html`（リッチレンダリング）
- **重要度:** 🟢 Low
- **修正案:** `/^[a-zA-Z0-9#(),. %]+$/` でカラー値を検証。

---

## 適用済み自動修正

今回は自動修正対象なし（前回 2026-07-02 に console.log 2件を削除済み）。

---

## 推奨アクション（優先度順）

1. **[最優先・継続] H-1: PAT の localStorage 保存廃止** — 2ヶ月超未対応。XSS → PAT 窃取 → リポジトリ書き込みの攻撃チェーンが成立中。
2. **[最優先・継続] S-11: editor.html に `e.origin` 検証追加** — 1行修正で埋め込み攻撃を防止: `if (e.source !== window.parent || e.origin !== location.origin) return;`
3. **[継続] H-4: アンカーテキストを `escHtml(text)` でサニタイズ** — 1行修正で XSS を防止。
4. **[継続] B-2/B-3 + Q-8: 置換・検索のタイミング競合を根本解決** — `replaceOne/All` に query 同梱化、Enter は `searchAndNext` アトミック化。
5. **[継続] H-3: `javascript:` スキーム検証追加** — 1行修正。
6. **[継続] M-10: ファイルサイズ上限チェック** — `handleFileSelected` に 50MB ガード追加（3行）。
7. **[継続] M-6: reader.onerror ハンドラ追加** — ファイル読み込みエラー時のユーザー通知（1行）。
8. **[継続] H-2: postMessage targetOrigin を `window.location.origin` に変更** — bridge.ts と editor.html 全 `postMessage` 呼び出しを修正。
9. **[継続] M-2: iframe sandbox 属性追加** — App.tsx に追加（1行）。
10. **[継続] M-4: CSP ヘッダ追加** — `client/index.html` head に meta タグで最小限 CSP を設定。
11. **[継続] H-6: デバッグ機能を DEV ビルドのみに制限** — `import.meta.env.DEV` ガード追加。
12. **[継続] L-1: stateSync の nullish coalescing 対応** — デフォルト値の意図せぬ上書き防止。
13. **[継続] N-1: focus() ポリシー対応** — scrollIntoView フォールバック追加。
