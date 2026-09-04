;;;; render-target.lisp --- RenderTarget2D, and binding one to the device.
;;;;
;;;; A render target is a `Texture2D' you can draw *into*, and XNA says so in the
;;;; type hierarchy: `RenderTarget2D' derives from `Texture2D', so everything a
;;;; texture can do it can do -- including being the source of a
;;;; `SpriteBatch.Draw'. That inheritance is not decoration here, it is what lets
;;;; the qualification prove something new: draw into a target, restore the back
;;;; buffer, draw the *target* as a texture, and read the back buffer. Every step
;;;; of that is checked in `tests/native/rasterization.lisp'.
;;;;
;;;; Three decisions worth stating.
;;;;
;;;; **Binding is on the device, and a null restores the back buffer.** XNA's
;;;; `SetRenderTarget(null)' is how a program stops drawing into a target, and
;;;; CNA spells it the same way -- `CNA_INVALID_HANDLE' to
;;;; `cna_graphics_device_set_render_target2d'. So SET-RENDER-TARGET takes NIL,
;;;; and NIL is not an error.
;;;;
;;;; **`IsContentLost' asks CNA rather than remembering.** CNA's own
;;;; `CNA_RenderTargetInfo' documents exactly when it is true -- "from the moment
;;;; a renderer reports a real device reset until this target is next bound" --
;;;; and that only three renderer families can ever report one. A cached Lisp
;;;; flag could not know.
;;;;
;;;; **The three constructors are one Lisp constructor with defaults, and the
;;;; defaults are XNA's.** `RenderTarget2D(device, width, height)' is the
;;;; three-argument overload and it is *not* "everything zero": XNA fills in no
;;;; mip map, `SurfaceFormat.Color', `DepthFormat.None', no multisampling and
;;;; `RenderTargetUsage.DiscardContents'. Each overload supplies a prefix of the
;;;; eight-argument one, so the keyword sets are nested and the mapping rules
;;;; carry one per overload.

(in-package #:microsoft.xna.framework.graphics)

(defclass render-target-2d (texture-2d)
  ((%usage :initarg :usage :initform :discard-contents :reader render-target-usage)
   (%multi-sample-count :initarg :multi-sample-count :initform 0
                        :reader multi-sample-count)
   (%depth-stencil-format :initarg :depth-stencil-format :initform :none
                          :reader depth-stencil-format))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.RenderTarget2D: a Texture2D that can be
drawn into.

    (make-instance 'render-target-2d :graphics-device device :width 64 :height 64)

Derived from TEXTURE-2D, as XNA's is, so a finished target is an ordinary
texture: SPRITE-BATCH can draw it, a device texture slot can hold it, and an
effect can sample it.

Bound with SET-RENDER-TARGET and unbound by passing NIL. Owned by the game and
disposed with MICROSOFT.XNA.FRAMEWORK:DISPOSE, before it.

`RenderTargetUsage', `MultiSampleCount' and `DepthStencilFormat' are read back
from CNA at construction rather than echoed from the arguments: a backend may
grant less than was asked for, and reporting the request instead of the grant is
how a program comes to believe it has multisampling it has not got."))

(microsoft.xna.framework::define-xna-enum render-target-usage
  '((:discard-contents . 0) (:preserve-contents . 1) (:platform-contents . 2))
  :documentation "Microsoft.Xna.Framework.Graphics.RenderTargetUsage.")

(microsoft.xna.framework::define-xna-enum depth-format
  '((:none . 0) (:depth-16 . 1) (:depth-24 . 2) (:depth-24-stencil-8 . 3))
  :documentation "Microsoft.Xna.Framework.Graphics.DepthFormat.")

(defun %render-target-info (handle operation)
  "Read a render target's granted configuration back out of CNA."
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-render-target-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-render-target-info+ :void)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   info '(:struct cna-lisp.internal.ffi::cna-render-target-info) ',name)))
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-render-target-info+
            (slot cna-lisp.internal.ffi::struct-version) 1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%render-target-get-info handle info)
       operation :object-type 'render-target-2d)
      (values (slot cna-lisp.internal.ffi::width)
              (slot cna-lisp.internal.ffi::height)
              (slot cna-lisp.internal.ffi::level-count)
              (surface-format-from-value (slot cna-lisp.internal.ffi::format))
              (depth-format-from-value (slot cna-lisp.internal.ffi::depth-format))
              (slot cna-lisp.internal.ffi::multi-sample-count)
              (render-target-usage-from-value (slot cna-lisp.internal.ffi::usage))
              (cna-lisp.internal.ffi:cna-true-p
               (slot cna-lisp.internal.ffi::is-content-lost))))))

(defmethod %texture-makes-own-storage-p ((target render-target-2d))
  "A render target's storage comes from cna_render_target2d_create, so TEXTURE-2D's
own constructor must not make a plain texture underneath it."
  t)

(defmethod initialize-instance :after
    ((target render-target-2d)
     &key graphics-device width height (mip-map nil) (format :color)
          (depth-stencil-format :none) (multi-sample-count 0)
          (usage :discard-contents)
          ((:%adopted-handle adopted-handle) nil))
  (when adopted-handle
    (return-from initialize-instance))
  (unless graphics-device
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "make-instance 'render-target-2d"
           :format-control
           "a RenderTarget2D is created against a GraphicsDevice; pass ~
            :GRAPHICS-DEVICE."))
  (check-type width (integer 1))
  (check-type height (integer 1))
  (check-type format surface-format)
  (check-type depth-stencil-format depth-format)
  (check-type usage render-target-usage)
  (check-type multi-sample-count (integer 0))
  (let ((device-handle (device-handle-for-child graphics-device
                                                "make-instance 'render-target-2d"))
        (game (cna-lisp.internal:owner-of graphics-device)))
    (cffi:with-foreign-object
        (info '(:struct cna-lisp.internal.ffi::cna-render-target-2d-create-info))
      (cffi:foreign-funcall
       "memset" :pointer info :int 0
       :size cna-lisp.internal.ffi::+sizeof-cna-render-target-2d-create-info+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     info '(:struct cna-lisp.internal.ffi::cna-render-target-2d-create-info)
                     ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-render-target-2d-create-info+
              (slot cna-lisp.internal.ffi::struct-version) 1
              (slot cna-lisp.internal.ffi::width) width
              (slot cna-lisp.internal.ffi::height) height
              (slot cna-lisp.internal.ffi::mip-map)
              (cna-lisp.internal.ffi:cna-bool-of mip-map)
              (slot cna-lisp.internal.ffi::format) (surface-format-value format)
              (slot cna-lisp.internal.ffi::depth-format)
              (depth-format-value depth-stencil-format)
              (slot cna-lisp.internal.ffi::multi-sample-count) multi-sample-count
              (slot cna-lisp.internal.ffi::usage) (render-target-usage-value usage)))
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%render-target-2d-create device-handle info out)
         "make-instance 'render-target-2d" :object-type 'render-target-2d)
        (let ((handle (cffi:mem-ref out :uint64))
              (constructed nil))
          (unwind-protect
               ;; Everything that can still fail runs under the rollback, so a
               ;; refused read-back cannot leave the game owning a target the
               ;; caller never received.
               (multiple-value-bind (w h levels granted-format granted-depth
                                     granted-samples granted-usage)
                   (%render-target-info handle "make-instance 'render-target-2d")
                 (setf (cna-lisp.internal:handle-of target) handle
                       (slot-value target 'cna-lisp.internal::owner) game
                       (slot-value target 'cna-lisp.internal::owner-thread)
                       (cna-lisp.internal:owner-thread-of game)
                       (slot-value target 'width) w
                       (slot-value target 'height) h
                       (slot-value target 'level-count) levels
                       (slot-value target 'format) granted-format
                       (slot-value target '%depth-stencil-format) granted-depth
                       (slot-value target '%multi-sample-count) granted-samples
                       (slot-value target '%usage) granted-usage)
                 (cna-lisp.internal:register-child game target)
                 (setf constructed t))
            (unless constructed
              (ignore-errors (cna-lisp.internal.ffi::%render-target-destroy handle)))))))))

(defmethod cna-lisp.internal:destroy-native ((target render-target-2d))
  ;; Its own route, not Texture2D's: CNA gives a render target a destroy of its
  ;; own, and reaching the base class's would hand a render-target handle to the
  ;; texture destructor.
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%render-target-destroy (cna-lisp.internal:handle-of target))
   "dispose" :object-type 'render-target-2d))

;;; IS-CONTENT-LOST is already the generic function the dynamic buffers answer;
;;; this adds the render target's method rather than a second name for the same
;;; question. Unlike a buffer's -- which CNA documents as always false -- this one
;;; can really become true: CNA reports it from the moment a renderer announces a
;;; device reset until the target is next bound, on the three renderer families
;;; that can announce one. It is asked of CNA rather than remembered, because a
;;; cached Lisp flag could not know.

(defmethod is-content-lost ((target render-target-2d))
  (cna-lisp.internal:check-usable target "is-content-lost")
  (nth-value 7 (%render-target-info (cna-lisp.internal:handle-of target)
                                    "is-content-lost")))

;;; --- the ContentLost event ---------------------------------------------------

(defmethod microsoft.xna.framework::%event-table ((object render-target-2d))
  microsoft.xna.framework::*buffer-event-values*)

(defmethod microsoft.xna.framework::%subscribe-natively
    ((object render-target-2d) value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%render-target-subscribe-content-lost
   (cna-lisp.internal:handle-of object)
   (cna-lisp.internal.ffi:content-lost-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod microsoft.xna.framework::%unsubscribe-natively
    ((object render-target-2d) registration)
  (cna-lisp.internal.ffi::%render-target-unsubscribe-content-lost registration))

(microsoft.xna.framework::%define-event-methods
 render-target-2d :content-lost add-content-lost-handler remove-content-lost-handler)

;;; --- binding one to the device -------------------------------------------------

(defgeneric set-render-target (graphics-device target)
  (:documentation
   "GraphicsDevice.SetRenderTarget(RenderTarget2D).

TARGET is a RENDER-TARGET-2D to draw into, or **NIL to restore the back buffer**,
which is XNA's `SetRenderTarget(null)' and CNA's `CNA_INVALID_HANDLE'. NIL is the
ordinary way to finish with a target, not an error.

Legal only inside a lifecycle callback, like every other device operation: the
device handle is lent for a callback's duration and this resolves a fresh one."))

(defmethod set-render-target ((device graphics-device) target)
  (when target (check-type target render-target-2d))
  (let ((handle (%resolve-device-handle device "set-render-target")))
    (when target
      (cna-lisp.internal:check-usable target "set-render-target"))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-set-render-target-2d
      handle (if target (cna-lisp.internal:handle-of target) 0))
     "set-render-target" :object-type 'graphics-device))
  (values))
