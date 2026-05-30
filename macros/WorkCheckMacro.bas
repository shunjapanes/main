'==============================================================
' モジュール名：WorkCheckMacro
' 目的：チェックシートで「作業打刻」「チェック打刻」ボタンを押すと、
'       そのボタンがある行に「Windowsアカウント名」と「日時」を
'       自動入力する。手入力していた氏名・時刻をワンクリック化する。
'
' シート構成（列の意味）：
'   A列：項目名（作業内容）          … 手入力
'   B列：作業者                      … ボタンで自動入力
'   C列：作業日時                    … ボタンで自動入力
'   D列：ダブルチェック者            … ボタンで自動入力
'   E列：ダブルチェック日時          … ボタンで自動入力
'   F列：作業打刻ボタン
'   G列：チェック打刻ボタン
'
' 使い方：
'   1. このファイルをインポートする（Windowsは WorkCheckMacro_Win.bas を使う）
'   2. SetupSheet を一度実行 → 見出し付きの見本シートが整う
'   3. A列に項目名（作業内容）を入力する
'   4. SetupButtons を実行 → 各行に2つのボタンが自動で並ぶ
'   5. 各行の「作業打刻」ボタン   → 作業者(B)・作業日時(C)が入る
'      各行の「チェック打刻」ボタン → ダブルチェック者(D)・日時(E)が入る
'
' 注意：
'   ・氏名は Windows のログインアカウント名がそのまま入る（例：tanaka.taro）
'   ・シートが保護されていると動かない（保護を解除してから使う）
'   ・打刻済みのセルでも上書きされる（確認は出さないシンプル仕様）
'==============================================================
Option Explicit

' ■ 設定値（ここを変えるだけで列やシート名を調整できる）
Private Const COL_WORKER       As Long = 2   ' 作業者の列（B列=2）
Private Const COL_WORKER_DATE  As Long = 3   ' 作業日時の列（C列=3）
Private Const COL_CHECKER      As Long = 4   ' ダブルチェック者の列（D列=4）
Private Const COL_CHECKER_DATE As Long = 5   ' ダブルチェック日時の列（E列=5）
Private Const COL_WORKER_BTN   As Long = 6   ' 作業打刻ボタンを置く列（F列=6）
Private Const COL_CHECKER_BTN  As Long = 7   ' チェック打刻ボタンを置く列（G列=7）
Private Const HEADER_ROW       As Long = 1   ' 見出し（ヘッダー）の行番号
Private Const DATE_FORMAT      As String = "yyyy/mm/dd hh:nn"  ' 日時の表示形式

'--------------------------------------------------------------
' 【処理名】作業打刻
' 【やること】押したボタンの行に、作業者(B)と作業日時(C)を入れる
' 【使い方】各行の「作業打刻」ボタンにこのマクロを割り当てる
' 【注意】氏名は Windows のアカウント名がそのまま入る
'--------------------------------------------------------------
Public Sub StampWorker()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Dim targetRow As Long

    Set ws = ActiveSheet

    ' 押されたボタンが置かれている行を特定する（行ごとにボタンがある運用）
    targetRow = GetTargetRow(ws)

    ' 見出し行に対しては打刻させない（押し間違い対策）
    If targetRow <= HEADER_ROW Then
        MsgBox "見出し行には打刻できません。作業行のボタンを押してください。", _
               vbExclamation, "打刻できません"
        Exit Sub
    End If

    ' 作業者(B)＝Windowsアカウント名、作業日時(C)＝今この瞬間の日時
    ws.Cells(targetRow, COL_WORKER).Value = GetWindowsUser()
    ws.Cells(targetRow, COL_WORKER_DATE).Value = Format(Now, DATE_FORMAT)

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description & vbCrLf & _
           "エラー番号: " & Err.Number, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】チェック打刻
' 【やること】押したボタンの行に、ダブルチェック者(D)とチェック日時(E)を入れる
' 【使い方】各行の「チェック打刻」ボタンにこのマクロを割り当てる
' 【注意】作業者と同じ人でも打刻できる（制約なしのシンプル仕様）
'--------------------------------------------------------------
Public Sub StampChecker()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Dim targetRow As Long

    Set ws = ActiveSheet

    ' 押されたボタンが置かれている行を特定する
    targetRow = GetTargetRow(ws)

    ' 見出し行に対しては打刻させない（押し間違い対策）
    If targetRow <= HEADER_ROW Then
        MsgBox "見出し行には打刻できません。作業行のボタンを押してください。", _
               vbExclamation, "打刻できません"
        Exit Sub
    End If

    ' ダブルチェック者(D)＝Windowsアカウント名、チェック日時(E)＝今この瞬間の日時
    ws.Cells(targetRow, COL_CHECKER).Value = GetWindowsUser()
    ws.Cells(targetRow, COL_CHECKER_DATE).Value = Format(Now, DATE_FORMAT)

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description & vbCrLf & _
           "エラー番号: " & Err.Number, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】打刻対象の行を求める
' 【やること】押されたボタンの位置から行番号を取得する
' 【引数】
'   ws ： 対象のシート
' 【戻り値】打刻する行番号
' 【注意】Application.Caller はボタンから呼ばれたときだけ
'         ボタン名（文字列）を返す。VBEから直接実行したときは
'         選択中のセルの行を対象にする（テストしやすくするため）。
'--------------------------------------------------------------
Private Function GetTargetRow(ws As Worksheet) As Long
    Dim caller As Variant
    caller = Application.Caller

    If VarType(caller) = vbString Then
        ' ボタンから呼ばれた → そのボタンの左上セルがある行を対象にする
        GetTargetRow = ws.Shapes(caller).TopLeftCell.Row
    Else
        ' VBEなどから直接実行された → いま選択しているセルの行を対象にする
        GetTargetRow = ActiveCell.Row
    End If
End Function

'--------------------------------------------------------------
' 【処理名】Windowsアカウント名の取得
' 【やること】ログイン中のユーザー名を「m.matsumoto」形式で返す
' 【戻り値】アカウント名（小文字に揃える。例：m.matsumoto）
' 【注意】・#If Mac でMac環境にも一応対応しているが、本番はWindows想定
'         ・大文字混じり（M.Matsumoto / MATSUMOTO）でも小文字に統一して
'           表記ゆれを防ぐため LCase で揃えている
'--------------------------------------------------------------
Private Function GetWindowsUser() As String
    Dim rawName As String

#If Mac Then
    ' Mac環境（参考）：環境変数 USER から取得
    rawName = Environ("USER")
#Else
    ' Windows環境：環境変数 USERNAME から取得
    rawName = Environ("USERNAME")
#End If

    ' 前後の空白を除き、小文字に統一する（例：M.Matsumoto → m.matsumoto）
    GetWindowsUser = LCase(Trim(rawName))
End Function

'--------------------------------------------------------------
' 【処理名】見本シートの作成
' 【やること】チェックシートの見出しと列幅を整える
' 【注意】今アクティブなシートに見出しを書き込む
'--------------------------------------------------------------
Public Sub SetupSheet()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Set ws = ActiveSheet

    ' 見出しをセットする
    ws.Cells(HEADER_ROW, 1).Value = "項目名"
    ws.Cells(HEADER_ROW, COL_WORKER).Value = "作業者"
    ws.Cells(HEADER_ROW, COL_WORKER_DATE).Value = "作業日時"
    ws.Cells(HEADER_ROW, COL_CHECKER).Value = "ダブルチェック者"
    ws.Cells(HEADER_ROW, COL_CHECKER_DATE).Value = "ダブルチェック日時"
    ws.Cells(HEADER_ROW, COL_WORKER_BTN).Value = "作業打刻"
    ws.Cells(HEADER_ROW, COL_CHECKER_BTN).Value = "チェック打刻"

    ' 見出し行を見やすく装飾する（太字＋薄い青）
    With ws.Range(ws.Cells(HEADER_ROW, 1), ws.Cells(HEADER_ROW, COL_CHECKER_BTN))
        .Font.Bold = True
        .Interior.Color = RGB(220, 230, 241)
    End With

    ' 列幅をざっくり整える（見やすさ優先）
    ws.Columns("A").ColumnWidth = 28
    ws.Columns("B").ColumnWidth = 16
    ws.Columns("C").ColumnWidth = 18
    ws.Columns("D").ColumnWidth = 18
    ws.Columns("E").ColumnWidth = 18
    ws.Columns("F").ColumnWidth = 12
    ws.Columns("G").ColumnWidth = 12

    MsgBox "チェックシートの見出しを作成しました。" & vbCrLf & _
           "A列に項目名を入力してから SetupButtons を実行してください。", _
           vbInformation, "完了"

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】各行へのボタン自動配置
' 【やること】A列に項目名が入っている各行に
'             「作業打刻」「チェック打刻」ボタンを並べる
' 【注意】何度実行しても重複しないよう、先に既存の打刻ボタンを消す
'--------------------------------------------------------------
Public Sub SetupButtons()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Dim lastRow As Long
    Dim r As Long

    Set ws = ActiveSheet

    ' まず既存の打刻ボタンを消す（二重配置を防ぐ）
    RemoveButtons

    ' A列の最終行（項目名が入っている一番下の行）を求める
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    ' 項目名が見出ししかない（データ0件）の場合は中止する
    If lastRow <= HEADER_ROW Then
        MsgBox "A列に項目名がありません。先に項目名を入力してください。", _
               vbExclamation, "データなし"
        Exit Sub
    End If

    ' ボタンを大量に作るので画面更新を止めて高速化する
    Application.ScreenUpdating = False

    ' 各データ行に2つのボタンを配置する
    For r = HEADER_ROW + 1 To lastRow
        AddButton ws, ws.Cells(r, COL_WORKER_BTN), "StampWorker", "作業打刻"
        AddButton ws, ws.Cells(r, COL_CHECKER_BTN), "StampChecker", "チェック打刻"
    Next r

    Application.ScreenUpdating = True

    MsgBox (lastRow - HEADER_ROW) & " 行分のボタンを配置しました。", _
           vbInformation, "完了"

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    ' エラーで止まっても画面更新は必ず元に戻す
    Application.ScreenUpdating = True
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】ボタン1個を配置する
' 【やること】指定セルの位置・大きさに合わせてボタンを作る
' 【引数】
'   ws        ： 対象シート
'   targetCell： ボタンを重ねるセル
'   macroName ： 押したときに動かすマクロ名
'   btnCaption： ボタンに表示する文字
'--------------------------------------------------------------
Private Sub AddButton(ws As Worksheet, targetCell As Range, macroName As String, btnCaption As String)
    Dim btn As Button

    ' セルの位置と大きさにぴったり重ねてボタンを作る
    Set btn = ws.Buttons.Add(targetCell.Left, targetCell.Top, targetCell.Width, targetCell.Height)
    btn.OnAction = macroName        ' 押したときに動くマクロ
    btn.Caption = btnCaption        ' ボタンに表示する文字
    ' 後で消せるよう「btn_」で始まる分かりやすい名前を付ける
    btn.Name = "btn_" & macroName & "_" & targetCell.Row
End Sub

'--------------------------------------------------------------
' 【処理名】打刻ボタンの全削除
' 【やること】このマクロで作ったボタン（名前が btn_ で始まる）だけ消す
' 【注意】他のボタンや図形は消さない（名前で判別している）
'         コレクションを後ろから消すことで消し飛ばしを防ぐ
'--------------------------------------------------------------
Public Sub RemoveButtons()
    Dim ws As Worksheet
    Dim i As Long

    Set ws = ActiveSheet

    ' 後ろの番号から順に消す（前から消すと番号がずれて消し漏れる）
    For i = ws.Buttons.Count To 1 Step -1
        If Left(ws.Buttons(i).Name, 4) = "btn_" Then
            ws.Buttons(i).Delete
        End If
    Next i
End Sub
