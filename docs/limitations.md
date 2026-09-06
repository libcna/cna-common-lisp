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
<!-- generated:rasterizer proof count=9 --> kinds of proof and fails when any is
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

`Texture2D`'s four stream members are no longer absent: the `System.IO.Stream`
projection landed, and a Common Lisp binary stream from `OPEN` is what they take.
`SaveAsPng` and `SaveAsJpeg` are **complete**; both `FromStream` overloads are
**partial**, for the two reasons the section on `System.IO.Stream` sets out below
rather than for want of a stream. `TEXTURE-2D-FROM-PNG-BYTES` and
`TEXTURE-2D-FROM-PNG-FILE` remain declared extensions, now as conveniences beside
the contract members rather than as substitutes for them.

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

**`Load<T>` reaches four types, not three.** The entry that used to stand here
named `cna_content_manager_load_texture2d`, `_load_texture_cube` and
`_load_sprite_font` and called them "the ones CNA has a route for". There is a
fourth, and it is in `effects.h` rather than `content.h`, which is how the search
missed it: `cna_content_manager_load_effect`, which CNA's own header calls "the
canonical `Load<Effect>` specialization, which is the route an XNA game's
`ContentManager.Load<Effect>` takes".

It is projected now. It reads three shapes — a compiled `.xnb` Effect asset, a
`.cnj` descriptor naming a stock effect, and a `.cnj` descriptor carrying shader
source — and **only the compiled shape needs
`CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS`**, which neither qualification renderer
has. So the descriptor shapes load on `HEADLESS` and `SOFTWARE` and are tested
there, which is the first content route in this binding that reaches `Effect` at
all.

A loaded effect is **not** flattened to the base class. `cna_effect_copy_type_name`
answers the handle's runtime type name in full, so a descriptor naming
`BasicEffect` comes back as a `BASIC-EFFECT` — which is what XNA's content reader
produces, and what `Load<Effect>`'s caller expects to be able to downcast to. Five
names map: `BasicEffect`, `AlphaTestEffect`, `SkinnedEffect`,
`EnvironmentMapEffect` and `DualTextureEffect`. Measured against 0.21.0,
`SpriteEffect` is refused by the loader and is not in the selection either. A name
outside that table answers an `EFFECT`, which is always correct if less specific.

The handle's destruction is recorded by the **constructor**, not by the loader,
which is the single-ledger rule applied to a constructor that takes an existing
handle: a construction that fails has already run its own ledger by the time the
loader's rollback runs, so recording it in both would destroy it twice. A
construction that succeeds drops its ledger, and from there the loader's undo is
the effect's own disposal. `Effect.Clone` takes the same path for the same reason.

**One of the route's three shapes is covered, and which one is worth stating.**
The stock-effect descriptor is tested on both qualification renderers. The
compiled `.xnb` shape needs `CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS`, which
neither renderer has, so it is refused here exactly as `Effect(GraphicsDevice,
byte[])` is. The shader-source descriptor needs
`CNA_GRAPHICS_CAPABILITY_CUSTOM_EFFECTS` — a *different* capability, and CNA's
header says the software renderer has it — so that shape should load under
`SOFTWARE`; what is missing is its schema. The `.cnj` shape for a source-carrying
effect is not documented in 0.21.0's headers, and five plausible spellings were
tried against the software renderer and all refused with `CNA_RESULT_IO`. Rather
than keep guessing, it is written down: **the shader-source shape is unexercised,
for want of its descriptor schema and not for want of a capability.**

`Load<T>` stays **partial** because it is generic over any type with a content
reader and this is four. CNA's `_load_sound_effect` and `_load_model` are for
types not in the selection; `_load_foreign_ext` and `_load_object_dictionary_ext`
are extensions rather than `Load<T>`.
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

`Game.Services` is in the selection and is **missing**, categorised
`PUBLIC_OBJECT_MODEL_CLOSURE`. `GameServiceContainer` itself is not in the
selection at all, and is not scheduled: the device-settings closure it was once
said to arrive with has landed without it.

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
pinned contract and reading its three members out of the IL. That is a closure of
its own and it is not scheduled — the device-settings closure this was once
assigned to has landed, and did not take it. A Lisp dictionary *on its own* — one
that answered a program's own services and invented the two canonical ones —
remains refused, because inventing them is the part that would be wrong.


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

**`GraphicsDevice`'s render-target surface is complete.** For one milestone
`SetRenderTarget(RenderTargetCube, CubeMapFace)`,
`SetRenderTargets(RenderTargetBinding[])` and `GetRenderTargets()` were absent
together, because all three need `RenderTargetCube` and `CubeMapFace` and
`RenderTargetCube` derives from `TextureCube`, which needed the texture data
surface. That closure landed and so did these. What is worth keeping from it is
the mechanism: they carried **explicit** absences in the mapping rules rather
than being left to the default naming rule, which would have resolved the cube
overload onto `SET-RENDER-TARGET`, the 2D one, and reported it complete when
nothing implemented it. An absence that the naming rule can satisfy by accident
has to be declared.

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

`RenderTargetCube` is complete and `RenderTargetBinding` is partial in one
member, and with them `GraphicsDevice`'s
`SetRenderTarget(RenderTargetCube, CubeMapFace)`, `SetRenderTargets` and
`GetRenderTargets` are all complete. The two subsections above are what remains
true of this family: which renderers will bind a cube target, and what
`GetRenderTargets` can answer.

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

**`Unload` is what disposes both**, in the right order, when the font came from
`ContentManager.Load<SpriteFont>` — see "The cache is XNA's, and now so is
`Unload`" above, which is the authority on that. A font a test built by hand is
still the caller's to dispose, font first. No public `Texture2D` atlas is exposed
for a SpriteFont, because XNA exposes none.

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
  extents and image operation 0: XNA caps an oversized image at what the profile
  can hold. CNA's null decode info "preserves source dimensions", which is this
  overload without that cap. An image within the limit decodes identically; a
  larger one decodes at its own size here and at the limit there.

  **The cap is not applied, and the reason is the fit rather than the number.**
  The number is available twice over: `ProfileCapabilities.MaxTextureSize` is
  `0x800` for `Reach` and `0x1000` for `HiDef`, hardcoded in the pinned assembly,
  and `GraphicsProfile` is projected. What is not available is what XNA's fit
  *does* — it happens inside `UnsafeNativeMethods::DecodeStreamToTexture`, a
  P/Invoke into unmanaged code the pinned assembly does not contain, with the
  extents passed by reference and rewritten on the way out. And CNA's fit is
  measured: a decode info with `zoom` false **scales in both directions**. A 16×8
  PNG fitted into 64×64 comes back 64×32; into 4×4 it comes back 4×2. Passing
  `MaxTextureSize` here would therefore return a 2048×2048 texture for an 8×8
  PNG, and no reading of this member says it should.

  The entry that used to stand here said "ABI 0.21.0 reports no maximum texture
  size for a fit to be computed from". That was wrong —
  `cna_graphics_device_get_renderer_limit_ext` answers
  `CNA_RENDERER_LIMIT_MAX_TEXTURE_DIMENSION` and `CNA_RendererInfo` carries
  `max_texture_dimension` — and it was also beside the point, because XNA uses
  the profile constant and not a device limit.
* The **five-argument** overload reaches CNA exactly — XNA computes
  `zoom ? 3 : 1` and `CNA_Texture2DDecodeInfo` carries a width, a height and a
  `zoom` flag meaning "cover-and-crop" against "fit while preserving aspect
  ratio". Measured against 0.21.0: a 16×8 PNG zoomed into 64×64 comes back 64×64,
  and fitted into 64×64 comes back 64×32 — so the fit enlarges as readily as it
  shrinks, which is worth knowing before asking for one. What is partial is what
  the result can say about itself: a *zooming* decode covers and crops, so `WIDTH`
  answers the requested extent, while a *fitting* decode answers something no
  larger and 0.21.0 reports no texture extent, so `WIDTH` refuses there.

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
is smaller than it sounds: XNA's property answers the device's own object, and
mutating that changes nothing there either until a `Reset`. `Reset` *is* projected
— all three overloads — so the way to apply changed settings is the same on both
sides: mutate a parameters object and hand it to `Reset`. What a program cannot do
here is mutate the object the getter answered and expect the device to have seen
it, because that object is a copy. `MAKE-INSTANCE` with no arguments
is XNA's parameterless constructor and its defaults come from
`cna_presentation_parameters_init` rather than being restated in Lisp, because a
list of numbers restated is a list of numbers that can drift. `Clone` goes through
`cna_presentation_parameters_clone` for the same reason: a field a later struct
version adds is copied by the routine that knows about it.

**`DeviceWindowHandle` is missing, and CNA refuses it by design.** The route is
`cna_graphics_device_get_native_window_handle` — there is no
`cna_graphics_device_get_device_window_handle`, and the reason that named one was
corrected in the audit table further down this file and left wrong here until the
second documentation audit. It answers `CNA_RESULT_NOT_SUPPORTED` after validating
the device — a native window handle is not something the stable C boundary hands
out — and an `IntPtr` is not a thing this projection has to hand one back in.

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
callback-scoped one — so `add-device-lost-handler` on a live device outside a
lifecycle method is a `CNA-SCOPE-ERROR`, exactly as every other device operation
is. Once the game is gone there is no handle to need and the managed path applies;
see "An event's `+=` outlives the object". Unsubscribing is
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

`GraphicsProfile`, `DisplayMode`, `GraphicsDeviceStatus`, `PresentationParameters`,
`Adapter`, the three `Reset` overloads, `Present()` and `DrawInstancedPrimitives`
are all complete. The device's five missing members are **two** things, and both
are closures rather than members. Its one partial member, `Viewport`'s setter, is
the by-value aggregate the optional shim exists for and is treated separately
above.

* **Two of the six device events**, and only the two that carry a payload.
  `ResourceCreated` and `ResourceDestroyed` have routes, and CNA's own header is
  the reason to be careful: "the canonical event is raised from the
  graphics-resource base constructor, so the reported object is still under
  construction: its concrete type does not exist yet and no member of it can" be
  used. Projecting that needs a decision about what object a handler is handed,
  and a half-built resource is not it.
* **`new(...)` and `Dispose()`** are the device as an object a program constructs,
  which a CNA-Lisp program never does. `IsDisposed` and `Disposing` are complete;
  these two are not, and **not because CNA lacks the routes** —
  `cna_graphics_device_create` and `cna_graphics_device_destroy` both exist, and
  the destroy explicitly accepts only a *caller-created* device and refuses a
  game's borrowed one, which is the same rule this binding enforces. What they
  need is a second kind of `GraphicsDevice`: an owned one with a handle of its
  own, alongside the parent-owned facade, and every device operation learning
  which of the two it has. That is a closure of its own rather than two members to
  add, and it is written down here so the next reader starts from the routes
  rather than from an assumption.

  **`Present(Nullable, Nullable, IntPtr)` sits with these two**, and is the third
  of the five: `cna_graphics_device_present` takes no arguments beyond the device,
  and an `IntPtr` override window is not a thing this projection can express. It is
  counted here rather than given a bullet because it needs the same two decisions.


#### Historical finding / retired limitation: three reasons that were wrong

Everything in this subsection describes absences that have since closed, and is
kept because *how* the reasons were wrong is the useful part. Nothing here is a
current limitation.

* **`Adapter` was listed here as blocked** and is complete, and so is `GraphicsAdapter` with
  `DisplayModeCollection`. The entry that used to stand here said the type "is not
  in the selection", which was true when written and had been false for a closure
  by the time the second documentation audit read it. "The adapter surface is
  complete, and needs a device to reach" above is the current statement, including
  the two static members that are partial and why.
* **`Reset` and `Present` were listed here as blocked** and are complete. The entry
  was wrong. It said the `Reset` family "needs a decision about
  what resetting means for a device CNA lends", which was speculation rather than
  a measurement: `cna_graphics_device_reset` and
  `cna_graphics_device_reset_with_parameters` were there all along. The three
  overloads are one generic function now, and the second route's adapter argument
  is a *pointer* whose null means "keep the current adapter" — which is exactly
  what XNA's one-argument overload means by not taking one.

  It is left recorded rather than quietly deleted, because it is the same mistake
  `Game.Services` made: a confident reason written without reading the routes.
* **`DrawInstancedPrimitives` was listed here as blocked** and is complete. The
  reason that used to stand for it was the third instance of that same mistake,
  and the most explicit one. It read: "ABI 0.21.0 has **no instanced draw route
  at all** — searched, not assumed". The search it claimed had happened had not.
  `cna_graphics_device_draw_instanced_primitives` is in the header with XNA's
  parameter list exactly, and it is the one draw that is *legal* while a vertex
  stream is bound with a non-zero instance frequency — the state every other draw
  in this binding refuses. So the member the instancing guard exists for was the
  member reported absent.

  Three wrong reasons, all the same shape: written from what seemed likely about
  CNA rather than from its headers. A declared reason is a claim about the ABI
  and has to be measured like one; "searched, not assumed" is worth less than
  nothing when the search did not happen, because it tells the next reader not to
  look again.

  So every remaining declared reason was then re-read against the 0.21.0 headers
  and the pinned IL, one at a time. **Six more were wrong**, and none of the six
  in a way that changed whether the member is reachable — which is the point:
  they were wrong about *why*, and a reason nobody can check is not a reason.

  | Member | What the reason claimed | What is true |
  | --- | --- | --- |
  | `Game.ShowMissingRequirementMessage` | needs "a platform message box" | CNA has one: `cna_message_box_show_ext`. The member is `.method family` — protected — and called from inside `Run`'s catch handlers, which are CNA's. That is the blocker, and it went unmentioned. |
  | `Effect.OnApply`, `BasicEffect.OnApply` | "returning true from it cancels the pass" | `OnApply()` returns **`void`** in the pinned assembly, and `Effect`'s body is a single `ret`. It cancels nothing. That was a claim about XNA taken from somewhere that is not XNA. |
  | `GraphicsDevice.ResourceCreated` | needs "a decision about what object a handler is handed" | There is nothing to hand: `CNA_ResourceCreatedEventInfo` carries one boolean, and "no native object pointer crosses the ABI". `ResourceCreatedEventArgs` is not in the selection either. |
  | `GraphicsDevice.ResourceDestroyed` | the same payload question | Its payload is a name and a `has_tag` boolean, and `ResourceDestroyedEventArgs` is not in the selection. |
  | `PresentationParameters.DeviceWindowHandle` | `cna_graphics_device_get_device_window_handle` refuses | No route has that name. `cna_graphics_device_get_native_window_handle` does, and does refuse, for a reason the header states. |
  | `DirectionalLight.new(…)` | "CNA has no route that would make that mean anything" | `cna_directional_light_create` exists. It takes no arguments and makes an unattached default light, so it is not this constructor — but "no route" was the wrong thing to say, and is the wording that hid three earlier mistakes. |

  `GraphicsDevice.Present(Nullable, Nullable, IntPtr)` was understated rather than
  wrong: the missing types are real, and `cna_graphics_device_present` also takes
  no arguments beyond the device.

  The reasons that survived the re-read unchanged are worth naming too, because
  they are now checked rather than merely written: `Game.Services` and
  `ContentManager`'s three (no CNA route registers a service or hands one back —
  "a service provider is a Sharp Runtime object and never crosses the C
  boundary"), `GameComponentCollection.new` (every `cna_game_components_*` route
  takes the game), `FindBestDevice`/`RankDevices`/`CanResetDevice` and
  `PreparingDeviceSettings` (`GraphicsDeviceInformation` is not in the selection),
  `GraphicsAdapter.MonitorHandle`, `GameWindow.Handle`,
  `EffectParameter.GetValueTexture3D` (`Texture3D` is not in the selection),
  `GraphicsDevice.new`/`Dispose`, and the eleven protected raisers.
`GraphicsDeviceManager`'s remaining nine are the five protected `On*` raisers, the
`PreparingDeviceSettings` event, and `FindBestDevice`/`RankDevices`/
`CanResetDevice`, which are the device-selection algorithm rather than a setting.
The count used to read "ten" because it counted `PreparingDeviceSettingsEventArgs`
— a type, and not one of this type's members. The generated frontier table in
`docs/compatibility.md` is what to count from.

## The Model family, and the two CNA defects that bound it

Twelve types, forty-eight members, and the dependency closure adds nothing: every
XNA type the family reaches was already selected. Forty-five of the members are
complete. What the other three are, and why, is two measured defects in CNA
rather than anything about the projection — and the second one is the larger.

### `Load<Model>` is refused on CNA 0.21.0, because the model could never be released

**`cna_model_destroy` applied to a model that came from
`cna_content_manager_load_model` is a null dereference on 0.21.0** — a memory
fault at offset 0x490, not a result code. Taking a mesh or a part view first only
defers the fault to `cna_game_destroy`. It is **fixed in 0.22.0 and still fixed in
0.23.0**: the same fixture, through the same binding, disposes cleanly on both.

**Re-measured for 0.23.0 with `tools/qualification/model-defect-matrix.sh`**,
which runs each step in its own process and reads the child's exit status, so a
fault is evidence rather than a lost test run. On 0.21.0 the fault arrives at
0x490 in `cna_model_destroy` itself — and the probe's `baseline` stage, which
loads a model and never touches it again, dies at the same address *after*
`cna_game_destroy` has already returned 0. So on 0.21.0 it is not the destroy
call that is unsafe so much as the load: a process that has loaded a model cannot
exit cleanly whatever it does next. On 0.22.0 and 0.23.0 every one of `baseline`,
`destroy` and the teardown that follows exits 0.

There is no sound fallback. Leaking the handle is not one: CNA refuses to destroy
a game that still owns a model, so a program would get a game that cannot shut
down instead of a crash — a worse failure, and further from its cause. So the
loader **refuses on 0.21.0, before anything is created**, with a condition naming
the defect and the version that does not have it.

**A binding may hand a program a refusal. It may not hand it a call that kills
the process.** That is the whole reasoning, and it is why this is not a
"limitation" in the usual sense: nothing here is unimplemented.

XNA has no public `Model` constructor either, so the consequence is exact: **on
CNA 0.21.0 the Model family has no public producer at all.** The suite asserts
the refusal on that ABI rather than skipping it, the way the rasterization tests
assert the no-readback branch — a lane that quietly skipped would stop proving
anything on the ABI it skipped.

### A loaded model's own effect cannot answer for its graph, on any admitted ABI

`cna_content_manager_load_model` publishes one handle per distinct effect its
model owns, and `PublishModelResource` fills in the value and the parent game and
nothing else: the `adapterState` every technique, parameter and texture route
reads is left null. `GetEffectState` is a cast of that null pointer, so
`cna_effect_get_techniques` on such a handle is a **memory fault at offset
0x20**, on 0.21.0, 0.22.0 and 0.23.0 alike, and an exception barrier cannot
contain it. **0.23.0 does not fix this one.** It was measured, not assumed: the
same subprocess matrix that shows `cna_model_destroy` working on 0.23.0 shows
`cna_effect_get_techniques` taking SIGSEGV at 0x20 there, `..._get_parameters` at
0x10, `..._get_current_technique` at 0x20 and `cna_effect_clone` at 0x8.

**22 of `effects.h`'s 322 routes read that field**, and which 22 is now
enumerated out of CNA's own source rather than listed by hand — every route in
`CnaCApiEffects.cpp` whose body reaches `GetEffectState`. **This binding binds 17
of them and refuses all 17** on a content-published handle; the remaining five
are shader-effect and PBR routes it does not project at all, so no public member
can reach them.

That audit corrected an earlier undercount. The refusal used to cover four
members — `Techniques`, `Parameters`, `CurrentTechnique` and `Clone` — and the
other thirteen were reachable: the stock effects' `Texture` pairs,
`DualTextureEffect`'s two layers, `EnvironmentMapEffect.EnvironmentMap`, and the
three directional-light readers. `BasicEffect.Texture` is the sharpest case,
because a `.cnj` model publishes a `BasicEffect` and reading its `Texture` is an
ordinary thing to do: it was measured killing a subprocess at address 0x0 on
0.22.0 and on 0.23.0, and removing the guard and running the suite gives
`Memory fault at (nil)` inside SBCL.

The other 300 routes answer normally on the same handle —
`cna_effect_matrices_get_world` was measured working on one — which is why the
effect object this binding hands back is real, is the concrete class CNA's own
type name reports, and refuses only the members that would read the missing
state. A condition stands where a crash was.

**The remedy is an ordinary XNA idiom and it works completely**: assigning your
own effect to the part replaces the handle with one that has adapter state.

```lisp
(setf (model-mesh-part-effect part) my-basic-effect)
```

Measured end to end: the part reports the new handle, its technique graph reads,
and the mesh's `Effects` collection is maintained across the swap. The pixel proof
does exactly this before it draws, which is what makes it a proof about geometry
rather than about a CNA bug.

So `ModelMeshPart.Effect`, `Model.Draw` and `ModelMesh.Draw` are partial under
`CNA_ADMITTED_ABI_LIMIT`: a model still carrying the effects its loader gave it
cannot be drawn.

### Both draws are transcribed rather than delegated

CNA has `cna_model_draw` and `cna_model_mesh_draw` and neither is bound. Three
reasons, in order of weight:

1. **`Model.Draw` is observable through its effects.** Its whole body assigns
   `World`, `View` and `Projection` on every effect of every mesh, and a program
   can read them back. A native route that drew the same pixels while leaving
   different values there would be a different member.
2. **Two refusals are part of the contract**: a null effect and an effect that is
   not `IEffectMatrices` are each an `InvalidOperationException`, thrown before
   anything is drawn. Nothing says CNA's route produces them.
3. `cna_model_draw` takes three `CNA_Matrix` **by value** — three MEMORY-class
   aggregates — so binding it would need a fourth shimmed route for no gain.

What they are transcribed onto is this binding's own public surface:
`SET-VERTEX-BUFFER`, `(setf INDICES)` and `DRAW-INDEXED-PRIMITIVES` are exactly
the three calls `ModelMeshPart.Draw` makes, and `part.Draw()` is inside the pass
loop where XNA puts it. `ModelMesh.Draw` therefore needs no shim; `Model.Draw`
does, because assigning the three matrices does.

### Object identity, and why the graph is built eagerly

**CNA handle identity is not XNA object identity.** `CreateBoneHandle` makes a
new registry handle on every call, so `Bones[0]` twice answers two handles for
one bone where XNA answers one object. The whole graph is therefore read once, at
construction, into a fixed vector per collection, and everything that names a
bone — a parent, a child, a mesh's parent bone, the root — is resolved through
the model's index map. `(eq (model-bone-parent child) parent)` is what XNA
guarantees and what this preserves.

Effects and buffers are the exception, and resolve differently: `published` in
CNA's loader is keyed on the native object address, so one native effect really
is one handle. A handle a program already owns answers that program's own object;
one only the model owns gets a `:PARENT-OWNED` wrapper whose `DISPOSE` refuses
and says to dispose the parent — which is the truth twice over, because CNA
refuses the destroy as well.

### `Tag` is a Lisp slot, and that is the only projection that works

XNA's `Tag` is `System.Object` — arbitrary consumer data the framework never
reads. CNA's is a `uint64` token, which cannot hold a Lisp object and could only
hold a pointer to one, and putting a pointer to a moving object into C is the
thing this binding never does. So the tag is a managed slot, the three
`cna_model_*_tag` routes are not bound at all, and `(eq (tag model) whatever-you-put-there)`
holds — which a `uint64` could not deliver. `GraphicsResource.Tag` settled this
first; this is the same decision.

### `ModelBone.Transform`'s setter goes through the model

`cna_model_bone_set_transform` takes `CNA_Matrix` by value, which would need a
fifth shimmed route and a member that refuses without a C toolchain.
`cna_model_set_bone_transforms` takes a pointer, so the setter reads the model's
local transforms, replaces this bone's and writes them all back. Nothing can
change in between — every handle in a model is affine to one thread — so it is
the same value written the same way, and the member is complete rather than
packaging-dependent.

### What the `.cnj` model reader actually honours

Measured, after a first fixture assumed otherwise. A mesh entry honours `name`,
`vertices`, `indices`, `vertexStride`, `effect`, `vertexColorEnabled`,
`parentBone` and the material fields, and **derives** the vertex and primitive
counts from the file sizes — it reads no `vertexCount`, `primitiveCount`,
`startIndex` or `vertexOffset`. Bone entry 0 gets the identity transform whatever
the file says. `vertexColorEnabled` matters for anything that reads pixels: both
`BasicEffect` and `SkinnedEffect` default `VertexColorEnabled` to false, so
without it the colour bytes are uploaded and the shader ignores them.

### CNA's model extensions are not in the selection

`models.h` carries morph targets, the skinned-model EXT family, animation clips,
`SkinningData`, `AnimationPlayer`, the glTF import report, cameras, skins and
material variants. None of them is XNA and none is selected. They share a header
with these routes and nothing else; a CNA route is not an argument for a member,
which is the rule `cna_sprite_font_create` is already unbound under.

## An event's `+=` outlives the object, and its registration does not

**Every one of the twenty-one event accessors in the three pinned assemblies is a
delegate field mutation and nothing else.** `Game`'s four events,
`GraphicsDeviceManager`'s five, `GraphicsDevice`'s six, `GraphicsResource`'s,
`GameComponent`'s, `GameComponentCollection`'s two, `GameWindow`'s three and
`DynamicSoundEffectInstance.BufferNeeded` all compile to a `Delegate.Combine` or
`Delegate.Remove` against a backing field — most of them through an
`Interlocked.CompareExchange` loop, the manager's four `IGraphicsDeviceService`
ones through a plain `stfld` — with **no** `IsDisposed` test and no other call at
all. Nor does any disposal clear such a field:
`DynamicSoundEffectInstance.Dispose(bool)` removes the instance from the static
`allInstances` table its raiser looks itself up in and then calls the base
disposal, and `GraphicsResource.Dispose(bool)` raises `Disposing` from its
backing store and leaves it there.

So in the original, **subscribing to and unsubscribing from a disposed object are
both legal**, `-=` still finds a handler that `+=` added before the disposal, and
what disposal ended is the event being *raised* rather than the list being
mutated.

This binding used to refuse the add. It does not any more, and the way it stops
refusing matters as much as that it stopped:

**A subscription is two facts with two lifetimes.** The *logical handler list* is
what `+=` and `-=` mutate; it is managed, and it survives disposal. The *live CNA
registration* is what makes a handler reachable; it exists only while the object
can raise the event, and disposal gives every one of them back.
`%EVENT-SOURCE-DISPOSED-P` in `src/runtime/event-machinery.lisp` is the seam.
Adding to a disposed object therefore updates the list and **acquires nothing** —
no registration, no callback-registry token, nothing rooted. Faking a
registration against a dead handle so that the code path could stay uniform would
have been the wrong repair, and the tests assert the registry count across every
post-disposal add and remove so that it cannot creep back.

**Why this is one mechanism and not one per type.** The audit that found it read
all twenty-one accessors rather than the one that was reported, and found the
same shape in every one. A type-specific fix for `BufferNeeded` would have left
the other twenty diverging in exactly the same way.

**One refusal is unchanged and is a different question.** `GraphicsDevice`'s
subscribe route wants the callback-scoped handle, so `add-device-lost-handler` on
a *live* device outside a lifecycle method is still a `CNA-SCOPE-ERROR` — see
"The device raises four events". On a device whose game is gone there is no
handle to want, so the managed path applies there like everywhere else. The two
answers are answers to two questions, not an inconsistency.

### A failing unsubscribe means the registration is still live

Both routes have one shape. `cna_audio_unsubscribe_ext` and `cna_game_unsubscribe`
look the registration up in the runtime handle registry and only then release it,
and every failure either can answer comes from the lookup or from the release,
under the registry's own mutex, **before anything is released**: an unknown or
already-released handle is `CNA_RESULT_INVALID_HANDLE`, and a call from a thread
other than the one that created the registration is `CNA_RESULT_THREAD`. The
registration object — whose destructor is what removes the C++ event token — is
untouched in both cases.

So the Lisp side must not forget a registration it did not get back.
`%UNSUBSCRIBE-EVENT` now releases first and forgets afterwards; a refusal
propagates with the row and its token intact, and the same removal on the right
thread still works. The thread failure is **reachable from a program**, which is
why this is a fix rather than a note: removal is the one event operation that
needs no handle, so it never checked the thread, and the previous order dropped
the row before the route refused. A registration nothing can release is one
`cna_game_destroy` refuses to shut down over, so the symptom would have been a
game that would not close, nowhere near the removal that caused it.

**Teardown is the one place a failed release is forgotten**, in
`%RELEASE-EVENT-HANDLERS`, and it is sound only there: it runs on the object's own
thread, after the object's own destruction, over registrations nothing can reach
any more — so an invalid handle means already-done and a thread mismatch cannot
occur. Nothing on that path may signal, either, because a condition would leave
the rest of the object undestroyed.

## Disposal does not cascade by default, and one type overrides that

CNA requires children to be destroyed before their parent. XNA's `Game.Dispose`
does not destroy every `Texture2D` a program made -- the finalizer thread dealt
with those -- so a straight port that relies on finalization will find that
CNA-Lisp refuses to dispose the game while those resources are alive.

CNA-Lisp reports that as `cna-ownership-error` naming the live children, instead
of cascading. Cascading on its own initiative would mean the binding deciding when
a program's resources die, which is not the binding's decision, and there is no
evidence that a particular cascade order is the right one.

**That is a default and not an invariant, and the wording used to say otherwise.**
`SoundEffect.Dispose(bool)` in the pinned assembly takes a snapshot of its
`children` list and calls `Dispose()` on every live `SoundEffectInstance` in it,
then drains its instance pool the same way, and only then releases its own native
handle. Refusing there would refuse a call XNA accepts, so `SoundEffect`
specialises `DISPOSE-OWNED-CHILDREN` and does what the assembly does. Every other
type takes the default refusal.

The rule is therefore: **default ownership does not cascade; a public type may do
so only where pinned XNA semantics require it.** Reproducing XNA here also
satisfies CNA rather than fighting it -- each instance's voice is deallocated
before the effect's handle is released, which is the child-before-parent order CNA
documents.

`ContentManager.Unload` inherits the same behaviour because it calls the same
`DISPOSE`. That is deliberate: the two paths to releasing a loaded effect must not
grow two ownership semantics, and there is one implementation between them.

**What happens when a child refuses is this binding's decision, and it is stated
rather than inherited.** XNA's `Dispose(bool)` walks its snapshot and lets the
first exception out; a `DOLIST` here did the same and left every instance after
the failing one alive, while the code's own documentation claimed the opposite.
`SoundEffect`'s children are dependent native children rather than the
independent assets `ContentManager.Unload` walks, so the policy is:

1. every live instance is attempted, in the recorded child-before-parent order;
2. the **first** condition is kept and no later one replaces it;
3. the condition is re-signalled from `DISPOSE-OWNED-CHILDREN`, which runs before
   `DISPOSE`'s own `UNWIND-PROTECT`, so the effect is left **undisposed** and a
   retry releases it once the children are gone.

Step 3 is conservative on purpose. `cna_sound_effect_instance_destroy` documents
its return as success "or a documented handle/thread/native failure" and does not
say that a failed call released the instance anyway — a handle failure plainly did
not — so destroying the effect over a child CNA may still hold is the one outcome
the ownership graph exists to prevent. A failed child is still invalidated on the
Lisp side, because `DISPOSE` invalidates through an `UNWIND-PROTECT`, so nothing
is left pointing at a handle that may or may not exist.

## Audio: five places CNA and XNA disagree, and XNA wins in the four it can

Every divergence below is a place the projection had to choose. It chose XNA in
each of the first four, because that is what a consumer's program was written
against; each is pinned by a test that asserts **both** sides, so a CNA that
changed would fail a test rather than silently changing this binding's public
behaviour.

The fifth is different in kind and is at the end: it is a place where XNA's answer
is not establishable from the pinned assembly, so there is nothing to choose XNA
*for*, and the member is partial rather than complete.

### `Play` on a disposed effect throws; CNA answers false

`cna_sound_effect_play`'s header says "a disposed effect answers `CNA_FALSE`
rather than failing, which is the canonical behavior". It is not the canonical
behaviour: `SoundEffect.Play` in the pinned assembly opens with an `IsDisposed`
test and throws `ObjectDisposedException` before it reaches anything else. This
binding's disposal check runs first, so a disposed effect signals
`CNA-DISPOSED-ERROR` and CNA's `CNA_FALSE` branch is never reached from here.

**`Duration` is the exception, and also XNA's.** Its getter is a bare `ldfld` over
a field the constructor filled in — no disposal test, no native call — so a
disposed `SoundEffect` still answers its duration there, and does here. Adding a
guard would refuse a program XNA runs.

**Four members of `SoundEffectInstance` are the same exception, and used to be
handled the other way.** `Volume`, `Pitch`, `Pan` and `IsLooped` are each a
seven-byte `ldfld` of a managed field, with no `IsDisposed` test; `State` is the
only one of that type's six public getters that reads the voice, and it is
guarded. Reading all five through `cna_sound_effect_instance_get_info` made the
four refuse with `CNA-DISPOSED-ERROR` where XNA answers — including after a
`SoundEffect` cascade, which is the common way to reach the state. They are
managed slots now, written after the native setter succeeds exactly where XNA's
`stfld` is, and the divergence is gone rather than documented.

The same change fixes a second disagreement that had nothing to do with disposal.
`Apply3D` writes `is3d` and `listenerData` and no other field, so XNA's `Pan`
keeps answering the value the caller assigned; CNA's mixer recomputes a spatial
pan and reported *that* through `get_info`. The public property is XNA's
assignment again. `tests/native/audio.lisp` cross-checks the slots against
`get_info` on a live instance, so the two may only part where the IL says they do.

### `Volume` is unclamped in CNA, `Pitch` is clamped, and XNA refuses both

| Member | CNA | XNA, and so here |
| --- | --- | --- |
| `SoundEffectInstance.Volume` | any finite value, passed through | refuses outside [0, 1] |
| `SoundEffectInstance.Pitch` | **clamps** to [-1, 1] | refuses outside [-1, 1] |
| `SoundEffectInstance.Pan` | refuses outside [-1, 1] | the same |

Two of the three would silently accept a value XNA throws on — a pitch of 2.0 is
a silent 1.0 through CNA — so all three are checked here, before the route.

### NaN is refused by three static properties and stored by one

XNA's guards branch on *unordered* comparisons, and which branch a NaN takes is
therefore a per-property fact rather than a consequence. Read from the IL:

| Property | Range | NaN |
| --- | --- | --- |
| `SoundEffect.MasterVolume` | [0, 1] | **throws** (`blt.un`/`bgt.un`) |
| `SoundEffect.DopplerScale` | [0, ∞) | **throws** (`blt.un`) |
| `SoundEffect.SpeedOfSound` | (0, ∞) | **throws** (`ble.un`) |
| `SoundEffect.DistanceScale` | [0, ∞) | **stored** (`bge.un`, and the clamp after it is ordered) |
| `AudioEmitter.DopplerScale` | [0, ∞) | **stored** (`bge.un`) |

The last two rows are the ones worth re-reading: `DistanceScale` alone among the
four statics keeps a NaN, and `AudioEmitter.DopplerScale` — the per-emitter
property of the same name as the static one above it — has the opposite answer to
its namesake. `DistanceScale` also raises a value in [0, `float.Epsilon`] to
`float.Epsilon`, because a zero distance scale would divide by zero.

**A NaN reaching CNA is masked at the boundary, and has to be.** CNA does binary32
arithmetic with the value and raises the IEEE invalid operation in hardware; SBCL
leaves floating-point traps enabled, so that surfaces as
`FLOATING-POINT-INVALID-OPERATION` out of a foreign call — a condition this API may
not signal. The four static setters, `Play`'s settings triple and `Apply3D` run
their native calls under `WITH-BINARY32-SEMANTICS` for that reason, which is what
the CLR does and what XNA's storing a NaN presumes.

### Every XNA duration is a whole millisecond, and neither CNA route agrees

`AudioFormat.DurationFromSize` divides the byte count by the block align, computes
the milliseconds in binary32, and hands the result to `TimeSpan.FromMilliseconds`.
What that last step does is the whole of this section. It is `TimeSpan.Interval(v, 1)`
in the pinned mscorlib:

    millis = v + (v >= 0 ? 0.5 : -0.5)
    ticks  = (long)millis * 10000

The half is added to the **millisecond** count and the `conv.i8` truncates *that*,
before the multiplication by 10000. So every duration XNA reports is a whole
number of milliseconds, rounded half away from zero, and 200 bytes of mono PCM16
at 8000 Hz -- 100 frames, 12.5 ms -- is **130000** ticks.

**This document previously said 125000, and that was wrong.** It called 125000
"the exact 12.5 ms those 100 frames hold", which is true of the frames and is not
what `TimeSpan.FromMilliseconds` returns. Two divergences follow from the
correction, and both are measured against 0.21.0:

| | 100 mono frames @ 8000 Hz | 1000 stereo frames @ 22050 Hz |
| --- | ---: | ---: |
| XNA | **130000** | **450000** |
| `cna_sound_effect_get_sample_duration_ticks` | 120000 | — |
| `cna_sound_effect_get_duration_ticks` | 125000 | 453514 |

CNA's *static* route truncates to whole milliseconds where XNA rounds. CNA's
*per-effect* route does not quantise at all -- it answers the exact tick count --
so the note that used to say it "agrees with XNA to the tick" was agreeing with
the old, wrong arithmetic.

So the two static sample computations are done here rather than through CNA — the
same decision the math types make, for the same reason: "CNA has routes for all of
it, and using them would make the binding's arithmetic CNA's rather than XNA's."
The routes stay bound and `tests/native/audio.lisp` asserts all three answers, so
a corrected CNA fails a test rather than passing silently.

**`SoundEffect.Duration` is partial because of the second row.** Wherever this
binding knows the format it computes XNA's answer instead of reading the route --
both constructors, and `FromStream`, which parses the wave header on the way past
— and those are exact. A `SoundEffect` obtained through `ContentManager.Load` was
never handed to this binding as bytes, and **neither admitted ABI** has a route
reporting an effect's sample rate, channel count or data length -- `audio.h` is
byte for byte the same in 0.21.0, 0.22.0 and 0.23.0 -- so there is nothing to compute
from. Its duration is CNA's tick count and can differ from XNA's by up to half a
millisecond. Answering it is better than refusing a member XNA always answers;
calling it complete would be claiming an agreement that was measured to be false.

### The streaming constructor needs no audio device in CNA, and XNA's answer is unknown

`SoundEffect`'s constructors refuse on a machine with no playback device:
`cna_sound_effect_create_pcm16_range_ext` answers `CNA_RESULT_NOT_SUPPORTED`,
which this binding raises as `NoAudioHardwareException`, and the
`AUDIO_UNAVAILABLE` lane qualifies exactly that.

`DynamicSoundEffectInstance`'s constructor does not.
`cna_dynamic_sound_effect_instance_create` answers `CNA_RESULT_SUCCESS` with no
device — measured against 0.21.0, 0.22.0 and 0.23.0, with a driver name SDL cannot
resolve — and the handle it gives back accepts `SubmitBuffer`. The refusal
arrives at `Play`.

**XNA's own behaviour there is not establishable.** Its constructor calls
`AllocateVoice()`, which calls
`SoundEffectUnsafeNativeMethods.CreateDynamicSoundEffectInstance`, whose body is
native code inside the mixed-mode assembly rather than IL. What the disassembly
*does* establish is the shape of the failure if there is one:
`Helpers.GetExceptionFromResult` maps XACT result `0x8ac70017` to
`NoAudioHardwareException`, so a failure would surface as that exception and not
as something else.

So the constructor is **partial**. Adopting CNA's success is a binding-defined
outcome standing in for an unknown one, which is legitimate for a partial member
and would not be legitimate while the member was called complete — the same
standard `Apply3D(AudioListener[], AudioEmitter)` is held to for its empty array.
Inventing a capability probe and refusing would be worse: it would be reproducing
a behaviour nothing in the pinned assembly says XNA has.

`tests/native/audio.lisp` asserts the measured behaviour in **both** directions
in its `AUDIO_DYNAMIC_UNAVAILABLE` lane — the constructor succeeds, a buffer is
accepted, `Play` refuses with `NoAudioHardwareException`, and the argument checks
still run first so a machine with no sound card cannot turn a wrong sample rate
into a hardware report.

## Audio has no game argument, and that is a projection limit

XNA's audio API takes no `Game`: its constructors take none and its four static
properties take none. CNA's routes need one — for lifetime on the creation routes,
and "for thread affinity only" on the statics, which its own header says. The gap
is closed the way `Keyboard.GetState` closes it: **CNA permits one active game per
process**, so there is exactly one game a static audio operation could mean, and
CNA-Lisp resolves it rather than making a consumer pass it. No public audio member
takes a `:game`, because adding one would change XNA's API to accommodate CNA.

**With no live game the operation signals `CNA-INVALID-STATE-ERROR`** naming what
is missing. That is the whole cost, and it is a runtime limit rather than a
structural one: the surface is complete, and a program that has created a game
never meets it. The two pure static computations need no game at all and answer
before one exists.

### Three of the four static properties work with no audio device

Measured, and not what a reader would guess: `DistanceScale`, `DopplerScale` and
`SpeedOfSound` are 3D parameters CNA keeps in process state and answers without
opening anything, so they read and write on a machine with no sound card.
`MasterVolume` reaches the mixer and answers `CNA_RESULT_NOT_SUPPORTED`, which
this binding raises as `NO-AUDIO-HARDWARE-ERROR` — the same mapping XNA's own
`Helpers.ThrowExceptionFromErrorCode` applies to that code.

### A missing sound asset is reported as NOT_SUPPORTED, not IO

`cna_content_manager_load_sound_effect`'s header documents `CNA_RESULT_IO` for "a
missing or undecodable asset", and a missing *font* really does answer IO. A
missing sound answers `CNA_RESULT_NOT_SUPPORTED`, with a message naming the file
it could not open.

The consequence is that **this route's NOT_SUPPORTED cannot be mapped to
`NO-AUDIO-HARDWARE-ERROR`**: the same code means either "no audio device" or "no
such file", and the result code alone does not distinguish them. It stays the
generic native condition, and a test asserts that a missing file is *not* reported
as missing hardware.

### `FromStream` reads one wave shape, and CNA's decoder reads more

`cna_sound_effect_create_from_encoded_ext` says so in its own header: "whatever
the audio backend can decode is accepted, which is more than the raw PCM the other
creation routes take." `SoundEffect.FromStream` is not that member. XNA hands the
stream to a private `WavFile` whose parser accepts exactly this:

* a `RIFF` chunk whose declared size is the stream's length minus eight;
* the form `WAVE`;
* a `fmt ` chunk of at least sixteen bytes declaring format tag **1** — PCM —
  one or two channels, a rate in [8000, 48000], 8 or 16 bits per sample, and a
  block alignment equal to `channels * bits / 8`;
* a `data` chunk **after** it, of at least one sample frame.

Unknown chunks are skipped and an odd-length chunk's pad byte is consumed, so
`LIST`, `smpl` and `fact` cost nothing. Everything else is refused, and
`src/audio/wave.lisp` is that parser transcribed instruction by instruction.

**A 32-bit IEEE-float WAV is the case worth naming**, because it is well-formed,
SDL decodes it, and XNA does not read it: `ParseFormat` refuses every format tag
but 1. `tests/native/audio.lisp` asserts *both* halves — the binding refuses the
bytes and CNA decodes the same bytes in the same test — because only the pair is
evidence that the refusal is the projection narrowing rather than CNA agreeing.

**The two rejection exceptions are XNA's two, and which one a caller gets depends
on how far the parse got.** `ParseWavHeader` runs outside the chunk loop, so a
stream that is not RIFF, whose declared size disagrees with its length, or whose
form is not WAVE throws `InvalidOperationException` — `CNA-USAGE-ERROR` here.
Everything below the header is raised inside
`try { ReadChunk(); } catch (object) { break; }`, so it merely ends the loop and
the caller sees `ArgumentException(InvalidWaveStream)` — `CNA-ARGUMENT-ERROR` —
from the `format == null || buffer == null` test that follows. An empty stream is
`ArgumentNullException` from `WavFile`'s own length test, before the parser runs.

**And a malformed wave is no longer reported as missing hardware.**
`CNA_RESULT_NOT_SUPPORTED` means both "no audio device" and "these bytes cannot be
decoded", and mapping both onto `NO-AUDIO-HARDWARE-ERROR` told a program with a
broken asset that its machine had no sound card. Validating first removes the
ambiguity; what remains of it is settled by asking
`cna_audio_get_capabilities` whether a playback device exists, so a wave XNA
accepts that CNA cannot decode on a machine that *has* a device is reported as the
decoder divergence it is rather than as absent hardware.

### `Apply3D`'s array overload is partial, and CNA's header says why

`cna_sound_effect_instance_apply_3d_multi_ext`: "XACT computes per-listener output
matrices; this runtime's mixer has a single stereo gain pair and no equivalent. So
every listener is evaluated and the **nearest** one — the listener that hears the
emitter loudest — decides the applied attenuation, pan and Doppler."

That is a different function of the listener array from XNA's, not an
approximation of it within a tolerance, and no argument this binding can pass
makes the two agree. The member is `CNA_ADMITTED_ABI_LIMIT`, and the concrete
evidence is the same in every admitted version: `audio.h` is byte for byte
identical in 0.21.0, 0.22.0 and 0.23.0, so the multi-listener route approximates
the same way in each.

**The single-listener overload is unaffected**, and the IL is why:
`Apply3D(AudioListener, AudioEmitter)` is `Apply3D(new[] { listener }, emitter)` —
it builds a one-element array and calls the same private path. The nearest of one
listener is that listener, so there is nothing to approximate and the overload
stays complete.

**XNA's behaviour for an empty array cannot be established from the pinned
assembly.** `UnsafeApply3D` pins its listener block, passes a null pointer and a
count of zero when the array is empty, and hands both to XACT: the managed IL
neither throws nor decides, and the outcome is inside a native boundary the
assembly does not contain. CNA refuses a count of zero and this binding adopts
that refusal — a binding-defined outcome standing in for an unknown one, which is
legitimate for a partial member and was not while the member was called complete.

## What the audio tests prove, and what they do not

**No test in this repository claims a sound was heard, and none may.** The
evidence levels are kept apart the way the rasterization kinds are:

| Level | What it means |
| --- | --- |
| `structural` | the enumerations, the sample arithmetic, the condition hierarchy and the listener and emitter defaults, checked with no device and no game |
| `unavailable` | no playback device opened, and every route needing one refused with `NO-AUDIO-HARDWARE-ERROR` |
| `state-machine` | a device opened, and play/pause/resume/stop transitioned as CNA's header says |

`tools/qualification/audio.sh` produces the second and third **in separate
processes**, because SDL's audio driver selection is process-global and latches at
initialisation: one image cannot answer for two drivers. A driver that does not
exist reaches the unavailable branch deterministically and with no hardware; SDL's
`dummy` driver still opens a device, so the state machine is qualified with no
speaker attached.

**A dummy audio device is not audible hardware.** A state transition, a duration
and a native acceptance are what these prove. Where a human would perceive a sound
is not established here, and a future hardware qualification would be a different
claim with different evidence.

## Microphone: runtime-owned devices, and five more places XNA wins

The capture half of `Microsoft.Xna.Framework.Audio` is projected and complete:
`Microphone`, `MicrophoneState` and `NoMicrophoneConnectedException`, three types
and twenty-one members over eighteen `cna_microphone_*` routes that are identical
in all three admitted ABIs — `audio.h` is byte for byte the same file in 0.21.0,
0.22.0 and 0.23.0.

### A microphone is not an object this binding owns

Every other CNA-Lisp type with a handle is a `NATIVE-OBJECT`: created, a child of
something, destroyed. A microphone is none of those. `audio.h` says the canonical
list "hands out pointers the runtime owns" and that "the microphone itself is
owned by the runtime and outlives every registration a caller can hold", and
there is no create route, no destroy route and no handle at all.

XNA agrees, and the pinned IL is where that was read rather than assumed:
`Microphone`'s only constructor is `assembly`-private and the only thing that
calls it is `MicrophoneCollection.EnumerateMicrophones`. A program never makes
one; it asks `All` or `Default` for the ones that exist.

So `MICROPHONE` is a plain CLOS facade over an active game and a device index. It
has no handle slot, it is not registered as a child of the game, and **there is no
`DISPOSE`** — not because disposal was skipped, but because XNA has none either.
`START` and `STOP` change what the device is doing; neither ends the object.

### Object identity is guaranteed, and the guarantee is XNA's own

`MicrophoneCollection` holds a `List<Microphone>` its static constructor makes
once and never replaces. `EnumerateMicrophones` is, in full:

```
GetMicrophoneCount(out count)
if (count < allMicrophones.Count) throw new InvalidOperationException();
for (i = allMicrophones.Count; i < count; i++)
    if (CreateMicrophone(i, out handle) == 0)
        allMicrophones.Add(new Microphone(handle));
```

**Append-only.** An existing element is never replaced, never removed and never
re-targeted, and a count that has *shrunk* is an error rather than a reason to
rebuild. So `Microphone.All[i]` is reference-identical across every query for the
life of the process, and `MICROPHONE-ALL` reproduces that with one process-global
cache keyed by index. `EQ` holds, and a test asserts it rather than asserting that
two facades have equal slots.

**The key is the index and not the name.** Two capture devices may share a display
name — the qualification environment's two differ, but nothing guarantees that —
so a name is a label and not an identity.

**It is not a generation either, and that is deliberate.** A generation would
claim a hot-plug story neither runtime has: CNA exposes a count and an index and
nothing else, no device id and no device-changed event. What the cache does
instead is refuse the one case that would silently re-target — a count below the
number already handed out is `CNA-INVALID-STATE-ERROR`, which is XNA's
`InvalidOperationException` in the same position.

**The cache is process-global rather than per-game, and that was measured.**
Destroying a game and creating another leaves CNA's device list identical — same
count, same names, same default index, same sample rates — and leaves a microphone
that was capturing still capturing. The runtime owns the devices, exactly as the
header says. That is XNA's model too, where the collection belongs to a static
field and there is no game to scope it to.

### `All` is a list, and `Default` is one of its elements

`ReadOnlyCollection<Microphone>` projects onto a Common Lisp **list**, which is the
same language projection `GraphicsAdapter.Adapters` already declares: a list is
what Common Lisp reads a sequence you must not mutate as, and **no XNA type is
invented to model the BCL wrapper**. The list is fresh on every call so that
nothing a caller does to it can reach the identity cache; the elements are the
cached facades so that `EQ` holds across calls.

`MICROPHONE-DEFAULT` is `EQ` to one of them or it is `NIL`. XNA's
`SelectDefaultMicrophone` picks an element of the very list `All` answers — it asks
each for `IsDefault` and falls back to index zero — so no facade is ever
manufactured outside `All` to satisfy `Default`. If CNA ever reported a default
index its own count does not cover, that is a native inconsistency and is signalled
as one.

**`Default` is cached once and `All` is not**, and that asymmetry is the IL's:
`get_Default` returns its stored `defaultMic` without enumerating whenever it is
already set, while `get_All` calls `EnumerateMicrophones` on every read. So the
first `MICROPHONE-DEFAULT` needs an active game and later ones do not.

### A facade retained across game disposal

`NAME`, `SAMPLE-RATE`, `IS-HEADSET` and `BUFFER-DURATION` keep answering, because
in XNA all four are **fields** their getters read and there is nothing native to
reach. `STATE`, `START`, `STOP` and `GET-DATA` call the device, so they need an
active game and refuse with the established projection-limit condition without
one. After another game is created the same facade works again and is still the
same device — which is not a hope: it is the measured process-global device list.

### Microphone has no game argument either

`Microphone.All`, `Microphone.Default` and every instance member take no game in
XNA; every CNA microphone route takes one. This is the same gap `Keyboard.GetState`
and the whole `SoundEffect` surface already close, closed the same way: CNA permits
one active game per process, so there is exactly one game a microphone operation
could mean. **No public member here grew a `:game` parameter to satisfy CNA.**

### Five measured disagreements, and XNA wins all five

Each is pinned by a test that asserts **both** sides, so a CNA that changed would
fail a test rather than silently changing this binding's public behaviour.

#### `IsHeadset` is always true, and `SafeIsHeadset` is dead code

`Microphone`'s constructor stores a literal:

```
IL_004a:  ldarg.0
IL_004b:  ldc.i4.1
IL_004c:  stfld      bool Microsoft.Xna.Framework.Audio.Microphone::isHeadset
```

and `get_IsHeadset` is a bare `ldfld` of that field. It is the **only** `stfld` of
`isHeadset` in the assembly. There is a `SafeIsHeadset` method that asks the native
layer for the real answer, and it has **no call sites at all**: it is compiled in
and never called.

`cna_microphone_get_is_headset_at` reports the device's real answer, and on the
qualification's capture devices that answer is false. Reporting it would be more
informative and would be **a different API from the one this binding projects**: a
program ported from XNA that branches on `IsHeadset` took the true branch there
and must take it here. The native route is bound and the qualification records both
answers side by side.

#### `BufferDuration` validates and does not round; CNA's header says otherwise

XNA's setter tests `TotalMilliseconds` three ways — `< 100`, `> 1000`,
`% 10 != 0` — each raising `ArgumentOutOfRangeException("value")`, and then stores
**the value it was given**: `set_BufferDuration` ends with `stfld
captureBufferDuration` of its own argument. There is no rounding anywhere in it.

`cna_microphone_set_buffer_duration_ticks_at` documents its argument as one "the
canonical setter validates and rounds". Measured against all three admitted ABIs
it accepts 1005000 ticks — 100.5 ms — and afterwards reports 1005000. It neither
rounded nor refused. So the guard is reproduced here, before the route is called,
and CNA's rounding is implementation support rather than the compatibility
contract.

#### `GetSampleDuration` rounds where CNA truncates

`AudioFormat.DurationFromSize` divides in **binary32** and then calls
`TimeSpan.FromMilliseconds`, which rounds half away from zero to a whole
millisecond. At 44100 Hz, 46 bytes is 23 frames and 0.5215 ms, so XNA answers
10000 ticks; `cna_microphone_get_sample_duration_ticks_at` truncates and answers 0.
This is the same rounding divergence `SoundEffect.GetSampleDuration` already
records, in a second place.

#### `GetSampleSizeInBytes` computes in binary32, and CNA accepts a negative

`AudioFormat.SizeFromDuration` is
`(int)(TotalMilliseconds * (double)((float)sampleRate / 1000f))`, then
`(n + n % Channels) * BlockAlign`, all checked. **The division is binary32 and the
multiplication is binary64**: `(float)44100 / 1000f` is 44.09999847412109375, not
44.1, so one second of 44.1 kHz mono PCM16 is **88198** bytes and not 88200.
`cna_microphone_get_sample_size_in_bytes_at` answers 88200.

The same route also accepts a negative duration and answers a negative byte count,
where XNA's first guard is `TotalMilliseconds < 0 -> ArgumentOutOfRangeException`.
Both are why the arithmetic is computed here and the two `cna_microphone_get_sample_*`
routes are bound only so the qualification can pin the divergence.

### `GetData`'s fifth condition, which no other member has

The first four checks are the three shared validators `SoundEffect` and
`DynamicSoundEffectInstance` already use, in the same order and raising the same
three `FrameworkResources` strings. `Microphone.GetData` adds one more to the last
`||` chain:

```
format.DurationFromSize(count) == TimeSpan.Zero
```

— a count whose duration rounds to zero milliseconds is refused. At 44100 Hz that
is every count below 46 bytes. A projection that dropped it would accept a two-byte
read XNA refuses, so it is implemented and tested against a threshold recomputed
from the device's own rate.

**A short read is success, including a read of zero bytes.** `audio.h` says so in
as many words — "a short read is **not** a failure here: the canonical operation
fills what it can and reports how much, because capture is a stream rather than a
value" — and XNA returns the count the native layer wrote. So `GET-DATA` answers a
byte count, exactly `[offset, offset + answer)` of the buffer is written, and
**every other byte is left as it was**. Nothing is filled in and a short read is
never turned into a buffer-too-small condition.

**A microphone that is not started answers 0 and reads nothing.** XNA's last act
before the native call is `if (State != Started) return 0`, so that is a normal
answer rather than a refusal.

### `Microphone.Stop` shares a generic function and refuses its optional

`SoundEffectInstance.Stop` has two overloads that collapse onto one generic
function with an optional flag. `Microphone.Stop` has **one** overload and takes no
argument. CLOS congruence forces the optional onto the microphone's method, so
supplying it is **refused rather than ignored** — a method that accepted and
dropped it would give `Microphone` a `Stop(bool)` XNA has not got. That is the rule
`%CHECK-OVERLOAD-KEYWORDS` enforces for keyword sets, applied in the one place an
*optional* reaches a member that has none.

### `BufferReady`'s sender is the object `All` hands out

`MicrophoneCollection.OnBufferReady(handle)` walks its own list for the element
whose handle matches and raises the event on **that element**. So the sender is the
object `All` and `Default` hand out, and a projection that built a fresh facade
from the device index inside the callback would deliver an object with equal slots
and the wrong identity. The qualification asserts it with `EQ`.

The registration is an owned `CNA_AudioEventRegistrationHandle` released by
`cna_audio_unsubscribe_ext`, exactly as `DynamicSoundEffectInstance`'s is, and it
goes through the shared event machinery: the logical handler list and the live
native registration are two facts with different lifetimes, a failing unsubscribe
keeps the row it did not release, and a condition signalled in a handler is
contained and re-signalled at the established outer boundary.

**There is no disposal seam here**, and that is the difference from every other
event in this binding. `%EVENT-SOURCE-DISPOSED-P` exists because a
`GraphicsResource` or a `DynamicSoundEffectInstance` can be destroyed while its
handler list survives. A microphone cannot, so the default `NIL` is correct and a
subscription is always a real native registration.

**Neither framework publishes the threshold at which the event is due, and this
binding claims none.** Measured, CNA raises it once per buffer check after the
unread backlog reaches `BufferDuration`, and keeps raising it until `GET-DATA`
drains the backlog — so a program that polls every frame never sees it, which is
what `examples/microphone-consumer.lisp` demonstrates by reporting zero. No test
asserts a rate.

## What the microphone tests prove, and what they do not

**No test in this repository claims a sound was captured, and none may.** The
evidence levels are kept apart the way the audio and rasterization kinds are:

| Level | What it means |
| --- | --- |
| `unavailable` | no capture device was enumerated; `All` answered the empty list and `Default` answered NIL, which `audio.h` calls an ordinary answer |
| `enumeration` | devices were enumerated, `All[i]` was the same object on every query, `Default` was `EQ` to one of them, and the stored properties answered |
| `capture-state-machine` | `Start`, `Stop` and `State` transitioned, and a repeated call of either was accepted without moving the state |
| `capture-data` | `GetData` wrote into exactly the range it reported, left every byte outside it unchanged, and advanced at the rate the device's own `SampleRate` implies |
| `buffer-ready` | the event arrived with the right sender, removing the handler released the registration and stopped delivery, and the callback registry came back |

`tools/qualification/microphone.sh` produces them **in separate processes**, for
the reason `audio.sh` does: SDL's audio driver selection is process-global and
latches at initialisation. It is a **separate script from `audio.sh`** because
playback and capture are different devices behind different CNA routes — a machine
may have a speaker and no microphone or the reverse — and a lane that read one out
of the other would let either be reported as the other.

It also runs `examples/microphone-consumer.lisp`, a complete capture session
through nothing but the two exported packages, under a mechanical audit: no
internal package, no CFFI, no handle, no result code, no private `%`-symbol. The
suite's own tests reach two private symbols — a device index, to cross-check CNA's
routes, and a cache reset, so one image can observe a first enumeration twice — and
both are legitimate for a test. The consumer is the independent evidence that
neither is *needed*.

**A dummy capture device is not a microphone.** SDL's dummy backend produces
silence — every byte zero — and no assertion anywhere inspects a captured byte. The
strongest claim this evidence supports is:

> the native capture device enumerated by the SDL dummy backend advances its PCM16
> capture stream at the reported sample rate, and CNA-Lisp reproduces the XNA
> state, buffer and event semantics over that stream.

It is **not** a claim that microphone audio is correct, that speech was captured,
or that a physical microphone works. A hardware qualification would be a different
claim with different evidence.

## Not implemented in this milestone

These are absent, and measured as absent, not faked:

* `GameServiceContainer` and `Game.Services` — see below;
* whole XNA namespaces outside the selected profile: **media, storage, gamer
  services and networking**. Audio was on this list and is not any more: the
  eight-type `SoundEffect` closure is selected and complete. What is still absent
  *within* audio is XACT — `AudioEngine`, `SoundBank`, `WaveBank`, `Cue`,
  `AudioCategory`, `RendererDetail` — and the reason given here used to be "CNA
  has no route at all", which is **measured false**: `xact.h` has 62 routes
  covering all five reachable types. The real reason is that it cannot be
  qualified — its three creation routes take `.xgs`, `.xwb` and `.xsb` files
  built by Microsoft's XACT authoring tool, so no fixture for them can be
  generated here, which is the standard every other fixture in this repository
  meets. Nothing else within audio is absent: `DynamicSoundEffectInstance` and
  the three `Microphone` types were on this list while each was a closure of its
  own, and both closures have landed — **which is exactly the staleness the
  paragraph below warns about, caught twice in one sentence**;
* the rest of the 3D resource surface — `Texture3D` and the `EffectParameter`
  member that needs one. `Model` was on this list too and its family is
  projected now; the generated per-type table is the authority.

**This list is the one place in this file that must name only what is absent
now**, and it had stopped doing that. It carried `ContentManager` and the XNB
pipeline, `GameWindow` as a type, `TextureCube`, `RenderTargetCube` and
`EnvironmentMapEffect` for as long as it took each of those closures to land,
and none of the five was removed when its closure did. Every one of them is
projected today: `ContentManager` and `GameWindow` are partial, `TextureCube` is
partial, and `RenderTargetCube`, `EnvironmentMapEffect` and `GameComponent` are
complete. The generated per-type table in `docs/compatibility.md` is the
authority, and a sentence here that disagrees with it is a defect in this file.

The absences that stayed on that list after being answered are the reason
`verify.py` now measures `*DECLARED-ABSENCES*` against the report and calls a
survivor `stale_declared_absence`. Prose cannot be checked that way; a list this
short can at least be kept next to the check that can.

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

One of `EffectParameter`'s getters is missing: `GetValueTexture3D` returns a
`Texture3D`, which this binding does not project. CNA has the route; the public
type does not exist, and inventing one would be worse than the absence.

**`GetValueTextureCube` used to be listed beside it, with the same reason, and
the reason was false: `TextureCube` *is* projected here.** The rest of that
reason was more honest — it said the remembering `GetValueTexture2D` depends on
had not been audited for cubes, and that a claim without the audit would be a
guess. The audit was done, against the header and against the running library,
and it found two things neither API documents:

* **CNA's texture identities are independent storage.** Setting the `TextureCube`
  identity leaves the `Texture2D` identity reading zero, and the reverse. So each
  getter reads its own and there is no ambiguity about which texture it means.
* **CNA's base identity is write-only.** The header says "no corresponding native
  getter exists", and a probe confirms both typed getters still read zero after a
  texture is written there.

The second fact decides the shape of the setter, and decided it before this was
measured — wrongly. XNA's single `SetValue(Texture)` makes **no distinction by
runtime type**: it calls one D3D `SetTexture` and the kind-specific getters
`QueryInterface` the result. The docstring here claimed the routing *was* that
distinction. It is not; it is a compensation for CNA modelling the same members
differently, and routing everything to the base identity — the closer
transcription of XNA — would silently lose every texture. A `TextureCube` was
being routed there, and was.

The audit found two more things worth having:

* **XNA's guards were missing entirely.** `SetValue(Texture)` and all three
  `GetValueTexture*` members guard on the parameter's *declared type* and throw
  `InvalidCastException` before touching anything — `Texture`/`Texture2D` for the
  2D getter, `Texture`/`TextureCube` for the cube one, the five texture types for
  the setter. CNA enforces none of them: a probe set a cube on a `:SCALAR`
  parameter and read it straight back. `CNA-INVALID-CAST-ERROR` is those guards,
  and it is a new condition because this is the first place the selected surface
  throws that exception.
* **Clearing has to clear every identity.** XNA has one texture value, so a null
  clears it. Writing the null to one CNA identity leaves the others holding stale
  handles, and the getter then finds a handle this binding no longer remembers
  and refuses. The test caught exactly that.

No stock effect CNA 0.21.0 builds exposes a texture-typed parameter — measured,
across all four — so the round trip is asserted over a parameter built through
CNA's own construction routes, like the rest of the value surface above. The
guards are asserted against a real stock-effect parameter, since any non-texture
one will do.

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
