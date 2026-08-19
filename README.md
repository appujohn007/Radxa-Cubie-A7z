# Radxa Cubie A7Z Driver & Release Documentation

[![Target Board](https://img.shields.io/badge/Hardware-Radxa%20Cubie%20A7Z-orange.svg)](https://radxa.com)
[![SoC](https://img.shields.io/badge/SoC-Allwinner%20A733%20%28ARM64%29-red.svg)](https://www.allwinnertech.com)
[![Target Kernel](https://img.shields.io/badge/Kernel-5.15.147--21--a733-blue.svg)](https://github.com/radxa-pkg/linux-a733)
[![License](https://img.shields.io/badge/License-GPL--2.0-green.svg)](https://www.gnu.org/licenses/gpl-2.0.html)

Welcome to the central operational documentation, custom driver patch repository, precompiled kernel module release hub, and hardware verification database for the **Radxa Cubie A7Z** single-board computer running the Allwinner Linux 5.15 BSP.

---

## 🌟 Need & Purpose of This Repository

The **Radxa Cubie A7Z** is an ARM64 single-board computer powered by the octa-core **Allwinner A733 (`sun60iw2p1`) SoC**. While the official vendor BSP provides basic hardware enablement, several critical peripheral drivers and specialized wireless operational modes (such as Access Point / Hotspot functionality on MediaTek USB adapters, and frame injection / monitor mode on AIC8800 Wi-Fi) are either unconfigured, disabled, or incomplete in the stock kernel release.

### Core Objectives:
1. **Operational Release Hub:** Delivers verified, drop-in `.ko` driver binaries matching the exact kernel release (`5.15.147-21-a733 SMP preempt mod_unload aarch64`) for immediate board deployment.
2. **Canonical Patch Repository:** Organizes clean, self-contained patch subprojects with source diffs, installation guides, changelogs, and verification checklists.
3. **Hardware Truth & Verification Database:** Records real hardware test results (e.g. `hostapd` runtime logs, beaconing, probe requests/responses, USB protocol quirks) to distinguish verified facts from theoretical features.
4. **AI Continuity & Developer Blueprint:** Maintains a self-contained AI handoff guide enabling future AI coding assistants and developers to immediately understand the entire platform architecture without previous chat history.

---

## 💻 Target Hardware & Platform Specifications

| Parameter | Specification |
| :--- | :--- |
| **Target Board** | Radxa Cubie A7Z |
| **SoC** | Allwinner A733 (`sun60iw2p1`) |
| **CPU Architecture** | 8x ARM Cortex-A55 @ 1.4 – 2.0 GHz (`aarch64` / ARM64) |
| **Operating System** | Debian GNU/Linux 11 (Bullseye) / Official Radxa Minimal Image |
| **Target Kernel Release** | `5.15.147-21-a733` |
| **Kernel `vermagic`** | `5.15.147-21-a733 SMP preempt mod_unload aarch64` |
| **Host USB Controller** | Allwinner EHCI 2.0 Host Controller (`sunxi-ehci`) |
| **Cross-Toolchain** | `aarch64-linux-gnu-gcc` (Cross) / `gcc` (Host) |

---

## 🗺️ Complete Repository Structure & Directory Map

```
Radxa-Cubie-A7z/
│
├── ⚙️ Configuration & Metadata
│   ├── .config                     <- Reference kernel .config for Cubie A7Z (CONFIG_MT7601U=m, NUMA disabled)
│   ├── .gitignore                  <- Git exclusion rules for disk images, logs & temp files
│   └── project-state.yaml          <- Machine-readable YAML state tracking hashes, statuses & parameters
│
├── 📖 Master Documentation
│   ├── README.md                   <- This document (general intro, architecture, specs & patch directory)
│   ├── BUILD.md                    <- Master kernel build system architecture, symbols & troubleshooting guide
│   └── AI_HANDOFF.md               <- Self-contained project memory for future AI sessions & developers
│
└── 🧩 Patches & Driver Subprojects (`patches/`)
    ├── README.md                   <- Patch catalog index, feature matrix & patch application workflow
    │
    ├── 📡 mt7601u-ap-mode/         <- MediaTek MT7601U AP Mode Subproject
    │   ├── README.md               <- Architecture overview & technical details
    │   ├── INSTALL.md              <- Target board deployment & hostapd launch guide
    │   ├── BUILD.md                <- Kbuild compilation workflow with build-module.sh
    │   ├── STATUS.md               <- Authoritative technical record & hardware verification logs
    │   ├── BUILD_NOTES.md          <- Developer build & kernel config checklist
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

## 🗃️ Driver Patches & Subprojects Catalog

All driver-specific instructions, deployment procedures, and precompiled binaries are organized in dedicated subdirectories under [`patches/`](patches/):

| Subproject Directory | Target Hardware | Feature Added | Verification Status | Direct Links |
| :--- | :--- | :--- | :--- | :--- |
| **[`patches/mt7601u-ap-mode/`](patches/mt7601u-ap-mode/)** | MediaTek MT7601U (`148f:7601`) | Access Point (AP / Hotspot) mode with autonomous MAC beaconing & `hostapd` | **VERIFIED WORKING** | [README](patches/mt7601u-ap-mode/README.md) · [INSTALL](patches/mt7601u-ap-mode/INSTALL.md) · [BUILD](patches/mt7601u-ap-mode/BUILD.md) · [STATUS](patches/mt7601u-ap-mode/STATUS.md) |
| **[`patches/aic8800d80-monitor-mode/`](patches/aic8800d80-monitor-mode/)** | AIC8800D80 USB Wi-Fi | Monitor mode packet reception, frame injection tracing & debug instrumentation | **READY / TESTING** | [README](patches/aic8800d80-monitor-mode/README.md) · [INSTALL](patches/aic8800d80-monitor-mode/INSTALL.md) · [BUILD](patches/aic8800d80-monitor-mode/BUILD.md) |

---

## 📚 Master Documentation Index

| File | Primary Focus | Key Contents |
| :--- | :--- | :--- |
| [`README.md`](README.md) | **General Landing Page** | Platform specs, repository mission, architecture tree, and patch catalog. |
| [`BUILD.md`](BUILD.md) | **Build Architecture** | Reusable `build-module.sh` mechanics, symbol table (`Module.symvers`) generation, and 9-point troubleshooting guide. |
| [`AI_HANDOFF.md`](AI_HANDOFF.md) | **AI Continuity Blueprint** | Full historical timeline, driver architecture breakdown, known limitations, open questions, and next experiment steps. |
| [`project-state.yaml`](project-state.yaml) | **Machine-Readable State** | Structured YAML tracking board parameters, kernel configs, verified features, unverified items, and SHA256 sums. |
| [`patches/README.md`](patches/README.md) | **Patch Catalog** | Directory of all available driver patches, unified diff guidelines, and patch application workflows. |
| [`patches/mt7601u-ap-mode/STATUS.md`](patches/mt7601u-ap-mode/STATUS.md) | **MT7601U Verification** | Hardware specs, exact `hostapd` runtime logs, beacon architecture, known errors (`-71`/`-110`), and recovery procedure. |
