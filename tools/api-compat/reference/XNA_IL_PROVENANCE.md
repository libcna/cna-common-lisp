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

## Pinned assembly

| | |
| --- | --- |
| Assembly | `Microsoft.Xna.Framework.dll`, version 4.0.0.0, public key token `842cf8be1de50553` |
| Bytes | 679424 |
| SHA-256 | `38e7093f52d7474bbc6256906519781a1210d7da50a1c667b52716fcf49ca130` |

The assembly is located **by hash, never by filename**: any copy whose SHA-256
matches is equally authoritative, and any copy whose SHA-256 does not match is
not. The same hash is pinned by the mature CNA-Ruby binding, which is where this
project's confidence that it is the right binary comes from.

## Disassembly

Disassembled with `ikdasm` (Debian package `ikdasm`). The disassembly used for
this work has SHA-256
`cbfdba082a3ab09e0b1ef604f277fedb23852cae0563a10b7066fd04b30d26d4`; it is a
derived artefact and is not committed.

```sh
sha256sum /path/to/Microsoft.Xna.Framework.dll
# must print 38e7093f52d7474bbc6256906519781a1210d7da50a1c667b52716fcf49ca130
ikdasm /path/to/Microsoft.Xna.Framework.dll > Microsoft.Xna.Framework.il
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
