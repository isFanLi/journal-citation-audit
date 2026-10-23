@echo off
where pwsh.exe >nul 2>nul
if %errorlevel% equ 0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish.ps1" %*
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish.ps1" %*
)
set "TASK_EXIT=%errorlevel%"
pause
exit /b %TASK_EXIT%
