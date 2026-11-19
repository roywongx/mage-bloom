@echo off
setlocal EnableExtensions
set "SRC=%~dp0"
set "DST=%LOCALAPPDATA%\MageProbeCollector"

echo ========================================
echo  MageProbe Collector - Install
echo ========================================
echo Source: "%SRC%"
echo Target: "%DST%"

if /I "%SRC%"=="%DST%\" goto run

if not exist "%DST%" mkdir "%DST%" >nul 2>&1
robocopy "%SRC%." "%DST%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto copyfail

:run
cd /d "%DST%"
if not exist "%DST%\install.ps1" goto copyfail
powershell -NoProfile -ExecutionPolicy Bypass -File "%DST%\install.ps1"
echo.
pause
exit /b 0

:copyfail
echo.
echo Copy failed. Please extract the zip to Desktop first, then run again.
pause
exit /b 1
