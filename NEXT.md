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
| `asdf:test-system` with a native library | **1436 checks, 0 failures, 0 not run** |
| `asdf:test-system` without one | 1075 checks, 0 failures, **61 not run** and reported as such |
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

<!-- generated:selected types=26 -->
<!-- generated:selected members=1043 -->
<!-- generated:complete types=16 -->
<!-- generated:partial types=9 -->
<!-- generated:missing types=1 -->
<!-- generated:complete members=739 -->
<!-- generated:partial members=1 -->
<!-- generated:missing members=141 -->
<!-- generated:not-applicable members=162 -->
<!-- generated:disagreement total=0 -->

26 selected types, 1043 members: **16 complete, 9 partial, 1 missing**;
**739 members complete, 141 missing**, 162 not applicable, 1 partial.
`docs/compatibility.md` has the per-type table.

`MathHelper`, `Vector2`, `Vector3`, `Vector4` and `Quaternion` are complete.
`Matrix` has seven members left, and each of them names what it is waiting for.

## GLOBAL_ACTIONABLE_LOCAL

**GLOBAL_ACTIONABLE_LOCAL is not zero.** There is a great deal of local work left,
and none of it is blocked on anything outside this repository. The one genuinely
external block is a single member.

### Externally blocked (1 member)

| Member | Blocker |
| --- | --- |
| `GraphicsDevice.Viewport` setter | `cna_graphics_device_set_viewport` takes `CNA_Viewport` (24 bytes) by value. The System V AMD64 ABI classifies it MEMORY, and CFFI cannot pass a MEMORY-class aggregate without `cffi-libffi`, which needs libffi headers and a C compiler at load time. Proved by `tools/native-abi/generate.py`, recorded in `docs/generated/native-abi-manifest.json` under `blocked_routes`. |

Unblocking it needs one of: a CNA route taking the viewport by pointer; a CFFI
that can pass a MEMORY-class aggregate without libffi; or a decision that a
released CNA-Lisp may require a C toolchain, which it currently may not.

## What to do next, in order

The order follows the public-signature dependency graph: each step is a closure
that can be finished, tested and measured before the next one starts.

1. **`Plane`**, which is small and unblocks three of `Matrix`'s seven remaining
   members (`CreateShadow` twice and `CreateReflection`). Then **`Ray`,
   `BoundingBox`, `BoundingSphere`, `BoundingFrustum`, `ContainmentType`,
   `PlaneIntersectionType`** -- `Matrix` and `Quaternion` are in place, so the
   whole geometry closure is now unblocked.
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
* **An exported symbol that is neither a mapped member nor a declared extension
  is a diagnostic.** Adding a convenience function means adding an entry to
  `cna-lisp.internal::*binding-extensions*` with the reason it exists. That is the
  mechanism that keeps the scoreboard honest; it is not paperwork to route around.
