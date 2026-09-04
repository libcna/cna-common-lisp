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
* audio, media, storage, gamer services and networking.

The math types are present and complete: `Vector2`, `Vector3`, `Vector4`,
`Quaternion`, `Matrix`, `Plane`, `Ray`, `BoundingBox`, `BoundingSphere`,
`BoundingFrustum`, `MathHelper`, `ContainmentType` and `PlaneIntersectionType`,
and so is the `Curve` family. They are pure Lisp and touch no native route.

### Matrix.Decompose answers three things even when it fails

`Decompose` returns four values: a flag, then the scale, the rotation and the
translation. **The flag is not advisory.** When the rotation part is not a
rotation -- a shear, say -- the framework answers false and *still* fills in the
scale it measured and the translation it read, with the rotation set to the
identity quaternion. A caller who ignores the flag gets a plausible answer that
does not reconstruct the matrix.

Two other answers surprise people, and both are the framework's:

* a left-handed matrix is not refused. `Decompose` flips the longest axis and
  its scale, so a mirror comes back as a **negative scale** with no rotation;
* an axis shorter than `1e-4` is replaced rather than treated as an error --
  by the canonical unit axis for the longest, by a cross product with the
  canonical axis most nearly perpendicular to it for the middle one, and by the
  cross of the other two for the shortest. A wholly zero matrix therefore
  decomposes *successfully*, into a zero scale and a half turn about X.

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

## An upstream CNA defect: DepthStencilState's two stencil masks

**Measured, and CNA's own source confirms it.** XNA's
`DepthStencilState.StencilMask` and `.StencilWriteMask` default to **-1**, the
all-ones mask: `DepthStencilState::SetDefaults` in the pinned assembly writes
`ldc.i4.m1` into `cachedStencilMask` and `cachedStencilWriteMask`. CNA's
`Microsoft::Xna::Framework::Graphics::DepthStencilState` constructor
(`modules/graphics/src/Xna/DepthStencilState.cpp`, lines 16-17) initialises both
to `0x7FFFFFFF`, and so `cna_depth_stencil_state_init` answers **2147483647** for
every one of its three presets.

The difference is bit 31. As an `Int32` property it is directly observable: a
game reading `new DepthStencilState().StencilMask` gets -1 in XNA and
`int.MaxValue` from CNA.

**CNA-Lisp keeps XNA's value.** Its own defaults come from the pinned assembly,
so a `depth-stencil-state` made here reports -1, and applying it writes -1 into
the descriptor CNA receives. `tests/native/graphics-state.lisp` pins **both**
sides: that CNA-Lisp answers -1, and that CNA's preset route answers 2147483647.
If CNA is corrected, that test fails and says so, which is the point of writing
the divergence down rather than tolerating it.

One place CNA's value can still be seen: the state a device reports *before*
anything has been applied to it is CNA's, not CNA-Lisp's, because it was never
written through this binding. Reading `(gfx:depth-stencil-state device)` on an
untouched device can therefore answer 2147483647 for the two masks.

**Nothing in CNA has been modified.** This is recorded, not worked around.

## A state object is latched at Begin, and XNA latches the deferred modes at End

XNA's state objects become permanently read-only when they are *applied* to a
device -- every setter calls `ThrowIfBound`, and `Apply` sets `isBound`.
`SpriteBatch` applies them in `SetRenderState`, which runs at `Begin` for
`SpriteSortMode.Immediate` and at `End` for the deferred modes.

CNA's `cna_sprite_batch_begin_with_states` takes the four descriptors **by
value**, so CNA-Lisp copies them at `begin` and has nothing left to read at
`end`. It therefore latches them at `begin` for every sort mode.

The one observable difference: mutating a state object between `begin` and `end`
in a deferred mode is accepted by XNA -- and honoured, because XNA had not read
it yet -- and refused here. Refusing was chosen over the alternative, which is
accepting a change that could no longer have any effect.

## The first state-bearing Begin does one-time native work

Measured with the HEADLESS renderer: the first `begin` that carries state
descriptors takes tens of milliseconds, and every one after it takes under a
millisecond. The cost is CNA creating its native state objects on first use, not
anything CNA-Lisp does per call -- the Lisp side allocates four small stack
descriptors and writes about forty fields.

It matters for one reason: under XNA's default *fixed* time step, a first frame
that overruns the 60 Hz target is followed by catch-up updates that draw nothing,
so an exact frame count taken across the warm-up measures the warm-up. Every
deterministic frame claim in this repository uses variable timing, for exactly
that reason; see the section above.

## A texture slot filled by CNA itself reads back as empty

`GraphicsDevice.Textures[i]` answers the texture that was *put* there, and in XNA
that is always a texture the program itself bound, because XNA owns both sides.

CNA's C ABI cannot always answer with an object, and its header says why in as
many words: **there is deliberately no route from a native object back to a
handle**, anywhere in that ABI. A handle is a record the ABI created for an
object a C caller asked it to make; it is not an identity the object carries.
`cna_graphics_device_get_texture` therefore answers a `bound` flag and a handle,
and the handle is `CNA_INVALID_HANDLE` when the slot was filled by canonical CNA
code -- a `SpriteBatch` flush, for instance -- rather than through the C ABI.

The header's own advice is to cache what you bind and use `bound` to tell
"something else owns this slot now" from "the slot is empty", and that is what
`texture-collection` does. The consequence is one case:

* a slot this binding filled reads back as the texture object it was given;
* an empty slot reads back as `NIL`;
* **a slot CNA filled from inside reads back as `NIL` as well**, because there is
  nothing truthful to answer -- the binding has no texture bound there, and
  inventing one would be worse than saying so.

`sampler-state-collection` has no equivalent case: CNA answers a complete sampler
descriptor for any slot, so a slot that was never set through the collection is
read once from the device and then answered stably, as XNA's array-backed getter
does.

## A graphics resource's Tag is a Lisp slot, not a round trip

XNA's `GraphicsResource.Tag` is `System.Object`: arbitrary consumer data the
framework never reads. CNA's is a `uint64` token, which cannot hold a Lisp object
and could only hold a pointer to one -- and putting a pointer to a moving object
into C is the single thing this binding never does. So the tag is a slot on the
Lisp object, it holds any Lisp value, and it is **not** carried through the C ABI.

The consequence is narrow and worth stating: a program that shared one native
resource between CNA-Lisp and another CNA binding would not see that binding's
tag through `gfx:tag`, and vice versa. Nothing in CNA-Lisp shares resources that
way, and the alternative -- a raw pointer in the public API -- is the one this
projection exists to avoid.

## TouchCollection's nested enumerator is not projected

`TouchCollection+Enumerator` is a nested value type that exists to implement
`IEnumerator<TouchLocation>`. Common Lisp has no enumerator protocol for it to
satisfy, and `touch-collection-locations-vector` answers the sequence a Lisp
caller iterates, so the nested type is absent from the measured selection rather
than reported as a missing type -- reporting it would claim it should be there.

## The two IPackedVector interfaces are not projected

`IPackedVector` and `IPackedVector<TPacked>` are interfaces, and Common Lisp has
no interface concept to project them onto. Everything they declare is present on
each of the seventeen packed types as an ordinary function -- the packed value
and the conversion to and from a vector -- so nothing is missing except the
ability to write a function over "any packed vector" by naming the interface. A
Lisp caller writes that function over the operations instead.

They are absent from the measured selection rather than reported as missing
types, because reporting a type as missing would claim it *should* be projected.

## No controller and no touch device were attached when those tests ran

The `GamePad` family and the `Input.Touch` namespace are bound to CNA's own
routes and the native tests exercise every one of them inside a running game.
What they check is that the routes work and that a device that is not there
answers a well-formed empty answer -- a disconnected gamepad slot with every
button up, a touch collection with no touches -- rather than failing or returning
rubbish. No controller and no touch device were attached to the machine that ran
them, so nothing here claims that a pressed button reads as pressed, that a
thumbstick reads its position, that a finger produces a touch location, or that
vibration was felt.

The touch panel's *settable* properties are a partial exception: the tests write
`EnabledGestures`, `DisplayWidth` and `DisplayOrientation` and read back what
they wrote, so those four routes are shown to round-trip through CNA rather than
merely to return without error.



Two related things this binding does not do:

* the analog **direction bits** -- `Buttons.LeftThumbstickUp` and its seven
  relatives -- are read from CNA rather than recomputed from the thumbstick
  vectors. CNA's C ABI documents `pressed_buttons` as carrying the physical and
  derived bits, and this binding trusts its implementation to derive them, which
  is what a binding is for. It has not independently verified that derivation
  against XNA;
* `GamePadType` is **translated** rather than passed through. CNA numbers the pad
  types consecutively 0 through 9; XNA numbers them 0 through 8 and then jumps to
  0x300 for `BigButtonPad`. The projection answers the contract's number, and the
  two tables are deliberately separate so that neither can be mistaken for the
  other.

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
