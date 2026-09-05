;;;; graphics-state.lisp --- the state objects against the real CNA C ABI.
;;;;
;;;; HEADLESS proves the descriptors were accepted, that the device round-trips
;;;; them, and that the state-bearing SpriteBatch.Begin shapes reach CNA. It
;;;; proves nothing about blending, culling, filtering or any other pixel-
;;;; producing behaviour, and nothing here claims otherwise.
;;;;
;;;; The cross-checks against CNA's own presets are the point of the file. XNA is
;;;; the authority for what a BlendState *is*; CNA has presets of its own, and
;;;; where the two differ the divergence is proved here rather than assumed away.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass state-game (graphics-game)
  ((body :initarg :body :initform nil :accessor body)
   (body-error :initform nil :accessor body-error)
   (body-ran :initform nil :accessor body-ran))
  (:documentation
   "A graphics game that runs one closure inside DRAW, where the device is lent."))

(defmethod xna:draw ((game state-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (body-ran game)
    (setf (body-ran game) t)
    (handler-case (funcall (body game) game)
      (error (condition) (setf (body-error game) condition)))))

(defmacro with-device-body ((game) &body body)
  "Run BODY inside a real DRAW callback, and re-signal anything it raised."
  `(let ((,game (make-instance 'state-game
                               :exit-after 2
                               :body (lambda (,game) ,@body))))
     (unwind-protect
          (progn
            (xna:run ,game)
            (is (body-ran ,game) "the device body never ran")
            (when (body-error ,game) (error (body-error ,game))))
       (progn
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (ignore-errors (xna:dispose ,game))))))

;;; --- CNA's presets, against XNA's ---------------------------------------------

(defun native-blend-state (preset)
  "The BlendState CNA's own cna_blend_state_init writes for one native preset."
  (gfx::%with-state-descriptor (pointer ffi::cna-blend-state
                                ffi::+sizeof-cna-blend-state+)
    (int:check-result (ffi::%blend-state-init preset pointer) "blend-state-init")
    (gfx::%read-blend-state pointer)))

(defun native-depth-stencil-state (preset)
  (gfx::%with-state-descriptor (pointer ffi::cna-depth-stencil-state
                                ffi::+sizeof-cna-depth-stencil-state+)
    (int:check-result (ffi::%depth-stencil-state-init preset pointer)
                      "depth-stencil-state-init")
    (gfx::%read-depth-stencil-state pointer)))

(defun native-rasterizer-state (preset)
  (gfx::%with-state-descriptor (pointer ffi::cna-rasterizer-state
                                ffi::+sizeof-cna-rasterizer-state+)
    (int:check-result (ffi::%rasterizer-state-init preset pointer)
                      "rasterizer-state-init")
    (gfx::%read-rasterizer-state pointer)))

(defun native-sampler-state (preset)
  (gfx::%with-state-descriptor (pointer ffi::cna-sampler-state
                                ffi::+sizeof-cna-sampler-state+)
    (int:check-result (ffi::%sampler-state-init preset pointer) "sampler-state-init")
    (gfx::%read-sampler-state pointer)))

(defun blend-state-differences (expected actual)
  "Every BlendState property on which two states disagree, as a list of names."
  (loop for (name . reader) in (list (cons "ColorSourceBlend" #'gfx:color-source-blend)
                                     (cons "ColorDestinationBlend"
                                           #'gfx:color-destination-blend)
                                     (cons "ColorBlendFunction" #'gfx:color-blend-function)
                                     (cons "AlphaSourceBlend" #'gfx:alpha-source-blend)
                                     (cons "AlphaDestinationBlend"
                                           #'gfx:alpha-destination-blend)
                                     (cons "AlphaBlendFunction" #'gfx:alpha-blend-function)
                                     (cons "ColorWriteChannels" #'gfx:color-write-channels)
                                     (cons "MultiSampleMask" #'gfx:multi-sample-mask))
        unless (equal (funcall reader expected) (funcall reader actual))
          collect (list name (funcall reader expected) (funcall reader actual))))

(define-native-test cnas-blend-presets-agree-with-the-pinned-xna-assembly
  ;; CNA is not the authority here: XNA is, and this is the cross-check that says
  ;; so out loud. A difference is a finding, not a test failure to paper over --
  ;; the projection would keep XNA's value and the divergence would be recorded.
  (dolist (pair (list (cons ffi::+blend-state-preset-opaque+ (gfx:blend-state-opaque))
                      (cons ffi::+blend-state-preset-alpha-blend+
                            (gfx:blend-state-alpha-blend))
                      (cons ffi::+blend-state-preset-additive+ (gfx:blend-state-additive))
                      (cons ffi::+blend-state-preset-non-premultiplied+
                            (gfx:blend-state-non-premultiplied))
                      (cons ffi::+blend-state-preset-default+
                            (make-instance 'gfx:blend-state))))
    (destructuring-bind (preset . xna-state) pair
      (let ((differences (blend-state-differences xna-state (native-blend-state preset))))
        (is (null differences)
            "CNA's blend preset ~d differs from XNA's: ~{~a~^, ~}" preset
            (mapcar (lambda (d) (format nil "~a XNA ~s CNA ~s"
                                        (first d) (second d) (third d)))
                    differences))))))

(define-native-test cnas-depth-and-rasterizer-presets-agree-with-xnas
  (let ((none (native-depth-stencil-state ffi::+depth-stencil-state-preset-none+))
        (default (native-depth-stencil-state ffi::+depth-stencil-state-preset-default+))
        (read-only (native-depth-stencil-state
                    ffi::+depth-stencil-state-preset-depth-read+)))
    (is (eq (gfx:depth-buffer-enable (gfx:depth-stencil-state-none))
            (gfx:depth-buffer-enable none)))
    (is (eq (gfx:depth-buffer-write-enable (gfx:depth-stencil-state-none))
            (gfx:depth-buffer-write-enable none)))
    (is (eq (gfx:depth-buffer-function (gfx:depth-stencil-state-default))
            (gfx:depth-buffer-function default)))
    (is (eq (gfx:depth-buffer-enable (gfx:depth-stencil-state-depth-read))
            (gfx:depth-buffer-enable read-only)))
    (is (eq (gfx:depth-buffer-write-enable (gfx:depth-stencil-state-depth-read))
            (gfx:depth-buffer-write-enable read-only)))
    ;; The two stencil masks are the one place these disagree, and the
    ;; disagreement is pinned rather than smoothed over: see
    ;; THE-STENCIL-MASK-DIVERGENCE-IS-STILL-THERE below.
    (is (= -1 (gfx:stencil-mask (make-instance 'gfx:depth-stencil-state))))
    (is (= -1 (gfx:stencil-write-mask (make-instance 'gfx:depth-stencil-state)))))
  (dolist (pair (list (cons ffi::+rasterizer-state-preset-cull-none+
                            (gfx:rasterizer-state-cull-none))
                      (cons ffi::+rasterizer-state-preset-cull-clockwise+
                            (gfx:rasterizer-state-cull-clockwise))
                      (cons ffi::+rasterizer-state-preset-cull-counter-clockwise+
                            (gfx:rasterizer-state-cull-counter-clockwise))
                      (cons ffi::+rasterizer-state-preset-default+
                            (make-instance 'gfx:rasterizer-state))))
    (destructuring-bind (preset . xna-state) pair
      (let ((native (native-rasterizer-state preset)))
        (is (eq (gfx:cull-mode xna-state) (gfx:cull-mode native)))
        (is (eq (gfx:fill-mode xna-state) (gfx:fill-mode native)))
        (is (eq (gfx:multi-sample-anti-alias xna-state)
                (gfx:multi-sample-anti-alias native))
            "XNA's MultiSampleAntiAlias default is true")
        (is (eq (gfx:scissor-test-enable xna-state) (gfx:scissor-test-enable native)))))))

(define-native-test the-stencil-mask-divergence-is-still-there
  ;; An upstream CNA defect, proved rather than asserted. XNA's
  ;; DepthStencilState::SetDefaults writes ldc.i4.m1 -- -1, the all-ones mask --
  ;; into cachedStencilMask and cachedStencilWriteMask. CNA's own
  ;; DepthStencilState constructor initialises both to 0x7FFFFFFF
  ;; (modules/graphics/src/Xna/DepthStencilState.cpp), losing bit 31, and its
  ;; three presets inherit that.
  ;;
  ;; CNA-Lisp keeps XNA's value, so the public API is right and applying a state
  ;; writes -1 into the descriptor CNA receives. This test pins BOTH sides: if
  ;; CNA is corrected it fails and says so, which is the whole reason for writing
  ;; a divergence down instead of tolerating it. docs/limitations.md has it.
  (dolist (preset (list ffi::+depth-stencil-state-preset-default+
                        ffi::+depth-stencil-state-preset-none+
                        ffi::+depth-stencil-state-preset-depth-read+))
    (let ((native (native-depth-stencil-state preset)))
      (is (= 2147483647 (gfx:stencil-mask native))
          "CNA's preset ~d StencilMask was ~d; the recorded divergence is ~
           int.MaxValue. If this now answers -1, CNA has been corrected and this ~
           test and docs/limitations.md should be retired."
          preset (gfx:stencil-mask native))
      (is (= 2147483647 (gfx:stencil-write-mask native)))))
  ;; And the public value is XNA's, in every instance this binding makes.
  (is (= -1 (gfx:stencil-mask (make-instance 'gfx:depth-stencil-state))))
  (is (= -1 (gfx:stencil-write-mask (make-instance 'gfx:depth-stencil-state))))
  (is (= -1 (gfx:stencil-mask (gfx:depth-stencil-state-default))))
  (is (= -1 (gfx:stencil-write-mask (gfx:depth-stencil-state-none))))
  ;; A state applied through this binding carries XNA's masks into CNA.
  (with-device-body (game)
    (let ((device (xna:graphics-device game)))
      (setf (gfx:depth-stencil-state device) (make-instance 'gfx:depth-stencil-state))
      (let ((back (gfx:depth-stencil-state device)))
        (is (= -1 (gfx:stencil-mask back))
            "an applied XNA default must survive the round trip as -1")
        (is (= -1 (gfx:stencil-write-mask back)))))))

(define-native-test cnas-sampler-presets-agree-with-xnas
  (dolist (pair (list (cons ffi::+sampler-state-preset-point-wrap+
                            (gfx:sampler-state-point-wrap))
                      (cons ffi::+sampler-state-preset-point-clamp+
                            (gfx:sampler-state-point-clamp))
                      (cons ffi::+sampler-state-preset-linear-wrap+
                            (gfx:sampler-state-linear-wrap))
                      (cons ffi::+sampler-state-preset-linear-clamp+
                            (gfx:sampler-state-linear-clamp))
                      (cons ffi::+sampler-state-preset-anisotropic-wrap+
                            (gfx:sampler-state-anisotropic-wrap))
                      (cons ffi::+sampler-state-preset-anisotropic-clamp+
                            (gfx:sampler-state-anisotropic-clamp))
                      (cons ffi::+sampler-state-preset-default+
                            (make-instance 'gfx:sampler-state))))
    (destructuring-bind (preset . xna-state) pair
      (let ((native (native-sampler-state preset)))
        (is (eq (gfx:filter xna-state) (gfx:filter native)))
        (is (eq (gfx:address-u xna-state) (gfx:address-u native)))
        (is (eq (gfx:address-v xna-state) (gfx:address-v native)))
        (is (eq (gfx:address-w xna-state) (gfx:address-w native)))
        (is (= (gfx:max-anisotropy xna-state) (gfx:max-anisotropy native))
            "XNA's MaxAnisotropy default is 4")
        (is (= (gfx:max-mip-level xna-state) (gfx:max-mip-level native)))))))

;;; --- the device round-trip ------------------------------------------------------

(define-native-test a-state-object-round-trips-through-the-device
  (with-device-body (game)
    (let ((device (xna:graphics-device game))
          (state (make-instance 'gfx:blend-state)))
      (setf (gfx:color-source-blend state) :source-alpha
            (gfx:color-destination-blend state) :inverse-source-alpha
            (gfx:color-blend-function state) :reverse-subtract
            (gfx:alpha-source-blend state) :destination-alpha
            (gfx:alpha-blend-function state) :min
            (gfx:color-write-channels state) '(:red :blue)
            (gfx:multi-sample-mask state) 12345)
      (setf (gfx:blend-state device) state)
      (let ((read-back (gfx:blend-state device)))
        (is (eq :source-alpha (gfx:color-source-blend read-back)))
        (is (eq :inverse-source-alpha (gfx:color-destination-blend read-back)))
        (is (eq :reverse-subtract (gfx:color-blend-function read-back)))
        (is (eq :destination-alpha (gfx:alpha-source-blend read-back)))
        ;; The one that proves the translation is by name: XNA's Min is 3 and
        ;; CNA's CNA_BLEND_FUNCTION_MIN is 4, so a numeric pass-through would
        ;; answer :MAX here.
        (is (eq :min (gfx:alpha-blend-function read-back))
            "a Min written by name must read back as Min, not Max")
        (is (equal '(:red :blue) (gfx:color-write-channels read-back)))
        (is (= 12345 (gfx:multi-sample-mask read-back))))
      ;; The device answers a copy, not the object that was applied.
      (is (not (eq state (gfx:blend-state device)))))))

(define-native-test applying-a-state-latches-it-read-only
  ;; XNA's Apply sets isBound, and every setter then throws. The device setter is
  ;; where that happens for a state a caller built.
  (with-device-body (game)
    (let ((device (xna:graphics-device game))
          (state (make-instance 'gfx:rasterizer-state)))
      (setf (gfx:fill-mode state) :wire-frame)
      (setf (gfx:rasterizer-state device) state)
      (signals xna:cna-invalid-state-error (setf (gfx:fill-mode state) :solid))
      (signals xna:cna-invalid-state-error (setf (gfx:cull-mode state) :none))
      ;; The value it was applied with is still readable.
      (is (eq :wire-frame (gfx:fill-mode state))))))

(define-native-test the-device-state-setters-refuse-nil
  ;; XNA throws ArgumentNullException; a null state means "the default" only to
  ;; SpriteBatch.Begin, never to the device.
  (with-device-body (game)
    (let ((device (xna:graphics-device game)))
      (signals xna:cna-argument-out-of-range-error (setf (gfx:blend-state device) nil))
      (signals xna:cna-argument-out-of-range-error
        (setf (gfx:depth-stencil-state device) nil))
      (signals xna:cna-argument-out-of-range-error
        (setf (gfx:rasterizer-state device) nil))
      (signals type-error (setf (gfx:blend-state device) (make-instance 'gfx:sampler-state))))))

(define-native-test the-depth-and-rasterizer-states-round-trip-too
  (with-device-body (game)
    (let ((device (xna:graphics-device game))
          (depth (make-instance 'gfx:depth-stencil-state))
          (rasterizer (make-instance 'gfx:rasterizer-state)))
      (setf (gfx:depth-buffer-enable depth) nil
            (gfx:stencil-enable depth) t
            (gfx:stencil-function depth) :greater-equal
            (gfx:stencil-pass depth) :increment-saturation
            (gfx:two-sided-stencil-mode depth) t
            (gfx:counter-clockwise-stencil-fail depth) :invert
            (gfx:stencil-mask depth) #x0F
            (gfx:reference-stencil depth) 3)
      (setf (gfx:depth-stencil-state device) depth)
      (let ((back (gfx:depth-stencil-state device)))
        (is (null (gfx:depth-buffer-enable back)))
        (is (eq t (gfx:stencil-enable back)))
        (is (eq :greater-equal (gfx:stencil-function back)))
        (is (eq :increment-saturation (gfx:stencil-pass back)))
        (is (eq t (gfx:two-sided-stencil-mode back)))
        (is (eq :invert (gfx:counter-clockwise-stencil-fail back)))
        (is (= #x0F (gfx:stencil-mask back)))
        (is (= 3 (gfx:reference-stencil back))))
      (setf (gfx:cull-mode rasterizer) :cull-clockwise-face
            (gfx:fill-mode rasterizer) :wire-frame
            (gfx:scissor-test-enable rasterizer) t
            (gfx:multi-sample-anti-alias rasterizer) nil
            (gfx:depth-bias rasterizer) 0.25
            (gfx:slope-scale-depth-bias rasterizer) -1.5)
      (setf (gfx:rasterizer-state device) rasterizer)
      (let ((back (gfx:rasterizer-state device)))
        (is (eq :cull-clockwise-face (gfx:cull-mode back)))
        (is (eq :wire-frame (gfx:fill-mode back)))
        (is (eq t (gfx:scissor-test-enable back)))
        (is (null (gfx:multi-sample-anti-alias back)))
        (is (= 0.25f0 (gfx:depth-bias back)))
        (is (= -1.5f0 (gfx:slope-scale-depth-bias back)))))))

(define-native-test the-devices-scalar-state-round-trips
  (with-device-body (game)
    (let ((device (xna:graphics-device game)))
      (setf (gfx:blend-factor device) (xna:cornflower-blue))
      (is (xna:color-equal (xna:cornflower-blue) (gfx:blend-factor device)))
      (setf (gfx:multi-sample-mask device) #x00FF00FF)
      (is (= #x00FF00FF (gfx:multi-sample-mask device)))
      (setf (gfx:reference-stencil device) 42)
      (is (= 42 (gfx:reference-stencil device)))
      ;; CNA_Rectangle is a by-value aggregate: two INTEGER eightbytes. If the
      ;; flattening were wrong this is where the wrong numbers would come back.
      (setf (gfx:scissor-rectangle device) (xna:make-rectangle 3 5 7 11))
      (let ((back (gfx:scissor-rectangle device)))
        (is (= 3 (xna:rectangle-x back)))
        (is (= 5 (xna:rectangle-y back)))
        (is (= 7 (xna:rectangle-width back)))
        (is (= 11 (xna:rectangle-height back)))))))

;;; --- SpriteBatch.Begin's state-bearing overloads --------------------------------

(define-native-test every-legal-begin-shape-reaches-cna
  (with-device-body (game)
    (let ((batch (batch game)))
      (macrolet ((accepted (&rest arguments)
                   `(progn (gfx:begin batch ,@arguments)
                           (gfx:draw-texture batch (texture game)
                                             :position (xna:make-vector2 1.0 2.0)
                                             :color (xna:white))
                           (gfx:end batch)
                           t)))
        ;; Begin()
        (is (accepted))
        ;; Begin(SpriteSortMode, BlendState), with a state and with the null that
        ;; selects AlphaBlend.
        (is (accepted :sort-mode :deferred :blend-state (gfx:blend-state-additive)))
        (is (accepted :sort-mode :deferred :blend-state nil))
        ;; The five-parameter overload, all supplied and all null.
        (is (accepted :sort-mode :back-to-front
                      :blend-state (gfx:blend-state-non-premultiplied)
                      :sampler-state (gfx:sampler-state-point-clamp)
                      :depth-stencil-state (gfx:depth-stencil-state-depth-read)
                      :rasterizer-state (gfx:rasterizer-state-cull-none)))
        (is (accepted :sort-mode :immediate :blend-state nil :sampler-state nil
                      :depth-stencil-state nil :rasterizer-state nil))
        ;; Every sort mode the enumeration has.
        (dolist (mode (gfx:all-sprite-sort-mode))
          (is (accepted :sort-mode mode :blend-state nil)))))))

(define-native-test a-caller-built-state-reaches-begin-and-is-latched
  (with-device-body (game)
    (let ((batch (batch game))
          (blend (make-instance 'gfx:blend-state))
          (sampler (make-instance 'gfx:sampler-state)))
      (setf (gfx:color-source-blend blend) :source-alpha
            (gfx:filter sampler) :point)
      (gfx:begin batch :sort-mode :deferred :blend-state blend
                       :sampler-state sampler
                       :depth-stencil-state (make-instance 'gfx:depth-stencil-state)
                       :rasterizer-state (make-instance 'gfx:rasterizer-state))
      (gfx:end batch)
      ;; XNA latches a state object when it is applied. It applies at Begin for
      ;; :IMMEDIATE and at End for the deferred modes; CNA copies the descriptors
      ;; at Begin, so this latches at Begin for every mode. docs/limitations.md
      ;; records the difference.
      (signals xna:cna-invalid-state-error (setf (gfx:color-source-blend blend) :one))
      (signals xna:cna-invalid-state-error (setf (gfx:filter sampler) :linear)))))

(define-native-test the-begin-shapes-xna-does-not-have-are-refused-by-the-real-begin
  (with-device-body (game)
    (let ((batch (batch game)))
      (macrolet ((refuses (why &rest arguments)
                   `(handler-case (progn (gfx:begin batch ,@arguments)
                                         (gfx:end batch)
                                         (fail ,why))
                      (xna:cna-usage-error () t))))
        (is (refuses "a sort mode on its own was accepted" :sort-mode :immediate))
        (is (refuses "a blend state without a sort mode was accepted"
                     :blend-state (gfx:blend-state-opaque)))
        (is (refuses "a partial state group was accepted"
                     :sort-mode :deferred :blend-state nil :sampler-state nil))
        (is (refuses "a partial state group was accepted"
                     :sort-mode :deferred :blend-state nil
                     :depth-stencil-state nil :rasterizer-state nil))
        (is (refuses "the trailing states without a blend state were accepted"
                     :sort-mode :deferred :sampler-state nil
                     :depth-stencil-state nil :rasterizer-state nil)))
      ;; A refused Begin applied nothing, so the batch is still closed and a
      ;; legal Begin still works.
      (finishes (progn (gfx:begin batch) (gfx:end batch))))))

(define-native-test a-refused-begin-does-not-latch-the-states-it-was-given
  (with-device-body (game)
    (let ((batch (batch game))
          (blend (make-instance 'gfx:blend-state)))
      ;; A shape XNA does not have, carrying a caller's state object.
      (signals xna:cna-usage-error
        (gfx:begin batch :blend-state blend))
      ;; Nothing was applied, so nothing may be read-only.
      (setf (gfx:color-source-blend blend) :destination-color)
      (is (eq :destination-color (gfx:color-source-blend blend))))))

(define-native-test begin-and-end-keep-their-order-with-states
  (with-device-body (game)
    (let ((batch (batch game)))
      (gfx:begin batch :sort-mode :deferred :blend-state nil)
      (signals xna:cna-invalid-state-error
        (gfx:begin batch :sort-mode :deferred :blend-state nil))
      (gfx:end batch)
      (signals xna:cna-invalid-state-error (gfx:end batch))
      ;; And drawing outside an interval is still refused.
      (signals xna:cna-invalid-state-error
        (gfx:draw-texture batch (texture game)
                          :position (xna:make-vector2 0.0 0.0) :color (xna:white))))))

(define-native-test a-disposed-batch-refuses-a-state-bearing-begin
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (let ((batch (batch game)))
      (xna:dispose batch)
      (signals xna:cna-disposed-error
        (gfx:begin batch :sort-mode :deferred :blend-state (gfx:blend-state-opaque)))
      (setf (batch game) nil))))

(define-native-test the-state-objects-are-refused-outside-a-callback
  ;; The device is lent for a callback's duration, and its state is device state.
  (with-counting-game (game)
    (let ((device (xna:graphics-device game)))
      (signals xna:cna-scope-error (gfx:blend-state device))
      (signals xna:cna-scope-error (setf (gfx:blend-state device)
                                         (gfx:blend-state-opaque)))
      (signals xna:cna-scope-error (gfx:scissor-rectangle device))
      (signals xna:cna-scope-error (gfx:multi-sample-mask device)))))

;;; --- the device's sampler and texture collections --------------------------------

(define-native-test the-collection-properties-answer-one-object-each
  ;; XNA's properties answer the same collection every time, and the collection is
  ;; where what was bound is remembered, so a fresh one per call would forget it.
  (with-device-body (game)
    (let ((device (xna:graphics-device game)))
      (is (eq (gfx:sampler-states device) (gfx:sampler-states device)))
      (is (eq (gfx:vertex-sampler-states device) (gfx:vertex-sampler-states device)))
      (is (eq (gfx:textures device) (gfx:textures device)))
      (is (eq (gfx:vertex-textures device) (gfx:vertex-textures device)))
      ;; And the pixel and vertex collections are different objects for different
      ;; shader stages.
      (is (not (eq (gfx:sampler-states device) (gfx:vertex-sampler-states device))))
      (is (not (eq (gfx:textures device) (gfx:vertex-textures device))))
      (is (typep (gfx:sampler-states device) 'gfx:sampler-state-collection))
      (is (typep (gfx:textures device) 'gfx:texture-collection)))))

(define-native-test a-sampler-slot-answers-the-object-that-was-set
  ;; The whole reason the collection keeps an array: XNA's indexer answers the
  ;; object, not a fresh equivalent, and reference identity is observable.
  (with-device-body (game)
    (let* ((samplers (gfx:sampler-states (xna:graphics-device game)))
           (state (make-instance 'gfx:sampler-state)))
      (setf (gfx:filter state) :point
            (gfx:address-u state) :mirror)
      (setf (gfx:item samplers 3) state)
      (is (eq state (gfx:item samplers 3)))
      ;; Applying it latched it, exactly as the device setter does.
      (signals xna:cna-invalid-state-error (setf (gfx:filter state) :linear))
      ;; A slot that was never set still answers something, read from the device
      ;; once and then stable.
      (let ((untouched (gfx:item samplers 7)))
        (is (typep untouched 'gfx:sampler-state))
        (is (eq untouched (gfx:item samplers 7)))))))

(define-native-test a-sampler-slot-refuses-nil-and-a-bad-index
  (with-device-body (game)
    (let ((samplers (gfx:sampler-states (xna:graphics-device game))))
      ;; The range check comes first, before the null check, as XNA's does.
      (signals xna:cna-argument-out-of-range-error (gfx:item samplers -1))
      (signals xna:cna-argument-out-of-range-error (gfx:item samplers 16))
      (signals xna:cna-argument-out-of-range-error (setf (gfx:item samplers 16) nil))
      ;; Then the null check: a sampler slot does not take one.
      (signals xna:cna-argument-out-of-range-error (setf (gfx:item samplers 0) nil))
      (signals type-error (setf (gfx:item samplers 0) (make-instance 'gfx:blend-state))))))

(define-native-test setting-a-sampler-slot-to-what-it-holds-applies-nothing
  ;; XNA short-circuits on identity, and that is observable: a state object that
  ;; the no-op assignment never applied must not be latched by it.
  (with-device-body (game)
    (let* ((samplers (gfx:sampler-states (xna:graphics-device game)))
           (state (make-instance 'gfx:sampler-state)))
      (setf (gfx:item samplers 1) state)
      (is (eq state (gfx:item samplers 1)))
      ;; Assigning it again changes nothing and raises nothing.
      (finishes (setf (gfx:item samplers 1) state))
      (is (eq state (gfx:item samplers 1))))))

(define-native-test a-texture-slot-round-trips-the-texture-it-was-given
  (with-device-body (game)
    (let ((textures (gfx:textures (xna:graphics-device game)))
          (texture (texture game)))
      ;; Empty to begin with, and NIL is what an empty slot answers.
      (is (null (gfx:item textures 5)))
      (setf (gfx:item textures 5) texture)
      (is (eq texture (gfx:item textures 5)))
      ;; NIL is legal on this collection -- it is the empty slot -- unlike the
      ;; sampler collection, whose null throws.
      (setf (gfx:item textures 5) nil)
      (is (null (gfx:item textures 5)))
      (signals xna:cna-argument-out-of-range-error (gfx:item textures 16))
      (signals type-error (setf (gfx:item textures 0) (make-instance 'gfx:sampler-state))))))

(define-native-test a-texture-slot-refuses-a-disposed-texture
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (let ((texture (texture game)))
      (xna:dispose texture)
      (setf (texture game) nil)
      ;; Outside a callback the device is refused first, which is the earlier of
      ;; the two checks and the one that matters.
      (signals xna:cna-error
        (setf (gfx:item (gfx:textures (xna:graphics-device game)) 0) texture)))))

;;; --- the manager's preference surface, and the two static fields -------------
;;;
;;; Seven members that were missing until CNA's get/set pairs were bound. The
;;; interesting half is the enums: a preference is a keyword here, or a *list* of
;;; them where the enum carries the FlagsAttribute, and the numbers stay private.

(defclass preference-game (counting-game)
  ((manager :initform nil :accessor preference-manager)
   (results :initform '() :accessor preference-results)
   (failure :initform nil :accessor preference-failure))
  (:documentation "Round-trips every GraphicsDeviceManager preference."))

(defmethod initialize-instance :after ((game preference-game) &key)
  (setf (preference-manager game)
        (make-instance 'xna:graphics-device-manager :game game)))

(defmacro %round-trip (game label place value)
  "Set PLACE to VALUE, read it back, and record both."
  `(push (list ,label ,value (progn (setf ,place ,value) ,place))
         (preference-results ,game)))

(defmethod xna:load-content ((game preference-game))
  (call-next-method)
  (handler-case
      (let ((manager (preference-manager game)))
        (%round-trip game :profile (xna:graphics-profile manager) :reach)
        (%round-trip game :multi-sampling (xna:prefer-multi-sampling manager) t)
        (%round-trip game :back-buffer-format
                     (xna:preferred-back-buffer-format manager) :bgr565)
        (%round-trip game :depth-format
                     (xna:preferred-depth-stencil-format manager) :depth-24)
        ;; A flags enum, so a list -- and a two-member one, so a set that a
        ;; single-keyword projection could not express at all.
        (%round-trip game :orientations
                     (xna:supported-orientations manager)
                     '(:landscape-left :landscape-right))
        ;; The empty list is the zero mask, and DisplayOrientation *has* a named
        ;; zero -- Default = 0 -- so it reads back as (:DEFAULT). Recorded as the
        ;; two separate values it is, rather than asserted equal.
        (push (list :orientations-empty '(:default)
                    (progn (setf (xna:supported-orientations manager) '())
                           (xna:supported-orientations manager)))
              (preference-results game)))
    (error (condition) (setf (preference-failure game) condition))))

(define-native-test the-manager-preferences-round-trip-through-cna
  "Every preference CNA has a get/set pair for, set and read back.

The values are deliberately not the defaults: a getter that ignored its setter
and answered whatever CNA started with would pass a test that set :REACH on a
manager that was already :REACH.

The orientation cases are the ones worth reading. `SupportedOrientations' is a
flags enum, so it is a **list** -- a two-member set a single-keyword projection
could not express at all -- and the empty list is the zero mask, which reads back
as `(:DEFAULT)' because DisplayOrientation has a named zero."
  (let ((game (make-instance 'preference-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (preference-failure game))
               "the fixture failed: ~a" (preference-failure game))
           (dolist (row (preference-results game))
             (destructuring-bind (label wanted got) row
               (if (listp wanted)
                   (is (null (set-exclusive-or wanted got))
                       "~a was set to ~a and read back as ~a" label wanted got)
                   (is (eql wanted got)
                       "~a was set to ~a and read back as ~a" label wanted got)))))
      (progn
        (when (preference-manager game)
          (ignore-errors (xna:dispose (preference-manager game))))
        (xna:dispose game)))))

(test the-default-back-buffer-size-is-the-assemblys-and-not-the-windows
  "GraphicsDeviceManager.DefaultBackBufferWidth and Height, read from the pinned
Game assembly's class constructor: `ldc.i4 0x320' and `ldc.i4 0x1e0'.

800 by 480, and the height is the half worth a test. `GameWindow' in the same
assembly has same-shaped static defaults set two instructions earlier -- 0x320
and 0x258, 800 by 600 -- so a projection that reasoned about \"the usual XNA
window size\" instead of reading the field would be wrong by 120 pixels."
  (is (= 800 (xna:graphics-device-manager-default-back-buffer-width)))
  (is (= 480 (xna:graphics-device-manager-default-back-buffer-height))))

;;; --- GraphicsDevice.Clear's other two overloads ------------------------------

(defclass clearing-game (counting-game)
  ((manager :initform nil :accessor clearing-manager)
   (profile :initform nil :accessor observed-profile)
   (outcomes :initform '() :accessor clear-outcomes))
  (:documentation "Calls every Clear shape, legal and illegal."))

(defmethod initialize-instance :after ((game clearing-game) &key)
  (setf (clearing-manager game)
        (make-instance 'xna:graphics-device-manager :game game)))

(defun %clear-outcome (game label thunk)
  (push (cons label
              (handler-case (progn (funcall thunk) :accepted)
                (error (condition) (type-of condition))))
        (clear-outcomes game)))

(defmethod xna:draw ((game clearing-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (when (= 1 (draws game))
    (let ((device (xna:graphics-device game)))
      (setf (observed-profile game) (gfx:graphics-profile device))
      ;; The three shapes XNA has.
      (%clear-outcome game :color
                      (lambda () (gfx:clear device (xna:cornflower-blue))))
      (%clear-outcome game :options-color
                      (lambda () (gfx:clear device (xna:cornflower-blue)
                                            :options '(:target) :depth 1.0 :stencil 0)))
      (%clear-outcome game :options-vector
                      (lambda () (gfx:clear device (xna:make-vector4 0.0 0.5 1.0 1.0)
                                            :options '(:target) :depth 1.0 :stencil 0)))
      ;; The empty mask is legal: XNA's ClearOptions has no named zero, and
      ;; clearing nothing is what asking for nothing means.
      (%clear-outcome game :no-options
                      (lambda () (gfx:clear device (xna:cornflower-blue)
                                            :options '() :depth 1.0 :stencil 0)))
      ;; ...and the shapes it has not.
      (%clear-outcome game :vector-alone
                      (lambda () (gfx:clear device (xna:make-vector4 0.0 0.5 1.0 1.0))))
      (%clear-outcome game :partial-keywords
                      (lambda () (gfx:clear device (xna:cornflower-blue) :options '(:target))))
      (%clear-outcome game :bad-option
                      (lambda () (gfx:clear device (xna:cornflower-blue)
                                            :options '(:not-a-buffer) :depth 1.0 :stencil 0))))))

(define-native-test clear-takes-all-three-overloads-and-only-those
  "Clear(Color), Clear(ClearOptions, Color, Single, Int32) and its Vector4
sibling, plus the shapes XNA has no overload for.

The Vector4 form is the one worth stating: XNA's is four instructions --
`new Color(vector4)' and then the Color overload -- so its eight-bit
quantisation is XNA's own. CNA has a float clear route and using it here would
make this member *differ* from XNA rather than match it."
  (let ((game (make-instance 'clearing-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (dolist (label '(:color :options-color :options-vector :no-options))
             (is (eq :accepted (cdr (assoc label (clear-outcomes game))))
                 "~a was refused with ~a" label (cdr (assoc label (clear-outcomes game)))))
           (is (eq 'xna:cna-argument-error (cdr (assoc :vector-alone (clear-outcomes game))))
               "a bare Vector4 gave ~a; XNA has no Clear(Vector4)"
               (cdr (assoc :vector-alone (clear-outcomes game))))
           (is (eq 'xna:cna-argument-error (cdr (assoc :partial-keywords (clear-outcomes game))))
               "one keyword of three gave ~a"
               (cdr (assoc :partial-keywords (clear-outcomes game))))
           (is (eq 'xna:cna-usage-error (cdr (assoc :bad-option (clear-outcomes game))))
               "an unknown option keyword gave ~a"
               (cdr (assoc :bad-option (clear-outcomes game)))))
      (progn
        (when (clearing-manager game) (ignore-errors (xna:dispose (clearing-manager game))))
        (xna:dispose game)))))

(define-native-test the-device-reports-the-profile-it-was-made-with
  "GraphicsDevice.GraphicsProfile, get-only as XNA's is."
  (let ((game (make-instance 'clearing-game :exit-after 2))
        (profile nil))
    (unwind-protect
         (progn
           (setf (xna:is-fixed-time-step game) nil)
           (xna:run-one-frame game)
           (setf profile (observed-profile game))
           (is (member profile (gfx:all-graphics-profile))
               "the device reported ~a, which is not a GraphicsProfile member" profile))
      (progn
        (when (clearing-manager game) (ignore-errors (xna:dispose (clearing-manager game))))
        (xna:dispose game)))))
