# Deployment Quick Reference

## Target Board
- **Device**: Radxa Cubie A7Z (Allwinner A733 / `sun60iw2p1`)
- **Kernel**: `5.15.147-21-a733`
- **Target Interface**: `wlan0` (AIC8800 internal Wi-Fi)
- **Protected Interface**: `wlan1` (Managed Wi-Fi with active SSH session)

## Quick Install
```bash
cd deploy/
sudo ./deploy.sh
sudo reboot
```

## Quick Test
```bash
sudo ip link set wlan0 down
sudo iw dev wlan0 set type monitor
sudo ip link set wlan0 up
iw dev wlan0 info
sudo tcpdump -i wlan0 -e -n -c 20
```

## Quick Rollback
```bash
cd deploy/
sudo ./rollback.sh
sudo reboot
```
