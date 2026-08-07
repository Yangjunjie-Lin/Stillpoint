$ErrorActionPreference = "Continue"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$runtimeDir = Join-Path $repoRoot "artifacts\interactive-e2e"
$backendRoot = Join-Path $repoRoot "services\npc_mind"

foreach ($name in @("godot", "backend")) {
    $pidPath = Join-Path $runtimeDir "$name.pid"
    if (Test-Path -LiteralPath $pidPath) {
        $rawProcessId = (Get-Content -LiteralPath $pidPath -Raw -ErrorAction SilentlyContinue).Trim()
        if ($rawProcessId -match "^\d+$") {
            Stop-Process -Id ([int]$rawProcessId) -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
    }
}

Push-Location $backendRoot
try {
    docker compose stop postgres | Out-Host
} finally {
    Pop-Location
}
Write-Host "Interactive E2E processes stopped." -ForegroundColor Green
