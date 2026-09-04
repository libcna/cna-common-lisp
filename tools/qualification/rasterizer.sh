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
# **The proofs it requires are not written here.** They are in
# `tools/qualification/rasterizer-proofs.json`, which is the one place they are
# written at all: this script requires exactly the kinds that file lists, refuses
# a run that produces a kind the file does not list, and
# `tools/qualification/verify-numbers.py` renders the same list and its count into
# the prose. That is deliberate. The list here used to be a comment, the loop
# below used to be a second copy of it, and the documents used to be a third --
# and the three had drifted apart: the comment said seven kinds, the loop
# required eight, and the README said four.
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
registry="$here/rasterizer-proofs.json"
required=$(python3 -c "import json,sys; print(' '.join(p['kind'] for p in json.load(open(sys.argv[1]))['proofs']))" "$registry")

for kind in $required; do
    if ! grep -q "^rasterization : $kind -- " "$log"; then
        echo "FAIL this lane requires a '$kind' proof and the run did not produce one:" >&2
        grep '^rasterization : ' "$log" >&2 || true
        echo "     The required set is $registry." >&2
        echo "     Build CNA with -DCNA_GRAPHICS_RENDERER=SOFTWARE (no display needed)." >&2
        exit 1
    fi
done

# And the other direction, which is what stops the registry going stale: a proof
# the suite produces and the registry does not name is not required by this lane
# and does not appear in the prose, so it is a proof nobody is counting.
# `none` is the runner's marker for a renderer that produced no proof at all, not
# a kind, so it is excluded here; the required loop above has already failed by
# then anyway, and this keeps that failure the one that gets reported.
produced=$(grep '^rasterization : ' "$log" | sed 's/^rasterization : //; s/ --.*//' \
               | grep -v '^none$' | sort -u)
for kind in $produced; do
    case " $required " in
        *" $kind "*) ;;
        *)
            echo "FAIL the run produced a '$kind' proof that $registry does not name." >&2
            echo "     Add it there, with what it claims, or the lane does not require it" >&2
            echo "     and no document counts it." >&2
            exit 1
            ;;
    esac
done

echo
echo "rasterizer qualification passed"
grep '^rasterization : ' "$log" | sed 's/^/  /'
echo "  log $log"
echo
echo "  Proved, one claim per required kind, from $registry:"
python3 -c "
import json, sys, textwrap
for proof in json.load(open(sys.argv[1]))['proofs']:
    print(textwrap.fill(proof['kind'] + ': ' + proof['claim'],
                        width=76, initial_indent='    ', subsequent_indent='      '))
" "$registry"
echo "  Not proved, and not claimed: anything about a physical monitor, and"
echo "  anything about a GPU renderer -- SOFTWARE rasterises on the CPU."
