#!/bin/sh
# Qualify Texture3D volume storage on a renderer that claims the capability.
#
#   tools/qualification/texture3d-matrix.sh /path/to/libcna_c_api.so ...
#
# **Why this is a script of its own.** `texture3d-support-probe' answered one
# question -- can this library create a Texture3D -- and on HEADLESS and SOFTWARE
# the answer is `CNA_RESULT_NOT_SUPPORTED' on every admitted ABI. That is a true
# answer about those two renderers and was read as an answer about CNA. EasyGL
# advertises `GraphicsCapability::Texture3D' on every non-ES2 GL profile, so the
# capability has to be measured against a build that claims it, on a software GL
# stack a CI machine can reproduce.
#
# Each stage runs in its **own process**, for two reasons that both cost a
# measurement here:
#
#   * a stage that faults must name itself rather than take the rest with it, and
#   * EasyGL cannot create a second GraphicsDevice in one process -- the second
#     `cna_graphics_device_create' segfaults after the first device is destroyed.
#     That is a renderer defect, not a Texture3D one: HEADLESS and SOFTWARE churn
#     devices happily. The `churn' stage exists to keep saying so, and it is the
#     one stage expected to fail.
#
# The GL stack is Xvfb plus Mesa's llvmpipe, forced with `LIBGL_ALWAYS_SOFTWARE'.
# The point of the lane is that volume storage works on a *deterministic software
# implementation*, so a physical GPU is never a prerequisite; if one is present it
# is deliberately not used.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PROBE="$ROOT/build-probe/texture3d-volume-probe"
HEADERS=${CNA_HEADERS:-$HOME/deps/cna-c-abi-0.21.0/include}

# The stages, in the order a reader wants them: can it exist, does it keep what
# it is given, does it keep the rest, does it do so per level, and does it let go.
STAGES="create whole box mip depth-levels bytes range destroy volumes"
# Measured separately, because it is expected to fault and its failing is the
# result rather than a regression.
FAULT_STAGES="churn"

if [ "$#" -eq 0 ]; then
    echo "usage: texture3d-matrix.sh <libcna_c_api.so> [more...]" >&2
    exit 2
fi

if [ ! -x "$PROBE" ]; then
    echo "building $PROBE" >&2
    mkdir -p "$ROOT/build-probe"
    cc -O1 -Wall -Wextra -I "$HEADERS" -o "$PROBE" \
       "$ROOT/tools/native-abi/texture3d-volume-probe.c" -ldl
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
    echo "texture3d-matrix.sh needs xvfb-run: EasyGL wants a display, and the" >&2
    echo "whole point is that a virtual one is enough." >&2
    exit 2
fi

# llvmpipe, explicitly, so the answer is about Mesa's software rasteriser and not
# about whatever card happens to be in the machine.
LIBGL_ALWAYS_SOFTWARE=1
GALLIUM_DRIVER=llvmpipe
export LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER

echo "GL stack under Xvfb:"
xvfb-run -a --server-args="-screen 0 1280x800x24" sh -c \
    'glxinfo -B 2>/dev/null | sed -n "s/^\(OpenGL vendor\|OpenGL renderer\|OpenGL core profile version\|OpenGL version\).*/  &/p"' \
    || echo "  (glxinfo not installed; EasyGL prints its own profile below)"
echo

# Run one stage and answer with the **probe's** exit status, not the filter's.
# A pipeline's status is its last command's, so a segfaulting probe piped into
# grep reads as success -- which it did here until this was noticed.
run_stage() {
    _library=$1
    _stage=$2
    _log="$ROOT/build-probe/texture3d-stage.log"
    if xvfb-run -a --server-args="-screen 0 1280x800x24" \
           "$PROBE" "$_library" "$_stage" > "$_log" 2>&1
    then _status=0
    else _status=$?
    fi
    grep -v '^\[INFO\]' "$_log" | grep -v '^\[WARN\]' || true
    return $_status
}

status=0
for library in "$@"; do
    echo "=============================================================="
    echo "$library"
    if [ -f "$(dirname "$library")/CNA_COMMIT" ]; then
        echo "  CNA commit:           $(cat "$(dirname "$library")/CNA_COMMIT")"
        echo "  sharp-runtime commit: $(cat "$(dirname "$library")/SHARP_RUNTIME_COMMIT" 2>/dev/null || echo unrecorded)"
        echo "  configuration:        $(cat "$(dirname "$library")/CONFIG" 2>/dev/null || echo unrecorded)"
    else
        echo "  CNA commit:           unrecorded -- development evidence only"
    fi
    echo "=============================================================="
    for stage in $STAGES; do
        echo "--- $stage"
        if run_stage "$library" "$stage"; then
            :
        else
            echo "  *** stage $stage did not finish cleanly (exit/signal)"
            status=1
        fi
    done
    for stage in $FAULT_STAGES; do
        echo "--- $stage (expected to fault on EasyGL)"
        if run_stage "$library" "$stage"; then
            echo "  NOTE: this renderer survived a second device in one process."
        else
            echo "  as expected: a second GraphicsDevice in one process did not survive."
        fi
    done
    echo
done

if [ "$status" -eq 0 ]; then
    echo "every measured stage finished cleanly on every library above."
else
    echo "at least one stage did not finish cleanly; read the log above."
fi
exit "$status"
