@echo off
cd /d "%~dp0"
if /i "%~1"=="--self-test" goto selftest
start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0pet.ps1"
exit /b 0
:selftest
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0pet.ps1" -SelfTest
exit /b %errorlevel%
