param([switch]$Elevated)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# 如果从 360zip/临时目录运行，先复制到稳定目录再继续（提权重启时临时文件可能已被删）
if ($PSScriptRoot -match '\\Temp\\|360zip|\\Temp') {
    $stable = Join-Path $env:LOCALAPPDATA 'MageProbeCollector'
    New-Item -ItemType Directory -Force -Path $stable | Out-Null
    & robocopy $PSScriptRoot $stable /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "复制到稳定目录失败，请先把压缩包解压到桌面再运行。" }
    Start-Process powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$stable\install.ps1`"")
    exit 0
}

. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " MageProbe 只读数据收集器 - 安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $wow = Resolve-WowPath
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "游戏目录：$wow"
$addons = Join-Path $wow 'Interface\AddOns'
if (-not (Test-Path $addons)) { New-Item -ItemType Directory -Force -Path $addons | Out-Null }

$src = Join-Path $PSScriptRoot 'MageProbe'
if (-not (Test-Path (Join-Path $src 'MageProbe.toc'))) {
    Write-Host "安装包不完整：找不到 MageProbe 文件夹。" -ForegroundColor Red
    exit 1
}

$dst = Join-Path $addons 'MageProbe'
try {
    if (Test-Path $dst) {
        $bak = "$dst.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Rename-Item $dst $bak
        Write-Host "旧版本已备份：$bak"
    }
    Copy-Item $src $dst -Recurse -Force
} catch {
    if (-not $Elevated) {
        Write-Host "需要管理员权限写入游戏目录，正在重新启动（请点“是”）..." -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -ArgumentList @(
            '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-Elevated'
        ) | Out-Null
        exit 0
    }
    Write-Host "安装失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Set-Content -Path (Join-Path $PSScriptRoot 'wowpath.txt') -Value $wow -Encoding UTF8

Write-Host ""
Write-Host "安装成功！" -ForegroundColor Green
Write-Host "接下来请：" -ForegroundColor Green
Write-Host " 1) 完全退出魔兽（不是返回角色），重新启动客户端"
Write-Host " 2) 进入角色，正常玩 10-15 分钟，尽量用不同技能"
Write-Host " 3) 输入 /mp dump 回车，再输入 /reload 回车"
Write-Host " 4) 双击 2-打包数据.bat，把桌面生成的 zip 发回"
Write-Host ""
Write-Host "插件只读：不会施法、不会按键、不会改设置。" -ForegroundColor Cyan
