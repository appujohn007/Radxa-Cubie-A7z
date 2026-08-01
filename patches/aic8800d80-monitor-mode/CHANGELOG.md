# Changelog - AIC8800D80 Monitor Mode Driver Patches

All notable changes to the AIC8800D80 USB Wi-Fi driver patches for monitor mode and packet injection are documented in this file.

## [2026-08-01] - Debug Instrumentation Phase 2 (Post-TX Completion & RX Message Path)

### Added
- **Post-USB-TX Completion Tracing (`MONDBG:`)**:
  - `usb_txc_sta_flowctrl()` (`aicwf_usb.c`): Log entry, `usb_buf`, `usb_dev`, `hostdesc`, `sta_idx`, flags, and NULL-check guards before dereferencing `usb_buf->skb`.
  - `aicwf_usb_tx_complete()` (`aicwf_usb.c`): Log entry, URB completion status, actual length, `cfm` flag, `skb` pointer, freeing non-cfm SKB via `dev_kfree_skb_any()`, and returning buffer to `tx_free_list`.
  - `aicwf_usb_rx_complete()` (`aicwf_usb.c`): Log entry for both prealloc and non-prealloc paths, URB status, length, enqueue to `rxq`, and signaling `busrx_trgg`.
- **Firmware Message & RX Handling Tracing**:
  - `aicwf_process_rxframes()` (`aicwf_txrxif.c`): Log entry, frame dequeue, and dispatch to `rwnx_rx_handle_msg` (CMD_RSP), `aicwf_usb_host_tx_cfm_handler` (DATA_CFM), `rwnx_rxdataind_aicwf` (DATA), and `rwnx_rx_handle_print` (PRINT).
  - `aicwf_tasklet_rxframes()` (`aicwf_txrxif.c`): Log entry and tasklet loop processing.
  - `rwnx_rxdataind_aicwf()` (`rwnx_rx.c`): Log entry, `hostid`/`skb`, and `rx_priv` pointers.
  - `rwnx_rx_monitor()` (`rwnx_rx.c`): Log entry, `rwnx_vif`, radiotap length, and `netif_receive_skb()` execution.
  - `aicwf_dev_skb_free()` (`aicwf_txrxif.c`): Log entry, SKB pointer, len, and `dev_kfree_skb_any()`.
- **Host TX Confirmation & Driver Completion Tracing**:
  - `aicwf_usb_host_tx_cfm_handler()` (`usb_host.c`): Log entry, `used_idx`, dequeued `host_id`/`skb`, status `data[0]`, and call to `rwnx_txdatacfm()`.
  - `rwnx_txdatacfm()` (`rwnx_tx.c`): Log entry, `txhdr`, `sw_txhdr`, `rwnx_vif`, `rwnx_sta`, `flags`, call to `cfg80211_mgmt_tx_status()`, call to `rwnx_txq_confirm_any()`, update of `net_stats`, `kmem_cache_free()`, and `consume_skb()`. Added NULL guards for `sw_txhdr->rwnx_vif`.
  - `rwnx_txq_confirm_any()` (`rwnx_txq.c`): Log entry, `txq`, `hwq`, `sw_txhdr`, `hwq_id`, and `cfm_balance`.
  - `rwnx_rx_handle_msg()` (`rwnx_msg_rx.c`): Log entry, `msg->id`, `MSG_T`, `MSG_I`, and handler dispatch.

### Changed
- Rebuilt `aic8800_fdrv.ko` at `/workspaces/monitor-debug-build/aic8800_fdrv.ko`.
- Updated `source_patch/monitor_tx_instrumentation.diff` (1567 lines).
- Updated `build.log` and `SHA256SUMS`.

---

## [2026-08-01] - Debug Instrumentation Phase 1 (Pre-TX & Vendor UAF Fix)

### Added
- **Pre-TX Instrumentation (`MONDBG:`)**:
  - `rwnx_select_queue()` (`rwnx_main.c`)
  - `rwnx_select_txq()` (`rwnx_tx.c`)
  - `rwnx_start_monitor_if_xmit()` (`rwnx_tx.c`)
  - `rwnx_txq_queue_skb()` (`rwnx_txq.c`)
  - `rwnx_hwq_process()` (`rwnx_txq.c`)
  - `rwnx_tx_push()` (`rwnx_tx.c`)
  - `aicwf_frame_tx()` (`aicwf_txrxif.c`)
  - `aicwf_usb_bus_txdata()` (`aicwf_usb.c`)
  - `aicwf_usb_tx_process()` (`aicwf_usb.c`)
- **Vendor Bug Fix**: Fixed vendor use-after-free bug in `aicwf_usb_bus_txdata()` where `txhdr->sw_hdr->need_cfm` was evaluated after `txhdr->sw_hdr` was freed via `kmem_cache_free`.

---

## [2024-11-19] - Initial Driver Release (Vendor RWNX v6.4.3.0)
- Initial vendor release for AIC8800D80 USB Wi-Fi chipset.
