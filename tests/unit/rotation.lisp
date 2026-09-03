;;;; rotation.lisp --- Quaternion, Matrix, and transforming vectors by them.
;;;;
;;;; Two kinds of test here. The identities -- a rotation matrix is orthogonal,
;;;; an inverse times its matrix is the identity -- catch a wrong formula. The
;;;; convention tests -- which row holds the translation, which way Z points,
;;;; which operand of Multiply is applied first -- catch the far more common
;;;; failure, where every formula is right and the whole thing is transposed.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defun ~= (a b &optional (tolerance 1.0e-5))
  "True when two binary32 values agree to TOLERANCE.

Used only where a test composes several operations and the accumulated rounding
is the point of neither. Exact equality is asserted wherever it can be."
  (< (abs (- a b)) tolerance))

(defun matrix~= (a b &optional (tolerance 1.0e-5))
  (loop for reader in (list #'xna:matrix-m11 #'xna:matrix-m12 #'xna:matrix-m13
                            #'xna:matrix-m14 #'xna:matrix-m21 #'xna:matrix-m22
                            #'xna:matrix-m23 #'xna:matrix-m24 #'xna:matrix-m31
                            #'xna:matrix-m32 #'xna:matrix-m33 #'xna:matrix-m34
                            #'xna:matrix-m41 #'xna:matrix-m42 #'xna:matrix-m43
                            #'xna:matrix-m44)
        always (~= (funcall reader a) (funcall reader b) tolerance)))

(defun vector3~= (a b &optional (tolerance 1.0e-5))
  (and (~= (xna:vector3-x a) (xna:vector3-x b) tolerance)
       (~= (xna:vector3-y a) (xna:vector3-y b) tolerance)
       (~= (xna:vector3-z a) (xna:vector3-z b) tolerance)))

;;; --- Quaternion -------------------------------------------------------------

(test quaternion-identity-is-a-fresh-unit-rotation
  (let ((q (xna:quaternion-identity)))
    (is (= 0.0f0 (xna:quaternion-x q)))
    (is (= 1.0f0 (xna:quaternion-w q)))
    (setf (xna:quaternion-w q) 0.0f0)
    (is (= 1.0f0 (xna:quaternion-w (xna:quaternion-identity))))))

(test quaternion-multiplication-is-not-commutative
  (let ((a (xna:quaternion-create-from-axis-angle (xna:vector3-unit-x) 0.5))
        (b (xna:quaternion-create-from-axis-angle (xna:vector3-unit-y) 0.7)))
    (is (not (xna:quaternion-equal (xna:quaternion-multiply a b)
                                   (xna:quaternion-multiply b a))))))

(test quaternion-concatenate-is-multiply-with-the-operands-reversed
  ;; The framework's Concatenate reads its second argument into the slots
  ;; Multiply reads its first from. A binding that assumes the obvious order
  ;; composes rotations backwards, and every individual formula still looks right.
  (let ((a (xna:quaternion-create-from-axis-angle (xna:vector3-unit-x) 0.5))
        (b (xna:quaternion-create-from-axis-angle (xna:vector3-unit-y) 0.7)))
    (is (xna:quaternion-equal (xna:quaternion-concatenate a b)
                              (xna:quaternion-multiply b a)))))

(test quaternion-times-its-inverse-is-the-identity
  (let* ((q (xna:quaternion-normalized
             (xna:make-quaternion 0.3 0.5 0.2 0.8)))
         (p (xna:quaternion-multiply q (xna:quaternion-inverse q))))
    (is (~= 1.0f0 (xna:quaternion-w p)))
    (is (~= 0.0f0 (xna:quaternion-x p)))
    (is (~= 0.0f0 (xna:quaternion-y p)))
    (is (~= 0.0f0 (xna:quaternion-z p)))))

(test quaternion-inverse-takes-no-square-root
  ;; Inverse divides by the *squared* length. For a unit quaternion the two agree,
  ;; so the test uses one that is deliberately not unit.
  (let* ((q (xna:make-quaternion 0.0 0.0 0.0 2.0))
         (inverse (xna:quaternion-inverse q)))
    ;; The squared length is 4, so the scale is 1/4 and W becomes 2 * 1/4.
    ;; Dividing by the length instead would answer 1.0.
    (is (= 0.5f0 (xna:quaternion-w inverse)))))

(test quaternion-conjugate-mutates-and-conjugated-does-not
  (let ((q (xna:make-quaternion 1 2 3 4)))
    (xna:quaternion-conjugate q)
    (is (= -1.0f0 (xna:quaternion-x q)))
    (is (= 4.0f0 (xna:quaternion-w q))))
  (let* ((q (xna:make-quaternion 1 2 3 4))
         (c (xna:quaternion-conjugated q)))
    (is (= 1.0f0 (xna:quaternion-x q)))
    (is (= -1.0f0 (xna:quaternion-x c)))))

(test quaternion-from-axis-angle-is-a-unit-rotation
  (let ((q (xna:quaternion-create-from-axis-angle (xna:vector3-unit-y)
                                                  xna:+math-helper-pi-over2+)))
    (is (~= 1.0f0 (xna:quaternion-length q)))
    (is (~= (/ (sqrt 2.0f0) 2.0f0) (xna:quaternion-y q)))
    (is (~= (/ (sqrt 2.0f0) 2.0f0) (xna:quaternion-w q)))))

(test quaternion-round-trips-through-a-rotation-matrix
  (dolist (axis (list (xna:vector3-unit-x) (xna:vector3-unit-y) (xna:vector3-unit-z)
                      (xna:vector3-normalized (xna:make-vector3 1 2 3))))
    (dolist (angle '(0.3 1.1 2.4 -0.7))
      (let* ((q (xna:quaternion-create-from-axis-angle axis angle))
             (m (xna:matrix-create-from-quaternion q))
             (back (xna:quaternion-create-from-rotation-matrix m)))
        ;; q and -q are the same rotation, so the sign is not part of the claim.
        (is (or (and (~= (xna:quaternion-x q) (xna:quaternion-x back) 1.0e-4)
                     (~= (xna:quaternion-w q) (xna:quaternion-w back) 1.0e-4))
                (and (~= (xna:quaternion-x q) (- (xna:quaternion-x back)) 1.0e-4)
                     (~= (xna:quaternion-w q) (- (xna:quaternion-w back)) 1.0e-4)))
            "axis ~a angle ~a did not round trip" axis angle)))))

(test quaternion-slerp-endpoints-and-midpoint
  (let* ((a (xna:quaternion-identity))
         (b (xna:quaternion-create-from-axis-angle (xna:vector3-unit-z)
                                                   xna:+math-helper-pi-over2+)))
    (is (~= 1.0f0 (xna:quaternion-w (xna:quaternion-slerp a b 0.0))))
    (is (~= (xna:quaternion-w b) (xna:quaternion-w (xna:quaternion-slerp a b 1.0))))
    ;; Halfway along the arc is the quarter turn's half: a rotation of pi/4.
    (let ((half (xna:quaternion-slerp a b 0.5)))
      (is (~= (cos (/ xna:+math-helper-pi-over4+ 2.0f0)) (xna:quaternion-w half) 1.0e-4)))))

(test quaternion-slerp-takes-the-short-way-round
  ;; With a negative dot product the framework flips the second quaternion, so
  ;; the interpolation crosses the shorter arc.
  (let* ((a (xna:quaternion-identity))
         (b (xna:quaternion-negate (xna:quaternion-identity)))
         (mid (xna:quaternion-slerp a b 0.5)))
    (is (~= 1.0f0 (abs (xna:quaternion-w mid))))))

(test quaternion-lerp-normalises-in-both-branches
  (let* ((a (xna:quaternion-identity))
         (b (xna:quaternion-create-from-axis-angle (xna:vector3-unit-z) 1.0)))
    (is (~= 1.0f0 (xna:quaternion-length (xna:quaternion-lerp a b 0.5))))
    (is (~= 1.0f0 (xna:quaternion-length
                   (xna:quaternion-lerp a (xna:quaternion-negate b) 0.5))))))

;;; --- Matrix -----------------------------------------------------------------

(test matrix-identity-is-a-fresh-value
  (let ((m (xna:matrix-identity)))
    (setf (xna:matrix-m11 m) 0.0f0)
    (is (= 1.0f0 (xna:matrix-m11 (xna:matrix-identity))))))

(test matrix-translation-lives-in-the-fourth-row
  ;; Row-vector convention. If the translation were in the fourth *column* every
  ;; formula in this file would still look right and nothing would draw.
  (let ((m (xna:matrix-create-translation (xna:make-vector3 1 2 3))))
    (is (= 1.0f0 (xna:matrix-m41 m)))
    (is (= 2.0f0 (xna:matrix-m42 m)))
    (is (= 3.0f0 (xna:matrix-m43 m)))
    (is (= 0.0f0 (xna:matrix-m14 m)))))

(test matrix-translation-accessor-round-trips
  (let ((m (xna:matrix-identity)))
    (setf (xna:matrix-translation m) (xna:make-vector3 4 5 6))
    (is (xna:vector3-equal (xna:matrix-translation m) (xna:make-vector3 4 5 6)))
    (is (= 4.0f0 (xna:matrix-m41 m)))))

(test matrix-forward-is-the-negated-third-row
  (let ((m (xna:matrix-identity)))
    (is (xna:vector3-equal (xna:matrix-backward m) (xna:make-vector3 0 0 1)))
    (is (xna:vector3-equal (xna:matrix-forward m) (xna:make-vector3 0 0 -1)))
    (is (xna:vector3-equal (xna:matrix-up m) (xna:make-vector3 0 1 0)))
    (is (xna:vector3-equal (xna:matrix-left m) (xna:make-vector3 -1 0 0)))))

(test matrix-create-scale-has-three-shapes
  (is (matrix~= (xna:matrix-create-scale 2)
                (xna:matrix-create-scale 2 2 2)))
  (is (matrix~= (xna:matrix-create-scale (xna:make-vector3 2 3 4))
                (xna:matrix-create-scale 2 3 4)))
  (is (= 3.0f0 (xna:matrix-m22 (xna:matrix-create-scale 2 3 4)))))

(test matrix-multiply-applies-the-left-operand-first
  ;; (multiply scale translation) scales and then translates; the other order
  ;; translates and then scales, and the two differ.
  (let* ((scale (xna:matrix-create-scale 2))
         (translate (xna:matrix-create-translation (xna:make-vector3 1 0 0)))
         (scale-then-translate (xna:matrix-multiply scale translate))
         (translate-then-scale (xna:matrix-multiply translate scale))
         (point (xna:make-vector3 1 0 0)))
    (is (vector3~= (xna:vector3-transform point scale-then-translate)
                   (xna:make-vector3 3 0 0)))
    (is (vector3~= (xna:vector3-transform point translate-then-scale)
                   (xna:make-vector3 4 0 0)))))

(test matrix-identity-is-a-multiplicative-identity
  (let ((m (xna:make-matrix 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)))
    (is (matrix~= m (xna:matrix-multiply m (xna:matrix-identity))))
    (is (matrix~= m (xna:matrix-multiply (xna:matrix-identity) m)))))

(test matrix-invert-undoes-a-transform
  (dolist (m (list (xna:matrix-create-translation (xna:make-vector3 1 2 3))
                   (xna:matrix-create-scale 2 3 4)
                   (xna:matrix-create-rotation-y 0.7)
                   (xna:matrix-multiply
                    (xna:matrix-create-rotation-z 0.3)
                    (xna:matrix-create-translation (xna:make-vector3 5 -2 1)))))
    (is (matrix~= (xna:matrix-identity)
                  (xna:matrix-multiply m (xna:matrix-invert m))
                  1.0e-4))))

(test matrix-determinant-of-a-rotation-is-one
  (is (~= 1.0f0 (xna:matrix-determinant (xna:matrix-create-rotation-x 0.9))))
  (is (~= 1.0f0 (xna:matrix-determinant (xna:matrix-identity))))
  (is (~= 24.0f0 (xna:matrix-determinant (xna:matrix-create-scale 2 3 4)))))

(test matrix-transpose-is-its-own-inverse
  (let ((m (xna:make-matrix 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)))
    (is (matrix~= m (xna:matrix-transpose (xna:matrix-transpose m))))
    (is (= (xna:matrix-m12 m) (xna:matrix-m21 (xna:matrix-transpose m))))))

(test matrix-rotation-matrices-agree-with-the-quaternions
  (dolist (angle '(0.0 0.4 1.6 -2.2))
    (is (matrix~= (xna:matrix-create-rotation-x angle)
                  (xna:matrix-create-from-quaternion
                   (xna:quaternion-create-from-axis-angle (xna:vector3-unit-x) angle))
                  1.0e-5))
    (is (matrix~= (xna:matrix-create-rotation-y angle)
                  (xna:matrix-create-from-axis-angle (xna:vector3-unit-y) angle)
                  1.0e-5))))

(test matrix-create-look-at-puts-the-camera-at-the-origin
  (let* ((eye (xna:make-vector3 0 0 10))
         (view (xna:matrix-create-look-at eye (xna:vector3-zero) (xna:vector3-up))))
    (is (vector3~= (xna:vector3-transform eye view) (xna:vector3-zero) 1.0e-4))
    ;; The target ends up straight ahead, ten units down -Z.
    (is (vector3~= (xna:vector3-transform (xna:vector3-zero) view)
                   (xna:make-vector3 0 0 -10) 1.0e-4))))

(test matrix-create-world-looks-down-negative-z
  (let ((world (xna:matrix-create-world (xna:make-vector3 1 2 3)
                                        (xna:vector3-forward)
                                        (xna:vector3-up))))
    (is (vector3~= (xna:matrix-translation world) (xna:make-vector3 1 2 3)))
    (is (vector3~= (xna:matrix-forward world) (xna:vector3-forward) 1.0e-5))))

(test matrix-perspective-refuses-what-the-framework-refuses
  (signals xna:cna-argument-out-of-range-error
    (xna:matrix-create-perspective-field-of-view 0.0 1.0 1.0 100.0))
  (signals xna:cna-argument-out-of-range-error
    (xna:matrix-create-perspective-field-of-view xna:+math-helper-pi+ 1.0 1.0 100.0))
  (signals xna:cna-argument-out-of-range-error
    (xna:matrix-create-perspective-field-of-view 1.0 1.0 0.0 100.0))
  (signals xna:cna-argument-out-of-range-error
    (xna:matrix-create-perspective-field-of-view 1.0 1.0 100.0 1.0))
  (finishes (xna:matrix-create-perspective-field-of-view 1.0 1.6 1.0 100.0)))

(test the-refusal-names-the-argument
  (handler-case (progn (xna:matrix-create-perspective 1.0 1.0 0.0 100.0)
                       (fail "a non-positive near plane was accepted"))
    (xna:cna-argument-out-of-range-error (condition)
      (is (string= "near-plane-distance" (xna:cna-error-parameter-name condition))))))

(test matrix-perspective-projects-into-a-clip-volume
  (let* ((projection (xna:matrix-create-perspective-field-of-view
                      xna:+math-helper-pi-over4+ 1.0 1.0 100.0))
         (near (xna:vector4-transform (xna:make-vector3 0 0 -1) projection))
         (far (xna:vector4-transform (xna:make-vector3 0 0 -100) projection)))
    ;; XNA's clip space runs z from 0 at the near plane to w at the far plane.
    (is (~= 0.0f0 (xna:vector4-z near) 1.0e-4))
    (is (~= 1.0f0 (xna:vector4-w near) 1.0e-4))
    (is (~= (xna:vector4-w far) (xna:vector4-z far) 1.0e-3))))

(test matrix-orthographic-maps-the-box-to-the-clip-volume
  (let ((m (xna:matrix-create-orthographic 2.0 2.0 0.0 1.0)))
    (is (= 1.0f0 (xna:matrix-m11 m)))
    (is (= 1.0f0 (xna:matrix-m22 m)))
    (is (= -1.0f0 (xna:matrix-m33 m)))))

;;; --- transforms --------------------------------------------------------------

(test vector3-transform-includes-the-translation-and-transform-normal-does-not
  (let ((m (xna:matrix-create-translation (xna:make-vector3 10 20 30)))
        (v (xna:make-vector3 1 2 3)))
    (is (xna:vector3-equal (xna:vector3-transform v m) (xna:make-vector3 11 22 33)))
    (is (xna:vector3-equal (xna:vector3-transform-normal v m) v))))

(test transforming-by-a-quaternion-agrees-with-its-matrix
  (let* ((q (xna:quaternion-create-from-axis-angle
             (xna:vector3-normalized (xna:make-vector3 1 1 0)) 0.9))
         (m (xna:matrix-create-from-quaternion q))
         (v (xna:make-vector3 0.3 -1.2 2.0)))
    (is (vector3~= (xna:vector3-transform v q) (xna:vector3-transform v m) 1.0e-5))))

(test a-quarter-turn-about-z-takes-x-to-y
  (let ((m (xna:matrix-create-rotation-z xna:+math-helper-pi-over2+)))
    (is (vector3~= (xna:vector3-transform (xna:vector3-unit-x) m)
                   (xna:vector3-unit-y) 1.0e-6))))

(test vector4-transform-extends-shorter-inputs-the-way-xna-does
  (let ((m (xna:matrix-create-translation (xna:make-vector3 1 2 3))))
    (let ((r (xna:vector4-transform (xna:make-vector2 10 20) m)))
      (is (= 11.0f0 (xna:vector4-x r)))
      (is (= 3.0f0 (xna:vector4-z r)) "the absent Z is zero, and the translation still applies")
      (is (= 1.0f0 (xna:vector4-w r))))
    (let ((r (xna:vector4-transform (xna:make-vector4 1 2 3 0) m)))
      (is (= 1.0f0 (xna:vector4-x r)) "a W of zero is a direction: no translation"))))

(test vector4-quaternion-transform-keeps-w-for-a-vector4-and-answers-one-otherwise
  (let ((q (xna:quaternion-identity)))
    (is (= 1.0f0 (xna:vector4-w (xna:vector4-transform (xna:make-vector3 1 2 3) q))))
    (is (= 7.0f0 (xna:vector4-w (xna:vector4-transform (xna:make-vector4 1 2 3 7) q))))))

(test the-array-transforms-do-the-whole-array-and-a-window-of-it
  (let* ((m (xna:matrix-create-translation (xna:make-vector3 1 0 0)))
         (source (vector (xna:make-vector3 0 0 0) (xna:make-vector3 1 0 0)
                         (xna:make-vector3 2 0 0)))
         (destination (make-array 3)))
    (xna:vector3-transform-array source m destination)
    (is (xna:vector3-equal (aref destination 0) (xna:make-vector3 1 0 0)))
    (is (xna:vector3-equal (aref destination 2) (xna:make-vector3 3 0 0)))
    (let ((window (make-array 3 :initial-element nil)))
      (xna:vector3-transform-array source m window
                                   :source-index 1 :destination-index 2 :length 1)
      (is (null (aref window 0)))
      (is (xna:vector3-equal (aref window 2) (xna:make-vector3 2 0 0))))))

(test an-array-transform-refuses-a-window-that-does-not-fit
  (let ((m (xna:matrix-identity))
        (source (vector (xna:make-vector3 0 0 0)))
        (destination (make-array 1)))
    (signals xna:cna-argument-out-of-range-error
      (xna:vector3-transform-array source m destination :length 5))
    (signals xna:cna-argument-out-of-range-error
      (xna:vector3-transform-array source m destination :destination-index 1))))
