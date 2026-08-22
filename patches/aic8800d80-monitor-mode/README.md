# AIC8800D80 Monitor Mode Driver Patch for Radxa Cubie A7Z

## Overview

This directory contains the production-quality kernel driver patch, build references, and deployment package for enabling **802.11 Monitor Mode & Packet Injection** on the **AIC8800D80** internal Wi-Fi chipset of the **Radxa Cubie A7Z** (Allwinner A733 / `sun60iw2p1`, ARM64, Kernel `5.15.147-21-a733`).

---

## 1. Problem Statement & Failure Analysis

### Original Symptom
When executing:
```bash
sudo iw dev wlan0 set type monitor
```
The driver failed with:
```
ieee80211 phy2: Monitor+Data interface support (MON_DATA) disabled
command failed: Input/output error (-5)
```

### Root Cause
1. **P2P Virtual Device Conflict in Interface Change Path**:
   In `drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_main.c` (`rwnx_cfg80211_change_iface`):
   ```c
   #ifndef CONFIG_RWNX_MON_DATA
       if ((type == NL80211_IFTYPE_MONITOR) &&
          (RWNX_VIF_TYPE(vif) != NL80211_IFTYPE_MONITOR)) {
           struct rwnx_vif *vif_el;
           list_for_each_entry(vif_el, &rwnx_hw->vifs, list) {
               // Check if data interface already exists
               if ((vif_el != vif) &&
                  (RWNX_VIF_TYPE(vif) != NL80211_IFTYPE_MONITOR)) {
                   wiphy_err(rwnx_hw->wiphy,
                           "Monitor+Data interface support (MON_DATA) disabled\n");
                   return -EIO;
               }
           }
       }
   #endif
   ```
   - **Bug A**: Inside `list_for_each_entry(vif_el, ...)`, the vendor code tested `RWNX_VIF_TYPE(vif)` (the changing interface before the switch, which is `NL80211_IFTYPE_STATION`) rather than `RWNX_VIF_TYPE(vif_el)` (the iterated interface in the list). Because `vif` is not yet in monitor mode, `RWNX_VIF_TYPE(vif) != NL80211_IFTYPE_MONITOR` is always true.
   - **Bug B**: The `rwnx_hw->vifs` list contains a non-netdev virtual management interface for P2P (`NL80211_IFTYPE_P2P_DEVICE`) created by `wpa_supplicant`. Even if `vif_el` were inspected, `P2P_DEVICE` is not a data interface and must be explicitly ignored when verifying there are no conflicting active data interfaces.
   - **Firmware Constraint**: `CONFIG_RWNX_MON_DATA` cannot simply be enabled in the driver because the AIC8800D80 firmware does not advertise `MM_FEAT_MON_DATA_BIT`. Setting `CONFIG_RWNX_MON_DATA=y` causes driver initialization to fail with `Monitor+Data interface support (MON_DATA) disabled in firmware but support compiled in driver` in `rwnx_mod_params.c:501`.

2. **Monitor Frame TX / Injection Pipeline**:
   - In `rwnx_tx.c` (`rwnx_select_txq`): `NL80211_IFTYPE_MONITOR` was missing from the switch statement, falling through to `PRIO_STA_NULL` on the BCMC queue.
   - In `rwnx_tx.c` (`rwnx_start_monitor_if_xmit`): Raw monitor injection frames are not associated with a peer station in `rwnx_hw->sta_table`. Attempting station lookup via `rwnx_get_tx_priv()` resulted in invalid queue selection. The injection path must assign `sta = NULL` and transmit on the VIF's unknown queue (`rwnx_txq_vif_get(vif, NX_UNK_TXQ_TYPE)`).
   - Radiotap iteration lacked a NULL guard on `iterator.this_arg`, causing potential kernel NULL dereferences on malformed or argument-less radiotap elements.

---

## 2. Patch Implementation

The fix is organized into two minimal, logical layers:

### Patch A: VIF P2P Conflict Fix (`rwnx_main.c`)
- Corrects `RWNX_VIF_TYPE(vif)` to `RWNX_VIF_TYPE(vif_el)`.
- Explicitly excludes `NL80211_IFTYPE_P2P_DEVICE` from the data interface check.

### Patch B: Monitor TX Safety & Queue Handling (`rwnx_tx.c`, `rwnx_tx.h`, `Makefile`)
- Adds `NL80211_IFTYPE_MONITOR` handling to `rwnx_select_txq()` returning `NX_UNK_TXQ_TYPE` queue.
- Directly routes monitor frames to `rwnx_txq_vif_get(vif, NX_UNK_TXQ_TYPE)` with `sta = NULL`.
- Adds `unlikely(!iterator.this_arg)` guard in radiotap iterator loop.
- Synchronizes `rwnx_start_monitor_if_xmit()` function signature to return `netdev_tx_t`.
- Enables `CONFIG_RWNX_MON_XMIT ?= y` in `Makefile`.

---

## 3. Verification & Validation Status

| Layer / Capability | Status | Evidence / Notes |
|---|---|---|
| **Source Code Validation** | **SOURCE VERIFIED** | Direct AST and call-graph verification against `rwnx_main.c`, `rwnx_tx.c`, `rwnx_rx.c` |
| **Cross-Compilation** | **BUILD VERIFIED** | Built cleanly with `aarch64-linux-gnu-gcc 13.3.0` against Linux 5.15.147-21-a733 |
| **Module Metadata / Vermagic** | **MODULE VERIFIED** | Vermagic: `5.15.147-21-a733 SMP preempt mod_unload aarch64` (exact match) |
| **Imported / Exported Symbols** | **SYMBOL VERIFIED** | Matched against `Module.symvers` / `vmlinux.symvers` |
| **SSH / wlan1 Coexistence** | **PROTECTION VERIFIED** | Deployment script isolates `wlan0`; `wlan1` remains untouched on active SSH |
| **Hardware Monitor Mode Switch** | **DEPLOYMENT READY** | Packaged in `deploy/` with deterministic deployment and rollback scripts |
| **Hardware Monitor RX / TX** | **DEPLOYMENT READY** | Code-audited for packet reception (`rwnx_rx_monitor`) and injection (`rwnx_start_monitor_if_xmit`) |

---

## 4. Repository Structure

```
patches/aic8800d80-monitor-mode/
├── BUILD.md                  # Exact build instructions & superproject commands
├── CHANGELOG.md              # Detailed chronological changelog
├── INSTALL.md                # Deployment and runtime test procedures
├── README.deploy.md          # Quick deployment reference
├── README.md                 # Technical forensics and patch documentation
├── SHA256SUMS                # Cryptographic checksums of all artifacts
├── deploy/
│   ├── deploy.sh             # Safe deployment script (preserves wlan1/SSH)
│   └── rollback.sh           # Safe rollback script (restores original module)
├── driver/
│   ├── aic8800_fdrv.ko       # Rebuilt patched kernel module binary
│   └── aic_load_fw.ko        # Accompanying firmware loader module binary
└── source_patch/
    ├── 0001-aic8800-fix-monitor-VIF-P2P-conflict.patch
    ├── 0002-aic8800-make-monitor-TX-queue-NULL-safe-and-enable-i.patch
    ├── rwnx_main.diff
    └── rwnx_tx.diff
```
