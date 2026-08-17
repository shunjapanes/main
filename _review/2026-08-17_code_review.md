# コードレビューレポート 2026-08-17 — shunjapanes/main

## サマリー

- 実行日時: 2026-08-17 00:00 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, editor.html, sw.js, vite.config.ts)
- 発見件数: 🔴 Critical 2 / 🟠 High 7 / 🟡 Medium 21 / 🟢 Low 10 = 計40件
- うち新規 [NEW]: **0件** / 継続 [継続]: **40件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（src配下・editor.html に console.log / console.error / debugger 文なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| ℹ️ 変更なし | 2026-07-22 の修正以降、ソースコードへの新規コミットなし。_review/*.md のみ更新。 |
| ⚠️ 継続中 | 前回 (2026-08-16) 指摘の全40件が未修正のまま継続中 |
| ⚠️ 最重要継続 | **[継続] NEW-PAT: GitHub PAT を sessionStorage に平文保存** — S-XSS と連鎖し PAT 窃取→リポジトリへの任意アクセスが可能。引き続き最優先で対応を推奨。 |

---

## セキュリティ所見（Agent A）

### 🔴 Critical

**[継続] S-PM: postMessage の origin 検証なし（送受信両方）**
- 場所: `client/src/lib/bridge.ts:3`（送信側）、`client/src/App.tsx:77`（受信側）
- `postMessage({ action, payload }, '*')` — 任意オリジンに送信。受信側も `e.origin` チェックなし。クロスオリジンフレームが任意のアクション（undo/replace等）を注入またはデータを傍受可能。
- **修正案:** `postMessage(data, window.location.origin)` に変更。受信側に `if (e.origin !== window.location.origin) return;` を追加。

**[継続] S-XSS: `javascript:` プロトコルが HTML プレビューの href を通過（XSS）**
- 場所: `client/public/editor.html:7787-7790`
- `escHtml()` は HTML 実体変換を行うが `javascript:` スキームは通過し、`innerHTML` に注入される。クリック時にアプリ同一オリジン上でスクリプトが実行され DOM/localStorage に完全アクセス可能。
- **修正案:** `if (!/^https?:\/\//i.test(url)) return escHtml(text)` を追加、`rel="noopener noreferrer"` 付与。

---

### 🟠 High

**[継続] NEW-PAT: GitHub PAT を sessionStorage に平文保存**
- 場所: `client/public/editor.html:9061`
- `sessionStorage.setItem("tsv-editor-debug-memo-pat", pat)` で GitHub PAT（repo スコープ = 全リポジトリ読み書き権限）を平文保存。editor.html は S-XSS・S-CSS 等の未修正 XSS ベクターを持ち、同一オリジン上の XSS が成立した場合 PAT が即座に窃取される。S-5（デバッグUI本番露出）と組み合わさることで攻撃面が増大。
- **修正案:** (1) S-5 修正でデバッグ機能を DEV 限定にすることが最優先。(2) PAT を sessionStorage に保存せず使用都度入力させる、または OAuth Device Flow に切り替え。(3) PAT を Fine-grained PAT（対象リポジトリ・書き込みのみ）に限定する。

**[継続] S-SBX: editor iframe に sandbox 属性が未設定**
- 場所: `client/src/App.tsx:141`
- sandbox 未指定のため iframe 内 XSS → 親フレームリダイレクト・任意ポップアップ・localStorage アクセスが可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-forms allow-modals allow-popups"` を付加。

**[継続] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`、`client/public/editor.html`
- CSP ヘッダーもメタタグも存在しない。インラインスクリプト・eval・外部リソースが無制限で、ブラウザ標準の XSS 緩和層が欠如。
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'unsafe-inline'; connect-src 'self' https://api.github.com;">` を追加。

**[継続] S-CLIP: clipboard-read 権限による iframe からのクリップボード窃取リスク**
- 場所: `client/src/App.tsx:146`
- `allow="clipboard-read; clipboard-write; popups"` のまま。`clipboard-read` は iframe がクリップボードを読み取ることを許可。
- **修正案:** `clipboard-read` を allow 属性から削除。

---

### 🟡 Medium

**[継続] S-POPUP: `allow="popups"` が iframe に無制限のポップアップ能力を付与**
- 場所: `client/src/App.tsx:146`
- **修正案:** `popups` を allow リストから削除。

**[継続] NEW-PM2: editor.html から親フレームへの postMessage も `'*'` を使用**
- 場所: `client/public/editor.html:9505, 9539, 9589, 9599, 9609, 9615, 9626, 9630, 9653`
- 悪意ある第三者が親フレームを差し替えた場合、ファイル名・ステータス・検索結果・位置情報・トグル状態が漏洩する。
- **修正案:** `window.parent.postMessage(msg, location.origin)` に統一。

**[継続] S-CSS: `<font color>` 値を介した CSS プロパティインジェクション**
- 場所: `client/public/editor.html:7793-7794`
- **修正案:** color 値を `/^[a-zA-Z0-9#()%., ]+$/` で検証するか、inline style を CSS クラスに置き換え。

**[継続] S-FN: OS 由来の file.name をサニタイズせず postMessage ペイロードに含める**
- 場所: `client/src/App.tsx:111`
- **修正案:** `/[^\w.\- ]/g` で除去するホワイトリストバリデーションを送信前に適用。

**[継続] S-9: 置換ボタンが search と replaceOne/All を連続 postMessage で競合**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- **修正案:** `searchAndReplaceOne`/`searchAndReplaceAll` として単一アクションに統合。

**[継続] S-SW: SW キャッシュバージョン固定・.catch が undefined を返す**
- 場所: `client/public/sw.js:1,14`
- **修正案:** Vite ビルドハッシュをキャッシュ名に含める。catch を `.catch(() => cached ?? new Response('Offline', { status: 504 }))` に変更。

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx:196-198`
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

---

### 🟢 Low

**[継続] NEW-URL: デバッグメモに location.href をそのまま GitHub に公開**
- 場所: `client/public/editor.html:9258`
- **修正案:** `location.origin + location.pathname` のみ記録する。

**[継続] S-4: FileReader.readAsText() エンコーディング引数未指定**
- 場所: `client/src/App.tsx:113`
- **修正案:** `chardet` 等で判定後 `readAsText(file, encoding)` を指定。

**[継続] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html:7790, 7803`

---

## コード品質所見（Agent B）

### 🟠 High

**[継続] Q-NOERR: FileReader.onerror ハンドラ未設定**
- 場所: `client/src/App.tsx:88-92`
- ファイル読み込みエラー時のフィードバックがなく失敗が無音でドロップされる。
- **修正案:** `reader.onerror = () => setStatus('ファイル読み込みエラー')` を追加。

**[継続] Q-MULTI: 連続 send() — ACKなし連続送信**
- 場所: `client/src/components/SearchBar.tsx:77-85`
- `send('search', query); send('replaceOne', replaceText)` 等、受信側の処理順序依存。
- **修正案:** `replaceOne`/`replaceAll` コマンドに query を含め、単一アクションとして送信。

---

### 🟡 Medium

**[継続] Q-CAST: FileReader.result の unsafe な型キャスト**
- 場所: `client/src/App.tsx:90`
- `ev.target?.result as string` は TypeScript のみのアサーション。null 時も `as string` でキャストされ、後続の `!= null` チェックに依存している。
- **修正案:** `if (typeof content !== 'string') return` の型ガードに変更。

**[継続] Q-ORIGIN: postMessage のターゲットオリジンがワイルドカード**
- 場所: `client/src/lib/bridge.ts:3`

**[継続] Q-MSGSRC: message イベントハンドラで e.origin を検証していない**
- 場所: `client/src/App.tsx:72`

**[継続] Q-TAB-TYPE: `Tab` インターフェースの重複定義**
- 場所: `client/src/App.tsx:9-12`、`client/src/components/FileTabBar.tsx:4-7`
- **修正案:** `src/types.ts` 等の共有モジュールに移動。

**[継続] Q-REF: SearchBar 内部 `query` state が外部 `externalQuery` を二重管理**
- 場所: `client/src/components/SearchBar.tsx:15, 22-27`

**[継続] Q-TYPE: `EditorMessage` の全フィールドがオプショナル**
- 場所: `client/src/App.tsx:35-50`
- **修正案:** discriminated union 型に変更。

**[継続] Q-KEY: FileTabBar.tsx:19 — 配列インデックスを React key に使用**
- **修正案:** タブにユニーク ID を付与し `key={tab.id}` を使用。

**[継続] Q-ESL: SearchBar.tsx:26 の eslint-disable-next-line react-hooks/exhaustive-deps**

**[継続] Q-CATCH: bridge.ts:10 — 空 catch ブロック**
- **修正案:** `catch (_e) { /* cross-origin focus blocked — expected */ }` のようにコメントを付ける。

**[継続] Q-TIMER: SearchBar.tsx:65 — Enter キー時の setTimeout がアンマウント時未クリア**
- **修正案:** `useRef` で保持し cleanup 関数でクリア。

**[継続] Q-CMD: App.tsx:64,66,68 — 冗長な `cmd &&` チェック**

**[継続] Q-TOGGLE: App.tsx — `!!` を6フィールド分繰り返し**
- **修正案:** `msg.filterActive ?? toggles.filterActive` の nullish coalescing に変更し、部分更新にも対応。

**[継続] Q-DOM: bridge.ts — `getElementById` をコール毎に重複実行**

---

### 🟢 Low

**[継続] Q-MOUNT-SEARCH: SearchBar マウント時に send('search','') が発火**
- 場所: `client/src/components/SearchBar.tsx:29-33`
- **修正案:** `isMounted` ref でマウント時の初回実行をスキップ。

**[継続] Q-NULLABLE: App.tsx:91 — `content != null` のルーズ等値比較**

**[継続] Q-MAGIC: SearchBar.tsx:65 — マジックナンバー `30`**
- **修正案:** `const SEARCH_NAV_DELAY_MS = 30` として定数化。

**[継続] Q-TITLE: iframe title がハードコード**

---

## バグ・ロジックリスク（Agent C）

### 🟠 High

**[継続] B-13: Ctrl+Z/Y が INPUT/TEXTAREA フォーカス中も editor に転送される（UXバグ）**
- 場所: `client/src/App.tsx:64-65`
- `if (tag === 'IFRAME') return` のみガード。INPUT/TEXTAREA フォーカス中に Ctrl+Z を押すと、ユーザーの入力テキストの undo ではなくエディタの undo が発動する。
- **修正案:** `if (['IFRAME','INPUT','TEXTAREA','SELECT'].includes(tag)) return;`

---

### 🟡 Medium

**[継続] N-1: FileReader にファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx:107-113`
- `reader.readAsText(file)` がサイズ無制限で実行される。数百MB のファイルは JS 文字列に全量読み込まれた後、postMessage でディープコピーされるため、ピーク時のメモリ使用量が2倍になりメインスレッドが長時間フリーズする。
- **修正案:** `if (file.size > 50 * 1024 * 1024) { setStatus('ファイルが大きすぎます（上限 50 MB）'); return }` を reader 呼び出し前に追加。

**[継続] B-2: searchNext/searchPrev を setTimeout(30ms) で呼び出す競合リスク**
- 場所: `client/src/components/SearchBar.tsx:61-65`
- **修正案:** `searchDone` 応答受信後に next/prev を送るコールバック方式に変更。

**[継続] B-3: FileReader.result を型確認なしに string キャスト**
- 場所: `client/src/App.tsx:110`

**[継続] B-8: FileReader に onerror ハンドラなし**
- 場所: `client/src/App.tsx:108-114`

**[継続] B-REPLACE: 置換ボタンが search 完了前に replaceOne/All を送信**
- 場所: `client/src/components/SearchBar.tsx:77-85`

**[継続] B-SW: Service Worker fetch catch が `undefined` を返す可能性**
- 場所: `client/public/sw.js:14`
- **修正案:** `.catch(() => cached ?? new Response('Offline', { status: 504 }))` に変更。

---

### 🟢 Low

**[継続] B-SYNC: stateSync の `!!` 強制キャストが部分更新を全フィールドリセットに変える**
- 場所: `client/src/App.tsx:83-90`

**[継続] B-DEBOUNCE: 外部クリア時にも debounce 経由で `send('search', '')` が発火**
- 場所: `client/src/components/SearchBar.tsx:20-33`

**[継続] B-TAB: FileTabBar — 配列インデックスをキーに使用**

**[継続] B-FOCUS: focusEditor() の空 catch**

---

## 適用済み自動修正

```diff
（なし — console.log / console.error / debugger 文はソースコードに存在しないため修正対象なし）
```

---

## 推奨アクション（優先度順）

1. **[CRITICAL/継続] S-PM + Q-ORIGIN + Q-MSGSRC + NEW-PM2**: postMessage の targetOrigin を `window.location.origin` に統一し、受信側に `e.origin` チェックを追加（bridge.ts・App.tsx・editor.html の各送受信箇所）
2. **[CRITICAL/継続] S-XSS**: `renderHtmlValue` の href に `https?:` ホワイトリスト検証を追加
3. **[HIGH/継続] NEW-PAT + S-5**: デバッグ UI を `import.meta.env.DEV` ガードで本番から除外し、sessionStorage の PAT 保存を廃止する（2箇所・即座に実施可能）
4. **[HIGH/継続] S-CLIP + S-SBX**: iframe allow から `clipboard-read` を削除し、`sandbox` 属性を最小権限で追加
5. **[HIGH/継続] B-13**: `if (tag === 'IFRAME') return` に INPUT/TEXTAREA/SELECT ガードを追加（1行変更）
6. **[MEDIUM/継続] N-1**: FileReader 呼び出し前に 50MB ファイルサイズ制限を追加
7. **[HIGH/継続] S-CSP**: `index.html` / `editor.html` に Content-Security-Policy meta タグを追加
8. **[MEDIUM/継続] NEW-PM2**: editor.html の `window.parent.postMessage` を `location.origin` に統一
9. **[MEDIUM/継続] B-SW + S-SW**: Service Worker の catch フォールバックを `Response('Offline', {status:504})` に修正
10. **[LOW/継続] NEW-URL**: デバッグメモの `location.href` を `origin+pathname` のみに変更

---

> ⚠️ **注記**: 2026-07-22 以降ソースコードへの変更がないため、全40件の指摘が継続中です。Critical 2件・High 7件の早期修正を強く推奨します。
