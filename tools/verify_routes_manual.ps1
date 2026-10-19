# Manual route gate without an agent-imposed timeout. Never use player saves.
$ErrorActionPreference = 'Stop'
$routeProject = Split-Path -Parent $PSScriptRoot
$routeData = Join-Path $routeProject '.planning/manual-route-verification'
$routePreviousAppData = $env:APPDATA
$routePreviousLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $routeData 'appdata'
    $env:LOCALAPPDATA = Join-Path $routeData 'local'
    New-Item -ItemType Directory -Force $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $routeGodot = Get-Command Godot_v4.7.2-stable_win64_console.exe -ErrorAction SilentlyContinue
    if (-not $routeGodot) { $routeGodot = Get-Command godot -ErrorAction SilentlyContinue }
    if (-not $routeGodot) { throw 'Godot executable not found; no download attempted.' }
    & $routeGodot.Source --headless --path $routeProject --script res://tests/test_routes.gd
    if ($LASTEXITCODE -ne 0) { throw "Route verification failed with exit code $LASTEXITCODE" }
}
finally {
    $env:APPDATA = $routePreviousAppData
    $env:LOCALAPPDATA = $routePreviousLocalData
}
