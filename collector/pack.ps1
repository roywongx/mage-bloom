$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " MageProbe 只读数据收集器 - 打包" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    $wow = Resolve-WowPath
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

$file = Get-LatestProbe -WowPath $wow
if (-not $file) {
    Write-Host "没有找到 MageProbe.lua。" -ForegroundColor Red
    Write-Host "请确认：已经安装插件、进过游戏、输入过 /mp dump，然后 /reload 或退出游戏。"
    exit 1
}

$ageMin = [math]::Round(((Get-Date) - $file.LastWriteTime).TotalMinutes, 0)
Write-Host "数据文件：$($file.FullName)"
Write-Host "最后写入：$($file.LastWriteTime)（约 $ageMin 分钟前）"
if ($ageMin -gt 30) {
    Write-Host "提示：文件超过 30 分钟没更新，可能不是本次数据。请先 /mp dump 再 /reload。" -ForegroundColor Yellow
}

$desktop = [Environment]::GetFolderPath('Desktop')
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$zip = Join-Path $desktop "MageProbe-收集-$stamp.zip"
$tmp = Join-Path $env:TEMP "MageProbe-$stamp"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Copy-Item $file.FullName (Join-Path $tmp 'MageProbe.lua') -Force

$info = @"
MageProbe 收集包
生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
来源文件：$($file.FullName)
最后写入：$($file.LastWriteTime)
说明：只读数据（技能/光环/读条/事件/冷却/天赋），不含账号密码。
"@
Set-Content -Path (Join-Path $tmp '说明.txt') -Value $info -Encoding UTF8

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip -Force
Remove-Item $tmp -Recurse -Force

Write-Host ""
Write-Host "已生成：$zip" -ForegroundColor Green
Write-Host "请把这个 zip 发回（微信/网盘都行）。" -ForegroundColor Green
Start-Process explorer.exe "/select,`"$zip`""
