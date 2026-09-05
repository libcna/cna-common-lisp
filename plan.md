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

### 4.3 Overloads are refused, not merely mapped

A `&key` lambda list accepts every keyword combination unless something refuses.
So the mapping rules carry, per overload, the exact keyword set that expresses
it; the verifier checks each against the real method lambda lists; and the
implementation refuses the combinations XNA does not have. `SpriteBatch.Draw` is
the worked example, with all seven overloads and six refused shapes.

A mapping rule keyed on a signature no member produces is a diagnostic in its own
right, because such a rule is silently ignored and the default naming rule
applies instead.

### 4.4 By-value aggregates are flattened, and the flattening is proved

Measured, not assumed: CFFI answers *"Unable to call structures by value without
cffi-libffi loaded"*, and `cffi-libffi` needs libffi headers and a C compiler at
load time, which a released CNA-Lisp must not.

So a by-value aggregate is bound only when it is at most 16 bytes, which is what
makes the ABI pass it in registers, and is passed as one scalar per eightbyte, of
the eightbyte's own class: an integer for INTEGER, a double -- or a float for a
trailing four-byte one -- for SSE. `CNA_Color` becomes `:uint32`; `CNA_StringView`
becomes `:pointer :uint64`; `CNA_Vector3` becomes `:double :float`. A
MEMORY-class aggregate, larger than 16 bytes, travels on the stack and no
sequence of scalar arguments occupies the same place, so it is **refused by the
generator** and the route is either shimmed or recorded as blocked with the
generator's own proof.

`tools/native-abi/valueprobe.generated.c` defines functions with the real
by-value prototypes; the run-time test calls them through the flattened shape and
compares byte for byte.

Four routes resist even that: `cna_graphics_device_set_viewport` takes a 24-byte
aggregate and the three `cna_effect_matrices_set_*` routes take a 64-byte one,
which the ABI passes in memory. For those the generator emits a tiny private
shim -- a wrapper that takes the aggregate by pointer and the real
route by function pointer, links against nothing, and does only the ABI
transition. It is optional and not shipped prebuilt, so a release still loads
with no C toolchain; `CNA_LISP_SHIM` names a build of it and those setters refuse
with an actionable condition when it is absent. Every corresponding *getter*
takes a pointer and needs nothing.

### 4.5 The graphics device stores no handle

CNA lends the device only inside a lifecycle callback and only for its duration.
`graphics-device` is therefore a parent-owned facade that resolves a fresh
borrowed handle per operation, and refuses with `cna-scope-error` outside a
callback.

### 4.6 No finalizer destroys anything

Every CNA handle is thread-affine; a finalizer runs on the collector's thread. A
finalizer that called CNA would be calling it from the wrong thread by
construction. Disposal is `dispose`, and it is deterministic.

### 4.7 Conditions, never result codes

One place translates a result code, and the code is not a public reader. A
callback's condition is preserved as an object and re-signalled on the Lisp side
after control leaves C.

## 5. Selected profile — Foundation 1 and the managed closures

The first qualified foundation is the dependency closure of a real textured
sprite game:

`Game`, `GameTime`, `GraphicsDeviceManager`, `GraphicsDevice`, `Viewport`,
`Color`, `Point`, `Rectangle`, `Vector2`, `Texture2D`, `Texture`, `SpriteBatch`,
`SpriteSortMode`, `SpriteEffects`, `SurfaceFormat`, `PlayerIndex`, `Keyboard`,
`KeyboardState`, `KeyState`, `Keys`, and the condition hierarchy.

The selection then grows one **dependency-complete closure** at a time, in the
order `NEXT.md` records, and never by a member here and a member there. A closure
is added only when every member of it can be finished, tested and measured
together, because a half-implemented family reports its own cross-product members
as missing anyway and hides which absences are real.

**The list below is a chronological record of the closures as they landed, not a
statement of current status.** Each entry says what was true when it was written
-- "the fourth stock effect is absent", "the rasterizer lane gained its third
proof" -- and later closures have answered several of those. The current status
is the generated scoreboard in section 6 and the per-type table in
`docs/compatibility.md`; nothing here may be read as a live constraint. Where an
entry's claim has since been overtaken, the entry says so inline rather than
being rewritten, because the order these were added in is the thing this list is
for.

* the 3D transform types -- `Vector3`, `Vector4`, `Quaternion`, `Matrix`,
  `Plane`, `MathHelper`;
* the bounding volumes -- `Ray`, `BoundingBox`, `BoundingSphere`,
  `BoundingFrustum`, `ContainmentType`, `PlaneIntersectionType`;
* the `Curve` family -- `Curve`, `CurveKey`, `CurveKeyCollection`,
  `CurveContinuity`, `CurveLoopType`, `CurveTangent`;
* the seventeen `Graphics.PackedVector` types, in their own package;
* the rest of `Microsoft.Xna.Framework.Input`: `Mouse`, the `GamePad` family and
  the `Input.Touch` namespace, each over CNA's own routes;
* the graphics state objects -- `BlendState`, `DepthStencilState`,
  `RasterizerState`, `SamplerState` and their nine enumerations -- with
  `GraphicsDevice`'s state surface, its four indexed state and texture
  collections, and `SpriteBatch.Begin`'s state-bearing overloads. Their values
  come from the pinned `Microsoft.Xna.Framework.Graphics` assembly; CNA's own
  presets are cross-checked against them and disagree on two fields, which
  `docs/limitations.md` records as an upstream defect;
* the vertex declaration types -- `VertexElement`, `VertexDeclaration`,
  `IVertexType` and the four standard vertex value types -- computed from the
  pinned assembly and cross-checked against CNA's own built-in declarations;
* the vertex and index buffers, their dynamic subclasses, `VertexBufferBinding`,
  the device's stream and index state, and the four primitive draw calls;
* the effect closure -- `Effect`, its techniques, passes, parameters, annotations
  and their four collections, the three `IEffect*` contracts as generic
  functions, `DirectionalLight` and `BasicEffect` -- which is what makes a
  primitive draw legal, and with it `SpriteBatch.Begin`'s last two overloads.
  With it the rasterizer lane gained its third proof: a triangle drawn through a
  `BasicEffect` pass covering exactly the pixels its geometry covers;
* the text closure -- `SpriteFont` and the six `SpriteBatch.DrawString`
  overloads. `MeasureString` and the per-glyph draw are transcribed from
  `SpriteFont::InternalMeasure` and `InternalDraw` in the pinned Graphics
  assembly and computed in Lisp over the glyph table CNA hands back, because
  routing layout through CNA's own `measure` and `draw_string` routes would make
  the layout CNA's and would narrow the input domain to what UTF-8 can encode.
  `System.Char` projects onto an integer in [0, 65535] -- a UTF-16 code unit, all
  65536 values legal -- and `String` and `StringBuilder` onto one Common Lisp
  string, declared as a unified collapse so neither contract member can go
  missing behind it. `SpriteFont` is not a `GraphicsResource` and not
  `IDisposable`, because XNA's is neither, and it has no public constructor for
  the same reason; the native handle it nevertheless owns goes back through the
  binding's own disposal, and the font is a child of its atlas so the two cannot
  be released in the wrong order. With it the rasterizer lane gained its fourth
  proof;
* three of the four remaining stock effects -- `AlphaTestEffect`,
  `DualTextureEffect` and `SkinnedEffect` -- over the same effect machinery, plus
  the mixin that makes "implements `IEffectLights`" a superclass instead of a
  hope: the first two implement neither that interface nor any part of it, and a
  generic function specialised on `Effect` had been giving them an applicable
  method for a member they have not got. `EnvironmentMapEffect` is the fourth and
  was deliberately absent at this point: its `EnvironmentMap` is a `TextureCube`,
  which was not projected then, and a closure is added whole or not at all.
  **Overtaken:** the `TextureCube` closure below brought both in, and all four
  other stock effects are complete;
* the render-target closure -- `RenderTarget2D`, `RenderTargetUsage`,
  `DepthFormat` and `GraphicsDevice.SetRenderTarget` -- which is the first thing
  here whose contents can be read without `GetBackBufferData`, because
  `RenderTarget2D` derives from `Texture2D` and a target can therefore be drawn.
  The rasterizer lane's sixth proof uses that: a clear into a bound target leaves
  the back buffer untouched, and the target's own contents then reach the screen
  through the texture path;
* **content** -- `ContentManager`, `Game.Content`, and `Load<T>` over the asset
  types CNA has a route for, which were three at this point and are four since
  `Load<Effect>` landed; `LOADABLE-ASSET-TYPES` is the live answer and the
  README renders it. This is the member that closes the SpriteFont
  loop: a font is glyph metrics *and* an atlas, neither of which a program can
  construct from arguments, so until a content manager existed the only producer
  was a test-only one. `Load<T>` stays a single member here rather than becoming
  one function per asset type, because Common Lisp can name a type -- the one
  place this projection is closer to XNA than the C ABI can be;
* the component engine -- `GameComponent`, `DrawableGameComponent`,
  `GameComponentCollection` and its two events, `GameComponentCollectionEventArgs`,
  the three `I*` contracts as generic functions, `LaunchParameters`, and
  `Game.Components` and `Game.LaunchParameters`. This is the one place in the
  binding where the consumer *provides* behaviour rather than consuming it: CNA
  takes a callback set and supplies the object implementing its C++ interfaces,
  and a component's behaviour is its CLOS methods on the same generic functions a
  `Game` specialises. The tests assert counts taken inside CNA's own loop, so an
  engine that was exported and never wired would fail them. `Game.Services` is
  deliberately absent, and the reason has since been re-audited route by route
  against 0.21.0: CNA's container has `contains_ext` and `remove_ext` over a
  closed two-member enum, no get route at all, and no registration route **by
  explicit decision**, so `GetService` cannot be answered *from CNA*.
  `docs/limitations.md` carries the audit and the one option it leaves open;
* `Texture2D`'s own construction and data surface -- both constructors and the
  three `SetData` and three `GetData` overloads, as narrow as the buffers' and
  over the same proven layouts. With it the rasterizer lane gained a seventh kind
  of proof and the first that does not go through `GetBackBufferData` at all: a
  render target's texels read straight out of it with `GetData`;
* `TextureCube`, `CubeMapFace` and `EnvironmentMapEffect`, which completes **all
  four** of XNA's other stock effects. A cube is a `Texture` and not a
  `Texture2D`, as XNA has it, and its two transfer families are the closure's only
  partial members: CNA's cube route takes `const CNA_Color*` with no texel-kind
  argument, so a face is transferable only as `Color` where XNA's `SetData<T>` is
  generic.

## 6. Measured status

Generated reports are the authority:

| Report | What it measures |
| --- | --- |
| `docs/generated/native-abi-manifest.json` | the bound native surface, with evidence |
| `docs/generated/api-compat-report.json` | the structural projection: complete / partial / missing |
| `docs/generated/behavior-corpus.json` | behaviour observations and their origin |

The counts in `README.md`, this file, `NEXT.md` and `docs/compatibility.md` are
cross-checked against those reports by `tools/qualification/verify-numbers.py`,
which refuses any figure in the prose that the reports do not produce. It checks
three ways: `<!-- generated:name=N -->` facts, whole
`<!-- generated-block:name -->` regions rendered straight from the reports, and
outright refusals for the class of figure that belongs to a *run* rather than to
the repository -- a suite's check count being the standing example, since it
moves with every test added and no report can pin it.

### Structural compatibility, as generated

<!-- generated:selected types=165 -->
<!-- generated:selected members=2389 -->
<!-- generated:complete types=149 -->
<!-- generated:partial types=16 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1906 -->
<!-- generated:partial members=19 -->
<!-- generated:missing members=35 -->
<!-- generated:not-applicable members=429 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 165 types, 2389 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **149** |
| Types partial | **16** |
| Types missing | **0** |
| Members complete | **1906** |
| Members partial | **19** |
| Members missing | **35** |
| Members not applicable | **429** |
| **Disagreement diagnostics** | **0** |
<!-- /generated-block:scoreboard -->

Every remaining diagnostic is an absence, and "zero disagreement" now means more
than it used to: no mapping rule names a member that does not exist, and every
collapsed overload family declares how each overload is distinguished, with its
keyword set checked against the real method lambda lists.

### Behaviour authority

Structure comes from the hash-pinned public metadata. **Behaviour comes from the
hash-pinned assembly**: `tools/api-compat/reference/XNA_IL_PROVENANCE.md` records
`Microsoft.Xna.Framework.dll` 4.0.0.0 by SHA-256, and every arithmetic method in
the projected value types was written by reading its IL body instruction by
instruction. No Microsoft binary or disassembly is stored here.

## 7. Rules this project keeps

* Strict verification may be red while real surface is missing. It must never be
  green because an allowlist hid something.
* A member that is blocked gets a precise evidence document; it does not get a
  fake implementation.
* Every public symbol that is not a mapped XNA member is a declared extension
  with a reason.
* No number in prose that is not generated or cross-checked.
* HEADLESS execution is never described as visible rendering.
* `REFERENCE_QUALIFIED`, `CI_TESTED`, `HEADLESS` and `NOT RUN` are four different
  claims and are never collapsed into one. `docs/qualification.md` defines them,
  and says which runtime and which CNA commit each CI run actually used.
