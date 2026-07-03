#!/usr/bin/env bash
# Installer for CPU Control v3.5 - Linux Mint / XFCE
set -euo pipefail

INSTALL_DIR="/opt/cpu-control"
DESKTOP_DIR="/usr/share/applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== CPU Control v3.5 installer =="

# --- Basic tool checks (run before any sudo re-exec so failures are clear) ---
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found. Please install Python 3.6+ and re-run this script."
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "This step needs sudo to install into $INSTALL_DIR, install dependencies,"
    echo "and register the app menu entry."
    exec sudo bash "$0" "$@"
fi

# --- System packages (apt) ---
# PyGObject needs the actual GTK3 introspection libs; these only come from
# apt, not pip, so we always make sure they're present first.
NEED_APT=0
python3 -c "import gi; gi.require_version('Gtk','3.0'); from gi.repository import Gtk" 2>/dev/null || NEED_APT=1
command -v pkexec >/dev/null 2>&1 || NEED_APT=1
command -v pip3 >/dev/null 2>&1 || NEED_APT=1

if [[ $NEED_APT -eq 1 ]]; then
    echo "Installing system dependencies (python3-gi, GTK3, PolicyKit, pip)..."
    apt-get update -y
    apt-get install -y python3-gi gir1.2-gtk-3.0 policykit-1 python3-pip
fi

# --- Python packages (pip, via requirements.txt) ---
if [[ -f "$SCRIPT_DIR/requirements.txt" ]]; then
    echo "Checking Python package requirements..."
    python3 -m pip install --break-system-packages -r "$SCRIPT_DIR/requirements.txt" \
        || pip3 install -r "$SCRIPT_DIR/requirements.txt" \
        || echo "WARNING: pip install had issues; will still verify below."
else
    echo "WARNING: requirements.txt not found next to install.sh, skipping pip step."
fi

# --- Final verification: make sure everything actually works ---
echo "Verifying dependencies..."
MISSING=0

if ! python3 -c "import gi; gi.require_version('Gtk','3.0'); from gi.repository import Gtk" 2>/dev/null; then
    echo "  [MISSING] GTK3 / PyGObject (gi) is still not importable."
    MISSING=1
else
    echo "  [OK] GTK3 / PyGObject"
fi

if ! command -v pkexec >/dev/null 2>&1; then
    echo "  [MISSING] pkexec (PolicyKit) not found."
    MISSING=1
else
    echo "  [OK] PolicyKit (pkexec)"
fi

if command -v sensors >/dev/null 2>&1; then
    echo "  [OK] lm-sensors (optional)"
else
    echo "  [INFO] lm-sensors not found (optional, better temp readings)"
fi

if command -v cpupower >/dev/null 2>&1; then
    echo "  [OK] cpupower (optional)"
else
    echo "  [INFO] cpupower not found (optional, deeper CPU info)"
fi

if [[ $MISSING -eq 1 ]]; then
    echo ""
    echo "ERROR: one or more required dependencies are missing. Aborting install."
    echo "Try running: sudo apt-get install python3-gi gir1.2-gtk-3.0 policykit-1"
    exit 1
fi

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/cpu_ctrl_v3_5.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/cpu_ctrl_helper" "$INSTALL_DIR/"
[[ -f "$SCRIPT_DIR/requirements.txt" ]] && cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
chmod 755 "$INSTALL_DIR/cpu_ctrl_v3_5.py"
chmod 755 "$INSTALL_DIR/cpu_ctrl_helper"

sed "s|Exec=.*|Exec=python3 $INSTALL_DIR/cpu_ctrl_v3_5.py|" \
    "$SCRIPT_DIR/cpu-control.desktop" > "$DESKTOP_DIR/cpu-control.desktop"
chmod 644 "$DESKTOP_DIR/cpu-control.desktop"

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

echo "Done. Find 'CPU Control' in your XFCE application menu (System category),"
echo "or launch it directly with:  python3 $INSTALL_DIR/cpu_ctrl_v3_5.py"
