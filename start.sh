#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════
#  SentinelNet v2.0 — Universal Start Script
#  Works on: Linux · macOS · Windows (Git Bash / WSL)
# ══════════════════════════════════════════════════════════

CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║   SENTINELNET v2.0  —  AMACDF Production            ║"
echo "  ║   DQN · Federated Learning · SHAP-XAI               ║"
echo "  ║   Deepfake · Phishing · Network · Voice Detection    ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Detect OS ─────────────────────────────────────────────
OS_TYPE="$(uname -s 2>/dev/null || echo Windows)"
case "$OS_TYPE" in
    Linux*)   PLATFORM="Linux"  ;;
    Darwin*)  PLATFORM="macOS"  ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows" ;;
    *)        PLATFORM="Unknown" ;;
esac
echo -e "  ${CYAN}Platform: ${PLATFORM}${NC}"

# ── Find correct Python command ───────────────────────────
PYTHON_CMD=""
for cmd in python3 python python3.12 python3.11 python3.10 python3.9 python3.8; do
    if command -v "$cmd" &>/dev/null; then
        VER=$($cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
        MAJOR=$(echo "$VER" | cut -d. -f1)
        MINOR=$(echo "$VER" | cut -d. -f2)
        if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 8 ] 2>/dev/null; then
            PYTHON_CMD="$cmd"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}[ERROR] Python 3.8+ not found.${NC}"
    echo "  Download from: https://python.org"
    exit 1
fi
echo -e "  ${GREEN}[OK]${NC} Python: $($PYTHON_CMD --version)"

# ── Check admin/root for live capture ─────────────────────
LIVE_CAPTURE=false
if [ "$PLATFORM" = "macOS" ]; then
    if [ "$EUID" -eq 0 ] 2>/dev/null || [ "$(id -u)" = "0" ]; then
        LIVE_CAPTURE=true
        echo -e "  ${GREEN}[OK]${NC} Running as root — LIVE packet capture enabled"
    else
        # Check /dev/bpf* permission
        if ls /dev/bpf* &>/dev/null && [ -r /dev/bpf0 ] 2>/dev/null; then
            LIVE_CAPTURE=true
            echo -e "  ${GREEN}[OK]${NC} /dev/bpf* readable — LIVE packet capture enabled"
        else
            echo -e "  ${YELLOW}[!]${NC} Not root — SYNTHETIC mode"
            echo "      For LIVE capture, choose one:"
            echo "        Option A: sudo ./start.sh"
            echo "        Option B: sudo chmod +r /dev/bpf*"
        fi
    fi

elif [ "$PLATFORM" = "Linux" ]; then
    if [ "$EUID" -eq 0 ] 2>/dev/null || [ "$(id -u)" = "0" ]; then
        LIVE_CAPTURE=true
        echo -e "  ${GREEN}[OK]${NC} Running as root — LIVE packet capture enabled"
    else
        # Check setcap
        SETCAP_OK=false
        if command -v getcap &>/dev/null; then
            if getcap "$($PYTHON_CMD -c 'import sys;print(sys.executable)')" 2>/dev/null | grep -q cap_net_raw; then
                SETCAP_OK=true
            fi
        fi
        if $SETCAP_OK; then
            LIVE_CAPTURE=true
            echo -e "  ${GREEN}[OK]${NC} cap_net_raw set — LIVE packet capture enabled"
        else
            echo -e "  ${YELLOW}[!]${NC} Not root — SYNTHETIC mode"
            echo "      For LIVE capture, choose one:"
            PM=""
            for p in apt dnf yum pacman; do
                if command -v $p &>/dev/null; then PM=$p; break; fi
            done
            if [ "$PM" = "apt" ]; then
                echo "        sudo apt install -y libpcap-dev tcpdump"
            elif [ "$PM" = "dnf" ] || [ "$PM" = "yum" ]; then
                echo "        sudo $PM install -y libpcap-devel tcpdump"
            elif [ "$PM" = "pacman" ]; then
                echo "        sudo pacman -S libpcap"
            fi
            echo "        sudo ./start.sh"
            echo "      OR (persistent, no sudo needed after):"
            echo "        sudo setcap cap_net_raw+eip \$($PYTHON_CMD -c 'import sys;print(sys.executable)')"
        fi
    fi

elif [ "$PLATFORM" = "Windows" ]; then
    echo -e "  ${YELLOW}[!]${NC} Windows detected — use START_WINDOWS.bat for best experience"
fi

echo ""

# ── Setup virtual environment ─────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "venv" ]; then
    echo "[*] Creating virtual environment..."
    $PYTHON_CMD -m venv venv
fi

# Activate venv
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
elif [ -f "venv/Scripts/activate" ]; then
    source venv/Scripts/activate
fi

echo "[*] Installing / verifying dependencies..."
pip install -r requirements.txt -q --no-warn-script-location

# ── Set correct permissions on sensitive files ─────────────
if [ "$PLATFORM" != "Windows" ]; then
    [ -f "certs/sentinelnet.key" ] && chmod 600 certs/sentinelnet.key
    [ -f "data/email_accounts.json" ] && chmod 600 data/email_accounts.json
fi

# Make start.sh itself executable for future runs
chmod +x "$0" 2>/dev/null

echo ""
echo -e "  ${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "  ${GREEN}║   Starting SentinelNet v2.0...                       ║${NC}"
if $LIVE_CAPTURE; then
echo -e "  ${GREEN}║   Mode: LIVE packet capture  ✅                       ║${NC}"
else
echo -e "  ${YELLOW}║   Mode: SYNTHETIC (realistic simulation)  ⚠️           ║${NC}"
fi
echo -e "  ${GREEN}║   Dashboard : http://localhost:8000                  ║${NC}"
echo -e "  ${GREEN}║   API Docs  : http://localhost:8000/docs             ║${NC}"
echo -e "  ${GREEN}║   Press Ctrl+C to stop                               ║${NC}"
echo -e "  ${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Open browser after 3 seconds ──────────────────────────
(sleep 3 && (
    if [ "$PLATFORM" = "macOS" ]; then
        open http://localhost:8000 2>/dev/null
    elif [ "$PLATFORM" = "Linux" ]; then
        xdg-open http://localhost:8000 2>/dev/null &
    fi
)) &

# ── Start the server ───────────────────────────────────────
cd backend
$PYTHON_CMD main.py
