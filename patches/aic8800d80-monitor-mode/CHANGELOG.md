# Changelog - AIC8800D80 Monitor Mode Driver Patches

All notable changes to the AIC8800D80 USB Wi-Fi driver patches for monitor mode and packet injection are documented in this file.

## [2026-08-01] - Build A (Pure Instrumentation) & Dual Build Architecture Setup

### Added
- **Build A Output Directory (`/workspaces/monitor-build-A-instrumentation/`)**:
  - Pure `MONDBG:` `printk()` logging across all TX, RX, USB completion, and message dispatch paths.
  - Reverted all previously introduced NULL guards, early returns, skipped paths, and vendor code re-orderings to ensure 100% original vendor control flow.
  - Generated `aic8800_fdrv.ko`, `git.diff`, `build.log`, `README.md`, and `SHA256SUMS`.
- **Build B Output Directory (`/workspaces/monitor-build-B-fix/`)**:
  - Initialized with placeholder `README.md` explaining Build B will be produced after Build A runtime log analysis identifies the exact crashing function.

---

## [2024-11-19] - Initial Driver Release (Vendor RWNX v6.4.3.0)
- Initial vendor release for AIC8800D80 USB Wi-Fi chipset.
