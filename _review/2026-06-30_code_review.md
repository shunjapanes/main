# コードレビューレポート 2026-06-30 — shunjapanes/main

## サマリー

- 実行日時: 2026-06-30 (UTC)
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 7件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, RibbonButton.tsx, RibbonGroup.tsx)
- 発見件数: 🔴 Critical 1 / 🟠 High 6 / 🟡 Medium 10 / 🟢 Low 7
- うち新規 [NEW]: 0件 / 継続 [継続]: 24件
- 適用済み自動修正: 0件
- ⚠️ **前回レビュー(2026-06-16)から14日間コード変更なし。Critical/High指摘が2週間継続未対応。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] H-1: GitHub PAT を btoa() のみで localStorage に保存 — 2週間未対応**
- 場所: `client/public/editor.html` — `dbmGetPat()` / `dbmSavePat()`
- btoa はエンコードであり暗号化ではない。DevTools から即座に `atob(localStorage.getItem('tsv-editor-debug-memo-pat'))` で取得可能。PAT に repo スコープがあるため XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。
- **修正案:** PAT はセッション変数（メモリのみ）に保持し、localStorage への永続化を廃止する。

### 🟠 High

**[継続] H-2: postMessage targetOrigin が `'*'`（送受信とも）**
- 場所: `client/src/lib/bridge.ts:3`、`editor.html` 複数箇所
- 親→子・子→親の両方向で `'*'` を使用。クロスオリジン環境では悪意ある第三者がメッセージを傍受・注入可能。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に変更。受信側に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] H-3/H-5: `<a href>` の URL に `javascript:` スキームを検証しない — 2週間未対応**
- 場所: `editor.html`（セルリッチレンダリング、自動リンク化の両パス）
- セル値に `javascript:alert(1)` を書いてリンクをクリックすると XSS が実行される（格納型XSS相当）。
- **修正案:** `const safeUrl = /^https?:/i.test(url) ? url : '#';` に絞り、`rel="noopener noreferrer"` も追加。

**[継続] H-4: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`（エンコーディング引数なし = UTF-8固定）
- 日本語 Shift-JIS / EUC-JP の CSV/TSV を開くと文字化けし、データの誤操作・誤保存を招く。
- **修正案:** `readAsArrayBuffer` → `TextDecoder` + BOM 検出ライブラリで自動判定。

**[継続] B-2: 置換ボタンが search と replaceOne を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-104`
- `search` 完了前に `replaceOne` が実行されると置換対象がずれる。検索結果が空状態での置換が起きる。
- **修正案:** iframe側から `searchDone` 応答を受け取ってから `replaceOne` を送るイベント駆動方式に変更。

**[継続] M-3（High相当）: デバッグ機能 (dbm*) が本番 UI に露出**
- 場所: `client/src/components/RibbonToolbar.tsx`（ツールバー「デバッグ」グループ）
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
- XSS 成立時の第2防衛線がない。H-3/H-5 の javascript: XSS リスクを増幅させる。
- **修正案:** `default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;` を設定。

**[継続] M-5: Service Worker が Cache-first 戦略でセキュリティ更新が遅延**
- 場所: `client/public/sw.js`
- セキュリティパッチを含むコード更新がクライアントに即座に反映されない。
- **修正案:** stale-while-revalidate 戦略に変更、またはビルドハッシュをキャッシュ名に含める。

**[継続] M-6: SEJ/価格参照の reader.onerror なし**
- 場所: `editor.html`（loadSejMasterFile, loadPriceRefFile）
- 読込失敗時にユーザー通知なしでサイレント失敗。
- **修正案:** `reader.onerror = () => showStatus('ファイル読み込みに失敗しました');` を追加。

**[継続] M-7: dbmUpload 画像アップロードエラー時にリンク切れ Markdown がコミットされる**
- 場所: `editor.html`（dbmUpload 処理）
- 画像アップロード失敗後も本文アップロードが続行され、壊れた画像参照を含む Markdown が GitHub に push される。
- **修正案:** 画像アップロードに失敗した場合は全体処理を中断してユーザーに通知。

**[継続] M-8: sortByColumn 後に cellColors の行インデックスが古いまま**
- 場所: `editor.html:3562-3568`
- `state.cellColors`（手動セル着色）の行インデックス再マッピングが実装されていない可能性がある。
- **修正案:** ソート後に `cellColors` を新しい行インデックスにリマップする処理を追加。

**[継続] Q-1: EditorMessage インターフェースが Discriminated Union でない**
- 場所: `client/src/App.tsx:22-36`
- 全プロパティがフラットかつオプショナルな単一インターフェース。型安全性が低い。
- **修正案:** `type` ごとに個別の interface を定義し `|` で結合する判別共用体に変更。

**[継続] Q-2: SearchBar.tsx debounce の ref cleanup が上書き後の ref を参照するリスク**
- 場所: `client/src/components/SearchBar.tsx:27-33`
- cleanup 関数実行時点で `debounceRef.current` が次の setTimeout ID に上書きされている可能性。
- **修正案:** `const id = setTimeout(...); return () => clearTimeout(id)` パターンに変更。

**[継続] Q-3: RibbonToolbar.tsx に 7 コンポーネント混在（207行）**
- 場所: `client/src/components/RibbonToolbar.tsx`
- 各タブコンポーネントを独立ファイルに分割し、可読性・テスト容易性を向上させることを推奨。

### 🟢 Low

**[継続] L-1: コンテキストメニューの `g.icon` / `g.group` が escHtml なし**
- 場所: `editor.html`（contextmenu レンダリング） — 現在はコード内定数なので実害なし。外部入力化時に XSS リスク。

**[継続] L-2: SEJ HTML 出力の Blob URL が 60 秒後に失効**
- 場所: `editor.html` — プレビューウィンドウ開口後に他タブへ遷移して戻ると白画面になる。ダウンロード完了後に revoke するパターンに変更推奨。

**[継続] L-3: bridge.ts の focusEditor() が空 catch で SecurityError を握りつぶす**
- 場所: `client/src/lib/bridge.ts:7-11` — `catch (e) { console.warn('focusEditor failed:', e) }` 最低限のログを残す。

**[継続] L-4: App.tsx の reader.onerror が未定義**
- 場所: `client/src/App.tsx:108-114` — ファイル読み込み失敗時にユーザー通知なし。

**[継続] L-5: App.tsx の handleKeyDown で `cmd` を二重チェック（冗長）**
- 場所: `client/src/App.tsx:62-70` — 関数冒頭の `if (!cmd) return` により以降の `cmd &&` チェックは不要。

**[継続] L-6: FileTabBar.tsx で `key={i}` インデックスキー**
- 場所: `client/src/components/FileTabBar.tsx:19` — タブ並び替え時に DOM 状態がずれる可能性。`key={tab.name}` に変更推奨。

**[継続] L-7: onOpenFile フォールバックがデッドコード**
- 場所: `client/src/components/RibbonToolbar.tsx:68` — App.tsx は常に `handleOpenFile` を渡すため `send('open')` 到達不能。

---

## コード品質所見

（M-1〜Q-3 セクション内に統合、上記参照）

---

## バグ・ロジックリスク

**[継続] B-1: Enter後の searchNext が 30ms 固定遅延に依存**
- 場所: `client/src/components/SearchBar.tsx:61`
- 低速環境・大ファイルで `moveSearch` が空の `searchHits` で空振りするリスク。
- **修正案:** iframe 側から `searchDone` 応答後に `searchNext` を送るイベント駆動方式に変更。

**[継続] B-3: iframe が null の場合 send() が無音で失敗**
- 場所: `client/src/lib/bridge.ts:1-4` — undo/save 等の操作が黙って捨てられる。開発時は `console.error` を出力すべき。

**[継続] B-6: gotoRow のペイロードが文字列型のまま送信**
- 場所: `client/src/components/SearchBar.tsx:41` — `parseInt(rowNum, 10)` に変換すべき。`NaN` の場合は送信しないガードも追加。

---

## 適用済み自動修正

なし（前回レビュー 2026-06-16 以降コード変更なし。対象 `console.log` は既に削除済み）

---

## 修正済みバグ確認（最近コミット）

| コミット | 内容 | 状態 |
|---------|------|------|
| 7c616a0 | chore: automated code review 2026-06-16 [auto-merged] | ✅ レビューのみ |
| 8718fdf | chore: automated code review 2026-06-15 [auto-merged] | ✅ レビューのみ |
| 921d31a | Merge PR #2 check-github | ✅ マージ済み |
| 3a4e274 | fix: sortByColumn firstRow ヘッダーモードバグ | ✅ 修正済み |

⚠️ **最後の機能コミットは 2026-05-21。以降 40 日間コード変更なし。**

---

## 推奨アクション（優先度順）

1. **[緊急・2週間未対応] H-3/H-5: `javascript:` URI を `<a href>` に許可しない** — CSV データ経由クリッカブル XSS の直接的な修正
2. **[緊急・2週間未対応] H-1: GitHub PAT を localStorage から除去** — XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンを断つ
3. **[高・2週間未対応] H-2/M-1: postMessage の origin 検証を追加** — bridge.ts と App.tsx の両方
4. **[高・2週間未対応] M-3: デバッグ機能 (dbm*) を開発環境限定に制限**
5. **[高] B-2: 検索→置換の race condition を修正**
6. **[中] B-1: searchNext の固定遅延を除去しイベント駆動に変更**
7. **[中] M-2: iframe に sandbox 属性を追加**
8. **[中] M-4: CSP ヘッダーを追加**
9. **[中] M-6/M-7: エラーハンドリング漏れを修正**
10. **[中] Q-1/Q-2: 型安全化・debounce cleanup 修正**
11. **[低] L-6: FileTabBar の key={i} を key={tab.name} に変更**
