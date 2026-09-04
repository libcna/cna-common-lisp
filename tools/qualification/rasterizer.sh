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

evidence=$(grep '^rasterization : ' "$log" || true)
if [ -z "$evidence" ]; then
    echo "FAIL the runner printed no rasterization line at all" >&2
    exit 1
fi
case "$evidence" in
    *"back buffer read"*) ;;
    *)
        echo "FAIL this lane must reach a rasterising renderer, and did not:" >&2
        echo "     $evidence" >&2
        echo "     Build CNA with -DCNA_GRAPHICS_RENDERER=SOFTWARE (no display needed)." >&2
        exit 1
        ;;
esac

echo
echo "rasterizer qualification passed"
echo "  $evidence"
echo "  log $log"
echo "  This proves selected drawing reached actual pixels in a back buffer."
echo "  It is not a claim about a physical monitor."
