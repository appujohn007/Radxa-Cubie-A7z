# System Modifications & Configurations for Radxa Cubie A7Z

This directory houses all operational system modifications, runtime allocator daemons, hardware abstraction tweaks, and network integration configs for the **Radxa Cubie A7Z** (Allwinner A733, Debian Bullseye).

---

## 📑 Available System Modifications

| Mod Subproject | Target Subsystem | Key Mechanism | Status | Quick Links |
| :--- | :--- | :--- | :--- | :--- |
| **[`wifi-interface-naming/`](wifi-interface-naming/)** | Linux Network Stack / udev / NetworkManager | Physical bus path inspection (`4200000.ehci1-controller`) + two-phase collision-free rename + NetworkManager MAC binding | **VERIFIED WORKING** | [README](wifi-interface-naming/README.md) · [INSTALL](wifi-interface-naming/INSTALL.md) · [SCRIPT](wifi-interface-naming/wlan-allocator) · [SERVICE](wifi-interface-naming/wlan-allocator.service) |

---

## 🗂️ Mod Folder Layout

Each modification subproject in `mods/` is organized with self-contained documentation, scripts, and unit files:

```
mods/<mod-name>/
├── README.md               <- Technical overview, hardware path analysis & design rationale
├── INSTALL.md              <- Target board deployment runbook & verification checklist
├── <script_or_tool>        <- Executable shell/Python utilities
└── <service_or_config>     <- Systemd units, udev rules, or configuration files
```
