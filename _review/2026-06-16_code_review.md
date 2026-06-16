# コードレビューレポート 2026-06-16 — shunjapanes/main

## サマリー

- 実行日時: 2026-06-16 16:04 UTC
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (editor.html, App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, RibbonButton/Group.tsx)
- 発見件数: 🔴 Critical 1 / 🟠 High 6 / 🟡 Medium 10 / 🟢 Low 7
- うち新規 [NEW]: 8件 / 継続 [継続]: 16件
- 適用済み自動修正: 2件 (console.log 削除)

---

## セキュリティ所見

### 🔴 Critical

**[継続] H-1: GitHub PAT を btoa() のみで localStorage に保存**
- 場所: `client/public/editor.html:9066-9069` — `dbmGetPat()` / `dbmSavePat()`
- btoa はエンコードであり暗号化ではない。DevTools から即座に `atob(localStorage.getItem('tsv-editor-debug-memo-pat'))` で取得可能。PAT に repo スコープがあるため XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。
- **修正案:** PAT はセッション変数（メモリのみ）に保持するか、Web Crypto API (AES-GCM) で暗号化して保存。

### 🟠 High

**[継続] H-2: postMessage targetOrigin が `'*'`（送受信とも）**
- 場所: `client/src/lib/bridge.ts:3`、`editor.html:9513,9547,9597,9607,9617,9623,9634,9638,9661`
- 親→子・子→親の両方向で `'*'` を使用。クロスオリジン環境では悪意ある第三者がメッセージを傍受・注入可能。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に変更。受信側に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] H-3: `<a href>` の URL に `javascript:` スキームを検証しない**
- 場所: `editor.html:7787-7790`（セルリッチレンダリング）
- `escHtml(url)` は HTML エンティティをエスケープするが `javascript:` スキームを許可。セル値に `javascript:alert(1)` を書いてリンクをクリックすると XSS が実行される。
- **修正案:** `const safeUrl = /^https?:/i.test(url) ? url : '#';` に絞る。`rel="noopener noreferrer"` も追加。

**[NEW] H-5: 生URL自動リンク化パス（`<a href>`構文）も同じく javascript: を許可**
- 場所: `editor.html:7787` — H-3 と同根。正規表現パスは `https?:` で絞るが HTML 構文解析パスは未検証のまま。
- H-3 の対策と同時に対処可能。

**[継続] H-4: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`（エンコーディング引数なし = UTF-8固定）
- Shift-JIS / EUC-JP の日本語 CSV/TSV を開くと文字化けし、データの誤操作を招く。
- **修正案:** `readAsArrayBuffer` → `TextDecoder` + BOM 検出 ライブラリで自動判定。

**[継続] M-3（昇格）: デバッグ機能 (dbm*) が本番 UI に露出**
- 場所: `editor.html:9066-9280`、`client/src/components/RibbonToolbar.tsx`（ツールバー「デバッグ」グループ）
- GitHub PAT 入力 UI を含むデバッグ機能が全ユーザーに公開されている。ツリーシェイクされず本番ビルドに含まれる。
- **修正案:** `if (import.meta.env.DEV)` ガードまたは別ビルドターゲットへ分離。

### 🟡 Medium

**[継続] M-1: App.tsx の message ハンドラに e.origin 検証なし**
- 場所: `client/src/App.tsx:77`
- 任意ページが `{type:'stateSync', freezeActive:true}` 等を postMessage すると親 React の状態を書き換え可能。
- **修正案:** `if (e.origin !== window.location.origin) return;` をハンドラ先頭に追加。

**[継続] M-2: iframe に sandbox 属性なし**
- 場所: `client/src/App.tsx:141-147`
- editor.html は完全な同一オリジン権限を持ち、最小権限の原則に反する。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-popups allow-downloads"` を追加。

**[継続] M-4: CSP (Content-Security-Policy) なし**
- 場所: `index.html` head 部分
- XSS 成立時の第2防衛線がない。
- **修正案:** `default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;` を設定。

**[継続] M-5: Service Worker が Cache-first 戦略でセキュリティ更新が遅延**
- 場所: `client/public/sw.js:9-17` — キャッシュ名 `tsv-editor-v1` が固定
- **修正案:** stale-while-revalidate 戦略に変更、またはビルドハッシュをキャッシュ名に含める。

**[NEW] M-6: SEJ・価格参照ファイルロードに reader.onerror なし**
- 場所: `editor.html:7835-7937`（loadSejMasterFile）、`editor.html:8012-8041`（loadPriceRefFile）
- loadFile() には onerror 実装済みだが、これら2関数の FileReader には未設定。読込失敗時にユーザー通知なし。
- **修正案:** `reader.onerror = () => showStatus('ファイル読み込みに失敗しました');` を追加。

**[NEW] M-7: dbmUpload 画像アップロードエラー時にリンク切れ Markdown がコミットされる**
- 場所: `editor.html:9251-9255`
- 画像アップロード失敗後も本文アップロードが続行され、壊れた画像参照を含む Markdown が GitHub に push される。
- **修正案:** 画像アップロードに失敗した場合は全体処理を中断してユーザーに通知。

**[NEW] M-8: sortByColumn 後に cellColors の行インデックスが古いまま**
- 場所: `editor.html:3562-3568`
- `_sortDataUpdateColors` が `_dupSet` を更新しているが、`state.cellColors`（手動セル着色）の行インデックス再マッピングが実装されていない可能性がある。修正コミット 3a4e274 でヘッダーモードバグは修正済みだが副作用として残存。
- **修正案:** ソート後に `cellColors` を新しい行インデックスにリマップする処理を追加。

### 🟢 Low

**[NEW] L-1: コンテキストメニューの `g.icon` / `g.group` が escHtml なし**
- 場所: `editor.html:6580-6586`
- 現在はコード内定数なので実害なし。将来的に動的化する場合の XSS リスク予防的指摘。

**[NEW] L-2: SEJ HTML 出力の Blob URL が 60 秒後に失効**
- 場所: `editor.html:8276-8278`
- プレビューウィンドウ開口後に他タブへ遷移して戻ると白画面になる。

**[継続] L-3: bridge.ts の focusEditor() が空 catch で SecurityError を握りつぶす**
- 場所: `client/src/lib/bridge.ts:7-11`

**[継続] L-4: App.tsx の reader.onerror が未定義**
- 場所: `client/src/App.tsx:108-114`

**[継続] L-5: App.tsx の handleKeyDown で `cmd` を二重チェック（冗長）**
- 場所: `client/src/App.tsx:62-70`

**[継続] L-6: FileTabBar.tsx で `key={i}` インデックスキー**
- 場所: `client/src/components/FileTabBar.tsx:19` — `key={tab.name}` に変更推奨。

**[継続] L-7: onOpenFile フォールバックがデッドコード**
- 場所: `client/src/components/RibbonToolbar.tsx:68` — App.tsx は常に `handleOpenFile` を渡すためフォールバック到達不能。

---

## コード品質所見

**[継続] Q-1: EditorMessage インターフェースが Discriminated Union でない**
- 場所: `client/src/App.tsx:22-36` — 型安全性が低い。各 type ごとに union branch を定義すべき。

**[継続] Q-2: SearchBar.tsx debounce の ref cleanup が上書き後の ref を参照するリスク**
- 場所: `client/src/components/SearchBar.tsx:27-33`
- `const id = debounceRef.current; return () => clearTimeout(id);` パターンが安全。

**[継続] Q-3: RibbonToolbar.tsx に 6 コンポーネント混在（207行）**
- 場所: `client/src/components/RibbonToolbar.tsx`

**[NEW] Q-6: stateSync ハンドラで `!!` 二重否定が冗長**
- 場所: `client/src/App.tsx:92-97` — Q-1 と連動して型を整備すれば不要になる。

---

## バグ・ロジックリスク

**[継続] B-1: Enter後の searchNext が 30ms 固定遅延に依存**
- 場所: `client/src/components/SearchBar.tsx:61`
- 低速環境・高負荷時に `moveSearch` が空の `searchHits` で空振りするリスク。

**[継続] B-2: 置換ボタンが search と replaceOne を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-104`
- `search` 完了前に `replaceOne` が実行されると置換対象がずれる。

**[継続] B-3: iframe が null の場合 send() が無音で失敗**
- 場所: `client/src/lib/bridge.ts:1-4` — undo/save 等の操作が黙って捨てられる。

**[継続] B-6: gotoRow のペイロードが文字列型のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41` — `parseInt(rowNum, 10)` に変換すべき。

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
               ...
-              console.log("[SEJ] 仮想列追加完了 index=" + vIdx);
```

- `console.log("[SEJ] 仮想列追加チェック:", {...})` 削除（editor.html:7880-7886）
- `console.log("[SEJ] 仮想列追加完了 index=" + vIdx)` 削除（editor.html:7897）

---

## 修正済みバグ確認（最新コミット）

| コミット | 内容 | 状態 |
|---------|------|------|
| 3a4e274 | sortByColumn の firstRow ヘッダーモードで先頭行が固定されるバグ | ✅ 修正済み |
| f86cc34 | Enter/Tab ナビゲーションが非表示行・列をスキップしないバグ | ✅ 修正済み |
| b63a916 | 重複削除後の _dupSet 残留 | ✅ 修正済み |
| 05cf170 | openContent 状態リセット漏れ | ✅ 修正済み |
| 911a008 | gotoRow 非表示行バグ | ✅ 修正済み |

---

## 推奨アクション（優先度順）

1. **[緊急] H-3/H-5: `javascript:` URI を `<a href>` に許可しない** — CSV データ経由クリッカブル XSS の直接的な修正
2. **[緊急] H-1: GitHub PAT を localStorage から除去** — XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンを断つ
3. **[高] H-2/M-1: postMessage の origin 検証を追加** — bridge.ts と App.tsx の両方
4. **[高] M-3: デバッグ機能 (dbm*) を開発環境限定に制限**
5. **[高] B-1/B-2: 検索→ナビゲーション・検索→置換の race condition を修正**
6. **[中] M-6: SEJ/価格参照の reader.onerror を追加**
7. **[中] M-7: 画像アップロード失敗時の処理を修正**
8. **[中] M-8: ソート後の cellColors 行インデックス再マッピングを確認・修正**
9. **[中] Q-1/Q-2: EditorMessage 型安全化・debounce cleanup 修正**
10. **[低] L-6: FileTabBar の key={i} を key={tab.name} に変更**
