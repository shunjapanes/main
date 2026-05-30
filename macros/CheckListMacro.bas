'==============================================================
' モジュール名：CheckListMacro
' 目的：検証・本番作業チェックリストで、氏名セルをダブルクリックすると
'       担当者名と日時を自動入力する。手入力を廃止してワンアクション化する。
'
' シート構成（2行ヘッダー、データは3行目から）：
'   A列：カテゴリ
'   B列：項目
'   C列：検証 作業者   ← ダブルクリックで氏名・D列に日時が入る
'   D列：検証 作業日   ← 自動入力
'   E列：検証 確認者   ← ダブルクリックで氏名・F列に日時が入る
'   F列：検証 確認日   ← 自動入力
'   G列：本番 作業者   ← ダブルクリックで氏名・H列に日時が入る
'   H列：本番 作業日   ← 自動入力
'   I列：本番 確認者   ← ダブルクリックで氏名・J列に日時が入る
'   J列：本番 確認日   ← 自動入力
'   K列：課長承認      ← ダブルクリックで氏名・L列に日時が入る
'   L列：承認日        ← 自動入力
'
' 氏名の決まり方：
'   「Users」シートの対応表にヒット → 表示名（例: m.matsumoto）
'   未登録の場合 → Windowsアカウント名を小文字にしてそのまま使う
'
' 導入手順：
'   【初回・管理者が1回だけ実施】
'   1. setup\enable_vba_access.reg をダブルクリックして実行する
'      → Excelのセキュリティ設定が自動で変わる
'   2. Excelを再起動する
'   3. CheckListMacro_Win.bas をインポートする
'   4. SetupUsersSheet を実行 → Usersシートを作り対応表を登録する
'   5. チェックシートをアクティブにして SetupSheet を実行 → 見出しが整う
'   6. SetupSheetEvents を実行 → ダブルクリック打刻が有効になる
'
'   【複数シートで使う場合】
'   5と6をシートごとに実行するだけ
'
'   【利用ユーザー（毎日使う人）は手順1のみ】
'   setup\enable_vba_access.reg を1回実行 → あとはダブルクリックするだけ
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

' 打刻対象の列（これらのセルをダブルクリックすると隣の日付列に日時が入る）
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
' 【処理名】ダブルクリック打刻（シートのイベントから呼ばれる）
' 【やること】ダブルクリックされたセルが打刻対象の列なら氏名と日時を入れる。
'             Usersシートに未登録の場合は登録方法を案内してから確認を取る。
' 【引数】
'   Target ： ダブルクリックされたセル
' 【戻り値】
'   True  = 打刻した（Excelのデフォルト動作＝編集モード移行をキャンセルする）
'   False = 打刻しなかった（デフォルトのままにする）
' 【注意】SetupSheetEvents でシートモジュールに自動登録されるイベントから呼ばれる
'--------------------------------------------------------------
Public Function StampOnDoubleClick(Target As Range) As Boolean
    StampOnDoubleClick = False

    ' 複数セル選択の場合は何もしない
    If Target.Cells.Count > 1 Then Exit Function

    Dim r As Long
    Dim c As Long
    r = Target.Row
    c = Target.Column

    ' ヘッダー行（1から2行目）への打刻は無視する
    If r < DATA_START_ROW Then Exit Function

    ' 打刻対象の列か判定し、対応する日付列番号を決める
    Dim dateCol As Long
    dateCol = 0
    Select Case c
        Case COL_KENSHO_WORKER:   dateCol = COL_KENSHO_WDATE
        Case COL_KENSHO_CHECKER:  dateCol = COL_KENSHO_CDATE
        Case COL_HONBAN_WORKER:   dateCol = COL_HONBAN_WDATE
        Case COL_HONBAN_CHECKER:  dateCol = COL_HONBAN_CDATE
        Case COL_APPROVAL:        dateCol = COL_APPROVAL_DATE
    End Select

    ' 打刻対象列でなければ通常の編集モードに任せる
    If dateCol = 0 Then Exit Function

    ' Usersシートに登録があるか確認し、未登録なら案内ダイアログを出す
    Dim isRegistered As Boolean
    Dim displayName As String
    displayName = GetDisplayName(isRegistered)

    If Not isRegistered Then
        Dim account As String
        account = GetWindowsUser()
        Dim answer As VbMsgBoxResult
        answer = MsgBox( _
            "あなたのアカウント（" & account & "）は Users シートに未登録です。" & vbCrLf & vbCrLf & _
            "【登録方法】" & vbCrLf & _
            "1. 画面下の「Users」シートタブをクリックする" & vbCrLf & _
            "2. A列に自分のアカウント名を入力（例: " & account & "）" & vbCrLf & _
            "3. B列に打刻に使う表示名を入力（例: m.matsumoto）" & vbCrLf & _
            "4. このシートに戻ってもう一度ダブルクリックする" & vbCrLf & vbCrLf & _
            "今すぐ登録せず「" & account & "」のまま打刻しますか？", _
            vbYesNo + vbExclamation, "Usersシートへの登録をお勧めします")

        ' 「いいえ」= 登録しに行く → 打刻せずキャンセル
        If answer = vbNo Then
            StampOnDoubleClick = True   ' 編集モードは抑止しつつ打刻はしない
            Exit Function
        End If
    End If

    ' 氏名と日時を入れる
    Target.Value = displayName
    Target.Worksheet.Cells(r, dateCol).Value = Format(Now, DATE_FORMAT)

    StampOnDoubleClick = True   ' 編集モードへの移行をキャンセルさせる
End Function

'--------------------------------------------------------------
' 【処理名】打刻する氏名を取得する（対応表ルックアップ）
' 【やること】Windowsアカウント名をキーに「Users」シートを検索し、
'             登録があれば表示名を、なければアカウント名（小文字）を返す
' 【引数】
'   isRegistered ： 戻り値。Trueなら対応表にヒット、Falseなら未登録
' 【注意】検索は大文字・小文字を区別しない
'--------------------------------------------------------------
Public Function GetDisplayName(Optional ByRef isRegistered As Boolean = True) As String
    Dim rawAccount As String
    Dim wsUsers As Worksheet
    Dim lastRow As Long
    Dim i As Long

    rawAccount = GetWindowsUser()
    isRegistered = False   ' 最初は未登録扱いにしておく

    On Error Resume Next
    Set wsUsers = ThisWorkbook.Worksheets(SHEET_USERS)
    On Error GoTo 0

    If wsUsers Is Nothing Then
        ' Usersシート自体がない場合はアカウント名をそのまま返す（登録不要とみなす）
        isRegistered = True
        GetDisplayName = rawAccount
        Exit Function
    End If

    lastRow = wsUsers.Cells(wsUsers.Rows.Count, 1).End(xlUp).Row

    ' 2行目から検索（1行目はヘッダー）
    For i = 2 To lastRow
        If LCase(Trim(CStr(wsUsers.Cells(i, 1).Value))) = rawAccount Then
            isRegistered = True
            GetDisplayName = Trim(CStr(wsUsers.Cells(i, 2).Value))
            Exit Function
        End If
    Next i

    ' 対応表に見つからなければアカウント名をそのまま返す（isRegistered=False のまま）
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
' 【処理名】シートへのダブルクリックイベント設定
' 【やること】アクティブシートのモジュールに Worksheet_BeforeDoubleClick を
'             自動で書き込み、ダブルクリック打刻を有効にする
' 【注意】事前に setup\enable_vba_access.reg を実行してExcelを再起動しておく必要がある
'--------------------------------------------------------------
Public Sub SetupSheetEvents()
    On Error GoTo ErrorHandler

    Dim ws As Worksheet
    Dim vbComp As Object
    Dim cm As Object
    Dim i As Long

    Set ws = ActiveSheet

    ' シートのVBAモジュールを取得する
    Set vbComp = ThisWorkbook.VBProject.VBComponents(ws.CodeName)
    Set cm = vbComp.CodeModule

    ' 既に設定済みか確認する（二重登録を防ぐ）
    For i = 1 To cm.CountOfLines
        If InStr(cm.Lines(i, 1), "StampOnDoubleClick") > 0 Then
            MsgBox "「" & ws.Name & "」シートには既にダブルクリック打刻が設定されています。", _
                   vbInformation, "スキップ"
            Exit Sub
        End If
    Next i

    ' BeforeDoubleClick イベントを書き込む（処理本体はStandardモジュールに委譲）
    cm.AddFromString _
        "Private Sub Worksheet_BeforeDoubleClick(ByVal Target As Range, Cancel As Boolean)" & vbCrLf & _
        "    If StampOnDoubleClick(Target) Then Cancel = True" & vbCrLf & _
        "End Sub"

    MsgBox "「" & ws.Name & "」シートのダブルクリック打刻を設定しました。" & vbCrLf & vbCrLf & _
           "C/E/G/I/K列のセルをダブルクリックすると氏名と日時が入ります。", _
           vbInformation, "完了"

    On Error GoTo 0
    Exit Sub

ErrorHandler:
    ' VBAプロジェクトへのアクセスが許可されていない場合の案内
    If Err.Number = 1004 Or Err.Number = 50289 Then
        MsgBox "事前設定が必要です。" & vbCrLf & vbCrLf & _
               "setup フォルダの「enable_vba_access.reg」を" & vbCrLf & _
               "ダブルクリックして実行し、Excelを再起動してから" & vbCrLf & _
               "もう一度 SetupSheetEvents を実行してください。", _
               vbExclamation, "事前設定が必要です"
    Else
        MsgBox "予期しないエラーが発生しました。" & vbCrLf & vbCrLf & _
               "エラー内容: " & Err.Description & vbCrLf & _
               "エラー番号: " & Err.Number, vbCritical, "エラー"
    End If
End Sub

'--------------------------------------------------------------
' 【処理名】チェックシートの見出し作成
' 【やること】2行ヘッダーの作成・セル結合・エリア別色分け・列幅整形を行う
' 【注意】今アクティブなシートに書き込む
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

    ' 検証設定・本番設定を4列分横に結合する
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

    ' --- エリア別色分け ---
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
    ws.Rows("1:2").RowHeight = 28

    Application.ScreenUpdating = True

    MsgBox "チェックシートの見出しを作成しました。" & vbCrLf & vbCrLf & _
           "次に SetupSheetEvents を実行してダブルクリック打刻を有効にしてください。", _
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

    wsUsers.Cells(1, 1).Value = "Windows"
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
