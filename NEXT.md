# CNA-Lisp continuation handoff

`plan.md` is the architecture and the rules. This file is *where the work stands*
and *what to do next*. Everything numbered here is generated; reproduce it rather
than trusting it.

## Reproduce the state

```sh
export CNA_NATIVE_LIBRARY=/absolute/path/to/libcna_c_api.so   # ABI 0.21.0, HEADLESS
export CNA_HEADERS=/path/to/cna/modules/c-api/include
export CNA_ABI_BASELINE=/path/to/cna/tools/c-api/abi_baseline.json
export CNA_LISP_VALUEPROBE="$PWD/build-probe/libcna-lisp-valueprobe.so"
export CNA_LISP_SHIM="$PWD/build-probe/libcna-lisp-shim.so"      # optional

# 1. the generated foreign layer is current
python3 tools/native-abi/generate.py --check --headers "$CNA_HEADERS" --baseline "$CNA_ABI_BASELINE"

# 2. a C compiler agrees with every bound prototype, layout and constant
tools/native-abi/verify.sh "$CNA_HEADERS"

# 3. the whole test suite
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
     --eval '(push (truename ".") asdf:*central-registry*)' \
     --eval '(asdf:test-system "cna-common-lisp")'

# 4. the structural scoreboard, and the prose consistency check
tools/api-compat/verify.sh --strict

# 5. the isolated consumer, at 60 and 600 frames
tools/qualification/isolated-consumer.sh ../cna-common-lisp-template

# 6. the rasterizer lane, which needs a CNA built with a rasterising renderer.
#    -DCNA_GRAPHICS_RENDERER=SOFTWARE is a CPU rasteriser and needs no display.
CNA_NATIVE_LIBRARY=/absolute/path/to/software/libcna_c_api.so \
    tools/qualification/rasterizer.sh
```

`git log --oneline` answers what has been published; a count written down here
would go stale the moment the next commit lands. The same is true of the suite's
check count, which is why this file no longer carries one and
`tools/qualification/verify-numbers.py` now refuses one.

## What is green, exactly

Locally, on the reference runtime (SBCL 2.5.2, Linux x86-64), against CNA C ABI
**0.21.0** (encoded 5376) built with the `SDL3` platform, `SDL3` audio and the
**HEADLESS** renderer:

| Gate | Result |
| --- | --- |
| ASDF load from a fresh image | no warnings |
| `asdf:test-system`, native library and shim present | 0 failures, nothing not run |
| `asdf:test-system`, native library, no shim | 0 failures (the setter's refusal path) |
| `asdf:test-system` with neither | 0 failures; the native layer reported as not run, never as passed |
| Compiler-backed ABI probe | compiles clean at `-Wall -Wextra -Werror -Wpedantic` |
| CFFI-vs-recorded layout check | 0 disagreements |
| Structural verification | **0 disagreement diagnostics** |
| Prose consistency | every generated fact and block matches the reports |
| Rasterizer lane | `tools/qualification/rasterizer.sh` against a SOFTWARE-renderer library: every kind its registry requires (<!-- generated:rasterizer proof count=8 -->) |
| Template canary | exactly 60/60 and 600/600 updates and draws |
| Isolated consumer | CNA-Lisp loaded from the artifact, not the checkout |
| Native stress | 20 plain cycles + 20 graphics cycles, registry empty after each |
| Construction atomicity | an exploding subclass of twelve resource families, plus `Game` and `GraphicsDeviceManager`, leaves no live child and lets the game shut down |
| Content transaction | a load made to fail at the texture's storage query, the font's info, its glyph table, or the **cache insertion** gives every handle back exactly once |
| Render-target cross-check | six ways a remembered binding can drift are each refused; an unmutated one is accepted first |

HEADLESS proves lifecycle and command submission. It proves nothing about pixels
-- **the SOFTWARE lane is what does**, and it needs no display: a CPU rasteriser
clears to CornflowerBlue and the back buffer reads back (100, 149, 237, 255), a
SpriteBatch draw lands a known texture's texels where its destination says, a
BasicEffect pass followed by one DrawUserPrimitives triangle covers exactly the
pixels its geometry covers, and `DrawString` lays a string out glyph by glyph --
each from its own atlas cell at its own advanced position, across a line break,
and a `SaveAsPng`/`FromStream` round trip returns every texel of a known texture.
Neither lane is a claim about a physical monitor. `docs/qualification.md` defines
`REFERENCE_QUALIFIED`, `CI_TESTED`, `HEADLESS` and `NOT RUN`, and no claim here
may collapse two of them.

## Continuous integration

Both workflows **have run on GitHub and are the live gate**; any statement that
they have never executed is stale.

| Workflow | What it runs |
| --- | --- |
| `Lisp` / reference | pure gates on SBCL 2.5.2, installed from the upstream binary release and verified by SHA-256 |
| `Lisp` / distro | the same gates on ubuntu-24.04's own SBCL, as a secondary compatibility test |
| `Native` | builds the CNA C ABI from source, then the ABI gate, both runtime configurations and the isolated consumer, on the reference runtime, with the HEADLESS renderer |
| `Native` / rasterizer | a second CNA with the SOFTWARE renderer, and the same suite: it fails unless every kind of pixel proof its registry requires was obtained, and fails too on a kind the registry does not name |

The `Native` job is **pinned to CNA commit `056e57d47`**, and not by preference:
`openeggbert/cna:next` does not currently build from published sources, because
its storage module calls a `sharp-runtime` member that has not been pushed. The
pin is that call's parent commit. Every run records the CNA and sharp-runtime
commits it landed on, in the step summary and in `qualification-run.json` inside
the run's artifact, and `workflow_dispatch` takes `cna_ref` and
`sharp_runtime_ref` for checking whether the two repositories have caught up.
`docs/qualification.md` has the policy and the evidence.

## The measured frontier

<!-- generated:selected types=154 -->
<!-- generated:selected members=2292 -->
<!-- generated:complete types=140 -->
<!-- generated:partial types=14 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1821 -->
<!-- generated:partial members=15 -->
<!-- generated:missing members=34 -->
<!-- generated:not-applicable members=422 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 154 types, 2292 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **140** |
| Types partial | **14** |
| Types missing | **0** |
| Members complete | **1821** |
| Members partial | **15** |
| Members missing | **34** |
| Members not applicable | **422** |
| **Disagreement diagnostics** | **0** |
<!-- /generated-block:scoreboard -->

`docs/compatibility.md` has the per-type table.

**Every pure-managed type in the selection is complete.** The math types
-- `Vector2`, `Vector3`, `Vector4`, `Quaternion`, `Matrix`, `Plane`, `Ray`,
`BoundingBox`, `BoundingSphere`, `BoundingFrustum`, `MathHelper`, `Color`,
`Point`, `Rectangle` -- the `Curve` family, the seventeen packed vector types and
every enumeration answer every member of the selected contract, and **so does
the whole of `Microsoft.Xna.Framework.Input`** -- the keyboard, the mouse, the
`GamePad` family and the touch panel. So do the four **graphics state objects**
and the nine enumerations they are built from.

**No selected type is missing.**
<!-- generated:partial types=14 --> are partial, and this is where the remaining
members actually are:

<!-- generated-block:partial-frontier -->
| Type | missing members | partial members |
| --- | ---: | ---: |
| `M.X.F.Graphics.GraphicsDevice` | 10 | 1 |
| `M.X.F.GraphicsDeviceManager` | 9 | 0 |
| `M.X.F.Game` | 5 | 1 |
| `M.X.F.Content.ContentManager` | 3 | 1 |
| `M.X.F.Graphics.EffectParameter` | 2 | 0 |
| `M.X.F.GameComponentCollection` | 1 | 0 |
| `M.X.F.Graphics.PresentationParameters` | 1 | 0 |
| `M.X.F.Graphics.Effect` | 1 | 0 |
| `M.X.F.Graphics.DirectionalLight` | 1 | 0 |
| `M.X.F.Graphics.BasicEffect` | 1 | 0 |
| `M.X.F.TitleContainer` | 0 | 1 |
| `M.X.F.Graphics.RenderTargetBinding` | 0 | 1 |
| `M.X.F.Graphics.Texture2D` | 0 | 4 |
| `M.X.F.Graphics.TextureCube` | 0 | 6 |
<!-- /generated-block:partial-frontier -->

Do not describe that as "graphics state objects, `Stream` and `SpriteFont`", and
do not describe it as the drawing family either -- both of those closed.
Regenerate this table after every closure rather than reasoning from the last
one.

## Where the missing members actually are

<!-- generated-block:partial-frontier -->
| Type | missing members | partial members |
| --- | ---: | ---: |
| `M.X.F.Graphics.GraphicsDevice` | 10 | 1 |
| `M.X.F.GraphicsDeviceManager` | 9 | 0 |
| `M.X.F.Game` | 5 | 1 |
| `M.X.F.Content.ContentManager` | 3 | 1 |
| `M.X.F.Graphics.EffectParameter` | 2 | 0 |
| `M.X.F.GameComponentCollection` | 1 | 0 |
| `M.X.F.Graphics.PresentationParameters` | 1 | 0 |
| `M.X.F.Graphics.Effect` | 1 | 0 |
| `M.X.F.Graphics.DirectionalLight` | 1 | 0 |
| `M.X.F.Graphics.BasicEffect` | 1 | 0 |
| `M.X.F.TitleContainer` | 0 | 1 |
| `M.X.F.Graphics.RenderTargetBinding` | 0 | 1 |
| `M.X.F.Graphics.Texture2D` | 0 | 4 |
| `M.X.F.Graphics.TextureCube` | 0 | 6 |
<!-- /generated-block:partial-frontier -->

`GraphicsDevice` is still most of it, but the drawing family is no longer any of
it. What is left there is four different things, and they belong to four
different closures rather than one:

* **render targets** -- `SetRenderTarget` (two), `SetRenderTargets`,
  `GetRenderTargets`, and `RenderTarget2D`, `RenderTargetUsage` and `DepthFormat`
  with them;
* **the device-settings surface** -- `Adapter`, `DisplayMode`,
  `PresentationParameters`, `GraphicsProfile`, `GraphicsDeviceStatus`, the three
  `Reset` overloads, `Present` and the five device-lifetime events. That is one
  closure with `GraphicsDeviceManager`'s sixteen, which are the same subject seen
  from the other side;
* **two `Clear` overloads and `DrawInstancedPrimitives`**, which need a
  `ClearOptions` and an instanced vertex stream respectively;
* **`new(...)` and `Dispose`/`IsDisposed`/`Disposing`**, which are the device as
  an object a program constructs -- something a CNA-Lisp program never does,
  since CNA lends the device.

`Texture2D`'s twelve are `SetData`/`GetData` (three each), two constructors, and
the four members that need `System.IO.Stream`: `FromStream` twice, `SaveAsPng`
and `SaveAsJpeg`.

`Game`'s eight are the component engine (`Components`, `Services`,
`LaunchParameters`), `Content`, `Window` as a type, and three protected `On*`
methods.

## GLOBAL_ACTIONABLE_LOCAL

**GLOBAL_ACTIONABLE_LOCAL is not zero**, and there is **nothing externally
blocked at all**. Every remaining absence is local work.

`GraphicsDevice.Viewport`'s setter used to be recorded here as the one external
blocker, on the grounds that CFFI cannot pass a 24-byte aggregate by value. That
was a true fact and a wrong conclusion: a tiny private shim for a *proved* ABI
impedance mismatch is exactly the permitted remedy, and the generator now emits
one. The setter works through it. The shim stays optional -- a release must load
with no C toolchain -- so without `CNA_LISP_SHIM` the setter refuses with a
condition naming the variable, the command that builds one, and the reason. That
is a packaging limit, not a blocker.

## What to do next, in order

The order follows the public-signature dependency graph: each step is a closure
that can be finished, tested and measured before the next one starts. Regenerate
the graph after each closure instead of following this list once it has moved.

0. **Every remaining absence now carries a stated reason**, and the mapping rules
   are where they live rather than this file. Twenty-six of the thirty-nine
   missing members had none until they were audited route by route against
   0.21.0's headers, and the audit changed what several of them *are*: three
   turned out to be implementable and are recorded as next steps rather than as
   limits, and one -- `GraphicsDevice.IsDisposed` -- was implemented on the spot.
   Read `unimplemented` in `tools/api-compat/mapping-rules.json` before assuming
   anything about what is left.

   The first of the three has since been done -- `GraphicsDevice`'s four
   payload-free events are complete. Two left: **`Game.Window`** needs
   only the `GameWindow` type, because `runtime_window.h` is a full window surface
   keyed by the game handle; and **`GraphicsDevice.Adapter`** needs `GraphicsAdapter`,
   whose thirteen CNA routes all take a *callback-scoped device handle* -- so
   projecting it inherits a scope rule XNA's static `GraphicsAdapter.Adapters` has
   not got, which is a design question to settle before starting rather than an
   obstacle.

1. **The device-settings closure**: `Adapter`, `DisplayMode`,
   `PresentationParameters`, `GraphicsProfile`, `GraphicsDeviceStatus`, the three
   `Reset` overloads, `Present`, `GraphicsDevice`'s six events, and
   `GraphicsDeviceManager`'s sixteen remaining members, which are the same subject
   seen from the other side. It brings `GameServiceContainer` into the selection.

   **`Game.Services` is where that closure gets hard**, and it is worth knowing
   why before starting. Re-audited against the pinned metadata:
   `IGraphicsDeviceService`'s five members -- the `GraphicsDevice` property and the
   `DeviceCreated`, `DeviceDisposing`, `DeviceReset` and `DeviceResetting` events
   -- are *already complete*, on `GraphicsDeviceManager`, the type that implements
   the interface; and `IGraphicsDeviceManager`'s `CreateDevice`, `BeginDraw` and
   `EndDraw` each have a CNA route. An earlier note here claimed the blocker was
   those interfaces and `GraphicsDevice`'s device-loss events; it had confused
   `GraphicsDevice`'s own same-named `DeviceReset`/`DeviceResetting` with the
   service interface's. **Do not reintroduce that reason.**

   Re-audited again against 0.21.0's headers, route by route: CNA's container has
   `contains_ext` and `remove_ext` over a closed two-member enum, **no get route
   at all, and no registration route by explicit decision** -- "a route that
   accepted an opaque token instead would satisfy neither side: native code asking
   for `IGraphicsDeviceService` needs a vtable, not a `void*`". CNA's own advice is
   that a consumer keep its own container beside this one.

   So `GetService` cannot be answered *from CNA*. It might be answerable from
   *here*: the binding holds the manager CNA registers as both canonical services,
   so a container could answer both keys from the record, ask `contains_ext` first,
   route a removal through `remove_ext` so the two sides stay in step, and keep a
   program's own services in a Lisp dictionary -- which is where CNA says they
   belong and where XNA keeps them too. That is a real option and it is this
   closure's work, not a shortcut to take earlier: `GameServiceContainer` has to
   enter the selection and its three members have to come out of the IL first. A
   Lisp dictionary on its own, inventing the two canonical services, stays refused.
   `docs/limitations.md` has the full audit.
2. **Audio, models, media, storage, gamer services, networking.**

## Frontier notes worth keeping

* **`System.IO.Stream` is a Common Lisp stream, and is not a type.** It is not in
  the pinned contract -- that snapshot is the XNA profile and `Stream` is the BCL's
  -- so there was never a type here to project. What there was, is members that
  take one, and they now take an ordinary binary stream from `OPEN`. `SeekOrigin`
  is not projected for the same kind of reason: .NET spells relative positioning
  as an enumeration argument and Common Lisp spells it as arithmetic on
  `FILE-POSITION`. Do not add either as a class.

* **`TitleContainer.OpenStream` does not use CNA's route for it, on purpose.**
  `cna_title_container_read_ext` reads a whole file and its own header calls that
  a deliberate narrowing; XNA answers a lazy `FileStream` and Common Lisp has one
  in `OPEN`. The *base path* still comes from CNA, so an override made there is
  honoured. The validation is XNA's, transcribed -- and the order matters: cleaning
  happens before the escape check, so `a/../b` is accepted and `../b` is refused.

* **ABI 0.22.0 has been audited and is still not admitted, for a reason that is
  not about effort.** Measured against `cnanext c4561fd2b`: all 328 bound routes
  are still exported, the generated foreign layer regenerated against 0.22.0's
  headers is **identical** but for the two version constants, and the
  compiler-backed probe passes against them at `-Werror`. The shape of 0.22.0 is
  the shape already bound, and a C compiler says so.

  What is missing is a library anybody can build. `cna:next` still calls
  `StoragePaths::SetIsolatedStorageRootOverride`; the sharp-runtime commit adding
  it, `c419f477`, is on **no remote branch**. A 0.22.0 library exists on this
  machine only because the unpublished commit is here, and qualifying against it
  would produce evidence CI could not reproduce. **Do not admit 0.22.0 on local
  evidence.**

  Re-measured after fetching both remotes, and **unchanged in every part that
  matters**: `cna:next` has moved on to `34c5a9d4a` and *still* makes that call,
  in `modules/storage/src/StorageDevice.cpp`, twice;
  `sharp-runtime:next` is still `bd282d101`; and
  `git branch -r --contains c419f477` is still **empty**. Those three commands are
  the whole re-check, and the last one is the cheapest. If it ever prints a
  branch, build a HEADLESS and a SOFTWARE 0.22.0 and run the whole gate set before
  touching the admitted set -- which lives in `src/internal/abi-gate.lisp` for the
  runtime and in the manifest's `admitted_abi_versions` for the generator, and both
  have to move together.

  Two practical notes for reproducing the 0.21.0 gates in the meantime: point
  `CNA_ABI_BASELINE` at a 0.21.0 baseline -- `cnanext 2b0c374a1` is the last
  commit carrying one -- rather than at whatever the checkout is on today, or the
  generator refuses with "supplied headers declare ABI ... which the manifest
  does not admit", which is the gate doing its job. And the admitted set lives in
  `src/internal/abi-gate.lisp`, not in the manifest: the manifest's
  `admitted_abi_versions` gates the *generator*, the Lisp constant gates the
  *runtime*, and both have to move together.

* **The render-target family is closed.** `RenderTargetCube` and
  `RenderTargetBinding` went in, and with them `GraphicsDevice`'s last three
  render-target members. Two things to know: `SetRenderTarget`'s two overloads are
  **one** generic function with an optional face, because XNA gives them one name;
  and binding a cube target is renderer-dependent -- HEADLESS accepts it, SOFTWARE
  refuses with "this renderer does not support RenderTargetCube", and the test
  checks both branches. `GetRenderTargets` answers the objects this binding bound,
  cross-checked against CNA's handles, because the ABI has no route from a handle
  back to an object.

* **A `SpriteFont` is obtainable from a program now, and the evidence is
  pixels.** `ContentManager.Load<SpriteFont>` reads a `.cnj` descriptor and
  answers the font *and* its atlas -- two owned handles for one asset, disposed
  font-first. The SOFTWARE lane's new `loaded-text` proof draws "AB" with a
  loaded font and asserts the same pixels, at the same coordinates, as the proof
  that uses the hand-built one: a descriptor that drifted from the suite's glyph
  rows would put a glyph somewhere else and fail. The template draws text through
  the same path, with `make-font-fixture.py` generating its 95-glyph asset.

* **Measured, not assumed, about content:** `.cnj` loads and the older
  `.font.json` convention does not (`CNA_RESULT_IO`); and ABI 0.21.0 has **no
  route reporting a Texture2D's width or height**, so a loaded texture refuses
  both rather than answering a plausible zero. A TextureCube does report its
  size, which makes the gap look like an oversight in CNA rather than a policy.

* **The cache is this binding's, in front of CNA's route, which is where XNA's is
  too.** CNA's ABI has one create-shaped route per asset type and no cache; the
  manager here keeps XNA's two collections, so `Load<T>` twice answers one object,
  `Unload` disposes what it loaded, and `Game.Content.Dispose()` is `Unload` plus
  being finished -- which is all XNA's `Dispose` is, since it has nothing native to
  destroy. Do not restore the note that said there is no cache and that two loads
  are four things to dispose.

* **A component added in `LoadContent` is never initialized, and that is XNA's
  doing.** `Game.Run` sets `inRun` *after* `Initialize()` returns; `Initialize()`
  drains `notYetInitialized` and then calls `LoadContent()` at its very end; and
  `GameComponentAdded` initializes a component only when `inRun` is already true.
  So one added there lands on the list after the loop that empties it has
  finished, and is updated and drawn every frame and initialized never. Read from
  the pinned Game assembly, measured to be CNA's behaviour too, and pinned by a
  test. Do not "fix" it.

* **Pixel evidence no longer has to come from the back buffer.** `RenderTarget2D`
  derives from `Texture2D`, so a target's contents can be read by drawing it --
  on any renderer that can draw at all. The `render-target` proof uses the
  back-buffer readback to check itself, because that is what this renderer
  offers; what changed is that the mechanism is no longer the only one. The next
  renderer added to the lane does not need `GetBackBufferData` to be qualified
  for anything but `clear`.

* **A state round-trip is not shading evidence, and the gap is now measured.**
  CNA's software renderer never reads `GpuDrawParams::alphaTest`, so
  `AlphaTestEffect`'s `AlphaFunction` and `ReferenceAlpha` reach the ABI and
  change no pixel -- `Never` draws what `Always` draws. Its bone palette works
  only for a skinned vertex layout no standard XNA vertex type carries.
  `DualTextureEffect` cannot be drawn at all without both layers *and* a second
  texture coordinate. All three are recorded in `docs/limitations.md`, and the
  rasterizer lane's `stock-effect` proof claims only that these are usable *draw*
  effects. Do not upgrade that claim without new evidence.

* **`System.Char` is a UTF-16 code unit, and a Common Lisp string is not made of
  them.** A CLR string is a sequence of code *units*; a Lisp string is a sequence
  of code *points*. They agree across the BMP and disagree above it, where
  U+1F600 is one character here and two `char`s there -- and XNA looks each of
  those two up in the glyph table separately. So `System.Char` projects onto an
  integer in [0, 65535] and text is converted to code units before it is measured
  or drawn. Do not "simplify" that to iterating the string's characters.

* **A projection may narrow, but it may not lose an overload.**
  `MeasureString(String)` and `MeasureString(StringBuilder)` are one Lisp call,
  because XNA's own `StringProxy` makes them one code path and a Lisp string
  expresses both. That is declared with `distinguished_by: "unified"`, each names
  the other, and the verifier refuses a collapse that names nobody. The same
  question found three older collapses nothing had declared -- `SpriteBatch.Draw`'s
  two scale overloads, `DrawUserIndexedPrimitives`'s two index widths, and the
  sixteen array transforms that claimed `arity` when there are two of each arity.

* **SpriteFont has no public constructor here, and does not need one.** XNA gives
  it none either: a font comes from `ContentManager.Load<SpriteFont>`, and it does
  here too. CNA has `cna_sprite_font_create`, and projecting *that* as a public
  constructor would invent a member XNA has not got, so the producer stays
  unexported and test-only. The template draws text through the public content
  path and must not be given an internal route to do so; the SOFTWARE lane's
  `loaded-text` proof and the template's own `text_pixel` are what say it works.

* **CNA is stricter than XNA about a SpriteFont's spacing, and XNA wins.**
  `cna_sprite_font_set_spacing` requires a finite value; XNA's setter is a bare
  `stfld` and stores a NaN. LineSpacing, Spacing and DefaultCharacter are managed
  fields here for that reason -- XNA's are too -- so the three CNA setters are
  **not bound at all** rather than bound and worked around. The cost is exact and
  is in `docs/limitations.md`: the native font keeps the values it was created
  with, and nothing in CNA-Lisp reads them.

* **A fixed time step does not make a frame count an update count.** Measured:
  catch-up updates follow a frame that overran its target, and a full collection
  between frames is enough. Every deterministic frame claim here uses variable
  timing. Do not "fix" a test that sets `is-fixed-time-step` to false.
* **`cna_game_destroy` answers `CNA_RESULT_CALLBACK` for a latched earlier
  failure**, not only for a failing shutdown callback. CNA-Lisp distinguishes the
  two by whether a condition was freshly contained; the alternative masks the
  original condition behind an unwind. `tests/native/ownership.lisp` pins both
  directions.
* **The graphics device must never keep its handle.** It is lent for a callback's
  duration. `graphics-device` resolves a fresh borrowed handle per operation, and
  a device operation outside a callback is refused before anything reaches the
  ABI.
* **Behaviour comes from the IL, not from a description of the behaviour.** The
  pinned assembly is recorded by SHA-256 in
  `tools/api-compat/reference/XNA_IL_PROVENANCE.md`. Reading it is what caught
  that `Math.Min(+0.0f, -0.0f)` answers `-0.0f`, that `Clamp` passes a NaN
  through, and that `ToRadians` multiplies by a constant rather than dividing by
  180 -- three things a reimplementation from first principles gets wrong.
* **A by-reference overload of a pure computation is not applicable, not
  missing.** It exists in XNA to avoid copying a value type; the value it computes
  is the by-value overload's, and Common Lisp passes a reference already. Each
  one carries its reason in the mapping rules.
* **A `&key` lambda list accepts everything unless something refuses.** That is
  how `draw-texture` came to accept combinations XNA has no overload for, and how
  `begin` came to offer a `Begin(SpriteSortMode)` that does not exist. The rules
  now carry a keyword set per overload and the verifier checks it; do not add a
  keyword without adding it to the rules and refusing the shapes it does not
  belong to.
* **A mapping rule keyed on a signature no member produces is silently ignored.**
  It is now a `stale_mapping_rule` diagnostic. When adding rules, take the
  signature from the generated report, not from a listing script.
* **A position and a destination rectangle are not interchangeable.**
  `SpriteBatch.Draw`'s position overloads take
  `cna_sprite_batch_submit_scaled_many`; computing a rectangle from a position
  and a scale loses the fractional position and moves the origin.
* **CNA is not the oracle, and here is where it was wrong.** CNA's
  `DepthStencilState` initialises `StencilMask` and `StencilWriteMask` to
  `0x7FFFFFFF`; XNA's `SetDefaults` writes `-1`. The public value is XNA's, the
  divergence is in `docs/limitations.md`, and
  `tests/native/graphics-state.lisp` pins *both* sides so a corrected CNA makes a
  test fail rather than passing silently. Nothing in CNA was modified.
* **XNA's `BlendFunction` numbers Min 3 and Max 4; CNA numbers them the other way
  round.** Every other enumeration in this binding happens to share CNA's
  numbering, which is exactly why the state enums translate **by name** through
  explicit tables -- a numeric pass-through would have worked everywhere else and
  turned a minimum into a maximum here.
* **A state object is latched at Begin, and XNA latches the deferred modes at
  End.** CNA's `begin_with_states` copies the descriptors by value, so there is
  nothing left to read at End. Refusing a mutation between Begin and End was
  chosen over accepting one that could no longer take effect.
* **The first state-bearing Begin costs tens of milliseconds**, and every one
  after it costs nothing measurable: CNA creates its native state objects on
  first use. Under a fixed time step that warm-up becomes catch-up updates with
  no draws, which is why the graphics fixture runs on variable timing.
* **A qualification lane that cannot fail for the right reason proves nothing.**
  The rasterizer lane runs the same suite against a SOFTWARE-renderer CNA, and
  the trap it avoids is passing while silently taking the no-readback branch. So
  the test branches on the renderer that is present and asserts the truth for
  each, the runner prints which branch ran, and
  `tools/qualification/rasterizer.sh` fails when the branch was the wrong one.
  Verified by pointing it at a HEADLESS library: it exits 1.
* **An exported symbol that is neither a mapped member nor a declared extension
  is a diagnostic.** Adding a convenience function means adding an entry to
  `cna-lisp.internal::*binding-extensions*` with the reason it exists. That is the
  mechanism that keeps the scoreboard honest; it is not paperwork to route around.
* **A number in prose is a claim.** `tools/qualification/verify-numbers.py` now
  checks three ways: `<!-- generated:name=N -->` facts, whole
  `<!-- generated-block:name -->` regions rendered from the reports, and outright
  refusals for figures that belong to a run rather than to the repository. The
  native-ABI summary in `docs/compatibility.md` had drifted to 69 bound routes
  while the manifest said 100, because no single number in it carried a marker.
