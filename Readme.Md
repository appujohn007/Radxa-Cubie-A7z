# Radxa Cubie A7Z Driver & Release Documentation

Operational documentation, build guides, patches, and deployment artifacts for custom kernel modules built for the Radxa Cubie A7Z (Kernel `5.15.147-21-a733`, ARM64).

## Module Quick Reference: MT7601U

* **Target Kernel:** `5.15.147-21-a733`
* **Module:** `mt7601u.ko` (`CONFIG_MT7601U=m`)
* **`vermagic`:** `5.15.147-21-a733 SMP preempt mod_unload aarch64`
* **Dependencies:** `cfg80211`, `mac80211`
* **Known-Good SHA256:** `2c83f127c331a6ee0c35f7323e13b2491f287a2c4abf08220f79644a7b760833`
* **Status:** Verified Working (AP / Hotspot mode operational with `hostapd`)

### Deployment Commands (On Target Board):
```bash
sudo modprobe mac80211
sudo insmod mt7601u.ko
```

---

## Documentation Guides

* [`MT7601U_AP_STATUS.md`](MT7601U_AP_STATUS.md) – Authoritative technical record, verification checklist, runtime test results, and troubleshooting for MT7601U AP mode.
* [`AI_HANDOFF.md`](AI_HANDOFF.md) – Complete AI handoff and continuity guide for future AI agents and developers.
* [`project-state.yaml`](project-state.yaml) – Machine-readable project state, hardware metadata, and verification statuses.
* [`BUILD.md`](BUILD.md) – Master guide for repository roles, architecture, `build-module.sh` usage, symbol table generation, and troubleshooting.
* [`BUILD_NOTES.md`](BUILD_NOTES.md) – Specific build notes, kernel configuration steps, and target deployment checklist for MediaTek MT7601U.
* [`patches/mt7601u-enable-ap-mode.patch`](patches/mt7601u-enable-ap-mode.patch) – Source patch implementing AP mode for MT7601U on kernel 5.15.
* [`patches/aic8800d80-monitor-mode/`](patches/aic8800d80-monitor-mode/) – Patch documentation and build references for AIC8800D80 USB Wi-Fi driver monitor mode experiments.
