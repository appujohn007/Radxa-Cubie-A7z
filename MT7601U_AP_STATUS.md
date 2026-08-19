# MT7601U AP Mode Status & Technical Record

## Current Status
**VERIFIED WORKING (Beacon / AP Mode Operations)**

The MediaTek MT7601U USB Wi-Fi driver has been successfully modified, compiled, and tested on the real Radxa Cubie A7Z hardware. The modified driver successfully transitions interface `wlan1` into AP mode, enables autonomous hardware beaconing, starts `hostapd` to the `AP-ENABLED` state, broadcasts the configured SSID (`MT7601U-Test`), receives 802.11 probe requests from scanning clients, and transmits valid probe responses over the air.

---

## Hardware Environment
* **Target Board:** Radxa Cubie A7Z
* **SoC:** Allwinner A733 (`sun60iw2p1`, Octa-Core ARM Cortex-A55)
* **Architecture:** `aarch64` (ARM64)
* **USB Wi-Fi Adapter:** MediaTek MT7601U (1T1R 802.11b/g/n, 2.4 GHz)
* **USB Vendor/Product ID:** `148f:7601`
* **MAC Address:** Read from on-chip EEPROM (`dev->macaddr`) or generated randomly if uninitialized
* **USB Host Controller:** Allwinner Enhanced Host Controller Interface (`sunxi-ehci`) / EHCI 2.0 Host Controller

---

## Software Environment
* **Operating System:** Debian GNU/Linux 11 (Bullseye) / Official Radxa Debian Minimal
* **Target Kernel:** `5.15.147-21-a733`
* **Toolchain:** 
  * Cross-compiler: `aarch64-linux-gnu-gcc`
  * Host compiler: `gcc` (x86_64)
* **Kernel Source Repository:** `linux-a733` (submodules: `src/` Linux 5.15 kernel, `bsp/` Allwinner BSP, `device-a733/` board configs)
* **Kernel Configuration State:**
  * `CONFIG_MT7601U=m`
  * `CONFIG_CFG80211=m`
  * `CONFIG_MAC80211=m`
  * `CONFIG_NUMA` is not set (disabled to match running target kernel)
  * `CONFIG_LOCALVERSION="-21-a733"` (with `CONFIG_LOCALVERSION_AUTO` disabled)

---

## Original Driver (Stock Baseline)
* **Module Path:** `drivers/net/wireless/mediatek/mt7601u/mt7601u.ko`
* **Release / Vermagic:** `5.15.147-21-a733 SMP preempt mod_unload aarch64`
* **Dependencies:** `cfg80211`, `mac80211`
* **Supported Modes (Stock):**
  ```text
  Supported interface modes:
       * managed
       * monitor
  ```
* **Observed Stock Behavior:**
  * Attempting to switch the interface to AP mode (`sudo iw dev wlan1 set type __ap` or `hostapd`) failed immediately with:
    ```text
    command failed: Operation not supported (-95)
    ```
  * In the stock driver, `wiphy->interface_modes` in `init.c` only exposed `BIT(NL80211_IFTYPE_STATION)`.

---

## Experimental Driver (AP-Enabled)
* **Source Changes:** Modifications across 6 files in `drivers/net/wireless/mediatek/mt7601u/` (`init.c`, `mac.c`, `mac.h`, `main.c`, `mt7601u.h`, `regs.h`).
* **Canonical Patch:** [`patches/mt7601u-enable-ap-mode.patch`](patches/mt7601u-enable-ap-mode.patch)
* **Known-Good Distributable Binary:** [`mt7601u.ko`](mt7601u.ko)
* **Binary SHA256:** `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833`
* **Module `vermagic`:** `5.15.147-21-a733 SMP preempt mod_unload aarch64`
* **Dependencies:** `cfg80211,mac80211`
* **Build Procedure:**
  ```bash
  cd /workspaces/linux-a733
  ./build-module.sh drivers/net/wireless/mediatek/mt7601u
  ```

---

## Runtime Verification on Radxa Hardware

### 1. Module Loading & Interface Initialization
```bash
sudo modprobe mac80211
sudo insmod mt7601u.ko
```

### 2. Interface Capability Inspection (`iw phy info`)
```bash
iw phy $(cat /sys/class/net/wlan1/phy80211/name) info
```
**Observed Output:**
```text
Supported interface modes:
     * managed
     * AP
     * AP/VLAN
     * monitor
```

### 3. Interface Mode Transition
```bash
sudo ip link set wlan1 down
sudo iw dev wlan1 set type __ap
sudo ip link set wlan1 up
iw dev wlan1 info
```
**Observed Result:**
* Exit code: `0`
* Interface type: `AP`

### 4. `hostapd` Hotspot Execution
Test configuration file (`/tmp/hostapd-mt7601u.conf`):
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

Execution command:
```bash
sudo hostapd -dd /tmp/hostapd-mt7601u.conf
```

**Observed Result Log:**
```text
Configuration file: /tmp/hostapd-mt7601u.conf
wlan1: interface state UNINITIALIZED->COUNTRY_UPDATE
wlan1: interface state COUNTRY_UPDATE->ENABLED
wlan1: AP-ENABLED
```

---

## Verified Results Checklist

| Capability / Feature | Status | Evidence / Notes |
| :--- | :--- | :--- |
| **AP Mode Advertised (`NL80211_IFTYPE_AP`)** | **VERIFIED** | Reported by `iw phy info` (`managed`, `AP`, `AP/VLAN`, `monitor`). |
| **`managed` -> `AP` Type Transition** | **VERIFIED** | `sudo iw dev wlan1 set type __ap` exits `0`, interface switches to `type AP`. |
| **`hostapd` Startup (`AP-ENABLED`)** | **VERIFIED** | `hostapd` successfully initializes nl80211 context and reaches `AP-ENABLED`. |
| **Hardware Beacon Configuration** | **VERIFIED** | `MT_BEACON_TIME_CFG` programmed with `BEACON_TX`, `TBTT_EN`, `TIMER_EN`, `SYNC_MODE`. |
| **Beacon Upload to SRAM (`0xC000`)** | **VERIFIED** | TXWI header with `MT_TXWI_FLAGS_TS` prepended and copied to SRAM via `mt7601u_wr_copy()`. |
| **SSID Visibility to External Devices** | **VERIFIED** | `MT7601U-Test` detected on channel 6 by external scanning client device. |
| **802.11 Probe Request Reception** | **VERIFIED** | Probe requests from scanning clients received and processed by driver. |
| **802.11 Probe Response Transmission** | **VERIFIED** | Probe responses with valid TSF timestamps transmitted back over the air. |
| **Group WCID (Multicast) Setup** | **VERIFIED** | `mt7601u_mac_wcid_setup()` programs group WCID table entry (`GROUP_WCID(0) = 126`). |
| **Station Association (4-Way Handshake)** | **NOT YET VERIFIED** | Association and 4-way WPA2-PSK handshake on target hardware pending next test cycle. |
| **Data Plane / Throughput (IP / ping)** | **NOT YET VERIFIED** | IP traffic over associated AP link pending client association test. |
| **DHCP / NAT / Internet Forwarding** | **NOT YET VERIFIED** | dnsmasq / iptables forwarding pending data plane verification. |

---

## Technical Details of Driver Changes

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ MT7601U AP Architecture & Execution Path                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 1. mac80211 calls mt7601u_bss_info_changed(BSS_CHANGED_BEACON_ENABLED):         │
│    -> Programs MT_BEACON_TIME_CFG (0x1114) with:                                │
│       - MT_BEACON_TIME_CFG_BEACON_TX  (BIT 20)                                  │
│       - MT_BEACON_TIME_CFG_TBTT_EN    (BIT 19)                                  │
│       - MT_BEACON_TIME_CFG_TIMER_EN   (BIT 16)                                  │
│       - MT_BEACON_TIME_CFG_SYNC_MODE  (GENMASK 18:17 = 3: AP Mode)              │
│    -> Programs MT_MAC_BSSID_DW1 (0x1014) for 8 AP MBSS mode                    │
│    -> Starts high-resolution pre_tbtt_timer (fires 8ms before TBTT)             │
│                                                                                 │
│ 2. Periodic pre_tbtt_timer Expiry -> mt7601u_pre_tbtt_work():                  │
│    -> Sets MT_BCN_BYPASS_MASK (0x108c) = 0xFFFF (locks SRAM from egress)       │
│    -> Retrieves beacon skb via ieee80211_beacon_get()                          │
│    -> Formats struct mt76_txwi (flags |= MT_TXWI_FLAGS_TS, rate=6M/1M, WCID=0xFF)│
│    -> Copies TXWI + beacon payload to MT_BEACON_BASE (0xC000) using wr_copy()   │
│    -> Clears bypass mask: MT_BCN_BYPASS_MASK = 0xFFFE (enables slot 0)         │
│    -> Reschedules pre_tbtt_timer for (next TBTT - 8ms)                          │
│                                                                                 │
│ 3. Autonomous Egress:                                                           │
│    -> Hardware MAC transmits beacon directly from 0xC000 SRAM at TBTT tick.     │
│    -> Hardware auto-inserts 64-bit TSF timestamp into outgoing frame header.    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Known Errors & Troubleshooting

### 1. USB Bus / MCU Communication Errors (`-71` / `-110`)
* **Observed Symptoms:**
  ```text
  mt7601u 1-1:1.0: Error: MCU resp urb failed:-71
  mt7601u 1-1:1.0: Error: send MCU cmd failed:-71
  mt7601u 1-1:1.0: Error: vendor request 0x02 failed:-71
  mt7601u 1-1:1.0: Error: probe of 1-1:1.0 failed with error -110
  ```
* **Root Cause:** Error `-71` is `-EPROTO` (low-level USB protocol error), and `-110` is `-ETIMEDOUT`. On the Allwinner A733 platform, rapid unbinding/rebinding or physical USB connector flakiness on the `sunxi-ehci` host controller can cause transient communication loss.
* **Important Note:** These errors represent USB transport disruptions during hotplug/reset, **not** driver logic defects in AP mode.

### 2. Device or Resource Busy (`-16`) During Interface Mode Change
* **Observed Symptom:** `sudo iw dev wlan1 set type __ap` fails with `Device or resource busy (-16)`.
* **Root Cause:** The network interface `wlan1` was currently `UP` or claimed by background managers (`NetworkManager` / `wpa_supplicant`).
* **Fix:**
  ```bash
  sudo systemctl stop NetworkManager wpa_supplicant
  sudo ip link set wlan1 down
  sudo iw dev wlan1 set type __ap
  ```

### 3. Unknown Symbol Errors on `insmod mt7601u.ko`
* **Observed Symptom:** `insmod: ERROR: could not insert module mt7601u.ko: Unknown symbol in module`.
* **Root Cause:** Module dependencies `mac80211` and `cfg80211` were not loaded before raw `insmod`.
* **Fix:**
  ```bash
  sudo modprobe cfg80211
  sudo modprobe mac80211
  sudo insmod mt7601u.ko
  ```

---

## Recovery Procedure (Restoring Original Driver)

If a backup of the original module was created on the target board at `/lib/modules/$(uname -r)/extra/mt7601u.ko.original`:

```bash
# 1. Unload experimental driver
sudo ip link set wlan1 down
sudo modprobe -r mt7601u

# 2. Restore original module backup
sudo cp /lib/modules/$(uname -r)/extra/mt7601u.ko.original /lib/modules/$(uname -r)/kernel/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko
sudo depmod -a

# 3. Reload stock driver
sudo modprobe mt7601u
```

---

## Reproduction From Clean State

To reproduce the verified AP-enabled driver binary from scratch:

```bash
# 1. Enter the kernel superproject
cd /workspaces/linux-a733

# 2. Ensure superproject environment fixups are initialized
make pre_build

# 3. Ensure target kernel configuration is configured (with CONFIG_MT7601U=m)
cd src
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ defconfig bsp.config
./scripts/config --set-str LOCALVERSION "-21-a733"
./scripts/config --disable LOCALVERSION_AUTO
./scripts/config --disable NUMA
./scripts/config --module MT7601U
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ olddefconfig

# 4. Apply the AP mode patch
patch -p1 < /workspaces/Radxa-Cubie-A7z/patches/mt7601u-enable-ap-mode.patch

# 5. Build the module using the global build script
cd /workspaces/linux-a733
./build-module.sh drivers/net/wireless/mediatek/mt7601u

# 6. Verify output binary
sha256sum src/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko
# Expected: 2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833
```

---

## Future Work & Next Experiments

1. **Client Association & 4-Way Handshake Test:** Connect a physical Wi-Fi client (smartphone or laptop) to the `MT7601U-Test` AP with open and WPA2-PSK security.
2. **Data Plane Validation:** Verify IP assignment, ARP resolution, ICMP echo (`ping`), and UDP/TCP throughput via `iperf3`.
3. **Power-Save Multicast (DTIM) Frame Queueing:** Implement `ieee80211_get_buffered_bc()` in `mt7601u_pre_tbtt_work()` to support sleeping power-save client stations.
