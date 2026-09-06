# Callbacks and threading

## No condition unwinds across a C frame

A Lisp condition that unwound through a C stack frame would leave CNA's own state
half-finished, and on some implementations would not be recoverable at all. So
every callback CNA can reach runs inside `with-contained-callback`, which:

1. enters callback scope, so scope-sensitive routes know where they are;
2. resolves the context token to the CLOS game, refusing a stale token;
3. invokes the correct generic function;
4. catches **every** `serious-condition`;
5. keeps the condition object itself in `*pending-callback-condition*` -- it is
   not flattened into a string. A callback that answers `void` rather than a
   result code keeps it in `*pending-event-condition*` instead, which is a
   different slot because it is delivered by a different rule; see below;
6. writes CNA's `CNA_CallbackError` diagnostic with the condition's own printed
   representation;
7. returns `CNA_RESULT_CALLBACK`, which is how a callback is *supposed* to fail;
8. lets the enclosing `cna_game_run` / `run_one_frame` / `tick` regain control;
9. and then, on the Lisp side, signals `cna-callback-error` **with the original
   condition attached** as `cna-callback-underlying-condition`.

A handler can therefore recover the real condition:

```lisp
(handler-case (xna:run game)
  (xna:cna-callback-error (c)
    (let ((original (xna:cna-callback-underlying-condition c)))
      (format t "~a during ~a~%" (type-of original) (xna:cna-error-operation c)))))
```

Nothing is ever converted into a generic string and left at that.

### The diagnostic buffer's lifetime

`CNA_CallbackError.message` is a borrowed view, and CNA reads it *after* the
callback returns. The bytes are therefore **not** freed inside the callback --
that would hand CNA a dangling pointer. They are held in a thread-local slot and
released once the enclosing native call has come back, in
`call-native-frame`'s cleanup.

## Top-level callbacks only

Every CFFI callback in CNA-Lisp is a top-level `defcallback`, defined once, in
`src/internal/ffi/callbacks.lisp`. Ten of them exist -- one per lifecycle hook --
and they all funnel into one dispatcher.

No Lisp object is ever handed to C as a `void*`. The chain is:

```
CNA's void* context -> integer token -> strongly rooted registry entry -> CLOS game
```

See `docs/ownership-and-lifetimes.md` for the registry's lifetime rules.

## Which callbacks exist

CNA carries the game loop in two tables. `CNA_GameCallbacks` is passed at
creation and copied during the call; `CNA_GameFrameHooks` is installed
afterwards with `cna_game_set_frame_hooks_ext`. CNA-Lisp installs both, so the
whole loop is available:

| Table | Hook | Generic function |
| --- | --- | --- |
| callbacks | `load_content` | `load-content` |
| callbacks | `update` | `update` |
| callbacks | `draw` | `draw` |
| callbacks | `unload_content` | `unload-content` |
| callbacks | `exiting` | `on-exiting` |
| frame hooks | `initialize` | `initialize` |
| frame hooks | `begin_run` | `begin-run` |
| frame hooks | `end_run` | `end-run` |
| frame hooks | `begin_draw` | `begin-draw` |
| frame hooks | `end_draw` | `end-draw` |

The order a first frame delivers is `initialize`, `load-content`, `begin-run`,
`update`, `begin-draw`, `draw`, `end-draw`, and it is a contract rather than an
accident. `begin-run` and `end-run` are delivered by `run`, not by
`run-one-frame`; that is CNA's behaviour and is asserted in
`tests/native/game-lifecycle.lisp`.

`begin-draw` answers a boolean: a `nil` from the generic function sets
`out_should_draw` to false and the frame's drawing is skipped.

## Threading

Every CNA handle is affine to the thread that created its game. CNA-Lisp records
that thread on the game and on everything the game owns, and refuses a
wrong-thread operation **before** it reaches the ABI -- so the refusal costs
nothing and the object stays usable from its own thread. The refusal is
`cna-thread-error` and it names both threads.

All implementation-specific thread identity lives in `src/internal/threads.lisp`,
behind `bordeaux-threads`. Nothing else in the binding knows how a thread is
identified.

### Re-entry

`run`, `run-one-frame` and `tick` are refused from inside a lifecycle method:
they would re-enter the loop they are part of. CNA refuses them too; CNA-Lisp
refuses first, with `cna-scope-error`, so nothing reaches the ABI.

### What is *not* claimed

CNA-Lisp does **not** claim support for callbacks arriving on arbitrary foreign
threads. Every callback qualified here arrives on the game's own thread, inside a
`cna_game_run`, `cna_game_run_one_frame`, `cna_game_tick` or `cna_game_destroy`
call made from that thread, and that is the only configuration tested.

If a later CNA subsystem invokes callbacks from worker threads, the members that
depend on it will stay absent until that exact configuration has been qualified
on SBCL. An untested claim about foreign-thread callbacks would be worth less
than no claim.

## An event handler has nowhere to report a failure *to CNA*

The lifecycle callbacks return a `CNA_Result` and fill in a diagnostic structure,
so a condition contained inside one is reported to CNA, turned into
`CNA_RESULT_CALLBACK`, and re-signalled on the Lisp side with the original
condition attached. That is the whole containment story for the game loop.

`CNA_GameEventCallback` returns **void**. So does `CNA_AudioEventCallback`, the
graphics-resource and graphics-device callbacks, the six component handlers and
the component-collection callback. There is no result code and no diagnostic
structure, so a condition signalled by a handler passed to
`add-activated-handler` and its neighbours cannot be reported to the *framework*
at all. It is still reported to the *program*:

* **the condition is contained** -- it never unwinds across the C frame, which is
  the rule that matters most;
* **it is preserved as itself**, in `*pending-event-condition*`, not flattened
  into a string and not merged with the lifecycle channel;
* **the first native call that returns to your program signals it.** That is the
  `run`, `run-one-frame` or `tick` the event was raised inside, or the component
  addition, or the disposal -- whichever call CNA raised the event during. The
  condition object itself arrives, not a copy.

Four rules make that precise, and each of them is a decision:

| | |
| --- | --- |
| **First one wins** | Two handlers on one event, or two events inside one native call, do not overwrite each other. You are told about the failure that happened first. |
| **Delivered outside every callback** | The drain answers nothing while this thread is inside an event dispatch or a lifecycle callback, so a pending condition is never signalled through a C frame. It waits for the enclosing call. |
| **A native failure outranks it** | If the call that would have delivered it failed on its own, that failure is what is signalled and the handler's condition is its `cna-error-cause`. Both are real and neither is dropped. |
| **Delivered once** | Taking it clears it. The next call is ordinary. |

**This section used to say the condition was lost**, and the audio suite recorded
the loss as "the documented limit" while `add-buffer-needed-handler`'s own
docstring promised a re-signal. Both could not be true:
`call-native-frame` cleared the pending slot unread on every successful call. The
docstring's version is the one that is now implemented, and
`src/internal/callback-conditions.lisp` is where the rule lives.

**What is still not claimed.** A condition raised by an event that no further
native call follows has nowhere to arrive. `Disposed`, raised inside
`cna_game_destroy`, is delivered by that disposal itself -- but a handler on the
*last* native operation a program ever performs, with the process exiting
afterwards, is not something any mechanism here can report. A handler that needs
its failures seen for certain should still catch them itself.

`CNA_AudioEventCallback` has exactly the same shape -- `void (*)(void* context)`
-- and everything above applies to `add-buffer-needed-handler` unchanged, which
`tests/native/audio.lisp` asserts on its own evidence rather than by argument
from the game family. It is a
**separate** top-level callback and a separate dispatcher rather than the game
one reused, because the routes that install it are audio's and the registration
it produces is released by `cna_audio_unsubscribe_ext` rather than by
`cna_game_unsubscribe`; what the two share is the dispatcher body, since the
registry entry is the same `(sender . function)` pair in both. The private
function that resolves it is called `%DISPATCH-PAYLOAD-FREE-EVENT` for that
reason -- it was `%DISPATCH-GAME-EVENT` while the game's four events were the
only such family.

A buffer-needed handler is called from whichever thread advances the streaming
queue, which is the game thread while the loop runs -- CNA's own route says so.
The rule above about the *owner* thread is therefore satisfied by the ordinary
game loop and is not a new claim about foreign threads.

**A subscription made during a construction is part of that construction.** An
initializer that subscribes and then signals used to leave CNA holding the
registration and the private registry holding the token that roots the object,
for any event-raising class -- and every exported class here is subclassable.
`%SUBSCRIBE-EVENT` records a construction undo while the object is still
constructing, so the rollback releases the registration and drops the token; once
`MAKE-INSTANCE` has returned it records nothing, because a subscription a program
made is an ordinary thing it did and nothing may undo it on the program's behalf.
`NATIVE-OBJECT` carries the flag that tells the two apart, rather than the
construction ledger's emptiness being read as one.
