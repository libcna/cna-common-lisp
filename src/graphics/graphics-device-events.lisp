;;;; graphics-device-events.lisp --- the four events GraphicsDevice raises.
;;;;
;;;; Separate from graphics-device.lisp for the load order, and for the same
;;;; reason manager-events.lisp is separate from graphics-device-manager.lisp:
;;;; three of these four event pairs are **shared with other types**, and the
;;;; generic functions have to exist before methods can be added to them.
;;;; `Disposing' is GraphicsResource's, `DeviceReset' and `DeviceResetting' are
;;;; GraphicsDeviceManager's -- the same-named pair on `IGraphicsDeviceService',
;;;; which is a different set on a different type from the two here, and
;;;; confusing them is a mistake docs/limitations.md records.
;;;;
;;;; Only `DeviceLost' is new, and only the device raises it.

(in-package #:microsoft.xna.framework.graphics)

;;; --- the four events the device raises ---------------------------------------
;;;
;;; The device is a facade with no handle of its own, and CNA's subscribe route
;;; wants a **callback-scoped** one -- so a subscription is only legal from inside
;;; a lifecycle method, exactly as every other device operation is. Unsubscribing
;;; is not: `cna_graphics_device_unsubscribe' takes only the registration, which
;;; is what lets the game release these during its own teardown, outside any
;;; callback. CNA requires exactly that: a registration "must be released before
;;; `cna_game_destroy' succeeds".

(defmethod microsoft.xna.framework::%event-table ((object graphics-device))
  microsoft.xna.framework::*graphics-device-event-values*)

(defmethod microsoft.xna.framework::%check-event-usable
    ((object graphics-device) operation)
  "A subscription needs the borrowed handle, so it needs the callback scope too."
  (%resolve-device-handle object operation))

(defmethod microsoft.xna.framework::%event-source-disposed-p ((object graphics-device))
  "Whether the source of these events can still raise one -- per lifetime mode.

For a **caller-owned** device the question is only about the device: it owns its
handle and answers for itself, and there is no game in the picture to consult --
which matters, because consulting one would report a device in a game-free
process permanently disposed and turn every `+=' into the managed-list operation
it must not be while the device is live.

For the **parent-owned facade** the game is what has been disposed: the facade
is the game's and raises nothing once the game is gone, so `+=' and `-=' are
then the managed list operations XNA's always were. While the game is alive they
still need the handle CNA lends only inside a lifecycle method, which is this
binding's own limit and is documented as one -- the two answers are different
questions, not an inconsistency."
  (if (%owned-device-p object)
      (cna-lisp.internal:disposed-state-of object)
      (let ((game (cna-lisp.internal:owner-of object)))
        (or (null game) (cna-lisp.internal:disposed-state-of game)
            (cna-lisp.internal:disposed-state-of object)))))

(defmethod cna-lisp.internal:destroy-native :around ((device graphics-device))
  "Release an owned device's event subscriptions after its native destruction.

After, not before: `Disposing' is raised inside the destruction, and a
subscription released first would swallow the last thing the device ever says.
The same ordering GRAPHICS-RESOURCE, GAME and GRAPHICS-DEVICE-MANAGER need.

A facade never reaches this method -- %CHECK-DISPOSABLE refuses its disposal --
and its registrations are released by the game, which is what performs the
`cna_game_destroy' CNA requires them released before."
  (unwind-protect (call-next-method)
    (microsoft.xna.framework::%release-event-handlers device)))

(defmethod microsoft.xna.framework::%subscribe-natively
    ((object graphics-device) value token registration)
  (cna-lisp.internal.ffi::%graphics-device-subscribe-event
   (%resolve-device-handle object "add-event-handler") value
   (cna-lisp.internal.ffi:graphics-device-event-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod microsoft.xna.framework::%unsubscribe-natively
    ((object graphics-device) registration)
  (cna-lisp.internal.ffi::%graphics-device-unsubscribe registration))

(setf cna-lisp.internal.ffi:*graphics-device-event-dispatcher*
      #'microsoft.xna.framework::%dispatch-payload-free-event)

(microsoft.xna.framework::%define-event-pair
 add-device-lost-handler remove-device-lost-handler
 "GraphicsDevice.DeviceLost: the device was lost.

HANDLER is called with the device. Subscribing is legal only inside a game
lifecycle method, because that is when CNA lends the handle the subscription is
made through -- and legal on a device whose game has been disposed, where there
is no handle to need and nothing left to raise the event, so the handler list is
all there is to update. XNA's `+=' is `Delegate.Combine' either way.")

;;; `DeviceReset' and `DeviceResetting' get **their own generic functions in this
;;; package**, and are not the manager's. One XNA namespace is one Common Lisp
;;; package, and a member belongs to its type's namespace: `GraphicsDevice' is in
;;; `Microsoft.Xna.Framework.Graphics' and `GraphicsDeviceManager' is not. So the
;;; two same-named CLR events project onto two same-named Lisp functions in two
;;; packages -- which is what makes `GFX:ADD-DEVICE-RESET-HANDLER' and
;;; `XNA:ADD-DEVICE-RESET-HANDLER' readable as the different events they are.
;;; `Disposing' is not like this: `GraphicsResource.Disposing' is in *this*
;;; namespace, so it really is one generic function with two methods.

(microsoft.xna.framework::%define-event-pair
 add-device-reset-handler remove-device-reset-handler
 "GraphicsDevice.DeviceReset: the device finished resetting.

**The device's own event, not `IGraphicsDeviceService`'s same-named one** --
that is `MICROSOFT.XNA.FRAMEWORK:ADD-DEVICE-RESET-HANDLER', on the manager.")

(microsoft.xna.framework::%define-event-pair
 add-device-resetting-handler remove-device-resetting-handler
 "GraphicsDevice.DeviceResetting: the device is about to reset. See DeviceReset
for why this is a different function from the manager's same-named one.")

(microsoft.xna.framework::%define-event-methods
 graphics-device :disposing add-disposing-handler remove-disposing-handler)
(microsoft.xna.framework::%define-event-methods
 graphics-device :device-lost add-device-lost-handler remove-device-lost-handler)
(microsoft.xna.framework::%define-event-methods
 graphics-device :device-reset add-device-reset-handler remove-device-reset-handler)
(microsoft.xna.framework::%define-event-methods
 graphics-device :device-resetting
 add-device-resetting-handler remove-device-resetting-handler)
