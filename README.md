# CNA-Lisp — CNA for Common Lisp

**CNA-Lisp is a Common Lisp binding for CNA.** It projects a selected subset of
the Microsoft XNA Framework 4.0 Windows runtime contract onto an idiomatic
ANSI Common Lisp and CLOS API, implemented over the CNA C ABI.

The C ABI is an implementation detail. A program using CNA-Lisp works with CLOS
classes, generic functions, methods, conditions, Lisp strings, Lisp numbers and
Lisp value objects, and never sees a handle, a result code, a CFFI pointer or a C
name.

```
    Public Common Lisp / CLOS API
        -> private CNA-Lisp runtime and mapping layer
        -> private CFFI declarations
        -> CNA C ABI
        -> the canonical CNA C++ implementation
```

## Qualified configuration

This is what has actually been run, not what might work.

| | |
| --- | --- |
| Implementation | SBCL 2.5.2 (Linux x86-64) |
| Foreign layer | CFFI, Babel, bordeaux-threads — no `cffi-libffi` |
| Portable dependency | `trivial-gray-streams`, so that a CNA file stream is an ordinary CL stream |
| Build system | ASDF |
| CNA C ABI | **0.21.0** (encoded 5376), **0.22.0** (encoded 5632) and **0.23.0** (encoded 5888) — an explicit set, all three qualified |
| CNA build | `SDL3` platform, `SDL3` audio, **HEADLESS** renderer |
| Second lane | the same suite against a **SOFTWARE** renderer, which reads real pixels back out of the back buffer |

No claim is made for another Common Lisp implementation, for Windows or macOS,
for another ABI version, for a physical monitor, or for a GPU renderer. The host
is stronger than a missing claim: the foreign layer refuses to open anywhere but
SBCL on Linux x86-64, because its by-value flattening is a System V AMD64 rule
and another host ABI would be a different calling convention, not an untested
one. Everything that touches no native route runs anywhere.

HEADLESS qualifies command submission and the lifecycle. The SOFTWARE lane
qualifies the pixel paths it actually tests, and it needs no display to do it.
The proofs it requires are one registry —
`tools/qualification/rasterizer-proofs.json` — which the lane enforces in both
directions: a required proof the run did not produce fails it, and a proof the
run produced that the registry does not name fails it too. That registry is what
the following is rendered from, so this list cannot drift from the gate:

<!-- generated-block:rasterizer-proofs -->
| Proof | What it claims |
| --- | --- |
| `clear` | GraphicsDevice.Clear reached the back buffer and read back |
| `sprite` | a SpriteBatch draw put a known texture's own texels on exactly the pixels its destination rectangle names, and on none outside it |
| `primitive` | a DrawUserPrimitives triangle, through a BasicEffect pass, covered exactly the pixels its geometry covers and none outside them |
| `text` | SpriteFont's metrics and SpriteBatch.DrawString's layout put each glyph of a string at its own advanced position, from its own atlas cell -- proved with a two-colour atlas, so a pixel says which glyph reached it, and across a line break, so the line advance is LineSpacing and not the glyph height |
| `loaded-text` | a SpriteFont obtained through ContentManager.Load, from a .cnj descriptor on disk with no test-only producer in the path, drew the same string at the same coordinates as the hand-built font -- so a descriptor that drifted from the suite's glyph rows would put a glyph somewhere else and fail |
| `stock-effect` | a pass applied through an AlphaTestEffect and through a SkinnedEffect made a primitive draw legal and covered the right pixels -- that they are usable draw effects, and nothing about the alpha test or about skinning, neither of which this renderer applies to the geometry these tests can give it |
| `render-target` | a clear into a bound RenderTarget2D left the back buffer untouched, and the target's own contents then reached the back buffer through the texture path -- the first evidence here that does not depend on the back-buffer readback being the only way to see a pixel |
| `render-target-data` | every texel of a bound-and-cleared RenderTarget2D read back through Texture2D.GetData -- which reads a texture and not a back buffer, so it is the one pixel claim here that does not depend on GetBackBufferData at all |
| `model` | a Model loaded through ContentManager.Load<Model>, whose mesh geometry lives in a VertexBuffer and an IndexBuffer the model owns, reached the back buffer through ModelMesh.Draw -- each of its two meshes painting its own colour on the pixels its own triangle covers, and neither on the other's |
<!-- /generated-block:rasterizer-proofs -->

`docs/qualification.md` defines the claims and `docs/limitations.md` bounds
them.

## What is implemented

The first qualified foundation is a real end-to-end vertical slice, not a set of
stubs:

* `Game` as a public CLOS class you subclass, with the whole native loop as
  overridable generic functions — `initialize`, `load-content`, `begin-run`,
  `update`, `begin-draw`, `draw`, `end-draw`, `end-run`, `unload-content`,
  `on-exiting`;
* `GraphicsDeviceManager` over CNA's own manager;
* `GraphicsDevice` in **both** the lifetimes XNA permits, behind one public
  type: a game's device as a parent-owned facade that borrows a valid handle per
  operation, because that is the only thing CNA's callback-scoped device lending
  permits — and a device you construct yourself with XNA's own
  `GraphicsDevice(GraphicsAdapter, GraphicsProfile, PresentationParameters)`,
  which holds its own handle, needs no callback and no `Game` at all, owns the
  graphics resources made against it, and is yours to dispose. A program can
  clear, draw and read pixels back with no game in the image;
* `Viewport`, `Color` with all 141 predefined XNA colours and its packed,
  float and vector forms, `Point`, `Rectangle`,
  `Vector2`, `Vector3`, `Vector4` and the whole of `MathHelper` — computed in
  binary32, in XNA's own order of operations, each method written from the
  disassembled IL of the hash-pinned assembly rather than from a description of
  what it should do;
* the 3D transform types on the same footing: `Quaternion`, `Matrix` and
  `Plane`, including the projection, view, billboard and reflection builders;
* the `Curve` family — `Curve`, `CurveKey`, `CurveKeyCollection` and the three
  curve enumerations — with the five loop types, the three tangent kinds and the
  step continuity all behaving as the framework's own IL does;
* the seventeen `Graphics.PackedVector` formats, generated from one table of bit
  layouts, including XNA's 16-bit half — which is **not** IEEE 754 binary16 and
  says so in the code, the tests and the documentation;
* the whole bounding-volume family — `Ray`, `BoundingBox`, `BoundingSphere` and
  `BoundingFrustum`, with every intersection and containment between them,
  `ContainmentType` and `PlaneIntersectionType` — down to which comparison is
  strict, which epsilon the framework chose, and one arithmetic defect it
  shipped, each recorded where it is reproduced. The frustum's convex tests are
  XNA's own Gilbert-Johnson-Keerthi solver, transcribed rather than
  reimplemented, and cross-checked against a separating-axis test over 3956
  random box placements and 985 exact sphere placements;
* `GraphicsResource` as the real base class the contract gives `Texture` and
  `SpriteBatch` — its name, its `Disposing` event, its device back-reference and
  the disposal every native object in this binding already had;
* `Texture2D` decoded from a real PNG into a real native texture;
* `SpriteBatch` with a real textured draw, with rotation, scale, origin, tint,
  source rectangle, effects and layer depth;
* the input surface over CNA's own routes: `Keyboard`, `KeyboardState`,
  `KeyState` and all 160 `Keys` members; `Mouse`, `MouseState` and
  `ButtonState`; the whole `GamePad` family — state, capabilities, vibration,
  the dead-zone modes and the `Buttons` flags enum; and the `Input.Touch`
  namespace, in a package of its own;
* the four **graphics state objects** — `BlendState`, `DepthStencilState`,
  `RasterizerState`, `SamplerState` — with their nine enumerations, their sixteen
  predefined instances, XNA's own defaults read from the pinned Graphics assembly
  rather than guessed, and XNA's read-only latch: a state object that has been
  applied refuses every setter, and the predefined ones refuse from the start;
* `GraphicsDevice`'s state surface over them — `BlendState`,
  `DepthStencilState`, `RasterizerState`, `BlendFactor`, `MultiSampleMask`,
  `ReferenceStencil` and `ScissorRectangle` — and its four indexed collections,
  `SamplerStates`, `VertexSamplerStates`, `Textures` and `VertexTextures`, each
  answering the same collection object every time and remembering what was bound
  into it, as XNA's do;
* **vertex and index buffers**: `VertexBuffer`, `IndexBuffer` and both dynamic
  subclasses, with both index widths, `BufferUsage`, `SetDataOptions`,
  `VertexBufferBinding`, the device's stream and index state, and `SetData` /
  `GetData` over a layout system that writes only element types whose binary
  layout it can prove and refuses the rest by name;
* the **primitive draw calls** — `DrawPrimitives`, `DrawIndexedPrimitives`,
  `DrawUserPrimitives`, `DrawUserIndexedPrimitives` — with XNA's own argument
  validation reproduced from the IL, and, since the effect closure landed, a
  rasterised triangle to show for it;
* `Texture2D` **made blank and filled by the program**: both constructors and
  the three `SetData` and three `GetData` overloads, accepted only for element
  types whose binary layout the binding can prove;
* **content**: `ContentManager` and `Game.Content`, which is what makes a
  `SpriteFont` obtainable -- `(load-asset content 'gfx:sprite-font "font")` is
  XNA's `Load<SpriteFont>`, with the type as an argument because Common Lisp can
  name one where C cannot. The asset types CNA has a route for are
  <!-- generated-block:loadable-asset-type-names -->
`Texture2D`, `TextureCube`, `SpriteFont`, `Effect`, `SoundEffect` and `Model`
<!-- /generated-block:loadable-asset-type-names -->,
  which is `LOADABLE-ASSET-TYPES` rendered from the live loader table rather than
  a list kept beside it. `Model` is the one of the six that is **not offered on
  every admitted ABI**: on CNA 0.21.0 a loaded model can never be released, so
  `Load<Model>` refuses there and says why rather than handing a program a call
  that kills the process. See `docs/limitations.md`. The manager
  keeps XNA's two collections, so a name loaded twice answers the same object and
  `Unload` disposes what it loaded -- in the order they have to go, a `SpriteFont`
  before the atlas it draws from;
* the **`Microsoft.Xna.Framework.Audio` `SoundEffect` closure**: `SoundEffect`,
  `SoundEffectInstance`, `AudioListener`, `AudioEmitter`, `SoundState`,
  `AudioChannels` and the two exceptions XNA's audio surface raises, which are
  projected as Common Lisp conditions subclassing the CNA result-code condition
  each one comes from. **No public member takes a game**, as XNA's take none: CNA
  permits one active game per process and the binding resolves it, the way
  `Keyboard.GetState` already did. The constructors' validation is XNA's, in
  XNA's order, and where CNA disagrees -- an unclamped `Volume`, a clamped
  `Pitch`, a truncating `GetSampleDuration` -- XNA wins publicly and
  `docs/limitations.md` records the difference. Qualified in two lanes, both
  without a sound card: a driver that does not exist proves the
  no-audio-hardware path, and SDL's `dummy` driver opens a device with no speaker
  behind it so the play/pause/resume/stop state machine can be observed. **No
  test claims a sound was heard**;
* **`DynamicSoundEffectInstance`**, which is the streaming half of that namespace
  and the one member of it that adds a *capability* rather than a surface:
  procedurally generated audio is not reachable through anything else here. A
  program builds one from a sample rate and a channel count, hands it PCM16 with
  `submit-buffer`, watches `pending-buffer-count`, and is told when the queue runs
  low through `add-buffer-needed-handler`. It derives from `SoundEffectInstance`
  in XNA and here, and the two members XNA overrides -- `IsLooped`, which is
  always false and refuses a true assignment, and `Play` -- are projected as
  overrides rather than inherited by accident. The same `dummy` driver qualifies
  it: generated PCM is submitted, the pending count rises and the native streaming
  state machine consumes it while the game loop runs. **A consumed buffer is not
  a buffer anyone heard**, and no test says otherwise;
* the **`Model` family**: `Model`, `ModelBone`, `ModelMesh`, `ModelMeshPart`,
  their four collections and the four nested enumerators those collections
  answer. A program loads one with `(load-asset content 'gfx:model "robot")`,
  walks its bone hierarchy with **XNA's object identity** -- `Bones[0]` twice is
  one object and `child.Parent` is the parent object, which CNA's handles alone
  cannot give, because it makes a new handle on every read -- copies or replaces
  the bone transforms, and draws it. `Model.Draw` and `ModelMesh.Draw` are
  transcribed from the pinned IL rather than delegated to CNA's one-shot routes,
  because `Draw` is observable through the effects it configures and throws two
  distinct exceptions before drawing anything. The SOFTWARE lane proves a loaded
  model's own geometry reaches pixels. **Two measured CNA defects bound it**: a
  loaded model's effect cannot answer for its own technique graph on either
  admitted ABI, and on 0.21.0 a loaded model cannot be released at all, so
  `Load<Model>` refuses there. `docs/limitations.md` has both, with the exact
  reproduction and the remedy;
* **`System.IO.Stream` as an ordinary Common Lisp binary stream**, which is what
  a language with its own equivalent abstraction should do with a BCL type that is
  not even in the profile's contract. `Texture2D.FromStream`, `SaveAsPng` and
  `SaveAsJpeg` take one from `OPEN`, and `TitleContainer.OpenStream` answers one --
  with XNA's own path validation, transcribed from the assembly down to the seven
  characters its `badCharacters` array holds;
* the **component engine**: `GameComponent`, `DrawableGameComponent`,
  `Game.Components` and the collection's two events. A component's behaviour is
  its CLOS methods on the same generic functions a `Game` overrides, and CNA's own
  loop drives them -- honouring `UpdateOrder`, `DrawOrder`, `Enabled` and
  `Visible`, which the tests check by counting calls inside the loop rather than
  by asking whether the members exist;
* **render targets**, now including `RenderTargetCube` and
  `RenderTargetBinding`: `RenderTarget2D`, `RenderTargetUsage`, `DepthFormat` and
  `GraphicsDevice.SetRenderTarget`. A target is a `Texture2D`, as XNA's is, so it
  can be drawn back onto the screen -- which is how the qualification reads one
  without depending on back-buffer readback;
* **all four other stock effects** -- `AlphaTestEffect`, `DualTextureEffect`,
  `SkinnedEffect` and `EnvironmentMapEffect`, with `TextureCube` and
  `CubeMapFace`, complete, over the same effect machinery. Their state
  round-trips through the CNA routes; what the SOFTWARE renderer does and does
  not shade with them is measured in `docs/limitations.md` rather than assumed;
* **`Effect` and `BasicEffect`**: the whole effect object graph — techniques,
  passes, parameters, annotations and their four collections — plus the three
  `IEffect*` contracts as generic functions, `DirectionalLight`, and
  `SpriteBatch.Begin`'s two remaining overloads. `Effect(GraphicsDevice, byte[])`
  loads compiled bytecode where the renderer can, and reports CNA's refusal where
  it cannot rather than substituting a stock shader;
* the **vertex declaration** surface: `VertexElement`, `VertexDeclaration` with
  XNA's own five-stage validator in its own refusal order, `IVertexType` as a
  generic function, and the four standard vertex value types with the exact
  declarations their class constructors build — strides 16, 20, 24 and 32,
  cross-checked element for element against CNA's own;
* `SpriteBatch.Begin`'s five shapes, and only those five: the parameterless one,
  the sort-mode-and-blend-state one, the five-parameter one and the two that add
  an `Effect` and a transform, with a null state meaning the framework default
  exactly as XNA's `SetRenderState` does;
* **`SpriteFont` and all six `SpriteBatch.DrawString` overloads.**
  `MeasureString` and the per-glyph layout are transcribed from the pinned
  assembly and computed in Lisp over the glyph table CNA hands back — CNA has its
  own `measure` and `draw_string` routes and they are deliberately not used for
  the answer, because a runtime cannot be the oracle for its own compatibility
  and because both take UTF-8, which cannot hold the unpaired surrogate a
  `System.String` can. `System.Char` is projected as an integer in [0, 65535],
  which is what a UTF-16 code unit is;
* the three **`Microphone`** types -- `Microphone`, `MicrophoneState` and
  `NoMicrophoneConnectedException`. A microphone is **not an object this binding
  owns**: CNA addresses capture devices by index and creates no handle, so `All`
  is a process-global identity cache and the same index answers the same object
  forever, which is what XNA's own static list does. `GetData` writes into a
  caller's byte vector with XNA's five refusal conditions in XNA's order, and
  `BufferReady` announces it. Qualified without a microphone, in three
  environments rather than two: none enumerated, some enumerated and delivering,
  and -- the runner's own -- some enumerated and delivering nothing, each
  asserted rather than skipped. **No test claims a sound was captured**;
* the **media playback closure**: `MediaPlayer`, `Song`, `SongCollection`,
  `MediaQueue`, `MediaState` and `VisualizationData`. `MediaPlayer` is a static
  class with two **static** events, whose handlers therefore take no arguments at
  all because XNA raises them with a null sender; the queue is one object forever
  and `ActiveSong` a fresh one every time, which is XNA's own identity and not
  CNA's. Qualified under SDL's `dummy` driver in four separate claims -- the
  transport, the play clock, the queue and the events -- and **no test claims
  music was heard**;
* the whole of **`Microsoft.Xna.Framework.Storage`**, which is the first closure
  to finish its own namespace: `StorageDevice`, `StorageContainer` and
  `StorageDeviceNotConnectedException`, all three complete. It is also the first
  surface that **needs no `Game`** -- no storage route takes one, so the entry
  points open the ABI gate themselves -- and the first with a three-deep
  ownership graph, device to container to stream. A file inside a container opens
  as an **ordinary Common Lisp binary stream**, so `WITH-OPEN-STREAM`,
  `READ-SEQUENCE` and `FILE-POSITION` are how a save is written and read. Two
  routes have no XNA member behind them at all -- naming the storage root and
  reading it back -- because off the Xbox nothing derives a title's directory for
  it, and they flatten a three-way disagreement between the admitted ABIs about
  where an unusable name is refused. A separate process reads back what another
  one wrote; **no test claims durability**;
* the CLR **event projection**: `game.Activated += handler` becomes
  `(add-activated-handler game handler)`, over CNA's own subscription routes,
  with the registrations released deterministically with the object. `Game`'s
  four events and `GraphicsDeviceManager`'s five data-free ones are bound;
* a full condition hierarchy, deterministic disposal, generation-checked
  ownership, thread affinity, and callback condition containment.

Everything else in XNA is **absent and measured as absent**. There are no
placeholder methods that answer a default and claim success.

<!-- generated:selected types=206 -->
<!-- generated:selected members=2682 -->
<!-- generated:complete types=183 -->
<!-- generated:partial types=23 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=2152 -->
<!-- generated:partial members=30 -->
<!-- generated:missing members=26 -->
<!-- generated:not-applicable members=474 -->
<!-- generated:disagreement total=0 -->
<!-- generated:bound native functions=820 -->
<!-- generated:bound native structs=75 -->

<!-- generated-block:scoreboard-headline -->
The generated scoreboard, over a selection of **206 XNA types and 2682 members**:

| | |
| --- | --- |
| Types complete / partial / missing | **183 / 23 / 0** |
| Members complete / missing | **2152 / 26** |
| Members not applicable | **474** |
| **Disagreement diagnostics** | **0** |
<!-- /generated-block:scoreboard-headline -->

Zero disagreement means nothing implemented contradicts the contract, nothing
private leaked into a public package, every exported symbol is accounted for, no
mapping rule names a member that does not exist, and every overload family that
collapses onto one function says how each overload is expressed. It does **not**
mean the binding is finished. Members are still missing and are reported as
missing; **no selected type is missing entirely**. `docs/compatibility.md` is the
authority, and its per-type table says exactly where the absences are.

<!-- generated-block:native-abi-headline -->
The private foreign layer binds **820 native routes** and **75 native structs**,
all of them generated from the canonical CNA headers and checked by a C compiler.
<!-- /generated-block:native-abi-headline -->

## Installing

CNA-Lisp is an ordinary ASDF system. Quicklisp or Qlot may be used to obtain its
dependencies, but nothing Quicklisp-specific is part of the runtime.

```sh
git clone https://github.com/libcna/cna-common-lisp
```

Make the checkout visible to ASDF — for example:

```sh
export CL_SOURCE_REGISTRY="$(pwd)/cna-common-lisp//"
```

then

```lisp
(asdf:load-system "cna-common-lisp")
```

### The native library

CNA-Lisp loads exactly the CNA C ABI shared library that `CNA_NATIVE_LIBRARY`
names, and searches nowhere else. It does not look in sibling checkouts, build
directories or the loader path, and it does not bundle a CNA binary.

```sh
export CNA_NATIVE_LIBRARY=/absolute/path/to/libcna_c_api.so
```

The path must be absolute and must name an existing file. Every diagnostic names
the exact path attempted.

## Hello, CNA

```lisp
(defpackage #:hello-cna
  (:use #:cl)
  (:local-nicknames (#:xna   #:microsoft.xna.framework)
                    (#:gfx   #:microsoft.xna.framework.graphics)
                    (#:input #:microsoft.xna.framework.input)))

(in-package #:hello-cna)

(defclass hello-game (xna:game)
  ((manager      :initform nil :accessor manager)
   (sprite-batch :initform nil :accessor sprite-batch)
   (texture      :initform nil :accessor texture)))

(defmethod initialize-instance :after ((game hello-game) &key)
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game)))

(defmethod xna:load-content ((game hello-game))
  (let ((device (xna:graphics-device game)))
    (setf (texture game)      (gfx:texture-2d-from-png-file device "Content/logo.png")
          (sprite-batch game) (make-instance 'gfx:sprite-batch :graphics-device device))))

(defmethod xna:update ((game hello-game) game-time)
  (declare (ignore game-time))
  (when (input:is-key-down (input:keyboard-get-state) :escape)
    (xna:exit game)))

(defmethod xna:draw ((game hello-game) game-time)
  (declare (ignore game-time))
  (gfx:clear (xna:graphics-device game) (xna:cornflower-blue))
  (gfx:begin (sprite-batch game))
  (unwind-protect
       (gfx:draw-texture (sprite-batch game) (texture game)
                         :position (xna:make-vector2 100.0 100.0)
                         :color (xna:white))
    (gfx:end (sprite-batch game))))

(defun main ()
  (let ((game (make-instance 'hello-game :window-title "Hello CNA")))
    (unwind-protect
         (xna:run game)
      (progn
        (when (sprite-batch game) (xna:dispose (sprite-batch game)))
        (when (texture game)      (xna:dispose (texture game)))
        (when (manager game)      (xna:dispose (manager game)))
        (xna:dispose game)))))
```

`examples/hello-cna.lisp` is the same program as a runnable file:

```sh
CNA_NATIVE_LIBRARY=/absolute/path/to/libcna_c_api.so CL_SOURCE_REGISTRY="$PWD//"   sbcl --non-interactive        --eval '(asdf:load-system "cna-common-lisp")'        --load examples/hello-cna.lisp        --eval '(hello-cna:main 60)'
```

A complete, runnable consumer -- with a canary that checks its own frame counts
-- lives in the separate `cna-common-lisp-template` repository.

## Testing

```sh
export CNA_NATIVE_LIBRARY=/absolute/path/to/libcna_c_api.so
sbcl --non-interactive \
     --eval '(asdf:test-system "cna-common-lisp")'
```

The suite has four layers. The pure-Lisp, structural and behaviour layers need no
native library; the native layer needs `CNA_NATIVE_LIBRARY` and **fails** rather
than skipping when it is set and the library is unusable. Without it the native
layer is reported as not run, never as passed.

Maintenance gates, which need a CNA source checkout and a C compiler:

```sh
# regenerate the private foreign layer from the canonical headers
python3 tools/native-abi/generate.py \
    --headers  /path/to/cna/modules/c-api/include \
    --baseline /path/to/cna/tools/c-api/abi_baseline.json

# compile-time prototype, layout and constant verification
tools/native-abi/verify.sh /path/to/cna/modules/c-api/include

# structural compatibility report
tools/api-compat/verify.sh --strict
```

Neither is needed to *use* a released CNA-Lisp: a consumer needs SBCL, the ASDF
dependencies and a qualified native library — not the CNA headers and not a C
compiler.

## Capability statement

CNA-Lisp implements a small, complete, measured part of XNA and says so. It is
not "XNA for Lisp"; it is the first qualified foundation of one, and the generated
reports in `docs/generated/` are the authority for exactly how much.

Read `plan.md` for the architecture and the current measured status, and
`NEXT.md` for the exact continuation point.

## Documents

| | |
| --- | --- |
| `plan.md` | architecture, selected profile, current measured status |
| `NEXT.md` | the exact continuation point and its commands |
| `docs/common-lisp-mapping.md` | how a CLR element becomes a Lisp one |
| `docs/native-abi.md` | the manifest, the ABI gate, by-value passing |
| `docs/ownership-and-lifetimes.md` | disposal, generations, the device facade |
| `docs/callbacks-and-threading.md` | containment, the registry, thread affinity |
| `docs/compatibility.md` | what is complete, partial and missing |
| `docs/limitations.md` | every measured limitation, with its reason |
| `docs/qualification.md` | what REFERENCE_QUALIFIED, CI_TESTED and HEADLESS mean |

## Licence

MS-PL, matching CNA. No Microsoft binary is stored in this repository or
distributed with it; only provenance, hashes and extraction procedures are
recorded.
