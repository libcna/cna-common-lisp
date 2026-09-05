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
for a different ABI version, or for a different renderer — and for the host, it
is stronger than "no claim": the foreign layer **refuses** to open on anything
but SBCL on Linux x86-64, because the by-value flattening is a System V AMD64
rule and another host ABI would be a different calling convention rather than an
untested one. The section below has the detail.

## HEADLESS proves execution, not pixels — and what does prove pixels

Every graphics result recorded here was produced against the HEADLESS renderer.
That proves the lifecycle ran, the device was borrowed, the commands were
accepted and the resources were created and destroyed. It proves **nothing** about
what a pixel looks like.

There is no visible-rendering claim anywhere in this repository. Under HEADLESS,
"drew a sprite" means "submitted a sprite draw that the renderer accepted"; the
rasterizer lane below is what turns that into a statement about pixels, and only
for the shapes it actually reads back.

### The rasterizer lane, which does prove pixels

`GraphicsDevice.GetBackBufferData` reads the back buffer, and CNA is honest about
which renderers can answer: the route returns `CNA_RESULT_NOT_SUPPORTED` "when
the active renderer has no honest back-buffer readback" rather than a buffer of
zeroes. Under `HEADLESS` it therefore refuses, by name.

Under a rasterising renderer it answers. Measured against a CNA built with
`-DCNA_GRAPHICS_RENDERER=SOFTWARE` — a CPU rasteriser, needing **no display and
no Xvfb** — in seven separate kinds of proof, kept apart because they are
different claims:

* **clear.** Clearing to `CornflowerBlue` reads back `(100, 149, 237, 255)` for
  every pixel of the window asked for.
* **sprite.** Drawing a generated 8×8 fully opaque magenta texture to an 8×8
  destination at (16,16), with `BlendState.Opaque`, `SamplerState.PointClamp`,
  `Color.White` and no rotation, scale or origin, puts `(255, 0, 255, 255)` on
  the pixels from (16,16) to (23,23) and leaves `(15,15)`, `(15,16)`, `(16,15)`,
  `(24,16)`, `(16,24)` and `(24,24)` at the clear colour. A second texture — four
  2×2 quadrants in four colours — lands each quadrant on its own pixels, so
  orientation and sampling are proved and not only placement.

* **primitive.** A `BasicEffect` pass applied, then one `DrawUserPrimitives`
  triangle in clip space — the effect's World, View and Projection left at the
  identity CNA reports as their default, so no matrix setter and therefore no
  optional shim takes part — puts the vertices' own colour on four sampled points
  inside the triangle and leaves five outside it, and the two far corners, at the
  clear colour. `VertexColorEnabled` is on and lighting off, so the colour read
  back is the vertex colour and not a shading result.

* **text.** A `SpriteFont` built over a generated 16×8 atlas whose two glyph
  cells are **different colours** — `'A'` opaque red, `'B'` opaque green — so a
  pixel's colour says which glyph reached it. Drawing `"AB"` at (16,16) with
  `BlendState.Opaque`, `SamplerState.PointClamp`, `Color.White`, unit scale and
  no rotation or origin puts red inside the first glyph and **green** inside the
  second, eight pixels to its right: that is the advance and the per-glyph source
  rectangle in one assertion, because red there would mean the second glyph was
  cut from the first one's cell and the clear colour would mean the pen never
  advanced. Drawing `"A\nA"` puts the second line's glyph twelve rows down —
  `LineSpacing`, not the glyph height — and leaves the four rows between the two
  eight-row glyphs at the clear colour, which a line advance of 8 would have
  filled.

* **stock-effect.** A pass applied through an `AlphaTestEffect`, and through a
  `SkinnedEffect`, makes a `DrawUserPrimitives` triangle legal and puts the
  triangle's own vertex colour on the pixels its geometry covers. That they are
  usable *draw* effects, and — as the section above says at length — nothing
  about the alpha test or about skinning.

* **render-target.** The back buffer is cleared, a `RenderTarget2D` is bound and
  cleared to a different colour, and the back buffer is read *before anything
  else*: it must be untouched, so a clear that leaked to the screen fails. Then
  the back buffer is restored, the target is drawn onto it as the ordinary
  `Texture2D` it is, and its own colour appears under the destination rectangle
  and nowhere else. Checked by mutation: a bind that silently does nothing turns
  fourteen of these assertions red.

* **render-target-data.** Every one of a bound-and-cleared `RenderTarget2D`'s 256
  texels, read back through `Texture2D.GetData`. This is the one pixel claim in
  the repository that does not go through `GetBackBufferData` at all: `GetData`
  reads a *texture*. Asserted on every renderer rather than only the rasterising
  ones — under `HEADLESS` CNA refuses it, and the refusal is asserted by name, so
  the test says which happened instead of quietly proving nothing.

`tools/qualification/rasterizer.sh` requires
<!-- generated:rasterizer proof count=8 --> kinds of proof and fails when any is
absent — and fails as well when a run produces a kind the registry does not name,
so neither half can drift. The required set is
`tools/qualification/rasterizer-proofs.json`; `docs/qualification.md` renders it.
A clear alone is not accepted as evidence about `SpriteBatch`, which it briefly
was, the sprite path is not accepted as evidence about the primitive path, which
is a different path through the renderer, and neither is accepted as evidence
about text layout — a font atlas texel arriving is a smaller claim than a string
being laid out.

Three things this does *not* establish. It is not a claim about a physical
monitor; a back buffer is a back buffer. It is one renderer: `SOFTWARE`
rasterises on the CPU, and nothing here says a GPU renderer would produce the
same pixels. And each proof is one shape: the sprite one is an axis-aligned,
unrotated, unscaled, untinted, opaque blit, the primitive one is a single
untextured, unlit, unfogged triangle list with no transform, and the text one is
unrotated, unscaled, untinted text with no origin and no `SpriteEffects`.
Rotation, scaling, tinting, blending, texturing, lighting, fog, indexed and
buffer-backed draws, flipped or rotated text and every non-identity transform are
submitted and accepted, and their pixels are not asserted anywhere.

## Texture data, and how narrow the transfer is

`Texture2D`'s two constructors and its three `SetData` and three `GetData`
overloads are complete. A texture can be made blank and filled by the program,
and read back.

**The transfer is as narrow as a buffer's**, and for the same reason: it is
accepted only for an element type whose binary layout this binding can prove —
`Color`, `(unsigned-byte 8)`, `single-float`, `Vector2`, `Vector4` — with the
layouts coming from `src/graphics/buffer-data.lisp` rather than a second opinion
about how a `Color` is packed. There is no vector-of-anything sink; an element
type with no proven layout is refused by name.

CNA is told the texel **kind** by name rather than by byte count, because it
distinguishes kinds that share one: an `Alpha8` byte and a raw byte are both one
byte, a `Color` and an `Rgba1010102` are both four. That is the same rule every
enumeration in this binding follows.

`SetData` and `GetData` are **one generic function each**, shared with the vertex
and index buffers, so CLOS congruence makes every method accept every keyword any
of them uses. Accepting is not having: a texture's method refuses
`:OFFSET-IN-BYTES`, `:VERTEX-STRIDE` and `:OPTIONS` by name, and a buffer's
refuses `:LEVEL` and `:SOURCE`, because silently ignoring one would invent an
overload XNA has not got.

`Texture2D.FromStream`, `SaveAsPng` and `SaveAsJpeg` remain absent: all four need
the `System.IO.Stream` projection. `TEXTURE-2D-FROM-PNG-BYTES` and
`TEXTURE-2D-FROM-PNG-FILE` stay declared extensions until then.

## Cube render targets exist, and only some renderers will bind one

`RenderTargetCube` and `RenderTargetBinding` complete the render-target family,
and with them `GraphicsDevice`'s last three members —
`SetRenderTarget(RenderTargetCube, CubeMapFace)`, `SetRenderTargets` and
`GetRenderTargets`.

**Creating a cube target works everywhere measured; binding one does not.**
HEADLESS accepts `SetRenderTarget(cube, face)`; the SOFTWARE rasterizer refuses
it with `SetRenderTargets: this renderer does not support RenderTargetCube`. That
is CNA's refusal, it names exactly what is missing, and it arrives *after* the
target was successfully created — so a program can build one and discover only at
bind time that this renderer will not have it. The test checks both branches, so
neither a HEADLESS run that silently stopped binding nor a SOFTWARE run that
suddenly started would pass unnoticed.

This is the exact inverse of the cube *storage* asymmetry recorded above, where
SOFTWARE has what HEADLESS lacks. Between them, no single renderer exercises the
whole `TextureCube` family.

### `GetRenderTargets` answers the objects this binding bound

`cna_graphics_device_copy_render_targets` answers **handles**, and the ABI has no
route from a handle back to the object that owns it. Wrapping them would invent a
second `RenderTarget2D` for a target the program already holds, with a second
lifetime to get wrong. So the device remembers the bindings it was given and
`GetRenderTargets` answers those — the same decision, for the same reason, that
the vertex-buffer bindings record.

Only the **objects** come from the record. Everything CNA can be asked is checked
against it, and a disagreement signals rather than being papered over:

| Checked | Against |
| --- | --- |
| `cna_graphics_device_get_render_target_count` | the number of remembered bindings |
| the copy route's `out_count` | that count, since the header calls it "the exact required element count" |
| each slot's `render_target` | the remembered target's handle, in order |
| each slot's `cube_map_face` | the remembered face |
| each slot's `array_slice` | zero, which CNA requires in both directions |

The face matters because a binding's identity is more than its target handle: two
bindings of the same cube differ only in which face they name, and checking the
handles alone would call them the same. A `RenderTarget2D` has no face here and
CNA reports positive X for one — "meaningless for a 2D target and must then be
positive X" — so a faceless binding is checked against *that*, rather than having
its face skipped.

`tests/native/render-target-cube.lisp` mutates the record four ways that need no
particular renderer — a wrong face, one binding too many, one too few, and a live
target that is not the bound one — and two more where the renderer allows them: a
swapped pair, which only the order distinguishes, and a cube binding whose face is
wrong, where the target handle is identical either way. Measured: HEADLESS runs
all six; SOFTWARE runs the first four and refuses to bind two targets at once
("SoftwareRenderer does not support multiple simultaneous render targets") or a
cube at all, which the test states rather than passes over.

### `RenderTargetBinding.CubeMapFace` answers NIL for a 2D target

Reported partial. XNA's struct is a value type and cannot hold "no face", so a
binding made from a `RenderTarget2D` answers `CubeMapFace.PositiveX` there —
a real value that means nothing. This answers `NIL`, which says "no face" without
claiming a face. `MAKE-RENDER-TARGET-BINDING` enforces the same distinction from
the other side: a cube requires a face and a 2D target refuses one, because those
are exactly XNA's two constructors.

## Content: what loads, and the two things that do not follow XNA

`ContentManager` is projected, `Game.Content` with it, and that is what makes a
`SpriteFont` obtainable at all — before it, the only producer in this binding was
a test-only one and no program written against the public API could draw text.

`Load<T>` is the one place this projection is **closer** to XNA than the C ABI
can be. CNA spells the generic method as one route per asset type —
`cna_content_manager_load_texture2d`, `..._load_sprite_font`,
`..._load_texture_cube` — because a C caller cannot name a type. Common Lisp can,
so the type stays an argument:

```lisp
(let ((content (xna:content game)))
  (setf (content:root-directory content) "Content")
  (multiple-value-bind (font atlas)
      (content:load-asset content 'gfx:sprite-font "font")
    ...))
```

`LOADABLE-ASSET-TYPES` answers the three types above, which is why `Load` is
reported **partial**: XNA's is generic over anything with a content reader, and
the set here is finite because CNA's routes are.

### The asset format is `.cnj`, measured and not assumed

CNA's header says the SpriteFont loader "reads both the `.xnb` font container and
CNA's own `.cnj` font descriptor". Measured against ABI 0.21.0, a `.cnj` loads
with or without its extension in the asset name, and the older `.font.json`
convention its own design notes mention does **not** — it fails with
`CNA_RESULT_IO`. `tests/fixtures/test-font.cnj` is the descriptor this suite
uses, and `tools/qualification/make-font-fixture.py` generates the template's.

### `Load<SpriteFont>` answers two objects, because a font is two things

CNA hands back the glyph atlas alongside the font: "handing back only the font
would leave the atlas alive but unnameable". Both are owned resources, so both
come back here, and both must be disposed — **the font first**, because a
SpriteFont keeps its atlas alive and CNA refuses the other order. The binding
records that parenting, so the wrong order is a diagnosable refusal rather than a
native failure.

### The cache is XNA's, and now so is `Unload`

XNA's `ContentManager` keeps two collections and they are two for a reason:
`loadedAssets`, a `Dictionary<string,object>` keyed by asset name, and
`disposableAssets`, a list of every disposable the loading *created* — which for
a `SpriteFont` is two objects for one name. `Load<T>` cleans the name with
`TitleContainer.GetCleanPath`, looks it up, answers the cached instance on a hit
and adds on a miss; `Unload` disposes every entry in the second list and clears
both in a `finally`; `Dispose` is `Unload` and then nulling them.

All of that is reproduced. Read from the pinned IL rather than described:

| Step | XNA | Here |
| --- | --- | --- |
| disposed manager | `ObjectDisposedException` | `CNA-DISPOSED-ERROR` |
| null or empty name | `ArgumentNullException("assetName")` | `CNA-ARGUMENT-ERROR`, parameter `asset-name` |
| name normalisation | `TitleContainer.GetCleanPath` | the same function, literally |
| cache hit, right type | the cached instance | the same objects |
| cache hit, wrong type | `ContentLoadException` | `CNA-ARGUMENT-ERROR` naming both types |
| cache miss | read, then `Add` | load, then commit inside the load's ledger |

The cache is keyed by the **cleaned name alone and not by the type**, which is
why a hit of the wrong type is a failure rather than a second load — and why
`"./x"` and `"x"` are one entry. `Load<SpriteFont>` twice therefore answers one
font and one atlas, and `Unload` is what frees them.

**The commit is inside the load's rollback ledger**, which is what makes the last
step of a load recoverable: by the time an asset reaches the cache CNA has handed
back every handle, the metadata is read, the objects are built and the game owns
them, and a failure there still has to give all of it back.
`tests/native/content-atomicity.lisp` makes exactly that failure happen, which is
the strongest state the transaction is tested from.

**One deliberate divergence in `Unload`, and it is a divergence.** XNA's has no
error handling: a throwing `Dispose` stops the walk while the `finally` still
clears both collections, so every remaining asset is stranded with nothing left
that can reach it. In .NET a finalizer eventually collects them; there are no
finalizers here by policy, so reproducing that would leak *permanently* and fail
the game's teardown — a worse outcome than XNA's, not the same one. So this
releases every independent asset and then signals the first failure. CNA's own
`cna_content_manager_unload` is called as well, so neither side is left holding
an asset the other has let go: that route drops CNA's cache and, in its own
words, "independently owned resource handles returned by the manager are not
destroyed by this call" — which is why the disposing half has to be this
binding's.

**`Game.Content` is disposable, and that is XNA's shape too.** `Dispose()` there
destroys nothing native, because there is nothing native; it unloads and marks
the manager finished. So it does here: the assets go, the facade is marked
disposed, `Game.Content` keeps answering it as XNA's field does, and every member
on it then refuses. The borrowed native manager CNA lends is left alone, which
costs nothing. The other parent-owned facade, `GraphicsDevice`, still refuses
disposal — it has nothing of its own to release, and `GraphicsDevice.Dispose` is
itself reported missing.


### A loaded `Texture2D` cannot report its size

`Texture2D.Width` and `Height` are reported **partial**, and this is the reason.
ABI 0.21.0 has no route that answers a texture's dimensions:
`cna_texture_get_info` answers the level count and the surface format,
`cna_texture2d_get_storage_info` answers which storage is retained, and neither
answers a width. A texture decoded through `TEXTURE-2D-FROM-PNG-BYTES` knows its
size because this binding read it out of the PNG header on the way past; one the
content manager loaded was never handed to this binding as bytes, so there is
nothing to have read. `WIDTH` and `HEIGHT` **refuse** on such a texture, with a
condition naming the missing route. Answering zero would be a lie that draws
wrong-sized quads.

A `TextureCube` has no such problem: `cna_texturecube_get_info` reports its edge
size, so a loaded cube is as complete as a constructed one. The asymmetry is
CNA's.

Every route that might have closed this was checked against 0.21.0's headers, so
that the search is not repeated:

| Route | What it answers |
| --- | --- |
| `cna_texture_get_info` | level count and surface format |
| `cna_texture2d_get_storage_info` | whether renderer and CPU-shadow storage are retained |
| `cna_texture2d_get_encoded_byte_count`, `..._copy_encoded` | encode to a `target_width`/`target_height` the **caller** supplies — they take a size rather than reporting one |
| `cna_texture2d_get_data` | `out_required_elements` for the requested region: with no rectangle at level 0 that is width × height, the *area*, which does not give back the two factors |
| `cna_content_manager_get_manifest_entry` | whether an entry has an `.xnb` or a `.cnj`, its relative path and reader names |

The closest miss is `get_data`'s required element count. A texture of 96×96 and
one of 144×64 are both 9216 elements, so it cannot answer the question, and
guessing a square from an area would be wrong exactly when it mattered. Closing
this needs a CNA route, not a cleverer caller.

### Three members of `ContentManager`, and `Game.Content`'s setter

* **Both constructors** take a `System.IServiceProvider`, which this binding
  cannot produce — the same obstacle `Game.Services` runs into above. CNA's own
  constructor takes the graphics device instead, and `MAKE-INSTANCE` projects
  *that*, as a declared extension rather than as either canonical overload.
* **`ServiceProvider`** is missing for the same reason.
  `cna_content_manager_get_has_service_provider` reports whether the native
  manager has one, not what it is.
* **`ReadAsset` and `OpenStream`** are protected hooks. CNA's loaders read and
  construct in one route with no callback in between, and no stream object
  crosses its C boundary.
* **`Game.Content`'s setter** is not projected, which is why that member is
  partial. XNA's `Game.Content = m` assigns a reference; CNA's
  `cna_game_set_content_manager_ext` **copies** — its header says "the canonical
  setter takes a reference and copies, so this does too: the caller keeps its own
  manager". Reading the property back would answer a different object than the
  one assigned, and a setter that silently means something else is worse than a
  missing one.

**A refused disposal costs the object nothing, and that took fixing.** `DISPOSE`
invalidates through an `UNWIND-PROTECT`, and a parent-owned facade's refusal used
to be raised from inside it, in `DESTROY-NATIVE`. The refusal was right and the
facade paid for it anyway: it came back marked disposed and holding no handle,
over a native object that had — correctly — never been destroyed. A caller who
wrapped the refusal in `HANDLER-CASE`, which is the reasonable thing to do with a
refusal, was left with a poisoned facade. The refusal is now `%CHECK-DISPOSABLE`,
called before `DISPOSE` touches anything.

`GRAPHICS-DEVICE` is the facade that still refuses, and it had the same bug and
worse: with no `DESTROY-NATIVE` method at all, disposing it was a
`NO-APPLICABLE-METHOD` raised from inside the same `UNWIND-PROTECT`, which then
invalidated the device the game draws through. `Game.Content` is no longer part
of that story — see the cache section above for why it is disposable.

**A `ContentManager` is built one of exactly two ways, and neither of them is
"partly".** `(make-instance 'content-manager)` used to succeed and answer a
zombie: a zero handle, no owner, no registered loaders, and a failure deferred to
whichever operation happened first. An owned manager now refuses to exist without
the graphics device `cna_content_manager_create` takes; a game's own manager is a
facade built by `MICROSOFT.XNA.FRAMEWORK:CONTENT` and by nothing else, and
refuses both that device and a root directory at construction.

## The component engine runs, and two things around it do not

`GameComponent`, `DrawableGameComponent`, `GameComponentCollection`,
`GameComponentCollectionEventArgs`, `IGameComponent`, `IUpdateable`, `IDrawable`
and `LaunchParameters` are complete, and `Game.Components` and
`Game.LaunchParameters` with them.

**The engine is CNA's and it is really wired up.** A component is not a list this
binding walks: `cna_game_components_add` puts it in the collection the game
drives, and CNA calls `Initialize`, `Update`, `Draw`, `LoadContent` and
`UnloadContent` in its own order, honouring `UpdateOrder`, `DrawOrder`, `Enabled`
and `Visible`. The tests assert *counts taken inside the loop* rather than that
the members exist: a disabled component's update count stays zero, an invisible
one's draw count stays zero, and two components with different `UpdateOrder`
values record the order they were actually called in — added in the wrong order
on purpose, so insertion order cannot pass for ordering.

A component's behaviour is its CLOS methods on the same generic functions a
`Game` specialises. There is no registration step, because CLOS is the
registration.

### A component added during LoadContent is never initialized

Surprising, and it is XNA's behaviour rather than CNA's defect. Read from the
pinned `Microsoft.Xna.Framework.Game` assembly:

* `Game.Run` calls `Initialize()` and sets `inRun = true` **afterwards**;
* `Game.Initialize()` drains `notYetInitialized` and then, at its very end, calls
  `LoadContent()`;
* `Game.GameComponentAdded` initializes the component only `if (inRun)`, and
  otherwise puts it on `notYetInitialized`.

So a component added inside `LoadContent` arrives after the drain loop has
finished and while `inRun` is still false: it goes on the list and stays there.
It is updated and drawn every frame and initialized never. CNA reproduces that
exactly, measured, and `tests/native/game-components.lisp` pins it — so a CNA
that changed it would fail rather than pass quietly. Add components in
`Initialize` or later.

### `Game.Services` is not projected, and not for the reason this file used to give

`Game.Services` is in the selection and is **missing**. `GameServiceContainer`
itself is not in the selection at all — it arrives with the device-settings
closure.

An earlier version of this section said the blocker was that
`IGraphicsDeviceService` and `IGraphicsDeviceManager` are not projected, and that
the first needs `GraphicsDevice`'s four device-loss events. **That was wrong, and
re-reading the pinned metadata is what corrected it.** `IGraphicsDeviceService`
is five members — the `GraphicsDevice` property and the `DeviceCreated`,
`DeviceDisposing`, `DeviceReset` and `DeviceResetting` events — and all five are
already *complete* here, on `GraphicsDeviceManager`, which is the type that
implements the interface. `IGraphicsDeviceManager` is `CreateDevice`, `BeginDraw`
and `EndDraw`, which `GraphicsDeviceManager` implements explicitly, and CNA has a
route for each of the three.

The mistake was a name collision. `GraphicsDevice` has its own `DeviceReset` and
`DeviceResetting` events, alongside `Disposing`, `ResourceCreated`,
`ResourceDestroyed` and `DeviceLost`; those six are all missing, but they are a
different set on a different type and the service interface does not ask for
them. Two types with two same-named events was enough to produce a confident
paragraph about the wrong one.

**The real obstacle is that CNA's service container is not a container.**
Re-audited against 0.21.0's headers, route by route, so the claim is a
measurement:

| Operation | Route | What it does |
| --- | --- | --- |
| contains | `cna_game_services_contains_ext` | answers a boolean for one of two identities |
| remove | `cna_game_services_remove_ext` | removes one of those two |
| get | — | **none** |
| register / add | — | **none, and deliberately so** |

Both existing routes are keyed by a closed `CNA_GAME_SERVICE_TYPE_*` enum with
exactly two members, the graphics device manager and the graphics device service.
CNA says why there is no third and fourth, and the reason is sound: "the canonical
container is keyed by C++ type identity, which has no C expression: a C consumer
cannot name a type, and cannot author an object implementing a C++ interface to
register under one." The registration route is not an omission but a stated
decision — "A route that accepted an opaque token instead would satisfy neither
side: native code asking for `IGraphicsDeviceService` needs a vtable, not a
`void*`" — and CNA's advice is that a consumer keep its own container beside this
one.

So `GetService` — the member the type exists for — cannot be answered *from CNA*
for the two services XNA's own runtime registers. `contains_ext` says whether one
is registered; it does not hand it back.

**A managed-side mirror is conceivable and is not being taken as a shortcut.**
This binding does hold the object in question: CNA's header records that creating
the manager "registers it as the game's graphics device manager and graphics
device service", and the manager is a Lisp object here. So a container could
answer both canonical keys from the record, ask `contains_ext` before doing so,
and route a removal through `remove_ext` so the two sides agree — and hold a
program's own services in a Lisp dictionary, which is exactly where CNA says they
belong and where XNA keeps them too, since nothing native reads them in XNA
either.

What stops that being done here and now is scope, not doubt: `GameServiceContainer`
is **not in the selection**, and putting it there means importing the type from the
pinned contract and reading its three members out of the IL. That is the
device-settings closure's work, and it is listed there rather than done early. A
Lisp dictionary *on its own* — one that answered a program's own services and
invented the two canonical ones — remains refused, because inventing them is the
part that would be wrong.


### LaunchParameters is empty unless the program fills it

CNA has no route that reports a game's command line, so `Game.LaunchParameters`
answers an empty map. The type, its identity across reads and its string-to-string
storage are all real; what is absent is anything to put in it. `LAUNCH-PARAMETER`,
its setter and `LAUNCH-PARAMETER-NAMES` are declared extensions, because XNA
derives the type from `Dictionary<string, string>` and adds nothing, so every
operation on one belongs to the BCL dictionary rather than to XNA.

### `GameComponentCollection`'s constructor is not projected

XNA's is public and a standalone collection is legal there, if useless — a `Game`
makes its own and drives that one. CNA has no route for a collection apart from a
game's: "a game owns exactly one component collection, so the collection needs no
handle of its own and every route addresses the game's". So a standalone one is
reported missing rather than faked, and it is the only missing member of the
type.

## Render targets, and the one thing they change about the evidence

`RenderTarget2D`, `RenderTargetUsage` and `DepthFormat` are complete, and
`GraphicsDevice.SetRenderTarget(RenderTarget2D)` with them. A `RenderTarget2D`
**is** a `Texture2D` here, as XNA's is, so a finished target is an ordinary
texture that `SpriteBatch` can draw and an effect can sample.

That inheritance is what changes the qualification. Until now every pixel claim
in this repository rested on `GraphicsDevice.GetBackBufferData`, which most
renderers refuse. Two things replace it. A render target's contents can be drawn
back onto the screen, because a target *is* a texture; and since `Texture2D`
gained `GetData` they can be read **directly**, with no back buffer in the
picture at all. The `render-target-data` proof does exactly that — all 256 texels
of a cleared target — and is the first evidence here that a renderer with no
readback could in principle produce. `HEADLESS` still refuses it, and the test
asserts the refusal rather than skipping.

Three properties are read back out of CNA at construction rather than echoed from
the constructor's arguments: `RenderTargetUsage`, `MultiSampleCount` and
`DepthStencilFormat`. A backend may grant less than was asked for, and reporting
the request is how a program comes to believe it has multisampling it has not
got.

`IsContentLost` is asked of CNA per read rather than cached, and is false on both
qualification renderers — not because nothing was tested, but because CNA
reports it only from the moment a renderer announces a real *device loss*, and
only `DIRECTX9`, `DIRECT2D` and `SKIA` can announce one. A caller-initiated reset
does not set it. The `ContentLost` subscription and its release are real and are
exercised; the raise is CNA's to make and neither qualification renderer ever
will.

**Three of `GraphicsDevice`'s render-target members are still absent**, and for
one reason: `SetRenderTarget(RenderTargetCube, CubeMapFace)`,
`SetRenderTargets(RenderTargetBinding[])` and `GetRenderTargets()` all need
`RenderTargetCube` and `CubeMapFace`, and `RenderTargetCube` derives from
`TextureCube`, which needs the texture data surface `Texture2D` has not got here
either. They carry explicit absences in the mapping rules rather than being left
to the default naming rule — which would have resolved the cube overload onto
`SET-RENDER-TARGET`, the 2D one, and reported it complete.

## The stock effects, and what their evidence is worth

All four of XNA's other stock effects — `AlphaTestEffect`, `DualTextureEffect`,
`SkinnedEffect` and `EnvironmentMapEffect` — are implemented and complete. Every member of each round-trips through the CNA route the manifest
binds. **That is state evidence, and state evidence is not shading evidence**,
which is the distinction this section exists to keep.

| Effect | State round-trip | Reaches pixels | Its own shading |
| --- | --- | --- | --- |
| `AlphaTestEffect` | yes, every member | **yes** — a pass applied through it makes a `DrawUserPrimitives` triangle legal and the triangle's vertex colour lands on exactly the pixels its geometry covers | **no** — see below |
| `SkinnedEffect` | yes, every member | **yes**, the same proof | **no** — see below |
| `DualTextureEffect` | yes, every member | **no** | no |
| `EnvironmentMapEffect` | yes, every member | **no** | no |

### The alpha test is not implemented by the SOFTWARE renderer

Measured, not inferred. CNA's `GpuDrawParams` carries an `alphaTest[4]` vector
and an `alphaTestEffect` flag, and
`modules/renderers/software/src/SoftwareRenderer.cpp` contains no reference to
`alphaTest` at all. So `AlphaFunction` and `ReferenceAlpha` reach the ABI, are
stored, and read back — and change no pixel: an `AlphaFunction` of `Never` with a
`ReferenceAlpha` of 128 draws exactly the triangle `Always` draws.

This is an upstream renderer limitation and not a projection defect, and
`tests/native/rasterization.lisp` pins it in both directions the way the
`DepthStencilState` divergence is pinned: the state is asserted to round-trip,
and the *absence* of any pixel that the alpha test decided is stated rather than
left to be inferred from a passing suite. A CNA whose software renderer grew an
alpha test would make that test's premise false, which is the point of writing it
down.

### Skinning needs a vertex layout this milestone does not project

The software renderer *does* implement a bone palette, but only for a skinned
vertex layout — blend indices and weights, stride 52. None of XNA's four standard
vertex types carries those, and `VertexPositionNormalTextureSkinned` is not
projected here. So `SetBoneTransforms` and `GetBoneTransforms` round-trip a
palette of up to 72 matrices, and replacing bone zero with a translation moves
nothing drawn from a `VertexPositionColor` array. Correctly so, and with no pixel
evidence about skinning anywhere in this repository.

### DualTextureEffect has no pixel evidence at all

It needs two things this milestone cannot give it together: both texture layers
assigned — CNA refuses the draw outright without the second, with
`"dualTexture=true but texture1 is null"` — and a second texture coordinate,
which no standard XNA vertex type has. Its state round-trips, including the two
layers being independent of each other, and nothing here says what it rasterises.

### EnvironmentMapEffect and TextureCube, and the one thing that is partial

Both are complete now — `EnvironmentMapEffect` waited for `TextureCube`, and
`TextureCube` waited for the texture data surface `Texture2D` gained first — so
**all four stock effects are implemented**.

`TextureCube` is a `Texture` and deliberately *not* a `Texture2D`: XNA derives it
straight from `Texture`, because a cube has no single width and height, it has a
`Size` that is the edge of every face.

Its `SetData` and `GetData` are the only **partial** members in this closure, and
the reason is CNA's. `cna_texture2d_set_data` names a texel *kind*, so
`Texture2D`'s projection takes five element types; `cna_texturecube_set_data`
takes `const CNA_Color*` with no kind argument, so a cube face is transferable
only as `Color`. XNA's `SetData<T>` is generic over anything blittable, so that
is a real narrowing of a member rather than a missing one — the six overloads are
reported partial, and an element type beyond `Color` is refused by name with that
reason rather than quietly reinterpreted.

**Cube-face storage is a renderer capability**, and CNA says so: creation "may
succeed even when face storage is unavailable", and a transfer then answers
`NOT_SUPPORTED`. Measured: `HEADLESS` has none and refuses, and `SOFTWARE` has it
— under `SOFTWARE` all six faces are written and read back and the test proves
each keeps its own texels, which is what tells a real face selector from an index
that is ignored. The test branches and both branches assert: a renderer without
the storage must refuse *by name*.

`RenderTargetCube` and `RenderTargetBinding` are still absent, and with them
`GraphicsDevice`'s `SetRenderTarget(RenderTargetCube, CubeMapFace)`,
`SetRenderTargets` and `GetRenderTargets`.

## SpriteFont has no constructor, and that is XNA's shape

Every member of `SpriteFont` is implemented and measured, and **a program obtains
one through `ContentManager.Load<SpriteFont>`** — which is the only way XNA offers
either. XNA's constructor is `assembly`-visible; a consumer never calls it.

CNA does have `cna_sprite_font_create`, and projecting it as a public constructor
would invent a member XNA has not got, so it is not projected as one.
`%MAKE-SPRITE-FONT-FROM-GLYPHS` is unexported, exists so that measurement, the
default-character fallback and `DrawString` could be qualified before
`ContentManager` landed, and is not part of the API. The template does not use it
and must not: a template that reached into the binding's internals to show text
would stop being a consumer. It draws text through the public content path
instead, and the SOFTWARE lane asserts the pixels.

### System.Char is an integer here, not a character

A CLR `char` is a **UTF-16 code unit**: sixteen bits, all 65536 values legal,
including an unpaired surrogate such as `0xD800`. It is not a Unicode scalar
value, not a code point, and not a Common Lisp `character`. So `System.Char`
projects onto **an integer in [0, 65535]**, and `Nullable<Char>` onto `NIL` or
one — unambiguously, because `0` is a real code unit and is not `NIL`, which is
the distinction `DefaultCharacter` needs between "no fallback" and "fall back to
U+0000".

The consequence for text is not cosmetic. A Common Lisp string is a sequence of
code *points* and a `System.String` is a sequence of code *units*; they agree
across the whole BMP and disagree above it, where `U+1F600` is one character here
and two chars there. XNA looks each of those two up in the glyph table
separately, so `MeasureString` and `DrawString` convert to code units first and
measure the surrogate pair, which is what XNA measures.

`StringBuilder` is not projected as a type. `SpriteFont` and `SpriteBatch` reach
one only through `Length` and `Chars` — XNA's own private `StringProxy` wraps a
`String` or a `StringBuilder` and the bodies that follow are identical — and a
Common Lisp string is already a mutable random-access sequence, so both
parameter types project onto `string`. The two contract members are still two
members: the mapping rules declare the collapse and the verifier refuses a
collapse that does not name what it collapses.

### `Characters` keeps XNA's immutability and gives up its identity

XNA answers a `ReadOnlyCollection<char>`, made lazily and then cached, so the
*same instance* comes back every time and no caller can modify it. Common Lisp
has no read-only vector, so a projection can have one of those properties or the
other. This one answers a **fresh** `(unsigned-byte 16)` vector per call: what
comes back cannot be used to modify the font, and reference identity is the
property that cannot be relied on. The choice is the one that cannot be silently
wrong — a cached vector a caller had mutated would disagree with the font's own
lookups and say nothing about it.

### Where CNA is stricter than XNA, and XNA wins

XNA's `LineSpacing` and `Spacing` setters are a bare `stfld` with no validation
at all: a negative or zero line spacing is accepted, and so is a `Spacing` of NaN
or either infinity. CNA's `cna_sprite_font_set_spacing` documents *"Must be
finite"* and would refuse those.

No managed validation is added here to match CNA, because that would refuse
programs XNA runs. Instead `LineSpacing`, `Spacing` and `DefaultCharacter` are
managed fields — XNA's are too, and `InternalMeasure` and `InternalDraw` read
them from the object — and since both algorithms are computed in Lisp, nothing
native reads them. The three CNA setters are therefore **not bound at all**,
rather than bound and worked around.

What that costs is exact and worth stating: after `(setf (spacing font) x)` the
native font still holds the spacing it was created with. Nothing in CNA-Lisp
reads it, so nothing here is affected; a future member that handed the native
font to CNA for its own layout would have to write the value through first, and
would then have to decide what to do about the NaN.

`cna_sprite_font_measure_utf8` has a narrower limitation of the same kind: it
takes UTF-8, which cannot encode an unpaired surrogate, while a `System.String`
can hold one and `MeasureString` here can measure one. It is bound and
cross-checked against this implementation over the text where the two domains
overlap — `tests/native/sprite-font.lisp` — as a comparison and never as an
authority. It agrees.

### SpriteFont is not IDisposable, and its handle is still released

XNA's `SpriteFont` is `sealed` and extends `System.Object`. It is not a
`GraphicsResource`: no `Name`, no `Tag`, no `GraphicsDevice`, no `Disposing`
event, and no `Dispose`. CNA nevertheless hands out an owned handle that must be
given back.

Those are two questions and they are answered separately. The public shape is
XNA's; the handle goes back through `MICROSOFT.XNA.FRAMEWORK:DISPOSE`, which is
this binding's own deterministic disposal — a declared extension on every native
object — and is **not** counted as an XNA member of this type. Nothing here
claims `SpriteFont` implements an XNA `IDisposable` contract, because it does
not.

The font is registered as a child of its **atlas texture**, not of the game. CNA
parents the native font to the game, but the resource whose destruction would
invalidate the font is the texture — CNA's own header says it "cannot be
destroyed until this SpriteFont is destroyed" — so disposing them in the wrong
order is a refusal naming both types instead of a native failure later. The game
still refuses while the texture lives, so CNA's ordering holds transitively.

`ContentManager` has arrived, and `Unload` is **not** yet the thing that disposes
both: CNA's unload does not destroy what it handed out, which is why `Unload()`
and `Dispose()` are reported partial above. Disposal is the caller's, font first.
No public `Texture2D` atlas is exposed for a SpriteFont, because XNA exposes none.

## The foreign layer is qualified for one host, and refuses the others

CNA-Lisp's by-value flattening is the System V AMD64 ABI's rule and only that: a
`CNA_Vector3` travels as a `:double` and a `:float` because that is what SysV
does with two SSE eightbytes. The Microsoft x64 ABI passes a 12-byte aggregate by
*reference*.

So opening the native boundary on another host would not be an unqualified
configuration — it would be **the wrong calling convention**, putting arguments
in the wrong registers and reporting nothing. `ensure-native-library` therefore
refuses anything that is not SBCL on Linux x86-64, with a
`cna-not-supported-error` that says which of the three facts disagreed and why
the refusal is about correctness rather than support.

The refusal is at the boundary and nowhere earlier. Everything in CNA-Lisp that
touches no native route — the math types, the bounding volumes, the `Curve`
family, the packed vectors, the enumerations, the conditions — is ordinary ANSI
Common Lisp and loads and runs anywhere.

Lifting this is real work rather than deleting a check: the generator would have
to classify against the target ABI, the valueprobe would have to be built and run
there, and the qualification would have to say so. `tests/native/abi-gate.lisp`
fakes each of the three facts in turn and requires the refusal, because there is
no honest way to run this suite on a Windows x64 image to find out.

## No `cffi-libffi`, and what that costs

CFFI cannot pass a structure by value without `cffi-libffi`, and `cffi-libffi`
requires libffi headers and a C compiler at load time. CNA-Lisp does not depend on
it, so a released binding needs neither.

The cost is that a route taking a by-value aggregate the System V AMD64 ABI
classifies as MEMORY — one larger than 16 bytes, which travels on the stack —
cannot be bound. An aggregate of at most 16 bytes *can*: each of its eightbytes
is passed as one scalar of the eightbyte's own class, an integer for INTEGER and
a double (or a float for a trailing four-byte one) for SSE. See
`docs/native-abi.md`, and `tests/native/struct-passing.lisp` for the proof
against a C compiler's own idea of the convention.

Four members are affected, all taking `CNA_Matrix` (64 bytes) or `CNA_Viewport`
(24 bytes) by value: `GraphicsDevice.Viewport`'s setter and `BasicEffect`'s
`World`, `View` and `Projection` setters. The refusal is proved by the generator,
not asserted.

It is **not blocked**, though. The generator emits a tiny private shim -- a
wrapper that takes the aggregate by pointer and the real route by function
pointer, and does nothing else -- and those four setters go through it. The shim
is optional and is **not shipped prebuilt**, because a released CNA-Lisp must
load with no C toolchain: `tools/native-abi/verify.sh` builds it, `CNA_LISP_SHIM`
names it, and without it each setter signals a `cna-not-supported-error` naming
the variable, the command and the reason. The readers work either way.

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

## `System.IO.Stream` is a Common Lisp stream, and is not a projected type

`Stream` is **not in the pinned contract**: that snapshot is the XNA profile, and
`Stream` belongs to the BCL. So there is no selected type here to be complete or
partial about. What there is, is five XNA members that take or answer one — four
on `Texture2D` and `TitleContainer.OpenStream` — and a language with its own
equivalent abstraction.

`System.IO.Stream` therefore maps onto an **ordinary Common Lisp binary stream**.
A consumer passes a stream from `OPEN`, and `WITH-OPEN-FILE`, `READ-SEQUENCE`,
`FILE-POSITION` and `CLOSE` all mean what they already mean:

```lisp
(with-open-file (out "shot.png" :direction :output
                                :element-type '(unsigned-byte 8))
  (gfx:save-as-png texture out 64 64))
```

**`SeekOrigin` is not projected, and needs no entry of its own.** .NET spells
relative positioning as an enumeration argument to `Stream.Seek`; Common Lisp
spells it as arithmetic on `FILE-POSITION`. An enumeration to pass to a function
that does not take one would be a type nobody could use.

**XNA's checks are reproduced in XNA's order.** `Texture2D.SaveAsImage` reads as
a null check and then a capability check, both `ArgumentException`s naming the
parameter, and that is what happens here against `INPUT-STREAM-P` and
`OUTPUT-STREAM-P`. Three things a Common Lisp stream makes different:

* **There is no `Length`, and none is asked for.** `FILE-LENGTH` is a file
  stream's member and a non-seekable stream answers NIL from `FILE-POSITION`, so
  reading goes on until `READ-SEQUENCE` returns short. That is end-of-file for
  every stream kind and the only correct response to a partial read.
* **A stream has an element type.** .NET has one `Stream` for bytes and for text;
  Common Lisp does not, so a character stream is refused by name rather than read
  as something it is not.
* **A closed stream is an argument failure, not a disposal — on both sides.** A
  disposed .NET `Stream` answers *false* from `CanRead` and `CanWrite`, so the
  check XNA reaches first is the capability one and what it throws is
  `ArgumentException`. Measured on this runtime: SBCL's `INPUT-STREAM-P` answers
  NIL for a closed stream too. The two agree, and the condition text says so, so
  the diagnosis is not lost.

**Ownership is the caller's in both directions.** Nothing closes a stream it was
given — XNA does not either, and a member that closed its argument would break a
`WITH-OPEN-FILE` around it. There is no leave-open flag because there is nothing
for one to control.

### `Texture2D.FromStream`'s two overloads are both partial, for different reasons

`SaveAsPng` and `SaveAsJpeg` are **complete**, and the evidence is a round trip: a
two-by-two texture of four different opaque colours is encoded to a file and read
back with every texel intact, so neither the encoder nor the decoder can pass by
doing nothing. The JPEG is not compared texel for texel — it is lossy — but it is
a different size from the PNG *and* decodes back into a texture, which arbitrary
bytes would not.

`FromStream` is partial twice over:

* The **two-argument** overload is, read from the assembly, the private
  constructor called with the graphics profile's `MaxTextureSize` for both
  extents: XNA *fits* an oversized image down to what the profile can hold. CNA's
  null decode info "preserves source dimensions", which is this overload without
  that fit, and ABI 0.21.0 reports no maximum texture size for a fit to be
  computed from. An image within the limit decodes identically; a larger one
  decodes at its own size here and at the limit there.
* The **five-argument** overload reaches CNA exactly — XNA computes
  `zoom ? 3 : 1` and `CNA_Texture2DDecodeInfo` carries a width, a height and a
  `zoom` flag meaning "cover-and-crop" against "fit while preserving aspect
  ratio". What is partial is what the result can say about itself: a *zooming*
  decode covers and crops, so `WIDTH` answers the requested extent, while a
  *fitting* decode answers something no larger and 0.21.0 reports no texture
  extent, so `WIDTH` refuses there.

### The extent a decoded texture reports, and when it refuses

`%DECODED-DIMENSIONS` reads the size out of the **PNG header** on the way past,
because CNA reports no texture extent. It used to answer zero for a payload that
was not a PNG, and zero is a number a caller draws a quad with. It answers NIL
now, and `WIDTH` and `HEIGHT` refuse — which is what "report what is actually
known: nothing" has to mean. This is reachable rather than theoretical: CNA
decodes JPEG and DDS as well as PNG, and `FromStream` will hand any of them to it.

## `TitleContainer.OpenStream` is partial, and only for two named reasons

Almost all of this member is *validation*, and the validation is XNA's own,
transcribed from the pinned assembly rather than delegated to CNA or to the host.
`GetCleanPath` folds slashes to backslashes, collapses `\.\`, strips a leading
`.\` and a trailing `\.`, and resolves `\..\` segments left to right;
`IsCleanPathAbsolute` then refuses a rooted path, a leading or trailing `..`, an
embedded `\..\`, and any of seven characters.

**Those seven were read out of the assembly's static data, not guessed.** XNA's
`badCharacters` is a seven-element `char[]` initialised from a fourteen-byte blob
that disassembles as `3A 00 2A 00 3F 00 22 00 3C 00 3E 00 7C 00` — `: * ? " < > |`.

The order of the two steps is the part a reimplementation gets wrong. Cleaning
happens **first**, so `a/../b` resolves to `b` and is accepted, while `../b` is
left alone by the cleaning and refused by the check. A validator that searched for
`..` before cleaning would refuse the first, and would be wrong.

**CNA's route for this exists and is deliberately not used.**
`cna_title_container_read_ext` reads a whole file, and its own header says why:
"The canonical operation hands back an open stream. This ABI has no stream handle
for title content … so the count/copy pair delivers the whole file instead. That
is a deliberate narrowing: incremental reads over a title stream are not
available." XNA's member answers a `FileStream` — lazy, seekable, no larger in
memory than what has been read — and Common Lisp has exactly that in `OPEN`.
Taking CNA's narrowing would make this member *less* like XNA than the language
already allows, for no gain: reading a file is not a CNA-owned resource. What does
come from CNA is the **base path**, through `cna_title_location_copy_path`, so an
override made through the ABI is honoured exactly as XNA reads `TitleLocation.Path`.

Two things are not reproduced, and they are the whole of why this is partial:

* XNA round-trips the cleaned name through `new Uri(name, UriKind.Relative)` and
  turns any exception into an `ArgumentException`. No input that survives the
  checks above has been found to fail that construction — but this binding cannot
  *evidence* that it rejects nothing, and a step that might reject something is
  not a step that can be claimed as reproduced.
* XNA's member is static and needs no game. CNA's title-location routes take a
  game handle for thread affinity, so this needs the process's one active game —
  the same shape, and the same reason, as `Keyboard.GetState`.

A name that escapes the title is an **argument** failure; a name that merely names
nothing is an **IO** failure. That is XNA's distinction between `ArgumentException`
and `FileNotFoundException`, and collapsing the two would make a traversal attempt
look like a typo.

## The adapter surface is complete, and needs a device to reach

`GraphicsAdapter` is projected, and so is `DisplayModeCollection` with it, so
`GraphicsDevice.Adapter` is complete. The instance members are complete too:
reading an adapter's description or negotiating a format from inside a draw is
exactly as available here as it is in XNA.

**The two static members are partial, and the scope is why.**
`GraphicsAdapter.Adapters` and `.DefaultAdapter` are *static* in XNA and answer
before any device exists — that is how an XNA program picks the adapter it then
creates a device on. **Every** CNA adapter route takes a callback-scoped
graphics-device handle, so here they need a live game *and* a lifecycle method to
be inside, and by then the device has been created. The capability is there; the
moment it is available at is not, and the test asserts the refusal outside a
callback rather than leaving a caller to discover it.

An adapter holds **no handle**: CNA names one by a zero-based index into its own
enumeration, so the class is that index plus the game to ask through, and every
reader resolves the borrowed device handle per call — which is also what makes the
scope rule enforce itself.

Three smaller things, each measured rather than assumed:

* **`Revision` and `SubSystemId` are partial**, and CNA says why in its own
  struct: "current CNA returns zero". They answer zero on every adapter rather
  than the adapter's revision. The zero is CNA's answer passed through, not a
  number invented here. `VendorId` and `DeviceId` are *not* partial, because there
  zero is documented as meaning "unavailable" rather than "not implemented" —
  a distinction worth keeping.
* **`UseNullDevice` and `UseReferenceDevice` are written together.** XNA's are two
  static properties; CNA carries both per adapter and sets them with one route
  that takes the pair. So each setter reads its sibling back first, and a test
  checks that setting one does not silently clear the other.
* **`MonitorHandle` is missing because CNA refuses it**, in the same words it
  refuses `PresentationParameters.DeviceWindowHandle`: the native-monitor-handle
  mapping is "unavailable at the stable C boundary".

`QueryBackBufferFormat` and `QueryRenderTargetFormat` are a `bool` and three `out`
parameters in XNA, so they answer **four values with the boolean first** — the
projection `TouchCollection.FindById` already uses for that shape. CNA answers all
three in one `CNA_GraphicsFormatSelection`.

## The test suite runs on a virtual screen, and CI runs on none

CNA's SDL3 platform initialises the host's windowing stack **even under the
HEADLESS renderer** — the GTK warnings in a test log are it doing so — and the
suite creates and destroys a game hundreds of times. On a machine with a desktop
that is hundreds of window-system round trips against the screen someone is using.

`tools/qualification/with-virtual-screen.sh` runs a command on a fresh Xvfb
display, and the two qualification scripts route themselves through it. It is
deliberately **conditional**:

| | |
| --- | --- |
| `DISPLAY` set, `xvfb-run` present | a fresh Xvfb display |
| `DISPLAY` unset | unchanged — there is nothing to keep off |
| `xvfb-run` absent | unchanged, with one note on stderr |
| `CNA_LISP_NO_XVFB` set | unchanged, for watching the windows |

The second row is the one that matters. The `Native` workflow runs with **no
`DISPLAY` at all**, and that is a property worth keeping rather than an accident:
it is what proves the SOFTWARE renderer is a CPU rasteriser that needs no display.
A wrapper that *required* Xvfb would have quietly ended that proof.

## `Game.Window` is a facade too, and needs no callback scope

`GameWindow` is projected, and like `Game.Content` and the graphics device it is a
**facade over the game**: every CNA window route takes the *game* handle, because
CNA models the window as something the game has rather than as an object with a
handle. So it holds no handle, is not disposed, and disposing it is refused with a
condition that says why.

Unlike the graphics device it needs **no callback scope**. CNA takes an "active
owned or callback-borrowed game handle" for every window route, so a program can
read the client bounds or set the title before the loop starts — which is where a
program most wants to. That is XNA's shape too.

**Under a headless renderer the client bounds are legitimately `0x0`.** There is
no window; CNA answers what is true rather than refusing, and the test asserts a
non-negative extent rather than a positive one, because asserting positive would
be asserting that a headless run has a window.

**`GameWindow` is abstract in XNA**, and its six protected `On*` methods are how a
platform's concrete window raises the three events. They are not projected, for
the reason no protected raiser here is: the half that cannot be projected is the
half the member exists for. `Handle` is not projected either, and for a different
reason from `PresentationParameters.DeviceWindowHandle` — CNA *answers* it,
`cna_game_window_get_native_handle_ext` gives back a `uint64`, so the number is
available and what is missing is a type to put it in. Handing back a bare integer
a consumer can do nothing safe with is not that type.

### `WINDOW-TITLE` on the game used to go stale, and a test caught it

`MICROSOFT.XNA.FRAMEWORK:WINDOW-TITLE` is a declared extension — XNA has no
`Game.Title` — and it used to answer the slot the game was **created** with. That
is the same string only until something sets the title, and once `Game.Window`
existed, `(setf (title (window game)) ...)` was exactly that something: the two
readers disagreed, and the new test said so on its first run.

It reads from CNA now. The creation title is still kept, because the constructor
needs it before there is a game to ask, but nothing reads it afterwards.

## The device-settings surface, and how much of it CNA has

`GraphicsDeviceManager`'s **preference surface is complete**: `GraphicsProfile`,
`PreferredBackBufferFormat`, `PreferredDepthStencilFormat`, `PreferMultiSampling`
and `SupportedOrientations` each have a CNA get/set pair, and each projects as a
keyword — or a *list* of them for `SupportedOrientations`, because
`DisplayOrientation` carries the `FlagsAttribute`. The empty list is the zero
mask and reads back as `(:default)`, because that enum has a named zero.

`DefaultBackBufferWidth` and `DefaultBackBufferHeight` are `static initonly`
fields, so they are **functions of no arguments** rather than constants: a
`DEFCONSTANT` would promise an immutability the CLR field has not got. Their
values are 800 and 480, read from the pinned Game assembly's class constructor
(`ldc.i4 0x320`, `ldc.i4 0x1e0`) and not assumed — `GameWindow` in the same
assembly sets same-shaped defaults two instructions earlier and they are **not
the same numbers**, 800 by 600. A projection that reasoned about "the usual XNA
window size" would be wrong by 120 pixels.

### `Clear`'s three overloads, and where the quantisation comes from

All three are complete. `Clear(Color)` is the shape with none of `:OPTIONS`,
`:DEPTH` and `:STENCIL`; the two four-argument overloads take all three and are
told apart by the colour's type, which is real CLOS dispatch rather than a tag.

**The Vector4 overload quantises to eight bits per channel, and that is XNA's
doing, not CNA's.** Read from the assembly, `Clear(ClearOptions, Vector4, Single,
Int32)` is four instructions: `new Color(vector4)`, then the `Color` overload. So
the two four-argument forms are one operation. CNA *does* have a float clear route
— `cna_graphics_device_clear_rgba` — and reaching for it here would make this
member **differ** from XNA rather than match it. This is the shape of decision the
`DepthStencilState` divergence has the other way round: there CNA was wrong and
XNA won; here CNA offers something better and XNA still wins, because matching is
the job.

One thing `Clear(Color)` cannot reproduce exactly and does not claim to: in the
assembly it is `Clear(DefaultClearOptions, color, 1f, 0)`, and
`DefaultClearOptions` is derived from the *current* depth-stencil format — `Target`
alone, `Target|DepthBuffer` when there is a depth buffer, and all three when the
format is `Depth24Stencil8`. That state is `PresentationParameters`, which is
missing. CNA implements the canonical member, so `cna_graphics_device_clear_rgba`
carries it and the derivation stays CNA's rather than being guessed here.

### The device-settings snapshot: `DisplayMode` and `PresentationParameters`

Both are **classes in XNA and classes here, holding no native resource**: CNA
carries them as versioned value structs rather than as handles, so neither is a
native object, neither owns anything, and neither is disposed. Each reader copies
out of CNA at the moment it is asked, exactly as the graphics device resolves its
handle per call.

`PresentationParameters` is a **snapshot and not a live view**, and the difference
is one a program cannot currently act on: XNA's property answers the device's own
object, and mutating that changes nothing there either until a `Reset` — which is
not projected, so nothing here could act on it. `MAKE-INSTANCE` with no arguments
is XNA's parameterless constructor and its defaults come from
`cna_presentation_parameters_init` rather than being restated in Lisp, because a
list of numbers restated is a list of numbers that can drift. `Clone` goes through
`cna_presentation_parameters_clone` for the same reason: a field a later struct
version adds is copied by the routine that knows about it.

**`DeviceWindowHandle` is missing, and CNA refuses it by design.**
`cna_graphics_device_get_device_window_handle` answers `CNA_RESULT_NOT_SUPPORTED`
after validating the device — a native window handle is not something the stable C
boundary hands out — and an `IntPtr` is not a thing this projection has to hand
one back in.

**There is no `DISPLAY-MODE-EQUAL`, and CNA having a route for one is not a
reason.** `cna_display_mode_equals` compares two modes by width, height and
format. XNA's `DisplayMode` has **no equality members at all** — not
`Equals(Object)`, not `op_Equality` — so it is compared by reference there.
Projecting the CNA route would invent a member XNA has not got, which is the same
reason `cna_sprite_font_create` is not a public constructor. The route is not
bound.

`DisplayMode.TitleSafeArea` is `Viewport.GetTitleSafeArea(0, 0, Width, Height)` in
the assembly — the same static method `Viewport.TitleSafeArea` calls — so the
arithmetic lives in one place here too, and a test asserts the two answer the same
rectangle.

### The device raises four events, and they are its own

`Disposing`, `DeviceLost`, `DeviceReset` and `DeviceResetting`, over
`cna_graphics_device_subscribe_event`. Two things about them are worth writing
down, because both are decisions rather than mechanics.

**A subscription needs the callback scope; releasing one does not.** The device is
a facade with no handle, and the subscribe route wants the borrowed,
callback-scoped one — so `add-device-lost-handler` outside a lifecycle method is a
`CNA-SCOPE-ERROR`, exactly as every other device operation is. Unsubscribing is
different: `cna_graphics_device_unsubscribe` takes only the registration. That
asymmetry is what makes the teardown possible at all, because CNA requires every
registration to be **released before `cna_game_destroy` succeeds** and the game
destroys itself outside any callback. The game's `DESTROY-NATIVE :before` releases
the device's subscriptions along with the component collection's, and the test
leaves one subscription live on purpose so that a clean shutdown is the proof.

**`DeviceReset` and `DeviceResetting` are the device's own**, and are *not* the
same-named pair on `IGraphicsDeviceService`, which is complete on
`GraphicsDeviceManager`. They are two different events on two different types, so
they project onto two different generic functions in two different packages:
`GFX:ADD-DEVICE-RESET-HANDLER` is the device's and
`XNA:ADD-DEVICE-RESET-HANDLER` is the manager's. One XNA namespace is one Common
Lisp package, and that rule is what keeps the two readable apart. `Disposing` is
*not* like this — `GraphicsResource.Disposing` is in the same namespace, so it
really is one generic function with two methods.

Asking a device for an event it does not raise is a **name** error rather than a
runtime refusal: each event is its own generic function, so CLOS answers before
anything reaches the event table or CNA. That is the right answer and the test
pins it as one.

### What is still missing from the device, and why

`GraphicsProfile`, `DisplayMode`, `GraphicsDeviceStatus` and
`PresentationParameters` are complete. What is left is four different things:

* **`Adapter`** needs `GraphicsAdapter`, which is not in the selection.
  `cna_graphics_device_get_adapter_index` answers an index into CNA's own adapter
  queries, so the route is there and the type is not.
* **The three `Reset` overloads and `Present`** are device-lifetime operations
  rather than settings. `cna_graphics_device_present` exists; the `Reset` family
  needs a decision about what resetting means for a device CNA lends rather than
  lets a program construct.
* **Two of the six device events**, and only the two that carry a payload.
  `ResourceCreated` and `ResourceDestroyed` have routes, and CNA's own header is
  the reason to be careful: "the canonical event is raised from the
  graphics-resource base constructor, so the reported object is still under
  construction: its concrete type does not exist yet and no member of it can" be
  used. Projecting that needs a decision about what object a handler is handed,
  and a half-built resource is not it.
* **`new(...)`, `Dispose`, `IsDisposed` and `Disposing`** are the device as an
  object a program constructs, which a CNA-Lisp program never does.

`GraphicsDeviceManager`'s remaining ten are the five protected `On*` raisers,
`PreparingDeviceSettings` and its event args, and
`FindBestDevice`/`RankDevices`/`CanResetDevice`, which are the device-selection
algorithm rather than a setting.

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

* `GameServiceContainer` and `Game.Services` — see below;
* `ContentManager` and the XNB pipeline;
* `GameWindow` as a type -- only the window title is reachable, on `game`;
* `Model`, `Texture3D`, `TextureCube`, `RenderTargetCube` and the rest of the 3D
  resource surface;
* `EnvironmentMapEffect`, the one stock effect still absent — see below;
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

## A GraphicsResource without a handle is still a GraphicsResource

Five selected types hold no CNA handle and are `GraphicsResource` subclasses
anyway: `BlendState`, `DepthStencilState`, `RasterizerState`, `SamplerState` and
`VertexDeclaration`. CNA models each as a versioned descriptor -- there is no
create route and nothing to destroy -- and none of that stops them from being
what the contract says they are.

XNA's own base class is written for the case:
`GraphicsResource::get_Name` reads the device's cache when `_internalHandle != 0`
and its own `_localName` field otherwise. `Tag`, `IsDisposed` and `Disposing` are
ordinary managed fields, and `GraphicsDevice` is `_parent`, which is **null until
the resource is applied** and is set by `Apply`.

So the projection has one public root and two private branches:
`%managed-graphics-resource` for the five with no handle, and
`%native-graphics-resource` -- which also inherits the ownership machinery -- for
`Texture`, `Texture2D` and `SpriteBatch`. Each branch has exactly one disposal
mechanism, there is no diamond, and no managed-only resource fabricates a handle.

What that means for a consumer, and it is all measured in
`tests/unit/graphics-resource-hierarchy.lisp`:

* `graphics-resource-name` on an unapplied state object answers `NIL` and can be
  set; the predefined instances answer the names XNA's own constructors give
  them, such as `"BlendState.Opaque"`;
* `graphics-resource-graphics-device` answers `NIL` before the object has been
  applied and the device afterwards, which is XNA's null and XNA's `Apply`;
* `dispose` marks it disposed and raises `Disposing` once, with the resource as
  the sender, and is idempotent;
* a managed-only subscription registers **no** callback token, because there is
  no C callback to resolve one and a token left behind would be a leak.

One thing this does *not* do: disposing a state object does not make it
unusable. XNA's setters are guarded by `ThrowIfBound` and by nothing else, so a
disposed but unapplied state object can still be mutated there, and it can here.
That is XNA's behaviour reproduced, not an oversight.

## Primitive drawing needs a current effect, and now has one

`DrawPrimitives`, `DrawIndexedPrimitives`, `DrawUserPrimitives` and
`DrawUserIndexedPrimitives` validate their arguments here before anything reaches
CNA — a non-positive `primitiveCount`, a non-positive `numVertices`, a short
vertex or index array, a vertex offset outside its buffer, and a non-instanced
draw while a stream carries a non-zero instance frequency are each refused with
the condition and the parameter name XNA uses.

Past those checks CNA refuses the draw itself unless an effect pass has been
applied:

    GraphicsDevice::DrawUserPrimitives: no effect has been applied

That is **XNA's own rule**, not a CNA limitation: `GraphicsDevice.VerifyCanDraw`
requires a current `Effect`. Since the Effect closure landed, applying a pass is
what changes the answer, and the rasterizer lane's third proof shows a triangle
drawn that way reaching real pixels.

Two halves of that are pinned rather than described.
`tests/native/buffers.lisp` requires all four draw entry points to refuse while
no effect is current, and to name the effect when they do; `tests/native/effects.lisp`
requires the same draw to be accepted once a pass has been applied.

What is still not proved about primitives: only the user-primitive path with a
`VertexPositionColor` triangle list has been read back. Indexed draws,
buffer-backed draws, non-identity transforms, textures, lighting and fog are
submitted and accepted, and no pixel of any of them is asserted.

## BasicEffect's matrix setters need the optional shim

`World`, `View` and `Projection` are the only members of the effect surface that
go through the private shim, and they join `GraphicsDevice.Viewport`'s setter as
the whole of that list. `CNA_Matrix` is 64 bytes, the System V AMD64 ABI
classifies it MEMORY, it travels on the stack, and no sequence of scalar
arguments occupies the same place — so CFFI cannot express the call without
`cffi-libffi`, which a released CNA-Lisp must not require. Without
`CNA_LISP_SHIM` those three setters refuse with an actionable
`CNA-NOT-SUPPORTED-ERROR`; the three *getters* take `CNA_Matrix*` and work
regardless.

Nothing else on the effect surface needs it. Every colour in it — fog, ambient
light, a directional light's diffuse and specular, `BasicEffect`'s diffuse,
emissive and specular — is a `CNA_Vector3` by value, which is 12 bytes and travels
in two SSE registers; the generator flattens those and
`tests/native/struct-passing.lisp` proves the flattening byte for byte.
`SpriteBatch.Begin`'s transform matrix needs no shim either, because CNA's route
for it takes `const CNA_Matrix*`.

## No effect here has ever had a *reflected* parameter graph

`Effect.Parameters` is real and is CNA's own collection. What it contains for a
stock effect is a property of the CNA **build**, not a constant: the prebuilt
0.21.0 library used locally answers an empty collection for a `BasicEffect`, and
a CNA built from source at the pinned commit does not. That was found by CI,
which failed a test asserting the count was zero, and the test now asserts what
is true of both — the collection is real, its count agrees with its elements,
and every parameter in it is findable by the name it reports — and prints the
count rather than requiring one.

What is constant is the *reflected* graph: CNA builds one only from compiled
Direct3D 9 Effect Framework bytecode, and loading that needs
`CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS`, which is a renderer property that
neither `HEADLESS` nor `SOFTWARE` has. They refuse the bytecode rather than
quietly drawing with a stock shader.

So `Effect(GraphicsDevice, byte[])` is implemented and reports CNA's refusal
rather than working around it, and `tests/native/effects.lisp` requires the
refusal. **No effect with a shader-reflected parameter graph has ever been
loaded in this repository.**

`EffectParameter`'s fifty-one members are therefore implemented against a surface
no reachable effect is guaranteed to expose. Rather than leave them written and
never once run,
the test suite builds a parameter collection through CNA's own construction
routes and round-trips every one of the nine value types, both scalar and array,
plus the string and texture pairs. **That proves the marshalling and nothing
more**: the layout each value is written and read with is exact, because CNA
stored it and gave it back. It says nothing about how a real shader's parameter
behaves, which nothing available here could say.

Two of `EffectParameter`'s getters are missing on purpose:
`GetValueTexture3D` and `GetValueTextureCube` return `Texture3D` and
`TextureCube`, which this binding does not project. CNA has the routes; the
public types do not exist, and inventing them would be worse than the absence.

## An effect's techniques, passes and parameters are not disposable

XNA gives `EffectTechnique`, `EffectPass`, `EffectParameter` and
`EffectAnnotation` `System.Object` for a base type: none of them is
`IDisposable`. On the CNA side every one of them is an *owned view handle* the
ABI expects back, and CNA refuses to destroy a game while any child handle is
alive.

The projection resolves that by having the `Effect` destroy all of them itself,
leaves first, when it is disposed. They are not registered as its disposable
children — that would make `DISPOSE` on the effect refuse until a consumer
disposed objects XNA gives them no way to dispose — but the effect *does* own them
for staleness, so using a technique after its effect is gone refuses rather than
reaching a handle CNA may have reissued. `DISPOSE` on one of them refuses by
name and says to dispose the effect.

One consequence a consumer can see: `Effect.CurrentTechnique` and every
collection element are the same Lisp objects for the life of the effect, because
the graph is built once. That is what XNA guarantees too — its `CurrentTechnique`
setter compares by reference — and it is not what CNA does on its own: CNA hands
back a fresh handle for each call, and `cna_effect_technique_get_identity` is
what maps one to the object that already stands for it.

## CNA never reports buffer content loss

`DynamicVertexBuffer.IsContentLost` and `DynamicIndexBuffer.IsContentLost` read
CNA's own `is_content_lost` field rather than returning a literal. CNA's headers
document that field as **"currently always false"**, for both buffer kinds, so
the answer is always `NIL` today.

The `ContentLost` event is wired to CNA's real subscription routes -- a handler is
registered, held and released like any other -- and CNA never raises it, because
nothing in it reports loss. That is a runtime capability CNA does not have yet.

Neither is faked. `tests/native/buffers.lisp` asserts today's answer and says, in
the failure message, that a CNA which starts reporting loss should retire the
limitation rather than the test.

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
