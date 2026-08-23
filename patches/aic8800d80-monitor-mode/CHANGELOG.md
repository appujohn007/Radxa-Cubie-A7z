# Changelog - AIC8800D80 Monitor Mode Driver Patches

All notable changes to the AIC8800D80 USB Wi-Fi driver patches for monitor mode and packet injection are documented in this file.

## [2026-08-23] - aic8800_fdrv: Canonical Monitor Mode RX Classification & Frame Capture Fix

### Added / Fixed
- **Monitor Mode RX Frame Classification Fallback (`rwnx_rx.c`)**:
  - In `rwnx_rxdataind_aicwf()`, added fallback acceptance of `flags_vif_idx == RWNX_INVALID_VIF (0xFF)` when guarded by active monitor context (`rwnx_hw->monitor_vif != RWNX_INVALID_VIF`).
  - Added strict mutual exclusion (`else`) between monitor classification (`status = RX_STAT_MONITOR`) and station data upload (`if (hw_rxhdr->flags_upload) status |= RX_STAT_FORWARD;`).
  - Prevented `status` from becoming `0x81` (`RX_STAT_MONITOR | RX_STAT_FORWARD`), ensuring `if (status == RX_STAT_MONITOR)` evaluates cleanly and `skb_monitor` is allocated and delivered to `rwnx_rx_monitor()` $\to$ `netif_receive_skb()` $\to$ `tcpdump`.
- **ARM64 Kernel NULL Dereference Prevention (`rwnx_rx.c`, `rwnx_tx.c`)**:
  - In `rwnx_rx.c`, added check `!rwnx_vif || !rwnx_vif->up` and immediate discard in forwarding path if `rwnx_vif->wdev.iftype == NL80211_IFTYPE_MONITOR`.
  - In `rwnx_tx.c`, added minimum frame length validation (`frame_len >= 10`) and radiotap iterator init safety checks.
- **Hardware Validation Results**:
  - `tcpdump -i wlan1 -e -n` captured 41/41 packets and 20/20 packets with zero drops.
  - Full Radiotap headers, RSSI signal levels, operational channel frequencies, and Beacons captured live on hardware.
  - Verified concurrent managed `wlan0` station stability with 0% packet loss ping tests and 0 error counters.
- **Canonical Module Rebuilt**:
  - `driver/aic8800_fdrv.ko` (Version: `6.4.3.0`, srcversion: `6145B35700233EE3FD18439`, SHA256: `2847fd5eeccd6b5264bf028539e0043ab46679ab7a13b850201dd2b84ad5ac29`).
  - Backup preserved as `backup/aic8800_fdrv.pre-monitor-rx.ko` (SHA256: `ed7cea4f183256c558a594044f76d9edc3ce7bdfd4b1fa994be7df16ff4e959d`).

---

## [2026-08-22] - aic8800_fdrv: Monitor Mode RX Filter, Channel Context, TX Queue, and NULL Safety Fixes

### Fixed
- **Monitor Channel Definition & `-105` / `nl80211_send_chandef` Error (`rwnx_main.c`)**:
  - Initialized default channel context (Channel 1, 2412 MHz, 20MHz) upon monitor interface open if unconfigured.
  - In `rwnx_cfg80211_get_channel()`, return existing valid channel context immediately instead of calling `set_monitor_channel(NULL)`.
  - Resolved `iw dev wlan0 info` `-105` (`-ENOBUFS`) error and eliminated kernel `nl80211_send_chandef` warnings.
- **Monitor TX Netdev Subqueue Clamping (`rwnx_tx.c`)**:
  - In `rwnx_select_txq()`, map `NL80211_IFTYPE_MONITOR` to valid subqueue `nx_bcmc_txq_ndev_idx` instead of returning `NDEV_NO_TXQ` (`65535`).
- **ARM64 Kernel NULL Pointer Dereference Prevention (`rwnx_tx.c`, `rwnx_rx.c`)**:
  - In `rwnx_txdatacfm()`, guarded `cfg80211_mgmt_tx_status()` with `!sw_txhdr->raw_frame`.
  - In `rwnx_rx_add_rtap_hdr()`, added NULL and array bounds checking for `band` and `rate_idx`.
  - In `rwnx_rxdataind_aicwf()`, added NULL check on `skb_monitor` after atomic SKB allocation.
- **Hardware Promiscuous RX Filter (`Makefile`)**:
  - Enabled `CONFIG_RWNX_MON_RXFILTER = y` so `rwnx_send_set_filter()` configures the LMAC MAC filter for promiscuous / other-BSS reception.

---

## [2026-08-22] - aic_load_fw Build Fix: RX Buffer Preallocation & Exported Symbols

### Changed
- **Memory Preallocation Configuration (`aic_load_fw/Makefile`)**:
  - Set `CONFIG_PREALLOC_RX_SKB ?= y` and `CONFIG_PREALLOC_TXQ ?= y` matching `aic8800_fdrv`.
  - Restored compilation of `aicwf_rx_prealloc.c` into `aic_load_fw.ko`.
  - Verified export of all 4 preallocation symbols: `aicwf_rxbuff_size_get`, `aicwf_prealloc_rxbuff_alloc`, `aicwf_prealloc_rxbuff_free`, and `aicwf_prealloc_txq_alloc`.
  - Maintained `CONFIG_PLATFORM_UBUNTU = y` and `aic_default_fw_path = "/lib/firmware"`.

---

## [2026-08-22] - Production Fix for AIC8800D80 Monitor Mode & Injection

### Fixed
- **Interface Change Conflict Check (`rwnx_main.c`)**:
  - Corrected VIF iteration in `rwnx_cfg80211_change_iface()` to evaluate `vif_el` instead of `vif`.
  - Excluded `NL80211_IFTYPE_P2P_DEVICE` from the active data interface check, resolving the `-EIO` failure on `iw dev wlan0 set type monitor`.
- **Monitor Mode TX Queue Selection (`rwnx_tx.c`)**:
  - Added `case NL80211_IFTYPE_MONITOR` to `rwnx_select_txq()`, properly assigning `TID_MGT` and mapping to the VIF unknown TX queue (`NX_UNK_TXQ_TYPE`).
- **Monitor Frame Injection Pipeline (`rwnx_tx.c`, `rwnx_tx.h`)**:
  - Guarded `iterator.this_arg` against NULL dereference in radiotap iterator loop.
  - Set `sta = NULL` and used `rwnx_txq_vif_get(vif, NX_UNK_TXQ_TYPE)` directly.
  - Updated `rwnx_start_monitor_if_xmit()` function signature to return `netdev_tx_t`.
  - Enabled `CONFIG_RWNX_MON_XMIT ?= y` in `Makefile`.

---

## [2024-11-19] - Initial Driver Release (Vendor RWNX v6.4.3.0)
- Initial vendor release for AIC8800D80 USB Wi-Fi chipset.
