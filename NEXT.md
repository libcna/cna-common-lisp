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
| Template canary | exactly 60/60 and 600/600 updates and draws |
| Isolated consumer | CNA-Lisp loaded from the artifact, not the checkout |
| Native stress | 20 plain cycles + 20 graphics cycles, registry empty after each |

HEADLESS proves lifecycle and command submission. It proves nothing about pixels,
and nothing in this repository says otherwise. `docs/qualification.md` defines
`REFERENCE_QUALIFIED`, `CI_TESTED`, `HEADLESS` and `NOT RUN`, and no claim here
may collapse two of them.

## Continuous integration

Both workflows **have run on GitHub and are the live gate**; any statement that
they have never executed is stale.

| Workflow | What it runs |
| --- | --- |
| `Lisp` / reference | pure gates on SBCL 2.5.2, installed from the upstream binary release and verified by SHA-256 |
| `Lisp` / distro | the same gates on ubuntu-24.04's own SBCL, as a secondary compatibility test |
| `Native` | builds the CNA C ABI from source, then the ABI gate, both runtime configurations and the isolated consumer, on the reference runtime |

The `Native` job follows CNA's moving `next` branch on purpose, and records the
CNA commit it landed on in the run's step summary and in `qualification-run.json`
inside the run's artifact. `workflow_dispatch` takes a `cna_ref` input for
qualifying a specific CNA commit. `docs/qualification.md` has the policy and the
reasons.

## The measured frontier

<!-- generated:selected types=77 -->
<!-- generated:selected members=1632 -->
<!-- generated:complete types=72 -->
<!-- generated:partial types=5 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1185 -->
<!-- generated:partial members=1 -->
<!-- generated:missing members=98 -->
<!-- generated:not-applicable members=348 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 77 types, 1632 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **72** |
| Types partial | **5** |
| Types missing | **0** |
| Members complete | **1185** |
| Members partial | **1** |
| Members missing | **98** |
| Members not applicable | **348** |
| **Disagreement diagnostics** | **0** |
<!-- /generated-block:scoreboard -->

`docs/compatibility.md` has the per-type table.

**Every pure-managed type in the selection is complete.** The math types
-- `Vector2`, `Vector3`, `Vector4`, `Quaternion`, `Matrix`, `Plane`, `Ray`,
`BoundingBox`, `BoundingSphere`, `BoundingFrustum`, `MathHelper`, `Color`,
`Point`, `Rectangle` -- the `Curve` family, the seventeen packed vector types and
all six enumerations answer every member of the selected contract, and **so does
the whole of `Microsoft.Xna.Framework.Input`** -- the keyboard, the mouse, the
`GamePad` family and the touch panel.

**No selected type is missing.** Five are partial, and this is where the
remaining members actually are:

<!-- generated-block:partial-frontier -->
| Type | missing members | partial members |
| --- | ---: | ---: |
| `M.X.F.Graphics.GraphicsDevice` | 52 | 1 |
| `M.X.F.GraphicsDeviceManager` | 16 | 0 |
| `M.X.F.Graphics.Texture2D` | 12 | 0 |
| `M.X.F.Graphics.SpriteBatch` | 10 | 0 |
| `M.X.F.Game` | 8 | 0 |
<!-- /generated-block:partial-frontier -->

Do not describe that as "graphics state objects, `Stream` and `SpriteFont`". The
largest single block is `GraphicsDevice`'s own drawing, render-target, buffer and
state surface; the state objects are the entry to it, not the whole of it.
Regenerate this table after every closure rather than reasoning from the last
one.

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

1. **Graphics state objects** -- `BlendState`, `DepthStencilState`,
   `RasterizerState`, `SamplerState`, with the enumerations they need
   (`Blend`, `BlendFunction`, `ColorWriteChannels`, `CompareFunction`,
   `StencilOperation`, `CullMode`, `FillMode`, `TextureAddressMode`,
   `TextureFilter`). These are what `SpriteBatch.Begin` and most of
   `GraphicsDevice`'s state surface need.
2. **`SpriteBatch.Begin`'s state-bearing overloads**, which the state objects
   unblock. Only the shapes XNA really has; the `Effect`-bearing ones stay
   missing until `Effect` exists, and are measured as missing.
3. **Vertex descriptors and vertex value types**: `VertexElement`,
   `VertexDeclaration`, `IVertexType`, and the four vertex structs.
4. **Game components and services**: `GameComponent`, `DrawableGameComponent`,
   `GameComponentCollection`, `GameServiceContainer`, `LaunchParameters`.
5. **`System.IO.Stream` and `TitleContainer`**, which unblock
   `Texture2D.FromStream`, `SaveAsPng`, `SaveAsJpeg`, and then `ContentManager`.
6. **`SpriteFont`**, which unblocks `SpriteBatch.DrawString`'s six overloads.
7. **Audio, effects, models, media, storage, gamer services, networking.**

## Frontier notes worth keeping

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
