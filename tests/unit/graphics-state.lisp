;;;; graphics-state.lisp --- BlendState, DepthStencilState, RasterizerState and
;;;; SamplerState, against what the pinned XNA assembly actually does.
;;;;
;;;; These are discriminating tests, not happy-path examples. Every default here
;;;; is one a plausible reconstruction gets wrong: MultiSampleAntiAlias is true,
;;;; MaxAnisotropy is 4, the stencil masks are -1 rather than 0, and the four
;;;; predefined blend states set the alpha pair as well as the colour pair.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

;;; --- the defaults SetDefaults writes ------------------------------------------

(test a-new-blend-state-has-xnas-defaults
  (let ((state (make-instance 'gfx:blend-state)))
    (is (eq :one  (gfx:color-source-blend state)))
    (is (eq :zero (gfx:color-destination-blend state)))
    (is (eq :add  (gfx:color-blend-function state)))
    (is (eq :one  (gfx:alpha-source-blend state)))
    (is (eq :zero (gfx:alpha-destination-blend state)))
    (is (eq :add  (gfx:alpha-blend-function state)))
    (dolist (reader (list #'gfx:color-write-channels #'gfx:color-write-channels-1
                          #'gfx:color-write-channels-2 #'gfx:color-write-channels-3))
      (is (equal '(:all) (funcall reader state))))
    ;; BlendFactor is Color.White, not a transparent or a black default: the IL
    ;; calls Color::get_White and stores the result.
    (is (xna:color-equal (xna:white) (gfx:blend-factor state)))
    ;; -1, the all-ones mask. A reconstruction that reached for 0 or #xFFFFFFFF
    ;; would be wrong in two different ways.
    (is (= -1 (gfx:multi-sample-mask state)))))

(test a-new-depth-stencil-state-has-xnas-defaults
  (let ((state (make-instance 'gfx:depth-stencil-state)))
    (is (eq t (gfx:depth-buffer-enable state)))
    (is (eq t (gfx:depth-buffer-write-enable state)))
    ;; LessEqual, which is 3. Not Less, and not Always.
    (is (eq :less-equal (gfx:depth-buffer-function state)))
    (is (null (gfx:stencil-enable state)))
    (is (eq :always (gfx:stencil-function state)))
    (dolist (reader (list #'gfx:stencil-pass #'gfx:stencil-fail
                          #'gfx:stencil-depth-buffer-fail
                          #'gfx:counter-clockwise-stencil-pass
                          #'gfx:counter-clockwise-stencil-fail
                          #'gfx:counter-clockwise-stencil-depth-buffer-fail))
      (is (eq :keep (funcall reader state))))
    (is (null (gfx:two-sided-stencil-mode state)))
    (is (eq :always (gfx:counter-clockwise-stencil-function state)))
    (is (= -1 (gfx:stencil-mask state)))
    (is (= -1 (gfx:stencil-write-mask state)))
    (is (= 0 (gfx:reference-stencil state)))))

(test a-new-rasterizer-state-antialiases-by-default
  (let ((state (make-instance 'gfx:rasterizer-state)))
    (is (eq :cull-counter-clockwise-face (gfx:cull-mode state)))
    (is (eq :solid (gfx:fill-mode state)))
    (is (null (gfx:scissor-test-enable state)))
    ;; True. This is the default most likely to be reconstructed backwards, and
    ;; RasterizerState::SetDefaults stores ldc.i4.1 into it.
    (is (eq t (gfx:multi-sample-anti-alias state)))
    (is (= 0.0f0 (gfx:depth-bias state)))
    (is (= 0.0f0 (gfx:slope-scale-depth-bias state)))))

(test a-new-sampler-state-has-four-way-anisotropy
  (let ((state (make-instance 'gfx:sampler-state)))
    (is (eq :linear (gfx:filter state)))
    (is (eq :wrap (gfx:address-u state)))
    (is (eq :wrap (gfx:address-v state)))
    (is (eq :wrap (gfx:address-w state)))
    ;; 4. Neither 1 nor 16, both of which a reconstruction might reach for.
    (is (= 4 (gfx:max-anisotropy state)))
    (is (= 0 (gfx:max-mip-level state)))
    (is (= 0.0f0 (gfx:mip-map-level-of-detail-bias state)))))

;;; --- the predefined instances -------------------------------------------------

(test the-predefined-blend-states-set-the-alpha-pair-too
  ;; The private constructor writes its two factors to the colour pair *and* the
  ;; alpha pair. A projection that set only the colour pair would leave the alpha
  ;; pair at One/Zero and be wrong for three of the four.
  (let ((opaque (gfx:blend-state-opaque))
        (alpha (gfx:blend-state-alpha-blend))
        (additive (gfx:blend-state-additive))
        (non-premultiplied (gfx:blend-state-non-premultiplied)))
    (is (eq :one (gfx:color-source-blend opaque)))
    (is (eq :zero (gfx:color-destination-blend opaque)))
    (is (eq :one (gfx:alpha-source-blend opaque)))
    (is (eq :zero (gfx:alpha-destination-blend opaque)))

    (is (eq :one (gfx:color-source-blend alpha)))
    (is (eq :inverse-source-alpha (gfx:color-destination-blend alpha)))
    (is (eq :one (gfx:alpha-source-blend alpha)))
    (is (eq :inverse-source-alpha (gfx:alpha-destination-blend alpha)))

    (is (eq :source-alpha (gfx:color-source-blend additive)))
    (is (eq :one (gfx:color-destination-blend additive)))
    (is (eq :source-alpha (gfx:alpha-source-blend additive)))
    (is (eq :one (gfx:alpha-destination-blend additive)))

    (is (eq :source-alpha (gfx:color-source-blend non-premultiplied)))
    (is (eq :inverse-source-alpha (gfx:color-destination-blend non-premultiplied)))
    (is (eq :source-alpha (gfx:alpha-source-blend non-premultiplied)))
    (is (eq :inverse-source-alpha (gfx:alpha-destination-blend non-premultiplied)))))

(test a-predefined-state-is-the-same-object-every-time
  ;; A `public static initonly' field answers one object. A projection that built
  ;; a fresh instance per call would pass every value test above and still be
  ;; wrong about identity, which is observable.
  (is (eq (gfx:blend-state-opaque) (gfx:blend-state-opaque)))
  (is (eq (gfx:depth-stencil-state-none) (gfx:depth-stencil-state-none)))
  (is (eq (gfx:rasterizer-state-cull-none) (gfx:rasterizer-state-cull-none)))
  (is (eq (gfx:sampler-state-linear-clamp) (gfx:sampler-state-linear-clamp)))
  (is (not (eq (gfx:blend-state-opaque) (gfx:blend-state-additive))))
  (is (not (eq (make-instance 'gfx:blend-state) (gfx:blend-state-opaque)))))

(test the-predefined-depth-and-rasterizer-states-carry-their-one-difference
  (is (null (gfx:depth-buffer-enable (gfx:depth-stencil-state-none))))
  (is (null (gfx:depth-buffer-write-enable (gfx:depth-stencil-state-none))))
  (is (eq t (gfx:depth-buffer-enable (gfx:depth-stencil-state-default))))
  (is (eq t (gfx:depth-buffer-write-enable (gfx:depth-stencil-state-default))))
  (is (eq t (gfx:depth-buffer-enable (gfx:depth-stencil-state-depth-read))))
  (is (null (gfx:depth-buffer-write-enable (gfx:depth-stencil-state-depth-read))))
  ;; Everything else stays at the defaults: DepthRead is not "depth read plus a
  ;; different comparison".
  (is (eq :less-equal (gfx:depth-buffer-function (gfx:depth-stencil-state-depth-read))))
  (is (eq :none (gfx:cull-mode (gfx:rasterizer-state-cull-none))))
  (is (eq :cull-clockwise-face (gfx:cull-mode (gfx:rasterizer-state-cull-clockwise))))
  (is (eq :cull-counter-clockwise-face
          (gfx:cull-mode (gfx:rasterizer-state-cull-counter-clockwise))))
  ;; And CullNone still antialiases, because SetDefaults ran first.
  (is (eq t (gfx:multi-sample-anti-alias (gfx:rasterizer-state-cull-none)))))

(test a-predefined-sampler-writes-one-address-mode-to-all-three-axes
  (let ((clamp (gfx:sampler-state-point-clamp)))
    (is (eq :point (gfx:filter clamp)))
    (is (eq :clamp (gfx:address-u clamp)))
    (is (eq :clamp (gfx:address-v clamp)))
    (is (eq :clamp (gfx:address-w clamp)))
    ;; MaxAnisotropy is still the default 4 even on the anisotropic presets: the
    ;; private constructor sets the filter and the address mode and nothing else.
    (is (= 4 (gfx:max-anisotropy (gfx:sampler-state-anisotropic-wrap))))
    (is (eq :anisotropic (gfx:filter (gfx:sampler-state-anisotropic-wrap))))
    (is (eq :wrap (gfx:address-u (gfx:sampler-state-anisotropic-wrap))))))

;;; --- the read-only latch ------------------------------------------------------

(test a-predefined-state-refuses-every-setter
  ;; XNA's private constructors set isBound, and every setter calls ThrowIfBound.
  (dolist (case (list (list (gfx:blend-state-opaque)
                            (lambda (s) (setf (gfx:color-source-blend s) :zero)))
                      (list (gfx:blend-state-alpha-blend)
                            (lambda (s) (setf (gfx:multi-sample-mask s) 0)))
                      (list (gfx:depth-stencil-state-default)
                            (lambda (s) (setf (gfx:depth-buffer-enable s) nil)))
                      (list (gfx:rasterizer-state-cull-none)
                            (lambda (s) (setf (gfx:fill-mode s) :wire-frame)))
                      (list (gfx:sampler-state-linear-wrap)
                            (lambda (s) (setf (gfx:filter s) :point)))))
    (destructuring-bind (state mutate) case
      (signals xna:cna-invalid-state-error (funcall mutate state)))))

(test the-refusal-names-the-predefined-instance-it-refused
  (handler-case (setf (gfx:color-source-blend (gfx:blend-state-opaque)) :zero)
    (xna:cna-invalid-state-error (condition)
      (let ((text (princ-to-string condition)))
        (is (search "BlendState.Opaque" text)
            "the condition should name the instance; it said: ~a" text)))
    (:no-error (&rest ignored)
      (declare (ignore ignored))
      (fail "mutating BlendState.Opaque was accepted"))))

(test an-unbound-state-accepts-every-setter
  (let ((state (make-instance 'gfx:blend-state)))
    (setf (gfx:color-source-blend state) :source-alpha
          (gfx:color-destination-blend state) :inverse-source-alpha
          (gfx:color-blend-function state) :reverse-subtract
          (gfx:color-write-channels state) '(:red :green)
          (gfx:blend-factor state) (xna:cornflower-blue)
          (gfx:multi-sample-mask state) 7)
    (is (eq :source-alpha (gfx:color-source-blend state)))
    (is (eq :inverse-source-alpha (gfx:color-destination-blend state)))
    (is (eq :reverse-subtract (gfx:color-blend-function state)))
    (is (equal '(:red :green) (gfx:color-write-channels state)))
    (is (xna:color-equal (xna:cornflower-blue) (gfx:blend-factor state)))
    (is (= 7 (gfx:multi-sample-mask state)))))

(test a-setter-refuses-a-value-of-the-wrong-enumeration
  (let ((state (make-instance 'gfx:rasterizer-state)))
    ;; :SOLID is a FillMode, not a CullMode, and the two overlap numerically:
    ;; FillMode.Solid is 0 and CullMode.None is 0. A projection that passed the
    ;; number through would accept this and mean something else.
    (signals type-error (setf (gfx:cull-mode state) :solid))
    (signals type-error (setf (gfx:fill-mode state) :cull-clockwise-face))
    (signals type-error (setf (gfx:depth-bias state) :none))))

(test a-single-property-takes-any-real
  ;; XNA's are System.Single and the CLR converts at the call site, so an integer
  ;; literal is legal there and must be here.
  (let ((state (make-instance 'gfx:rasterizer-state)))
    (setf (gfx:depth-bias state) 1)
    (is (eql 1.0f0 (gfx:depth-bias state)))
    (setf (gfx:slope-scale-depth-bias state) 1/2)
    (is (eql 0.5f0 (gfx:slope-scale-depth-bias state)))))

;;; --- the enumerations ---------------------------------------------------------

(test the-state-enumerations-carry-xnas-values
  (is (= 0 (gfx:blend-value :one)))
  (is (= 1 (gfx:blend-value :zero)))
  (is (= 12 (gfx:blend-value :source-alpha-saturation)))
  (is (= 15 (gfx:color-write-channels-value '(:all))))
  (is (= 3 (gfx:color-write-channels-value '(:red :green))))
  (is (= 3 (gfx:compare-function-value :less-equal)))
  (is (= 7 (gfx:stencil-operation-value :invert)))
  (is (= 2 (gfx:cull-mode-value :cull-counter-clockwise-face)))
  (is (= 1 (gfx:fill-mode-value :wire-frame)))
  (is (= 2 (gfx:texture-address-mode-value :mirror)))
  (is (= 8 (gfx:texture-filter-value :min-point-mag-linear-mip-point))))

(test blend-functions-min-and-max-keep-xnas-numbering
  ;; The one enumeration where the pinned XNA contract and the CNA C ABI
  ;; disagree: XNA numbers Min 3 and Max 4, CNA numbers CNA_BLEND_FUNCTION_MAX 3
  ;; and CNA_BLEND_FUNCTION_MIN 4. The public value is XNA's.
  (is (= 3 (gfx:blend-function-value :min)))
  (is (= 4 (gfx:blend-function-value :max)))
  (is (eq :min (gfx:blend-function-from-value 3)))
  (is (eq :max (gfx:blend-function-from-value 4)))
  ;; And CNA really does number them the other way round, which is what makes the
  ;; translation table necessary rather than decorative.
  (is (= 3 ffi::+blend-function-max+))
  (is (= 4 ffi::+blend-function-min+))
  ;; The table maps by name, so a CNA-Lisp Min reaches CNA's minimum.
  (is (= ffi::+blend-function-min+
         (cdr (assoc :min gfx::%blend-function-to-native))))
  (is (= ffi::+blend-function-max+
         (cdr (assoc :max gfx::%blend-function-to-native)))))

(test every-other-state-enumeration-agrees-with-the-abi
  ;; Stated rather than assumed. If a future CNA renumbers one of these, this is
  ;; where it is noticed instead of in a wrongly rendered frame.
  (dolist (pair (list (cons gfx::%blend-to-native #'gfx:blend-value)
                      (cons gfx::%compare-function-to-native #'gfx:compare-function-value)
                      (cons gfx::%stencil-operation-to-native #'gfx:stencil-operation-value)
                      (cons gfx::%cull-mode-to-native #'gfx:cull-mode-value)
                      (cons gfx::%fill-mode-to-native #'gfx:fill-mode-value)
                      (cons gfx::%texture-address-mode-to-native
                            #'gfx:texture-address-mode-value)
                      (cons gfx::%texture-filter-to-native #'gfx:texture-filter-value)))
    (destructuring-bind (table . xna-value) pair
      (dolist (row table)
        (is (= (funcall xna-value (car row)) (cdr row))
            "~s: XNA ~d, CNA ~d" (car row) (funcall xna-value (car row)) (cdr row))))))

(test the-color-write-channel-bits-agree-with-the-abi
  (is (= 0 ffi::+color-write-none+))
  (is (= 15 ffi::+color-write-all+))
  (is (= 3 (gfx::%native-write-channels '(:red :green))))
  (is (= 0 (gfx::%native-write-channels '())))
  (is (= 15 (gfx::%native-write-channels :all)))
  ;; A bare member is the one-element list it means.
  (is (= 1 (gfx::%native-write-channels :red))))

;;; --- the Begin overload shapes, checked without a native library ---------------
;;;
;;; The public path needs a SpriteBatch and so a CNA library; the shape decision
;;; itself does not, and it is the part that has to be exhaustive. The native
;;; suite exercises the same shapes through the real BEGIN.

(test the-five-begin-shapes-xna-has-are-recognised
  (is (eq :plain (gfx::%check-begin-shape nil nil nil nil nil nil nil)))
  (is (eq :blend (gfx::%check-begin-shape t t nil nil nil nil nil)))
  (is (eq :full (gfx::%check-begin-shape t t t t t nil nil)))
  ;; And the two the Effect closure added.
  (is (eq :effect (gfx::%check-begin-shape t t t t t t nil)))
  (is (eq :transform (gfx::%check-begin-shape t t t t t t t))))

(test the-begin-shapes-xna-does-not-have-are-refused
  ;; A sort mode on its own. XNA's second Begin takes a SpriteSortMode *and* a
  ;; BlendState; there has never been an overload taking only the mode, and
  ;; offering one is the mistake this check exists to stop.
  (signals xna:cna-usage-error (gfx::%check-begin-shape t nil nil nil nil nil nil))
  ;; A state without a sort mode.
  (signals xna:cna-usage-error (gfx::%check-begin-shape nil t nil nil nil nil nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape nil nil t nil nil nil nil))
  ;; Every partial subset of the three trailing states.
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t t nil nil nil nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t nil t nil nil nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t nil nil t nil nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t t t nil nil nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t t nil t nil nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t nil t t nil nil))
  ;; The trailing states without a blend state: the five-parameter overload takes
  ;; all five, so there is no shape that skips the second argument.
  (signals xna:cna-usage-error (gfx::%check-begin-shape t nil t t t nil nil))
  ;; An :EFFECT without the four states, and a :TRANSFORM-MATRIX without an
  ;; :EFFECT, are each no XNA overload.
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t nil nil nil t nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape nil nil nil nil nil t nil))
  (signals xna:cna-usage-error (gfx::%check-begin-shape t t t t t nil t)))

(test the-begin-refusals-say-what-is-wrong
  (handler-case (gfx::%check-begin-shape t nil nil nil nil nil nil)
    (xna:cna-usage-error (condition)
      (is (search "BLEND-STATE" (princ-to-string condition))
          "the refusal should name the missing argument; it said: ~a" condition))))
