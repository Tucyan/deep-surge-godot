param([switch]$Verify)
$ErrorActionPreference = 'Stop'
$storyGodot = Get-Command Godot_v4.7.2-stable_win64.exe -ErrorAction SilentlyContinue
if (-not $storyGodot) { $storyGodot = Get-Command godot -ErrorAction SilentlyContinue }
if (-not $storyGodot) { throw '找不到 Godot，请用编辑器打开 scenes/story_demo.tscn 并按 F6。' }
$storyConsole = Join-Path (Split-Path $storyGodot.Source) 'Godot_v4.7.2-stable_win64_console.exe'
$storyExecutable = if (Test-Path -LiteralPath $storyConsole) { $storyConsole } else { $storyGodot.Source }
if ($Verify) {
    & $storyExecutable --headless --path $PSScriptRoot --script res://tests/test_story_player.gd
    if ($LASTEXITCODE -ne 0) { throw '剧情数据/状态测试失败。' }
    & $storyExecutable --path $PSScriptRoot --script res://tests/story_page_visual.gd
    if ($LASTEXITCODE -ne 0) { throw '剧情页面运行验证失败。' }
} else {
    & $storyExecutable --path $PSScriptRoot res://scenes/story_demo.tscn
}
