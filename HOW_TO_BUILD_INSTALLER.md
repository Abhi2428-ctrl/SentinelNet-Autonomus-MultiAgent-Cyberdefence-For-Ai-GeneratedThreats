# How to Build SentinelNet Windows Installer

## What You'll Get
```
SentinelNet_v2_Setup.exe   ← single file, send to any Windows user
                              90-100 MB
                              Includes everything — Python, all packages,
                              Npcap driver, no dependencies needed
```

---

## Machine Requirements
- Windows 10/11 64-bit (must build on Windows)
- Python 3.11 or 3.12 (64-bit)
- Internet connection (for pip installs)
- ~2 GB free disk space during build
- 10-15 minutes time

---

## Step 1 — Install Python Build Tools

Open Command Prompt or PowerShell and run:

```bat
pip install pyinstaller pillow pystray win10toast
pip install fastapi "uvicorn[standard]" numpy scapy
pip install cryptography mss psutil certifi
pip install websockets python-multipart
```

---

## Step 2 — Download Asset Files

Place these in the `assets/` folder:

### Npcap OEM (bundled with installer)
1. Go to https://npcap.com/oem/
2. Fill out the free OEM license form
3. Download `npcap-X.XX-oem.exe`
4. Rename to `npcap-oem.exe`
5. Place in `assets/npcap-oem.exe`

> If you skip this: installer still works but
> user must install Npcap manually for live capture.
> Synthetic mode works without it.

### Visual C++ Redistributable
1. Go to https://aka.ms/vs/17/release/vc_redist.x64.exe
2. Save as `assets/vc_redist.x64.exe`

> If you skip this: most Windows 10/11 machines
> already have it. Only very fresh installs need it.

---

## Step 3 — Run the Build Script

```bat
cd sentinelnet2
python build_windows.py
```

This will:
- Check all requirements
- Generate PyInstaller spec file
- Bundle Python + all packages + your code
- Output to `dist/SentinelNet/` folder

**Takes 3-8 minutes.** Normal to see warnings.

---

## Step 4 — Create the Setup.exe Installer

### Install Inno Setup (free)
1. Go to https://jrsoftware.org/isdl.php
2. Download "Inno Setup X" (latest stable)
3. Install it

### Compile the installer
1. Open `installer_script.iss` in Inno Setup
2. Press `Ctrl+F9` (or Build → Compile)
3. Wait 1-2 minutes
4. Find output: `dist/SentinelNet_v2_Setup.exe`

---

## Step 5 — Test It

On a clean Windows machine (or VM):
1. Double-click `SentinelNet_v2_Setup.exe`
2. Accept UAC prompt
3. Click through installer
4. SentinelNet should start automatically
5. System tray icon 🛡️ should appear
6. Browser should open to http://localhost:8000

---

## Final File Sizes (approximate)

```
dist/SentinelNet/           ← portable folder
  SentinelNet.exe           ← 1-2 MB (just the launcher)
  _internal/                ← 150-180 MB (Python + packages)
  frontend/                 ← 120 KB (dashboard HTML)
  agents/                   ← 200 KB (Python agents)
  backend/                  ← 40 KB (FastAPI server)

dist/SentinelNet_v2_Setup.exe ← 85-100 MB (compressed installer)
```

---

## Troubleshooting

### "DLL not found" error when running EXE
```
pip install pyinstaller-hooks-contrib
Then re-run build_windows.py
```

### Windows Defender deletes the EXE
```
This is a false positive from PyInstaller packaging.
Options:
  A. Add build output to Defender exclusions while testing
  B. Get a code signing certificate ($70-200/year)
     from DigiCert, Sectigo, or Comodo
     A signed EXE is trusted by Defender automatically
```

### "Failed to execute script" on launch
```
Run with console enabled to see error:
Edit sentinelnet.spec: change console=False to console=True
Rebuild, run, check the error message
```

### Installer says "Npcap already installed"
```
Normal — installer detects existing Npcap and skips.
Live capture should work automatically.
```

### EXE is very large (>200 MB)
```
Install UPX compressor: https://upx.github.io/
Place upx.exe in the same folder as pyinstaller
It compresses the output ~40-50%
```

---

## Optional — Code Signing

A signed installer removes all security warnings.
Without signing: Windows shows "Unknown publisher" warning.
With signing: Windows shows your company name, no warning.

```
1. Buy certificate from DigiCert (~$200/year)
   or Sectigo (~$70/year)
   or use Microsoft's free signing for open source

2. Sign the EXE:
   signtool sign /tr http://timestamp.digicert.com
                 /td sha256 /fd sha256
                 /a dist\SentinelNet_v2_Setup.exe

3. Verify:
   signtool verify /pa dist\SentinelNet_v2_Setup.exe
```

---

## What's Inside the Installer

```
SentinelNet_v2_Setup.exe contains:
  ✅ Python 3.11 runtime (user needs no Python)
  ✅ All pip packages (no pip install needed)
  ✅ SentinelNet agents + backend + dashboard
  ✅ Npcap OEM driver (silent auto-install)
  ✅ VC++ runtime
  ✅ Windows Defender auto-exclusion
  ✅ Start Menu shortcut
  ✅ Desktop shortcut (optional)
  ✅ Startup with Windows (optional)
  ✅ System tray integration
  ✅ Auto-updater
  ✅ Proper uninstaller
```
