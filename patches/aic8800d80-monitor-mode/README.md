# AIC8800D80 USB Wi-Fi Driver Patch & Dual Build Workflow (Radxa Cubie A7Z)

## Overview

This directory contains the patch documentation and build references for the AIC8800D80 USB Wi-Fi driver on the Radxa Cubie A7Z.

To ensure strict separation between empirical root-cause analysis and bug fixes, the project maintains **TWO separate build directories**:

1. **Build A (`/workspaces/monitor-build-A-instrumentation/`)**:
   - **Purpose**: Root-cause analysis.
   - **Characteristics**: Contains ONLY `MONDBG:` `printk()` instrumentation. **100% original vendor driver logic** with zero early returns, zero NULL guards, zero skipped paths, and zero execution flow changes.
2. **Build B (`/workspaces/monitor-build-B-fix/`)**:
   - **Purpose**: Targeted bug fix.
   - **Status**: Pending empirical runtime crash identification via Build A.

---

## 1. Build A & Build B Separation Rules

| Property | Build A (`monitor-build-A-instrumentation`) | Build B (`monitor-build-B-fix`) |
|---|---|---|
| **Objective** | Identify exact crash location in `dmesg` | Implement minimal bug fix |
| **Vendor Logic** | 100% Original | Modified (Only as needed for fix) |
| **NULL Guards** | NONE | Allowed for verified bug fix |
| **Early Returns** | NONE | Allowed for verified bug fix |
| **Instrumentation** | Dense `MONDBG:` logging | Retained for verification |
| **Current Status** | **Ready & Packaged** | **Placeholder (Pending Build A analysis)** |

---

## 2. Driver Call Pipeline & Instrumentation Tracing (`MONDBG:`)

```
USB Core Endpoint Completion Callback
  │
  ├───► aicwf_usb_tx_complete() [aicwf_usb.c]
  │       ├── usb_txc_sta_flowctrl()
  │       ├── dev_kfree_skb_any() [if cfm == false]
  │       └── aicwf_usb_tx_queue(..., tx_free_list)
  │
  └───► aicwf_usb_rx_complete() [aicwf_usb.c]
          │
          └──► usb_busrx_thread() / aicwf_tasklet_rxframes()
                │
                └──► aicwf_process_rxframes() [aicwf_txrxif.c]
                      │
                      ├── [DATA] ───────► rwnx_rxdataind_aicwf() ──► rwnx_rx_monitor() ──► netif_receive_skb()
                      ├── [DATA_CFM] ───► aicwf_usb_host_tx_cfm_handler() ──► rwnx_txdatacfm() ──► rwnx_txq_confirm_any()
                      └── [CMD_RSP] ────► rwnx_rx_handle_msg()
```

---

## 3. Package References & Locations

- **Build A Output Directory**: `/workspaces/monitor-build-A-instrumentation/`
  - `aic8800_fdrv.ko` (Build A binary)
  - `git.diff` (Pure MONDBG instrumentation diff)
  - `build.log`
  - `README.md`
  - `SHA256SUMS`
- **Build B Output Directory**: `/workspaces/monitor-build-B-fix/` (Placeholder)
- **Linux BSP Source Tree**: `/workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/`

Author: Appu John
