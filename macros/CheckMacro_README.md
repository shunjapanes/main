# CheckMacro（チェックシート記入マクロ）

チェックシートのボタンを押した行に「担当者名」と「日時」を自動記入する Excel VBA マクロ。

## ファイル
| ファイル | エンコード | 用途 |
|---|---|---|
| `CheckMacro.bas` | UTF-8 | ソース管理用・macOS 版 Excel でのインポート用 |
| `CheckMacro_Win.bas` | Shift-JIS (CP932) | **Windows 版 Excel** でのインポート用 |

## 文字化けについて
Windows 版 Excel の VBE は `.bas` インポート時にファイルをシステムの
ANSI コードページ（日本語環境では Shift-JIS）として読み込むため、
UTF-8 の `.bas` を読み込むとコメントや文字列が文字化けします。
そのため Windows では **`CheckMacro_Win.bas`（Shift-JIS）** を取り込んでください。
（マクロのロジック自体は `#If Mac Then` で Win / Mac 両対応済みです）

## 導入手順（Windows）
1. Excel で Alt+F11 → VBE を開く
2. ファイル → ファイルのインポート → `CheckMacro_Win.bas` を選択
3. `SetupSheets` を一度実行（`Users` シートと `_設定` シートが作成される）
4. `Users` シートに自分の OS ユーザー名と表示名を登録
   （OS ユーザー名は `ShowMyUserName` を実行すると確認できる）
5. チェックシートにボタンを配置し、マクロ `StampCheck` を割り当てる
