# Radxa Cubie A7Z - MT7601U USB Wi-Fi Driver Notes

## Environment

* **Target Board:** Radxa Cubie A7Z
* **OS:** Official Radxa Debian Minimal
* **Target Kernel:** `5.15.147-21-a733`
* **USB Wi-Fi Adapter:** MediaTek MT7601U (USB ID: `148f:7601`)
* **Kernel Superproject Repository:** `https://github.com/radxa-pkg/linux-a733`

---

## Problem Overview

The stock Radxa kernel image had MediaTek MT7601U support disabled (`CONFIG_MT7601U is not set`). As a result, plugging in the MT7601U USB Wi-Fi adapter detected the USB device, but no wireless network interface appeared (`wlan1` missing).

---

## Kernel Configuration & Submodule Setup

### 1. Repository Initialisation
Clone the `linux-a733` superproject with all required submodules:

```bash
git clone --recursive https://github.com/radxa-pkg/linux-a733.git
cd linux-a733
make pre_build
```

### 2. Tracked Config Workflow
The kernel configuration is built from the tracked `device-a733` submodule (`bsp_defconfig` / `bsp.config`):

```bash
cd src
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ defconfig bsp.config
./scripts/config --set-str LOCALVERSION "-21-a733"
./scripts/config --disable LOCALVERSION_AUTO
./scripts/config --disable NUMA
./scripts/config --module MT7601U
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ olddefconfig
```

---

## Validated Automated Module Build Command

Use the global reusable build script located at the root of `linux-a733`:

```bash
cd linux-a733
./build-module.sh drivers/net/wireless/mediatek/mt7601u
```

### Key Build Parameters Explained
* **`LOCALVERSION=`**: Passed as empty on make invocations so `scripts/setlocalversion` does NOT append `+` to `vermagic`.
* **`HOSTCC=gcc`**: Overrides `HOSTCC=$(CROSS_COMPILE)gcc` to prevent host build tools from failing with `scripts/basic/fixdep: Exec format error`.
* **`M=drivers/net/wireless/mediatek/mt7601u`**: Restricts compilation to the specific module directory, bypassing broken/incomplete BSP components (e.g. `cedar_ve.h`).
* **`EXTRA_CFLAGS="-I<top_dir>/bsp/drivers/usb/host"`**: Resolves relative USB host header includes during `vmlinux` symbol table generation.

---

## Module Verification Results

After compilation, verify the module dependencies and release string:

```bash
modinfo src/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko | grep -E 'depends|vermagic'
```

**Validated Output:**
```text
depends:        cfg80211,mac80211
vermagic:       5.15.147-21-a733 SMP preempt mod_unload aarch64
```

---

## Target Installation & Deployment Checklist (On Radxa Device)

### 1. Verify Running Kernel
```bash
uname -r
# Expected: 5.15.147-21-a733
```

### 2. Verify Module `vermagic`
```bash
modinfo patches/mt7601u-ap-mode/driver/mt7601u.ko | grep vermagic
# Expected: 5.15.147-21-a733 SMP preempt mod_unload aarch64
```

### 3. Load Dependency & Driver Module
```bash
# Load mac80211 dependency first
sudo modprobe mac80211

# Insert custom compiled driver
sudo insmod patches/mt7601u-ap-mode/driver/mt7601u.ko
```

### 4. Verify Network Interface Creation
```bash
ip link
iw dev
```
**Expected Output:** Interface `wlan1` appears and is operational.

---

## MT7601U AP Mode Status & Implementation

The AP interface mode implementation is verified working on target hardware:
* **Current Status:** Verified Working (Beaconing, SSID broadcast, probe requests/responses, `hostapd` reaching `AP-ENABLED`).
* **Canonical Patch:** [`source_patch/mt7601u-enable-ap-mode.patch`](source_patch/mt7601u-enable-ap-mode.patch).
* **Known-Good Distributable Binary:** [`driver/mt7601u.ko`](driver/mt7601u.ko) (SHA256: `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833`).
* **Authoritative Documentation:** See [`STATUS.md`](STATUS.md) for full technical analysis, hostapd runtime test logs, and verification checklist.
* **AI Continuity Guide:** See [`../../AI_HANDOFF.md`](../../AI_HANDOFF.md).
