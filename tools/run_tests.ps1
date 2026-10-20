param([string]$Pattern = 'test_*', [switch]$Quiet)
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent $PSScriptRoot
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root '.planning/test-appldata'
$prevA = $env:APPDATA
$prevL = $env:LOCALAPPDATA
$godot = 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
try {
    $env:APPDATA = Join-Path $data 'appdata'
    $env:LOCALAPPDATA = Join-Path $data 'local'
    New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $names = Get-ChildItem (Join-Path $project 'tests') -Filter "$Pattern.gd" | ForEach-Object { $_.BaseName }
    $failed = @()
    $crashed = @()
    foreach ($t in $names) {
        $out = & $godot --headless --path $project --script "res://tests/$t.gd" 2>&1 | Out-String
        $fails = ([regex]::Matches($out, '(?m)^\s*FAIL: ')).Count
        $crash = ([regex]::Matches($out, 'SCRIPT ERROR')).Count
        $line = ($out -split "`r?`n" | Where-Object { $_ -match ': (PASS|FAIL)' } | Select-Object -Last 1)
        if (-not $line) { $line = 'NO RESULT' }
        $verdict = if ($line -match 'PASS' -and $fails -eq 0 -and $crash -eq 0) { 'ok  ' } else { 'BAD ' }
        if ($verdict -eq 'BAD ') {
            if ($crash -gt 0) { $crashed += $t } else { $failed += $t }
        }
        Write-Output ("{0} {1,-44} {2}" -f $verdict, $t, $line.Trim())
        if ($verdict -eq 'BAD ' -and -not $Quiet) {
            ([regex]::Matches($out, '(?m)^\s*FAIL: [^\r\n]*') | Select-Object -First 8) | ForEach-Object { Write-Output ("       " + $_.Value.Trim()) }
            ([regex]::Matches($out, 'SCRIPT ERROR: [^\r\n]*') | Select-Object -First 3) | ForEach-Object { Write-Output ("       " + $_.Value.Trim()) }
        }
    }
    Write-Output ""
    Write-Output ("TOTAL={0} FAILED={1} CRASHED={2}" -f $names.Count, $failed.Count, $crashed.Count)
    if ($failed.Count) { Write-Output ("FAILED: " + ($failed -join ', ')) }
    if ($crashed.Count) { Write-Output ("CRASHED: " + ($crashed -join ', ')) }
}
finally {
    $env:APPDATA = $prevA
    $env:LOCALAPPDATA = $prevL
}