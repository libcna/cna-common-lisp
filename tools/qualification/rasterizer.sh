#!/bin/sh
# Rasterizer qualification: prove that drawing reaches actual pixels.
#
# The HEADLESS lane proves lifecycle and command submission and says so; it
# cannot say anything about pixels, because the Headless renderer has no
# back-buffer storage to read. This lane runs the same suite against a CNA built
# with a rasterising renderer, and then **checks the evidence**: it fails if the
# run silently took the no-readback branch, which is the way a lane like this
# quietly stops proving anything.
#
# It requires two separate proofs, because they are two separate claims:
#
#   clear    GraphicsDevice.Clear reached the back buffer and read back
#   sprite   a SpriteBatch draw put a known texture's own texels on exactly the
#            pixels its destination rectangle names, and on none outside it
#
# A clear reaching the back buffer says nothing about whether SpriteBatch
# rasterises. This script used to accept the first as though it were both.
#
#   CNA_NATIVE_LIBRARY=/abs/path/libcna_c_api.so \
#     tools/qualification/rasterizer.sh
#
# The SOFTWARE renderer needs no display and no Xvfb: it is a CPU rasteriser, and
# a build configured with -DCNA_GRAPHICS_RENDERER=SOFTWARE runs headlessly in the
# ordinary sense of the word while still producing real pixels.
#
# No claim is made here about a physical monitor. Pixels in a back buffer are
# pixels in a back buffer.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}
log="$root/build-probe/rasterizer-qualification.log"

if [ -z "${CNA_NATIVE_LIBRARY:-}" ]; then
    echo "CNA_NATIVE_LIBRARY must name a CNA C ABI library built with a rasterising renderer" >&2
    exit 2
fi

mkdir -p "$root/build-probe"
echo "== running the suite against $CNA_NATIVE_LIBRARY =="
cd "$root"
"$sbcl" --non-interactive \
    --load "$HOME/quicklisp/setup.lisp" \
    --eval '(push (truename ".") asdf:*central-registry*)' \
    --eval '(asdf:test-system "cna-common-lisp")' > "$log" 2>&1 || {
        echo "the suite failed; last lines:" >&2
        tail -40 "$log" >&2
        exit 1
    }

grep -E "^(checks passed|failures|not run|rasterization) " "$log" || true

if ! grep -q '^rasterization : ' "$log"; then
    echo "FAIL the runner printed no rasterization line at all" >&2
    exit 1
fi
for kind in clear sprite; do
    if ! grep -q "^rasterization : $kind -- " "$log"; then
        echo "FAIL this lane requires a '$kind' proof and the run did not produce one:" >&2
        grep '^rasterization : ' "$log" >&2 || true
        echo "     Build CNA with -DCNA_GRAPHICS_RENDERER=SOFTWARE (no display needed)." >&2
        exit 1
    fi
done

echo
echo "rasterizer qualification passed"
grep '^rasterization : ' "$log" | sed 's/^/  /'
echo "  log $log"
echo
echo "  Proved: Clear reached the back buffer, and a SpriteBatch draw put a known"
echo "  texture's own texels on exactly the pixels its destination named."
echo "  Not proved, and not claimed: anything about a physical monitor, and"
echo "  anything about a GPU renderer -- SOFTWARE rasterises on the CPU."
