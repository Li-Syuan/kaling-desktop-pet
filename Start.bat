@echo off
cd /d "%~dp0"
if /i "%~1"=="--self-test" (
  powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0pet.ps1" -SelfTest
  exit /b
)
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0pet.ps1"
