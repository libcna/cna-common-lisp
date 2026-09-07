#!/bin/sh
# owned-graphics-device.sh --- the caller-owned GraphicsDevice, in its own lanes.
#
# A seventh script beside audio, microphone, media, storage, services and the
# rasterizer, and for a reason of its own: **this is the only graphics surface in
# the repository that needs no `GAME'**, and the whole point of it would be lost
# if it were qualified inside a run that has one. The suite exercises it too --
# `tests/native/owned-graphics-device.lisp' -- but a suite run has games in it,
# so a lane that proves "no game is needed" has to be a process with no game.
#
#   OWNED_DEVICE_SUITE     the whole test system with all of the owned-device
#                          evidence required by name: the constructor, two
#                          coexisting devices, a game and an owned device side
#                          by side, resources reporting their actual device,
#                          cross-device use, the shared sampler slots, disposal,
#                          the Disposing event and construction atomicity.
#
#   OWNED_DEVICE_CONSUMER  the public-only consumer, audited mechanically for
#                          any reach into the internal package, CFFI, a handle,
#                          a result code or a private `%'-symbol -- and, the
#                          claim only this consumer and the storage one make,
#                          **for constructing no `GAME'**.
#
# The pixel claim depends on the renderer and the script says which it got.
# HEADLESS proves lifecycle and command submission and nothing about pixels;
# SOFTWARE -- a CPU rasteriser needing no display -- proves pixels. A run that
# took the no-readback branch says so rather than letting the reader assume.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so \
#     tools/qualification/owned-graphics-device.sh
#
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}

if [ -z "${CNA_NATIVE_LIBRARY:-}" ]; then
    echo "CNA_NATIVE_LIBRARY must name a CNA C ABI library" >&2
    exit 2
fi

mkdir -p "$root/build-probe"
cd "$root"

lisp() {
    "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
        --load "$HOME/quicklisp/setup.lisp" \
        --eval '(push (truename ".") asdf:*central-registry*)' "$@"
}

# ---------------------------------------------------------------------------
# 1. The suite, with every owned-device kind required by name.
# ---------------------------------------------------------------------------
echo "== lane suite: the owned-device evidence, required one kind at a time =="
suite_log="$root/build-probe/owned-device-suite.log"
lisp --eval '(asdf:test-system "cna-common-lisp")' > "$suite_log" 2>&1 || {
    echo "FAIL the suite failed; last lines:" >&2
    tail -40 "$suite_log" >&2
    exit 1
}

grep -E '^(checks passed|failures|not run) ' "$suite_log" || true

# Every kind that must be present on any renderer. The two renderer-dependent
# ones are handled below, because requiring both would make the lane unpassable
# on either.
for kind in create coexistence coexistence-with-game resources cross-device \
            shared-sampler-slots disposal events construction-atomicity; do
    if ! grep -q "^owned device  : $kind -- " "$suite_log"; then
        echo "FAIL this lane requires the '$kind' owned-device evidence and the run" >&2
        echo "     did not produce it:" >&2
        grep '^owned device  : ' "$suite_log" >&2 || true
        exit 1
    fi
done
grep '^owned device  : ' "$suite_log" | sed 's/^/  /'

# The pixel claim, and which branch this renderer took. Exactly one of the two
# must be present: neither means the test did not run at all, and both would
# mean it ran twice and cannot be read.
if grep -q '^owned device  : software -- ' "$suite_log"; then
    if grep -q '^owned device  : headless -- ' "$suite_log"; then
        echo "FAIL the run produced both a pixel claim and a no-readback result" >&2
        exit 1
    fi
    echo "  PIXELS: this renderer reads the back buffer back, and the standalone"
    echo "          device's pixels were checked one by one."
    renderer_claim=pixels
elif grep -q '^owned device  : headless -- ' "$suite_log"; then
    echo "  NO PIXELS: this renderer has no honest back-buffer readback, so the"
    echo "             standalone device proved its lifecycle and its commands and"
    echo "             nothing whatever about pixels. Run again against a CNA built"
    echo "             with -DCNA_GRAPHICS_RENDERER=SOFTWARE for the pixel claim."
    renderer_claim=lifecycle
else
    echo "FAIL the run produced neither a pixel claim nor a no-readback result," >&2
    echo "     which means the standalone-device pixel test did not run at all." >&2
    exit 1
fi
echo "  log $suite_log"
echo

# ---------------------------------------------------------------------------
# 2. The public-only consumer, which constructs no game.
# ---------------------------------------------------------------------------
echo "== lane consumer: the public API alone, and no game at all =="
consumer="$root/examples/owned-graphics-device-consumer.lisp"
consumer_log="$root/build-probe/owned-device-consumer.log"

code=$(sed 's/;.*$//' "$consumer")
audit() {
    pattern=$1; what=$2
    if printf '%s\n' "$code" | grep -qiE -- "$pattern"; then
        echo "FAIL $consumer uses $what, so it is not public-only and proves" >&2
        echo "     nothing about the public API:" >&2
        printf '%s\n' "$code" | grep -niE -- "$pattern" >&2
        exit 1
    fi
}
audit 'cna-lisp\.internal'   "the internal package"
audit 'cffi'                 "CFFI"
audit 'handle-of'            "a native handle"
audit 'check-result'         "a CNA result code"
audit 'defcfun|foreign-'     "a foreign definition"
audit '(^|[( :])%[a-z]'      "a private %-symbol"
# The claim this consumer shares with the storage one and with nothing else in
# the graphics surface: it never constructs a game.
if printf '%s\n' "$code" | grep -qE "make-instance +'xna:game|make-instance +\(quote xna:game\)"; then
    echo "FAIL $consumer constructs a GAME, so it does not show that a standalone" >&2
    echo "     GraphicsDevice needs none." >&2
    exit 1
fi
echo "  audited: no internal package, no CFFI, no handle, no result code,"
echo "           no private %-symbol -- and no GAME"

lisp --eval '(handler-bind ((warning (function muffle-warning)))
               (asdf:load-system "cna-common-lisp"))' \
     --load "$consumer" \
     --eval '(uiop:quit (cna-lisp-owned-graphics-device-consumer:main))' \
     > "$consumer_log" 2>&1 || {
        echo "FAIL the public-only consumer failed; last lines:" >&2
        tail -30 "$consumer_log" >&2
        exit 1
     }
grep '^OWNED-DEVICE ' "$consumer_log" | sed 's/^/  /'

# The consumer must have got as far as disposing what it made, on any renderer.
grep -q '^OWNED-DEVICE disposed yes' "$consumer_log" || {
    echo "FAIL the consumer did not dispose its device" >&2
    exit 1
}
grep -q '^OWNED-DEVICE adapter-identity the device answers the adapter it was given' \
     "$consumer_log" || {
    echo "FAIL the consumer's device did not answer the adapter it was constructed with" >&2
    exit 1
}
if [ "$renderer_claim" = pixels ]; then
    grep -q '^OWNED-DEVICE pixels a clear and a draw both reached the back buffer' \
         "$consumer_log" || {
        echo "FAIL this renderer reads pixels back and the consumer proved none" >&2
        grep '^OWNED-DEVICE ' "$consumer_log" >&2
        exit 1
    }
fi
echo "  log $consumer_log"
echo

echo "== what this run proved =="
echo "  OWNED_DEVICE_SUITE     nine kinds of owned-device evidence, each required"
echo "                         by name rather than read out of another"
echo "  OWNED_DEVICE_CONSUMER  a complete render through the public API alone,"
echo "                         with no GAME in the image"
if [ "$renderer_claim" = pixels ]; then
    echo "  OWNED_DEVICE_SOFTWARE  a standalone device's clear and draw reached real"
    echo "                         back-buffer pixels"
else
    echo "  OWNED_DEVICE_HEADLESS  a standalone device's lifecycle and commands only."
    echo "                         **No pixel claim is made by this run.**"
fi
echo
echo "  Not proved, and not claimed: anything about a physical monitor. Pixels in"
echo "  a back buffer are pixels in a back buffer. And nothing here says that"
echo "  cross-device resource use is refused -- it is not, by CNA or by XNA, and"
echo "  the suite asserts that rather than inventing a guard."
