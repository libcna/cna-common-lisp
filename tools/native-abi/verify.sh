#!/bin/sh
# Compiler-backed CNA ABI verification for CNA-Lisp.
#
# Compiles the generated probe against the canonical CNA headers. Every bound
# struct size, alignment, field offset, field size, constant value and function
# prototype is a _Static_assert or a typed function-pointer initialisation, so a
# mismatch is a compile error rather than a claim in a document.
#
# It also builds the by-value probe shared object the run-time struct-passing
# test loads. That object is a test fixture: it never ships and CNA-Lisp never
# links against it.
#
#   tools/native-abi/verify.sh <cna-header-root> [out-dir]
#
# <cna-header-root> is the directory containing CNA/C/cna.h.
set -eu

headers=${1:?usage: verify.sh <cna-header-root> [out-dir]}
out=${2:-build-probe}

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
cc=${CC:-cc}

mkdir -p "$out"

echo "== compiling prototype and layout probe (${cc}) =="
$cc -std=c11 -Wall -Wextra -Werror -Wpedantic -c \
    -I "$headers" -DCNA_C_API_STATIC \
    -o "$out/cna-lisp-probe.o" "$here/probe.generated.c"
echo "   ok: $out/cna-lisp-probe.o"

echo "== building the by-value aggregate probe =="
$cc -std=c11 -Wall -Wextra -Werror -Wpedantic -fPIC -shared \
    -I "$headers" -DCNA_C_API_STATIC \
    -o "$out/libcna-lisp-valueprobe.so" "$here/valueprobe.generated.c"
echo "   ok: $out/libcna-lisp-valueprobe.so"

echo "== regeneration check =="
python3 "$here/generate.py" --check \
    --headers "$headers" \
    --baseline "${CNA_ABI_BASELINE:-$headers/../../../tools/c-api/abi_baseline.json}"

echo "ABI verification passed."
