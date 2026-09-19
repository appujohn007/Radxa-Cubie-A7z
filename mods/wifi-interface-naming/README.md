# Wi-Fi Interface Naming & AIC/ASIC Reservation

[![Target Board](https://img.shields.io/badge/Hardware-Radxa%20Cubie%20A7Z-orange.svg)](https://radxa.com)
[![SoC](https://img.shields.io/badge/SoC-Allwinner%20A733%20%28ARM64%29-red.svg)](https://www.allwinnertech.com)
[![Kernel](https://img.shields.io/badge/Kernel-5.15.147--21--a733-blue.svg)](https://github.com/radxa-pkg/linux-a733)
[![Status](https://img.shields.io/badge/Status-VERIFIED%20WORKING-brightgreen.svg)](#verified-results-after-reboot)

This directory provides the architecture, implementation scripts, systemd service, and NetworkManager hardware-binding instructions to achieve **deterministic Wi-Fi interface naming** on the **Radxa Cubie A7Z** single-board computer.

---

## 🎯 Purpose & Design Rationale

When multiple Wi-Fi adapters (e.g. onboard AIC8800 and external USB dongles like MediaTek MT7601U) are connected to the Radxa Cubie A7Z, Linux assigns interface names (`wlan0`, `wlan1`, ...) based on non-deterministic driver probe and USB bus enumeration order.

### Design Objectives
1. **Deterministic AIC Ownership:** The onboard AIC/ASIC Wi-Fi must always be assigned to `wlan0`.
2. **Dedicated External Allocation:** All other Wi-Fi adapters must be assigned sequential indices starting at `wlan1` (`wlan1`, `wlan2`, `wlan3`, ...).
3. **Strict Reservation:** `wlan0` must remain strictly reserved for the onboard AIC even when the AIC is absent or not initialized; non-AIC adapters must never take `wlan0`.
4. **Collision-Free Reordering:** Interface enumeration race conditions must be resolved cleanly without naming collisions.
5. **Hardware-Bound Network Profiles:** NetworkManager connection profiles must follow physical hardware MAC addresses rather than volatile interface names.

> **Key Architectural Principle:**
> *Interface names represent the functional role of the hardware (`wlan0` = onboard AIC, `wlan1+` = external adapters), while NetworkManager connection profiles identify the physical hardware via MAC address.*

---

## 🖥️ Target Hardware Identification

Real hardware testing on the Radxa Cubie A7Z identified the following physical paths and MAC addresses:

### 1. Onboard AIC/ASIC Wi-Fi
* **Role:** Primary Onboard Wireless Adapter (`wlan0`)
* **Hardware MAC:** `ec:b5:0a:6a:23:f6`
* **P2P MAC:** `ec:b5:0a:6a:23:f7`
* **Physical Device Path:** `/sys/devices/platform/soc@3000000/4200000.ehci1-controller/usb4/4-1`
* **udev Path:** `platform-4200000.ehci1-controller-usb-0:1`
* **Identification Criterion:** Path matches `*/4200000.ehci1-controller/usb4/4-1`

### 2. MediaTek MT7601U Wi-Fi
* **Role:** External USB Wireless Adapter (`wlan1`)
* **Hardware MAC:** `20:e0:17:0b:3a:1d`
* **Vendor ID / Product ID:** `148f:7601`
* **Model:** 802.11_n_WLAN
* **Kernel Driver:** `mt7601u`
* **Physical Device Path:** `/sys/devices/platform/soc@3000000/4101000.ehci0-controller/usb3/3-1/3-1:1.0`
* **udev Path:** `platform-4101000.ehci0-controller-usb-0:1:1.0`

---

## 🔍 Initial Problem & Why Standard Solutions Failed

### The Initial Problem
At boot, the Linux kernel and USB subsystem enumerated the external MT7601U adapter before the onboard AIC:
```text
wlan0 -> MediaTek MT7601U (20:e0:17:0b:3a:1d)
wlan1 -> AIC/ASIC Onboard (ec:b5:0a:6a:23:f6)
```
Applications, services, and scripts expecting `wlan0` to be the onboard Wi-Fi failed or operated against the wrong physical radio.

### Why Vendor `.link` Files Failed
The vendor Radxa BSP shipping image includes:
`/usr/lib/systemd/network/50-radxa-aic8800.link`:
```ini
[Match]
OriginalName=wlan*

[Link]
NamePolicy=kernel
```
This rule does **not** identify the AIC8800 hardware specifically. It tells systemd-udevd to retain whatever random name the kernel assigned first (`NamePolicy=kernel`).

### Why Custom `.link` Files Were Insufficient
Attempting static renaming via `/etc/systemd/network/*.link` rules (such as matching MAC addresses or udev paths) resulted in device naming collisions and race conditions:
* If MT7601U was probed first and claimed `wlan0`, systemd could not rename the AIC to `wlan0` because `wlan0` was already occupied.
* Hardcoding individual external adapters in `.link` files is not scalable across arbitrary USB dongles.

---

## ⚙️ Solution Architecture

```
                                  [ System Boot ]
                                         │
                                         ▼
                            systemd-udev-settle.service
                           (USB & kernel drivers probe)
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
               MT7601U probed (wlan0)           AIC probed (wlan1)
                         └───────────────┬───────────────┘
                                         │
                                         ▼
                             wlan-allocator.service
                       (/usr/local/sbin/wlan-allocator)
                                         │
             ┌───────────────────────────┴───────────────────────────┐
             │ 1. Phase 1: Evacuate all wlan* to temporary names:    │
             │    wlan0 -> wlanx<PID>_0                              │
             │    wlan1 -> wlanx<PID>_1                              │
             │                                                       │
             │ 2. Phase 2: Inspect /sys/class/net/<dev>/device       │
             │    Find device matching */4200000.ehci1-controller/   │
             │                                                       │
             │ 3. Phase 3: Deterministic Assignment                  │
             │    AIC -> wlan0                                       │
             │    Other adapters -> wlan1, wlan2, ...                │
             │    (If AIC absent, wlan0 remains unoccupied!)         │
             └───────────────────────────┬───────────────────────────┘
                                         │
                                         ▼
                               NetworkManager.service
                   (Binds profiles via 802-11-wireless.mac-address)
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
                 wlan0: AIC                          wlan1: MT7601U
            Profile "ab" (MAC EC:..)            Profile "ab 1" (MAC 20:..)
```

### 1. Two-Phase Name Evacuation
Directly renaming `wlan1` to `wlan0` fails with `File exists` (`EEXIST`) if `wlan0` is already assigned to another adapter. The allocator solves this by moving all active `wlan*` interfaces into temporary namespaces (`wlanx<PID>_<index>`), freeing up the `wlan0..wlanN` slots before final assignment.

### 2. Physical Controller Path Inspection
Rather than relying on volatile kernel naming or MAC addresses (which may change on new hardware revisions or multiple boards), the allocator verifies the physical USB root hub / bus topology:
```sh
path=$(readlink -f "/sys/class/net/$iface/device" 2>/dev/null || true)
case "$path" in
    */4200000.ehci1-controller/usb4/4-1)
        return 0 # Onboard AIC
        ;;
    *)
        return 1 # External USB Adapter
        ;;
esac
```

### 3. Slot Allocation Logic
* **Onboard AIC Present:** Assigned to `wlan0`.
* **Onboard AIC Absent:** `wlan0` is **not** assigned to any device; external adapters start strictly at `wlan1`. This preserves `wlan0` role reservation.
* **External Adapters:** Sorted and allocated sequentially to `wlan1`, `wlan2`, `wlan3`, etc.

---

## 🌐 NetworkManager Hardware Profile Binding

In Debian Bullseye on the Cubie A7Z:
* `NetworkManager.service` is **active** and **enabled**.
* `systemd-networkd.service` is **inactive** and **disabled**.

Default NetworkManager connection profiles bind to interface names (`connection.interface-name: wlan0`). If interfaces ever change, connections become misrouted.

NetworkManager profiles were modified to bind strictly to hardware MAC addresses, setting `connection.interface-name ""` to unbind from names:

### Onboard AIC Profile (`ab`)
```bash
sudo nmcli connection modify "ab" \
    connection.interface-name "" \
    802-11-wireless.mac-address EC:B5:0A:6A:23:F6
```

### External MT7601U Profile (`ab 1`)
```bash
sudo nmcli connection modify "ab 1" \
    connection.interface-name "" \
    802-11-wireless.mac-address 20:E0:17:0B:3A:1D
```

---

## 📁 Repository Files

| File | Target Installation Path | Description |
| :--- | :--- | :--- |
| [`wlan-allocator`](wlan-allocator) | `/usr/local/sbin/wlan-allocator` | POSIX shell allocator script implementing two-phase interface reordering |
| [`wlan-allocator.service`](wlan-allocator.service) | `/etc/systemd/system/wlan-allocator.service` | Systemd oneshot unit executing after udev settle and before NetworkManager |
| [`INSTALL.md`](INSTALL.md) | N/A | Step-by-step deployment, activation, and verification guide |

---

## 🧪 Verified Results After Reboot

The service and allocator were verified on target hardware:

### 1. Interface Assignment (`ip -br link`)
```text
wlan0  UP  ec:b5:0a:6a:23:f6 <BROADCAST,MULTICAST,UP,LOWER_UP>
wlan1  UP  20:e0:17:0b:3a:1d <BROADCAST,MULTICAST,UP,LOWER_UP>
```
* `wlan0` consistently assigned to AIC/ASIC (`ec:b5:0a:6a:23:f6`).
* `wlan1` consistently assigned to MediaTek MT7601U (`20:e0:17:0b:3a:1d`).

### 2. Wireless Device Status (`iw dev`)
```text
wlan1:
    addr 20:e0:17:0b:3a:1d
    ssid ab

wlan0:
    addr ec:b5:0a:6a:23:f6
    ssid ab
```

### 3. NetworkManager State (`nmcli device status`)
```text
DEVICE  TYPE      STATE      CONNECTION
wlan0   wifi      connected  ab
wlan1   wifi      connected  ab 1
```

### 4. Systemd Service Execution Status
```text
$ systemctl status wlan-allocator.service --no-pager
● wlan-allocator.service - Reserve wlan0 for onboard AIC and allocate other Wi-Fi interfaces
     Loaded: loaded (/etc/systemd/system/wlan-allocator.service; enabled; vendor preset: enabled)
     Active: active (exited) since Sat 2026-09-19 05:20:00 UTC; 10min ago
    Process: 412 ExecStart=/usr/local/sbin/wlan-allocator (code=exited, status=0/SUCCESS)
   Main PID: 412 (code=exited, status=0/SUCCESS)
```

---

## 📌 Scope & Current Limitations

> [!IMPORTANT]
> **Boot-Time vs Hot-Plug Scope:**
> The current implementation runs as a boot-time oneshot service prior to NetworkManager startup.
>
> * **Supported:** Deterministic allocation and collision-free naming for all adapters connected at system boot.
> * **Not Yet Implemented (Future Roadmap):** Dynamic renumbering/compacting upon physical USB hotplug/unplug events occurring **after** boot (e.g., unplugging `wlan1` does not automatically shift `wlan2` to `wlan1`; plugging a dongle after boot relies on default kernel assignment).

