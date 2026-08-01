# Changelog

## 2026-08-01

### Driver

- Verified AIC8800 USB driver rebuild succeeds with monitor mode support enabled
- Confirmed `CONFIG_RWNX_MON_DATA` is enabled
- Confirmed the earlier `RWNX_VIF_TYPE(vif_el)` fix remains included
- Confirmed the `NL80211_IFTYPE_P2P_DEVICE` exclusion remains included
- Confirmed the monitor interface can coexist with a managed interface without the earlier interface-removal failure

### Firmware

- Verified firmware loads correctly on the patched driver
- Confirmed the driver loads automatically at boot

### Modules

- Verified rebuilt modules:
  - `aic8800_fdrv.ko`
  - `aic_load_fw.ko`

### Runtime

- Verified post-reboot interface layout:
  - AIC8800: `wlan0` -> managed, `wlan1` -> monitor
  - MT7601U: `wlan2` -> managed
- Verified managed Wi-Fi remains connected while the monitor interface exists

### Known issue

- MT7601U no longer reconnects automatically because its interface name changed after the AIC driver created `wlan1`
- This is believed to be a NetworkManager configuration issue rather than a driver failure

---

## 2026-07-31

### Driver

- Patched monitor mode validation
- Fixed interface type check
- Added P2P_DEVICE exclusion

### Firmware

- Fixed firmware search path
- Added permanent firmware symlink

### Modules

- Built
  - aic_load_fw.ko
  - aic8800_fdrv.ko

### Installation

- Installed modules into

```
/lib/modules/5.15.147-21-a733/extra
```

- Added automatic loading through

```
/etc/modules-load.d/aic8800.conf
```

### Verified

- Module loading
- Firmware upload
- Driver initialization
- Wi-Fi interface creation
- Successful reboot

