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
;;;; **A subscription is two facts and they have different lifetimes.** The
;;;; logical handler list is what `+=' and `-=' mutate, and in the original it is
;;;; a delegate field that outlives the object -- every one of the twenty-one
;;;; event accessors in the pinned assemblies is a bare `Delegate.Combine' or
;;;; `Delegate.Remove' with no `IsDisposed' test. The live CNA registration is
;;;; what makes a handler reachable, and it exists only while the object can raise
;;;; the event. %EVENT-SOURCE-DISPOSED-P is where the two part company.
;;;;
;;;; **A condition signalled by a handler cannot be reported to CNA.**
;;;; `CNA_GameEventCallback' returns `void'. There is no result code and no
;;;; diagnostic structure, so containment here has nowhere to put a failure
;;;; except the Lisp side. The condition is preserved in
;;;; `*PENDING-EVENT-CONDITION*' and re-signalled by the next native call that
;;;; returns to Lisp outside every callback -- see
;;;; src/internal/callback-conditions.lisp, which owns that rule and its
;;;; precedence.

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
        ;; No result code to answer with: the condition is contained and left for
        ;; the next native call that returns to the program. See
        ;; src/internal/callback-conditions.lisp.
        (cna-lisp.internal:with-event-dispatch (funcall function sender))))))

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
game's collection and has no handle, so what has to be usable is the game.

**This is asked only when a native registration is actually about to be
acquired.** A disposed source needs none -- see %EVENT-SOURCE-DISPOSED-P -- and
asking it there would refuse an operation the original accepts.")
  (:method ((object cna-lisp.internal:native-object) operation)
    (cna-lisp.internal:check-usable object operation)))

(defgeneric %event-source-disposed-p (object)
  (:documentation
   "Whether OBJECT can no longer raise its events, because it has been disposed.

**A CLR event's `+=' and `-=' are field mutation and nothing else.** Every one of
the twenty-one event accessors in the three pinned assemblies -- `Game''s four,
`GraphicsDeviceManager''s five, `GraphicsDevice''s six, `GraphicsResource''s,
`GameComponent''s, `GameComponentCollection''s two, `GameWindow''s three and
`DynamicSoundEffectInstance.BufferNeeded' -- is a `Delegate.Combine' or
`Delegate.Remove' against a backing field, with **no** `IsDisposed' test and no
other call at all. `DynamicSoundEffectInstance.Dispose(bool)' removes the
instance from the static `allInstances' table and never touches the `BufferNeeded'
field; `GraphicsResource.Dispose(bool)' raises `Disposing' from its backing store
and never clears it. So in XNA the handler list outlives the object, and
subscribing to or unsubscribing from a disposed object is legal and does nothing
else.

This binding reproduces that by separating the two facts a subscription is: the
**logical handler list**, which is managed, survives disposal and is what `+=' and
`-=' mutate; and the **live CNA registration**, which exists only while the object
can still raise the event. A disposed source needs no registration -- no event can
reach it, because the native side gave its registrations back when it was
destroyed -- so the add is purely managed there rather than faked against a dead
handle.

The default is NIL: an object with no disposal has no such state. A *facade* asks
the object that really dies -- the game, for the component collection and the
window.")
  (:method (object) (declare (ignore object)) nil)
  (:method ((object cna-lisp.internal:native-object))
    (cna-lisp.internal:disposed-state-of object)))

(defun %subscribe-event (object event function)
  "Subscribe FUNCTION to OBJECT's EVENT, and answer FUNCTION.

One mechanism for every type that raises events: the table, whether the event
comes from CNA at all, and the native route are the only things that differ, and
all three are generic functions on the object."
  (check-type function (or function symbol))
  (let ((native (and (%subscribes-natively-p object)
                     (not (%event-source-disposed-p object)))))
    (when native
      (%check-event-usable object "add-event-handler"))
    (let ((value (or (cdr (assoc event (%event-table object)))
                     (error 'cna-usage-error
                            :operation "add-event-handler"
                            :format-control "~s does not raise a ~s event."
                            :format-arguments (list (type-of object) event)))))
      (unless native
        ;; No token: either there is no C callback to resolve one, or the source
        ;; is disposed and there is no live event to resolve it for. An entry
        ;; left in the registry would be a leak the ownership tests would report.
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
  "Release OBJECT's subscription of FUNCTION to EVENT, if it has one.

**The native registration is given back before the local row is forgotten**, and
that order is the whole point rather than a style. Both unsubscribe routes CNA
offers here -- `cna_audio_unsubscribe_ext' and `cna_game_unsubscribe' -- have one
shape: look the registration up in the handle registry, and only then release it.
Every failure either route can answer is raised by the lookup or by the release,
under the registry's own mutex, **before anything is released**: an unknown or
already-released handle answers `CNA_RESULT_INVALID_HANDLE' and a call from a
thread other than the one that created the registration answers
`CNA_RESULT_THREAD'. So a failing unsubscribe means the registration is still
live -- and the thread one is reachable from Lisp, because removal is the one
event operation that needs no handle and therefore never checked the thread.

Forgetting the row there would leave CNA holding a registration nothing can
release, which `cna_game_destroy' refuses to shut down over. So the failure
propagates with the row intact, and the same call on the right thread still works."
  (let ((entry (find-if (lambda (row)
                          (and (eq (first row) event) (eq (second row) function)))
                        (%event-handlers object))))
    (when entry
      (let ((token (third entry)))
        (when token
          (cna-lisp.internal:check-result
           (%unsubscribe-natively object (cdddr entry))
           "remove-event-handler")
          ;; Only now: CNA can no longer reach the token, so dropping it cannot
          ;; strand a callback, and the row is no longer claiming a live handle.
          (setf (third entry) nil (cdddr entry) 0)
          (cna-lisp.internal:unregister-callback-target token)))
      (setf (%event-handlers object) (remove entry (%event-handlers object)))
      t)))

(defun %release-event-handlers (object)
  "Release every live CNA registration OBJECT holds, and keep its handler list.

Called while OBJECT is being destroyed. **The logical subscriptions survive and
the native ones do not**, which is exactly what the original does: XNA's disposal
stops an event being *raised* -- `DynamicSoundEffectInstance' leaves the static
table its raiser looks itself up in, `GraphicsResource' raises `Disposing' one
last time -- and never empties a handler field. A program that removes a handler
after disposal must still be told it was there.

Nothing here may signal: it runs on the teardown path, where a condition would
leave the rest of the object undestroyed. **This is the one place a failed
unsubscribe is forgotten**, and it is sound only here: it runs on the object's own
thread, after its own destruction, on registrations that can no longer be reached
by anything -- so the two failures the route can give, an invalid handle and a
thread mismatch, are respectively already-done and unreachable. The
program-facing path above forgets nothing it did not get back."
  (dolist (entry (%event-handlers object))
    (when (third entry)
      (ignore-errors (%unsubscribe-natively object (cdddr entry)))
      (ignore-errors (cna-lisp.internal:unregister-callback-target (third entry)))
      (setf (third entry) nil (cdddr entry) 0)))
  nil)

(defmacro %define-event-pair (add remove documentation)
  "Define the two generic functions one CLR event projects to."
  `(progn
     (defgeneric ,add (object handler) (:documentation ,documentation))
     (defgeneric ,remove (object handler)
       (:documentation
        ,(format nil "The `-=' of ~a. Answers true when it found a handler to ~
remove and NIL when it did not, which is what the original does silently.~2%~
Legal after the sender has been disposed, exactly as `Delegate.Remove' against ~
a field no disposal clears is: the handler list survives, and what disposal ~
ended is the event being raised."
                 (string-downcase (symbol-name add)))))))

(defmacro %define-event-methods (class event add remove)
  "Specialise one event pair on the type that raises it."
  `(progn
     (defmethod ,add ((object ,class) handler) (%subscribe-event object ,event handler))
     (defmethod ,remove ((object ,class) handler)
       (%unsubscribe-event object ,event handler))))
