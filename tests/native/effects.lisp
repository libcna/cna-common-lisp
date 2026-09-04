;;;; effects.lisp --- Effect, BasicEffect and the object graph, against real CNA.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defmacro with-effect-game ((game effect) &body body)
  "One BasicEffect, made inside DRAW where the device is lent, disposed after."
  `(with-buffer-game (,game)
     (let ((,effect (keep ,game (make-instance 'gfx:basic-effect
                                               :graphics-device
                                               (xna:graphics-device ,game)))))
       ,@body)))

;;; --- construction and the graph ----------------------------------------------------

(define-native-test a-basic-effect-is-a-graphics-resource-with-a-handle
  (with-effect-game (game effect)
    (is (typep effect 'gfx:graphics-resource))
    (is (typep effect 'gfx:effect))
    (is (null (gfx:graphics-resource-is-disposed effect)))
    (setf (gfx:graphics-resource-name effect) "the stock effect")
    (is (equal "the stock effect" (gfx:graphics-resource-name effect)))
    (is (eq (xna:graphics-device game) (gfx:graphics-resource-graphics-device effect)))))

(define-native-test a-basic-effect-has-a-technique-with-at-least-one-pass
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((techniques (gfx:effect-techniques effect)))
      (is (plusp (gfx:collection-count techniques))
          "a stock effect with no technique could never be drawn with")
      (let ((technique (gfx:effect-current-technique effect)))
        (is (typep technique 'gfx:effect-technique))
        (is (stringp (gfx:effect-technique-name technique)))
        (is (plusp (length (gfx:effect-technique-name technique))))
        (is (plusp (gfx:collection-count (gfx:effect-technique-passes technique))))
        (is (typep (gfx:collection-item (gfx:effect-technique-passes technique) 0)
                   'gfx:effect-pass))))))

(define-native-test the-current-technique-is-the-same-object-every-time
  ;; The whole reason the graph is built eagerly: CNA answers a *fresh handle*
  ;; for each get_current_technique, and XNA guarantees reference identity.
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((first (gfx:effect-current-technique effect))
          (second (gfx:effect-current-technique effect)))
      (is (eq first second)
          "CurrentTechnique answered two different objects for one technique")
      (is (eq first (gfx:collection-item (gfx:effect-techniques effect) 0))
          "the current technique must be one of the effect's own"))))

(define-native-test an-effect-collection-answers-by-index-and-by-name
  (with-effect-game (game effect)
    (declare (ignore game))
    (let* ((techniques (gfx:effect-techniques effect))
           (technique (gfx:collection-item techniques 0))
           (name (gfx:effect-technique-name technique)))
      (is (eq technique (gfx:collection-item techniques name)))
      (is (equal (list technique)
                 (subseq (gfx:collection-elements techniques) 0 1))))))

(define-native-test an-effect-collection-answers-nil-rather-than-signalling
  ;; From the pinned IL: get_Item(int32) branches on a negative index and on one
  ;; that is not below Count straight to `ldnull; ret'. It is not an exception in
  ;; XNA and it is not a condition here.
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((techniques (gfx:effect-techniques effect)))
      (is (null (gfx:collection-item techniques -1)))
      (is (null (gfx:collection-item techniques (gfx:collection-count techniques))))
      (is (null (gfx:collection-item techniques 1000)))
      (is (null (gfx:collection-item techniques "no technique is called this"))))))

(define-native-test a-stock-effect-exposes-no-parameters
  ;; Recorded rather than worked around: CNA's stock effects carry no reflected
  ;; parameter graph. The collection is real and empty. If a future CNA reflects
  ;; BasicEffect's parameters this fails, and that is the point of the test --
  ;; docs/limitations.md says the answer is always zero today.
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((parameters (gfx:effect-parameters effect)))
      (is (typep parameters 'gfx:effect-parameter-collection))
      (is (= 0 (gfx:collection-count parameters))
          "CNA now reflects stock effect parameters; docs/limitations.md is stale")
      (is (null (gfx:collection-elements parameters)))
      (is (null (gfx:collection-parameter-by-semantic parameters "WORLD"))))))

;;; --- CurrentTechnique's setter, from the IL ----------------------------------------

(define-native-test setting-the-current-technique-refuses-nil
  (with-effect-game (game effect)
    (declare (ignore game))
    (signals xna:cna-argument-out-of-range-error
      (setf (gfx:effect-current-technique effect) nil))))

(define-native-test setting-the-current-technique-refuses-another-effects
  ;; XNA compares the technique's parent with the effect and throws
  ;; InvalidOperationException when they differ.
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (one (keep game (make-instance 'gfx:basic-effect :graphics-device device)))
           (two (keep game (make-instance 'gfx:basic-effect :graphics-device device))))
      (handler-case
          (progn (setf (gfx:effect-current-technique one)
                       (gfx:effect-current-technique two))
                 (fail "a technique from another effect was accepted"))
        (xna:cna-usage-error (condition)
          (is (search "different Effect" (princ-to-string condition))))))))

(define-native-test setting-the-current-technique-to-what-it-already-is-does-nothing
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((current (gfx:effect-current-technique effect)))
      (setf (gfx:effect-current-technique effect) current)
      (is (eq current (gfx:effect-current-technique effect))))))

;;; --- the compiled-effect constructor ------------------------------------------------

(define-native-test an-effect-refuses-empty-compiled-code-before-anything-else
  ;; The IL checks effectCode before graphicsDevice, and answers
  ;; ArgumentNullException for an *empty* array as well as a missing one.
  (with-buffer-game (game)
    (declare (ignore game))
    (signals xna:cna-argument-out-of-range-error
      (make-instance 'gfx:effect :graphics-device nil :effect-code #()))
    (signals xna:cna-argument-out-of-range-error
      (make-instance 'gfx:effect :graphics-device nil :effect-code nil))))

(define-native-test an-effect-refuses-code-that-is-not-a-multiple-of-four
  (with-buffer-game (game)
    (handler-case
        (progn (make-instance 'gfx:effect
                              :graphics-device (xna:graphics-device game)
                              :effect-code (make-array 6 :element-type '(unsigned-byte 8)
                                                         :initial-element 0))
               (fail "a six-byte effect payload was accepted"))
      (xna:cna-argument-out-of-range-error (condition)
        (is (search "multiple of four" (princ-to-string condition)))))))

(define-native-test compiled-effects-are-a-renderer-capability-and-say-so
  ;; Neither qualification renderer has CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS.
  ;; CNA refuses well-formed-length bytes that are not a real Effect Framework
  ;; binary; either refusal is honest, and a *success* here would mean CNA had
  ;; silently substituted something.
  (with-buffer-game (game)
    (signals xna:cna-error
      (make-instance 'gfx:effect
                     :graphics-device (xna:graphics-device game)
                     :effect-code (make-array 64 :element-type '(unsigned-byte 8)
                                                 :initial-element 7)))))

;;; --- IEffectMatrices, IEffectFog, IEffectLights -------------------------------------

(define-native-test the-effect-matrices-start-as-identity
  (with-effect-game (game effect)
    (declare (ignore game))
    (dolist (reader (list #'gfx:effect-world #'gfx:effect-view #'gfx:effect-projection))
      (is (xna:matrix-equal (xna:matrix-identity) (funcall reader effect))))))

(define-native-test the-matrix-setters-need-the-shim-and-say-which
  ;; CNA_Matrix is 64 bytes: MEMORY class, so the setter is the shim's. Both
  ;; outcomes are asserted, because the suite runs with and without the shim.
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((wanted (xna:make-matrix 2.0 0.0 0.0 0.0
                                   0.0 3.0 0.0 0.0
                                   0.0 0.0 4.0 0.0
                                   5.0 6.0 7.0 1.0)))
      (handler-case
          (progn
            (setf (gfx:effect-world effect) wanted)
            (is (xna:matrix-equal wanted (gfx:effect-world effect))
                "the shim wrote a matrix that did not come back")
            (setf (gfx:effect-view effect) wanted)
            (is (xna:matrix-equal wanted (gfx:effect-view effect)))
            (setf (gfx:effect-projection effect) wanted)
            (is (xna:matrix-equal wanted (gfx:effect-projection effect))))
        (xna:cna-not-supported-error (condition)
          (is (search "shim" (princ-to-string condition))
              "the refusal must say what to build")
          (is (search "CNA_LISP_SHIM" (princ-to-string condition))))))))

(define-native-test the-effect-fog-surface-round-trips
  (with-effect-game (game effect)
    (declare (ignore game))
    (setf (gfx:effect-fog-enabled effect) t)
    (is (eq t (gfx:effect-fog-enabled effect)))
    (setf (gfx:effect-fog-start effect) 12.5)
    (is (= 12.5 (gfx:effect-fog-start effect)))
    (setf (gfx:effect-fog-end effect) 400.0)
    (is (= 400.0 (gfx:effect-fog-end effect)))
    ;; A Vector3 by value, through the SSE flattening. Z is the field a wrong
    ;; flattening would corrupt while leaving X and Y right.
    (setf (gfx:effect-fog-color effect) (v3 0.25 0.5 0.75))
    (let ((back (gfx:effect-fog-color effect)))
      (is (= 0.25f0 (xna:vector3-x back)))
      (is (= 0.5f0 (xna:vector3-y back)))
      (is (= 0.75f0 (xna:vector3-z back))
          "Z came back wrong: the trailing SSE eightbyte is not being passed right"))
    (setf (gfx:effect-fog-enabled effect) nil)
    (is (null (gfx:effect-fog-enabled effect)))))

(define-native-test the-effect-light-surface-round-trips
  (with-effect-game (game effect)
    (declare (ignore game))
    (setf (gfx:effect-lighting-enabled effect) t)
    (is (eq t (gfx:effect-lighting-enabled effect)))
    (setf (gfx:effect-ambient-light-color effect) (v3 0.1 0.2 0.3))
    (let ((back (gfx:effect-ambient-light-color effect)))
      (is (= 0.1f0 (xna:vector3-x back)))
      (is (= 0.2f0 (xna:vector3-y back)))
      (is (= 0.3f0 (xna:vector3-z back))))
    (gfx:enable-default-lighting effect)
    (is (eq t (gfx:effect-lighting-enabled effect))
        "EnableDefaultLighting must leave lighting on")))

(define-native-test the-three-directional-lights-are-stable-and-independent
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((zero (gfx:directional-light-0 effect))
          (one (gfx:directional-light-1 effect))
          (two (gfx:directional-light-2 effect)))
      (is (eq zero (gfx:directional-light-0 effect))
          "DirectionalLight0 must answer the same object every time")
      (is (not (eq zero one)))
      (is (not (eq one two)))
      (setf (gfx:directional-light-enabled zero) t
            (gfx:directional-light-enabled one) nil)
      (is (eq t (gfx:directional-light-enabled zero)))
      (is (null (gfx:directional-light-enabled one)))
      (setf (gfx:directional-light-direction zero) (v3 0.0 -1.0 0.0)
            (gfx:directional-light-diffuse-color zero) (v3 1.0 0.5 0.25)
            (gfx:directional-light-specular-color zero) (v3 0.125 0.0 1.0))
      (let ((direction (gfx:directional-light-direction zero))
            (diffuse (gfx:directional-light-diffuse-color zero))
            (specular (gfx:directional-light-specular-color zero)))
        (is (= -1.0f0 (xna:vector3-y direction)))
        (is (= 0.25f0 (xna:vector3-z diffuse)))
        (is (= 1.0f0 (xna:vector3-z specular))))
      ;; Light 1's colour must not have moved when light 0's did.
      (setf (gfx:directional-light-diffuse-color one) (v3 0.0 0.0 0.0))
      (is (= 0.25f0 (xna:vector3-z (gfx:directional-light-diffuse-color zero)))))))

;;; --- BasicEffect's own --------------------------------------------------------------

(define-native-test the-basic-effect-material-surface-round-trips
  (with-effect-game (game effect)
    (declare (ignore game))
    (setf (gfx:effect-alpha effect) 0.5)
    (is (= 0.5f0 (gfx:effect-alpha effect)))
    (setf (gfx:effect-specular-power effect) 24.0)
    (is (= 24.0f0 (gfx:effect-specular-power effect)))
    (setf (gfx:effect-diffuse-color effect) (v3 1.0 0.0 0.5))
    (is (= 0.5f0 (xna:vector3-z (gfx:effect-diffuse-color effect))))
    (setf (gfx:effect-emissive-color effect) (v3 0.0 0.25 0.0))
    (is (= 0.25f0 (xna:vector3-y (gfx:effect-emissive-color effect))))
    (setf (gfx:effect-specular-color effect) (v3 0.75 0.75 0.75))
    (is (= 0.75f0 (xna:vector3-x (gfx:effect-specular-color effect))))
    (setf (gfx:effect-vertex-color-enabled effect) t)
    (is (eq t (gfx:effect-vertex-color-enabled effect)))
    (setf (gfx:effect-prefer-per-pixel-lighting effect) t)
    (is (eq t (gfx:effect-prefer-per-pixel-lighting effect)))
    (setf (gfx:effect-texture-enabled effect) nil)
    (is (null (gfx:effect-texture-enabled effect)))))

(define-native-test the-basic-effect-texture-answers-the-object-it-was-given
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (effect (keep game (make-instance 'gfx:basic-effect :graphics-device device)))
           (texture (keep game (gfx:texture-2d-from-png-file
                                device (fixture-path "solid-magenta-8.png")))))
      (is (null (gfx:effect-texture effect)))
      (setf (gfx:effect-texture effect) texture)
      (is (eq texture (gfx:effect-texture effect))
          "the effect must answer the Texture2D object, not one it invented")
      (setf (gfx:effect-texture effect) nil)
      (is (null (gfx:effect-texture effect))))))

(define-native-test cloning-an-effect-gives-an-independent-one
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (effect (keep game (make-instance 'gfx:basic-effect :graphics-device device))))
      (setf (gfx:effect-alpha effect) 0.25)
      (let ((clone (keep game (gfx:clone-effect effect))))
        (is (typep clone 'gfx:basic-effect) "a clone keeps its concrete type")
        (is (not (eq clone effect)))
        (is (= 0.25f0 (gfx:effect-alpha clone)) "a clone carries the source's state")
        (setf (gfx:effect-alpha clone) 1.0)
        (is (= 0.25f0 (gfx:effect-alpha effect))
            "changing the clone changed the original: it is not independent")
        ;; The clone has its own graph, with its own technique objects.
        (is (not (eq (gfx:effect-current-technique clone)
                     (gfx:effect-current-technique effect))))))))

;;; --- disposal ------------------------------------------------------------------------

(define-native-test disposing-an-effect-releases-its-whole-graph
  ;; The failure this guards against is not visible here: a view handle left
  ;; alive makes *game destruction* fail, later, far from the effect. So the
  ;; fixture's own teardown is the assertion -- WITH-BUFFER-GAME disposes the
  ;; game, and CNA refuses that while any child handle is alive.
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (effect (make-instance 'gfx:basic-effect :graphics-device device))
           (technique (gfx:effect-current-technique effect)))
      (xna:dispose effect)
      (is (gfx:graphics-resource-is-disposed effect))
      (xna:dispose effect)                  ; idempotent, as IDisposable is
      (signals xna:cna-error (gfx:effect-alpha effect))
      ;; A view of a disposed effect refuses rather than calling through a handle
      ;; CNA may since have reissued.
      (signals xna:cna-error (gfx:apply-effect-pass
                              (gfx:collection-item
                               (gfx:effect-technique-passes technique) 0))))))

(define-native-test an-effect-view-is-not-disposable
  (with-effect-game (game effect)
    (declare (ignore game))
    (let ((technique (gfx:effect-current-technique effect)))
      (handler-case
          (progn (xna:dispose technique) (fail "a technique accepted DISPOSE"))
        (xna:cna-usage-error (condition)
          (is (search "not disposable" (princ-to-string condition)))
          (is (search "Dispose the Effect" (princ-to-string condition))))))))

;;; --- drawing -------------------------------------------------------------------------
;;;
;;; These assert *outside* the game, on an outcome the body recorded. A FiveAM
;;; check that fails inside a lifecycle callback has no restart to report itself
;;; through -- the callback machinery contains conditions on purpose, so they
;;; cannot unwind through C -- and the failure comes out as a type error about a
;;; missing restart rather than as the assertion that failed.

(defun draw-outcome (thunk)
  "Run THUNK and answer :ACCEPTED, or the text of the condition that refused it."
  (handler-case (progn (funcall thunk) :accepted)
    (error (condition) (princ-to-string condition))))

(define-native-test applying-a-pass-makes-a-primitive-draw-legal
  ;; This is what A-PRIMITIVE-DRAW-NEEDS-AN-EFFECT-AND-SAYS-SO was standing in
  ;; for. Without an applied pass CNA refuses for want of an effect; with one it
  ;; accepts, on both qualification renderers.
  (let ((outcome nil))
    (with-effect-game (game effect)
      (let ((device (xna:graphics-device game))
            (vertices (triangle-vertices)))
        (setf (gfx:effect-vertex-color-enabled effect) t
              (gfx:effect-lighting-enabled effect) nil)
        (dolist (pass (gfx:collection-elements
                       (gfx:effect-technique-passes
                        (gfx:effect-current-technique effect))))
          (gfx:apply-effect-pass pass))
        (setf outcome
              (draw-outcome
               (lambda ()
                 (gfx:draw-user-primitives device :triangle-list vertices
                                           :primitive-count 1))))))
    (is (eq :accepted outcome)
        "a draw with an applied effect pass was refused: ~a" outcome)))

(define-native-test a-buffered-primitive-draw-is-legal-once-a-pass-is-applied
  (let ((outcome nil))
    (with-effect-game (game effect)
      (let* ((device (xna:graphics-device game))
             (buffer (keep game (make-instance 'gfx:vertex-buffer
                                               :graphics-device device
                                               :vertex-type 'gfx:vertex-position-color
                                               :vertex-count 3))))
        (gfx:set-data buffer (triangle-vertices))
        (gfx:set-vertex-buffer device buffer)
        (setf (gfx:effect-vertex-color-enabled effect) t
              (gfx:effect-lighting-enabled effect) nil)
        (dolist (pass (gfx:collection-elements
                       (gfx:effect-technique-passes
                        (gfx:effect-current-technique effect))))
          (gfx:apply-effect-pass pass))
        (setf outcome
              (draw-outcome
               (lambda ()
                 (gfx:draw-primitives device :triangle-list 0 1))))
        (gfx:set-vertex-buffer device nil)))
    (is (eq :accepted outcome)
        "a buffered draw with an applied effect pass was refused: ~a" outcome)))
