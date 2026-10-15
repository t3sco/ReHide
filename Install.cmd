@echo off
rem Installs ReHide. Runs Fix-Taskbar.ps1 -Install from this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-Taskbar.ps1" -Install
echo.
pause
