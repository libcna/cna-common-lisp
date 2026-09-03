# CNA-Lisp — plan and current measured status

This file is normative. It records the architecture CNA-Lisp is built to, the
profile it selects, and what is *measured* to be true right now. Every number in
it is either generated or cross-checked against a generated report; where a
report does not exist yet, the entry says so rather than guessing.

`NEXT.md` is the resumable handoff. This file is the state of the design.

## 1. The product decision

CNA-Lisp is **CNA for Common Lisp**:

* ANSI Common Lisp as the language family;
* CLOS as the public object system;
* SBCL as the first and reference-qualified implementation;
* Linux x86-64 as the first qualified platform;
* CFFI as the *private* foreign-function layer;
* ASDF as the system, build and test definition mechanism.

No other Lisp dialect is implemented here. The repository is
`openeggbert/cna-common-lisp`; the ASDF system is `cna-common-lisp`; the product
is called CNA-Lisp.

**The CNA C ABI is an internal implementation detail.** The dependency direction
is strictly one way:

```
Public Common Lisp / CLOS API
  -> private CNA-Lisp runtime and mapping layer
  -> private CFFI declarations
  -> CNA C ABI
  -> the canonical CNA C++ implementation
```

CNA-Lisp never calls the CNA C++ ABI and never depends on another language
binding at runtime.

## 2. Authorities

1. The current CNA source checkout: `modules/c-api/include/CNA/C/`,
   `docs/c-api/`, `tools/c-api/abi_baseline.json`,
   `modules/c-api/examples/c/hello_cna.c`, `modules/c-api/tests/pure_c/`.
2. The selected Microsoft XNA Framework 4.0 Windows runtime public contract.
3. Hash-pinned Microsoft XNA IL or metadata, where a mature binding has already
   established it.
4. FNA and MonoGame as secondary comparison only.
5. Other CNA language bindings as architecture and tooling examples, never as
   behavioural authorities.

**CNA is never the oracle for XNA behaviour.** A runtime cannot prove its own
compatibility. No Microsoft binary is stored here.

## 3. Layout

```
cna-common-lisp/
├── cna-common-lisp.asd          two systems: the library and its tests
├── src/
│   ├── packages.lisp            the whole public surface, in three packages
│   ├── capabilities.lisp        declared extensions and deliberate absences
│   ├── internal/
│   │   ├── ffi/                 the only code that knows the C ABI exists
│   │   │   ├── package.lisp     every private package
│   │   │   ├── types.lisp
│   │   │   ├── constants.generated.lisp
│   │   │   ├── structs.generated.lisp
│   │   │   ├── callbacks.lisp   ten top-level CFFI callbacks, one dispatcher
│   │   │   └── functions.generated.lisp
│   │   ├── results.lisp         result code -> condition, once, here
│   │   ├── utf8.lisp            exact UTF-8, count-then-copy
│   │   ├── native-library.lisp  one resolver, CNA_NATIVE_LIBRARY only
│   │   ├── abi-gate.lisp        the admitted version set
│   │   ├── threads.lisp         all thread identity, behind bordeaux-threads
│   │   ├── ownership.lisp       native-object, generations, parent/child
│   │   └── callback-registry.lisp  token -> object, condition containment
│   ├── framework/               Microsoft.Xna.Framework
│   ├── graphics/                Microsoft.Xna.Framework.Graphics
│   ├── input/                   Microsoft.Xna.Framework.Input
│   └── runtime/                 Game and GraphicsDeviceManager
├── tests/{unit,structure,behavior,native}/
├── tools/{native-abi,api-compat,qualification}/
├── docs/, docs/generated/
├── README.md, plan.md, NEXT.md
```

## 4. Architecture decisions, and the evidence behind them

### 4.1 The manifest generates the foreign layer

`tools/native-abi/manifest.json` names the bound surface and carries **no C
types**. `tools/native-abi/generate.py` reads the types out of the canonical CNA
headers and emits the CFFI declarations, the C probes and the resolved manifest.
A hand-copied signature cannot drift, because there are none.

### 4.2 The ABI version set is explicit

Admitted: **0.21.0 only** (encoded 5376). Not a range, not "any 0.x", not "this
minor or newer". A version enters the set after the whole bound surface has
passed the compiler gate against that version's headers.

### 4.3 By-value aggregates are flattened, and the flattening is proved

Measured, not assumed: CFFI answers *"Unable to call structures by value without
cffi-libffi loaded"*, and `cffi-libffi` needs libffi headers and a C compiler at
load time, which a released CNA-Lisp must not.

So a by-value aggregate is bound only when the System V AMD64 ABI classifies
every eightbyte INTEGER and the size is at most 16 bytes, and is passed as one
scalar per eightbyte. `CNA_Color` becomes `:uint32`; `CNA_StringView` becomes
`:pointer :uint64`. A MEMORY-class or SSE-class aggregate is **refused by the
generator**, and the route is recorded as blocked with the generator's own proof.

`tools/native-abi/valueprobe.generated.c` defines functions with the real
by-value prototypes; the run-time test calls them through the flattened shape and
compares byte for byte.

### 4.4 The graphics device stores no handle

CNA lends the device only inside a lifecycle callback and only for its duration.
`graphics-device` is therefore a parent-owned facade that resolves a fresh
borrowed handle per operation, and refuses with `cna-scope-error` outside a
callback.

### 4.5 No finalizer destroys anything

Every CNA handle is thread-affine; a finalizer runs on the collector's thread. A
finalizer that called CNA would be calling it from the wrong thread by
construction. Disposal is `dispose`, and it is deterministic.

### 4.6 Conditions, never result codes

One place translates a result code, and the code is not a public reader. A
callback's condition is preserved as an object and re-signalled on the Lisp side
after control leaves C.

## 5. Selected profile — Foundation 1

The first qualified foundation is the dependency closure of a real textured
sprite game:

`Game`, `GameTime`, `GraphicsDeviceManager`, `GraphicsDevice`, `Viewport`,
`Color`, `Point`, `Rectangle`, `Vector2`, `Texture2D`, `Texture`, `SpriteBatch`,
`SpriteSortMode`, `SpriteEffects`, `SurfaceFormat`, `PlayerIndex`, `Keyboard`,
`KeyboardState`, `KeyState`, `Keys`, and the condition hierarchy.

`GameWindow` is not implemented as a type; only the window title is reachable,
on `game`, and that is recorded as a deliberate absence.

## 6. Measured status

Generated reports are the authority:

| Report | What it measures |
| --- | --- |
| `docs/generated/native-abi-manifest.json` | the bound native surface, with evidence |
| `docs/generated/api-compat-report.json` | the structural projection: complete / partial / missing |
| `docs/generated/behavior-corpus.json` | behaviour observations and their origin |

The counts in `README.md`, this file and `NEXT.md` are cross-checked against
those reports by `tools/qualification/verify-numbers.py`.

### Native ABI, as generated

| | |
| --- | --- |
| Bound functions | 68 |
| Bound structs | 19 |
| Bound struct fields | 110 |
| Bound constants | 237 |
| Bound callback typedefs | 2 |
| By-value aggregates admitted | 2 (`CNA_Color`, `CNA_StringView`) |
| Routes proved blocked | 1 (`cna_graphics_device_set_viewport`) |

### Qualified against

| | |
| --- | --- |
| SBCL | 2.5.2 (Debian), Linux x86-64 |
| CNA C ABI | 0.21.0, encoded 5376 |
| CNA build | `SDL3` platform, `SDL3` audio, `HEADLESS` renderer |
| Renderer reported by the device | `HEADLESS` |
| Viewport reported by the device | 800x480 |

HEADLESS proves lifecycle and command submission. It proves nothing about
pixels, and no visible-rendering claim is made anywhere in this repository.

## 7. Rules this project keeps

* Strict verification may be red while real surface is missing. It must never be
  green because an allowlist hid something.
* A member that is blocked gets a precise evidence document; it does not get a
  fake implementation.
* Every public symbol that is not a mapped XNA member is a declared extension
  with a reason.
* No number in prose that is not generated or cross-checked.
* HEADLESS execution is never described as visible rendering.
