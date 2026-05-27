@echo off
chcp 65001 >nul 2>&1
title SentinelNet v2.0 - 
color 0B
setlocal enabledelayedexpansion

cls
echo.
echo  +=========================================================+
echo  ^|   SENTINELNET v2.0  -                                 ^|
echo  ^|   DQN Agents ^| Federated Learning ^| SHAP-XAI        ^|
echo  ^|   Deepfake ^| e-mail threats ^| Network ^|            ^|
echo  +=========================================================+
echo.

set "BASEDIR=%~dp0"
if "%BASEDIR:~-1%"=="\" set "BASEDIR=%BASEDIR:~0,-1%"
cd /d "%BASEDIR%"

:: ============================================================
:: STEP 0 - Admin check
:: ============================================================
net session >nul 2>&1
if %errorlevel% == 0 (
    echo  [OK] Running as Administrator - LIVE capture enabled
    set "LIVE_MODE=1"
) else (
    echo  [!]  Not Administrator - SYNTHETIC mode only
    echo       Right-click this file, Run as Administrator for LIVE mode
    set "LIVE_MODE=0"
)
echo.

:: ============================================================
:: STEP 1 - Find REAL Python (skip Microsoft Store stub)
:: ============================================================
echo  [1/4] Looking for Python...
set "PY="

:: Check venv first (fastest on repeat runs)
if exist "%BASEDIR%\venv\Scripts\python.exe" (
    set "PY=%BASEDIR%\venv\Scripts\python.exe"
    goto :py_verify
)

:: Check real install locations ONLY - never WindowsApps (Store stub)
for %%V in (312 311 310 39 38) do (
    if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" (
        set "PY=%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
        goto :py_verify
    )
    if exist "C:\Python%%V\python.exe" (
        set "PY=C:\Python%%V\python.exe"
        goto :py_verify
    )
    if exist "%PROGRAMFILES%\Python%%V\python.exe" (
        set "PY=%PROGRAMFILES%\Python%%V\python.exe"
        goto :py_verify
    )
)

:: Check PATH but skip WindowsApps (Store stub)
for /f "tokens=* usebackq" %%A in (`where python.exe 2^>nul`) do (
    echo %%A | findstr /i "WindowsApps" >nul 2>&1
    if !errorlevel! neq 0 (
        if not defined PY set "PY=%%A"
    )
)
for /f "tokens=* usebackq" %%A in (`where python3.exe 2^>nul`) do (
    echo %%A | findstr /i "WindowsApps" >nul 2>&1
    if !errorlevel! neq 0 (
        if not defined PY set "PY=%%A"
    )
)

if defined PY goto :py_verify

:: ============================================================
:: No real Python - download and install silently
:: ============================================================
:install_python
echo  [*] Real Python not found. Auto-installing Python 3.11...
echo      (Microsoft Store Python is disabled - installing real version)
echo      This is a ONE-TIME setup (~2 minutes)
echo.

set "PY_TMP=%TEMP%\sentinelnet_py311.exe"
set "PY_URL=https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"

echo  [*] Downloading Python 3.11.9 (24 MB)...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (New-Object Net.WebClient).DownloadFile('%PY_URL%','%PY_TMP%')" 2>nul

if not exist "%PY_TMP%" (
    echo.
    echo  [ERROR] Download failed. Please:
    echo    1. Check your internet connection
    echo    2. Go to https://python.org/downloads
    echo    3. Download Python 3.11 (Windows 64-bit)
    echo    4. Install it (CHECK "Add to PATH")
    echo    5. Run this file again
    echo.
    pause
    exit /b 1
)

echo  [*] Installing Python 3.11 silently (please wait)...
"%PY_TMP%" /quiet InstallAllUsers=0 PrependPath=1 ^
    Include_test=0 Include_doc=0 Include_launcher=1
if %errorlevel% neq 0 (
    echo  [!] Silent install failed - trying interactive install...
    "%PY_TMP%" InstallAllUsers=0 PrependPath=1 Include_test=0
)
del "%PY_TMP%" >nul 2>&1

:: Reload PATH
for /f "skip=2 tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "UPATH=%%B"
for /f "skip=2 tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SPATH=%%B"
if defined SPATH set "PATH=%SPATH%"
if defined UPATH set "PATH=%PATH%;%UPATH%"

:: Find it now
for %%V in (311 312 310) do (
    if exist "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe" (
        set "PY=%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
        goto :py_verify
    )
)
for /f "tokens=* usebackq" %%A in (`where python.exe 2^>nul`) do (
    echo %%A | findstr /i "WindowsApps" >nul 2>&1
    if !errorlevel! neq 0 (
        if not defined PY set "PY=%%A"
    )
)

if not defined PY (
    echo  [ERROR] Python installed but still not found.
    echo          Please restart this file.
    pause
    exit /b 1
)

:py_verify
:: Make sure it is not the Store stub (store stub exits with code 9009)
"%PY%" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Found python is the Microsoft Store stub - ignoring it
    set "PY="
    goto :install_python
)
:: Extra check - real python returns version string
"%PY%" -c "import sys; exit(0 if sys.version_info>=(3,8) else 1)" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Python too old or is Store stub - installing real Python
    set "PY="
    goto :install_python
)

echo  [OK] Python: %PY%

:: Disable the Windows Store Python app execution alias so it stops interfering
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\python.exe" /f >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { Remove-Item 'HKCU:\Software\Classes\ms-python' -Recurse -Force -EA Stop } catch {}" >nul 2>&1

:: ============================================================
:: STEP 2 - Check pip works (skip venv - use system Python directly)
:: ============================================================
echo  [2/4] Checking pip...

:: Delete broken venv if it exists (it causes more problems than it solves)
if exist "%BASEDIR%\venv" (
    rmdir /s /q "%BASEDIR%\venv" >nul 2>&1
)

:: Check if pip works on system Python
"%PY%" -m pip --version >nul 2>&1
if %errorlevel% == 0 (
    echo  [OK] pip ready
    goto :install_packages
)

:: pip missing - fix it with ensurepip
echo  [*] pip not found - fixing with ensurepip...
"%PY%" -m ensurepip --upgrade >nul 2>&1

"%PY%" -m pip --version >nul 2>&1
if %errorlevel% == 0 (
    echo  [OK] pip fixed via ensurepip
    goto :install_packages
)

:: Last resort - download get-pip.py
echo  [*] Downloading get-pip.py...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (New-Object Net.WebClient).DownloadFile('https://bootstrap.pypa.io/get-pip.py','%TEMP%\get-pip.py')" >nul 2>&1
if exist "%TEMP%\get-pip.py" (
    "%PY%" "%TEMP%\get-pip.py" --quiet >nul 2>&1
    del "%TEMP%\get-pip.py" >nul 2>&1
)

"%PY%" -m pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Cannot get pip working.
    echo  Run this manually in Command Prompt as Admin:
    echo    "%PY%" -m ensurepip --upgrade
    echo  Then run this file again.
    pause
    exit /b 1
)
echo  [OK] pip ready

:install_packages

:: ============================================================
:: STEP 3 - Install packages (using system Python directly)
:: ============================================================
echo  [3/4] Checking packages...

"%PY%" -c "import fastapi, uvicorn, numpy, scapy, scipy, cv2" >nul 2>&1
if %errorlevel% == 0 (
    echo  [OK] All packages already installed
    goto :check_npcap
)

echo  [*] Installing packages (~2-3 min, ~80 MB download)...

:: Upgrade pip first
"%PY%" -m pip install --upgrade pip --quiet --no-warn-script-location >nul 2>&1

:: Install all packages
"%PY%" -m pip install ^
    fastapi==0.110.0 ^
    "uvicorn[standard]==0.29.0" ^
    websockets==12.0 ^
    numpy==1.26.4 ^
    python-multipart==0.0.9 ^
    scapy==2.5.0 ^
    Pillow==10.3.0 ^
    cryptography==42.0.5 ^
    certifi==2024.2.2 ^
    mss==9.0.1 ^
    psutil==5.9.8 ^
    scipy==1.13.0 ^
    opencv-python==4.9.0.80 ^
    --quiet --no-warn-script-location

if %errorlevel% neq 0 (
    echo  [!] Some packages failed - retrying individually...
    for %%P in (fastapi "uvicorn[standard]" websockets numpy scapy Pillow cryptography certifi mss psutil scipy opencv-python) do (
        "%PY%" -m pip install %%P --quiet --no-warn-script-location >nul 2>&1
    )
)

"%PY%" -c "import fastapi, uvicorn, numpy, scapy, scipy, cv2" >nul 2>&1
if %errorlevel% == 0 (
    echo  [OK] Packages installed
) else (
    echo  [ERROR] Package install failed.
    echo.
    echo  Manual fix - open a new Command Prompt and run:
    echo    "%PY%" -m pip install fastapi uvicorn numpy scapy Pillow cryptography psutil mss certifi
    echo  Then run this file again.
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: STEP 4 - Npcap
:: ============================================================
:check_npcap
echo  [4/4] Checking Npcap...

if exist "C:\Windows\System32\Npcap\" (
    echo  [OK] Npcap installed - LIVE capture ready
    goto :launch
)
reg query "HKLM\SOFTWARE\Npcap" >nul 2>&1
if %errorlevel% == 0 (
    echo  [OK] Npcap ready
    goto :launch
)

if "%LIVE_MODE%"=="1" (
    echo  [*] Installing Npcap for live packet capture...
    set "NP_TMP=%TEMP%\sentinelnet_npcap.exe"
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "[Net.ServicePointManager]::SecurityProtocol='Tls12'; (New-Object Net.WebClient).DownloadFile('https://npcap.com/dist/npcap-1.79.exe','%NP_TMP%')" 2>nul
    if exist "%NP_TMP%" (
        "%NP_TMP%" /S /winpcap_mode=yes >nul 2>&1
        del "%NP_TMP%" >nul 2>&1
        echo  [OK] Npcap installed
    ) else (
        echo  [!]  Npcap download failed - SYNTHETIC mode
        echo       Install manually: https://npcap.com/#download
    )
) else (
    echo  [!]  Npcap not installed - SYNTHETIC mode active
    echo       For LIVE capture: install Npcap from https://npcap.com
)

:: ============================================================
:: LAUNCH
:: ============================================================
:launch
echo.
echo  +=========================================================+
if "%LIVE_MODE%"=="1" (
echo  ^|  Mode     : LIVE packet capture [ACTIVE]               ^|
) else (
echo  ^|  Mode     : SYNTHETIC simulation                       ^|
)
echo  ^|  Dashboard: http://localhost:8000                      ^|
echo  ^|  Press Ctrl+C to stop                                  ^|
echo  +=========================================================+
echo.

start "" cmd /c "timeout /t 4 /nobreak >nul 2>&1 && start http://localhost:8000"

:: Clear stale Python bytecode so new code always runs
echo [*] Clearing Python cache...
for /d /r "%BASEDIR%" %%d in (__pycache__) do @if exist "%%d" rd /s /q "%%d" 2>nul
for /r "%BASEDIR%" %%f in (*.pyc) do @del /q "%%f" 2>nul

cd /d "%BASEDIR%\backend"
"%PY%" -B main.py

echo.
echo  SentinelNet stopped. Press any key to close.
pause >nul
