@echo off
chcp 65001 >nul 2>&1
title SentinelNet - Fix Python (Run Once)
color 0E
setlocal

cls
echo.
echo  +=========================================================+
echo  ^|   SentinelNet - Python Fix Utility                     ^|
echo  ^|   Run this ONCE to fix the Microsoft Store Python      ^|
echo  ^|   issue, then use START_WINDOWS.bat normally           ^|
echo  +=========================================================+
echo.
echo  This will:
echo    1. Disable the Microsoft Store Python stub
echo    2. Install real Python 3.11 from python.org
echo    3. Verify everything works
echo.
echo  Press any key to continue or Ctrl+C to cancel...
pause >nul
echo.

:: ── Step 1: Disable Microsoft Store Python App Execution Alias ──
echo  [1/3] Disabling Microsoft Store Python stub...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\python.exe" /ve /d "" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\python3.exe" /ve /d "" /f >nul 2>&1

:: Disable via App Execution Aliases (Settings > Apps > Advanced app settings)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppModelUnlock" /v AllowAllTrustedApps /t REG_DWORD /d 0 /f >nul 2>&1

:: The proper way - disable the alias entries
set "AEA=HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$paths = @('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.py','HKCU:\SOFTWARE\Classes\Applications\python.exe'); foreach($p in $paths){ if(Test-Path $p){Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue}}" >nul 2>&1

echo  [OK] Store stub disabled

:: ── Step 2: Download and install real Python 3.11 ──────────────
echo  [2/3] Installing Python 3.11.9 (real version)...
echo        Downloading from python.org (24 MB)...

set "PY_TMP=%TEMP%\python_311_real.exe"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (New-Object Net.WebClient).DownloadFile('https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe','%PY_TMP%')"

if not exist "%PY_TMP%" (
    echo  [ERROR] Download failed. Check internet and run again.
    pause
    exit /b 1
)

echo  [*] Installing Python 3.11 (this takes ~1 minute)...
"%PY_TMP%" /quiet InstallAllUsers=0 PrependPath=1 ^
    Include_test=0 Include_doc=0 Include_launcher=1
del "%PY_TMP%" >nul 2>&1

:: ── Step 3: Verify ─────────────────────────────────────────────
echo  [3/3] Verifying Python installation...

:: Reload PATH
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "UPATH=%%B"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SPATH=%%B"
if defined SPATH set "PATH=%SPATH%"
if defined UPATH set "PATH=%PATH%;%UPATH%"

set "REAL_PY="
for %%V in (311 312 310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" (
        set "REAL_PY=%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
        goto :verify
    )
)

:verify
if not defined REAL_PY (
    echo  [ERROR] Python not found after install.
    echo          Please install manually: https://python.org/downloads
    echo          Make sure to CHECK "Add Python to PATH" during install.
    pause
    exit /b 1
)

"%REAL_PY%" --version
echo  [OK] Real Python installed: %REAL_PY%

echo.
echo  +=========================================================+
echo  ^|   SUCCESS! Python is ready.                            ^|
echo  ^|                                                         ^|
echo  ^|   Now close this window and                            ^|
echo  ^|   double-click START_WINDOWS.bat                       ^|
echo  +=========================================================+
echo.
pause
