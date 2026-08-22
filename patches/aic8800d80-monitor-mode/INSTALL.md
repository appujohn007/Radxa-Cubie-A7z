# AIC8800 Driver Installation & Deployment Guide

## Deployment Safety Overview

This deployment is specifically designed for environments where:
- `wlan1` (MediaTek MT7601U) handles the active SSH management connection (`10.150.138.121:22`) and must NOT be disrupted.
- `wlan0` (AIC8800) is the target internal Wi-Fi interface to be set to monitor mode.

---

## 1. Deploying to the Radxa Cubie A7Z Board

### Step 1: Copy Deployment Package to Board
```bash
# On your local machine / host:
scp -r patches/aic8800d80-monitor-mode radxa@<board-ip>:/tmp/
```

### Step 2: Run Safe Automated Deployment
```bash
# On the Radxa board:
cd /tmp/aic8800d80-monitor-mode/deploy
sudo ./deploy.sh
```

Or install manually to the target DKMS updates directory:
```bash
sudo mkdir -p /lib/modules/5.15.147-21-a733/updates/dkms/
sudo cp /tmp/aic8800d80-monitor-mode/driver/aic8800_fdrv.ko /lib/modules/5.15.147-21-a733/updates/dkms/
sudo cp /tmp/aic8800d80-monitor-mode/driver/aic_load_fw.ko /lib/modules/5.15.147-21-a733/updates/dkms/
sudo depmod -a 5.15.147-21-a733
```

---

## 2. Activating the Patched Driver (Live Driver Swap)

The driver swap can be executed live while preserving SSH over `wlan1`:

```bash
# Verify wlan1 is your active SSH interface
echo "$SSH_CONNECTION"

# Unload stock driver
sudo rmmod aic8800_fdrv

# Load patched driver
sudo modprobe aic8800_fdrv_usb
```

Verify that `wlan0` reappears and `wlan1` remains connected.

---

## 3. Real Hardware Monitor Mode Test Procedure

### Test 1: Switch wlan0 to Monitor Mode (Verified Succeeded)
```bash
sudo ip link set wlan0 down
sudo iw dev wlan0 set type monitor
```

Verify interface type:
```bash
iw dev wlan0 info
```
Expected output:
```
Interface wlan0
    ifindex <n>
    wdev 0x...
    addr <mac>
    type monitor
    wiphy <phy>
```

> [!NOTE]
> **NetworkManager Observation**: If NetworkManager is managing `wlan0`, running `sudo ip link set wlan0 up` may trigger NetworkManager to restore managed mode and reconnect to an existing Wi-Fi profile. To prevent NetworkManager from taking over the interface, configure it as unmanaged:
> ```bash
> sudo nmcli device set wlan0 managed no
> sudo ip link set wlan0 up
> ```

### Test 2: Monitor Capture (RX) Test (Pending Live Validation)
```bash
sudo tcpdump -i wlan0 -e -n -c 20
```

### Test 3: Packet Injection (TX) Test (Pending Live Validation)
```bash
sudo aireplay-ng --test wlan0
```

---

## 4. Rollback Procedure

If needed, restore the original module at any time:
```bash
cd /tmp/aic8800d80-monitor-mode/deploy
sudo ./rollback.sh
sudo reboot
```
