Attribute VB_Name = "BarcodeHtml"
'==============================================================
' BarcodeHtml (Windows / macOS 両対応版)
' Excel 表（A=JAN, B=商品名, C=数量, D=金額）から EAN-13 バーコード一覧 HTML を出力
'
' 動作環境：
'   - Windows 版 Excel 2016 以降
'   - macOS 版 Excel (Microsoft 365) 16.x 以降
'
' 行継続文字 (_) を一切使わない構成にしてあります。
' macOS では SaveAs ダイアログが不安定なので、InputBox で名前のみ入力。
'==============================================================
Option Explicit

Private Const MODULE_WIDTH As Double = 2
Private Const BAR_HEIGHT As Double = 80
Private Const QUIET_ZONE As Double = 10

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

Public Sub ExportBarcodeHtml()
    Dim ws As Worksheet
    Dim lastRow As Long
    Dim i As Long
    Dim jan As String
    Dim productName As String
    Dim quantity As Variant
    Dim price As Variant
    Dim html As String
    Dim items As String
    Dim skippedRows As String
    Dim totalCount As Long
    Dim okCount As Long
    Dim savePath As String
    Dim msg As String

    Set ws = ActiveSheet
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    If lastRow < 2 Then
        MsgBox "データ行が見つかりません。" & vbCrLf & "A列=JAN, B列=商品名, C列=数量, D列=金額 を入れてください。", vbInformation, "データなし"
        Exit Sub
    End If

    Application.ScreenUpdating = False

    For i = 2 To lastRow
        jan = NormalizeJan(ws.Cells(i, 1).Value)
        productName = CStr(ws.Cells(i, 2).Value)
        quantity = ws.Cells(i, 3).Value
        price = ws.Cells(i, 4).Value

        If LenB(jan) = 0 Then
            ' 空行スキップ
        ElseIf Len(jan) <> 13 Then
            skippedRows = skippedRows & vbCrLf & "  " & i & " 行目: 「" & jan & "」(" & Len(jan) & "桁) → 13桁ではありません"
            totalCount = totalCount + 1
        ElseIf Not IsNumeric(jan) Then
            skippedRows = skippedRows & vbCrLf & "  " & i & " 行目: 「" & jan & "」 → 数字以外が含まれています"
            totalCount = totalCount + 1
        Else
            items = items & BuildItemHtml(jan, productName, quantity, price)
            okCount = okCount + 1
            totalCount = totalCount + 1
        End If
    Next i

    Application.ScreenUpdating = True

    If okCount = 0 Then
        MsgBox "出力対象が0件でした。" & skippedRows, vbExclamation, "出力できません"
        Exit Sub
    End If

    html = BuildPageHtml(items, okCount)

    savePath = MakeTempPath()

    On Error GoTo WriteError
    WriteTextFile savePath, html
    On Error GoTo 0

    OpenInBrowser savePath

    msg = okCount & " 件のバーコードを出力しました。" & vbCrLf & vbCrLf
    msg = msg & "ファイル: " & savePath & vbCrLf & vbCrLf
    msg = msg & "ブラウザが自動で開かない場合は上記ファイルを Finder（Mac）またはエクスプローラ（Windows）から開いてください。"
    If LenB(skippedRows) > 0 Then
        msg = msg & vbCrLf & vbCrLf & "スキップした行（" & (totalCount - okCount) & " 件）:" & skippedRows
    End If
    MsgBox msg, vbInformation, "出力完了"
    Exit Sub

WriteError:
    MsgBox "ファイル書き込みに失敗しました。" & vbCrLf & "パス: " & savePath & vbCrLf & "エラー: " & Err.Description, vbCritical, "エラー"
End Sub

Private Function BuildItemHtml(jan As String, productName As String, quantity As Variant, price As Variant) As String
    Dim svg As String
    Dim qtyText As String
    Dim priceText As String
    Dim sb As String

    svg = BuildEan13Svg(jan)

    If IsNumeric(quantity) Then
        qtyText = CStr(CLng(quantity))
    Else
        qtyText = HtmlEscape(CStr(quantity))
    End If

    priceText = FormatPrice(price)

    sb = "    <div class=""item"">" & vbLf
    sb = sb & "      <div class=""name"">" & HtmlEscape(productName) & "</div>" & vbLf
    sb = sb & "      <div class=""barcode"">" & svg & "</div>" & vbLf
    sb = sb & "      <div class=""jan"">" & jan & "</div>" & vbLf
    sb = sb & "      <div class=""meta"">"
    sb = sb & "<span class=""qty""><span class=""label"">数量</span><span class=""val"">" & qtyText & "</span></span>"
    sb = sb & "<span class=""price""><span class=""label"">金額</span><span class=""val"">" & priceText & "</span></span>"
    sb = sb & "</div>" & vbLf
    sb = sb & "    </div>" & vbLf

    BuildItemHtml = sb
End Function

Private Function FormatPrice(p As Variant) As String
    If IsNull(p) Or IsEmpty(p) Then
        FormatPrice = "—"
        Exit Function
    End If

    If IsNumeric(p) Then
        FormatPrice = "¥" & Format(CDbl(p), "#,##0")
    Else
        FormatPrice = HtmlEscape(CStr(p))
    End If
End Function

Private Function BuildPageHtml(items As String, okCount As Long) As String
    Dim sb As String

    sb = "<!DOCTYPE html>" & vbLf
    sb = sb & "<html lang=""ja"">" & vbLf
    sb = sb & "<head>" & vbLf
    sb = sb & "  <meta charset=""UTF-8"">" & vbLf
    sb = sb & "  <title>バーコード一覧 (" & okCount & " 件)</title>" & vbLf
    sb = sb & "  <style>" & vbLf
    sb = sb & "    * { box-sizing: border-box; }" & vbLf
    sb = sb & "    body { font-family: 'Yu Gothic', 'Hiragino Sans', 'Meiryo', sans-serif; margin: 16px; background: #f5f5f5; color: #222; }" & vbLf
    sb = sb & "    header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 12px; }" & vbLf
    sb = sb & "    header h1 { font-size: 18px; margin: 0; }" & vbLf
    sb = sb & "    header .info { font-size: 12px; color: #555; }" & vbLf
    sb = sb & "    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px; }" & vbLf
    sb = sb & "    .item { background: #fff; border: 2px solid #333; border-radius: 8px; padding: 14px; page-break-inside: avoid; display: flex; flex-direction: column; gap: 8px; }" & vbLf
    sb = sb & "    .name { font-size: 16px; font-weight: bold; line-height: 1.35; min-height: 2.7em; color: #111; border-bottom: 1px dashed #ccc; padding-bottom: 6px; }" & vbLf
    sb = sb & "    .barcode { text-align: center; padding: 4px 0; }" & vbLf
    sb = sb & "    .barcode svg { max-width: 100%; height: auto; }" & vbLf
    sb = sb & "    .jan { font-family: 'Menlo', 'Consolas', monospace; font-size: 18px; font-weight: bold; text-align: center; letter-spacing: 1px; color: #000; background: #f0f0f0; padding: 4px 0; border-radius: 4px; }" & vbLf
    sb = sb & "    .meta { display: flex; justify-content: space-between; gap: 8px; margin-top: 4px; }" & vbLf
    sb = sb & "    .meta > span { flex: 1; display: flex; flex-direction: column; align-items: center; padding: 6px; border-radius: 4px; }" & vbLf
    sb = sb & "    .meta .label { font-size: 11px; color: #666; }" & vbLf
    sb = sb & "    .meta .val { font-size: 20px; font-weight: bold; }" & vbLf
    sb = sb & "    .qty { background: #e8f4ff; }" & vbLf
    sb = sb & "    .qty .val { color: #0066cc; }" & vbLf
    sb = sb & "    .price { background: #fff4e6; }" & vbLf
    sb = sb & "    .price .val { color: #cc6600; }" & vbLf
    sb = sb & "    @media print {" & vbLf
    sb = sb & "      body { background: #fff; margin: 8mm; }" & vbLf
    sb = sb & "      header { border-bottom: 1px solid #999; padding-bottom: 4px; }" & vbLf
    sb = sb & "      .item { border-color: #000; }" & vbLf
    sb = sb & "      .qty, .price { background: #fff; border: 1px solid #999; }" & vbLf
    sb = sb & "      .jan { background: #fff; border: 1px solid #999; }" & vbLf
    sb = sb & "    }" & vbLf
    sb = sb & "  </style>" & vbLf
    sb = sb & "</head>" & vbLf
    sb = sb & "<body>" & vbLf
    sb = sb & "  <header>" & vbLf
    sb = sb & "    <h1>バーコード一覧</h1>" & vbLf
    sb = sb & "    <div class=""info"">出力件数: " & okCount & " 件 / 出力日時: " & Format(Now, "yyyy/mm/dd hh:mm") & "</div>" & vbLf
    sb = sb & "  </header>" & vbLf
    sb = sb & "  <div class=""grid"">" & vbLf
    sb = sb & items
    sb = sb & "  </div>" & vbLf
    sb = sb & "</body>" & vbLf
    sb = sb & "</html>"

    BuildPageHtml = sb
End Function

Public Function BuildEan13Svg(jan As String) As String
    Dim bits As String
    Dim totalModules As Long
    Dim svgWidth As Double
    Dim svgHeight As Double
    Dim x As Double
    Dim i As Long
    Dim ch As String
    Dim bars As String
    Dim textY As Double
    Dim textElems As String
    Dim fontSize As Double
    Dim leftStart As Double
    Dim rightStart As Double
    Dim leftWidth As Double
    Dim svgOut As String

    bits = BuildEan13Bits(jan)
    If LenB(bits) = 0 Then
        BuildEan13Svg = ""
        Exit Function
    End If

    totalModules = Len(bits) + QUIET_ZONE * 2
    svgWidth = totalModules * MODULE_WIDTH
    svgHeight = BAR_HEIGHT + 20

    x = QUIET_ZONE * MODULE_WIDTH

    For i = 1 To Len(bits)
        ch = Mid$(bits, i, 1)
        If ch = "1" Then
            bars = bars & "<rect x=""" & FormatNum(x) & """ y=""0"" "
            bars = bars & "width=""" & FormatNum(MODULE_WIDTH) & """ "
            bars = bars & "height=""" & FormatNum(BAR_HEIGHT) & """ fill=""#000""/>"
        End If
        x = x + MODULE_WIDTH
    Next i

    textY = BAR_HEIGHT + 14
    fontSize = 14

    textElems = textElems & "<text x=""" & FormatNum(QUIET_ZONE * MODULE_WIDTH - 2) & """"
    textElems = textElems & " y=""" & FormatNum(textY) & """"
    textElems = textElems & " font-family=""monospace"" font-size=""" & FormatNum(fontSize) & """"
    textElems = textElems & " text-anchor=""end"">" & Mid$(jan, 1, 1) & "</text>"

    leftStart = QUIET_ZONE * MODULE_WIDTH + 3 * MODULE_WIDTH
    leftWidth = 7 * 6 * MODULE_WIDTH
    textElems = textElems & "<text x=""" & FormatNum(leftStart + leftWidth / 2) & """"
    textElems = textElems & " y=""" & FormatNum(textY) & """"
    textElems = textElems & " font-family=""monospace"" font-size=""" & FormatNum(fontSize) & """"
    textElems = textElems & " text-anchor=""middle"""
    textElems = textElems & " letter-spacing=""" & FormatNum(MODULE_WIDTH * 2) & """>"
    textElems = textElems & Mid$(jan, 2, 6) & "</text>"

    rightStart = leftStart + leftWidth + 5 * MODULE_WIDTH
    textElems = textElems & "<text x=""" & FormatNum(rightStart + leftWidth / 2) & """"
    textElems = textElems & " y=""" & FormatNum(textY) & """"
    textElems = textElems & " font-family=""monospace"" font-size=""" & FormatNum(fontSize) & """"
    textElems = textElems & " text-anchor=""middle"""
    textElems = textElems & " letter-spacing=""" & FormatNum(MODULE_WIDTH * 2) & """>"
    textElems = textElems & Mid$(jan, 8, 6) & "</text>"

    svgOut = "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 "
    svgOut = svgOut & FormatNum(svgWidth) & " " & FormatNum(svgHeight)
    svgOut = svgOut & """ preserveAspectRatio=""xMidYMid meet"">"
    svgOut = svgOut & "<rect width=""100%"" height=""100%"" fill=""#fff""/>"
    svgOut = svgOut & bars & textElems & "</svg>"

    BuildEan13Svg = svgOut
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

Private Function HtmlEscape(s As String) As String
    Dim t As String
    t = s
    t = Replace(t, "&", "&amp;")
    t = Replace(t, "<", "&lt;")
    t = Replace(t, ">", "&gt;")
    t = Replace(t, """", "&quot;")
    HtmlEscape = t
End Function

Private Function FormatNum(n As Double) As String
    FormatNum = Format(n, "0.##")
End Function

Private Function MakeTempPath() As String
    ' Mac は Excel サンドボックスから確実に書ける ~/Documents/ に出力
    ' Windows は %TEMP% に出力（自動掃除される）
    Dim baseDir As String
    Dim fileName As String

    fileName = "barcode_" & Format(Now, "yyyymmdd_hhmmss") & ".html"

#If Mac Then
    baseDir = Environ("HOME") & "/Documents/"
    MakeTempPath = baseDir & fileName
#Else
    baseDir = Environ("TEMP")
    If LenB(baseDir) = 0 Then baseDir = Environ("TMP")
    If LenB(baseDir) = 0 Then baseDir = "C:\Windows\Temp"
    If Right(baseDir, 1) <> "\" Then baseDir = baseDir & "\"
    MakeTempPath = baseDir & fileName
#End If
End Function

Private Sub WriteTextFile(path As String, content As String)
#If Mac Then
    Dim fileNum As Integer
    fileNum = FreeFile
    Open path For Output As #fileNum
    Print #fileNum, content;
    Close #fileNum
#Else
    Dim stream As Object
    Dim binStream As Object
    Set stream = CreateObject("ADODB.Stream")
    stream.Type = 2
    stream.Charset = "utf-8"
    stream.Open
    stream.WriteText content

    stream.Position = 0
    stream.Type = 1
    stream.Position = 3

    Set binStream = CreateObject("ADODB.Stream")
    binStream.Type = 1
    binStream.Mode = 3
    binStream.Open
    stream.CopyTo binStream
    stream.Flush
    stream.Close
    binStream.SaveToFile path, 2
    binStream.Close
#End If
End Sub

Private Sub OpenInBrowser(path As String)
    On Error Resume Next
#If Mac Then
    ' Finder 経由で開く（既定のブラウザが起動）
    Dim cmd As String
    cmd = "tell application """ & "Finder" & """ to open POSIX file """ & path & """"
    MacScript cmd
#Else
    ' Windows: 既定のブラウザで開く
    CreateObject("Shell.Application").Open path
#End If
    If Err.Number <> 0 Then Err.Clear
    On Error Goto 0
End Sub
