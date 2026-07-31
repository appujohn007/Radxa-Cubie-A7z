# Changelog

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

