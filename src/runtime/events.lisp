;;;; events.lisp --- the CLR event projection.
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

(defparameter *game-event-values*
  (list (cons :activated cna-lisp.internal.ffi::+game-event-activated+)
        (cons :deactivated cna-lisp.internal.ffi::+game-event-deactivated+)
        (cons :disposed cna-lisp.internal.ffi::+game-event-disposed+)
        (cons :exiting cna-lisp.internal.ffi::+game-event-exiting+))
  "The CNA identity of each projected game event.")

(defun %dispatch-game-event (token)
  "Invoke the handler TOKEN names. Called from the one top-level event callback."
  (let ((entry (cna-lisp.internal:callback-target token)))
    (when entry
      (destructuring-bind (game . function) entry
        (handler-case (funcall function game)
          (serious-condition (condition)
            ;; Nowhere to report it: see the file header.
            (setf cna-lisp.internal:*pending-callback-condition* condition)))))))

(setf cna-lisp.internal.ffi:*game-event-dispatcher* #'%dispatch-game-event)

(defun %subscribe-game-event (game event function)
  (check-type function (or function symbol))
  (cna-lisp.internal:check-usable game "add-event-handler")
  (let ((value (or (cdr (assoc event *game-event-values*))
                   (error 'cna-usage-error
                          :operation "add-event-handler"
                          :format-control "~s is not a projected game event."
                          :format-arguments (list event))))
        (token (cna-lisp.internal:register-callback-target (cons game function))))
    (handler-case
        (cffi:with-foreign-object (registration :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%game-subscribe
            (cna-lisp.internal:handle-of game) value
            (cna-lisp.internal.ffi:game-event-callback-pointer)
            (cffi:make-pointer token)
            registration)
           "add-event-handler")
          (push (list* event function token (cffi:mem-ref registration :uint64))
                (%event-handlers game))
          function)
      (serious-condition (condition)
        (cna-lisp.internal:unregister-callback-target token)
        (error condition)))))

(defun %unsubscribe-game-event (game event function)
  (let ((entry (find-if (lambda (row)
                          (and (eq (first row) event) (eq (second row) function)))
                        (%event-handlers game))))
    (when entry
      (setf (%event-handlers game) (remove entry (%event-handlers game)))
      (cna-lisp.internal:unregister-callback-target (third entry))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-unsubscribe (cdddr entry))
       "remove-event-handler")
      t)))

(defun %release-game-event-handlers (game)
  "Release every live subscription. Called while the game is being destroyed.

Nothing here may signal: it runs on the teardown path, where a condition would
leave the rest of the game undestroyed."
  (dolist (entry (%event-handlers game))
    (ignore-errors (cna-lisp.internal.ffi::%game-unsubscribe (cdddr entry)))
    (ignore-errors (cna-lisp.internal:unregister-callback-target (third entry))))
  (setf (%event-handlers game) '())
  nil)

(macrolet ((define-event (event add remove documentation)
             `(progn
                (defgeneric ,add (object handler)
                  (:documentation ,documentation))
                (defmethod ,add ((game game) handler)
                  (%subscribe-game-event game ,event handler))
                (defgeneric ,remove (object handler)
                  (:documentation
                   ,(format nil "The `-=' of ~a. Answers true when it found a ~
handler to remove and NIL when it did not, which is what the original does ~
silently." (string-downcase (symbol-name add)))))
                (defmethod ,remove ((game game) handler)
                  (%unsubscribe-game-event game ,event handler)))))
  (define-event :activated add-activated-handler remove-activated-handler
    "Game.Activated: the game gained focus.

HANDLER is called with the game and nothing else, on the thread CNA raises the
event on.")
  (define-event :deactivated add-deactivated-handler remove-deactivated-handler
    "Game.Deactivated: the game lost focus.")
  (define-event :exiting add-exiting-handler remove-exiting-handler
    "Game.Exiting: the game is exiting.

This only observes. ON-EXITING is the overridable step that runs as part of the
shutdown; a handler here cannot stop it.")
  (define-event :disposed add-disposed-handler remove-disposed-handler
    "Game.Disposed: the game was disposed.

A condition signalled from this handler has nowhere to go -- see the file
header -- because there is no later native call to report it through."))
