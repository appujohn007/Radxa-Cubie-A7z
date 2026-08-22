# AIC8800 Driver Build System Reference

## Target Environment
- **Target Kernel**: `5.15.147-21-a733`
- **Architecture**: `arm64` (`aarch64-linux-gnu-`)
- **Target Vermagic**: `5.15.147-21-a733 SMP preempt mod_unload aarch64`
- **Compiler**: `aarch64-linux-gnu-gcc` (Ubuntu 13.3.0)

---

## Build Procedure

The build superproject is located at `/workspaces/linux-a733`.

### 1. Using the Project Module Build Helper (Recommended)

To build both `aic8800_fdrv.ko` and `aic_load_fw.ko` with consistent configuration:

```bash
cd /workspaces/linux-a733
./build-module.sh bsp/drivers/net/wireless/aic8800/usb
```

### 2. Manual Kernel Makefile Invocation

```bash
cd /workspaces/linux-a733/src
LOCALVERSION= make -j$(nproc) \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    HOSTCC=gcc \
    BSP_TOP=bsp/ \
    LICHEE_KERN_DIR=./ \
    EXTRA_CFLAGS="-I/workspaces/linux-a733/bsp/drivers/usb/host" \
    M=bsp/drivers/net/wireless/aic8800/usb \
    modules
```

To build only `aic_load_fw.ko`:
```bash
cd /workspaces/linux-a733/src
LOCALVERSION= make -j$(nproc) \
    ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    HOSTCC=gcc \
    BSP_TOP=bsp/ \
    LICHEE_KERN_DIR=./ \
    EXTRA_CFLAGS="-I/workspaces/linux-a733/bsp/drivers/usb/host" \
    M=bsp/drivers/net/wireless/aic8800/usb/aic_load_fw \
    modules
```

---

## Build Configuration & Inter-Module Dependency Notes

### 1. Firmware Search Path Configuration (`CONFIG_PLATFORM_UBUNTU = y`)
- **Issue**: In default vendor configurations, `aic_default_fw_path` defaulted to `"/vendor/etc/firmware"` unless `CONFIG_PLATFORM_UBUNTU=y` was defined, causing `filp_open()` to fail on Linux systems where firmware is located in `/lib/firmware/aic8800D80/`.
- **Fix**: Defined `CONFIG_PLATFORM_UBUNTU = y` and `ccflags-$(CONFIG_PLATFORM_UBUNTU) += -DCONFIG_PLATFORM_UBUNTU` in [`aic_load_fw/Makefile`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic_load_fw/Makefile).

### 2. Memory Preallocation & Exported Symbols (`CONFIG_PREALLOC_RX_SKB = y`)
- **Issue**: When building `aic_load_fw` independently, `CONFIG_PREALLOC_RX_SKB ?= n` caused `aicwf_rx_prealloc.c` to be omitted from `aic_load_fw.ko`. When `aic8800_fdrv.ko` (built with `CONFIG_PREALLOC_RX_SKB = y`) loaded, it failed with:
  ```text
  Unknown symbol aicwf_rxbuff_size_get
  Unknown symbol aicwf_prealloc_rxbuff_alloc
  Unknown symbol aicwf_prealloc_rxbuff_free
  ```
- **Fix**: Set `CONFIG_PREALLOC_RX_SKB ?= y` in [`aic_load_fw/Makefile`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic_load_fw/Makefile). This ensures `aicwf_rx_prealloc.o` is compiled and exports all four symbols required by `aic8800_fdrv.ko`:
  - `aicwf_rxbuff_size_get`
  - `aicwf_prealloc_rxbuff_alloc`
  - `aicwf_prealloc_rxbuff_free`
  - `aicwf_prealloc_txq_alloc`

---

## Build Artifacts

- **Driver Module**: `bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/aic8800_fdrv.ko`
- **Firmware Loader**: `bsp/drivers/net/wireless/aic8800/usb/aic_load_fw/aic_load_fw.ko`

### Verification Command
```bash
modinfo aic8800_fdrv.ko | grep vermagic
modinfo aic_load_fw.ko | grep vermagic
# Expected: vermagic: 5.15.147-21-a733 SMP preempt mod_unload aarch64
```
