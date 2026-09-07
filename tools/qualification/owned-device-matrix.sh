#!/bin/sh
# owned-device-matrix.sh --- measure the caller-created GraphicsDevice, one stage per process.
#
# `graphics_device.h' is byte-identical across ABI 0.21.0, 0.22.0 and 0.23.0 --
# `md5sum' says so -- and Storage already proved what that is worth. So every
# claim CNA-Lisp makes about a caller-created device is measured here, through
# the C ABI alone with no binding in the path.
#
#   owned-device-matrix.sh <library> [<library> ...]
#
# Each stage runs in its own process, so a stage that faults names itself and
# does not take the others with it. The output is the evidence; nothing in it is
# asserted here, because what CNA does is what this script is for finding out.
#
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
probe="$root/build-probe/owned-device-probe"

stages="create headless-ext two-devices game-then-device device-then-game resource
        cross-device cross-game destroy-with-child game-destroy-with-owned adapters churn events
        dispose-route double-destroy clear present pixels thread"

[ -x "$probe" ] || {
    echo "build the probe first:" >&2
    echo "  gcc -std=c11 -Wall -Wextra -O0 -g -I \$CNA_HEADERS \\" >&2
    echo "      tools/native-abi/owned-device-probe.c -o build-probe/owned-device-probe -ldl -lpthread" >&2
    exit 2
}

for library in "$@"; do
    echo "=============================================================="
    echo "=== $library"
    echo "=============================================================="
    for stage in $stages; do
        echo "--- stage: $stage"
        out=$("$probe" "$library" "$stage" 2>&1) && status=0 || status=$?
        printf '%s\n' "$out" | grep -v '^\[INFO\]\|^\[WARN\]\|Gtk-WARNING' || true
        if [ "$status" -eq 0 ]; then
            :
        elif [ "$status" -gt 128 ]; then
            echo "    VERDICT subprocess crash (signal $((status - 128)))"
        else
            echo "    VERDICT controlled failure (exit $status)"
        fi
    done
done
