@echo off
setlocal enabledelayedexpansion
title SentinelNet - Prepare Installer
color 0B
cls

echo.
echo  +=========================================================+
echo  ^|   SentinelNet v2.0  -  Installer Preparation           ^|
echo  +=========================================================+
echo.

:: ============================================================
:: STEP 0 - Setup
:: ============================================================
set "BASEDIR=%~dp0"
if "%BASEDIR:~-1%"=="\" set "BASEDIR=%BASEDIR:~0,-1%"
set "PKG_DIR=%BASEDIR%\packages"
set "ASSETS_DIR=%BASEDIR%\assets"

echo [*] Base directory: %BASEDIR%
echo.

:: ============================================================
:: STEP 1 - Find Python
:: ============================================================
echo [1/3] Locating Python...
set "PY="

for %%V in (313 312 311 310 39) do (
    if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" (
        if not defined PY set "PY=%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
    )
)
for %%V in (313 312 311 310 39) do (
    if exist "C:\Python%%V\python.exe" (
        if not defined PY set "PY=C:\Python%%V\python.exe"
    )
)
if not defined PY (
    where py >nul 2>&1
    if !errorlevel! == 0 (
        for /f "tokens=*" %%A in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do set "PY=%%A"
    )
)
if not defined PY (
    where python >nul 2>&1
    if !errorlevel! == 0 (
        for /f "tokens=*" %%A in ('python -c "import sys; print(sys.executable)" 2^>nul') do set "PY=%%A"
    )
)
if not defined PY (
    echo.
    echo [ERROR] Python not found! Install from https://python.org
    pause
    exit /b 1
)
echo [OK] Python: !PY!
echo.

echo [*] Upgrading pip...
"!PY!" -m pip install --upgrade pip --quiet
echo [OK] pip ready.
echo.

:: ============================================================
:: STEP 2 - Download wheels one by one
:: ============================================================
echo [2/3] Downloading Python wheels into packages\ ...
echo       (Each package shown individually so you can see errors)
echo.

if exist "!PKG_DIR!" rmdir /s /q "!PKG_DIR!"
mkdir "!PKG_DIR!"

set /a FAIL=0
set /a OK=0

call :DL "pip"
call :DL "setuptools"
call :DL "wheel"
call :DL "fastapi==0.110.0"
call :DL "uvicorn==0.29.0"
call :DL "websockets==12.0"
call :DL "numpy==1.26.4"
call :DL "python-multipart==0.0.9"
call :DL "scapy==2.5.0"
call :DL "Pillow==10.3.0"
call :DL "cryptography==42.0.5"
call :DL "certifi==2024.2.2"
call :DL "mss==9.0.1"
call :DL "psutil==5.9.8"
call :DL "scipy==1.13.0"
call :DL "opencv-python==4.9.0.80"
call :DL "starlette"
call :DL "pydantic"
call :DL "anyio"
call :DL "httptools"
call :DL "click"
call :DL "h11"
call :DL "python-dotenv"
call :DL "watchdog==4.0.0"

echo.
set /a TOTAL=0
for %%F in ("!PKG_DIR!\*.*") do set /a TOTAL+=1
echo [*] Files in packages\: !TOTAL!

if !TOTAL! LSS 15 (
    echo [WARNING] Very few packages downloaded. Check internet and retry!
) else (
    echo [OK] Package download successful.
)
echo.
goto :NPCAP

:DL
"!PY!" -m pip download "%~1" -d "!PKG_DIR!" --quiet 2>nul
if !errorlevel! neq 0 (
    echo     [FAIL] %~1
    set /a FAIL+=1
) else (
    echo     [OK]   %~1
    set /a OK+=1
)
goto :eof

:: ============================================================
:NPCAP
echo [3/3] Downloading Npcap...
if not exist "!ASSETS_DIR!" mkdir "!ASSETS_DIR!"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "try {" ^
    "    (New-Object Net.WebClient).DownloadFile(" ^
    "    'https://npcap.com/dist/npcap-1.79.exe'," ^
    "    '!ASSETS_DIR!\npcap-setup.exe');" ^
    "    Write-Host '[OK] Npcap downloaded.'" ^
    "} catch { Write-Host '[FAIL] Npcap:' $_.Exception.Message }"

echo.

:: ============================================================
:: DONE
:: ============================================================
echo  +=========================================================+
echo  ^|   PREPARATION COMPLETE                                 ^|
echo  +=========================================================+
echo.
set /a TOTAL=0
for %%F in ("!PKG_DIR!\*.*") do set /a TOTAL+=1
echo  packages\  - !TOTAL! files
if exist "!ASSETS_DIR!\npcap-setup.exe" (
    echo  assets\    - npcap-setup.exe OK
) else (
    echo  assets\    - Npcap MISSING (will download at runtime)
)
echo.
if !TOTAL! GEQ 15 (
    echo  STATUS: READY - Open SentinelNet_Installer.iss in Inno Setup
    echo          Press Ctrl+F9 to build installer.
) else (
    echo  STATUS: WARNING - Package count low (!TOTAL!)
    echo          Fix internet issues above and re-run this script.
)
echo.
pause
endlocal
