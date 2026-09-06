# XNA implementation provenance

`xna40-selected-contract.json` pins the **public metadata** of the selected
profile: which types and members exist, and with what signatures. That is enough
to measure structure. It says nothing about what a member *does*.

This file pins the authority CNA-Lisp derives **behaviour** from: the original
Microsoft XNA Framework 4.0 Windows assembly, identified by exact SHA-256 and
read as disassembled IL.

No Microsoft binary and no disassembly is stored in this repository or
distributed with it. Only hashes, identities, and the behavioural facts derived
from them are committed.

## Pinned assemblies

The XNA 4.0 Windows profile is more than one assembly, and the types this
projection covers are spread across four of them.

| Assembly | Bytes | SHA-256 |
| --- | ---: | --- |
| `Microsoft.Xna.Framework.dll` 4.0.0.0 | 679424 | `38e7093f52d7474bbc6256906519781a1210d7da50a1c667b52716fcf49ca130` |
| `Microsoft.Xna.Framework.Graphics.dll` 4.0.0.0 | 427520 | `560080fc39021c611ca9d076dcebed312faf6d7d1413c2dc523683ea635e9f55` |
| `Microsoft.Xna.Framework.Game.dll` 4.0.0.0 | 74752 | `b5dffdd8125abef2a4507ba4e1d2f11062143f0a63d48fe4f298b95ad746a1f0` |
| `Microsoft.Xna.Framework.Storage.dll` 4.0.0.0 | 20992 | `798f678e9ae3d9afc3bed66c30123bc9634fb923b6d200188344b618e608cbb8` |

All four carry the public key token `842cf8be1de50553`.

`Microsoft.Xna.Framework.dll` holds the value types -- `Color`, `Vector*`,
`Matrix`, `Quaternion`, `Plane`, the bounding volumes, `Curve`, `MathHelper` --
and `ContentManager` and `TitleContainer`.
`Microsoft.Xna.Framework.Graphics.dll` holds `GraphicsResource`, `Texture2D`,
`SpriteBatch` and the four graphics state objects.
`Microsoft.Xna.Framework.Game.dll` holds `Game`, `GameComponent` and
`GraphicsDeviceManager`. A behavioural question about a type is answered by
reading the assembly that declares it.

`Microsoft.Xna.Framework.Storage.dll` holds `StorageDevice`, `StorageContainer`
and `StorageDeviceNotConnectedException`, and its two private `IAsyncResult`
implementations -- which is where the answer to "what is XNA's async actually
doing" lives.

**Two assemblies have been added to this table after the fact, and that is worth
recording rather than quietly fixing.** Behavioural claims already rested on it --
that `Game.Run` sets `inRun` *after* `Initialize()` returns, which is why a
component added in `LoadContent` is never initialized -- and the handoff already
called it "the pinned Game assembly" while this file pinned only two. A claim
whose authority is not named here is not sourced, so the authority is now named.

The Storage assembly was added the same way and *before* any claim rested on it:
the Storage closure's first act was to notice that its IL was not pinned here and
pin it, rather than to read it and pin it afterwards. That is the order this
paragraph exists to ask for.

An assembly is located **by hash, never by filename**: any copy whose SHA-256
matches is equally authoritative, and any copy whose SHA-256 does not match is
not. Both hashes are pinned by the mature CNA-Ruby and CNA-Go bindings, which is
where this project's confidence that they are the right binaries comes from.

## Disassembly

Disassembled with `ikdasm` (Debian package `ikdasm`). The disassembly used for
this work has SHA-256
`cbfdba082a3ab09e0b1ef604f277fedb23852cae0563a10b7066fd04b30d26d4`; it is a
derived artefact and is not committed.

```sh
sha256sum /path/to/Microsoft.Xna.Framework.dll
# must print 38e7093f52d7474bbc6256906519781a1210d7da50a1c667b52716fcf49ca130
ikdasm /path/to/Microsoft.Xna.Framework.dll > Microsoft.Xna.Framework.il

sha256sum /path/to/Microsoft.Xna.Framework.Graphics.dll
# must print 560080fc39021c611ca9d076dcebed312faf6d7d1413c2dc523683ea635e9f55
ikdasm /path/to/Microsoft.Xna.Framework.Graphics.dll \
    > Microsoft.Xna.Framework.Graphics.il
```

## What was derived from it, and how

Every arithmetic method in `src/framework/math-helper.lisp`,
`src/framework/value-types.lisp`, `src/framework/vector3.lisp` and
`src/framework/vector4.lisp` was written by reading the corresponding IL method
body, instruction by instruction, and reproducing:

* the **order** of the arithmetic — `Lerp` is `v1 + (v2 - v1) * t`, not
  `v1 * (1 - t) + v2 * t`, and the two answer different binary32;
* the **precision** at each step — `Length` sums the squares in binary32 and only
  the square root is taken in binary64, then narrowed;
* the **shape** of a division — `Divide` by a scalar takes one reciprocal and
  multiplies, which is not the same binary32 as dividing each component;
* the **comparison order and orderedness** — `Clamp` compares against the maximum
  first, with ordered comparisons, which is why a NaN passes through unchanged;
* the **exact constants** — `MathHelper.Pi` is the binary32 `3.14159274f`, and
  `ToRadians` multiplies by `0.0174532924f` rather than dividing by 180.

Where the framework calls into the base class library — `Math.Min`, `Math.Max`,
`Math.IEEERemainder` — the .NET definition is reproduced rather than replaced by
the nearest Common Lisp equivalent, because they differ: `Math.Min(-0.0f, 0.0f)`
answers `+0.0f`, and `Math.Min(NaN, x)` answers `NaN` while `Math.Min(x, NaN)`
answers `x`.

These facts are recorded as `:xna-derived` observations in
`tests/behavior/corpus.lisp`. **CNA is never the oracle for any of them.** CNA
has native routes for most of this arithmetic and they are deliberately not used:
routing the value types through the C ABI would make the binding's arithmetic
CNA's rather than XNA's, and would leave nothing to cross-check.

## The half-precision format, which is the least believable claim here

CNA-Lisp says XNA's 16-bit half is **not** IEEE 754 binary16. That is unusual
enough that it should not rest on a source comment, so the evidence is written
out. Both methods are `Microsoft.Xna.Framework.Graphics.PackedVector.HalfUtils`
in `Microsoft.Xna.Framework.dll` -- a `private abstract sealed` class, so it is
not in the contract and only its effects are observable.

`Pack(float32)` reads the argument's bits, keeps the sign as bit 15, and
compares the magnitude against the literal field `wMaxNormal = 0x47FFEFFF`:

```
IL_001b:  ldloc.0                       // value bits & 0x7FFFFFFF
IL_001c:  ldc.i4     0x47ffefff
IL_0021:  ble.un.s   IL_002e            // <= : the ordinary paths
IL_0023:  ldloc.2                       // sign
IL_0024:  ldc.i4     0x7fff
IL_0029:  or                            // saturate
```

The comparison is unsigned over `uint32`, so an infinity (`0x7F800000`) and
every NaN (above it) both exceed `wMaxNormal` and both take the saturating
branch. **Nothing anywhere in `Pack` produces a non-finite pattern**, and
nothing tests for one on the way in.

`Unpack(uint16)` is where the other half of the claim lives. It branches once,
on whether the exponent field is zero, and the non-zero branch has **no case
for an exponent of 31**:

```
IL_005f:  ldarg.0
IL_0060:  ldc.i4     0x8000
IL_0065:  and
IL_0066:  ldc.i4.s   16
IL_0068:  shl                           // sign
IL_0069:  ldarg.0
IL_006a:  ldc.i4.s   10
IL_006c:  shr
IL_006d:  ldc.i4.s   31
IL_006f:  and
IL_0070:  ldc.i4.s   15
IL_0072:  sub                           // - cExpBias
IL_0073:  ldc.i4.s   127
IL_0075:  add                           // + binary32 bias
IL_0076:  ldc.i4.s   23
IL_0078:  shl
```

So exponent 31 rebiases to 143 like any other, which is 2^16, and `0x7FFF`
becomes `0x47FFE000` -- **131008.0**. IEEE 754 binary16 would read the same
pattern as a NaN.

Everything else about the format *is* binary16: the zero-exponent branch does
the ordinary subnormal renormalisation down to 2^-24, and both `Pack` paths
round to nearest with the even tie-break. **Only the top exponent distinguishes
the two formats**, which is exactly why the claim is easy to disbelieve and
worth pinning.

Measured against the implementation, and asserted in
`packedvector.half-is-not-binary16`: `65504` packs to `0x7BFF` and is *not* the
maximum; `+Inf` packs to `0x7FFF` and `-Inf` to `0xFFFF`, so the sign survives
saturation and the infinity does not; a quiet NaN packs to `0x7FFF`; and
`wMaxNormal` itself already rounds up to `0x7FFF`, so the boundary is visible in
the IL and not in the answers.

## What the Graphics assembly answered

`src/graphics/state-objects.lisp` was written by reading
`Microsoft.Xna.Framework.Graphics.dll`, and these are the facts that came out of
it rather than out of a description:

* **Every setter calls `ThrowIfBound` first.** A state object becomes permanently
  read-only when it is applied to a device, and the predefined instances are
  constructed already bound -- their private constructors set `isBound` before
  anyone can reach them, which is why `BlendState.Opaque.ColorSourceBlend = x`
  throws `InvalidOperationException`.
* **The defaults are not the obvious ones.** `RasterizerState`'s
  `MultiSampleAntiAlias` is **true**; `SamplerState`'s `MaxAnisotropy` is **4**;
  `DepthStencilState`'s `StencilMask` and `StencilWriteMask` are **-1**, and its
  `DepthBufferFunction` is `LessEqual`; `BlendState`'s `MultiSampleMask` is -1 and
  its `BlendFactor` is `Color.White`.
* **A predefined blend state sets the alpha pair as well as the colour pair.**
  The private constructor takes two `Blend` values and writes both to
  `cachedColorSourceBlend`/`cachedColorDestinationBlend` *and* to
  `cachedAlphaSourceBlend`/`cachedAlphaDestinationBlend`, leaving everything else
  at the defaults.
* **A predefined sampler writes one address mode to U, V and W.**
* **`SpriteBatch.SetRenderState` is where a null state becomes a default**:
  `BlendState.AlphaBlend`, `SamplerState.LinearClamp` into `SamplerStates[0]`,
  `DepthStencilState.None` and `RasterizerState.CullCounterClockwise`. It runs at
  `Begin` for `SpriteSortMode.Immediate` and at `End` for the deferred modes,
  which is when the states it was given are applied and therefore latched.
* **`GraphicsDevice`'s state setters throw `ArgumentNullException` for a null.**
  Only `SpriteBatch.Begin` treats a null as "use the default".

`src/graphics/vertex-types.lisp` came out of the same assembly, and so did these:

* **`VertexElementValidator.GetTypeSize` is not the obvious table.** `Color` is
  **4** bytes, because it is a packed BGRA rather than four floats, and
  `HalfVector4` is **8**, because a half is two bytes. Anything else in the switch
  answers 0.
* **`GetVertexStride` is a maximum, not a sum**: the largest `offset + size` over
  the elements, which is what lets a declaration list them in any order.
* **`Validate` refuses in a fixed order**, and an element can fail more than one
  of its checks at once: a non-positive stride (`ArgumentOutOfRangeException`),
  then a stride that is not a multiple of four, then per element a usage outside
  the enumeration, an element that starts before zero or ends past the stride, an
  offset that is not a multiple of four, an earlier element with the same usage
  *and* usage index, and finally an overlap with any byte an earlier element
  already claimed. The overlap check is per **byte**, tracked in an array as long
  as the vertex, so two elements at different offsets still collide when the
  first is long enough to reach the second.
* **Both constructors clone the elements**, and `GetVertexElements` answers a
  fresh array, so neither the caller's array nor the returned one can change the
  declaration afterwards.
* **The four standard declarations** are built by each type's own class
  constructor, with strides 16, 20, 24 and 32. `VertexPositionNormalTexture` puts
  its texture coordinate at 24, not 16, because a normal is a `Vector3`.

Each of those is a `:xna-derived` observation in `tests/behavior/corpus.lisp` and
is asserted in `tests/unit/graphics-state.lisp` and
`tests/unit/vertex-types.lisp`. **CNA is not the oracle for any
of them**, and where CNA disagrees -- it does, on both stencil masks -- the
divergence is recorded in `docs/limitations.md` and pinned by a test rather than
adopted.

## The release audit: the extraordinary claims, re-read

Before calling Foundation 1 release-ready, the handful of claims that are
surprising enough that a reader might reasonably doubt them were re-opened
against the pinned assemblies rather than against the source comments that
assert them. Each is recorded with what the IL actually says, so that a later
reader can tell a checked claim from an inherited one.

Both assemblies were re-hashed first. `Microsoft.Xna.Framework.dll` is
`38e7093f…ca130` and `Microsoft.Xna.Framework.Graphics.dll` is `560080fc…e9f55`,
matching the table above.

| Claim | Verdict | What the IL says |
| --- | --- | --- |
| XNA's 16-bit half is not IEEE 754 binary16 | **stands** | see the section above: `Pack` saturates everything above `wMaxNormal` including both infinities and every NaN, and `Unpack` has no case for exponent 31 |
| `Color` multiplication truncates in 16.16 fixed point | **stands** | `op_Multiply` scales by `65536.0f`, clamps the factor into `[0, 0xFFFFFF]`, multiplies each byte as an integer and shifts right by 16 — a floor, not a round — then clamps each channel at `0xFF`. Half of white is 127 |
| `DepthStencilState`'s stencil masks default to -1 | **stands** | `SetDefaults` emits `ldc.i4.m1` into both `cachedStencilMask` and `cachedStencilWriteMask`. CNA writes `0x7FFFFFFF`; the divergence is real and XNA is the authority |
| `SpriteBatch` turns a null state into a specific default | **stands** | `SetRenderState` branches on each null and loads `BlendState::AlphaBlend`, `DepthStencilState::None`, `RasterizerState::CullCounterClockwise` and `SamplerState::LinearClamp`, the last into `SamplerStates[0]` |
| `Matrix.Decompose` fills its outputs even when it answers false | **stands** | the failing branch writes `Quaternion::get_Identity()` into the rotation and `ldc.i4.0` into the result. Scale and translation were written earlier and are not undone |
| `System.Char` is a UTF-16 code unit, and a surrogate pair is two glyph lookups | **stands** | the measure and draw loops index `StringProxy::get_Item(int32)`, whose return type is `char`, and pass each one to `GetIndexForCharacter(char)`. Nothing combines a surrogate pair anywhere in the path |

`StringProxy` also settles a structural question rather than a behavioural one:
it holds *either* a `string` or a `StringBuilder` and answers `Length` and
`get_Item` over whichever it has, so the `String` and `StringBuilder` overloads
really are one code path in the original. That is the evidence for the
`distinguished_by: "unified"` collapse the verifier requires a reason for.

**Nothing in this round changed an implementation.** Six claims were re-read and
six survived; what changed is that the half claim now carries its IL rather than
a comment asserting it, and that this table exists so the next audit knows which
claims have already been checked and against what.
