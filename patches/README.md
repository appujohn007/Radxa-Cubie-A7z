# Driver Patches & Extensions for Radxa Cubie A7Z

This directory houses all hardware driver patches, enhancements, instrumentation diffs, and precompiled kernel modules for the **Radxa Cubie A7Z** (Allwinner A733, Kernel `5.15.147-21-a733`).

---

## 📑 Available Patch Subprojects

| Patch Subproject | Target Hardware | Driver Subsystem | Feature Added | Status | Quick Links |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **[`mt7601u-ap-mode/`](mt7601u-ap-mode/)** | MediaTek MT7601U (`148f:7601`) | `mac80211` / `cfg80211` | Access Point (AP / Hotspot) mode with autonomous MAC beaconing & `hostapd` support | **VERIFIED WORKING** | [README](mt7601u-ap-mode/README.md) · [INSTALL](mt7601u-ap-mode/INSTALL.md) · [BUILD](mt7601u-ap-mode/BUILD.md) · [CHANGELOG](mt7601u-ap-mode/CHANGELOG.md) |
| **[`aic8800d80-monitor-mode/`](aic8800d80-monitor-mode/)** | AIC8800D80 USB Wi-Fi | Allwinner BSP | Monitor mode & frame injection instrumentation / debug tracing | **TESTING / READY** | [README](aic8800d80-monitor-mode/README.md) · [INSTALL](aic8800d80-monitor-mode/INSTALL.md) · [BUILD](aic8800d80-monitor-mode/BUILD.md) · [CHANGELOG](aic8800d80-monitor-mode/CHANGELOG.md) |

---

## 🗂️ Standardized Patch Folder Layout

Each patch subproject follows a consistent, modular folder structure:

```
patches/<patch-name>/
├── README.md               <- Technical overview, architectural analysis & feature summary
├── INSTALL.md              <- Step-by-step target deployment and runtime test instructions
├── BUILD.md                <- Compilation instructions using build-module.sh
├── CHANGELOG.md            <- Version history, bug fixes, and development iterations
├── driver/                 <- Precompiled, verified kernel module (.ko) binaries
│   └── <module_name>.ko
└── source_patch/           <- Canonical unified diff (.patch / .diff) files
    └── <patch_name>.patch
```

---

## 🔧 General Patch Application Workflow

To apply any patch to a clean checkout of the `linux-a733` source tree:

```bash
# 1. Navigate to kernel source directory
cd /workspaces/linux-a733/src

# 2. Dry-run verify the patch
patch -p1 --dry-run < /workspaces/Radxa-Cubie-A7z/patches/<patch-name>/source_patch/<patch-name>.patch

# 3. Apply the patch
patch -p1 < /workspaces/Radxa-Cubie-A7z/patches/<patch-name>/source_patch/<patch-name>.patch

# 4. Build the module using the global build script
cd /workspaces/linux-a733
./build-module.sh <relative_driver_path>
```
