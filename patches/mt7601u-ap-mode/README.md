# MediaTek MT7601U Access Point (AP Mode) Patch Subproject

[![Status](https://img.shields.io/badge/Status-VERIFIED%20WORKING-brightgreen.svg)](STATUS.md)
[![Kernel](https://img.shields.io/badge/Kernel-5.15.147--21--a733-blue.svg)](https://github.com/radxa-pkg/linux-a733)
[![Device](https://img.shields.io/badge/USB%20ID-148f%3A7601-orange.svg)](https://mediatek.com)

## 📖 Overview

The **MediaTek MT7601U** is a single-stream (1T1R) 802.11b/g/n USB 2.0 Wi-Fi adapter widely used with single-board computers like the **Radxa Cubie A7Z**. 

In the stock Linux 5.15 kernel driver (`drivers/net/wireless/mediatek/mt7601u/`), the driver only advertises Station (`managed`) and `monitor` modes. Attempting to switch the interface into Access Point mode with `iw` or `hostapd` fails with `-95` (`Operation not supported`).

This subproject provides the **canonical patch and verified kernel module** that implements true Access Point (AP / Hotspot) functionality by leveraging the MT7601U's on-chip autonomous MAC beacon engine, SRAM beacon template memory, high-resolution pre-TBTT timer refresh loop, and group WCID table initialization.

---

## 🗂️ Subproject Structure

```
patches/mt7601u-ap-mode/
├── README.md               <- This document (architecture & feature overview)
├── INSTALL.md              <- Target board deployment, mode transition & hostapd instructions
├── BUILD.md                <- Kbuild compilation workflow using build-module.sh
├── STATUS.md               <- Authoritative technical record & hardware verification logs
├── BUILD_NOTES.md          <- Developer build & kernel config checklist
├── CHANGELOG.md            <- Version history and development progression
├── driver/
│   └── mt7601u.ko          <- Verified working module binary (SHA256: 2c83f127...)
└── source_patch/
    └── mt7601u-enable-ap-mode.patch  <- Complete unified diff for drivers/net/wireless/mediatek/mt7601u/
```

---

## ⚙️ Key Technical Features

1. **Autonomous MAC Beaconing:** Configures `MT_BEACON_TIME_CFG` (`0x1114`) with `BEACON_TX`, `TBTT_EN`, `TIMER_EN`, and `SYNC_MODE_3` (AP mode), allowing the hardware to transmit beacons at every TBTT tick without host USB latency jitter.
2. **SRAM Beacon Upload:** Formats a 20-byte `struct mt76_txwi` descriptor with `MT_TXWI_FLAGS_TS` (auto-TSF timestamp insertion) and copies the beacon frame body into on-chip SRAM at `0xC000` (`MT_BEACON_BASE`).
3. **Pre-TBTT High-Resolution Timer:** Schedules an `hrtimer` to fire 8 ms prior to each TBTT. A high-priority worker retrieves updated dynamic beacons (DTIM/TIM bitmaps) via `ieee80211_beacon_get()` and refreshes SRAM safely using `MT_BCN_BYPASS_MASK`.
4. **Drift Resynchronization:** Compensates for the 1 µs hardware timer drift every 64 TBTT periods.
5. **Group WCID Table Setup:** Programs `mt7601u_mac_wcid_setup()` for multicast/broadcast WCID (`GROUP_WCID(0) = 126`) upon interface creation.

---

## 📊 Verification Summary

| Capability | Status | Evidence |
| :--- | :--- | :--- |
| **AP Mode Advertised** | **VERIFIED** | Reported by `iw phy info` (`managed`, `AP`, `AP/VLAN`, `monitor`). |
| **Interface Switch to AP** | **VERIFIED** | `sudo iw dev wlan1 set type __ap` exits `0`, interface switches to `type AP`. |
| **`hostapd` Startup** | **VERIFIED** | `hostapd` initializes nl80211 and reaches `wlan1: AP-ENABLED`. |
| **SSID Visibility** | **VERIFIED** | `MT7601U-Test` visible to external scanning Wi-Fi devices. |
| **Probe Requests / Responses** | **VERIFIED** | Client probe requests received; valid probe responses transmitted over air. |

---

## 🔗 Related Authoritative Documents

* **Full Verification & Hardware Logs:** [`STATUS.md`](STATUS.md)
* **AI Continuity & Project Memory:** [`../../AI_HANDOFF.md`](../../AI_HANDOFF.md)
* **Root Repository Architecture:** [`../../README.md`](../../README.md)
