# コードレビューレポート 2026-07-11 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-11 UTC（自動レビュー）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, sw.js, package.json)
- 発見件数: 🔴 Critical 1 / 🟠 High 7 / 🟡 Medium 12 / 🟢 Low 12
- うち新規 [NEW]: 9件 / 継続 [継続]: 23件
- 解消 [FIXED]: 3件 (B-5, Q-1, Q-4)
- 適用済み自動修正: **0件**（対象コードなし）
- ⚠️ **S-1 Critical は2026-07-02以降 26日間未対応。B-1（Ctrl+Shift+Z redo不動作）も継続中。今週の新規発見: sw.js のキャッシュ更新欠如(S-13)、sw.js undefined レスポンス(S-14/B-N-1)、ファイルサイズ上限なし(S-15)、FileTabBar アクセシビリティ問題(N-2, N-3)、RibbonButton デッドコード(N-4) ほか。B-5(sw.js エラーキャッシュ)・Q-1(console.warn)・Q-4(aria-label)は前回から解消確認。**

---

## セキュリティ所見

### 🔴 Critical

**[継続] S-1: GitHub PAT を btoa() のみで localStorage に保存**
- 場所: `client/public/editor.html:9061` — `dbmSavePat()`
- `btoa` はBase64エンコードであり暗号化ではない。DevToolsから即座に読み取り可能。XSS → PAT漏洩 → リポジトリ書き込みの攻撃チェーンが成立。**2026-07-02から26日間未対応。**
- **修正案:** Web Crypto API (AES-GCM) で暗号化後保存、またはsessionStorage+メモリのみ保持してlocalStorage永続化を廃止。

---

### 🟠 High

**[継続] S-2: postMessage targetOrigin が `'*'`（bridge.ts 親→子、editor.html 子→親 双方向）**
- 場所: `client/src/lib/bridge.ts:2` および `editor.html:9505,9539,9589` 等
- 双方向で `'*'` 使用。PAT・ファイル内容・ユーザーデータが任意オリジンに傍受される。
- **修正案:** `postMessage(msg, location.origin)` で明示的オリジンを指定。受信側も `e.origin` で検証。

**[継続] S-3: `<a href>` の URL に `javascript:` スキームを検証しない（XSS）**
- 場所: `editor.html:7790`
- セルのMarkdownリンクを展開する際、`javascript:alert(1)` 等が `escHtml()` を通過してinnerHTMLへ挿入される。
- **修正案:** `url.startsWith('https://') || url.startsWith('http://')` でホワイトリスト検証。`rel="noopener noreferrer"` 追加。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx:87`
- Shift-JIS/EUC-JPファイルで文字化け・データ破損リスク。バリデーション迂回の可能性。
- **修正案:** `readAsArrayBuffer` + `TextDecoder` + BOM検出で自動判定。

**[継続] S-5: デバッグ機能 (debugMemo) が本番UIに露出 — PAT入力UIを含む**
- 場所: `client/public/editor.html:1781-1786`、`client/src/components/RibbonToolbar.tsx:197`
- `import.meta.env.DEV` ガードなしに常時表示。GitHub PAT入力フォームが一般ユーザーに見える。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}` でガード。

**[継続] S-6: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `editor.html:7793-7794` — `<span style="color:${escHtml(...)}">`
- `escHtml` はセミコロン・コロン・スラッシュを変換しないためCSSインジェクションが可能。
- **修正案:** `/^(#[0-9a-fA-F]{3,8}|[a-zA-Z]+|rgb\(\d+,\s*\d+,\s*\d+\))$/.test(color)` で検証。

**[継続] S-7: iframe に sandbox 属性なし → XSS 時に親フレームをリダイレクト可能**
- 場所: `client/src/App.tsx:128-133`
- sandbox未指定のためiframe内から `window.parent.location` による強制リダイレクトが可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-clipboard-read allow-clipboard-write allow-popups"` を追加（`allow-top-navigation` は除外）。

**[継続] B-1: Ctrl+Shift+Z (redo) が macOS で動作しない**
- 場所: `client/src/App.tsx:62` — `handleKeyDown`
- redo条件が `e.key === 'z' && e.shiftKey` だが、macOSでShiftを押すと `e.key` は `'Z'`（大文字）になるため条件が永遠に false。undo側は `'z' || 'Z'` 両対応済みなのに redo 側が抜けている。
- **修正案:** `(e.key === 'z' || e.key === 'Z') && e.shiftKey` に変更。

---

### 🟡 Medium

**[継続] S-8: App.tsx の postMessage 受信側で `e.origin` を未検証**
- 場所: `client/src/App.tsx:76`
- 任意オリジンからのpostMessageでUI状態（ステータス・タブ・トグル）が操作可能。
- **修正案:** `if (e.origin !== location.origin) return;` をハンドラ先頭に追加。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:104,107`
- `send('search', query); send('replaceOne', replaceText)` を同期送信。検索インデックス確定前に置換が実行されセルがずれる。
- **修正案:** `searchCount` 応答受信後にreplaceを発行するコールバック方式に変更。

**[継続] S-10: Content-Security-Policy (CSP) の欠如**
- 場所: `editor.html` / `index.html` — CSPヘッダー・メタタグなし
- S-3・S-6成功時の外部スクリプト・データ送信が無制限。
- **修正案:** `default-src 'self'; script-src 'self'; connect-src 'self' https://api.github.com;` を設定。

**[継続] S-11: allow="popups" による iframe へのポップアップ権限付与（sandbox なしと組み合わせ）**
- 場所: `client/src/App.tsx:132`
- S-7と組み合わせてフィッシングウィンドウの開封が可能。S-7のsandbox適用で同時解決可能。

**[継続] S-12: editor.html の postMessage ハンドラが `e.source` のみ検証し `e.origin` を未確認**
- 場所: `editor.html:9339-9341`
- 親フレームがクロスオリジンへナビゲートされた後も別オリジンのメッセージが `openContent`・`replaceAll` 等の破壊的アクションを実行できる。
- **修正案:** `if (e.source !== window.parent || e.origin !== location.origin) return;`

**[NEW] S-13: Service Worker がキャッシュファーストのため、セキュリティパッチを既存ユーザーに配信不可**
- 場所: `client/public/sw.js:10-14`
- `cached || fetch(...)` のcache-first戦略により、サーバー側にパッチを適用しても既存ユーザーには永久に届かない。`activate` ハンドラーに旧キャッシュ削除処理がなく、`tsv-editor-v1` バージョン固定では意図的キャッシュバスティングが不可能。
- **修正案:** stale-while-revalidate戦略に変更。`activate` 時に旧バージョンキャッシュを削除。

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:53`
- `send('search', query)` の直後に `setTimeout(() => send('searchNext'), 30)` を呼ぶが、低速端末や大ファイルでは30ms以内に検索インデックスが確定しない。
- **修正案:** iframe から `searchCount` メッセージ受信後にnext/prevを送るコールバック方式に変更。

**[継続] B-6: SearchBar — externalQuery 同期 useEffect の古い state 参照**
- 場所: `client/src/components/SearchBar.tsx:35`
- `externalQuery !== query` の比較で `query` が依存配列に含まれないため古い値との比較になる（eslint-disable で意図的に抑制）。不要な `setQuery` 実行または必要な更新スキップのリスク。
- **修正案:** `setQuery(prev => externalQuery !== prev ? externalQuery : prev)` の関数形式で更新。

**[継続] B-7: doGotoRow が行番号を文字列のまま送信**
- 場所: `client/src/components/SearchBar.tsx:42` — `doGotoRow()`
- `rowNum` は文字列型のまま `send('gotoRow', rowNum)` で送信。受信側が数値を期待している場合に行ジャンプが失敗。
- **修正案:** `send('gotoRow', parseInt(rowNum, 10))`

**[継続] Q-2: focusEditor() が空の catch でエラーを握り潰す**
- 場所: `client/src/lib/bridge.ts:9`
- `catch {}` が空のためiframeフォーカス失敗が検出不可能。開発中も診断情報が残らない。
- **修正案:** `catch { /* cross-origin restriction */ }` のようにコメントで意図を明示。またはDEVビルドで `console.warn` を残す。

**[継続] Q-5: SearchBar の useEffect に eslint-disable コメント（二重状態管理）**
- 場所: `client/src/components/SearchBar.tsx:39`
- `query` を依存配列から除外しているが、内部/外部の二重状態管理そのものが設計上の複雑性。
- **修正案:** `externalQuery` を唯一の真実源として内部 `query` 状態を廃止し `onSearchQueryChange` に委ねる。

**[継続] Q-6: FileTabBar がタブのキーに配列インデックスを使用**
- 場所: `client/src/components/FileTabBar.tsx:27`
- `key={i}` はタブ並べ替えや中間削除時にReactの差分計算を誤らせ、意図しないフォーカス喪失を引き起こす。
- **修正案:** `Tab` インターフェースに `id: string` フィールドを追加して `key={tab.id}` とする。

**[NEW] Q-N-2: FileTabBar のタブ本体が `<div>` で実装されキーボード操作不可**
- 場所: `client/src/components/FileTabBar.tsx:27-44`
- Tabキーでフォーカスできずスクリーンリーダーにも「ボタン」として認識されない。
- **修正案:** `<div>` を `<button type="button">` に変更するか `role="tab" tabIndex={0} onKeyDown={...}` を追加。

---

### 🟢 Low

**[NEW] S-14: sw.js のフェッチ失敗時に undefined を返しエラーをマスク**
- 場所: `client/public/sw.js:14`
- キャッシュミス時 `cached` は `undefined`。ネットワーク失敗時 `.catch(() => cached)` が `Promise<undefined>` を返しブラウザがTypeErrorをスロー。オフライン時に何も表示されない。
- **修正案:** `.catch(() => cached ?? new Response('Offline', { status: 503 }))` でフォールバックResponseを返す。

**[NEW] S-15: FileReader でファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx:83`
- `accept` 属性はドラッグ&ドロップ等でバイパス可能。数百MB〜GBファイルでブラウザタブがクラッシュ。
- **修正案:** `if (file.size > 50 * 1024 * 1024) { alert('ファイルが大きすぎます'); return; }`

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx:86`
- `ev.target?.result as string` はTypeScriptキャストであり実行時チェックではない。将来 `readAsArrayBuffer` 変更時にbinaryデータがそのまま送信される。
- **修正案:** `typeof content === 'string'` のガードを追加。

**[継続] B-4: FileTabBar — 親 div の onClick がアクセシビリティ上不正**
- 場所: `client/src/components/FileTabBar.tsx:27` (Q-N-2 と重複、アクセシビリティ観点)
- `role="button"`, `tabIndex`, `onKeyDown` がなくキーボード・スクリーンリーダー非対応。

**[継続] Q-3: message ハンドラの型判別に `else if` が使われていない**
- 場所: `client/src/App.tsx:68-82`
- `msg.type` はユニオン型で排他的なのに 8 本の独立 `if` 文で毎回全件評価。
- **修正案:** `switch (msg.type) { ... }` に変更。

**[継続] Q-7: RibbonToolbar の activeTab 比較に文字列リテラルを直接使用**
- 場所: `client/src/components/RibbonToolbar.tsx:49-53`
- `TABS` 定数で型安全な定義があるのにレンダリング分岐で `'ファイル'` 等をそのまま比較。
- **修正案:** `TABS[0]`, `TABS[1]` を参照するか定数へ分解して使う。

**[NEW] Q-N-1: handleKeyDown 内で早期 return 後も `cmd &&` を再チェック**
- 場所: `client/src/App.tsx:57,60-62`
- `if (!cmd) return` で弾いた後、後続の `if (cmd && ...)` で再度 `cmd` を評価。常に `true` なので冗長。
- **修正案:** `cmd &&` を除去して条件を簡潔にする。

**[NEW] Q-N-3: FileTabBar の閉じるボタンと追加ボタンに aria-label がない**
- 場所: `client/src/components/FileTabBar.tsx:36-49`
- アイコンのみのボタンに `title` はあるが `aria-label` がない。`title` はスクリーンリーダーへのアクセシビリティ情報として不十分。
- **修正案:** `aria-label="タブを閉じる"` および `aria-label="シートを追加"` を追加。

**[NEW] Q-N-4: RibbonButton の `size='large'` オプションがデッドコード**
- 場所: `client/src/components/RibbonButton.tsx:16-18,33`
- `size?: 'normal' | 'large'` を定義し `large` 用CSS分岐があるが、コードベース全体で `size="large"` を渡している箇所がゼロ。
- **修正案:** `size` propと `'large'` 分岐を削除してインターフェースを単純化。

**[NEW] Q-N-5: SearchBar の Enter キー後に setTimeout の魔法の数値 30ms**
- 場所: `client/src/components/SearchBar.tsx:53`
- `setTimeout(() => send(...), 30)` の 30ms の根拠が不明。デバウンス(180ms)との関係も不透明。
- **修正案:** `const SEARCH_DISPATCH_DELAY_MS = 30` のような定数に切り出し、意図をコメントで明記。

**[NEW] Q-N-6: FileTabBar と StatusBar でインラインスタイルに魔法の数値**
- 場所: `client/src/components/FileTabBar.tsx:26` (`height: 28`)、`client/src/components/StatusBar.tsx:11` (`height: 22`)
- ピクセル値が散在し両コンポーネント間の高さ関係が不明。
- **修正案:** Tailwind の `h-7` (28px)、`h-[22px]` のユーティリティクラスに統一するかCSSカスタムプロパティで管理。

---

## 解消済み（前回から）

| ID | 内容 |
|---|---|
| B-5 | sw.js: エラーレスポンスのキャッシュ — `resp.ok` チェック追加で解消 |
| Q-1 | console.warn/error の本番残存 — src配下から全て除去確認 |
| Q-4 | RibbonButton に aria-label なし — `aria-label={label}` 追加確認 |

---

## 適用済み自動修正

```diff
(なし — 対象コードなし)
```

src配下の全ファイルおよびsw.jsに console.log / console.error / debugger 文なし（Grep確認済み）。

---

## 推奨アクション（優先度順）

1. **[即対応] S-1 (Critical):** editor.html の btoa() localStorage PAT保存を廃止。26日間未対応。sessionStorage + セッション変数のみに変更。
2. **[今週] B-1 (High):** `App.tsx:62` のredo条件 `e.key === 'z' && e.shiftKey` を `(e.key === 'z' || e.key === 'Z') && e.shiftKey` に修正。1行の変更。
3. **[今週] S-7 (High):** iframeに `sandbox="allow-scripts allow-same-origin allow-downloads allow-clipboard-read allow-clipboard-write allow-popups"` を追加。S-11も同時解決。
4. **[今週] S-8 (Medium):** `App.tsx` のメッセージハンドラ先頭に `if (e.origin !== location.origin) return;` を追加。1行の変更。
5. **[今週] S-12 (Medium):** editor.html:9339 に `e.origin !== location.origin` チェックを追加。
6. **[今週] S-13 (Medium NEW):** sw.js を stale-while-revalidate 戦略に変更。`activate` 時に旧キャッシュを削除。
7. **[来週] S-14 (Low NEW):** sw.js の `.catch()` で `new Response('Offline', { status: 503 })` フォールバックを追加。
8. **[来週] S-15 (Low NEW):** `App.tsx` の `handleFileSelected` にファイルサイズ上限チェック (50MB) を追加。
9. **[来週] B-7 (Medium):** `doGotoRow` で `parseInt(rowNum, 10)` に変更。
10. **[検討] Q-6 (Medium):** タブIDをeditor.htmlからのmessageに含めてFileTabBarの `key` を安定させる。
