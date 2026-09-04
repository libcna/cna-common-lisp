#!/bin/sh
# Overload-shape mutation self-test.
#
# A family of XNA overloads collapsed onto one Lisp function has to declare how
# each overload is told from its siblings, and the verifier has to be able to
# call a declaration a lie. This mutates the rules four ways and requires a
# wrong_overload_shape diagnostic each time, mutates the contract once and
# requires a refusal, and then requires a clean run.
#
# The fifth is not about overloads at all but belongs with them: two members
# sharing a signature key is how an overload goes unmeasured, and the count is the
# only thing that notices.
#
# The tagged-argument steps exist because of the mechanism EffectParameter
# needed. Its eighteen SetValue overloads differ only in the value's type; Lisp
# has no overloading to dispatch on that, so the projection takes the type as an
# argument and the rules declare "tagged-argument". A mechanism like that is
# worth nothing unless declaring it *wrongly* is caught -- naming no tag, or
# giving two overloads the same tag, which would make them the same call.
#
#   tools/api-compat/overload-mutations.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work="$root/build-probe/overload-mutations"
rules="$here/mapping-rules.json"

mkdir -p "$work"
cp "$rules" "$work/rules.orig"
restore() { cp "$work/rules.orig" "$rules"; }
trap restore EXIT

expect_red() {
    label=$1
    if python3 "$here/verify.py" --strict > "$work/out.txt" 2>&1; then
        echo "FAIL $label: the verifier stayed green" >&2
        exit 1
    fi
    if ! grep -q "wrong_overload_shape" "$work/out.txt"; then
        echo "FAIL $label: it went red, but not with wrong_overload_shape:" >&2
        sed -n '1,25p' "$work/out.txt" >&2
        exit 1
    fi
    echo "  ok  $label -> wrong_overload_shape"
    restore
}

echo "== 1. an overload family that declares no mechanism at all =="
python3 - "$rules" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
overrides = d["types"]["Microsoft.Xna.Framework.Graphics.EffectParameter"]["member_overrides"]
for key in ("SetValue(Single)", "SetValue(Int32)"):
    overrides[key].pop("distinguished_by", None)
    overrides[key].pop("tag", None)
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "two SetValue overloads stop saying how they differ"

echo "== 2. a tagged-argument rule that names no tag =="
python3 - "$rules" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
overrides = d["types"]["Microsoft.Xna.Framework.Graphics.EffectParameter"]["member_overrides"]
overrides["SetValue(Vector3)"].pop("tag", None)
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "a tagged-argument rule with no tag"

echo "== 3. two overloads answering to the same tag =="
python3 - "$rules" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
overrides = d["types"]["Microsoft.Xna.Framework.Graphics.EffectParameter"]["member_overrides"]
overrides["SetValue(Vector3)"]["tag"] = overrides["SetValue(Vector2)"]["tag"]
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "Vector3 and Vector2 claiming the same tag"

echo "== 4. a keyword-distinguished overload that lists a keyword the method has not =="
python3 - "$rules" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
overrides = d["types"]["Microsoft.Xna.Framework.Graphics.SpriteBatch"]["member_overrides"]
key = "Begin(SpriteSortMode,BlendState,SamplerState,DepthStencilState,RasterizerState,Effect)"
overrides[key]["keywords"] = ["sort-mode", "blend-state", "sampler-state",
                              "depth-stencil-state", "rasterizer-state", "shader"]
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "Begin claiming a :SHADER keyword it does not take"

echo "== 5. a contract whose member count does not match what gets measured =="
# Not an overload rule, but the same failure it protects against: two members
# sharing a signature key means one of them is never measured, and the count is
# the only thing that notices. The guard is a refusal to write the report at all
# rather than a diagnostic, so this checks the exit and the message.
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['selection']['member_count'] += 1; json.dump(d, open(sys.argv[2],'w'))" \
    "$here/reference/xna40-selected-contract.json" "$work/contract.json"
if python3 "$here/verify.py" --contract "$work/contract.json" \
        --output "$work/report.json" > "$work/out.txt" 2>&1; then
    echo "FAIL a wrong member count was accepted" >&2
    exit 1
fi
if ! grep -q "were measured" "$work/out.txt"; then
    echo "FAIL it refused, but not for the count:" >&2
    sed -n '1,10p' "$work/out.txt" >&2
    exit 1
fi
echo "  ok  a selection count that does not match the measurement -> refused"

echo "== 6. and the unmutated rules are green =="
python3 "$here/verify.py" --strict | grep -E "disagreement"

echo
echo "overload mutation self-test passed: the verifier goes red for a family that"
echo "declares nothing, for a tagged-argument rule with no tag, for two overloads"
echo "sharing one tag, and for a keyword set the real method does not have -- and"
echo "refuses to write a report whose member count does not add up."
