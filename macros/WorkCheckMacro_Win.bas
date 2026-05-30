'==============================================================
' モジュール名：WorkCheckMacro
' 目的：チェックシートで「作業打刻」「チェック打刻」ボタンを押すと、
'       そのボタンがある行に「担当者名」と「日時」を自動入力する。
'       手入力していた氏名・時刻をワンクリック化する。
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
' 氏名の決まり方（優先順位）：
'   1. 「Users」シートにアカウント名が登録されていれば → 表示名を使う
'   2. 登録がなければ → アカウント名を小文字にしてそのまま使う
'
' 使い方：
'   1. このファイルをインポートする（Windowsは WorkCheckMacro_Win.bas を使う）
'   2. SetupUsersSheet を一度実行 → 「Users」シートが作られる
'   3. 「Users」シートのA列にアカウント名、B列に表示名を登録する
'      （登録しなくてもアカウント名がそのまま入るので最初は空でもよい）
'   4. SetupSheet を実行 → 見出し付きの見本シートが整う
'   5. A列に項目名（作業内容）を入力する
'   6. SetupButtons を実行 → 各行に2つのボタンが自動で並ぶ
'   7. 各行の「作業打刻」ボタン    → 作業者(B)・作業日時(C)が入る
'      各行の「チェック打刻」ボタン → ダブルチェック者(D)・日時(E)が入る
'
' 注意：
'   ・シートが保護されていると動かない（保護を解除してから使う）
'   ・打刻済みのセルでも上書きされる（確認は出さないシンプル仕様）
'==============================================================
Option Explicit

' ■ 設定値（ここを変えるだけで列やシート名を調整できる）
Private Const SHEET_USERS      As String = "Users"          ' 氏名対応表シートの名前
Private Const COL_WORKER       As Long   = 2                ' 作業者の列（B列=2）
Private Const COL_WORKER_DATE  As Long   = 3                ' 作業日時の列（C列=3）
Private Const COL_CHECKER      As Long   = 4                ' ダブルチェック者の列（D列=4）
Private Const COL_CHECKER_DATE As Long   = 5                ' ダブルチェック日時の列（E列=5）
Private Const COL_WORKER_BTN   As Long   = 6                ' 作業打刻ボタンを置く列（F列=6）
Private Const COL_CHECKER_BTN  As Long   = 7                ' チェック打刻ボタンを置く列（G列=7）
Private Const HEADER_ROW       As Long   = 1                ' 見出し（ヘッダー）の行番号
Private Const DATE_FORMAT      As String = "yyyy/mm/dd hh:nn"  ' 日時の表示形式

'--------------------------------------------------------------
' 【処理名】作業打刻
' 【やること】押したボタンの行に、作業者(B)と作業日時(C)を入れる
' 【使い方】各行の「作業打刻」ボタンにこのマクロを割り当てる
'--------------------------------------------------------------
Public Sub StampWorker()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Dim targetRow As Long

    Set ws = ActiveSheet
    targetRow = GetTargetRow(ws)

    ' 見出し行に対しては打刻させない（押し間違い対策）
    If targetRow <= HEADER_ROW Then
        MsgBox "見出し行には打刻できません。作業行のボタンを押してください。", _
               vbExclamation, "打刻できません"
        Exit Sub
    End If

    ws.Cells(targetRow, COL_WORKER).Value = GetDisplayName()
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
'--------------------------------------------------------------
Public Sub StampChecker()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Dim targetRow As Long

    Set ws = ActiveSheet
    targetRow = GetTargetRow(ws)

    ' 見出し行に対しては打刻させない（押し間違い対策）
    If targetRow <= HEADER_ROW Then
        MsgBox "見出し行には打刻できません。作業行のボタンを押してください。", _
               vbExclamation, "打刻できません"
        Exit Sub
    End If

    ws.Cells(targetRow, COL_CHECKER).Value = GetDisplayName()
    ws.Cells(targetRow, COL_CHECKER_DATE).Value = Format(Now, DATE_FORMAT)

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description & vbCrLf & _
           "エラー番号: " & Err.Number, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】打刻する氏名を取得する（対応表ルックアップ）
' 【やること】Windowsアカウント名をキーに「Users」シートの対応表を検索し、
'             登録があれば表示名を、なければアカウント名（小文字）を返す
' 【戻り値】打刻する氏名
' 【注意】対応表の検索は大文字・小文字を区別しない
'         （アカウント名をどちらの表記で登録してもヒットする）
'--------------------------------------------------------------
Private Function GetDisplayName() As String
    Dim rawAccount As String
    Dim wsUsers As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim cellAccount As String

    ' Windowsアカウント名を小文字で取得する
    rawAccount = GetWindowsUser()

    ' 「Users」シートが存在しない場合はアカウント名をそのまま返す
    On Error Resume Next
    Set wsUsers = ThisWorkbook.Worksheets(SHEET_USERS)
    On Error GoTo 0

    If wsUsers Is Nothing Then
        GetDisplayName = rawAccount
        Exit Function
    End If

    ' 対応表の最終行を求める（A列が対応表のアカウント名列）
    lastRow = wsUsers.Cells(wsUsers.Rows.Count, 1).End(xlUp).Row

    ' 1行目はヘッダーなので2行目から検索する
    For i = 2 To lastRow
        cellAccount = LCase(Trim(CStr(wsUsers.Cells(i, 1).Value)))
        If cellAccount = rawAccount Then
            ' ヒットした行のB列（表示名）を返す
            GetDisplayName = Trim(CStr(wsUsers.Cells(i, 2).Value))
            Exit Function
        End If
    Next i

    ' 対応表に見つからなかった場合はアカウント名をそのまま返す
    GetDisplayName = rawAccount
End Function

'--------------------------------------------------------------
' 【処理名】Windowsアカウント名の取得
' 【やること】ログイン中のアカウント名を小文字に揃えて返す
' 【戻り値】アカウント名（小文字。例：mahito.matsumoto）
' 【注意】このままでは対応表の検索キーとして使われる。
'         打刻に使う氏名は GetDisplayName が決める。
'--------------------------------------------------------------
Private Function GetWindowsUser() As String
    Dim rawName As String

#If Mac Then
    rawName = Environ("USER")
#Else
    rawName = Environ("USERNAME")
#End If

    ' 前後空白を除いて小文字化（大文字混じりのアカウント名も一致させるため）
    GetWindowsUser = LCase(Trim(rawName))
End Function

'--------------------------------------------------------------
' 【処理名】自分の打刻名を確認する
' 【やること】このPCで打刻したときに入る氏名をダイアログで表示する
' 【使い方】導入時に各PCで実行し、正しい氏名になるか確認する
'--------------------------------------------------------------
Public Sub ShowMyUserName()
    Dim account As String
    Dim displayName As String

    account = GetWindowsUser()
    displayName = GetDisplayName()

    MsgBox "このPCで打刻される氏名は：" & vbCrLf & vbCrLf & _
           "  " & displayName & vbCrLf & vbCrLf & _
           "（Windowsアカウント名： " & account & "）" & vbCrLf & _
           IIf(displayName = account, _
               "※ Usersシートに未登録のため、アカウント名をそのまま使用", _
               "（Usersシートの対応表から取得）"), _
           vbInformation, "打刻名の確認"
End Sub

'--------------------------------------------------------------
' 【処理名】氏名対応表シートの作成
' 【やること】「Users」シートを新規作成し、見出しとサンプル行を入れる
' 【注意】同名シートが既にある場合は何もしない
'--------------------------------------------------------------
Public Sub SetupUsersSheet()
    On Error GoTo ErrorHandler

    Dim wsUsers As Worksheet

    ' 既に存在するか確認する
    On Error Resume Next
    Set wsUsers = ThisWorkbook.Worksheets(SHEET_USERS)
    On Error GoTo ErrorHandler

    If Not wsUsers Is Nothing Then
        MsgBox "「" & SHEET_USERS & "」シートは既に存在します。", _
               vbInformation, "スキップ"
        Exit Sub
    End If

    ' 末尾に新しいシートを作る
    Set wsUsers = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
    wsUsers.Name = SHEET_USERS

    ' 見出しを入れる
    wsUsers.Cells(1, 1).Value = "Windowsアカウント名"
    wsUsers.Cells(1, 2).Value = "表示名"

    ' 見出し行を装飾する
    With wsUsers.Range("A1:B1")
        .Font.Bold = True
        .Interior.Color = RGB(220, 230, 241)
    End With

    ' サンプル行を2行入れておく（実際の名前に書き換えて使う）
    wsUsers.Cells(2, 1).Value = "mahito.matsumoto"
    wsUsers.Cells(2, 2).Value = "m.matsumoto"
    wsUsers.Cells(3, 1).Value = "taro.tanaka"
    wsUsers.Cells(3, 2).Value = "t.tanaka"

    wsUsers.Columns("A").ColumnWidth = 26
    wsUsers.Columns("B").ColumnWidth = 18

    MsgBox "「" & SHEET_USERS & "」シートを作成しました。" & vbCrLf & vbCrLf & _
           "A列にWindowsアカウント名、B列に打刻したい表示名を" & vbCrLf & _
           "登録してください（サンプル行は書き換えてください）。" & vbCrLf & vbCrLf & _
           "登録しないアカウントはアカウント名がそのまま入ります。", _
           vbInformation, "完了"

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】見本シートの作成
' 【やること】チェックシートの見出しと列幅を整える
' 【注意】今アクティブなシートに見出しを書き込む
'--------------------------------------------------------------
Public Sub SetupSheet()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Set ws = ActiveSheet

    ws.Cells(HEADER_ROW, 1).Value = "項目名"
    ws.Cells(HEADER_ROW, COL_WORKER).Value = "作業者"
    ws.Cells(HEADER_ROW, COL_WORKER_DATE).Value = "作業日時"
    ws.Cells(HEADER_ROW, COL_CHECKER).Value = "ダブルチェック者"
    ws.Cells(HEADER_ROW, COL_CHECKER_DATE).Value = "ダブルチェック日時"
    ws.Cells(HEADER_ROW, COL_WORKER_BTN).Value = "作業打刻"
    ws.Cells(HEADER_ROW, COL_CHECKER_BTN).Value = "チェック打刻"

    With ws.Range(ws.Cells(HEADER_ROW, 1), ws.Cells(HEADER_ROW, COL_CHECKER_BTN))
        .Font.Bold = True
        .Interior.Color = RGB(220, 230, 241)
    End With

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
    RemoveButtons

    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    If lastRow <= HEADER_ROW Then
        MsgBox "A列に項目名がありません。先に項目名を入力してください。", _
               vbExclamation, "データなし"
        Exit Sub
    End If

    Application.ScreenUpdating = False

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
    Application.ScreenUpdating = True
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】打刻対象の行を求める
' 【やること】押されたボタンの位置から行番号を取得する
' 【引数】
'   ws ： 対象のシート
' 【戻り値】打刻する行番号
' 【注意】Application.Caller はボタンから呼ばれたときだけ文字列を返す。
'         VBEから直接実行したときは選択中のセルの行を使う（テスト用）。
'--------------------------------------------------------------
Private Function GetTargetRow(ws As Worksheet) As Long
    Dim caller As Variant
    caller = Application.Caller

    If VarType(caller) = vbString Then
        GetTargetRow = ws.Shapes(caller).TopLeftCell.Row
    Else
        GetTargetRow = ActiveCell.Row
    End If
End Function

'--------------------------------------------------------------
' 【処理名】ボタン1個を配置する
' 【引数】
'   ws        ： 対象シート
'   targetCell： ボタンを重ねるセル
'   macroName ： 押したときに動かすマクロ名
'   btnCaption： ボタンに表示する文字
'--------------------------------------------------------------
Private Sub AddButton(ws As Worksheet, targetCell As Range, macroName As String, btnCaption As String)
    Dim btn As Button
    Set btn = ws.Buttons.Add(targetCell.Left, targetCell.Top, targetCell.Width, targetCell.Height)
    btn.OnAction = macroName
    btn.Caption = btnCaption
    ' 後で消せるよう「btn_」で始まる名前を付ける
    btn.Name = "btn_" & macroName & "_" & targetCell.Row
End Sub

'--------------------------------------------------------------
' 【処理名】打刻ボタンの全削除
' 【やること】このマクロで作ったボタン（名前が btn_ で始まる）だけ消す
' 【注意】後ろから消すことでインデックスずれを防ぐ
'--------------------------------------------------------------
Public Sub RemoveButtons()
    Dim ws As Worksheet
    Dim i As Long
    Set ws = ActiveSheet

    For i = ws.Buttons.Count To 1 Step -1
        If Left(ws.Buttons(i).Name, 4) = "btn_" Then
            ws.Buttons(i).Delete
        End If
    Next i
End Sub
