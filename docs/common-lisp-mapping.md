# The Common Lisp mapping

This document is the rulebook. It says how a selected Microsoft XNA Framework
4.0 Windows contract element becomes a Common Lisp one, and it is normative: the
structural verifier in `tools/api-compat/` checks the live image against these
rules, and `tests/structure/public-surface.lisp` fails when a name appears that
no rule accounts for.

Two things are true of every rule below.

* **The public API is Common Lisp.** A consumer works with CLOS classes, generic
  functions, methods, conditions, Lisp strings, Lisp numbers, Lisp sequences and
  Lisp value objects. There is no handle, no result code, no CFFI pointer and no
  C name anywhere in it.
* **The exceptions are declared.** Where Common Lisp cannot express something the
  way C# does, the deviation is written down here and recorded in
  `src/capabilities.lisp`, not smoothed over.

## 1. Namespaces and packages

One XNA namespace maps to one Common Lisp package with the namespace's own name,
lowercased:

| XNA namespace | Common Lisp package |
| --- | --- |
| `Microsoft.Xna.Framework` | `microsoft.xna.framework` |
| `Microsoft.Xna.Framework.Graphics` | `microsoft.xna.framework.graphics` |
| `Microsoft.Xna.Framework.Input` | `microsoft.xna.framework.input` |

Namespaces not yet reached keep their obvious names when they arrive:
`microsoft.xna.framework.input.touch`, `.content`, `.audio`, `.media`,
`.storage`, `.gamer-services`, `.net`, `.graphics.packed-vector`.

There is no single flattened package. Two members named the same thing in two
namespaces stay two symbols in two packages, which is what lets `Game.Draw` and
`SpriteBatch.Draw` both keep the name `draw` without either one shadowing the
other. Consumers are expected to use `:local-nicknames`:

```lisp
(defpackage #:my-game
  (:use #:cl)
  (:local-nicknames (#:xna   #:microsoft.xna.framework)
                    (#:gfx   #:microsoft.xna.framework.graphics)
                    (#:input #:microsoft.xna.framework.input)))
```

Implementation packages are named so that their status is unmistakable and export
nothing a consumer needs: `cna-lisp.internal`, `cna-lisp.internal.ffi`,
`cna-lisp.internal.framework`, `cna-lisp.internal.input`, `cna-lisp.internal.abi`.

## 2. Spelling

A CLR identifier becomes a Common Lisp symbol by inserting a hyphen at each
word boundary and lowercasing: `LoadContent` becomes `load-content`,
`IsKeyDown` becomes `is-key-down`, `Texture2D` becomes `texture-2d`,
`PreferredBackBufferWidth` becomes `preferred-back-buffer-width`.

The `Is` prefix is kept where the original has it (`is-active`, `is-key-down`,
`is-fixed-time-step`). It is not translated into a `-p` suffix, because that
would silently rename a member. `-p` is reserved for predicates CNA-Lisp adds
itself, of which `disposed-p` is the only one at present.

`microsoft.xna.framework` shadows `cl:exit` so that `Game.Exit` keeps its name.

## 3. Reference types

An XNA class becomes a CLOS class. Reference identity is preserved where XNA
preserves it: `(graphics-device game)` answers the same object every time,
because `Game.GraphicsDevice` answers the same device.

Native-backed classes inherit from the private base
`cna-lisp.internal:native-object`, which carries the native handle, the ownership
category, the owner, the owner's generation, the owning thread and the disposed
flag. **None of those slots is publicly readable**, and none of their accessors
is exported from any public package.

The public inheritance the contract gives a class is kept too:
`graphics-resource` is the base of `texture` and `sprite-batch`, as it is in XNA,
and the mapping rules declare each type's `expected_superclass` so the verifier
checks the class precedence list rather than taking the hierarchy on trust.

A member may project onto a symbol in **another package** when the operation is
one thing rather than one thing per type. `GraphicsResource.Dispose()` is
`microsoft.xna.framework:dispose`, because deterministic disposal is one
operation every native object in this binding has, not one per graphics type. The
rule says which package, so the symbol is accounted for where it really lives.

Not every XNA class is native-backed. `BoundingFrustum` is a class in XNA -- two
names for one frustum see each other's changes, and assigning its `Matrix`
rebuilds its planes and corners in place -- and it is a CLOS class here for that
reason alone. It owns no native resource, so it has no `native-object`
superclass, nothing to dispose, and no thread affinity. A class in this
projection means *reference semantics*; it does not mean *holds a handle*.

A class's members would otherwise project to bare names -- `contains`,
`intersects`, `matrix` -- so where those would collide, as every member of
`BoundingFrustum` would, the mapping rules name each one explicitly and the
verifier checks the names it declares rather than the default it would have
produced.

## 4. Value types

An XNA struct becomes a Common Lisp structure (`defstruct`), because that is what
a value is: `point`, `rectangle`, `vector2`, `color`, `viewport`,
`keyboard-state`. Value semantics are restored at every boundary -- a value
stored into an object is copied in, and a value read out of one is copied out --
so mutating what an accessor answered can never reach through to the object, the
way it cannot in C#.

A predefined value of a mutable value type is a **function**, not a constant:
`(cornflower-blue)`, `(white)`, `(point-zero)`, `(rectangle-empty)`,
`(vector2-one)`. `Color.CornflowerBlue` is a property on a value type, so every
read of it in C# is a fresh copy; a Lisp constant bound to one shared structure
would not be, and a consumer who set `R` on it would change what every later read
answered.

Pure value arithmetic is implemented in Lisp, not routed through the C ABI, even
where CNA has a route for it. The route would be slower and would make the
binding's arithmetic CNA's arithmetic rather than XNA's -- and would leave
nothing to cross-check.

Every arithmetic method in the projected value types was written by reading the
corresponding method body in the disassembled IL of the hash-pinned
`Microsoft.Xna.Framework.dll`, instruction by instruction. See
`tools/api-compat/reference/XNA_IL_PROVENANCE.md` for the hash and the procedure,
and for the list of things that reading caught which a reimplementation from
first principles gets wrong.

### Binary32

XNA computes in IEEE 754 binary32, under the CLR's floating-point rules, which
are IEEE's **default** rules: an overflow answers an infinity, an invalid
operation answers a NaN, and nothing is signalled. SBCL traps overflow, invalid
and divide-by-zero by default, so every projected arithmetic operation runs
inside `cna-lisp.internal:with-binary32-semantics`, which masks them. Without it,
`(vector2-length (make-vector2 1f20 1f20))` would signal where XNA answers +Inf.

XNA computes in IEEE 754 binary32. Every arithmetic step in a projected value
type is performed in `single-float`, in the order the original performs it. Where
the original promotes -- `Math.Sqrt` takes a `double` -- the projection promotes
at exactly that point and narrows exactly where the original casts back. Computing
in `double-float` and rounding at the end answers different bits and is not done.

`Vector2.Divide` by a scalar takes the reciprocal once and multiplies twice,
because the original does; `x * (1/d)` and `x / d` are not the same binary32.

## 5. Methods, properties and constructors

| XNA | Common Lisp |
| --- | --- |
| instance method | generic function, dispatching on the receiver |
| readable property | reader generic function of one argument |
| writable property | `(setf reader)` method |
| constructor | `make-instance`, plus initargs |
| static method on a static class | function named `<class>-<member>` |
| static method on an instantiable type | function named `<type>-<member>` |
| constant / predefined value | constant if immutable, function if not (§4) |

`Keyboard.GetState()` is `keyboard-get-state`, not `get-state`: `Mouse` and
`GamePad` live in the same namespace and have a `GetState` of their own, and a
binding that gives two different members the same name has already lost. The
original takes no game argument and neither does the projection, because CNA
allows one active game per process and CNA-Lisp resolves it.

`Rectangle.Left` and friends are `rectangle-left` and friends: they are static-
looking readers on a value type, and the type prefix is what keeps them from
colliding with `Viewport`'s.

## 6. Inheritance and the game loop

`game` is a public CLOS class meant to be subclassed. The loop is generic
functions, never a callback table:

| XNA virtual | Generic function | Default method |
| --- | --- | --- |
| `Game.Initialize` | `initialize` | does nothing |
| `Game.LoadContent` | `load-content` | does nothing |
| `Game.UnloadContent` | `unload-content` | does nothing |
| `Game.BeginRun` | `begin-run` | does nothing |
| `Game.EndRun` | `end-run` | does nothing |
| `Game.Update(GameTime)` | `update` | does nothing |
| `Game.BeginDraw()` | `begin-draw` | answers `t` |
| `Game.Draw(GameTime)` | `draw` | does nothing |
| `Game.EndDraw()` | `end-draw` | does nothing |
| `Game.OnExiting` | `on-exiting` | does nothing |

The default methods do what XNA's base implementations do **for a game with no
components**: nothing, except that `BeginDraw` answers true. The component
engine that would give them more to do is not implemented, and is reported as
missing rather than faked.

`initialize` is CNA-Lisp's name for `Game.Initialize`. It is a distinct symbol
from `cl:initialize-instance`, and a subclass that wants to build its own state
at construction time uses `initialize-instance :after` as any CLOS program does;
`initialize` is the game-loop hook and runs later, on the game's own thread.

### Static and instance members with the same name

XNA often has both an instance method that mutates the receiver and a static one
that answers a new value, under one name: `Vector3.Normalize()` and
`Vector3.Normalize(Vector3)`, `Quaternion.Conjugate()` and
`Quaternion.Conjugate(Quaternion)`, `Plane.Normalize()` and
`Plane.Normalize(Plane)`.

One Lisp function cannot be both without the caller having to know which it got,
so the pair splits: the **verb** mutates and answers the receiver, and the
**adjective** answers a new value.

| XNA | Common Lisp |
| --- | --- |
| `Vector3.Normalize()` | `vector3-normalize` — mutates |
| `Vector3.Normalize(Vector3)` | `vector3-normalized` — answers a new value |
| `Quaternion.Conjugate()` | `quaternion-conjugate` |
| `Quaternion.Conjugate(Quaternion)` | `quaternion-conjugated` |

### Constant fields of a static class

A constant field projects to a Common Lisp constant, which by convention wears
earmuffs: `MathHelper.Pi` is `+math-helper-pi+`, not `math-helper-pi`.

### The M<row><column> fields

`Matrix`'s sixteen fields keep their digits together: `matrix-m11`, not
`matrix-m-1-1`. The identifier rule would split at the digit boundary, and for
the one type where the indices *are* the name that is unreadable.

## 7. Overloads

An overload family maps by this order of preference.

1. **Multiple dispatch**, when the overloads have congruent lambda lists and the
   dispatch really is on argument type. `rectangle-contains` has methods on
   `point` and on `rectangle`; `vector2-multiply` has methods on `real` and on
   `vector2`.
2. **Keyword arguments**, when the family is one member with optional parameters
   and no ambiguity results. `draw-texture` takes `:position` or `:destination`,
   `:source`, `:color`, `:rotation`, `:origin`, `:scale`, `:effects` and
   `:layer-depth`. Giving both `:position` and `:destination` is refused, because
   they are different overloads meaning different things.
3. **Optional arguments**, when the family differs only by a trailing parameter.
   `keyboard-get-state` takes an optional `player-index`.
4. **A separate, descriptive function**, when Common Lisp cannot express the
   family congruently. `rectangle-contains-coordinates` is
   `Rectangle.Contains(int, int)`: three arguments cannot share a congruent
   generic function with two-argument methods.

Never done: one `&rest` sink; accepting everything and guessing; answering
success for a shape that is not supported; dropping an overload silently; adding
a default that changes behaviour.

### The keyword combination *is* the overload

When a family collapses onto one keyword-taking function, the keyword combination
selects the overload — and **only the combinations the original has are
accepted**. `SpriteBatch.Draw` is the worked example:

| XNA overload | Keywords |
| --- | --- |
| `Draw(t, Vector2, Color)` | `:position :color` |
| `Draw(t, Vector2, Rectangle?, Color)` | `:position :source :color` |
| `Draw(t, Vector2, Rectangle?, Color, float, Vector2, float, SpriteEffects, float)` | `:position [:source] :color :rotation :origin :scale :effects :layer-depth` |
| `Draw(t, Vector2, Rectangle?, Color, float, Vector2, Vector2, SpriteEffects, float)` | the same, with `:scale` a `vector2` |
| `Draw(t, Rectangle, Color)` | `:destination :color` |
| `Draw(t, Rectangle, Rectangle?, Color)` | `:destination :source :color` |
| `Draw(t, Rectangle, Rectangle?, Color, float, Vector2, SpriteEffects, float)` | `:destination [:source] :color :rotation :origin :effects :layer-depth` |

Everything else is refused: no placement, both placements, no `:color`, half the
transform group, `:scale` without the transform group, `:scale` with a
`:destination`. A keyword-taking projection that accepted a combination the
original lacks would be **inventing an overload**, which is the failure the whole
overload section exists to prevent — and it is easy to do accidentally, because a
`&key` lambda list accepts every combination unless something says otherwise.

The mapping rules therefore carry, per overload, the exact keyword set that
expresses it, and `tools/api-compat/verify.py` checks every one of them against
the real method lambda lists in the image. A family that collapses without
declaring how each overload is distinguished — by CLOS dispatch, by a trailing
optional argument, or by keywords — is a `wrong_overload_shape` diagnostic.

### When two overloads are two operations

`Color`'s constructors take either three integers or three floats, and XNA tells
them apart by static type. Common Lisp would have to tell `1` from `1.0` at run
time to do the same -- and those two mean almost opposite colours, since
`(make-color 1 1 1)` is very nearly black where
`(make-color-from-floats 1.0 1.0 1.0)` is white. A projection that dispatched on
`integer` versus `single-float` would be correct and unreadable: the bug it
invites is a literal written without its decimal point, and nothing would catch
it. So the two are separate names.

`Color.FromNonPremultiplied` is the stronger case. Its integer overload
multiplies the unclamped channel by the unclamped alpha and truncates an integer
quotient; its `Vector4` overload multiplies in floats and packs through
`PackUNorm`. They disagree by a level on ordinary inputs. Collapsing them onto
one name would be claiming they are one operation reached two ways, which they
are not.

Every such split is declared in `overload_families` in the mapping rules with
the reason, and the verifier reports an `overload_mapping_mismatch` for a family
that maps to several symbols without one.

### One generic function, three return types

`BoundingSphere.Intersects` has four overloads, and three different return types
between them: a Boolean for a box or another sphere, a `PlaneIntersectionType`
for a plane, and a `Nullable<float>` for a ray. CLOS dispatches on the argument,
so all four collapse onto `bounding-sphere-intersects` and the answer's *type*
follows the argument's, which is exactly what the original does. The
documentation string of each such generic function names the return type per
argument type, because the lambda list cannot.

`Nullable<float>` maps to a `single-float` or `nil`, never to a distinguished
float. A miss is `nil`; a hit at distance zero is `0.0f0`, and those are
different answers a caller has to be able to tell apart.

Each of these families declares `distinguished_by: "dispatch"` in
`tools/api-compat/mapping-rules.json`, so the verifier checks that a method
really is specialised on each overload's argument type rather than the family
having quietly become one method that accepts anything.

### By-reference overloads

XNA pairs almost every value-type computation with a by-reference form:
`Vector3.Add(Vector3, Vector3)` and
`Vector3.Add(ref Vector3, ref Vector3, out Vector3)`. The second exists so a C#
caller can avoid copying a value type into a call and can write the answer into
storage it already has. **The value it computes is the by-value overload's.**

Common Lisp passes a reference already, so the by-value form *is* the whole
contract, and projecting the ref form would be a second name for one operation.
Those members are classified **not applicable**, not missing, with the reason
recorded per type in `tools/api-compat/mapping-rules.json`. Calling them missing
would imply work that is never going to be done.

### Array overloads

`Transform(Vector3[], ref Matrix, Vector3[])` and
`Transform(Vector3[], int, ref Matrix, Vector3[], int, int)` differ only by
trailing parameters, so one function with `:source-index`, `:destination-index`
and `:length` expresses both — `vector3-transform-array`. It is a distinct
function from the single-value `vector3-transform`, because a rule that let one
stand for the other would be a rule that could claim either without doing it.

## 8. Enumerations and flags

**An enum member is a keyword.** Each enum gets a Common Lisp type of the enum's
name over those keywords, plus `<enum>-value`, `<enum>-from-value` and
`all-<enum>`:

```lisp
(gfx:begin batch :sort-mode :deferred)
(input:is-key-down state :escape)
(gfx:sprite-sort-mode-value :back-to-front)   ; => 3
(typep :escape 'input:keys)                   ; => T
```

A **flags** enum is a *list* of keywords, and `<enum>-value` combines their bits:
`(gfx:sprite-effects-value '(:flip-horizontally :flip-vertically))` is 3. The
empty list is the named zero member where the enum has one.

The exact numeric values are preserved privately, generated from the CNA C ABI's
own identities, and are reachable only through the conversion functions. A raw
ABI integer is never the public representation of an enum.

`define-xna-enum` in `src/graphics/enums.lisp` is the single place this shape is
defined, so no enum can drift into a different one. `ContainmentType` and
`PlaneIntersectionType` follow the same shape from `src/framework/plane.lisp`,
because they are needed before the graphics package exists.

## 9. Conditions

Every failure a consumer can see is a Lisp condition. The hierarchy is

```
error
└── cna-error                        operation, native-message, object-type
    ├── cna-usage-error              the program broke a contract
    │   ├── cna-argument-out-of-range-error   parameter-name
    │   ├── cna-disposed-error
    │   ├── cna-ownership-error
    │   ├── cna-scope-error
    │   ├── cna-native-library-error native-library-path
    │   └── cna-abi-rejected-error   found-version, admitted-versions
    └── cna-native-error             CNA refused or failed
        ├── cna-invalid-argument-error   cna-not-supported-error
        ├── cna-invalid-object-error     cna-platform-error
        ├── cna-invalid-state-error      cna-thread-error
        ├── cna-out-of-memory-error      cna-overflow-error
        ├── cna-io-error                 cna-encoding-error
        ├── cna-internal-error           cna-shutting-down-error
        ├── cna-buffer-too-small-error
        └── cna-callback-error       underlying-condition
```

The CNA result code is **not** a public reader. It is an ABI detail; the
condition class is the public fact. The code and CNA's error category are kept in
private slots so diagnostics and tests can still see exactly what the ABI said.

A native failure is never swallowed, printed, or turned into a default answer.

### The one BCL exception

`System.ArgumentOutOfRangeException` is the only base-class-library exception the
selected surface throws at a caller: `Matrix.CreatePerspectiveFieldOfView` and
its neighbours check their arguments and throw. It projects to
`cna-argument-out-of-range-error`, whose `cna-error-parameter-name` reader names
the argument. Projecting it -- rather than letting the checks disappear -- is
what keeps `(matrix-create-perspective-field-of-view 0 ...)` refusing here as it
refuses there.

No other BCL exception type is projected, because the selected surface reaches no
other.

## 10. `ref`, `out`, nullable, and collections

| CLR shape | Common Lisp |
| --- | --- |
| `out T` | an additional return value (`values`) |
| `ref T` on a value type | the mutable value object itself, mutated in place |
| nullable reference | `nil` |
| `Nullable<T>` value type, returned | the value, or `nil` -- `nil` is not of the value's type, so it is not a sentinel |
| `Nullable<T>` value type, as a parameter | an optional argument whose absent value is `nil` |
| `T[]` | a Lisp vector, with the element type where it is fixed |
| byte buffer | `(vector (unsigned-byte 8))` |
| `IEnumerable<T>` | a Lisp list or vector, whichever the member's shape fits |
| read-only collection | a fresh Lisp sequence; the projection copies rather than aliasing |
| `TimeSpan` | an integer count of 100-nanosecond ticks |
| `IntPtr` | not projected. `Mouse.WindowHandle` is the only member of the selection that has one, and it is classified not applicable: answering it would put a raw platform pointer in the public API, and setting it would need a window handle a CNA-Lisp program never has, because CNA owns the game's window |

A member with a return value *and* `out` parameters answers the return value
first and the `out` parameters after it, in their declared order.
`matrix-decompose` is the example, and the order matters: its first value says
whether the decomposition succeeded, and the three that follow are filled in
either way.

`GameTime.TotalGameTime` is `total-game-time`, answering ticks.
`total-game-time-seconds` is a CNA-Lisp convenience over it, declared as an
extension.

No fake .NET base class library is invented. Only the BCL surface the selected
XNA profile actually reaches is projected, and each projection is recorded here.

### 7a. Events

A CLR event is two operations -- `add_E` and `remove_E` -- and it projects to two
**generic functions** on the object that raises it:

    (add-activated-handler game (lambda (game) ...))
    (remove-activated-handler game the-same-function)

Three decisions, each with a reason a reader can check.

* **Generic functions, not plain ones.** `Disposed` is raised by more than one
  type in one package -- `Game` and `GraphicsDeviceManager` -- so a plain
  function could not be specialised on the second. The verifier rejects an event
  projection whose add or remove is not generic, for exactly that reason.
* **The handler takes the sender and nothing else.** The events in the selection
  carry `EventArgs.Empty`, which holds no information. A second always-empty
  argument would be something every handler had to write and ignore. This is the
  same decision `on-exiting` already records.
* **Removal takes the function, not a registration object.** `-=` takes the
  delegate, so this takes the function; the object keeps the native registration
  beside the function it belongs to and finds it by identity. Removing a handler
  that is not subscribed answers `nil` rather than signalling, which is what `-=`
  does silently.

A condition signalled inside a handler cannot be reported to the framework:
CNA's event callback returns `void`, so there is no result code and no
diagnostic structure. It is contained and preserved on the Lisp side, and
`docs/callbacks-and-threading.md` says what happens to it.

The protected `On<Event>` methods -- `OnActivated`, `OnDeactivated` -- are the
base class's way of letting a subclass intercept an event before its handlers
run. CNA raises the events itself, so there is no place in this projection for a
subclass to stand between CNA and the handlers, and those two are reported
missing with that reason rather than projected as something they are not.

## 11. Disposal

`dispose` and `disposed-p` are CNA-Lisp additions rather than XNA members: XNA
spells disposal differently on each type that has it, and a binding over a native
runtime needs one operation and one question that apply to anything holding a
handle. `with-disposal` is an `unwind-protect` convenience, not a replacement for
the object model. See `docs/ownership-and-lifetimes.md`.

## 12. What the projection refuses to invent

Three failures are easy to commit and hard to see, so each has a check:

* **An overload the original does not have.** A `&key` lambda list accepts every
  combination unless something refuses; `draw-texture` refuses the six illegal
  ones, and `begin` takes no arguments because XNA's next `Begin` overload takes
  a `SpriteSortMode` *and* a `BlendState` together.
* **A mapping rule that names nothing.** A rule keyed on a signature no member
  produces is silently ignored and the default naming rule applies instead, so
  the member ends up reported under a mapping nobody wrote. That is a
  `stale_mapping_rule` diagnostic, and it is how five `SpriteBatch.Draw`
  overloads once came to be reported missing while a rule for each of them sat in
  the file being skipped.
* **A route reimplemented instead of used.** `SpriteBatch.Draw`'s position-and-
  scale overloads take CNA's `cna_sprite_batch_submit_scaled_many`, not a
  destination rectangle computed from the position. The C ABI says the two are
  not interchangeable and it is right: the position is in floating-point screen
  pixels and the origin is in source-texture pixels with the scale applied after
  that offset, so rounding a rectangle out of them loses the fractional position
  and moves the sprite.

### A defect in the original is part of the contract

`BoundingBox.Contains(BoundingSphere)` tests `Max.X - Min.X` against the radius
twice, the second time in the slot where the Z extent belongs. It is a typo in
the shipped assembly, it is observable — a zero radius against a box with no
thickness in Z answers Contains where the intended test answers Intersects — and
it is reproduced here, because a binding whose job is to agree with XNA does not
get to decide which of XNA's answers are the real ones. What the projection does
owe the reader is a note wherever the defect is reproduced: the source comment
cites the IL offset, the unit test says the quirk is the point of the test, and
the behaviour corpus records it as `:xna-derived` with the inputs that see it.

Silently "fixing" it would be the worse failure of the two, and an unmarked
reproduction would be the second worst.

## 13. Declared extensions

Every public symbol that is not a mapped XNA member is listed in
`cna-lisp.internal::*binding-extensions*` with the reason it exists. The
structural verifier treats an exported symbol that is neither a mapped member nor
a declared extension as a diagnostic.
