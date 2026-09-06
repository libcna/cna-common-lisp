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
| Audio, streaming unavailable branch | the same driver: `DynamicSoundEffectInstance`'s constructor **succeeded** anyway and took a buffer, and the refusal arrived at `Play`. Recorded because it is CNA's asymmetry with `SoundEffect`, not asserted away |
| Audio, state machine | `SDL_AUDIODRIVER=dummy`: a device opened with no speaker behind it, and play/pause/resume/stop transitioned |
| Audio, dynamic streaming | the same device: generated PCM16 submitted, the pending-buffer count observed rising to two, and the native streaming state machine observed consuming both while the game loop ran |
| Isolated consumer | CNA-Lisp loaded from the artifact, not the checkout |
| Native stress | 20 plain cycles + 20 graphics cycles, registry empty after each |
| Construction atomicity | an exploding subclass of twelve resource families, plus `Game` and `GraphicsDeviceManager`, leaves no live child and lets the game shut down -- and one that **subscribed before it failed** leaves no registration and no rooted token either |
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

**The four audio rows are four claims and not one**, for the same reason. That a
transport transitioned says nothing about whether a submitted buffer was ever
taken, and `tools/qualification/audio.sh` requires each kind of evidence by name
rather than reading one out of another. **`dummy device != speaker`**: the
strongest thing the streaming row supports is that generated PCM was accepted and
consumed by the native streaming state machine, and no test in this repository
says a sound was heard.

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
streaming closure added a third. The frontier is 57 members now, not the 54 it was
at the freeze, and the three that are not Foundation 1's are `SoundEffect.Duration`,
`SoundEffectInstance.Apply3D(AudioListener[], AudioEmitter)` and
`DynamicSoundEffectInstance.new(Int32, AudioChannels)`. **Foundation 1's own 54
are unchanged**, which is the claim the freeze actually rests on: still 35 missing
and 19 partial there, still no missing type, still no disagreement.

The decision was about the *foundation as a coherent milestone*, not about the
scoreboard reaching zero. It never will: of the 57, 41 cannot be represented
across the admitted ABI set, 6 need types the profile has not selected, 5 are held
up by the Common Lisp projection, 3 by an object-model closure and 2 by a missing
proof. Regenerate that split from `tools/api-compat/mapping-rules.json` rather
than reading it here -- it has been stale once.

The eight conditions, and what each rests on:

| Condition | Evidence |
| --- | --- |
| All gates green | the gates in "Reproduce the state" and the table above, re-run at each audit; the suite reports no failure and nothing not run in all three native configurations, and in the fourth it reports the native layer as not run rather than as passed |
| The freeze holds | Audio landed after it, twice, and changed no Foundation 1 member: still 35 missing and 19 partial *there*, still 0 missing types, still 0 disagreements. The whole-binding partial count is 22 because Audio owns three of them |
| No known ownership or lifetime defect | ownership stress, construction atomicity over twelve resource families, content transaction rollback at four injection points, callback registry empty after each cycle |
| Zero structural disagreements | `verify.py --strict`, over <!-- generated:diagnostic categories=18 --> diagnostic categories |
| No stale live-state documentation | three audits now. The third ran with the streaming closure and found four survivals the first two missed: `LOAD-ASSET` still promising two objects for one name, `UNLOAD` still telling a program to dispose what the manager now disposes, `docs/ownership-and-lifetimes.md` still describing the pre-cache content model, and this section's own claim that Audio contributed no frontier members. The first two are **public generated documentation** -- they are dumped into `docs/generated/public-surface.json` -- which is what makes them a release-condition failure rather than a comment |
| Admitted ABI set truthful | `{0.21.0, 0.22.0}`, and both are evidenced: the whole gate set is run against a real library of each at every closure, not once. `cna:next` is 0.23.0 and is **correctly not admitted** -- nothing here has run against it, and the measurement at the end of this file is of its headers rather than of a run |
| CI green | both workflows `success`, and named by run id below rather than by "the latest run" |
| Qualification wording no stronger than its evidence | the SOFTWARE lane's claims are rendered from the registry the lane enforces, and every required proof must also be *described* |
| Every non-complete member has a concrete reason | 57 of 57, each naming a route or an IL fact, each in one of seven categories, with **zero** in either implementable category. `verify.py` refuses an uncategorised one and refuses a category the taxonomy does not define, which is what carried the `CNA_0_21_ABI_LIMIT` rename |

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
| `Lisp` | [33968261788](https://github.com/libcna/cna-common-lisp/actions/runs/33968261788) | `5a7f7c1` | **success** |
| `Native` | [33968261886](https://github.com/libcna/cna-common-lisp/actions/runs/33968261886) | `5a7f7c1` | **success** |

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
  and that closure is over.

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

<!-- generated:selected types=178 -->
<!-- generated:selected members=2447 -->
<!-- generated:complete types=156 -->
<!-- generated:partial types=22 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1957 -->
<!-- generated:partial members=25 -->
<!-- generated:missing members=35 -->
<!-- generated:not-applicable members=430 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 178 types, 2447 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **156** |
| Types partial | **22** |
| Types missing | **0** |
| Members complete | **1957** |
| Members partial | **25** |
| Members missing | **35** |
| Members not applicable | **430** |
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
| `M.X.F.Audio.DynamicSoundEffectInstance` | 0 | 1 |
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
| `LANGUAGE_PROJECTION_LIMIT` | **5** | The Common Lisp projection cannot express the member, or the type it needs has no counterpart a Lisp program could use safely. |
| `CNA_ADMITTED_ABI_LIMIT` | **44** | No admitted CNA ABI can represent the member. |
| `PUBLIC_OBJECT_MODEL_CLOSURE` | **3** | Implementable against every admitted CNA ABI, but only as a new closure in this binding's object model rather than as a member. |
| `DEPENDENCY_NOT_SELECTED` | **6** | Blocked on a type that is not in the selected profile. |
| `QUALIFICATION_LIMIT` | **2** | Implemented, but some part of it cannot be evidenced, so it is not claimed complete. |
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
sentence is byte for byte the same in both admitted ABIs -- the whole of
`audio.h` is. There is no dynamic *destroy* route in either, and that is not an
omission. What XNA overrides is exactly two members and both are projected as
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

## What to do next

**One closure, and this file carries one.** When the next one lands, this section
is replaced rather than added to. The streaming closure that used to be
recommended here has landed and its recommendation is deleted rather than left to
age; what it did is recorded above, under Audio.

### The four candidates and one infrastructure task, measured

Type and member counts are the pinned 257-type contract's. **Route counts are
`grep` over both admitted ABIs' headers, not one of them**, because the previous
measurement counted 0.22.0 only and the binding admits a set. Every determinism
claim names the header sentence it rests on.

| | Types | Members | Routes 0.21 | Routes 0.22 | Deps outside the selection | Hardware | Deterministic in CI |
| --- | ---: | ---: | ---: | ---: | --- | --- | --- |
| `Model` family | 12 | 48 | 133 | 133 | none | **none** | **yes** |
| `Microphone` family | 3 | 21 | 18 | 18 | none | a **capture** device | half |
| `Storage` | 3 | 35 | 35 | 35 | `IAsyncResult`, `AsyncCallback`, `FileMode`/`FileAccess`/`FileShare` | none -- the filesystem | **yes** |
| `Media` | 24 | 223 | 267 | 267 | none | a playback device; `MediaLibrary` scans the machine | half |
| Admit CNA **0.23.0** | -- | -- | -- | -- | -- | none | **yes** |

**The both-ABI column is not a discriminator, and measuring it is what says so.**
The two admitted header trees differ in exactly six files:
`abi.h` (the version constant), `graphics.h` (six new renderer identity
constants), `net_sessions.h` (one added route), `devices.h` and `engine_layer.h`
(documentation corrections), and `runtime.h` (a *behavioural* documentation
change to `cna_launch_parameters_add`, from "overwrites an existing entry" to
"keeps its first value"). None of the four candidates' route families differs at
all, and the one behavioural change is to a route this binding does not bind. So
no candidate is version-dependent and none needs a fallback. That had to be
checked rather than assumed: it is exactly the check the streaming closure's route
matrix turned out to need and pass.

**Two entries in the previous measurement were wrong and are corrected here.**
`Storage`'s dependency was recorded as `IAsyncResult` alone; it is also
`System.AsyncCallback` and three `System.IO` enumerations, which is more BCL
surface to decide about, not less. And `Media`'s route count was recorded as 270
against a family that answers 267 to the same `grep`.

### The recommendation: the `Model` family

It is the only candidate that is **fully qualifiable with no hardware of any
kind** and also adds a capability, and it is the last one on this list of which
that is true.

* **Every level of qualification is reachable.** HEADLESS proves the lifecycle
  and the ownership graph; the SOFTWARE lane can prove a drawn mesh reaches the
  pixels its geometry covers, exactly the way it already proves a
  `DrawUserPrimitives` triangle does. Nothing in it needs a device that a
  verification tree may not have.
* **It is the largest missing capability.** 133 routes are waiting in both
  admitted ABIs, and a binding that can draw a triangle but cannot load a mesh is
  missing the thing most XNA programs are actually built around.
* **Its projection novelty is settled work rather than new work.** Four
  collection-and-enumerator pairs, and this binding has already projected
  `CurveKeyCollection`, `DisplayModeCollection` and `GameComponentCollection`.
* **Its one real cost is a `.cnb` model fixture**, and that decision is now
  better informed than it was. `tools/qualification/` already generates a font
  and a wave byte for byte, so a generated model is the same kind of work at a
  larger size, and CNA's CNB writer routes are bound-able. Worth knowing before
  starting: `cna_model_create` and `cna_model_create_with_parents` exist in both
  admitted ABIs, so the *ABI* can build a model from bone and mesh handles with
  no container at all -- but XNA's `Model` has no public constructor, so a
  *public-surface* qualification of `ContentManager.Load<Model>` still needs the
  fixture. The two are different claims and the closure needs both.

**Not `Microphone`, for the reason it was not chosen last time and one more.**
`cna_microphone_get_count`'s header says a machine with no capture device
"answers zero, which is an ordinary answer and the one every verification tree
gives", so the *absent* branch is deterministic and the *present* branch is not
reachable in CI -- there is no capture equivalent of `SDL_AUDIODRIVER=dummy` in
either admitted ABI. Its buffer-ready event would now cost almost nothing, since
`add-buffer-needed-handler` proved the audio event machinery, but that makes the
qualifiable half cheaper without making the unqualifiable half reachable.

**Not `Storage`**, which is smaller than `Model` and asks a bigger question. Its
four public members are `BeginShowSelector`/`EndShowSelector` and
`BeginOpenContainer`/`EndOpenContainer`, the .NET asynchronous pair returning
`IAsyncResult`. CNA has already collapsed them --
`cna_storage_device_show_selector` "collapses the canonical
`BeginShowSelector`/`EndShowSelector` pair, which CNA completes synchronously; no
operation handle is invented for work that never pends" -- so the projection is
possible and needs a *decision* about how an async pair becomes one Common Lisp
call, plus a decision about three `System.IO` enumerations. That is a public API
decision rather than an implementation, and it should not be made in the same
task that implements it.

**Not `Media`**, which is larger than everything this binding has added since
Foundation 1 put together, and whose interesting half -- a library with music in
it -- cannot be produced in CI any more than a microphone can.

### The infrastructure task, and why it is not the recommendation

**Admitting CNA 0.23.0 is measured to be cheap**, and that is worth writing down
even though it is not being done. The 0.22.0-to-0.23.0 delta is three files:
`abi.h`'s version constant, one added route (`cna_decal_pass_is_supported`, in
`engine_layer.h`, which this binding does not bind), and documentation
corrections in `models.h` and `engine_layer.h`. **No route this binding binds
changed**, so the expected cost is a build of the 0.23.0 library and a gate run,
with no code change -- which is precisely what the admitted-set machinery was
built for.

It is still not the next closure. Chasing a moving branch is a task that never
finishes and never adds a member, and the version policy in
`docs/qualification.md` exists so that the binding can *notice* an ABI move
without having to follow every one. Do it as a side task when a 0.23.0 library is
built for some other reason.

**CNA 0.23.0 is not admitted and not qualified.** Nothing in this repository has
run against it, and this section is a measurement of headers rather than a run.

**Do not implement the recommendation yet.** This is a measurement, and the next
task chooses.

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
