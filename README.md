# Radxa Cubie A7Z Driver & Release Documentation

[![Target Kernel](https://img.shields.io/badge/Kernel-5.15.147--21--a733-blue.svg)](https://github.com/radxa-pkg/linux-a733)
[![Architecture](https://img.shields.io/badge/Architecture-ARM64%20%2F%20aarch64-green.svg)](https://radxa.com)
[![Status](https://img.shields.io/badge/MT7601U%20AP%20Mode-VERIFIED%20WORKING-brightgreen.svg)](MT7601U_AP_STATUS.md)

Welcome to the official operational documentation, release packaging, custom driver patches, and deployment repository for the **Radxa Cubie A7Z** (Allwinner A733 SoC, ARM64, Debian 11 Bullseye).

---

## 📌 Repository Contents & Quick Navigation

| Document | Purpose | Audience |
| :--- | :--- | :--- |
| [`MT7601U_AP_STATUS.md`](MT7601U_AP_STATUS.md) | **Authoritative MT7601U AP Mode Record** – Full hardware verification, runtime test logs, architecture analysis & troubleshooting. | Developers, QA, Users |
| [`AI_HANDOFF.md`](AI_HANDOFF.md) | **AI Continuity Guide** – Self-contained project memory for future AI agents to continue development without prior chat context. | AI Agents, Developers |
| [`project-state.yaml`](project-state.yaml) | **Machine-Readable State** – Structured YAML tracking hardware metadata, hashes, verification statuses, and parameters. | Automation, Scripts |
| [`BUILD.md`](BUILD.md) | **Master Build Architecture** – Kernel superproject setup, `build-module.sh` pipeline, symbol tables, and troubleshooting. | Kernel Engineers |
| [`BUILD_NOTES.md`](BUILD_NOTES.md) | **Driver Build & Deployment Checklist** – Step-by-step kernel config, compilation, and board installation steps. | Developers |
| [`patches/mt7601u-ap-mode/`](patches/mt7601u-ap-mode/) | **MediaTek MT7601U AP Mode Subproject** – Source patch, verified `.ko` binary, and target deployment guide. | All |
| [`patches/aic8800d80-monitor-mode/`](patches/aic8800d80-monitor-mode/) | **AIC8800D80 Monitor Mode Subproject** – Frame injection instrumentation, drivers, and changelog. | All |

---

## 🛠️ Hardware & Platform Specifications

* **Target Board:** Radxa Cubie A7Z
* **SoC:** Allwinner A733 (`sun60iw2p1`, 8x ARM Cortex-A55 @ 1.4-2.0 GHz)
* **Architecture:** `aarch64` / `arm64`
* **Operating System:** Debian GNU/Linux 11 (Bullseye) / Official Radxa Debian Minimal
* **Target Kernel Release:** `5.15.147-21-a733`
* **Host USB Controller:** Allwinner EHCI 2.0 Host Controller (`sunxi-ehci`)

---

## 🚀 Module Quick Reference: MediaTek MT7601U

* **Driver Subsystem:** `mac80211` / `cfg80211`
* **USB ID:** `148f:7601`
* **Binary Path:** [`mt7601u.ko`](mt7601u.ko) (and [`patches/mt7601u-ap-mode/driver/mt7601u.ko`](patches/mt7601u-ap-mode/driver/mt7601u.ko))
* **Verified SHA256:** `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833`
* **Module `vermagic`:** `5.15.147-21-a733 SMP preempt mod_unload aarch64`
* **Dependencies:** `cfg80211`, `mac80211`
* **Status:** **VERIFIED WORKING** (AP beaconing, SSID broadcast, probe response, `hostapd` reaching `AP-ENABLED`)

### Target Deployment Quickstart (On Radxa Board):
```bash
# 1. Load mac80211 dependency
sudo modprobe mac80211

# 2. Insert verified driver module
sudo insmod mt7601u.ko

# 3. Configure interface for Access Point mode
sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true
sudo ip link set wlan1 down
sudo iw dev wlan1 set type __ap
sudo ip link set wlan1 up

# 4. Start hostapd hotspot
sudo hostapd /etc/hostapd/hostapd-mt7601u.conf
```

---

## 📦 Verified Artifacts & Checksums

| Artifact | Location | SHA256 Checksum | Vermagic | Status |
| :--- | :--- | :--- | :--- | :--- |
| **MT7601U AP Driver (Root)** | [`mt7601u.ko`](mt7601u.ko) | `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833` | `5.15.147-21-a733` | **Verified on Hardware** |
| **MT7601U AP Driver (Subproject)** | [`patches/mt7601u-ap-mode/driver/mt7601u.ko`](patches/mt7601u-ap-mode/driver/mt7601u.ko) | `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833` | `5.15.147-21-a733` | **Verified on Hardware** |
| **MT7601U Source Patch** | [`patches/mt7601u-enable-ap-mode.patch`](patches/mt7601u-enable-ap-mode.patch) | N/A (Unified Diff) | N/A | **Clean Apply on 5.15** |
| **AIC8800 FDRV Driver** | `patches/aic8800d80-monitor-mode/driver/aic8800_fdrv.ko` | Verified | `5.15.147-21-a733` | **Verified** |
| **AIC8800 FW Loader** | `patches/aic8800d80-monitor-mode/driver/aic_load_fw.ko` | Verified | `5.15.147-21-a733` | **Verified** |

---

## 🏗️ Building from Source

To compile or modify kernel modules using the `linux-a733` superproject:

```bash
# 1. Enter kernel superproject
cd /workspaces/linux-a733

# 2. Run workspace setup fixups
make pre_build

# 3. Apply target kernel configuration (CONFIG_MT7601U=m)
cd src
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ defconfig bsp.config
./scripts/config --set-str LOCALVERSION "-21-a733"
./scripts/config --disable LOCALVERSION_AUTO
./scripts/config --disable NUMA
./scripts/config --module MT7601U
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ olddefconfig

# 4. Apply AP mode patch
patch -p1 < /workspaces/Radxa-Cubie-A7z/patches/mt7601u-enable-ap-mode.patch

# 5. Build module
cd /workspaces/linux-a733
./build-module.sh drivers/net/wireless/mediatek/mt7601u
```

For comprehensive details on Kbuild parameters, symbol tables (`Module.symvers`), and common build errors, refer to [`BUILD.md`](BUILD.md).
