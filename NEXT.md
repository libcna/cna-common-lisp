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

# 4. the structural scoreboard
tools/api-compat/verify.sh --strict

# 5. the isolated consumer, at 60 and 600 frames
tools/qualification/isolated-consumer.sh ../cna-common-lisp-template
```

`git log --oneline` answers what has been published; a count written down here
would go stale the moment the next commit lands.

## What is green, exactly

| Gate | Result |
| --- | --- |
| ASDF load from a fresh image | no warnings |
| `asdf:test-system` with a native library and the shim | **1503 checks, 0 failures** |
| `asdf:test-system` with a native library, no shim | 1500 checks, 0 failures (the setter's refusal path) |
| `asdf:test-system` without either | 1123 checks, 0 failures, **67 not run** and reported as such |
| Compiler-backed ABI probe | compiles clean at `-Wall -Wextra -Werror -Wpedantic` |
| CFFI-vs-recorded layout check | 0 disagreements |
| Structural verification | **0 disagreement diagnostics** |
| Template canary | exactly 60/60 and 600/600 updates and draws |
| Isolated consumer | CNA-Lisp loaded from the artifact, not the checkout |
| Native stress | 20 plain cycles + 20 graphics cycles, registry empty after each |

Qualified against SBCL 2.5.2 on Linux x86-64, CNA C ABI **0.21.0** (encoded 5376),
a CNA build with the `SDL3` platform, `SDL3` audio and the **HEADLESS** renderer.
HEADLESS proves lifecycle and command submission. It proves nothing about pixels,
and nothing in this repository says otherwise.

## The measured frontier

<!-- generated:selected types=32 -->
<!-- generated:selected members=1163 -->
<!-- generated:complete types=18 -->
<!-- generated:partial types=13 -->
<!-- generated:missing types=1 -->
<!-- generated:complete members=800 -->
<!-- generated:partial members=1 -->
<!-- generated:missing members=140 -->
<!-- generated:not-applicable members=222 -->
<!-- generated:disagreement total=0 -->

32 selected types, 1163 members: **18 complete, 13 partial, 1 missing**;
**800 members complete, 140 missing**, 222 not applicable, 1 partial.
`docs/compatibility.md` has the per-type table.

`MathHelper`, `Vector2`, `Vector3`, `Vector4` and `Quaternion` are complete.
`Matrix` has three members left; `Plane`, `Ray`, `BoundingBox` and
`BoundingSphere` have between one and three each, and every one of those is
`BoundingFrustum` — the next closure, and the only thing they are waiting for.

## GLOBAL_ACTIONABLE_LOCAL

**GLOBAL_ACTIONABLE_LOCAL is not zero**, and there is now **nothing externally
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
that can be finished, tested and measured before the next one starts.

1. **The bounding volumes**: `Ray`, `BoundingBox`, `BoundingSphere` and
   `BoundingFrustum`. `Plane`, `ContainmentType` and `PlaneIntersectionType` are
   done and `Plane`'s three remaining members are the ones that need these. The
   four types intersect and contain each other in every combination, so they are
   one closure and not four: implement them together or the cross-products stay
   missing anyway. `BoundingFrustum` is the hard one -- its corners come from
   intersecting three planes at a time, and its frustum-frustum test is not the
   naive one.
2. **Complete `Rectangle`** (`Intersect`, `Union`, the `Point` overload of
   `Offset`) and **`Color`** (the float and vector constructors, `ToVector3`,
   `ToVector4`, `Lerp`) -- `Color`'s vector members are unblocked now that
   `Vector3` and `Vector4` exist.
3. **`Matrix.Decompose` and `Matrix.CreateConstrainedBillboard`**, the two
   deferred members. Both are real work rather than transcription: `Decompose` is
   540 IL instructions over a private pointer basis with a degenerate-scale
   fallback, and the constrained billboard has a three-deep threshold chain. Read
   them properly or leave them absent; do not approximate either.
4. **The `Curve` family**: `Curve`, `CurveKey`, `CurveKeyCollection`,
   `CurveContinuity`, `CurveLoopType`, `CurveTangent`. Pure managed, CNA has the
   routes for cross-checking.
5. **Packed vectors**: the 19-type `Graphics.PackedVector` family. Pure managed.
6. **Vertex descriptors and vertex value types**: `VertexElement`,
   `VertexDeclaration`, `IVertexType`, and the four vertex structs.
7. **The rest of input**: `Mouse`/`MouseState`, the `GamePad` family,
   `Input.Touch`. `Mouse.GetState` becomes `mouse-get-state`, which is the whole
   reason the static-class rule exists.
8. **Game components and services**: `GameComponent`, `DrawableGameComponent`,
   `GameComponentCollection`, `GameServiceContainer`, `LaunchParameters`, and the
   **event projection** the four `Game` events and six `GraphicsDevice` events
   need. That one decision unblocks `GraphicsResource` and 21 of
   `GraphicsDeviceManager`'s 30 members.
9. **`System.IO.Stream` and `TitleContainer`**, which unblock
   `Texture2D.FromStream`, `SaveAsPng`, `SaveAsJpeg`, and then `ContentManager`.
10. **Graphics state objects** (`BlendState`, `DepthStencilState`,
   `RasterizerState`, `SamplerState`), which unblock `SpriteBatch.Begin`'s four
   state-bearing overloads.
11. **`SpriteFont`**, which unblocks `SpriteBatch.DrawString`'s six overloads.
12. **Audio, effects, models, media, storage, gamer services, networking.**

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
  is the by-value overload's, and Common Lisp passes a reference already. 75
  members are classified that way, each with the reason recorded in the mapping
  rules.
* **A `&key` lambda list accepts everything unless something refuses.** That is
  how `draw-texture` came to accept combinations XNA has no overload for, and how
  `begin` came to offer a `Begin(SpriteSortMode)` that does not exist. The rules
  now carry a keyword set per overload and the verifier checks it; do not add a
  keyword without adding it to the rules and refusing the shapes it does not
  belong to.
* **A mapping rule keyed on a signature no member produces is silently ignored.**
  It is now a `stale_mapping_rule` diagnostic. When adding rules, take the
  signature from the generated report, not from a listing script -- ten of them
  were wrong because `System.Nullable\`1[Rectangle]` had been shortened by
  splitting on the wrong character.
* **A position and a destination rectangle are not interchangeable.**
  `SpriteBatch.Draw`'s position overloads take
  `cna_sprite_batch_submit_scaled_many`; computing a rectangle from a position
  and a scale loses the fractional position and moves the origin.
* **An exported symbol that is neither a mapped member nor a declared extension
  is a diagnostic.** Adding a convenience function means adding an entry to
  `cna-lisp.internal::*binding-extensions*` with the reason it exists. That is the
  mechanism that keeps the scoreboard honest; it is not paperwork to route around.
