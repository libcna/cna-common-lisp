;;;; sprite-batch.lisp --- Microsoft.Xna.Framework.Graphics.SpriteBatch.
;;;;
;;;; XNA's SpriteBatch.Draw is a family of seven overloads that split on what the
;;;; second argument is and on which of a dozen optional arguments are present.
;;;; Common Lisp cannot express that as one congruent generic function, and this
;;;; binding will not pretend otherwise: the texture-drawing overloads are
;;;; DRAW-TEXTURE with keyword arguments for the optional family, and text
;;;; drawing will be a separate generic function when SpriteFont arrives. See
;;;; docs/common-lisp-mapping.md for the overload table.

(in-package #:microsoft.xna.framework.graphics)

(defclass sprite-batch (cna-lisp.internal:native-object)
  ((begun :initform nil :accessor %begun-p))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.SpriteBatch.

Created against a graphics device inside a lifecycle method, owned by the game,
and disposed with MICROSOFT.XNA.FRAMEWORK:DISPOSE before the game is."))

(defmethod initialize-instance :after ((batch sprite-batch) &key graphics-device)
  (when graphics-device
    (let* ((device-handle (device-handle-for-child graphics-device "make sprite-batch"))
           (game (cna-lisp.internal:owner-of graphics-device)))
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%sprite-batch-create device-handle out)
         "make sprite-batch" :object-type 'sprite-batch)
        (setf (cna-lisp.internal:handle-of batch) (cffi:mem-ref out :uint64)
              (slot-value batch 'cna-lisp.internal::owner) game
              (slot-value batch 'cna-lisp.internal::owner-thread)
              (cna-lisp.internal:owner-thread-of game)))
      (cna-lisp.internal:register-child game batch))))

(defgeneric begin (sprite-batch &key sort-mode)
  (:documentation
   "SpriteBatch.Begin(). SORT-MODE is a SPRITE-SORT-MODE member; the state-bearing
overloads are not part of this milestone."))

(defmethod begin ((batch sprite-batch) &key (sort-mode :deferred))
  (check-type sort-mode sprite-sort-mode)
  (cna-lisp.internal:check-usable batch "begin")
  (when (%begun-p batch)
    (error 'microsoft.xna.framework:cna-invalid-state-error
           :operation "begin" :object-type 'sprite-batch
           :format-control "BEGIN was called twice without an intervening END."))
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-sprite-batch-begin-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-sprite-batch-begin-info+ :void)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   info '(:struct cna-lisp.internal.ffi::cna-sprite-batch-begin-info) ',name)))
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-sprite-batch-begin-info+
            (slot cna-lisp.internal.ffi::struct-version) 1
            (slot cna-lisp.internal.ffi::sort-mode) (sprite-sort-mode-value sort-mode)))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sprite-batch-begin (cna-lisp.internal:handle-of batch) info)
     "begin" :object-type 'sprite-batch))
  (setf (%begun-p batch) t)
  (values))

(defgeneric end (sprite-batch)
  (:documentation "SpriteBatch.End()."))

(defmethod end ((batch sprite-batch))
  (cna-lisp.internal:check-usable batch "end")
  (unless (%begun-p batch)
    (error 'microsoft.xna.framework:cna-invalid-state-error
           :operation "end" :object-type 'sprite-batch
           :format-control "END was called without a matching BEGIN."))
  (setf (%begun-p batch) nil)
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%sprite-batch-end (cna-lisp.internal:handle-of batch))
   "end" :object-type 'sprite-batch)
  (values))

(defgeneric draw-texture (sprite-batch texture &key)
  (:documentation
   "SpriteBatch.Draw for a texture.

POSITION places the sprite's origin; DESTINATION gives an explicit destination
rectangle instead. SOURCE selects a sub-rectangle of the texture, COLOR tints,
ROTATION is in radians, ORIGIN is the rotation and scale centre in texture
texels, SCALE is a uniform or per-axis factor, EFFECTS is a SPRITE-EFFECTS
member or list, and LAYER-DEPTH orders the sprite."))

(defmethod draw-texture ((batch sprite-batch) (texture texture-2d)
                         &key position destination source
                              (color nil color-supplied-p)
                              (rotation 0.0f0) origin (scale 1.0f0)
                              (effects :none) (layer-depth 0.0f0))
  ;; Arguments are checked before state, the same order the CNA C ABI documents
  ;; for itself: a call that gets both wrong reports the argument.
  (when (and position destination)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "draw-texture"
           :format-control
           "give either :POSITION or :DESTINATION, not both: they are different XNA ~
            overloads and mean different things."))
  (cna-lisp.internal:check-usable batch "draw-texture")
  (cna-lisp.internal:check-live texture "draw-texture")
  (unless (%begun-p batch)
    (error 'microsoft.xna.framework:cna-invalid-state-error
           :operation "draw-texture" :object-type 'sprite-batch
           :format-control "DRAW-TEXTURE is only legal between BEGIN and END."))
  (let* ((tint (if color-supplied-p color (microsoft.xna.framework:white)))
         (src (or source (bounds texture)))
         (scale-x (if (numberp scale) (coerce scale 'single-float)
                      (microsoft.xna.framework:vector2-x scale)))
         (scale-y (if (numberp scale) (coerce scale 'single-float)
                      (microsoft.xna.framework:vector2-y scale)))
         (dest (or destination
                   (let ((px (if position (microsoft.xna.framework:vector2-x position) 0.0f0))
                         (py (if position (microsoft.xna.framework:vector2-y position) 0.0f0)))
                     (microsoft.xna.framework:make-rectangle
                      (round px) (round py)
                      (round (* (microsoft.xna.framework:rectangle-width src) scale-x))
                      (round (* (microsoft.xna.framework:rectangle-height src) scale-y)))))))
    (cffi:with-foreign-object (cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command))
      (cffi:foreign-funcall "memset" :pointer cmd :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-sprite-command+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command) ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-sprite-command+
              (slot cna-lisp.internal.ffi::struct-version) 1
              (slot cna-lisp.internal.ffi::texture) (cna-lisp.internal:handle-of texture)
              (slot cna-lisp.internal.ffi::rotation) (coerce rotation 'single-float)
              (slot cna-lisp.internal.ffi::effects) (sprite-effects-value effects)
              (slot cna-lisp.internal.ffi::layer-depth) (coerce layer-depth 'single-float))
        ;; CNA_Color is an aggregate field; its four bytes are exactly the packed
        ;; value, in the same order, so one 32-bit store writes it.
        (setf (cffi:mem-ref (cffi:foreign-slot-pointer
                             cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command)
                             'cna-lisp.internal.ffi::color)
                            :uint32)
              (microsoft.xna.framework:color-packed-value tint))
        (let ((d (cffi:foreign-slot-pointer
                  cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command)
                  'cna-lisp.internal.ffi::destination))
              (s (cffi:foreign-slot-pointer
                  cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command)
                  'cna-lisp.internal.ffi::source))
              (o (cffi:foreign-slot-pointer
                  cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command)
                  'cna-lisp.internal.ffi::origin)))
          (%write-rectangle d dest)
          (%write-rectangle s src)
          (setf (cffi:foreign-slot-value o '(:struct cna-lisp.internal.ffi::cna-vector-2)
                                         'cna-lisp.internal.ffi::x)
                (if origin (microsoft.xna.framework:vector2-x origin) 0.0f0)
                (cffi:foreign-slot-value o '(:struct cna-lisp.internal.ffi::cna-vector-2)
                                         'cna-lisp.internal.ffi::y)
                (if origin (microsoft.xna.framework:vector2-y origin) 0.0f0))))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%sprite-batch-submit-many
        (cna-lisp.internal:handle-of batch) cmd 1)
       "draw-texture" :object-type 'sprite-batch)))
  (values))

(defun %write-rectangle (pointer rectangle)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-rectangle) ',name)))
    (setf (slot cna-lisp.internal.ffi::x) (microsoft.xna.framework:rectangle-x rectangle)
          (slot cna-lisp.internal.ffi::y) (microsoft.xna.framework:rectangle-y rectangle)
          (slot cna-lisp.internal.ffi::width) (microsoft.xna.framework:rectangle-width rectangle)
          (slot cna-lisp.internal.ffi::height)
          (microsoft.xna.framework:rectangle-height rectangle))))

(defmethod cna-lisp.internal:destroy-native ((batch sprite-batch))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%sprite-batch-destroy (cna-lisp.internal:handle-of batch))
   "dispose" :object-type 'sprite-batch))
