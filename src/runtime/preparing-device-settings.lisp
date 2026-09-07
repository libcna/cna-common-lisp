;;;; preparing-device-settings.lisp --- PreparingDeviceSettingsEventArgs and the
;;;; one event in this binding whose argument can be changed.
;;;;
;;;; **This is the event an XNA application overrides device settings with**, and
;;;; until now it was not reachable at all. It is reachable because CNA fixed it
;;;; at the source: `cna_graphics_device_manager_subscribe_preparing_device_settings_ext'
;;;; hands the handler a **mutable** `CNA_GraphicsDeviceInformation*' whose writes
;;;; "are kept and are what the device is then created from", where the older
;;;; `..._subscribe_preparing_device_settings' takes the same structure `const'
;;;; and can only observe. The observation-only route is deliberately not bound:
;;;; binding it would be projecting a member whose entire purpose is to change
;;;; something, onto a route that cannot.
;;;;
;;;; The flow, and every step of it is load-bearing:
;;;;
;;;;     CNA calls back with a borrowed, mutable CNA_GraphicsDeviceInformation*
;;;;         -> read it into ONE CLOS GRAPHICS-DEVICE-INFORMATION
;;;;         -> wrap that in ONE PREPARING-DEVICE-SETTINGS-EVENT-ARGS
;;;;         -> invoke the virtual ON-PREPARING-DEVICE-SETTINGS
;;;;         -> whose default method raises the managed handler list
;;;;         -> handlers mutate the CLOS object
;;;;         -> write the final CLOS state back into the borrowed struct
;;;;         -> return through C
;;;;
;;;; **One object for the whole callback**, which is what makes the mutation
;;;; work: a fresh information object per property read would give each handler
;;;; its own copy and drop every change. The event-args object is ephemeral -- XNA
;;;; constructs one per raise too -- but its `GraphicsDeviceInformation' answers
;;;; the same object for the life of the call, because XNA's is a plain field read
;;;; of a field the constructor sets once.
;;;;
;;;; **A Lisp condition never unwinds through C.** The callback answers `void',
;;;; so CNA has nowhere to put a failure and says so itself: "a handler that
;;;; cannot decide what to change simply changes nothing, and there is no failure
;;;; for it to report that device preparation could act on". A handler's condition
;;;; is contained by the established policy and re-signalled by the first native
;;;; call that returns to the program -- which for a handler reached during
;;;; `CREATE-DEVICE' or `APPLY-CHANGES' is that call.
;;;;
;;;; **What happens to the settings when a handler fails is CNA's rule and not
;;;; this binding's.** The write-back is skipped when the containment caught a
;;;; condition, so a handler that died half way through leaves the proposal
;;;; exactly as CNA computed it rather than half-applied. CNA validates the
;;;; structure afterwards in any case and "an invalid structure is ignored rather
;;;; than obeyed", so a corrupted write would have been dropped there too; doing
;;;; it here means the *reason* is a Lisp condition rather than a silent native
;;;; no-op.

(in-package #:microsoft.xna.framework)

(defclass preparing-device-settings-event-args ()
  ((%graphics-device-information :initarg :graphics-device-information
                                 :reader graphics-device-information))
  (:documentation
   "Microsoft.Xna.Framework.PreparingDeviceSettingsEventArgs.

    (add-preparing-device-settings-handler
     manager
     (lambda (sender args)
       (let ((info (graphics-device-information args)))
         (setf (back-buffer-width (presentation-parameters-of info)) 1280))))

Carries the candidate configuration a handler may change before the device
exists. Derives from `System.EventArgs' in XNA, which this projection has no
counterpart for and does not invent -- an empty base class with no members is not
a type a Lisp program can use, and this binding collapses `EventArgs.Empty'
everywhere rather than projecting the hierarchy.

**This is the one event whose handler takes two arguments.** Everywhere else the
argument is `EventArgs.Empty' and is collapsed away; here it carries the thing the
event exists for, so it is passed."))

(defmethod print-object ((args preparing-device-settings-event-args) stream)
  (print-unreadable-object (args stream :type t)
    (princ (graphics-device-information args) stream)))

(defgeneric on-preparing-device-settings (manager sender args)
  (:documentation
   "GraphicsDeviceManager.OnPreparingDeviceSettings(Object,
PreparingDeviceSettingsEventArgs): raise PreparingDeviceSettings.

`family hidebysig newslot virtual' in the pinned assembly, and a real seam here
exactly as the four data-free raisers are:

    (defmethod on-preparing-device-settings ((manager my-manager) sender args)
      (setf (graphics-profile-of (graphics-device-information args)) :reach)
      (call-next-method))

An override that does not call the next method suppresses the public event, and
**still keeps its own mutations**: the write-back happens after this generic
function returns, over whatever state the information object is left in. So an
override can both replace the handlers' say and have one of its own, which is what
overriding a protected raiser is for.

SENDER is the manager. ARGS is the PREPARING-DEVICE-SETTINGS-EVENT-ARGS, and its
information object is the same object for the whole callback.")
  (:method ((manager graphics-device-manager) sender args)
    (dolist (handler (%manager-handlers manager :preparing-device-settings))
      ;; %LISTENER-FUNCTION for the reason %MANAGER-RAISE uses it: a handler list
      ;; may hold framework listeners beside the program's handlers. The framework
      ;; installs none on *this* event -- `Game::HookDeviceEvents' subscribes to
      ;; four and this is not one of them -- so the unwrap is uniformity rather
      ;; than a live case, and it costs one type test.
      (funcall (%listener-function handler) sender args))
    (values)))

(%define-event-pair add-preparing-device-settings-handler
                    remove-preparing-device-settings-handler
  "GraphicsDeviceManager.PreparingDeviceSettings's `+=': change the device settings
before the device is created.

    (add-preparing-device-settings-handler
     manager
     (lambda (sender args)
       (setf (multi-sample-count (presentation-parameters-of
                                  (graphics-device-information args)))
             4)))

HANDLER takes **two** arguments -- the sender and the event args -- unlike every
other event in this binding, whose argument is `EventArgs.Empty' and is collapsed.
This one carries the candidate configuration, which is the whole point of the
event.

What the handler writes is what the device is then created from. The handler runs
inside device preparation, which CREATE-DEVICE and APPLY-CHANGES both enter, after
the manager has computed its proposal and before anything is created -- so this is
different from setting the manager's preference properties, and it is what XNA
programs use to request multisampling, pick a back-buffer format or choose an
adapter.

Raised by ON-PREPARING-DEVICE-SETTINGS and only by it, so a subclass overriding
that method without calling the next one stops this event reaching handlers.

A condition the handler signals cannot be reported to CNA -- the callback answers
void -- so it is contained and re-signalled by the call that entered device
preparation, and the settings are left as CNA proposed them.")

(defmethod add-preparing-device-settings-handler
    ((manager graphics-device-manager) handler)
  (check-type handler (or function symbol))
  (%ensure-preparing-device-settings-raiser manager)
  (let ((row (assoc :preparing-device-settings (%manager-handler-lists manager)
                    :test #'eq)))
    (if row
        (push handler (cdr row))
        (push (list :preparing-device-settings handler)
              (%manager-handler-lists manager))))
  handler)

(defmethod remove-preparing-device-settings-handler
    ((manager graphics-device-manager) handler)
  (let ((row (assoc :preparing-device-settings (%manager-handler-lists manager)
                    :test #'eq)))
    (when (and row (member handler (cdr row) :test #'eq))
      (setf (cdr row) (remove handler (cdr row) :test #'eq :count 1))
      (unless (cdr row)
        (setf (%manager-handler-lists manager)
              (remove row (%manager-handler-lists manager)))
        (%release-preparing-device-settings-raiser manager))
      t)))

;;; --- the native side ---------------------------------------------------------

(defparameter *preparing-device-settings-raiser-key* :preparing-device-settings
  "The key `%MANAGER-RAISERS' files this event's registration under.

It is not a `CNA_GraphicsDeviceManagerEvent': this event has a subscribe route of
its own and a callback shape of its own, so it is not in
`*GRAPHICS-DEVICE-MANAGER-EVENT-VALUES*' and `%ENSURE-MANAGER-RAISER' would not
know how to make it. It shares the raiser *table* because release and teardown are
the same work.")

(defun %ensure-preparing-device-settings-raiser (manager)
  "Subscribe MANAGER to CNA's mutable device-settings callback, once."
  (when (or (assoc *preparing-device-settings-raiser-key* (%manager-raisers manager)
                   :test #'eq)
            (cna-lisp.internal:disposed-state-of manager))
    (return-from %ensure-preparing-device-settings-raiser nil))
  (cna-lisp.internal:check-usable manager "add-preparing-device-settings-handler")
  (let ((token (cna-lisp.internal:register-callback-target manager)))
    (handler-case
        (cffi:with-foreign-object (registration :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%graphics-device-manager-subscribe-preparing-device-settings-ext
            (cna-lisp.internal:handle-of manager)
            (cna-lisp.internal.ffi:preparing-device-settings-callback-pointer)
            (cffi:make-pointer token) registration)
           "add-preparing-device-settings-handler" :object-type 'graphics-device-manager)
          (push (list* *preparing-device-settings-raiser-key* token
                       (cffi:mem-ref registration :uint64))
                (%manager-raisers manager))
          (when (cna-lisp.internal:constructing-p manager)
            (cna-lisp.internal:record-construction-undo
             manager (lambda () (%release-preparing-device-settings-raiser manager))))
          t)
      (serious-condition (condition)
        (cna-lisp.internal:unregister-callback-target token)
        (error condition)))))

(defun %release-preparing-device-settings-raiser (manager)
  "Give the device-settings registration back, if MANAGER holds one.

CNA's route says its registration is \"released with `cna_game_unsubscribe' like
every other registration in this ABI\", so this is the same release the four
data-free events use."
  (%release-manager-raiser manager *preparing-device-settings-raiser-key*))

(defun %dispatch-preparing-device-settings (token information)
  "CNA is preparing device settings: read, raise, write back.

INFORMATION is borrowed and mutable for the duration of this call and must not
outlive it, which is why the CLOS object is a *copy* that is written back rather
than a view onto the pointer: a handler that stashed the information object would
otherwise be holding a dangling pointer the moment the call returned."
  (let ((manager (cna-lisp.internal:callback-target token)))
    (when manager
      (let* ((game (game manager))
             (info (%read-graphics-device-information information game))
             (args (make-instance 'preparing-device-settings-event-args
                                  :graphics-device-information info))
             (raised nil))
        ;; The containment policy owns what happens to a handler's condition; all
        ;; this needs to know is whether one was caught, because the write-back is
        ;; what must not happen if so.
        (cna-lisp.internal:with-event-dispatch
            (progn (on-preparing-device-settings manager manager args)
                   (setf raised t)))
        (when raised
          (%write-graphics-device-information information info))))
    (values)))

(setf cna-lisp.internal.ffi:*preparing-device-settings-dispatcher*
      #'%dispatch-preparing-device-settings)
