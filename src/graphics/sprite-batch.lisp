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

(defclass sprite-batch (%native-graphics-resource)
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

(defgeneric begin (sprite-batch &key sort-mode blend-state sampler-state
                                     depth-stencil-state rasterizer-state)
  (:documentation
   "SpriteBatch.Begin: the three overloads whose arguments this milestone has.

    (begin batch)                              Begin()
    (begin batch :sort-mode m :blend-state b)  Begin(SpriteSortMode, BlendState)
    (begin batch :sort-mode m :blend-state b
                 :sampler-state s :depth-stencil-state d
                 :rasterizer-state r)          the five-parameter overload

Only those three keyword shapes are accepted. XNA has no Begin that takes a sort
mode on its own, none that takes a state without a sort mode, and none that takes
some of the four states and not the others, so each of those is refused rather
than quietly treated as one of the overloads that does exist.

A state argument may be NIL, and NIL is not the same as absent: XNA's state
parameters are nullable and a null selects the framework's default, so
`:blend-state nil' is `Begin(sortMode, null)' -- the AlphaBlend overload -- while
leaving `:blend-state' out entirely is a different overload. The defaults a null
selects are XNA's own, read from SpriteBatch::SetRenderState: **AlphaBlend**,
**LinearClamp**, **DepthStencilState.None** and **CullCounterClockwise**.

Every state object supplied here becomes read-only, as XNA's do when they reach a
device. XNA latches them at Begin for `:immediate' and at End for the deferred
modes, because that is when it applies them; CNA copies the descriptors at Begin,
so this latches them at Begin for every sort mode. The difference is one
observable case -- mutating a state between BEGIN and END in a deferred mode --
and refusing it is preferred to accepting a change that could no longer have any
effect. `docs/limitations.md' records it.

The two overloads that take an `Effect' are **not** projected: `Effect' does not
exist in this milestone, and an effect parameter that could only ever be given
NIL would be a fourth shape XNA does not have. They are measured as missing."))

(defun %refuse-begin (format-control &rest format-arguments)
  (error 'microsoft.xna.framework:cna-usage-error
         :operation "begin"
         :format-control format-control
         :format-arguments format-arguments))

(defun %check-begin-shape (sort-mode-p blend-p sampler-p depth-p rasterizer-p)
  "Refuse every keyword combination XNA's Begin family does not have.

Answers :PLAIN, :BLEND or :FULL for the three shapes it accepts."
  (let ((states (list blend-p sampler-p depth-p rasterizer-p)))
    (cond ((notany #'identity (cons sort-mode-p states)) :plain)
          ((not sort-mode-p)
           (%refuse-begin "a state argument needs :SORT-MODE with it: every XNA Begin ~
                           that takes a state takes a SpriteSortMode first, and there ~
                           is no overload that takes one without the other."))
          ((not blend-p)
           (%refuse-begin ":SORT-MODE alone is not an XNA overload. Begin() takes nothing ~
                           and the next one takes a SpriteSortMode *and* a BlendState; ~
                           pass :BLEND-STATE too, with NIL if you want the default."))
          ((notany #'identity (list sampler-p depth-p rasterizer-p)) :blend)
          ((every #'identity (list sampler-p depth-p rasterizer-p)) :full)
          (t
           (%refuse-begin ":SAMPLER-STATE, :DEPTH-STENCIL-STATE and :RASTERIZER-STATE are ~
                           one group: XNA has no Begin carrying some of them and not the ~
                           others. Give all three or none.")))))

(defmethod begin ((batch sprite-batch)
                  &key (sort-mode nil sort-mode-p)
                       (blend-state nil blend-state-p)
                       (sampler-state nil sampler-state-p)
                       (depth-stencil-state nil depth-stencil-state-p)
                       (rasterizer-state nil rasterizer-state-p))
  ;; Arguments before state, the same order the CNA C ABI documents for itself.
  (let ((shape (%check-begin-shape sort-mode-p blend-state-p sampler-state-p
                                   depth-stencil-state-p rasterizer-state-p)))
    (cna-lisp.internal:check-usable batch "begin")
    (when (%begun-p batch)
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation "begin" :object-type 'sprite-batch
             :format-control "BEGIN was called twice without an intervening END."))
    ;; Begin() is Begin(Deferred, null, null, null, null) in XNA's own IL, so the
    ;; three shapes differ only in which arguments the caller supplied, never in
    ;; what reaches CNA.
    (let ((sort-mode (if (eq shape :plain) :deferred sort-mode))
          (blend (or blend-state (blend-state-alpha-blend)))
          (sampler (or sampler-state (sampler-state-linear-clamp)))
          (depth (or depth-stencil-state (depth-stencil-state-none)))
          (rasterizer (or rasterizer-state (rasterizer-state-cull-counter-clockwise))))
      (check-type sort-mode sprite-sort-mode)
      (check-type blend blend-state)
      (check-type sampler sampler-state)
      (check-type depth depth-stencil-state)
      (check-type rasterizer rasterizer-state)
      (%with-state-descriptor (blend-pointer cna-lisp.internal.ffi::cna-blend-state
                               cna-lisp.internal.ffi::+sizeof-cna-blend-state+)
        (%with-state-descriptor (sampler-pointer cna-lisp.internal.ffi::cna-sampler-state
                                 cna-lisp.internal.ffi::+sizeof-cna-sampler-state+)
          (%with-state-descriptor (depth-pointer
                                   cna-lisp.internal.ffi::cna-depth-stencil-state
                                   cna-lisp.internal.ffi::+sizeof-cna-depth-stencil-state+)
            (%with-state-descriptor (rasterizer-pointer
                                     cna-lisp.internal.ffi::cna-rasterizer-state
                                     cna-lisp.internal.ffi::+sizeof-cna-rasterizer-state+)
              (%write-blend-state blend-pointer blend)
              (%write-sampler-state sampler-pointer sampler)
              (%write-depth-stencil-state depth-pointer depth)
              (%write-rasterizer-state rasterizer-pointer rasterizer)
              (cna-lisp.internal:check-result
               (cna-lisp.internal.ffi::%sprite-batch-begin-with-states
                (cna-lisp.internal:handle-of batch)
                (sprite-sort-mode-value sort-mode)
                blend-pointer sampler-pointer depth-pointer rasterizer-pointer)
               "begin" :object-type 'sprite-batch)))))
      ;; Only after the native call has been accepted: a Begin that was refused
      ;; applied nothing, so it must not leave the caller's state objects latched.
      (let ((device (graphics-resource-graphics-device batch)))
        (dolist (state (list blend sampler depth rasterizer))
          (%mark-bound state device)))))
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
   "SpriteBatch.Draw for a texture: all seven of XNA's texture overloads.

They differ in whether the sprite is placed by a **position** or by a
**destination rectangle**, and in whether the transform group is present. The
keyword combination selects the overload, and only the seven combinations XNA
actually has are accepted:

    :position :color                                          Draw(t, Vector2, Color)
    :position :source :color                                  Draw(t, Vector2, Rectangle?, Color)
    :position [:source] :color :rotation :origin :scale
              :effects :layer-depth                           the two scaled overloads
    :destination :color                                       Draw(t, Rectangle, Color)
    :destination :source :color                               Draw(t, Rectangle, Rectangle?, Color)
    :destination [:source] :color :rotation :origin
                 :effects :layer-depth                        Draw(t, Rectangle, Rectangle?, ...)

:COLOR is required, because every one of the seven takes one. Exactly one of
:POSITION and :DESTINATION must be given. :ROTATION, :ORIGIN, :EFFECTS and
:LAYER-DEPTH are all-or-nothing, because XNA has no overload carrying some of
them. :SCALE belongs to the position family only -- the destination overload has
no scale parameter, and a destination rectangle already says how big the sprite
is.

A position and a destination rectangle are **not interchangeable**, and this does
not convert between them: with a position, the origin is measured in
source-texture pixels and the scale applies after that offset, which no computed
rectangle reproduces. The two shapes take CNA's two different submission
routes."))

(defun %sprite-scale-components (scale)
  "The two scale components of the uniform and per-axis overloads."
  (if (numberp scale)
      (let ((s (coerce scale 'single-float))) (values s s))
      (values (microsoft.xna.framework:vector2-x scale)
              (microsoft.xna.framework:vector2-y scale))))

(defun %refuse-draw (format-control &rest format-arguments)
  (error 'microsoft.xna.framework:cna-usage-error
         :operation "draw-texture"
         :format-control format-control
         :format-arguments format-arguments))

(defun %check-draw-shape (position destination color-supplied-p source
                          rotation origin scale effects layer-depth)
  "Refuse every keyword combination XNA does not have.

Accepting a shape XNA lacks would be inventing an overload, which is exactly what
the projection is supposed to make impossible. Answers T when the transform group
is present."
  (declare (ignore source))
  (cond ((and position destination)
         (%refuse-draw "give either :POSITION or :DESTINATION, not both: they are ~
                        different XNA overloads and place the sprite differently."))
        ((and (null position) (null destination))
         (%refuse-draw "one of :POSITION or :DESTINATION is required; XNA has no Draw ~
                        overload that places a sprite without either.")))
  (unless color-supplied-p
    (%refuse-draw ":COLOR is required: every one of XNA's seven texture Draw overloads ~
                   takes a colour, so leaving it out would be an eighth."))
  (let ((group (list (and rotation t) (and origin t) (and effects t) (and layer-depth t))))
    (cond ((every #'identity group)
           (when (and destination scale)
             (%refuse-draw ":SCALE belongs to the position overloads. The destination ~
                            rectangle already says how large the sprite is, and XNA's ~
                            destination overload has no scale parameter."))
           t)
          ((some #'identity group)
           (%refuse-draw ":ROTATION, :ORIGIN, :EFFECTS and :LAYER-DEPTH are one group: ~
                          XNA has no overload that carries some of them and not the ~
                          others. Give all four or none."))
          (t
           (when scale
             (%refuse-draw ":SCALE is only part of the overloads that also take ~
                            :ROTATION, :ORIGIN, :EFFECTS and :LAYER-DEPTH."))
           nil))))

(defmethod draw-texture ((batch sprite-batch) (texture texture-2d)
                         &key position destination source
                              (color nil color-supplied-p)
                              (rotation nil) (origin nil) (scale nil)
                              (effects nil) (layer-depth nil))
  ;; Arguments are checked before state, the same order the CNA C ABI documents
  ;; for itself: a call that gets both wrong reports the argument.
  (let ((transformed (%check-draw-shape position destination color-supplied-p source
                                        rotation origin scale effects layer-depth)))
    (cna-lisp.internal:check-usable batch "draw-texture")
    (cna-lisp.internal:check-live texture "draw-texture")
    (unless (%begun-p batch)
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation "draw-texture" :object-type 'sprite-batch
             :format-control "DRAW-TEXTURE is only legal between BEGIN and END."))
    (let ((rotation (if transformed (coerce rotation 'single-float) 0.0f0))
          (layer-depth (if transformed (coerce layer-depth 'single-float) 0.0f0))
          (effects (if transformed effects :none)))
      (if destination
          (%submit-destination-sprite batch texture destination source color
                                      rotation origin effects layer-depth)
          (%submit-scaled-sprite batch texture position source color
                                 rotation origin scale effects layer-depth))))
  (values))

(defun %submit-destination-sprite (batch texture destination source color
                                   rotation origin effects layer-depth)
  "Draw(Texture2D, Rectangle, ...) through CNA's destination-rectangle route."
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
            (slot cna-lisp.internal.ffi::rotation) rotation
            (slot cna-lisp.internal.ffi::effects) (sprite-effects-value effects)
            (slot cna-lisp.internal.ffi::layer-depth) layer-depth))
    (%write-packed-color cmd 'cna-lisp.internal.ffi::cna-sprite-command
                         'cna-lisp.internal.ffi::color color)
    (%write-rectangle (cffi:foreign-slot-pointer
                       cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command)
                       'cna-lisp.internal.ffi::destination)
                      destination)
    (%write-rectangle (cffi:foreign-slot-pointer
                       cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command)
                       'cna-lisp.internal.ffi::source)
                      (or source (bounds texture)))
    (%write-vector2 (cffi:foreign-slot-pointer
                     cmd '(:struct cna-lisp.internal.ffi::cna-sprite-command)
                     'cna-lisp.internal.ffi::origin)
                    origin)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sprite-batch-submit-many
      (cna-lisp.internal:handle-of batch) cmd 1)
     "draw-texture" :object-type 'sprite-batch)))

(defun %submit-scaled-sprite (batch texture position source color
                              rotation origin scale effects layer-depth)
  "Draw(Texture2D, Vector2, ...) through CNA's position-and-scale route.

Not a computed destination rectangle. The C ABI says the two are not
interchangeable, and it is right: the position is in floating-point screen pixels,
the origin is in source-texture pixels, and the scale applies after that offset.
Rounding a rectangle out of them loses the fractional position and moves the
sprite."
  (multiple-value-bind (scale-x scale-y)
      (if scale (%sprite-scale-components scale) (values 1.0f0 1.0f0))
    (cffi:with-foreign-object (cmd '(:struct cna-lisp.internal.ffi::cna-sprite-scaled-command))
      (cffi:foreign-funcall "memset" :pointer cmd :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-sprite-scaled-command+
                            :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     cmd '(:struct cna-lisp.internal.ffi::cna-sprite-scaled-command) ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-sprite-scaled-command+
              (slot cna-lisp.internal.ffi::struct-version) 1
              (slot cna-lisp.internal.ffi::texture) (cna-lisp.internal:handle-of texture)
              (slot cna-lisp.internal.ffi::rotation) rotation
              (slot cna-lisp.internal.ffi::effects) (sprite-effects-value effects)
              (slot cna-lisp.internal.ffi::layer-depth) layer-depth))
      (%write-packed-color cmd 'cna-lisp.internal.ffi::cna-sprite-scaled-command
                           'cna-lisp.internal.ffi::color color)
      (%write-vector2 (cffi:foreign-slot-pointer
                       cmd '(:struct cna-lisp.internal.ffi::cna-sprite-scaled-command)
                       'cna-lisp.internal.ffi::position)
                      position)
      (%write-vector2 (cffi:foreign-slot-pointer
                       cmd '(:struct cna-lisp.internal.ffi::cna-sprite-scaled-command)
                       'cna-lisp.internal.ffi::origin)
                      origin)
      ;; An absent source is a zero-by-zero rectangle, which is what an empty
      ;; optional means to this route: draw the whole texture.
      (%write-rectangle (cffi:foreign-slot-pointer
                         cmd '(:struct cna-lisp.internal.ffi::cna-sprite-scaled-command)
                         'cna-lisp.internal.ffi::source)
                        (or source (microsoft.xna.framework:make-rectangle 0 0 0 0)))
      (let ((scale-slot (cffi:foreign-slot-pointer
                         cmd '(:struct cna-lisp.internal.ffi::cna-sprite-scaled-command)
                         'cna-lisp.internal.ffi::scale)))
        (setf (cffi:foreign-slot-value scale-slot '(:struct cna-lisp.internal.ffi::cna-vector-2)
                                       'cna-lisp.internal.ffi::x) scale-x
              (cffi:foreign-slot-value scale-slot '(:struct cna-lisp.internal.ffi::cna-vector-2)
                                       'cna-lisp.internal.ffi::y) scale-y))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%sprite-batch-submit-scaled-many
        (cna-lisp.internal:handle-of batch) cmd 1)
       "draw-texture" :object-type 'sprite-batch))))

(defmethod cna-lisp.internal:destroy-native ((batch sprite-batch))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%sprite-batch-destroy (cna-lisp.internal:handle-of batch))
   "dispose" :object-type 'sprite-batch))
