# Installation & Deployment Guide: Clean MT7601U Production Driver

Follow these steps on the physical Radxa Cubie A7Z.

---

## 1. Backup Existing Module
```bash
TARGET_DIR="/lib/modules/$(uname -r)/extra"
sudo mkdir -p "${TARGET_DIR}"
[ -f "${TARGET_DIR}/mt7601u.ko" ] && sudo cp "${TARGET_DIR}/mt7601u.ko" "${TARGET_DIR}/mt7601u.ko.diag_backup"
```

---

## 2. Install Clean Production `.ko`
```bash
sudo cp driver/mt7601u.ko "${TARGET_DIR}/mt7601u.ko"
sudo depmod -a
```

---

## 3. Reload Driver & Verify
```bash
sudo modprobe -r mt7601u
sudo modprobe mt7601u

# Plug in MT7601U adapter
# Inspect logs:
dmesg | tail -n 25
```

---

## 4. Expected Output
* Clean enumeration on `usb 3-1` (`148f:7601`).
* `mt7601u` binds without `-71` / `-110` errors or timeouts.
* `wlan1: renamed from wlan0` appears.
* No verbose `[DIAG-MCU]` or `[DIAG-RXDC]` logs in dmesg.

---

## 5. Rollback Procedure
```bash
sudo modprobe -r mt7601u
sudo cp "${TARGET_DIR}/mt7601u.ko.diag_backup" "${TARGET_DIR}/mt7601u.ko"
sudo depmod -a
sudo modprobe mt7601u
```
