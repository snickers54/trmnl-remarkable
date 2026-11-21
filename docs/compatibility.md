# Compatibility

| Component | Status |
|---|---|
| reMarkable Paper Pro (`reMarkable Ferrari`, aarch64) | Supported; developed and validated on this device |
| reMarkable 2 (`reMarkable 2.0`, armv7l) | Supported; not yet exercised on hardware |
| reMarkable 1 (`reMarkable 1.0` or `reMarkable Prototype 1`, armv7l) | Supported; not yet exercised on hardware |
| Other reMarkable models (Paper Pro Move, Paper Pure) | Blocked |
| reMarkable OS 3.29.x | Supported on the Paper Pro and reMarkable 2; 3.29.1.0 exercised on Paper Pro hardware |
| reMarkable OS 3.27.x | Supported; 3.27.3.0 exercised on Paper Pro hardware |
| reMarkable OS 3.26.x | Allowed by the installer; not exercised on hardware |
| reMarkable OS 3.20.x–3.25.x | Allowed on the reMarkable 1 only, which no longer receives releases |
| reMarkable OS 3.28.x | Blocked; AppLoad 0.6.0 supports it, but it has not been validated |
| OS 3.30 and later, or below the windows above | Blocked until validated |
| XOVI 0.3.3 (aarch64 and arm32) | Pinned |
| rm-xovi-extensions release 19 (aarch64 and arm32) | Pinned |
| AppLoad 0.5.3 (aarch64 and arm32) | Pinned; installed on OS 3.20.x–3.27.x |
| AppLoad 0.6.0 (aarch64 and arm32) | Pinned; installed on OS 3.29.x |
| Windows 10/11 x64 | Installer platform |

## Firmware windows

The window is per device because the devices are not on the same release line:

| Device | Accepted firmware | Why |
|---|---|---|
| Paper Pro | 3.26.x, 3.27.x, 3.29.x | The lines validated against pinned XOVI/AppLoad |
| reMarkable 2 | 3.26.x, 3.27.x, 3.29.x | Same release line as the Paper Pro |
| reMarkable 1 | 3.20.x – 3.27.x | reMarkable stopped shipping releases for it; a window ending at 3.26 would exclude every rM1 in use |

## AppLoad and the hashtable

AppLoad hooks Xochitl's own QML, and that QML changed in 3.28. AppLoad 0.6.0
hooks the new interface and 0.5.3 the old one, so the release carries both and
installs the one that matches the tablet's firmware. XOVI and its extensions
are the same on every line.

qt-resource-rebuilder resolves those hooks through a hashtable that has to be
built on the exact firmware the tablet runs
(`/home/root/xovi/exthome/qt-resource-rebuilder/hashtab`). Without one, or with
one from another firmware, Xochitl aborts as soon as XOVI starts; systemd
restarts it, and after four failures the tablet reboots itself. Right after an
OS update that reboot also falls back to the previous OS partition.

Every start of XOVI therefore goes through `activate.sh` on the tablet, which:

1. refuses an AppLoad build that is not the one for the running firmware;
2. reads the firmware recorded in the hashtable and, if it is missing or names
   another firmware, rebuilds it (Xochitl runs on its own for about a minute);
3. starts XOVI and watches Xochitl for eight seconds, restoring the stock
   interface at the first restart instead of letting it loop.

**Diagnostics** reports `appload_sha256` and `hashtab_firmware`.

## Panels

| Device | Resolution | Colour | Front light |
|---|---|---|---|
| Paper Pro | 1620 × 2160 | Yes | Yes |
| reMarkable 2 | 1404 × 1872 | No, 16 greys | No |
| reMarkable 1 | 1404 × 1872 | No, 16 greys | No |

The app reads `/sys/devices/soc0/machine` to decide, falling back to
`/proc/device-tree/model`. Front-light controls are hidden where there is no
front light, and dithering targets the panel that is present.

Do not bypass the model or firmware checks. reMarkable updates can change
private APIs, framebuffer behaviour, runtime compatibility, or SSH access.
Before updating the tablet, return to the stock interface, check this page and
the open issues, and keep a recovery path available.

Adding a firmware version to this list requires all of the following on physical
hardware, against the exact release archive: clean install, launch, a real
Device API refresh, cache and offline restart, overlay cleanup, front-light
restore where the device has one, suspend and resume, reboot to stock,
reactivation, uninstall, purge, and stock recovery. Record the model, the OS
build, and the archive's SHA-256.
