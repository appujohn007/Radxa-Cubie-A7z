# Build Notes - AIC8800 Monitor Mode Debug Build

## Overview

This document details the build environment, compilation steps, and instrumentation patch structure for the AIC8800 USB Wi-Fi driver debug build.

---

## Driver Source Directory

The driver source code modified is located at:
```
/workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv
```

---

## Build Environment

- **Host**: Ubuntu 24.04
- **Target Architecture**: ARM64
- **Kernel Version**: 5.15.147-21-a733
- **Compiler**: `aarch64-linux-gnu-gcc`

---

## Working Build Command

```bash
cd /workspaces/linux-a733/src && \
make -j4 \
  ARCH=arm64 \
  CROSS_COMPILE=aarch64-linux-gnu- \
  HOSTCC=gcc \
  KBUILD_DEFCONFIG=bsp.config \
  M=/workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb \
  modules
```

---

## Instrumentation & Modifications Applied

### 1. Fine-Grained `MONDBG:` Tracing
Instrumented all major functions in the monitor TX path:
- `rwnx_select_queue()` (`rwnx_main.c`)
- `rwnx_select_txq()` (`rwnx_tx.c`)
- `rwnx_start_monitor_if_xmit()` (`rwnx_tx.c`)
- `rwnx_txq_queue_skb()` (`rwnx_txq.c`)
- `rwnx_hwq_process()` (`rwnx_txq.c`)
- `rwnx_tx_push()` (`rwnx_tx.c`)
- `aicwf_frame_tx()` (`aicwf_txrxif.c`)
- `aicwf_usb_bus_txdata()` (`aicwf_usb.c`)
- `aicwf_usb_tx_process()` (`aicwf_usb.c`)
- `aicwf_usb_tx_complete()` (`aicwf_usb.c`)

### 2. Defensive NULL-Pointer Guards
Before every pointer dereference, explicit `if (!ptr)` checks were added to:
- Log the exact NULL pointer name and context via `printk(KERN_ERR "MONDBG: ...")`
- Return proper error codes (`NETDEV_TX_OK`, `-EINVAL`, `-EIO`) or exit early instead of causing a kernel Oops crash.

### 3. Vendor Driver Bug Fix
Discovered and fixed a vendor driver use-after-free bug in `aicwf_usb_bus_txdata()`:
- `txhdr->sw_hdr` was freed with `kmem_cache_free()` in the `!need_cfm` path.
- Subsequently, `if (txhdr->sw_hdr->need_cfm)` was evaluated on line 1857, dereferencing freed memory.
- Replaced with local boolean check `if (need_cfm)`.

---

## Debug Build Artifact Output

The generated debug module is packaged at:
```
/workspaces/monitor-debug-build/
├── aic8800_fdrv.ko
├── git.diff
├── build.log
├── README.md
└── SHA256SUMS
```

The driver binary `aic8800_fdrv.ko` is intentionally kept in `/workspaces/monitor-debug-build/` for testing and diagnostic evidence collection.
