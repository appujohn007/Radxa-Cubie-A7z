# Changelog

## 2026-08-01

### Monitor TX Injection Instrumentation Debug Build

- Instrumented the complete monitor mode TX injection path with `printk(KERN_ERR "MONDBG: ...\n")` logging:
  - `rwnx_select_queue()` ([`rwnx_main.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_main.c))
  - `rwnx_select_txq()` ([`rwnx_tx.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_tx.c))
  - `rwnx_start_monitor_if_xmit()` ([`rwnx_tx.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_tx.c))
  - `rwnx_txq_queue_skb()` ([`rwnx_txq.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_txq.c))
  - `rwnx_hwq_process()` ([`rwnx_txq.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_txq.c))
  - `rwnx_tx_push()` ([`rwnx_tx.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_tx.c))
  - `aicwf_frame_tx()` ([`aicwf_txrxif.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/aicwf_txrxif.c))
  - `aicwf_usb_bus_txdata()` ([`aicwf_usb.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/aicwf_usb.c))
  - `aicwf_usb_tx_process()` ([`aicwf_usb.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/aicwf_usb.c))
  - `aicwf_usb_tx_complete()` ([`aicwf_usb.c`](file:///workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/aicwf_usb.c))
- Added defensive NULL pointer checks before every pointer dereference across all listed functions to prevent kernel Oops crashes and log exact NULL pointer origins.
- Identified and fixed a vendor driver use-after-free bug in `aicwf_usb_bus_txdata()` where `txhdr->sw_hdr->need_cfm` was accessed after `txhdr->sw_hdr` had been freed by `kmem_cache_free()`.
- Built the debug driver module `aic8800_fdrv.ko` and packaged it under `/workspaces/monitor-debug-build/` alongside `git.diff`, `build.log`, `SHA256SUMS`, and `README.md`.
- Added patch file `monitor_tx_instrumentation.diff` into `source_patch/`.

### Monitor TX Injection Fix (Previous Pass)

- Updated the monitor injection path in `rwnx_tx.c`
- Switched monitor TX to the VIF unknown TXQ so injection no longer depends on peer-STA state
- Added a radiotap iterator guard to avoid null-field dereferences during monitor injection
- Left `driver/aic_load_fw.ko` unchanged because it was not rebuilt for this patch

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

- Verified rebuilt debug module: `/workspaces/monitor-debug-build/aic8800_fdrv.ko`
- Confirmed `aic_load_fw.ko` remains unchanged

### Runtime

- Verified post-reboot interface layout:
  - AIC8800: `wlan0` -> managed, `wlan1` -> monitor
  - MT7601U: `wlan2` -> managed
- Verified managed Wi-Fi remains connected while the monitor interface exists

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

- Installed modules into `/lib/modules/5.15.147-21-a733/extra`
- Added automatic loading through `/etc/modules-load.d/aic8800.conf`

### Verified

- Module loading
- Firmware upload
- Driver initialization
- Wi-Fi interface creation
- Successful reboot
