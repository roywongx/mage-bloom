@echo off
chcp 65001 >nul
title MageProbe 打包数据
echo ========================================
echo  MageProbe 只读数据收集器 - 打包
echo ========================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pack.ps1"
echo.
pause
