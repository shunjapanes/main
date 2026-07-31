# コードレビューレポート 2026-07-31 — shunjapanes/main

## サマリー

- 実行日時: 2026-07-31 16:09 UTC（自動レビュー・3エージェント並列）
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 10件 (App.tsx, bridge.ts, SearchBar.tsx, FileTabBar.tsx, RibbonButton.tsx, RibbonGroup.tsx, RibbonToolbar.tsx, StatusBar.tsx, main.tsx, sw.js)
- 発見件数: 🔴 Critical 0 / 🟠 High 10 / 🟡 Medium 15 / 🟢 Low 16 = 計41件
- うち新規 [NEW]: **9件** / 継続 [継続]: **32件** / 解消 [FIXED]: **0件**
- 適用済み自動修正: **0件**（console.log / debugger / trailing whitespace なし）

### 今回の主な変化

| 変化 | 内容 |
|------|------|
| ℹ️ src変更なし | 2026-07-22 以降、src/ への新規コミットなし（9日間停止中） |
| 🆕 Q-M-1 [NEW] Medium | `App.tsx` の `FileReader.onerror` ハンドラ欠如 — ファイル読み込み失敗時に無音で失敗 |
| 🆕 Q-M-2 [NEW] Medium | `sw.js` の fetch catch で `cached` が undefined の場合に `TypeError` — オフライン時クラッシュ |
| 🆕 Q-L-2 [NEW] Low | `App.tsx` handleKeyDown 内の冗長な `cmd &&` チェック（early return で常に true） |
| 🆕 Q-L-3 [NEW] Low | `SearchBar.tsx` の魔法の数字 `180`/`30` ms — 定数化されていない |
| 🆕 Q-L-5 [NEW] Low | `App.tsx` の `!= null` ルーズ等価チェック — TypeScript 慣習と不一致 |
| 🆕 B-18 [NEW] High | `clearSearch` メッセージが SearchBar UI を実際にリセットしない — `setSearchQuery('')` が no-op |
| 🆕 B-20 [NEW] Medium | SearchBar sync `useEffect` の stale closure — `query` が古い値を参照 |
| 🆕 B-22 [NEW] Low | SearchBar debounce が初回マウント時に `send('search','')` を発火 |
| 🆕 B-23 [NEW] Low | `sw.js` が非 ok ネットワーク応答をキャッシュより優先して返却 |

---

## セキュリティ所見

### 🔴 Critical

**（なし）**

---

### 🟠 High（セキュリティ）

**[継続] S-28: iframe の `allow` 属性に `clipboard-read` + `popups` — XSS と複合でクリップボード盗取・タブナッピング成立**
- 場所: `client/src/App.tsx` — `<iframe allow="clipboard-read; clipboard-write; popups">`
- S-3 の XSS が editor.html で実行された場合、`navigator.clipboard.readText()` でクリップボード（パスワード等）を外部送信可能。`popups` はタブナッピング（フィッシングページ誘導）を可能にする。S-7（sandbox なし）が未修正のため複合的に深刻。
- **修正案:** `allow` から `clipboard-read` と `popups` を削除し `clipboard-write` のみ残す。同時に S-7 の sandbox 追加。

**[継続] S-27: GitHub PAT が sessionStorage に保存 — S-3 の javascript: XSS で1クリック漏洩**
- 場所: `client/public/editor.html`（sessionStorage.setItem 処理）
- S-28 と組み合わさることで攻撃チェーンが完成（XSS → PAT → clipboard → repo 書き込み）。
- **修正案:** ① S-3 の javascript: ブロック。② PAT をモジュール変数のみに保持しリロードごとに再入力。

**[継続] S-3: `<a href>` の URL で `javascript:` スキームを検証しない（XSS）**
- 場所: `client/public/editor.html` — `renderHtmlValue` の isHtml セル処理
- **修正案:** `const u = new URL(url, location.href); if (!['http:','https:'].includes(u.protocol)) return escHtml(text);`

**[継続] S-2: postMessage の targetOrigin が `'*'`（bridge.ts 親→子）**
- 場所: `client/src/lib/bridge.ts:3`
- **修正案:** `postMessage(msg, new URL(iframe.src, location.href).origin)`

**[継続] S-5: デバッグ機能 (debugMemo) が本番 UI に露出 — DEV ガードなし**
- 場所: `client/src/components/RibbonToolbar.tsx` — `ToolsTab` の `<RibbonGroup label="デバッグ">`
- **修正案:** `{import.meta.env.DEV && <RibbonGroup label="デバッグ">...</RibbonGroup>}`

**[継続] S-7: iframe に sandbox 属性なし → フルオリジン信頼**
- 場所: `client/src/App.tsx`
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-clipboard-write"`

**[継続] S-24: `new RegExp(q)` が無制限実行 → ReDoS**
- 場所: `client/public/editor.html` — regex モード検索処理
- **修正案:** 入力長上限（200文字）＋実行タイムアウト追加。

**[継続] S-25: editor.html の `window.parent.postMessage` が全て `'*'`**
- 場所: `client/public/editor.html` — 複数箇所（9505, 9539, 9589 等）
- **修正案:** `window.parent.postMessage(msg, location.origin)` に統一。

**[継続] B-13 (セキュリティ兼バグ): Ctrl+Z/Y が INPUT/TEXTAREA フォーカス中もエディタに転送**
- 場所: `client/src/App.tsx:64–65`
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

---

### 🟡 Medium（セキュリティ）

**[継続] S-8: App.tsx の message ハンドラが `e.origin` 未検証**
- **修正案:** `if (e.origin !== window.location.origin) return;`

**[継続] S-12: editor.html が `e.origin` 未検証（`e.source` チェックのみ）**
- **修正案:** `e.origin` チェックを追加。

**[継続] S-9: `send()` が iframe contentWindow null 時に無音で失敗**
- `bridge.ts` の optional chaining はエラーを飲み込む。エラー通知なし。

**[継続] S-14: FileReader 経由でローカルファイルパスが `filename` として editor.html に送信**
- 場所: `App.tsx` — `send('openContent', { content, filename: file.name })`
- `file.name` はファイル名のみ（パスなし）なので直接のパス漏洩リスクは低いが、editor.html 側でのサニタイズ確認が必要。

**[継続] S-15: Service Worker キャッシュが HTTPS 限定でない**
- 場所: `sw.js` — `cache.put` でレスポンスの `ok` をチェックしていない
- HTTP 経由の非 ok レスポンス（404, 500）がキャッシュされる可能性。

**[継続] S-16: `import.meta.env.BASE_URL` に外部制御可能な文字列を連結**
- 場所: `App.tsx` — `` src={`${import.meta.env.BASE_URL}editor.html`} ``
- Vite ビルド時定数のため実害は極めて限定的だが、開発環境での環境変数汚染に注意。

---

### 🟢 Low（セキュリティ）

**[継続] S-10: `focusEditor()` の空 catch が DOM 操作エラーを隠蔽**
- 場所: `client/src/lib/bridge.ts`

**[継続] S-11: タブ `dirty` フラグが editor → React への一方向のみ**
- アプリ再レンダリング時に未保存状態の不一致リスク。

**[継続] S-13: Content-Security-Policy ヘッダーが未設定**
- 展開環境に依存しているが、HTML/JS レベルでの meta CSP が望ましい。

**[継続] S-17: sw.js の CACHE 文字列 `'tsv-editor-v1'` がハードコード — キャッシュバスト困難**

---

## コード品質所見

### 🟡 Medium（品質）

**[継続] Q-3: SearchBar の debounce / sync ロジックが2つの `useEffect` で複雑に絡み合う**
- 場所: `client/src/components/SearchBar.tsx` — lines 20–33
- `externalQuery` 同期 effect と search 送信 debounce effect が相互作用し、予期しない副作用を生む。
- **修正案:** 内部 `query` state を廃止し、入力を `externalQuery` で直接ドライブする controlled pattern に統一。

**[継続] Q-N-20: `clearSearch` メッセージ → debounce → `send('search','')` 意図しないラウンドトリップ**
- 場所: `App.tsx:88` + `SearchBar.tsx` debounce effect
- エディタが `clearSearch` を送信すると、180ms 後に `send('search','')` が逆送されフリッカーの原因になる。
- **修正案:** 外部 clear の場合はデバウンスをキャンセルし search を送信しない。

**[NEW] Q-M-1: `App.tsx` に `FileReader.onerror` ハンドラが欠如**
- 場所: `client/src/App.tsx` — handleFileSelected
- ファイル読み込み失敗時（大容量バイナリ、I/O エラー等）にユーザーへのフィードバックがなく、ステータスバーが `準備完了` のまま固まる。
- **修正案:** `reader.onerror = () => { setStatus('ファイルの読み込みに失敗しました') }` を追加。

**[NEW] Q-M-2: `sw.js` の fetch catch で `cached` が undefined の場合 TypeError**
- 場所: `client/public/sw.js` — fetch イベントハンドラ
- 初回訪問でネットワーク失敗時、`cached` は undefined → `e.respondWith(undefined)` でブラウザが TypeError をスロー。また `resp.ok` チェックなしで `cache.put` しているため 404 等が永続キャッシュされる。
- **修正案:** catch 内に `return cached ?? new Response('Offline', { status: 503 })` を追加し、`resp.ok` チェック後にキャッシュ。

---

### 🟢 Low（品質）

**[継続] Q-4: `// eslint-disable-next-line react-hooks/exhaustive-deps` in SearchBar.tsx**
- Lint ルールを抑制するのではなく Q-3 の設計修正で解消可能。

**[継続] Q-L-4: React key に配列インデックスを使用（FileTabBar.tsx `key={i}`）**
- タブを中間で閉じると後続タブの key がずれ、dirty インジケータやトランジションが誤動作する可能性。
- **修正案:** `key={tab.name}` など安定した識別子を使用。

**[NEW] Q-L-2: `handleKeyDown` 内の冗長な `cmd &&` チェック（早期 return 後は常に true）**
- 場所: `client/src/App.tsx:66–69`
- `if (!cmd) return` の後の `if (cmd && ...)` は常に true の条件。デッドコード。
- **修正案:** `cmd &&` を両方の内側条件から削除。

**[NEW] Q-L-3: 魔法の数字 `180` / `30` ms が定数化されていない（SearchBar.tsx）**
- 場所: `client/src/components/SearchBar.tsx` — lines 31, 61
- 特に `30`ms はレースコンディション回避のガードであることが暗黙的。
- **修正案:** `const SEARCH_DEBOUNCE_MS = 180` / `const SEARCH_NAV_DELAY_MS = 30` として上部で定義。

**[NEW] Q-L-5: `App.tsx` の `!= null` ルーズ等価 — TypeScript 慣習と不一致**
- 場所: `client/src/App.tsx:111` — `if (content != null)`
- TypeScript strict mode では `!== null` が慣用的。
- **修正案:** `if (content !== null)` に変更。

**[継続] Q-L-6: `bridge.ts` `focusEditor` の空 catch はデバッグを困難にする**
- 場所: `client/src/lib/bridge.ts`
- 開発環境では `console.warn` 等でエラーを可視化する価値がある。

---

## バグ・ロジックリスク

### 🟠 High（バグ）

**[継続] B-13: Ctrl+Z/Y が INPUT/TEXTAREA フォーカス中もエディタに転送される**
- 場所: `client/src/App.tsx:64–65` — `if (tag === 'IFRAME') return` のみ
- 検索バーやテキスト入力でテキスト編集中に Ctrl+Z を押すと、自分の入力を元に戻す代わりにエディタへ undo が送信される。
- **修正案:** `if (tag === 'INPUT' || tag === 'TEXTAREA') return;` を追加。

**[NEW] B-18: `clearSearch` メッセージが SearchBar UI を実際にリセットしない**
- 場所: `client/src/App.tsx:88` + `client/src/components/SearchBar.tsx` sync effect
- `searchQuery` は初期値 `''` のため、editor からの `clearSearch` で `setSearchQuery('')` を呼んでも state は変わらず re-render が起きない。`externalQuery` prop が変化しないため SearchBar の sync effect も発火せず、検索ボックスに入力したテキストが残る。
- **失敗シナリオ:** ユーザーが "foo" と検索 → Escape → editor が `clearSearch` 送信 → 検索ボックスに "foo" が残ったまま → UI とエディタ状態が不一致。
- **修正案:** `clearSearch` 受信時にカウンタをインクリメントするなど、確実に prop が変化する仕組みへ変更。

---

### 🟡 Medium（バグ）

**[継続] B-14: `FileReader.readAsText` がデフォルト UTF-8 のみ — Shift-JIS ファイルで文字化け**
- 場所: `client/src/App.tsx` — handleFileSelected
- **修正案:** Encoding API (`TextDecoder`) で文字コード検出・変換を行う、またはファイルエンコーディング選択 UI を追加。

**[継続] B-16: Enter キー押下時に `searchNext` を 30ms 遅延送信 — 低速エディタでレースコンディション**
- 場所: `client/src/components/SearchBar.tsx:61`
- **修正案:** editor 側から検索完了 ack を受けてからナビゲートする非同期フローに変更。

**[継続] B-17: `gotoRow` に文字列型 `rowNum` を送信（数値が期待される可能性）**
- 場所: `client/src/components/SearchBar.tsx:47`
- `rowNum` は string。editor.html 側で parseInt を期待している場合、暗黙変換が発生。
- **修正案:** `send('gotoRow', parseInt(rowNum, 10))`

**[NEW] B-20: SearchBar sync `useEffect` の stale closure — `query` が古い値を参照**
- 場所: `client/src/components/SearchBar.tsx` — 1番目の `useEffect`
- `query` が依存配列から除外されており（lint 抑制）、`externalQuery` が変化した時点の `query` 値を closure がキャプチャ。ユーザーが typing 中に `externalQuery` が変化すると guard 条件が古い値を比較し同期をスキップすることがある。
- **修正案:** `useRef` で `query` の現在値を追跡するか、`key` reset パターンで sync を単純化。

**[継続] B-N-1: clearSearch ラウンドトリップ — editor→App→SearchBar→debounce→send('search','')→editor**
- 場所: `App.tsx:88` + `SearchBar.tsx` debounce effect
- Q-N-20 と同一の根本原因。B-18 が修正された後に顕在化するリスク。

---

### 🟢 Low（バグ）

**[継続] B-15: `FileTabBar` の React key にインデックスを使用 — タブ操作時の DOM 再利用誤り**
- 場所: `client/src/components/FileTabBar.tsx` — `key={i}`
- 中間のタブを閉じると後続タブの key がシフトし、React が DOM ノードを誤って再利用する。

**[NEW] B-22: SearchBar debounce が初回マウント時に `send('search', '')` を発火**
- 場所: `client/src/components/SearchBar.tsx` — debounce `useEffect`
- 初回マウント時も `query=''` で effect が実行され、180ms 後に `send('search', '')` が editor に送信される。editor が復元済み検索状態を持つ場合にクリアされる。
- **修正案:** `isMountedRef` フラグで初回 effect をスキップ。

**[NEW] B-23: `sw.js` が非 ok ネットワーク応答をキャッシュより優先して返却**
- 場所: `client/public/sw.js`
- `cache.put` は `resp.ok` チェックで保護されているが、非 ok 応答（503 等）はキャッシュ済みバージョンが存在してもそのまま返却される。
- **修正案:** `return resp.ok ? resp : (cached ?? resp)` — エラー応答の場合はキャッシュを優先。

**[継続] B-24: `FileTabBar` スクロールコンテナでアクティブタブへの自動スクロール未実装**
- タブ数が多い場合、アクティブタブが非表示になっても自動スクロールしない。

**[継続] B-25: `StatusBar` の `status || ' '` — 空白文字がアクセシビリティ的に不明確**
- スペースを `aria-label` なしで挿入するのは空要素より混乱を招く可能性。

**[継続] B-26: `import.meta.env.BASE_URL` の trailing slash 依存**
- BASE_URL が `/` で終わらない場合 `editor.html` のパスが壊れる可能性（Vite は通常保証するが明示的ガードなし）。

---

## 適用済み自動修正

```diff
(変更なし — console.log / debugger / trailing whitespace は検出されず)
```

---

## 推奨アクション（優先度順）

1. **[最優先] S-3 を修正**: `javascript:` URL の XSS ブロック — S-27・S-28 の攻撃チェーンの起点
2. **[最優先] S-7 を修正**: iframe に `sandbox` 属性を追加 — popup 権限をデフォルト剥奪
3. **[高] S-28 を修正**: `allow` から `clipboard-read` と `popups` を削除
4. **[高] S-2 / S-25 を修正**: `postMessage` の targetOrigin を `'*'` から `location.origin` に変更
5. **[高] B-13 を修正**: INPUT/TEXTAREA フォーカス中の undo/redo 誤送信防止
6. **[高] S-5 を修正**: `debugMemo` ボタンを DEV ガードで囲む
7. **[高] B-18 を修正**: `clearSearch` no-op を修正し SearchBar UI を正しくリセット
8. **[中] Q-M-1/B-21 を修正**: `FileReader.onerror` ハンドラ追加
9. **[中] Q-M-2/B-19 を修正**: `sw.js` の offline fallback と ok チェック追加
10. **[中] B-20 を修正**: SearchBar sync effect の stale closure を解消
11. **[中] Q-3 / Q-N-20 を修正**: SearchBar を controlled component パターンに統一（B-22/B-N-1 も解消）
12. **[低] Q-L-2/3/5 を修正**: コード品質の細部改善（冗長チェック・魔法の数字・等価演算子）
