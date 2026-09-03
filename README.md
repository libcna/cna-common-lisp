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

No claim is made for another Common Lisp implementation, for Windows or macOS,
for another ABI version, or for visible rendering. See `docs/limitations.md`.

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
* `Viewport`, `Color` with all 141 predefined XNA colours, `Point`, `Rectangle`,
  `Vector2`, `Vector3`, `Vector4` and the whole of `MathHelper` — computed in
  binary32, in XNA's own order of operations, each method written from the
  disassembled IL of the hash-pinned assembly rather than from a description of
  what it should do;
* `Texture2D` decoded from a real PNG into a real native texture;
* `SpriteBatch` with a real textured draw, with rotation, scale, origin, tint,
  source rectangle, effects and layer depth;
* `Keyboard`, `KeyboardState`, `KeyState` and all 160 `Keys` members;
* a full condition hierarchy, deterministic disposal, generation-checked
  ownership, thread affinity, and callback condition containment.

Everything else in XNA is **absent and measured as absent**. There are no
placeholder methods that answer a default and claim success.

<!-- generated:selected types=29 -->
<!-- generated:selected members=1081 -->
<!-- generated:complete types=18 -->
<!-- generated:partial types=10 -->
<!-- generated:missing types=1 -->
<!-- generated:complete members=756 -->
<!-- generated:partial members=1 -->
<!-- generated:missing members=136 -->
<!-- generated:not-applicable members=188 -->
<!-- generated:disagreement total=0 -->
<!-- generated:bound native functions=69 -->
<!-- generated:bound native structs=20 -->

The generated scoreboard, over a selection of **29 XNA types and 1081 members**:

| | |
| --- | --- |
| Types complete / partial / missing | **18 / 10 / 1** |
| Members complete / missing | **756 / 136** |
| Members not applicable | **188** |
| **Disagreement diagnostics** | **0** |

Zero disagreement means nothing implemented contradicts the contract, nothing
private leaked into a public package, every exported symbol is accounted for, no
mapping rule names a member that does not exist, and every overload family that
collapses onto one function says how each overload is expressed. It does **not**
mean the binding is finished: 136 members are missing and are reported as
missing. `docs/compatibility.md` is the authority.

The private foreign layer binds **68 native routes** and **19 native structs**,
all of them generated from the canonical CNA headers and checked by a C
compiler.

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

## Licence

MS-PL, matching CNA. No Microsoft binary is stored in this repository or
distributed with it; only provenance, hashes and extraction procedures are
recorded.
