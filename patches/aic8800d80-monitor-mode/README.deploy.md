# AIC8800 monitor TX fix deployment package

This directory contains the already-built driver module for deployment to the Radxa Cubie A7Z.

## Files
- aic8800_fdrv.ko: rebuilt kernel module containing the monitor TX fix
- monitor_tx_fix.patch: source diff for the patch
- SHA256SUMS: SHA256 digest for the packaged module
- build.log: build output captured from the build step

## Installation on Radxa
1. Copy the module to the board:
   scp aic8800_fdrv.ko radxa@<board-ip>:/tmp/
2. Install on the board:
   sudo install -m 0644 /tmp/aic8800_fdrv.ko /lib/modules/$(uname -r)/extra/aic8800_fdrv.ko
   sudo depmod -a
3. Reload the module if needed:
   sudo modprobe -r aic8800_fdrv 2>/dev/null || true
   sudo modprobe aic8800_fdrv
4. Verify the module:
   modinfo /lib/modules/$(uname -r)/extra/aic8800_fdrv.ko
   sha256sum /lib/modules/$(uname -r)/extra/aic8800_fdrv.ko
   lsmod | grep aic8800_fdrv
