@echo off
chcp 932 > nul

echo ============================================
echo  VBAプロジェクトアクセス許可 設定ツール
echo  対象: Excel 2016 / 2019 / Microsoft 365
echo ============================================
echo.
echo Excelが起動中の場合は先に閉じてください。
echo.
pause

reg add "HKCU\Software\Microsoft\Office\16.0\Excel\Security" ^
    /v AccessVBOM /t REG_DWORD /d 1 /f > nul

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [完了] 設定が適用されました。
    echo        Excelを再起動してから SetupSheetEvents を実行してください。
) else (
    echo.
    echo [エラー] 設定の適用に失敗しました。
    echo          管理者権限で実行し直してください。
)

echo.
pause
