# MT7601U AP Mode - Target Deployment & Installation Guide

## 1. Prerequisites
* **Board:** Radxa Cubie A7Z
* **Kernel:** `5.15.147-21-a733`
* **Dependencies:** `cfg80211`, `mac80211`, `hostapd`

## 2. Load Driver
```bash
# Load mac80211 stack dependency
sudo modprobe mac80211

# Insert driver module
sudo insmod driver/mt7601u.ko
```

## 3. Configure Interface for AP Mode
```bash
# Stop background network managers to prevent interface conflicts
sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true

# Switch interface type to AP
sudo ip link set wlan1 down
sudo iw dev wlan1 set type __ap
sudo ip link set wlan1 up
```

## 4. Run hostapd
Create `/tmp/hostapd-mt7601u.conf`:
```ini
interface=wlan1
driver=nl80211
ssid=MT7601U-Test
hw_mode=g
channel=6
ieee80211n=0
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
```

Run hostapd:
```bash
sudo hostapd -dd /tmp/hostapd-mt7601u.conf
```
Expected output: `wlan1: AP-ENABLED`
