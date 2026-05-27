@echo off
:: SentinelNet v2.0 - Double-click to launch
:: Automatically requests admin rights if not already admin
:: Then runs LAUNCH.ps1 which handles everything else

setlocal
set "BASEDIR=%~dp0"
if "%BASEDIR:~-1%"=="\" set "BASEDIR=%BASEDIR:~0,-1%"

:: Check if already admin
net session >nul 2>&1
if %errorlevel% == 0 goto :run_as_admin

:: Not admin - ask for elevation via PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:run_as_admin
:: Now running as admin - launch via PowerShell for best experience
cd /d "%BASEDIR%"

where powershell.exe >nul 2>&1
if %errorlevel% == 0 (
    if exist "%BASEDIR%\LAUNCH.ps1" (
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BASEDIR%\LAUNCH.ps1"
        exit /b
    )
)

:: Fallback to bat launcher
call "%BASEDIR%\START_WINDOWS.bat"
