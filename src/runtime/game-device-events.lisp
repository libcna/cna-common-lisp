;;;; game-device-events.lisp --- Game's private device-event wiring.
;;;;
;;;; XNA's `Game' subscribes to the graphics device service on its own behalf, in
;;;; a private method the program cannot see, call or unsubscribe. Nothing in the
;;;; public surface names it, so nothing in the compatibility scoreboard moves
;;;; when it exists -- and a game whose device is disposed without it silently
;;;; keeps every asset its content manager loaded. It is a lifecycle invariant
;;;; rather than a member, which is why it lives in a file of its own.
;;;;
;;;; **The pinned flow, transcribed from
;;;; `Microsoft.Xna.Framework.Game.dll' 4.0.0.0 (SHA-256 b5dffdd8125abef2...),
;;;; not from a description of it and not from MonoGame or FNA.**
;;;;
;;;; `Game::RunGame(bool)' is where the order is set, and it matters:
;;;;
;;;;     this.graphicsDeviceManager = Services.GetService(IGraphicsDeviceManager)
;;;;                                   as IGraphicsDeviceManager;
;;;;     if (this.graphicsDeviceManager != null)
;;;;         this.graphicsDeviceManager.CreateDevice();   // <-- before Initialize
;;;;     this.Initialize();
;;;;
;;;; `Game::Initialize()' -- `family newslot virtual', the overridable one:
;;;;
;;;;     IL_0000: ldarg.0
;;;;     IL_0001: call instance void Game::HookDeviceEvents()   // first statement
;;;;     ... initialize every component in notYetInitialized ...
;;;;     if (graphicsDeviceService != null &&
;;;;         graphicsDeviceService.GraphicsDevice != null)
;;;;         this.LoadContent();
;;;;
;;;; `Game::HookDeviceEvents()' -- private, 133 bytes, the whole of it:
;;;;
;;;;     this.graphicsDeviceService = Services.GetService(IGraphicsDeviceService)
;;;;                                   as IGraphicsDeviceService;
;;;;     if (this.graphicsDeviceService == null) return;
;;;;     graphicsDeviceService.DeviceCreated   += this.DeviceCreated;
;;;;     graphicsDeviceService.DeviceResetting += this.DeviceResetting;
;;;;     graphicsDeviceService.DeviceReset     += this.DeviceReset;
;;;;     graphicsDeviceService.DeviceDisposing += this.DeviceDisposing;
;;;;
;;;; The four private handlers, in full:
;;;;
;;;;     DeviceCreated   -> this.LoadContent();
;;;;     DeviceResetting -> (empty: a single `ret')
;;;;     DeviceReset     -> (empty: a single `ret')
;;;;     DeviceDisposing -> this.content.Unload(); this.UnloadContent();
;;;;
;;;; `Game::UnhookDeviceEvents()' -- private, removes the same four in the same
;;;; order, guarded by the same null test, and **does not clear the field**.
;;;;
;;;; `Game::Dispose(bool)' calls them in this order, under `lock (this)':
;;;;
;;;;     dispose every IDisposable game component
;;;;     dispose graphicsDeviceManager if it is IDisposable   // raises DeviceDisposing
;;;;     UnhookDeviceEvents()                                 // *after* that
;;;;     raise Disposed
;;;;
;;;; -- so the manager's disposal happens while the private handler is still
;;;; subscribed. That is the shutdown path, and it is the reason the wiring is
;;;; load-bearing rather than decorative.
;;;;
;;;; **What CNA already does, measured rather than assumed.** With a game and a
;;;; `GRAPHICS-DEVICE-MANAGER' on ABI 0.23.0 HEADLESS, disposing the manager
;;;; produces exactly:
;;;;
;;;;     EVENT device-disposing
;;;;     LIFECYCLE unload-content        <- CNA's own callback
;;;;     EVENT disposed
;;;;
;;;; **CNA's native game already drives `Game.UnloadContent', at exactly the point
;;;; XNA's private handler would call it.** So this file implements the *first*
;;;; half of XNA's handler and not the second: calling UNLOAD-CONTENT here would
;;;; run the program's overridable method twice for one device disposal, which is
;;;; a defect and not fidelity. The resulting order is XNA's --
;;;; `content.Unload()' and then `UnloadContent()' -- because the event runs
;;;; before the callback.
;;;;
;;;; **`DeviceCreated -> LoadContent' is deliberately not wired here, for the same
;;;; measured reason.** The same probe shows CNA driving LOAD-CONTENT itself after
;;;; the first device is created:
;;;;
;;;;     EVENT device-created
;;;;     LIFECYCLE initialize
;;;;     LIFECYCLE load-content
;;;;
;;;; A handler here would double it on every ordinary run. XNA avoids the same
;;;; double a different way -- `CreateDevice()' runs *before* `Initialize()', so
;;;; the first creation happens while nothing is subscribed yet, and
;;;; `Initialize''s tail calls `LoadContent' once. CNA reproduces that sequence
;;;; natively (the `device-created' event above precedes `initialize'), so the
;;;; ordinary path is already right. What is *not* covered either way is content
;;;; reload after a **later** device re-creation, which CNA does not drive: two
;;;; `CREATE-DEVICE' calls raise created/resetting/reset/created and no
;;;; `load-content'. That is a separate hole, recorded in docs/limitations.md and
;;;; measured rather than guessed at; it is not the same invariant as this one and
;;;; wiring it blind would break the common path to fix the rare one.

(in-package #:microsoft.xna.framework)

(defun %game-device-service (game)
  "`Services.GetService(typeof(IGraphicsDeviceService)) as IGraphicsDeviceService'.

`isinst' answers null rather than throwing when the service is absent or is not
the interface, so a lookup that finds nothing is NIL here and not a condition."
  (ignore-errors
   (let ((service (get-service (services game) 'igraphics-device-service)))
     (and (typep service 'graphics-device-manager) service))))

;;; --- the four private handlers ----------------------------------------------

(defun %game-device-created (game)
  "XNA's private `Game::DeviceCreated'. See the file header for why it is empty."
  (declare (ignore game))
  (values))

(defun %game-device-resetting (game)
  "XNA's private `Game::DeviceResetting'. A single `ret' there, and here."
  (declare (ignore game))
  (values))

(defun %game-device-reset (game)
  "XNA's private `Game::DeviceReset'. A single `ret' there, and here."
  (declare (ignore game))
  (values))

(defun %game-device-disposing (game)
  "XNA's private `Game::DeviceDisposing': unload what the game's content holds.

**The current reference, read now.** XNA's handler is `ldarg.0; ldfld content;
callvirt ContentManager::Unload()' -- a read of the field *at the moment the
event arrives*, not of whatever the field held when the handler was installed. So
a game whose `CONTENT' was reassigned unloads the manager it was reassigned to,
and this reads the slot here rather than closing over it.

**A slot that is still NIL means there is nothing to unload, and nothing is
built.** XNA's field is filled by the `Game' constructor and is never null, so
its handler always has a manager to call; this binding makes `CONTENT' lazily,
so the slot is NIL until something reads or assigns it. The two are equivalent
where it counts: an asset can only enter the game's content manager through the
property, so a NIL slot is a manager that has loaded nothing and whose `UNLOAD'
would clear two empty collections. Materialising the facade during teardown --
which resolves a borrowed handle out of a game that is being torn down -- to
call a no-op on it would be an implementation detail changing framework
behaviour in the direction this file exists to prevent.

`UNLOAD' itself is unchanged and is not re-implemented here: newest asset first,
a font before the atlas it keeps alive, every later asset still attempted after
one fails, and the first condition re-signalled once the manager is empty."
  (let ((manager (%game-content game)))
    (when manager
      (microsoft.xna.framework.content:unload manager)))
  (values))

;;; --- HookDeviceEvents / UnhookDeviceEvents ----------------------------------

(defparameter +game-device-event-wiring+
  '((:device-created   . %game-device-created)
    (:device-resetting . %game-device-resetting)
    (:device-reset     . %game-device-reset)
    (:device-disposing . %game-device-disposing))
  "XNA's four subscriptions, in `HookDeviceEvents''s own order.

The order is not decoration. All four go into one multicast delegate there and
one handler list here, and a program's handlers are interleaved with them by
subscription time, so the order the framework subscribes in is observable
between the framework's own four.")

(defun %hook-device-events (game)
  "XNA's private `Game::HookDeviceEvents'. Called from INITIALIZE's default method.

Finds the service exactly as XNA does, stores it in the game's own field, and
returns having done nothing else when there is none -- a game with no
`GRAPHICS-DEVICE-MANAGER' hooks nothing and is not an error.

**Installation is all-or-nothing.** XNA's four `add_' calls cannot fail; here the
first one for an event kind asks CNA for a registration, which can. A failure
part-way would leave the game subscribed to some events and not others, and
disposed later would give back only what it remembered -- so the installed
listeners are unwound before the condition is allowed out, and the game is left
exactly as unhooked as it was before the call."
  (let ((service (%game-device-service game)))
    (setf (%game-graphics-device-service game) service)
    (when service
      (let ((installed '()))
        (handler-bind
            ((serious-condition
               (lambda (condition)
                 (declare (ignore condition))
                 (when installed
                   (ignore-errors (%manager-remove-framework-listeners service game))
                   (setf (%game-device-event-listeners game) '())))))
          (dolist (row +game-device-event-wiring+)
            (let ((handler (cdr row)))
              (push (%manager-add-framework-listener
                     service (car row) game
                     (lambda (sender) (declare (ignore sender)) (funcall handler game)))
                    installed))))
        (setf (%game-device-event-listeners game)
              (append (%game-device-event-listeners game) (nreverse installed)))))
    service))

(defun %unhook-device-events (game)
  "XNA's private `Game::UnhookDeviceEvents'. Called from the game's disposal.

Reads the same field `%HOOK-DEVICE-EVENTS' filled, as XNA's does, and does
nothing when it is NIL. **Cannot signal**: it runs inside the game's disposal
unwind, where a condition would replace whatever was already being signalled.

Like XNA's, it leaves the field alone rather than clearing it."
  (let ((service (%game-graphics-device-service game)))
    (when service
      (ignore-errors (%manager-remove-framework-listeners service game)))
    (setf (%game-device-event-listeners game) '())
    (values)))

(setf *device-event-hook* (lambda (game) (%hook-device-events game))
      *device-event-unhook* (lambda (game) (%unhook-device-events game)))
