# AIC8800D80 USB Wi-Fi Driver Patch (Radxa Cubie A7Z)

## Overview

This repository contains a patched build of the AIC8800D80 USB Wi-Fi driver for the Radxa Cubie A7Z.

The original vendor driver was modified to improve monitor mode support and rebuilt for the Radxa kernel.

Kernel Version

```
5.15.147-21-a733
```

Driver Version

```
RWNX v6.4.3.0
Release: 2024_1119_06da8476
```

---

## Changes

### Driver

- Updated the monitor injection path in `rwnx_tx.c`
- Added a safe monitor TX path that uses the VIF unknown TXQ instead of relying on peer-STA state
- Added a radiotap iterator guard so malformed or unexpected radiotap data does not dereference a null field
- Preserved the existing vendor driver architecture

### Module packaging

- Rebuilt and packaged `driver/aic8800_fdrv.ko`
- `driver/aic_load_fw.ko` remains unchanged and was not rebuilt for this patch

### Firmware

No firmware binaries were modified.

The firmware loading issue was caused by an incorrect firmware search path.

A permanent symbolic link was added:

```
/lib/firmware/aic8800D80
    ->
/lib/firmware/aic8800_fw/USB/aic8800D80
```

---

## Included Files

```
driver/
    aic_load_fw.ko
    aic8800_fdrv.ko

backup/
    rwnx_main.clean.c

source_patch/
    rwnx_main.diff
```

---

## Status

- Patched AIC8800 USB driver builds successfully
- Firmware loads correctly
- Driver loads automatically at boot
- Monitor interface can coexist with a managed interface
- `CONFIG_RWNX_MON_DATA` is enabled
- Rebuilt module is:
  - `driver/aic8800_fdrv.ko`
- Unchanged module is:
  - `driver/aic_load_fw.ko`
- Verified runtime interface layout after reboot:
  - AIC8800: `wlan0` -> managed, `wlan1` -> monitor
  - MT7601U: `wlan2` -> managed
- Managed Wi-Fi remains connected while the monitor interface exists
- The previous interface-removal issue has been resolved
- The earlier `RWNX_VIF_TYPE(vif_el)` fix remains included
- The `NL80211_IFTYPE_P2P_DEVICE` exclusion remains included
- Known remaining issue: MT7601U no longer reconnects automatically because its interface name changed after the AIC driver created `wlan1`; this is believed to be a NetworkManager configuration issue rather than a driver failure

---

## Repository Layout

```
patches/
└── aic8800d80-monitor-mode/
```

---

Author

Appu John
