# Changelog - AIC8800D80 Monitor Mode Driver Patches

All notable changes to the AIC8800D80 USB Wi-Fi driver patches for monitor mode and packet injection are documented in this file.

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
