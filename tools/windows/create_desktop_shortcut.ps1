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
$shortcutPath = Join-Path $desktop "Stillpoint 0.11.0.lnk"
$icon = Join-Path $RepoRoot "assets\ui\stillpoint_emblem.ico"
if (-not (Test-Path -LiteralPath $icon)) {
    throw "Stillpoint launcher icon was not found: $icon"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcher
$shortcut.WorkingDirectory = $RepoRoot
$shortcut.Description = "Start Stillpoint Debug, PostgreSQL + pgvector, and NPC backend"
$shortcut.IconLocation = "$icon,0"
$shortcut.Save()

Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
