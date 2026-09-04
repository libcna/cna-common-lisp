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
| Build system | ASDF |
| CNA C ABI | **0.21.0** only (encoded 5376) |
| CNA build | `SDL3` platform, `SDL3` audio, **HEADLESS** renderer |
| Second lane | the same suite against a **SOFTWARE** renderer, which reads real pixels back out of the back buffer |

No claim is made for another Common Lisp implementation, for Windows or macOS,
for another ABI version, for a physical monitor, or for a GPU renderer.

HEADLESS qualifies command submission and the lifecycle. The SOFTWARE lane
qualifies the three pixel paths it actually tests: a `Clear` reaches the back
buffer and reads back; a `SpriteBatch` draw puts a generated opaque texture's own
texels on exactly the pixels its destination rectangle names — checked at the
rectangle's corners and at the pixels immediately outside it, with a second,
four-colour texture proving orientation as well as placement; and a
`DrawUserPrimitives` triangle drawn through a `BasicEffect` pass covers exactly
the pixels its geometry covers and none outside them. It needs no display to do
any of that. `docs/qualification.md` defines the claims and
`docs/limitations.md` bounds them.

## What is implemented

The first qualified foundation is a real end-to-end vertical slice, not a set of
stubs:

* `Game` as a public CLOS class you subclass, with the whole native loop as
  overridable generic functions — `initialize`, `load-content`, `begin-run`,
  `update`, `begin-draw`, `draw`, `end-draw`, `end-run`, `unload-content`,
  `on-exiting`;
* `GraphicsDeviceManager` over CNA's own manager;
* `GraphicsDevice` as a parent-owned facade that borrows a valid handle per
  operation, because that is the only thing CNA's callback-scoped device lending
  permits;
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
  exactly as XNA's
  `SetRenderState` does. The two `Effect`-bearing overloads are **not** faked and
  are measured as missing;
* the CLR **event projection**: `game.Activated += handler` becomes
  `(add-activated-handler game handler)`, over CNA's own subscription routes,
  with the registrations released deterministically with the object. `Game`'s
  four events and `GraphicsDeviceManager`'s five data-free ones are bound;
* a full condition hierarchy, deterministic disposal, generation-checked
  ownership, thread affinity, and callback condition containment.

Everything else in XNA is **absent and measured as absent**. There are no
placeholder methods that answer a default and claim success.

<!-- generated:selected types=126 -->
<!-- generated:selected members=2057 -->
<!-- generated:complete types=117 -->
<!-- generated:partial types=9 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1594 -->
<!-- generated:partial members=1 -->
<!-- generated:missing members=72 -->
<!-- generated:not-applicable members=390 -->
<!-- generated:disagreement total=0 -->
<!-- generated:bound native functions=273 -->
<!-- generated:bound native structs=49 -->

<!-- generated-block:scoreboard-headline -->
The generated scoreboard, over a selection of **126 XNA types and 2061 members**:

| | |
| --- | --- |
| Types complete / partial / missing | **117 / 9 / 0** |
| Members complete / missing | **1594 / 72** |
| Members not applicable | **390** |
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
The private foreign layer binds **273 native routes** and **49 native structs**,
all of them generated from the canonical CNA headers and checked by a C compiler.
<!-- /generated-block:native-abi-headline -->

## Installing

CNA-Lisp is an ordinary ASDF system. Quicklisp or Qlot may be used to obtain its
dependencies, but nothing Quicklisp-specific is part of the runtime.

```sh
git clone https://github.com/openeggbert/cna-common-lisp
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
