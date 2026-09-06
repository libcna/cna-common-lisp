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
```

The three qualification scripts do that for themselves. `with-virtual-screen.sh`
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
| Isolated consumer | CNA-Lisp loaded from the artifact, not the checkout |
| Native stress | 20 plain cycles + 20 graphics cycles, registry empty after each |
| Construction atomicity | an exploding subclass of twelve resource families, plus `Game` and `GraphicsDeviceManager`, leaves no live child and lets the game shut down -- and one that **subscribed before it failed** leaves no registration and no rooted token either |
| Content transaction | a load made to fail at the texture's storage query, the font's info, its glyph table, or the **cache insertion** gives every handle back exactly once |
| Render-target cross-check | six ways a remembered binding can drift are each refused; an unmutated one is accepted first |
| Model, on 0.22.0 and 0.23.0 | a `.cnj` fixture loads through `ContentManager.Load<Model>`, its three-bone hierarchy and two meshes answer XNA's object identity, the transform copies compose in the IL's order, and `Unload` leaves every view refusing |
| Model, on 0.21.0 | `Load<Model>` **refuses**, because `cna_model_destroy` on a loaded model is a null dereference there. Asserted as a result, not skipped |
| Model effect safety, all three | every one of the 17 bound routes that read a content-published effect's missing adapter state refuses with a condition. Enumerated from CNA's source, not listed by hand, and the count was four until this was measured |
| Model pixels | the SOFTWARE lane's `model` proof: two meshes of a loaded model each put their own colour on the pixels their own triangle covers |
| Microphone, unavailable | a driver that does not exist: no capture device enumerated, `Microphone.All` answered the empty list and `Microphone.Default` answered NIL -- which `audio.h` calls an ordinary answer, so this is a result and not a skip |
| Microphone, enumeration | `SDL_AUDIODRIVER=dummy`: capture devices enumerated, `All[i]` was the **same object** on every query, the returned list was fresh, and `Default` was `EQ` to an entry in `All` rather than a second object with equal slots |
| Microphone, state machine | the same devices: `:STOPPED -> :STARTED -> :STOPPED` through `Start` and `Stop`, and a repeated call of either accepted without moving the state |
| Microphone, capture data | the same devices: `GetData` wrote into **exactly** the range it reported, left every byte outside it unchanged -- including the rest of the requested range on a short read -- and advanced inside a justified window around what the device's own `SampleRate` implies |
| Microphone, BufferReady | the same devices: the event arrived, its sender was `EQ` to the object `All` and `Default` hand out, removing the handler released the native registration and stopped delivery, and the callback registry returned to its baseline |
| Microphone, public-only consumer | a complete capture session through the two exported packages alone, under a mechanical audit for the internal package, CFFI, handles, result codes and private `%`-symbols |
| Microphone, XNA over CNA | five measured disagreements between CNA and the pinned XNA behaviour, each asserted in **both** directions so a CNA that changed would fail a test rather than silently changing this binding |

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

## Four milestone statuses, and they are four

**One boolean must not cover several milestones**, which is why these are stated
separately and each names what it rests on:

| | |
| --- | --- |
| `FOUNDATION_1_IMPLEMENTATION_FROZEN` | **yes**. Its 35 missing and 19 partial members are unchanged, and every closure since has added types rather than reopening it. What later work has touched is shared *machinery*, additively, and each such change is named where it landed |
| `FOUNDATION_1_RELEASE_READY` | **yes**, decided at `5a7f7c1` and re-affirmed at each audit against the eight conditions below |
| `AUDIO_FOUNDATION_READY` | **yes**. Six complete types and three partial over nine types and 67 members, each partial with a measured reason; two lanes, neither claiming a sound was heard |
| `DYNAMIC_AUDIO_READY` | **yes**. `BufferNeeded` is complete for real now: its `+=` and `-=` match the IL before *and* after disposal, and a handler's condition is delivered rather than lost. Both were overclaimed until the pre-Model audit and both are fixed |
| `MODEL_READY` | **on 0.22.0 and 0.23.0**, and that is a measurement rather than a hedge: on 0.21.0 `Load<Model>` refuses because a loaded model cannot be released there, so the family has no public producer on that ABI. 0.23.0 was measured, not assumed -- it fixes the destroy defect that 0.22.0 already fixed, and fixes neither the effect-graph one |

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
| Admitted ABI set truthful | `{0.21.0, 0.22.0, 0.23.0}`, and all three are evidenced: the whole gate set is run against a real library of each at every closure, not once. 0.23.0 was admitted on 2026-09-06 against an exact published pair, after its ABI delta was diffed, its generated layer proved unchanged, and both gates were watched refusing it first |
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

<!-- generated:selected types=181 -->
<!-- generated:selected members=2468 -->
<!-- generated:complete types=159 -->
<!-- generated:partial types=22 -->
<!-- generated:missing types=0 -->
<!-- generated:complete members=1976 -->
<!-- generated:partial members=25 -->
<!-- generated:missing members=35 -->
<!-- generated:not-applicable members=432 -->
<!-- generated:disagreement total=0 -->

<!-- generated-block:selection -->
Selection **Foundation 1 and the managed closures**: 181 types, 2468 members.
<!-- /generated-block:selection -->

<!-- generated-block:scoreboard -->
| | |
| --- | --- |
| Types complete | **159** |
| Types partial | **22** |
| Types missing | **0** |
| Members complete | **1976** |
| Members partial | **25** |
| Members missing | **35** |
| Members not applicable | **432** |
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

### The candidates, re-measured against all three admitted ABIs

Type and member counts are the pinned 257-type contract's, recomputed here from
`xna40-windows-runtime-contract.json`. Route counts are
`grep -c '^CNA_C_API'` over each family's own headers, **in all three admitted
ABIs** -- and every one of them is identical in 0.21.0, 0.22.0 and 0.23.0, which
is the first thing 0.23.0's arrival changes about this table: it changes nothing.
0.23.0's one added route is `cna_decal_pass_is_supported`, in the engine layer.
**It unlocks no candidate.**

| Candidate | Types | Members | Routes (identical in all three ABIs) | Deps outside the selection | Hardware | New language design | Deterministic CI | User value | Complexity |
| --- | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- |
| `Microphone` | 3 | 21 | 18, in `audio.h` | `Byte[]`, `TimeSpan`, `Int32`, `String`, `Exception` -- all already projected | a capture device | **none** | **yes, both branches** | moderate | **low** |
| `Storage` | 3 | 35 | 49, `storage.h` | `IAsyncResult`, `AsyncCallback`, `Stream`, `FileMode`/`FileAccess`/`FileShare` | none -- the filesystem | **two open questions** | yes | high | medium |
| `Media` / `MediaPlayer` | 7 | 61 | ~80 of `media.h` + `media_player.h` | `Uri`, `Stream` | a playback device | none | yes | moderate | medium |
| `Media` / `MediaLibrary` | 15 | 142 | 148, `media_library.h` | 8 `IEnumerator<T>` instantiations, `IList<MediaSource>` | scans the machine | collection protocol | **empty only** | low | high |
| `Media` / `Video` | 2 | 20 | 42, `video.h` | `Stream` | an optional FFmpeg decoder | none | build-dependent | low | medium |

**The recommendation is `Microphone`, and the reason is new evidence.**

It was rejected last time because "its present branch has no capture equivalent of
`SDL_AUDIODRIVER=dummy` in either admitted ABI". **That is false, and it was
measured this time rather than repeated.** A probe that creates a game and asks
`cna_microphone_get_count` finds, on 0.23.0:

| `SDL_AUDIODRIVER` | devices | default | what it gives |
| --- | ---: | --- | --- |
| unset (this machine) | 3 | index 0, available | a real capture device |
| `dummy` | **2** | index 0, available | **a deterministic positive branch** |
| a name SDL cannot load | 0 | not available | the deterministic negative branch |

And the dummy device does not merely enumerate. Started, it reports
`sample_rate` 44100 and a one-second buffer, transitions `Stopped -> Started ->
Stopped` through `Start` and `Stop`, and over 180 frames answered **130
`GetData` reads totalling 266 240 bytes** -- against 264 600 expected for three
seconds of 44.1 kHz PCM16, so the *capture clock runs at the sample rate*, which
is a checkable claim rather than "a call succeeded".

**The bytes are silence**, every one of them zero. So Microphone would qualify
exactly the way Audio already does, with the same honesty and the same wording
discipline: a dummy capture device is not a microphone, and no test would say a
sound was heard. What it *can* say is that the device enumerated, the state
machine transitioned, the buffer duration round-tripped, and PCM arrived at the
rate the sample rate implies. That is a **full two-branch qualification**, not the
negative-capability-only qualification this family was assumed to be limited to.

It is also the smallest candidate by every measure -- 3 types, 21 members, 18
routes -- it needs no type the binding has not already projected, and it needs no
public API decision at all.

**Not `Storage`, and the reason is two open design questions rather than size.**
CNA has already collapsed XNA's fake-async pair: `storage.h` says in as many words
that "the canonical API uses XNA's fake-async `BeginXxx`/`EndXxx` pair, which CNA
completes synchronously", and the C route is one synchronous call whose optional
completion callback fires *before it returns*. So the C side is easy and the
projection is not:

1. **How does `BeginShowSelector`/`EndShowSelector` become Common Lisp?** Four
   `Begin` overloads and two `End` methods, plus `IAsyncResult` and
   `AsyncCallback`, neither of which is in the selection. Candidate designs: a
   literal `IAsyncResult` object projection; one idiomatic synchronous call with
   the `Begin`/`End` pair measured separately; a promise or future extension; a
   partial projection that implements `Begin` and refuses `End`. **Do not choose
   one in the task that implements it** -- the choice is a public API decision and
   deserves its own argument.
2. **What does `OpenFile` return?** `StorageContainer.CreateFile` and its three
   `OpenFile` overloads answer `System.IO.Stream`, and CNA backs that with eleven
   real `cna_storage_stream_*` routes. There is a precedent -- `SaveAsPng` and
   `FromStream` project `Stream` onto an ordinary Common Lisp binary stream -- but
   that precedent moves *byte arrays* across the boundary. A CNA-owned, seekable,
   readable-and-writable stream is a different object, and making it an ordinary
   CL stream means Gray streams. `ContentManager.OpenStream` is currently
   unimplemented precisely because "no stream object crosses CNA's C boundary";
   Storage is where one would have to.

Both questions are worth answering. Neither should be answered in passing.

**Not `Media` as one closure**, and the measurement says why: at 24 types and 223
members it is larger than everything added since Foundation 1 put together, and
it **splits cleanly into three sub-closures** whose XNA dependencies do not cross.
`MediaPlayer` (7 types, 61 members) is producible in CI -- `cna_song_create` takes
a file path, so a Song comes from a fixture and playback goes through the same
dummy audio device the existing lanes use. `MediaLibrary` (15 types, 142 members)
scans the machine's music and picture locations; `media_library.h` says an empty
library is an ordinary result, so CI can qualify *empty* and nothing else, and
fifteen collection types that are only ever empty are not a closure worth having
yet. `Video` (2 types, 20 members) needs CNA's optional FFmpeg decoder and answers
`CNA_RESULT_NOT_SUPPORTED` without it. If Media is ever done, `MediaPlayer` first
and alone.

**Do not implement the recommendation yet.** This is a measurement, and the next
task chooses.


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
