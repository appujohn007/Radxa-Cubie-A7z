# Building BSP Kernel Modules for the Radxa Cubie A7Z

## Architecture & Repository Roles

The development setup is separated into two repositories with distinct responsibilities:

### 1. `Radxa-Cubie-A7z` (Release & Operational Repository)
* **Role:** Operations, release packaging, deployment guides, troubleshooting documentation, patch tracking, module backups, and deployment artifacts.
* **Contents:**
  * Release-ready `.ko` kernel modules for deployment.
  * Operational documentation ([`BUILD.md`](BUILD.md), [`BUILD_NOTES.md`](BUILD_NOTES.md), [`Readme.Md`](Readme.Md)).
  * Driver patches (e.g. [`patches/aic8800d80-monitor-mode/`](patches/aic8800d80-monitor-mode/)).

### 2. `linux-a733` (Kernel Superproject & Source Repository)
* **Role:** Canonical kernel source, vendor BSP submodules, device definitions, tracked kernel configuration sources, build scripts, and experimental source changes.
* **Submodule Structure:**
  * `src/`: Linux kernel 5.15 source tree (submodule).
  * `bsp/`: Vendor Allwinner BSP drivers and headers (submodule).
  * `device-a733/`: Board and SoC configurations, including `bsp_defconfig` (submodule).
  * `build-module.sh`: Global reusable module build helper script.

---

## Build Environment Requirements

The validated kernel build environment is:

* **Target Hardware:** Radxa Cubie A7Z (ARM64)
* **Target Kernel Release:** `5.15.147-21-a733`
* **Architecture:** `arm64`
* **Cross Compiler:** `aarch64-linux-gnu-`
* **Host Compiler:** `gcc` (x86_64 host compiler; required for host utilities)

### Required Environment Variables & Parameters
When running `kbuild` commands directly inside `src/`:
* `ARCH=arm64`: Target architecture.
* `CROSS_COMPILE=aarch64-linux-gnu-`: ARM64 cross-compiler prefix.
* `HOSTCC=gcc`: Force host compiler to local `gcc` (prevents host tool execution `Exec format error`).
* `BSP_TOP=bsp/`: Points `kbuild` to vendor BSP directory.
* `LICHEE_KERN_DIR=./`: Allwinner build root reference.
* `LOCALVERSION=`: Explicitly empty on make invocation to prevent appending a `+` suffix to `vermagic`.
* `EXTRA_CFLAGS="-I<path_to_linux-a733>/bsp/drivers/usb/host"`: Include path required by Allwinner USB host drivers during `vmlinux` symbol table builds.

---

## Workspace Setup & Superproject Initialisation

A clean checkout of `linux-a733` requires initializing submodules and running superproject pre-build fixups:

```bash
# 1. Clone superproject with all submodules recursively
git clone --recursive https://github.com/radxa-pkg/linux-a733.git
cd linux-a733

# 2. Execute superproject workspace setup
make pre_build
```

### What `make pre_build` Does
* Creates the mandatory symlink `src/bsp -> ../bsp` so Kbuild evaluates `bsp/Kconfig` and `bsp/` headers correctly.
* Symlinks `src/arch/arm64/configs/bsp.config` to `../../../../device-a733/configs/default/linux-5.15/bsp_defconfig`.
* Generates `bsp/include/sunxi-autogen.h`.
* Copies DTSI files and `dt-bindings` headers into `src/`.

---

## Configuration & Symbol State Management

### 1. Kernel Configuration Source of Truth
* **Tracked Source:** `device-a733/configs/default/linux-5.15/bsp_defconfig` (symlinked as `src/arch/arm64/configs/bsp.config`).
* **Generated State:** `src/.config` is a **generated build state file** (ignored by Git) created when Kbuild runs:
  ```bash
  cd src && make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc BSP_TOP=bsp/ LICHEE_KERN_DIR=./ defconfig bsp.config
  ```
* **Local Adjustments:** Set `CONFIG_LOCALVERSION="-21-a733"`, disable `CONFIG_LOCALVERSION_AUTO`, and disable `CONFIG_NUMA` (since ARM64 defconfig enables NUMA by default, whereas Cubie A7Z target kernel has NUMA disabled).

### 2. Symbol Version Table (`Module.symvers`)
* **Generated State:** `src/Module.symvers` and `src/vmlinux.symvers` are generated build artifacts (ignored by Git).
* **Generation Procedure:** To resolve kernel symbols (`kmalloc_caches`, `msleep`, `single_open`, etc.) without modpost errors, `vmlinux` is built with `EXTRA_CFLAGS="-I.../bsp/drivers/usb/host"` to produce `vmlinux.symvers`, which is then copied to `src/Module.symvers`.

---

## Reusable Global Build Helper (`build-module.sh`)

The global build script `build-module.sh` located at the root of `linux-a733` automates setup, configuration, symbol table generation, and module compilation for **any** kernel driver.

### Canonical Script Usage

```bash
cd linux-a733

# Reusable build command syntax:
./build-module.sh <relative_module_path>

# Example 1: MediaTek MT7601U Wi-Fi Driver
./build-module.sh drivers/net/wireless/mediatek/mt7601u

# Example 2: AIC8800 USB Wi-Fi Driver
./build-module.sh bsp/drivers/net/wireless/aic8800/usb
```

---

## Validated Results & Verification

### 1. MediaTek MT7601U Driver
Rebuilding `drivers/net/wireless/mediatek/mt7601u` using `build-module.sh` builds cleanly with **0 modpost errors**:

```bash
modinfo src/drivers/net/wireless/mediatek/mt7601u/mt7601u.ko | grep -E 'depends|vermagic'
```

**Validated Output:**
```text
depends:        cfg80211,mac80211
vermagic:       5.15.147-21-a733 SMP preempt mod_unload aarch64
```

### 2. AIC8800 USB Wi-Fi Subtree
Running `build-module.sh bsp/drivers/net/wireless/aic8800/usb` compiles the Wi-Fi modules:
* `aic_load_fw.ko` – Compiles cleanly.
* `aic8800_fdrv.ko` – Compiles cleanly.
* *Note on `aic_btusb.ko`:* The Bluetooth HCI helper module `aic_btusb.ko` inside the AIC USB subtree requires Bluetooth HCI symbols (`hci_register_dev`, etc.) from `net/bluetooth`. If building `aic_btusb.ko` stand-alone, ensure `net/bluetooth` symbol definitions are present in `Module.symvers`.

---

## Isolation of Experimental Code (MT7601U AP Mode)

To keep experimental driver work strictly separated from the stable global build infrastructure:

* **Stable Infrastructure:** `make pre_build`, `build-module.sh`, `bsp_defconfig`, and Kbuild environment parameters.
* **MT7601U AP Experiment:**
  * Branch: `mt7601u-ap-experiment` in `src/`.
  * Source Change: [`src/drivers/net/wireless/mediatek/mt7601u/init.c`](../linux-a733/src/drivers/net/wireless/mediatek/mt7601u/init.c) line 612 adds `BIT(NL80211_IFTYPE_AP)` to `wiphy->interface_modes`.
  * Status: **Experimental**. This change belongs solely to the feature experiment branch and is NOT part of the stable/global build infrastructure.

---

## Troubleshooting Guide

### 1. `Kconfig:10: can't open file "bsp/Kconfig"`
* **Cause:** The symlink `src/bsp -> ../bsp` is missing in the kernel source directory.
* **Fix:** Run `make pre_build` from the root of `linux-a733`.

### 2. `bsp/Kconfig:5: can't open file "platform/Kconfig"`
* **Cause:** Kbuild was invoked without `BSP_TOP=bsp/`.
* **Fix:** Pass `BSP_TOP=bsp/` on all `make` commands inside `src/`.

### 3. `The base file '.config' does not exist`
* **Cause:** `make bsp.config` was invoked directly without generating a base `.config`.
* **Fix:** Run `make defconfig bsp.config`.

### 4. Missing `Module.symvers` / Unresolved Symbol Warnings
* **Cause:** Kbuild has not generated the kernel symbol version table.
* **Fix:** Build `vmlinux` using `build-module.sh` (or `make vmlinux`) and copy `vmlinux.symvers` to `Module.symvers`.

### 5. Release Version Has `+` Suffix (`5.15.147-21-a733+`)
* **Cause:** `scripts/setlocalversion` detected an untagged Git commit while `LOCALVERSION` was unset.
* **Fix:** Pass `LOCALVERSION=` (explicitly empty) on all make invocations and when updating `include/config/kernel.release`.

### 6. `fixdep: Exec format error`
* **Cause:** `HOSTCC` defaulted to `aarch64-linux-gnu-gcc` instead of the host x86_64 compiler.
* **Fix:** Explicitly pass `HOSTCC=gcc`.

### 7. `fatal error: ../sunxi_usb/include/sunxi_usb_debug.h: No such file or directory`
* **Cause:** Relative include path failure in `bsp/drivers/usb/host/sunxi-hci.h`.
* **Fix:** Pass `EXTRA_CFLAGS="-I<top_dir>/bsp/drivers/usb/host"`.

### 8. `ERROR: modpost: "numa_node" ... undefined`
* **Cause:** ARM64 default `defconfig` enables NUMA, whereas target kernel has NUMA disabled.
* **Fix:** Run `./scripts/config --disable NUMA` and `make olddefconfig`.

### 9. AIC8800 `aic_btusb.ko` Unresolved Bluetooth Symbols
* **Cause:** `aic_btusb.ko` uses Bluetooth stack symbols exported by `net/bluetooth`.
* **Fix:** Compile `net/bluetooth` or include Bluetooth symbols in `Module.symvers` prior to building `aic_btusb.ko`.
