# Building BSP Kernel Modules for the Radxa Cubie A7Z

## Overview

This repository is the release and packaging side of the Radxa Cubie A7Z BSP work. The actual Linux kernel source and vendor BSP live in a separate checkout, and the build artifacts for deployment live here.

### Repository layout

- /workspaces/linux-a733
  - src: the actual Linux kernel source tree
  - bsp: the vendor BSP tree, including the AIC8800 USB Wi-Fi driver sources

- /workspaces/Radxa-Cubie-A7z
  - patches: local source patches and work-in-progress modifications
  - built modules: generated .ko artifacts for deployment
  - documentation: developer notes and release documentation

The important distinction is:

- /workspaces/linux-a733 contains the kernel source and BSP sources used to build modules.
- /workspaces/Radxa-Cubie-A7z contains the rebuilt modules, release-oriented patches, backups, and developer documentation.

This document is the canonical guide for rebuilding the AIC8800 USB Wi-Fi driver and related BSP kernel modules for the Radxa Cubie A7Z.

---

## Build Environment

The verified kernel build environment for this work is:

- Kernel version: 5.15.147-21-a733
- Architecture: arm64
- Cross compiler: aarch64-linux-gnu-

### Required tools

The repo’s actual build flow assumes a standard Linux kernel build environment with the following available:

- make
- gcc / host build tools
- aarch64-linux-gnu-gcc
- kernel build dependencies already installed for the source tree
- the kernel source tree located at /workspaces/linux-a733/src
- the vendor BSP tree located at /workspaces/linux-a733/bsp

The repo’s top-level build wrapper also relies on the kernel source checkout being complete and configured for the target tree. The project’s own build rules define the build as a kernel-module build from the kernel source tree, not as a standalone vendor driver build.

---

## Correct Build Method

The build method that actually works for the AIC8800 USB Wi-Fi modules is the kernel module build from the real kernel source directory, restricted to the AIC USB directory with `M=...`.

This is the verified working command:

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

### Why other methods are wrong

#### 1) `make build-modules`

This command is part of the repo’s wrapper, but it is not the right command for the AIC USB driver when the goal is to build just the affected module set.

Why it fails:

- it triggers the top-level kernel build flow and then starts processing the whole source tree
- in this environment, unrelated BSP sources fail before the target driver build is isolated
- the failure is outside the AIC8800 USB driver itself

The repo’s wrapper is useful for a full kernel modules pass, but it is not the minimal or reliable path for developing the AIC8800 driver.

#### 2) Building the entire BSP

This is not a safe development method for this driver.

Why it fails:

- the BSP contains unrelated drivers and platform code
- the Cedar VE driver fails independently with a missing header
- unrelated failures stop the build before the AIC USB modules are produced

The command that works is deliberately restricted to the AIC8800 USB module directory.

#### 3) `make -C /lib/modules/$(uname -r)/build`

This is the standard kernel module pattern for in-tree modules, but it is not the correct build path for this repo when the driver is checked out in a vendor BSP subtree and the actual build tree is the kernel source at /workspaces/linux-a733/src.

Why it fails:

- it points at the currently running host kernel build tree, not the Radxa target kernel tree
- it does not match the repository’s intended source layout
- it can miss the proper kernel configuration and generated headers used by the AIC8800 driver build

#### 4) Arbitrary `O=` build directories

The project does not use an out-of-tree object directory for this driver development flow.

Why it fails:

- generated headers and module dependencies are expected to be created in the kernel source tree
- `O=` builds can fail with missing generated headers such as `asm/compiler.h`
- the repo’s verified path is the standard in-tree kernel source build, not a temporary object tree

### Parameter explanation

The working command uses these key pieces:

- `cd /workspaces/linux-a733/src`
  - actual kernel source tree

- `make ... modules`
  - build kernel modules in the current kernel tree

- `ARCH=arm64`
  - build for the Radxa A7Z target architecture

- `CROSS_COMPILE=aarch64-linux-gnu-`
  - use the Arm64 cross compiler

- `HOSTCC=gcc`
  - local host compiler for host tools

- `KBUILD_DEFCONFIG=bsp.config`
  - use the Radxa BSP config for this kernel

- `M=/workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb`
  - restrict the module build to the AIC8800 USB directory only

This ensures the build proceeds only for the target modules and avoids unrelated BSP drivers.

---

## Building Individual Modules

The AIC8800 USB directory contains the following modules:

- aic_load_fw
- aic8800_fdrv

They are selected by the USB module directory Makefile:

```make
obj-$(CONFIG_AIC_LOADFW_SUPPORT)    += aic_load_fw/
obj-$(CONFIG_AIC8800_WLAN_SUPPORT) += aic8800_fdrv/
```

This means the build system will build both modules when the directory is used as the target of the `M=` build.

### Verified module-only build

The working command used for the module-only build is:

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

This is the correct way to rebuild only the AIC USB kernel modules without rebuilding the whole BSP.

---

## Where Output Files Are Produced

When the module build succeeds, the generated kernel objects are produced in the module source directories themselves.

For this driver, the output files are written to:

- /workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic_load_fw/aic_load_fw.ko
- /workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/aic8800_fdrv.ko

The release copy into the Radxa working directory is:

- /workspaces/monitor-data-test-build/aic_load_fw.ko
- /workspaces/monitor-data-test-build/aic8800_fdrv.ko

These are the exact files produced and copied during the verified successful module-only build.

---

## Installing On The Radxa

The driver can be installed on the target Radxa after the modules are rebuilt.

### 1) Backup commands

Before replacing modules on the device, always back up the existing binaries:

```bash
cp /lib/modules/$(uname -r)/kernel/drivers/net/wireless/aic8800/aic_load_fw.ko \
   /root/aic_load_fw.ko.bak

cp /lib/modules/$(uname -r)/kernel/drivers/net/wireless/aic8800/aic8800_fdrv.ko \
   /root/aic8800_fdrv.ko.bak
```

### 2) Copy commands

Copy the rebuilt modules into the target directory:

```bash
cp /workspaces/monitor-data-test-build/aic_load_fw.ko \
   /lib/modules/$(uname -r)/kernel/drivers/net/wireless/aic8800/

cp /workspaces/monitor-data-test-build/aic8800_fdrv.ko \
   /lib/modules/$(uname -r)/kernel/drivers/net/wireless/aic8800/
```

### 3) depmod

Rebuild module dependencies:

```bash
depmod -a
```

### 4) Reboot

Then reboot the target system:

```bash
reboot
```

### 5) Verification commands

After boot, verify that the modules are present and loaded:

```bash
lsmod | grep aic
modinfo aic8800_fdrv
modinfo aic_load_fw
```

Also verify the interface appears as expected:

```bash
ip link
iw dev
```

---

## Common Build Errors

These are the errors and failure modes encountered during the development of this build workflow.

### 1) `asm/compiler.h: No such file or directory`

Cause:

- the kernel source tree is not configured to generate the required generated headers
- an `O=` or temporary object build is being used without the proper kernel build environment

How to recognize it:

```text
fatal error: asm/compiler.h: No such file or directory
```

Whether it is fatal:

- Yes, fatal

Correct solution:

- use the verified in-tree kernel build method from /workspaces/linux-a733/src
- do not use an arbitrary temporary object directory
- do not use `O=` for this work

### 2) `cedar_ve.h: No such file or directory`

Cause:

- unrelated BSP driver compilation triggers before the AIC8800 USB modules are processed
- the whole BSP build is being attempted instead of the module-only build

How to recognize it:

```text
bsp/drivers/ve/cedar-ve/platforms/ve_plat_sun60iw2.c:20:10: fatal error: cedar_ve.h: No such file or directory
```

Whether it is fatal:

- Yes, fatal for the whole BSP build

Correct solution:

- do not build the entire BSP
- build only the AIC USB modules with the `M=...` module-only build command

### 3) `Module.symvers` warnings

Cause:

- the module build completes without a full symbol version dump for the current kernel tree
- this is common during isolated external module builds

How to recognize it:

```text
WARNING: Symbol version dump "Module.symvers" is missing.
```

Whether it is fatal:

- No, not usually fatal for a module-only build

Correct solution:

- treat it as a warning, not a build blocker
- verify the target `.ko` files are still produced
- if needed, use the expected kernel tree and `M=` build path to keep the environment consistent

### 4) Undefined symbols during modpost

Cause:

- the module is built but its dependencies are not fully resolved in the current kernel tree or environment
- this can happen when building isolated modules outside the full target kernel or with missing module dependencies

How to recognize it:

```text
WARNING: modpost: "..." undefined!
```

Whether it is fatal:

- Often not fatal for the build itself, but it means the module may not load cleanly in a target system until dependencies are resolved properly

Correct solution:

- use the project’s canonical module build command from the real kernel source tree
- keep the module build isolated to the AIC USB directory
- test on the target system with `depmod` and `modprobe`/`insmod` as needed

### 5) Compiler warnings about indentation or unused labels

Cause:

- existing code warnings in the vendor driver, not necessarily a build failure

How to recognize it:

- `warning: label 'putbss' defined but not used`
- `warning: unused variable 'reord_cnt'`
- `warning: this 'if' clause does not guard...`

Whether it is fatal:

- No

Correct solution:

- ignore them unless they are accompanied by compiler errors

---

## Driver Development Workflow

The recommended incremental workflow is:

1. Edit the source under the vendor BSP tree
2. Keep the source change minimal and isolated
3. Rebuild only the affected module using the `M=...` build command
4. Copy the generated `.ko` files to the working artifacts directory
5. Install the rebuilt modules on the Radxa device
6. Run `depmod -a`
7. Reboot the device
8. Test the Wi-Fi functionality
9. If the result is wrong, roll back to the backup and retry

This workflow avoids the long rebuild loop associated with the full BSP.

---

## Monitor Mode Development

The monitor-mode work completed during this workflow involved the AIC8800 USB driver and live kernel-source patches.

### Modifications included

#### 1) `RWNX_VIF_TYPE(vif_el) fix`

The original patch logic checks the active interface list and ignores the monitor interface itself while determining whether data VIFs are present.

The relevant source guard lives in:

- /workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_main.c

This safeguard ensures the monitor VIF is handled correctly without incorrectly blocking monitor mode when a dedicated non-data interface is present.

#### 2) `NL80211_IFTYPE_P2P_DEVICE` exclusion

The guard explicitly ignores the P2P device type when checking for active data VIFs.

This is important because P2P_DEVICE is not a data interface and should not be treated as blocking monitor mode.

The modification lives in the same runtime interface-creation logic in:

- /workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/rwnx_main.c

#### 3) `CONFIG_RWNX_MON_DATA`

The build option is set in:

- /workspaces/linux-a733/bsp/drivers/net/wireless/aic8800/usb/aic8800_fdrv/Makefile

The change is:

```make
CONFIG_RWNX_MON_DATA = y
```

This enables the compile-time support for monitor+data behavior when the firmware supports it.

#### 4) Firmware symlink fix

The driver expects the firmware path to exist and be reachable from the target system. The firmware symlink fix ensures the runtime firmware files resolve correctly and the driver can load the expected helper module correctly.

This belongs with the release-side deployment work and should be maintained in the Radxa release tree rather than in the upstream vendor source tree directly.

---

## Repository Release Workflow

New patches and rebuilt modules should be released into /workspaces/Radxa-Cubie-A7z according to the following structure:

- source_patch/
  - source changes and patch files
- driver/
  - rebuilt or release candidate module files
- backup/
  - prior working .ko backups from the target system
- documentation/
  - developer notes and release instructions

The intended release flow is:

1. Keep a clean source branch for the driver experiment
2. Apply only the necessary source patch
3. Rebuild the affected module subset
4. Copy the generated `.ko` modules into the release directory
5. Save the build log
6. Back up prior modules before installation
7. Install and test on the Radxa
8. Update this document if the build process changes

---

## Lessons Learned

These are the practical lessons that saved time during this work:

- Never build the entire BSP unless absolutely necessary.
- Always build only the target module directory.
- Keep original `.ko` backups before installation.
- Use the verified in-tree kernel build path, not arbitrary out-of-tree builds.
- Test incrementally.
- Use Git branches for experiments and module testing.
- Record the exact working build command in the documentation.
- Keep BUILD.md updated whenever the build process changes.
- Do not trust generic kernel-module recipes when the repo is using a vendor BSP layout.
- Use the `M=...` module build command whenever the goal is to rebuild only AIC8800 modules.

---

## Canonical Command Summary

This is the canonical command verified for the AIC8800 USB Wi-Fi driver rebuild:

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

This is the command to use when rebuilding the AIC8800 USB driver in a controlled, minimal, and repeatable way.
