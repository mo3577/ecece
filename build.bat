@echo off
REM Build ECE-screen for Windows
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows\build.ps1"
if errorlevel 1 exit /b 1
echo.
echo Done. Run with run.bat
