# AI Handoff & Project Continuity Guide

> **Purpose:** This document is the primary, self-contained project memory for any future AI agent or developer continuing work on the **Radxa Cubie A7Z** kernel drivers and **MediaTek MT7601U AP Mode** implementation without access to previous conversation history.

---

## 1. Project Goal
The primary objective of this repository is to provide operational documentation, reproducible build instructions, patches, and deployment artifacts for custom kernel drivers on the **Radxa Cubie A7Z** single-board computer, with a specific focus on:
1. Enabling and stabilizing the **MediaTek MT7601U** USB Wi-Fi adapter for **Access Point (AP / Hotspot) mode** with `hostapd`.
2. Providing a 100% repository-portable, cross-compilation pipeline for the Allwinner A733 BSP kernel (`5.15.147-21-a733`).
3. Documenting verified hardware behaviors, failed experiments, and known operational quirks.

---

## 2. Target Hardware & Platform Environment
* **Target Board:** Radxa Cubie A7Z
* **SoC:** Allwinner A733 (`sun60iw2p1`, 8x ARM Cortex-A55 @ 1.4-2.0 GHz)
* **Architecture:** `aarch64` / `arm64`
* **Target Operating System:** Debian GNU/Linux 11 (Bullseye) (Official Radxa Debian Minimal image)
* **Target Kernel Release:** `5.15.147-21-a733`
* **Target USB Device:** MediaTek MT7601U 1T1R 802.11b/g/n USB 2.0 Wi-Fi adapter (USB ID: `148f:7601`)
* **Host USB Controller:** Allwinner EHCI USB Controller (`sunxi-ehci`)

---

## 3. Repository Structure & Workspace Topology

The development environment consists of two peer repositories in `/workspaces`:

```
/workspaces/
├── Radxa-Cubie-A7z/                <- Operational & Release Repository (This repo)
│   ├── .config                     <- Reference kernel .config for Cubie A7Z (CONFIG_MT7601U=m)
│   ├── BUILD.md                    <- Master build architecture and troubleshooting guide
│   ├── AI_HANDOFF.md               <- This document (self-contained AI memory)
│   ├── project-state.yaml          <- Machine-readable project state
│   ├── README.md                   <- Repository overview & quick reference
│   ├── patches/                    <- Clean, distributable patch directory
│   │   ├── README.md               <- Patch catalog index
│   │   ├── mt7601u-ap-mode/        <- MT7601U AP subproject
│   │   │   ├── driver/mt7601u.ko   <- VERIFIED KNOWN-GOOD AP MODULE (SHA256: 2c83f127...)
│   │   │   ├── source_patch/       <- Source patch (mt7601u-enable-ap-mode.patch)
│   │   │   ├── STATUS.md           <- Authoritative technical record & hardware verification logs
│   │   │   ├── BUILD.md            <- Kbuild compilation workflow
│   │   │   ├── BUILD_NOTES.md      <- Developer build notes
│   │   │   ├── CHANGELOG.md        <- Version history
│   │   │   ├── README.md           <- Subproject overview
│   │   │   └── INSTALL.md          <- Target installation steps
│   │   └── aic8800d80-monitor-mode/<- AIC8800 Wi-Fi monitor mode experiment files
│   ├── extracted/                  <- Extracted raw partitions from stock Radxa OS image
│   └── rootfs/                     <- Mounted/extracted reference root filesystem
│
└── linux-a733/                     <- Canonical Kernel Superproject & Source
    ├── src/                        <- Linux 5.15.147 kernel source submodule (branch: mt7601u-ap-experiment)
    ├── bsp/                        <- Allwinner BSP drivers and headers submodule
    ├── device-a733/                <- Board/SoC defconfigs (bsp_defconfig) submodule
    ├── Makefile                    <- Contains `make pre_build` setup targets
    └── build-module.sh             <- Universal, reusable module compilation script
```

---

## 4. Current Git Branches & Commit States

### `Radxa-Cubie-A7z`
* **Branch:** `main`
* **Tracking:** `origin/main`

### `linux-a733`
* **Superproject Branch:** `allwinner-aiot-linux-5.15`
* **`src/` Submodule Branch:** `mt7601u-ap-experiment`
* **Applied Source Modifications in `src/`:**
  * [`drivers/net/wireless/mediatek/mt7601u/init.c`](file:///workspaces/linux-a733/src/drivers/net/wireless/mediatek/mt7601u/init.c): Advertises AP mode in `wiphy->interface_modes`, initializes pre-TBTT timer/work, initializes bypass mask.
  * [`drivers/net/wireless/mediatek/mt7601u/mac.c`](file:///workspaces/linux-a733/src/drivers/net/wireless/mediatek/mt7601u/mac.c): Implements beacon TXWI creation, SRAM burst copy, pre-TBTT periodic worker, beacon timer resync, and beacon enable/disable.
  * [`drivers/net/wireless/mediatek/mt7601u/mac.h`](file:///workspaces/linux-a733/src/drivers/net/wireless/mediatek/mt7601u/mac.h): Function declarations for beacon management.
  * [`drivers/net/wireless/mediatek/mt7601u/main.c`](file:///workspaces/linux-a733/src/drivers/net/wireless/mediatek/mt7601u/main.c): Updates `bss_info_changed` to process `BSS_CHANGED_BEACON_ENABLED` and `BSS_CHANGED_BEACON`, updates `add_interface` / `remove_interface` for group WCID registration, flushes timers on `stop`.
  * [`drivers/net/wireless/mediatek/mt7601u/mt7601u.h`](file:///workspaces/linux-a733/src/drivers/net/wireless/mediatek/mt7601u/mt7601u.h): Declares timer, work_struct, beacon bitmasks, and `mt76_get_field` helper.
  * [`drivers/net/wireless/mediatek/mt7601u/regs.h`](file:///workspaces/linux-a733/src/drivers/net/wireless/mediatek/mt7601u/regs.h): Defines `MT_TSF_TIMER_DW0/DW1` and `MT_TBTT_TIMER`.

---

## 5. MT7601U Investigation Timeline & History

1. **Initial Issue:** Stock Radxa kernel image lacked `CONFIG_MT7601U` (`CONFIG_MT7601U is not set`). The USB device was recognized by `lsusb` (`148f:7601`), but no network interface appeared.
2. **First Driver Build:** Enabled `CONFIG_MT7601U=m` using `build-module.sh`. The driver loaded and created `wlan1`, but `iw list` only reported `managed` and `monitor` interface modes.
3. **Attempting AP Mode with Stock Driver:** Running `sudo iw dev wlan1 set type __ap` failed with `-95` (`Operation not supported`).
4. **Initial Advertising Experiment:** Changed `wiphy->interface_modes` in `init.c` to include `BIT(NL80211_IFTYPE_AP)`. `iw phy info` now reported `AP` mode, and `iw dev wlan1 set type __ap` succeeded, but starting `hostapd` failed to broadcast beacons because the hardware beacon memory was unpopulated and the MAC beacon engine remained unconfigured.
5. **Architectural Deep-Dive:** Compared the standalone `mt7601u` driver against the unified `mt76/mt76x02` USB beacon engine. Confirmed that MT7601U has identical on-chip SRAM at `0xC000` (`MT_BEACON_BASE`), identical 20-byte `struct mt76_txwi` descriptors with `MT_TXWI_FLAGS_TS`, and an autonomous MAC beacon sequencer at `0x1114` (`MT_BEACON_TIME_CFG`).
6. **Full AP Implementation:** Implemented beacon TXWI packaging, USB burst write to SRAM, pre-TBTT periodic hrtimer refresh loop, drift resynchronization, group WCID initialization, and mac80211 `bss_info_changed` event handling.
7. **Hardware Verification on Cubie A7Z:** Loaded the experimental module (`SHA256: 2c83f127...`). Successfully executed `hostapd`, reached `wlan1: AP-ENABLED`, observed the SSID (`MT7601U-Test`) on an external smartphone/client, received probe requests, and transmitted probe responses.

---

## 6. Known-Good vs. Known-Bad Artifacts

### Known-Good Artifacts
* **File:** `/workspaces/Radxa-Cubie-A7z/patches/mt7601u-ap-mode/driver/mt7601u.ko`
  * **Purpose:** Distributable, verified working AP-mode driver binary for `5.15.147-21-a733`.
  * **SHA256:** `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833`
  * **`vermagic`:** `5.15.147-21-a733 SMP preempt mod_unload aarch64`
  * **Dependencies:** `cfg80211,mac80211`
  * **Status:** **VERIFIED WORKING on real Radxa hardware.**
* **File:** `/workspaces/Radxa-Cubie-A7z/patches/mt7601u-ap-mode/source_patch/mt7601u-enable-ap-mode.patch`
  * **Purpose:** Source patch to cleanly recreate the AP-enabled driver from a clean kernel tree.
  * **Status:** **VERIFIED (applies cleanly, builds cleanly with 0 warnings/errors).**

### Known-Bad / Incomplete Configurations
* **Stock Driver (without patch):** Only advertises STA/Monitor; returns `-95` on AP mode switch.
* **Interface Modes Only Change (without beacon engine):** Advertises AP mode, but `hostapd` cannot transmit beacons over the air.

---

## 7. Working Runtime Configuration

### A. Driver Load & Mode Switch Commands
```bash
# 1. Ensure dependencies are loaded
sudo modprobe cfg80211
sudo modprobe mac80211

# 2. Insert experimental driver
sudo insmod patches/mt7601u-ap-mode/driver/mt7601u.ko

# 3. Stop network managers that may interfere with interface state
sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true

# 4. Configure interface for AP mode
sudo ip link set wlan1 down
sudo iw dev wlan1 set type __ap
sudo ip link set wlan1 up
```

### B. Tested `hostapd` Configuration (`/tmp/hostapd-mt7601u.conf`)
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

### C. Launch Command
```bash
sudo hostapd -dd /tmp/hostapd-mt7601u.conf
```

---

## 8. Driver Subsystem Architecture

```
User Space:      hostapd / iw / wpa_supplicant
                         │  (Netlink nl80211)
                         ▼
Kernel Layer:         cfg80211
                         │
                         ▼
                    mac80211 (IEEE 802.11 Stack)
                         │  (ieee80211_ops / callbacks)
                         ▼
Driver Layer:      mt7601u driver (drivers/net/wireless/mediatek/mt7601u/)
                         │
        ┌────────────────┴────────────────┐
        ▼                                 ▼
   Control & Calibration           Data & Beacon Path
 (mcu.c / phy.c / usb.c)       (mac.c / tx.c / dma.c)
        │                                 │
        ▼                                 ▼
  Inband USB Commands          USB Bulk URBs / SRAM Copies
  (CMD_BURST_WRITE)             (MT_BEACON_BASE 0xC000)
        │                                 │
        └────────────────┬────────────────┘
                         ▼
Hardware Layer:    MediaTek MT7601U USB SoC (148f:7601)
                   ├── Autonomous MAC Beacon Engine (0x1114)
                   ├── 16-slot Beacon SRAM (0xC000)
                   ├── 128 WCID Crypto Engines (WEP/TKIP/AES-CCMP)
                   └── 802.11b/g/n Baseband / Radio (2.4 GHz)
```

---

## 9. Known Limitations & Unverified Features

1. **Station Association & 4-Way Handshake:** `NOT YET VERIFIED` on target hardware (scheduled for next testing phase).
2. **Data Plane / IP Traffic:** `NOT YET VERIFIED` over active AP link.
3. **Power-Save Multicast (DTIM):** Sleeping station multicast buffering (`ieee80211_get_buffered_bc()`) is not yet implemented. Active clients will receive unicast/broadcast normally.
4. **AP + STA Concurrent Mode:** NOT SUPPORTED. The driver is strictly configured for single-interface operation (either STA or AP).
5. **Multi-BSSID:** Only single BSSID (slot 0) is active.

---

## 10. Reproduction & Rebuild Procedure

```bash
# Step 1: Navigate to kernel superproject
cd /workspaces/linux-a733

# Step 2: Initialize workspace symlinks and headers
make pre_build

# Step 3: Configure target kernel configuration
cd src
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ defconfig bsp.config
./scripts/config --set-str LOCALVERSION "-21-a733"
./scripts/config --disable LOCALVERSION_AUTO
./scripts/config --disable NUMA
./scripts/config --module MT7601U
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ olddefconfig

# Step 4: Apply the AP mode patch
patch -p1 < /workspaces/Radxa-Cubie-A7z/patches/mt7601u-ap-mode/source_patch/mt7601u-enable-ap-mode.patch

# Step 5: Compile the module
cd /workspaces/linux-a733
./build-module.sh drivers/net/wireless/mediatek/mt7601u

# Step 6: Verify SHA256 matches known-good
sha256sum src/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko
```
