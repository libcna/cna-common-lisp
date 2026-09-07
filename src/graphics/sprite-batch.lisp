;;;; sprite-batch.lisp --- Microsoft.Xna.Framework.Graphics.SpriteBatch.
;;;;
;;;; XNA's SpriteBatch.Draw is a family of seven overloads that split on what the
;;;; second argument is and on which of a dozen optional arguments are present.
;;;; Common Lisp cannot express that as one congruent generic function, and this
;;;; binding will not pretend otherwise: the texture-drawing overloads are
;;;; DRAW-TEXTURE with keyword arguments for the optional family, and the six
;;;; text overloads are DRAW-STRING, at the end of this file. See
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
    (let ((device-handle (device-handle-for-child graphics-device "make sprite-batch")))
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%sprite-batch-create device-handle out)
         "make sprite-batch" :object-type 'sprite-batch)
        (let ((handle (cffi:mem-ref out :uint64)))
          (cna-lisp.internal:record-construction-undo
           batch (lambda () (cna-lisp.internal.ffi::%sprite-batch-destroy handle)))
          (setf (cna-lisp.internal:handle-of batch) handle)))
      (adopt-native-resource batch graphics-device)
      (cna-lisp.internal:record-construction-undo
       batch (lambda () (cna-lisp.internal:invalidate batch))))))

(defgeneric begin (sprite-batch &key sort-mode blend-state sampler-state
                                     depth-stencil-state rasterizer-state
                                     effect transform-matrix)
  (:documentation
   "SpriteBatch.Begin: all five overloads.

    (begin batch)                              Begin()
    (begin batch :sort-mode m :blend-state b)  Begin(SpriteSortMode, BlendState)
    (begin batch :sort-mode m :blend-state b
                 :sampler-state s :depth-stencil-state d
                 :rasterizer-state r)          the five-parameter overload
    (begin batch ... :effect e)                the six-parameter overload
    (begin batch ... :effect e
                     :transform-matrix m)      the seven-parameter overload

Only those five keyword shapes are accepted. XNA has no Begin that takes a sort
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

`:EFFECT' and `:TRANSFORM-MATRIX' extend the five-parameter shape and only that
one: XNA has no Begin that takes an effect without the four states, and none that
takes a transform without an effect, so both are refused. A NIL `:EFFECT' is the
default sprite effect, which is what a null Effect means to XNA, and is not the
same as leaving the keyword out.

`:TRANSFORM-MATRIX' takes a Matrix by pointer here, so unlike BasicEffect's World,
View and Projection it needs no shim: CNA's route already takes `const
CNA_Matrix*'."))

(defun %refuse-begin (format-control &rest format-arguments)
  (error 'microsoft.xna.framework:cna-usage-error
         :operation "begin"
         :format-control format-control
         :format-arguments format-arguments))

(defun %check-begin-shape (sort-mode-p blend-p sampler-p depth-p rasterizer-p
                           effect-p transform-p)
  "Refuse every keyword combination XNA's Begin family does not have.

Answers :PLAIN, :BLEND, :FULL, :EFFECT or :TRANSFORM for the five it accepts."
  (let ((states (list blend-p sampler-p depth-p rasterizer-p)))
    (when (and transform-p (not effect-p))
      (%refuse-begin ":TRANSFORM-MATRIX is XNA's seventh Begin parameter and comes ~
                      after the Effect; there is no overload that takes a transform ~
                      without one. Pass :EFFECT too, with NIL for the default sprite ~
                      effect."))
    (when (and effect-p (notevery #'identity (cons sort-mode-p states)))
      (%refuse-begin ":EFFECT extends the five-parameter Begin and only that one: XNA ~
                      has no overload that takes an Effect without the sort mode and ~
                      all four states."))
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
          ((every #'identity (list sampler-p depth-p rasterizer-p))
           (cond (transform-p :transform) (effect-p :effect) (t :full)))
          (t
           (%refuse-begin ":SAMPLER-STATE, :DEPTH-STENCIL-STATE and :RASTERIZER-STATE are ~
                           one group: XNA has no Begin carrying some of them and not the ~
                           others. Give all three or none.")))))

(defun %begin-with-effect (batch sort-mode blend sampler depth rasterizer
                           effect transform-matrix)
  "The two Begin overloads that carry an Effect.

CNA folds both into one route: a null transform is the identity the
effect-without-transform overload uses, and CNA_INVALID_HANDLE selects the
default sprite effect, which is what a null Effect means to XNA. The transform
travels by pointer, so this needs no shim."
  (when effect (check-type effect effect))
  (when transform-matrix (check-type transform-matrix microsoft.xna.framework:matrix))
  (let ((handle (if effect
                    (progn (cna-lisp.internal:check-usable effect "begin")
                           (cna-lisp.internal:handle-of effect))
                    0)))
    (flet ((call (matrix-pointer)
             (cna-lisp.internal:check-result
              (cna-lisp.internal.ffi::%sprite-batch-begin-with-effect
               (cna-lisp.internal:handle-of batch)
               (sprite-sort-mode-value sort-mode)
               blend sampler depth rasterizer handle matrix-pointer)
              "begin" :object-type 'sprite-batch)))
      (if transform-matrix
          (cffi:with-foreign-object (m '(:struct cna-lisp.internal.ffi::cna-matrix))
            (%write-matrix m transform-matrix)
            (call m))
          (call (cffi:null-pointer))))))

(defmethod begin ((batch sprite-batch)
                  &key (sort-mode nil sort-mode-p)
                       (blend-state nil blend-state-p)
                       (sampler-state nil sampler-state-p)
                       (depth-stencil-state nil depth-stencil-state-p)
                       (rasterizer-state nil rasterizer-state-p)
                       (effect nil effect-p)
                       (transform-matrix nil transform-matrix-p))
  ;; Arguments before state, the same order the CNA C ABI documents for itself.
  (let ((shape (%check-begin-shape sort-mode-p blend-state-p sampler-state-p
                                   depth-stencil-state-p rasterizer-state-p
                                   effect-p transform-matrix-p)))
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
              (if (member shape '(:effect :transform))
                  (%begin-with-effect batch sort-mode blend-pointer sampler-pointer
                                      depth-pointer rasterizer-pointer
                                      effect transform-matrix)
                  (cna-lisp.internal:check-result
                   (cna-lisp.internal.ffi::%sprite-batch-begin-with-states
                    (cna-lisp.internal:handle-of batch)
                    (sprite-sort-mode-value sort-mode)
                    blend-pointer sampler-pointer depth-pointer rasterizer-pointer)
                   "begin" :object-type 'sprite-batch))))))
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

;;; --- DrawString --------------------------------------------------------------
;;;
;;; Six contract members and one Lisp function. The six divide two ways: the text
;;; is a `String' or a `StringBuilder', and the placement is the plain
;;; position-and-colour form or the transformed form with a scalar or a Vector2
;;; scale. Only the second division is expressible here -- a StringBuilder is
;;; reached through `Length' and `Chars' and nothing else, which is what a Common
;;; Lisp string already is -- so the String/StringBuilder pair is a *unified*
;;; collapse the mapping rules declare and the verifier checks, and the three
;;; shapes are told apart by keywords and by the type of the scale, exactly as
;;; DRAW-TEXTURE's are.
;;;
;;; XNA implements all six by wrapping the text in a private `StringProxy' and
;;; calling `SpriteFont::InternalDraw', which walks the glyphs and issues one
;;; ordinary `SpriteBatch.Draw' per glyph. CNA has a `cna_sprite_batch_draw_string'
;;; route and this does not use it: the layout below is XNA's, transcribed from
;;; the assembly, and drawing through the texture path that the rasterizer lane
;;; has already proved is what makes a text pixel proof mean something.

(defgeneric draw-string (sprite-batch sprite-font text &key)
  (:documentation
   "SpriteBatch.DrawString: all six of XNA's overloads.

    (draw-string batch font text :position p :color c)
    (draw-string batch font text :position p :color c :rotation r :origin o
                                 :scale s :effects e :layer-depth d)

:POSITION and :COLOR are required, because every overload takes both. :ROTATION,
:ORIGIN, :SCALE, :EFFECTS and :LAYER-DEPTH are one group -- XNA has no overload
carrying some of them and not the others -- so they are all given or none is.

:SCALE is a real for the uniform overload and a Vector2 for the per-axis one,
which is the only thing that tells those two apart; XNA's own scalar overload
builds `Vector2(scale, scale)' and hands it to the same code.

TEXT is a string, and it is laid out as the sequence of UTF-16 code units a
`System.String' already is. Both of XNA's text overloads land here: after XNA's
private StringProxy the String and StringBuilder bodies are identical.

Only legal between BEGIN and END, which the per-glyph draws enforce. An empty
string draws nothing and refuses nothing, exactly as XNA's loop does."))

(defun %check-draw-string-shape (position color-supplied-p
                                 rotation origin scale effects layer-depth)
  "Refuse every keyword combination XNA's DrawString family does not have.

Answers T when the transform group is present. The same discipline as
%CHECK-DRAW-SHAPE, and for the same reason: a `&key' lambda list accepts
everything unless something refuses, and accepting a shape XNA lacks would be
inventing a seventh overload."
  (flet ((refuse (format-control &rest format-arguments)
           (error 'microsoft.xna.framework:cna-usage-error
                  :operation "draw-string"
                  :format-control format-control
                  :format-arguments format-arguments)))
    (unless position
      (refuse ":POSITION is required: every one of XNA's six DrawString overloads ~
               places the text at a Vector2."))
    (unless color-supplied-p
      (refuse ":COLOR is required: every one of XNA's six DrawString overloads takes ~
               a colour."))
    (let ((group (list (and rotation t) (and origin t) (and scale t)
                       (and effects t) (and layer-depth t))))
      (cond ((every #'identity group) t)
            ((some #'identity group)
             (refuse ":ROTATION, :ORIGIN, :SCALE, :EFFECTS and :LAYER-DEPTH are one ~
                      group: XNA has no DrawString carrying some of them and not the ~
                      others. Give all five or none."))
            (t nil)))))

(defmethod draw-string ((batch sprite-batch) (font sprite-font) (text string)
                        &key position (color nil color-supplied-p)
                             (rotation nil) (origin nil) (scale nil)
                             (effects nil) (layer-depth nil))
  (let ((transformed (%check-draw-string-shape position color-supplied-p rotation
                                               origin scale effects layer-depth)))
    (cna-lisp.internal:check-live font "draw-string")
    (multiple-value-bind (scale-x scale-y)
        (if transformed (%sprite-scale-components scale) (values 1.0f0 1.0f0))
      (%draw-string-glyphs
       batch font (cna-lisp.internal:string-code-units text) position color
       (if transformed (coerce rotation 'single-float) 0.0f0)
       (or origin (microsoft.xna.framework:vector2-zero))
       scale-x scale-y
       (if transformed effects :none)
       (if transformed (coerce layer-depth 'single-float) 0.0f0))))
  (values))

(defun %draw-string-glyphs (batch font units position color rotation origin
                            scale-x scale-y effects layer-depth)
  "SpriteFont::InternalDraw, transcribed.

The parts that are not obvious from a description of text layout, and that the
assembly settles:

* the origin is applied as a **translation composed with the rotation**, not by
  passing an origin to the per-glyph Draw -- each glyph is drawn with
  `Vector2.Zero' as its origin, and the whole text block's origin lives in the
  matrix;
* `FlipHorizontally' measures the string, starts the pen at that width, and
  multiplies every horizontal advance by -1;
* `FlipVertically' starts the pen at `(measure.Y - lineSpacing) * scale.Y' and
  *subtracts* the line advance at each newline instead of adding it;
* a flipped glyph's cropping rectangle is adjusted before it is used --
  vertically by `lineSpacing - glyph.Height - crop.Y', horizontally by
  `crop.X - crop.Width';
* the source rectangle handed to Draw is the **glyph** rectangle and the
  cropping rectangle only moves the pen;
* the advance after a glyph is `(kern.Y + kern.Z) * scale.X * flip', which is the
  glyph's width plus its right bearing, and the left bearing was already paid."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((flip-horizontally (logtest (sprite-effects-value effects) 1))
           (flip-vertically (logtest (sprite-effects-value effects) 2))
           (line-spacing (%font-line-spacing font))
           (spacing (%font-spacing font))
           (transform
             (microsoft.xna.framework:matrix-multiply
              (microsoft.xna.framework:matrix-create-translation
               (* (- (microsoft.xna.framework:vector2-x origin)) scale-x)
               (* (- (microsoft.xna.framework:vector2-y origin)) scale-y)
               0.0f0)
              (microsoft.xna.framework:matrix-create-rotation-z rotation)))
           (flip (if flip-horizontally -1.0f0 1.0f0))
           (flip-offset-x
             (if flip-horizontally
                 (* (microsoft.xna.framework:vector2-x
                     (%measure-code-units font units "draw-string"))
                    scale-x)
                 0.0f0))
           (pen-x flip-offset-x)
           (pen-y (if flip-vertically
                      (* (- (microsoft.xna.framework:vector2-y
                             (%measure-code-units font units "draw-string"))
                            (coerce line-spacing 'single-float))
                         scale-y)
                      0.0f0))
           (first-glyph-of-line t)
           (texture (%font-texture font)))
      (dotimes (i (length units))
        (let ((unit (aref units i)))
          (cond
            ((= unit 13))
            ((= unit 10)
             (setf first-glyph-of-line t
                   pen-x flip-offset-x
                   pen-y (if flip-vertically
                             (- pen-y (* (coerce line-spacing 'single-float) scale-y))
                             (+ pen-y (* (coerce line-spacing 'single-float) scale-y)))))
            (t
             (let* ((index (%font-required-glyph-index font unit "draw-string"))
                    (kern (aref (%font-kerning font) index))
                    (left (microsoft.xna.framework:vector3-x kern))
                    (glyph (aref (%font-glyphs font) index))
                    (crop (aref (%font-cropping font) index)))
               (if first-glyph-of-line
                   (setf left (microsoft.xna.framework:math-helper-max left 0.0f0))
                   (setf pen-x (+ pen-x (* (* spacing scale-x) flip))))
               (setf pen-x (+ pen-x (* (* left scale-x) flip)))
               (let ((crop-x (microsoft.xna.framework:rectangle-x crop))
                     (crop-y (microsoft.xna.framework:rectangle-y crop)))
                 (when flip-vertically
                   (setf crop-y (- line-spacing
                                   (microsoft.xna.framework:rectangle-height glyph)
                                   crop-y)))
                 (when flip-horizontally
                   (setf crop-x (- crop-x (microsoft.xna.framework:rectangle-width crop))))
                 (let ((placed
                         (microsoft.xna.framework:vector2-add
                          (microsoft.xna.framework:vector2-transform
                           (microsoft.xna.framework:make-vector2
                            (+ pen-x (* (coerce crop-x 'single-float) scale-x))
                            (+ pen-y (* (coerce crop-y 'single-float) scale-y)))
                           transform)
                          position)))
                   (draw-texture batch texture
                                 :position placed
                                 :source glyph
                                 :color color
                                 :rotation rotation
                                 :origin (microsoft.xna.framework:vector2-zero)
                                 :scale (microsoft.xna.framework:make-vector2 scale-x scale-y)
                                 :effects effects
                                 :layer-depth layer-depth)))
               (setf first-glyph-of-line nil
                     pen-x (+ pen-x
                              (* (* (+ (microsoft.xna.framework:vector3-y kern)
                                       (microsoft.xna.framework:vector3-z kern))
                                    scale-x)
                                 flip)))))))))))
