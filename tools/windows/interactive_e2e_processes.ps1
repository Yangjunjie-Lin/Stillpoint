function Get-InteractiveProcessId {
    param([string]$PidPath)

    if (-not (Test-Path -LiteralPath $PidPath)) {
        return $null
    }
    $rawProcessId = (Get-Content -LiteralPath $PidPath -Raw -ErrorAction SilentlyContinue).Trim()
    if ($rawProcessId -notmatch "^\d+$") {
        return $null
    }
    return [int]$rawProcessId
}


function Get-ProcessInfo {
    param([int]$TargetProcessId)

    return Get-CimInstance Win32_Process `
        -Filter "ProcessId=$TargetProcessId" `
        -ErrorAction SilentlyContinue
}


function Test-StillpointBackendCommand {
    param([object]$ProcessInfo, [int]$Port = 8443)

    if ($null -eq $ProcessInfo -or [string]::IsNullOrWhiteSpace($ProcessInfo.CommandLine)) {
        return $false
    }
    $commandLine = [string]$ProcessInfo.CommandLine
    return (
        $commandLine -match "(?i)(^|\s)-m\s+uvicorn\s+app\.main:app(\s|$)" `
        -and $commandLine -match "(?i)--port\s+$Port(\s|$)"
    )
}


function Test-StillpointBackendHealth {
    param([int]$Port = 8443)

    try {
        $health = Invoke-RestMethod `
            -Uri "http://127.0.0.1:$Port/health" `
            -TimeoutSec 2
        return $health.service -eq "stillpoint-npc-mind"
    } catch {
        return $false
    }
}


function Get-ProjectGodotProcesses {
    param([string]$RepoRoot)

    return @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like "Godot*" `
                    -and -not [string]::IsNullOrWhiteSpace($_.CommandLine) `
                    -and $_.CommandLine.IndexOf(
                        $RepoRoot,
                        [System.StringComparison]::OrdinalIgnoreCase
                    ) -ge 0
            }
    )
}


function Stop-InteractiveProcess {
    param([int]$TargetProcessId, [string]$Label)

    if ($null -eq (Get-ProcessInfo -TargetProcessId $TargetProcessId)) {
        return
    }
    Write-Host "Stopping $Label process (PID $TargetProcessId)..." -ForegroundColor Yellow
    Stop-Process -Id $TargetProcessId -Force -ErrorAction SilentlyContinue
    Wait-Process -Id $TargetProcessId -Timeout 5 -ErrorAction SilentlyContinue
}


function Get-PortListenerProcessId {
    param([int]$Port = 8443)

    $listener = Get-NetTCPConnection `
        -LocalPort $Port `
        -State Listen `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $listener) {
        return $null
    }
    return [int]$listener.OwningProcess
}


function Assert-InteractiveE2EAvailable {
    param(
        [string]$RepoRoot,
        [string]$RuntimeDir,
        [int]$Port = 8443
    )

    $activeGodot = @(Get-ProjectGodotProcesses -RepoRoot $RepoRoot)
    if ($activeGodot.Count -gt 0) {
        throw "Stillpoint is already running (Godot PID $($activeGodot[0].ProcessId))."
    }

    $backendPidPath = Join-Path $RuntimeDir "backend.pid"
    $recordedBackendId = Get-InteractiveProcessId -PidPath $backendPidPath
    if ($null -ne $recordedBackendId) {
        $recordedProcess = Get-ProcessInfo -TargetProcessId $recordedBackendId
        if (Test-StillpointBackendCommand -ProcessInfo $recordedProcess -Port $Port) {
            Stop-InteractiveProcess -TargetProcessId $recordedBackendId -Label "stale Stillpoint Backend"
        } elseif ($null -ne $recordedProcess) {
            Write-Warning "Ignoring stale Backend PID file; PID $recordedBackendId belongs to another process."
        }
        Remove-Item -LiteralPath $backendPidPath -Force -ErrorAction SilentlyContinue
    }

    $listenerId = Get-PortListenerProcessId -Port $Port
    if ($null -ne $listenerId) {
        $listenerProcess = Get-ProcessInfo -TargetProcessId $listenerId
        $isStillpointBackend = (
            (Test-StillpointBackendCommand -ProcessInfo $listenerProcess -Port $Port) `
            -and (Test-StillpointBackendHealth -Port $Port)
        )
        if ($isStillpointBackend) {
            Stop-InteractiveProcess -TargetProcessId $listenerId -Label "orphaned Stillpoint Backend"
        } else {
            throw "Port $Port is already in use by PID $listenerId and is not a verified Stillpoint Backend."
        }
    }

    $remainingListenerId = Get-PortListenerProcessId -Port $Port
    if ($null -ne $remainingListenerId) {
        throw "Port $Port is still in use by PID $remainingListenerId after cleanup."
    }

    Remove-Item -LiteralPath (Join-Path $RuntimeDir "godot.pid") `
        -Force `
        -ErrorAction SilentlyContinue
}


function Stop-StillpointInteractiveSession {
    param(
        [string]$RepoRoot,
        [string]$RuntimeDir,
        [int]$Port = 8443
    )

    $recordedGodotId = Get-InteractiveProcessId `
        -PidPath (Join-Path $RuntimeDir "godot.pid")
    if ($null -ne $recordedGodotId) {
        $recordedGodot = Get-ProcessInfo -TargetProcessId $recordedGodotId
        if ($null -ne $recordedGodot -and $recordedGodot.Name -like "Godot*") {
            Stop-InteractiveProcess -TargetProcessId $recordedGodotId -Label "Stillpoint Godot"
        }
    }
    foreach ($godotProcess in @(Get-ProjectGodotProcesses -RepoRoot $RepoRoot)) {
        Stop-InteractiveProcess `
            -TargetProcessId ([int]$godotProcess.ProcessId) `
            -Label "Stillpoint Godot"
    }

    $recordedBackendId = Get-InteractiveProcessId `
        -PidPath (Join-Path $RuntimeDir "backend.pid")
    if ($null -ne $recordedBackendId) {
        $recordedBackend = Get-ProcessInfo -TargetProcessId $recordedBackendId
        if (Test-StillpointBackendCommand -ProcessInfo $recordedBackend -Port $Port) {
            Stop-InteractiveProcess -TargetProcessId $recordedBackendId -Label "Stillpoint Backend"
        }
    }

    $listenerId = Get-PortListenerProcessId -Port $Port
    if ($null -ne $listenerId) {
        $listenerProcess = Get-ProcessInfo -TargetProcessId $listenerId
        if (
            (Test-StillpointBackendCommand -ProcessInfo $listenerProcess -Port $Port) `
            -and (Test-StillpointBackendHealth -Port $Port)
        ) {
            Stop-InteractiveProcess -TargetProcessId $listenerId -Label "orphaned Stillpoint Backend"
        } else {
            Write-Warning "Port $Port belongs to an unrelated process (PID $listenerId); leaving it running."
        }
    }

    foreach ($name in @("godot", "backend")) {
        Remove-Item -LiteralPath (Join-Path $RuntimeDir "$name.pid") `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
