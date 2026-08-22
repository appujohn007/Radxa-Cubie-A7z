# Deployment Quick Reference

## Target Hardware Topology
- **Device**: Radxa Cubie A7Z (Allwinner A733 / `sun60iw2p1`)
- **Kernel**: `5.15.147-21-a733`
- **Target Interface**: `wlan0` (AIC8800 internal Wi-Fi)
- **Protected Interface**: `wlan1` (MediaTek MT7601U with active SSH session at `10.150.138.121`)

## Verified Deployment Steps
```bash
# 1. Install patched modules
sudo cp driver/aic8800_fdrv.ko /lib/modules/5.15.147-21-a733/updates/dkms/
sudo cp driver/aic_load_fw.ko /lib/modules/5.15.147-21-a733/updates/dkms/
sudo depmod -a 5.15.147-21-a733

# 2. Live driver swap (preserves wlan1/SSH)
sudo rmmod aic8800_fdrv
sudo modprobe aic8800_fdrv_usb

# 3. Switch to monitor mode (Hardware Verified)
sudo nmcli device set wlan0 managed no
sudo ip link set wlan0 down
sudo iw dev wlan0 set type monitor
sudo ip link set wlan0 up
iw dev wlan0 info
```

## Rollback
```bash
cd deploy/
sudo ./rollback.sh
sudo reboot
```
