# AIC8800D80 Monitor Mode Driver Patch for Radxa Cubie A7Z

## Overview

This directory contains the canonical production kernel driver patch, build references, deployment package, forensic analysis, and hardware validation records for enabling **802.11 Monitor Mode & Packet Capture** on the **AIC8800D80** internal Wi-Fi chipset of the **Radxa Cubie A7Z** (Allwinner A733 / `sun60iw2p1`, ARM64, Linux Kernel `5.15.147-21-a733`).

---

## 1. Problem History & Root-Cause Forensics

### Phase 1: Initial Interface Creation Failure (`-EIO` / MON_DATA)
* **Symptom:** Executing `sudo iw dev wlan0 set type monitor` failed with:
  ```
  ieee80211 phy2: Monitor+Data interface support (MON_DATA) disabled
  command failed: Input/output error (-5)
  ```
* **Root Cause:**
  1. In `rwnx_cfg80211_change_iface()`, the vendor code iterated `rwnx_hw->vifs` checking `RWNX_VIF_TYPE(vif) != NL80211_IFTYPE_MONITOR` (the changing interface before switch, which is `STATION`) instead of `vif_el` (the iterated list entry).
  2. `wpa_supplicant` created a virtual management `P2P_DEVICE` interface in `rwnx_hw->vifs` that was falsely treated as a conflicting active data interface.
  3. Firmware does not support `CONFIG_RWNX_MON_DATA` (`MM_FEAT_MON_DATA_BIT` is 0); setting `CONFIG_RWNX_MON_DATA=y` causes driver init failure with `-1` in `rwnx_mod_params.c:501`.

### Phase 2: Missing Monitor Channel Context & Netdev Subqueue Warning
* **Symptom:** `iw dev wlan0 info` returned `-105` (`-ENOBUFS`), kernel logged `nl80211_send_chandef` warnings, and kernel logged `wlan0 selects TX queue 65535, but real number of TX queues is 257`.
* **Root Cause:**
  1. `rwnx_open()` did not assign a default channel definition (Channel 1, 2412 MHz) when bringing up a monitor interface without prior channel configuration.
  2. `rwnx_cfg80211_get_channel()` unlinked the channel context instead of returning the existing channel context.
  3. `rwnx_select_txq()` lacked `case NL80211_IFTYPE_MONITOR:`, falling through to invalid subqueue index `65535`.

### Phase 3: Monitor Mode Active but 0 Packets Captured in `tcpdump`
* **Symptom:** `wlan1` successfully switched to monitor mode on Channel 11 (2462 MHz), USB RX was active in ftrace (`aicwf_process_rxframes` $\to$ `rwnx_rxdataind_aicwf`), but `tcpdump -i wlan1 -e -n` saw **0 packets** and `RX packets` stayed at 0.
* **Root Cause:**
  1. **Hardware MAC RX Filter:** In `rwnx_send_set_filter()`, `rwnx_send_set_filter` lacked `NXMAC_ACCEPT_OTHER_DATA_FRAMES_BIT` (`BIT(29)`) and `NXMAC_ACCEPT_UNICAST_BIT` (`BIT(6)`), and `#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 2, 0)` prevented setting `NXMAC_ACCEPT_UNICAST_BIT` on Kernel 5.15.
  2. **Ingress Frame Classification in `rwnx_rxdataind_aicwf()`:** The driver required `(hw_rxhdr->flags_vif_idx == rwnx_hw->monitor_vif)`. For unassociated ambient frames captured from foreign BSSIDs, the FullMAC firmware sets `flags_vif_idx = 0xFF` (`RWNX_INVALID_VIF`) and `is_monitor_vif = 0`. This caused unassociated air traffic to bypass `RX_STAT_MONITOR` and enter `RX_STAT_FORWARD` where `rwnx_rx_get_vif(rwnx_hw, 0xFF)` returned `NULL` and dropped the packet.
  3. **Status Invariant Clobbering:** In `rwnx_rxdataind_aicwf()`, `if (hw_rxhdr->flags_upload)` immediately followed monitor classification without an `else`. Since firmware sets `flags_upload = 1`, `status` became `RX_STAT_MONITOR | RX_STAT_FORWARD` (`0x81`). Line 2118 checked `if (status == RX_STAT_MONITOR)` (exact equality to `0x80`). Because `0x81 != 0x80`, execution fell into the `else` branch (empty under `CONFIG_RWNX_MON_DATA=n`), leaving `skb_monitor = NULL` and dropping the frame at line 2157.

---

## 2. Technical Architecture of the Canonical Fixes

The canonical driver incorporates all verified fixes across the RX and TX pipelines:

```mermaid
flowchart TD
    subgraph RXPath ["Ingress RX Pipeline (rwnx_rx.c)"]
        USB["USB Ingress Frame (skb)"] --> Classify{"is_monitor_vif || (monitor_vif != 0xFF && flags_vif_idx in {monitor_vif, 0xFF})"}
        Classify -->|True| MonStat["status = RX_STAT_MONITOR (0x80)"]
        Classify -->|False (else)| FwdStat["if (flags_upload) status |= RX_STAT_FORWARD (0x01)"]
        MonStat --> MonCheck{"status == RX_STAT_MONITOR?"}
        MonCheck -->|True (0x80)| Strip["Strip 54B HW Header -> rwnx_rx_monitor()"]
        Strip --> Rtap["rwnx_rx_add_rtap_hdr() (Rate, Freq, RSSI)"]
        Rtap --> Netif["netif_receive_skb(ETH_P_802_2) -> tcpdump"]
    end

    subgraph TXPath ["Egress TX Pipeline (rwnx_tx.c)"]
        Inj["Raw Injection Packet"] --> SelQ["rwnx_select_txq() -> Subqueue 0"]
        SelQ --> Xmit["rwnx_start_monitor_if_xmit()"]
        Xmit --> Val["Validate Radiotap + Frame Length (len >= 10)"]
        Val --> UnkQ["rwnx_txq_vif_get(NX_UNK_TXQ_TYPE, sta = NULL)"]
        UnkQ --> Cfm["rwnx_txdatacfm(): skip cfg80211_mgmt_tx_status on raw frames"]
    end
```

### Key Semantics & Invariants
* **`flags_vif_idx == RWNX_INVALID_VIF (0xFF)`:** Represents unmapped/ambient frames with no associated station context. It is used for monitor mode classification **ONLY** when guarded by `rwnx_hw->monitor_vif != RWNX_INVALID_VIF`. Ordinary managed mode (`monitor_vif == 0xFF`) never executes this fallback.
* **Status Mutual Exclusion:** `status = RX_STAT_MONITOR` ($0\text{x}80$) and `status = RX_STAT_FORWARD` ($0\text{x}01$) are strictly mutually exclusive via `else`. This prevents `status` from becoming $0\text{x}81$, ensuring `skb_monitor` is allocated and delivered cleanly to userspace without double delivery or use-after-free.

---

## 3. Real-Hardware Test & Verification Evidence

### Target Environment
* **Platform:** Radxa Cubie A7Z (Allwinner A733 SoC, ARM64)
* **Kernel:** `5.15.147-21-a733 SMP preempt mod_unload aarch64`
* **Target Interface:** `wlan0` / `wlan1` (AIC8800D80 USB Wi-Fi)

### Live Capture & Verification Log
1. **Module Load & Interface Configuration:**
   - Module `aic8800_fdrv.ko` (version `6.4.3.0`, srcversion `6145B35700233EE3FD18439`) loaded cleanly.
   - Monitor mode enabled on `wlan1`: `sudo iw dev wlan1 set type monitor` $\to$ `type monitor`.
   - Interface brought UP on Channel 11: `sudo ip link set wlan1 up` $\to$ `state UP`.
2. **Live `tcpdump` Packet Capture:**
   - Command: `sudo tcpdump -i wlan1 -e -n -c 41`
   - **Result:** Captured **41 / 41 packets** with **0 drops**.
   - Subsequent capture: `sudo tcpdump -i wlan1 -e -n -c 20` $\to$ Captured **20 / 20 packets** with **0 drops**.
   - Captured packets included full IEEE 802.11 Radiotap headers, RSSI signal levels, operational frequencies (2462 MHz), and ambient Beacon / Probe frames from surrounding networks.
3. **Concurrent Managed Network Isolation:**
   - Primary station interface (`wlan0`) remained 100% active and connected to LAN.
   - Continuous ping test to gateway (`10.150.138.10`): **0% packet loss**, stable low latency.
   - Interface counters on `wlan0` confirmed **0 errors, 0 dropped packets**, demonstrating complete isolation between monitor RX and managed IP traffic.

---

## 4. Verification Matrix & Proven Scope

| Capability | Status | Evidence |
| :--- | :--- | :--- |
| **Interface Switching (`iw set type monitor`)** | **PROVEN ON HARDWARE** | `iw dev` confirms `type monitor`, `-EIO` eliminated. |
| **Channel Context & Chandef** | **PROVEN ON HARDWARE** | `iw dev wlan1 info` returns valid 2462 MHz chandef; no kernel warnings. |
| **Promiscuous Packet Capture (`tcpdump`)** | **PROVEN ON HARDWARE** | Live capture of 41/41 and 20/20 packets with full Radiotap metadata. |
| **Managed Mode Integrity (`wlan0`)** | **PROVEN ON HARDWARE** | 0% ping loss to gateway; station RX/TX error counters zero. |
| **Raw Frame Injection (`aireplay-ng`)** | **CODE-COMPLETE** | TX unknown queue routing and radiotap validation implemented; broad injection suite pending. |
| **Broad 5GHz / DFS / Control Frame Capture** | **PENDING EXTENDED TEST** | 2.4GHz beacon capture verified; extended 5GHz/DFS testing planned. |

---

## 5. Build & Compilation Instructions

### Build Command
```bash
cd /workspaces/linux-a733
./build-module.sh bsp/drivers/net/wireless/aic8800/usb
```

### Resulting Module Metadata
* **Path:** `patches/aic8800d80-monitor-mode/driver/aic8800_fdrv.ko`
* **Kernel Version / Vermagic:** `5.15.147-21-a733 SMP preempt mod_unload aarch64`
* **Driver Version:** `6.4.3.0`
* **Source Version (`srcversion`):** `6145B35700233EE3FD18439`
* **Dependencies:** `cfg80211, aic_load_fw`
* **SHA256 Checksum:** `2847fd5eeccd6b5264bf028539e0043ab46679ab7a13b850201dd2b84ad5ac29`

---

## 6. Rollback Instructions

In the event that the driver needs to be reverted to the pre-monitor-rx build:

1. **Restore Backup Binary:**
   ```bash
   cp /workspaces/Radxa-Cubie-A7z/patches/aic8800d80-monitor-mode/backup/aic8800_fdrv.pre-monitor-rx.ko \
      /workspaces/Radxa-Cubie-A7z/patches/aic8800d80-monitor-mode/driver/aic8800_fdrv.ko
   ```
2. **Re-deploy to System:**
   ```bash
   sudo cp /workspaces/Radxa-Cubie-A7z/patches/aic8800d80-monitor-mode/driver/aic8800_fdrv.ko \
           /lib/modules/5.15.147-21-a733/updates/dkms/aic8800_fdrv.ko
   sudo depmod -a
   sudo modprobe -r aic8800_fdrv && sudo modprobe aic8800_fdrv
   ```
