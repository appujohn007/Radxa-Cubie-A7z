# AIC8800D80 Monitor Mode Driver Patch for Radxa Cubie A7Z

## Overview

This directory contains the production-quality kernel driver patch, build references, deployment package, and hardware validation records for enabling **802.11 Monitor Mode & Packet Injection** on the **AIC8800D80** internal Wi-Fi chipset of the **Radxa Cubie A7Z** (Allwinner A733 / `sun60iw2p1`, ARM64, Kernel `5.15.147-21-a733`).

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

## 3. Verification & Validation Status Matrix

| Layer / Capability | Status | Evidence / Notes |
|---|---|---|
| **Source Patch** | **VERIFIED** | Direct AST and call-graph verification against `rwnx_main.c`, `rwnx_tx.c`, `rwnx_rx.c` |
| **Cross-Build** | **VERIFIED** | Built cleanly with `aarch64-linux-gnu-gcc 13.3.0` against Linux `5.15.147-21-a733` |
| **Module Vermagic** | **VERIFIED** | `5.15.147-21-a733 SMP preempt mod_unload aarch64` (exact match) |
| **Module SHA256** | **VERIFIED** | `aic8800_fdrv.ko`: `ce9659f42b35c25b459629dd1c39d8e3c5682167debe506e06a7f00fe5ffb6bd`<br>`aic_load_fw.ko`: `ba2582887defecb8dfc57cafcdbe99bb184f9cb47344da1e285d12362dcc1f43` |
| **Deployment** | **VERIFIED** | Deployed to `/lib/modules/5.15.147-21-a733/updates/dkms/` with `depmod -a` |
| **Patched Driver Load** | **VERIFIED** | Loaded via `modprobe aic8800_fdrv_usb`; initialized cleanly on physical board |
| **wlan1/SSH Preservation** | **VERIFIED** | Active SSH over `wlan1` (`10.150.138.121:22` on MT7601U) remained 100% operational |
| **wlan0 Monitor-Mode Switching** | **VERIFIED ON REAL HARDWARE** | `sudo iw dev wlan0 set type monitor` succeeded; `iw dev` reports `type monitor` |
| **Original MON_DATA / -EIO Bug** | **FIXED AND VERIFIED ON REAL HARDWARE** | Previous `-EIO` error completely eliminated |
| **Passive Monitor RX** | **NOT YET VERIFIED** | Not yet exercised in live capture test |
| **Monitor TX** | **NOT VERIFIED** | Queue mapping and radiotap parsing logs observed; requires further validation |
| **Packet Injection** | **NOT VERIFIED** | `aireplay-ng` injection test not yet completed |
| **Persistent Monitor Mode with NetworkManager** | **NOT YET CONFIGURED/VERIFIED** | `sudo ip link set wlan0 up` triggers NetworkManager to restore managed mode and reconnect to SSID |

---

## 4. Real-Hardware Validation Results (2026-08-22)

### Target Hardware Environment
- **Board**: Radxa Cubie A7Z
- **Kernel**: `5.15.147-21-a733`
- **Topology**:
  - `wlan0`: AIC8800 internal Wi-Fi (Target)
  - `wlan1`: MediaTek MT7601U external Wi-Fi (Protected SSH transport: `10.150.138.121`)

### Actual Deployment & Test Sequence
1. **Initial State**: Stock AIC driver loaded (`aic8800_fdrv`, `aic_load_fw`). Active SSH session established over `wlan1`.
2. **Backup**: Stock modules backed up safely.
3. **Installation**: Patched modules installed to `/lib/modules/5.15.147-21-a733/updates/dkms/`.
4. **Module Dependency Refresh**: Executed `sudo depmod -a`.
5. **Module Inspection**: Verified with `modinfo aic8800_fdrv_usb` and decompressed binary SHA256 checksum check.
6. **Live Driver Swap**:
   - Stock driver unloaded: `sudo rmmod aic8800_fdrv`
   - `wlan1` / SSH transport remained fully operational without interruption.
   - Patched driver loaded: `sudo modprobe aic8800_fdrv_usb`
   - `wlan0` reappeared; `wlan1` remained connected.
7. **Critical Mode Switching Test**:
   ```bash
   sudo iw dev wlan0 set type monitor
   ```
   **Result**: **SUCCEEDED** (Exit code 0).
   Output from `iw dev`:
   ```
   Interface wlan0
       type monitor
   ```

### Runtime Observations & Analysis
- **Original Bug Fixed**: The stock failure (`Monitor+Data interface support (MON_DATA) disabled` / `-EIO`) is resolved on physical hardware.
- **NetworkManager Interface Management**: When running `sudo ip link set wlan0 up`, `wlan0` was restored to managed mode by NetworkManager and reconnected to SSID `"ab"`. This confirms monitor mode is successfully accepted by the kernel/driver, but NetworkManager must be configured (e.g. `nmcli device set wlan0 managed no` or unmanaged keyfile rule) to maintain monitor mode persistence upon interface up.
- **Monitor TX Path Kernel Traces**: Kernel logs during monitor activity showed:
  - `monitor xmit: netif_carrier_on`
  - `wlan0 selects TX queue 65535, but real number of TX queues is 257`
  - `rwnx_start_monitor_if_xmit, skb_len=...`
  - `rwnx_start_monitor_if_xmit itv`
  These traces confirm the monitor transmission code path is active, but indicate further refinements may be needed for queue index handling and radiotap validation during active frame injection.

---

## 5. Repository Structure

```
patches/aic8800d80-monitor-mode/
├── BUILD.md                  # Exact build instructions & superproject commands
├── CHANGELOG.md              # Detailed chronological changelog
├── INSTALL.md                # Deployment and runtime test procedures
├── README.deploy.md          # Quick deployment reference
├── README.md                 # Technical forensics, patch docs, and hardware results
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
