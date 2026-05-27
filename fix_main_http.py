"""
SentinelNet - Quick Fix Script
Run this once in the sentinelnet2 folder to force HTTP on port 8000.
Usage: python fix_main_http.py
"""
import re
from pathlib import Path

main_py = Path(__file__).parent / "backend" / "main.py"

if not main_py.exists():
    print("ERROR: backend/main.py not found. Run from sentinelnet2 folder.")
    exit(1)

src = main_py.read_text(encoding="utf-8")
original = src

# Pattern 1: replace any uvicorn.run with ssl args
src = re.sub(
    r'uvicorn\.run\(app[^)]*ssl_keyfile[^)]*\)',
    'uvicorn.run(app, host="0.0.0.0", port=8000)',
    src, flags=re.DOTALL
)

# Pattern 2: replace any uvicorn.run with port 8443
src = re.sub(
    r'uvicorn\.run\(app[^)]*port\s*=\s*8443[^)]*\)',
    'uvicorn.run(app, host="0.0.0.0", port=8000)',
    src, flags=re.DOTALL
)

# Pattern 3: force PORT variable to 8000
src = re.sub(r'PORT\s*=\s*\d+', 'PORT = 8000', src)

# Pattern 4: remove any ssl_keyfile / ssl_certfile from uvicorn.run
src = re.sub(
    r',\s*ssl_keyfile\s*=\s*[^\s,)]+', '', src
)
src = re.sub(
    r',\s*ssl_certfile\s*=\s*[^\s,)]+', '', src
)

# Make absolutely sure the final uvicorn.run is clean
# Replace the entire __main__ block
if '__name__ == "__main__"' in src:
    # Find where __main__ block starts
    idx = src.rfind('if __name__ == "__main__"')
    if idx != -1:
        before = src[:idx]
        new_main = '''if __name__ == "__main__":
    import uvicorn

    # Try to generate TLS certs (optional - does not affect HTTP startup)
    try:
        https_manager.ensure_certificates()
    except Exception:
        pass

    print("")
    print("  =========================================================")
    print("  SentinelNet  v2.0")
    print("  =========================================================")
    print("  Dashboard : http://localhost:8000")
    print("  API Docs  : http://localhost:8000/docs")
    print("  =========================================================")
    print("")

    uvicorn.run(app, host="0.0.0.0", port=8000)
'''
        src = before + new_main

if src != original:
    # Backup old file
    backup = main_py.with_suffix(".py.bak")
    backup.write_text(original, encoding="utf-8")
    print(f"  Backup saved: {backup}")
    
    main_py.write_text(src, encoding="utf-8")
    print("  [OK] main.py patched - now uses HTTP port 8000")
else:
    print("  [OK] main.py already correct - no changes needed")

print("")
print("  Now run START_WINDOWS.bat again.")
print("  Open browser: http://localhost:8000")
