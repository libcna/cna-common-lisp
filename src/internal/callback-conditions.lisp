;;;; callback-conditions.lisp --- where a Lisp condition raised inside a CNA
;;;; callback goes, and when it is delivered.
;;;;
;;;; **No Lisp condition may unwind across a C frame.** Every CNA callback body
;;;; therefore contains whatever it signals. What the containment does with the
;;;; condition afterwards depends on whether CNA gave the callback a way to say
;;;; that it failed, and CNA's callbacks come in exactly two shapes:
;;;;
;;;;   a **lifecycle** callback answers a `CNA_Result' and takes a
;;;;   `CNA_CallbackError*'. Containment answers `CNA_RESULT_CALLBACK', CNA stops
;;;;   what it was doing, and the enclosing native call reports the failure. The
;;;;   condition waits in *PENDING-CALLBACK-CONDITION* and is attached to the
;;;;   CNA-CALLBACK-ERROR that call signals. Nothing is lost and nothing is
;;;;   guessed at: the result code is the channel.
;;;;
;;;;   an **event** callback answers `void'. `CNA_GameEventCallback',
;;;;   `CNA_AudioEventCallback', the graphics-resource and graphics-device
;;;;   callbacks, the component handlers and the component-collection callback
;;;;   are all of this shape, and CNA's own headers say why: "a handler that
;;;;   fails has nowhere to report it: return normally and record the failure in
;;;;   your own context". So there is no result code, CNA carries on, and the
;;;;   condition has to reach the program some other way.
;;;;
;;;; **This file is the some other way, and it used to be a promise rather than a
;;;; mechanism.** The public documentation said an event handler's condition was
;;;; "preserved and re-signalled by the next native call that drains it" while
;;;; `CALL-NATIVE-FRAME' cleared it unread on every successful call, and the audio
;;;; test that exercised it recorded the loss as "the documented limit". Both
;;;; could not be true. The condition is now delivered.
;;;;
;;;; The rules, each of which is a decision rather than an implementation detail:
;;;;
;;;; 1. **An event condition is stored, never thrown.** CONTAIN-EVENT-CONDITION
;;;;    is called from a `handler-case' inside the callback. The C frame always
;;;;    returns normally.
;;;;
;;;; 2. **The first one wins.** A second handler on the same event, or a second
;;;;    event inside the same native call, does not overwrite an earlier
;;;;    condition. A caller learns about the first failure, which is the one that
;;;;    happened first; silently replacing it would lose the only report of it.
;;;;
;;;; 3. **It is delivered where signalling is safe, which is outside every
;;;;    callback.** CHECK-RESULT drains it, and only when this thread is inside
;;;;    no CNA callback at all -- neither an event dispatch (which does not open a
;;;;    lifecycle scope, because it is not one) nor a lifecycle callback. So the
;;;;    delivery point is the first native route a program calls after control
;;;;    has genuinely come back to it.
;;;;
;;;; 4. **A native failure wins the report, and the event condition becomes its
;;;;    CAUSE.** The two are independent failures and both are real; the native
;;;;    one is what the call the program actually made answered, so it is what is
;;;;    signalled, and the condition an event handler raised is attached rather
;;;;    than dropped. This is the same precedence CNA-CALLBACK-ERROR already
;;;;    applies to a lifecycle callback's condition, which it carries in
;;;;    UNDERLYING-CONDITION rather than signalling in place of the native report.
;;;;
;;;; 5. **Delivered once.** Taking it clears it, on both branches.
;;;;
;;;; What is *not* claimed: that an event handler's condition reaches the caller
;;;; of the exact call the event was raised from. It reaches the first call that
;;;; returns to the program, which for an event raised inside `Game.Run' is
;;;; `Game.Run' itself and for one raised inside a component addition is that
;;;; addition. There is one place with no next call at all -- an event raised by
;;;; the very last native operation a program ever performs -- and
;;;; docs/callbacks-and-threading.md says so.

(in-package #:cna-lisp.internal)

;;; --- callback scope ----------------------------------------------------

(defvar *callback-depth* 0
  "How many CNA lifecycle callbacks are active on this thread.")

(defun in-callback-scope-p ()
  "True while the calling thread is inside a CNA lifecycle callback.

Some CNA routes -- borrowing the graphics device is the important one -- are
legal only here, and the handles they answer are valid only until the callback
returns."
  (plusp *callback-depth*))

(defun call-with-callback-scope (function)
  ;; WITH-CALLER-FLOAT-ENVIRONMENT is the inbound half of the foreign boundary:
  ;; CNA calls this back from inside a foreign call the binding masked traps
  ;; around, and a user's Update or Draw must see the floating-point environment
  ;; their own program set up rather than the one the C code needed. See
  ;; src/internal/float-semantics.lisp for the measurements.
  (let ((*callback-depth* (1+ *callback-depth*)))
    (with-caller-float-environment (funcall function))))

;;; --- a lifecycle callback's condition ----------------------------------

(defvar *pending-callback-condition* nil
  "The condition a lifecycle callback contained, waiting to be re-signalled after
the C call that entered the callback has returned.

Paired with `CNA_RESULT_CALLBACK': the code says a callback failed and this says
which condition it failed with. CALL-NATIVE-FRAME reads both together.")

(defun take-pending-callback-condition ()
  "Answer and clear the contained lifecycle-callback condition, if any."
  (prog1 *pending-callback-condition*
    (setf *pending-callback-condition* nil)))

;;; --- an event callback's condition -------------------------------------

(defvar *pending-event-condition* nil
  "The condition a void-returning CNA callback contained, waiting for delivery.

Separate from *PENDING-CALLBACK-CONDITION* because the two are answers to
different questions. That one accompanies a result code and is read by the call
that received the code; this one accompanies nothing, so its delivery is this
file's rule rather than CNA's.")

(defvar *in-event-dispatch* nil
  "True while this thread is running a void-returning CNA callback's handler.

**Not `*CALLBACK-DEPTH*', deliberately.** That variable answers \"CNA has lent
this thread a graphics device for the duration of a lifecycle method\", and an
event dispatch is not one: raising it here would silently make device operations
legal inside an event handler and re-entering the game loop illegal there, two
behaviour changes that have nothing to do with containment. What is needed here
is only that a pending condition is not delivered inside the very callback that
would have to carry it back through C.")

(defun contain-event-condition (condition)
  "Record CONDITION as the failure of a void-returning callback. First one wins.

Answers CONDITION when it was recorded and NIL when an earlier one already was.
Nothing here may signal: it runs on the failure path of a C callback."
  (if *pending-event-condition*
      nil
      (setf *pending-event-condition* condition)))

(defun take-pending-event-condition ()
  "Answer and clear the contained event condition, if it may be delivered now.

Answers NIL inside any CNA callback, where signalling would unwind through C."
  (when (and *pending-event-condition*
             (not *in-event-dispatch*)
             (not (in-callback-scope-p)))
    (prog1 *pending-event-condition*
      (setf *pending-event-condition* nil))))

(defun call-with-event-dispatch (function)
  "Run FUNCTION as the body of a void-returning CNA callback."
  ;; The same inbound restoration as CALL-WITH-CALLBACK-SCOPE, and needed for the
  ;; same reason: an event handler is user Lisp reached from inside a foreign
  ;; call. It does not raise *CALLBACK-DEPTH*, so it cannot share that path.
  (let ((*in-event-dispatch* t))
    (with-caller-float-environment (funcall function))))

(defmacro with-event-dispatch (&body body)
  "Run BODY as the body of a void-returning CNA callback, containing everything.

Answers NIL. The condition, if there was one, is left for the next native call
that returns to the program; see this file's header."
  `(call-with-event-dispatch
    (lambda ()
      (handler-case (progn ,@body nil)
        (serious-condition (condition)
          (contain-event-condition condition)
          nil)))))
