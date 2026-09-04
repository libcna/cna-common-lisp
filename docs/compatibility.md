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

2. **The projection** is `tools/api-compat/mapping-rules.json`: the deterministic
   rules that turn a CLR element into a Lisp one, plus every declared exception
   with its reason. `docs/common-lisp-mapping.md` is the prose for the same
   rules.

3. **The image** is dumped by `tools/api-compat/dump-surface.lisp` straight out
   of a loaded CNA-Lisp: whatever it actually exports, with each symbol's kind,
   lambda list, setf-ability, class precedence and documentation.

4. **The verifier** compares them and classifies every selected type and member.

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

## Diagnostic categories

Fourteen categories are measured. Two of them mean *absence*; the other twelve
mean **disagreement** -- the binding claiming something that is not so, or hiding
something.

| Absence | Disagreement |
| --- | --- |
| `missing_type` | `wrong_package`, `wrong_kind`, `wrong_superclass` |
| `missing_member` | `wrong_generic_function_shape`, `wrong_lambda_list` |
| | `wrong_accessor_mutability`, `overload_mapping_mismatch` |
| | `event_mapping_mismatch`, `enum_mismatch` |
| | `unexpected_public_symbol`, `private_implementation_leak` |
| | `unmeasured_category`, `stale_mapping_rule` |
| | `wrong_overload_shape` |

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

**Strict verification is allowed to be red while real surface is missing.** It is
never allowed to be green because an allowlist hid something: a public symbol
that is neither a mapped XNA member nor a declared extension is a diagnostic, and
so is a category nothing measures.

For a qualified milestone every disagreement category must be zero, every type
claimed complete must have no local diagnostics, and the remaining red must be
genuine absence.

## Current measurement

<!-- generated:selected types=101 -->
<!-- generated:selected members=1846 -->
<!-- generated:complete types=96 -->
<!-- generated:partial types=5 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1381 -->
<!-- generated:partial members=1 -->
<!-- generated:missing members=85 -->
<!-- generated:not-applicable members=379 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 101 types, 1846 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **96** |
| Types partial | **5** |
| Types missing | **0** |
| Members complete | **1381** |
| Members partial | **1** |
| Members missing | **85** |
| Members not applicable | **379** |
| **Disagreement diagnostics** | **0** |
<!-- /generated-block:scoreboard -->

Every remaining diagnostic is an absence. Nothing implemented disagrees with the
contract, nothing private has leaked into a public package, no exported symbol is
unaccounted for, no mapping rule names a member that does not exist, and every
collapsed overload family says how each of its overloads is expressed.

<!-- generated-block:per-type-table -->
| Type | Status | complete | partial | missing | n/a |
| --- | --- | ---: | ---: | ---: | ---: |
| `M.X.F.Game` | **partial** | 28 | 0 | 8 | 2 |
| `M.X.F.GameTime` | **complete** | 6 | 0 | 0 | 0 |
| `M.X.F.GraphicsDeviceManager` | **partial** | 13 | 0 | 16 | 1 |
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
| `M.X.F.Graphics.GraphicsDevice` | **partial** | 13 | 1 | 41 | 2 |
| `M.X.F.Graphics.Viewport` | **complete** | 13 | 0 | 0 | 1 |
| `M.X.F.Graphics.Texture` | **complete** | 2 | 0 | 0 | 0 |
| `M.X.F.Graphics.Texture2D` | **partial** | 3 | 0 | 12 | 1 |
| `M.X.F.Graphics.SpriteBatch` | **partial** | 12 | 0 | 8 | 1 |
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
| `M.X.F.Graphics.GraphicsDevice` | 41 | 1 |
| `M.X.F.GraphicsDeviceManager` | 16 | 0 |
| `M.X.F.Graphics.Texture2D` | 12 | 0 |
| `M.X.F.Game` | 8 | 0 |
| `M.X.F.Graphics.SpriteBatch` | 8 | 0 |
<!-- /generated-block:partial-frontier -->

The counts in that table are the real remaining surface. The largest by far is
`GraphicsDevice`'s own drawing, render-target, vertex- and index-buffer surface;
the rest is `System.IO.Stream` and the `Texture2D` members that need it,
`SpriteFont` and `SpriteBatch.DrawString`, the two `Effect`-bearing `Begin`
overloads, and the parts of `Game` and `GraphicsDeviceManager` that need a
component engine or a device-settings type.

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

<!-- generated:bound native functions=124 -->
<!-- generated:bound native structs=33 -->
<!-- generated:bound native struct fields=248 -->
<!-- generated:bound native constants=420 -->
<!-- generated:bound native callbacks=4 -->
<!-- generated:by-value aggregates=3 -->
<!-- generated:shimmed routes=1 -->
<!-- generated:abi version encoded=5376 -->

<!-- generated-block:native-abi-summary -->
| | |
| --- | --- |
| Bound functions | 124 |
| Bound structs | 33 |
| Bound struct fields | 248 |
| Bound constants | 420 |
| Bound callback typedefs | 4 |
| By-value aggregates admitted | 3 |
| Routes proved unbindable, and shimmed | 1 |
| Admitted ABI versions | 0.21.0 only (encoded 5376) |
<!-- /generated-block:native-abi-summary -->

See `docs/native-abi.md` for what the C compiler proves about each of those.
