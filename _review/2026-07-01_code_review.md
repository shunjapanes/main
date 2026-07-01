# コードレビューレポート 2026-07-01 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-01 16:08 UTC
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (editor.html, App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, RibbonButton/Group.tsx)
- 発見件数: 🔴 Critical 1 / 🟠 High 5 / 🟡 Medium 8 / 🟢 Low 2
- うち新規 [NEW]: 2件 / 継続 [継続]: 14件
- 適用済み自動修正: 2件 (console.log 削除 — editor.html 自動適用済み・別コミット予定)
- ⚠️ **前回レビュー(2026-06-30)からコード変更なし。Critical/High指摘が1ヶ月以上継続未対応。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] H-1: GitHub PAT を btoa() のみで localStorage に保存 — 1ヶ月超未対応**
- 場所: `client/public/editor.html:9065-9069` — `dbmGetPat()` / `dbmSavePat()`
- btoa はエンコードであり暗号化ではない。XSS やストレージ漏洩で PAT が平文取得される。
- **修正案:** Web Crypto API (AES-GCM) で暗号化、またはセッション限りのメモリ保持に変更し localStorage への永続化を廃止する。

---

### 🟠 High

**[継続] H-2: postMessage targetOrigin が `'*'`（送受信とも）**
- 場所: `client/src/lib/bridge.ts:3`、`editor.html` L9513/9547/9597 等
- 任意オリジンの悪意あるページがメッセージを受信・注入可能。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に変更。受信側に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] H-3/H-5: `<a href>` の URL に `javascript:` スキームを検証しない**
- 場所: `editor.html` L7787-7790（リッチレンダリングの `<a href>` 復元処理）
- `escHtml()` はスキームをサニタイズしない。`javascript:alert(1)` を含むセル値からのXSS成立。
- **修正案:** `const safeUrl = /^https?:/i.test(url) ? url : '#';` でホワイトリスト検証、`rel="noopener noreferrer"` も追加。

**[継続] H-4: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`（エンコーディング引数なし = UTF-8固定）
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** `readAsArrayBuffer` → `TextDecoder` + BOM 検出で自動判定、またはUIでエンコーディング選択を提供。

**[継続] M-3（High相当）: デバッグ機能 (dbm*) が本番 UI に露出**
- 場所: `editor.html`（デバッグタブ、GitHub PAT 入力 UI が一般ユーザーに表示）
- **修正案:** `import.meta.env.DEV` ガードまたは別ビルドターゲットへ分離。

**[継続] B-2: 置換ボタンが search と replaceOne を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-104`
- `send('search', query)` 完了前に `send('replaceOne', replaceText)` が実行されると置換対象がずれる。Enter押下は 30ms delay で対策済みだが置換ボタンには未適用。
- **修正案:** iframe 側から `searchDone` 応答を受け取ってから `replaceOne` を送るイベント駆動方式に変更。

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
- 読込失敗時にユーザー通知なし。
- **修正案:** `reader.onerror = () => send('status', 'ファイル読み込みに失敗しました');` を追加。

**[継続] M-7: dbmUpload 画像アップロードエラー時にリンク切れ Markdown がコミットされる**
- 場所: `editor.html`（dbmUpload 処理）
- **修正案:** 画像アップロード成功を確認してから本文アップロードを実行するよう順序制御。

**[NEW] Low: SearchBar.tsx useEffect 空deps のコメント依存**
- 場所: `client/src/components/SearchBar.tsx:20-25`
- `query` を deps から意図的に除外しているが eslint-disable コメントの理由が不明瞭。将来の変更で無言バグ化リスク。
- **修正案:** コメントに意図を明記するか `deps` を見直す。

---

## コード品質所見

**[継続] 置換ボタンの race condition（再掲 B-2）**
- `SearchBar.tsx:103-104` — 上記セキュリティ/バグ欄と同一。

**[NEW] Low: SearchBar.tsx eslint-disable の意図不明**
- `client/src/components/SearchBar.tsx:25` — `// eslint-disable-next-line react-hooks/exhaustive-deps`
- コメントに意図を追記することを推奨。

---

## バグ・ロジックリスク

**[継続 → 修正済] B-1: SearchBar Enterキーでデバウンス競合**
- `clearTimeout(debounceRef.current)` + 即時 `send('search', query)` + 30ms delay による修正が確認できた。**解消済み。**

**[継続] B-2: 置換ボタン連続 postMessage 競合（再掲 High欄）**

**[継続] M-6: reader.onerror 未実装（再掲 Medium欄）**

---

## 適用済み自動修正

```diff
--- a/client/public/editor.html
+++ b/client/public/editor.html
@@ -7880,8 +7880,0 @@
-            console.log("[SEJ] 仮想列追加チェック:", {
-              curCodeIdx,
-              masterHeaders: normHeaders,
-              grpKey,
-              hasExistingVirtual: !!state.sejVirtualCols,
-              dataRows: state.data.length,
-            });
-              console.log("[SEJ] 仮想列追加完了 index=" + vIdx);
```

- console.log "[SEJ] 仮想列追加チェック" 削除（editor.html 旧7880行）
- console.log "[SEJ] 仮想列追加完了" 削除（editor.html 旧7897行）

---

## 推奨アクション（優先度順）

1. **[Critical] H-1** — PAT を localStorage から排除、セッションメモリ保持に変更
2. **[High] H-3/H-5** — リッチレンダリングの `<a href>` に `https?:` スキーム検証を追加（1行の修正）
3. **[High] H-2 + M-1** — postMessage の origin 検証追加（bridge.ts + App.tsx + editor.html、3箇所）
4. **[High] B-2** — 置換ボタンのイベント駆動化（SearchBar.tsx）
5. **[High] M-3** — `import.meta.env.DEV` ガードでデバッグUIを本番から除外
6. **[Medium] M-4** — CSP meta タグを index.html に追加（1行の修正）
7. **[Medium] M-5** — sw.js をネットワークファーストまたは stale-while-revalidate に変更
8. **[Medium] M-2** — iframe に sandbox 属性を追加（App.tsx 1行の修正）

> ⚠️ H-1〜H-3 は XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンを構成しており、最優先での対応を推奨します。
