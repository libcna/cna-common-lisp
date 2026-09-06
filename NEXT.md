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
```

The two qualification scripts do that for themselves. `with-virtual-screen.sh`
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
**0.21.0** (encoded 5376) and **0.22.0** (encoded 5632), each built with the
`SDL3` platform, `SDL3` audio and the **HEADLESS** renderer. Both are in the
admitted set, and every row below that involves a library was produced against
each of them -- the fourth row is the lane with no library at all, so it has no
ABI to be produced against:

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
| Rasterizer lane | `tools/qualification/rasterizer.sh` against a SOFTWARE-renderer library: every kind its registry requires (<!-- generated:rasterizer proof count=8 -->) |
| Template canary | exactly 60/60 and 600/600 updates and draws |
| Audio, unavailable branch | a driver that does not exist: no device, and every route needing one refused with `NO-AUDIO-HARDWARE-ERROR` |
| Audio, state machine | `SDL_AUDIODRIVER=dummy`: a device opened with no speaker behind it, and play/pause/resume/stop transitioned |
| Isolated consumer | CNA-Lisp loaded from the artifact, not the checkout |
| Native stress | 20 plain cycles + 20 graphics cycles, registry empty after each |
| Construction atomicity | an exploding subclass of twelve resource families, plus `Game` and `GraphicsDeviceManager`, leaves no live child and lets the game shut down |
| Content transaction | a load made to fail at the texture's storage query, the font's info, its glyph table, or the **cache insertion** gives every handle back exactly once |
| Render-target cross-check | six ways a remembered binding can drift are each refused; an unmutated one is accepted first |

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

## Continuous integration

Both workflows **have run on GitHub and are the live gate**; any statement that
they have never executed is stale.

| Workflow | What it runs |
| --- | --- |
| `Lisp` / reference | pure gates on SBCL 2.5.2, installed from the upstream binary release and verified by SHA-256 |
| `Lisp` / distro | the same gates on ubuntu-24.04's own SBCL, as a secondary compatibility test |
| `Native` | builds the CNA C ABI from source, then the ABI gate, both runtime configurations and the isolated consumer, on the reference runtime, with the HEADLESS renderer |
| `Native` / rasterizer | a second CNA with the SOFTWARE renderer, and the same suite: it fails unless every kind of pixel proof its registry requires was obtained, and fails too on a kind the registry does not name |

**A run has three outcomes and they are three, not two.** `success` is evidence.
`failure` is evidence of a defect. `cancelled` is **neither** -- the workflows use
`cancel-in-progress`, so pushing again kills the run in flight, and a run that was
killed proves nothing in either direction. Cite a run by id and conclusion, never
by "the last run"; `gh run list` prints all three fields.

The `Native` job is **pinned to CNA commit `fb62662c9`** -- ABI 0.22.0, the newest
commit on `origin/next` whose ABI this binding admits, and the parent of the
0.23.0 bump. The pin is no longer the sharp-runtime one: that blocker closed on
2026-09-05 and the pin's old comment said otherwise until this task. It is the ABI
gate now. `cna:next` is 0.23.0, which is not admitted, so an unpinned job would
fail the gate on its first run -- correctly. Every run records the CNA and
sharp-runtime commits it landed on, in the step summary and in
`qualification-run.json` inside the run's artifact, and `workflow_dispatch` takes
`cna_ref` and `sharp_runtime_ref` -- `cna_ref: next` measures the tip, and
`cna_ref: 056e57d47...` reproduces the 0.21.0 half of the admitted set.
`docs/qualification.md` has the policy and the evidence.

## Foundation 1 is release-ready, and frozen

**`FOUNDATION_1_RELEASE_READY = yes`**, decided at `5a7f7c1` and unchanged since.

**Read this section's numbers as Foundation 1's, and the generated scoreboard
below as the whole binding's.** They were the same figure when this was written
and they are not any more: Audio landed after the freeze and added eight complete
types and 57 members to the selection. Foundation 1 at its release commit was

    157 selected types, 2332 selected members
    141 complete types, 16 partial, 0 missing
    1854 complete members, 19 partial, 35 missing, 424 not applicable
    0 disagreement diagnostics

and the generated blocks further down are that plus Audio. Every non-complete
member is still Foundation 1's -- Audio contributed none -- so the category table
below describes the same 54 members it always did.

The decision was about the *foundation as a coherent milestone*, not about the
scoreboard reaching zero. It never will: of those 54, 39 are held up by CNA
0.21.0, 6 by types the profile has not selected, 5 by the Common Lisp projection,
3 by an object-model closure and 1 by a missing proof.

The eight conditions, and what each rests on:

| Condition | Evidence |
| --- | --- |
| All gates green | the gates in "Reproduce the state" and the table above, re-run at each audit; the suite reports no failure and nothing not run in all three native configurations, and in the fourth it reports the native layer as not run rather than as passed |
| The freeze holds | Audio landed after it and changed no Foundation 1 member: still 35 missing and 19 partial, still 0 missing types, still 0 disagreements |
| No known ownership or lifetime defect | ownership stress, construction atomicity over twelve resource families, content transaction rollback at four injection points, callback registry empty after each cycle |
| Zero structural disagreements | `verify.py --strict`, over <!-- generated:diagnostic categories=18 --> diagnostic categories |
| No stale live-state documentation | two audits; the second is recorded below, and found what the first left behind |
| Admitted ABI set truthful | `{0.21.0, 0.22.0}`, and both are evidenced: the whole gate set ran against a real 0.22.0 library built from an exact published source pair, and 0.21.0 was re-run afterwards. `cna:next` is 0.23.0 and is **correctly not admitted** -- nothing has run against it |
| CI green | both workflows `success`, and named by run id below rather than by "the latest run" |
| Qualification wording no stronger than its evidence | the SOFTWARE lane's claims are rendered from the registry the lane enforces, and every required proof must also be *described* |
| Every non-complete member has a concrete reason | 54 of 54, each naming a route or an IL fact, each in one of seven categories, with **zero** in either implementable category |

That last row is the one to re-read before believing this.
<!-- generated:high-value frontier members=0 --> members are
`IMPLEMENTABLE_AND_HIGH_VALUE`, and that is a *measurement*:
`docs/compatibility.md` renders the count and `verify.py` refuses a frontier
member that has no category. Nothing in the selected profile is both unblocked and
worth doing. That is what makes this a milestone rather than a pause.

**The release evidence, named exactly.** Foundation 1's release decision rests on
these runs, at the commit where the documentation-truth condition first became
true:

| Workflow | Run | Commit | Conclusion |
| --- | --- | --- | --- |
| `Lisp` | [33968261788](https://github.com/openeggbert/cna-common-lisp/actions/runs/33968261788) | `5a7f7c1` | **success** |
| `Native` | [33968261886](https://github.com/openeggbert/cna-common-lisp/actions/runs/33968261886) | `5a7f7c1` | **success** |

A run at an earlier commit is not release evidence for this one, and a `cancelled`
run is not evidence at all -- run `33966149186`, the `Native` run for `efae9c9`,
was cancelled by the push that followed it seconds later and must not be cited as
green.

**Foundation 1 is frozen.** The 35 missing members are not work in progress. The
owned `GraphicsDevice`, `GameServiceContainer`, an `IntPtr` projection and the
protected `On<Event>` raisers each have a measured reason in
`tools/api-compat/mapping-rules.json`, and reducing the missing count for its own
sake is explicitly not the next task. A selected, qualified subset is what this
milestone is.

**No tag was created.** This repository has no tags and no documented
version/tagging policy, and inventing one at a release audit would be the wrong
place for that decision. The proposed version is the one
`cna-common-lisp.asd` already carries -- **0.1.0** -- which is honest for a first
qualified foundation that projects a selected subset and says so. The choice is
the project's.

### What the two documentation audits found

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
  and that closure is over.

The remedy is structural rather than a checker: a closure's landing commit deletes
the prose that described it as future, this file carries **one** generation of
next-work, and `docs/limitations.md` marks a retained historical finding as
historical in its own heading. `verify.py` and `verify-numbers.py` already refuse
every *number* that drifts; what neither can check is a paragraph, so the paragraph
count is kept low on purpose.

### The extraordinary claims, re-read

Six claims that a reader might reasonably disbelieve were re-opened against the
hash-checked assemblies rather than against the comments asserting them, and
**all six stand**. The half-precision format is the one that needed it most and
`tools/api-compat/reference/XNA_IL_PROVENANCE.md` now carries its IL: `Pack`
saturates everything above `wMaxNormal` as an unsigned comparison, so both
infinities and every NaN go, and `Unpack` has no case for exponent 31, so
`0x7FFF` reads back as 131008.0. No implementation changed.

## The measured frontier

<!-- generated:selected types=165 -->
<!-- generated:selected members=2389 -->
<!-- generated:complete types=147 -->
<!-- generated:partial types=18 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1904 -->
<!-- generated:partial members=21 -->
<!-- generated:missing members=35 -->
<!-- generated:not-applicable members=429 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 165 types, 2389 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **147** |
| Types partial | **18** |
| Types missing | **0** |
| Members complete | **1904** |
| Members partial | **21** |
| Members missing | **35** |
| Members not applicable | **429** |
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
| `M.X.F.GraphicsDeviceManager` | 9 | 0 |
| `M.X.F.GameWindow` | 7 | 0 |
| `M.X.F.Graphics.GraphicsDevice` | 5 | 1 |
| `M.X.F.Game` | 4 | 1 |
| `M.X.F.Content.ContentManager` | 3 | 1 |
| `M.X.F.GameComponentCollection` | 1 | 0 |
| `M.X.F.Graphics.PresentationParameters` | 1 | 0 |
| `M.X.F.Graphics.GraphicsAdapter` | 1 | 4 |
| `M.X.F.Graphics.Effect` | 1 | 0 |
| `M.X.F.Graphics.EffectParameter` | 1 | 0 |
| `M.X.F.Graphics.DirectionalLight` | 1 | 0 |
| `M.X.F.Graphics.BasicEffect` | 1 | 0 |
| `M.X.F.TitleContainer` | 0 | 1 |
| `M.X.F.Graphics.RenderTargetBinding` | 0 | 1 |
| `M.X.F.Graphics.Texture2D` | 0 | 4 |
| `M.X.F.Graphics.TextureCube` | 0 | 6 |
| `M.X.F.Audio.SoundEffect` | 0 | 1 |
| `M.X.F.Audio.SoundEffectInstance` | 0 | 1 |
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
| `LANGUAGE_PROJECTION_LIMIT` | **5** | The Common Lisp projection cannot express the member, or the type it needs has no counterpart a Lisp program could use safely. |
| `CNA_ADMITTED_ABI_LIMIT` | **41** | No admitted CNA ABI can represent the member. |
| `PUBLIC_OBJECT_MODEL_CLOSURE` | **3** | Implementable against every admitted CNA ABI, but only as a new closure in this binding's object model rather than as a member. |
| `DEPENDENCY_NOT_SELECTED` | **6** | Blocked on a type that is not in the selected profile. |
| `QUALIFICATION_LIMIT` | **1** | Implemented, but some part of it cannot be evidenced, so it is not claimed complete. |
| `IMPLEMENTABLE_BUT_LOW_VALUE` | **0** | Nothing blocks it and it is not worth the surface. |
| `IMPLEMENTABLE_AND_HIGH_VALUE` | **0** | Nothing blocks it and it should be done next. |
<!-- /generated-block:frontier-categories -->

This table replaces a boolean called `GLOBAL_ACTIONABLE_LOCAL`, which was retired
because it was made to carry two different facts and got one of them wrong. The
two facts are:

* **`SELECTED_PROFILE_IMPLEMENTABLE_NOW = 0`.** Inside the selected profile,
  nothing is both unblocked and worth doing. The two implementable categories are
  empty, and that is the release condition.
* **Local work remains, and it is profile expansion.** Growing the selection into
  Audio is entirely this repository's work and needs nothing from anybody. So
  "there is no more local work" would be false.

What the retired boolean actually claimed -- **"there is nothing externally
blocked at all"** -- was false when it was written. Thirty-nine selected members
are classified `CNA_ADMITTED_ABI_LIMIT`: they need a CNA release, not a commit
here.
Six more need a type the profile has not selected, which is a profile decision
rather than an implementation. Say which category, not which boolean.

The one thing the retired section got right is worth keeping.
`GraphicsDevice.Viewport`'s setter was once recorded as an external blocker on the
grounds that CFFI cannot pass a 24-byte aggregate by value. That was a true fact
and a wrong conclusion: a tiny private shim for a *proved* ABI impedance mismatch
is the permitted remedy, the generator emits one, and the setter works through it.
The shim stays optional -- a release must load with no C toolchain -- so without
`CNA_LISP_SHIM` the setter refuses with a condition naming the variable, the
command that builds one, and the reason. That is a packaging limit, not a blocker.

## Audio has landed, and it is not 8/8 complete

**Read this before the table.** The first Audio milestone reported eight types and
57 members with every one complete. A re-audit against the pinned assembly found
that several of those claims were the implementation's rather than XNA's, and the
corrected scoreboard is **six complete types and two partial**: 50 complete
members, 2 partial, 5 not applicable. Nothing was removed -- the surface is the
same size -- and two members are now described accurately instead of generously:

| Member | Why partial |
| --- | --- |
| `SoundEffect.Duration` | CNA's per-effect duration route does not quantise to whole milliseconds and XNA always does. Computed exactly where the format is known -- both constructors and `FromStream` -- and taken from the route for a `ContentManager`-loaded effect, where 0.21.0 reports no format to compute from |
| `SoundEffectInstance.Apply3D(AudioListener[], AudioEmitter)` | CNA's own header: several listeners are combined by taking the **nearest**, where XACT computes a per-listener output matrix. A different function of the array, not an approximation of one. The single-listener overload is complete on its own evidence |

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
what CNA documents, enforced before the ABI sees a wrong order -- except that
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

## What to do next

**One closure, and this file carries one.** When the next one lands, this section
is replaced rather than added to.

### The five candidates, measured

Audio was chosen last time because it was *measured* to be reachable rather than
taken off a list, and this is that measurement repeated for the five closures in
front of it. Type and member counts are the pinned 257-type contract's; route
counts are `grep` over CNA 0.22.0's own headers; every determinism claim names the
header sentence it rests on.

| | Types | Members | CNA 0.22 routes | Selected deps missing | Hardware | Deterministic in CI |
| --- | ---: | ---: | ---: | --- | --- | --- |
| `DynamicSoundEffectInstance` | 1 | 10 | 12 | none | a playback device | **yes** — the SDL `dummy` driver already qualifies the audio lanes |
| `Microphone` family | 3 | 21 | 18 | none | a **capture** device | **half** — see below |
| `Model` family | 12 | 48 | 133 | none | none | **yes** — HEADLESS for lifecycle, SOFTWARE for pixels |
| `Media` | 24 | 223 | 270 | none | a playback device; `MediaLibrary` scans the machine | **half** — an empty library is "an ordinary result" |
| `Storage` | 3 | 35 | 49 | `IAsyncResult` | none — the filesystem | **yes** |

**Every one of the five has complete CNA route coverage**, so route count is not
the discriminator it was when Audio was chosen. Three things are.

**Qualification determinism.** `cna_microphone_get_count`'s header says "a machine
with no capture device answers zero, which is an ordinary answer and the one every
verification tree gives" -- so the *absent* branch is deterministic and the
*present* branch needs hardware CI does not have. There is no capture equivalent
of `SDL_AUDIODRIVER=dummy` in this ABI. `Media` is the same shape one level up:
`cna_media_library_create` "scans the device's music and picture locations" and an
empty library is ordinary, so the empty branch qualifies and nothing else does.
A closure whose interesting half cannot be qualified is worth less than its route
count suggests, whatever Section 29's route inventory says.

**Projection novelty.** `Storage`'s members are `BeginShowSelector` /
`EndShowSelector` / `BeginOpenContainer` / `EndOpenContainer` -- the .NET
asynchronous pair, returning `IAsyncResult`. CNA has already collapsed them:
`cna_storage_device_show_selector` and its three siblings are synchronous. So the
projection is possible and it needs a *decision* about how an async pair becomes
one Common Lisp call, which is the first member in this binding to raise that
question. `Model` raises a different one: XNA's `Model` has **no public
constructor**, so `ContentManager.Load<Model>` is the only way in, and a
qualification needs a `.cnb` model fixture -- generatable, because the CNB writer
routes are there and `tools/qualification/` already generates a font and a wave
byte for byte, but it is the largest fixture this repository would own.
`DynamicSoundEffectInstance` raises none: it derives from `SoundEffectInstance`,
which is already projected, and its one novelty is the `BufferNeeded` event, for
which the event machinery already exists.

**Size.** 10 members against 223. `Media` is larger than the whole Audio closure
by a factor of four and would be the biggest single expansion this binding has
attempted; `Model`'s 48 members include four collection-and-enumerator pairs whose
projection is settled work rather than new work.

### The recommendation: `DynamicSoundEffectInstance`

It wins on the same grounds Audio won on, and the reasoning is the same shape.

* **Every qualification level is reachable with no hardware.** Its buffers are
  PCM the test generates, its state machine is `SoundEffectInstance`'s -- already
  qualified against the `dummy` driver in a separate process -- and
  `cna_dynamic_sound_effect_instance_get_pending_buffer_count` makes buffer
  consumption *observable*, so "the runtime took the buffer" is an assertion and
  not an assumption. Nothing else on the list can say that of its whole surface.
* **It needs nothing this binding does not already have.** One type, ten members,
  a base class that is projected, and an event.
* **It is the only candidate that adds a capability rather than a surface.**
  Procedurally generated and streamed audio is not reachable through any member
  the binding has; `Storage` and `Media` largely re-express things a Lisp program
  can already do with `OPEN`.

**Not `Microphone`, and deliberately not "Audio phase 2".** It shares a namespace
with `DynamicSoundEffectInstance` and nothing else: its route family is the same
size, and half of it cannot be qualified without a capture device. Bundling the
two would attach an unqualifiable half to a fully qualifiable closure and let the
first hide behind the second's evidence.

**`Model` is the runner-up and is the bigger prize** -- it is the largest missing
*capability*, 133 routes are waiting, and the SOFTWARE lane can prove a drawn mesh
reached pixels the same way it proves a drawn triangle does. What it needs first
is the `.cnb` model fixture, and deciding to build one is a bigger decision than
this measurement should make on its own.

**Do not implement it yet.** This is a measurement, and the next task chooses.

## Architectural facts a future agent must not undo

Each of these was arrived at by measurement and each has cost a mistake at least
once. `docs/limitations.md` carries the full reasoning; what is here is the
decision and the reason it is not an oversight.

**About the ABI**

* **The admitted set is `{0.21.0, 0.22.0}`, and it is a *set*.** 0.22.0 was
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

  **The layer really is identical across the set.** 496 functions, 72 structs,
  511 constants and 10 callbacks, byte for byte, differing only in
  `+abi-version+` and `+abi-version-minor+`. All 496 bound routes are exported by
  the 0.22.0 library.
* **`cna:next` is ABI 0.23.0 and is not admitted.** Auditing and qualifying it is
  the same job this task did for 0.22.0, and the machinery is now in place for it.
  Do not widen the gate to a range to avoid doing it: the explicit set is what
  makes "qualified" mean something.
* To reproduce the 0.21.0 gates, point `CNA_ABI_BASELINE` at a 0.21.0 baseline --
  `cnanext 2b0c374a1` is the last commit carrying one -- rather than at whatever
  the checkout is on today, or the generator refuses with "supplied headers
  declare ABI ... which the manifest does not admit", which is the gate working.
  `~/deps/cna-c-abi-0.21.0/` and `~/deps/cna-c-abi-0.22.0/` hold a built library
  and its baseline for each.
* **A private shim is the permitted remedy for a proved ABI impedance mismatch**,
  and it stays optional: a release must load with no C toolchain.

**About the object model**

* **The graphics device must never keep its handle.** It is lent for a callback's
  duration. `graphics-device` resolves a fresh borrowed handle per operation, and
  a device operation outside a callback is refused before anything reaches the
  ABI. The adapter, the window and the content manager are facades on the same
  rule.
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
