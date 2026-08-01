# AIC8800 Driver Build Instructions & Debug Build Reference

## Build Instructions

To compile the AIC8800 USB Wi-Fi driver module (`aic8800_fdrv.ko`):

```bash
cd /workspaces/linux-a733/src
make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc KBUILD_DEFCONFIG=bsp.config M=/workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb modules
```

---

## Debug Build Location

As requested, the rebuilt debug kernel module is kept isolated at:

```
/workspaces/monitor-debug-build/aic8800_fdrv.ko
```

It is NOT copied or committed to `/workspaces/Radxa-Cubie-A7z/patches/aic8800d80-monitor-mode/driver/`.

---

## Instrumentation & Debug Patch Files

- Full Patch Diff: `/workspaces/Radxa-Cubie-A7z/patches/aic8800d80-monitor-mode/source_patch/monitor_tx_instrumentation.diff` (1567 lines)
- Debug Build Package: `/workspaces/monitor-debug-build/`
