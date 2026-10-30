@echo off
rem cwork Windows entry point (cmd / double-click / PowerShell).
rem Purpose: bypass the PowerShell execution policy that blocks .ps1,
rem so users do not need to add -ExecutionPolicy Bypass every time.
rem NOTE: keep this file pure ASCII - cmd.exe decodes batch comments with the
rem OEM code page and mis-parses non-ASCII lines.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cwork.ps1" %*
exit /b %ERRORLEVEL%
