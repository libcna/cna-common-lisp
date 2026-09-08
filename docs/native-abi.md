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
| `tools/native-abi/shim.generated.c` | the optional private shim, one wrapper per proved-unbindable route |
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
| 0.21.0 | 5376 | `probe.generated.c` compiled against this version's canonical headers, `valueprobe.generated.c` run against a real library built from them, and the whole gate set re-run against it at every closure since |
| 0.22.0 | 5632 | the same, against a library built from an exact published source pair -- CNA `fb62662c9`, sharp-runtime `bfc826e1` -- and `generate.py --check` proving the generated layer identical but for the four version constants |
| 0.23.0 | 5888 | the same, against CNA `5c8840657` with the same sharp-runtime `bfc826e1`, both `HEADLESS` and `SOFTWARE`; the whole gate set, the four audio lanes, the nine pixel proofs and the isolated consumer |

**This table listed 0.21.0 alone until 2026-09-06**, four commits after 0.22.0 was
admitted and its evidence written into `docs/qualification.md`. The set is a set
in the manifest, in the gate and in the tests; it was a set of one only here.

`cna_get_abi_version` is the first route CNA-Lisp ever calls, before anything
else. A version outside the set is refused, and the refusal names the library
that was loaded, the version it reports, the whole admitted set, and how to
supply a qualified library.

A matching major number is not evidence: 0.7.0 and 0.21.0 share a major and do
not share a surface. A version enters the set only after the whole bound surface
has passed the compiler-backed gate against that version's headers.

**What actually differs between 0.21.0 and 0.22.0**, measured by diffing
the header trees rather than inferred from the version bump: six files. `abi.h`'s
version constant; six new renderer identity constants in `graphics.h`; one added
route in `net_sessions.h`; documentation corrections in `devices.h` and
`engine_layer.h`; and one *behavioural* documentation change in `runtime.h`, where
`cna_launch_parameters_add` goes from "overwrites an existing entry" to "keeps its
first value". **None of the routes this binding binds differs**, which is why
`generate.py --check` passes against both from one set of generated files, and the
one behavioural change is to a route the manifest does not name.

**And what differs between 0.22.0 and 0.23.0**, measured the same way: three
files, and the delta is the smallest yet. `abi.h`'s version constant; one added
route, `cna_decal_pass_is_supported` in `engine_layer.h`, which this binding does
not bind and which closes a gap CNA had recorded against itself; and prose in
`models.h` documenting which model formats `cna_content_manager_load_model`
opens. No struct, no field, no constant but the four version ones, no callback,
no ownership annotation and no by-value aggregate changed, and nothing was
removed. `generate.py` run against 0.23.0's headers produces a byte-identical
`functions.generated.lisp`, `structs.generated.lisp`,
`predefined-colors.generated.lisp`, `valueprobe.generated.c` and
`shim.generated.c`, with the same 572 functions, 73 structs, 511 constants and 11
callbacks.

That is a fact about these three versions and not a rule. The next version to be
proposed gets the same diff and the same gate set, because "the delta looked
small" is not evidence -- and the 0.22 -> 0.23 delta looking small is exactly why
it was diffed rather than assumed.

### A closure's route matrix names every version

A new closure has to state, per member, which route it takes **in each admitted
version** and whether the semantics agree -- not which route it takes in the
newest one. `DynamicSoundEffectInstance` is the worked example, and its matrix is
one column wide because `modules/c-api/include/CNA/C/audio.h` is byte for byte
identical in 0.21.0, 0.22.0 and 0.23.0:

| XNA member | CNA 0.21.0 route | CNA 0.22.0 route | Semantics | Strategy |
| --- | --- | --- | --- | --- |
| `new(Int32, AudioChannels)` | `cna_dynamic_sound_effect_instance_create` | same | equal | XNA's two bounds first, in the IL's order, then the route; owner is the game |
| `SubmitBuffer(Byte[])` | `cna_dynamic_sound_effect_instance_submit_buffer` | same | equal | offset 0, count = length, after XNA's own checks |
| `SubmitBuffer(Byte[], Int32, Int32)` | the same route | same | equal | XNA's five checks in its order, then the route |
| `GetSampleDuration(Int32)` | `..._get_sample_duration_ticks` | same | **different** | computed from `AudioFormat.DurationFromSize`; the route quantises differently and is pinned by a test instead |
| `GetSampleSizeInBytes(TimeSpan)` | `..._get_sample_size_in_bytes` | same | **different** | the same treatment, from `SizeFromDuration` |
| `Play()` | `cna_sound_effect_instance_play` | same | equal | inherited, because the create route says every `cna_sound_effect_instance_*` route accepts the handle |
| `IsLooped` get/set | none | none | n/a | pure managed: XNA's getter answers a constant and its setter refuses a true value |
| `PendingBufferCount` | `..._get_pending_buffer_count` | same | equal | direct |
| `BufferNeeded` +=/-= | `..._subscribe_buffer_needed`, `cna_audio_unsubscribe_ext` | same | equal | the existing event machinery, with its own callback and its own unsubscribe route |
| `Dispose(Boolean)` | n/a | n/a | n/a | not applicable: no finalizer touches a native resource here |

Destruction is not in that table because there is no dynamic destroy route in
either version, and that is deliberate rather than missing: the create route
documents that `cna_sound_effect_instance_destroy` accepts the handle.

### An identical header is not identical behaviour

**"One column wide because the header is byte for byte identical" is a statement
about surface, and the Storage closure measured a case where it is not a
statement about semantics.** `CNA/C/storage.h` has the same SHA-256 in 0.21.0,
0.22.0 and 0.23.0 -- same forty-nine routes, same doc comments, same result codes
-- and the three libraries do not agree about what one of them does. Given an
application name it cannot build a directory from:

| ABI | `cna_storage_set_app_name_ext` | the first `cna_storage_get_root_size_ext` after it |
| --- | --- | --- |
| 0.21.0 | `CNA_RESULT_SUCCESS` | `CNA_RESULT_INVALID_STATE` |
| 0.22.0 | `CNA_RESULT_INVALID_STATE` | `SUCCESS` with a size of zero |
| 0.23.0 | `CNA_RESULT_INVALID_STATE` | `SUCCESS` with a size of zero |

Where the refusal arrives moved between 0.21.0 and 0.22.0, and the two that
refuse do not restore the root they had. Nothing in the header says which, and
nothing could: the header documents the result codes a route *may* answer, not
which one a given build *will*.

So a route matrix's "same" column means **the same route with the same
signature**, and a closure still has to run its lanes against every admitted
library. Hashing the header is what makes the *surface* claim cheap; it is not
evidence for the behaviour claim, and this document said it was.

`SET-STORAGE-APPLICATION-NAME` is what a projection does about it: it reads the
root back after the route accepts, and restores the last accepted name when
either half refuses, so all three ABIs behave alike above the boundary.
`docs/limitations.md` has the whole measurement.

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

CNA-Lisp binds a by-value aggregate parameter **only when it is at most 16
bytes**, which is what makes the ABI pass it in registers, and then passes one
scalar argument per eightbyte, **of the eightbyte's own class**: an integer of
that width for INTEGER, a C `double` for a whole SSE eightbyte, and a C `float`
for a trailing four-byte SSE one -- which is the register half the ABI gives a
lone `float` argument. An eightbyte that is exactly one pointer field is bound as
`:pointer`, which occupies the same integer register either way and saves turning
every pointer into an address at the call site.

The integer and SSE argument sequences are assigned independently, so a flattened
mixed aggregate still lands every piece where the aggregate itself would.

| Aggregate | Size | Eightbyte classes | Bound as |
| --- | --- | --- | --- |
| `CNA_Color` | 4 | INTEGER | `:uint32` |
| `CNA_Rectangle` | 16 | INTEGER INTEGER | `:uint64 :uint64` |
| `CNA_StringView` | 16 | INTEGER INTEGER | `:pointer :uint64` |
| `CNA_Vector2` | 8 | SSE | `:double` |
| `CNA_Vector3` | 12 | SSE SSE | `:double :float` |
| `CNA_Vector4` | 16 | SSE SSE | `:double :double` |

The generator computes the classification from the field types it read out of the
headers and the offsets it read out of the ABI baseline. It **refuses** a
MEMORY-class aggregate -- one larger than 16 bytes -- because that travels on the
stack and no sequence of scalar arguments occupies the same place; the route that
needed it is shimmed or left unbound.

The SSE half of this rule is newer than the rest. Until the effect surface needed
it the generator refused every non-INTEGER eightbyte, which was one rule too
broad: it would have cost `BasicEffect` every colour it has, since a `CNA_Vector3`
by value is how CNA carries all of them.

This flattening is not taken on trust. `valueprobe.generated.c` defines, for each
admitted aggregate, a function whose prototype is the real one -- it takes the
aggregate *by value* -- and copies the bytes that arrived back out.
`tests/native/struct-passing.lisp` calls it through the flattened CFFI shape and
compares byte for byte, including with integer arguments before and after the
aggregate so that register and stack assignment is exercised rather than only the
first slot. If the flattening were wrong on some platform, that test fails there.

### Routes the generator refuses, and the four shims

A route that cannot be bound is recorded in the manifest's `shimmed_routes`, and
the generator **proves** the refusal rather than accepting the claim: it resolves
the route's real parameter types and requires the flattening to actually fail. A
route claimed unbindable that could in fact be bound is a generator error.

| Route | Why |
| --- | --- |
| `cna_graphics_device_set_viewport` | takes `CNA_Viewport` (24 bytes) by value: MEMORY class |
| `cna_effect_matrices_set_world` | takes `CNA_Matrix` (64 bytes) by value: MEMORY class |
| `cna_effect_matrices_set_view` | the same |
| `cna_effect_matrices_set_projection` | the same |

Every corresponding *getter* takes a pointer and needs nothing. For each refused
route the generator emits the smallest thing that gets past it, in
`tools/native-abi/shim.generated.c`:

```c
CNA_Result cna_lisp_shim_cna_graphics_device_set_viewport(
    void (*target)(void), CNA_Handle graphics_device, const CNA_Viewport *viewport)
{
    typedef CNA_Result (*target_t)(CNA_Handle, CNA_Viewport);
    return ((target_t)target)(graphics_device, *viewport);
}
```

Four properties make this a shim rather than a second implementation:

* it takes the aggregate **by pointer** and the real route **by function
  pointer**, and does nothing but the one ABI transition;
* it is **never linked against CNA**, so it cannot drift from the library it
  forwards to — the caller supplies the target, which CNA-Lisp resolves from the
  library it already loaded;
* it holds no state and makes no decision;
* it is **not the public API** and is not reachable from one: only
  `(setf viewport)` and `BasicEffect`'s `World`, `View` and `Projection` setters
  use it.

It is **optional**. A released CNA-Lisp must load with no C toolchain, so the
shim is not shipped prebuilt. `CNA_LISP_SHIM` names a build of it;
`tools/native-abi/verify.sh` produces one; and without it each of those four
setters signals a `cna-not-supported-error` that names the variable, the command
and the reason. Nothing else in the binding depends on it, and the suite asserts
both outcomes -- `tests/native/graphics.lisp` for the viewport and
`tests/native/effects.lisp` for the matrices -- the setter really setting a value
when the shim is present, and the refusal naming all three things when it is not.
The whole suite is run twice in CI, once with the shim and once without, and
`tools/qualification/shim-policy.sh` asserts the stronger claim the per-type
tests cannot: that the four are **one class**, taking the same branch as each
other on every admitted ABI. A run in which they disagree is a failure, because
that would mean the shim answered for some routes and not others.

**All four members are reported `partial` for this reason.** A released CNA-Lisp
does not ship the shim, so an ordinary installation cannot reach any of the four
setters, and `docs/compatibility.md` defines `complete` as reachable in every
supported installation. Three of them were reported `complete` until 2026-09-07
while the fourth was `partial` on the identical blocker; that contradiction is
what the rule settles. Their frontier category is `PACKAGING_ABI_BRIDGE_LIMIT`:
what must change to close them is packaging -- ship the shim prebuilt, take
`cffi-libffi` as a load-time dependency, or get a pointer-taking variant into a
future CNA ABI -- and not anything about the public API.

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

## The floating-point environment at the boundary

**C libraries assume the IEEE traps are masked. SBCL does not mask them.** A C
program begins with every IEEE exception masked — that is the C ecosystem's
default — so C code raises `invalid` and `divide-by-zero` freely and reads the
answers as NaN and infinity. SBCL instead *enables* `:invalid`,
`:divide-by-zero` and `:overflow`, and an enabled trap raised inside a foreign
call arrives as a Lisp condition signalled from a frame containing no Lisp
arithmetic at all.

Measured 2026-09-08 on SBCL 2.5.2, with CNA built for the `OPENGL33` (EasyGL)
renderer on Mesa llvmpipe:

| question | answer |
| --- | --- |
| Where | `cna_graphics_device_create`, reached by `GraphicsAdapter.Adapters` in a process with no device |
| What | `FLOATING-POINT-INVALID-OPERATION`, from `SIGFPE-HANDLER`, with no Lisp operation or operands |
| Is it a CNA or Mesa defect | **No.** The same sequence in a plain C program runs to completion and answers one adapter. The same C program with `feenableexcept(FE_INVALID)` dies with `SIGFPE` at the same call — `tools/qualification/foreign-fp-probe.c` runs both halves |
| Which traps | `:invalid` **and** `:divide-by-zero`. Masking either alone still fails — with the other one's condition. Adding `:overflow` changes nothing |
| How wide | Narrow. With only device construction masked, a whole Texture3D round trip runs with the caller's traps live and round-trips byte for byte. The renderer raises while it builds a context, not while it moves texels |

### What the binding does

`WITH-FOREIGN-FLOAT-ENVIRONMENT`, in `src/internal/float-semantics.lisp`, masks
exactly those two traps for the dynamic extent of one foreign call and then
restores the caller's **complete** environment: trap enables, rounding mode, and
the accrued exception flags the foreign code raised while they were masked.
That last part is not free — SBCL's own `WITH-FLOAT-TRAPS-MASKED` deliberately
lets the body's accrued flags survive — so the binding puts them back itself.
Measured: entering with `accrued=(:INEXACT)` and returning with
`accrued=(:INEXACT)`, where the unrestored version returns
`(:INEXACT :INVALID :DIVIDE-BY-ZERO)`.

It is applied where a renderer context is built or rebuilt, and nowhere else:
`cna_game_create`, `cna_graphics_device_create` (both the caller-owned
constructor and the transient enumeration device), `cna_graphics_device_reset`
and its parameterised form, `GraphicsDeviceManager.ApplyChanges` and
`ToggleFullScreen`, and the three game-loop routes through `CALL-NATIVE-FRAME`.

**Not on every route, and that is a measurement.** The boundary costs about
300 ns, against about 8 ns for the cheapest bare `defcfun` — some 39× — because
restoring the x87 control word and `MXCSR` flushes the floating-point pipeline.
On a lifecycle route that runs once, 300 ns is nothing. On a getter in a
`SpriteBatch` loop it would be a tax on every sprite, and the routes in that
loop were measured not to need it.

### Callbacks get the caller's environment back

CNA calls Lisp back from inside those calls, and a callback body would otherwise
inherit the mask. Measured, before the fix: with an outer mask, every lifecycle
method saw `traps=(:OVERFLOW)` — the user's `:invalid` and `:divide-by-zero`
silently gone inside their own `Update` and `Draw`.

So the boundary has two directions. `WITH-CALLER-FLOAT-ENVIRONMENT` restores the
Lisp caller's environment for the duration of a callback and puts the foreign
one back on the way out, and it is installed in `CALL-WITH-CALLBACK-SCOPE` and
`CALL-WITH-EVENT-DISPATCH` — both callback paths. A floating-point condition
raised by callback code is contained and re-signalled by the existing machinery,
exactly like any other serious condition: it is never unwound through C.

### What this does not do

It does not change the process's floating-point modes globally, and **you should
not either**. XNA arithmetic has its own, separate reason to mask traps —
`WITH-BINARY32-SEMANTICS`, because the CLR's rules are IEEE 754's *default*
rules where an overflow answers an infinity — and that is a projection decision
about `MathHelper`, `Vector` and `Matrix`, not a workaround for a C library. The
two are independent and neither is allowed to widen into the other.

`SB-INT:WITH-FLOAT-TRAPS-MASKED` and `SB-INT:SET-FLOATING-POINT-MODES` are SBCL
internals, and the native host is qualified as SBCL on Linux x86-64 anyway. They
are confined to `src/internal/float-semantics.lisp`; nothing in the public XNA
projection exposes a trap keyword or an SBCL floating-point mode.

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
