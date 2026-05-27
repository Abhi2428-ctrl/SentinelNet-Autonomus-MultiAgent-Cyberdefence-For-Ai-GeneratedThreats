"""
SentinelNet v2.0 — Windows 64-bit Build Script
===============================================
Run this script on your Windows machine to produce
the final installer.

STEP 1 — Install build tools (run once):
    pip install pyinstaller pillow pystray win10toast
    pip install fastapi uvicorn[standard] numpy scapy
    pip install cryptography mss psutil certifi
    pip install websockets python-multipart

STEP 2 — Place these files in assets/ folder:
    assets/npcap-oem.exe        (from https://npcap.com/oem/)
    assets/vc_redist.x64.exe    (from Microsoft)

STEP 3 — Run this script:
    python build_windows.py

STEP 4 — Compile the installer:
    Install Inno Setup: https://jrsoftware.org/isdl.php
    Open installer_script.iss
    Press Ctrl+F9

OUTPUT:
    dist/SentinelNet_v2_Setup.exe   ← send this to users
"""

import os, sys, shutil, subprocess
from pathlib import Path

BASE_DIR  = Path(__file__).parent.resolve()
DIST_DIR  = BASE_DIR / "dist"
BUILD_DIR = BASE_DIR / "build"
SPEC_FILE = BASE_DIR / "sentinelnet.spec"

C = {
    "green":  "\033[92m",
    "yellow": "\033[93m",
    "red":    "\033[91m",
    "cyan":   "\033[96m",
    "reset":  "\033[0m",
}
def ok(m):   print(f"  {C['green']}✅ {m}{C['reset']}")
def warn(m): print(f"  {C['yellow']}⚠️  {m}{C['reset']}")
def err(m):  print(f"  {C['red']}❌ {m}{C['reset']}")
def info(m): print(f"  {C['cyan']}→  {m}{C['reset']}")
def head(m): print(f"\n{C['cyan']}{m}{C['reset']}")


def step1_check():
    head("[1/4] Checking requirements...")
    pkgs = [
        ("PyInstaller",  "PyInstaller"),
        ("pystray",      "pystray"),
        ("PIL",          "Pillow"),
        ("win10toast",   "win10toast"),
        ("fastapi",      "fastapi"),
        ("uvicorn",      "uvicorn"),
        ("numpy",        "numpy"),
        ("scapy",        "scapy"),
        ("cryptography", "cryptography"),
        ("mss",          "mss"),
        ("psutil",       "psutil"),
        ("certifi",      "certifi"),
        ("websockets",   "websockets"),
    ]
    missing = []
    for imp, pkg in pkgs:
        try:
            __import__(imp); ok(pkg)
        except ImportError:
            err(f"{pkg}  — run: pip install {pkg}"); missing.append(pkg)

    # Check asset files
    assets = BASE_DIR / "assets"
    for f in ["npcap-oem.exe", "vc_redist.x64.exe",
              "sentinelnet.ico"]:
        p = assets / f
        if p.exists():
            ok(f"assets/{f}  ({p.stat().st_size//1024} KB)")
        else:
            if f == "sentinelnet.ico":
                warn(f"assets/{f} not found — will use default icon")
            else:
                warn(f"assets/{f} not found — "
                     f"installer will skip this component")

    if missing:
        print(f"\n  Install missing: pip install {' '.join(missing)}")
        return False
    return True


def step2_clean():
    head("[2/4] Cleaning previous build...")
    for d in [DIST_DIR, BUILD_DIR]:
        if d.exists():
            shutil.rmtree(d); ok(f"Removed {d.name}/")
    if SPEC_FILE.exists():
        SPEC_FILE.unlink(); ok("Removed sentinelnet.spec")


def step3_generate_spec():
    head("[3/4] Generating PyInstaller spec...")

    # Build datas list
    datas = []
    def add(src, dst):
        p = BASE_DIR / src
        if p.exists():
            datas.append(f"    (r'{p}', r'{dst}'),")

    add("frontend/index.html",   "frontend")
    add("agents/__init__.py",    "agents")
    for py in (BASE_DIR / "agents").glob("*.py"):
        datas.append(f"    (r'{py}', r'agents'),")
    add("backend/main.py",       "backend")
    add("assets/sentinelnet.ico","assets")
    add("README.md",             ".")
    add("requirements.txt",      ".")

    datas_str = "[\n" + "\n".join(datas) + "\n]"

    ico = BASE_DIR / "assets" / "sentinelnet.ico"
    ico_line = f"icon=r'{ico}'," if ico.exists() else ""

    ver = BASE_DIR / "assets" / "version_info.txt"
    ver_line = f"version=r'{ver}'," if ver.exists() else ""

    spec = f"""# -*- mode: python ; coding: utf-8 -*-
# SentinelNet v2.0 — Windows 64-bit PyInstaller spec

block_cipher = None

a = Analysis(
    [r'{BASE_DIR / "sentinelnet_tray.py"}'],
    pathex=[r'{BASE_DIR}'],
    binaries=[],
    datas={datas_str},
    hiddenimports=[
        # Uvicorn / FastAPI
        'uvicorn.main','uvicorn.config',
        'uvicorn.lifespan.on',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.loops.auto','uvicorn.logging',
        'fastapi','fastapi.middleware.cors',
        'starlette.routing','starlette.responses',
        'starlette.middleware','anyio',
        'anyio._backends._asyncio',
        'websockets','websockets.legacy',
        'websockets.legacy.server',
        # Numpy
        'numpy','numpy.core._multiarray_umath',
        # PIL
        'PIL','PIL.Image','PIL.ImageDraw',
        'PIL.ImageFont','PIL.ImageStat',
        'PIL.ImageGrab','PIL.ImageFilter',
        # Crypto
        'cryptography',
        'cryptography.hazmat.primitives.ciphers.aead',
        'cryptography.hazmat.backends.openssl',
        # Scapy
        'scapy','scapy.all',
        'scapy.layers.http','scapy.arch.windows',
        # Tray
        'pystray','pystray._win32','win10toast',
        # Windows
        'winreg','ctypes','ctypes.wintypes',
        # Misc
        'mss','psutil','certifi',
        'imaplib','ssl','email','email.mime',
        'email.mime.text','hashlib','hmac',
    ],
    hookspath=[],
    runtime_hooks=[],
    excludes=[
        'matplotlib','scipy','pandas',
        'sklearn','tensorflow','torch',
        'tkinter','PyQt5','PyQt6','wx',
        'notebook','IPython','sphinx',
        'pytest','setuptools','cv2',
    ],
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz, a.scripts, [],
    exclude_binaries=True,
    name='SentinelNet',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=['vcruntime140.dll','python3*.dll'],
    console=False,
    target_arch='x86_64',
    {ico_line}
    {ver_line}
)

coll = COLLECT(
    exe, a.binaries, a.zipfiles, a.datas,
    strip=False, upx=True, upx_exclude=[],
    name='SentinelNet',
)
"""
    SPEC_FILE.write_text(spec, encoding="utf-8")
    ok(f"Spec written: {SPEC_FILE.name}")
    return True


def step4_build():
    head("[4/4] Running PyInstaller (2-5 minutes)...")
    result = subprocess.run(
        [
            sys.executable, "-m", "PyInstaller",
            str(SPEC_FILE),
            "--clean", "--noconfirm",
            f"--distpath={DIST_DIR}",
            f"--workpath={BUILD_DIR}",
            "--log-level=WARN",
        ],
        cwd=str(BASE_DIR),
    )
    if result.returncode != 0:
        err("PyInstaller failed — check output above")
        return False

    out = DIST_DIR / "SentinelNet"
    if not out.exists():
        err("Output folder not found"); return False

    size = sum(f.stat().st_size for f in out.rglob("*")
               if f.is_file()) / (1024*1024)
    ok(f"Built: {out}  ({size:.0f} MB uncompressed)")
    return True


def print_next_steps():
    print(f"""
{C['cyan']}{'='*58}{C['reset']}
{C['green']}  ✅  PyInstaller build complete!{C['reset']}
{C['cyan']}{'='*58}{C['reset']}

  Your portable app is ready at:
  {C['yellow']}  dist/SentinelNet/SentinelNet.exe{C['reset']}

  To create the professional Setup.exe installer:
  {C['cyan']}  1. Install Inno Setup (free):{C['reset']}
        https://jrsoftware.org/isdl.php
  {C['cyan']}  2. Open installer_script.iss in Inno Setup{C['reset']}
  {C['cyan']}  3. Press Ctrl+F9 to compile{C['reset']}
  {C['cyan']}  4. Find installer at:{C['reset']}
        dist/SentinelNet_v2_Setup.exe

  To test portable version right now:
  {C['yellow']}  dist\\SentinelNet\\SentinelNet.exe{C['reset']}

{C['cyan']}{'='*58}{C['reset']}
""")


def main():
    print(f"""
{C['cyan']}{'='*58}
  SentinelNet v2.0 — Windows 64-bit Build Script
{'='*58}{C['reset']}
""")
    if not step1_check():
        err("Fix missing packages first"); sys.exit(1)
    step2_clean()
    if not step3_generate_spec():
        err("Spec generation failed"); sys.exit(1)
    if not step4_build():
        err("Build failed"); sys.exit(1)
    print_next_steps()


if __name__ == "__main__":
    main()
