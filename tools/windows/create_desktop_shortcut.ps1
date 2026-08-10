param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
}
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$launcher = Join-Path $RepoRoot "START_STILLPOINT.cmd"
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Stillpoint launcher was not found: $launcher"
}

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "Stillpoint 0.8.0.lnk"
$godot = Join-Path $RepoRoot "artifacts\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $godot)) {
    $godot = Join-Path $RepoRoot "tools\godot\Godot_v4.7.1-stable_win64_console.exe"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcher
$shortcut.WorkingDirectory = $RepoRoot
$shortcut.Description = "Start Stillpoint Debug, PostgreSQL + pgvector, and NPC backend"
if (Test-Path -LiteralPath $godot) {
    $shortcut.IconLocation = "$godot,0"
}
$shortcut.Save()

Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
