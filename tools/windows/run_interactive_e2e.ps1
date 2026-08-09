$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$runtimeDir = Join-Path $repoRoot "artifacts\interactive-e2e"
$backendRoot = Join-Path $repoRoot "services\npc_mind"
$godot = Join-Path $repoRoot "artifacts\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe"
$databaseUrl = "postgresql+psycopg://stillpoint:stillpoint@127.0.0.1:55432/stillpoint"
$backendProcess = $null
$godotProcess = $null

if (-not (Test-Path -LiteralPath $godot)) {
    $godot = Join-Path $repoRoot "tools\godot\Godot_v4.7.1-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot 4.7.1 console executable was not found."
}

$siliconFlowKey = $env:SILICONFLOW_API_KEY
if ([string]::IsNullOrWhiteSpace($siliconFlowKey)) {
    $siliconFlowKey = [Environment]::GetEnvironmentVariable("SILICONFLOW_API_KEY", "User")
}
$siliconFlowModel = $env:SILICONFLOW_TEXT_MODEL
if ([string]::IsNullOrWhiteSpace($siliconFlowModel)) {
    $siliconFlowModel = [Environment]::GetEnvironmentVariable("SILICONFLOW_TEXT_MODEL", "User")
}

$provider = "fake"
$providerLabel = "fake"
$embeddingProvider = "fake"
$isSiliconFlow = $false
if (-not [string]::IsNullOrWhiteSpace($siliconFlowKey)) {
    $isSiliconFlow = $true
    $env:OPENAI_API_KEY = $siliconFlowKey
    $env:OPENAI_BASE_URL = "https://api.siliconflow.cn/v1"
    # Qwen/Qwen2.5-7B-Instruct can misspell or truncate structured fields on
    # SiliconFlow. Text mode keeps the real spoken reply while the Backend owns
    # safe empty memory, graph, and gameplay-intent candidate arrays.
    $env:OPENAI_RESPONSE_FORMAT = "text"
    $env:OPENAI_TEXT_MODEL = if ([string]::IsNullOrWhiteSpace($siliconFlowModel)) {
        "Qwen/Qwen2.5-7B-Instruct"
    } else {
        $siliconFlowModel
    }
    $provider = "openai"
    $providerLabel = "siliconflow/$($env:OPENAI_TEXT_MODEL)"
} elseif (-not [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY) `
    -and -not [string]::IsNullOrWhiteSpace($env:OPENAI_TEXT_MODEL)) {
    $provider = "openai"
    $providerLabel = "openai-compatible/$($env:OPENAI_TEXT_MODEL)"
    if ([string]::IsNullOrWhiteSpace($env:OPENAI_RESPONSE_FORMAT)) {
        $env:OPENAI_RESPONSE_FORMAT = "json_object"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:OPENAI_EMBEDDING_MODEL)) {
        $embeddingProvider = "openai"
    }
}

$env:APP_ENV = "development"
$env:NPC_REPOSITORY = "postgres"
$env:DATABASE_URL = $databaseUrl
$env:NPC_MIND_SIGNING_KEY = [guid]::NewGuid().ToString("N")
$env:LLM_PROVIDER = $provider
$env:NPC_EMBEDDING_PROVIDER = $embeddingProvider
$env:NPC_PROVIDER_READ_TIMEOUT_SECONDS = if ($isSiliconFlow) {
    "17"
} elseif ($provider -eq "openai") {
    "60"
} else {
    "15"
}
# Text-quality retries happen only after a valid HTTP response. At most three
# quality attempts, each with two 17-second reads plus a 3-second connect phase,
# stay below the 130-second Godot request budget even on the combined worst path.
$env:NPC_PROVIDER_RETRIES = if ($isSiliconFlow) {
    "1"
} elseif ($provider -eq "openai") {
    "1"
} else {
    "2"
}
$env:NPC_MAX_OUTPUT_TOKENS = if ($isSiliconFlow) {
    "400"
} elseif ($provider -eq "openai") {
    "800"
} else {
    "400"
}
$env:NPC_BACKEND_URL = "http://127.0.0.1:8443"
$env:NPC_DIALOGUE_TIMEOUT_SECONDS = if ($provider -eq "openai") { "130" } else { "15" }
$env:NPC_DIALOGUE_MAX_RETRIES = if ($provider -eq "openai") { "0" } else { "1" }
$env:NO_PROXY = "127.0.0.1,localhost"
$env:APPDATA = Join-Path $runtimeDir "appdata"
$env:LOCALAPPDATA = Join-Path $runtimeDir "localappdata"

New-Item -ItemType Directory -Path $runtimeDir, $env:APPDATA, $env:LOCALAPPDATA -Force | Out-Null

try {
    Write-Host "[1/4] Starting PostgreSQL + pgvector..." -ForegroundColor Cyan
    Push-Location $backendRoot
    try {
        docker compose up -d postgres
        if ($LASTEXITCODE -ne 0) { throw "PostgreSQL failed to start." }

        Write-Host "[2/4] Applying Alembic migrations..." -ForegroundColor Cyan
        python -m alembic -c alembic.ini upgrade head
        if ($LASTEXITCODE -ne 0) { throw "Alembic migration failed." }
    } finally {
        Pop-Location
    }

    $existingListener = Get-NetTCPConnection -LocalPort 8443 -State Listen -ErrorAction SilentlyContinue
    if ($existingListener) {
        throw "Port 8443 is already in use by PID $($existingListener[0].OwningProcess). Run STOP_E2E.cmd first."
    }

    Write-Host "[3/4] Starting Uvicorn on 127.0.0.1:8443 (Provider: $providerLabel)..." -ForegroundColor Cyan
    $backendProcess = Start-Process `
        -FilePath "python" `
        -ArgumentList @("-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8443") `
        -WorkingDirectory $backendRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $runtimeDir "backend.stdout.log") `
        -RedirectStandardError (Join-Path $runtimeDir "backend.stderr.log") `
        -PassThru
    Set-Content -LiteralPath (Join-Path $runtimeDir "backend.pid") -Value $backendProcess.Id

    $healthy = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:8443/health" -TimeoutSec 1
            if ($health.status -eq "ok" `
                -and $health.repository -eq "PostgresCognitionRepository" `
                -and $health.llm_provider -eq $provider) {
                $healthy = $true
                break
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $healthy) {
        Get-Content -LiteralPath (Join-Path $runtimeDir "backend.stderr.log") -Tail 80 -ErrorAction SilentlyContinue
        throw "Backend did not become healthy."
    }

    # Uvicorn has inherited its server-only configuration. Remove every secret
    # from the launcher environment before spawning the Godot client.
    Remove-Item Env:SILICONFLOW_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:NPC_MIND_SIGNING_KEY -ErrorAction SilentlyContinue
    $siliconFlowKey = $null

    Write-Host "[4/4] Opening Stillpoint Debug Build..." -ForegroundColor Cyan
    Write-Host "Provider: $providerLabel" -ForegroundColor Yellow
    Write-Host "Close the game window to stop Backend and PostgreSQL automatically." -ForegroundColor Green
    $godotProcess = Start-Process `
        -FilePath $godot `
        -ArgumentList @("--path", $repoRoot, "--log-file", (Join-Path $runtimeDir "godot-debug.log")) `
        -WorkingDirectory $repoRoot `
        -NoNewWindow `
        -PassThru
    Set-Content -LiteralPath (Join-Path $runtimeDir "godot.pid") -Value $godotProcess.Id
    $godotProcess.WaitForExit()
} catch {
    Write-Host "E2E launcher failed: $($_.Exception.Message)" -ForegroundColor Red
    throw
} finally {
    Write-Host "Stopping interactive E2E services..." -ForegroundColor Cyan
    if ($godotProcess -and -not $godotProcess.HasExited) {
        Stop-Process -Id $godotProcess.Id -Force -ErrorAction SilentlyContinue
    }
    if ($backendProcess -and -not $backendProcess.HasExited) {
        Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
        $backendProcess.WaitForExit(5000) | Out-Null
    }
    Remove-Item -LiteralPath (Join-Path $runtimeDir "godot.pid") -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $runtimeDir "backend.pid") -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $backendRoot) {
        Push-Location $backendRoot
        try {
            docker compose stop postgres | Out-Host
        } finally {
            Pop-Location
        }
    }
    Write-Host "Interactive E2E stopped." -ForegroundColor Green
}
