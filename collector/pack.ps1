$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " LiuyueForever + MageBloom - Package" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try { $wow = Resolve-WowPath } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
$file = Get-LatestProbe -WowPath $wow
if (-not $file) {
    Write-Host "没有找到 MageBloomDB.lua。" -ForegroundColor Red
    Write-Host "请确认改版 LiuyueForever 已启用；进游戏输过 /mb dump，然后 /reload 或退出游戏。"
    exit 1
}

$ageMin = [math]::Round(((Get-Date) - $file.LastWriteTime).TotalMinutes, 0)
Write-Host "数据文件：$($file.FullName)"
Write-Host "最后写入：$($file.LastWriteTime)（约 $ageMin 分钟前）"
if ($ageMin -gt 30) { Write-Host "提示：文件超过 30 分钟没更新，请先 /mb dump 再 /reload。" -ForegroundColor Yellow }

$desktop = [Environment]::GetFolderPath('Desktop')
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$zip = Join-Path $desktop "MageBloom-$stamp.zip"
$tmp = Join-Path $env:TEMP "MageBloom-$stamp"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Copy-Item $file.FullName (Join-Path $tmp 'MageBloomDB.lua') -Force
$liuyueSv = Join-Path $file.Directory.FullName 'LiuyueForeverDB.lua'
if (Test-Path $liuyueSv) { Copy-Item $liuyueSv (Join-Path $tmp 'LiuyueForeverDB.lua') -Force }

$info = @"
MageBloom 收集包（改版 LiuyueForever）
生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
来源：$($file.FullName)
说明：MageBloom 模块从小六月内部导出 SpellBook/Duration/Talents/APL/db/自身光环。
"@
Set-Content -Path (Join-Path $tmp '说明.txt') -Value $info -Encoding UTF8

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip -Force
Remove-Item $tmp -Recurse -Force

Write-Host ""
Write-Host "已生成：$zip" -ForegroundColor Green
Write-Host "请把这个 zip 发回。" -ForegroundColor Green
Start-Process explorer.exe "/select,`"$zip`""
