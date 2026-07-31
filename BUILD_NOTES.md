# Radxa Cubie A7Z - MT7601U USB Wi-Fi Driver Notes

## Environment

Board:
- Radxa Cubie A7Z

OS:
- Official Radxa Debian Minimal

Kernel:
- 5.15.147-21-a733

USB Wi-Fi Adapter:
- MediaTek MT7601U
- USB ID: 148f:7601

---

# Problem

The stock Radxa kernel did not include MT7601U support.

Kernel config:

```
CONFIG_MT7601U is not set
```

As a result, the USB Wi-Fi adapter was detected by USB but no wireless interface appeared.

---

# Repository Used

Kernel source:

https://github.com/radxa-pkg/linux-a733

---

# What Was Changed

Enabled:

```
CONFIG_MT7601U=m
```

using

```
scripts/config --module MT7601U
```

followed by

```
make olddefconfig
```

---

# Important Discovery #1

Do NOT build the entire kernel.

Building all modules fails because the BSP source tree is incomplete.

Failure encountered:

```
cedar_ve.h: No such file or directory
```

Instead, build only the MT7601U module.

---

# Build Command

```
LOCALVERSION= make \
 ARCH=arm64 \
 CROSS_COMPILE=aarch64-linux-gnu- \
 HOSTCC=gcc \
 BSP_TOP=bsp/ \
 LICHEE_KERN_DIR=./ \
 M=drivers/net/wireless/mediatek/mt7601u \
 modules
```

---

# Important Discovery #2

The build system incorrectly used

```
HOSTCC=$(CROSS_COMPILE)gcc
```

This causes

```
scripts/basic/fixdep: Exec format error
```

Changing it to

```
HOSTCC=gcc
```

fixed the build.

---

# Important Discovery #3

The module MUST have identical vermagic.

Wrong:

```
5.15.147+
```

Correct:

```
5.15.147-21-a733
```

The fix was:

```
CONFIG_LOCALVERSION="-21-a733"
```

and rebuilding with

```
LOCALVERSION=
```

Otherwise the build system appends a "+".

---

# Important Discovery #4

The module loaded only after loading mac80211.

Before:

```
Unknown symbol ieee80211_register_hw
Unknown symbol ieee80211_alloc_hw_nm
...
```

Fix:

```
sudo modprobe mac80211
sudo insmod mt7601u.ko
```

---

# Successful Driver Load

Kernel log:

```
ASIC revision: 76010001
Firmware Version: 0.1.00
EEPROM ver:0d
ieee80211 phy1
registered new interface driver mt7601u
```

New interface:

```
wlan1
```

---

# Files

Working module:

```
mt7601u.ko
```

Built for:

```
Kernel:
5.15.147-21-a733
```

---

# Lessons Learned

- Always compare `vermagic` first.
- `CONFIG_MODVERSIONS` is disabled on this kernel, so symbol CRCs are not the issue.
- Do not build the entire BSP unless required.
- Building a single module is much faster and avoids missing BSP components.
- Vendor kernels may require manually loading dependency modules (`mac80211`) before inserting custom drivers.
- Keep a copy of the compiled module after every successful build.

---

# Future Checklist

1. Verify kernel version

```
uname -r
```

2. Verify module

```
modinfo mt7601u.ko | grep vermagic
```

3. Load dependency

```
sudo modprobe mac80211
```

4. Load driver

```
sudo insmod mt7601u.ko
```

5. Verify

```
ip link
iw dev
```

Expected:

```
wlan1
```

---

# Next Improvements

- Install `mt7601u.ko` under `/lib/modules/$(uname -r)/extra`
- Run `depmod`
- Allow loading via `modprobe mt7601u`
- Automate loading during boot
