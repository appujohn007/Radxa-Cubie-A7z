# AIC8800 Driver Installation & Deployment Guide

## Deployment Safety Overview

This deployment is specifically designed for environments where:
- `wlan1` handles the active SSH management connection (must not be disrupted).
- `wlan0` is the target AIC8800 internal Wi-Fi interface to be set to monitor mode.

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

The script automatically:
1. Verifies kernel version compatibility.
2. Checks `wlan1` status and protects active SSH connections.
3. Validates binary checksums against `SHA256SUMS`.
4. Creates a timestamped backup in `/var/backups/aic8800-driver-<timestamp>`.
5. Installs the patched `aic8800_fdrv.ko` module and executes `depmod -a`.
6. Sets NetworkManager to unmanaged on `wlan0` so `wlan1` stays undisturbed.

---

## 2. Activating the New Driver

### Option A: Reboot (Recommended & Safest)
```bash
sudo reboot
```

### Option B: Live Module Reload
```bash
sudo ip link set wlan0 down
sudo modprobe -r aic8800_fdrv
sudo modprobe aic8800_fdrv
```

---

## 3. Real Hardware Verification Procedure

### Test 1: Verify Pre-Conditions
```bash
echo "$SSH_CONNECTION"
ip -br addr
iw dev
```
Confirm that SSH enters through `wlan1`.

### Test 2: Switch wlan0 to Monitor Mode
```bash
sudo ip link set wlan0 down
sudo iw dev wlan0 set type monitor
sudo ip link set wlan0 up
```

### Test 3: Verify Interface State
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
    channel <ch>
```
Confirm `wlan1` remains connected and active in managed mode.

### Test 4: Verify Monitor Packet Capture (RX)
```bash
sudo tcpdump -i wlan0 -e -n -c 20
```

### Test 5: Verify Monitor Injection (TX)
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
