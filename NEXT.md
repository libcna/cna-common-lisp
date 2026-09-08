# CNA-Lisp continuation handoff

`plan.md` is the architecture and the rules. This file is *where the work stands*
and *what to do next*, and nothing else: when a closure lands, the prose that
described it as future work is **deleted** rather than left to age. Everything
numbered here is generated; reproduce it rather than trusting it. Git history
holds the states this file used to describe.

## Reproduce the state

```sh
export CNA_NATIVE_LIBRARY=/absolute/path/to/libcna_c_api.so   # ABI 0.21.0, HEADLESS
export CNA_HEADERS=/path/to/cna/modules/c-api/include
export CNA_ABI_BASELINE=/path/to/cna/tools/c-api/abi_baseline.json
export CNA_LISP_VALUEPROBE="$PWD/build-probe/libcna-lisp-valueprobe.so"
export CNA_LISP_SHIM="$PWD/build-probe/libcna-lisp-shim.so"      # optional

# 1. the generated foreign layer is current
python3 tools/native-abi/generate.py --check --headers "$CNA_HEADERS" --baseline "$CNA_ABI_BASELINE"

# 2. a C compiler agrees with every bound prototype, layout and constant
tools/native-abi/verify.sh "$CNA_HEADERS"

# 3. the whole test suite. On a machine with a desktop, run it on a virtual
#    screen: CNA's SDL3 platform initialises the host's windowing stack even
#    under HEADLESS, and the suite creates and destroys a game hundreds of times.
tools/qualification/with-virtual-screen.sh \
  sbcl --non-interactive --load ~/quicklisp/setup.lisp \
     --eval '(push (truename ".") asdf:*central-registry*)' \
     --eval '(asdf:test-system "cna-common-lisp")'

# 4. the structural scoreboard, and the prose consistency check
tools/api-compat/verify.sh --strict

# 5. the isolated consumer, at 60 and 600 frames
tools/qualification/isolated-consumer.sh ../cna-common-lisp-template

# 6. the rasterizer lane, which needs a CNA built with a rasterising renderer.
#    -DCNA_GRAPHICS_RENDERER=SOFTWARE is a CPU rasteriser and needs no display.
CNA_NATIVE_LIBRARY=/absolute/path/to/software/libcna_c_api.so \
    tools/qualification/rasterizer.sh

# 7. the audio lanes, in separate processes because SDL's driver selection is
#    process-global and latches at initialisation. Needs no sound card.
tools/qualification/audio.sh

# 8. the capture lanes, the same way and for the same reason, plus the
#    public-only consumer. Needs no microphone. A separate script from the one
#    above because playback and capture are different devices behind different
#    CNA routes, and a machine may have either without the other.
tools/qualification/microphone.sh

# 9. the song-playback lanes, plus their own public-only consumer. Needs no
#    sound card. A third script because a song is neither a sound effect nor a
#    capture device: it goes through media_player.h routes of its own.
tools/qualification/media.sh

# 10. the save-game lanes, plus their own public-only consumer. Needs no device
#     at all and no game either -- and its own processes for two other reasons:
#     CNA's storage application name is process-global and cannot be unset, and
#     one claim is that a save written by one process is read back by another.
tools/qualification/storage.sh

# 11. the service and device-selection lanes, plus their own public-only
#     consumer. Needs no display, no GPU, no audio device and no content
#     fixture: everything it does is lifecycle and configuration. A sixth
#     script rather than a section of the suite because its seven kinds are
#     seven claims and it requires each of them by name -- and because its
#     consumer drives the manager through the *interface* it was retrieved
#     under, which is the actual IServiceProvider use case.
tools/qualification/services.sh

# 12. the caller-owned GraphicsDevice, plus its public-only consumer. A seventh
#     script for a reason of its own: a suite run creates games, and the claim
#     this lane makes is that a GraphicsDevice needs none. Requires nine kinds
#     of owned-device evidence by name and exactly one of the two renderer
#     branches -- the pixel claim under a rasterising renderer, the lifecycle
#     claim under HEADLESS, and never both or neither.
tools/qualification/owned-graphics-device.sh

# 13. the volume-storage lane, which needs a CNA built with a renderer that has
#     it. Neither HEADLESS nor SOFTWARE does -- they answer NOT_SUPPORTED and
#     the suite asserts that, which is the other branch of the same claim. An
#     eighth script because it is the only lane that needs a display, and it
#     needs a *virtual* one on purpose: Xvfb plus Mesa llvmpipe, so that no GPU
#     is ever a prerequisite. It runs four focused claim groups rather than the
#     suite, one per process, for two measured reasons in
#     docs/texture3d-audit.md.
tools/qualification/texture3d.sh   # defaults to ~/deps/cna-c-abi-*-opengl33
```

Two probes are built on demand rather than by any of the above, and neither is
part of the gate stack:

```sh
# the ABI a library actually implements, read out of the library and not the path
cc -O1 -o build-probe/abiver tools/native-abi/abi-version-probe.c -ldl

# both loaded-Model defects, one stage per subprocess, on every admitted ABI
cc -O1 -I "$CNA_HEADERS" -o build-probe/model-defect-probe \
   tools/native-abi/model-defect-probe.c -ldl
tools/qualification/model-defect-matrix.sh /path/to/each/libcna_c_api.so ...
```

`abiver` is what `model-defect-matrix.sh` labels its rows with, and its source
was missing until 2026-09-07 -- the script depended on a binary nobody could
build. `tools/qualification/xna-reference/` is a third, and it is the one probe
here that is expected to *fail*: read its README before believing that two
members are unqualifiable.

The qualification scripts do that for themselves. `with-virtual-screen.sh`
runs its command on a fresh Xvfb display **only when `DISPLAY` is set** -- so a
developer's own screen is left alone, and CI, which runs with no display at all,
is unchanged. That last part is deliberate: the `Native` workflow proves the
SOFTWARE renderer needs no display, and a lane that quietly grew a dependency on
one would stop proving it. `CNA_LISP_NO_XVFB=1` opts out, for watching the
windows.

`git log --oneline` answers what has been published; a count written down here
would go stale the moment the next commit lands. The same is true of the suite's
check count, which is why this file no longer carries one and
`tools/qualification/verify-numbers.py` now refuses one.

## What is green, exactly

Locally, on the reference runtime (SBCL 2.5.2, Linux x86-64), against CNA C ABI
**0.21.0** (encoded 5376), **0.22.0** (encoded 5632) and **0.23.0** (encoded
5888), each built with the `SDL3` platform, `SDL3` audio and the **HEADLESS**
renderer. All three are in the admitted set, and every row below that involves a
library was produced against each of them -- the fourth row is the lane with no
library at all, so it has no ABI to be produced against:

| Gate | Result |
| --- | --- |
| ASDF load from a fresh image | no warnings |
| `asdf:test-system`, native library and shim present | 0 failures, nothing not run |
| `asdf:test-system`, native library, no shim | 0 failures (the setter's refusal path) |
| `asdf:test-system` with neither | 0 failures; the native layer reported as not run, never as passed |
| Compiler-backed ABI probe | compiles clean at `-Wall -Wextra -Werror -Wpedantic` |
| CFFI-vs-recorded layout check | 0 disagreements |
| Structural verification | **0 disagreement diagnostics** |
| Prose consistency | every generated fact and block matches the reports |
| Rasterizer lane | `tools/qualification/rasterizer.sh` against a SOFTWARE-renderer library: every kind its registry requires (<!-- generated:rasterizer proof count=9 -->) |
| Template canary | exactly 60/60 and 600/600 updates and draws |
| Audio, unavailable branch | a driver that does not exist: no device, and every route needing one refused with `NO-AUDIO-HARDWARE-ERROR` |
| Audio, streaming unavailable branch | the same driver: `DynamicSoundEffectInstance`'s constructor **succeeded** anyway and took a buffer, and the refusal arrived at `Play`. Recorded because it is CNA's asymmetry with `SoundEffect`, not asserted away |
| Audio, state machine | `SDL_AUDIODRIVER=dummy`: a device opened with no speaker behind it, and play/pause/resume/stop transitioned |
| Audio, dynamic streaming | the same device: generated PCM16 submitted, the pending-buffer count observed rising to two, and the native streaming state machine observed consuming both while the game loop ran |
| Texture3D, unsupported branch | HEADLESS and SOFTWARE: `cna_texture3d_create` answers `NOT_SUPPORTED` on all three admitted ABIs and the binding reports it as a condition. Asserted, not skipped, and the constructor's own profile guards run there too because XNA applies them before the device is touched |
| Texture3D, EasyGL branch | `tools/qualification/texture3d.sh` against an OPENGL33 build on Mesa llvmpipe under Xvfb: every claim its registry requires (<!-- generated:texture3d claim count=11 -->), on 0.21.0, 0.22.0 and 0.23.0 -- whole-volume, sub-volume with the rest proven unmoved, per-level, both device lifetimes, and `GetValueTexture3D` |
| Isolated consumer | CNA-Lisp loaded from the artifact, not the checkout |
| Native stress | 20 plain cycles + 20 graphics cycles, registry empty after each |
| Construction atomicity | an exploding subclass of twelve resource families, plus `Game` and `GraphicsDeviceManager`, leaves no live child and lets the game shut down -- and one that **subscribed before it failed** leaves no registration and no rooted token either |
| Content transaction | a load made to fail at the texture's storage query, the font's info, its glyph table, or the **cache insertion** gives every handle back exactly once |
| Render-target cross-check | six ways a remembered binding can drift are each refused; an unmutated one is accepted first |
| Model, on 0.22.0 and 0.23.0 | a `.cnj` fixture loads through `ContentManager.Load<Model>`, its three-bone hierarchy and two meshes answer XNA's object identity, the transform copies compose in the IL's order, and `Unload` leaves every view refusing |
| Model, on 0.21.0 | `Load<Model>` **refuses**, because `cna_model_destroy` on a loaded model is a null dereference there. Asserted as a result, not skipped |
| Microphone, on 0.21.0 | everything works except a 1000 ms `BufferDuration`, the top of XNA's range, which that ABI alone refuses. The other four capture lanes are identical on all three |
| Model effect safety, all three | every one of the 17 bound routes that read a content-published effect's missing adapter state refuses with a condition. Enumerated from CNA's source, not listed by hand, and the count was four until this was measured |
| Model pixels | the SOFTWARE lane's `model` proof: two meshes of a loaded model each put their own colour on the pixels their own triangle covers |
| Microphone, unavailable | a driver that does not exist: no capture device enumerated, `Microphone.All` answered the empty list and `Microphone.Default` answered NIL -- which `audio.h` calls an ordinary answer, so this is a result and not a skip |
| Microphone, enumeration | `SDL_AUDIODRIVER=dummy`: capture devices enumerated, `All[i]` was the **same object** on every query, the returned list was fresh, and `Default` was `EQ` to an entry in `All` rather than a second object with equal slots |
| Microphone, state machine | the same devices: `:STOPPED -> :STARTED -> :STOPPED` through `Start` and `Stop`, and a repeated call of either accepted without moving the state |
| Microphone, capture data | the same devices: `GetData` wrote into **exactly** the range it reported, left every byte outside it unchanged -- including the rest of the requested range on a short read -- and advanced inside a justified window around what the device's own `SampleRate` implies |
| Microphone, idle capture | the GitHub runner's own driver enumerates two capture devices and delivers **nothing** from either. That is a third environment, not a variation: every test that needs bytes branches on a bounded probe and both branches assert, the negative one proving `GetData` answers zero rather than refusing and writes no byte |
| Microphone, BufferReady | the same devices: the event arrived, its sender was `EQ` to the object `All` and `Default` hand out, removing the handler released the native registration and stopped delivery, and the callback registry returned to its baseline |
| Microphone, public-only consumer | a complete capture session through the two exported packages alone, under a mechanical audit for the internal package, CFFI, handles, result codes and private `%`-symbols |
| Microphone, XNA over CNA | five measured disagreements between CNA and the pinned XNA behaviour, each asserted in **both** directions so a CNA that changed would fail a test rather than silently changing this binding |
| Media, unavailable | a driver that does not exist: a `Song` is created **anyway** -- CNA's constructor only checks that the file exists -- and the refusal arrives at `Play`, wrapped as XNA wraps a failed `Play(Song)` with the native failure as its inner exception. The same asymmetry `DynamicSoundEffectInstance` has with `SoundEffect` |
| Media, playback | `SDL_AUDIODRIVER=dummy`: the transport moved through `:PLAYING`, `:PAUSED` and `:STOPPED`, and each of XNA's **three guards** -- `Pause` only when playing, `Resume` only when not, `Stop` only when not stopped -- was asserted as a no-op in the state it guards against |
| Media, play clock | the same device: the play position advanced inside a justified window around the wall clock and **stood still while paused**, which is the half that makes it a clock rather than a counter |
| Media, queue | the same device: `Play` enqueued, `ActiveSong` answered a **fresh** object `SONG-EQUAL` to its entry and not `EQ` to it, `MoveNext` and `MovePrevious` wrapped at both ends in the managed layer, and the active-index setter clamped where the indexer refuses |
| Media, static events | both events reached handlers that take **no arguments** -- XNA raises them with a null sender because they are static -- subscribing needed no game because CNA's two routes take none, and removing released the registration and stopped delivery |
| Media, public-only consumer | a complete playback session through the two exported packages alone, under the same mechanical audit the capture consumer passes |
| Storage, the root | an application name produced a storage root read back from CNA, and an unusable one was **refused on all three ABIs** with the working root left standing -- which is this binding's doing: 0.21.0 accepts such a name and fails later at the reader, 0.22.0 and 0.23.0 refuse and destroy the root on the way out |
| Storage, no root | a process whose **very first** application name is refused: `STORAGE-ROOT` refuses, a device still selects, `IsConnected` answers **false**, and every container open is refused. XNA's disconnected device, forced by construction rather than waited for |
| Storage, no game | a device selected, a container opened and a save written with **no `GAME` in the image**. The only surface here that needs none, and the consumer lane refuses the example if it ever constructs one |
| Storage, the stream | bytes written through `WRITE-SEQUENCE` came back through `READ-SEQUENCE` after a close and a reopen; `FILE-POSITION`, `READ-BYTE`, `WRITE-BYTE`, `FORCE-OUTPUT` and `WITH-OPEN-STREAM` all work, and a read-only stream refused a write from CNA's own `can_write` rather than from the `FileAccess` asked for |
| Storage, persistence | **two processes**: one writes a save and exits, the other finds the file, reads the bytes back and deletes the container. The one claim in this repository that spans processes, and the reason the surface exists |
| Storage, ownership | the graph is three deep -- device to container to stream -- and **does not cascade**: a container with an open stream and a device with a live container each refused disposal, naming what was still live, and closing children first closed all three |
| Storage, the overloads | `OpenFile`'s three keyword sets and `BeginShowSelector`'s four were accepted, and every shape XNA has not -- a subset, a superset, a mixture -- was refused |
| Storage, the Disposing event | reached a handler taking the sender alone, stopped when the handler was removed, and left the callback registry where it found it. The last of those was a **real leak**: the container had no `:AROUND` releasing its subscriptions, and the stress lanes caught it |
| Services, the managed container | arbitrary user-defined service types CNA has **no identity for** were added, read back by identity, removed one at a time and re-added with a different provider -- with no native route involved at any point. The lane that says the container is XNA's arbitrary dictionary rather than a projection of CNA's two slots |
| Services, the canonical pair | a `GraphicsDeviceManager` registered itself under **both** `IGraphicsDeviceManager` and `IGraphicsDeviceService`, both keys answered the *same object*, and CNA's own `cna_game_services_contains_ext` agreed about both. Disposal then removes only the service key, and only when the entry is still the manager -- so a program's replacement provider survives it, which is XNA's `bne.un.s` and not a convenience |
| Services, the content constructors | both canonical `ContentManager` constructors resolved a graphics device through the `IServiceProvider` protocol, `ServiceProvider` answered the **exact object** each was given, `Game.Content`'s provider is `EQ` to `Game.Services`, and the graphics-device extension constructor still works beside them |
| Device information | `GraphicsDeviceInformation` answered a `GraphicsAdapter` **object** rather than CNA's adapter index; `Clone` shared the adapter and copied the parameters as the IL does; `Equals` compared the parameters field by field; and the `Adapter` setter's wrong-operand defect -- assigning NIL succeeds once and the *next* assignment throws -- was reproduced rather than corrected |
| Preparing device settings | a handler wrote 1234x567 into the candidate while the manager's preference said 800x600, and **the device CNA then made was 1234x567**. The no-handler pass took the preference and the handler-removed pass took it again, so the mutation is the reason rather than a coincidence. A direct device-information observation, not a pixel inference |
| Manager virtual events | a `GraphicsDeviceManager` subclass overriding `OnDeviceCreated` saw the public event raised when it called `CALL-NEXT-METHOD` and **suppressed when it did not** -- which is what makes a protected raiser a seam rather than a callable function, and which the old one-registration-per-handler event machinery could not have done |
| Device selection, and its limit | `FindBestDevice` built candidates from the adapters CNA enumerates and ranked them through the **virtual** `RankDevices`; `CanResetDevice` reproduced XNA's profile comparison exactly. And a real `ApplyChanges` and a real `CreateDevice` **called none of the three**, which the suite asserts directly -- the measured reason all three are partial |
| Services, public-only consumer | the whole flow through the two exported packages alone, under the same mechanical audit the four other consumers pass, with the manager driven through `CREATE-DEVICE`, `BEGIN-DRAW-DEVICE` and `END-DRAW-DEVICE` on the **interface** it was retrieved under rather than on its concrete class |
| Owned device, the constructor | XNA's `GraphicsDevice(GraphicsAdapter, GraphicsProfile, PresentationParameters)` in a process with **no `GAME` in it**, with the IL's own guard order asserted -- the *parameters* are tested first and the adapter second, so a call missing both names the parameters -- and the two `Clone()` calls proved: the device answers neither the caller's object nor one clone shared between its two fields |
| Owned device, coexistence | two owned devices with distinct viewports, distinct collection objects and independent disposal; and a game created and destroyed *around* a live owned device and its texture, with neither gating the other -- which is the strongest proof that no fake game parent leaked into the owned graph |
| Owned device, resources | seven native `GraphicsResource` families built on **two** owned devices, each reporting the device that made it; and a game's own texture still reporting the game's facade with an owned device alive beside it |
| Owned device, cross-device | **not refused, and not invented.** CNA accepts every crossing and the binding read XNA's `TextureCollection::set_Item` to check: it guards disposal, the active render target, the profile and the slot index, and compares no devices at all. Asserted in both directions |
| Owned device, sampler slots | CNA's slot table is **shared between devices** and XNA's is per device -- not mentioned in the header, found by measuring. The collection answers NIL for a displaced slot rather than a binding it can no longer vouch for |
| Owned device, disposal | a device with three live children disposed all four; every child reports disposed, keeps answering its `GraphicsDevice`, refuses its operations, and accepts a second `Dispose` as a no-op. The facade's refusal is unchanged and survives being refused |
| Owned device, one member two lifetimes | `Clear` on a game's facade outside a callback is a `CNA-SCOPE-ERROR`; the same `Clear` on an owned device is legal. Paired in one test, because the difference is private native capability and not two public types |
| Owned device, pixels | **the first graphics evidence in this repository that needs no game.** Under SOFTWARE a standalone device cleared to CornflowerBlue and every one of 128 back-buffer pixels read back (100, 149, 237, 255); a triangle through a BasicEffect pass then covered 36 pixels of 256 with 220 outside it left cleared. Under HEADLESS the readback refuses and that refusal is asserted rather than skipped |
| Owned device, public-only consumer | a complete render -- enumerate, construct, clear, draw, read back, verify, dispose -- through the two exported packages alone, under the same mechanical audit the four other consumers pass, plus the check only this one and the storage consumer can pass: it constructs no `GAME` |
| Microphone, the one ABI limit | `BufferDuration` is **partial**: XNA accepts [100, 1000] ms in steps of ten inclusive, CNA 0.21.0 accepts [100, **990**] and refuses exactly 1000, and 0.22.0 and 0.23.0 take the whole range. Nothing is rounded down to hide it; the refusal names the ABI rather than the argument, and both branches assert |

HEADLESS proves lifecycle and command submission. It proves nothing about pixels
-- **the SOFTWARE lane is what does**, and it needs no display: a CPU rasteriser
clears to CornflowerBlue and the back buffer reads back (100, 149, 237, 255), a
SpriteBatch draw lands a known texture's texels where its destination says, a
BasicEffect pass followed by one DrawUserPrimitives triangle covers exactly the
pixels its geometry covers, and `DrawString` lays a string out glyph by glyph --
each from its own atlas cell at its own advanced position, across a line break,
and a `SaveAsPng`/`FromStream` round trip returns every texel of a known texture.
Neither lane is a claim about a physical monitor. `docs/qualification.md` defines
`REFERENCE_QUALIFIED`, `CI_TESTED`, `HEADLESS` and `NOT RUN`, and no claim here
may collapse two of them.

**The four audio rows are four claims and not one**, for the same reason. That a
transport transitioned says nothing about whether a submitted buffer was ever
taken, and `tools/qualification/audio.sh` requires each kind of evidence by name
rather than reading one out of another. **`dummy device != speaker`**: the
strongest thing the streaming row supports is that generated PCM was accepted and
consumed by the native streaming state machine, and no test in this repository
says a sound was heard.

**The five microphone rows are five claims and not one**, and the same discipline
applies twice over. Devices that enumerate say nothing about whether capture
advances; a stream that advances says nothing about the event that announces it;
and `tools/qualification/microphone.sh` requires each kind by name. It is a
**separate script from `audio.sh`** because playback and capture are different
devices behind different CNA routes -- the GitHub runner has neither, a
developer's laptop may have one and not the other -- and a lane that read one out
of the other would let either be reported as the other.

**The six media rows are six claims and not one**, and the discipline applies a
third time. A transport that transitions says nothing about whether the play
clock advances; a clock that advances says nothing about the queue or the events.
`tools/qualification/media.sh` requires each kind by name, and it is a **third
script** beside the other two because a song is neither a sound effect nor a
capture device -- it goes through `media_player.h` routes of its own, and a run
that qualified the sound-effect transport says nothing about the media player's.

The strongest sentence the media rows support is:

> the media player CNA drives over an SDL device with no speaker behind it moves
> through XNA's transport states, advances its play position at something like
> the wall clock, keeps its queue in XNA's order with XNA's object identity, and
> raises both of its static events -- and CNA-Lisp reproduces the XNA semantics
> over that.

It is **not** a claim that music was audible, that the file was decoded, or that a
physical output device works.

**The eight storage rows are eight claims and not one**, and the discipline
applies a fourth time -- from a different direction, because storage needs no
device and its branch is not the environment's to choose. A container that opens
says nothing about whether bytes come back; bytes that come back in one process
say nothing about whether they reached the filesystem.
`tools/qualification/storage.sh` requires each kind by name, and it is a
**fourth script** because two of its claims cannot be made inside one image at
all: the application name is process-global with no route to unset it, and
"another process reads it back" needs another process.

The strongest sentence the storage rows support is:

> a save file written through CNA-Lisp's public API is on the filesystem under a
> root the program named, is found and read back byte for byte by a different
> process, and the three-deep device/container/stream graph opens and closes in
> the order CNA requires -- and CNA-Lisp reproduces the XNA semantics over that.

It is **not** a claim that the data survives a power cut, a full disk, or a
filesystem that lies about `fsync`. **No test in this repository qualifies
durability**, and none may.

**`dummy capture device != microphone`**, and this is the strongest sentence the
capture rows support, written out in full because a shorter one would overstate
it:

> the native capture device enumerated by the SDL dummy backend advances its
> PCM16 capture stream at the reported sample rate, and CNA-Lisp reproduces the
> XNA state, buffer and event semantics over that stream.

Every byte that backend produces is zero and **no assertion anywhere inspects a
captured byte**. Nothing here says microphone audio is correct, that speech was
captured, or that a physical microphone works.

## The canonical repositories are `libcna`, not `openeggbert`

Both repositories moved: `libcna/cna-common-lisp` and
`libcna/cna-common-lisp-template`, and so did the two they build against --
`libcna/cna` and `libcna/sharp-runtime`. GitHub redirects the old names, and a
redirect is not project configuration: every operational reference is the
canonical one now, and both `origin` remotes push straight to `libcna` rather
than through a redirect. That covers the README's clone command, the template's
link back, `plan.md`'s statement of what the repository *is*, `docs/qualification.md`,
and the six `actions/checkout` repository values in the `Native` workflow.

The pinned commits are unaffected and were re-checked against the new names:
`libcna/cna` has both `fb62662c9` (ABI 0.22.0) and `056e57d47` (0.21.0), and
`libcna/sharp-runtime` has `bfc826e1`. `openeggbert/cnanext`, which older notes
call the current CNA source, **no longer resolves at all**; `libcna/cna` is the
repository the pins live in.

Historical prose that names a run under the old URL is rewritten only where the
link is meant to be followed -- the run ids are unchanged and the runs are the
same runs.

## Continuous integration

Both workflows **have run on GitHub and are the live gate**; any statement that
they have never executed is stale.

| Workflow | What it runs |
| --- | --- |
| `Lisp` / reference | pure gates on SBCL 2.5.2, installed from the upstream binary release and verified by SHA-256 |
| `Lisp` / distro | the same gates on ubuntu-24.04's own SBCL, as a secondary compatibility test |
| `Native` | builds the CNA C ABI from source, then the ABI gate, both runtime configurations and the isolated consumer, on the reference runtime, with the HEADLESS renderer |
| `Native` / rasterizer | a second CNA with the SOFTWARE renderer, and the same suite: it fails unless every kind of pixel proof its registry requires was obtained, and fails too on a kind the registry does not name |
| `Native` / texture3d | a third CNA with the **OPENGL33** (EasyGL) renderer, under Xvfb and Mesa llvmpipe, for the one capability the other two have not got: volume storage. It runs the native matrix and then eleven named claims, and **it does not run the suite** -- a suite run creates and destroys devices hundreds of times, which is what this renderer cannot survive. It changes nothing about the two lanes above; adding a renderer must not make an existing gate conditional. **Dispatch-gated and cannot pass yet -- see below** |

**The `texture3d` job is blocked on an unpublished meta-gl commit, and that is a
measurement rather than a caveat.** CNA's EasyGL renderer references
`metagl::InternalFormat::Rgba16` at all three admitted commits; that enumerator
exists only in meta-gl `20c8b2dc5`, and meta-gl's `origin/develop` is `2520173`,
whose `Enums.hpp` has no `Rgba16`. Run `34210794619` measured it: the checkout
step fails with `upload-pack: not our ref 20c8b2dc5...`.

**This is the sharp-runtime break of 2026-09 again, in a different repository.**
That one was `cna:next` calling `SetIsolatedStorageRootOverride` while the
sharp-runtime commit defining it sat unpushed for four measurements, and its fix
was to publish the commit. This one's fix is the same: **push meta-gl
`20c8b2dc5`**, then set `texture3d_lane: on` once to confirm, then delete the
job's `if:` so it runs on every push. It is one focused build with no suite run,
so it costs about what the rasterizer lane costs.

Pinning the published tip instead would produce a library that does not compile,
so there would be nothing to run; the lane is gated rather than pointed at
something broken. The evidence itself is not in doubt -- eleven claims on all
three admitted ABIs, locally, from exact commits, reproducible with
`tools/qualification/texture3d.sh` -- and it is **local** evidence until CI can
take it, which is the distinction `docs/qualification.md` already draws.

**A run has three outcomes and they are three, not two.** `success` is evidence.
`failure` is evidence of a defect. `cancelled` is **neither** -- the workflows use
`cancel-in-progress`, so pushing again kills the run in flight, and a run that was
killed proves nothing in either direction. Cite a run by id and conclusion, never
by "the last run"; `gh run list` prints all three fields.

The `Native` job is **pinned to CNA commit `5c8840657`** -- ABI 0.23.0, the newest
commit on `origin/next`, and the exact commit 0.23.0 was qualified against. Two
earlier reasons for pinning are both gone: the sharp-runtime blocker closed on
2026-09-05, and the "the tip's ABI is not admitted" reason closed when 0.23.0 was
admitted. What is left is that evidence has to be reproducible -- `next` moved
from 0.22.0 to 0.23.0 in a day and moved fifteen more commits while 0.23.0 was
being qualified, so a job following the tip qualifies whatever the tip was that
hour.

**Both halves of the pair are pinned, and the second half was caught the hard
way.** `SHARP_RUNTIME_REF` followed the `next` branch until the first run after
0.23.0 was admitted -- run `34041187578`, which resolved it to `30ccdef3`, one
commit past the `bfc826e1` every document names, pushed while the qualification
was running. It passed, so nothing broke but the claim. CNA pins no sharp-runtime
revision, so that half is the one most likely to move with nobody deciding to;
it is an exact commit now.

**One admitted ABI per push, the others on dispatch**, and that was measured
rather than assumed: a `Native` run is three to five minutes with a warm ccache
and its cache key is the resolved CNA commit, so a second ABI on every push is a
second cold CNA build. `cna_ref: fb62662c9...` requalifies 0.22.0,
`cna_ref: 056e57d47...` requalifies 0.21.0, and `cna_ref: next` measures the next
bump before admitting it. The release standard is unchanged: the full gate set
must have run against an exact ABI before this binding is called compatible with
it. Every run records the CNA and sharp-runtime commits it landed on, in the step
summary and in `qualification-run.json` inside the run's artifact.
`docs/qualification.md` has the policy and the evidence for all three.

## Whether to keep 0.21.0 admitted, now that there are three

Admitting 0.23.0 makes 0.21.0 look expensive: it is the only admitted ABI on
which a whole projected family has no public producer, and dropping it would turn
`Load<Model>` from "refuses on one third of the matrix" into "works everywhere".
That is exactly why it must be an argued decision and not a side effect, and
**the decision here is to keep it**.

| | Compatibility benefit | User cost | Test and maintenance burden | Effect on Model completeness | Versioning implication |
| --- | --- | --- | --- | --- | --- |
| **A. Keep 0.21.0 admitted** | a program built against a 0.21.0 CNA keeps working; the binding stays usable on the oldest CNA anyone has | `Load<Model>` refuses there, and the three Model members stay partial for everyone | the `model` pixel proof must stay capability-gated, and the refusal branch stays asserted | 45 of 48 complete, 3 partial | none |
| **B. Deprecate 0.21.0, drop it later** | the same as A today | the same as A today, plus a warning to act on | the same as A, plus a deprecation mechanism the binding does not have | the same as A | needs a deprecation policy first, and there is none |
| **C. Drop 0.21.0 now** | none -- it removes compatibility rather than adding it | a working configuration stops being admitted, with no release to blame it on | smaller: the refusal branch and the capability gate could both go | the three Model members could be re-argued as complete | a **breaking** change to what the binding claims to support |

**A, and not because C is wrong in principle.** C buys a tidier scoreboard and
nothing else, and it buys it by removing support from users who have it. There is
no project policy authorising a drop, and "the newest ABI fixes it" is not one:
0.23.0 has been admitted for a day and 0.21.0 has been the qualified baseline for
weeks.

**The scoreboard is not the argument it looks like.** The three Model members
would not become complete under C anyway -- `ModelMeshPart.Effect`, `Model.Draw`
and `ModelMesh.Draw` are partial because a content-published effect cannot answer
for its graph, and that defect is present in **0.22.0 and 0.23.0 too**. Dropping
0.21.0 would remove a refusal, not a partial.

If a drop is ever wanted, the thing to write first is the deprecation policy --
what warns, when, and against what release -- not the drop.

## Nine milestone statuses, and they are nine

**One boolean must not cover several milestones**, which is why these are stated
separately and each names what it rests on. The heading said *four* while the
table held five and two more closures had landed without a row at all -- the
staleness this file exists to prevent, found in the file's own scoreboard. The
three that were missing are below.

| | |
| --- | --- |
| `FOUNDATION_1_IMPLEMENTATION_FROZEN` | **yes**. Its 35 missing and 19 partial members are unchanged, and every closure since has added types rather than reopening it. What later work has touched is shared *machinery*, additively, and each such change is named where it landed |
| `FOUNDATION_1_RELEASE_READY` | **yes**, decided at `5a7f7c1` and re-affirmed at each audit against the eight conditions below |
| `AUDIO_FOUNDATION_READY` | **yes**. Six complete types and three partial over nine types and 67 members, each partial with a measured reason; two lanes, neither claiming a sound was heard |
| `DYNAMIC_AUDIO_READY` | **yes**. `BufferNeeded` is complete for real now: its `+=` and `-=` match the IL before *and* after disposal, and a handler's condition is delivered rather than lost. Both were overclaimed until the pre-Model audit and both are fixed |
| `MODEL_READY` | **on 0.22.0 and 0.23.0**, and that is a measurement rather than a hedge: on 0.21.0 `Load<Model>` refuses because a loaded model cannot be released there, so the family has no public producer on that ABI. 0.23.0 was measured, not assumed -- it fixes the destroy defect that 0.22.0 already fixed, and fixes neither the effect-graph one |
| `MICROPHONE_READY` | **yes on all three ABIs**, with one measured partial: `BufferDuration` refuses exactly 1000 ms on 0.21.0, which is the top of XNA's range, and both branches assert. Three environments qualified rather than two, because a capture device that enumerates is not one that delivers |
| `MEDIA_PLAYBACK_READY` | **yes on all three ABIs**. Six complete types over the *playback* half of the namespace |
| `MEDIA_LIBRARY_READY` | **yes on all three ABIs**, since 2026-09-08. Fifteen types over the *library* half, qualified against a generated XDG fixture with exact counts rather than a non-zero assertion. `Video`/`VideoPlayer` remain outside the closure and are measured as absent, not faked |
| `STORAGE_READY` | **yes on all three ABIs**, and it is the first closure to finish its whole namespace: three types, three complete, nothing left in `Microsoft.Xna.Framework.Storage` to be absent. The one place it is narrower than XNA is a lifetime rather than a member -- XNA lets a container be disposed with a stream still open and CNA does not |
| `SERVICES_AND_DEVICE_SELECTION_READY` | **yes on all three ABIs**, with one honest partial that is three members. Five types, 21 members, all five complete; thirteen members of already-selected types closed, of which ten are complete and three -- `FindBestDevice`, `RankDevices`, `CanResetDevice` -- are **partial**, because no admitted CNA ABI calls them during device creation and the suite asserts that limit directly. `GraphicsDeviceManager` is therefore still a partial type, and that is the truthful outcome rather than a shortfall. The first closure whose evidence is entirely lifecycle and configuration: it needs no display, no GPU, no audio device, no capture device and no content fixture |

**The template is deliberately unchanged, and the Model closure strengthens that
decision rather than weakening it.** The canary's whole value is that it produces
the same counts and the same pixels on every admitted ABI; a model in it would
load on 0.22.0 and refuse on 0.21.0, so it would either fail half the matrix or
have to branch — and a canary that branches is a canary that has stopped being
one. The library's own isolated Model evidence is stronger than a template demo
would be, and it is where a reader should look.

## Foundation 1 is release-ready, and frozen

**`FOUNDATION_1_RELEASE_READY = yes`**, decided at `5a7f7c1` and unchanged since.

**Read this section's numbers as Foundation 1's, and the generated scoreboard
below as the whole binding's.** They were the same figure when this was written
and they are not any more: Audio landed after the freeze, in two closures, and
added nine types and 67 members to the selection. Foundation 1 at its release
commit was

    157 selected types, 2332 selected members
    141 complete types, 16 partial, 0 missing
    1854 complete members, 19 partial, 35 missing, 424 not applicable
    0 disagreement diagnostics

and the generated blocks further down are that plus Audio.

**Audio contributed three of the frontier's members, and this paragraph used to
say it contributed none.** That was written when Audio was believed 8/8 complete
and was already false when the re-audit corrected two of its members; the
streaming closure added a third. The three that are not Foundation 1's are
`SoundEffect.Duration`, `SoundEffectInstance.Apply3D(AudioListener[],
AudioEmitter)` and `DynamicSoundEffectInstance.new(Int32, AudioChannels)`.

**Foundation 1's own members changed classification on 2026-09-07, and no
Foundation 1 member changed behaviour.** The completeness rule in
`docs/compatibility.md` was made explicit for the first time, and applying it
uniformly moved `BasicEffect.World`, `.View` and `.Projection` from `complete` to
`partial`: they need the optional private shim, exactly as
`GraphicsDevice.Viewport` does, and were labelled differently from it on an
identical blocker. `BasicEffect` is a Foundation 1 type, so **Foundation 1's own
frontier is 22 partial where it was 19**, and its missing count is still 35.

Those are two different facts and the freeze rests on the second:

| | At the release commit `5a7f7c1` | Now |
| --- | --- | --- |
| Foundation 1 partial | 19 | **22** |
| Foundation 1 missing | 35 | 35 |
| What changed in the code | — | nothing: no member gained or lost a capability |

The release commit's measured numbers stay as they were measured; they are not
rewritten as though the rule had always been written down. What moved is the
classification, and the row for it below says so.

The decision was about the *foundation as a coherent milestone*, not about the
scoreboard reaching zero. It never will. The whole-binding frontier is **53
members** and splits like this -- regenerate it from
`tools/api-compat/mapping-rules.json` rather than reading it here, because it has
now been stale twice:

| Category | Members |
| --- | ---: |
| `CNA_ADMITTED_ABI_LIMIT` | 40 |
| `DEPENDENCY_NOT_SELECTED` | 4 |
| `PACKAGING_ABI_BRIDGE_LIMIT` | 4 |
| `LANGUAGE_PROJECTION_LIMIT` | 3 |
| `QUALIFICATION_LIMIT` | 2 |
| `PUBLIC_OBJECT_MODEL_CLOSURE` | 0 |
| `IMPLEMENTABLE_AND_HIGH_VALUE` | 0 |
| `IMPLEMENTABLE_BUT_LOW_VALUE` | 0 |

The eight conditions, and what each rests on:

| Condition | Evidence |
| --- | --- |
| All gates green | the gates in "Reproduce the state" and the table above, re-run at each audit; the suite reports no failure and nothing not run in all three native configurations, and in the fourth it reports the native layer as not run rather than as passed |
| The freeze holds | **Re-run on 2026-09-07 and it does, for a reason it did not need before.** Audio landed after the freeze, twice, and changed no Foundation 1 member. What did change three of them is a *classification* correction: `BasicEffect.World`, `.View` and `.Projection` moved `complete` -> `partial` when the completeness rule was written down and applied uniformly, so Foundation 1 is 22 partial where it was 19, and 35 missing as before. **No code changed and nothing that worked stopped working** -- the qualified configuration still exercises all four shim setters -- so this is the scoreboard becoming truthful about an installation that was always the ordinary one, not the foundation reopening. Still 0 missing types, still 0 disagreements |
| No known ownership or lifetime defect | ownership stress, construction atomicity over twelve resource families, content transaction rollback at four injection points, callback registry empty after each cycle |
| Zero structural disagreements | `verify.py --strict`, over <!-- generated:diagnostic categories=18 --> diagnostic categories |
| No stale live-state documentation | three audits now. The third ran with the streaming closure and found four survivals the first two missed: `LOAD-ASSET` still promising two objects for one name, `UNLOAD` still telling a program to dispose what the manager now disposes, `docs/ownership-and-lifetimes.md` still describing the pre-cache content model, and this section's own claim that Audio contributed no frontier members. The first two are **public generated documentation** -- they are dumped into `docs/generated/public-surface.json` -- which is what makes them a release-condition failure rather than a comment |
| Admitted ABI set truthful | `{0.21.0, 0.22.0, 0.23.0}`, and all three are evidenced: the whole gate set is run against a real library of each at every closure, not once. 0.23.0 was admitted on 2026-09-06 against an exact published pair, after its ABI delta was diffed, its generated layer proved unchanged, and both gates were watched refusing it first |
| CI green | both workflows `success`, and named by run id below rather than by "the latest run" |
| Qualification wording no stronger than its evidence | the SOFTWARE lane's claims are rendered from the registry the lane enforces, and every required proof must also be *described* |
| Every non-complete member has a concrete reason | 53 of 53, each naming a route or an IL fact, each in one of **eight** categories -- `PACKAGING_ABI_BRIDGE_LIMIT` was added on 2026-09-07 for the four shim-dependent setters, because what must change to close them is a packaging decision and `LANGUAGE_PROJECTION_LIMIT` would have told a contributor the false thing that Common Lisp cannot express a Matrix. `verify.py` refuses an uncategorised one and refuses a category the taxonomy does not define, which is what carried the `CNA_0_21_ABI_LIMIT` rename. **This row used to add "with zero in either implementable category", and that half is no longer true**: the 2026-09-07 audit moved two members into `IMPLEMENTABLE_AND_HIGH_VALUE`. It was true at the release commit named below, and the condition it states is about *reasons being concrete*, which is unchanged -- but the parenthesis was a second claim riding on the first and it has now moved, so it is stated separately below rather than left here to age |

That last row is the one to re-read before believing this.
<!-- generated:high-value frontier members=0 --> members are
`IMPLEMENTABLE_AND_HIGH_VALUE`, and that is a *measurement*:
`docs/compatibility.md` renders the count and `verify.py` refuses a frontier
member that has no category. **That count was zero when Foundation 1 was
released and is two now**, because the 2026-09-07 partial-frontier audit found
`RenderTargetBinding.CubeMapFace` and `Game.Content` kept partial by reasons that
did not survive re-reading. Neither was implemented; both are still partial. The
sentence that used to stand here -- "nothing in the selected profile is both
unblocked and worth doing" -- was true of the evidence available then and is not
true now, and saying so is the point of measuring again.

**The release evidence, named exactly.** Foundation 1's release decision rests on
these runs, at the commit where the documentation-truth condition first became
true:

| Workflow | Run | Commit | Conclusion |
| --- | --- | --- | --- |
| `Lisp` | [33968261788](https://github.com/libcna/cna-common-lisp/actions/runs/33968261788) | `5a7f7c1` | **success** |
| `Native` | [33968261886](https://github.com/libcna/cna-common-lisp/actions/runs/33968261886) | `5a7f7c1` | **success** |

A run at an earlier commit is not release evidence for this one, and a `cancelled`
run is not evidence at all -- run `33966149186`, the `Native` run for `efae9c9`,
was cancelled by the push that followed it seconds later and must not be cited as
green.

**Foundation 1 is frozen.** Its 35 missing members are not work in progress; the
owned `GraphicsDevice`, an `IntPtr` projection and `Game`'s two protected
`On<Event>` raisers each have a measured reason in
`tools/api-compat/mapping-rules.json`, and reducing the missing count for its own
sake is explicitly not the next task. A selected, qualified subset is what this
milestone is.

**Two of the items that list used to name have since landed, additively, and the
distinction matters.** `GameServiceContainer` and `GraphicsDeviceManager`'s
protected raisers were named here as frozen absences. Neither was reopened as
Foundation 1 work: the container arrived as a *new selected type* in a later
closure, and the raisers became reachable when that closure gave the event
machinery a seam it had not had. Foundation 1's own frozen list is what is above,
and it is shorter than it was because the profile grew around it rather than
because the freeze was lifted.

**No tag was created.** This repository has no tags and no documented
version/tagging policy, and inventing one at a release audit would be the wrong
place for that decision. The proposed version is the one
`cna-common-lisp.asd` already carries -- **0.1.0** -- which is honest for a first
qualified foundation that projects a selected subset and says so. The choice is
the project's.

**`FOUNDATION_1_RELEASE_READY` is still `yes`, and the third audit is why it is
still a claim rather than a habit.** The condition is truthful live documentation,
not documentation that was truthful once; two public docstrings contradicting
their own implementations would have failed it, and they were found and corrected
before this was re-stated. **Foundation 1's implementation was not reopened**:
the only Foundation 1 material touched was that stale documentation, plus one
additive fix to shared construction machinery -- a subscription made during a
failed construction is now given back -- which closes a hole that no Foundation 1
type had ever been shown to fall into and any of them could have.

### What the three documentation audits found

The generated machinery had become much stronger than the hand-written prose, and
the gap is where every finding was, both times.

The **first** audit found `*DECLARED-ABSENCES*` stale in seven of eight entries,
five landed closures still listed as absent in `docs/limitations.md`, a README
claiming four pixel paths where the registry has eight and three loadable asset
types where the loader table answers four, a proof table missing a row its count
had already been moved for, `plan.md`'s chronological list reading as live status,
and a template README four fields behind its own program. It added three gates,
each verified by breaking it.

The **second** audit was run because the release statement's own "no stale
live-state documentation" condition was not yet true: this file still described a
frontier two closures old, and `docs/limitations.md` carried eight claims that the
generated report contradicts. Both are fixed, and the shape of the mistake is
worth keeping:

* **a landed closure leaves its "what to do next" entry behind.** The
  device-settings closure landed whole and its future-work paragraph stayed, still
  naming `Adapter`, `Reset` and `Present` as the work to do.
* **a corrected claim gets corrected in one place.** `DeviceWindowHandle`'s route
  name was fixed in an audit table and left wrong in the paragraph that states it;
  `Texture2D`'s extent was documented twice, once as a refusal and once as a zero,
  which is the answer the code was changed away from.
* **a forward reference outlives the thing it points at.** Two paragraphs said
  `GameServiceContainer` "arrives with the device-settings closure". It did not,
  and that closure is over. (It has arrived since, in a closure of its own, and
  this entry stays as the record of what the audit found rather than as current
  status -- which is the same distinction the entry itself is about.)

The **third** audit ran with the streaming closure and found a fourth shape, the
worst of the four because the reader has no way to notice it:

* **a docstring outlives the implementation it documents, and is published.**
  `LOAD-ASSET` still said "Loading the same name twice answers two distinct
  objects here" after the manager grew XNA's cache, and `UNLOAD` still said "This
  does not destroy objects already handed out. Dispose them yourself" after it
  began disposing them. Both are dumped into
  `docs/generated/public-surface.json`, so they were published API documentation
  telling a program to do the opposite of the right thing.
  `docs/ownership-and-lifetimes.md` carried the same model one level up, and this
  file's own Foundation 1 section claimed Audio had contributed no frontier
  member when it had contributed two.

The remedy is structural rather than a checker: a closure's landing commit deletes
the prose that described it as future, this file carries **one** generation of
next-work, and `docs/limitations.md` marks a retained historical finding as
historical in its own heading. To that the third audit adds one rule: **a closure
that changes what a member does re-reads that member's docstring in the same
commit**, because the generated public surface is where a stale one ends up.
`verify.py` and `verify-numbers.py` already refuse every *number* that drifts;
what neither can check is a paragraph, so the paragraph count is kept low on
purpose.

### The extraordinary claims, re-read

Six claims that a reader might reasonably disbelieve were re-opened against the
hash-checked assemblies rather than against the comments asserting them, and
**all six stand**. The half-precision format is the one that needed it most and
`tools/api-compat/reference/XNA_IL_PROVENANCE.md` now carries its IL: `Pack`
saturates everything above `wMaxNormal` as an unsigned comparison, so both
infinities and every NaN go, and `Unpack` has no case for exponent 31, so
`0x7FFF` reads back as 131008.0. No implementation changed.

## The measured frontier

<!-- generated:selected types=211 -->
<!-- generated:selected members=2734 -->
<!-- generated:complete types=189 -->
<!-- generated:partial types=22 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=2190 -->
<!-- generated:partial members=36 -->
<!-- generated:missing members=19 -->
<!-- generated:not-applicable members=489 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 211 types, 2734 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **189** |
| Types partial | **22** |
| Types missing | **0** |
| Members complete | **2190** |
| Members partial | **36** |
| Members missing | **19** |
| Members not applicable | **489** |
| **Disagreement diagnostics** | **0** |
<!-- /generated-block:scoreboard -->

`docs/compatibility.md` has the per-type table.

**Every pure-managed type in the selection is complete.** The math types
-- `Vector2`, `Vector3`, `Vector4`, `Quaternion`, `Matrix`, `Plane`, `Ray`,
`BoundingBox`, `BoundingSphere`, `BoundingFrustum`, `MathHelper`, `Color`,
`Point`, `Rectangle` -- the `Curve` family, the seventeen packed vector types and
every enumeration answer every member of the selected contract, and **so does
the whole of `Microsoft.Xna.Framework.Input`** -- the keyboard, the mouse, the
`GamePad` family and the touch panel. So do the four **graphics state objects**
and the nine enumerations they are built from.

**No selected type is missing**, and that is a property the release statement
uses: a selected type with nothing behind it would be one. Every remaining absence
is a member of a type that is otherwise there, and this is where they are:

<!-- generated-block:partial-frontier -->
| Type | missing members | partial members |
| --- | ---: | ---: |
| `M.X.F.GameWindow` | 7 | 0 |
| `M.X.F.Game` | 3 | 0 |
| `M.X.F.Graphics.GraphicsDevice` | 3 | 1 |
| `M.X.F.GameComponentCollection` | 1 | 0 |
| `M.X.F.Graphics.PresentationParameters` | 1 | 0 |
| `M.X.F.Graphics.GraphicsAdapter` | 1 | 4 |
| `M.X.F.Graphics.Effect` | 1 | 0 |
| `M.X.F.Graphics.DirectionalLight` | 1 | 0 |
| `M.X.F.Graphics.BasicEffect` | 1 | 3 |
| `M.X.F.TitleContainer` | 0 | 1 |
| `M.X.F.GraphicsDeviceManager` | 0 | 3 |
| `M.X.F.Content.ContentManager` | 0 | 1 |
| `M.X.F.Graphics.Texture2D` | 0 | 4 |
| `M.X.F.Graphics.TextureCube` | 0 | 6 |
| `M.X.F.Graphics.Texture3D` | 0 | 6 |
| `M.X.F.Audio.SoundEffect` | 0 | 1 |
| `M.X.F.Audio.SoundEffectInstance` | 0 | 1 |
| `M.X.F.Audio.DynamicSoundEffectInstance` | 0 | 1 |
| `M.X.F.Audio.Microphone` | 0 | 1 |
| `M.X.F.Graphics.Model` | 0 | 1 |
| `M.X.F.Graphics.ModelMesh` | 0 | 1 |
| `M.X.F.Graphics.ModelMeshPart` | 0 | 1 |
<!-- /generated-block:partial-frontier -->

That table is the authority on where the frontier is. **Do not restate it in
prose** -- a per-type sentence beside it is exactly what went stale twice, once
describing "graphics state objects, `Stream` and `SpriteFont`" and once
`Texture2D`'s twelve members and `Game`'s eight, both long after those numbers
had moved. Regenerate the table after every closure and read it there.

### Why each absence is an absence

<!-- generated-block:frontier-categories -->
| Category | Members | What it means |
| --- | ---: | --- |
| `LANGUAGE_PROJECTION_LIMIT` | **3** | The Common Lisp projection cannot express the member, or the type it needs has no counterpart a Lisp program could use safely. |
| `PACKAGING_ABI_BRIDGE_LIMIT` | **4** | The projection and every admitted CNA route exist and work, and the member is reachable only in an installation that has built an optional compiled artifact. |
| `CNA_ADMITTED_ABI_LIMIT` | **46** | No admitted CNA ABI can represent the member. |
| `PUBLIC_OBJECT_MODEL_CLOSURE` | **0** | Implementable against every admitted CNA ABI, but only as a new closure in this binding's object model rather than as a member. |
| `DEPENDENCY_NOT_SELECTED` | **0** | Blocked on a type that is not in the selected profile. |
| `QUALIFICATION_LIMIT` | **2** | Implemented, but some part of it cannot be evidenced, so it is not claimed complete. |
| `IMPLEMENTABLE_BUT_LOW_VALUE` | **0** | Nothing blocks it and it is not worth the surface. |
| `IMPLEMENTABLE_AND_HIGH_VALUE` | **0** | Nothing blocks it and it should be done next. |
<!-- /generated-block:frontier-categories -->

This table replaces a boolean called `GLOBAL_ACTIONABLE_LOCAL`, which was retired
because it was made to carry two different facts and got one of them wrong. The
two facts are:

* **`SELECTED_PROFILE_IMPLEMENTABLE_NOW` was 0 at the release commit and is 2
  now.** It was the release condition, and it was honestly met on the evidence
  then available; the 2026-09-07 audit re-read every partial reason from zero and
  two did not survive. One of the two, `RenderTargetBinding.CubeMapFace`, has
  since been implemented, and so has the other, `Game.Content`. Both are complete
  and the category is empty again. The generated block above is the authority for
  the number -- **do not restate it in prose here**, which is the mistake the two
  paragraphs below this list record.
* **Local work remains, and it is profile expansion.** Growing the selection into
  Audio is entirely this repository's work and needs nothing from anybody. So
  "there is no more local work" would be false.

What the retired boolean actually claimed -- **"there is nothing externally
blocked at all"** -- was false when it was written, and the generated table above
says by how much: the members in `CNA_ADMITTED_ABI_LIMIT` need a CNA release
rather than a commit here, and the ones in `DEPENDENCY_NOT_SELECTED` need a
profile decision rather than an implementation. **The counts are deliberately not
repeated in this paragraph.** They were, as "thirty-nine" and "six", and both had
drifted from the block a few lines above them -- the exact failure the section on
the frontier table warns about, two headings earlier, in this same file. Say
which category, not which boolean, and never which number.

The one thing the retired section got right is worth keeping.
`GraphicsDevice.Viewport`'s setter was once recorded as an external blocker on the
grounds that CFFI cannot pass a 24-byte aggregate by value. That was a true fact
and a wrong conclusion: a tiny private shim for a *proved* ABI impedance mismatch
is the permitted remedy, the generator emits one, and the setter works through it.
The shim stays optional -- a release must load with no C toolchain -- so without
`CNA_LISP_SHIM` the setter refuses with a condition naming the variable, the
command that builds one, and the reason. That is a packaging limit, not a blocker.

## Audio has landed in two closures, and it is not all complete

**Read this before the table.** The first Audio milestone reported eight types and
57 members with every one complete. A re-audit against the pinned assembly found
that several of those claims were the implementation's rather than XNA's; the
streaming closure that followed added a ninth type and ten members and one more
honest partial. Audio is now **six complete types and three partial**: 58 complete
members, 3 partial, 6 not applicable, over nine types and 67 members. Nothing was
ever removed -- each correction described a member accurately instead of
generously. Those figures are the generated report's; reproduce them from
`docs/generated/api-compat-report.json` rather than trusting this paragraph:

| Member | Why partial |
| --- | --- |
| `SoundEffect.Duration` | CNA's per-effect duration route does not quantise to whole milliseconds and XNA always does. Computed exactly where the format is known -- both constructors and `FromStream` -- and taken from the route for a `ContentManager`-loaded effect, where neither admitted ABI reports a format to compute from |
| `SoundEffectInstance.Apply3D(AudioListener[], AudioEmitter)` | CNA's own header: several listeners are combined by taking the **nearest**, where XACT computes a per-listener output matrix. A different function of the array, not an approximation of one. The single-listener overload is complete on its own evidence |
| `DynamicSoundEffectInstance.new(Int32, AudioChannels)` | CNA's streaming create route succeeds with no playback device where `SoundEffect`'s refuses, and **XNA's answer is not establishable**: the constructor reaches native code the disassembly does not contain. Adopting CNA's success is a binding-defined outcome standing in for an unknown one |

**A third correction landed with the streaming closure and is not in that table,
because it made two members honest rather than partial.** `SoundEffectInstance`'s
`Volume`, `Pitch`, `Pan` and `IsLooped` were read through
`cna_sound_effect_instance_get_info`, so all four refused after disposal where
XNA's seven-byte `ldfld` getters answer -- and the test that exercised them called
that a divergence in its own comment while the report went on calling the members
complete. They are managed slots now, written after the native setter succeeds
exactly where XNA's `stfld` is, and complete for real. The same change stopped
`Apply3D` leaking CNA's computed spatial pan through a property XNA defines as the
caller's last assignment.

Six other corrections landed with them and changed behaviour rather than wording:
the two constructors and both `Play` overloads now have exactly XNA's shapes,
`Play` validates all three of its settings from the setter IL rather than one of
them, `TimeSpan.FromMilliseconds` is reproduced as the millisecond rounding it is,
`GetSampleSizeInBytes` has the upper bound and the overflow rethrow it documented
and lacked, `FromStream` reads the wave shape XNA reads rather than whatever CNA
can decode, and `SoundEffect.Dispose` cascades to its live instances because the
pinned `Dispose(bool)` does. `docs/limitations.md` has all of them.

**Foundation 1 was not reopened**, and its release decision stands on the
qualification recorded above; three of those corrections did reach shared
machinery -- the overload-shape helper, the disposal seam and the condition
`CAUSE` slot -- and each is additive. What changed for a Foundation 1 *caller* is
four keyword shapes that were accepted and are not XNA's: `:OFFSET-IN-BYTES`
without a window, `GetBackBufferData`'s `:SOURCE` without one, and the two
user-primitive draws' vertex and index offsets, which every XNA overload takes and
none defaults.

This section is what a future reader needs to know about Audio that the scoreboard
does not say.

| Type | Members | Notes |
| --- | ---: | --- |
| `SoundEffect` | 17 | two constructors, `FromStream`, `CreateInstance`, two `Play` overloads, four process-wide statics, two static sample computations. **Partial**: `Duration` |
| `SoundEffectInstance` | 16 | the transport, four bounded properties, both `Apply3D` overloads. **Not sealed in XNA** -- `DynamicSoundEffectInstance` derives from it -- and not sealed here. **Partial**: the array `Apply3D` |
| `DynamicSoundEffectInstance` | 10 | the streaming subclass: one constructor, two `SubmitBuffer` overloads, two instance sample computations, `PendingBufferCount`, an overridden `IsLooped` and `Play`, and the `BufferNeeded` event. **Partial**: the constructor, which CNA lets succeed with no playback device |
| `AudioListener` | 5 | a plain managed object; no handle |
| `AudioEmitter` | 6 | the same, plus `DopplerScale` |
| `SoundState` | 4 | `Playing` 0, `Paused` 1, `Stopped` 2 |
| `AudioChannels` | 3 | `Mono` 1, `Stereo` 2 -- the member *is* the channel count, which is what makes the sample arithmetic arithmetic |
| `NoAudioHardwareException` | 3 | a condition subclassing `CNA-NOT-SUPPORTED-ERROR` |
| `InstancePlayLimitException` | 3 | a condition subclassing `CNA-INVALID-STATE-ERROR` |

**The two exceptions are conditions, not invented objects**, and each subclasses
the exact CNA result-code condition that produces it. So a program can handle the
XNA-specific class or the CNA one and both work, and a generic native failure is
still neither -- which is the distinction the qualification has to prove and does.

**`AudioListener` and `AudioEmitter` hold no handle.** CNA's own header calls them
"a fixed value here rather than a handle", so the C struct is built at the
`Apply3D` boundary and thrown away. XNA's private handedness flip -- it negates Z
on the way in and again on the way out -- is deliberately **not** reproduced: it
is its own inverse and no program can observe it. Reproducing it would match XNA's
storage and break XNA's public behaviour.

**The ownership graph is `Game -> SoundEffect -> SoundEffectInstance`**, which is
what CNA documents, enforced before the ABI sees a wrong order -- **and
`Game -> DynamicSoundEffectInstance` with nothing between**, which is what
`cna_dynamic_sound_effect_instance_create` documents: it takes a game handle and
"unlike an instance created from a sound effect, it has no parent effect -- the
caller is the source". XNA agrees: its `SoundEffectInstance.effect` field is null
for that subclass and its `Dispose(bool)` reads the field and skips
`ChildDestroyed`. The two kinds are one CLOS class hierarchy over two ownership
shapes, which is why construction and destruction are polymorphic hooks on the
base rather than one method that knows about both -- except that
`SoundEffect.Dispose` **cascades to its instances**, because the pinned
`Dispose(bool)` does, and `ContentManager.Unload` inherits that by calling the
same `DISPOSE`. The game does not cascade, so the two directions of the graph are
deliberately not the same. Four failure
states are pinned by `tests/native/audio.lisp` -- a subclass initializer signalling
after each of the two handles exists, a load whose cache insertion fails, and a
load whose duration read fails -- and each must give every handle back exactly
once, restore the child count and the cache, and leave the game able to shut down.

**`ContentManager.Load<SoundEffect>` uses the managed cache**, because CNA's route
"deliberately does not cache" and XNA's `Load<T>` does. Two loads of one name
answer one object. The fixture is a generated WAV; no recording is stored here.

### The streaming half, and what its qualification does and does not say

`DynamicSoundEffectInstance` is the one member of this namespace that adds a
**capability** rather than a surface: procedurally generated audio is reachable
through nothing else here.

**It does not construct itself the way its base class does, and that is XNA's
shape rather than this projection's.** `SoundEffectInstance` has two constructors
in the pinned assembly -- an assembly-visible `(SoundEffect, bool)` that stores
the parent and calls `AllocateVoice()`, and a **parameterless** one that stores
nothing and calls nothing -- and the streaming subclass calls the second, then
validates its two arguments, then calls the same virtual `AllocateVoice()`, which
it overrides. So the base class's construction is already polymorphic in the
original, and it is polymorphic here: `%INITIALIZE-NATIVE-SOUND-INSTANCE` and
three sibling hooks, dispatched on the actual class, rather than a `TYPEP` ladder
in the ordinary constructor.

**The transport, the four settings and `Apply3D` are inherited on evidence.**
`cna_dynamic_sound_effect_instance_create` says its handle "is a **sound-effect
instance**: every `cna_sound_effect_instance_*` route accepts it, including the
transport, the mixing setters and `cna_sound_effect_instance_destroy`", and that
sentence is byte for byte the same in all three admitted ABIs -- the whole of
`audio.h` is. There is no dynamic *destroy* route in any of them, and that is not
an omission. What XNA overrides is exactly two members and both are projected as
overrides: `IsLooped`, whose getter tests `IsDisposed` where the base class's
bare `ldfld` does not and then answers a constant false, and whose setter refuses
a true assignment and stores nothing either way; and `Play`, whose override is
what this binding's base method already did.

**What the streaming lane proves.** Generated PCM16 is submitted, the
pending-buffer count rises to two, and the native streaming state machine consumes
both while the game loop runs -- CNA's route documents that the count "only
shrinks once a buffer has actually been **consumed by playback**, not merely
handed to the mixer", which is what makes the fall evidence about the runtime
rather than about this binding. The queue is advanced by
`cna_framework_dispatcher_update`, so the test runs frames and polls with a bound
rather than asserting a frame count. **A consumed buffer is not a buffer anyone
heard**: `dummy device != speaker`, and the strongest claim here is that the bytes
were accepted and consumed.

**The constructor is partial, and it is the one place XNA cannot be consulted.**
`cna_dynamic_sound_effect_instance_create` succeeds on a machine with no playback
device and the handle it answers takes buffers; the refusal arrives at `Play`.
`SoundEffect`'s constructor refuses in the same situation, so the two constructors
of this namespace disagree about hardware and the difference is CNA's. XNA's own
answer is **not establishable**: its constructor reaches
`CreateDynamicSoundEffectInstance`, whose body is native code in the mixed-mode
assembly rather than IL. The IL does establish the *shape* -- XACT result
`0x8ac70017` becomes `NoAudioHardwareException` -- so a failure would surface as
that and not as something else. Adopting CNA's success is a binding-defined
outcome standing in for an unknown one, which is what partial means here and what
the array `Apply3D` already means. Inventing a capability probe would be worse:
it would reproduce a behaviour nothing in the pinned assembly says XNA has.

**One defect in shared machinery was found by this closure's own atomicity test**
and is worth recording, because it was never about audio. A construction that
subscribed to an event and *then* failed left CNA holding the registration and
the private registry holding the token that roots the object -- for **any**
event-raising class, since every one of them is subclassable. `%SUBSCRIBE-EVENT`
now records a construction undo while the object is still constructing, and
`NATIVE-OBJECT` carries the flag that says whether it is.

**Audio is not in the template, and that is deliberate.** The template is a
deterministic graphics and content canary whose value is that it produces the same
60/60 and 600/600 counts and the same pixels every run. Making its ordinary
execution depend on an audio backend would make it fail on a machine with no sound
card, which is most CI. A public-only audio consumer script is the right shape for
that if it is ever wanted; a "hello game" beep to show Audio exists is not.

### What Audio does not claim

No test here says a sound was heard. `tools/qualification/audio.sh` produces the
unavailable branch from a driver that does not exist and the state machine from
SDL's `dummy` driver, in separate processes because SDL's driver selection is
process-global and latches at initialisation. **A dummy audio device is not
audible hardware.** A state transition, a duration and a native acceptance are
what this proves.

## The Model family has landed, and one admitted ABI cannot produce a model

Twelve types, forty-eight members, **45 complete and 3 partial**, and the closure
adds no type: every XNA type the family reaches was already selected and
everything else it reaches is the base-class library's. The recommendation this
section used to carry has been carried out and is deleted rather than left to
age; what remains is what a future reader needs that the scoreboard does not say.

**Two CNA defects were measured while building it, and they are the whole of the
three partials.** Neither is a limit of the projection. `docs/limitations.md` has
the reasoning; these are the facts:

| | 0.21.0 | 0.22.0 |
| --- | --- | --- |
| `cna_model_destroy` on a **loaded** model | **null dereference at 0x490** | works |
| `cna_effect_get_techniques` on a loaded model's effect handle | **null dereference at 0x20** | **null dereference at 0x20** |

The first is the larger. **On CNA 0.21.0 a model obtained from
`ContentManager.Load<Model>` can never be released** — and taking a mesh view
first only defers the fault to `cna_game_destroy`. There is no sound fallback,
because leaking the handle gives a game that cannot shut down instead of a crash.
So `Load<Model>` refuses on 0.21.0, before anything is created, and names the
defect. XNA has no public `Model` constructor either, so the consequence is
exact: **on 0.21.0 the Model family has no public producer at all.** The suite
asserts that refusal on that ABI rather than skipping it.

The second is on both, and it is narrower: 22 of `effects.h`'s 322 routes read
the `adapterState` CNA's model loader never fills in, and the other 300 answer
normally on the same handle. So the effect object a loaded model hands back is
real and refuses exactly four members — and **assigning your own effect to the
part repairs it completely**, which is an ordinary XNA idiom and is what the
pixel proof does before it draws.

**A binding may hand a program a refusal. It may not hand it a call that kills
the process.** That is the rule both decisions come from.

### What the Model qualification proves, and what it does not

* **Structural**: 178 types and 2447 members measured, 0 disagreement
  diagnostics, all four nested enumerators projected.
* **XNA behaviour**: the identity map (`Bones[0]` twice is one object,
  `child.Parent` is the parent *object*), the three transform copies with the
  IL's validation order, and `absolute[i] = local[i] * absolute[parent]` — proved
  with a fixture whose child carries a **scale**, so the reverse order gives a
  different number.
* **Native**: buffers and effects resolved to one object per handle, model-owned
  wrappers that refuse disposal, and stale views that refuse after `Unload`.
* **Content**: `Load<Model>` twice answers one object; `Unload` disposes it and
  every view then refuses.
* **SOFTWARE pixel**: the `model` proof, registered in
  `tools/qualification/rasterizer-proofs.json` so the lane fails without it. Two
  meshes in two colours, so a pixel says which mesh drew it.

**What it does not prove.** `Model.Draw` has no pixel evidence: it sets World,
View and Projection, which needs the optional shim, and the rasterizer lane has
none. Its *logic* is transcribed and its refusals are tested; that a matrix it
set changed a pixel is not claimed. Nor is anything about a bone transform moving
geometry on screen, for the same reason.

## What to do next

**One closure, and this file carries one.** When the next one lands, this section
is replaced rather than added to.

The owned `GraphicsDevice` was the last recommendation and it has landed. It
added **no type and no route to the selection** -- `cna_graphics_device_create`
and `cna_graphics_device_destroy` had existed since 0.21.0 and were unbound
because nothing needed them -- and it closed the last two
`PUBLIC_OBJECT_MODEL_CLOSURE` members: `GraphicsDevice.new(GraphicsAdapter,
GraphicsProfile, PresentationParameters)` and `GraphicsDevice.Dispose()`.

**Both measurement questions this file asked were answered, and both by running
the ABI rather than reading it.**

1. *Can a caller-created device coexist with a game's?* **Yes**, on all three
   admitted ABIs and both renderers. Two owned devices are live at once with
   distinct handles; one may be destroyed while the other still draws; and
   `cna_game_destroy` succeeds with an owned device and its resources still
   live, exactly as the header promises.
2. *Does creation work under HEADLESS?* **Yes** -- it does not answer
   `CNA_RESULT_PLATFORM`. HEADLESS and SOFTWARE differ in exactly one place in
   the whole nineteen-stage matrix: the back-buffer readback, which HEADLESS
   answers `NOT_SUPPORTED`. So the closure qualifies on the CI renderer for
   lifecycle and needs the SOFTWARE lane for pixels, which is the discipline
   this repository already had.

**Three things the measurement found that nobody asked for**, and each is
asserted in both directions so a CNA that changed would fail a test:

* **Cross-device resource use is not refused**, though the header says it is.
  Every crossing measured was accepted and really took. XNA does not refuse it
  either -- `TextureCollection::set_Item` compares no devices at all -- so this
  binding does not invent the guard.
* **CNA's sampler slot table is shared between devices**, and XNA's is per
  device. The header does not mention it.
* **The three admitted ABIs behave identically here.** The matrix output is
  byte-identical apart from the version banner. Unlike Storage, where identical
  headers hid different behaviour, this time they did not -- and that is now a
  measured fact rather than an inference.

### What the frontier looks like now, measured

The generated tables above are the authority; what follows is what changed
*category*, which a table of counts cannot say.

* **`PUBLIC_OBJECT_MODEL_CLOSURE` is empty**, and stays empty. Its row is still
  rendered because its being empty is the claim: the object model represents
  both native ownership graphs XNA permits, rather than one of them and a note
  about the other. The 2026-09-07 audit checked the converse too -- that no
  partial is parked in another category because this one used to carry the only
  "local architecture work" concept -- and found none that belongs here.
* **`IMPLEMENTABLE_AND_HIGH_VALUE` is no longer empty**, for the first time.
  Two members are in it, and neither was implemented: see the audit below.
* `LANGUAGE_PROJECTION_LIMIT` and `CNA_ADMITTED_ABI_LIMIT` each lost exactly the
  one member that moved. `DEPENDENCY_NOT_SELECTED` and `QUALIFICATION_LIMIT` are
  unchanged. **The partial member count did not move**: a reclassified member is
  still partial until somebody implements it.

## The 29 partial members, re-read from zero

Measured 2026-09-07 against the whole admitted set. **Both members the audit
found have since been implemented** -- `RenderTargetBinding.CubeMapFace` and then
`Game.Content`, each in its own task -- so the frontier is 27 now and
`IMPLEMENTABLE_AND_HIGH_VALUE` is empty again. The audit is kept as written,
because what it found is why the two members moved.

The question asked of each
was not "can the existing reason be confirmed" but "what exact XNA behaviour
makes this partial *today*". **Twenty-seven survived. Two did not**, and both had
been kept by the same bad implication -- *CNA cannot represent X, therefore the
public binding cannot* -- which `Game.Services` and the owned `GraphicsDevice`
had each already disproved.

### The two that were wrong

* **`RenderTargetBinding.CubeMapFace`** -- **implemented since, and complete.**
  It was a `LANGUAGE_PROJECTION_LIMIT`, a
  category meaning the projection *cannot express* the member. It expresses it
  easily: `CUBE-MAP-FACE` is a projected, complete XNA enum, and this binding
  **already computes `:POSITIVE-X`** on both native paths -- `SetRenderTargets`
  and the `GetRenderTargets` cross-check each read the face as
  `(or face :positive-x)`. Nothing else needs `NIL`: 2D-versus-cube is
  answerable from the target's type, value equality cannot collide, and the two
  constructor shapes are XNA's own. The only argument left was that `NIL` reads
  better, which is a preference and not compatibility evidence. The
  implementation then found the IL stronger than the audit had claimed: XNA's 2D
  constructor does not leave the field defaulted, it *stores* the value --
  `ldc.i4.0; stfld _cubeMapFace` -- so the binding stores it in the same place
  for the same reason, and the two normalisations were deleted rather than kept.
* **`Game.Content`** -- **implemented since, and complete.** It was a
  `CNA_ADMITTED_ABI_LIMIT` because
  `cna_game_set_content_manager_ext` copies where XNA assigns a reference. True
  of the route, irrelevant to the member, because the member need not use it.
  The pinned IL is a plain field -- `get_Content` is `ldfld`, `set_Content` is a
  null check plus `stfld`, and the only other framework reader is the private
  `DeviceDisposing`, which calls `Unload` on whatever is *currently assigned*.
  On CNA's side the decisive count: in the entire engine, outside tests and
  examples, `getContentProperty()` has **one caller**, and it is
  `cna_game_get_content_manager_ext` itself. So CNA's copy is observable through
  no selected public member, and a Lisp slot would reproduce XNA exactly.

`docs/limitations.md` carries both measurements and the test each next task
needs. **Neither was implemented here**, which is why both are still partial.

### The one thing this audit found and did not resolve

`GraphicsDevice.Viewport` is partial because its setter needs the optional
private shim. The manifest lists **four** shimmed routes, and the other three are
`BasicEffect`'s `World`, `View` and `Projection` -- which are reported
**complete** on the same blocker, with the same refusal, in the same condition
class. One of the two labels is wrong. Choosing needs a decision about whether an
optional build artifact makes a member incomplete, which would move three
members reported complete; that is a scoreboard decision rather than a reason
correction, so this measurement recorded it instead of making it. It is the
first thing a reader of this frontier should be told, because it is the only
place the scoreboard is known to be internally inconsistent.

### The stale reasons, and there were more than this file claimed

This file said "three of the 29 have not been re-read since the ABI set became
three versions". Derived mechanically from the reasons themselves -- which name
the versions they were read against -- **the three are** `ContentManager.Load`,
`SoundEffect.Duration` and `DynamicSoundEffectInstance.new`, each still written
against `{0.21.0, 0.22.0}`. But the same scan found a worse class the claim
missed: **four members whose reasons still named 0.21.0 alone** -- `Texture2D`'s
`Width`, `Height` and both `FromStream` overloads -- never re-read since the set
became even two. All seven now carry evidence from all three, and two of them
were factually wrong rather than merely narrow:

* **`ContentManager.Load<T>` said four loaders; the registry, regenerated from
  the running system, answers six.** The two that joined are exactly the two the
  old text dismissed as "for types not in the selection" -- the Audio and Model
  closures selected both. Every typed content route any admitted ABI has is now
  projected, so the member is at CNA's ceiling; it stays partial because the
  contract puts *no* bound on `T` and fifteen types **in this selection** have a
  canonical XNA reader no CNA route can answer -- `Song` and fourteen value
  types.
* **Both `FromStream` overloads said XNA's fit lives in code "the pinned
  assembly does not contain".** The assembly contains it:
  `Microsoft.Xna.Framework.dll` is a mixed-mode x86 image and the call is
  `XnaImaging.DecodeStreamToTexture` with `CallConvCdecl`, native code in that
  same PE. The boundary is the disassembler's, not the file's.

### What re-measurement rather than re-reading established

Header equality was not accepted as behavioural evidence anywhere it mattered:

| Member | Evidence taken |
| --- | --- |
| `GraphicsAdapter.Revision`, `.SubSystemId` | not the header's "current CNA returns zero" but the **function bodies** at each admitted commit: `return 0;`, a literal with no branch on renderer, platform or adapter |
| the `GraphicsDeviceManager` trio | each whole CNA tree searched at `056e57d47`, `fb62662c9` and `5c8840657`: six hits, three declarations and three definitions, **no call site**, and no C route in any admitted header |
| `Model.Draw`, `ModelMesh.Draw`, `ModelMeshPart.Effect` | `model-defect-matrix.sh` re-run on real libraries from all three: SIGSEGV at 0x20, 0x10, 0x20, 0x8/0x0 and 0x0, everywhere; 0.21.0 additionally dies at 0x490 loading at all |
| `Microphone.BufferDuration` | the boundary re-run on all three, both branches asserting -- 0.21.0 refuses exactly 1000 ms and names the ABI and its 990 ceiling, 0.22.0 and 0.23.0 take the range |
| `SoundEffect.Duration` | the literal tick counts (130000 against 125000, 450000 against 453514) are asserted per ABI by every suite run, not inferred from `audio.h`'s single SHA-256 |
| `GraphicsAdapter.Adapters`, `.DefaultAdapter` | all **twelve** `cna_graphics_adapter_*` routes take `CNA_Handle graphics_device` first, in all three header sets: nothing enumerates adapters without a device |

**Two reference experiments were attempted rather than assumed away.** This
machine has Wine 10.0 and a prefix with Microsoft .NET Framework 4.0, so a probe
was compiled against the pinned XNA assembly -- the compile succeeded -- and run.
It fails at load with `BadImageFormatException`, because a mixed-mode assembly
needs the Windows CLR's own image loader; and a Wine result would have been
FAudio's and Wine D3D9's rather than XNA's in any case. That is what keeps both
`QUALIFICATION_LIMIT` members where they are, and it is now a measurement rather
than a presumption.

**The `Model` safety guard was re-derived in the same pass** -- 322 functions in
`CnaCApiEffects.cpp`, 22 reaching `GetEffectState`, 17 of them bound here -- and
every one of the 17 is reachable only through a guarded path. **No unguarded
process-kill route was found, so no `Model` code was changed.**

### Both recommendations are done

The audit found two members kept partial by reasons that did not survive
re-reading, recommended them in that order, and both have since been implemented
in tasks of their own. **`IMPLEMENTABLE_AND_HIGH_VALUE` is empty again**, which
is the release condition, and it is empty because the work was done rather than
because nothing was found.

`RenderTargetBinding.CubeMapFace` cost one stored value, two deleted
normalisations and five assertions, and turned out to be a straighter
transcription than the audit knew: XNA *stores* the face in its 2D constructor
rather than defaulting it, so the binding stores it in the same place.

`Game.Content`'s setter is the null check and the field store, and **no native
call at all** -- which is the whole point, since the reason it was partial was a
native route it never needed. Three things the implementation settled that the
audit had left open:

* **Ownership does not move.** A reference store is not an adoption: a manager
  built over a graphics device is already an owned child of its game, so
  assigning it changes no ledger and it is still released with its game.
* **Nothing is disposed, and the facade is reassignable.** XNA's setter disposes
  nothing; the replaced facade is only unreferenced, so a program can put it
  back. That is the answer to the question the audit said had to be *chosen*
  rather than fallen into.
* **One requirement the audit stated did not exist yet.** It said the setter must
  make `DeviceDisposing` reach the assigned manager. XNA's private handler is
  real and `HookDeviceEvents` subscribes it, but the binding had not implemented
  that hookup at all, so there was nothing to redirect. It was recorded as
  separate work -- and **it has since been done**, below. The setter needed no
  change, which is what "separate" meant: the handler reads the field, and a
  field holding a reference is all it needs.

### Both of the two open items are now closed too

**`Game`'s private device-event wiring is implemented and qualified.** The pinned
`HookDeviceEvents` was re-read in full, and the finding that mattered was a
measurement rather than a transcription: CNA's native game already drives
`Game.UnloadContent` at the point XNA's private handler calls it, so the binding
supplies `ContentManager.Unload` alone and the pair lands in XNA's order. Eight
kinds of evidence on all three admitted ABIs, including a real `SpriteFont` and
its atlas reaching their disposed state, the **current** `Game.Content` being
chosen over a replaced one, and the framework's listener running in subscription
order between two program handlers. **No compatibility cell moved**, which is
correct: none of the four handlers is a public XNA member. One adjacent handler
is deliberately still missing and is measured rather than guessed at --
`DeviceCreated -> LoadContent` after a *later* device re-creation; see
`docs/limitations.md`.

**The four-shim contradiction is resolved.** The rule -- a member is `complete`
when it is reachable in every supported installation, not merely in the fully
equipped one -- is written down in `docs/compatibility.md` and applied uniformly,
which moved `BasicEffect.World`, `.View` and `.Projection` from `complete` to
`partial` beside `GraphicsDevice.Viewport`. It was settled by the project's own
precedent rather than by preference: `ModelBone.Transform` avoided a fifth shimmed
route specifically so it could be "complete rather than packaging-dependent".
Their category is the new `PACKAGING_ABI_BRIDGE_LIMIT`, because what must change
is packaging and not the public API.

### What is next

**Nothing inside the selected profile is both unblocked and worth doing.**
`IMPLEMENTABLE_AND_HIGH_VALUE` is empty, and it is empty because the work was
done rather than because nothing was found.

**The `MediaLibrary` closure landed on 2026-09-08 and it was the recommendation
this section carried.** Fifteen types and 142 members, in one dependency-complete
closure rather than two: `MediaLibrary` returns `PictureCollection` and
`PictureAlbum` from six of its own members, so a closure that stopped at the
music half would have left it partial by construction. It closed
`Song.Artist`, `.Album` and `.Genre` -- three of the twenty-three then missing --
and it moved the binding to 210 types and 2723 members.

Three things it established that a future closure should not have to rediscover:

* **A blocker can be a measurement error rather than a limit.** This closure was
  declined for months because `media_library.h` calls an empty library an
  ordinary result, so CI was believed able to qualify *empty* and nothing else.
  What that missed is that SDL resolves the user folders through
  `$XDG_CONFIG_HOME/user-dirs.dirs` -- a generated fixture makes the library
  deterministic and non-empty on every admitted ABI. **Re-measure a blocker
  before believing it**, which is what `docs/media-library-audit.md` is.
* **The pinned contract snapshot went missing and was recovered, not re-pinned.**
  No file with the pinned hash existed on the machine any more. Stripping the one
  additive field from a newer serialization reproduces the pinned bytes exactly,
  so the authority was recovered and the hash is unchanged;
  `tools/api-compat/recover-contract-snapshot.py` refuses to write anything that
  does not hash to it.
* **Route coverage is not closure evidence.** All 148 routes existed and all 142
  members mapped, and the closure still turned on three things no route list
  shows: XNA caches its collection properties in private fields where CNA answers
  a fresh handle per call; a song from a library collection is *owned* where an
  album is *borrowed*; and nine routes carry an `out_available` flag that a
  two-parameter reading silently corrupts.

**The `Texture3D` closure landed on 2026-09-08, and it landed because the
recommendation above was acted on rather than repeated.** The section that used
to sit here said `Texture3D` was ruled out by measurement, that "neither renderer
can construct one at all, so every member of the type would be unreachable in
CI", and -- in the same breath -- that the honest next step was to re-measure
those blockers against a CNA built with the capability. It was re-measured. The
six `NOT_SUPPORTED` rows are all still true and were re-run; what they say is that
*those two renderers* have no volume storage, which is what
`cna_texture3d_create`'s own documentation says it means. A desktop-core EasyGL
build has it, and the whole transfer surface works there on all three admitted
ABIs. `docs/texture3d-audit.md` is the audit and
`tools/qualification/texture3d.sh` is the standing lane.

One type and eleven members -- the pinned contract's count, not the plan's "~13"
-- with an empty dependency closure, and it closed
`EffectParameter.GetValueTexture3D`, which had stood at
`DEPENDENCY_NOT_SELECTED` for exactly this reason. 210 types and 2723 members
became 211 and 2734.

Four things it established that a future closure should not have to rediscover:

* **"Re-measure a blocker before believing it" applies twice, and the second time
  is subtler.** `MediaLibrary` established the rule; this closure needed it again
  *within itself*. The first measurement of EasyGL's device limit said "a second
  GraphicsDevice in one process faults", which would have forced every claim onto
  a `Game` and given up the caller-owned device path this type's ownership claim
  needs. What actually faults is a device created across a **gap with none
  alive**: four devices created and destroyed beside one that stays alive all
  work. A blocker measured coarsely is still a blocker measured wrongly.
* **A capability flag is not a measurement.** EasyGL advertises `Texture3D` and
  its mip level count is still not XNA's: XNA hands `Levels = 0` to D3D9, which
  is a complete chain to 1×1×1, and EasyGL computes the count from width and
  height alone, citing FNA. They agree for 8×4×3 and differ for 2×2×8. Nothing
  short of asking the library would have said so.
* **CNA applies none of XNA's profile guards, and two of them change what the
  type *is*.** CNA creates a `Texture3D` on the **Reach** profile, where XNA has
  none at all (`MaxVolumeExtent` 0), and at 257 wide where XNA's HiDef maximum is
  256. Those guards live in this binding or nowhere, and their values are the
  pinned `ProfileCapabilities`.
* **A route that exists is not a route that closes a member.**
  `cna_texture3d_set_data_bytes` works and would widen `SetData` beyond `Color` --
  and there is no byte *read* route, so using it would leave a volume writable as
  bytes and never readable as bytes. XNA's generic pair is symmetric; both halves
  stay `Color` and both are reported partial.

### The candidates, re-measured 2026-09-08

| Candidate | Types | Members | New routes | Closes, in selected types | Deterministic CI | User value | Complexity |
| --- | ---: | ---: | ---: | --- | --- | --- | --- |
| ~~`Texture3D`~~ | ~~1~~ | ~~11~~ | ~~8~~ | ~~1~~ | **DONE 2026-09-08** | — | — |
| ~~`Media` / `MediaLibrary`~~ | ~~15~~ | ~~142~~ | ~~148~~ | ~~3~~ | **DONE 2026-09-08** | — | — |
| `Media` / `Video` | 3 | 24 | 42, `video.h` | 0 | **unmeasured — see below** | low | medium |
| XACT | 7 | 72 | 62, `xact.h` | 0 | **unmeasured — see below** | low | high |
| `GameWindow`'s seven | 0 | 0 | 0 | 0 | n/a | low | **blocked** |

**The two remaining rows changed their reasons on 2026-09-08, and neither changed
to "possible".** Both used to be recorded as impossible. Both are now recorded as
*unmeasured*, which is a different and more honest thing, and the difference is
exactly the mistake `Texture3D` was:

* **`Video` is conditional on FFmpeg, and this build has none.** CNA's
  `CNA_ENABLE_VIDEO` is `AUTO`, so a build resolves it from what is installed;
  every library in the admitted set was built without it. "Needs an optional
  decoder this build does not have" was true of *this build* and says nothing
  about CNA. **Re-measuring it means building with `CNA_FFMPEG_AVAILABLE` and
  asking the routes**, exactly as `Texture3D` was re-measured against a renderer
  that had the capability. Nothing here starts that work.
* **XACT's "no fixture can exist" is too strong.** CNA's own test suite contains
  **source-generated XGS/XSB fixtures**, so a fixture can plainly be produced.
  The unresolved question is a different one: whether a fixture produced without
  the Microsoft XACT authoring tool is admissible as *XNA-authority* evidence, or
  only as evidence about CNA. **Those fixtures are not promoted to authority
  here**, and doing so silently would be the failure this file exists to prevent.
  Nothing here starts that work either.

### The one thing to do next

**Mask the floating-point traps around CNA-Lisp's foreign calls, or decide
deliberately not to.** This closure found it and deliberately did not fix it,
because it is a question about every foreign call this binding makes and not
about `Texture3D`.

SBCL unmasks `invalid`, `overflow` and `divide-by-zero` by default. Mesa's
llvmpipe raises them in the ordinary course of rasterising, and the trap arrives
as a condition signalled from *inside* a foreign call -- measured during
`GraphicsAdapter.Adapters`, before any `Texture3D` existed. The EasyGL lane masks
them itself and works; a program a user writes would not, and would see
`FLOATING-POINT-INVALID-OPERATION` out of a graphics call it made no arithmetic
in.

It has never come up because the two renderers the ordinary suite uses never
raise one. That is the shape of the problem: **the binding is qualified against
exactly the renderers that cannot show this**, and the first renderer that could
showed it immediately.

The decision is a real one and it is not obvious. `src/internal/float-semantics.lisp`
already owns "how a particular implementation spells masking the traps", and
`WITH-BINARY32-SEMANTICS` masks them around *projected arithmetic* so that XNA's
IEEE 754 default semantics reach the caller. Extending that to foreign calls
would mean deciding where the boundary is -- every `check-result` site, or a
wrapper around the whole public surface -- and what a caller's own trap settings
should survive. Do it as its own task, with its own measurement of which routes
can raise one, or record the decision not to and say what a user on a GL renderer
must do instead.

## Architectural facts a future agent must not undo

Each of these was arrived at by measurement and each has cost a mistake at least
once. `docs/limitations.md` carries the full reasoning; what is here is the
decision and the reason it is not an oversight.

**About the ABI**

* **The admitted set is `{0.21.0, 0.22.0, 0.23.0}`, and it is a *set*.** 0.22.0 was
  qualified on 2026-09-05 against an exact published pair -- CNA `fb62662c9` and
  sharp-runtime `bfc826e1`, both detached worktrees of `origin/next`, neither
  patched -- and the whole gate set was run against a real library built from it.
  0.21.0 was re-run afterwards, because admitting a second version changes the
  first one's gate too. `docs/qualification.md` names every gate and its result.

  **Making it a set needed three fixes, and each had silently assumed one
  version.** `generate.py --check` compared the generated layer byte for byte, so
  it could only pass against whichever version the checked-in files came from;
  `probe.generated.c` asserted `CNA_ABI_VERSION == 5376` in C; and the
  admitted-set test asserted a set of exactly one. The four ABI-version constants
  are now compared and asserted as *an admitted version* and nothing else is
  relaxed -- a version that changed a route, a layout or any other constant still
  fails, which was verified by breaking it. That is the shape of the mistake to
  expect when a third version arrives: not the layer, but the machinery that
  checks it.

  **The layer really is identical across the set.** Byte for byte across all
  three versions, differing only in `+abi-version+` and `+abi-version-minor+`;
  regenerate against any admitted version's headers and `--check` passes.
  `docs/compatibility.md` carries the current counts.

  **Admitting 0.23.0 cost two more of these**, exactly as predicted:
  `the-admitted-set-is-explicit-and-small` asserted a length of 2, and
  `the-loaded-library-is-one-of-the-two-admitted-versions` carried the count in
  its name. Both keep their literals -- that is the point of them -- and the
  second was renamed. Expect the same when a fourth version arrives, and look for
  it in the tests rather than in the layer.
* **Do not widen the gate to a range.** Three admitted versions is the moment
  "any 0.2x" starts to look reasonable. The explicit set is what makes "qualified"
  mean something: each entry is a version whose whole bound surface a compiler has
  checked against that version's own headers, and a range would admit versions
  nobody has compiled against.
* **A newer CNA is not evidence of anything.** 0.23.0 was admitted because its
  header delta was diffed, its generated layer was proved unchanged, both gates
  were watched refusing it first, and the whole suite ran against real libraries
  built from an exact published pair. It fixed nothing here -- both Model defects
  were re-measured on it and neither is fixed -- and it was admitted anyway,
  because admission claims compatibility and not improvement.
* To reproduce the 0.21.0 gates, point `CNA_ABI_BASELINE` at a 0.21.0 baseline --
  `cnanext 2b0c374a1` is the last commit carrying one -- rather than at whatever
  the checkout is on today, or the generator refuses with "supplied headers
  declare ABI ... which the manifest does not admit", which is the gate working.
  `~/deps/cna-c-abi-0.21.0/`, `~/deps/cna-c-abi-0.22.0/` and
  `~/deps/cna-c-abi-0.23.0/` hold a built library, its headers and its baseline
  for each, with a `-software` directory beside each holding the SOFTWARE build.
* **A private shim is the permitted remedy for a proved ABI impedance mismatch**,
  and it stays optional: a release must load with no C toolchain.

**About the object model**

* **The graphics device has two lifetimes and one public type, and neither half
  may be collapsed into the other.** A *game's* device must never keep its
  handle: CNA lends it for a callback's duration, so the parent-owned mode
  resolves a fresh borrowed handle per operation and refuses every operation
  outside a callback before anything reaches the ABI. A device the *caller*
  constructed holds a persistent handle, needs no callback and no game, and is
  the caller's to dispose. `%DEVICE-LIFETIME-MODE` is the discriminator and
  `%RESOLVE-DEVICE-HANDLE` is the only seam -- every device member goes through
  it and none of them is written twice. Do not make them two public classes;
  XNA has one. Do not relax the facade's scope rule to match the owned device's;
  the facade genuinely has no handle out there. The window and the content
  manager are facades on the parent-owned rule.
* **One place decides which native object owns a graphics resource.**
  `NATIVE-RESOURCE-OWNER-FOR-DEVICE` answers the game for a facade and the
  device for an owned device, and `ADOPT-NATIVE-RESOURCE` acts on it. Nine
  resource constructors used to spell the game-owned answer inline, and each was
  correct only because a game's device was the only device. Scattering
  `if owned-device` back through them is how a resource family gets left behind.
* **A native `GraphicsResource` records the device it was made against and never
  looks one up.** `get_GraphicsDevice` is `ldfld _parent` in the pinned IL, with
  no lookup of any kind. The old implementation answered the *active game's*
  device, which is wrong for an owned device and wrong silently.
* **`System.IO.Stream` is a Common Lisp stream, and is not a type.** It is the
  BCL's, not the XNA profile's, so there was never a type here to project --
  members that take one take an ordinary binary stream from `OPEN`. `SeekOrigin`
  is not projected either: .NET spells relative positioning as an enumeration and
  Common Lisp spells it as arithmetic on `FILE-POSITION`. Do not add either class.
* **`System.Char` is a UTF-16 code unit, and a Lisp string is not made of them.**
  It projects onto an integer in [0, 65535], and text is converted to code units
  before it is measured or drawn -- XNA looks up each of a surrogate pair's two
  `char`s separately. Do not "simplify" that to iterating the string's characters.
* **A projection may narrow, but it may not lose an overload.** A collapse must be
  declared with the mechanism that distinguishes its members, each naming the
  others, and the verifier refuses one that names nobody.
* **An exported symbol that is neither a mapped member nor a declared extension is
  a diagnostic.** A convenience function needs an entry in
  `cna-lisp.internal::*binding-extensions*` with the reason it exists. That is
  what keeps the scoreboard honest; it is not paperwork to route around.
* **Projecting a CNA route that XNA has no member for invents API.**
  `cna_sprite_font_create` and `cna_display_mode_equals` are both unbound for that
  reason. CNA having a route is not an argument.

**About ownership**

* **Whoever receives a handle from CNA records its destruction** -- one asset load,
  one ledger. A constructor taking an existing handle records it; the loader that
  obtained it does not record it twice.
* **Default ownership does not cascade; a public type may do so only where pinned
  XNA semantics require it.** CNA requires children destroyed before parents, and
  `DISPOSE-OWNED-CHILDREN`'s default reports a live child rather than deciding
  when a program's resources die. `SoundEffect` is the one override, and it is not
  a convenience: `SoundEffect.Dispose(bool)` in the pinned assembly disposes every
  live `SoundEffectInstance` before releasing its own handle, so refusing there
  would refuse a call XNA accepts. This used to read "disposal is not cascaded",
  full stop, which described the code and not the contract.
* **`cna_game_destroy` answers `CNA_RESULT_CALLBACK` for a latched earlier
  failure**, not only for a failing shutdown callback. The two are distinguished
  by whether a condition was freshly contained; the alternative masks the original
  condition behind an unwind. `tests/native/ownership.lisp` pins both directions.
* **The cache is this binding's, in front of CNA's route, which is where XNA's is
  too.** `Load<T>` twice answers one object, `Unload` disposes what it loaded, and
  `Game.Content.Dispose()` is `Unload` plus being finished. Do not restore the note
  that said there is no cache.

**About behaviour**

* **Behaviour comes from the IL, not from a description of it.** The pinned
  assembly is recorded by SHA-256 in
  `tools/api-compat/reference/XNA_IL_PROVENANCE.md`. Reading it is what caught
  that `Math.Min(+0.0f, -0.0f)` answers `-0.0f`, that `Clamp` passes a NaN
  through, and that `ToRadians` multiplies by a constant rather than dividing by
  180 -- three things a reimplementation from first principles gets wrong.
* **CNA is not the oracle, and XNA wins publicly.** CNA's `DepthStencilState`
  initialises both stencil masks to `0x7FFFFFFF`; XNA's `SetDefaults` writes `-1`.
  The public value is XNA's and `tests/native/graphics-state.lisp` pins *both*
  sides, so a corrected CNA fails a test rather than passing silently. Likewise
  `BlendFunction` numbers Min 3 and Max 4 in XNA and the other way round in CNA,
  which is why the state enums translate **by name**.
* **CNA is stricter than XNA about a SpriteFont's spacing**, so the three CNA
  setters are not bound at all rather than bound and worked around.
* **A component added in `LoadContent` is never initialized, and that is XNA's
  doing.** `Game.Run` sets `inRun` after `Initialize()` returns, and `Initialize()`
  calls `LoadContent()` at its very end. Read from the pinned assembly, measured
  to be CNA's behaviour too, and pinned by a test. Do not "fix" it.
* **A state object is latched at Begin.** CNA's `begin_with_states` copies the
  descriptors by value, so refusing a mutation between Begin and End was chosen
  over accepting one that could no longer take effect.
* **A fixed time step does not make a frame count an update count.** Catch-up
  updates follow a frame that overran its target, and a full collection between
  frames is enough. Every deterministic frame claim here uses variable timing. Do
  not "fix" a test that sets `is-fixed-time-step` to false.

**About the evidence**

* **A qualification lane that cannot fail for the right reason proves nothing.**
  The rasterizer lane's trap is passing while silently taking the no-readback
  branch, so every test branches on the renderer present and asserts the truth for
  each, and `rasterizer.sh` fails when the branch was wrong. Verified by pointing
  it at a HEADLESS library: it exits 1.
* **A state round-trip is not shading evidence.** CNA's software renderer never
  reads `GpuDrawParams::alphaTest`, so `AlphaTestEffect`'s parameters reach the ABI
  and change no pixel. The `stock-effect` proof claims only that these are usable
  *draw* effects. Do not upgrade that claim without new evidence.
* **A number in prose is a claim.** `tools/qualification/verify-numbers.py` checks
  `<!-- generated:name=N -->` facts, whole `<!-- generated-block:name -->` regions
  rendered from the reports, and refuses figures that belong to a run rather than
  to the repository.
* **A mapping rule keyed on a signature no member produces is silently ignored**,
  and is now a `stale_mapping_rule` diagnostic. Take a signature from the generated
  report, not from a listing script.
* **A declared reason is a claim about the ABI and has to be measured like one.**
  Ten declared reasons were found wrong at the route-by-route audit, and three of
  them said "CNA has no route" about a route that existed. That is the wording to
  distrust first, and the reason to read the header rather than the reason.
