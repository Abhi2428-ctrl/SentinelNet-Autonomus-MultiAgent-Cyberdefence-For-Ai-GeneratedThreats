"""
SentinelNet v2.0 — Windows System Tray Application
====================================================
Main entry point for Windows installer users.
No terminal shown. Everything via system tray icon.

Tray icon shows:
  Cyan    = Running fine
  Yellow  = Warning / starting
  Red     = Critical threats detected
  Gray    = Stopped

Right-click tray icon to:
  Open dashboard, start/stop, check threats,
  toggle startup-with-Windows, update, quit.
"""

import os
import sys
import time
import threading
import subprocess
import webbrowser
import json
import logging
import queue
from pathlib import Path

# ── Resolve base directory ────────────────────────────────
# Works both when run as .py and as PyInstaller .exe
if getattr(sys, "frozen", False):
    BASE_DIR = Path(sys.executable).parent.resolve()
else:
    BASE_DIR = Path(__file__).parent.resolve()

sys.path.insert(0, str(BASE_DIR))

# ── Logging ───────────────────────────────────────────────
LOG_DIR = BASE_DIR / "logs" / "system"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    filename=str(LOG_DIR / "sentinelnet_tray.log"),
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("SentinelNet.Tray")

# ── Tray library ──────────────────────────────────────────
try:
    import pystray
    from pystray import MenuItem as item, Menu
    from PIL import Image, ImageDraw, ImageFont
    TRAY_OK = True
except ImportError as e:
    TRAY_OK = False
    log.error(f"Tray libraries missing: {e}")

# ── Windows toast notifications ───────────────────────────
try:
    from win10toast import ToastNotifier
    _toaster = ToastNotifier()
    TOAST_OK = True
except ImportError:
    TOAST_OK = False
    _toaster = None

# ── Auto updater ──────────────────────────────────────────
try:
    from auto_updater import check_on_startup, UpdateDownloader
    UPDATER_OK = True
except ImportError:
    UPDATER_OK = False

DASHBOARD_URL = "http://localhost:8000"
APP_NAME      = "SentinelNet v2.0"
VERSION       = "2.0.0"


# ══════════════════════════════════════════════════════════
# ICON GENERATOR
# ══════════════════════════════════════════════════════════

def _make_icon(color_accent: str, color_bg: str) -> "Image.Image":
    sz   = 64
    img  = Image.new("RGBA", (sz, sz), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([2,2,62,62], fill=color_bg,
                 outline=color_accent, width=3)
    shield = [(32,10),(52,18),(52,34),(32,56),(12,34),(12,18)]
    draw.polygon(shield, fill=color_accent)
    inner  = [(32,16),(47,22),(47,33),(32,50),(17,33),(17,22)]
    draw.polygon(inner, fill=color_bg)
    try:
        font = ImageFont.truetype("arial.ttf", 20)
    except Exception:
        font = ImageFont.load_default()
    draw.text((24, 20), "S", fill=color_accent, font=font)
    return img

ICONS = {
    "running":  _make_icon("#00f5ff", "#020b14"),
    "warning":  _make_icon("#ffd60a", "#1a1200"),
    "critical": _make_icon("#ff2d55", "#1a0010"),
    "stopped":  _make_icon("#4a7a99", "#050f1c"),
}


# ══════════════════════════════════════════════════════════
# NOTIFICATION
# ══════════════════════════════════════════════════════════

def notify(title: str, msg: str, duration: int = 5):
    log.info(f"[NOTIFY] {title}: {msg}")
    if TOAST_OK and _toaster:
        try:
            _toaster.show_toast(title, msg,
                                duration=duration,
                                threaded=True)
        except Exception:
            pass


# ══════════════════════════════════════════════════════════
# SERVER MANAGER
# ══════════════════════════════════════════════════════════

class Server:
    """Manages the FastAPI backend subprocess."""

    def __init__(self):
        self.proc    = None
        self.running = False
        self.started = None
        self.stats   = {
            "status":        "stopped",
            "threats_today": 0,
            "capture_mode":  "SYNTHETIC",
            "agents":        0,
        }

    def start(self) -> bool:
        if self.running and self._alive():
            return True
        main_py = BASE_DIR / "backend" / "main.py"
        if not main_py.exists():
            log.error(f"main.py not found: {main_py}")
            return False
        try:
            self.proc = subprocess.Popen(
                [sys.executable, str(main_py)],
                cwd=str(BASE_DIR),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            self.running = True
            self.started = time.time()
            self.stats["status"] = "starting"
            log.info(f"Server started PID={self.proc.pid}")
            threading.Thread(target=self._wait_ready,
                             daemon=True).start()
            return True
        except Exception as e:
            log.error(f"Server start failed: {e}")
            return False

    def _wait_ready(self):
        import socket
        for _ in range(40):
            try:
                s = socket.socket()
                s.settimeout(1)
                if s.connect_ex(("127.0.0.1", 8000)) == 0:
                    s.close()
                    self.stats["status"] = "running"
                    log.info("Server ready on :8000")
                    return
                s.close()
            except Exception:
                pass
            time.sleep(1)
        log.warning("Server did not respond in 40s")

    def stop(self):
        if self.proc:
            try:
                self.proc.terminate()
                self.proc.wait(timeout=5)
            except Exception:
                try: self.proc.kill()
                except Exception: pass
            self.proc = None
        self.running = False
        self.stats["status"] = "stopped"
        log.info("Server stopped")

    def restart(self):
        self.stop(); time.sleep(1); self.start()

    def _alive(self) -> bool:
        return self.proc is not None and self.proc.poll() is None

    def uptime_str(self) -> str:
        if not self.started: return "—"
        s = int(time.time() - self.started)
        if s > 3600:   return f"{s//3600}h {(s%3600)//60}m"
        elif s > 60:   return f"{s//60}m {s%60}s"
        else:          return f"{s}s"

    def poll_stats(self):
        """Fetch live stats from API (non-blocking)."""
        try:
            import urllib.request
            with urllib.request.urlopen(
                "http://127.0.0.1:8000/api/dashboard",
                timeout=2
            ) as r:
                d = json.loads(r.read())
                self.stats.update({
                    "threats_today": d.get("total_threats", 0),
                    "capture_mode":  d.get("capture_mode", "SYNTHETIC"),
                    "agents":        sum(
                        1 for a in d.get("agents", {}).values()
                        if a.get("active")
                    ),
                })
        except Exception:
            pass


# ══════════════════════════════════════════════════════════
# WINDOWS STARTUP REGISTRY
# ══════════════════════════════════════════════════════════

_REG_RUN = r"Software\Microsoft\Windows\CurrentVersion\Run"

def startup_enabled() -> bool:
    try:
        import winreg
        k = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _REG_RUN,
                           0, winreg.KEY_READ)
        winreg.QueryValueEx(k, "SentinelNet")
        winreg.CloseKey(k)
        return True
    except Exception:
        return False

def startup_enable():
    try:
        import winreg
        exe = (str(BASE_DIR / "SentinelNet.exe")
               if getattr(sys, "frozen", False)
               else f'"{sys.executable}" "{BASE_DIR / "sentinelnet_tray.py"}"')
        k = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _REG_RUN,
                           0, winreg.KEY_SET_VALUE)
        winreg.SetValueEx(k, "SentinelNet", 0,
                          winreg.REG_SZ, exe)
        winreg.CloseKey(k)
    except Exception as e:
        log.error(f"startup_enable: {e}")

def startup_disable():
    try:
        import winreg
        k = winreg.OpenKey(winreg.HKEY_CURRENT_USER, _REG_RUN,
                           0, winreg.KEY_SET_VALUE)
        winreg.DeleteValue(k, "SentinelNet")
        winreg.CloseKey(k)
    except Exception:
        pass


# ══════════════════════════════════════════════════════════
# TRAY APPLICATION
# ══════════════════════════════════════════════════════════

class TrayApp:

    def __init__(self):
        self.srv  = Server()
        self.tray = None
        self._icon_key = "stopped"

    # ── Menu builder ──────────────────────────────────────
    def _menu(self):
        s      = self.srv.stats
        alive  = self.srv._alive()
        status = {
            "running":  "● RUNNING",
            "starting": "◌ STARTING...",
            "stopped":  "○ STOPPED",
        }.get(s["status"], s["status"].upper())

        return Menu(
            item(f"🛡️  {APP_NAME}",         None, enabled=False),
            item(f"   {status}",            None, enabled=False),
            Menu.SEPARATOR,
            item("📊  Open Dashboard",      self._open_dash),
            Menu.SEPARATOR,
            item(f"📡  {s['capture_mode']} mode",
                                            None, enabled=False),
            item(f"🔴  Threats today: {s['threats_today']}",
                                            None, enabled=False),
            item(f"🤖  Agents: {s['agents']}/4",
                                            None, enabled=False),
            item(f"⏱️   Uptime: {self.srv.uptime_str()}",
                                            None, enabled=False),
            Menu.SEPARATOR,
            item("▶  Start",   self._start,   enabled=not alive),
            item("⟳  Restart", self._restart, enabled=alive),
            item("⏹  Stop",    self._stop,    enabled=alive),
            Menu.SEPARATOR,
            item("🔄  Start with Windows",
                 self._toggle_startup,
                 checked=lambda _: startup_enabled()),
            item("🔍  Check for Updates",   self._update),
            item("📋  View Logs",           self._logs),
            Menu.SEPARATOR,
            item("✕  Quit",                self._quit),
        )

    # ── Actions ───────────────────────────────────────────
    def _open_dash(self, *_):
        webbrowser.open(DASHBOARD_URL)

    def _start(self, *_):
        notify(APP_NAME, "Starting SentinelNet...")
        threading.Thread(target=self.srv.start, daemon=True).start()

    def _stop(self, *_):
        self.srv.stop()
        self._set_icon("stopped")
        notify(APP_NAME, "SentinelNet stopped.")

    def _restart(self, *_):
        notify(APP_NAME, "Restarting...")
        threading.Thread(target=self.srv.restart, daemon=True).start()

    def _toggle_startup(self, *_):
        if startup_enabled():
            startup_disable()
            notify(APP_NAME, "Removed from Windows startup.")
        else:
            startup_enable()
            notify(APP_NAME, "Will now start with Windows.")

    def _update(self, *_):
        if not UPDATER_OK:
            notify(APP_NAME, "Updater not available.")
            return
        notify(APP_NAME, "Checking for updates...")
        def _check():
            from auto_updater import UpdateChecker
            def _found(ver, url, notes):
                notify(APP_NAME,
                       f"Update v{ver} available!\n"
                       f"Click dashboard → About to download.",
                       duration=10)
            checker = UpdateChecker(on_update_available=_found)
            result  = checker.check_now(force=True)
            if result.get("status") == "up_to_date":
                notify(APP_NAME, f"Already on latest version (v{VERSION}).")
        threading.Thread(target=_check, daemon=True).start()

    def _logs(self, *_):
        try:
            os.startfile(str(LOG_DIR))
        except Exception:
            pass

    def _quit(self, *_):
        self.srv.stop()
        if self.tray:
            self.tray.stop()

    # ── Icon updater ──────────────────────────────────────
    def _set_icon(self, key: str):
        if key != self._icon_key and self.tray:
            self.tray.icon  = ICONS.get(key, ICONS["stopped"])
            self.tray.title = f"{APP_NAME} — {key.upper()}"
            self._icon_key  = key
        if self.tray:
            self.tray.menu = self._menu()

    # ── Background monitor ────────────────────────────────
    def _monitor(self):
        """Poll server health and stats every 5 seconds."""
        while True:
            try:
                if self.srv._alive():
                    self.srv.poll_stats()
                    threats = self.srv.stats.get("threats_today", 0)
                    status  = self.srv.stats.get("status", "stopped")
                    if status == "running" and threats > 100:
                        self._set_icon("critical")
                    elif status == "running":
                        self._set_icon("running")
                    else:
                        self._set_icon("warning")
                else:
                    if self.srv.running:
                        # Died unexpectedly — restart
                        log.warning("Server died — restarting")
                        self.srv.running = False
                        notify(APP_NAME,
                               "⚠️ Server stopped unexpectedly. Restarting...")
                        time.sleep(3)
                        self.srv.start()
                    self._set_icon("stopped")
            except Exception as e:
                log.error(f"Monitor error: {e}")
            time.sleep(5)

    # ── Entry point ───────────────────────────────────────
    def run(self):
        if not TRAY_OK:
            log.warning("pystray unavailable — terminal fallback")
            self._terminal_fallback()
            return

        # Start server
        self.srv.start()

        # Background monitor thread
        threading.Thread(target=self._monitor, daemon=True).start()

        # Open browser after brief delay
        def _open():
            time.sleep(5)
            webbrowser.open(DASHBOARD_URL)
            notify(APP_NAME,
                   "🛡️ SentinelNet is running!\n"
                   "Dashboard: http://localhost:8000")
        threading.Thread(target=_open, daemon=True).start()

        # Check for updates in background
        if UPDATER_OK:
            def _on_update(ver, url, notes):
                notify(APP_NAME,
                       f"Update v{ver} available! "
                       f"Open tray → Check for Updates",
                       duration=10)
            check_on_startup(notify_callback=_on_update)

        # Build and run tray icon (blocks until _quit called)
        self.tray = pystray.Icon(
            name  = "SentinelNet",
            icon  = ICONS["warning"],
            title = APP_NAME,
            menu  = self._menu(),
        )
        log.info("Tray running")
        self.tray.run()

    def _terminal_fallback(self):
        """If pystray not available run as terminal app."""
        self.srv.start()
        print(f"\n{'═'*52}")
        print(f"  {APP_NAME}")
        print(f"  Dashboard : {DASHBOARD_URL}")
        print(f"  API Docs  : {DASHBOARD_URL}/docs")
        print(f"  Press Ctrl+C to stop")
        print(f"{'═'*52}\n")
        webbrowser.open(DASHBOARD_URL)
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.srv.stop()
            print("\nSentinelNet stopped.")


# ══════════════════════════════════════════════════════════
# SINGLE INSTANCE GUARD
# ══════════════════════════════════════════════════════════

def _single_instance():
    """If already running, open dashboard and exit."""
    lock = BASE_DIR / "data" / "sentinelnet.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)

    if lock.exists():
        try:
            old_pid = int(lock.read_text().strip())
            import ctypes
            h = ctypes.windll.kernel32.OpenProcess(
                0x1000, False, old_pid
            )
            if h:
                ctypes.windll.kernel32.CloseHandle(h)
                webbrowser.open(DASHBOARD_URL)
                sys.exit(0)
        except Exception:
            pass

    lock.write_text(str(os.getpid()))
    import atexit
    atexit.register(lambda: lock.unlink(missing_ok=True))


# ══════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════

def main():
    log.info(f"SentinelNet {VERSION} starting — PID {os.getpid()}")
    _single_instance()
    TrayApp().run()


if __name__ == "__main__":
    main()
