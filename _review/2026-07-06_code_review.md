# コードレビューレポート 2026-07-06 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-06 16:08 UTC
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (editor.html, App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, RibbonButton/Group.tsx)
- 発見件数: 🔴 Critical 1 / 🟠 High 7 / 🟡 Medium 6 / 🟢 Low 2
- うち新規 [NEW]: 3件 / 継続 [継続]: 13件
- 適用済み自動修正: **0件**（自動修正対象なし）
- ⚠️ **Critical/High指摘が最長2ヶ月超継続未対応。今回、新規バグ（Ctrl+Shift+Z redo不動作）を検出。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存 — 2ヶ月超未対応**
- 場所: `client/public/editor.html:9057-9061` — `dbmGetPat()` / `dbmSavePat()`
- `btoa` はエンコードであり暗号化ではない。`atob(localStorage.getItem(key))` で即座に PAT を取得可能。XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。
- **修正案:** Web Crypto API (AES-GCM) で暗号化、またはセッション限りのメモリ保持に変更し localStorage への永続化を廃止。

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（親→子・子→親）**
- 場所: `client/src/lib/bridge.ts:3` / `editor.html:9505,9539,9589,9599,9609,9615,9626,9630,9653`
- 送受信とも任意オリジン。クロスオリジン環境では悪意あるページがメッセージを傍受・注入可能。`openContent`（ファイル内容）送信時は機密データも対象になる。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に固定。受信側で `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `editor.html:7787-7793`（リッチレンダリング `<a href>` 復元）
- `escHtml()` は HTML エンティティをエスケープするが `javascript:` スキームを許可する。セル値に `javascript:alert(1)` を書き込みリンクをクリックすると XSS が実行される。
- **修正案:** `/^https?:/i.test(url)` でホワイトリスト検証。`rel="noopener noreferrer"` を追加。

**[継続] S-4: アンカーテキストが 2重エスケープ後に未検証で DOM に注入**
- 場所: `editor.html:7793` — `${text}</a>` の `text` 変数
- `text` は `escHtml(v)` 通過後のキャプチャだが、複雑な変換チェーン内での追加注入リスクが残る。
- **修正案:** `${escHtml(text)}</a>` と明示的に再エスケープし、意図を明確化する。

**[継続] S-5: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)` （エンコーディング引数なし = UTF-8固定）
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM 検出で自動判定、またはUIでエンコーディング選択を提供。

**[継続] S-6: デバッグ機能 (debugMemo) が本番 UI に露出 — PAT入力UI含む**
- 場所: `client/src/components/RibbonToolbar.tsx`（「デバッグ」グループ）
- GitHub PAT 入力 UI を含むデバッグ機能が全ユーザーに公開。S-1 と組み合わさり PAT 漏洩の入口になる。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] S-7: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx:72-93`
- 悪意あるオリジンからのメッセージで `setStatus`・`setTabs` 等の UI 状態が操作される可能性。
- **修正案:** ハンドラ冒頭に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-8: 置換ボタンが search と replaceOne を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- `search` 完了前に `replaceOne` / `replaceAll` が実行され置換対象がずれる。debounce タイマーも未キャンセル。
- **修正案:** `replaceOne/All` に query を同梱した単一メッセージとして送信し、エディタ側でアトミックに処理。

---

## コード品質所見

**[継続] Q-1: console.warn / console.error 6件が本番コードに残存**
- 場所: `editor.html:7891, 7893, 9031, 9048, 9524, 9557`
- 重要度: **Medium**
- ユーザー環境のコンソールに内部状態（列名・オブジェクト構造）が漏洩する。
- **修正案:** Viteの `build.drop: ['console']` オプション適用、またはエラーログは適切なエラーハンドラ（Sentry等）に置換。

**[継続] Q-2: focusEditor() が空の catch で失敗を握りつぶす**
- 場所: `client/src/lib/bridge.ts:7-12`
- 重要度: **Medium**
- 呼び出し元が成否を知る手段がない。
- **修正案:** `if (import.meta.env.DEV) console.warn('[bridge] focusEditor failed:', e)` を追加。

**[NEW] Q-3: message ハンドラの型判別に `else if` が使われていない**
- 場所: `client/src/App.tsx:72-93`
- 重要度: **Low**
- `msg.type` は判別共用体だが全条件を独立した `if` で評価。マッチ後も全条件を評価し続ける不要な処理が発生する。
- **修正案:** `else if` チェーンまたは `switch` 文に変更する。

---

## バグ・ロジックリスク

**[NEW] B-1: `e.key === 'z' && e.shiftKey` がデッドコード → Ctrl+Shift+Z redo が動作しない**
- 場所: `client/src/App.tsx:65`
- 重要度: **Medium**（ユーザー向け機能の不動作）
- ブラウザは Shift を押しながら Z を押すと `e.key` を `'Z'`（大文字）として報告する。そのため `e.key === 'z' && e.shiftKey` は常に false。結果として Ctrl+Shift+Z による redo が機能しない。
```typescript
// 現状（バグ）
} else if (cmd && ((e.key === 'z' && e.shiftKey) || e.key === 'y' || e.key === 'Y')) {
// 修正後
} else if (cmd && ((e.key === 'Z' && e.shiftKey) || e.key === 'y' || e.key === 'Y')) {
```

**[継続] B-2: `handleKeyDown` 内で `cmd &&` の冗長な二重チェック**
- 場所: `client/src/App.tsx:61-67`
- 重要度: **Low**
- `if (!cmd) return` による早期リターン後も `if (cmd && ...)` と再評価。読み手を混乱させる。
- **修正案:** `cmd &&` 部分を除去してシンプルにする。

**[継続] B-3: FileReader の `onerror` ハンドラが未定義**
- 場所: `client/src/App.tsx:109-115`
- 重要度: **Medium**
- ファイル読み込み失敗時（権限エラー・破損ファイル等）に UI 側で何も通知されない。
- **修正案:** `reader.onerror = () => { setStatus('ファイルの読み込みに失敗しました'); }` を追加。

---

## 適用済み自動修正

**なし。** 前回レビューまでに console.log は削除済み。残存する console.warn/error は意図的なエラーハンドラと判断し、ロジック変更を避けるため自動修正対象外とした。

---

## 推奨アクション（優先度順）

1. **🔴 即対応** — **S-1**: PAT の btoa 保存を廃止し、Web Crypto (AES-GCM) またはセッション変数に移行
2. **🟠 早期対応** — **S-2**: `postMessage` の targetOrigin を `'*'` → `window.location.origin` に変更（bridge.ts + editor.html 両方）
3. **🟠 早期対応** — **S-3**: `javascript:` スキームの URL をホワイトリスト検証（1行修正）
4. **🟠 早期対応** — **S-6**: デバッグUIを `import.meta.env.DEV` ガードで本番ビルドから除外
5. **🟡 今週中** — **B-1**: `e.key === 'z'` → `e.key === 'Z'` に修正（Ctrl+Shift+Z redo 不動作バグ）
6. **🟡 今週中** — **B-3**: `reader.onerror` ハンドラを追加
7. **🟢 余裕時** — S-5: Shift-JIS/EUC-JP エンコーディング自動判定の実装

> 詳細は `_review/2026-07-06_code_review.md` を参照
