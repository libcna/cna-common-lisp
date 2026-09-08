#!/bin/sh
# Texture3D qualification: the branch where volume storage exists.
#
#   tools/qualification/texture3d.sh [libcna_c_api.so ...]
#
# **The ordinary suite already qualifies the other branch and this does not
# replace it.** HEADLESS and SOFTWARE have no volume storage, `cna_texture3d_create'
# answers CNA_RESULT_NOT_SUPPORTED on every admitted ABI, and
# `tests/native/texture-3d.lisp' asserts that refusal as a result rather than
# skipping it. This lane is the positive branch: a CNA built with the desktop-core
# EasyGL profile, on Mesa llvmpipe under Xvfb, so the evidence is about a software
# OpenGL implementation CI can reproduce and never about a card in the machine.
#
# The capability this lane requires is TEXTURE3D_TRANSFER, named in
# `tools/qualification/texture3d-proofs.json' with each claim it stands for.
#
# **One claim group per process, and that is a measurement rather than caution.**
# EasyGL cannot create a second GraphicsDevice in one process: the second
# `cna_graphics_device_create' segfaults after the first is destroyed, with no
# Texture3D anywhere in the stage, and HEADLESS and SOFTWARE do not. So a group is
# one device, the groups are this lane's units, and the ordinary suite -- which
# creates and destroys devices hundreds of times in one image -- must keep running
# on the renderers that tolerate it. `docs/texture3d-audit.md' has the matrix.
#
# The groups:
#
#   volume       one caller-owned HiDef device: construction and metadata, the
#                ownership identity, the whole level, one sub-volume with the rest
#                proven unmoved, the two refusals that make the transfers partial,
#                and disposal
#   mip          one caller-owned HiDef device: a mipmapped 8x4x3 volume, every
#                level CNA claims it has, and a refusal past the last
#   game-device  a Game: the same resource on a Game's own device, and the
#                EffectParameter that carries it
#   reach        one caller-owned **Reach** device: the refusal XNA's
#                ProfileCapabilities requires and CNA does not apply
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}
registry="$here/texture3d-proofs.json"

mkdir -p "$root/build-probe"
cd "$root"

if ! command -v xvfb-run >/dev/null 2>&1; then
    echo "texture3d.sh needs xvfb-run: EasyGL wants a display, and the whole" >&2
    echo "point of this lane is that a virtual one is enough." >&2
    exit 2
fi

# llvmpipe, explicitly, so the answer is about Mesa's software rasteriser.
LIBGL_ALWAYS_SOFTWARE=1
GALLIUM_DRIVER=llvmpipe
export LIBGL_ALWAYS_SOFTWARE GALLIUM_DRIVER

groups=$(python3 -c "
import json, sys
seen = []
for proof in json.load(open(sys.argv[1]))['proofs']:
    if proof['group'] not in seen:
        seen.append(proof['group'])
print(' '.join(seen))
" "$registry")

registered=$(python3 -c "
import json, sys
print(' '.join(p['kind'] for p in json.load(open(sys.argv[1]))['proofs']))
" "$registry")

run_group () {
    label=$1
    library=$2
    group=$3
    log="$root/build-probe/texture3d-$label-$group.log"

    CNA_NATIVE_LIBRARY="$library" \
    CNA_LISP_VALUEPROBE="${CNA_LISP_VALUEPROBE:-$root/build-probe/libcna-lisp-valueprobe.so}" \
    xvfb-run -a --server-args="-screen 0 1280x800x24" \
        "$sbcl" --non-interactive \
        --load "$HOME/quicklisp/setup.lisp" \
        --eval '(push (truename ".") asdf:*central-registry*)' \
        --eval '(asdf:load-system "cna-common-lisp/tests")' \
        --eval "(cna-common-lisp.tests:run-texture3d-claim :$group)" \
        > "$log" 2>&1 || {
            echo "FAIL $label/$group: the claim did not finish; last lines:" >&2
            tail -30 "$log" >&2
            return 1
        }
    grep '^texture3d : ' "$log" | sed 's/^/  /'
    return 0
}

run_one () {
    label=$1
    library=$2

    if [ ! -f "$library" ]; then
        echo "FAIL $label: $library does not exist" >&2
        return 1
    fi

    echo "== $label: $library =="
    if [ -f "$(dirname "$library")/CNA_COMMIT" ]; then
        echo "   CNA commit           $(cat "$(dirname "$library")/CNA_COMMIT")"
        echo "   sharp-runtime commit $(cat "$(dirname "$library")/SHARP_RUNTIME_COMMIT" 2>/dev/null || echo unrecorded)"
        echo "   configuration        $(cat "$(dirname "$library")/CONFIG" 2>/dev/null || echo unrecorded)"
    else
        echo "   CNA commit           unrecorded -- development evidence only"
    fi

    produced=""
    for group in $groups; do
        run_group "$label" "$library" "$group" || return 1
        produced="$produced $(grep '^texture3d : ' "$root/build-probe/texture3d-$label-$group.log" \
                              | sed 's/^texture3d : //; s/ --.*//' | tr '\n' ' ')"
    done

    # Every registered kind by name. A group that ran and recorded nothing is
    # exactly what this catches, and it is the failure a "the lane passed" line
    # would hide.
    missing=0
    for kind in $registered; do
        case " $produced " in
            *" $kind "*) ;;
            *)
                echo "FAIL $label: no '$kind' claim was recorded. Each kind is required" >&2
                echo "     by name: a volume that constructs says nothing about whether" >&2
                echo "     the voxels it is given come back, and voxels that come back" >&2
                echo "     say nothing about whether a box write left the rest alone." >&2
                missing=1
                ;;
        esac
    done

    # And the other direction, which is what stops the registry going stale.
    for kind in $produced; do
        case " $registered " in
            *" $kind "*) ;;
            *)
                echo "FAIL $label: a '$kind' claim was produced that $registry does not" >&2
                echo "     name. Add it there, with what it claims, or the lane does not" >&2
                echo "     require it and no document counts it." >&2
                missing=1
                ;;
        esac
    done
    [ "$missing" -eq 0 ] || return 1
    echo "   all $(echo $registered | wc -w) claims recorded"
    echo
}

failures=0
if [ "$#" -gt 0 ]; then
    for library in "$@"; do
        run_one "$(basename "$(dirname "$library")")" "$library" \
            || failures=$((failures + 1))
    done
elif [ -n "${CNA_NATIVE_LIBRARY:-}" ]; then
    run_one requested "$CNA_NATIVE_LIBRARY" || failures=$((failures + 1))
else
    for version in 0.21.0 0.22.0 0.23.0; do
        run_one "$version" "$HOME/deps/cna-c-abi-$version-opengl33/libcna_c_api.so" \
            || failures=$((failures + 1))
    done
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL $failures lane(s) failed" >&2
    exit 1
fi

cat <<'EOF'
== what this run proved ==
  TEXTURE3D_TRANSFER  a renderer with volume storage kept every voxel it was
                      given: whole level, one sub-volume with the rest unmoved,
                      and every mip level the renderer claims to have -- byte for
                      byte, over a pattern that varies on all three axes.
  The ordinary suite keeps the other branch: HEADLESS and SOFTWARE answer
  NOT_SUPPORTED and tests/native/texture-3d.lisp asserts it. Both are evidence.
EOF
