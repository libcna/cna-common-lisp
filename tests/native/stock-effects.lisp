;;;; stock-effects.lisp --- AlphaTestEffect, DualTextureEffect, SkinnedEffect.
;;;;
;;;; What these prove and what they do not is the distinction to keep. Every
;;;; assertion below is either
;;;;
;;;;   * a **state round-trip**: the value went to CNA through the route the
;;;;     manifest binds and came back unchanged; or
;;;;   * a **structural** fact: which generic functions have an applicable method
;;;;     for which effect, which is how "implements IEffectLights" is expressed
;;;;     here and therefore has to be checked rather than asserted in prose.
;;;;
;;;; **None of it is evidence about shading.** A setter that round-trips says
;;;; nothing about whether the alpha test discards a fragment, whether two
;;;; texture layers are blended, or whether a bone palette moves a vertex.
;;;; `docs/limitations.md' says so, and `tests/native/rasterization.lisp' is
;;;; where a claim about pixels would have to live.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass stock-effect-game (graphics-game)
  ((effects :initform '() :accessor stock-effects)
   (build-error :initform nil :accessor build-error))
  (:documentation "Creates one of each stock effect during LoadContent."))

(defmethod xna:load-content ((game stock-effect-game))
  (call-next-method)
  (handler-case
      (let ((device (xna:graphics-device game)))
        (setf (stock-effects game)
              (list (make-instance 'gfx:alpha-test-effect :graphics-device device)
                    (make-instance 'gfx:dual-texture-effect :graphics-device device)
                    (make-instance 'gfx:skinned-effect :graphics-device device))))
    (error (condition) (setf (build-error game) condition))))

(defmacro with-stock-effects ((alpha dual skinned &key (game (gensym "GAME"))) &body body)
  "Run a game that makes all three, then assert outside the loop.

Outside, not inside: a FiveAM failure raised in a lifecycle callback would be a
test-framework restart crossing the callback containment layer, which is for
application conditions."
  `(let ((,game (make-instance 'stock-effect-game :exit-after 2)))
     (unwind-protect
          (progn
            (xna:run ,game)
            (when (build-error ,game) (error (build-error ,game)))
            (destructuring-bind (,alpha ,dual ,skinned) (stock-effects ,game)
              (declare (ignorable ,alpha ,dual ,skinned))
              ,@body))
       (progn
         (dolist (effect (stock-effects ,game))
           (ignore-errors (xna:dispose effect)))
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (ignore-errors (xna:dispose ,game))))))

;;; --- each one is a real Effect ------------------------------------------------

(define-native-test each-stock-effect-is-an-effect-with-a-graph
  "Every one is an Effect, is a GraphicsResource, has a handle, and has the
technique/pass graph the base class builds -- which is what makes a primitive
draw legal through any of them."
  (with-stock-effects (alpha dual skinned)
    (dolist (effect (list alpha dual skinned))
      (is (typep effect 'gfx:effect) "~a is not an Effect" (type-of effect))
      (is (typep effect 'gfx:graphics-resource))
      (is (not (xna:disposed-p effect)))
      (let ((technique (gfx:effect-current-technique effect)))
        (is (not (null technique)) "~a has no current technique" (type-of effect))
        (is (plusp (gfx:collection-count (gfx:effect-technique-passes technique)))
            "~a's technique has no pass" (type-of effect))))))

;;; --- the interfaces, as classes ------------------------------------------------

(define-native-test only-the-lighting-effects-answer-the-lighting-members
  "This is the whole point of putting IEffectLights on a mixin. XNA's
AlphaTestEffect and DualTextureEffect implement IEffectFog and IEffectMatrices
and not IEffectLights, so an ambient colour or a directional light is a member
they have not got -- and a generic function specialised on EFFECT would have
answered for them anyway."
  (with-stock-effects (alpha dual skinned)
    ;; The two that do not implement it have no applicable method at all.
    (dolist (effect (list alpha dual))
      (signals error (gfx:effect-ambient-light-color effect))
      (signals error (gfx:directional-light-0 effect))
      (signals error (gfx:enable-default-lighting effect)))
    ;; The one that does, does.
    (is (typep (gfx:effect-ambient-light-color skinned) 'xna:vector3))
    (is (typep (gfx:directional-light-0 skinned) 'gfx:directional-light))
    (finishes (gfx:enable-default-lighting skinned))
    ;; LightingEnabled is BasicEffect's alone among the public contracts: XNA's
    ;; SkinnedEffect implements that member of the interface explicitly.
    (signals error (gfx:effect-lighting-enabled skinned))))

(define-native-test every-stock-effect-answers-the-matrices-and-the-fog
  "IEffectMatrices and IEffectFog, which all three implement, are on EFFECT
itself -- CNA's routes take any effect handle and every stock effect here has
both."
  (with-stock-effects (alpha dual skinned)
    (dolist (effect (list alpha dual skinned))
      (is (typep (gfx:effect-world effect) 'xna:matrix))
      (is (typep (gfx:effect-view effect) 'xna:matrix))
      (is (typep (gfx:effect-projection effect) 'xna:matrix))
      (setf (gfx:effect-fog-enabled effect) t)
      (is (eq t (gfx:effect-fog-enabled effect)))
      (setf (gfx:effect-fog-start effect) 3.5
            (gfx:effect-fog-end effect) 40.25)
      (is (= 3.5f0 (gfx:effect-fog-start effect)))
      (is (= 40.25f0 (gfx:effect-fog-end effect)))
      (setf (gfx:effect-fog-color effect) (xna:make-vector3 0.25 0.5 0.75))
      (is (xna:vector3-equal (xna:make-vector3 0.25 0.5 0.75)
                             (gfx:effect-fog-color effect))))))

;;; --- AlphaTestEffect ------------------------------------------------------------

(define-native-test the-alpha-test-effect-surface-round-trips
  (with-stock-effects (alpha dual skinned)
    (setf (gfx:effect-alpha alpha) 0.25)
    (is (= 0.25f0 (gfx:effect-alpha alpha)))
    (setf (gfx:effect-diffuse-color alpha) (xna:make-vector3 0.1 0.2 0.3))
    (is (xna:vector3-equal (xna:make-vector3 0.1 0.2 0.3)
                           (gfx:effect-diffuse-color alpha)))
    (setf (gfx:effect-vertex-color-enabled alpha) t)
    (is (eq t (gfx:effect-vertex-color-enabled alpha)))
    (setf (gfx:effect-reference-alpha alpha) 128)
    (is (= 128 (gfx:effect-reference-alpha alpha)))))

(define-native-test the-alpha-function-travels-by-name-and-not-by-number
  "CompareFunction is translated through the projected enumeration, which is the
rule every enumeration here follows -- and the rule exists because XNA and CNA
number BlendFunction's Min and Max the other way round from each other. So the
keyword that goes in is the keyword that comes back, whatever the two runtimes'
integers happen to be."
  (with-stock-effects (alpha dual skinned)
    (dolist (function '(:never :less :equal :less-equal :greater :not-equal
                        :greater-equal :always))
      (setf (gfx:effect-alpha-function alpha) function)
      (is (eq function (gfx:effect-alpha-function alpha))
          "AlphaFunction ~s came back as ~s" function
          (gfx:effect-alpha-function alpha)))
    ;; And a value that is not a CompareFunction is refused before CNA sees it.
    (signals error (setf (gfx:effect-alpha-function alpha) :sometimes))))

(define-native-test the-alpha-test-effect-has-no-lighting-or-second-texture
  "The absences are part of the contract and are checked as such."
  (with-stock-effects (alpha dual skinned)
    (signals error (gfx:effect-texture-2 alpha))
    (signals error (gfx:effect-emissive-color alpha))
    (signals error (gfx:effect-specular-color alpha))
    (signals error (gfx:effect-weights-per-vertex alpha))))

;;; --- DualTextureEffect ----------------------------------------------------------

(define-native-test the-dual-texture-effect-surface-round-trips
  (with-stock-effects (alpha dual skinned)
    (setf (gfx:effect-alpha dual) 0.75)
    (is (= 0.75f0 (gfx:effect-alpha dual)))
    (setf (gfx:effect-diffuse-color dual) (xna:make-vector3 0.9 0.8 0.7))
    (is (xna:vector3-equal (xna:make-vector3 0.9 0.8 0.7)
                           (gfx:effect-diffuse-color dual)))
    (setf (gfx:effect-vertex-color-enabled dual) t)
    (is (eq t (gfx:effect-vertex-color-enabled dual)))
    ;; Neither of the two members it has not got.
    (signals error (gfx:effect-reference-alpha dual))
    (signals error (gfx:effect-alpha-function dual))))

(define-native-test the-two-texture-layers-are-independent
  "XNA has two properties; CNA has one route and a layer index. The mapping is
right only if setting one layer leaves the other alone, which is what a single
shared route would get wrong."
  (with-stock-effects (alpha dual skinned :game game)
    (let ((fixture (texture game)))
      (is (null (gfx:effect-texture dual)))
      (is (null (gfx:effect-texture-2 dual)))
      (setf (gfx:effect-texture dual) fixture)
      (is (eq fixture (gfx:effect-texture dual)))
      (is (null (gfx:effect-texture-2 dual))
          "setting layer zero must not have filled layer one")
      (setf (gfx:effect-texture-2 dual) fixture)
      (is (eq fixture (gfx:effect-texture-2 dual)))
      (is (eq fixture (gfx:effect-texture dual))
          "setting layer one must not have disturbed layer zero")
      ;; NIL clears one layer and not the other.
      (setf (gfx:effect-texture dual) nil)
      (is (null (gfx:effect-texture dual)))
      (is (eq fixture (gfx:effect-texture-2 dual))))))

;;; --- SkinnedEffect ---------------------------------------------------------------

(define-native-test the-skinned-effect-material-surface-round-trips
  (with-stock-effects (alpha dual skinned)
    (setf (gfx:effect-alpha skinned) 0.5)
    (is (= 0.5f0 (gfx:effect-alpha skinned)))
    (setf (gfx:effect-specular-power skinned) 12.5)
    (is (= 12.5f0 (gfx:effect-specular-power skinned)))
    (dolist (pair (list (list #'gfx:effect-diffuse-color
                              #'(setf gfx:effect-diffuse-color)
                              (xna:make-vector3 0.1 0.2 0.3))
                        (list #'gfx:effect-emissive-color
                              #'(setf gfx:effect-emissive-color)
                              (xna:make-vector3 0.4 0.5 0.6))
                        (list #'gfx:effect-specular-color
                              #'(setf gfx:effect-specular-color)
                              (xna:make-vector3 0.7 0.8 0.9))))
      (destructuring-bind (reader writer value) pair
        (funcall writer value skinned)
        (is (xna:vector3-equal value (funcall reader skinned)))))
    (setf (gfx:effect-prefer-per-pixel-lighting skinned) t)
    (is (eq t (gfx:effect-prefer-per-pixel-lighting skinned)))
    (setf (gfx:effect-vertex-color-enabled skinned) t)
    (is (eq t (gfx:effect-vertex-color-enabled skinned)))))

(define-native-test weights-per-vertex-takes-one-two-or-four
  (with-stock-effects (alpha dual skinned)
    (dolist (weights '(1 2 4))
      (setf (gfx:effect-weights-per-vertex skinned) weights)
      (is (= weights (gfx:effect-weights-per-vertex skinned))))
    ;; CNA documents one, two or four; three is not one of them.
    (signals xna:cna-error (setf (gfx:effect-weights-per-vertex skinned) 3))))

(define-native-test the-bone-palette-round-trips-and-is-copied
  "SetBoneTransforms copies -- CNA reads the array during the call -- so mutating
the caller's matrices afterwards must not change what the effect holds, and
GetBoneTransforms answers a fresh vector for the same reason."
  (with-stock-effects (alpha dual skinned)
    (let ((palette (vector (xna:matrix-create-translation 1.0 0.0 0.0)
                           (xna:matrix-create-translation 0.0 2.0 0.0)
                           (xna:matrix-create-translation 0.0 0.0 3.0))))
      (gfx:set-bone-transforms skinned palette)
      (let ((back (gfx:get-bone-transforms skinned 3)))
        (is (= 3 (length back)))
        (is (= 1.0f0 (xna:matrix-m41 (aref back 0))))
        (is (= 2.0f0 (xna:matrix-m42 (aref back 1))))
        (is (= 3.0f0 (xna:matrix-m43 (aref back 2))))
        ;; A fresh vector: writing into it changes nothing.
        (setf (aref back 0) (xna:matrix-identity))
        (is (= 1.0f0 (xna:matrix-m41 (aref (gfx:get-bone-transforms skinned 3) 0)))))
      ;; Copied on the way in: mutating the caller's matrix afterwards is invisible.
      (setf (xna:matrix-m41 (aref palette 0)) 99.0)
      (is (= 1.0f0 (xna:matrix-m41 (aref (gfx:get-bone-transforms skinned 1) 0)))))))

(define-native-test the-bone-palette-refuses-a-count-it-cannot-hold
  (with-stock-effects (alpha dual skinned)
    (is (= 72 gfx:+skinned-effect-max-bones+)
        "the CNA header and XNA's public MaxBones should agree")
    (signals xna:cna-argument-out-of-range-error
      (gfx:set-bone-transforms skinned #()))
    (signals xna:cna-argument-out-of-range-error
      (gfx:set-bone-transforms
       skinned (make-array (1+ gfx:+skinned-effect-max-bones+)
                           :initial-element (xna:matrix-identity))))
    (signals xna:cna-argument-out-of-range-error (gfx:get-bone-transforms skinned 0))
    (signals xna:cna-argument-out-of-range-error
      (gfx:get-bone-transforms skinned (1+ gfx:+skinned-effect-max-bones+)))
    ;; The full palette is accepted at both ends of the range.
    (finishes (gfx:set-bone-transforms
               skinned (make-array gfx:+skinned-effect-max-bones+
                                   :initial-element (xna:matrix-identity))))
    (is (= gfx:+skinned-effect-max-bones+
           (length (gfx:get-bone-transforms skinned gfx:+skinned-effect-max-bones+))))))

;;; --- cloning and disposal ---------------------------------------------------------

(define-native-test cloning-a-stock-effect-keeps-its-concrete-type
  "Effect.Clone answers the same runtime type, and the clone is independent."
  (with-stock-effects (alpha dual skinned)
    (dolist (effect (list alpha dual skinned))
      (let ((clone (gfx:clone-effect effect)))
        (unwind-protect
             (progn
               (is (eq (class-of effect) (class-of clone))
                   "cloning a ~a answered a ~a" (type-of effect) (type-of clone))
               (is (not (eq effect clone)))
               (setf (gfx:effect-alpha effect) 0.125
                     (gfx:effect-alpha clone) 0.875)
               (is (= 0.125f0 (gfx:effect-alpha effect)))
               (is (= 0.875f0 (gfx:effect-alpha clone))))
          (ignore-errors (xna:dispose clone)))))))

(define-native-test disposing-a-stock-effect-releases-its-whole-graph
  "The same ledger BasicEffect uses: every view handle recorded at acquisition and
given back newest-first. A stock effect that built its own cleanup would show up
as a game that will not shut down, nowhere near the effect that leaked."
  (with-stock-effects (alpha dual skinned)
    (dolist (effect (list alpha dual skinned))
      (let ((technique (gfx:effect-current-technique effect)))
        (xna:dispose effect)
        (is (xna:disposed-p effect))
        (is (gfx:graphics-resource-is-disposed effect))
        (xna:dispose effect)                ; idempotent, as IDisposable is
        (signals xna:cna-error (gfx:effect-alpha effect))
        ;; The views went with it, so using one refuses rather than reaching a
        ;; handle CNA may since have reissued. A technique's *name* would not
        ;; refuse: it is cached at construction, because XNA's is a field of an
        ;; object made then and crossing the ABI for a string that cannot change
        ;; would buy nothing.
        (signals xna:cna-error
          (gfx:apply-effect-pass
           (gfx:collection-item (gfx:effect-technique-passes technique) 0)))))))
