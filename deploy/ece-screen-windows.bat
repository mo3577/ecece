@echo off
REM Kiosk launcher for Windows. Put a shortcut to this file in the Startup folder:
REM   Win+R → shell:startup
REM Or Task Scheduler: trigger "At log on", action = this .bat
REM
REM Edit ROOT if the repo is not next to this script's ../../ layout.

setlocal
cd /d "%~dp0.."
set "ROOT=%CD%"

REM Optional environment (or use a .env file — run.ps1 loads it)
REM set FPS=60
REM set ZOOM=1.2

if not exist "ECE-screen.exe" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\windows\build.ps1"
  if errorlevel 1 exit /b 1
)

set "PATH=%ROOT%;%ROOT%\deps;%PATH%"
start "" /D "%ROOT%" /max "%ROOT%\ECE-screen.exe"
endlocal
