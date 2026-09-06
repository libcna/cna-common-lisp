;;;; graphics-resource.lisp --- Microsoft.Xna.Framework.Graphics.GraphicsResource.
;;;;
;;;; The abstract base of every graphics object XNA owns: a name, a tag, the
;;;; device it belongs to, whether it has been disposed, and an event raised
;;;; while it is being disposed.
;;;;
;;;; **The public hierarchy is not the native ownership hierarchy.** That is the
;;;; whole shape of this file, and getting it wrong is what it was written to
;;;; correct. The pinned contract says `BlendState', `DepthStencilState',
;;;; `RasterizerState', `SamplerState', `VertexDeclaration', `Texture' and
;;;; `SpriteBatch' all have `baseType` GraphicsResource. Five of those hold no
;;;; CNA handle at all -- CNA models a state object and a vertex declaration as
;;;; versioned descriptors, with no create route and nothing to destroy. An
;;;; earlier version of this binding concluded from that that they could not be
;;;; GraphicsResources. That was wrong, and the assembly says why:
;;;;
;;;;   GraphicsResource::get_Name reads the *device's* cache when
;;;;   `_internalHandle != 0' and its own `_localName' field otherwise.
;;;;
;;;; XNA already has the handle-less case, in the base class, by design. `Tag',
;;;; `IsDisposed' and `Disposing' are ordinary managed fields; `GraphicsDevice'
;;;; is `_parent', which is **null until the resource is applied to a device**
;;;; and is set by `Apply'. None of it needs a handle.
;;;;
;;;; So the hierarchy has one public root and two private branches:
;;;;
;;;;     graphics-resource                 public, no native anything
;;;;       %managed-graphics-resource      local name, local disposal
;;;;         %state-object -> the four states
;;;;         vertex-declaration
;;;;       %native-graphics-resource       + NATIVE-OBJECT: handle, generation,
;;;;         texture -> texture-2d           owner thread, parent/child
;;;;         sprite-batch
;;;;
;;;; Two branches, one disposal mechanism each, no diamond and no fabricated
;;;; handle. A managed-only resource never pretends to have one.
;;;;
;;;; Two projection decisions, unchanged from before the split.
;;;;
;;;; **`IsDisposed' and `Dispose()' are the ones CNA-Lisp already had.** Every
;;;; object in this binding carries deterministic disposal, so this type does not
;;;; introduce a second mechanism: `IsDisposed' *is* DISPOSED-P and `Dispose()'
;;;; *is* DISPOSE, and the rules record that rather than inventing a
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

(defclass graphics-resource ()
  ((%local-name :initform nil :accessor %local-name
                :documentation
                "XNA's GraphicsResource::_localName: the name a resource carries
when it has no native handle for the device to cache one against.")
   (tag :initform nil :accessor tag
        :documentation "Arbitrary consumer data. See the file header.")
   (%device :initform nil :accessor %resource-device
            :documentation
            "XNA's GraphicsResource::_parent. NIL until the resource is applied
to or created against a device, which is exactly what XNA's null means.")
   (event-handlers :initform '() :accessor microsoft.xna.framework::%event-handlers))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.GraphicsResource: the base of the graphics
objects a device owns.

Abstract, as XNA's is. Its two branches are private: one for the resources CNA
gives a handle -- TEXTURE-2D, SPRITE-BATCH -- and one for the resources it models
as descriptors, which are GraphicsResources in the contract and hold no handle:
the four state objects and VERTEX-DECLARATION."))

;;; --- the two branches ------------------------------------------------------

(defclass %managed-graphics-resource (graphics-resource)
  ((%disposed :initform nil :accessor %resource-disposed-p))
  (:documentation
   "A GraphicsResource with no native handle: its name, its disposal and its
Disposing event are entirely on the Lisp side, which is what XNA's own base class
does when `_internalHandle' is zero."))

(defclass %native-graphics-resource (graphics-resource cna-lisp.internal:native-object)
  ()
  (:documentation
   "A GraphicsResource that owns a CNA handle, and therefore all of
NATIVE-OBJECT's ownership machinery: generation, owner thread, parent/child
registration and native destruction."))

;;; --- Name ------------------------------------------------------------------
;;;
;;; XNA's getter reads the device's cache when there is a handle and its own
;;; field when there is not. Both halves are reproduced, on the branch each
;;; belongs to.

(defgeneric graphics-resource-name (resource)
  (:documentation
   "GraphicsResource.Name.

A resource with a native handle answers CNA's name for it; one without answers
the name it was given, which is what XNA's `_localName' is for."))

(defgeneric (setf graphics-resource-name) (name resource)
  (:documentation "GraphicsResource.Name's setter."))

(defmethod graphics-resource-name ((resource %managed-graphics-resource))
  (%local-name resource))

(defmethod (setf graphics-resource-name) (name (resource %managed-graphics-resource))
  (check-type name (or null string))
  (setf (%local-name resource) name))

(defmethod graphics-resource-name ((resource %native-graphics-resource))
  (cna-lisp.internal:check-usable resource "graphics-resource-name")
  (cna-lisp.internal:count-then-copy-string
   (lambda (out-count)
     (cna-lisp.internal.ffi::%graphics-resource-get-name-byte-count
      (cna-lisp.internal:handle-of resource) out-count))
   (lambda (buffer capacity out-count)
     (cna-lisp.internal.ffi::%graphics-resource-copy-name
      (cna-lisp.internal:handle-of resource) buffer capacity out-count))
   "graphics-resource-name"))

(defmethod (setf graphics-resource-name) (name (resource %native-graphics-resource))
  (check-type name string)
  (cna-lisp.internal:check-usable resource "graphics-resource-name")
  (cna-lisp.internal:with-utf8-view (data length name)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-resource-set-name
      (cna-lisp.internal:handle-of resource) data length)
     "graphics-resource-name" :object-type (type-of resource)))
  name)

;;; --- IsDisposed and disposal -------------------------------------------------

(defgeneric graphics-resource-is-disposed (resource)
  (:documentation
   "GraphicsResource.IsDisposed.

For a resource with a handle this asks CNA rather than the CLOS object, so a
resource CNA disposed underneath the binding reports disposed here even before
the Lisp side notices. For one without, the Lisp side is the only side there is."))

(defmethod graphics-resource-is-disposed ((resource %managed-graphics-resource))
  (%resource-disposed-p resource))

(defmethod graphics-resource-is-disposed ((resource %native-graphics-resource))
  (if (cna-lisp.internal:disposed-state-of resource)
      t
      (cffi:with-foreign-object (disposed :uint8)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%graphics-resource-get-is-disposed
          (cna-lisp.internal:handle-of resource) disposed)
         "graphics-resource-is-disposed")
        (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref disposed :uint8)))))

(defmethod microsoft.xna.framework:disposed-p ((resource %managed-graphics-resource))
  (%resource-disposed-p resource))

(defmethod microsoft.xna.framework:dispose ((resource %managed-graphics-resource))
  "GraphicsResource.Dispose() for a resource with nothing native to release.

XNA's `~GraphicsResource' is guarded by `isDisposed', releases whatever native
thing there is -- nothing, here -- and then raises Disposing once with the
resource as the sender. Idempotent, as IDisposable.Dispose is."
  (unless (%resource-disposed-p resource)
    (setf (%resource-disposed-p resource) t)
    (%raise-managed-disposing resource))
  (values))

;;; --- the device the resource belongs to --------------------------------------

(defgeneric graphics-resource-graphics-device (resource)
  (:documentation
   "GraphicsResource.GraphicsDevice: the device this resource belongs to.

XNA reads `_parent', which is **null until the resource is applied to a device**.
A state object or a vertex declaration that has never been applied therefore
answers NIL here, which is that null; one that has been applied answers the
device it was applied to.

A resource with a handle answers the game's GRAPHICS-DEVICE facade, which is the
only device a CNA-Lisp program has. The C handle CNA answers there is a
*borrowed* device handle with the same callback-scoped lifetime as every other
one, so it is checked against the facade rather than wrapped in a second device
object -- there is exactly one device and two objects for it would be one too
many."))

(defmethod graphics-resource-graphics-device ((resource %managed-graphics-resource))
  (%resource-device resource))

(defmethod graphics-resource-graphics-device ((resource %native-graphics-resource))
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

;;; A managed-only resource has no CNA object to subscribe to, so its
;;; subscriptions live entirely in the handler list and this raises them. Saying
;;; so with a generic function rather than letting the native path quietly
;;; succeed on a zero handle is the difference between a projection and a bug.
(defmethod microsoft.xna.framework::%subscribes-natively-p
    ((object %managed-graphics-resource))
  nil)

(defun %raise-managed-disposing (resource)
  "Raise Disposing on a managed-only resource, once, with RESOURCE as the sender.

Every handler runs even if an earlier one signalled: XNA invokes a multicast
delegate, and one handler's failure does not cancel the others. The first
condition is re-signalled afterwards, because unlike the native path there is a
Lisp caller here to report it to."
  (let ((failure nil))
    (dolist (entry (microsoft.xna.framework::%event-handlers resource))
      (when (eq (first entry) :disposing)
        (handler-case (funcall (second entry) resource)
          (serious-condition (condition) (unless failure (setf failure condition))))))
    (setf (microsoft.xna.framework::%event-handlers resource) '())
    (when failure (error failure))))

(defmethod microsoft.xna.framework::%subscribe-natively
    ((object %native-graphics-resource) value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%graphics-resource-subscribe-disposing
   (cna-lisp.internal:handle-of object)
   (cna-lisp.internal.ffi:resource-disposing-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod microsoft.xna.framework::%unsubscribe-natively
    ((object %native-graphics-resource) registration)
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
      #'microsoft.xna.framework::%dispatch-payload-free-event)

(defmethod cna-lisp.internal:destroy-native :around ((resource %native-graphics-resource))
  "Release the resource's event subscriptions after its native destruction.

After, not before: the Disposing event is raised inside the destruction, and a
subscription released first would swallow the last thing the resource ever says.
This is the same ordering GAME and GRAPHICS-DEVICE-MANAGER need, and it is here
rather than in each concrete resource so no future resource can forget it."
  (unwind-protect (call-next-method)
    (microsoft.xna.framework::%release-event-handlers resource)))
