# Ownership and lifetimes

Native destruction in CNA-Lisp is deterministic and explicit. `dispose` is the
only thing that destroys a CNA object, and it destroys it now.

## No finalizer destroys anything

There is no garbage-collection finalizer anywhere in CNA-Lisp that releases a CNA
resource, and there will not be one. A finalizer runs on whichever thread the
collector happens to be using, and every CNA handle is affine to the thread that
created its game: a finalizer that called CNA would be calling it from the wrong
thread **by construction**. A leak detector that only reports is a separate,
possible thing; a finalizer that pretends to repair ownership is not.

The consequence is the ordinary one for a native binding: a resource you create
is a resource you dispose. `with-disposal` and `unwind-protect` are how.

## The five kinds of native reference

| Kind | Meaning | Destroyed by CNA-Lisp? |
| --- | --- | --- |
| `:owned` | this object holds the handle | yes, by `dispose` |
| `:borrowed` | someone else owns it | never |
| `:callback-scoped` | borrowed, and valid only inside a lifecycle callback | never |
| `:parent-owned` | a facade with no handle of its own | never |

## The graphics device is a facade, on purpose

CNA lends the graphics device only from inside a lifecycle callback, and the
handle it lends is valid only until that callback returns.

So `graphics-device` **stores no handle at all**. It is a `:parent-owned` facade
over the game, and every operation resolves a fresh borrowed handle at the moment
it is performed. Keeping the borrowed handle in a slot is the classic bug here: it
would appear to work right up to the first use after the frame that produced it,
and then it would be reaching through a handle that may since have been reissued
to something else.

An operation on the device outside a callback is refused by CNA-Lisp with
`cna-scope-error`, before anything reaches the ABI, and the message says where
graphics work belongs.

## Generations

Every native object records the generation its owner had when the object was
created, and disposing an object bumps its generation. A child whose owner has
been disposed -- or disposed and replaced -- is *stale*: its recorded generation
no longer matches. Using a stale object signals `cna-ownership-error` and **does
not** pass its handle to CNA, because a handle from a destroyed owner may since
have been reissued and calling through it would reach an unrelated object.

## Disposal order

CNA destroys children before their parent and refuses the other order. So does
CNA-Lisp, one step earlier: `dispose` on an object that still owns live children
signals `cna-ownership-error` naming them, instead of letting the native refusal
happen.

**CNA-Lisp does not cascade.** Disposing a game does not dispose the textures and
sprite batches the program made, because deciding when a resource dies is the
program's decision and not the binding's, and because XNA does not cascade there
either -- `Game.Dispose` disposes the components and the device it owns, not
every `Texture2D` the program happened to create. The deviation from XNA is that
CNA *requires* the program to have disposed them, where XNA would have let the
finalizer thread deal with it. That is recorded in `docs/limitations.md`.

The order a Foundation 1 program uses is:

```lisp
(let ((game (make-instance 'my-game)))
  (unwind-protect
       (xna:run game)
    (progn
      (when (sprite-batch game) (xna:dispose (sprite-batch game)))
      (when (texture game)      (xna:dispose (texture game)))
      (when (manager game)      (xna:dispose (manager game)))
      (xna:dispose game))))
```

### A parent that is not the native parent: SpriteFont and its atlas

CNA makes a `SpriteFont` a child of the *game*. CNA-Lisp records it as a child of
its **atlas texture** instead, and the difference is deliberate.

The ordering that actually matters is not the game's. CNA's own header says the
source texture "cannot be destroyed until this SpriteFont is destroyed", so the
texture is the resource whose destruction would invalidate the font. Recording
that as the parent/child relation is what turns disposing them in the wrong order
into `cna-ownership-error` naming both types, instead of a native failure
somewhere later. The game's own requirement still holds, transitively: the
texture is a child of the game, so the game refuses while the texture lives and
the texture refuses while the font does.

The public consequence is worth stating plainly, because it is the one place in
this binding where a disposal exists that XNA has no member for. XNA's
`SpriteFont` extends `System.Object`, is sealed, and is **not** `IDisposable`.
`dispose` on one is the binding's own deterministic disposal — the declared
extension every native object carries — and is not counted as an XNA member of
that type.

**`ContentManager.Unload` does call it**, and this paragraph said the opposite
until the content closure landed. The current model is:

* the manager owns the assets it loaded, at the managed projection level;
* its cache preserves XNA's reference identity, so two loads of one cleaned name
  answer one object;
* `Unload` disposes those assets in the safe order — a font before the atlas it
  keeps alive, a later asset before an earlier one — and then calls
  `cna_content_manager_unload` as well, so neither side keeps what the other has
  let go;
* `Game.Content`'s `Dispose` is XNA's managed unload-and-drop, which is why
  `%CHECK-DISPOSABLE` accepts it where it refuses every other parent-owned facade.

`Unload` and `Dispose()` are **complete**, not partial; the two members that are
not are `Load(String)`, which is partial, and the two `IServiceProvider`
constructors and `ServiceProvider`, which are missing.
`docs/compatibility.md` has the per-member table and `docs/limitations.md` the
audit.

## Construction is all-or-nothing, and a subclass's share of it too

A native-backed class takes its handle in an `initialize-instance :after` method.
CLOS runs `:after` methods **least-specific-first**, so the last initializer to
run is the most derived one — a consumer's. By then the handle exists, the object
is registered as a child of its owner, and the base class's own local
`unwind-protect` has already returned. A subclass initializer that signals used
to leave CNA holding a resource the caller never received, with nothing left that
could dispose it. The symptom is never at the constructor: it is the game
refusing to shut down, later, because a child handle is still alive.

Common Lisp has no `sealed`, so **every exported class here can be subclassed**.
The remedy is therefore one mechanism on the private base rather than one per
class:

* `NATIVE-OBJECT` carries a `construction-undo` ledger;
* each constructor calls `RECORD-CONSTRUCTION-UNDO` for the handle it takes and
  again for the registration it makes;
* one `initialize-instance :around` on `NATIVE-OBJECT` runs that ledger
  newest-first when the construction does not finish, and drops it when it does.

The `:around` is on the *least* specific class, which makes it the **innermost**
one, and that is exactly what is wanted: `call-next-method` from there runs every
`:before`, primary and `:after` method there is, a subclass's included.

`tests/native/construction-atomicity.lisp` builds an ordinary exploding subclass
of twelve resource families plus `Game` and `GraphicsDeviceManager`, and checks
the four things that matter — the caller sees the subclass's own condition, the
owner is left owning no live child, the callback registry is unmoved, and the
game shuts down. Removing the `:around`'s undo turns 130 checks red.

Two families are worth calling out because their evidence is indirect and
stronger for it. CNA allows exactly **one live game per process**, so a native
game left behind by a failed `Game` construction does not merely leak — it makes
every later game in the image impossible; the proof is that the next one is not.
XNA's `GraphicsDeviceManager` constructor refuses a second manager on one game,
and so does this, so the proof there is that a second manager can still be made.

Classes with no native resource of their own — `VertexDeclaration` and the four
state objects — record nothing, because there is nothing to give back.

**A handle is not the only thing a construction can acquire.** An initializer may
also *subscribe*, and that was a hole in the mechanism above until
`DynamicSoundEffectInstance`'s own atomicity test opened it: an initializer that
subscribed and then signalled left CNA holding the event registration and the
private callback registry holding the token that roots the object. Nothing in the
ledger gave either back, because only the constructor's own two steps were in it.
The hole was never about audio — every exported class that raises an event is
subclassable, and the same subclass could be written for any of them.

`%SUBSCRIBE-EVENT` therefore records a construction undo for the subscription it
just made, and only while the object is still constructing: `NATIVE-OBJECT`
carries a `constructing` flag that the `:around` sets and clears. After the
construction commits the same call records nothing, because a subscription a
program made is an ordinary thing it did and nothing may undo it on the program's
behalf. A non-empty ledger is *nearly* the same test and is not the same test,
which is why the flag is explicit.

## Double disposal

`dispose` is idempotent, exactly as `IDisposable.Dispose` is. The second call
does nothing and signals nothing.

## Failed disposal

`cna_game_destroy` releases the handle **even when it answers
`CNA_RESULT_CALLBACK`**, and it answers that in two different situations: a
shutdown callback failed, or an earlier frame callback had already stopped the
loop.

Only the first is news. The second was already signalled where it happened, and
re-signalling it during disposal would mask the original condition behind an
unwind -- which is exactly what happens if you do not distinguish them, and it
was observed while building this binding. So:

* a callback result carrying a **freshly contained condition** is a real shutdown
  failure, and is signalled with that condition attached;
* a callback result with **no** freshly contained condition is the latched
  earlier failure, and disposal completes.

Either way the handle is dropped and the object is marked disposed, so a failed
disposal can never leave a stale handle reachable.

## Thread affinity

A game and everything it owns belong to the thread that created the game.
CNA-Lisp records that thread and refuses a wrong-thread operation **before** it
reaches the ABI, so the handle is untouched and stays usable from its own thread
afterwards. The refusal is `cna-thread-error` and names both threads.

## The callback registry

CNA holds one `void*` context per callback table. CNA-Lisp never puts a Lisp
object there: a Lisp object moves, and its address means nothing after the next
collection. What goes in is a small integer token.

```
CNA's void* context -> integer token -> callback registry -> the CLOS game
```

The registry holds a **strong** reference: an entry in it is what keeps a game
reachable while CNA can still call back into it. The entry is removed only after
`cna_game_destroy` has returned -- the shutdown callbacks run *inside* that call,
and a game that could not be resolved there would be a callback arriving after
teardown. `tests/native/ownership.lisp` asserts the registry is empty afterwards,
and `tests/native/stress.lisp` asserts it stays empty across twenty cycles with a
full collection in between.

## One active game

CNA allows one active game per process. CNA-Lisp refuses a second live `game`
with `cna-invalid-state-error`, and tracks the active one so that XNA's static
input classes can be projected without a game argument.
