# 公共函数：找魔兽目录、找 SavedVariables
$ErrorActionPreference = 'Stop'

function Find-WowCandidates {
    $out = New-Object System.Collections.Generic.List[string]

    # 1) 正在运行的 Wow.exe
    $proc = Get-Process Wow -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path) {
        $dir = Split-Path -Parent $proc.Path
        if (Test-Path (Join-Path $dir 'Wow.exe')) { $out.Add($dir) }
    }

    # 2) 常见路径
    foreach ($d in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue).Root) {
        foreach ($sub in @(
            'World of Warcraft\_forever_',
            'Program Files\World of Warcraft\_forever_',
            'Program Files (x86)\World of Warcraft\_forever_',
            'Games\World of Warcraft\_forever_',
            'Battle.net\World of Warcraft\_forever_',
            'WeGameApps\World of Warcraft\_forever_'
        )) {
            $p = Join-Path $d $sub
            if (Test-Path (Join-Path $p 'Wow.exe')) { $out.Add($p) }
        }
    }

    # 3) 在 Program Files / Games 下有限深度搜索
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, 'C:\Games', 'D:\Games')) {
        if ($base -and (Test-Path $base)) {
            Get-ChildItem $base -Directory -Depth 3 -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq '_forever_' -and (Test-Path (Join-Path $_.FullName 'Wow.exe')) } |
                ForEach-Object { $out.Add($_.FullName) }
        }
    }

    return ($out | Select-Object -Unique)
}

function Resolve-WowPath {
    $saved = Join-Path $PSScriptRoot 'wowpath.txt'
    if (Test-Path $saved) {
        $p = (Get-Content $saved -Raw).Trim()
        if ($p -and (Test-Path (Join-Path $p 'Wow.exe'))) { return $p }
    }

    $cands = @(Find-WowCandidates)
    if ($cands.Count -eq 1) { return $cands[0] }
    if ($cands.Count -gt 1) {
        # 优先有 WTF/Account 的
        foreach ($c in $cands) {
            if (Test-Path (Join-Path $c 'WTF\Account')) { return $c }
        }
        return $cands[0]
    }

    Write-Host ""
    Write-Host "没有自动找到魔兽世界（_forever_）。" -ForegroundColor Yellow
    Write-Host "请把 World of Warcraft 里面的 _forever_ 文件夹直接拖到这个窗口，然后回车：" -ForegroundColor Yellow
    $p = (Read-Host).Trim().Trim('"').Trim("'")
    if ($p -and (Test-Path (Join-Path $p 'Wow.exe'))) { return $p }
    if ($p -and (Test-Path (Join-Path $p 'World of Warcraft\_forever_\Wow.exe'))) {
        return (Join-Path $p 'World of Warcraft\_forever_')
    }
    throw "路径不对：没有找到 Wow.exe"
}

function Get-LatestProbe {
    param([string]$WowPath)
    $account = Join-Path $WowPath 'WTF\Account'
    if (-not (Test-Path $account)) { return $null }
    return Get-ChildItem $account -Recurse -Filter MageProbe.lua -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\SavedVariables\\MageProbe\.lua$' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}
