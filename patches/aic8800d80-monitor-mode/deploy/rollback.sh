#!/usr/bin/env bash
# ==============================================================================
# AIC8800D80 Driver Rollback Script for Radxa Cubie A7Z
# Restores original stock driver from backup
# ==============================================================================

set -euo pipefail

echo "======================================================================"
echo " Starting AIC8800D80 Driver Rollback"
echo "======================================================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This script must be run as root (sudo ./rollback.sh)" >&2
    exit 1
fi

LATEST_BACKUP=$(ls -td /var/backups/aic8800-driver-* 2>/dev/null | head -n 1 || true)
if [ -z "${LATEST_BACKUP}" ] || [ ! -f "${LATEST_BACKUP}/aic8800_fdrv.ko.orig" ]; then
    echo "[-] Error: No valid backup found in /var/backups/aic8800-driver-*" >&2
    exit 1
fi

echo "[+] Found backup at ${LATEST_BACKUP}..."

TARGET_LOCATION=$(cat "${LATEST_BACKUP}/installed_location.txt" 2>/dev/null || true)
if [ -z "${TARGET_LOCATION}" ]; then
    TARGET_LOCATION="/lib/modules/$(uname -r)/kernel/drivers/net/wireless/aic8800/aic8800_fdrv.ko"
fi

echo "[+] Restoring ${TARGET_LOCATION} from backup..."
cp -v "${LATEST_BACKUP}/aic8800_fdrv.ko.orig" "${TARGET_LOCATION}"
depmod -a "$(uname -r)"

echo "[+] Rollback complete. Reboot or reload the driver module to apply."
echo "======================================================================"
