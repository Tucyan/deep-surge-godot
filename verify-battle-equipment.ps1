# Run manually: this graphical check is intentionally not retried by the agent.
$ErrorActionPreference = 'Stop'
$godotCheckCommand = Get-Command Godot_v4.7.2-stable_win64_console.exe -ErrorAction SilentlyContinue
if (-not $godotCheckCommand) {
    throw 'Godot 4.7.2 console executable was not found on PATH.'
}
Write-Host 'Running graphical battle/equipment verification (30 second script watchdog).'
Write-Host 'Expected screenshots: evidence/battle-equipment-{1280,1600,generator}.png'
& $godotCheckCommand.Source --path $PSScriptRoot --script res://tests/battle_equipment_visual.gd
if ($LASTEXITCODE -ne 0) {
    throw "Graphical verification failed or timed out (exit $LASTEXITCODE). See console output."
}
