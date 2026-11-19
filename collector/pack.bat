@echo off
setlocal EnableExtensions
set "SRC=%~dp0"
set "DST=%LOCALAPPDATA%\MageProbeCollector"

if /I not "%SRC%"=="%DST%\" (
  if not exist "%DST%\pack.ps1" (
    if not exist "%DST%" mkdir "%DST%" >nul 2>&1
    robocopy "%SRC%." "%DST%" /E /NFL /NDL /NJH /NJS /NP >nul
  )
)

cd /d "%DST%"
if not exist "%DST%\pack.ps1" goto fail
powershell -NoProfile -ExecutionPolicy Bypass -File "%DST%\pack.ps1"
echo.
pause
exit /b 0

:fail
echo.
echo pack.ps1 missing. Extract the zip to Desktop and run 1-Install first.
pause
exit /b 1
