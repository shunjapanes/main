Windows 版 Excel VBA マクロを作成・修正します。非エンジニアでも読めるコメントと、リリース前チェックリストを必ず実施してください。

---

## ■ 基本方針

- **対象環境**: Windows 版 Excel 2016 以降（Microsoft 365 含む）
- **文字コード**: Shift-JIS (CP932) でファイルを保存すること（VBE インポート時に文字化けしないため）
- **コメント**: 非エンジニアが読んで意図がわかる日本語で書く
- **エラー処理**: ユーザーが状況を理解できるメッセージを必ず表示する

---

## ■ コメント記述ルール（最重要）

### 良いコメントの原則
「何をしているか」ではなく **「なぜそうしているか」「何に注意すべきか」** を書く。

```vba
' ■ 悪い例（何をしているか＝コードを読めばわかる）
i = i + 1  ' i に 1 を足す

' ■ 良い例（なぜ・注意点）
i = i + 1  ' ヘッダー行（1行目）をスキップしているので 2 から開始
```

### ブロックコメントのフォーマット
```vba
'==============================================================
' モジュール名：CheckMacro
' 目的：チェックシートのボタンを押すと、担当者名と日時を自動入力する
' 使い方：
'   1. Excelのボタンにこのマクロ（StampCheck）を割り当てる
'   2. ボタンを押すと「担当者名」と「日時」が自動で入力される
' 注意：
'   ・シートが保護されている場合は動かない（保護を解除してから使う）
'   ・「Users」シートに自分の PC ユーザー名と表示名を登録しておくこと
'==============================================================
```

### サブルーチン・関数のコメント
```vba
'--------------------------------------------------------------
' 【処理名】在庫数チェック
' 【やること】指定した行の在庫数が 0 以下なら警告を出す
' 【引数】
'   targetRow ： チェックする行番号（例: 5）
' 【戻り値】
'   True  = 在庫あり（問題なし）
'   False = 在庫なし（警告を出す）
' 【注意】在庫列は C 列固定（設定シートで変更可能）
'--------------------------------------------------------------
Private Function CheckStock(targetRow As Long) As Boolean
```

### インラインコメントの書き方
```vba
' --- 変数宣言 ---
Dim lastRow As Long     ' データが入っている最終行番号
Dim userName As String  ' 担当者の表示名（「田中 太郎」形式）

' --- 処理開始 ---
' A列の一番下のデータがある行を探す（空白セルは無視する）
lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

' もしデータが 1 行目（ヘッダー）しかなければ処理を止める
If lastRow < 2 Then
    MsgBox "データがありません。A列にデータを入力してください。", vbInformation, "データなし"
    Exit Sub
End If
```

---

## ■ コーディング規約

### 必須ルール
```vba
Option Explicit  ' 変数の宣言を必須にする（宣言し忘れバグを防ぐ）
```

### 変数命名規則
| 型 | プレフィックス | 例 |
|---|---|---|
| String | str / なし | userName, strPath |
| Long / Integer | i, n, lng | lastRow, itemCount |
| Boolean | is / b | isValid, bExists |
| Worksheet | ws | wsData, wsConfig |
| Workbook | wb | wbTarget |
| Range | rng | rngHeader |
| Variant | v / なし | v, cellValue |

### エラー処理の書き方
```vba
' ■ 処理が失敗したときにユーザーに分かりやすく伝える
On Error GoTo ErrorHandler

    ' （メイン処理）

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description & vbCrLf & _
           "エラー番号: " & Err.Number, _
           vbCritical, "エラー"
End Sub
```

### ユーザーへのメッセージ
```vba
' ■ 成功メッセージ
MsgBox n & " 件を処理しました。", vbInformation, "完了"

' ■ 確認メッセージ（はい/いいえ）
If MsgBox("上書きしますか？", vbYesNo + vbQuestion, "確認") = vbNo Then Exit Sub

' ■ 警告（処理は続行）
MsgBox "〇〇行目のデータが空白です。スキップします。", vbExclamation, "注意"

' ■ 致命的エラー（処理を止める）
MsgBox "シートが見つかりません。「設定」シートを作成してください。", vbCritical, "エラー"
```

### パフォーマンス改善（件数が多い場合）
```vba
' ■ 大量データ処理の前後に必ずセットで書く
Application.ScreenUpdating = False   ' 画面更新を止める（速くなる）
Application.DisplayAlerts = False    ' 確認ダイアログを抑制

    ' （メイン処理）

Application.DisplayAlerts = True
Application.ScreenUpdating = True
```

---

## ■ ファイル・モジュール構成

### 推奨モジュール分割
| モジュール名 | 役割 |
|---|---|
| `Main.bas` | エントリーポイント（ユーザーが実行するマクロ） |
| `DataUtil.bas` | データ読み書き・検索などの共通処理 |
| `UIHelper.bas` | メッセージ表示・進捗バーなど画面系の処理 |
| `Config.bas` | シート名・列番号などの定数・設定値 |

### 定数は先頭にまとめる
```vba
' ■ 設定値（ここを変えるだけで動作が変わる）
Private Const SHEET_DATA    As String = "データ"     ' データシートの名前
Private Const SHEET_CONFIG  As String = "_設定"      ' 設定シートの名前
Private Const COL_NAME      As Long   = 2            ' 担当者名の列番号（B列=2）
Private Const COL_DATE      As Long   = 3            ' 日付の列番号（C列=3）
Private Const HEADER_ROW    As Long   = 1            ' ヘッダー行番号
```

---

## ■ Windows 環境での注意点

### ファイルパス
```vba
' ■ Windows のパス区切りは「\」（スラッシュではない）
Dim savePath As String
savePath = Environ("TEMP") & "\" & "output_" & Format(Now, "yyyymmdd") & ".xlsx"
' → 例: C:\Users\username\AppData\Local\Temp\output_20260101.xlsx
```

### ユーザー名取得
```vba
' ■ Windows のログインユーザー名を取得する
Dim winUser As String
winUser = Environ("USERNAME")  ' 例: tanaka.taro
```

### 文字コード対応（.bas ファイルの保存）
- VBE（Visual Basic Editor）からエクスポートした `.bas` ファイルは **Shift-JIS** で保存される
- Git 管理する場合はリポジトリに **UTF-8版** と **Shift-JIS版（_Win.bas）** の両方を置く
- Windows での Import は必ず `_Win.bas`（Shift-JIS）を使う

---

## ■ リリース前チェックリスト

マクロの実装が完了したら、以下を必ず確認してから納品・コミットすること。

### 【A】コード品質チェック
- [ ] `Option Explicit` が全モジュールの先頭に書かれているか
- [ ] 変数が全て宣言されているか（未宣言の変数がないか）
- [ ] `On Error Resume Next` を使っている場合、直後に `On Error GoTo 0` で解除しているか
- [ ] `Application.ScreenUpdating = False` にしたら、必ず `True` に戻しているか
- [ ] `Application.DisplayAlerts = False` にしたら、必ず `True` に戻しているか

### 【B】コメント品質チェック
- [ ] モジュール先頭に「目的」「使い方」「注意点」のブロックコメントがあるか
- [ ] Public Sub / Public Function にはコメントが書かれているか
- [ ] 「なぜそうしているか」が読めばわかるコメントになっているか
- [ ] 定数・変数名の後ろに何を表す値か短いコメントがあるか

### 【C】動作確認チェック
- [ ] 正常データで動作することを確認したか
- [ ] 空のシートで実行してもエラーにならないか（または適切なメッセージを出すか）
- [ ] ヘッダーのみ（データ0件）で実行してもクラッシュしないか
- [ ] シートが保護されている状態で実行した場合の挙動を確認したか
- [ ] 大量データ（想定最大件数）で速度に問題がないか

### 【D】ユーザビリティチェック
- [ ] 処理完了時にユーザーへの通知メッセージがあるか
- [ ] エラー時に「何が問題か」が分かるメッセージを表示しているか
- [ ] 破壊的な操作（上書き・削除）の前に確認ダイアログがあるか
- [ ] ボタンやメニューに表示するマクロ名が日本語で分かりやすいか

### 【E】ファイル管理チェック
- [ ] `.bas` ファイルは Shift-JIS で書き出したか（Windows用: `_Win.bas`）
- [ ] UTF-8 版も合わせてリポジトリに置いているか
- [ ] マクロ名・モジュール名が英語の意味のある名前になっているか（`Macro1` などは NG）

---

## ■ よくあるバグパターンと対策

```vba
' ■ バグ① 最終行の取得ミス
' 悪い例：A列にデータがない場合に 1048576 行目を返す
lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row  ' ← これ自体は正しい
' 対策：ヘッダーのみの場合を別途チェックする
If lastRow < 2 Then
    MsgBox "データがありません。"
    Exit Sub
End If

' ■ バグ② 数値と文字列の混在
' セルの値は Variant で受け取り、用途に応じて変換する
Dim cellVal As Variant
cellVal = ws.Cells(i, 1).Value
If IsNumeric(cellVal) Then
    ' 数値として処理
    Dim numVal As Long
    numVal = CLng(cellVal)
End If

' ■ バグ③ JAN コードなど先頭ゼロが消える
' 数値として格納されていると先頭ゼロが消えるため Format で補完する
Dim janCode As String
If IsNumeric(ws.Cells(i, 1).Value) Then
    janCode = Format(ws.Cells(i, 1).Value, "0000000000000")  ' 13桁
Else
    janCode = CStr(ws.Cells(i, 1).Value)
End If

' ■ バグ④ シートが存在しない場合のクラッシュ
' シート取得前に存在確認を行う
Dim ws As Worksheet
On Error Resume Next
Set ws = ThisWorkbook.Worksheets("データ")
On Error GoTo 0
If ws Is Nothing Then
    MsgBox "「データ」シートが見つかりません。", vbCritical, "エラー"
    Exit Sub
End If
```

---

## ■ 作業の進め方（ワークフロー）

1. **要件の確認**
   - 何をするマクロか（目的）
   - 入力はどのシート・どの列か
   - 出力はどこに・どんな形式か
   - エラー時はどう振る舞うべきか

2. **設計（コメント先に書く）**
   - モジュール先頭コメントを先に書き、処理の流れを日本語でまとめる

3. **実装**
   - コーディング規約に従って実装する
   - 定数は先頭にまとめる

4. **リリース前チェックリスト実施**
   - 上記チェックリスト【A】〜【E】を全項目確認する

5. **ファイル書き出し**
   - UTF-8 版（`.bas`）と Shift-JIS 版（`_Win.bas`）の両方を書き出す
   - リポジトリにコミットする
