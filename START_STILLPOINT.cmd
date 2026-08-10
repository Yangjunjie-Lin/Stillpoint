@echo off
setlocal

rem One-click Windows entry point for Stillpoint Debug + PostgreSQL + Backend.
set "REPO_ROOT=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%tools\windows\run_interactive_e2e.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Stillpoint launcher failed with exit code %EXIT_CODE%.
    pause
)
endlocal & exit /b %EXIT_CODE%
