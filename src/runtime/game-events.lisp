;;;; game-events.lisp --- Game's four events.
;;;;
;;;; The mechanism is in runtime/event-machinery.lisp; these are the four events
;;;; XNA's Game raises, and the table and route that reach them.

(in-package #:microsoft.xna.framework)

(defmethod %event-table ((object game)) *game-event-values*)

(defmethod %subscribe-natively ((object game) value token registration)
  (cna-lisp.internal.ffi::%game-subscribe
   (cna-lisp.internal:handle-of object) value
   (cna-lisp.internal.ffi:game-event-callback-pointer)
   (cffi:make-pointer token) registration))

(macrolet ((define-event (event add remove documentation)
             `(progn
                (%define-event-pair ,add ,remove ,documentation)
                (%define-event-methods game ,event ,add ,remove))))
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
