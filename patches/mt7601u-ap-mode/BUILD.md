# MediaTek MT7601U AP Mode - Build & Compilation Guide

This document outlines the step-by-step procedure to apply the AP mode patch and compile the `mt7601u.ko` kernel module using the `linux-a733` build infrastructure.

---

## 1. Prerequisites

* **Cross-Compiler:** `aarch64-linux-gnu-gcc`
* **Host Compiler:** `gcc` (x86_64)
* **Kernel Superproject:** `linux-a733`
* **Target Kernel Release:** `5.15.147-21-a733`

---

## 2. Step-by-Step Compilation Workflow

### Step 1: Navigate to Kernel Superproject
```bash
cd /workspaces/linux-a733
```

### Step 2: Initialize Superproject Environment Fixups
```bash
make pre_build
```
*What this does:* Creates mandatory symlinks (`src/bsp -> ../bsp`), copies SoC DTSI definitions, and generates `bsp/include/sunxi-autogen.h`.

### Step 3: Configure Kernel Configuration
```bash
cd src
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ defconfig bsp.config
./scripts/config --set-str LOCALVERSION "-21-a733"
./scripts/config --disable LOCALVERSION_AUTO
./scripts/config --disable NUMA
./scripts/config --module MT7601U
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ olddefconfig
```

### Step 4: Apply the AP Mode Patch
```bash
# Verify dry-run
patch -p1 --dry-run < /workspaces/Radxa-Cubie-A7z/patches/mt7601u-ap-mode/source_patch/mt7601u-enable-ap-mode.patch

# Apply patch
patch -p1 < /workspaces/Radxa-Cubie-A7z/patches/mt7601u-ap-mode/source_patch/mt7601u-enable-ap-mode.patch
```

### Step 5: Build Module via Universal Build Script
```bash
cd /workspaces/linux-a733
./build-module.sh drivers/net/wireless/mediatek/mt7601u
```

### Step 6: Verify Compiled Output
```bash
# Check vermagic and dependencies
modinfo src/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko | grep -E 'depends|vermagic'

# Verify SHA256 matches verified build
sha256sum src/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko
# Expected: 2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833
```
