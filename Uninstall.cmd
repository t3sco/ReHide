@echo off
rem Removes ReHide. Runs Fix-Taskbar.ps1 -Uninstall from this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-Taskbar.ps1" -Uninstall
echo.
pause
