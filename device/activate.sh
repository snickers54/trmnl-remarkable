#!/bin/sh
# Starts XOVI with AppLoad for TRMNL, and refuses anything that would make
# Xochitl crash on launch.
#
#   activate.sh             check, build the hashtable if needed, start XOVI
#   activate.sh --check     check the model and firmware only
#   activate.sh --prepare   check, and build the hashtable if needed
#
# Starting XOVI with an AppLoad build for another firmware line, or without a
# hashtable built on this exact firmware, makes qt-resource-rebuilder abort
# Xochitl as soon as it loads. systemd restarts it, and after four failures in
# ten minutes the tablet runs its emergency service and reboots. Right after an
# OS update that emergency also falls back to the previous OS partition. Every
# path that starts XOVI therefore goes through the checks below first.
set -eu

XOVI=/home/root/xovi
APPLOAD_SO="$XOVI/extensions.d/appload.so"
REBUILDER_SO="$XOVI/extensions.d/qt-resource-rebuilder.so"
HASHTAB_DIR="$XOVI/exthome/qt-resource-rebuilder"
HASHTAB="$HASHTAB_DIR/hashtab"
DROPIN=/etc/systemd/system/xochitl.service.d
START_LOG=/tmp/trmnl-xovi-start.log
WORK=/tmp/trmnl-hashtab
SELF="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"

os_version=$(sed -n 's/^IMG_VERSION="\{0,1\}\([^" ]*\)"\{0,1\}$/\1/p' /etc/os-release | head -n1)

# The hashtable builder runs detached so that a dropped SSH session cannot leave
# Xochitl stopped. It is this same script, re-entered.
if [ "${1:-}" = "--build-hashtab-worker" ]; then
    out="$2"
    log="$WORK/xochitl.log"
    status=timeout
    systemctl stop xochitl || true
    QMLDIFF_HASHTAB_CREATE="$out" QML_DISABLE_DISK_CACHE=1 XOVI_ROOT="$WORK/root" \
        LD_PRELOAD="$XOVI/xovi.so" /usr/bin/xochitl >"$log" 2>&1 </dev/null &
    builder=$!
    # qmldiff hashes every QML file as Xochitl registers its resources, then
    # writes the table from a thread that wakes once a minute.
    i=0
    while [ "$i" -lt 150 ]; do
        sleep 1
        i=$((i + 1))
        if grep -qF "Hashtab saved to $out" "$log"; then status=saved; break; fi
        if ! kill -0 "$builder" 2>/dev/null; then status=exited; break; fi
    done
    kill -TERM "$builder" 2>/dev/null || true
    i=0
    while kill -0 "$builder" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 1; i=$((i + 1)); done
    kill -KILL "$builder" 2>/dev/null || true
    systemctl reset-failed xochitl 2>/dev/null || true
    systemctl start xochitl || true
    echo "$status" >"$WORK/done"
    exit 0
fi

model=$(tr -d '\000' </proc/device-tree/model 2>/dev/null || true)
machine=$(cat /sys/devices/soc0/machine 2>/dev/null || true)
identity=$machine
[ -n "$identity" ] || identity=$model
case "$identity" in
    "reMarkable Ferrari"|*"Paper Pro"*) device=rmpp ;;
    "reMarkable 2.0") device=rm2 ;;
    "reMarkable 1.0"|"reMarkable Prototype 1") device=rm1 ;;
    *) echo "Refusing to start: connected device is not a supported reMarkable ($identity)" >&2; exit 20 ;;
esac

# Each firmware line needs the AppLoad build made for it. AppLoad 0.6.0 hooks
# the 3.28 and later interface; 0.5.3 hooks the older one. The reMarkable 1 no
# longer receives releases, so its window ends with the line it last shipped.
appload=""
case "$device" in
    rm1) case "$os_version" in 3.2[0-7].*) appload=0.5.3 ;; esac ;;
    *) case "$os_version" in
           3.26.*|3.27.*) appload=0.5.3 ;;
           3.29.*) appload=0.6.0 ;;
       esac ;;
esac
if [ -z "$appload" ]; then
    echo "Refusing to start: reMarkable OS $os_version is not supported on this device" >&2
    exit 25
fi
[ "${1:-}" = "--check" ] && exit 0

case "$(uname -m)" in
    aarch64) payload=aarch64 ;;
    armv7l|armv6l) payload=arm32 ;;
    *) echo "Refusing to start: unsupported architecture $(uname -m)" >&2; exit 32 ;;
esac
case "$appload-$payload" in
    0.5.3-aarch64) appload_hash=31214cbbe64c8bfe7d99096f077c3009dba8a42ef1a733801aa0ec59c134e7cc ;;
    0.5.3-arm32) appload_hash=0c5592e48098288fd00b71f72b3eb6821aae0bf17cc3646dd8e95bf19c391810 ;;
    0.6.0-aarch64) appload_hash=5b2dd6c066da6932d88a1d62be1068ca5ba751f481636dd51f727221db62e3ad ;;
    0.6.0-arm32) appload_hash=28082cb18c5ca26740d15babc7334388866394004040a659613a0640047cb551 ;;
    *) echo "Refusing to start: no AppLoad $appload build is known for $payload" >&2; exit 32 ;;
esac

if ! { [ -f "$XOVI/xovi.so" ] && [ -x "$XOVI/start" ] && [ -f "$REBUILDER_SO" ]; }; then
    echo "Refusing to start: the XOVI runtime is missing or incomplete. Run the installer again." >&2
    exit 21
fi
actual=$(sha256sum "$APPLOAD_SO" 2>/dev/null | awk '{print $1}')
if [ "$actual" != "$appload_hash" ]; then
    echo "Refusing to start: reMarkable OS $os_version needs AppLoad $appload, and the installed AppLoad is a different build. Run the installer again to replace it." >&2
    exit 27
fi

# qmldiff writes a fixed header (an all-zero key, the length 38, and a 38-byte
# notice), then the version entry: the key hash("!*HashTab-Version"), the length
# of the version, and the version itself. Comparing those bytes exactly means a
# table built on any other firmware, or by an unknown writer, is rebuilt rather
# than trusted.
hashtab_matches() {
    [ -s "$1" ] || return 1
    expected="$WORK.expected.$$"
    {
        printf '\000\000\000\000\000\000\000\000\000\000\000\046'
        printf '%s' 'Hashtab file for QMLDIFF. Do not edit.'
        printf '\364\131\006\321\201\177\102\167\000\000\000'
        # The length is one byte written as an octal escape, so it has to be
        # part of the format string.
        # shellcheck disable=SC2059
        printf "\\$(printf '%03o' "${#os_version}")"
        printf '%s' "$os_version"
    } >"$expected"
    if dd if="$1" bs=1 count=$((62 + ${#os_version})) 2>/dev/null | cmp -s - "$expected"; then
        rm -f -- "$expected"
        return 0
    fi
    rm -f -- "$expected"
    return 1
}

# The stock unit must be the one that comes back after the builder: with XOVI's
# drop-in still mounted, Xochitl would restart with AppLoad against the table
# that is being replaced.
use_stock_unit() {
    if mount | grep -F " on $DROPIN type " >/dev/null 2>&1; then
        umount "$DROPIN"
    fi
    systemctl daemon-reload
}

build_hashtab() {
    echo "Building the qt-resource-rebuilder hashtable for reMarkable OS $os_version. The tablet screen restarts; this takes about a minute."
    rm -rf -- "$WORK"
    mkdir -p "$WORK/root/extensions.d" "$HASHTAB_DIR"
    ln -s "$REBUILDER_SO" "$WORK/root/extensions.d/qt-resource-rebuilder.so"
    rm -f -- "$HASHTAB.new"
    use_stock_unit
    setsid sh "$SELF" --build-hashtab-worker "$HASHTAB.new" </dev/null >"$WORK/worker.log" 2>&1 &
    i=0
    while [ ! -s "$WORK/done" ] && [ "$i" -lt 200 ]; do
        sleep 1
        i=$((i + 1))
    done
    status=$(cat "$WORK/done" 2>/dev/null || echo unfinished)
    if [ "$status" != saved ] || ! hashtab_matches "$HASHTAB.new"; then
        echo "The hashtable could not be built ($status). XOVI was not started; the stock interface is running." >&2
        grep -v 'Hashing:' "$WORK/xochitl.log" 2>/dev/null | tail -n 5 >&2 || true
        rm -f -- "$HASHTAB.new"
        exit 28
    fi
    mv -f -- "$HASHTAB.new" "$HASHTAB"
    rm -rf -- "$WORK"
    echo "Hashtable ready for reMarkable OS $os_version."
}

hashtab_matches "$HASHTAB" || build_hashtab
[ "${1:-}" = "--prepare" ] && exit 0

xochitl_pid() { pidof xochitl 2>/dev/null | awk '{print $1}'; }
xochitl_restarts() { systemctl show xochitl -p NRestarts --value 2>/dev/null || echo 0; }
injected() {
    [ -n "$1" ] && [ -r "/proc/$1/environ" ] &&
        tr '\000' '\n' <"/proc/$1/environ" | grep -q '^LD_PRELOAD=/home/root/xovi/xovi.so$'
}
# A quarter-second tick where sleep takes fractions, a second where it does not.
tick() { sleep 0.25 2>/dev/null || sleep 1; }
# Stopping first cancels the restart systemd has already queued; only then is
# the stock unit put back and started.
give_up() {
    systemctl stop xochitl 2>/dev/null || true
    use_stock_unit
    systemctl reset-failed xochitl 2>/dev/null || true
    systemctl start xochitl || true
    journalctl -u xochitl -n 80 --no-pager 2>/dev/null | grep -E 'panicked|Error' | tail -n 3 >&2 || true
    echo "$1" >&2
    exit 29
}

# systemd allows Xochitl four starts in ten minutes, then treats it as failed
# and the tablet reboots. XOVI re-mounting an unchanged drop-in does not reset
# that count, so a few activations in a row would leave a crash no retries at
# all. reset-failed clears it.
systemctl reset-failed xochitl 2>/dev/null || true
restarts=$(xochitl_restarts)
# When XOVI is already active the running Xochitl is injected too, so only a
# process that replaced it counts as started.
previous=$(xochitl_pid)
rm -f -- "$START_LOG"
setsid sh -c "exec $XOVI/start" >"$START_LOG" 2>&1 </dev/null &
pid=""
deadline=$(($(date +%s) + 30))
while [ "$(date +%s)" -lt "$deadline" ]; do
    tick
    [ "$(xochitl_restarts)" = "$restarts" ] || give_up "Xochitl crashed as XOVI started, so the stock interface was restored."
    pid=$(xochitl_pid)
    [ "$pid" != "$previous" ] && injected "$pid" && break
    pid=""
done
if [ -z "$pid" ]; then
    tail -n 3 "$START_LOG" 2>/dev/null >&2 || true
    echo "XOVI did not start within 30 seconds." >&2
    exit 29
fi
# A Xochitl that aborts on launch is injected too, briefly. Only one that is
# still the same process a few seconds later has actually loaded AppLoad.
deadline=$(($(date +%s) + 8))
while [ "$(date +%s)" -lt "$deadline" ]; do
    tick
    if [ "$(xochitl_pid)" != "$pid" ] || [ "$(xochitl_restarts)" != "$restarts" ]; then
        give_up "Xochitl did not stay up with XOVI loaded, so the stock interface was restored."
    fi
done
systemctl is-active --quiet xochitl || give_up "Xochitl is not running with XOVI loaded, so the stock interface was restored."
echo "XOVI_ACTIVE appload=$appload os=$os_version"
