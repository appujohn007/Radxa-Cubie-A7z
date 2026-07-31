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

- Patched `rwnx_main.c`
- Fixed monitor interface validation logic
- Corrected VIF iteration
- Ignored `NL80211_IFTYPE_P2P_DEVICE`
- Preserved vendor driver architecture

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

- Driver builds successfully
- Firmware loads successfully
- Modules load automatically at boot
- Firmware upload verified
- Wi-Fi interface created successfully
- Ready for monitor mode testing

---

## Repository Layout

```
patches/
└── aic8800d80-monitor-mode/
```

---

Author

Appu John
