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
projection covers are spread across two of them.

| Assembly | Bytes | SHA-256 |
| --- | ---: | --- |
| `Microsoft.Xna.Framework.dll` 4.0.0.0 | 679424 | `38e7093f52d7474bbc6256906519781a1210d7da50a1c667b52716fcf49ca130` |
| `Microsoft.Xna.Framework.Graphics.dll` 4.0.0.0 | 427520 | `560080fc39021c611ca9d076dcebed312faf6d7d1413c2dc523683ea635e9f55` |

Both carry the public key token `842cf8be1de50553`.

`Microsoft.Xna.Framework.dll` holds the value types -- `Color`, `Vector*`,
`Matrix`, `Quaternion`, `Plane`, the bounding volumes, `Curve`, `MathHelper`.
`Microsoft.Xna.Framework.Graphics.dll` holds `GraphicsResource`, `Texture2D`,
`SpriteBatch` and the four graphics state objects. A behavioural question about a
type is answered by reading the assembly that declares it.

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
