# MT7601U AP Mode - Target Deployment & Installation Guide

This guide covers running the MT7601U in Access Point mode on the **Radxa Cubie A7Z** using either:
1. **Standalone `hostapd`** (direct mac80211/nl80211 control)
2. **NetworkManager (`nmcli`)** (integrated system hotspot with DHCP/NAT sharing)

---

## 1. Driver Prerequisites & Loading

```bash
# 1. Load the mac80211 kernel stack dependency
sudo modprobe cfg80211
sudo modprobe mac80211

# 2. Insert the custom compiled driver module
sudo insmod driver/mt7601u.ko

# 3. Verify interface creation
ip link show wlan1
```

---

## 2. Option A: Standalone `hostapd` Hotspot

### Step 1: Prepare Interface
```bash
# Stop background network managers to prevent interface conflicts
sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true

# Set interface type to AP
sudo ip link set wlan1 down
sudo iw dev wlan1 set type __ap
sudo ip link set wlan1 up
```

### Step 2: Create Hostapd Configuration (`/tmp/hostapd-mt7601u.conf`)
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

### Step 3: Run Hostapd
```bash
sudo hostapd -dd /tmp/hostapd-mt7601u.conf
```
*Expected output:* `wlan1: AP-ENABLED`

---

## 3. Option B: NetworkManager (`nmcli`) Hotspot

When deploying the MT7601U AP using NetworkManager, specific wireless, security, and regulatory constraints must be configured to ensure compatibility with the driver.

### Step 1: Set Regulatory Domain
```bash
# Set regulatory domain to your region (e.g. IN, US, EU) to unlock non-restricted 2.4 GHz channels
sudo iw reg set IN
```

### Step 2: Create NetworkManager Hotspot Profile
```bash
# Create AP profile bound strictly to wlan1
sudo nmcli connection add type wifi ifname wlan1 con-name "MT7601U-Hotspot" autoconnect no ssid "MT7601U-Test"

# Configure standard 2.4 GHz band and channel
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless.mode ap
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless.band bg
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless.channel 6

# Configure legacy WPA2-PSK security (mandatory for MT7601U AP mode)
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless-security.key-mgmt wpa-psk
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless-security.proto rsn
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless-security.pairwise ccmp
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless-security.group ccmp
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless-security.pmf 0
sudo nmcli connection modify "MT7601U-Hotspot" 802-11-wireless-security.psk "Password123"

# Enable IPv4 shared NAT routing & DHCP
sudo nmcli connection modify "MT7601U-Hotspot" ipv4.method shared

# Bring up the hotspot connection
sudo nmcli connection up "MT7601U-Hotspot"
```

---

## ⚠️ Critical Operational Troubleshooting & Known Pitfalls

### Issue 1: Regulatory Domain and Channel Incompatibility
* **Reason:** NetworkManager defaults to Channel 13 (`2472 MHz`) on auto-channel selection. Under the default global regulatory domain (`00`), higher channels (12-14) are marked with `NO-IR` (No Initiating Radiation), preventing the kernel from transmitting beacons.
* **Fix:** Explicitly set the regional regulatory domain (`sudo iw reg set IN`) and force a standard globally permitted channel (`802-11-wireless.channel 6`).

### Issue 2: Unsupported Security Ciphers and PMF
* **Reason:** Modern NetworkManager / `wpa_supplicant` defaults attempt to negotiate WPA3/SAE, `WPA-PSK-SHA256`, and Protected Management Frames (PMF / 802.11w). The `mt7601u` MAC hardware does not support PMF or WPA3 suites in AP mode, causing `wpa_supplicant` to immediately fail with `Failed to start AP functionality`.
* **Fix:** Restrict the connection profile strictly to legacy WPA2-PSK (`key-mgmt wpa-psk`, `proto rsn`, `pairwise ccmp`, `group ccmp`, `pmf 0`).

### Issue 3: Interface Busy / Stale Association State
* **Reason:** When `wlan1` is brought up, NetworkManager may automatically attempt to scan and associate it as a client station (`ab 1`) before switching to AP mode, causing `Device or resource busy (-16)`.
* **Fix:** Bind the profile strictly to the interface (`connection.interface-name wlan1`), disconnect any active client profiles on `wlan1` (`nmcli device disconnect wlan1`), and use `ipv4.method shared`.
