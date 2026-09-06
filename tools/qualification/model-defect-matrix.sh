#!/bin/sh
# model-defect-matrix.sh --- run every loaded-Model probe stage in its own process.
#
# Both of CNA's loaded-Model defects are memory faults, not result codes, so the
# only honest way to measure them is to let a child process take the fault and
# read its exit status. The parent never touches the dangerous handle.
#
#   model-defect-matrix.sh <library> [<library> ...]
#
# Prints one line per (library, stage) with an explicit classification:
#
#   works                 the stage completed and the process exited 0
#   controlled failure    a CNA_Result came back non-zero; nothing crashed
#   subprocess crash      the child died of a signal, with the signal named
#
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
probe="$root/build-probe/model-defect-probe"
content="$root/tests/fixtures"
asset="three-bone-triangles"
stages="baseline destroy world techniques parameters current-technique clone basic-texture directional-light replaced"

[ -x "$probe" ] || { echo "build $probe first" >&2; exit 2; }

for library in "$@"; do
    abi=$("$root/build-probe/abiver" "$library" | sed 's/.*  //')
    echo "=== $abi  ($library)"
    for stage in $stages; do
        out=$("$probe" "$library" "$content" "$asset" "$stage" 2>&1) && status=0 || status=$?
        last=$(printf '%s\n' "$out" | grep '^STAGE ' | tail -1 | sed 's/^STAGE  *//; s/  */ /g')
        fault=$(printf '%s\n' "$out" | grep '^FAULT ' | tail -1 || true)
        if [ "$status" -eq 0 ]; then
            verdict="works"
        elif [ "$status" -gt 128 ]; then
            signal=$(kill -l $((status - 128)) 2>/dev/null || echo "signal $((status - 128))")
            verdict="subprocess crash (SIG$signal)"
        else
            verdict="controlled failure (exit $status)"
        fi
        printf '  %-18s %-34s last: %s\n' "$stage" "$verdict" "${last:-<none>}"
        [ -n "$fault" ] && printf '  %-18s %s\n' "" "$fault" || true
    done
done
