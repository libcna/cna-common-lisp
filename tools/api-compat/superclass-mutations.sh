#!/bin/sh
# Superclass mutation self-test.
#
# "Zero disagreement diagnostics" is only worth reading if the verifier can
# actually go red. This mutates the projection five ways and requires a
# wrong_superclass diagnostic each time, then requires a clean run afterwards.
#
# The five are the ones that were possible before the check was derived from the
# contract's own baseType, and the fourth is the one that actually happened: five
# types whose contract says baseType GraphicsResource were not GraphicsResources,
# and the scoreboard read zero.
#
#   tools/api-compat/superclass-mutations.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work="$root/build-probe/superclass-mutations"
rules="$here/mapping-rules.json"
surface="$root/docs/generated/public-surface.json"

mkdir -p "$work"
cp "$rules" "$work/rules.orig"
cp "$surface" "$work/surface.orig"
restore() { cp "$work/rules.orig" "$rules"; cp "$work/surface.orig" "$surface"; }
trap restore EXIT

# The verifier must not rewrite the surface underneath a mutation, so these run
# verify.py directly against the dumped surface rather than through verify.sh.
expect_red() {
    label=$1
    if python3 "$here/verify.py" --strict > "$work/out.txt" 2>&1; then
        echo "FAIL $label: the verifier stayed green" >&2
        exit 1
    fi
    if ! grep -q "wrong_superclass" "$work/out.txt"; then
        echo "FAIL $label: it went red, but not with wrong_superclass:" >&2
        sed -n '1,25p' "$work/out.txt" >&2
        exit 1
    fi
    echo "  ok  $label -> wrong_superclass"
    restore
}

echo "== 1. remove GraphicsResource from BlendState's precedence list =="
python3 - "$surface" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
for p in d["packages"]:
    for s in p["symbols"]:
        if s["name"] == "blend-state" and s["class"]:
            s["precedence"] = [x for x in s["precedence"]
                               if not x.endswith(":graphics-resource")]
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "BlendState loses GraphicsResource"

echo "== 2. replace a superclass with an unrelated class =="
python3 - "$surface" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
for p in d["packages"]:
    for s in p["symbols"]:
        if s["name"] == "texture-2d" and s["class"]:
            s["precedence"] = ["microsoft.xna.framework.graphics:texture-2d",
                               "microsoft.xna.framework.graphics:sprite-batch",
                               "common-lisp:standard-object", "common-lisp:t"]
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "Texture2D reparented onto an unrelated class"

echo "== 3. map a CLR subclass onto a root CLOS class with no exception =="
python3 - "$surface" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
for p in d["packages"]:
    for s in p["symbols"]:
        if s["name"] == "vertex-declaration" and s["class"]:
            s["precedence"] = ["microsoft.xna.framework.graphics:vertex-declaration",
                               "common-lisp:standard-object", "common-lisp:t"]
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "VertexDeclaration flattened to a root class"

echo "== 4. the mistake that actually happened: all four state objects reparented =="
python3 - "$surface" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
for p in d["packages"]:
    for s in p["symbols"]:
        if s["name"] in ("blend-state", "depth-stencil-state",
                         "rasterizer-state", "sampler-state") and s["class"]:
            s["precedence"] = ["microsoft.xna.framework.graphics:" + s["name"],
                               "microsoft.xna.framework.graphics:%state-object",
                               "common-lisp:standard-object", "common-lisp:t"]
json.dump(d, open(path, "w"), indent=2)
PY
expect_red "the four state objects off GraphicsResource"

echo "== 5. a stale expected_superclass naming a class nothing inherits =="
python3 - "$rules" <<'PY'
import json, sys, collections
path = sys.argv[1]
r = json.loads(open(path).read(), object_pairs_hook=collections.OrderedDict)
r["types"]["Microsoft.Xna.Framework.Graphics.SpriteBatch"]["expected_superclass"] = \
    "microsoft.xna.framework.graphics:no-such-class"
open(path, "w").write(json.dumps(r, indent=1) + "\n")
PY
expect_red "a stale expected_superclass rule"

echo "== 6. an exception with no substantial reason buys nothing =="
python3 - "$rules" <<'PY'
import json, sys, collections
path = sys.argv[1]
r = json.loads(open(path).read(), object_pairs_hook=collections.OrderedDict)
r["types"]["Microsoft.Xna.Framework.Graphics.BlendState"]["base_type_exception"] = \
    {"reason": "because"}
open(path, "w").write(json.dumps(r, indent=1) + "\n")
PY
expect_red "a base_type_exception with a token reason"

echo "== 7. a declared exception with a real reason is accepted, and only then =="
python3 - "$rules" "$surface" <<'PY'
import json, sys, collections
rules, surface = sys.argv[1], sys.argv[2]
r = json.loads(open(rules).read(), object_pairs_hook=collections.OrderedDict)
r["types"]["Microsoft.Xna.Framework.Graphics.BlendState"]["base_type_exception"] = {
    "reason": "A deliberate language-projection exception, written here only to "
              "prove the verifier accepts one when the reason is substantial. "
              "Nothing in this repository actually claims it."}
open(rules, "w").write(json.dumps(r, indent=1) + "\n")
d = json.load(open(surface))
for p in d["packages"]:
    for s in p["symbols"]:
        if s["name"] == "blend-state" and s["class"]:
            s["precedence"] = [x for x in s["precedence"]
                               if not x.endswith(":graphics-resource")]
json.dump(d, open(surface, "w"), indent=2)
PY
if python3 "$here/verify.py" --strict > "$work/out.txt" 2>&1; then
    echo "  ok  a substantiated exception is accepted"
else
    echo "FAIL a substantiated exception should have been accepted:" >&2
    sed -n '1,25p' "$work/out.txt" >&2
    exit 1
fi
restore

echo "== 8. and the unmutated projection is green =="
python3 "$here/verify.py" --strict > "$work/out.txt" 2>&1 || {
    echo "FAIL the restored projection is not green:" >&2
    sed -n '1,25p' "$work/out.txt" >&2
    exit 1
}
grep -E "disagreement" "$work/out.txt"

echo
echo "superclass mutation self-test passed: the verifier goes red for each of the"
echo "six mutations, accepts one substantiated exception, and is green otherwise."
