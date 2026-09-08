# Compatibility

Every number here is generated. `docs/generated/api-compat-report.json` is the
authority, `tools/api-compat/verify.py` produces it, and
`tools/qualification/verify-numbers.py` refuses any figure in this repository's
prose that does not match it.

## How the measurement works

1. **The contract** is a hash-pinned public-metadata snapshot of the Microsoft
   XNA Framework 4.0 Windows runtime profile: 257 types with their public
   members. `tools/api-compat/import-contract.py` refuses to run unless the
   snapshot's SHA-256 is exactly the pinned one, and extracts the selected
   subset into `tools/api-compat/reference/xna40-selected-contract.json`. No
   Microsoft binary is stored here or distributed.

   **The snapshot itself is not committed, and on 2026-09-08 no copy of it
   existed on the machine any more.** That is the failure mode a hash pin has:
   it is exactly as available as the file it names. What survived was a *newer
   serialization of the same metadata* — CNA-Swift pins the same profile, and its
   copy is `schemaVersion` 2, which adds one field, `readonly`, to every field
   member and changes nothing else.

   `tools/api-compat/recover-contract-snapshot.py` reconstructs the pinned bytes
   from such a copy by removing exactly that field, and **refuses to write
   anything unless the result hashes to the pinned value**. It does:
   `7207908e…`, byte for byte, and the unmodified importer then regenerates the
   committed selected contract identically — 195 types, 2581 members, no diff.

   So **the pin was recovered and not changed**. That distinction is the whole
   point: re-pinning to whatever file happens to survive would make the hash a
   record of what was found rather than of what was chosen, and the next such
   loss would have nothing to check against. If a future source does *not*
   reconstruct the hash, the tool fails and says so, and the answer is a full
   257-type equivalence diff and a deliberate decision — not a new pin.

2. **The projection** is `tools/api-compat/mapping-rules.json`: the deterministic
   rules that turn a CLR element into a Lisp one, plus every declared exception
   with its reason. `docs/common-lisp-mapping.md` is the prose for the same
   rules.

3. **The image** is dumped by `tools/api-compat/dump-surface.lisp` straight out
   of a loaded CNA-Lisp: whatever it actually exports, with each symbol's kind,
   lambda list, setf-ability, class precedence and documentation.

4. **The verifier** compares them and classifies every selected type and member.
   Base classes are part of that comparison and are checked from the contract
   rather than from a rule: every selected type carries a `baseType`, so the
   default is to require the projected CLOS superclass and a mapping rule is only
   needed to declare a deliberate exception -- with a substantial reason, which is
   itself checked. `tools/api-compat/superclass-mutations.sh` breaks the
   projection six ways and requires a `wrong_superclass` diagnostic each time.

```sh
sbcl --script tools/api-compat/dump-surface.lisp
python3 tools/api-compat/verify.py --strict
```

## Classification

| Status | Meaning |
| --- | --- |
| `complete` | projected, with the shape the rules require |
| `partial` | projected, but part of the member is not reachable |
| `missing` | not projected |
| `not-applicable` | the member has no meaning in Common Lisp, with a declared reason |
| `externally-blocked` | something outside CNA-Lisp prevents it, with evidence |

### What `complete` means across configurations

`complete` and `partial` are about **reachability**, and reachability has to be
measured in some configuration or the words mean nothing. The rule, stated once
here rather than left implicit in individual mapping rows:

> A member is `complete` when it is reachable in **every supported
> installation of CNA-Lisp**, not merely in the fully equipped
> `REFERENCE_QUALIFIED` one. A member that a supported installation refuses is
> `partial`, and its reason must name what that installation is missing.

"Supported" is not a judgement call here; it is whatever the release standard
already gates on. **The no-shim lane is a supported configuration**: the `Native`
workflow runs the whole suite without `CNA_LISP_SHIM` on every commit, as a
required stage beside the one that supplies it, and the release standard requires
both. A configuration the project qualifies on every commit is one it supports.

The alternative rule — count a member complete if the reference configuration can
reach it — was rejected for two reasons, and neither is about which number looks
better. First, it would make the scoreboard claim something that is not so for
the ordinary case: the shim is deliberately **not shipped prebuilt**, because a
released CNA-Lisp must load with no C toolchain, so a member reported `complete`
would refuse in a default installation. This repository calls that class of
defect a *disagreement* and treats it as the worst kind. Second, the project had
already decided it in code before writing it down: `ModelBone.Transform` faced
the same by-value `MEMORY` aggregate and was deliberately routed around the shim,
and `src/graphics/model.lisp` says why in its own words — "the alternative was a
fifth shimmed route and a member that refuses without a C toolchain. This is the
same value written the same way, so the member is **complete rather than
packaging-dependent**." That sentence is this rule, applied.

**What it costs, applied uniformly: four members.** All four take a by-value
aggregate the System V AMD64 ABI classifies as `MEMORY` and all four go through
the optional private shim. Measured 2026-09-07 against ABI 0.23.0, with the shim
absent, all four refuse identically — same condition class
`CNA-NOT-SUPPORTED-ERROR`, same message naming `CNA_LISP_SHIM` and the command
that builds one, and all four readers still working — and with the shim loaded
all four succeed. Nothing distinguishes them, so nothing may classify them
differently:

| Member | Shimmed route | Aggregate | Status |
| --- | --- | --- | --- |
| `GraphicsDevice.Viewport` | `cna_graphics_device_set_viewport` | `CNA_Viewport`, 24 bytes | `partial` |
| `BasicEffect.World` | `cna_effect_matrices_set_world` | `CNA_Matrix`, 64 bytes | `partial` |
| `BasicEffect.View` | `cna_effect_matrices_set_view` | `CNA_Matrix`, 64 bytes | `partial` |
| `BasicEffect.Projection` | `cna_effect_matrices_set_projection` | `CNA_Matrix`, 64 bytes | `partial` |

The three `BasicEffect` matrices were reported `complete` until 2026-09-07 while
`GraphicsDevice.Viewport` was reported `partial` on the identical blocker. That
was the contradiction this rule exists to settle, and settling it moved three
members from `complete` to `partial`. **It is a classification correction, not a
regression**: no code changed, nothing that worked stopped working, and the
qualified configuration still exercises all four setters.

Their frontier category is `PACKAGING_ABI_BRIDGE_LIMIT` rather than
`LANGUAGE_PROJECTION_LIMIT`, because what must change to close them is a
packaging decision — ship the shim prebuilt, take `cffi-libffi` as a dependency,
or get a pointer-taking variant into a future CNA ABI — and not a decision about
the public API. Common Lisp expresses a `Matrix` perfectly well.

## Diagnostic categories

<!-- generated:diagnostic categories=18 --> categories are measured.
<!-- generated:absence categories=2 --> of them mean *absence*; the other
<!-- generated:disagreement categories=16 --> mean **disagreement** -- the
binding claiming something that is not so, or hiding something.

<!-- generated-block:diagnostic-categories -->
| Absence | Disagreement |
| --- | --- |
| `missing_type` | `wrong_package` |
| `missing_member` | `wrong_kind` |
|  | `wrong_superclass` |
|  | `wrong_generic_function_shape` |
|  | `wrong_lambda_list` |
|  | `wrong_accessor_mutability` |
|  | `overload_mapping_mismatch` |
|  | `event_mapping_mismatch` |
|  | `enum_mismatch` |
|  | `unexpected_public_symbol` |
|  | `private_implementation_leak` |
|  | `unmeasured_category` |
|  | `stale_mapping_rule` |
|  | `stale_declared_absence` |
|  | `uncategorised_absence` |
|  | `wrong_overload_shape` |
<!-- /generated-block:diagnostic-categories -->

Two of those exist because "zero diagnostics" was once true and still not enough.

`stale_mapping_rule` catches a rule keyed on a signature no member produces. Such
a rule is silently ignored, the default naming rule applies instead, and the
member is reported under a mapping nobody wrote. Adding the check found ten of
them at once, including five `SpriteBatch.Draw` overloads reported missing while
a rule for each sat in the file being skipped — and nine by-reference members
reported *complete* against the by-value function.

`wrong_overload_shape` catches a family collapsing onto one function without
saying how each overload is distinguished, and a declared keyword set that the
function does not actually accept. Both are checked against the real method
lambda lists in the image, not against the generic function's, which says `&key`
and stops.

It also catches the subtler version, which the first form of the check did not:
a mechanism that is *declared* and does not actually separate anything. Each
declared mechanism is applied to the member's contract signature to produce a
key — dispatch gives the parameter types, arity the count, keywords the keyword
set — and two overloads on one symbol with the same key have been accounted for
by nothing. Three real collapses were hiding behind that: `SpriteBatch.Draw`'s
two scale overloads and `GraphicsDevice.DrawUserIndexedPrimitives`'s two index
widths, each pair declaring identical keyword sets, and the sixteen
array-transform overloads, which declared `arity` when there are two overloads of
each arity. A rule may now declare a **discriminator** — an argument whose Lisp
type selects the overload, which is what a scale's realness and an index array's
element type do — or a **unified** collapse, for the case where nothing separates
two overloads and that is correct because their parameter types share one Common
Lisp representation and their bodies are identical.
`SpriteFont.MeasureString(String)` and `MeasureString(StringBuilder)` are the
worked example; `SpriteBatch.DrawString` needs both mechanisms at once.
`tools/api-compat/overload-mutations.sh` proves each refusal.

**Strict verification is allowed to be red while real surface is missing.** It is
never allowed to be green because an allowlist hid something: a public symbol
that is neither a mapped XNA member nor a declared extension is a diagnostic, and
so is a category nothing measures.

For a qualified milestone every disagreement category must be zero, every type
claimed complete must have no local diagnostics, and the remaining red must be
genuine absence.

## Current measurement

<!-- generated:selected types=210 -->
<!-- generated:selected members=2723 -->
<!-- generated:complete types=188 -->
<!-- generated:partial types=22 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=2185 -->
<!-- generated:partial members=30 -->
<!-- generated:missing members=20 -->
<!-- generated:not-applicable members=488 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 210 types, 2723 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **188** |
| Types partial | **22** |
| Types missing | **0** |
| Members complete | **2185** |
| Members partial | **30** |
| Members missing | **20** |
| Members not applicable | **488** |
| **Disagreement diagnostics** | **0** |
<!-- /generated-block:scoreboard -->

Every remaining diagnostic is an absence. Nothing implemented disagrees with the
contract, nothing private has leaked into a public package, no exported symbol is
unaccounted for, no mapping rule names a member that does not exist, and every
collapsed overload family says how each of its overloads is expressed.

<!-- generated-block:per-type-table -->
| Type | Status | complete | partial | missing | n/a |
| --- | --- | ---: | ---: | ---: | ---: |
| `M.X.F.Game` | **partial** | 33 | 0 | 3 | 2 |
| `M.X.F.GameTime` | **complete** | 6 | 0 | 0 | 0 |
| `M.X.F.IGameComponent` | **complete** | 1 | 0 | 0 | 0 |
| `M.X.F.IUpdateable` | **complete** | 5 | 0 | 0 | 0 |
| `M.X.F.IDrawable` | **complete** | 5 | 0 | 0 | 0 |
| `M.X.F.GameComponent` | **complete** | 11 | 0 | 0 | 3 |
| `M.X.F.DrawableGameComponent` | **complete** | 11 | 0 | 0 | 2 |
| `M.X.F.GameComponentCollection` | **partial** | 2 | 0 | 1 | 4 |
| `M.X.F.GameComponentCollectionEventArgs` | **complete** | 2 | 0 | 0 | 0 |
| `M.X.F.LaunchParameters` | **complete** | 1 | 0 | 0 | 0 |
| `M.X.F.GameWindow` | **partial** | 11 | 0 | 7 | 2 |
| `M.X.F.TitleContainer` | **partial** | 0 | 1 | 0 | 0 |
| `M.X.F.Graphics.GraphicsProfile` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Graphics.ClearOptions` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Graphics.PresentInterval` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.Graphics.GraphicsDeviceStatus` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Graphics.DisplayMode` | **complete** | 5 | 0 | 0 | 1 |
| `M.X.F.Graphics.PresentationParameters` | **partial** | 12 | 0 | 1 | 0 |
| `M.X.F.Graphics.GraphicsAdapter` | **partial** | 13 | 4 | 1 | 0 |
| `M.X.F.Graphics.DisplayModeCollection` | **complete** | 2 | 0 | 0 | 0 |
| `M.X.F.GraphicsDeviceManager` | **partial** | 26 | 3 | 0 | 1 |
| `M.X.F.Content.ContentManager` | **partial** | 6 | 1 | 0 | 3 |
| `M.X.F.Graphics.RenderTargetCube` | **complete** | 7 | 0 | 0 | 1 |
| `M.X.F.Graphics.RenderTargetBinding` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.Color` | **complete** | 161 | 0 | 0 | 4 |
| `M.X.F.Point` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Rectangle` | **complete** | 24 | 0 | 0 | 9 |
| `M.X.F.Vector2` | **complete** | 50 | 0 | 0 | 27 |
| `M.X.F.Vector3` | **complete** | 60 | 0 | 0 | 28 |
| `M.X.F.Vector4` | **complete** | 56 | 0 | 0 | 29 |
| `M.X.F.MathHelper` | **complete** | 19 | 0 | 0 | 0 |
| `M.X.F.Quaternion` | **complete** | 35 | 0 | 0 | 20 |
| `M.X.F.Matrix` | **complete** | 70 | 0 | 0 | 37 |
| `M.X.F.Plane` | **complete** | 18 | 0 | 0 | 12 |
| `M.X.F.ContainmentType` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.PlaneIntersectionType` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Ray` | **complete** | 9 | 0 | 0 | 7 |
| `M.X.F.BoundingBox` | **complete** | 20 | 0 | 0 | 13 |
| `M.X.F.BoundingSphere` | **complete** | 19 | 0 | 0 | 14 |
| `M.X.F.BoundingFrustum` | **complete** | 22 | 0 | 0 | 11 |
| `M.X.F.Curve` | **complete** | 11 | 0 | 0 | 0 |
| `M.X.F.CurveKey` | **complete** | 12 | 0 | 0 | 3 |
| `M.X.F.CurveKeyCollection` | **complete** | 13 | 0 | 0 | 0 |
| `M.X.F.CurveContinuity` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.CurveLoopType` | **complete** | 5 | 0 | 0 | 1 |
| `M.X.F.CurveTangent` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.PlayerIndex` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.DisplayOrientation` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.Graphics.GraphicsResource` | **complete** | 6 | 0 | 0 | 3 |
| `M.X.F.Graphics.GraphicsDevice` | **partial** | 51 | 1 | 3 | 2 |
| `M.X.F.Graphics.Viewport` | **complete** | 13 | 0 | 0 | 1 |
| `M.X.F.Graphics.Texture` | **complete** | 2 | 0 | 0 | 0 |
| `M.X.F.Graphics.Texture2D` | **partial** | 11 | 4 | 0 | 1 |
| `M.X.F.Graphics.RenderTarget2D` | **complete** | 8 | 0 | 0 | 1 |
| `M.X.F.Graphics.RenderTargetUsage` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Graphics.DepthFormat` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.Graphics.SpriteBatch` | **complete** | 20 | 0 | 0 | 1 |
| `M.X.F.Graphics.SpriteFont` | **complete** | 6 | 0 | 0 | 0 |
| `M.X.F.Graphics.SpriteSortMode` | **complete** | 5 | 0 | 0 | 1 |
| `M.X.F.Graphics.SpriteEffects` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Graphics.SurfaceFormat` | **complete** | 20 | 0 | 0 | 1 |
| `M.X.F.Graphics.Blend` | **complete** | 13 | 0 | 0 | 1 |
| `M.X.F.Graphics.BlendFunction` | **complete** | 5 | 0 | 0 | 1 |
| `M.X.F.Graphics.ColorWriteChannels` | **complete** | 6 | 0 | 0 | 1 |
| `M.X.F.Graphics.CompareFunction` | **complete** | 8 | 0 | 0 | 1 |
| `M.X.F.Graphics.StencilOperation` | **complete** | 8 | 0 | 0 | 1 |
| `M.X.F.Graphics.CullMode` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Graphics.FillMode` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Graphics.TextureAddressMode` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Graphics.TextureFilter` | **complete** | 9 | 0 | 0 | 1 |
| `M.X.F.Graphics.BlendState` | **complete** | 17 | 0 | 0 | 1 |
| `M.X.F.Graphics.DepthStencilState` | **complete** | 20 | 0 | 0 | 1 |
| `M.X.F.Graphics.RasterizerState` | **complete** | 10 | 0 | 0 | 1 |
| `M.X.F.Graphics.SamplerState` | **complete** | 14 | 0 | 0 | 1 |
| `M.X.F.Graphics.SamplerStateCollection` | **complete** | 1 | 0 | 0 | 0 |
| `M.X.F.Graphics.TextureCollection` | **complete** | 1 | 0 | 0 | 0 |
| `M.X.F.Graphics.VertexElementFormat` | **complete** | 12 | 0 | 0 | 1 |
| `M.X.F.Graphics.VertexElementUsage` | **complete** | 13 | 0 | 0 | 1 |
| `M.X.F.Graphics.VertexElement` | **complete** | 7 | 0 | 0 | 3 |
| `M.X.F.Graphics.VertexDeclaration` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.Graphics.IVertexType` | **complete** | 1 | 0 | 0 | 0 |
| `M.X.F.Graphics.VertexPositionColor` | **complete** | 6 | 0 | 0 | 3 |
| `M.X.F.Graphics.VertexPositionTexture` | **complete** | 6 | 0 | 0 | 3 |
| `M.X.F.Graphics.VertexPositionColorTexture` | **complete** | 7 | 0 | 0 | 3 |
| `M.X.F.Graphics.VertexPositionNormalTexture` | **complete** | 7 | 0 | 0 | 3 |
| `M.X.F.Graphics.BufferUsage` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Graphics.IndexElementSize` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Graphics.SetDataOptions` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Graphics.PrimitiveType` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.Graphics.VertexBuffer` | **complete** | 11 | 0 | 0 | 1 |
| `M.X.F.Graphics.DynamicVertexBuffer` | **complete** | 6 | 0 | 0 | 0 |
| `M.X.F.Graphics.IndexBuffer` | **complete** | 11 | 0 | 0 | 1 |
| `M.X.F.Graphics.DynamicIndexBuffer` | **complete** | 6 | 0 | 0 | 0 |
| `M.X.F.Graphics.VertexBufferBinding` | **complete** | 7 | 0 | 0 | 0 |
| `M.X.F.Graphics.Effect` | **partial** | 5 | 0 | 1 | 2 |
| `M.X.F.Graphics.EffectTechnique` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.EffectTechniqueCollection` | **complete** | 4 | 0 | 0 | 0 |
| `M.X.F.Graphics.EffectPass` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.EffectPassCollection` | **complete** | 4 | 0 | 0 | 0 |
| `M.X.F.Graphics.EffectParameter` | **partial** | 50 | 0 | 1 | 0 |
| `M.X.F.Graphics.EffectParameterCollection` | **complete** | 5 | 0 | 0 | 0 |
| `M.X.F.Graphics.EffectAnnotation` | **complete** | 14 | 0 | 0 | 0 |
| `M.X.F.Graphics.EffectAnnotationCollection` | **complete** | 4 | 0 | 0 | 0 |
| `M.X.F.Graphics.EffectParameterClass` | **complete** | 5 | 0 | 0 | 1 |
| `M.X.F.Graphics.EffectParameterType` | **complete** | 10 | 0 | 0 | 1 |
| `M.X.F.Graphics.IEffectMatrices` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.IEffectLights` | **complete** | 6 | 0 | 0 | 0 |
| `M.X.F.Graphics.IEffectFog` | **complete** | 4 | 0 | 0 | 0 |
| `M.X.F.Graphics.DirectionalLight` | **partial** | 4 | 0 | 1 | 0 |
| `M.X.F.Graphics.BasicEffect` | **partial** | 21 | 3 | 1 | 1 |
| `M.X.F.Graphics.AlphaTestEffect` | **complete** | 15 | 0 | 0 | 2 |
| `M.X.F.Graphics.DualTextureEffect` | **complete** | 14 | 0 | 0 | 2 |
| `M.X.F.Graphics.SkinnedEffect` | **complete** | 25 | 0 | 0 | 2 |
| `M.X.F.Graphics.EnvironmentMapEffect` | **complete** | 22 | 0 | 0 | 2 |
| `M.X.F.Graphics.TextureCube` | **partial** | 2 | 6 | 0 | 1 |
| `M.X.F.Graphics.CubeMapFace` | **complete** | 6 | 0 | 0 | 1 |
| `M.X.F.Graphics.PackedVector.Alpha8` | **complete** | 5 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Bgr565` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Bgra4444` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Bgra5551` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Byte4` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.HalfSingle` | **complete** | 5 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.HalfVector2` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.HalfVector4` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.NormalizedByte2` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.NormalizedByte4` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.NormalizedShort2` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.NormalizedShort4` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Rg32` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Rgba1010102` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Rgba64` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Short2` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Graphics.PackedVector.Short4` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Input.Keyboard` | **complete** | 2 | 0 | 0 | 0 |
| `M.X.F.Input.KeyboardState` | **complete** | 6 | 0 | 0 | 3 |
| `M.X.F.Input.KeyState` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Input.Keys` | **complete** | 160 | 0 | 0 | 1 |
| `M.X.F.Input.Touch.TouchPanel` | **complete** | 8 | 0 | 0 | 1 |
| `M.X.F.Input.Touch.TouchCollection` | **complete** | 15 | 0 | 0 | 0 |
| `M.X.F.Input.Touch.TouchLocation` | **complete** | 8 | 0 | 0 | 4 |
| `M.X.F.Input.Touch.TouchLocationState` | **complete** | 4 | 0 | 0 | 1 |
| `M.X.F.Input.Touch.TouchPanelCapabilities` | **complete** | 2 | 0 | 0 | 0 |
| `M.X.F.Input.Touch.GestureSample` | **complete** | 7 | 0 | 0 | 0 |
| `M.X.F.Input.Touch.GestureType` | **complete** | 11 | 0 | 0 | 1 |
| `M.X.F.Input.GamePad` | **complete** | 4 | 0 | 0 | 0 |
| `M.X.F.Input.GamePadState` | **complete** | 11 | 0 | 0 | 4 |
| `M.X.F.Input.GamePadButtons` | **complete** | 13 | 0 | 0 | 4 |
| `M.X.F.Input.GamePadDPad` | **complete** | 6 | 0 | 0 | 4 |
| `M.X.F.Input.GamePadThumbSticks` | **complete** | 4 | 0 | 0 | 4 |
| `M.X.F.Input.GamePadTriggers` | **complete** | 4 | 0 | 0 | 4 |
| `M.X.F.Input.GamePadCapabilities` | **complete** | 26 | 0 | 0 | 0 |
| `M.X.F.Input.Buttons` | **complete** | 25 | 0 | 0 | 1 |
| `M.X.F.Input.GamePadType` | **complete** | 10 | 0 | 0 | 1 |
| `M.X.F.Input.GamePadDeadZone` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Input.Mouse` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Input.MouseState` | **complete** | 10 | 0 | 0 | 4 |
| `M.X.F.Input.ButtonState` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Audio.SoundEffect` | **partial** | 15 | 1 | 0 | 1 |
| `M.X.F.Audio.SoundEffectInstance` | **partial** | 13 | 1 | 0 | 2 |
| `M.X.F.Audio.DynamicSoundEffectInstance` | **partial** | 8 | 1 | 0 | 1 |
| `M.X.F.Audio.AudioListener` | **complete** | 5 | 0 | 0 | 0 |
| `M.X.F.Audio.AudioEmitter` | **complete** | 6 | 0 | 0 | 0 |
| `M.X.F.Audio.SoundState` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Audio.AudioChannels` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Audio.NoAudioHardwareException` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Audio.InstancePlayLimitException` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Audio.Microphone` | **partial** | 13 | 1 | 0 | 1 |
| `M.X.F.Audio.MicrophoneState` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Audio.NoMicrophoneConnectedException` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.Model` | **partial** | 7 | 1 | 0 | 0 |
| `M.X.F.Graphics.ModelBone` | **complete** | 5 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelBoneCollection` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelBoneCollection+Enumerator` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelMesh` | **partial** | 6 | 1 | 0 | 0 |
| `M.X.F.Graphics.ModelMeshCollection` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelMeshCollection+Enumerator` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelMeshPart` | **partial** | 7 | 1 | 0 | 0 |
| `M.X.F.Graphics.ModelMeshPartCollection` | **complete** | 1 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelMeshPartCollection+Enumerator` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelEffectCollection` | **complete** | 1 | 0 | 0 | 0 |
| `M.X.F.Graphics.ModelEffectCollection+Enumerator` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Media.MediaPlayer` | **complete** | 20 | 0 | 0 | 0 |
| `M.X.F.Media.MediaState` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Media.MediaQueue` | **complete** | 4 | 0 | 0 | 0 |
| `M.X.F.Media.Song` | **complete** | 15 | 0 | 0 | 5 |
| `M.X.F.Media.SongCollection` | **complete** | 4 | 0 | 0 | 2 |
| `M.X.F.Media.VisualizationData` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Media.MediaLibrary` | **complete** | 16 | 0 | 0 | 1 |
| `M.X.F.Media.MediaSource` | **complete** | 3 | 0 | 0 | 1 |
| `M.X.F.Media.MediaSourceType` | **complete** | 2 | 0 | 0 | 1 |
| `M.X.F.Media.Album` | **complete** | 12 | 0 | 0 | 5 |
| `M.X.F.Media.AlbumCollection` | **complete** | 4 | 0 | 0 | 2 |
| `M.X.F.Media.Artist` | **complete** | 7 | 0 | 0 | 5 |
| `M.X.F.Media.ArtistCollection` | **complete** | 4 | 0 | 0 | 2 |
| `M.X.F.Media.Genre` | **complete** | 7 | 0 | 0 | 5 |
| `M.X.F.Media.GenreCollection` | **complete** | 4 | 0 | 0 | 2 |
| `M.X.F.Media.Playlist` | **complete** | 7 | 0 | 0 | 5 |
| `M.X.F.Media.PlaylistCollection` | **complete** | 4 | 0 | 0 | 2 |
| `M.X.F.Media.Picture` | **complete** | 11 | 0 | 0 | 5 |
| `M.X.F.Media.PictureAlbum` | **complete** | 8 | 0 | 0 | 5 |
| `M.X.F.Media.PictureCollection` | **complete** | 4 | 0 | 0 | 2 |
| `M.X.F.Media.PictureAlbumCollection` | **complete** | 4 | 0 | 0 | 2 |
| `M.X.F.GameServiceContainer` | **complete** | 4 | 0 | 0 | 0 |
| `M.X.F.IGraphicsDeviceManager` | **complete** | 3 | 0 | 0 | 0 |
| `M.X.F.Graphics.IGraphicsDeviceService` | **complete** | 5 | 0 | 0 | 0 |
| `M.X.F.GraphicsDeviceInformation` | **complete** | 6 | 0 | 0 | 1 |
| `M.X.F.PreparingDeviceSettingsEventArgs` | **complete** | 2 | 0 | 0 | 0 |
| `M.X.F.Storage.StorageDevice` | **complete** | 12 | 0 | 0 | 0 |
| `M.X.F.Storage.StorageContainer` | **complete** | 18 | 0 | 0 | 1 |
| `M.X.F.Storage.StorageDeviceNotConnectedException` | **complete** | 3 | 0 | 0 | 1 |
<!-- /generated-block:per-type-table -->

### Not applicable, and why so many

348 members are classified not applicable, and most of them are one thing: the
**by-reference overloads** of the value types. `Vector3.Add(ref a, ref b, out r)`
exists in XNA so a caller can avoid copying a value type into a call and can
write into storage it already has. The value it computes is the by-value
overload's. Common Lisp passes a reference already, so `vector3-add` *is* that
contract, and projecting the ref form would be a second name for one operation.

The rest are the CLR universals -- `ToString`, `GetHashCode`, `Equals(Object)`,
`op_Inequality`, `Finalize` -- and the protected `Dispose(bool)` pattern, which
exists to tell a finalizer call from an explicit one and has nothing to
distinguish in a binding with no finalizers.

### The one partial member

`GraphicsDevice.Viewport`: the reader is unconditional, the setter needs a build
of the private shim. `cna_graphics_device_set_viewport` takes `CNA_Viewport` (24
bytes) by value, which the System V AMD64 ABI classifies MEMORY, and CFFI cannot
pass a MEMORY-class aggregate without `cffi-libffi`. That refusal is proved by
`tools/native-abi/generate.py` rather than asserted, and the generator emits the
one-function shim that answers it; see `docs/native-abi.md`.

The member is `partial` and not `complete` because a *released* CNA-Lisp must
load with no C toolchain present, so the shim is optional. `CNA_LISP_SHIM` names
a build of it; without one the setter refuses with a condition naming the
variable, the command that builds the shim and the reason. That is a packaging
limit, and it is not an external blocker: the remedy is in this repository and it
is already written.

### No selected type is missing

`types missing` is zero: every type in the selection is projected. Five are
`partial`, which is a statement about members, not about the type existing.
`Graphics.GraphicsResource` -- the last one that was wholly absent -- is the real
base class now, with its name, its `Disposing` event and its device
back-reference.

<!-- generated-block:partial-frontier -->
| Type | missing members | partial members |
| --- | ---: | ---: |
| `M.X.F.GameWindow` | 7 | 0 |
| `M.X.F.Game` | 3 | 0 |
| `M.X.F.Graphics.GraphicsDevice` | 3 | 1 |
| `M.X.F.GameComponentCollection` | 1 | 0 |
| `M.X.F.Graphics.PresentationParameters` | 1 | 0 |
| `M.X.F.Graphics.GraphicsAdapter` | 1 | 4 |
| `M.X.F.Graphics.Effect` | 1 | 0 |
| `M.X.F.Graphics.EffectParameter` | 1 | 0 |
| `M.X.F.Graphics.DirectionalLight` | 1 | 0 |
| `M.X.F.Graphics.BasicEffect` | 1 | 3 |
| `M.X.F.TitleContainer` | 0 | 1 |
| `M.X.F.GraphicsDeviceManager` | 0 | 3 |
| `M.X.F.Content.ContentManager` | 0 | 1 |
| `M.X.F.Graphics.Texture2D` | 0 | 4 |
| `M.X.F.Graphics.TextureCube` | 0 | 6 |
| `M.X.F.Audio.SoundEffect` | 0 | 1 |
| `M.X.F.Audio.SoundEffectInstance` | 0 | 1 |
| `M.X.F.Audio.DynamicSoundEffectInstance` | 0 | 1 |
| `M.X.F.Audio.Microphone` | 0 | 1 |
| `M.X.F.Graphics.Model` | 0 | 1 |
| `M.X.F.Graphics.ModelMesh` | 0 | 1 |
| `M.X.F.Graphics.ModelMeshPart` | 0 | 1 |
<!-- /generated-block:partial-frontier -->

The counts in that table are the real remaining surface, and the table is where to
read it: a sentence here naming which type is largest has gone stale twice, both
times because the closure it described had landed. The render-target family,
`System.IO.Stream`, the content manager, the device-settings types and the
component engine were each named here as remaining after each had closed.

## Why each non-complete member is non-complete

Every missing and every partial member carries a prose reason, one per member,
in `tools/api-compat/mapping-rules.json` -- `unimplemented` for the missing and
`member_overrides` for the partial. Each names the CNA route it was read from or
the IL fact it rests on, and they are measurements rather than claims: a
route-by-route re-audit rewrote ten of them, three of which had said "CNA has no
route" about a route that existed, and found two members that were not blocked at
all.

Reasons alone do not add up, though. The question a release has to answer is not
how many members are missing but whether any of them is missing for no better
reason than that nobody has done it. So each also carries a **category**, the set
is closed, and `verify.py` requires the mapping to cover the frontier exactly --
an uncategorised non-complete member is an `uncategorised_absence` diagnostic,
and so is a category left behind by a member that has since been completed.

<!-- generated-block:frontier-categories -->
| Category | Members | What it means |
| --- | ---: | --- |
| `LANGUAGE_PROJECTION_LIMIT` | **3** | The Common Lisp projection cannot express the member, or the type it needs has no counterpart a Lisp program could use safely. |
| `PACKAGING_ABI_BRIDGE_LIMIT` | **4** | The projection and every admitted CNA route exist and work, and the member is reachable only in an installation that has built an optional compiled artifact. |
| `CNA_ADMITTED_ABI_LIMIT` | **40** | No admitted CNA ABI can represent the member. |
| `PUBLIC_OBJECT_MODEL_CLOSURE` | **0** | Implementable against every admitted CNA ABI, but only as a new closure in this binding's object model rather than as a member. |
| `DEPENDENCY_NOT_SELECTED` | **1** | Blocked on a type that is not in the selected profile. |
| `QUALIFICATION_LIMIT` | **2** | Implemented, but some part of it cannot be evidenced, so it is not claimed complete. |
| `IMPLEMENTABLE_BUT_LOW_VALUE` | **0** | Nothing blocks it and it is not worth the surface. |
| `IMPLEMENTABLE_AND_HIGH_VALUE` | **0** | Nothing blocks it and it should be done next. |
<!-- /generated-block:frontier-categories -->

<!-- generated:high-value frontier members=0 --> members are in
`IMPLEMENTABLE_AND_HIGH_VALUE`. **That row was zero when the release statement
rested on it and is not any more**: the 2026-09-07 audit re-read all 29 partial
reasons against the current admitted set and two did not survive --
`RenderTargetBinding.CubeMapFace` and `Game.Content`. The first has since been
implemented and is complete, which is why the partial count is 28 and
`RenderTargetBinding` is a complete type; `Game.Content` is the entry that
remains, and it is still partial. `NEXT.md` has the measurement and names
the implementation task. The remaining empty rows are rendered rather than
dropped, because their being empty is the claim.

**Two of these categories were named after CNA 0.21.0 and are not any more.**
`CNA_ADMITTED_ABI_LIMIT` was `CNA_0_21_ABI_LIMIT` and `PUBLIC_OBJECT_MODEL_CLOSURE`
said "implementable against 0.21.0". Both were exactly right while the binding
admitted one version, and both became the wrong abstraction the moment the
admitted set became `{0.21.0, 0.22.0}`: a category describes the compatibility
policy, and the policy is about the set rather than about its oldest member. A
member that only one admitted version could express is as unrepresentable as one
no version can express, because the binding promises the same public surface
against every version it admits.

**A member's own reason may still name a version, and several do.** "0.21.0 lacks
route X" is a fact about a version that is still admitted, and that fact alone is
enough to stop a uniform implementation, so it belongs in the entry where it can
be checked against a header. What it may not do is name the category. No member's
status changed with the rename; only the name did.

The categories are not excuses of equal weight. `CNA_ADMITTED_ABI_LIMIT` holds the
large majority, and most of that is one shape repeated: XNA's protected
`On<Event>` raisers, thirteen of them across `Game`, `GameWindow` and
`GraphicsDeviceManager`. In XNA the raiser *is* what raises the event, and a
subclass overrides it to stand between the framework and the handlers. CNA raises
the events itself and reaches Lisp through one callback per subscribed handler,
so an override here could notify but never suppress -- there is no moment at
which this binding decides whether to raise. Projecting them would give a
consumer a method that looks like an interception point and is not.

`PUBLIC_OBJECT_MODEL_CLOSURE` is the one category that is this binding's own work
rather than a limit imposed on it, and **it is empty**. It is the first category
to have been emptied, and the row is rendered rather than dropped because its
being empty is the claim.

It held three members and each was a closure rather than a member.
`Game.Services` needed `GameServiceContainer` in the selection and a managed
container that stays in step with CNA's two canonical services; that landed with
the services closure. `GraphicsDevice`'s constructor and `Dispose` needed a
second kind of `GraphicsDevice` -- an owned one with a handle of its own beside
the parent-owned facade -- and that is what the owned-device closure did. The
category emptying is the measure of it: the object model represents both native
ownership graphs XNA permits, rather than one of them and a note about the other.

## Behaviour, as distinct from structure

Structure says a member exists with the right shape. It says nothing about what
the member *does*. That is the behaviour corpus in `tests/behavior/corpus.lisp`,
which records the origin of every observation:

| Origin | Meaning |
| --- | --- |
| `:xna-derived` | derived from the selected Microsoft XNA contract |
| `:abi-derived` | a fact about the CNA C ABI's own published contract |
| `:mapping` | a CNA-Lisp mapping decision |

The separation is the point. **CNA is never the oracle for what XNA does**: a
runtime cannot prove its own compatibility. An `:xna-derived` observation that
CNA also answers may be cross-checked against CNA; it is never established by it.

## Native ABI

<!-- generated:bound native functions=871 -->
<!-- generated:bound native structs=75 -->
<!-- generated:bound native struct fields=555 -->
<!-- generated:bound native constants=540 -->
<!-- generated:bound native callbacks=14 -->
<!-- generated:by-value aggregates=6 -->
<!-- generated:shimmed routes=4 -->
<!-- generated:abi version encoded=5888 -->

<!-- generated-block:native-abi-summary -->
| | |
| --- | --- |
| Bound functions | 871 |
| Bound structs | 75 |
| Bound struct fields | 555 |
| Bound constants | 540 |
| Bound callback typedefs | 14 |
| By-value aggregates admitted | 6 |
| Routes proved unbindable, and shimmed | 4 |
| Admitted ABI versions | 0.21.0 (encoded 5376), 0.22.0 (encoded 5632), 0.23.0 (encoded 5888) |
| Version constant in the generated layer | 0.23.0 (encoded 5888) |
<!-- /generated-block:native-abi-summary -->

See `docs/native-abi.md` for what the C compiler proves about each of those.
