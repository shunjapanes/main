Attribute VB_Name = "CheckMacro"
'==============================================================
' CheckMacro (Windows / macOS 両対応版)
' チェックシート用：ボタンを押した行に担当者名と日時を記入する
'
' 動作環境：
'   - Windows 版 Excel 2016 以降
'   - macOS 版 Excel (Microsoft 365) 16.x 以降
'
' 行継続文字 (_) を一切使わない構成にしています。
' Excel for Mac の VBA エディタが行継続でコンパイルエラーを出す環境向け。
'
' メンテナンス：
'   - 担当者追加：Users シートに1行追加（A=ユーザー名、B=表示名）
'   - 列名や行番号変更：_設定 シートを編集
'==============================================================
Option Explicit

Private Const SETTINGS_SHEET As String = "_設定"
Private Const USERS_SHEET As String = "Users"
Private Const DEFAULT_DATE_FORMAT As String = "yyyy/mm/dd hh:mm"

Private g_cachedDisplayName As String
Private g_cachedUserKey As String

Public Sub StampCheck()
    Dim btn As Shape
    Dim ws As Worksheet
    Dim targetRow As Long
    Dim headerRow As Long
    Dim userColHeader As String
    Dim dateColHeader As String
    Dim dateFormat As String
    Dim userCol As Long
    Dim dateCol As Long
    Dim displayName As String
    Dim existingUser As String
    Dim existingDate As Variant
    Dim existingDateText As String
    Dim msg As String

    Set btn = GetCallerButton()
    If btn Is Nothing Then
        MsgBox "このマクロはシート上のボタンから実行してください。", vbInformation, "操作のお願い"
        Exit Sub
    End If

    Set ws = btn.Parent
    targetRow = GetButtonRow(btn)

    headerRow = GetSettingAsLong("ヘッダー行", 1)
    userColHeader = GetSettingAsString("担当者ヘッダー", "担当者")
    dateColHeader = GetSettingAsString("日時ヘッダー", "日時")
    dateFormat = GetSettingAsString("日時フォーマット", DEFAULT_DATE_FORMAT)

    userCol = FindColumn(ws, btn, headerRow, userColHeader)
    dateCol = FindColumn(ws, btn, headerRow, dateColHeader)

    If userCol = 0 Then
        msg = "ヘッダー「" & userColHeader & "」が見つかりません。" & vbCrLf & vbCrLf
        msg = msg & "対処方法：" & vbCrLf
        msg = msg & "  ・" & headerRow & " 行目に「" & userColHeader & "」という見出しを追加" & vbCrLf
        msg = msg & "  ・または _設定 シートの「担当者ヘッダー」を実際の見出し名に合わせる"
        MsgBox msg, vbExclamation, "設定エラー"
        Exit Sub
    End If
    If dateCol = 0 Then
        msg = "ヘッダー「" & dateColHeader & "」が見つかりません。" & vbCrLf & vbCrLf
        msg = msg & "対処方法：" & vbCrLf
        msg = msg & "  ・" & headerRow & " 行目に「" & dateColHeader & "」という見出しを追加" & vbCrLf
        msg = msg & "  ・または _設定 シートの「日時ヘッダー」を実際の見出し名に合わせる"
        MsgBox msg, vbExclamation, "設定エラー"
        Exit Sub
    End If

    If targetRow <= headerRow Then
        msg = "ボタンがヘッダー行以下に配置されています。" & vbCrLf
        msg = msg & "データ行（" & (headerRow + 1) & " 行目以降）に移動してください。"
        MsgBox msg, vbExclamation, "配置エラー"
        Exit Sub
    End If

    If ws.ProtectContents Then
        msg = "シート「" & ws.Name & "」は保護されています。" & vbCrLf & vbCrLf
        msg = msg & "対処方法：" & vbCrLf
        msg = msg & "  1) 管理者にシート保護の解除を依頼" & vbCrLf
        msg = msg & "  2) 解除後、もう一度ボタンをクリック"
        MsgBox msg, vbExclamation, "シート保護中"
        Exit Sub
    End If

    existingUser = NormalizeText(ws.Cells(targetRow, userCol).Value)
    existingDate = ws.Cells(targetRow, dateCol).Value
    If LenB(existingUser) > 0 Then
        If IsDate(existingDate) Then
            existingDateText = Format(existingDate, dateFormat)
        Else
            existingDateText = CStr(existingDate)
        End If
        msg = "この行は既に記入済みです。" & vbCrLf & vbCrLf
        msg = msg & "  担当者：" & existingUser & vbCrLf
        msg = msg & "  日時：" & existingDateText & vbCrLf & vbCrLf
        msg = msg & "上書きしますか？"
        If MsgBox(msg, vbYesNo + vbExclamation + vbDefaultButton2, "上書き確認") = vbNo Then
            Exit Sub
        End If
    End If

    displayName = GetUserDisplayName()

    Application.ScreenUpdating = False
    On Error GoTo WriteError
    ws.Cells(targetRow, userCol).Value = displayName
    With ws.Cells(targetRow, dateCol)
        .Value = Now
        .NumberFormat = dateFormat
    End With
    On Error GoTo 0
    Application.ScreenUpdating = True
    Exit Sub

WriteError:
    Application.ScreenUpdating = True
    msg = "書き込みに失敗しました。" & vbCrLf & vbCrLf
    msg = msg & "考えられる原因：" & vbCrLf
    msg = msg & "  ・対象セルが保護されている" & vbCrLf
    msg = msg & "  ・対象セルが結合されている" & vbCrLf
    msg = msg & "  ・他のユーザーが編集中" & vbCrLf & vbCrLf
    msg = msg & "エラー、詳細：" & Err.Description
    MsgBox msg, vbCritical, "書き込みエラー"
End Sub

Private Function GetCallerButton() As Shape
    Dim caller As Variant
    Dim callerName As String
    Dim ws As Worksheet
    Dim shp As Shape

    On Error Resume Next
    caller = Application.Caller
    On Error GoTo 0

    If VarType(caller) <> vbString Then Exit Function
    callerName = CStr(caller)
    If LenB(callerName) = 0 Then Exit Function

    If Not ActiveSheet Is Nothing Then
        For Each shp In ActiveSheet.Shapes
            If shp.Name = callerName Then
                Set GetCallerButton = shp
                Exit Function
            End If
        Next shp
    End If

    For Each ws In ThisWorkbook.Worksheets
        For Each shp In ws.Shapes
            If shp.Name = callerName Then
                Set GetCallerButton = shp
                Exit Function
            End If
        Next shp
    Next ws
End Function

Private Function GetButtonRow(btn As Shape) As Long
    Dim ws As Worksheet
    Dim centerY As Double
    Dim accY As Double
    Dim r As Long

    Set ws = btn.Parent
    centerY = btn.Top + btn.Height / 2

    accY = 0
    r = 1
    Do While accY <= centerY And r <= ws.Rows.Count
        accY = accY + ws.Rows(r).RowHeight
        If accY > centerY Then
            GetButtonRow = r
            Exit Function
        End If
        r = r + 1
    Loop
    GetButtonRow = btn.TopLeftCell.Row
End Function

Private Function FindColumn(ws As Worksheet, btn As Shape, headerRow As Long, headerName As String) As Long
    Dim lo As ListObject
    Dim headerRange As Range
    Dim cell As Range
    Dim targetNorm As String
    Dim lastCol As Long
    Dim c As Long

    targetNorm = NormalizeText(headerName)
    If LenB(targetNorm) = 0 Then Exit Function

    On Error Resume Next
    Set lo = btn.TopLeftCell.ListObject
    On Error GoTo 0

    If Not lo Is Nothing Then
        Set headerRange = lo.HeaderRowRange
        For Each cell In headerRange
            If NormalizeText(cell.Value) = targetNorm Then
                FindColumn = cell.Column
                Exit Function
            End If
        Next cell
        Exit Function
    End If

    lastCol = ws.Cells(headerRow, ws.Columns.Count).End(xlToLeft).Column
    If lastCol < 1 Then lastCol = 1

    For c = 1 To lastCol
        If NormalizeText(ws.Cells(headerRow, c).Value) = targetNorm Then
            FindColumn = c
            Exit Function
        End If
    Next c
End Function

Private Function NormalizeText(v As Variant) As String
    Dim s As String
    If IsNull(v) Then Exit Function
    s = CStr(v)
    If LenB(s) = 0 Then Exit Function
    s = StrConv(s, vbNarrow)
    s = Replace(s, " ", "")
    s = Replace(s, vbTab, "")
    s = Replace(s, vbLf, "")
    s = Replace(s, vbCr, "")
    NormalizeText = s
End Function

Private Function GetSettingAsString(key As String, defaultValue As String) As String
    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim v As Variant

    Set ws = GetOrCreateSettingsSheet()
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    For i = 2 To lastRow
        If NormalizeText(ws.Cells(i, 1).Value) = NormalizeText(key) Then
            v = ws.Cells(i, 2).Value
            If LenB(CStr(v)) > 0 Then
                GetSettingAsString = CStr(v)
                Exit Function
            End If
        End If
    Next i

    GetSettingAsString = defaultValue
End Function

Private Function GetSettingAsLong(key As String, defaultValue As Long) As Long
    Dim s As String
    Dim n As Long

    s = GetSettingAsString(key, CStr(defaultValue))
    On Error Resume Next
    n = CLng(Val(s))
    On Error GoTo 0
    If n <= 0 Then n = defaultValue
    GetSettingAsLong = n
End Function

Public Function GetCurrentOSUserName() As String
    If LenB(g_cachedUserKey) > 0 Then
        GetCurrentOSUserName = g_cachedUserKey
        Exit Function
    End If

#If Mac Then
    Dim result As String
    Dim home As String
    Dim parts() As String

    On Error Resume Next
    result = MacScript("return short user name of (system info)")
    On Error GoTo 0
    If LenB(result) = 0 Then
        home = Environ("HOME")
        If LenB(home) > 0 Then
            parts = Split(home, "/")
            If UBound(parts) >= 0 Then result = parts(UBound(parts))
        End If
    End If
    g_cachedUserKey = result
#Else
    g_cachedUserKey = Environ("USERNAME")
#End If

    GetCurrentOSUserName = g_cachedUserKey
End Function

Private Function GetUserDisplayName() As String
    Dim winUser As String
    Dim looked As String

    If LenB(g_cachedDisplayName) > 0 Then
        GetUserDisplayName = g_cachedDisplayName
        Exit Function
    End If

    winUser = GetCurrentOSUserName()
    looked = LookupUsersSheet(winUser)

    If LenB(looked) > 0 Then
        g_cachedDisplayName = looked
    ElseIf LenB(winUser) > 0 Then
        g_cachedDisplayName = winUser
    Else
        g_cachedDisplayName = "(不明)"
    End If

    GetUserDisplayName = g_cachedDisplayName
End Function

Private Function LookupUsersSheet(key As String) As String
    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim k As String

    k = NormalizeText(key)
    If LenB(k) = 0 Then Exit Function

    Set ws = GetOrCreateUsersSheet()
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    For i = 2 To lastRow
        If LCase(NormalizeText(ws.Cells(i, 1).Value)) = LCase(k) Then
            LookupUsersSheet = CStr(ws.Cells(i, 2).Value)
            Exit Function
        End If
    Next i
End Function

Private Function GetOrCreateSettingsSheet() As Worksheet
    Dim ws As Worksheet

    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(SETTINGS_SHEET)
    On Error GoTo 0

    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
        ws.Name = SETTINGS_SHEET
        ws.Range("A1:B1").Value = Array("キー（編集禁止）", "値")
        ws.Range("A2:B2").Value = Array("担当者ヘッダー", "担当者")
        ws.Range("A3:B3").Value = Array("日時ヘッダー", "日時")
        ws.Range("A4:B4").Value = Array("ヘッダー行", 1)
        ws.Range("A5:B5").Value = Array("日時フォーマット", DEFAULT_DATE_FORMAT)
        ws.Range("A1:B1").Font.Bold = True
        ws.Range("A1:B1").Interior.Color = RGB(220, 230, 241)
        ws.Range("D1").Value = "※A列の「キー」は変更しないでください。B列の「値」だけ編集できます。"
        ws.Range("D1").Font.Color = RGB(150, 0, 0)
        ws.Columns("A:B").AutoFit
    End If

    Set GetOrCreateSettingsSheet = ws
End Function

Private Function GetOrCreateUsersSheet() As Worksheet
    Dim ws As Worksheet

    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(USERS_SHEET)
    On Error GoTo 0

    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
        ws.Name = USERS_SHEET
        ws.Range("A1:B1").Value = Array("OSユーザー名", "表示名")
        ws.Range("A1:B1").Font.Bold = True
        ws.Range("A1:B1").Interior.Color = RGB(220, 230, 241)
        ws.Range("D1").Value = "※Windows なら %USERNAME%、Mac なら whoami の結果です。ShowMyUserName を実行すると確認できます。"
        ws.Range("D1").Font.Color = RGB(150, 0, 0)
        ws.Columns("A:B").AutoFit
    End If

    Set GetOrCreateUsersSheet = ws
End Function

Public Sub SetupSheets()
    Dim msg As String
    GetOrCreateSettingsSheet
    GetOrCreateUsersSheet
    msg = "初期セットアップが完了しました。" & vbCrLf & vbCrLf
    msg = msg & "次の手順：" & vbCrLf
    msg = msg & "  1) Users シートに自分の OS ユーザー名と表示名を登録" & vbCrLf
    msg = msg & "     （ShowMyUserName を実行するとユーザー名が分かります）" & vbCrLf
    msg = msg & "  2) チェックシートに「担当者」「日時」のヘッダーを準備" & vbCrLf
    msg = msg & "  3) フォームコントロールのボタンを配置し、StampCheck を割り当て"
    MsgBox msg, vbInformation, "セットアップ完了"
End Sub

Public Sub ShowMyUserName()
    Dim u As String
    Dim msg As String

    u = GetCurrentOSUserName()
    If LenB(u) = 0 Then
        MsgBox "ユーザー名を取得できませんでした。", vbCritical, "取得失敗"
        Exit Sub
    End If

#If Mac Then
    msg = "あなたの Mac ユーザー名：" & vbCrLf & vbCrLf
    msg = msg & "  " & u & vbCrLf & vbCrLf
    msg = msg & "この値を Users シートの A 列にコピーしてください。"
    MsgBox msg, vbInformation, "Mac ユーザー名"
#Else
    msg = "あなたの Windows ユーザー名：" & vbCrLf & vbCrLf
    msg = msg & "  " & u & vbCrLf & vbCrLf
    msg = msg & "この値を Users シートの A 列にコピーしてください。"
    MsgBox msg, vbInformation, "Windows ユーザー名"
#End If
End Sub
