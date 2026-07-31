# Installation

## Copy Modules

```bash
sudo mkdir -p /lib/modules/$(uname -r)/extra

sudo cp aic_load_fw.ko \
/lib/modules/$(uname -r)/extra/

sudo cp aic8800_fdrv.ko \
/lib/modules/$(uname -r)/extra/
```

---

## Update Module Database

```bash
sudo depmod -a
```

---

## Firmware Path

```bash
sudo ln -sf \
/lib/firmware/aic8800_fw/USB/aic8800D80 \
/lib/firmware/aic8800D80
```

---

## Automatic Module Loading

```bash
echo -e "aic_load_fw\naic8800_fdrv" | \
sudo tee /etc/modules-load.d/aic8800.conf
```

---

## Reboot

```bash
sudo reboot
```

---

## Verify

```bash
lsmod | grep aic
```

```bash
iw dev
```

```bash
sudo dmesg | grep AIC
```

Expected

- aic_load_fw loaded
- aic8800_fdrv loaded
- wlan0 present
- firmware uploaded successfully

