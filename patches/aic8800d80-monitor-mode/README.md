# AIC8800D80 USB Wi-Fi Driver Patch & Post-TX Instrumentation (Radxa Cubie A7Z)

## Overview

This directory contains the patch documentation, source diffs, and build logs for the AIC8800D80 USB Wi-Fi driver on the Radxa Cubie A7Z.

The driver has been instrumented with a **DEBUG BUILD** featuring dense kernel logging (`MONDBG:`) and defensive NULL-pointer safeguards across both pre-TX and **post-TX completion & confirmation paths** to isolate the exact post-transmission function where kernel Oops crashes occur during raw frame injection (e.g. `aireplay-ng --test wlan1`).

> [!IMPORTANT]
> The rebuilt debug module binary `aic8800_fdrv.ko` is stored at `/workspaces/monitor-debug-build/aic8800_fdrv.ko` for evidence collection and has **not** been installed on the target Radxa board or committed inside `driver/`.

### Build Environment
- **Target OS / Kernel**: Linux 5.15.147-21-a733 (arm64)
- **Driver Version**: RWNX v6.4.3.0 (Release 2024_1119_06da8476)
- **Compiler**: `aarch64-linux-gnu-gcc`

---

## 1. Complete Monitor TX & Post-TX Pipeline Call Graph

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
                                                                              └──► aicwf_frame_tx() [aicwf_txrxif.c]
                                                                                    │
                                                                                    └──► aicwf_bus_txdata() [aicwf_usb.c]
                                                                                          │
                                                                                          └──► usb_submit_urb() [Linux USB Core]
                                                                                                │
                                                                                                ▼
                                                                                   [Post-TX / Completion Pipeline]
                                                                                                │
  ┌─────────────────────────────────────────────────────────────────────────────────────────────┴────────────────────────────────┐
  │                                                                                                                              │
  ▼                                                                                                                              ▼
aicwf_usb_tx_complete() [aicwf_usb.c]                                                                          aicwf_usb_rx_complete() [aicwf_usb.c]
  ├── usb_txc_sta_flowctrl()                                                                                     │
  ├── dev_kfree_skb_any() [if cfm == false]                                                                      ├── Enqueues rx_buff/skb to rxq
  ├── aicwf_usb_tx_queue(..., tx_free_list)                                                                      └── Signals complete(&busrx_trgg)
  └── aicwf_usb_tx_flowctrl()                                                                                          │
                                                                                                                       ▼
                                                                                                                 usb_busrx_thread() / aicwf_tasklet_rxframes()
                                                                                                                       │
                                                                                                                       └──► aicwf_process_rxframes() [aicwf_txrxif.c]
                                                                                                                             │
                                                                                                                             ├── [DATA] ───► rwnx_rxdataind_aicwf() ──► rwnx_rx_monitor() ──► netif_receive_skb()
                                                                                                                             │
                                                                                                                             ├── [DATA_CFM] ► aicwf_usb_host_tx_cfm_handler() ──► rwnx_txdatacfm()
                                                                                                                             │                  │                                   ├── rwnx_txq_confirm_any()
                                                                                                                             │                  │                                   ├── cfg80211_mgmt_tx_status()
                                                                                                                             │                  │                                   ├── kmem_cache_free()
                                                                                                                             │                  │                                   └── consume_skb()
                                                                                                                             │
                                                                                                                             └── [CMD_RSP] ─► rwnx_rx_handle_msg()
```

---

## 2. Detailed Instrumentation Points (`MONDBG:`)

| Function | File | Traced Event & Parameters |
|---|---|---|
| `rwnx_select_queue()` | `rwnx_main.c` | Queue selection, `vif`, `skb_len`, priority |
| `rwnx_select_txq()` | `rwnx_tx.c` | Monitor TXQ selection, `txq` pointer, `ndev_idx` |
| `rwnx_start_monitor_if_xmit()` | `rwnx_tx.c` | 8-step monitor TX pipeline, radiotap iteration, descriptor allocation, `rate_config` |
| `rwnx_txq_queue_skb()` | `rwnx_txq.c` | SKB queueing to `txq->sk_list` |
| `rwnx_hwq_process()` | `rwnx_txq.c` | HW queue processing, size, id |
| `rwnx_tx_push()` | `rwnx_tx.c` | Descriptor flags, `rate_config`, `sw_txhdr->rwnx_vif` check |
| `aicwf_frame_tx()` | `aicwf_txrxif.c` | Bus interface submission, `usbdev->state` |
| `aicwf_usb_bus_txdata()` | `aicwf_usb.c` | USB buffer dequeue, URB filling, vendor use-after-free fix |
| `aicwf_usb_tx_process()` | `aicwf_usb.c` | URB submission (`usb_submit_urb`), pipe, buffer length |
| `aicwf_usb_tx_complete()` | `aicwf_usb.c` | URB status, `usb_txc_sta_flowctrl`, SKB freeing, queue return |
| `usb_txc_sta_flowctrl()` | `aicwf_usb.c` | `usb_buf`, `usb_dev`, `hostdesc`, `sta_idx`, flags |
| `aicwf_usb_rx_complete()` | `aicwf_usb.c` | RX URB status, actual_len, skb pointer, queue enqueue |
| `aicwf_process_rxframes()` | `aicwf_txrxif.c` | Frame dequeue, frame type dispatch (DATA, DATA_CFM, CMD_RSP, PRINT) |
| `aicwf_tasklet_rxframes()` | `aicwf_txrxif.c` | RX tasklet entry & processing |
| `rwnx_rxdataind_aicwf()` | `rwnx_rx.c` | RX data indication entry, skb pointer, rx_priv |
| `rwnx_rx_monitor()` | `rwnx_rx.c` | `rwnx_vif`, radiotap length, `netif_receive_skb()` submission |
| `aicwf_dev_skb_free()` | `aicwf_txrxif.c` | SKB pointer, len, `dev_kfree_skb_any()` execution |
| `aicwf_usb_host_tx_cfm_handler()` | `usb_host.c` | `env`, `used_idx`, `host_id`/`skb` pointer, `data[0]` status |
| `rwnx_txdatacfm()` | `rwnx_tx.c` | `host_id`/`skb`, `txhdr`, `sw_txhdr`, `rwnx_vif`, `cfg80211_mgmt_tx_status`, `net_stats`, `kmem_cache_free`, `consume_skb` |
| `rwnx_txq_confirm_any()` | `rwnx_txq.c` | `txq`, `hwq`, `sw_txhdr`, `hwq_id`, `cfm_balance` |
| `rwnx_rx_handle_msg()` | `rwnx_msg_rx.c` | Message ID (`msg->id`), Type (`MSG_T`), Index (`MSG_I`), handler dispatch |

---

## 3. Repository Layout & Artifact Locations

```
/workspaces/monitor-debug-build/
├── aic8800_fdrv.ko              # Rebuilt instrumented debug kernel module binary
├── git.diff                     # Complete instrumentation patch diff (1567 lines)
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
    └── monitor_tx_instrumentation.diff # Full MONDBG instrumentation & NULL check patch (1567 lines)
```

---

Author: Appu John
