@echo off
REM Run ECE-screen on Windows (builds first if needed)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\run.ps1"
exit /b %ERRORLEVEL%
