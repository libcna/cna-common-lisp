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
   not flattened into a string;
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
