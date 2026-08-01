# AIC8800 Driver Dual Build System Reference

## Build Commands

To compile the driver from the BSP source tree (`/workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/`):

```bash
cd /workspaces/linux-a733/src
make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc KBUILD_DEFCONFIG=bsp.config M=/workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb modules
```

---

## Output Packages

- **Build A (Instrumentation)**:
  Path: `/workspaces/monitor-build-A-instrumentation/aic8800_fdrv.ko`
  Contains: Pure `MONDBG:` logging, 100% original vendor logic.

- **Build B (Fix)**:
  Path: `/workspaces/monitor-build-B-fix/`
  Contains: Placeholder `README.md` (Will be built after Build A log analysis).
