;;;; manager-events.lisp --- GraphicsDeviceManager's events.
;;;;
;;;; The same mechanism as Game's, a different table and a different subscribe
;;;; route. The four device events are also the graphics-device-service events,
;;;; so a handler on the manager sees the device being created, resetting, reset
;;;; and disposed.

(in-package #:microsoft.xna.framework)

(defmethod %event-table ((object graphics-device-manager))
  *graphics-device-manager-event-values*)

(defmethod %subscribe-natively ((object graphics-device-manager) value token registration)
  (cna-lisp.internal.ffi::%graphics-device-manager-subscribe
   (cna-lisp.internal:handle-of object) value
   (cna-lisp.internal.ffi:game-event-callback-pointer)
   (cffi:make-pointer token) registration))

(%define-event-methods graphics-device-manager :disposed
                       add-disposed-handler remove-disposed-handler)

(macrolet ((manager-event (event add remove documentation)
             `(progn
                (%define-event-pair ,add ,remove ,documentation)
                (%define-event-methods graphics-device-manager ,event ,add ,remove))))
  (manager-event :device-created add-device-created-handler
                 remove-device-created-handler
    "GraphicsDeviceManager.DeviceCreated: a graphics device was created.

HANDLER is called with the manager. The device itself is reached through the
game, as it always is: the event carries nothing.")
  (manager-event :device-resetting add-device-resetting-handler
                 remove-device-resetting-handler
    "GraphicsDeviceManager.DeviceResetting: the device is about to reset.")
  (manager-event :device-reset add-device-reset-handler remove-device-reset-handler
    "GraphicsDeviceManager.DeviceReset: the device finished resetting.")
  (manager-event :device-disposing add-device-disposing-handler
                 remove-device-disposing-handler
    "GraphicsDeviceManager.DeviceDisposing: the device is about to be disposed."))
