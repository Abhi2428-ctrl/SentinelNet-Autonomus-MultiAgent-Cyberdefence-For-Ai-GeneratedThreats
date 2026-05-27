@echo off
chcp 65001 >nul 2>&1
title SentinelNet v2.0

:: This launcher:
:: 1. Tries PowerShell launcher first (best experience)
:: 2. Falls back to direct Python if PS fails
:: 3. Auto-installs Python if not found
:: 4. Installs all dependencies automatically
:: No manual pip installs needed. Ever.

setlocal enabledelayedexpansion
set "BASEDIR=%~dp0"
if "%BASEDIR:~-1%"=="\" set "BASEDIR=%BASEDIR:~0,-1%"
cd /d "%BASEDIR%"

:: ── Try PowerShell launcher first ─────────────────────────
where powershell.exe >nul 2>&1
if %errorlevel% == 0 (
    if exist "%BASEDIR%\LAUNCH.ps1" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BASEDIR%\LAUNCH.ps1"
        exit /b %errorlevel%
    )
)

:: ── Fallback: direct bat launcher ─────────────────────────
call "%BASEDIR%\START_WINDOWS.bat"
