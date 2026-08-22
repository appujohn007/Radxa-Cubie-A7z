# Changelog - AIC8800D80 Monitor Mode Driver Patches

All notable changes to the AIC8800D80 USB Wi-Fi driver patches for monitor mode and packet injection are documented in this file.

## [2026-08-22] - aic8800_fdrv: Monitor Mode RX Filter, Channel Context, TX Queue, and NULL Safety Fixes

### Fixed
- **Monitor Channel Definition & `-105` / `nl80211_send_chandef` Error (`rwnx_main.c`)**:
  - Initialized a default channel context (Channel 1, 2412 MHz, 20MHz) upon monitor interface open if unconfigured.
  - In `rwnx_cfg80211_get_channel()`, return existing valid channel context immediately instead of calling `set_monitor_channel(NULL)` (which unlinked and destroyed the channel context).
  - Resolved `iw dev wlan0 info` `-105` (`-ENOBUFS`) error and eliminated kernel `nl80211_send_chandef` warnings.
- **Monitor TX Netdev Subqueue Clamping (`rwnx_tx.c`)**:
  - In `rwnx_select_txq()`, map `NL80211_IFTYPE_MONITOR` to valid subqueue `nx_bcmc_txq_ndev_idx` instead of returning `NDEV_NO_TXQ` (`65535`), resolving `wlan0 selects TX queue 65535, but real number of TX queues is 257`.
- **ARM64 Kernel NULL Pointer Dereference Prevention (`rwnx_tx.c`, `rwnx_rx.c`)**:
  - In `rwnx_txdatacfm()`, guarded `cfg80211_mgmt_tx_status()` with `!sw_txhdr->raw_frame` to prevent traversing uninitialized cfg80211 mgmt registrations on raw monitor frames.
  - In `rwnx_rx_add_rtap_hdr()`, added NULL and array bounds checking for `band` and `rate_idx`.
  - In `rwnx_rxdataind_aicwf()`, added NULL check on `skb_monitor` after atomic SKB allocation.
- **Hardware Promiscuous RX Filter (`Makefile`)**:
  - Enabled `CONFIG_RWNX_MON_RXFILTER = y` so `rwnx_send_set_filter()` configures the LMAC MAC filter for promiscuous / other-BSS reception (`tcpdump` packet capture).
- **Module Rebuilt**:
  - `driver/aic8800_fdrv.ko` (SHA256: `49d84ed79c6270c69d86c852e96fa03f4b789788806bd34740f2b19b5068753e`).

---

## [2026-08-22] - aic_load_fw Build Fix: RX Buffer Preallocation & Exported Symbols

### Changed
- **Memory Preallocation Configuration (`aic_load_fw/Makefile`)**:
  - Set `CONFIG_PREALLOC_RX_SKB ?= y` and `CONFIG_PREALLOC_TXQ ?= y` matching `aic8800_fdrv`.
  - Restored compilation of `aicwf_rx_prealloc.c` into `aic_load_fw.ko`.
  - Verified export of all 4 preallocation symbols: `aicwf_rxbuff_size_get`, `aicwf_prealloc_rxbuff_alloc`, `aicwf_prealloc_rxbuff_free`, and `aicwf_prealloc_txq_alloc`.
  - Maintained `CONFIG_PLATFORM_UBUNTU = y` and `aic_default_fw_path = "/lib/firmware"`.
  - Rebuilt `driver/aic_load_fw.ko` (SHA256: `ba2582887defecb8dfc57cafcdbe99bb184f9cb47344da1e285d12362dcc1f43`).

---

## [2026-08-22] - Real-Hardware Validation on Radxa Cubie A7Z

### Validated on Real Hardware
- **Driver Deployment & Module Load**:
  - Successfully installed patched modules under `/lib/modules/5.15.147-21-a733/updates/dkms/`.
  - Module vermagic, binary decompression, and SHA256 hashes (`ce9659f4...` and `ba258288...`) verified.
  - Executed live driver swap (`sudo rmmod aic8800_fdrv` followed by `sudo modprobe aic8800_fdrv_usb`).
  - Verified 100% preservation of `wlan1` (MT7601U at `10.150.138.121:22`) and active SSH transport throughout the driver swap.
- **Hardware Monitor Mode Switching**:
  - Executed `sudo iw dev wlan0 set type monitor` on the physical AIC8800 interface.
  - Command completed successfully with exit code 0.
  - `iw dev` confirmed interface status: `type monitor`.
  - **Original MON_DATA / -EIO Bug: FIXED AND VERIFIED ON REAL HARDWARE**.

### Observations & Future Verification
- **NetworkManager Persistence**:
  - Executing `sudo ip link set wlan0 up` caused NetworkManager to restore `wlan0` to managed mode and reconnect to SSID `"ab"`.
  - Status: `MONITOR MODE PERSISTENCE UNDER NETWORKMANAGER: NOT YET CONFIGURED/VERIFIED`.
- **Monitor Transmission Logs**:
  - Observed kernel messages: `monitor xmit: netif_carrier_on`, `wlan0 selects TX queue 65535, but real number of TX queues is 257`, and `rwnx_start_monitor_if_xmit itv`.
  - Status: `Monitor TX` and `Packet Injection` remain **NOT VERIFIED**.

---

## [2026-08-22] - Production Fix for AIC8800D80 Monitor Mode & Injection

### Fixed
- **Interface Change Conflict Check (`rwnx_main.c`)**:
  - Corrected VIF iteration in `rwnx_cfg80211_change_iface()` to evaluate `vif_el` instead of `vif`.
  - Excluded `NL80211_IFTYPE_P2P_DEVICE` from the active data interface check, resolving the `-EIO` (`Monitor+Data interface support (MON_DATA) disabled`) failure on `iw dev wlan0 set type monitor`.
- **Monitor Mode TX Queue Selection (`rwnx_tx.c`)**:
  - Added `case NL80211_IFTYPE_MONITOR` to `rwnx_select_txq()`, properly assigning `TID_MGT` and mapping to the VIF unknown TX queue (`NX_UNK_TXQ_TYPE`).
- **Monitor Frame Injection Pipeline (`rwnx_tx.c`, `rwnx_tx.h`)**:
  - Guarded `iterator.this_arg` against NULL dereference in radiotap iterator loop.
  - Set `sta = NULL` and used `rwnx_txq_vif_get(vif, NX_UNK_TXQ_TYPE)` directly, eliminating invalid STA table lookups.
  - Updated `rwnx_start_monitor_if_xmit()` function signature to return `netdev_tx_t`.
  - Enabled `CONFIG_RWNX_MON_XMIT ?= y` in `Makefile`.

### Added
- Automated safe deployment script (`deploy/deploy.sh`) with strict `wlan1` / SSH transport protections.
- Deterministic rollback script (`deploy/rollback.sh`).
- Packaged production-ready modules: `driver/aic8800_fdrv.ko` and `driver/aic_load_fw.ko`.
- Comprehensive documentation and verified checksums (`SHA256SUMS`).

---

## [2026-08-01] - Build A / Build B Exploration Setup
- Diagnostic instrumentation investigation.

---

## [2024-11-19] - Initial Driver Release (Vendor RWNX v6.4.3.0)
- Initial vendor release for AIC8800D80 USB Wi-Fi chipset.
