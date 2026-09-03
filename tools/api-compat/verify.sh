#!/bin/sh
# Structural compatibility gate: dump the live public surface, then measure it
# against the pinned XNA contract.
#
#   tools/api-compat/verify.sh [--strict]
#
# --strict exits non-zero unless every disagreement category is zero. Missing
# surface does not fail it: strict verification is allowed to be red for real
# absence, and must never be green because something was hidden.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}

"$sbcl" --script "$here/dump-surface.lisp"
python3 "$here/verify.py" "$@"
python3 "$root/tools/qualification/verify-numbers.py"
