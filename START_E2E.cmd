@echo off
title Stillpoint Interactive E2E Launcher
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows\run_interactive_e2e.ps1"
if errorlevel 1 (
  echo.
  echo E2E launcher failed. Check artifacts\interactive-e2e\backend.stderr.log and godot-debug.log.
  pause
)
