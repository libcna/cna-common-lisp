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
**0.21.0** (encoded 5376) built with the `SDL3` platform, `SDL3` audio and the
**HEADLESS** renderer:

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

The `Native` job is **pinned to CNA commit `056e57d47`**, and not by preference:
`openeggbert/cna:next` does not currently build from published sources, because
its storage module calls a `sharp-runtime` member that has not been pushed. The
pin is that call's parent commit. Every run records the CNA and sharp-runtime
commits it landed on, in the step summary and in `qualification-run.json` inside
the run's artifact, and `workflow_dispatch` takes `cna_ref` and
`sharp_runtime_ref` for checking whether the two repositories have caught up.
`docs/qualification.md` has the policy and the evidence.

## Foundation 1 is release-ready, and frozen

**`FOUNDATION_1_RELEASE_READY = yes`.** The decision is about the *foundation as a
coherent milestone*, not about the scoreboard reaching zero. It never will: of the
54 non-complete members, 39 are held up by CNA 0.21.0, 6 by types the profile has
not selected, 5 by the Common Lisp projection, 3 by an object-model closure and 1
by a missing proof. The category table below is the whole of that, generated.

The eight conditions, and what each rests on:

| Condition | Evidence |
| --- | --- |
| All gates green | the gates in "Reproduce the state" and the table above, re-run at each audit; the suite reports no failure and nothing not run in all three native configurations, and in the fourth it reports the native layer as not run rather than as passed |
| No known ownership or lifetime defect | ownership stress, construction atomicity over twelve resource families, content transaction rollback at four injection points, callback registry empty after each cycle |
| Zero structural disagreements | `verify.py --strict`, over <!-- generated:diagnostic categories=18 --> diagnostic categories |
| No stale live-state documentation | two audits; the second is recorded below, and found what the first left behind |
| Admitted ABI set truthful | 0.21.0 only. 0.22.0 is audited, shape-identical, and **correctly not admitted** -- the blocker is reproducibility, re-measured a fourth time and unchanged |
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

<!-- generated:selected types=157 -->
<!-- generated:selected members=2332 -->
<!-- generated:complete types=141 -->
<!-- generated:partial types=16 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1854 -->
<!-- generated:partial members=19 -->
<!-- generated:missing members=35 -->
<!-- generated:not-applicable members=424 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 157 types, 2332 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **141** |
| Types partial | **16** |
| Types missing | **0** |
| Members complete | **1854** |
| Members partial | **19** |
| Members missing | **35** |
| Members not applicable | **424** |
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
| `CNA_0_21_ABI_LIMIT` | **39** | CNA 0.21.0 has no route for the member, or its route cannot express what the member means. |
| `PUBLIC_OBJECT_MODEL_CLOSURE` | **3** | Implementable against 0.21.0, but only as a new closure in this binding's object model rather than as a member. |
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
are classified `CNA_0_21_ABI_LIMIT`: they need a CNA release, not a commit here.
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

## What to do next: Audio

**One closure, and this file carries one.** When Audio lands, this section is
replaced by the next closure rather than added to.

Audio is next because it was measured to be, at the Foundation 1 release audit,
and the measurement said three things: both authorities are already pinned, CNA's
ABI is complete for it, and all of its qualification levels are reachable in CI
with no audio hardware.

**Nothing here is implemented and the selection has not grown.** Do not add these
types to `SELECTED` until the implementation lands with them: a selected type with
nothing behind it is a missing type, and "no selected type is missing" is a
property the release statement uses. This closure goes in whole, as every closure
here does.

### Both authorities are already pinned

`Microsoft.Xna.Framework.Audio.SoundEffect` and `SoundEffectInstance` are in
**`Microsoft.Xna.Framework.dll`** -- the assembly this project already pins by
SHA-256 and already reads behaviour from. No new assembly has to be found or
hashed. The 257-type contract snapshot carries **19 Audio types**, so the
structural authority is in place too.

### What CNA 0.21.0 actually has

`modules/c-api/include/CNA/C/audio.h` is 1241 lines and exports **74 routes**.
Inventoried whole rather than by guessing names, they fall into five families:

| Family | Routes | Enough for the XNA type? |
| --- | ---: | --- |
| `cna_sound_effect_*` | 25 | yes -- both `create_pcm16` forms, `from_encoded_ext`, `from_asset_ext`, `create_instance`, the four statics as get/set pairs, duration, the two sample-maths statics, name, type name, disposal |
| `cna_sound_effect_instance_*` | 15 | yes -- play/pause/resume/stop, volume/pitch/pan/looping, `get_info`, `apply_3d` and `apply_3d_multi_ext` |
| `cna_dynamic_sound_effect_instance_*` | 12 | a later closure; depends on this one |
| `cna_microphone_*` | 18 | a later closure, and needs hardware |
| `cna_audio_listener_init`, `cna_audio_emitter_init`, `cna_audio_get_capabilities`, `cna_audio_unsubscribe_ext` | 4 | yes |

`cna_content_manager_load_sound_effect` exists as well, so
`ContentManager.Load<SoundEffect>` is the canonical fifth loader route rather
than something to invent -- and `LOADABLE-ASSET-TYPES` and the README's rendered
block will pick it up on their own.

**Do not conclude a route is absent from one guessed name.** That mistake was made
three times in the graphics closure, each time about a route that was in the
header. Inventory the family.

### The dependency-complete selection this suggests

Eight types: **`SoundEffect`**, **`SoundEffectInstance`**, **`AudioListener`**,
**`AudioEmitter`**, **`SoundState`**, **`AudioChannels`**, and the two exceptions
**`NoAudioHardwareException`** and **`InstancePlayLimitException`**. Their
dependencies are already selected or already solved: `Vector3` and `TimeSpan`, and
a `Stream` for `SoundEffect.FromStream`, which is an ordinary Common Lisp binary
stream here.

**All eight verified against the pinned 257-type contract**, which carries 19
Audio types: 57 members exactly -- `SoundEffect` 17, `SoundEffectInstance` 16,
`AudioListener` 5, `AudioEmitter` 6, `SoundState` 4, `AudioChannels` 3, and 3 each
for the two exceptions, which are sealed and extend
`System.Runtime.InteropServices.ExternalException`. `SoundEffectInstance` is
**not** sealed -- `DynamicSoundEffectInstance` derives from it -- so its
projection must leave room for that subclass without projecting it. Once the
implementation starts, the generated report carries these numbers and this
paragraph is not the place to read them.

The other eleven Audio types stay out, and for reasons rather than by omission:
`AudioEngine`, `SoundBank`, `WaveBank`, `Cue`, `AudioCategory` and
`RendererDetail` are XACT, and **CNA has no route for any of them**;
`DynamicSoundEffectInstance` and the three `Microphone` types have full CNA route
families but are each a closure of their own, and the microphone one needs
hardware.

### The qualification levels are reachable, and this was measured

The task a sound test usually fails is being green because nothing happened.
CNA's design makes that avoidable: `cna_audio_get_capabilities` reports
`is_playback_available` as **data**, returning `CNA_RESULT_SUCCESS` either way,
and its header says so. Probed against the qualified HEADLESS library:

| Environment | Result | `is_playback_available` |
| --- | --- | --- |
| as the suite runs it | `SUCCESS` | **TRUE** -- a real device opens, even under HEADLESS |
| `SDL_AUDIODRIVER=dummy` | `SUCCESS` | **TRUE** -- SDL's dummy driver still opens a device, so this is *not* how to reach the unavailable branch |
| `SDL_AUDIODRIVER=nonexistent-driver` | `SUCCESS` | **FALSE** |

So every level is reachable and none has to be a skip. **SDL's audio driver
selection is process-global and latches at initialisation**, so the available and
unavailable branches cannot be qualified in one image: the unavailable lane has to
be its own process, with its own environment.

**Nothing above is a claim that a sound was heard, and no test may make one.** A
state transition, a duration and a native acceptance are what this can prove. A
dummy audio device is not audible hardware.

### After Audio

Models, media, storage, gamer services and networking are the remaining
namespaces. **Measure the next one rather than starting it**: Audio is a large
enough milestone to audit before expanding again, and the measurement is what
decides which comes next.

## Architectural facts a future agent must not undo

Each of these was arrived at by measurement and each has cost a mistake at least
once. `docs/limitations.md` carries the full reasoning; what is here is the
decision and the reason it is not an oversight.

**About the ABI**

* **ABI 0.22.0 is audited, shape-identical, and correctly not admitted.** All 328
  bound routes are still exported, the foreign layer regenerated against 0.22.0's
  headers is identical but for two version constants, and the compiler probe
  passes at `-Werror`. What is missing is a library anybody can build: `cna:next`
  calls `StoragePaths::SetIsolatedStorageRootOverride` and the sharp-runtime
  commit adding it, `c419f477`, is on **no remote branch**. Re-measured a fourth
  time at this audit and unchanged -- `cna:next` has moved on to `cb2c90208` and
  still makes that call, `sharp-runtime:next` is still `bd282d101`, and
  `git branch -r --contains c419f477` is still empty. That last command is the
  whole cheap re-check. **Do not admit 0.22.0 on local evidence.** The admitted
  set lives in `src/internal/abi-gate.lisp` for the runtime and in the manifest's
  `admitted_abi_versions` for the generator, and both move together.
* To reproduce the 0.21.0 gates, point `CNA_ABI_BASELINE` at a 0.21.0 baseline --
  `cnanext 2b0c374a1` is the last commit carrying one -- rather than at whatever
  the checkout is on today, or the generator refuses with "supplied headers
  declare ABI ... which the manifest does not admit", which is the gate working.
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
* **Disposal is not cascaded.** CNA requires children destroyed before parents and
  this binding reports a live child rather than deciding when a program's
  resources die.
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
