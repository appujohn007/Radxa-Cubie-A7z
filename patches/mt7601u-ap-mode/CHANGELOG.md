# MT7601U AP Mode Patch Changelog

## [2.0.0] - 2026-08-18 (Autonomous MAC Beacon Engine & Group WCID Support)
### Added
* Implemented `mt7601u_write_beacon()` to format 20-byte `struct mt76_txwi` descriptors with `MT_TXWI_FLAGS_TS` and write beacon templates to on-chip SRAM (`0xC000`).
* Implemented high-resolution timer (`pre_tbtt_timer`) and high-priority workqueue (`pre_tbtt_work`) scheduled 8 ms before each TBTT.
* Implemented `mt7601u_resync_beacon_timer()` to correct 1 µs hardware timer drift every 64 TBTT ticks.
* Added `mt7601u_mac_set_beacon_enable()` to program `MT_BEACON_TIME_CFG` (`0x1114`) with `BEACON_TX`, `TBTT_EN`, `TIMER_EN`, and `SYNC_MODE_3`.
* Added group WCID hardware table setup (`mt7601u_mac_wcid_setup()`) for broadcast/multicast encryption context in `mt7601u_add_interface()`.
* Added `MT_TSF_TIMER_DW0/DW1` (`0x111c`/`0x1120`) and `MT_TBTT_TIMER` (`0x1124`) register definitions in `regs.h`.
* Handled `BSS_CHANGED_BEACON_ENABLED`, `BSS_CHANGED_BEACON`, and `BSS_CHANGED_BEACON_INT` in `mt7601u_bss_info_changed()`.

### Verified on Hardware
* `hostapd` reaches `wlan1: AP-ENABLED`.
* SSID `MT7601U-Test` is visible to external scanning client devices.
* Probe requests received from scanning devices and probe responses transmitted over the air.

---

## [1.1.0] - 2026-08-17 (Initial Interface Mode Advertisement)
### Changed
* Modified `init.c` to advertise `BIT(NL80211_IFTYPE_AP)` in `wiphy->interface_modes`.
* Verified interface type switch `sudo iw dev wlan1 set type __ap` succeeds.
* Note: `hostapd` failed to broadcast beacons because hardware beacon SRAM remained unpopulated.

---

## [1.0.0] - 2026-08-16 (Stock Driver Baseline)
* Stock vendor driver supports Station (`managed`) and `monitor` modes only.
* Attempting `set type __ap` returns error `-95` (`Operation not supported`).
