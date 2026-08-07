@echo off
title Stop Stillpoint Interactive E2E
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows\stop_interactive_e2e.ps1"
timeout /t 2 /nobreak >nul
