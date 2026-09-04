;;;; state-collections.lisp --- SamplerStateCollection and TextureCollection.
;;;;
;;;; Two one-member types: an indexer each. What makes them worth their own file
;;;; is that XNA's indexers answer *the object that was set*, not a fresh
;;;; equivalent, and reproducing that is a decision about where the collection's
;;;; contents live.
;;;;
;;;; They live here, in a per-slot array, which is where XNA keeps them too:
;;;; `SamplerStateCollection' has a private `pSamplerList' array and its getter
;;;; reads that array rather than asking the device. The setter is the half that
;;;; reaches the device.
;;;;
;;;; For `TextureCollection' the CNA C ABI asks for the same shape and says why.
;;;; `cna_graphics_device_get_texture' answers a `bound' flag and a handle, and
;;;; the handle is invalid when the slot was filled by canonical CNA code -- a
;;;; SpriteBatch flush, say -- because **there is deliberately no route from a
;;;; native object back to a handle** anywhere in that ABI. The header's own
;;;; advice is to cache what you bind and use `bound' to tell "something else
;;;; owns this slot now" from "the slot is empty". That is exactly what happens
;;;; below, and the one case a cache cannot cover is documented in
;;;; docs/limitations.md rather than answered with a guess.

(in-package #:microsoft.xna.framework.graphics)

(defconstant +state-collection-slots+ 16
  "Slots in each of the device's sampler and texture collections.

CNA_MAX_SAMPLERS and CNA_TEXTURE_COLLECTION_MAX_TEXTURES are both sixteen, and
the two are checked against each other at load time rather than assumed equal.")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (assert (= cna-lisp.internal.ffi::+max-samplers+
             cna-lisp.internal.ffi::+texture-collection-max-textures+)
          () "CNA's sampler and texture collections are no longer the same size."))

(defclass %state-collection ()
  ((device :initarg :device :reader %collection-device)
   (stage :initarg :stage :reader %collection-stage)
   (slots :reader %collection-slots
          :initform (make-array +state-collection-slots+ :initial-element nil)))
  (:documentation
   "What a device's sampler and texture collections share: the device they belong
to, the shader stage they are the collection for, and one entry per slot."))

(defclass sampler-state-collection (%state-collection)
  ()
  (:documentation
   "Microsoft.Xna.Framework.Graphics.SamplerStateCollection.

Reached through GRAPHICS-DEVICE's SAMPLER-STATES and VERTEX-SAMPLER-STATES, which
answer the same collection object every time, as XNA's properties do. A consumer
does not construct one."))

(defclass texture-collection (%state-collection)
  ()
  (:documentation
   "Microsoft.Xna.Framework.Graphics.TextureCollection.

Reached through GRAPHICS-DEVICE's TEXTURES and VERTEX-TEXTURES."))

(defun %check-slot-index (collection index operation)
  "XNA's range check, which comes before every other check in both indexers."
  (unless (and (integerp index) (<= 0 index) (< index +state-collection-slots+))
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation operation
           :parameter-name "index"
           :object-type (type-of collection)
           :format-control "~s is not a slot index; the collection has ~d slots, 0 to ~d."
           :format-arguments (list index +state-collection-slots+
                                   (1- +state-collection-slots+))))
  index)

(defgeneric item (collection index)
  (:documentation
   "The indexer of a graphics collection: SamplerStateCollection.Item and
TextureCollection.Item.

One generic function, because the two are the same idea with different element
types and Common Lisp dispatches on the collection. An index outside the
collection is a CNA-ARGUMENT-OUT-OF-RANGE-ERROR, which is the
ArgumentOutOfRangeException XNA's own range check throws, and it is checked
first -- before the null check on a setter, as XNA does."))

(defgeneric (setf item) (value collection index)
  (:documentation "The indexer's setter. See ITEM."))

;;; --- the sampler collection ----------------------------------------------------

(defmethod item ((collection sampler-state-collection) index)
  (%check-slot-index collection index "item")
  (or (aref (%collection-slots collection) index)
      ;; Nothing has been set through this collection yet, so the slot's contents
      ;; are whatever the device already had. Read it once and keep the object, so
      ;; that from here on the collection answers the same object every time --
      ;; which is what XNA's array-backed getter does.
      (setf (aref (%collection-slots collection) index)
            (let ((handle (%resolve-device-handle (%collection-device collection) "item")))
              (%with-state-descriptor (pointer cna-lisp.internal.ffi::cna-sampler-state
                                       cna-lisp.internal.ffi::+sizeof-cna-sampler-state+)
                (cna-lisp.internal:check-result
                 (cna-lisp.internal.ffi::%graphics-device-get-sampler-state
                  handle (%collection-stage collection) index pointer)
                 "item" :object-type 'sampler-state-collection)
                ;; Bound, because it is the state the device is already using.
                (%mark-bound (%read-sampler-state pointer)
                             (%collection-device collection)))))))

(defmethod (setf item) (value (collection sampler-state-collection) index)
  (%check-slot-index collection index "(setf item)")
  (unless value
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "(setf item)" :parameter-name "value"
           :object-type 'sampler-state-collection
           :format-control
           "a sampler slot does not accept NIL; XNA throws ArgumentNullException ~
            here. Only SpriteBatch.Begin reads a null state as \"use the default\"."))
  (check-type value sampler-state)
  ;; XNA short-circuits on identity: assigning the object already in the slot
  ;; applies nothing. Reproduced, because Apply is not free and because a state
  ;; object that was never applied must not be latched by a no-op.
  (unless (eq value (aref (%collection-slots collection) index))
    (let ((handle (%resolve-device-handle (%collection-device collection) "(setf item)")))
      (%with-state-descriptor (pointer cna-lisp.internal.ffi::cna-sampler-state
                               cna-lisp.internal.ffi::+sizeof-cna-sampler-state+)
        (%write-sampler-state pointer value)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%graphics-device-set-sampler-state
          handle (%collection-stage collection) index pointer)
         "(setf item)" :object-type 'sampler-state-collection)))
    (%mark-bound value (%collection-device collection))
    (setf (aref (%collection-slots collection) index) value))
  value)

;;; --- the texture collection ----------------------------------------------------

(defun %texture-slot-bound-p (collection index operation)
  "Whether CNA reports a texture in this slot, and the handle it reports.

Answers two values: the CNA_Bool as a generalized Boolean, and the handle, which
is CNA_INVALID_HANDLE when the slot was filled by canonical CNA code rather than
through this ABI."
  (let ((handle (%resolve-device-handle (%collection-device collection) operation)))
    (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-texture-slot-info))
      (cffi:foreign-funcall "memset" :pointer info :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-texture-slot-info+ :void)
      (setf (cffi:foreign-slot-value
             info '(:struct cna-lisp.internal.ffi::cna-texture-slot-info)
             'cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-texture-slot-info+
            (cffi:foreign-slot-value
             info '(:struct cna-lisp.internal.ffi::cna-texture-slot-info)
             'cna-lisp.internal.ffi::struct-version)
            1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-texture
        handle (%collection-stage collection) index info)
       operation :object-type 'texture-collection)
      (values (cna-lisp.internal.ffi:cna-true-p
               (cffi:foreign-slot-value
                info '(:struct cna-lisp.internal.ffi::cna-texture-slot-info)
                'cna-lisp.internal.ffi::bound))
              (cffi:foreign-slot-value
               info '(:struct cna-lisp.internal.ffi::cna-texture-slot-info)
               'cna-lisp.internal.ffi::texture)))))

(defmethod item ((collection texture-collection) index)
  (%check-slot-index collection index "item")
  (let ((cached (aref (%collection-slots collection) index)))
    (multiple-value-bind (bound handle) (%texture-slot-bound-p collection index "item")
      (cond
        ;; The slot is empty, so whatever was cached is stale.
        ((not bound) (setf (aref (%collection-slots collection) index) nil))
        ;; The slot holds the texture this collection put there.
        ((and cached
              (not (cna-lisp.internal:disposed-state-of cached))
              (= handle (cna-lisp.internal:handle-of cached)))
         cached)
        ;; Bound, but not by this collection. CNA cannot answer with an object --
        ;; its ABI has no route from a native object back to a handle, on purpose
        ;; -- so there is nothing truthful to return but "this binding has nothing
        ;; bound here". docs/limitations.md records the case.
        (t (setf (aref (%collection-slots collection) index) nil))))))

(defmethod (setf item) (value (collection texture-collection) index)
  (%check-slot-index collection index "(setf item)")
  ;; NIL is legal here and means the empty slot, which is what XNA's setter takes
  ;; a null for -- unlike the sampler collection, whose null throws.
  (when value
    (check-type value texture)
    (cna-lisp.internal:check-live value "(setf item)"))
  (let ((handle (%resolve-device-handle (%collection-device collection) "(setf item)")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-set-texture
      handle (%collection-stage collection) index
      (if value (cna-lisp.internal:handle-of value) 0))
     "(setf item)" :object-type 'texture-collection))
  (setf (aref (%collection-slots collection) index) value)
  value)

;;; --- the device's four collection properties -----------------------------------

(macrolet ((define-collection-property (name class stage doc)
             `(progn
                (defgeneric ,name (graphics-device) (:documentation ,doc))
                (defmethod ,name ((device graphics-device))
                  ;; The same object every time, as XNA's property is. It is a
                  ;; slot on the device facade rather than a fresh object per
                  ;; call, because the collection *is* the cache of what was
                  ;; bound and a fresh one would forget it.
                  (or (slot-value device ',name)
                      (setf (slot-value device ',name)
                            (make-instance ',class :device device :stage ,stage)))))))
  (define-collection-property sampler-states sampler-state-collection
      cna-lisp.internal.ffi::+shader-stage-pixel+
    "GraphicsDevice.SamplerStates: the pixel-shader sampler collection.")
  (define-collection-property vertex-sampler-states sampler-state-collection
      cna-lisp.internal.ffi::+shader-stage-vertex+
    "GraphicsDevice.VertexSamplerStates: the vertex-shader sampler collection.")
  (define-collection-property textures texture-collection
      cna-lisp.internal.ffi::+shader-stage-pixel+
    "GraphicsDevice.Textures: the pixel-shader texture collection.")
  (define-collection-property vertex-textures texture-collection
      cna-lisp.internal.ffi::+shader-stage-vertex+
    "GraphicsDevice.VertexTextures: the vertex-shader texture collection."))
