# AIC8800D80 USB Wi-Fi Driver Patch & Monitor-Mode Instrumentation (Radxa Cubie A7Z)

## Overview

This directory contains the patch documentation, source diffs, and build logs for the AIC8800D80 USB Wi-Fi driver on the Radxa Cubie A7Z.

The driver has been instrumented with a **DEBUG BUILD** featuring fine-grained kernel logging (`MONDBG:`) and defensive NULL-pointer safeguards across the entire Monitor Mode Packet Injection (TX) path to diagnose kernel NULL pointer Oops crashes during packet injection (e.g. `aireplay-ng --test wlan1`).

> [!IMPORTANT]
> The rebuilt debug module binary `aic8800_fdrv.ko` is stored at `/workspaces/monitor-debug-build/aic8800_fdrv.ko` for evidence collection and has **not** been installed on the target Radxa board.

### Build Environment
- **Target OS / Kernel**: Linux 5.15.147-21-a733 (arm64)
- **Driver Version**: RWNX v6.4.3.0 (Release 2024_1119_06da8476)
- **Compiler**: `aarch64-linux-gnu-gcc`

---

## 1. Monitor TX Injection Flow & Call Graph

When raw 802.11 radiotap frames are injected via `aireplay-ng`:

```
User Space (aireplay-ng --test wlan1)
  │
  ▼  [PF_PACKET / Raw Socket]
Linux Kernel Network Subsystem / Netdev Layer
  │
  ├───► ndo_select_queue() ──► rwnx_select_queue() [rwnx_main.c]
  │                             │
  │                             └──► rwnx_select_txq() [rwnx_tx.c]
  │                                   (Selects NX_UNK_TXQ_TYPE for NL80211_IFTYPE_MONITOR)
  │
  └───► ndo_start_xmit() ───► rwnx_start_monitor_if_xmit() [rwnx_tx.c]
                                │
                                ├── 1. Validate skb, net_device, rwnx_vif, rwnx_hw
                                ├── 2. Parse radiotap header (ieee80211_radiotap_iterator)
                                ├── 3. Get VIF Unknown TX Queue (rwnx_txq_vif_get(vif, NX_UNK_TXQ_TYPE))
                                ├── 4. Allocate skb_mgmt & sw_txhdr (kmem_cache_alloc)
                                ├── 5. Fill hardware & software descriptors (txdesc_api, rate_config)
                                ├── 6. Lock tx_lock & queue SKB ──► rwnx_txq_queue_skb() [rwnx_txq.c]
                                └── 7. Trigger HW Queue processing ──► rwnx_hwq_process() [rwnx_txq.c]
                                                                        │
                                                                        └──► rwnx_tx_push() [rwnx_tx.c]
                                                                              │
                                                                              ├── Check need_cfm / raw_frame / rate_config
                                                                              └──► aicwf_frame_tx() [aicwf_txrxif.c]
                                                                                    │
                                                                                    └──► aicwf_bus_txdata() [aicwf_usb.c]
                                                                                          │
                                                                                          ├── Dequeue USB buffer (aicwf_usb_tx_dequeue)
                                                                                          ├── Format USB header & payload
                                                                                          ├── Fill URB (usb_fill_bulk_urb)
                                                                                          ├── Queue to tx_post_list
                                                                                          └── Schedule TX process / Tasklet
                                                                                                │
                                                                                                └──► aicwf_usb_tx_process()
                                                                                                      │
                                                                                                      └──► usb_submit_urb() [Linux USB Core]
```

---

## 2. Detailed Instrumentation Points (`MONDBG:`)

Every step in the monitor injection path has been instrumented with `printk(KERN_ERR "MONDBG: ...\n")` to ensure immediate logging to `dmesg`:

1. **`rwnx_select_queue()`** (`rwnx_main.c`):
   - Added NULL checks for `dev`, `skb`, `netdev_priv(dev)` (`rwnx_vif`), and `rwnx_vif->rwnx_hw`.
   - Logs `MONDBG: [select_queue] MONITOR xmit select_queue on dev wlan1 (vif ..., skb len ..., prio ...)`.
2. **`rwnx_select_txq()`** (`rwnx_tx.c`):
   - In `case NL80211_IFTYPE_MONITOR:` checks `rwnx_vif`, `rwnx_vif->rwnx_hw`, and `txq = rwnx_txq_vif_get(rwnx_vif, NX_UNK_TXQ_TYPE)`.
   - Logs `MONDBG: [select_txq] MONITOR select_txq: txq=..., txq->idx=..., ndev_idx=...`.
3. **`rwnx_start_monitor_if_xmit()`** (`rwnx_tx.c`):
   - **STEP 1**: Validates `skb`, `dev`, `vif`, `rwnx_hw`, `skb->data`. Logs `dev->name`, `ifindex`, `vif_idx`, `skb_len`, `rtap_len`.
   - **STEP 2**: Validates Radiotap header version and length. Checks `iterator.this_arg` for NULL on every iteration.
   - **STEP 3**: Summarizes parsed radiotap parameters (`frame_len`, `rate_fmt`, `rate_idx`, `txsig_bw`).
   - **STEP 4**: Validates `txq`, `txq->idx != TXQ_INACTIVE`, and `txq->hwq != NULL`.
   - **STEP 5**: Allocates `skb_mgmt` & `sw_txhdr` (`kmem_cache_alloc`), fills `txdesc_api` (staid `0xFF`, `vif_idx`, `flags = TXU_CNTRL_MGMT`, `rate_config`, `status_desc_addr`).
   - **STEP 6 & 7**: Logs acquiring `tx_lock`, queueing SKB via `rwnx_txq_queue_skb()`, and invoking `rwnx_hwq_process()`.
   - **STEP 8**: Logs releasing `tx_lock` and returning `NETDEV_TX_OK`.
4. **`rwnx_txq_queue_skb()` & `rwnx_hwq_process()`** (`rwnx_txq.c`):
   - Validates `skb`, `txq`, `rwnx_hw`, `hwq`. Logs queue status, credits, `hwq_id`, and `hwq_size`.
5. **`rwnx_tx_push()`** (`rwnx_tx.c`):
   - Validates `rwnx_hw`, `txhdr`, `sw_txhdr`, `skb`, `txq`, `txq->hwq`, `rwnx_hw->usbdev`.
   - Added a NULL check on `sw_txhdr->rwnx_vif` before updating `net_stats`.
6. **`aicwf_frame_tx()`** (`aicwf_txrxif.c`):
   - Validates `dev`, `skb`, `usbdev`, `usbdev->state`, `usbdev->bus_if`.
7. **`aicwf_usb_bus_txdata()` & `aicwf_usb_tx_process()`** (`aicwf_usb.c`):
   - Validates `dev`, `skb`, `bus_if`, `usb_dev`, `txhdr`, `txhdr->sw_hdr`, `usb_buf`, `usb_buf->urb`, `usb_dev->udev`.
   - **Vendor Bug Fix**: Fixed a use-after-free in `aicwf_usb_bus_txdata()` where `txhdr->sw_hdr->need_cfm` was accessed after `txhdr->sw_hdr` was freed by `kmem_cache_free()`.
   - Logs URB submission (`usb_submit_urb`) status and return codes.

---

## 3. Firmware Communication Analysis

- **Interface Setup (`MM_ADD_IF_REQ`)**:
  - When the monitor VIF is opened/added, the driver sends firmware message `MM_ADD_IF_REQ` (`rwnx_msg_tx.c`) with `type = MM_MONITOR`.
- **Packet Transmission (`TXU_CNTRL_MGMT` / Data EP)**:
  - Monitor injection frames construct a `txdesc_api` header with `flags = TXU_CNTRL_MGMT` and `staid = 0xFF`.
  - Frames are transmitted over the USB bulk out endpoint (`bulk_out_pipe`) carrying the 4-byte AIC USB header, `txdesc_api`, and 802.11 payload.
- **Firmware Capabilities**:
  - Driver relies on `CONFIG_RWNX_MON_DATA` and `CONFIG_RWNX_MON_XMIT` build options.

---

## 4. Repository Layout & Artifact Locations

```
/workspaces/monitor-debug-build/
├── aic8800_fdrv.ko              # Rebuilt instrumented debug kernel module binary
├── git.diff                     # Complete instrumentation patch diff
├── build.log                    # Compilation log
├── README.md                    # Instrumentation details
└── SHA256SUMS                   # Artifact checksums

/workspaces/Radxa-Cubie-A7z/patches/aic8800d80-monitor-mode/
├── BUILD.md                     # Build instructions and notes
├── CHANGELOG.md                 # Change log
├── INSTALL.md                   # Installation & deployment guide
├── README.md                    # This document
├── README.deploy.md             # Deployment notes
├── build.log                    # Build output log
└── source_patch/
    ├── rwnx_main.diff           # VIF interface validation patch
    ├── rwnx_tx.diff             # Monitor TX queue patch
    └── monitor_tx_instrumentation.diff # Full MONDBG instrumentation & NULL check patch
```

---

Author: Appu John
