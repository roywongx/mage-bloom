@echo off
chcp 65001 >nul
title MageProbe 安装
echo ========================================
echo  MageProbe 只读数据收集器 - 安装
echo ========================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
pause
