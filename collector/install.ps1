param([switch]$Elevated)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

if ($PSScriptRoot -match '\\Temp\\|360zip') {
    $stable = Join-Path $env:LOCALAPPDATA 'MageBloomCollector'
    New-Item -ItemType Directory -Force -Path $stable | Out-Null
    & robocopy $PSScriptRoot $stable /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "复制到稳定目录失败，请先把压缩包解压到桌面再运行。" }
    Start-Process powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$stable\install.ps1`"")
    exit 0
}

. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " LiuyueForever + MageBloom - Install" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try { $wow = Resolve-WowPath } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
Write-Host "游戏目录：$wow"

$addons = Join-Path $wow 'Interface\AddOns'
if (-not (Test-Path $addons)) { New-Item -ItemType Directory -Force -Path $addons | Out-Null }
$backupDir = Join-Path $PSScriptRoot 'backup'
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null }

# 1) 移走旧探针/旧 hook，避免被客户端扫描
foreach ($name in @('MageProbe','MageData','LiuyueHook')) {
    $p = Join-Path $addons $name
    if (Test-Path $p) {
        try { Move-Item $p (Join-Path $backupDir ($name + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))) -Force; Write-Host ("已移出旧版: " + $name) } catch {}
    }
}
Get-ChildItem $addons -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(MageProbe|MageData|LiuyueHook)(\.bak-|\.disabled|\.old)' } |
    ForEach-Object { try { Move-Item $_.FullName (Join-Path $backupDir ($_.Name + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))) -Force } catch {} }

# 2) 备份原版小六月
$liu = Join-Path $addons 'LiuyueForever'
if (Test-Path $liu) {
    try {
        Move-Item $liu (Join-Path $backupDir ('LiuyueForever-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))) -Force
        Write-Host "原版 LiuyueForever 已备份。"
    } catch {
        Write-Host "原版 LiuyueForever 备份失败，停止安装（避免覆盖）。" -ForegroundColor Red
        exit 1
    }
}

# 3) 安装改版小六月
$src = Join-Path $PSScriptRoot 'LiuyueForever'
if (-not (Test-Path (Join-Path $src 'LiuyueForever.toc'))) {
    Write-Host "安装包不完整：找不到 LiuyueForever 文件夹。" -ForegroundColor Red
    exit 1
}
$dst = Join-Path $addons 'LiuyueForever'
try {
    Copy-Item $src $dst -Recurse -Force
} catch {
    if (-not $Elevated) {
        Write-Host "需要管理员权限写入游戏目录，正在重新启动（请点“是”）..." -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-Elevated') | Out-Null
        exit 0
    }
    Write-Host "安装失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Set-Content -Path (Join-Path $PSScriptRoot 'wowpath.txt') -Value $wow -Encoding UTF8

Write-Host ""
Write-Host "安装成功：已装入带 MageBloom 的 LiuyueForever。" -ForegroundColor Green
Write-Host "接下来：" -ForegroundColor Green
Write-Host " 1) 完全退出魔兽，重新启动客户端"
Write-Host " 2) 确认 LiuyueForever 已启用（不用另装小六月）"
Write-Host " 3) 进角色正常玩 10-15 分钟"
Write-Host " 4) 输入 /mb dump 回车，再输入 /reload 回车"
Write-Host " 5) 双击 2-打包数据.bat，把桌面 zip 发回"
