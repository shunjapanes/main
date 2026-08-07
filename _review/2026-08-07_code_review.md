# コードレビューレポート 2026-08-07 — shunjapanes/main

## サマリー

- 実行日時: 2026-08-07 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 7件 (App.tsx, bridge.ts, FileTabBar.tsx, SearchBar.tsx, RibbonButton.tsx, RibbonToolbar.tsx, sw.js)
- 発見件数: 🔴 Critical 0 / 🟠 High 4 / 🟡 Medium 9 / 🟢 Low 16 = 計29件
- うち新規 [NEW]: **8件** / 継続 [継続]: **21件** / 解消 [FIXED]: **1件**
- 適用済み自動修正: **0件**（src配下に console.log / debugger 文なし）

### 前回比較（2026-08-02）

- 前回: 🔴 0 / 🟠 4 / 🟡 9 / 🟢 15 = 28件
- 今回: 🔴 0 / 🟠 4 / 🟡 9 / 🟢 16 = 29件
- **[FIXED]**: B-DEBOUNCE（SearchBar のアンマウント時タイムアウト漏れ）が解消 ✅
- High 4件は全て継続・未修正
- 新規指摘 8件（Medium 2件 + Low 6件）を追加発見

---

## セキュリティ所見（Agent A）

### 🟠 High

**[継続] S-PM: postMessage の origin 検証なし**
- 場所: `client/src/App.tsx:77`（受信側）、`client/src/lib/bridge.ts:3`（送信側）
- `window.addEventListener('message', handler)` が `e.origin` を一切チェックしない。bridge.ts の `postMessage` も引き続き第2引数 `'*'`（ワイルドカード）を使用。任意のオリジンから status・stateSync・focusSearch 等のメッセージを注入可能。`openContent` 送信時にファイル内容が外部オリジンに漏洩する恐れがある。
- **修正案:** 送信側: `postMessage(data, window.location.origin)`。受信側: `if (e.origin !== window.location.origin) return` を先頭に追加。

**[継続] S-XSS: `javascript:` プロトコルが HTML プレビューの href を通過**
- 場所: `client/public/editor.html`（`renderHtmlValue` 関数）
- `<a href="javascript:alert(1)">` がクリック可能なリンクとして挿入される。`escHtml()` は HTML 特殊文字をエスケープするが `javascript:` プロトコル自体は無害化しない。
- **修正案:** href 挿入前に `url.startsWith('http://') || url.startsWith('https://')` のホワイトリスト検証を追加。

### 🟡 Medium

**[継続] S-CSS: CSS インジェクション（`<font color>` のカラー値が style 属性に直接挿入）**
- 場所: `client/public/editor.html`（`renderHtmlValue` 関数）
- 任意の CSS プロパティを追記可能（UI 偽装・クリックジャッキング相当）。
- **修正案:** `CSS.supports('color', value)` でホワイトリスト検証してから style に挿入。

**[継続] S-CSP: Content-Security-Policy 未設定**
- 場所: `client/index.html`、`client/public/editor.html`
- **修正案:** `<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self';">` を追加。

**[継続] S-SBX: editor iframe に sandbox 属性が未設定**
- 場所: `client/src/App.tsx:141`
- S-XSS が成立した場合、`window.parent` 経由で親フレームの DOM 操作が無制限に可能。
- **修正案:** `<iframe sandbox="allow-scripts allow-same-origin allow-downloads allow-modals" allow="clipboard-read; clipboard-write" ...>`

### 🟢 Low

**[継続] S-REL: `target="_blank"` に `rel="noopener noreferrer"` なし**
- 場所: `client/public/editor.html`（blob プレビュー内リンク）

**[継続] S-CI: deploy.yml の `permissions: contents: write` がワークフロー全体に適用**
- 場所: `.github/workflows/deploy.yml`

**[継続] S-SW: SW キャッシュバージョン固定（セキュリティパッチ不達リスク）**
- 場所: `client/public/sw.js:1` — `const CACHE = 'tsv-editor-v1'`

**[継続] S-POP: iframe に popups 権限を付与**
- 場所: `client/src/App.tsx:143`
- S-XSS と組み合わさるとタブナッピング攻撃に利用可能。`popups` の必要性を確認の上、不要なら削除。

**[継続] S-FT: ファイル種別検証がクライアントの accept 属性のみに依存**
- 場所: `client/src/App.tsx:105-115`
- drag-and-drop 等で accept 属性を迂回でき、任意のファイルを `readAsText` で読み込める。

**[NEW] S-FSZ: ファイルサイズ上限チェックなし**
- 場所: `client/src/App.tsx:104`
- `reader.readAsText(file)` の前にサイズ検証がない。数百 MB のファイルを選択するとブラウザタブがフリーズ（クライアントサイド DoS）。
- **修正案:** `if (file.size > 10 * 1024 * 1024) { alert('ファイルが大きすぎます'); return; }` を追加。

---

## コード品質所見（Agent B）

### 🟡 Medium

**[継続] Q-ESL: SearchBar.tsx:24 の eslint-disable-next-line react-hooks/exhaustive-deps**
- 場所: `client/src/components/SearchBar.tsx:24`
- Q-HYBRID の修正により根本的に解消できる。

**[継続] Q-HYBRID: SearchBar の「半制御」状態パターンが Q-ESL の根本原因**
- 場所: `client/src/components/SearchBar.tsx:13,20-24`
- 内部 `query` state と外部 `externalQuery` prop の両方を保持する半制御パターン。
- **修正案:** fully-controlled パターンに統一。`value={externalQuery ?? ''}` + `onChange` で親が全状態を保持。

**[NEW] Q-CURSOR: RibbonButton.tsx — Tailwind カーソルクラスの競合**
- 場所: `client/src/components/RibbonButton.tsx:15,19`
- `base` クラスに常に `cursor-pointer` が含まれ、disabled 時に `cursor-not-allowed` が追加されるが両方が共存する。Tailwind の出力順に `cursor-not-allowed` の適用が依存するため不安定。
- **修正案:** `base` から `cursor-pointer` を除外し、`stateClass` の非disabled パスにのみ追加。

### 🟢 Low

**[継続] Q-CMD: App.tsx:66,68 — 冗長な `cmd &&` チェック**
- 場所: `client/src/App.tsx:66,68`
- L63 で `if (!cmd) return` により早期リターン済みなのに再確認している。

**[継続] Q-KEY: FileTabBar.tsx:19 — 配列インデックスを React key に使用**
- 場所: `client/src/components/FileTabBar.tsx:19`
- タブ中間削除時に React の reconciliation が誤動作する可能性。`tab.name` 等の安定したキー推奨。

**[継続] Q-DUP: Tab インターフェース重複定義**
- 場所: `client/src/App.tsx:8`、`client/src/components/FileTabBar.tsx:4`
- 同一の `interface Tab { name: string; dirty: boolean }` が 2 ファイルに存在。共通 `types.ts` に切り出し推奨。

**[継続] Q-ECH: bridge.ts:10 — 空の catch ブロック**
- 場所: `client/src/lib/bridge.ts:10`
- `// cross-origin focus may throw; intentionally ignored` 等のコメント追加推奨。

**[継続] Q-ORIGIN: postMessage のワイルドカードオリジン（品質観点）**
- 場所: `client/src/lib/bridge.ts:3`

**[NEW] Q-DBLDIS: RibbonButton.tsx — onClick 条件と disabled 属性の二重ガード**
- 場所: `client/src/components/RibbonButton.tsx:28,31`
- `onClick={disabled ? undefined : ...}` と `disabled={disabled}` が両方存在。HTML の `disabled` 属性がブラウザレベルでクリックを抑制するため ternary は冗長。

**[NEW] Q-MOUNT: SearchBar.tsx — 初回マウント時に search('') を送信**
- 場所: `client/src/components/SearchBar.tsx:27-33`
- debounce の `useEffect` は初回マウント時にも実行され、`send('search', '')` が 180ms 後に無条件で送信される。
- **修正案:** `isFirstRender` ref でスキップ。

---

## バグ・ロジックリスク（Agent C）

### 🟠 High

**[継続] B-TAB: tabs メッセージで activeTab が送られない場合、インデックス不整合が発生**
- 場所: `client/src/App.tsx:83`
- `tabs` メッセージに `activeTab` フィールドが省略された場合、旧い `activeTab` が維持されたまま `tabs` 配列が縮小し、`FileTabBar` でどのタブも選択状態にならない（サイレントな視覚的破損）。
- **修正案:** `tabs` 更新時は必ず `activeTab` もセットする、またはエディタ側プロトコルで保証する。

**[継続] B-ASYNC: SearchBar.tsx:61 — 30ms の固定遅延で searchNext を送信**
- 場所: `client/src/components/SearchBar.tsx:61`
- Enter キー時、`setTimeout(30ms)` で `searchNext` を送るが、大規模ファイルで editor の検索完了前にナビゲーション命令が到達する可能性がある。
- **修正案:** editor 側から `searchReady` 応答を受け取ってから送信する応答ドリブン方式に変更。

### 🟡 Medium

**[継続] B-FILE: App.tsx — FileReader の onerror が未設定**
- 場所: `client/src/App.tsx:108-113`
- `reader.onerror` が未定義のため、ファイル読み込み失敗時にユーザーへのフィードバックがない。
- **修正案:** `reader.onerror = () => setStatus('ファイルの読み込みに失敗しました')` を追加。

**[継続] B-NULL: bridge.ts — iframe が存在しない場合のサイレント失敗**
- 場所: `client/src/lib/bridge.ts:2-3`
- `send` と `focusEditor` は iframe が見つからない場合に無音で何もしない。

**[NEW] N-STATESYNC: App.tsx — 部分的な stateSync メッセージが全トグル状態をリセット**
- 場所: `client/src/App.tsx:91-98`
- editor が一部のフィールドのみ含む `stateSync` メッセージを送った場合、`!!undefined === false` により未送信フィールドが全て `false` にリセットされる。`verticalHeaderActive` は `DEFAULT_TOGGLES` で `true` だが、部分 sync で誤って `false` になりヘッダーが非表示になる可能性がある。
- **修正案:** `setToggles(prev => ({ ...prev, ...(msg.filterActive !== undefined && { filterActive: !!msg.filterActive }), ... }))` のように prev をスプレッドして存在するフィールドのみ上書き。

### 🟢 Low

**[FIXED] B-DEBOUNCE: SearchBar.tsx — アンマウント時のタイムアウト漏れ**
- debounce の `useEffect` クリーンアップが正しく実装されている ✅

**[NEW] N-ENTER-TIMEOUT-LEAK: SearchBar.tsx:61 — Enter キー時 setTimeout の ID が保存されない**
- 場所: `client/src/components/SearchBar.tsx:61`
- `setTimeout(() => send(...), 30)` の戻り値が破棄され、アンマウント時にキャンセル不能。B-DEBOUNCE の修正は debounce のみで Enter パスは未対応。

**[NEW] N-REPLACE-RACE: SearchBar.tsx:103-108 — search と replaceOne/replaceAll のレース**
- 場所: `client/src/components/SearchBar.tsx:103-108`
- `send('search', query); send('replaceOne', replaceText)` を連続送信するが、editor が search を非同期処理する場合、前の match set に対して replace が実行される可能性がある。

**[NEW] N-CLEARSEARCH-ECHO: clearSearch メッセージが search('') を誘発**
- 場所: `client/src/components/SearchBar.tsx:20-33` + `client/src/App.tsx:88`
- editor からの `clearSearch` → App が `searchQuery=''` → SearchBar の sync effect → debounce → `send('search', '')` という 1 サイクルの echo が常に発生する。

---

## 適用済み自動修正

```diff
（なし — src配下に console.log / console.error / debugger 文なし）
```

---

## 推奨アクション（優先度順）

1. **[最優先] S-PM + S-XSS の修正**（High × 2）: `postMessage` の origin 検証追加 + `javascript:` href ホワイトリスト化。セキュリティ上の実害リスクが最大。
2. **B-TAB + N-STATESYNC の修正**（High/Medium）: `tabs` メッセージプロトコルを `activeTab` 必須に変更 + `stateSync` ハンドラを部分更新対応に。UI 破損の根本原因。
3. **S-SBX の追加**（Medium）: iframe に `sandbox` 属性を付与して XSS の被害範囲を封じ込める。
4. **B-FILE の修正**（Medium）: `reader.onerror` 追加でユーザーへエラー通知。
5. **Q-HYBRID の修正**（Medium）: SearchBar を fully-controlled に変更し Q-ESL・B-ASYNC・N-REPLACE-RACE を同時解消できる可能性がある。
6. **S-FSZ の追加**（Low）: ファイルサイズ上限チェック（10MB 程度）をファイル選択時に追加。
