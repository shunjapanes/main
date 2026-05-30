'==============================================================
' モジュール名：CheckListMacro
' 目的：検証・本番作業チェックリストで、打刻したいセルを選択して
'       「打刻」ボタンを押すと担当者名と日時を自動入力する。
'       特別なExcel設定変更が不要で、複数ユーザーがそのまま使える。
'
' シート構成（2行ヘッダー、データは3行目から）：
'   A列：カテゴリ
'   B列：項目
'   C列：検証 作業者   ← 選択して打刻ボタン → D列に日時が入る
'   D列：検証 作業日   ← 自動入力
'   E列：検証 確認者   ← 選択して打刻ボタン → F列に日時が入る
'   F列：検証 確認日   ← 自動入力
'   G列：本番 作業者   ← 選択して打刻ボタン → H列に日時が入る
'   H列：本番 作業日   ← 自動入力
'   I列：本番 確認者   ← 選択して打刻ボタン → J列に日時が入る
'   J列：本番 確認日   ← 自動入力
'   K列：課長承認      ← 選択して打刻ボタン → L列に日時が入る
'   L列：承認日        ← 自動入力
'   M列：打刻ボタン    ← SetupSheet で自動配置される
'
' 氏名の決まり方：
'   「Users」シートの対応表にヒット → 表示名（例: m.matsumoto）
'   未登録の場合 → Windowsアカウント名を小文字にしてそのまま使う
'
' 導入手順（初回のみ・管理者が1回実行するだけ）：
'   1. このファイルをインポート（Windowsは CheckListMacro_Win.bas を使う）
'   2. SetupUsersSheet を実行 → 「Users」シートを作り対応表を登録する
'   3. チェックシートをアクティブにして SetupSheet を実行
'      → 見出し・色分け・列幅・打刻ボタンがすべて整う
'   ※ 複数シートで使う場合：3をシートごとに実行するだけ
'   ※ 利用ユーザー側は何も設定変更不要
'
' 日常の使い方：
'   1. 打刻したい「作業者」「確認者」「課長承認」のセルを1クリックで選ぶ
'   2. M列の「打刻」ボタンを押す → 氏名と日時が入る
'
' 注意：
'   ・シートが保護されていると動かない（保護を解除してから使う）
'   ・打刻済みのセルでも上書きされる（確認は出さないシンプル仕様）
'==============================================================
Option Explicit

' ■ 設定値（ここを変えるだけで動作を調整できる）
Private Const SHEET_USERS    As String = "Users"            ' 氏名対応表シートの名前
Private Const DATA_START_ROW As Long   = 3                  ' データ開始行（ヘッダー2行）
Private Const DATE_FORMAT    As String = "yyyy/mm/dd hh:nn" ' 日時の表示形式
Private Const COL_STAMP_BTN  As Long   = 13                 ' M列: 打刻ボタンを置く列

' 打刻対象の列（これらのセルを選択して打刻ボタンを押す）
Private Const COL_KENSHO_WORKER   As Long = 3   ' C列: 検証 作業者
Private Const COL_KENSHO_WDATE    As Long = 4   ' D列: 検証 作業日
Private Const COL_KENSHO_CHECKER  As Long = 5   ' E列: 検証 確認者
Private Const COL_KENSHO_CDATE    As Long = 6   ' F列: 検証 確認日
Private Const COL_HONBAN_WORKER   As Long = 7   ' G列: 本番 作業者
Private Const COL_HONBAN_WDATE    As Long = 8   ' H列: 本番 作業日
Private Const COL_HONBAN_CHECKER  As Long = 9   ' I列: 本番 確認者
Private Const COL_HONBAN_CDATE    As Long = 10  ' J列: 本番 確認日
Private Const COL_APPROVAL        As Long = 11  ' K列: 課長承認
Private Const COL_APPROVAL_DATE   As Long = 12  ' L列: 承認日

'--------------------------------------------------------------
' 【処理名】打刻ボタンから呼ばれるメイン処理
' 【やること】今選択中のセルが打刻対象の列なら氏名と日時を入れる
' 【使い方】M列の「打刻」ボタンにこのマクロを割り当てる（SetupSheetで自動設定）
' 【注意】C/E/G/I/K列以外を選んでいる場合はガイドメッセージを表示する
'--------------------------------------------------------------
Public Sub StampSelectedCell()
    ' ボタンを押したとき選択中のセルが打刻対象かチェックする
    If TypeName(Selection) <> "Range" Then Exit Sub

    Dim target As Range
    Set target = Selection.Cells(1)   ' 複数選択でも左上の1セルだけを対象にする

    If StampCell(target) Then
        ' 打刻成功 → 何も出さずに静かに完了（視覚的に確認できるため）
    Else
        ' 打刻対象外の列を選んでいた場合
        MsgBox "打刻できる列を選択してください。" & vbCrLf & vbCrLf & _
               "  検証  : C列（作業者）または E列（確認者）" & vbCrLf & _
               "  本番  : G列（作業者）または I列（確認者）" & vbCrLf & _
               "  承認  : K列（課長承認）" & vbCrLf & vbCrLf & _
               "セルを選んでからもう一度ボタンを押してください。", _
               vbExclamation, "列を選んでください"
    End If
End Sub

'--------------------------------------------------------------
' 【処理名】セルへの打刻（内部処理）
' 【やること】指定セルが打刻対象の列なら氏名と日時を入れる
' 【引数】
'   target ： 打刻するセル
' 【戻り値】
'   True  = 打刻した
'   False = 打刻対象外の列だった
'--------------------------------------------------------------
Private Function StampCell(target As Range) As Boolean
    StampCell = False

    Dim r As Long
    Dim c As Long
    r = target.Row
    c = target.Column

    ' ヘッダー行（1から2行目）への打刻は無視する
    If r < DATA_START_ROW Then Exit Function

    ' 選択列が打刻対象か判定し、対応する日付列を決める
    Dim dateCol As Long
    dateCol = 0
    Select Case c
        Case COL_KENSHO_WORKER:   dateCol = COL_KENSHO_WDATE
        Case COL_KENSHO_CHECKER:  dateCol = COL_KENSHO_CDATE
        Case COL_HONBAN_WORKER:   dateCol = COL_HONBAN_WDATE
        Case COL_HONBAN_CHECKER:  dateCol = COL_HONBAN_CDATE
        Case COL_APPROVAL:        dateCol = COL_APPROVAL_DATE
    End Select

    If dateCol = 0 Then Exit Function   ' 打刻対象外

    ' 氏名と日時を入れる
    target.Value = GetDisplayName()
    target.Worksheet.Cells(r, dateCol).Value = Format(Now, DATE_FORMAT)

    StampCell = True
End Function

'--------------------------------------------------------------
' 【処理名】打刻する氏名を取得する（対応表ルックアップ）
' 【やること】Windowsアカウント名をキーに「Users」シートを検索し、
'             登録があれば表示名を、なければアカウント名（小文字）を返す
' 【注意】検索は大文字・小文字を区別しない
'--------------------------------------------------------------
Public Function GetDisplayName() As String
    Dim rawAccount As String
    Dim wsUsers As Worksheet
    Dim lastRow As Long
    Dim i As Long

    rawAccount = GetWindowsUser()

    ' Usersシートが存在しない場合はアカウント名をそのまま返す
    On Error Resume Next
    Set wsUsers = ThisWorkbook.Worksheets(SHEET_USERS)
    On Error GoTo 0

    If wsUsers Is Nothing Then
        GetDisplayName = rawAccount
        Exit Function
    End If

    lastRow = wsUsers.Cells(wsUsers.Rows.Count, 1).End(xlUp).Row

    ' 2行目から検索（1行目はヘッダー）
    For i = 2 To lastRow
        If LCase(Trim(CStr(wsUsers.Cells(i, 1).Value))) = rawAccount Then
            GetDisplayName = Trim(CStr(wsUsers.Cells(i, 2).Value))
            Exit Function
        End If
    Next i

    ' 対応表に見つからなければアカウント名をそのまま返す
    GetDisplayName = rawAccount
End Function

'--------------------------------------------------------------
' 【処理名】Windowsアカウント名の取得
' 【戻り値】アカウント名（小文字・前後空白なし。例：mahito.matsumoto）
'--------------------------------------------------------------
Private Function GetWindowsUser() As String
    Dim rawName As String
#If Mac Then
    rawName = Environ("USER")
#Else
    rawName = Environ("USERNAME")
#End If
    ' 前後空白を除き小文字化（大文字混じりアカウントも対応表とマッチさせるため）
    GetWindowsUser = LCase(Trim(rawName))
End Function

'--------------------------------------------------------------
' 【処理名】自分の打刻名を確認する
' 【やること】このPCで打刻したときに入る氏名をダイアログで表示する
' 【使い方】導入時に各PCで一度実行して確認する
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
               "※ Usersシートに未登録のためアカウント名をそのまま使用", _
               "（Usersシートの対応表から取得）"), _
           vbInformation, "打刻名の確認"
End Sub

'--------------------------------------------------------------
' 【処理名】チェックシートの見出し・ボタン作成
' 【やること】2行ヘッダーの作成・セル結合・エリア別色分け・列幅整形・
'             打刻ボタン配置をまとめて行う
' 【注意】今アクティブなシートに書き込む。何度実行しても安全（冪等）。
'--------------------------------------------------------------
Public Sub SetupSheet()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Set ws = ActiveSheet

    Application.ScreenUpdating = False

    ' --- 1行目の見出し ---
    ws.Range("A1").Value = "カテゴリ"
    ws.Range("B1").Value = "項目"
    ws.Range("C1").Value = "検証設定"
    ws.Range("G1").Value = "本番設定"
    ws.Range("K1").Value = "課長承認"
    ws.Range("L1").Value = "承認日"

    ' 検証設定・本番設定をそれぞれ4列分横に結合する
    ws.Range("C1:F1").Merge
    ws.Range("G1:J1").Merge

    ' カテゴリ・項目・課長承認・承認日は2行にまたがるので縦結合する
    ws.Range("A1:A2").Merge
    ws.Range("B1:B2").Merge
    ws.Range("K1:K2").Merge
    ws.Range("L1:L2").Merge

    ' --- 2行目の見出し ---
    ws.Cells(2, COL_KENSHO_WORKER).Value  = "作業者"
    ws.Cells(2, COL_KENSHO_WDATE).Value   = "作業日"
    ws.Cells(2, COL_KENSHO_CHECKER).Value = "確認者"
    ws.Cells(2, COL_KENSHO_CDATE).Value   = "確認日"
    ws.Cells(2, COL_HONBAN_WORKER).Value  = "作業者"
    ws.Cells(2, COL_HONBAN_WDATE).Value   = "作業日"
    ws.Cells(2, COL_HONBAN_CHECKER).Value = "確認者"
    ws.Cells(2, COL_HONBAN_CDATE).Value   = "確認日"

    ' --- 見出し共通装飾 ---
    With ws.Range("A1:L2")
        .Font.Bold = True
        .HorizontalAlignment = xlCenter
        .VerticalAlignment = xlCenter
        .WrapText = True
    End With

    ' --- エリア別色分け（役割が一目でわかるように）---
    ws.Range("A1:B2").Interior.Color = RGB(242, 242, 242)   ' グレー（カテゴリ・項目）
    ws.Range("C1:F2").Interior.Color = RGB(226, 239, 218)   ' 薄い緑（検証設定）
    ws.Range("G1:J2").Interior.Color = RGB(252, 228, 214)   ' 薄いオレンジ（本番設定）
    ws.Range("K1:L2").Interior.Color = RGB(255, 242, 204)   ' 薄い黄（課長承認）

    ' --- 列幅・行高さ ---
    ws.Columns("A").ColumnWidth = 10
    ws.Columns("B").ColumnWidth = 22
    ws.Columns("C").ColumnWidth = 12
    ws.Columns("D").ColumnWidth = 16
    ws.Columns("E").ColumnWidth = 12
    ws.Columns("F").ColumnWidth = 16
    ws.Columns("G").ColumnWidth = 12
    ws.Columns("H").ColumnWidth = 16
    ws.Columns("I").ColumnWidth = 12
    ws.Columns("J").ColumnWidth = 16
    ws.Columns("K").ColumnWidth = 12
    ws.Columns("L").ColumnWidth = 16
    ws.Columns("M").ColumnWidth = 10
    ws.Rows("1:2").RowHeight = 28

    ' --- 打刻ボタンをM1:M2の位置に配置する ---
    ' 既存の打刻ボタンがあれば先に削除して重複を防ぐ
    Dim i As Long
    For i = ws.Buttons.Count To 1 Step -1
        If ws.Buttons(i).Name = "btn_stamp" Then ws.Buttons(i).Delete
    Next i

    ' M列1行目から2行目にまたがる位置にボタンを作る
    Dim btnLeft As Double
    Dim btnTop As Double
    Dim btnWidth As Double
    Dim btnHeight As Double
    btnLeft   = ws.Cells(1, COL_STAMP_BTN).Left
    btnTop    = ws.Cells(1, COL_STAMP_BTN).Top
    btnWidth  = ws.Cells(1, COL_STAMP_BTN).Width
    btnHeight = ws.Cells(1, COL_STAMP_BTN).Top + ws.Cells(2, COL_STAMP_BTN).Height - btnTop

    Dim btn As Button
    Set btn = ws.Buttons.Add(btnLeft, btnTop, btnWidth, btnHeight)
    btn.OnAction  = "StampSelectedCell"   ' 押したときに動くマクロ
    btn.Caption   = "打刻"
    btn.Name      = "btn_stamp"
    btn.Font.Size = 12
    btn.Font.Bold = True

    Application.ScreenUpdating = True

    MsgBox "チェックシートを設定しました。" & vbCrLf & vbCrLf & _
           "【使い方】" & vbCrLf & _
           "  1. 打刻したいセル（作業者・確認者・課長承認）を選ぶ" & vbCrLf & _
           "  2. M列の「打刻」ボタンを押す", _
           vbInformation, "完了"

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    Application.ScreenUpdating = True
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description, vbCritical, "エラー"
End Sub

'--------------------------------------------------------------
' 【処理名】氏名対応表シートの作成
' 【やること】「Users」シートを新規作成し、見出しとサンプル行を入れる
' 【注意】同名シートが既にある場合はスキップする
'--------------------------------------------------------------
Public Sub SetupUsersSheet()
    On Error GoTo ErrorHandler

    Dim wsUsers As Worksheet

    On Error Resume Next
    Set wsUsers = ThisWorkbook.Worksheets(SHEET_USERS)
    On Error GoTo ErrorHandler

    If Not wsUsers Is Nothing Then
        MsgBox "「" & SHEET_USERS & "」シートは既に存在します。", vbInformation, "スキップ"
        Exit Sub
    End If

    Set wsUsers = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
    wsUsers.Name = SHEET_USERS

    wsUsers.Cells(1, 1).Value = "Windowsアカウント名"
    wsUsers.Cells(1, 2).Value = "表示名"
    With wsUsers.Range("A1:B1")
        .Font.Bold = True
        .Interior.Color = RGB(220, 230, 241)
    End With

    ' サンプル行（実際の名前に書き換えて使う）
    wsUsers.Cells(2, 1).Value = "mahito.matsumoto"
    wsUsers.Cells(2, 2).Value = "m.matsumoto"
    wsUsers.Cells(3, 1).Value = "taro.tanaka"
    wsUsers.Cells(3, 2).Value = "t.tanaka"

    wsUsers.Columns("A").ColumnWidth = 26
    wsUsers.Columns("B").ColumnWidth = 18

    MsgBox "「" & SHEET_USERS & "」シートを作成しました。" & vbCrLf & vbCrLf & _
           "A列にWindowsアカウント名、B列に打刻したい表示名を登録してください。" & vbCrLf & _
           "（サンプル行は書き換えてください）" & vbCrLf & vbCrLf & _
           "登録しないアカウントはアカウント名がそのまま入ります。", _
           vbInformation, "完了"

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
           "エラー内容: " & Err.Description, vbCritical, "エラー"
End Sub
