#!/bin/sh
# The four shim-dependent setters, in both configurations, in two processes.
#
# **Two branches and they are two claims**, and the split is forced rather than
# stylistic: the shim handle is process-global and latches in the loader, so one
# image cannot answer for two configurations. A run that reported both from one
# process would be reporting one of them from memory.
#
#   SHIM_ABSENT_ALL_FOUR   with no CNA_LISP_SHIM, GraphicsDevice.Viewport,
#                          BasicEffect.World, .View and .Projection ALL refuse
#                          with a CNA-NOT-SUPPORTED-ERROR that names the
#                          variable, the command that builds the shim and the
#                          System V reason -- and all four readers still work.
#   SHIM_PRESENT_ALL_FOUR  with the shim loaded, all four setters succeed.
#
# **This is the evidence behind a scoreboard decision.** All four are reported
# `partial', and until 2026-09-07 three of them were reported `complete' while
# the fourth was `partial' on the identical blocker. The lane exists so that the
# claim "they are one class" is measured rather than asserted: the suite fails a
# run in which the four disagree with each other, which is what would happen if
# the shim answered for some routes and not others.
#
# The rule they are classified under is in docs/compatibility.md, "What
# `complete' means across configurations": a member is complete when it is
# reachable in every supported installation, and the no-shim configuration is
# supported -- the Native workflow gates on it every commit.
#
#   tools/qualification/shim-policy.sh
#
# CNA_NATIVE_LIBRARY selects a single library instead of the admitted three.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}
shim=${CNA_LISP_SHIM:-$root/build-probe/libcna-lisp-shim.so}

mkdir -p "$root/build-probe"
cd "$root"

if [ ! -f "$shim" ]; then
    echo "FAIL the shim does not exist at $shim." >&2
    echo "     Build it with tools/native-abi/verify.sh <cna-header-root>." >&2
    echo "     This lane needs it: half of what it proves is that the four" >&2
    echo "     setters WORK when it is loaded." >&2
    exit 2
fi

# $1 label, $2 library, $3 kind (shim-absent|shim-present)
run_branch () {
    label=$1; library=$2; kind=$3
    log="$root/build-probe/shim-policy-$label-$kind.log"

    if [ "$kind" = shim-present ]; then
        CNA_LISP_SHIM="$shim"; export CNA_LISP_SHIM
    else
        unset CNA_LISP_SHIM || true
    fi

    CNA_NATIVE_LIBRARY="$library" \
    CNA_LISP_VALUEPROBE="${CNA_LISP_VALUEPROBE:-$root/build-probe/libcna-lisp-valueprobe.so}" \
    "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
        --load "$HOME/quicklisp/setup.lisp" \
        --eval '(push (truename ".") asdf:*central-registry*)' \
        --eval '(asdf:test-system "cna-common-lisp")' > "$log" 2>&1 || {
            echo "FAIL $label/$kind: the suite failed; last lines:" >&2
            tail -40 "$log" >&2
            return 1
        }

    grep '^shim policy   :' "$log" | sed 's/^/  /'

    if ! grep -q "^shim policy   : $kind " "$log"; then
        echo "FAIL $label/$kind: the suite did not record '$kind'." >&2
        echo "     A branch that does not report itself is a branch that did not" >&2
        echo "     run, and this lane must not read one out of the other." >&2
        return 1
    fi
    # And it must NOT have reported the other one: that would mean the shim
    # state was not what this branch set.
    other=shim-present
    [ "$kind" = shim-present ] && other=shim-absent
    if grep -q "^shim policy   : $other " "$log"; then
        echo "FAIL $label/$kind: the run also recorded '$other'." >&2
        return 1
    fi
    return 0
}

failures=0
if [ -n "${CNA_NATIVE_LIBRARY:-}" ]; then
    libraries="requested:$CNA_NATIVE_LIBRARY"
else
    libraries="0.21.0:$HOME/deps/cna-c-abi-0.21.0/libcna_c_api.so
0.22.0:$HOME/deps/cna-c-abi-0.22.0/libcna_c_api.so
0.23.0:$HOME/deps/cna-c-abi-0.23.0/libcna_c_api.so"
fi

echo "$libraries" | while IFS= read -r pair; do
    label=${pair%%:*}
    library=${pair#*:}
    echo "== $label: $library =="
    if [ ! -f "$library" ]; then
        echo "FAIL $label: $library does not exist" >&2
        exit 1
    fi
    run_branch "$label" "$library" shim-absent  || exit 1
    run_branch "$label" "$library" shim-present || exit 1
    echo "  both branches recorded"
    echo
done || failures=1

if [ "$failures" -ne 0 ]; then
    echo "FAIL at least one branch failed" >&2
    exit 1
fi

cat <<'EOF'
== what this run proved ==
  SHIM_ABSENT_ALL_FOUR   GraphicsDevice.Viewport and BasicEffect's World, View
                         and Projection ALL refused, in the same shape, with the
                         readers still working
  SHIM_PRESENT_ALL_FOUR  all four succeeded once the shim was loaded

  The four are one class: same blocker, same refusal, same working reader, and
  no run may produce a mixture. That is why all four are reported `partial' and
  why reporting three of them `complete' was wrong.

  Not proved, and not claimed: that shipping the shim prebuilt would be a good
  idea. Whether to close these four by packaging, by taking cffi-libffi, or by a
  pointer-taking CNA route is an open question, and PACKAGING_ABI_BRIDGE_LIMIT
  is the category that says so.
EOF
