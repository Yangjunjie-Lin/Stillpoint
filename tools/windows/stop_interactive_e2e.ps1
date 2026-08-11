$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
. (Join-Path $scriptDir "interactive_e2e_processes.ps1")
$runtimeDir = Join-Path $repoRoot "artifacts\interactive-e2e"
$backendRoot = Join-Path $repoRoot "services\npc_mind"

Stop-StillpointInteractiveSession `
    -RepoRoot $repoRoot `
    -RuntimeDir $runtimeDir `
    -Port 8443

Push-Location $backendRoot
try {
    docker compose stop postgres | Out-Host
} finally {
    Pop-Location
}
Write-Host "Interactive E2E processes stopped." -ForegroundColor Green
