@echo off
setlocal
cd /d "%~dp0"

set "GODOT=%CD%\artifacts\godot-4.7.1\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot Debug executable was not found:
  echo %GODOT%
  pause
  exit /b 1
)

"%GODOT%" --path "%CD%" --log-file "artifacts/inventory-debug.log" res://scenes/world/world_session.tscn
endlocal
