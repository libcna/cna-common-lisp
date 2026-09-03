# The native ABI boundary

CNA-Lisp talks to exactly one thing: the CNA C ABI, through CFFI, from a private
package no consumer can reach. This document says what is bound, how the binding
is generated, how it is verified, and what it refuses to bind.

## The manifest is the whole surface

`tools/native-abi/manifest.json` names every native route, struct, callback and
constant CNA-Lisp may use. Nothing outside it reaches the library.

The manifest deliberately **carries no C types**. Types are read from the
canonical CNA headers by `tools/native-abi/generate.py`, which then emits:

| Output | What it is |
| --- | --- |
| `src/internal/ffi/constants.generated.lisp` | every bound constant, and the keyword tables for `Keys` and `SurfaceFormat` |
| `src/internal/ffi/structs.generated.lisp` | one `defcstruct` per bound struct, every field pinned to an explicit offset |
| `src/internal/ffi/functions.generated.lisp` | one `defcfun` per bound route |
| `src/framework/predefined-colors.generated.lisp` | the 141 predefined XNA colours, from the ABI's own table |
| `tools/native-abi/probe.generated.c` | the compile-time prototype and layout gate |
| `tools/native-abi/valueprobe.generated.c` | the run-time by-value aggregate gate |
| `docs/generated/native-abi-manifest.json` | the resolved, fully typed manifest, with evidence |

A hand-copied signature cannot drift from the ABI it claims to describe, because
there are no hand-copied signatures. Regenerate with:

```sh
python3 tools/native-abi/generate.py \
    --headers  /path/to/cna/modules/c-api/include \
    --baseline /path/to/cna/tools/c-api/abi_baseline.json
```

Every generated file carries a "do not edit" header, and
`tests/structure/generated-files.lisp` fails when one is stale.

## The admitted ABI version set

The CNA 0.x C ABI is experimental. CNA-Lisp therefore admits an explicit **set**
of encoded versions -- not a range, not "any 0.x", not "this minor or newer":

| Version | Encoded | Evidence |
| --- | --- | --- |
| 0.21.0 | 5376 | `probe.generated.c` compiled against this version's canonical headers, `valueprobe.generated.c` run against a real library built from them |

`cna_get_abi_version` is the first route CNA-Lisp ever calls, before anything
else. A version outside the set is refused, and the refusal names the library
that was loaded, the version it reports, the whole admitted set, and how to
supply a qualified library.

A matching major number is not evidence: 0.7.0 and 0.21.0 share a major and do
not share a surface. A version enters the set only after the whole bound surface
has passed the compiler-backed gate against that version's headers.

## What the compiler proves

`tools/native-abi/verify.sh <cna-header-root>` compiles `probe.generated.c`
against the canonical headers with `-Wall -Wextra -Werror -Wpedantic`. In it:

* every bound struct's **size** and **alignment** is a `_Static_assert`;
* every bound field's **offset** and **size** is a `_Static_assert`;
* every bound constant's **value** is a `_Static_assert`;
* every bound route's **prototype** is a typed function-pointer initialisation,
  which will not compile if the declaration differs in any parameter or in the
  return type.

Nothing there is a claim in a document; each is a compile error if it is wrong.

Independently of the C compiler, `verify-struct-layouts` checks **CFFI's own**
view of every bound struct -- its computed size, alignment and field offsets --
against the layout the generator recorded. The two checks are separate on
purpose: one proves the recorded layout matches the headers, the other proves the
Lisp side matches the recorded layout.

`tests/native/abi-gate.lisp` runs the second check against the real library and
also asserts that the rejection path really rejects.

## Passing an aggregate by value

CFFI cannot pass a structure by value without `cffi-libffi`, and `cffi-libffi`
needs libffi headers and a C compiler **at load time**. A released CNA-Lisp must
need neither, so `cffi-libffi` is not a dependency. This is a measured limitation,
not an assumption: the first spike against a real CNA library failed with

```
Unable to call structures by value without cffi-libffi loaded.
```

and `tests/native/struct-passing.lisp` keeps the measurement current.

The CNA C ABI passes `CNA_StringView` by value in 294 routes and `CNA_Color` in
35, so "do not bind anything that takes a struct by value" would mean binding
almost nothing. Instead CNA-Lisp uses the System V AMD64 ABI's own rule:

> An aggregate of at most 16 bytes is passed in registers, one per *eightbyte*.
> An eightbyte whose fields are all floating-point is class SSE; otherwise it is
> class INTEGER. An aggregate larger than 16 bytes is class MEMORY and is passed
> on the stack.

CNA-Lisp binds a by-value aggregate parameter **only when every eightbyte is class
INTEGER and the aggregate is at most 16 bytes**, and then passes one scalar
argument per eightbyte. Those scalars occupy exactly the argument registers, in
exactly the order, that the aggregate itself would occupy. So:

| Aggregate | Size | Eightbyte classes | Bound as |
| --- | --- | --- | --- |
| `CNA_Color` | 4 | INTEGER | `:uint32` |
| `CNA_StringView` | 16 | INTEGER INTEGER | `:pointer :uint64` |

The generator computes the classification from the field types it read out of the
headers and the offsets it read out of the ABI baseline. It **refuses** anything
else -- an SSE eightbyte, or a MEMORY-class aggregate -- and the route that needed
it is left unbound.

This flattening is not taken on trust. `valueprobe.generated.c` defines, for each
admitted aggregate, a function whose prototype is the real one -- it takes the
aggregate *by value* -- and copies the bytes that arrived back out.
`tests/native/struct-passing.lisp` calls it through the flattened CFFI shape and
compares byte for byte, including with integer arguments before and after the
aggregate so that register and stack assignment is exercised rather than only the
first slot. If the flattening were wrong on some platform, that test fails there.

### Blocked routes

A route that cannot be bound is recorded in the manifest's `blocked_routes`, and
the generator **proves** the block rather than accepting the claim: it resolves
the route's real parameter types and requires the flattening to actually fail. A
"blocked" route that could in fact be bound is a generator error.

| Route | Why |
| --- | --- |
| `cna_graphics_device_set_viewport` | takes `CNA_Viewport` (24 bytes) by value: MEMORY class |

`Microsoft.Xna.Framework.Graphics.GraphicsDevice.Viewport`'s setter is therefore
absent, and is reported as externally blocked with this reason rather than as
unfinished work. The getter is bound and present.

## Strings and buffers

The ABI carries text as an explicit pointer-plus-length view of UTF-8 bytes. It
never uses a NUL terminator and its byte counts never include one.

* Text going in is encoded with Babel, exactly, and passed as a borrowed view
  that lives for the duration of the call -- which is exactly the lifetime the
  contract asks for. An embedded NUL is refused by CNA, and CNA-Lisp reports that
  as `cna-encoding-error`.
* Text coming out uses the ABI's count-then-copy idiom: ask for the byte count,
  allocate exactly that, copy. Insufficient capacity is refused **without a
  partial write**, so nothing is ever half-copied.

## The native library

There is one resolver, in `src/internal/native-library.lisp`, and it is
deliberately unhelpful. It loads the library `CNA_NATIVE_LIBRARY` names and
searches nowhere else: no sibling checkout, no build directory, no loader path,
no bundled copy. The path must be absolute and must name an existing regular
file, and every diagnostic names the exact path that was attempted.

CNA native binaries are not packaged inside CNA-Lisp.

## What a consumer needs

To *use* a released CNA-Lisp: SBCL, the ASDF systems it depends on, and a
qualified CNA C ABI shared library. **Not** the CNA headers, and **not** a C
compiler.

The header-based generation and the compiler-backed gate are maintenance and
qualification activities. They run in this repository and in CI, against a CNA
source checkout, and never in a consumer's image.

## What is deliberately *not* bound

CNA has native routes for most of the projected value-type arithmetic --
`cna_vector3_normalize`, `cna_matrix_invert` and their neighbours. None of them
is bound, and that is a decision rather than an omission.

Two reasons, and the second is the one that matters:

1. A foreign call per vector addition would be slower than the arithmetic.
2. It would make the binding's arithmetic **CNA's** arithmetic rather than XNA's,
   and would leave nothing to cross-check. A binding that computes a dot product
   by asking CNA cannot then be evidence that CNA computes it the way XNA does.

So the value types are pure Lisp, written from the pinned XNA IL, and CNA's
routes remain available as an independent second opinion. See
`tools/api-compat/reference/XNA_IL_PROVENANCE.md`.
