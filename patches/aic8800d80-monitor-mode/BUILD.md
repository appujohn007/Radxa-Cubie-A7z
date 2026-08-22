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

Run from `/workspaces/linux-a733`:

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

---

## Build Artifacts

- **Driver Module**: `bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/aic8800_fdrv.ko`
- **Firmware Loader**: `bsp/drivers/net/wireless/aic8800/usb/aic_load_fw/aic_load_fw.ko`

### Verification Command
```bash
modinfo aic8800_fdrv.ko | grep vermagic
# Expected: vermagic: 5.15.147-21-a733 SMP preempt mod_unload aarch64
```
