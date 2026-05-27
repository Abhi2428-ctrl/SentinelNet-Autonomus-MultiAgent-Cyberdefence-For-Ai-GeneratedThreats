# SentinelNet v2.0 - Windows PowerShell Launcher
# Right-click -> Run with PowerShell
# OR double-click if PowerShell scripts are enabled

#Requires -Version 5.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Force TLS 1.2 for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = "SilentlyContinue"

# ── Base directory ─────────────────────────────────────────
$BASE = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $BASE

# ── Console colours ────────────────────────────────────────
function OK   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function WARN { param($m) Write-Host "  [!]  $m" -ForegroundColor Yellow }
function ERR  { param($m) Write-Host "  [X]  $m" -ForegroundColor Red }
function INFO { param($m) Write-Host "  [*]  $m" -ForegroundColor Cyan }
function HEAD { param($m) Write-Host "`n$m" -ForegroundColor Cyan }

Clear-Host
Write-Host ""
Write-Host "  =========================================================" -ForegroundColor Cyan
Write-Host "   SENTINELNET v2.0  -  " -ForegroundColor Cyan
Write-Host "   DQN Agents | Federated Learning | SHAP-XAI" -ForegroundColor Cyan
Write-Host "   Deepfake | Phishing | Network | " -ForegroundColor Cyan
Write-Host "  =========================================================" -ForegroundColor Cyan
Write-Host ""

# ── Admin check ────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    OK "Running as Administrator - LIVE capture enabled"
    $liveMode = $true
} else {
    WARN "Not Administrator - SYNTHETIC mode active"
    Write-Host "      To enable LIVE capture: right-click LAUNCH.ps1 -> Run as Administrator" -ForegroundColor Yellow
    $liveMode = $false
}

# ══════════════════════════════════════════════════════════
# STEP 1 - Find or install Python
# ══════════════════════════════════════════════════════════
HEAD "[1/4] Checking Python 3.8+..."

$pythonCmd = $null
$searchPaths = @(
    "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python310\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python39\python.exe",
    "C:\Python312\python.exe",
    "C:\Python311\python.exe",
    "C:\Python310\python.exe",
    "$BASE\venv\Scripts\python.exe"
)

foreach ($p in $searchPaths) {
    if (Test-Path $p) {
        $pythonCmd = $p
        break
    }
}

if (-not $pythonCmd) {
    $found = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($found) { $pythonCmd = $found.Source }
}
if (-not $pythonCmd) {
    $found = Get-Command python3.exe -ErrorAction SilentlyContinue
    if ($found) { $pythonCmd = $found.Source }
}

if (-not $pythonCmd) {
    INFO "Python not found - downloading Python 3.11.9..."
    INFO "This is a ONE-TIME setup (1-2 minutes)"
    
    $pyInstaller = "$env:TEMP\python_311_installer.exe"
    $pyUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
    
    try {
        INFO "Downloading Python 3.11.9 (24 MB)..."
        Invoke-WebRequest -Uri $pyUrl -OutFile $pyInstaller -UseBasicParsing
        
        INFO "Installing Python silently..."
        $proc = Start-Process -FilePath $pyInstaller -ArgumentList `
            "/quiet", "InstallAllUsers=0", "PrependPath=1", `
            "Include_test=0", "Include_doc=0" `
            -Wait -PassThru
        
        Remove-Item $pyInstaller -Force -ErrorAction SilentlyContinue
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH","User")
        
        # Find it
        $newPaths = @(
            "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
        )
        foreach ($p in $newPaths) {
            if (Test-Path $p) { $pythonCmd = $p; break }
        }
        if (-not $pythonCmd) {
            $found = Get-Command python.exe -ErrorAction SilentlyContinue
            if ($found) { $pythonCmd = $found.Source }
        }
        
        if ($pythonCmd) {
            OK "Python installed: $pythonCmd"
        } else {
            ERR "Python installed but not found. Please restart this script."
            Read-Host "Press Enter to exit"
            exit 1
        }
    } catch {
        ERR "Failed to download Python: $_"
        ERR "Please download manually: https://python.org/downloads"
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    OK "Python found: $pythonCmd"
}

# ══════════════════════════════════════════════════════════
# STEP 2 - Virtual environment
# ══════════════════════════════════════════════════════════
HEAD "[2/4] Setting up virtual environment..."

$venvPython = "$BASE\venv\Scripts\python.exe"
$venvPip    = "$BASE\venv\Scripts\pip.exe"

if (-not (Test-Path $venvPython)) {
    INFO "Creating virtual environment..."
    & $pythonCmd -m venv "$BASE\venv" 2>&1 | Out-Null
    if (Test-Path $venvPython) {
        OK "Virtual environment created"
    } else {
        WARN "Could not create venv - using system Python"
        $venvPython = $pythonCmd
    }
} else {
    OK "Virtual environment ready"
}

# ══════════════════════════════════════════════════════════
# STEP 3 - Install packages (skip if already done)
# ══════════════════════════════════════════════════════════
HEAD "[3/4] Checking dependencies..."

# Check each critical package individually — never skip if any is missing
$criticalPackages = @(
    @{import="fastapi";    pip="fastapi==0.110.0"},
    @{import="uvicorn";    pip="uvicorn[standard]==0.29.0"},
    @{import="websockets"; pip="websockets==12.0"},
    @{import="numpy";      pip="numpy==1.26.4"},
    @{import="multipart";  pip="python-multipart==0.0.9"},
    @{import="scapy";      pip="scapy==2.5.0"},
    @{import="PIL";        pip="Pillow==10.3.0"},
    @{import="cryptography"; pip="cryptography==42.0.5"},
    @{import="certifi";    pip="certifi==2024.2.2"},
    @{import="mss";        pip="mss==9.0.1"},
    @{import="psutil";     pip="psutil==5.9.8"},
    @{import="scipy";      pip="scipy==1.13.0"},
    @{import="cv2";        pip="opencv-python==4.9.0.80"}
)

& $venvPython -m pip install --upgrade pip --quiet 2>&1 | Out-Null

$anyMissing = $false
foreach ($pkg in $criticalPackages) {
    $imp = $pkg.import
    $pip = $pkg.pip
    & $venvPython -c "import $imp" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        INFO "Installing missing package: $pip"
        & $venvPython -m pip install $pip --quiet 2>&1 | Out-Null
        & $venvPython -c "import $imp" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            OK "Installed: $pip"
        } else {
            WARN "Failed to install: $pip (will continue without it)"
        }
        $anyMissing = $true
    }
}

if (-not $anyMissing) {
    OK "All dependencies already installed"
} else {
    OK "Dependency check complete"
}

# ══════════════════════════════════════════════════════════
# STEP 4 - Npcap check
# ══════════════════════════════════════════════════════════
HEAD "[4/4] Checking Npcap (live capture driver)..."

$npcapPath = "C:\Windows\System32\Npcap"
$npcapReg  = "HKLM:\SOFTWARE\Npcap"
$npcapOK   = (Test-Path $npcapPath) -or (Test-Path $npcapReg)

if ($npcapOK) {
    OK "Npcap installed - LIVE packet capture available"
} elseif ($liveMode) {
    INFO "Admin mode - downloading Npcap for live capture..."
    $npcapInstaller = "$env:TEMP\npcap_installer.exe"
    $npcapUrl = "https://npcap.com/dist/npcap-1.79.exe"
    
    try {
        Invoke-WebRequest -Uri $npcapUrl -OutFile $npcapInstaller -UseBasicParsing
        INFO "Installing Npcap silently..."
        Start-Process -FilePath $npcapInstaller `
            -ArgumentList "/S", "/winpcap_mode=yes" `
            -Wait
        Remove-Item $npcapInstaller -Force -ErrorAction SilentlyContinue
        OK "Npcap installed - LIVE capture active"
        $npcapOK = $true
    } catch {
        WARN "Could not install Npcap - continuing in SYNTHETIC mode"
        WARN "Download manually: https://npcap.com/#download"
    }
} else {
    WARN "Npcap not installed - SYNTHETIC mode"
    WARN "Install from https://npcap.com for live capture"
}

# ── Set file permissions on sensitive files ────────────────
if (Test-Path "$BASE\certs\sentinelnet.key") {
    try {
        $acl  = Get-Acl "$BASE\certs\sentinelnet.key"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "Allow"
        )
        $acl.SetAccessRule($rule)
        Set-Acl "$BASE\certs\sentinelnet.key" $acl
    } catch {}
}

# ══════════════════════════════════════════════════════════
# LAUNCH
# ══════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  =========================================================" -ForegroundColor Green
Write-Host "   SentinelNet v2.0 is starting..." -ForegroundColor Green
if ($liveMode -and $npcapOK) {
    Write-Host "   Mode     : LIVE packet capture  [ACTIVE]" -ForegroundColor Green
} else {
    Write-Host "   Mode     : SYNTHETIC  [realistic simulation]" -ForegroundColor Yellow
}
Write-Host "   Dashboard: http://localhost:8000" -ForegroundColor Green
Write-Host "   API Docs : http://localhost:8000/docs" -ForegroundColor Green
Write-Host "   Press Ctrl+C to stop" -ForegroundColor Green
Write-Host "  =========================================================" -ForegroundColor Green
Write-Host ""

# Open browser after 4 seconds
Start-Job -ScriptBlock {
    Start-Sleep 4
    Start-Process "http://localhost:8000"
} | Out-Null

# Start the server
Set-Location "$BASE"

# Clear stale Python bytecode cache so new code always runs fresh
INFO "Clearing Python bytecode cache..."
Get-ChildItem -Path "$BASE" -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path "$BASE" -Recurse -Filter "*.pyc" -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
OK "Bytecode cache cleared"

Set-Location "$BASE\backend"
& $venvPython -B main.py

Write-Host ""
Write-Host "  SentinelNet has stopped." -ForegroundColor Yellow
Read-Host "Press Enter to close"
