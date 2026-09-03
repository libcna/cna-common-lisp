;;;; graphics-resource.lisp --- Microsoft.Xna.Framework.Graphics.GraphicsResource.
;;;;
;;;; The abstract base of every graphics object XNA owns: a name, a tag, the
;;;; device it belongs to, whether it has been disposed, and an event raised
;;;; while it is being disposed. `Texture' and `SpriteBatch' inherit it here, as
;;;; they do in the original.
;;;;
;;;; Two projection decisions.
;;;;
;;;; **`IsDisposed' and `Dispose()' are the ones CNA-Lisp already had.** Every
;;;; native object in this binding carries deterministic disposal, so this type
;;;; does not introduce a second mechanism: `IsDisposed' *is* DISPOSED-P and
;;;; `Dispose()' *is* DISPOSE, and the rules record that rather than inventing a
;;;; `graphics-resource-dispose'.
;;;;
;;;; **`Tag' is kept on the Lisp side.** XNA's Tag is `System.Object' -- arbitrary
;;;; consumer data the framework never reads. CNA's is a `uint64' token, which
;;;; cannot hold a Lisp object and could only hold a pointer to one, and putting a
;;;; pointer to a moving object into C is the one thing this binding never does.
;;;; So the tag is a slot, it holds any Lisp object, and it is not round-tripped
;;;; through the C ABI. A consumer that shares a resource with another CNA
;;;; binding would not see that binding's tag; nothing in CNA-Lisp does.

(in-package #:microsoft.xna.framework.graphics)

(defclass graphics-resource (cna-lisp.internal:native-object)
  ((tag :initform nil :accessor tag
        :documentation "Arbitrary consumer data. See the file header.")
   (event-handlers :initform '() :accessor microsoft.xna.framework::%event-handlers))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.GraphicsResource: the base of the graphics
objects a device owns.

Abstract: CNA-Lisp creates TEXTURE-2D and SPRITE-BATCH, never a bare resource."))

(defun graphics-resource-name (resource)
  "GraphicsResource.Name."
  (cna-lisp.internal:check-usable resource "graphics-resource-name")
  (cna-lisp.internal:count-then-copy-string
   (lambda (out-count)
     (cna-lisp.internal.ffi::%graphics-resource-get-name-byte-count
      (cna-lisp.internal:handle-of resource) out-count))
   (lambda (buffer capacity out-count)
     (cna-lisp.internal.ffi::%graphics-resource-copy-name
      (cna-lisp.internal:handle-of resource) buffer capacity out-count))
   "graphics-resource-name"))

(defun (setf graphics-resource-name) (name resource)
  "GraphicsResource.Name setter."
  (check-type name string)
  (cna-lisp.internal:check-usable resource "graphics-resource-name")
  (cna-lisp.internal:with-utf8-view (data length name)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-resource-set-name
      (cna-lisp.internal:handle-of resource) data length)
     "graphics-resource-name" :object-type (type-of resource)))
  name)

(defun graphics-resource-is-disposed (resource)
  "GraphicsResource.IsDisposed.

The same question DISPOSED-P answers, asked of CNA rather than of the CLOS
object -- so a resource CNA disposed underneath the binding reports disposed
here even before the Lisp side notices."
  (if (cna-lisp.internal:disposed-state-of resource)
      t
      (cffi:with-foreign-object (disposed :uint8)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%graphics-resource-get-is-disposed
          (cna-lisp.internal:handle-of resource) disposed)
         "graphics-resource-is-disposed")
        (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref disposed :uint8)))))

;;; --- the device the resource belongs to --------------------------------------

(defgeneric graphics-resource-graphics-device (resource)
  (:documentation
   "GraphicsResource.GraphicsDevice: the device this resource belongs to.

Answers the game's GRAPHICS-DEVICE facade, which is the only device a CNA-Lisp
program has. The C handle CNA answers here is a *borrowed* device handle with the
same callback-scoped lifetime as every other one, so it is checked against the
facade rather than wrapped in a second device object -- there is exactly one
device and two objects for it would be one too many."))

(defmethod graphics-resource-graphics-device ((resource graphics-resource))
  (let ((game (cna-lisp.internal:active-game)))
    (unless game
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation "graphics-resource-graphics-device"
             :format-control
             "the resource's device is the active game's, and there is no active game."))
    (microsoft.xna.framework:graphics-device game)))

;;; --- the Disposing event -----------------------------------------------------

(defparameter microsoft.xna.framework::*graphics-resource-event-values*
  '((:disposing . 0))
  "GraphicsResource raises one event, and CNA gives it a route of its own rather
than an identity in a table. The single entry keeps it in the same shape as the
others so one mechanism serves every type.")

(defmethod microsoft.xna.framework::%event-table ((object graphics-resource))
  microsoft.xna.framework::*graphics-resource-event-values*)

(defmethod microsoft.xna.framework::%subscribe-natively
    ((object graphics-resource) value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%graphics-resource-subscribe-disposing
   (cna-lisp.internal:handle-of object)
   (cna-lisp.internal.ffi:resource-disposing-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod microsoft.xna.framework::%unsubscribe-natively
    ((object graphics-resource) registration)
  ;; A graphics-resource registration is its own handle type with its own release
  ;; route, unlike the game's and the manager's, which share one.
  (cna-lisp.internal.ffi::%graphics-resource-unsubscribe-disposing registration))

(microsoft.xna.framework::%define-event-pair
 add-disposing-handler remove-disposing-handler
 "GraphicsResource.Disposing: the resource is being disposed.

HANDLER is called with the resource. It runs *inside* the disposal, so the
resource is still addressable but must not be used for new work.")

(microsoft.xna.framework::%define-event-methods
 graphics-resource :disposing add-disposing-handler remove-disposing-handler)

(setf cna-lisp.internal.ffi:*resource-disposing-dispatcher*
      #'microsoft.xna.framework::%dispatch-game-event)

(defmethod cna-lisp.internal:destroy-native :around ((resource graphics-resource))
  "Release the resource's event subscriptions after its native destruction.

After, not before: the Disposing event is raised inside the destruction, and a
subscription released first would swallow the last thing the resource ever says.
This is the same ordering GAME and GRAPHICS-DEVICE-MANAGER need, and it is here
rather than in each concrete resource so no future resource can forget it."
  (unwind-protect (call-next-method)
    (microsoft.xna.framework::%release-event-handlers resource)))
