# Qualification: what each claim means, and what it does not

"Tested" is not one thing. This document defines the words the rest of the
repository uses, so that a green tick somewhere never gets read as a stronger
claim than the run behind it supports.

## The terms

| Term | Meaning |
| --- | --- |
| `REFERENCE_QUALIFIED` | Run on the reference runtime — **SBCL 2.5.2, Linux x86-64** — against a qualified CNA C ABI shared library. This is the configuration the capability statement in `README.md` is about. |
| `CI_TESTED` | Run by GitHub Actions on a runtime or a configuration that is *not* the reference one. Real evidence, and a weaker claim: a green `CI_TESTED` job says the code also works there, never that the reference qualification covers it. |
| `HEADLESS` | Executed against a CNA build whose renderer is `HEADLESS`. Proves the lifecycle ran and that draw commands were submitted and accepted. Proves **nothing** about pixels. |
| `NOT RUN` | A gate that did not execute, with the reason. Never written as a pass. |

Nothing in this repository may collapse two of those into "fully tested".

## The runtimes, and why there are two

The reference runtime is SBCL **2.5.2** on Linux x86-64. Ubuntu 24.04 — the CI
runner image — packages SBCL **2.2.9**. Those are different runtimes, three years
apart, and a suite that passes on one has not been run on the other.

So CI runs both, in jobs that say which is which:

| Job | Runtime | Claim |
| --- | --- | --- |
| `Lisp` / reference | SBCL 2.5.2, installed from the upstream binary release and verified by SHA-256 | `REFERENCE_QUALIFIED` runtime, pure-Lisp gates |
| `Lisp` / distro | whatever `ubuntu-24.04` packages; the job prints the exact version | `CI_TESTED` — a secondary compatibility test, not the reference qualification |
| `Native` | SBCL 2.5.2, the same pinned binary release | the reference runtime, against a CNA C ABI built in the job |

`.github/actions/reference-sbcl` is the one place the reference runtime is
installed, and the version and its SHA-256 are pinned there. A substituted
tarball fails the checksum rather than quietly becoming "the reference runtime".

Locally, the reference runtime is Debian's build of the same upstream release
(`SBCL 2.5.2.debian`). Same version, different packaging; both are 2.5.2.

## The CNA source

The intent is to follow a moving branch: `libcna/cna`, branch `next`. That
is where the CNA C ABI lives, and pinning by preference would mean the binding
stops noticing the day CNA's ABI moves — which is the one thing this
qualification exists to notice.

**It has since moved twice.** CNA bumped the ABI to **0.22.0** on 2026-09-04 and
to **0.23.0** later the same day. This binding admits **{0.21.0, 0.22.0, 0.23.0}**,
and all three members of that set are qualified.

### ABI 0.22.0 is admitted, and this is the evidence

Qualified on 2026-09-05 against an exact, published source pair:

| | |
| --- | --- |
| CNA | `fb62662c9536f30a6a8bd080597002b8443b28d4` — on `origin/next`, the newest commit there whose headers declare 0.22.0 (the parent of `e18854238`, which raises the ABI to 0.23.0) |
| sharp-runtime | `bfc826e1fa7eef1adb36df1c64782e9939a0af37` — `origin/next`, which declares and defines `StoragePaths::SetIsolatedStorageRootOverride` |

Neither is a local commit and neither tree was patched: both are detached
worktrees of the published branches, and `git status` is clean in each. The
HEADLESS and SOFTWARE libraries were built from that one tree with
`-DCNA_BUILD_C_API=ON -DCNA_PLATFORM=SDL3 -DCNA_AUDIO_PLATFORM=SDL3` and the two
renderer settings, against `-DCNA_SHARP_RUNTIME_ROOT` pointing at the
sharp-runtime worktree above.

What was run against a real 0.22.0 library built from that pair:

| Gate | Result |
| --- | --- |
| Headers declare 0.22.0 | encoded **5632**, and `tools/c-api/abi_baseline.json` agrees |
| Every bound route exported | **496 of 496**, none absent from the built library's 4055 exported symbols |
| Generated foreign layer regenerated against 0.22.0's headers | **identical** but for the four version constants — every prototype, struct size, alignment, field offset and field size, every other constant and all ten callback typedefs byte for byte the same |
| Compiler-backed probe, 0.22.0 headers | **passes** at `-Wall -Wextra -Werror -Wpedantic` |
| The gate accepts it | `ENSURE-ABI-ADMITTED` answers 0.22.0 |
| Whole suite, HEADLESS, native + shim | **0 failures, nothing not run** |
| Whole suite, HEADLESS, no shim | **0 failures, nothing not run** |
| Audio lanes, in separate processes | unavailable branch and dummy-driver state machine, both as on 0.21.0 |
| Isolated consumer, 60 and 600 frames | passes |
| Whole suite, SOFTWARE, with the rasterizer proof registry | **0 failures, nothing not run**, and every proof kind the registry requires |

**That table is the record of one dated run and its numbers are that run's**, not
live ones: the bound-route count in particular has grown since, because
`DynamicSoundEffectInstance` landed afterwards and brought seven more routes and
one more callback with it. The gate set is re-run against **both** admitted
versions at every closure -- the streaming closure's own run added a fourth audio
lane, `AUDIO_DYNAMIC_UNAVAILABLE`, and a fifth kind of evidence,
`AUDIO_DYNAMIC_STREAMING` -- and `README.md`'s generated block carries the current
route count. Reproduce, do not read off.

**And 0.21.0 was re-run after the set grew**, because admitting a second version
is a change to the first one's gate as well: the same suite, the same audio lanes
and the same consumer against the 0.21.0 library, all green, with
`ENSURE-ABI-ADMITTED` answering 0.21.0. The admitted set is a set, and both
members are evidenced.

**Making the set a set needed three fixes**, each of which had silently assumed
one version. `generate.py --check` compared the generated layer byte for byte, so
it could only ever pass against the version the checked-in files were generated
from; `probe.generated.c` asserted `CNA_ABI_VERSION == 5376` in C; and
`the-admitted-set-is-explicit-and-small` asserted a set of exactly one. The four
ABI-version constants are now compared and asserted as *an admitted version*
rather than one particular one — and nothing else is relaxed, so a version that
changed a route, a layout or any other constant still fails. Verified by breaking
it.

### ABI 0.23.0 is admitted, and this is the evidence

Qualified on 2026-09-06 against an exact, published source pair:

| | |
| --- | --- |
| CNA | `5c8840657caa448149af9374b96bbd6acee354a1` — `origin/next`, the tip, and the newest commit whose headers declare 0.23.0 |
| sharp-runtime | `bfc826e1fa7eef1adb36df1c64782e9939a0af37` — `libcna/sharp-runtime:next`, unchanged since 0.22.0 was qualified against it |

Neither is a local commit and neither tree was patched; `git status` is clean in
each. Both libraries were built from that one tree with
`-DCNA_BUILD_C_API=ON -DCNA_PLATFORM=SDL3 -DCNA_AUDIO_PLATFORM=SDL3` and the two
renderer settings, against `-DCNA_SHARP_RUNTIME_ROOT` pointing at the
sharp-runtime worktree, and both report encoded **5888**.

**The ABI delta was measured before the build.** Three headers differ from
`fb62662c9`: `abi.h`'s minor version; one added route,
`cna_decal_pass_is_supported`, which this binding does not bind; and
documentation in `models.h`. No struct, field, constant, callback, ownership
annotation or by-value aggregate changed, and nothing was removed. So the
generated layer had to be identical apart from the version constants, and it is —
verified with a throwaway manifest **before** the admission, so that a change
would have stopped it rather than arriving inside it.

**Both gates were watched refusing 0.23.0 first**, while the set was still two:
the C probe fails its `_Static_assert` against 0.23.0's headers, and
`ENSURE-ABI-ADMITTED` rejects the library by name.

| Gate | Result |
| --- | --- |
| Headers declare 0.23.0 | encoded **5888**, and `tools/c-api/abi_baseline.json` agrees |
| Generated foreign layer regenerated against 0.23.0's headers | **identical** but for the four version constants — 572 functions, 73 structs, 511 constants, 11 callbacks, the same as 0.21.0 and 0.22.0 |
| Compiler-backed probe, 0.23.0 headers | **passes** at `-Wall -Wextra -Werror -Wpedantic` |
| The gate accepts it | `ENSURE-ABI-ADMITTED` answers 0.23.0 |
| Whole suite, HEADLESS, native + shim | **0 failures, nothing not run** |
| Whole suite, HEADLESS, no shim | **0 failures, nothing not run** |
| Whole suite, SOFTWARE, with the rasterizer proof registry | **0 failures, nothing not run**, and every one of the nine required pixel proofs |
| Audio lanes, in separate processes | all four: unavailable, dynamic-unavailable, dummy-device state machine, dynamic streaming |
| Structural verifier, strict | 178 types / 2447 members, **0 disagreements** |
| Isolated consumer, 60 and 600 frames, HEADLESS and SOFTWARE | passes, and the SOFTWARE run asserts the triangle's own pixel |

**And 0.21.0 and 0.22.0 were re-run after the set grew**, because admitting a
third version changes the other two's gate as well: both 0 failures with nothing
not run, each with `ENSURE-ABI-ADMITTED` answering its own version.

**Making the set three needed two test edits**, the same class of thing making it
two needed three of. `the-admitted-set-is-explicit-and-small` asserted a length of
2, and `the-loaded-library-is-one-of-the-two-admitted-versions` carried two
literals in its body and a count in its name. Both keep their literals on purpose
— that is what makes growing the set an edit a reviewer sees rather than a
consequence of a version bump — and the second was renamed, because a name that
says "two" about three versions is a name that lies.

### Three admitted versions, and what CI runs against which

Admitting a third version is an invitation to triple the CI bill, and this
project does not take it — because it never ran all of them on every push in the
first place. The shape was already right and is now written down rather than
implied:

| When | Against what |
| --- | --- |
| Every push and pull request | the **newest admitted** ABI, pinned to its exact qualified commit: the whole `native` job (HEADLESS, gate, suite, consumer) and the whole `rasterizer` job (SOFTWARE, pixels) |
| On demand, `workflow_dispatch` with `cna_ref` | any other admitted version, or `next` to measure a bump before it is admitted |

**Measured before deciding.** A `Native` run takes three to five minutes with a
warm ccache, and its cache key is the resolved CNA commit — so a second ABI is
not a marginal cost, it is a second CNA build from a cold cache. Two more ABIs on
every push would buy re-running gates against libraries that did not change,
paid for on every documentation commit.

**The release standard is not weakened by that.** Before this binding is
described as compatible with an admitted ABI, the full gate set must have run
against that exact ABI — every push is not the only occasion that can happen on,
and `docs/qualification.md` records which run it did happen on for each of the
three. What the per-push job buys is early warning on the version most likely to
move; what the dispatch runs buy is the claim itself.

### What differs between the admitted versions, in behaviour this binding sees

Not a route-by-route matrix: only the differences that reach the public surface.

| | 0.21.0 | 0.22.0 | 0.23.0 |
| --- | --- | --- | --- |
| `cna_model_destroy` on a content-loaded model | **null dereference at 0x490** | works | works |
| A process that merely *loaded* a model exiting | **faults after `cna_game_destroy` returns 0** | clean | clean |
| `ContentManager.Load<Model>` in this binding | **safe refusal**, naming the defect and 0.22.0 | works | works |
| The `model` pixel proof | **not obtainable** — no model can be loaded | produced | produced |
| A content-published `Effect`'s graph and texture routes | **null dereference** | **null dereference** | **null dereference** |
| The remedy — assign your own effect to the part | n/a, no model | works | works |

The second row is the one worth stating separately: on 0.21.0 the fault is not
confined to the destroy call. The subprocess probe's `baseline` stage loads a
model, touches nothing, and still dies at 0x490 after teardown reported success.

**0.23.0 fixes neither defect that this binding refuses for.** It fixes nothing
here at all — its one added route is in a family this binding does not bind. It is
admitted because it is *compatible*, which is the only thing admission claims.

### Why the `Native` workflow is still pinned, and to what

`CNA_REF` defaults to `fb62662c9536f30a6a8bd080597002b8443b28d4` — the 0.22.0
commit above.

**The old reason for a pin is gone.** Between 2026-09-04 and 2026-09-05 the pin
existed because `cna:next` did not build from published sources at all:
commit `822d3b960` made `modules/storage/src/StorageDevice.cpp` call
`SharpRuntime::Storage::StoragePaths::SetIsolatedStorageRootOverride`, the
sharp-runtime commit adding it had not been pushed, and the build failed eleven
minutes in with `'SetIsolatedStorageRootOverride' is not a member of
'SharpRuntime::Storage::StoragePaths'` — workflow run 33841079977 is that
evidence. `sharp-runtime:next` caught up on 2026-09-05 (`bfc826e1`), and that
blocker is closed.

**The reason now is the ABI gate working.** `cna:next` is ABI 0.23.0, which this
binding does not admit, so an unpinned job would fail the gate on its first run —
correctly, and with nothing to fix but a decision. Pinning to the newest *admitted*
commit on the branch is what following `next` means while the gate is the thing
that decides.

This is still not a preference for reproducibility. When 0.23.0 is audited and
qualified the pin moves again, and `workflow_dispatch` with `cna_ref: next` is how
to measure the tip without making it the default.

**Reproducing either half of the admitted set:**

* **0.22.0** — the default. Nothing to pass.
* **0.21.0** — `workflow_dispatch` on `Native` with
  `cna_ref: 056e57d478f8e6accfa9124337803e735b39f1e4`. That commit is on
  `origin/next`, is ABI 0.21.0, carries every route the manifest binds, and is
  what this workflow qualified against until 2026-09-05.

Locally, either is `CNA_NATIVE_LIBRARY`, `CNA_HEADERS` and `CNA_ABI_BASELINE`
pointed at the matching build; the generator refuses a mismatch by name.

Following a branch, or a pin, is only honest if every run records where it
actually landed. So the `Native` workflow:

1. resolves `CNA_REF` to a commit immediately after checkout;
2. writes the requested ref, the resolved CNA commit, the sharp-runtime commit,
   the template commit and the CNA-Lisp commit into the run's step summary;
3. writes the same facts, plus the runtime version and the CNA build
   configuration, into `qualification-run.json` in the run's uploaded artifact.

`workflow_dispatch` takes `cna_ref` and `sharp_runtime_ref` inputs, so a specific
pairing can be qualified on demand without editing the workflow.

### sharp-runtime is CNA's unpinned dependency, and therefore ours

CNA consumes `sharp-runtime` as a *sibling checkout*, with `add_subdirectory` and
no recorded revision. CNA's own `CHANGELOG.md` says so in as many words --
"`sharp-runtime` is the exception and is not pinned by the build ... Recording the
revision here is a stopgap" -- so the pairing is the consumer's to make.

Getting it wrong is not a version error. It is a compile error a long way inside
CNA: building `libcna/cna:next` against `sharp-runtime`'s default `develop`
branch fails in `modules/storage/src/StorageDevice.cpp` with
`SetIsolatedStorageRootOverride is not a member of StoragePaths`, eleven minutes
into the build. `libcna/cna:next` needs `libcna/sharp-runtime:next`.

So the workflow checks out `sharp-runtime` at `SHARP_RUNTIME_REF`, records the
commit it resolved to next to the CNA one, and takes a `sharp_runtime_ref`
dispatch input for qualifying a different pairing.

**And `SHARP_RUNTIME_REF` is now an exact commit too, because following the
branch was caught qualifying an undocumented pair.** It defaulted to `next` until
2026-09-06. In run **34041187578** — the first run after 0.23.0 was admitted —
`CNA_REF` was the exact qualified 0.23.0 commit and `next` resolved to
sharp-runtime **`30ccdef3`**, one commit past the `bfc826e1` every document here
names, pushed while the 0.23.0 qualification was running. The run passed, so
nothing was broken except the claim: CI had qualified a pair no document
describes, and the only reason anyone noticed is that the run records the commits
it resolved.

A pair is two commits, and pinning one of them is half a pin. The half CNA leaves
unpinned is exactly the half most likely to move without anyone deciding to move
it, so it is pinned here now. This is not a CNA defect; it is a documented property of how CNA is
built, and the remedy belongs here.

**An ABI artifact whose CNA commit was not recorded is not qualification
evidence**, and no document here may describe one as qualified.

## The CNA build this qualification uses

| | |
| --- | --- |
| Platform backend | `SDL3` |
| Audio backend | `SDL3` |
| Renderer | `HEADLESS` |
| C API | `CNA_BUILD_C_API=ON`, tests and examples off |
| ABI version admitted | 0.21.0 only |

CNA's vendored SDL submodules are initialised non-recursively and by name —
`third_party/SDL`, `third_party/SDL_image`, `third_party/SDL_mixer`,
`third_party/draco` — because CNA's own configure-time message says a recursive
init only adds nested codec submodules this build disables anyway.
`vendor/googletest` is not initialised, because `CNA_BUILD_TESTS` is off.

## The two native lanes

| Lane | Renderer | What it proves |
| --- | --- | --- |
| `Native` | `HEADLESS` | the lifecycle ran, handles were valid, and draw commands were submitted and accepted. **Nothing about pixels**, and the back-buffer readback refuses by name rather than answering zeroes. |
| `Rasterizer` | `SOFTWARE` | the same suite, plus <!-- generated:rasterizer proof count=9 --> separate kinds of pixel proof — see below. |

The rasterizer lane's proofs are kept apart because they are different claims,
and one of them used to be asserted on the strength of the other:

| Proof | What is actually done | What it establishes |
| --- | --- | --- |
| `clear` | clear to CornflowerBlue, read the back buffer | `GraphicsDevice.Clear` reaches the back buffer and the readback returns those pixels |
| `sprite` | clear, then draw a generated 8×8 fully opaque texture to an 8×8 destination at (16,16) with `BlendState.Opaque`, `SamplerState.PointClamp`, `Color.White`, no rotation/scale/origin — then read the corners of that rectangle *and* the pixels immediately outside it | **`SpriteBatch.Draw` rasterises**: the texture's own texels land on exactly the pixels its destination names, and on none outside them |
| `sprite` | the same with a generated 4×4 texture of four differently-coloured 2×2 quadrants | orientation and sampling are right, not merely placement — a flipped or transposed sample would fail |
| `primitive` | clear, make a `BasicEffect`, apply its one pass, then one `DrawUserPrimitives` triangle list in clip space — World, View and Projection left at the identity CNA reports as their default, `VertexColorEnabled` on and lighting off — then read four points inside the triangle and five outside it | **the primitive pipeline rasterises**: the vertices' own colour lands on the pixels the geometry covers and on none outside it, and no matrix setter and therefore no optional shim takes part in the proof |
| `text` | clear, then `DrawString` of `"AB"` at (16,16) with a `SpriteFont` over a generated 16×8 atlas whose two glyph cells are **different colours** — `'A'` red, `'B'` green — under `BlendState.Opaque`, `SamplerState.PointClamp`, `Color.White`, unit scale, no rotation and no origin; then read inside both glyphs and outside the run | **`SpriteFont` metrics and `DrawString` layout reach pixels**: the second glyph reads **green** eight pixels right of the first, which is the advance *and* the per-glyph atlas rectangle in one assertion — red there would mean the second glyph was cut from the first one's cell, and the clear colour would mean the pen never advanced |
| `render-target-data` | clear a bound 16×16 `RenderTarget2D` to red and read every texel back with `Texture2D.GetData` | **a render target's pixels are readable without any back buffer**: `GetData` reads a texture. The only pixel claim here that does not go through `GetBackBufferData`, and the first that a renderer with no readback could in principle produce — `HEADLESS` still refuses it and the test asserts the refusal by name |
| `render-target` | clear the back buffer, bind a 16×16 `RenderTarget2D`, clear *it* to red, read the back buffer before anything else, then restore, draw the target onto the back buffer as a texture and read again | **a render target redirects drawing and keeps its contents**: the red clear did not reach the screen, the restore worked, and the target's own pixels are samplable. The first evidence here that does not depend on the back-buffer readback being the only way to see a pixel |
| `stock-effect` | clear, make an `AlphaTestEffect` (then a `SkinnedEffect`), apply its pass, draw the same clip-space triangle through it, read inside and outside | **each is a usable draw effect**: its technique graph, its pass and the draw through it all work, and the triangle's own colour lands where its geometry is. **Not** the alpha test and **not** skinning — `docs/limitations.md` measures why neither is reachable under this renderer |
| `loaded-text` | the same `"AB"` draw, with the `SpriteFont` obtained through `ContentManager.Load<SpriteFont>` from a `.cnj` descriptor on disk — no test-only producer anywhere in the path — and asserted at the same coordinates as the hand-built font | **the public content path yields a font that draws the same pixels**: the descriptor, the loader, the glyph table CNA hands back and the layout all agree with the font the suite builds itself. A descriptor that drifted from the suite's glyph rows would put a glyph somewhere else and fail |
| `text` | the same with `"A\nA"` | the line advance is `LineSpacing` (12) and not the glyph height (8): the second line's glyph reads red twelve rows down, and the four rows between the two eight-row glyphs stay the clear colour, which an advance of 8 would have filled |
| `model` | clear, load `three-bone-triangles` through `ContentManager.Load<Model>`, replace each mesh part's effect with one `BasicEffect` (`VertexColorEnabled` on, lighting off), call `ModelMesh.Draw` on both meshes, and read three points inside each triangle and four outside both | **a loaded model's own geometry rasterises**: the vertex and index buffers the *model* owns feed the pipeline through the three calls `ModelMeshPart.Draw` makes, and the two meshes are **two colours**, so a pixel says which mesh drew it — one mesh drawing twice, or neither drawing, reads differently from both drawing. The vertices are clip-space, so World, View and Projection stay at identity and no matrix setter and therefore no optional shim takes part. The effect is replaced first because a model still carrying the one its loader published cannot be drawn at all; `docs/limitations.md` measures why |

The textures are **generated**, not drawn:
`tools/qualification/make-pixel-fixtures.py` states every texel in source, so the
expected colours are checkable without opening an image editor.

**The required set is written down once**, in
`tools/qualification/rasterizer-proofs.json`, and everything else derives from
it. `rasterizer.sh` requires exactly those kinds *and* refuses a run that produces
a kind the registry does not name, so the set cannot drift in either direction;
`tools/qualification/verify-numbers.py` renders the count and the table below from
the same file. Before that the list existed in three places — a comment in the
script, the script's own loop, and the prose — and the three disagreed: the
comment said seven, the loop required eight, and one document still said four.

<!-- generated-block:rasterizer-proof-kinds -->
9 kinds -- `clear`, `sprite`, `primitive`, `text`, `loaded-text`, `stock-effect`, `render-target`, `render-target-data` and `model`.
<!-- /generated-block:rasterizer-proof-kinds -->

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

So the lane cannot pass on a clear alone, the sprite path cannot stand in for the
primitive path — they are different paths through the renderer — and neither
stands in for text, because one font atlas texel arriving is a smaller claim than
a string being laid out. Verified in both directions: it exits 1 against a
`HEADLESS` library and 0 against a `SOFTWARE` one.

They are separate jobs on purpose. They support different claims, and a failure
in one must not take down the other.

**The rasterizer lane needs no display and no Xvfb.** `SOFTWARE` is a CPU
rasteriser: a CNA configured with `-DCNA_GRAPHICS_RENDERER=SOFTWARE` runs
headlessly in the ordinary sense of the word while still producing real pixels.
That was measured before the lane was written, not assumed.

The lane cannot degrade quietly. `GraphicsDevice.GetBackBufferData` is the member
that reads pixels, and CNA answers `CNA_RESULT_NOT_SUPPORTED` for a renderer with
no honest readback rather than a buffer of zeroes — so every test branches on the
renderer that is actually present and asserts the truth for it, the runner prints
one line per proof that was obtained, and `rasterizer.sh` fails when a required
proof is absent.

### What is not in the rasterizer lane

**Every draw shape but the ones above.** Each proof is one shape. The sprite
ones are axis-aligned, unrotated, unscaled, untinted opaque blits; the primitive
one is a single untextured, unlit, unfogged triangle list with no transform; the
text ones are unrotated, unscaled, untinted text with no origin and no
`SpriteEffects`. Rotation, scaling, tinting, blending, texturing, lighting, fog,
indexed draws, buffer-backed draws, flipped or rotated text and every
non-identity transform are submitted and accepted, and no pixel of any of them is
asserted anywhere.

**Any stock effect's own shading.** The `stock-effect` proof is about the draw
reaching pixels, not about what the effect computes. The alpha test is not
implemented by this renderer at all, skinning needs a vertex layout this
milestone does not project, and `DualTextureEffect` has no pixel evidence
whatever. Every one of those is measured in `docs/limitations.md` rather than
left as an unstated gap.

**A real font.** The text proof's atlas is generated: two flat opaque colour
cells with no antialiasing, chosen so the expected back-buffer value is the texel
itself. Nothing here says anything about a font produced by the content pipeline,
about antialiased glyph edges, or about how a real typeface's bearings and
kerning table would lay out — `MeasureString` computes those from whatever table
it is given, and the arithmetic is pinned by the unit tests, but no
pipeline-produced font has been through this.

**Compiled effects.** `Effect(GraphicsDevice, byte[])` is implemented, and
neither qualification renderer has `CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS`, so
no effect with a reflected parameter graph has ever been loaded here.
`docs/limitations.md` says what that means for `EffectParameter`.

**No claim is made about a physical monitor.** Pixels in a back buffer are pixels
in a back buffer. Nothing here has been displayed to anyone.

**And no claim is made about a GPU renderer.** `SOFTWARE` rasterises on the CPU.
Nothing here says an OpenGL or Vulkan renderer would produce the same pixels.

### The isolated consumer asserts its pixels too

`tools/qualification/isolated-consumer.sh` builds a source artifact of CNA-Lisp,
extracts it somewhere clean, and runs the template against *that* — with a source
registry naming nothing else and a fresh FASL cache — so a canary that passed
because ASDF found the developer's working tree would fail instead.

It checks the three pixels the template reads, **in both directions**. Under a
rasterising renderer they must be exactly the colours the template drew:
CornflowerBlue for the clear, the triangle's own vertex colour, and the colour
that exists nowhere in the frame except inside the render target. Under a
renderer with no readback all three must say `not-supported`. Printing them was
not enough: a consumer that had quietly stopped drawing would have printed
whatever it found. Verified by mutation — a wrong expected colour makes the lane
exit 1 naming the line.

## What HEADLESS does and does not prove

A HEADLESS run proves:

* the game loop ran, in CNA's own frame order, for exactly the frames requested;
* every lifecycle callback was delivered, and conditions raised inside one were
  contained rather than unwound through C;
* draw commands were submitted through the real native routes and accepted;
* handles were created and destroyed deterministically, and the callback registry
  was empty afterwards.

It proves nothing about rasterisation, blending, filtering, sampling or any other
pixel-producing behaviour, and nothing about a physical display. Where a member's
observable behaviour is pixels, the tests here assert command and state
submission and say so; the limitation is recorded in `docs/limitations.md` rather
than papered over.

## The device lanes, which need no device

Three qualification scripts prove branches the suite alone cannot, and each runs
its lanes in **separate processes** because SDL's audio driver selection is
process-global and latches at initialisation: one image cannot answer for two
drivers.

| Script | Lanes | Needs |
| --- | --- | --- |
| `tools/qualification/audio.sh` | `AUDIO_UNAVAILABLE`, `AUDIO_DYNAMIC_UNAVAILABLE`, `AUDIO_AVAILABLE_STATE_MACHINE`, `AUDIO_DYNAMIC_STREAMING` | no sound card |
| `tools/qualification/microphone.sh` | `MICROPHONE_UNAVAILABLE`, `MICROPHONE_ENUMERATION`, `MICROPHONE_CAPTURE_STATE_MACHINE`, `MICROPHONE_CAPTURE_DATA`, `MICROPHONE_BUFFER_READY`, plus a public-API-only consumer | no microphone |
| `tools/qualification/media.sh` | `MEDIA_UNAVAILABLE`, `MEDIA_PLAYBACK`, `MEDIA_PLAY_CLOCK`, `MEDIA_QUEUE`, `MEDIA_EVENTS`, plus a public-API-only consumer | no sound card |
| `tools/qualification/rasterizer.sh` | the pixel proofs above | a rasterising renderer, no display |

**Playback, capture and song playback are three scripts and not one.** Playback
and capture are different devices behind different CNA routes -- a machine may
have a speaker and no microphone or the reverse -- and a song is neither: it goes
through `media_player.h` routes of its own, so a run that qualified the
sound-effect transport says nothing about whether the media player's did. A lane
that read any of the three out of another would let one be reported as another. The GitHub runner has neither, and both scripts
produce both of their branches there anyway — a driver name SDL cannot load gives
the unavailable branch deterministically, and SDL's `dummy` driver opens a
playback device with no speaker and enumerates capture devices that advance a
stream of silence.

**Every level in those two tables is a separate claim and none may be read out of
another.** A transport that transitioned says nothing about whether a submitted
buffer was consumed; devices that enumerated say nothing about whether capture
advances; a stream that advances says nothing about the event that announces it.
Each script requires each kind of evidence *by name*.

**A capture device that enumerates is not one that delivers.** The runner's
default audio driver enumerates two capture devices and delivers no PCM from
either, which is a third environment and not a variation of the other two. The
suite therefore branches on a bounded probe and asserts in both directions —
`MICROPHONE_CAPTURE_IDLE` proves `GetData` answers zero rather than refusing and
writes no byte — while `microphone.sh`, which chooses the driver, requires the
positive lanes that `SDL_AUDIODRIVER=dummy` does produce.

**Neither is a claim about sound.** A dummy playback device is not a speaker and a
dummy capture device is not a microphone. No test in this repository says a sound
was heard or that a sound was captured, and the strongest supportable sentence is
written out in full at the end of each script. `docs/limitations.md` carries both.

## Where the evidence is

| Evidence | Where |
| --- | --- |
| Structural projection | `docs/generated/api-compat-report.json` |
| Bound native surface | `docs/generated/native-abi-manifest.json` |
| Public image of the loaded system | `docs/generated/public-surface.json` |
| Per-run CI qualification facts | the `cna-lisp-reports` artifact of each `Native` run |
