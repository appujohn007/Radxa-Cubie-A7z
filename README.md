# Radxa Cubie A7Z Driver & Release Documentation

[![Target Board](https://img.shields.io/badge/Hardware-Radxa%20Cubie%20A7Z-orange.svg)](https://radxa.com)
[![SoC](https://img.shields.io/badge/SoC-Allwinner%20A733%20%28ARM64%29-red.svg)](https://www.allwinnertech.com)
[![Target Kernel](https://img.shields.io/badge/Kernel-5.15.147--21--a733-blue.svg)](https://github.com/radxa-pkg/linux-a733)
[![MT7601U AP Mode](https://img.shields.io/badge/MT7601U%20AP%20Mode-VERIFIED%20WORKING-brightgreen.svg)](MT7601U_AP_STATUS.md)
[![AIC8800 Monitor Mode](https://img.shields.io/badge/AIC8800%20Monitor%20Mode-READY-brightgreen.svg)](patches/aic8800d80-monitor-mode/README.md)

Welcome to the central operational documentation, custom driver patch repository, precompiled kernel module release hub, and hardware verification database for the **Radxa Cubie A7Z** single-board computer running the Allwinner Linux 5.15 BSP.

---

## 🌟 Need & Purpose of This Repository

The **Radxa Cubie A7Z** is a high-performance single-board computer powered by the octa-core **Allwinner A733 (`sun60iw2p1`) SoC** (ARM64). While the official vendor BSP provides a solid foundation, several common networking drivers and specialized wireless operational modes (such as Access Point / Hotspot functionality on MediaTek USB adapters, and frame injection on AIC8800 Wi-Fi) are either unconfigured, disabled, or incomplete in the stock kernel release.

### Why This Repository Exists:
1. **Operational Release Hub:** Provides verified, drop-in `.ko` driver binaries matching the exact kernel release (`5.15.147-21-a733 SMP preempt mod_unload aarch64`) so developers can deploy features without rebuilding the entire operating system.
2. **Canonical Patch Repository:** Maintains structured, clean, unified diff patches for upstreaming or building custom kernels from source.
3. **Hardware Truth & Verification Records:** Documents real hardware test results (e.g. `hostapd` runtime logs, beaconing, probe requests/responses, USB protocol quirks) to distinguish verified facts from speculation.
4. **AI Continuity & Developer Memory:** Features a self-contained AI handoff blueprint enabling future AI coding assistants and developers to immediately understand the entire platform architecture without chat history.

---

## 🗺️ Complete Repository Structure & Directory Map

```
Radxa-Cubie-A7z/
│
├── ⚙️ Configuration & Metadata
│   ├── .config                     <- Reference kernel .config for Cubie A7Z (CONFIG_MT7601U=m, NUMA disabled)
│   ├── .gitignore                  <- Git exclusion rules for large disk images, logs & temp files
│   └── project-state.yaml          <- Machine-readable YAML state tracking hashes, statuses & parameters
│
├── 📖 Master Documentation
│   ├── README.md                   <- This document (general intro, architecture, specs & quick navigation)
│   ├── MT7601U_AP_STATUS.md        <- Authoritative technical record & hardware verification logs for MT7601U
│   ├── AI_HANDOFF.md               <- Self-contained project memory for future AI sessions & developers
│   ├── BUILD.md                    <- Master build system architecture, symbols & troubleshooting guide
│   └── BUILD_NOTES.md              <- Step-by-step kernel module build checklist & deployment steps
│
└── 🧩 Patches & Driver Subprojects (`patches/`)
    ├── README.md                   <- Index of all driver patch subprojects and general workflow
    ├── mt7601u-enable-ap-mode.patch<- Root canonical patch file for MediaTek MT7601U AP mode
    │
    ├── 📡 mt7601u-ap-mode/         <- MediaTek MT7601U AP Mode Subproject
    │   ├── README.md               <- Architecture overview & technical details
    │   ├── INSTALL.md              <- Target board deployment & hostapd launch guide
    │   ├── BUILD.md                <- Kbuild compilation workflow with build-module.sh
    │   ├── CHANGELOG.md            <- Version history & development iterations
    │   ├── driver/
    │   │   └── mt7601u.ko          <- VERIFIED WORKING module binary (SHA256: 2c83f127...)
    │   └── source_patch/
    │       └── mt7601u-enable-ap-mode.patch
    │
    └── 📶 aic8800d80-monitor-mode/ <- AIC8800D80 Monitor Mode Subproject
        ├── README.md               <- Dual-build workflow & instrumentation architecture
        ├── INSTALL.md              <- Driver installation and monitor mode commands
        ├── BUILD.md                <- Build notes and configuration parameters
        ├── CHANGELOG.md            <- Iteration history for monitor mode experiments
        ├── README.deploy.md        <- Target deployment checklist
        ├── build.log               <- Compilation logs
        ├── driver/
        │   ├── aic8800_fdrv.ko     <- AIC8800 Wi-Fi driver module
        │   └── aic_load_fw.ko      <- AIC8800 firmware loader module
        ├── source_patch/           <- Monitor mode instrumentation diffs
        └── backup/                 <- Clean baseline vendor files
```

---

## 💻 Target Hardware & Platform Specifications

| Parameter | Specification |
| :--- | :--- |
| **Target Board** | Radxa Cubie A7Z |
| **SoC** | Allwinner A733 (`sun60iw2p1`) |
| **CPU Architecture** | 8x ARM Cortex-A55 @ 1.4 – 2.0 GHz (`aarch64` / ARM64) |
| **GPU / VPU** | Imagination PowerVR / Allwinner Cedar Video Engine |
| **Operating System** | Debian GNU/Linux 11 (Bullseye) / Official Radxa Minimal Image |
| **Target Kernel Release** | `5.15.147-21-a733` |
| **Kernel `vermagic`** | `5.15.147-21-a733 SMP preempt mod_unload aarch64` |
| **USB Host Controller** | Allwinner EHCI 2.0 Host Controller (`sunxi-ehci`) |
| **Cross-Toolchain** | `aarch64-linux-gnu-gcc` (Cross) / `gcc` (Host) |

---

## 🗃️ Driver Subprojects & Release Artifacts

### 1. MediaTek MT7601U AP Mode ([`patches/mt7601u-ap-mode/`](patches/mt7601u-ap-mode/))
* **Hardware:** MediaTek MT7601U 1T1R 802.11b/g/n USB Adapter (`148f:7601`)
* **Feature:** Real Access Point (AP / Hotspot) mode with autonomous on-chip beaconing, dynamic pre-TBTT periodic worker, and `hostapd` support.
* **Status:** **VERIFIED WORKING ON HARDWARE** (SSID broadcast, beaconing, probe requests/responses).
* **Binary Location:** [`patches/mt7601u-ap-mode/driver/mt7601u.ko`](patches/mt7601u-ap-mode/driver/mt7601u.ko)
* **SHA256:** `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833`
* **Dependencies:** `cfg80211`, `mac80211`

### 2. AIC8800D80 Monitor Mode ([`patches/aic8800d80-monitor-mode/`](patches/aic8800d80-monitor-mode/))
* **Hardware:** AIC8800D80 Wi-Fi 6 USB adapter
* **Feature:** Monitor mode packet reception, debug instrumentation, and frame injection tracing.
* **Status:** Ready & Packaged for testing.
* **Binary Location:** [`patches/aic8800d80-monitor-mode/driver/`](patches/aic8800d80-monitor-mode/driver/)

---

## 🚀 Quickstart: Deploying Drivers on the Radxa Board

### MediaTek MT7601U Hotspot Setup:
```bash
# 1. Load mac80211 wireless stack dependency
sudo modprobe mac80211

# 2. Insert custom compiled driver module
sudo insmod patches/mt7601u-ap-mode/driver/mt7601u.ko

# 3. Stop background network managers to prevent interface conflicts
sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true

# 4. Bring down interface, switch mode to AP, and bring up
sudo ip link set wlan1 down
sudo iw dev wlan1 set type __ap
sudo ip link set wlan1 up

# 5. Launch hostapd with test configuration
sudo hostapd /etc/hostapd/hostapd-mt7601u.conf
# Expected output: wlan1: AP-ENABLED
```

---

## 🏗️ Reproducing & Building From Source

All modules are compiled using the companion kernel superproject located at `/workspaces/linux-a733`:

```bash
# 1. Enter kernel superproject
cd /workspaces/linux-a733

# 2. Run superproject pre-build workspace setup (symlinks & headers)
make pre_build

# 3. Generate target kernel configuration
cd src
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ defconfig bsp.config
./scripts/config --set-str LOCALVERSION "-21-a733"
./scripts/config --disable LOCALVERSION_AUTO
./scripts/config --disable NUMA
./scripts/config --module MT7601U
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ olddefconfig

# 4. Apply desired patch (e.g. MT7601U AP mode)
patch -p1 < /workspaces/Radxa-Cubie-A7z/patches/mt7601u-ap-mode/source_patch/mt7601u-enable-ap-mode.patch

# 5. Compile module using universal build helper
cd /workspaces/linux-a733
./build-module.sh drivers/net/wireless/mediatek/mt7601u
```

---

## 📚 Master Documentation Index

| File | Primary Focus | Key Contents |
| :--- | :--- | :--- |
| [`MT7601U_AP_STATUS.md`](MT7601U_AP_STATUS.md) | **MT7601U Verification** | Hardware specs, exact `hostapd` runtime logs, beacon architecture, known errors (`-71`/`-110`), and recovery procedure. |
| [`AI_HANDOFF.md`](AI_HANDOFF.md) | **AI Continuity Blueprint** | Full historical timeline, driver architecture breakdown, known limitations, open questions, and next experiment steps. |
| [`project-state.yaml`](project-state.yaml) | **Machine-Readable State** | Structured YAML tracking board parameters, kernel configs, verified features, unverified items, and SHA256 sums. |
| [`BUILD.md`](BUILD.md) | **Build Architecture** | Reusable `build-module.sh` mechanics, symbol table (`Module.symvers`) generation, and 9-point troubleshooting guide. |
| [`BUILD_NOTES.md`](BUILD_NOTES.md) | **Developer Checklist** | Kbuild environment variables, `.config` management workflow, and target board deployment checklist. |
| [`patches/README.md`](patches/README.md) | **Patch Catalog** | Directory of all available driver patches, unified diff guidelines, and patch application workflows. |
