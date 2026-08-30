# MediaTek MT7601U Baseband RX DC Calibration Timing Fix for Radxa Cubie A7Z

## 1. Problem Statement & Root-Cause Summary
On the **Radxa Cubie A7Z** (Allwinner A733 / `sun60iw2p1`, kernel `5.15.147-21-a733`), connecting a MediaTek MT7601U USB Wi-Fi dongle (`148f:7601`) resulted in repeated initialization failures:

```text
mt7601u 3-1:1.0: mt7601u_rxdc_cal timed out
mt7601u 3-1:1.0: Error: MCU resp urb failed:-71
mt7601u 3-1:1.0: Error: MCU resp evt:0 seq:5-4!
mt7601u 3-1:1.0: Error: mt7601u_mcu_wait_resp timed out
mt7601u 3-1:1.0: Vendor request req:07 off:0080 failed:-71
mt7601u: probe of 3-1:1.0 failed with error -110
usb 3-1: USB disconnect
```

### Technical Root Cause:
1. During `mt7601u_phy_init()`, the driver executes `mt7601u_rxdc_cal()` to calibrate analog baseband DC offsets.
2. In stock upstream Linux (`drivers/net/wireless/mediatek/mt7601u/phy.c`), `mt7601u_rxdc_cal()` polls Baseband Processor (BBP) register 159 for status `0x0c` with only **20 iterations of `usleep_range(300, 500)`** ($\approx 6\text{–}10\,\text{ms}$).
3. On the Allwinner A733 platform, analog settling time during baseband power-up requires $\approx 14\text{–}25\,\text{ms}$ to converge. The stock driver timed out prematurely, leaving the on-chip baseband engine in an active, unsettled state.
4. When the driver subsequently sent `MCU_CAL_LOFT` (`CMD_CALIBRATION_OP`), the on-chip 8051 MCU stalled waiting for the baseband, dropping the Bulk IN response URB. This caused the host EHCI controller to return `-71` (`-EPROTO`), timing out the probe with `-110` and triggering an unrecoverable USB disconnect loop.

---

## 2. What Code Was Changed
In [`drivers/net/wireless/mediatek/mt7601u/phy.c:567-573`](file:///workspaces/linux-a733/src/drivers/net/wireless/mediatek/mt7601u/phy.c#L567-L573):
* Extended the polling loop count from 20 to **100 iterations**.
* Adjusted sleep interval from `usleep_range(300, 500)` to **`usleep_range(500, 800)`** ($\approx 60\text{–}80\,\text{ms}$ maximum timeout).
* Removed all debug/diagnostic overhead to maintain clean, production-grade driver performance.
* Preserved autonomous MAC beaconing and AP-mode functionality.

---

## 3. Directory Layout
```
patches/mt7601u-rxdc-cal-fix/
├── driver/
│   └── mt7601u.ko             <- Clean production module (5.15.147-21-a733)
├── source_patch/
│   └── 0001-mt7601u-extend-rxdc-cal-convergence-timeout.patch
├── README.md                  <- This technical overview
├── INSTALL.md                 <- Installation, validation & rollback guide
├── STATUS.md                  <- Verification report
└── SHA256SUMS                 <- Cryptographic integrity checksums
```
