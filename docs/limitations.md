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

Currently blocked by this:

| Member | Route |
| --- | --- |
| `GraphicsDevice.Viewport` setter | `cna_graphics_device_set_viewport` takes `CNA_Viewport` (24 bytes) by value |

The getter is present. The refusal is proved by the generator, not asserted.

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
* everything 3D: `Matrix`, `Effect`, `Model`, vertex and index buffers;
* audio, media, storage, gamer services and networking;
* `Vector3`, `Vector4`, `Quaternion`, `Plane`, the bounding volumes, and the
  `Curve` family.

`Vector2` is present because Foundation 1's `SpriteBatch.Draw` needs it.

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
