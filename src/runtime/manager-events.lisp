;;;; manager-events.lisp --- GraphicsDeviceManager's events, through its virtual
;;;; On* methods.
;;;;
;;;; **This is a different mechanism from the one every other event in this
;;;; binding uses, and the difference is the point.** Everywhere else, one user
;;;; handler is one CNA registration: `%SUBSCRIBE-EVENT' asks CNA for a
;;;; registration per handler and CNA calls each of them. That cannot implement
;;;; what `GraphicsDeviceManager' has, because in XNA the framework does not call
;;;; the handlers at all -- it calls a **protected virtual method**, and the base
;;;; implementation is what raises the handler list:
;;;;
;;;;     .method family hidebysig newslot virtual
;;;;             instance void OnDeviceCreated(object sender, EventArgs args)
;;;;       ldarg.0; ldfld deviceCreated; brfalse.s ret
;;;;       ldarg.0; ldfld deviceCreated; ldarg.1; ldarg.2; callvirt Invoke
;;;;
;;;; All five are `family ... newslot virtual' and all five have that body, so a
;;;; subclass that overrides one and does not call the base implementation
;;;; **suppresses the public event**. With one native registration per handler,
;;;; CNA would call every handler directly and an override could suppress
;;;; nothing.
;;;;
;;;; So the shape here is:
;;;;
;;;;     CNA raises the event
;;;;         -> one native registration per event *kind*
;;;;         -> the CLOS generic function ON-DEVICE-CREATED (etc.)
;;;;         -> whose default method raises the managed handler list
;;;;
;;;; and a `CALL-NEXT-METHOD' from an override is what XNA's `base.OnDeviceCreated'
;;;; is. That is the managed/native split this binding already draws elsewhere,
;;;; drawn one level higher.
;;;;
;;;; **`Disposed' is the exception and is not a virtual seam**, because XNA's
;;;; isn't: `Dispose(bool)' loads the `Disposed' field and invokes it inline, with
;;;; no `OnDisposed' anywhere in the type. It still goes through the single
;;;; registration, because the registration is about how many times CNA is asked
;;;; rather than about virtual dispatch.
;;;;
;;;; **Handlers run oldest first.** A .NET multicast delegate invokes its
;;;; invocation list in subscription order, and now that one raiser owns the whole
;;;; list this binding can honour that; with a registration per handler the order
;;;; was CNA's.

(in-package #:microsoft.xna.framework)

;;; --- the managed handler lists and the raisers -------------------------------

(defun %manager-handlers (manager event)
  "MANAGER's handler list for EVENT, oldest first.

Entries are user handlers -- functions or symbols -- and, mixed in among them in
subscription order, the framework listeners described below. Call
`%LISTENER-FUNCTION' on an entry rather than funcalling it directly."
  (reverse (cdr (assoc event (%manager-handler-lists manager) :test #'eq))))

;;; --- framework listeners ------------------------------------------------
;;;
;;; **XNA's framework subscribes to these events itself, and its subscriptions
;;; sit in the same multicast delegate as the program's.** `Game.Initialize' calls
;;; the private `Game::HookDeviceEvents', whose whole body is a service lookup and
;;; four `add_' calls on `IGraphicsDeviceService':
;;;
;;;     this.graphicsDeviceService = Services.GetService(IGraphicsDeviceService)
;;;                                   as IGraphicsDeviceService;
;;;     if (this.graphicsDeviceService == null) return;
;;;     graphicsDeviceService.DeviceCreated   += this.DeviceCreated;
;;;     graphicsDeviceService.DeviceResetting += this.DeviceResetting;
;;;     graphicsDeviceService.DeviceReset     += this.DeviceReset;
;;;     graphicsDeviceService.DeviceDisposing += this.DeviceDisposing;
;;;
;;; A `Delegate' cannot tell the framework's entries from the program's, and the
;;; invocation list runs in subscription order, so **where the framework's
;;; listener falls among the program's handlers depends on when it subscribed** --
;;; before every handler added after `Initialize', after every handler added
;;; before it. That is observable, so it is reproduced rather than normalised.
;;;
;;; They are a distinct type here for the one thing .NET gets for free and this
;;; does not: identity. XNA's `-=' takes a delegate, and a program has no way to
;;; name the framework's, so it cannot remove it by accident. `%MANAGER-ADD-
;;; HANDLER' accepts only a function or a symbol, so a listener can never be
;;; `EQ' to anything a program could pass to `%MANAGER-REMOVE-HANDLER' -- the
;;; private subscription survives every public `-=', which is XNA's behaviour and
;;; the reason for the wrapper.

(defstruct (%framework-listener (:constructor %make-framework-listener (owner function))
                                (:copier nil))
  "One subscription the framework made on its own behalf.

OWNER is the object whose lifecycle installed it -- a `GAME' -- and is what
`%MANAGER-REMOVE-FRAMEWORK-LISTENERS' keys on, so a game gives back exactly its
own listeners however many it installed."
  (owner nil :read-only t)
  (function nil :read-only t))

(defun %listener-function (entry)
  "The function to call for one entry of a handler list."
  (if (%framework-listener-p entry) (%framework-listener-function entry) entry))

(defun %manager-add-framework-listener (manager event owner function)
  "Subscribe FUNCTION to MANAGER's EVENT on OWNER's behalf, as XNA's framework does.

Goes into the same list, in the same order, as a program's own handler: this is
one `+=' on one multicast delegate and nothing about it is a second event source.
Answers the listener, which is the only handle on it that exists."
  (%ensure-manager-raiser manager event)
  (let ((listener (%make-framework-listener owner function))
        (row (assoc event (%manager-handler-lists manager) :test #'eq)))
    (if row
        (push listener (cdr row))
        (push (list event listener) (%manager-handler-lists manager)))
    listener))

(defun %manager-remove-framework-listeners (manager owner)
  "Give back every framework listener OWNER installed on MANAGER. Answers how many.

Nothing here may signal: it runs while OWNER is being disposed. The native
registration is released when a list empties, exactly as a public `-=' releases
it, so a game that hooked and unhooked leaves the callback registry where it
found it."
  (let ((removed 0))
    (dolist (row (copy-list (%manager-handler-lists manager)))
      (let ((keep (remove-if (lambda (entry)
                               (and (%framework-listener-p entry)
                                    (eq (%framework-listener-owner entry) owner)))
                             (cdr row))))
        (unless (= (length keep) (length (cdr row)))
          (incf removed (- (length (cdr row)) (length keep)))
          (setf (cdr row) keep)
          (unless keep
            (setf (%manager-handler-lists manager)
                  (remove row (%manager-handler-lists manager)))
            (ignore-errors (%release-manager-raiser manager (car row)))))))
    removed))

(defun %manager-raise (manager event sender)
  "Invoke every handler subscribed to EVENT, in subscription order.

Each handler is called with the sender alone. `EventArgs.Empty' carries nothing,
and this binding has collapsed it everywhere rather than asking every handler to
write and ignore a second always-empty argument -- see
`src/runtime/event-machinery.lisp', which made that decision for `Game''s four
events and which this follows rather than diverging from."
  (dolist (handler (%manager-handlers manager event))
    (funcall (%listener-function handler) sender))
  (values))

(defun %manager-event-value (event)
  "EVENT's `CNA_GraphicsDeviceManagerEvent', or NIL for one CNA raises otherwise."
  (cdr (assoc event *graphics-device-manager-event-values* :test #'eq)))

(defun %ensure-manager-raiser (manager event)
  "Make sure CNA is calling MANAGER back for EVENT, once.

Nothing is asked of CNA for a disposed manager: no event can reach it, because
the native side gave its registrations back when it was destroyed, so the
subscription is purely managed there. That is `%EVENT-SOURCE-DISPOSED-P''s rule
and the reason for it, applied here."
  (when (or (assoc event (%manager-raisers manager) :test #'eq)
            (cna-lisp.internal:disposed-state-of manager))
    (return-from %ensure-manager-raiser nil))
  (cna-lisp.internal:check-usable manager "add-event-handler")
  (let* ((value (%manager-event-value event))
         ;; The registry entry is `(SENDER . FUNCTION)', which is what
         ;; %DISPATCH-PAYLOAD-FREE-EVENT already destructures -- so this needs no
         ;; dispatcher of its own. The function it stores is the raiser rather
         ;; than a user handler, which is the whole difference.
         (token (cna-lisp.internal:register-callback-target
                 (cons manager
                       (lambda (sender) (%manager-dispatch-event manager event sender))))))
    (handler-case
        (cffi:with-foreign-object (registration :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%graphics-device-manager-subscribe
            (cna-lisp.internal:handle-of manager) value
            (cna-lisp.internal.ffi:game-event-callback-pointer)
            (cffi:make-pointer token) registration)
           "add-event-handler" :object-type 'graphics-device-manager)
          (push (list* event token (cffi:mem-ref registration :uint64))
                (%manager-raisers manager))
          ;; A registration acquired during a construction belongs in that
          ;; construction's ledger, for the reason %SUBSCRIBE-EVENT records one:
          ;; an initializer that subscribes and then fails would otherwise leave
          ;; CNA holding a registration and the registry holding the token that
          ;; roots the object.
          (when (cna-lisp.internal:constructing-p manager)
            (cna-lisp.internal:record-construction-undo
             manager (lambda () (%release-manager-raiser manager event))))
          t)
      (serious-condition (condition)
        (cna-lisp.internal:unregister-callback-target token)
        (error condition)))))

(defun %release-manager-raiser (manager event)
  "Give EVENT's native registration back, if MANAGER holds one.

The native registration is released **before** the local row is forgotten, for
the reason `%UNSUBSCRIBE-EVENT' gives at length: `cna_game_unsubscribe' raises
every failure it can raise before releasing anything, so a failure means the
registration is still live and forgetting the row would strand it."
  (let ((row (assoc event (%manager-raisers manager) :test #'eq)))
    (when row
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-unsubscribe (cddr row))
       "remove-event-handler" :object-type 'graphics-device-manager)
      (cna-lisp.internal:unregister-callback-target (second row))
      (setf (%manager-raisers manager)
            (remove row (%manager-raisers manager)))
      t)))

(defun %release-manager-raisers (manager)
  "Release every native registration MANAGER holds, and keep its handler lists.

Called while the manager is being destroyed. **The logical subscriptions survive
and the native ones do not**, which is what XNA does: its disposal never empties a
delegate field, so a program that removes a handler afterwards must still be told
it was there. Nothing here may signal -- it runs on the teardown path -- and that
is sound for the same narrow reason `%RELEASE-EVENT-HANDLERS' is: it runs on the
manager's own thread, after its own destruction, on registrations nothing can
reach."
  (dolist (row (%manager-raisers manager))
    (ignore-errors (cna-lisp.internal.ffi::%game-unsubscribe (cddr row)))
    (ignore-errors (cna-lisp.internal:unregister-callback-target (second row))))
  (setf (%manager-raisers manager) '())
  nil)

(defun %manager-add-handler (manager event function)
  "The `+=' of one of MANAGER's events."
  (check-type function (or function symbol))
  (unless (%manager-event-value event)
    (error 'cna-usage-error
           :operation "add-event-handler"
           :format-control "~s does not raise a ~s event."
           :format-arguments (list (type-of manager) event)))
  (%ensure-manager-raiser manager event)
  (let ((row (assoc event (%manager-handler-lists manager) :test #'eq)))
    (if row
        (push function (cdr row))
        (push (list event function) (%manager-handler-lists manager))))
  function)

(defun %manager-remove-handler (manager event function)
  "The `-=' of one of MANAGER's events. Answers whether it found one to remove.

Releases the native registration when the last handler for EVENT goes, so that a
lifecycle that subscribes and unsubscribes leaves the callback registry exactly
where it found it -- the property the ownership and stress lanes assert."
  (let ((row (assoc event (%manager-handler-lists manager) :test #'eq)))
    (when (and row (member function (cdr row) :test #'eq))
      ;; The most recently added match, which is what `Delegate.Remove' removes
      ;; and what this binding's other `-=' already does.
      (setf (cdr row) (remove function (cdr row) :test #'eq :count 1))
      (unless (cdr row)
        (setf (%manager-handler-lists manager)
              (remove row (%manager-handler-lists manager)))
        (%release-manager-raiser manager event))
      t)))

;;; --- the five protected virtual methods --------------------------------------
;;;
;;; `family hidebysig newslot virtual' in the pinned assembly, which is
;;; `protected virtual' in C#. A CLOS generic function is the projection: a
;;; subclass adds a method, and `CALL-NEXT-METHOD' is `base.OnX(...)'.
;;;
;;; The argument shape is `(MANAGER SENDER)' rather than `(MANAGER SENDER ARGS)'.
;;; XNA's signature is `OnX(object sender, EventArgs args)', and `EventArgs' here
;;; is always `EventArgs.Empty' -- every raise site in the assembly loads
;;; `ldsfld EventArgs::Empty' -- so it is collapsed exactly as it is collapsed in
;;; the public handler shape. `Object sender' is **not** collapsed: it is a real
;;; value a handler receives, and every raise site passes the manager (`ldarg.0;
;;; ldarg.0'), so it is the manager in practice and an argument in principle.
;;; `docs/common-lisp-mapping.md' records both halves of that.

(macrolet
    ((define-raiser (name event documentation)
       `(progn
          (defgeneric ,name (manager sender)
            (:documentation ,documentation)
            (:method ((manager graphics-device-manager) sender)
              (%manager-raise manager ,event sender))))))
  (define-raiser on-device-created :device-created
    "GraphicsDeviceManager.OnDeviceCreated(Object, EventArgs): raise DeviceCreated.

Protected and virtual in XNA, and a real seam here:

    (defmethod on-device-created ((manager my-manager) sender)
      (note-it)
      (call-next-method))            ; base.OnDeviceCreated -- the event is raised

An override that does **not** call the next method suppresses the public event,
because the base implementation is the only thing that invokes the handler list.
That is XNA's behaviour and not an accident of this projection.

SENDER is the manager: every raise site in the pinned assembly passes `this'.")
  (define-raiser on-device-disposing :device-disposing
    "GraphicsDeviceManager.OnDeviceDisposing(Object, EventArgs): raise
DeviceDisposing. Protected and virtual; see ON-DEVICE-CREATED for the seam.")
  (define-raiser on-device-reset :device-reset
    "GraphicsDeviceManager.OnDeviceReset(Object, EventArgs): raise DeviceReset.
Protected and virtual; see ON-DEVICE-CREATED for the seam.")
  (define-raiser on-device-resetting :device-resetting
    "GraphicsDeviceManager.OnDeviceResetting(Object, EventArgs): raise
DeviceResetting. Protected and virtual; see ON-DEVICE-CREATED for the seam."))

(defun %manager-dispatch-event (manager event sender)
  "Route one native event to the virtual method that owns it.

`Disposed' has no virtual method because XNA has none: `Dispose(bool)' invokes
the `Disposed' field inline. It reaches the handler list directly rather than
through a seam this projection would have invented."
  (ecase event
    (:device-created (on-device-created manager sender))
    (:device-disposing (on-device-disposing manager sender))
    (:device-reset (on-device-reset manager sender))
    (:device-resetting (on-device-resetting manager sender))
    (:disposed (%manager-raise manager :disposed sender)))
  (values))

;;; --- the public event pairs --------------------------------------------------

(macrolet ((manager-methods (event add remove)
             `(progn
                (defmethod ,add ((manager graphics-device-manager) handler)
                  (%manager-add-handler manager ,event handler))
                (defmethod ,remove ((manager graphics-device-manager) handler)
                  (%manager-remove-handler manager ,event handler))))
           (manager-event (event add remove documentation)
             `(progn
                (%define-event-pair ,add ,remove ,documentation)
                (manager-methods ,event ,add ,remove))))
  ;; `Disposed' shares GAME's pair -- the generic functions are declared in
  ;; runtime/game-events.lisp and every disposable type in this binding adds a
  ;; method to them -- so this adds methods and does not redeclare them.
  ;;
  ;; **No `OnDisposed' seam either**, because XNA has none: `Dispose(bool)'
  ;; invokes the `Disposed' delegate field directly and the type declares no such
  ;; virtual method, so one here would be invented rather than projected.
  (manager-methods :disposed add-disposed-handler remove-disposed-handler)
  (manager-event :device-created add-device-created-handler
                 remove-device-created-handler
    "GraphicsDeviceManager.DeviceCreated: a graphics device was created.

HANDLER is called with the manager. The device itself is reached through the
game, as it always is: the event carries nothing.

**Raised by ON-DEVICE-CREATED and only by it.** A subclass that overrides that
method without calling the next one stops this event, which is what XNA does.

This is also `IGraphicsDeviceService.DeviceCreated': the service and the class
are one object, so subscribing through either reaches this one handler list.")
  (manager-event :device-resetting add-device-resetting-handler
                 remove-device-resetting-handler
    "GraphicsDeviceManager.DeviceResetting: the device is about to reset. Raised by
ON-DEVICE-RESETTING; also `IGraphicsDeviceService.DeviceResetting'.")
  (manager-event :device-reset add-device-reset-handler remove-device-reset-handler
    "GraphicsDeviceManager.DeviceReset: the device finished resetting. Raised by
ON-DEVICE-RESET; also `IGraphicsDeviceService.DeviceReset'.")
  (manager-event :device-disposing add-device-disposing-handler
                 remove-device-disposing-handler
    "GraphicsDeviceManager.DeviceDisposing: the device is about to be disposed.
Raised by ON-DEVICE-DISPOSING; also `IGraphicsDeviceService.DeviceDisposing'."))
