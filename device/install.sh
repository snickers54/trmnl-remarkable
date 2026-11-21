#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
APP_SOURCE="$PROJECT_DIR/dist/trmnl-remarkable-app"
APP_ROOT="/home/root/xovi/exthome/appload"
APP_DEST="$APP_ROOT/trmnl-remarkable"
BACKUP_DIR="/home/root/.local/share/trmnl-remarkable/install-backup"
STAGED="$APP_ROOT/.trmnl-remarkable.new.$$"

# activate.sh holds the model and firmware table, because every later start of
# XOVI goes through it too.
sh "$PROJECT_DIR/activate.sh" --check || exit $?

[ -d /home/root/xovi ] || { echo "Compatible XOVI is not installed; inspect OS compatibility before installing it." >&2; exit 21; }
[ -d "$APP_ROOT" ] || { echo "AppLoad application directory is missing: $APP_ROOT" >&2; exit 22; }
if ! { [ -f "$APP_SOURCE/manifest.json" ] && [ -f "$APP_SOURCE/resources.rcc" ] && [ -x "$APP_SOURCE/backend/entry" ]; }; then
  echo "Built AppLoad bundle is incomplete" >&2
  exit 23
fi

free_kb=$(df -Pk /home/root | awk 'NR==2 {print $4}')
[ "${free_kb:-0}" -ge 51200 ] || { echo "At least 50 MiB free under /home/root is required" >&2; exit 24; }

mkdir -p "$BACKUP_DIR" "$APP_ROOT"
rm -rf -- "$STAGED"
trap 'rm -rf -- "$STAGED"' EXIT HUP INT TERM
cp -R "$APP_SOURCE" "$STAGED"
chmod 0755 "$STAGED/backend/entry" "$STAGED/scripts/brightness_guard.sh"
chmod 0644 "$STAGED/manifest.json" "$STAGED/resources.rcc" "$STAGED/icon.png"
chown -R root:root "$STAGED"

# A bundle built for the other architecture fails here rather than at first
# launch, and the exec error on its own would not explain why.
if ! "$STAGED/backend/entry" --self-check "$STAGED"; then
  echo "Refusing installation: the bundled backend did not run on this device ($(uname -m)); this payload was built for a different reMarkable architecture" >&2
  exit 26
fi

if [ -e "$APP_DEST" ]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  mv "$APP_DEST" "$BACKUP_DIR/trmnl-remarkable.$stamp"
fi
# Each backup is a full app bundle. Timestamped names sort chronologically, so
# dropping the leading entries keeps the newest and stops repeated reinstalls
# from filling /home/root.
prune_oldest() {
  keep=$1
  shift
  while [ "$#" -gt "$keep" ]; do
    if [ -e "$1" ]; then rm -rf -- "$1"; fi
    shift
  done
}
prune_oldest 2 "$BACKUP_DIR"/trmnl-remarkable.*
mv "$STAGED" "$APP_DEST"
trap - EXIT HUP INT TERM

echo "TRMNL AppLoad bundle installed: $APP_DEST"

# activate.sh checks that AppLoad matches this firmware and that the hashtable
# was built on it, then starts XOVI and waits until Xochitl stays up with it.
if out=$(sh "$PROJECT_DIR/activate.sh" 2>&1); then
  echo "AppLoad is running. On the tablet, open AppLoad and tap TRMNL."
  exit 0
fi
# The bundle itself is installed and verified; only the runtime start did not
# take. Exiting non-zero here would make the caller roll back a good install, so
# report it instead and let the user reactivate.
echo "TRMNL_ACTIVATION_PENDING: the bundle is installed, but XOVI was not started."
printf '%s\n' "$out" | tail -n 5
exit 0
