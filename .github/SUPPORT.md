# Support

Before filing an issue, confirm the tablet is a Paper Pro and the firmware is in
the supported range. Reboot once to return to the stock interface, then retry
the graphical installer.

For a bug report, include:

- TRMNL release version
- reMarkable model and firmware version
- Whether USB or Wi-Fi was used
- The exact redacted error message
- Diagnostics copied from the in-app Diagnostics screen
- Reproduction steps

Never post API keys, SSH passwords, private keys, or an unredacted config file.
Firmware outside 3.26.x, 3.27.x and 3.29.x (3.20.x to 3.27.x on the reMarkable
1) is a compatibility request, not an installation failure; the installer
intentionally refuses it. After updating the tablet's OS, run **Install TRMNL**
again before opening an issue: **Reactivate after reboot** refuses on purpose
until the AppLoad build for the new OS is installed.
