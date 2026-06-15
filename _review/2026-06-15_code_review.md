# コードレビューレポート 2026-06-15 — shunjapanes/main

## サマリー

- 実行日時: 2026-06-15 (自動夜間レビュー)
- プロジェクト: TSV/CSVエディタ (React 19 + TypeScript + Vite + Tailwind)
- レビューファイル数: 8件 (App.tsx, main.tsx, bridge.ts, RibbonToolbar.tsx, SearchBar.tsx, FileTabBar.tsx, StatusBar.tsx, RibbonButton/Group.tsx)
- 発見件数: 🔴 Critical 0 / 🟠 High 6 / 🟡 Medium 9 / 🟢 Low 10
- うち新規 [NEW]: 25件 / 継続 [継続]: 0件 (初回レビュー)
- 適用済み自動修正: 0件 (console.log・debugger・タイポなし)

---

## セキュリティ所見

### 🔴 Critical
なし

### 🟠 High

**[NEW] H-1: GitHub PAT を base64 のみで localStorage に保存**
- 場所: `index.html` — `dbmGetPat()` / `dbmSavePat()` 関数
- `btoa()` は暗号化でなく単なる base64 変換。DevTools で即座に確認可能。
- PAT に `repo` スコープがあるため、XSS 経由で取得されると `shunjapanes/main` への書き込みが可能。
- **修正案:** PAT はセッション変数（メモリのみ）に保持し localStorage には保存しない。長期保存が必要な場合は Web Crypto API (AES-GCM) で暗号化。

**[NEW] H-2: postMessage の targetOrigin が `'*'`（送受信とも）**
- 場所: `client/src/lib/bridge.ts:3`、`index.html` 内の RIBBON BRIDGE 送信箇所
- `e.origin` 検証なし。将来クロスオリジン環境に置かれた場合、悪意ある第三者がメッセージを傍受可能。
- **修正案:** `postMessage` の第2引数を `window.location.origin` に変更。受信側にも `if (e.origin !== window.location.origin) return` を追加。

**[NEW] H-3: `isHtml` 列の `javascript:` URI スキームを検証しない**
- 場所: `index.html` — HTML レンダリング処理
- `escHtml(url)` はHTMLエンティティをエスケープするが `javascript:` スキームを許可。クリッカブルなXSSペイロードが生成されうる。
- **修正案:** `const safeUrl = /^(https?:|mailto:)/i.test(url) ? url : '#';` に絞る。`rel="noopener noreferrer"` も追加。

**[NEW] H-4: ファイル読み込みエンコーディング固定（Shift-JIS文字化け）**
- 場所: `client/src/App.tsx:113` — `reader.readAsText(file)`
- エンコーディング指定なし → UTF-8 固定。Shift-JIS / EUC-JP の日本語 CSV/TSV を開くと文字化け。
- **修正案:** `encoding-japanese` ライブラリで自動検出するか、エンコーディング選択UIを提供。

### 🟡 Medium

**[NEW] M-1: App.tsx の message ハンドラに origin 検証なし**
- 場所: `client/src/App.tsx:67`
- 悪意あるページが `window.opener.postMessage()` を送ることで UI 状態（トグル・検索フォーカス等）を操作可能。
- **修正案:** `if (e.origin !== window.location.origin) return`

**[NEW] M-2: iframe に sandbox 属性なし**
- 場所: `client/src/App.tsx:116-120`
- `editor.html` は完全な同一オリジン権限を持ち、`window.parent` DOM へ直接アクセス可能。
- **修正案:** `sandbox="allow-scripts allow-same-origin allow-downloads allow-popups"` を最小権限で追加。

**[NEW] M-3: DebugMemo ボタンが本番 UI に露出**
- 場所: `client/src/components/RibbonToolbar.tsx` — ToolsTab「デバッグ」グループ
- 全ユーザーが PAT を入力してリポジトリにファイルをアップロードできる状態。
- **修正案:** `{import.meta.env.DEV && <RibbonGroup ...>}` で開発環境限定に制限。

**[NEW] M-4: CSP (Content-Security-Policy) が存在しない**
- 場所: `index.html` head、`.github/workflows/`
- XSS 成立時の第2の防衛線がない。
- **修正案:** CSP メタタグを追加（ただしインライン script が多いため nonce/hash 対応が必要）。

**[NEW] M-5: Service Worker が古いキャッシュを永続的に保持**
- 場所: `client/public/sw.js:6-16` — Cache-first 戦略
- `CACHE = 'tsv-editor-v1'` が変更されるまでセキュリティ更新が反映されない。
- **修正案:** Network-first または Stale-while-revalidate 戦略に変更。

### 🟢 Low

**[NEW] L-1: focusEditor() の空 catch {} でエラーが無音消去**
- 場所: `client/src/lib/bridge.ts:6-11`
- セキュリティイベント（SecurityError等）の検知が困難。開発環境でのみ `console.warn` 出力を推奨。

**[NEW] L-2: HTML エクスポートに `<script>` タグが埋め込まれる**
- 場所: `index.html` — `exportHtmlPreview` 生成 HTML
- エクスポート HTML 内のスクリプトにセル値由来文字列が含まれる可能性。エスケープの継続確認が必要。

**[NEW] L-3: replaceOne/replaceAll payload が文字列か未検証**
- 場所: `index.html` — RIBBON BRIDGE replaceAll ハンドラ
- `typeof payload === 'string'` チェックがなく、オブジェクト等が渡された場合の挙動が未定義。

**[NEW] L-4: contenteditable メモ本文の HTML サニタイズなし**
- 場所: `index.html` — `#debug-memo-body` (contenteditable div)
- `innerText` で送信するため XSS ではないが、悪意ある HTML の貼り付けに対するサニタイズが不在。

---

## コード品質所見

**[NEW] Q-1: EditorMessage インターフェースが Discriminated Union でない** 🟡 Medium
- 場所: `client/src/App.tsx:22-36`
- `type` フィールドで絞り込んでいるにも関わらず、全フィールドが `?` でフラットに並ぶ。型安全性が低い。
- **修正案:** `| { type: 'status'; text: string } | { type: 'searchCount'; count: string } | ...` の判別共用体へ。

**[NEW] Q-2: デバウンス useEffect のクリーンアップに競合の余地** 🟡 Medium
- 場所: `client/src/components/SearchBar.tsx:27-33`
- クリーンアップ時に `debounceRef.current` が次の effect に上書きされている可能性。タイマーIDをローカル変数にキャプチャするパターンが安全:
```typescript
const id = setTimeout(() => send('search', query), 180)
return () => clearTimeout(id)
```

**[NEW] Q-3: RibbonToolbar.tsx に6コンポーネントが混在（10.7KB）** 🟡 Medium
- 場所: `client/src/components/RibbonToolbar.tsx`
- `FileTab`, `HomeTab`, `DataTab`, `ViewTab`, `ToolsTab`, `Divider` が1ファイルに集中。`components/tabs/` への分割を推奨。

**[NEW] Q-4: FileTabBar.tsx で `key={i}` インデックスキー使用** 🟡 Medium
- 場所: `client/src/components/FileTabBar.tsx`
- タブ追加・削除・並べ替えで React の reconciliation が誤判定しうる。`key={tab.name}` に変更（重複名がある場合は ID を追加）。

**[NEW] Q-5: handleKeyDown 内の `cmd` 二重チェック** 🟢 Low
- 場所: `client/src/App.tsx:61-71`
- `if (!cmd) return` の後に `if (cmd && ...)` を再チェック。デッドコードではないが冗長。

**[NEW] Q-6: Enter キー後の 30ms 固定遅延のマジックナンバー** 🟢 Low
- 場所: `client/src/components/SearchBar.tsx:61`
- 意図（postMessage 処理待ち）のコメントがなく、低速環境では動作不安定。

**[NEW] Q-7: X ボタン・ナビゲーションボタンに aria-label なし** 🟢 Low
- 場所: `client/src/components/SearchBar.tsx:69`, ChevronUp/Down ボタン
- スクリーンリーダーが「button」としか読み上げない。`aria-label="検索をクリア"` 等を追加。

**[NEW] Q-8: onOpenFile フォールバックがデッドコード** 🟢 Low
- 場所: `client/src/components/RibbonToolbar.tsx:68`
- `onOpenFile ? onOpenFile() : send('open')` — App.tsx は常に `onOpenFile` を渡しており、フォールバックは到達不能。`onOpenFile` を必須 props にして整理すること。

**[NEW] Q-9: 命名規則の不一致（`condHLActive` vs `verticalHeaderActive`）** 🟢 Low
- 場所: `client/src/App.tsx` — `ToggleStates` インターフェース
- 略語と完全表記が混在。統一すること。

---

## バグ・ロジックリスク

**[NEW] B-1: Enterキー後の searchNext が 30ms 固定遅延に依存** 🟠 High
- 場所: `client/src/components/SearchBar.tsx:61`
- 重いファイルや低速環境で検索インデックス構築が間に合わず `searchNext` が空振りする。
- **修正案:** iframe 側から「search 完了」応答を受け取ってからナビゲートするコールバック方式へ。

**[NEW] B-2: 置換ボタンが search と replace を連続 postMessage で競合** 🟠 High
- 場所: `client/src/components/SearchBar.tsx:103-108`
- `send('search', query)` と `send('replaceOne', ...)` を同時発火。前の検索中に置換命令が到着するリスク。
- **修正案:** 単一の `searchAndReplaceOne` アクション、またはコールバック方式。

**[NEW] B-3: iframe が null の場合 send() が無音で失敗** 🟠 High
- 場所: `client/src/lib/bridge.ts:1-4`
- optional chaining で null 時は何もせず終了。undo・save 等の操作が黙って捨てられる。
- **修正案:** エラーログ出力、またはリトライキュー実装。

**[NEW] B-4: reader.onerror ハンドラが未定義** 🟡 Medium
- 場所: `client/src/App.tsx:108-116`
- ファイル読み取りエラー時にユーザーへのフィードバックが一切ない。

**[NEW] B-5: gotoRow に 0 や過大な値が渡せる** 🟡 Medium
- 場所: `client/src/components/SearchBar.tsx` — `rowNum` state
- `replace(/[^0-9]/g, '')` は `"0"` を通過。`parseInt(rowNum) >= 1` のバリデーションを追加すること。

**[NEW] B-6: gotoRow のペイロードが文字列型** 🟡 Medium
- 場所: `client/src/components/SearchBar.tsx`
- `send('gotoRow', rowNum)` で文字列を送信。iframe 側が数値を期待する場合に不一致。`parseInt(rowNum, 10)` に変換すること。

**[NEW] B-7: externalQuery 同期の stale closure リスク** 🟢 Low
- 場所: `client/src/components/SearchBar.tsx:22-26` (eslint-disable)
- `query` を依存配列から除外しているため、頻繁な変化で不整合状態が発生しうる。

**[NEW] B-8: デバウンス StrictMode での二重実行** 🟢 Low
- 場所: `client/src/components/SearchBar.tsx:27-33`
- `main.tsx` で `StrictMode` 有効のため開発環境で `clearTimeout` が意図しないタイミングで実行されうる。

---

## 適用済み自動修正

```diff
（なし — console.log・console.error・debugger・タイポ・行末空白は検出されませんでした）
```

---

## 推奨アクション（優先度順）

1. **[緊急] H-2: GitHub PAT を localStorage から除去** — XSS → PAT 漏洩 → リポジトリ書き込みの攻撃チェーンを断つ
2. **[緊急] H-3: `javascript:` URI スキームをブロック** — CSVデータ経由のクリッカブル XSS を防止
3. **[高] H-1/M-1: postMessage の origin 検証を追加** — bridge.ts と App.tsx の両方
4. **[高] H-4: ファイル読み込みエンコーディング対応** — 日本語 Shift-JIS ファイルの文字化けを修正
5. **[高] B-1/B-2: 検索→ナビゲーション・検索→置換の race condition を修正** — コールバック方式または単一アクション化
6. **[中] M-2: iframe に sandbox 属性を追加**
7. **[中] M-3/Q-8: デバッグ機能を本番ビルドから除外**
8. **[中] Q-1: EditorMessage を Discriminated Union に移行**
9. **[中] Q-2: デバウンス cleanup のローカルキャプチャ修正**
10. **[低] Q-4: FileTabBar の key={i} を key={tab.name} に変更**
