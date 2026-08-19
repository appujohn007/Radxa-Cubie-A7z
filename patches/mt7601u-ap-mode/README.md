# MediaTek MT7601U AP Mode Patch & Driver

## Overview
This directory contains the canonical patch and precompiled driver module enabling **Access Point (AP / Hotspot) mode** for the MediaTek MT7601U USB Wi-Fi adapter on the **Radxa Cubie A7Z** (Kernel `5.15.147-21-a733`).

## Contents
* [`source_patch/mt7601u-enable-ap-mode.patch`](source_patch/mt7601u-enable-ap-mode.patch): Complete patch for `drivers/net/wireless/mediatek/mt7601u/`.
* [`driver/mt7601u.ko`](driver/mt7601u.ko): Verified working kernel module binary (SHA256: `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833`).
* [`INSTALL.md`](INSTALL.md): Step-by-step target deployment and `hostapd` setup guide.

## Technical Documentation
For full architectural analysis, hardware verification checklists, and troubleshooting, refer to the root technical documents:
* [`../../MT7601U_AP_STATUS.md`](../../MT7601U_AP_STATUS.md)
* [`../../AI_HANDOFF.md`](../../AI_HANDOFF.md)
* [`../../BUILD_NOTES.md`](../../BUILD_NOTES.md)
