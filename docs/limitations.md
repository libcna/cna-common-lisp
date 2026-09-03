# Limitations

Everything here is a measured limitation of the current build, with the reason it
exists. Nothing here is a placeholder for a member that is secretly present.

## Qualified configuration

CNA-Lisp is qualified on exactly one configuration:

* SBCL 2.5.2 on Linux x86-64;
* CFFI and Babel from Quicklisp;
* the CNA C ABI at version **0.21.0** (encoded 5376), and no other;
* a CNA build with the `SDL3` platform, `SDL3` audio and the **HEADLESS**
  renderer.

No claim is made for any other Common Lisp implementation, for Windows or macOS,
for a different ABI version, or for a different renderer.

## HEADLESS proves execution, not pixels

Every graphics result recorded here was produced against the HEADLESS renderer.
That proves the lifecycle ran, the device was borrowed, the commands were
accepted and the resources were created and destroyed. It proves **nothing** about
what a pixel looks like.

There is no visible-rendering claim and no rasterisation readback test. Until one
of those exists, "drew a sprite" here means "submitted a sprite draw that the
renderer accepted".

## No `cffi-libffi`, and what that costs

CFFI cannot pass a structure by value without `cffi-libffi`, and `cffi-libffi`
requires libffi headers and a C compiler at load time. CNA-Lisp does not depend on
it, so a released binding needs neither.

The cost is that a route taking a by-value aggregate the System V AMD64 ABI
classifies as MEMORY (larger than 16 bytes), or one with a floating-point (SSE)
eightbyte, cannot be bound. See `docs/native-abi.md`.

One member is affected: `GraphicsDevice.Viewport`'s setter, whose route takes
`CNA_Viewport` (24 bytes) by value. The refusal is proved by the generator, not
asserted.

It is **not blocked**, though. The generator emits a tiny private shim -- a
wrapper that takes the aggregate by pointer and the real route by function
pointer, and does nothing else -- and the setter goes through it. The shim is
optional and is **not shipped prebuilt**, because a released CNA-Lisp must load
with no C toolchain: `tools/native-abi/verify.sh` builds it, `CNA_LISP_SHIM`
names it, and without it the setter signals a `cna-not-supported-error` naming
the variable, the command and the reason. The reader works either way.

The qualified configuration includes the shim, and the test suite asserts both
outcomes.

## A fixed time step does not make a frame count an update count

Measured: under CNA's fixed time step, a frame that took longer than the target
step is followed by catch-up updates, so `n` calls to `run-one-frame` can deliver
more than `n` updates. A full garbage collection between frames is enough to
trigger it.

Drawing is one per frame in both modes. Under **variable** timing
(`(setf (is-fixed-time-step game) nil)`) a frame is exactly one update and one
draw, with a full collection in between or without.

That is why every deterministic frame-count claim in this project -- the
template's `--frames 60` and `--frames 600`, and the tests that pin an update
count -- uses variable timing. A deterministic claim under a fixed step would be
a claim about how fast the machine happened to be.

## Texture extent comes from the image, not from CNA

CNA has no route reporting a `Texture2D`'s pixel extent. `width` and `height`
therefore report what the PNG header of the supplied image declared. For a
payload that is not a PNG they report zero, which is the truth: nothing about the
extent is known.

`level-count` and `format-of` come from CNA's own `cna_texture_get_info`.

## Disposal is not cascaded

CNA requires children to be destroyed before their parent. XNA's `Game.Dispose`
does not destroy every `Texture2D` a program made -- the finalizer thread dealt
with those -- so a straight port that relies on finalization will find that
CNA-Lisp refuses to dispose the game while those resources are alive.

CNA-Lisp reports that as `cna-ownership-error` naming the live children, instead
of cascading. Cascading would mean the binding deciding when a program's
resources die, which is not the binding's decision, and there is no evidence that
a particular cascade order is the right one.

## Not implemented in this milestone

These are absent, and measured as absent, not faked:

* the game component engine (`GameComponent`, `Game.Components`, services);
* `ContentManager` and the XNB pipeline;
* `GameWindow` as a type -- only the window title is reachable, on `game`;
* `SpriteFont` and `SpriteBatch.DrawString`;
* `SpriteBatch.Begin`'s state-bearing overloads, and the four graphics state
  objects they need;
* `Mouse`, `GamePad`, `TouchPanel`;
* `Effect`, `Model`, vertex and index buffers, and everything else that draws in
  three dimensions;
* audio, media, storage, gamer services and networking;
* the `Curve` family.

The math types are present: `Vector2`, `Vector3`, `Vector4`, `Quaternion`,
`Matrix`, `Plane`, `Ray`, `BoundingBox`, `BoundingSphere`, `BoundingFrustum`,
`MathHelper`, `ContainmentType` and `PlaneIntersectionType`. They are pure Lisp
and touch no native route.

### Three members of Matrix

| Member | Why |
| --- | --- |
| `Matrix.Decompose` | 540 IL instructions over a private `CanonicalBasis`/`VectorBasis` pair using unsafe pointer arithmetic, with a fallback path for degenerate scales. An implementation that agreed on well-conditioned matrices and diverged on degenerate ones would be worse than the absence. |
| `Matrix.CreateConstrainedBillboard` (both overloads) | A three-deep threshold chain over two optional vectors. Same reason. |

## What BoundingFrustum's answers are, and are not

The bounding volumes are closed: every intersection and containment between
`Ray`, `BoundingBox`, `BoundingSphere`, `BoundingFrustum` and `Plane` is
answered. Two limits are worth stating rather than discovering.

**`Contains` and `Intersects` do not answer the same question about a box.**
`BoundingFrustum.Contains(BoundingBox)` tests the box against the six planes one
at a time, which reports `Intersects` for a box that sits in a corner region and
touches nothing. `BoundingFrustum.Intersects(BoundingBox)` runs XNA's GJK solver,
which is geometrically exact but accepts once the squared closest distance falls
under `4E-05` of the largest support length seen -- about a tenth of a world unit
for a frustum twenty units deep. So the two disagree in **both** directions on
bodies near the boundary. That is XNA's behaviour, it is reproduced, and
`tests/unit/bounding-frustum.lisp` pins one case of each direction.

**The corners are derived, not stored.** They come out of intersecting three
normalised planes, which costs about a part in 10^6 of the far distance: a
frustum whose far plane is at `z = -15` answers `-14.999987`. And a frustum built
from a singular matrix answers corners full of infinities and NaNs rather than
signalling, because the arithmetic is IEEE 754's and XNA lets it run.

The GJK transcription was cross-checked against an independent separating-axis
test over the two convex hulls: 3956 random box placements and 985 sphere
placements whose exact distance to the frustum could be computed from a single
plane, with the ambiguous band set to XNA's own acceptance tolerance. No
disagreement. That is evidence, not proof, and it is evidence about this
transcription rather than about XNA.

The other three volumes are read from the IL branch by branch, down to the
epsilons (`1E-05f` in `Ray.Intersects(Plane)`, `1E-06f` in
`BoundingBox.Intersects(Ray)`), the strict `<` that makes a point exactly on a
`BoundingSphere`'s surface *Disjoint*, and one arithmetic defect XNA shipped:
`BoundingBox.Contains(BoundingSphere)` tests the X extent against the radius
twice, the second time where the Z extent belongs. That defect is reproduced,
because the contract is what the framework answers, and it is marked as a defect
wherever it is reproduced -- in the source, in the unit test and in the
behaviour corpus.

## Foreign-thread callbacks

Not claimed and not tested. See `docs/callbacks-and-threading.md`.

## Behaviour authority

Behaviour claimed here for XNA members is derived from the selected Microsoft XNA
Framework 4.0 Windows public contract. CNA's own answers are cross-checked
against it where both exist, but **CNA is never used as the oracle for what XNA
does**: a runtime cannot prove its own compatibility.

Where this milestone reproduces XNA arithmetic -- binary32 order of operations,
`Rectangle.Center`'s integer halving, `Viewport.TitleSafeArea`'s 640x480
threshold -- the behaviour corpus records the origin of the observation. Where a
member's exact behaviour has not been established against an authority, the
member is absent rather than guessed.
