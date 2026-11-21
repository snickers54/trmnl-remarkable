#!/bin/sh
set -u
echo "TRMNL reMarkable diagnostics"
echo "timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z')"
echo "model=$(tr -d '\000' </proc/device-tree/model 2>/dev/null || true)"
echo "machine=$(cat /sys/devices/soc0/machine 2>/dev/null || true)"
echo "arch=$(uname -m)"
echo "payload=$(case "$(uname -m)" in aarch64) echo aarch64;; armv7l|armv6l) echo arm32;; *) echo unknown;; esac)"
echo "kernel=$(uname -r)"
echo "os_version=$(grep -E '^(VERSION|VERSION_ID)=' /etc/os-release 2>/dev/null | tr '\n' ' ')"
echo "display=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null || echo unavailable)"
echo "xochitl=$(systemctl is-active xochitl 2>/dev/null || true)"
echo "xovi=$([ -d /home/root/xovi ] && echo present || echo absent)"
echo "appload=$([ -d /home/root/xovi/exthome/appload ] && echo present || echo absent)"
echo "appload_sha256=$(sha256sum /home/root/xovi/extensions.d/appload.so 2>/dev/null | awk '{print $1}')"
# The hashtable names the firmware it was built on right after its 50-byte
# header, as a one-byte length (od prints it in octal) and the version itself.
# activate.sh rebuilds the table when that is not the running firmware.
hashtab=/home/root/xovi/exthome/qt-resource-rebuilder/hashtab
hashtab_len=$(dd if="$hashtab" bs=1 skip=61 count=1 2>/dev/null | od -b | awk 'NR==1 {print $2}')
case "$hashtab_len" in
  [0-7][0-7][0-7]) echo "hashtab_firmware=$(dd if="$hashtab" bs=1 skip=62 count=$((0$hashtab_len)) 2>/dev/null | tr -cd '0-9.')" ;;
  *) echo "hashtab_firmware=absent" ;;
esac
for d in /sys/class/backlight/*; do
  [ -d "$d" ] || continue
  echo "backlight=$(basename "$d") min=$(cat "$d/min_brightness" 2>/dev/null || echo 0) max=$(cat "$d/max_brightness" 2>/dev/null || echo unknown) current=$(cat "$d/brightness" 2>/dev/null || echo unknown)"
done
battery=unknown
for supply in /sys/class/power_supply/*; do
  [ "$(cat "$supply/type" 2>/dev/null || true)" = Battery ] || continue
  [ -f "$supply/capacity" ] || continue
  battery=$(cat "$supply/capacity")
  break
done
echo "battery=$battery"
backend_pids=""
for proc in /proc/[0-9]*; do
  [ "$(readlink -f "$proc/exe" 2>/dev/null || true)" = "/home/root/xovi/exthome/appload/trmnl-remarkable/backend/entry" ] && backend_pids="$backend_pids${proc##*/},"
done
echo "backend_pids=$backend_pids"
echo "disk_free_kb=$(df -Pk /home/root 2>/dev/null | awk 'NR==2 {print $4}')"
