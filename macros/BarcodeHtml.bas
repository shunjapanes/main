Attribute VB_Name = "BarcodeHtml"
'==============================================================
' BarcodeHtml (Windows / macOS 両対応版)
' Excel 表（A=JAN, B=商品名, C=数量, D=金額）から EAN-13 バーコード一覧 PDF を出力
'
' 動作環境：
'   - Windows 版 Excel 2016 以降
'   - macOS 版 Excel (Microsoft 365) 16.x 以降
'==============================================================
Option Explicit

Private Function GetLPatterns() As String
    GetLPatterns = "0001101,0011001,0010011,0111101,0100011,0110001,0101111,0111011,0110111,0001011"
End Function

Private Function GetGPatterns() As String
    GetGPatterns = "0100111,0110011,0011011,0100001,0011101,0111001,0000101,0010001,0001001,0010111"
End Function

Private Function GetRPatterns() As String
    GetRPatterns = "1110010,1100110,1101100,1000010,1011100,1001110,1010000,1000100,1001000,1110100"
End Function

Private Function GetParityTable() As String
    GetParityTable = "LLLLLL,LLGLGG,LLGGLG,LLGGGL,LGLLGG,LGGLLG,LGGGLL,LGLGLG,LGLGGL,LGGLGL"
End Function

Public Sub ExportBarcodePdf()
    Dim ws As Worksheet
    Dim outWs As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim jan As String
    Dim productName As String
    Dim quantity As Variant
    Dim price As Variant
    Dim savePath As String
    Dim rowOut As Long
    Dim okCount As Long
    Dim skippedRows As String

    Set ws = ActiveSheet
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    If lastRow < 2 Then
        MsgBox "データ行が見つかりません。" & vbCrLf & "A列=JAN, B列=商品名, C列=数量, D列=金額 を入れてください。", vbInformation, "データなし"
        Exit Sub
    End If

    Application.ScreenUpdating = False
    Application.DisplayAlerts = False
    On Error Resume Next
    ThisWorkbook.Sheets("_BarcodeOut").Delete
    On Error GoTo 0
    Application.DisplayAlerts = True

    Set outWs = ThisWorkbook.Sheets.Add(After:=ws)
    outWs.Name = "_BarcodeOut"

    SetupOutputSheet outWs

    rowOut = 2

    For i = 2 To lastRow
        jan = NormalizeJan(ws.Cells(i, 1).Value)
        productName = CStr(ws.Cells(i, 2).Value)
        quantity = ws.Cells(i, 3).Value
        price = ws.Cells(i, 4).Value

        If LenB(jan) = 0 Then
            ' 空行スキップ
        ElseIf Len(jan) <> 13 Then
            skippedRows = skippedRows & vbCrLf & "  " & i & " 行目: 「" & jan & "」(" & Len(jan) & "桁) → 13桁ではありません"
        ElseIf Not IsNumeric(jan) Then
            skippedRows = skippedRows & vbCrLf & "  " & i & " 行目: 「" & jan & "」→ 数字以外が含まれています"
        Else
            DrawBarcodeRow outWs, rowOut, jan, productName, quantity, price
            rowOut = rowOut + 1
            okCount = okCount + 1
        End If
    Next i

    If okCount = 0 Then
        Application.DisplayAlerts = False
        outWs.Delete
        Application.DisplayAlerts = True
        Application.ScreenUpdating = True
        MsgBox "出力対象が0件でした。" & skippedRows, vbExclamation, "出力できません"
        Exit Sub
    End If

    savePath = MakePdfPath()

    On Error GoTo PdfError
    outWs.ExportAsFixedFormat Type:=xlTypePDF, Filename:=savePath, _
        Quality:=xlQualityStandard, IncludeDocProperties:=False, _
        IgnorePrintAreas:=False, OpenAfterPublish:=True
    On Error GoTo 0

    Application.DisplayAlerts = False
    outWs.Delete
    Application.DisplayAlerts = True
    Application.ScreenUpdating = True

    If LenB(skippedRows) > 0 Then
        MsgBox okCount & " 件を PDF で出力しました。" & vbCrLf & vbCrLf & _
            "スキップした行:" & skippedRows, vbInformation, "完了（一部スキップ）"
    End If
    Exit Sub

PdfError:
    Application.DisplayAlerts = False
    On Error Resume Next
    outWs.Delete
    On Error GoTo 0
    Application.DisplayAlerts = True
    Application.ScreenUpdating = True
    MsgBox "PDF 出力に失敗しました。" & vbCrLf & "エラー: " & Err.Description, vbCritical, "エラー"
End Sub

Private Sub SetupOutputSheet(ws As Worksheet)
    With ws.PageSetup
        .Orientation = xlPortrait
        .PaperSize = xlPaperA4
        .LeftMargin = Application.InchesToPoints(0.4)
        .RightMargin = Application.InchesToPoints(0.4)
        .TopMargin = Application.InchesToPoints(0.4)
        .BottomMargin = Application.InchesToPoints(0.4)
        .HeaderMargin = 0
        .FooterMargin = 0
        .FitToPagesWide = 1
        .FitToPagesTall = False
        .Zoom = False
    End With

    ws.Columns(1).ColumnWidth = 22
    ws.Columns(2).ColumnWidth = 26
    ws.Columns(3).ColumnWidth = 14
    ws.Columns(4).ColumnWidth = 7
    ws.Columns(5).ColumnWidth = 10

    ws.Rows(1).RowHeight = 20

    ws.Cells(1, 1).Value = "商品名"
    ws.Cells(1, 2).Value = "バーコード"
    ws.Cells(1, 3).Value = "JAN"
    ws.Cells(1, 4).Value = "数量"
    ws.Cells(1, 5).Value = "金額"

    With ws.Range("A1:E1")
        .Interior.Color = RGB(51, 51, 51)
        .Font.Color = RGB(255, 255, 255)
        .Font.Bold = True
        .Font.Size = 10
        .HorizontalAlignment = xlCenter
        .VerticalAlignment = xlCenter
    End With
End Sub

Private Sub DrawBarcodeRow(ws As Worksheet, rowNum As Long, jan As String, productName As String, quantity As Variant, price As Variant)
    Const MOD_PT As Double = 1.5
    Const BAR_H As Double = 52
    Const QZ As Long = 8
    Const ROW_H As Double = 72

    Dim bits As String
    bits = BuildEan13Bits(jan)

    ws.Rows(rowNum).RowHeight = ROW_H

    ws.Cells(rowNum, 1).Value = productName
    ws.Cells(rowNum, 3).Value = "'" & jan
    If IsNumeric(quantity) Then
        ws.Cells(rowNum, 4).Value = CLng(quantity)
    Else
        ws.Cells(rowNum, 4).Value = quantity
    End If
    If IsNumeric(price) Then
        ws.Cells(rowNum, 5).Value = CDbl(price)
    Else
        ws.Cells(rowNum, 5).Value = price
    End If

    With ws.Cells(rowNum, 1)
        .Font.Size = 9
        .WrapText = True
        .VerticalAlignment = xlCenter
    End With
    With ws.Cells(rowNum, 3)
        .Font.Name = "Courier New"
        .Font.Size = 9
        .HorizontalAlignment = xlCenter
        .VerticalAlignment = xlBottom
    End With
    With ws.Cells(rowNum, 4)
        .HorizontalAlignment = xlRight
        .VerticalAlignment = xlCenter
        .Font.Bold = True
        .Font.Size = 11
        .Font.Color = RGB(0, 102, 204)
    End With
    With ws.Cells(rowNum, 5)
        .NumberFormat = """¥""#,##0"
        .HorizontalAlignment = xlRight
        .VerticalAlignment = xlCenter
        .Font.Bold = True
        .Font.Size = 11
        .Font.Color = RGB(204, 102, 0)
    End With

    With ws.Range(ws.Cells(rowNum, 1), ws.Cells(rowNum, 5)).Borders(xlEdgeBottom)
        .LineStyle = xlContinuous
        .Color = RGB(200, 200, 200)
        .Weight = xlThin
    End With

    Dim cellLeft As Double
    Dim cellTop As Double
    Dim cellWidth As Double
    cellLeft = ws.Columns(2).Left
    cellTop = ws.Rows(rowNum).Top
    cellWidth = ws.Columns(2).Width

    Dim barcodeWidth As Double
    barcodeWidth = (Len(bits) + QZ * 2) * MOD_PT
    Dim startX As Double
    startX = cellLeft + (cellWidth - barcodeWidth) / 2 + QZ * MOD_PT

    Dim x As Double
    Dim inBar As Boolean
    Dim barStart As Double
    Dim barWidth As Double
    Dim i As Long
    Dim ch As String

    x = startX
    inBar = False

    For i = 1 To Len(bits)
        ch = Mid$(bits, i, 1)
        If ch = "1" Then
            If Not inBar Then
                barStart = x
                barWidth = MOD_PT
                inBar = True
            Else
                barWidth = barWidth + MOD_PT
            End If
        Else
            If inBar Then
                AddBar ws, barStart, cellTop + 4, barWidth, BAR_H
                inBar = False
            End If
        End If
        x = x + MOD_PT
    Next i
    If inBar Then AddBar ws, barStart, cellTop + 4, barWidth, BAR_H
End Sub

Private Sub AddBar(ws As Worksheet, left As Double, top As Double, width As Double, height As Double)
    Dim shp As Shape
    Set shp = ws.Shapes.AddShape(msoShapeRectangle, left, top, width, height)
    With shp
        .Fill.ForeColor.RGB = RGB(0, 0, 0)
        .Fill.Solid
        .Line.Visible = msoFalse
        .LockAspectRatio = msoFalse
    End With
End Sub

Private Function MakePdfPath() As String
    Dim baseDir As String
    Dim fileName As String
    fileName = "barcode_" & Format(Now, "yyyymmdd_hhmmss") & ".pdf"
#If Mac Then
    baseDir = Environ("HOME") & "/Documents/"
    MakePdfPath = baseDir & fileName
#Else
    baseDir = Environ("TEMP")
    If LenB(baseDir) = 0 Then baseDir = Environ("TMP")
    If LenB(baseDir) = 0 Then baseDir = "C:\Windows\Temp"
    If Right(baseDir, 1) <> "\" Then baseDir = baseDir & "\"
    MakePdfPath = baseDir & fileName
#End If
End Function

Private Function BuildEan13Bits(jan As String) As String
    Dim firstDigit As Long
    Dim parity As String
    Dim i As Long
    Dim digit As Long
    Dim bits As String

    If Len(jan) <> 13 Or Not IsNumeric(jan) Then Exit Function

    firstDigit = CLng(Mid$(jan, 1, 1))
    parity = SplitItem(GetParityTable(), ",", firstDigit + 1)

    bits = "101"

    For i = 2 To 7
        digit = CLng(Mid$(jan, i, 1))
        If Mid$(parity, i - 1, 1) = "L" Then
            bits = bits & SplitItem(GetLPatterns(), ",", digit + 1)
        Else
            bits = bits & SplitItem(GetGPatterns(), ",", digit + 1)
        End If
    Next i

    bits = bits & "01010"

    For i = 8 To 13
        digit = CLng(Mid$(jan, i, 1))
        bits = bits & SplitItem(GetRPatterns(), ",", digit + 1)
    Next i

    bits = bits & "101"

    BuildEan13Bits = bits
End Function

Private Function SplitItem(source As String, delim As String, index As Long) As String
    Dim arr() As String
    arr = Split(source, delim)
    If index < 1 Or index > UBound(arr) + 1 Then Exit Function
    SplitItem = arr(index - 1)
End Function

Private Function NormalizeJan(v As Variant) As String
    Dim s As String

    If IsNull(v) Or IsEmpty(v) Then Exit Function

    If IsNumeric(v) Then
        s = Format(v, "0")
    Else
        s = CStr(v)
    End If

    s = Replace(s, " ", "")
    s = Replace(s, vbTab, "")
    NormalizeJan = s
End Function
