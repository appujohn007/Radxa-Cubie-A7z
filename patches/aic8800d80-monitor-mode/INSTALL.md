# AIC8800 Driver Installation & Deployment Guide

## Deployment Instructions for Build A

1. Copy `aic8800_fdrv.ko` from `/workspaces/monitor-build-A-instrumentation/` to your target Radxa Cubie A7Z board.

2. Unload any existing driver module:
   ```bash
   sudo rmmod aic8800_fdrv
   ```

3. Load the Build A module:
   ```bash
   sudo insmod aic8800_fdrv.ko
   ```

4. Configure monitor mode:
   ```bash
   sudo iw dev wlan1 set type monitor
   sudo ip link set wlan1 up
   ```

5. Monitor `dmesg` output during injection testing:
   ```bash
   sudo dmesg -w &
   sudo aireplay-ng --test wlan1
   ```
