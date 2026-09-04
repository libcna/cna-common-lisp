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
# It requires four separate proofs, because they are four separate claims:
#
#   clear      GraphicsDevice.Clear reached the back buffer and read back
#   sprite     a SpriteBatch draw put a known texture's own texels on exactly the
#              pixels its destination rectangle names, and on none outside it
#   primitive  a DrawUserPrimitives triangle, through a BasicEffect pass, covered
#              exactly the pixels its geometry covers and none outside them
#   render-target-data
#              every texel of a bound-and-cleared RenderTarget2D read back through
#              Texture2D.GetData -- which reads a texture and not a back buffer,
#              so it is the one pixel claim here that does not depend on
#              GetBackBufferData at all
#   render-target
#              a clear into a bound RenderTarget2D left the back buffer untouched,
#              and the target's own contents then reached the back buffer through
#              the texture path -- the first evidence here that does not depend on
#              the back-buffer readback being the only way to see a pixel
#   stock-effect
#              a pass applied through an AlphaTestEffect and through a
#              SkinnedEffect made a primitive draw legal and covered the right
#              pixels -- that they are usable draw effects, and nothing about the
#              alpha test or about skinning, neither of which this renderer
#              applies to the geometry these tests can give it
#   text       SpriteFont's metrics and SpriteBatch.DrawString's layout put each
#              glyph of a string at its own advanced position, from its own atlas
#              cell -- proved with a two-colour atlas, so a pixel says which
#              glyph reached it, and across a line break, so the line advance is
#              LineSpacing and not the glyph height
#
# A clear reaching the back buffer says nothing about whether SpriteBatch
# rasterises, neither says anything about the primitive pipeline, and none of the
# three says anything about text layout -- a font atlas texel arriving is not the
# same claim as a string being laid out. This script used to accept the first as
# though it were all of them.
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
for kind in clear sprite primitive text stock-effect render-target render-target-data; do
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
echo "  Proved: Clear reached the back buffer; a SpriteBatch draw put a known"
echo "  texture's own texels on exactly the pixels its destination named; a"
echo "  DrawUserPrimitives triangle drawn through a BasicEffect pass covered"
echo "  exactly the pixels its geometry covers; and DrawString laid a string out"
echo "  glyph by glyph, each from its own atlas cell at its own advanced"
echo "  position, across a line break."
echo "  Not proved, and not claimed: anything about a physical monitor, and"
echo "  anything about a GPU renderer -- SOFTWARE rasterises on the CPU."
