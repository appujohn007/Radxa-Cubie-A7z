# Installation & Deployment Guide: Deterministic Wi-Fi Naming

This guide covers installing and enabling the deterministic Wi-Fi interface allocator on the **Radxa Cubie A7Z**.

---

## 📋 Prerequisites

Ensure you have root/sudo access to the Radxa Cubie A7Z board.

Clean up any conflicting custom `.link` files that may have been created previously:

```bash
sudo rm -f /etc/systemd/network/10-wlan-names.link
sudo rm -f /etc/systemd/network/11-mt7601u.link
```

*(Note: The stock vendor file `/usr/lib/systemd/network/50-radxa-aic8800.link` can remain in place as it only defers to kernel naming).*

---

## 🚀 Step 1: Install Allocator Script

1. Copy `wlan-allocator` to `/usr/local/sbin/`:
   ```bash
   sudo cp wlan-allocator /usr/local/sbin/wlan-allocator
   ```

2. Make sure executable permissions are set:
   ```bash
   sudo chmod 755 /usr/local/sbin/wlan-allocator
   sudo chown root:root /usr/local/sbin/wlan-allocator
   ```

3. Test run the script manually (optional):
   ```bash
   sudo /usr/local/sbin/wlan-allocator
   ip -br link
   ```

---

## ⚙️ Step 2: Install and Enable Systemd Service

1. Copy `wlan-allocator.service` to `/etc/systemd/system/`:
   ```bash
   sudo cp wlan-allocator.service /etc/systemd/system/wlan-allocator.service
   ```

2. Set proper ownership and permissions:
   ```bash
   sudo chmod 644 /etc/systemd/system/wlan-allocator.service
   sudo chown root:root /etc/systemd/system/wlan-allocator.service
   ```

3. Reload systemd and enable the unit:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable wlan-allocator.service
   ```

4. Start or verify the unit:
   ```bash
   sudo systemctl start wlan-allocator.service
   systemctl status wlan-allocator.service --no-pager
   ```

---

## 📶 Step 3: Bind NetworkManager Profiles to Hardware MACs

To ensure connection profiles stay with their physical hardware regardless of interface reordering:

1. Identify the MAC addresses:
   ```bash
   ip -br link
   ```

2. Unbind existing connection profiles from interface names and bind them to the respective MAC:

   **For Onboard AIC/ASIC profile:**
   ```bash
   sudo nmcli connection modify "<AIC_PROFILE_NAME>" \
       connection.interface-name "" \
       802-11-wireless.mac-address "<AIC_MAC_ADDRESS>"
   ```
   *(Example: `sudo nmcli connection modify "ab" connection.interface-name "" 802-11-wireless.mac-address EC:B5:0A:6A:23:F6`)*

   **For External Adapter profile:**
   ```bash
   sudo nmcli connection modify "<EXT_PROFILE_NAME>" \
       connection.interface-name "" \
       802-11-wireless.mac-address "<EXT_MAC_ADDRESS>"
   ```
   *(Example: `sudo nmcli connection modify "ab 1" connection.interface-name "" 802-11-wireless.mac-address 20:E0:17:0B:3A:1D`)*

---

## 🔍 Step 4: Verification After Reboot

Reboot the board to test boot-time sequencing:
```bash
sudo reboot
```

After reboot, verify the system state:

```bash
# 1. Check network interfaces and MAC assignments
ip -br link

# 2. Check wireless interface physical binding
iw dev

# 3. Check NetworkManager status
nmcli device status
nmcli connection show

# 4. Check systemd allocator service status
systemctl status wlan-allocator.service --no-pager

# 5. Check sysfs device link paths
readlink -f /sys/class/net/wlan0/device
readlink -f /sys/class/net/wlan1/device
```

