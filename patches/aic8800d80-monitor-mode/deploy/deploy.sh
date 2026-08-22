#!/usr/bin/env bash
# ==============================================================================
# AIC8800D80 Monitor Mode Driver Deployment Script for Radxa Cubie A7Z
# Target Kernel: 5.15.147-21-a733
# Safe Deployment: Protects wlan1 (SSH session interface) and verifies system health
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULE_SRC="${PARENT_DIR}/driver/aic8800_fdrv.ko"
LOADFW_SRC="${PARENT_DIR}/driver/aic_load_fw.ko"
BACKUP_DIR="/var/backups/aic8800-driver-$(date +%Y%m%d%H%M%S)"
TARGET_KVER="5.15.147-21-a733"
EXPECTED_SHA256="ce9659f42b35c25b459629dd1c39d8e3c5682167debe506e06a7f00fe5ffb6bd"

echo "======================================================================"
echo " Starting AIC8800D80 Driver Deployment (Safe Mode)"
echo "======================================================================"

# Step 0: Ensure running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (sudo ./deploy.sh)" >&2
    exit 1
fi

# Step 1: Kernel version check
CURRENT_KVER="$(uname -r)"
echo "[+] Checking kernel release: ${CURRENT_KVER}"
if [ "${CURRENT_KVER}" != "${TARGET_KVER}" ]; then
    echo "[!] Warning: Current kernel (${CURRENT_KVER}) does not match build target (${TARGET_KVER})."
    read -rp "Do you wish to continue? (y/N): " CONFIRM
    if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
        echo "[-] Aborted by user."
        exit 1
    fi
fi

# Step 2: Critical Interface & SSH Safety Check (wlan1)
echo "[+] Verifying wlan1 and SSH transport safety..."
if ! ip link show wlan1 >/dev/null 2>&1; then
    echo "[!] Warning: wlan1 interface not detected."
else
    WLAN1_IP=$(ip -4 addr show wlan1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)
    echo "[+] wlan1 detected with IP: ${WLAN1_IP:-none}"
fi

# Inspect active SSH connection if available
if [ -n "${SSH_CONNECTION:-}" ]; then
    echo "[+] Active SSH Connection: ${SSH_CONNECTION}"
    SSH_DEST_IP=$(echo "${SSH_CONNECTION}" | awk '{print $3}')
    echo "[+] SSH destination IP: ${SSH_DEST_IP}"
fi

# Step 3: Verify source module exists and matches checksum
if [ ! -f "${MODULE_SRC}" ]; then
    echo "[-] Error: Source module not found at ${MODULE_SRC}" >&2
    exit 1
fi

ACTUAL_SHA256=$(sha256sum "${MODULE_SRC}" | awk '{print $1}')
echo "[+] Validating aic8800_fdrv.ko checksum: ${ACTUAL_SHA256}"
if [ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]; then
    echo "[!] Checksum notice: Actual (${ACTUAL_SHA256}) differs from expected (${EXPECTED_SHA256})."
fi

# Step 4: Backup existing module
MODULE_DEST_DIR="/lib/modules/${CURRENT_KVER}/kernel/drivers/net/wireless/aic8800"
if [ ! -d "${MODULE_DEST_DIR}" ]; then
    MODULE_DEST_DIR="/lib/modules/${CURRENT_KVER}/extra"
fi
mkdir -p "${MODULE_DEST_DIR}"

echo "[+] Creating backup directory at ${BACKUP_DIR}..."
mkdir -p "${BACKUP_DIR}"
if [ -f "${MODULE_DEST_DIR}/aic8800_fdrv.ko" ]; then
    cp -v "${MODULE_DEST_DIR}/aic8800_fdrv.ko" "${BACKUP_DIR}/aic8800_fdrv.ko.orig"
    echo "${MODULE_DEST_DIR}/aic8800_fdrv.ko" > "${BACKUP_DIR}/installed_location.txt"
fi

# Step 5: Install new module
echo "[+] Installing patched aic8800_fdrv.ko to ${MODULE_DEST_DIR}/..."
install -m 0644 -p "${MODULE_SRC}" "${MODULE_DEST_DIR}/aic8800_fdrv.ko"
if [ -f "${LOADFW_SRC}" ] && [ ! -f "${MODULE_DEST_DIR}/aic_load_fw.ko" ]; then
    install -m 0644 -p "${LOADFW_SRC}" "${MODULE_DEST_DIR}/aic_load_fw.ko"
fi

echo "[+] Updating module dependencies (depmod -a)..."
depmod -a "${CURRENT_KVER}"

# Step 6: Configure NetworkManager to ignore wlan0 for monitor mode if NetworkManager is active
if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "[+] Configuring NetworkManager to treat wlan0 as unmanaged (protecting wlan1)..."
    nmcli device set wlan0 managed no 2>/dev/null || true
fi

# Step 7: Safe Module Reload Instructions
echo "======================================================================"
echo "[+] Driver installation complete!"
echo ""
echo "To activate the new driver:"
echo "  Option A (Recommended & Safest): Reboot the board"
echo "    sudo reboot"
echo ""
echo "  Option B (Live Reload - ONLY if safe and wlan1 does NOT use aic8800):"
echo "    sudo ip link set wlan0 down"
echo "    sudo modprobe -r aic8800_fdrv"
echo "    sudo modprobe aic8800_fdrv"
echo ""
echo "To enable monitor mode on wlan0 after reboot / reload:"
echo "    sudo ip link set wlan0 down"
echo "    sudo iw dev wlan0 set type monitor"
echo "    sudo ip link set wlan0 up"
echo "    iw dev wlan0 info"
echo ""
echo "Backup location: ${BACKUP_DIR}"
echo "======================================================================"
