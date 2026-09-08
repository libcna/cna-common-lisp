# The Video family: measured, and not selected

Measured 2026-09-08 against the admitted ABI set `{0.21.0, 0.22.0, 0.23.0}`.
Nothing in `Microsoft.Xna.Framework.Media.Video`, `VideoPlayer` or
`VideoSoundtrackType` is bound, and this file is why.

**The short version.** `VideoPlayer` works. It plays a video, advances a real
clock, loops, and hands back real decoded frames as `Texture2D` pixels on every
admitted ABI and every renderer here. That was the question this audit was
opened to answer, and the answer is yes.

It is not the question that decides the namespace. **XNA's `Video` has no public
constructor** -- its only constructor is `assembly`-scoped, and its only public
producer is `ContentManager.Load<Video>`. **No admitted C ABI exposes that
route**, and none of the ways around it survives contact:
`cna_content_manager_load_foreign_ext` refuses an asset whose root reader is one
of CNA's own, and the canonical `VideoReader` name cannot be taken over because
CNA registers it itself.

So a `VideoPlayer` could be bound whose only argument no XNA program could
construct. That is the thing this project does not do, and the blocker is a
missing C route with a name: `cna_content_manager_load_video`.

## The two gates

The audit was run as two independent gates, and a namespace needs both.

| Gate | Question | Result |
| --- | --- | --- |
| A | Is `VideoPlayer` positively qualifiable on every admitted ABI? | **passes** |
| B | Can CNA-Lisp obtain a `Video` through an XNA-public producer? | **fails** |

`A` passing is what makes `B` worth writing down at this length. A blocker
behind a feature that does not work is a footnote; a blocker in front of one
that does is a specific, reportable gap in the C ABI.

## Gate A --- the player

### The instruments

Two of them, both committed, both reproducible with no GPU:

* `tools/qualification/make-video-fixture.py` generates the fixture. It is
  generated rather than downloaded because an arbitrary file proves that a
  decoder ran and nothing about **which frame came back** -- which is exactly
  the difference between playback and one poster frame.
* `tools/native-abi/video-player-probe.c` drives the player, one stage per
  process.

The fixture is 64x48, 10 fps, 2.000 s, twenty frames, in four half-second
sections. Each frame carries three independent signals:

| signal | what it proves |
| --- | --- |
| the field colour -- red, green, blue, yellow by section | which half-second the frame is from |
| a white 16x12 marker, in a different corner per section | the same thing again, independently |
| a black 8x8 anchor at the exact centre of every frame | the frame arrived the right way up and the right way round |

Two signals for the temporal question is deliberate. They have to agree, so a
frame that came back in the wrong colour space cannot pass as the wrong section;
the four field colours are the most separated points available in RGB, so a YUV
round trip moves them and never far enough to confuse two. The anchor answers
the spatial question a uniform field cannot.

The generator emits the same twenty raw frames into three containers. `-g 1` on
the Theora encode is not decoration: without it libtheora returns fifteen frames
for the twenty it was given, and a fixture whose frame count is not the one it
was built from cannot anchor a claim about *which* frame came back.

### What the player does

Every row below was measured on all three admitted ABIs. **156 observations, and
four differences** -- all four of them microsecond jitter in wall-clock timings,
which is what a real clock is supposed to produce.

| measurement | result |
| --- | --- |
| player create, from a `Game` | `SUCCESS` |
| initial `State` / `PlayPosition` / `Video` | `Stopped` / 0 ticks / none |
| `Play` | `SUCCESS`, `State` becomes `Playing` |
| `PlayPosition` while playing | advanced 0.300 s over a 0.300 s wait |
| `Pause` | `Paused`; position stable across a 0.200 s wait, to the tick |
| `Resume` | `Playing`; position continues from where it paused |
| `Stop` | `Stopped`; position 0; **`Video` cleared** |
| `Pause`/`Resume`/`Stop` on a stopped player | `SUCCESS`, state unchanged -- observable no-ops |
| `GetTexture` before `Play` | `SUCCESS` with `available = false` |
| `GetTexture` after `Play` | a real texture handle |
| pixel readback | 3072 texels, which is exactly 64x48 |
| the pattern in those pixels | section 0: field `238,14,13`, marker `235,235,235`, anchor `15,18,18` |
| four samples across the four sections | red, green, blue, yellow, **in order** |
| `generation` across those samples | 4, 9, 14, 19 -- monotonic, and it moved |
| `presentation_time` across them | 0.300, 0.800, 1.300, 1.800 s |
| natural end of a 2.000 s video | `Stopped`, position 0, **`Video` still attached** |
| the same with `IsLooped` | still `Playing` at t=3.2 s, position **1.203 s** -- it wrapped |
| `get_video` after `Play(A)` then `Play(B)` | the exact handle passed in, each time |
| wrong thread: every operation | `CNA_RESULT_THREAD`, uniformly |

The strongest claim the evidence supports is the one worth making: **decoded
video frames advanced and were exposed as real `Texture2D` pixels**, identified
by a pattern that says which frame they were, not merely that `Play` returned
success.

### Renderers and codecs

`GetTexture` was expected to need the positive renderer, the way `Texture3D`
did. It does not.

| renderer | frames? |
| --- | --- |
| HEADLESS | **yes** |
| SOFTWARE | **yes** |
| EasyGL `OPENGL33`, Xvfb + Mesa llvmpipe, no GPU | **yes**, all 14 stages, no failures |

CNA's frame texture is a CPU-shadowed `Texture2D`, so it does not need volume
storage or a GL context the way a `Texture3D` does. The EasyGL lane raised no
`SIGFPE`: the floating-point boundary closure holds.

All three containers decode: WMV8 in ASF, Theora in Ogg, and H.264 in MP4.

**This is not codec parity with XNA, and must not be reported as it.** XNA 4
consumes WMV3/VC-1, and the ffmpeg here decodes both and can encode neither, so
the `.wmv` fixture is WMV8 -- the closest thing this machine can produce. CNA
decodes through `avformat_open_input` and `avcodec_find_decoder` with no format
restriction, so it reads whatever ffmpeg reads. What the fixture qualifies is
CNA's decoder and the `VideoPlayer` state machine. It does not qualify the file
format an XNA title ships.

One decoder detail, recorded because it looked like a fixture bug and is not:
the Theora file reports **24 fps** where the other two report 10. Its
`avg_frame_rate` is `0/0` and CNA falls back to 24 when it cannot read one; the
container's `r_frame_rate` is 10/1 and correct.

### The borrowed frame handle

`cna_video_player_get_texture` documents its result as valid only until the next
call on that player. Measured, that is literal:

| after | the earlier handle |
| --- | --- |
| reading its pixels straight away | works -- 3072 texels |
| one `get_state` call | **`INVALID_HANDLE`** |
| `Pause` | **`INVALID_HANDLE`** |
| `Stop` | **`INVALID_HANDLE`** |
| another `GetTexture` | **`INVALID_HANDLE`** |
| the player's `Dispose` | **`INVALID_HANDLE`** |

Every `GetTexture` mints a **new handle value** -- `4294967301`, `8589934597`,
`12884901893` -- so the handle is not even stable while it is valid. Nothing
survives a single unrelated property read.

**XNA's shape is materially different, and this is the second finding that would
have to be reconciled before anything is bound.** The pinned IL shows
`VideoPlayer` holding `Texture2D[] frameTextures` and an `int32
currentTextureId`, passing *both* textures to `VideoDecoder_GetTexture` and
being told which is now current. XNA hands back **one of two stable,
player-owned `Texture2D` objects**; CNA hands back a handle that dies on the
next call of any kind. A public `Texture2D` over CNA's handle cannot be held
across a property read, and XNA's can.

### Where CNA and pinned XNA already disagree

Measured against the pinned IL rather than assumed. These are Stage B problems
and are recorded now because they are the reason Stage B would not have been
short.

| member | pinned XNA | CNA, measured |
| --- | --- | --- |
| `Volume` setter | **`ArgumentOutOfRangeException`** outside [0,1] | **clamps silently**: -5 reads back 0, +5 reads back 1 |
| `Volume` setter, NaN | out of range, so it throws | **`SUCCESS`, and `Volume` reads back NaN** -- `std::clamp` propagates it |
| `GetTexture` with no active video | **`InvalidOperationException`** | `SUCCESS` with `available = false` |
| `Play(null)` | `ArgumentNullException` | an invalid handle is `INVALID_HANDLE`; there is no null to pass |
| natural end of video | -- | `Stopped` but the `Video` stays attached, unlike `Stop`, which clears it |
| `Play` of an undecodable video | -- | returns `SUCCESS`, leaves `Stopped` with no video -- but **a frame texture is still reported available** |
| `get_Video` after `Dispose` | ungarded in IL, returns the field | `SUCCESS`, still reports a video |

`Pause`, `Resume`, `Stop` and `State` are guarded in XNA by `ThrowIfDisposed`
and an `IsValidDecoder` check, and are observable no-ops otherwise -- which is
the shape CNA has.

The player does **not** own the `Video` it plays. Disposing a player mid-playback
leaves the video's `Width` readable and `cna_video_destroy` succeeding, so the
ownership edge is `Game -> VideoPlayer` with a reference and no adoption.

## Gate B --- the producer

### XNA's answer

From the pinned 257-type contract snapshot (SHA-256 `7207908e...`, recovered
byte-for-byte by `tools/api-compat/recover-contract-snapshot.py`) and the pinned
`Microsoft.Xna.Framework.Video.dll` IL:

`Microsoft.Xna.Framework.Media.Video` is `public sealed`, extends `System.Object`,
and its public surface is **five read-only properties and nothing else**:
`Duration`, `Width`, `Height`, `FramesPerSecond`, `VideoSoundtrackType`.

It has exactly one constructor, and the IL says what it is:

```
.method assembly hidebysig specialname rtspecialname
        instance void .ctor(GraphicsDevice device, string file, int32 duration,
                            int32 width, int32 height, float32 framesPerSecond,
                            VideoSoundtrackType soundtrackType)
```

`assembly` -- internal. **Not public, not protected.** The contrast inside the
same file is the proof this is not a metadata artefact: `VideoPlayer` carries an
ordinary `public .ctor()` and `Video` does not.

Its one public producer is `ContentManager.Load<Video>`, through the private
`Microsoft.Xna.Framework.Content.VideoReader`, whose `Read` is six field reads
and a constructor call:

```
ReadObject<string>()    ->  GetAbsolutePathToReference(...)
ReadObject<int32>()     ->  duration in milliseconds
ReadObject<int32>()     ->  width
ReadObject<int32>()     ->  height
ReadObject<float32>()   ->  frames per second
ReadObject<int32>()     ->  VideoSoundtrackType
GraphicsDeviceFromContentReader(input)
new Video(device, path, duration, width, height, fps, soundtrackType)
```

That payload maps exactly onto `cna_video_create_with_metadata`, argument for
argument and in the same order, which is what made this architecture worth
testing rather than dismissing.

### What the C ABI has

Measured by `tools/native-abi/video-producer-probe.c`, identically on all three
admitted ABIs -- **30 observations, zero differences**.

| route | 0.21.0 | 0.22.0 | 0.23.0 |
| --- | --- | --- | --- |
| `cna_content_manager_load_video` | absent | absent | absent |
| `cna_content_manager_load_video_ext` | absent | absent | absent |
| `cna_content_manager_load_song` | absent | absent | absent |
| `cna_video_create_from_content` / `_from_asset` | absent | absent | absent |

The typed loaders that **do** exist are `texture2d`, `texture_cube`,
`sprite_font`, `model`, `effect` and `sound_effect`. `video` is not among them,
and neither is `song`. `video.h` is byte-identical across all three ABIs
(SHA-256 `892867ed...`), so this is not a version to wait for.

### The three ways around it, and why none works

**1. `cna_content_manager_load_foreign_ext`.** The only route that reaches a
reader from outside. Given a real Video `.xnb` under a
content root whose manifest it refreshes and reads, it answers
`CNA_RESULT_IO`, and CNA says why in its own words:

> The asset's root type reader is not a caller-registered reader, so it did not
> produce a foreign object.

The asset was found. Its root reader ran. It produced a native `Video`. The C
ABI then **discarded it**, because `Load<ForeignContentObjectEXT>` `any_cast`s
the result and a built-in reader's product is not a foreign object. There is no
typed route to ask for it instead.

**2. Register a Lisp `VideoReader` under the canonical name.** Refused:
`CNA_RESULT_INVALID_STATE`, because `RegisterBuiltinLoaders` registers
`Microsoft.Xna.Framework.Content.VideoReader` itself and the C ABI deliberately
refuses a duplicate rather than handing back a live handle whose factory is
never called. `get_is_registered` confirms it: already taken.

The mechanism is not the problem, and the probe proves that separately: the same
table registered under a name CNA does not own succeeds, its read callback runs,
and `read_bytes_exact` works inside it.

**3. Parse the payload in Lisp anyway.** Even with a name, the C content-reader
surface cannot express XNA's reader. It has `read_bytes_exact`,
`read_object_tag`, `read_shared_resources` and typed reads for `Color`,
`Matrix`, `Quaternion`, `BoundingSphere` and the vectors. It has **no
`ReadObject<string>`, no `ReadObject<int32>`, no `ReadObject<float32>`, no
7-bit-encoded-integer read** -- all five verified absent. A Lisp reader would
decode raw bytes and re-implement the `ContentReader` primitive layer: a second
content pipeline beside CNA's, which is the thing that is not worth doing for
one type.

### The fixture question, answered before it mattered

CNA's own `Video` `.xnb` fixture is **hand-assembled**, and CNA's test file says
so plainly -- "no MonoGame/dotnet content-pipeline tooling is available in this
environment to produce a real Video .xnb ... documented as an honest gap".

That is the XACT situation again, and the decisive part is again not the bytes
but the compensation. `DecodeVideoXnbData` has **two paths**, chosen by counting
the type-reader table:

* more than one entry -- every field dispatched through the table, which is what
  a real content pipeline writes;
* exactly one entry -- the fields read inline, with the comment that this keeps
  the behaviour of "CNA's established runtime reader ... including in its
  historical full-container fixtures".

CNA's fixture writes **one** table entry, so CNA's own end-to-end `Load<Video>`
test exercises **the compensation path**, not the one an XNA program takes.

`tools/qualification/make-video-xnb.py` therefore defaults to the dispatching
form and documents the difference on the flag, so the distinction is drawn
before a claim rests on it rather than after. It is a measurement instrument, not
an authority: it was written to ask the C ABI a question, and the C ABI's answer
did not depend on which form it was given.

CNA's reader also diverges from XNA in a way worth recording separately: it
implements **FNA's** `VideoReader`, with FNA's `.ogv`/`.ogg` supported-extension
list and FNA's `Normalize()` probing. Pinned XNA does none of that -- it takes
`GetAbsolutePathToReference` and stops.

## What would unblock it

One C route, and the header for it already exists in everything but name:

```
CNA_C_API CNA_Result cna_content_manager_load_video(
    CNA_Handle content_manager,
    CNA_StringView asset_name,
    CNA_VideoHandle* out_video);
```

CNA's C++ `ContentManager::Load<Video>()` works and is tested; the C ABI simply
does not export it, the way it does for the six types it does export. With it,
the binding would still owe the two reconciliations Gate A turned up -- the
frame-texture lifetime against XNA's double-buffered player-owned pair, and
`Volume`'s throw-versus-clamp -- but the namespace would become a question about
projection rather than about reachability.

Until then, binding `VideoPlayer` would mean publishing a player whose only
argument has no public producer, or inventing `make-instance 'video` out of
`cna_video_create` -- an XNA-public constructor that XNA does not have.
