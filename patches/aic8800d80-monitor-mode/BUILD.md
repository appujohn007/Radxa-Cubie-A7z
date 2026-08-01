# Build Notes

## Initial Problem

The original AIC8800 USB driver rejected monitor mode because of an incorrect interface validation check inside:

```
drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_main.c
```

The loop checked:

```
RWNX_VIF_TYPE(vif)
```

instead of

```
RWNX_VIF_TYPE(vif_el)
```

which caused monitor interface creation to fail.

---

## Patch Applied

The current patch updates the monitor injection path in:

```
drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_tx.c
```

It changes the monitor TX path to:

- use the VIF unknown TXQ for monitor injection instead of assuming a peer STA context
- guard the radiotap iterator before dereferencing fields

This change is intentionally narrow and only affects the monitor TX/injection flow.

---

## Build Environment

Host

Ubuntu 24.04

Target

ARM64

Kernel

5.15.147-21-a733

Compiler

aarch64-linux-gnu-gcc

---

## Modules Built

```
aic8800_fdrv.ko
```

`aic_load_fw.ko` was not rebuilt for this patch and remains unchanged.

---

## Runtime Issues Found

### Missing exported symbols

Resolved by loading

```
aic_load_fw.ko
```

before

```
aic8800_fdrv.ko
```

---

### Firmware loading failure

Originally

```
fw_patch_table_8800d80_u02.bin file failed to open
```

Reason

Driver searched

```
/lib/firmware/aic8800D80
```

Firmware existed in

```
/lib/firmware/aic8800_fw/USB/aic8800D80
```

Solution

Created symlink.

---

## Verification

Verified

- firmware upload
- firmware patch table
- ADID upload
- firmware patch upload
- fmac firmware upload
- automatic module loading
- successful reboot
