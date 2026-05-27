"""
SentinelNet v2.0 — Auto Updater
================================
Checks GitHub for new releases and downloads/applies
updates silently in the background.

Called from sentinelnet_tray.py on startup
and from the tray menu "Check for Updates".
"""

import os
import sys
import json
import time
import shutil
import hashlib
import logging
import threading
import subprocess
import urllib.request
import urllib.error
from pathlib import Path

log = logging.getLogger("SentinelNet.Updater")

BASE_DIR        = Path(__file__).parent.resolve()
CURRENT_VERSION = "2.0.0"
UPDATE_URL      = "https://api.github.com/repos/sentinelnet/sentinelnet/releases/latest"
UPDATE_CACHE    = BASE_DIR / "data" / "update_cache.json"
CHECK_INTERVAL  = 86400   # check once per day


# ══════════════════════════════════════════════════════════
# VERSION HELPERS
# ══════════════════════════════════════════════════════════

def parse_version(v: str) -> tuple:
    """Parse version string into comparable tuple."""
    v = v.strip().lstrip("v")
    try:
        parts = v.split(".")
        return tuple(int(x) for x in parts)
    except Exception:
        return (0, 0, 0)


def is_newer(remote_version: str, local_version: str = CURRENT_VERSION) -> bool:
    """Return True if remote_version > local_version."""
    return parse_version(remote_version) > parse_version(local_version)


# ══════════════════════════════════════════════════════════
# UPDATE CHECKER
# ══════════════════════════════════════════════════════════

class UpdateChecker:

    def __init__(self, on_update_available=None):
        """
        on_update_available: callback(version, download_url, notes)
        Called when a newer version is found.
        """
        self.on_update_available = on_update_available
        self._checking = False

    def should_check(self) -> bool:
        """Return True if enough time has passed since last check."""
        try:
            if UPDATE_CACHE.exists():
                cache = json.loads(UPDATE_CACHE.read_text())
                last  = cache.get("last_checked", 0)
                if time.time() - last < CHECK_INTERVAL:
                    return False
        except Exception:
            pass
        return True

    def check_now(self, force: bool = False) -> dict:
        """
        Check for updates. Returns dict with result.
        force=True: ignore time cache, check anyway.
        """
        if self._checking:
            return {"status": "already_checking"}

        if not force and not self.should_check():
            # Return cached result
            try:
                cache = json.loads(UPDATE_CACHE.read_text())
                return cache.get("last_result", {"status": "up_to_date"})
            except Exception:
                pass

        self._checking = True
        result = {"status": "unknown"}

        try:
            req = urllib.request.Request(
                UPDATE_URL,
                headers={
                    "User-Agent": f"SentinelNet/{CURRENT_VERSION}",
                    "Accept":     "application/vnd.github.v3+json",
                }
            )
            with urllib.request.urlopen(req, timeout=10) as r:
                data = json.loads(r.read().decode())

            latest_version = data.get("tag_name", "").lstrip("v")
            release_notes  = data.get("body", "")[:500]
            assets         = data.get("assets", [])

            # Find Windows x64 installer asset
            download_url = None
            for asset in assets:
                name = asset.get("name", "").lower()
                if "setup" in name and "x64" in name and name.endswith(".exe"):
                    download_url = asset.get("browser_download_url")
                    break
                elif "setup" in name and name.endswith(".exe"):
                    download_url = asset.get("browser_download_url")

            if is_newer(latest_version):
                result = {
                    "status":        "update_available",
                    "current":       CURRENT_VERSION,
                    "latest":        latest_version,
                    "download_url":  download_url,
                    "release_notes": release_notes,
                    "release_url":   data.get("html_url", ""),
                }
                if self.on_update_available:
                    self.on_update_available(
                        latest_version,
                        download_url,
                        release_notes
                    )
            else:
                result = {
                    "status":   "up_to_date",
                    "current":  CURRENT_VERSION,
                    "latest":   latest_version,
                }

        except urllib.error.URLError:
            result = {"status": "no_connection"}
        except Exception as e:
            result = {"status": "error", "message": str(e)}
            log.error(f"Update check failed: {e}")

        finally:
            self._checking = False

        # Cache the result
        try:
            UPDATE_CACHE.parent.mkdir(parents=True, exist_ok=True)
            cache_data = {
                "last_checked": time.time(),
                "last_result":  result,
            }
            UPDATE_CACHE.write_text(
                json.dumps(cache_data, indent=2)
            )
        except Exception:
            pass

        return result

    def check_background(self, force: bool = False):
        """Run check in background thread — non-blocking."""
        t = threading.Thread(
            target=self.check_now,
            args=(force,),
            daemon=True
        )
        t.start()
        return t


# ══════════════════════════════════════════════════════════
# DOWNLOADER + APPLIER
# ══════════════════════════════════════════════════════════

class UpdateDownloader:

    def __init__(self, on_progress=None, on_complete=None):
        """
        on_progress: callback(percent: int)
        on_complete: callback(success: bool, path: str)
        """
        self.on_progress = on_progress
        self.on_complete = on_complete

    def download(self, url: str, dest: Path) -> bool:
        """Download update installer to dest path."""
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)

            req = urllib.request.Request(
                url,
                headers={"User-Agent": f"SentinelNet/{CURRENT_VERSION}"}
            )
            with urllib.request.urlopen(req, timeout=60) as r:
                total = int(r.headers.get("Content-Length", 0))
                downloaded = 0
                chunk_size = 65536  # 64KB chunks

                with open(dest, "wb") as f:
                    while True:
                        chunk = r.read(chunk_size)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total > 0 and self.on_progress:
                            pct = int(downloaded * 100 / total)
                            self.on_progress(pct)

            if self.on_complete:
                self.on_complete(True, str(dest))
            return True

        except Exception as e:
            log.error(f"Download failed: {e}")
            if self.on_complete:
                self.on_complete(False, "")
            return False

    def verify_checksum(self, path: Path,
                        expected_sha256: str) -> bool:
        """Verify downloaded file matches expected hash."""
        try:
            sha256 = hashlib.sha256()
            with open(path, "rb") as f:
                for chunk in iter(lambda: f.read(65536), b""):
                    sha256.update(chunk)
            actual = sha256.hexdigest().lower()
            return actual == expected_sha256.lower()
        except Exception:
            return False

    def apply_update(self, installer_path: Path) -> bool:
        """
        Launch the new installer, which will:
        1. Stop the running SentinelNet instance
        2. Install the new version over the existing
        3. Restart SentinelNet
        """
        try:
            if not installer_path.exists():
                log.error(f"Installer not found: {installer_path}")
                return False

            # Launch installer (elevated, silent mode)
            subprocess.Popen(
                [
                    str(installer_path),
                    "/SILENT",           # silent install
                    "/NORESTART",        # don't restart Windows
                    "/CLOSEAPPLICATIONS",# close running instance
                ],
                creationflags=subprocess.DETACHED_PROCESS,
            )
            log.info(f"Update installer launched: {installer_path}")

            # Give installer 2 seconds to start then exit
            time.sleep(2)
            sys.exit(0)

        except Exception as e:
            log.error(f"Failed to apply update: {e}")
            return False


# ══════════════════════════════════════════════════════════
# CONVENIENCE — startup check
# ══════════════════════════════════════════════════════════

def check_on_startup(notify_callback=None):
    """
    Called once on startup. Checks for updates in background.
    notify_callback(version, url, notes): called if update found.
    """
    def _on_update(version, url, notes):
        log.info(f"Update available: v{version}")
        if notify_callback:
            notify_callback(version, url, notes)

    checker = UpdateChecker(on_update_available=_on_update)
    checker.check_background(force=False)
