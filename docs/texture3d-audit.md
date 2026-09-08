# Texture3D: the capability audit, and what the old measurement really said

Measured 2026-09-08, before any of the closure was written, against all three
admitted CNA ABIs. It exists because the previous frontier ruled `Texture3D` out
on evidence that was **true and misread**:

    HEADLESS  0.21.0, 0.22.0, 0.23.0 -> CNA_RESULT_NOT_SUPPORTED
    SOFTWARE  0.21.0, 0.22.0, 0.23.0 -> CNA_RESULT_NOT_SUPPORTED

Six combinations, one answer, and it was recorded as "CNA cannot create a
Texture3D". What it actually says is "**these two renderers** cannot". Both of
them are the ones the qualification suite happens to use, so the distinction
never showed up. `cna_texture3d_create`'s own documentation is explicit — it
creates one "when the selected renderer supports volume storage" — and CNA's
EasyGL family reports `GraphicsCapability::Texture3D` true on every non-ES2 GL
profile and carries a real `EasyGLTexture3DRenderer` with 3D allocation, mip
storage, sub-volume `SetData`/`GetData` and `BindTexture3D`.

So the blocker was re-measured against a build that claims the capability. **The
six rows above are unchanged and were re-run on 2026-09-08**; what changed is
that there is now a seventh, eighth and ninth row where the answer is different.

## 1. The libraries, by exact commit

Three clean detached worktrees, no CNA patches, each built with the desktop-core
EasyGL profile and the same sharp-runtime pairing qualification uses.

| ABI | CNA commit | sharp-runtime commit |
| --- | --- | --- |
| 0.21.0 | `056e57d478f8e6accfa9124337803e735b39f1e4` | `bfc826e1fa7eef1adb36df1c64782e9939a0af37` |
| 0.22.0 | `fb62662c9536f30a6a8bd080597002b8443b28d4` | `bfc826e1fa7eef1adb36df1c64782e9939a0af37` |
| 0.23.0 | `5c8840657caa448149af9374b96bbd6acee354a1` | `bfc826e1fa7eef1adb36df1c64782e9939a0af37` |

EasyGL is not a submodule of CNA; it is a **sibling checkout**, and so is its own
sibling `meta-gl`. Both were built from clean detached worktrees too:

| Repository | Commit |
| --- | --- |
| `easy-gl` | `deda7a426c3c166c0e03a4790f1ede610e2e46fb` |
| `meta-gl` | `20c8b2dc5bb80e32706784066db9fd9e15b3f46a` |

The CMake arguments, identical for all three:

```sh
cmake -S <cna> -B <tree> -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCNA_PLATFORM=SDL3 \
    -DCNA_GRAPHICS_RENDERER=OPENGL33 \
    -DCNA_BUILD_C_API=ON -DCNA_BUILD_TESTS=OFF -DCNA_BUILD_EXAMPLES=OFF \
    -DCNA_SHARP_RUNTIME_ROOT=<sharp-runtime>
```

`OPENGL33` is the identity `cmake/RendererRegistry.cmake` maps to
`EasyGL|GetDescriptorOpenGL33` — the desktop-core profile. `OPENGLES2` and
`WEBGL1` are deliberately **not** used: EasyGL reports `Texture3D` unsupported
for the ES2 API generation, so a refusal there would be the profile's answer and
not the renderer's.

Each built artifact records the commits it came from, next to the library:
`~/deps/cna-c-abi-<version>-opengl33/{CNA_COMMIT,SHARP_RUNTIME_COMMIT,CONFIG}`.
An artifact whose CNA commit was not recorded is not qualification evidence, and
that is why these carry one.

## 2. The GL stack, which is deliberately not a GPU

    Xvfb :N, screen 1280x800x24
    LIBGL_ALWAYS_SOFTWARE=1  GALLIUM_DRIVER=llvmpipe

    OpenGL vendor                Mesa
    OpenGL renderer              llvmpipe (LLVM 19.1.7, 256 bits)
    OpenGL core profile version  4.5 (Core Profile) Mesa 25.0.7-2+deb13u1
    EasyGL runtime profile       OPENGL33, "EasyGL initialized with OpenGL 4.5
                                 (Core Profile) Mesa 25.0.7-2+deb13u1"

The whole point of the lane is that volume storage works on a **deterministic
software OpenGL implementation** a CI machine can reproduce. A physical GPU is
not a prerequisite and, where one exists, `LIBGL_ALWAYS_SOFTWARE` keeps it out of
the answer.

EasyGL's own capability line, printed at device creation on all three:

    texture SurfaceFormat: Color + NormalizedByte4 + NormalizedByte2 + Bgr565
      + Bgra5551 + Bgra4444 + Dxt1/Dxt3/Dxt5
    render-target SurfaceFormat: Color + half-float + float

## 3. The matrix

`tools/qualification/texture3d-matrix.sh` over
`tools/native-abi/texture3d-volume-probe.c`, one stage per process. Identical on
all three ABIs — every row below was produced three times, and no stage reported
a single failure.

| Stage | 0.21.0 | 0.22.0 | 0.23.0 |
| --- | --- | --- | --- |
| `create` — 4×3×2 Color volume, metadata, native type name | pass | pass | pass |
| `whole` — whole level 0 out and back, byte for byte | pass | pass | pass |
| `box` — one sub-volume out and back, rest unmoved | pass | pass | pass |
| `mip` — 8×4×3 mipmapped: levels 0, 1, last, and one past | pass | pass | pass |
| `depth-levels` — 2×2×8 mipmapped, where the authorities differ | pass | pass | pass |
| `bytes` — the raw-byte upload route, read back as Color | pass | pass | pass |
| `range` — bad level, box past the edge, short array | pass | pass | pass |
| `destroy` — destroy, then refuse every use of the handle | pass | pass | pass |
| `volumes` — 32 volumes made, written and destroyed on one device | pass | pass | pass |
| `churn` — **a second GraphicsDevice in one process** | **faults** | **faults** | **faults** |

### 3.1 The voxel pattern is nonuniform on every axis

    R = 16 + 40·x    G = 16 + 40·y    B = 16 + 40·z    A = 255

so a transposed axis, a reversed slice, or a row- or slice-pitch mistake cannot
round-trip by accident. The volume is 4×3×2 — three different extents — for the
same reason. Every transfer above is compared **byte for byte**, not by count.

### 3.2 The sub-volume claim is two claims

`box` writes `x ∈ [1,3), y ∈ [1,3), z ∈ [1,2)` over a seeded volume and then reads
the **whole** level back, so it can assert both halves separately: the voxels
inside the box carry the patch, and the voxels outside it are still the seed. A
sub-volume write that quietly rewrote the level would pass the first check and
fail the second.

### 3.3 A refused `GetData` leaves the destination alone

`range` fills the destination with `0xab`, asks for a box larger than the
capacity, and checks every byte afterwards. CNA answers result 14 and writes
nothing — which is what `texture_volume.h` promises ("failure leaves
`destination` unchanged") and is now measured rather than believed. The route
still reports the required element count on refusal.

## 4. The one measured divergence: what `LevelCount` counts

**XNA and CNA/EasyGL do not agree about how many mip levels a volume has, and the
disagreement only shows when depth is the largest axis.**

XNA's authority is the pinned `Microsoft.Xna.Framework.Graphics.dll`
(SHA-256 `560080fc…9f55`). `Texture3D::CreateTexture` computes

    Levels = mipMap ? 0 : 1

and hands that to `IDirect3DDevice9::CreateVolumeTexture`. Zero is D3D9's request
for a **complete chain down to 1×1×1**, so XNA's level count is
`1 + floor(log2(max(width, height, depth)))`. The IL reaches native D3D9 here
rather than computing the number itself, so Microsoft's documented rule for
`Levels = 0` is the corroborating authority for what happens next.

EasyGL computes it differently, and says so in a comment:

```cpp
// Mirrors Texture3D.cpp's CalculateMipLevels(w,h) — depth does not participate
// in the level count, matching FNA's Texture3D constructor, but each level's own
// GPU storage still halves in all 3 dimensions
static int CalculateTexture3DMipLevels(int w, int h)
```

FNA is secondary evidence and it is not XNA's answer here. Measured, on all three
ABIs:

| Volume | XNA (D3D9, `Levels = 0`) | CNA/EasyGL, measured | Agree? |
| --- | ---: | ---: | --- |
| 8×4×3 | 4 | **4** | yes |
| 2×2×8 | 4 | **2** | **no** |

The per-level *dimensions* are not in dispute: level 1 of the 2×2×8 volume
measures 1×1×4, so depth does halve per level exactly as the comment says. What
differs is where the chain stops.

**This is a renderer property, not a binding narrowing**, and it is the same
class of fact as "HEADLESS cannot create a Texture3D at all": CNA-Lisp reports
what CNA reports, and a CNA built on a renderer that counts the way D3D9 does
would answer XNA's number through the same code. The binding therefore reads the
level count from `cna_texture3d_get_info` and never computes one, and the
divergence is recorded in `docs/limitations.md` rather than asserted away.

## 5. The second GraphicsDevice, which is why the lane is one per process

`churn` creates a caller-owned `GraphicsDevice`, destroys it, and creates
another. The second `cna_graphics_device_create` **segfaults**, on all three
ABIs, with no Texture3D involved anywhere in the stage.

It is EasyGL's, not Texture3D's, and not the ABI's:

| Renderer | second device in one process |
| --- | --- |
| HEADLESS 0.23.0 | fine — four cycles, no fault |
| SOFTWARE 0.23.0 | fine — four cycles, no fault |
| OPENGL33 (EasyGL) | **SIGSEGV inside the second create** |

Two consequences, both of which shape the closure rather than block it:

* the EasyGL lane is **one device per process**, which is why the matrix runs one
  stage per process and why the Lisp lane does the same. The ordinary suite —
  which creates and destroys games hundreds of times in one image — must keep
  running on HEADLESS, and does.
* it is not a leak in the volume path. `volumes` makes, writes and destroys 32
  mipmapped volumes on **one live device** and the device then tears down
  cleanly, which is the teardown evidence this renderer can actually give.

## 6. The routes, against the members

`texture_volume.h` is byte-identical across the admitted set and declares eight
Texture3D routes. The eleven-member XNA contract maps onto them like this — and
the mapping is what decides which members are complete and which are narrowed,
which is not something a route count can tell you.

| XNA member | Route | Complete? |
| --- | --- | --- |
| `.ctor(GraphicsDevice,Int32,Int32,Int32,Boolean,SurfaceFormat)` | `cna_texture3d_create` | yes |
| `Width` / `Height` / `Depth` | `cna_texture3d_get_info` | yes |
| `SetData<T>(T[])` | `cna_texture3d_set_data` | **Color only** |
| `SetData<T>(T[],Int32,Int32)` | `cna_texture3d_set_data` | **Color only** |
| `SetData<T>(Int32×7,T[],Int32,Int32)` | `cna_texture3d_set_data` | **Color only** |
| `GetData<T>(T[])` | `cna_texture3d_get_data` | **Color only** |
| `GetData<T>(T[],Int32,Int32)` | `cna_texture3d_get_data` | **Color only** |
| `GetData<T>(Int32×7,T[],Int32,Int32)` | `cna_texture3d_get_data` | **Color only** |
| `Dispose(Boolean)` — protected | — | not applicable |

`LevelCount` and `Format` are `Texture`'s members, already selected, and
`cna_texture3d_get_info` answers both. The remaining three routes —
`cna_texture3d_destroy`, `cna_texture3d_get_type_name_byte_count` and
`cna_texture3d_copy_type_name` — serve disposal and the native type-name check
rather than a named XNA member.

### 6.1 Why the six transfer members are partial

XNA's `SetData<T>`/`GetData<T>` accept any blittable `T` whose size divides the
surface format's. From `Texture3D::GetAndValidateSizes<T>` in the pinned IL,
exactly:

    elementSize = sizeof(T);  formatSize = GetExpectedByteSizeFromFormat(format)
    elementSize == formatSize                      -> accepted
    formatSize  <  elementSize                     -> ArgumentException(InvalidDataSize)
    formatSize  %  elementSize != 0                -> ArgumentException(InvalidDataSize)
    otherwise                                      -> accepted

So for a `Color` volume (`formatSize` 4), XNA takes `T` of 4, 2 or 1 bytes.

CNA's routes cannot express that. `cna_texture3d_set_data` takes
`const CNA_Color*` and `cna_texture3d_get_data` a `CNA_Color*`, with a capacity
counted in elements and **no texel-kind argument anywhere** — unlike
`cna_texture2d_set_data`, whose `CNA_TEXTURE_DATA_*` argument is exactly what
lets `Texture2D` here project five element types. This is the same narrowing
`TextureCube` has, and for the same reason.

`cna_texture3d_set_data_bytes` is the one thing Texture3D has that TextureCube
does not: a `SetDataPointerEXT` route taking tightly packed raw bytes. It works —
the `bytes` stage proves a raw upload lands as exactly the voxels `Color` would —
but it is **upload only**. There is no byte read route. Using it to widen
`SetData` alone would leave a Texture3D that can be written as bytes and never
read back as bytes, which is not what XNA's symmetric generic pair means. So both
halves stay Color, both are reported partial, and the asymmetry is recorded here
rather than half-resolved.

## 7. Verdict

Stage A succeeds on all three admitted ABIs: creation, metadata, whole-volume
transfer, sub-volume transfer, mip transfer, destruction and clean teardown, on a
software GL stack, with zero failures. `Texture3D` is **no longer blocked by
qualification capability**, and the two facts that survive the change are the two
worth keeping:

* HEADLESS and SOFTWARE still answer `NOT_SUPPORTED`, and that branch is
  evidence too — it is asserted, not skipped.
* a renderer that claims a capability still has to be measured. EasyGL's mip
  level count is not XNA's, and no capability flag would have said so.
