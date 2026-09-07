;;;; render-target-cube.lisp --- RenderTargetCube and RenderTargetBinding.
;;;;
;;;; The last of the render-target family, and the pair that closes
;;;; `GraphicsDevice`'s three remaining render-target members.
;;;;
;;;; `RenderTargetCube' is to `TextureCube' what `RenderTarget2D' is to
;;;; `Texture2D': the same type with its own creation route and its own destroy,
;;;; so a finished target is an ordinary cube that an effect can sample. Both are
;;;; derived from the texture rather than wrapping it, because that is what XNA's
;;;; base types say.
;;;;
;;;; `RenderTargetBinding' is a **value type** -- XNA derives it from
;;;; `System.ValueType' -- so it projects as a struct, like `Rectangle' or
;;;; `Viewport', and not as a native object. It holds a target and, for a cube,
;;;; the face being drawn into.
;;;;
;;;; **`GetRenderTargets' answers the objects this binding bound.**
;;;; `cna_graphics_device_copy_render_targets' answers *handles*, and the ABI has
;;;; no route from a handle back to the CLOS object that owns it. So the device
;;;; remembers what was bound and this cross-checks CNA's count and handles
;;;; against that record rather than inventing objects to wrap handles it already
;;;; has objects for. The same decision the vertex-buffer bindings record, for the
;;;; same reason.

(in-package #:microsoft.xna.framework.graphics)

;;; --- RenderTargetCube --------------------------------------------------------

(defclass render-target-cube (texture-cube)
  ((%usage :initarg :usage :initform :discard-contents :reader render-target-usage)
   (%multi-sample-count :initarg :multi-sample-count :initform 0
                        :reader multi-sample-count)
   (%depth-stencil-format :initarg :depth-stencil-format :initform :none
                          :reader depth-stencil-format))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.RenderTargetCube: a TextureCube drawn into.

    (make-instance 'render-target-cube :graphics-device device :size 64)

Derived from TEXTURE-CUBE, as XNA's is. Bound one face at a time with
SET-RENDER-TARGET, which takes the face as a third argument:

    (set-render-target device target :positive-x)

`RenderTargetUsage', `MultiSampleCount' and `DepthStencilFormat' are read back
from CNA rather than echoed from the arguments, for the reason RENDER-TARGET-2D
records: a backend may grant less than was asked for."))

(defmethod %cube-makes-own-storage-p ((texture render-target-cube))
  "A cube render target's storage comes from `cna_render_target_cube_create', so
TEXTURE-CUBE's own constructor must not make a plain cube underneath it."
  t)

(defmethod initialize-instance :after
    ((target render-target-cube)
     &key graphics-device size (mip-map nil) (format :color)
          (depth-stencil-format :none) (multi-sample-count 0)
          (usage :discard-contents))
  "RenderTargetCube(GraphicsDevice, Int32, Boolean, SurfaceFormat, DepthFormat)
and its seven-argument overload, distinguished by keywords rather than by arity."
  (when graphics-device
    (check-type size (integer 1))
    (check-type format surface-format)
    (check-type depth-stencil-format depth-format)
    (check-type usage render-target-usage)
    (check-type multi-sample-count (integer 0))
    (let ((device-handle (device-handle-for-child graphics-device
                                                  "make-instance 'render-target-cube")))
      (cffi:with-foreign-object
          (info '(:struct cna-lisp.internal.ffi::cna-render-target-cube-create-info))
        (cffi:foreign-funcall
         "memset" :pointer info :int 0
         :size cna-lisp.internal.ffi::+sizeof-cna-render-target-cube-create-info+ :void)
        (macrolet ((slot (name)
                     `(cffi:foreign-slot-value
                       info
                       '(:struct cna-lisp.internal.ffi::cna-render-target-cube-create-info)
                       ',name)))
          (setf (slot cna-lisp.internal.ffi::struct-size)
                cna-lisp.internal.ffi::+sizeof-cna-render-target-cube-create-info+
                (slot cna-lisp.internal.ffi::struct-version) 1
                (slot cna-lisp.internal.ffi::size) size
                (slot cna-lisp.internal.ffi::mip-map)
                (cna-lisp.internal.ffi:cna-bool-of mip-map)
                (slot cna-lisp.internal.ffi::format) (surface-format-value format)
                (slot cna-lisp.internal.ffi::depth-format)
                (depth-format-value depth-stencil-format)
                (slot cna-lisp.internal.ffi::multi-sample-count) multi-sample-count
                (slot cna-lisp.internal.ffi::usage) (render-target-usage-value usage)))
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%render-target-cube-create device-handle info out)
           "make-instance 'render-target-cube" :object-type 'render-target-cube)
          (let ((handle (cffi:mem-ref out :uint64)))
            (cna-lisp.internal:record-construction-undo
             target (lambda () (cna-lisp.internal.ffi::%render-target-destroy handle)))
            (multiple-value-bind (granted-width granted-height levels granted-format
                                  granted-depth granted-samples granted-usage)
                (%render-target-info handle "make-instance 'render-target-cube")
              ;; A cube is square by construction; CNA reports the face as a
              ;; width and a height and they must agree, so this checks rather
              ;; than picking one and hoping.
              (unless (= granted-width granted-height)
                (error 'microsoft.xna.framework:cna-internal-error
                       :operation "make-instance 'render-target-cube"
                       :object-type 'render-target-cube
                       :format-control
                       "CNA granted a cube render target whose face is ~dx~d. A cube's ~
                        faces are square by construction, so this binding will not ~
                        guess which of the two is the edge."
                       :format-arguments (list granted-width granted-height)))
              (setf (cna-lisp.internal:handle-of target) handle
                    (slot-value target '%size) granted-width
                    (slot-value target '%level-count) levels
                    (slot-value target '%format) granted-format
                    (slot-value target '%depth-stencil-format) granted-depth
                    (slot-value target '%multi-sample-count) granted-samples
                    (slot-value target '%usage) granted-usage)
              (adopt-native-resource target graphics-device)
              (cna-lisp.internal:record-construction-undo
               target (lambda () (cna-lisp.internal:invalidate target)))
              target)))))))

(defmethod cna-lisp.internal:destroy-native ((target render-target-cube))
  ;; The render-target destroy, not TextureCube's: reaching the base class's would
  ;; hand a render-target handle to the cube destructor.
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%render-target-destroy (cna-lisp.internal:handle-of target))
   "dispose" :object-type 'render-target-cube))

(defmethod is-content-lost ((target render-target-cube))
  (cna-lisp.internal:check-usable target "is-content-lost")
  (nth-value 7 (%render-target-info (cna-lisp.internal:handle-of target)
                                    "is-content-lost")))

(defmethod microsoft.xna.framework::%event-table ((object render-target-cube))
  microsoft.xna.framework::*buffer-event-values*)

(defmethod microsoft.xna.framework::%subscribe-natively
    ((object render-target-cube) value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%render-target-subscribe-content-lost
   (cna-lisp.internal:handle-of object)
   (cna-lisp.internal.ffi:content-lost-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod microsoft.xna.framework::%unsubscribe-natively
    ((object render-target-cube) registration)
  (cna-lisp.internal.ffi::%render-target-unsubscribe-content-lost registration))

(microsoft.xna.framework::%define-event-methods
 render-target-cube :content-lost add-content-lost-handler remove-content-lost-handler)

(defmethod print-object ((target render-target-cube) stream)
  (print-unreadable-object (target stream :type t)
    (format stream "~d~:[~; disposed~]" (texture-cube-size target)
            (cna-lisp.internal:disposed-state-of target))))

;;; --- RenderTargetBinding -----------------------------------------------------

(defstruct (render-target-binding (:constructor %make-render-target-binding
                                      (target &optional cube-map-face))
                                  (:copier copy-render-target-binding))
  "Microsoft.Xna.Framework.Graphics.RenderTargetBinding: one target of a
multiple-render-target draw.

A value type in XNA -- it derives from System.ValueType -- so it is a struct here
and not a native object: it names a target, it does not own one.

    (make-render-target-binding target)                ; a RENDER-TARGET-2D
    (make-render-target-binding cube-target :positive-x) ; one face of a cube"
  (target nil :read-only t)
  (cube-map-face nil :read-only t))

(defun make-render-target-binding (target &optional cube-map-face)
  "RenderTargetBinding(RenderTarget2D) and RenderTargetBinding(RenderTargetCube,
CubeMapFace), distinguished by whether a face is given.

A face is required for a cube and refused for a 2D target, because in XNA the two
constructors are the only way to build one and neither accepts the other's
arguments."
  (etypecase target
    (render-target-cube
     (unless cube-map-face
       (error 'microsoft.xna.framework:cna-argument-error
              :operation "make-render-target-binding"
              :parameter-name "cube-map-face"
              :format-control
              "a RENDER-TARGET-CUBE is bound one face at a time, so a CUBE-MAP-FACE is ~
               required. XNA's RenderTargetBinding(RenderTargetCube, CubeMapFace) takes ~
               one for the same reason."))
     (check-type cube-map-face cube-map-face)
     (%make-render-target-binding target cube-map-face))
    (render-target-2d
     (when cube-map-face
       (error 'microsoft.xna.framework:cna-argument-error
              :operation "make-render-target-binding"
              :parameter-name "cube-map-face"
              :format-control
              "a RENDER-TARGET-2D has no faces, so a CUBE-MAP-FACE means nothing here. ~
               XNA's RenderTargetBinding(RenderTarget2D) takes no face."))
     (%make-render-target-binding target nil))))

(defun render-target-binding-equal (a b)
  "Value equality, as a value type has."
  (and (eq (render-target-binding-target a) (render-target-binding-target b))
       (eq (render-target-binding-cube-map-face a)
           (render-target-binding-cube-map-face b))))

;;; --- binding cubes and arrays of targets to the device -----------------------

(defun %check-render-target-shape (target cube-map-face operation)
  "Refuse a target/face pair that neither of XNA's two overloads accepts.

A cube is drawn into one face at a time and a RenderTarget2D has no faces, so
each overload takes exactly one of the two shapes. Defined here rather than in
render-target.lisp because it has to know about RENDER-TARGET-CUBE, which loads
after; SET-RENDER-TARGET calls it and the compiler is told nothing it needs."
  (typecase target
    (null
     (when cube-map-face
       (error 'microsoft.xna.framework:cna-argument-error
              :operation operation :parameter-name "cube-map-face"
              :format-control
              "restoring the back buffer takes no face. XNA's SetRenderTarget(null) is ~
               the RenderTarget2D overload.")))
    (render-target-cube
     (unless cube-map-face
       (error 'microsoft.xna.framework:cna-argument-error
              :operation operation :parameter-name "cube-map-face"
              :format-control
              "a RENDER-TARGET-CUBE is drawn into one face at a time, so a CUBE-MAP-FACE ~
               is required. XNA's SetRenderTarget(RenderTargetCube, CubeMapFace) takes ~
               one for the same reason."))
     (check-type cube-map-face cube-map-face))
    (render-target-2d
     (when cube-map-face
       (error 'microsoft.xna.framework:cna-argument-error
              :operation operation :parameter-name "cube-map-face"
              :format-control
              "a RENDER-TARGET-2D has no faces, so a CUBE-MAP-FACE means nothing here. ~
               XNA's SetRenderTarget(RenderTarget2D) takes no face.")))
    (t
     (error 'microsoft.xna.framework:cna-argument-error
            :operation operation :parameter-name "target"
            :format-control
            "~a is not a render target. SET-RENDER-TARGET takes a RENDER-TARGET-2D, a ~
             RENDER-TARGET-CUBE, or NIL for the back buffer."
            :format-arguments (list (type-of target))))))

(defgeneric set-render-targets (graphics-device &rest bindings)
  (:documentation
   "GraphicsDevice.SetRenderTargets(params RenderTargetBinding[]).

    (set-render-targets device binding-a binding-b)
    (set-render-targets device)          ; back to the back buffer

XNA's `params' array is a &REST list here, and no arguments is XNA's empty array,
which restores the back buffer. Each argument is a RENDER-TARGET-BINDING."))

(defmethod set-render-targets ((device graphics-device) &rest bindings)
  (dolist (binding bindings)
    (check-type binding render-target-binding)
    (cna-lisp.internal:check-usable (render-target-binding-target binding)
                                    "set-render-targets"))
  (let ((handle (%resolve-device-handle device "set-render-targets"))
        (count (length bindings)))
    (cffi:with-foreign-object
        (array '(:struct cna-lisp.internal.ffi::cna-render-target-binding) (max 1 count))
      (cffi:foreign-funcall
       "memset" :pointer array :int 0
       :size (* (max 1 count) cna-lisp.internal.ffi::+sizeof-cna-render-target-binding+)
       :void)
      (loop for binding in bindings
            for index from 0
            for entry = (cffi:mem-aptr
                         array '(:struct cna-lisp.internal.ffi::cna-render-target-binding)
                         index)
            do (macrolet ((slot (name)
                            `(cffi:foreign-slot-value
                              entry
                              '(:struct cna-lisp.internal.ffi::cna-render-target-binding)
                              ',name)))
                 (setf (slot cna-lisp.internal.ffi::struct-size)
                       cna-lisp.internal.ffi::+sizeof-cna-render-target-binding+
                       (slot cna-lisp.internal.ffi::struct-version) 1
                       (slot cna-lisp.internal.ffi::render-target)
                       (cna-lisp.internal:handle-of (render-target-binding-target binding))
                       (slot cna-lisp.internal.ffi::array-slice) 0
                       (slot cna-lisp.internal.ffi::cube-map-face)
                       (let ((face (render-target-binding-cube-map-face binding)))
                         (if face (cube-map-face-value face) 0)))))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-set-render-targets handle array count)
       "set-render-targets" :object-type 'graphics-device))
    (setf (%bound-render-targets device) (copy-list bindings)))
  (values))

(defgeneric get-render-targets (graphics-device)
  (:documentation
   "GraphicsDevice.GetRenderTargets(): the bindings currently set, as a list.

Answers the RENDER-TARGET-BINDING values this binding bound, **cross-checked**
against what CNA reports. Only the objects come from the record, and only because
they have to: `cna_graphics_device_copy_render_targets' answers handles, and the
ABI has no route from a handle back to the object that owns it, so wrapping them
would invent second objects for targets this program already has.

Everything CNA *can* be asked is checked against the record, and a disagreement
signals rather than being papered over. That is four things, because a binding's
identity is more than its target handle:

* the **count** `cna_graphics_device_get_render_target_count' reports;
* the **written count** the copy route reports, which is the exact required
  element count -- a copy that wrote fewer elements than the count promised would
  otherwise leave the rest of the array reading as zeroed bindings;
* every slot's **target handle**, in order, so a swapped pair is caught;
* every slot's **cube map face**, which is the half of a cube binding's identity
  the handle does not carry. A 2D target has no face, and CNA reports positive X
  for one -- \"meaningless for a 2D target and must then be positive X\" -- so that
  is what a faceless binding is checked against, rather than being skipped.

The array slice is checked to be zero as well, which is what CNA requires of it
in both directions.

An empty list is XNA's empty array: the back buffer is current."))

(defmethod get-render-targets ((device graphics-device))
  (let ((handle (%resolve-device-handle device "get-render-targets"))
        (remembered (%bound-render-targets device)))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-render-target-count handle out)
       "get-render-targets" :object-type 'graphics-device)
      (let ((count (cffi:mem-ref out :uint64)))
        (unless (= count (length remembered))
          (error 'microsoft.xna.framework:cna-internal-error
                 :operation "get-render-targets"
                 :object-type 'graphics-device
                 :format-control
                 "CNA reports ~d bound render target(s) and this binding recorded ~d. ~
                  The record is what GetRenderTargets answers, because the ABI has no ~
                  route from a handle back to the object that owns it, so a disagreement ~
                  means the record is wrong rather than merely stale."
                 :format-arguments (list count (length remembered))))
        (when (plusp count)
          (cffi:with-foreign-object
              (array '(:struct cna-lisp.internal.ffi::cna-render-target-binding) count)
            (cffi:foreign-funcall
             "memset" :pointer array :int 0
             :size (* count cna-lisp.internal.ffi::+sizeof-cna-render-target-binding+) :void)
            (macrolet ((entry (index name)
                         `(cffi:foreign-slot-value
                           (cffi:mem-aptr
                            array '(:struct cna-lisp.internal.ffi::cna-render-target-binding)
                            ,index)
                           '(:struct cna-lisp.internal.ffi::cna-render-target-binding)
                           ',name)))
              (dotimes (index count)
                (setf (entry index cna-lisp.internal.ffi::struct-size)
                      cna-lisp.internal.ffi::+sizeof-cna-render-target-binding+
                      (entry index cna-lisp.internal.ffi::struct-version) 1))
              (cffi:with-foreign-object (written :uint64)
                (setf (cffi:mem-ref written :uint64) 0)
                (cna-lisp.internal:check-result
                 (cna-lisp.internal.ffi::%graphics-device-copy-render-targets
                  handle array count written)
                 "get-render-targets" :object-type 'graphics-device)
                ;; The copy route answers "the exact required element count", so a
                ;; number that is not the count already reported means the rest of
                ;; the array is the zeroed memory this filled in, not bindings.
                (let ((n (cffi:mem-ref written :uint64)))
                  (unless (= n count)
                    (error 'microsoft.xna.framework:cna-internal-error
                           :operation "get-render-targets"
                           :object-type 'graphics-device
                           :format-control
                           "CNA reported ~d bound render target(s) and then wrote ~d. ~
                            The remainder of the array is not a binding, so no part of ~
                            this answer can be trusted."
                           :format-arguments (list count n)))))
              (loop for binding in remembered
                    for index from 0
                    for expected-target = (cna-lisp.internal:handle-of
                                           (render-target-binding-target binding))
                    for expected-face
                      = (let ((face (render-target-binding-cube-map-face binding)))
                          ;; A 2D binding has no face here, and CNA reports positive X
                          ;; for one; checking against that is what makes a cube
                          ;; binding's face a real cross-check rather than a skipped one.
                          (cube-map-face-value (or face :positive-x)))
                    do (progn
                         (unless (= (entry index cna-lisp.internal.ffi::render-target)
                                    expected-target)
                           (error 'microsoft.xna.framework:cna-internal-error
                                  :operation "get-render-targets"
                                  :object-type 'graphics-device
                                  :format-control
                                  "CNA reports a different target in slot ~d than this ~
                                   binding recorded there."
                                  :format-arguments (list index)))
                         (unless (= (entry index cna-lisp.internal.ffi::cube-map-face)
                                    expected-face)
                           (error 'microsoft.xna.framework:cna-internal-error
                                  :operation "get-render-targets"
                                  :object-type 'graphics-device
                                  :format-control
                                  "CNA reports slot ~d bound to face ~a and this binding ~
                                   recorded ~a. A cube binding's identity is the target ~
                                   *and* the face, so the handles agreeing is not enough."
                                  :format-arguments
                                  (list index
                                        (cube-map-face-from-value
                                         (entry index cna-lisp.internal.ffi::cube-map-face))
                                        (cube-map-face-from-value expected-face))))
                         (unless (zerop (entry index cna-lisp.internal.ffi::array-slice))
                           (error 'microsoft.xna.framework:cna-internal-error
                                  :operation "get-render-targets"
                                  :object-type 'graphics-device
                                  :format-control
                                  "CNA reports an array slice of ~d in slot ~d. CNA ~
                                   requires the slice to be zero in both directions, so ~
                                   this binding does not know what it would mean."
                                  :format-arguments
                                  (list (entry index cna-lisp.internal.ffi::array-slice)
                                        index))))))))
        (copy-list remembered)))))
