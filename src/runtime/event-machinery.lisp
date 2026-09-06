;;;; event-machinery.lisp --- the CLR event projection.
;;;;
;;;; XNA raises four events on a `Game': Activated, Deactivated, Exiting and
;;;; Disposed. In C# a caller writes `game.Activated += handler', and the handler
;;;; is an `EventHandler<EventArgs>' -- a sender and an argument object that
;;;; carries nothing.
;;;;
;;;; The projection:
;;;;
;;;;   (add-activated-handler game (lambda (game) ...))
;;;;   (remove-activated-handler game the-same-function)
;;;;
;;;; Three decisions are worth stating.
;;;;
;;;; **The handler takes the sender and nothing else.** `EventArgs.Empty' carries
;;;; no information, and a projection that passed a second always-empty argument
;;;; would be asking every handler to write and ignore it. This is the same
;;;; decision ON-EXITING already records.
;;;;
;;;; **Removal takes the function, not a registration object.** That is what `-='
;;;; takes, so it is what this takes; the game keeps the native registration
;;;; handle beside the function it belongs to and finds it by identity.
;;;;
;;;; **A condition signalled by a handler cannot be reported to CNA.**
;;;; `CNA_GameEventCallback' returns `void'. There is no result code and no
;;;; diagnostic structure, so containment here has nowhere to put a failure
;;;; except the Lisp side. The condition is preserved in the same place a
;;;; lifecycle callback's is, so the next native call that drains it re-signals
;;;; the real condition -- and if no such call ever comes, because the event was
;;;; the game's own disposal, it is lost. That is a real limit and
;;;; docs/callbacks-and-threading.md says so rather than pretending otherwise.

(in-package #:microsoft.xna.framework)

(defparameter *graphics-device-event-values*
  (list (cons :disposing
              cna-lisp.internal.ffi::+graphics-device-event-disposing+)
        (cons :device-lost
              cna-lisp.internal.ffi::+graphics-device-event-device-lost+)
        (cons :device-reset
              cna-lisp.internal.ffi::+graphics-device-event-device-reset+)
        (cons :device-resetting
              cna-lisp.internal.ffi::+graphics-device-event-device-resetting+))
  "GraphicsDevice's four payload-free events.

`DeviceReset' and `DeviceResetting' are **the device's own**, not the
same-named pair on `IGraphicsDeviceService' -- those two are complete on
GRAPHICS-DEVICE-MANAGER, and mistaking one set for the other is a mistake this
project has already made once and written down.")

(defparameter *graphics-device-manager-event-values*
  (list (cons :disposed
              cna-lisp.internal.ffi::+graphics-device-manager-event-disposed+)
        (cons :device-created
              cna-lisp.internal.ffi::+graphics-device-manager-event-device-created+)
        (cons :device-disposing
              cna-lisp.internal.ffi::+graphics-device-manager-event-device-disposing+)
        (cons :device-reset
              cna-lisp.internal.ffi::+graphics-device-manager-event-device-reset+)
        (cons :device-resetting
              cna-lisp.internal.ffi::+graphics-device-manager-event-device-resetting+))
  "The CNA identity of each projected graphics-device-manager event.

CNA raises them through the same CNA_GameEventCallback and releases their
registrations with the same cna_game_unsubscribe, so the machinery below is one
mechanism serving two types rather than two mechanisms.")

(defparameter *game-event-values*
  (list (cons :activated cna-lisp.internal.ffi::+game-event-activated+)
        (cons :deactivated cna-lisp.internal.ffi::+game-event-deactivated+)
        (cons :disposed cna-lisp.internal.ffi::+game-event-disposed+)
        (cons :exiting cna-lisp.internal.ffi::+game-event-exiting+))
  "The CNA identity of each projected game event.")

(defun %dispatch-payload-free-event (token)
  "Invoke the handler TOKEN names. Called from a top-level event callback.

One function for every CNA event that carries nothing but its sender, whatever
family it belongs to: the registry entry is `(SENDER . FUNCTION)' in each case,
and the callback shapes are the same `void (*)(void*)'. It was called
%DISPATCH-GAME-EVENT while the game's four events were the only such family."
  (let ((entry (cna-lisp.internal:callback-target token)))
    (when entry
      (destructuring-bind (sender . function) entry
        (handler-case (funcall function sender)
          (serious-condition (condition)
            ;; Nowhere to report it: see the file header.
            (setf cna-lisp.internal:*pending-callback-condition* condition)))))))

(setf cna-lisp.internal.ffi:*game-event-dispatcher* #'%dispatch-payload-free-event
      ;; CNA_AudioEventCallback is the same shape and its registry entry is the
      ;; same pair, so it is the same dispatcher. What differs is the subscribe
      ;; and unsubscribe routes, and those are the two generic functions below.
      cna-lisp.internal.ffi:*audio-event-dispatcher* #'%dispatch-payload-free-event)

(defgeneric %event-handlers (object)
  (:documentation
   "The live event subscriptions of OBJECT, as a list of
(EVENT FUNCTION TOKEN . REGISTRATION-HANDLE).

Declared here rather than left to DEFCLASS so that this file, which is the whole
mechanism, does not forward-reference the two classes that use it. Each class's
:ACCESSOR adds its method."))

(defgeneric (setf %event-handlers) (value object))

(defgeneric %event-table (object)
  (:documentation "The event keyword-to-CNA-identity table for OBJECT's type."))

(defgeneric %subscribe-natively (object value token registration)
  (:documentation "Call OBJECT's own CNA subscribe route."))

(defgeneric %subscribes-natively-p (object)
  (:documentation
   "Whether OBJECT's events come from CNA.

They do for everything with a handle. They do not for a GraphicsResource CNA
models as a descriptor -- a state object, a vertex declaration -- which is a
GraphicsResource in the contract, raises Disposing like any other, and has no
native object to subscribe to. Saying so here is what keeps the native path from
quietly succeeding on a handle that does not exist, and what keeps a purely
managed subscription out of the callback registry, which the ownership tests
require to be empty after a lifecycle.")
  (:method (object) (declare (ignore object)) t))

(defgeneric %check-event-usable (object operation)
  (:documentation
   "Refuse a subscription on an object that cannot take one.

Almost every type that raises an event holds its own handle, so the default is
NATIVE-OBJECT's own check. A *facade* does not: GAME-COMPONENT-COLLECTION is the
game's collection and has no handle, so what has to be usable is the game.")
  (:method ((object cna-lisp.internal:native-object) operation)
    (cna-lisp.internal:check-usable object operation)))

(defun %subscribe-event (object event function)
  "Subscribe FUNCTION to OBJECT's EVENT, and answer FUNCTION.

One mechanism for every type that raises events: the table, whether the event
comes from CNA at all, and the native route are the only things that differ, and
all three are generic functions on the object."
  (check-type function (or function symbol))
  (let ((native (%subscribes-natively-p object)))
    (when native
      (%check-event-usable object "add-event-handler"))
    (let ((value (or (cdr (assoc event (%event-table object)))
                     (error 'cna-usage-error
                            :operation "add-event-handler"
                            :format-control "~s does not raise a ~s event."
                            :format-arguments (list (type-of object) event)))))
      (unless native
        ;; No token: there is no C callback to resolve one, and an entry left in
        ;; the registry would be a leak the ownership tests would report.
        (push (list* event function nil 0) (%event-handlers object))
        (return-from %subscribe-event function))
      (let ((token (cna-lisp.internal:register-callback-target (cons object function))))
        (handler-case
            (cffi:with-foreign-object (registration :uint64)
              (cna-lisp.internal:check-result
               (%subscribe-natively object value token registration)
               "add-event-handler")
              (push (list* event function token (cffi:mem-ref registration :uint64))
                    (%event-handlers object))
              ;; **A subscription made *during* a construction belongs in that
              ;; construction's ledger.** Otherwise an initializer that subscribes
              ;; and then fails leaves CNA holding a registration and the private
              ;; registry holding the token that roots the object -- which is the
              ;; leak `DynamicSoundEffectInstance''s atomicity test found, and
              ;; which any subclass of any event-raising class could have caused.
              ;; After the construction commits this records nothing: a
              ;; subscription a program made is an ordinary thing it did, and
              ;; nothing may undo it on its behalf.
              (when (and (typep object 'cna-lisp.internal:native-object)
                         (cna-lisp.internal:constructing-p object))
                (cna-lisp.internal:record-construction-undo
                 object
                 (lambda () (%unsubscribe-event object event function))))
              function)
          (serious-condition (condition)
            (cna-lisp.internal:unregister-callback-target token)
            (error condition)))))))

(defgeneric %unsubscribe-natively (object registration)
  (:documentation
   "Release one of OBJECT's registrations. The default is the game's route, which
CNA also uses for the graphics device manager's; a type whose registrations are a
different handle type overrides it."))

(defmethod %unsubscribe-natively (object registration)
  (declare (ignore object))
  (cna-lisp.internal.ffi::%game-unsubscribe registration))

(defun %unsubscribe-event (object event function)
  "Release OBJECT's subscription of FUNCTION to EVENT, if it has one."
  (let ((entry (find-if (lambda (row)
                          (and (eq (first row) event) (eq (second row) function)))
                        (%event-handlers object))))
    (when entry
      (setf (%event-handlers object) (remove entry (%event-handlers object)))
      (when (third entry)
        (cna-lisp.internal:unregister-callback-target (third entry))
        (cna-lisp.internal:check-result
         (%unsubscribe-natively object (cdddr entry))
         "remove-event-handler"))
      t)))

(defun %release-event-handlers (object)
  "Release every live subscription. Called while OBJECT is being destroyed.

Nothing here may signal: it runs on the teardown path, where a condition would
leave the rest of the object undestroyed."
  (dolist (entry (%event-handlers object))
    (when (third entry)
      (ignore-errors (%unsubscribe-natively object (cdddr entry)))
      (ignore-errors (cna-lisp.internal:unregister-callback-target (third entry)))))
  (setf (%event-handlers object) '())
  nil)

(defmacro %define-event-pair (add remove documentation)
  "Define the two generic functions one CLR event projects to."
  `(progn
     (defgeneric ,add (object handler) (:documentation ,documentation))
     (defgeneric ,remove (object handler)
       (:documentation
        ,(format nil "The `-=' of ~a. Answers true when it found a handler to ~
remove and NIL when it did not, which is what the original does silently."
                 (string-downcase (symbol-name add)))))))

(defmacro %define-event-methods (class event add remove)
  "Specialise one event pair on the type that raises it."
  `(progn
     (defmethod ,add ((object ,class) handler) (%subscribe-event object ,event handler))
     (defmethod ,remove ((object ,class) handler)
       (%unsubscribe-event object ,event handler))))
