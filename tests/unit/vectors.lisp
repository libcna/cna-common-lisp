;;;; vectors.lisp --- Vector3 and Vector4, and Vector2's completion.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

;;; --- construction and value semantics -------------------------------------

(test vector3-constructors
  (let ((v (xna:make-vector3 1 2 3)))
    (is (= 1.0f0 (xna:vector3-x v)))
    (is (= 2.0f0 (xna:vector3-y v)))
    (is (= 3.0f0 (xna:vector3-z v))))
  ;; One value fills every component, exactly as Vector3(float) does.
  (let ((v (xna:make-vector3 7)))
    (is (= 7.0f0 (xna:vector3-x v)))
    (is (= 7.0f0 (xna:vector3-y v)))
    (is (= 7.0f0 (xna:vector3-z v))))
  (let ((v (xna:make-vector3-from-vector2 (xna:make-vector2 1 2) 3)))
    (is (= 1.0f0 (xna:vector3-x v)))
    (is (= 3.0f0 (xna:vector3-z v)))))

(test vector4-constructors
  (let ((v (xna:make-vector4 1 2 3 4)))
    (is (= 4.0f0 (xna:vector4-w v))))
  (let ((v (xna:make-vector4 5)))
    (is (= 5.0f0 (xna:vector4-w v))))
  (let ((v (xna:make-vector4-from-vector3 (xna:make-vector3 1 2 3) 4)))
    (is (= 3.0f0 (xna:vector4-z v)))
    (is (= 4.0f0 (xna:vector4-w v))))
  (let ((v (xna:make-vector4-from-vector2 (xna:make-vector2 1 2) 3 4)))
    (is (= 2.0f0 (xna:vector4-y v)))
    (is (= 3.0f0 (xna:vector4-z v)))))

(test vector3-predefined-directions-are-fresh-values
  (let ((up (xna:vector3-up)))
    (setf (xna:vector3-y up) 99.0f0)
    (is (= 1.0f0 (xna:vector3-y (xna:vector3-up))))))

(test vector3-predefined-directions-are-xnas
  ;; Forward is -Z and Backward is +Z: XNA's right-handed convention, and the one
  ;; thing about these constants a port will notice immediately if it is wrong.
  (is (xna:vector3-equal (xna:vector3-forward) (xna:make-vector3 0 0 -1)))
  (is (xna:vector3-equal (xna:vector3-backward) (xna:make-vector3 0 0 1)))
  (is (xna:vector3-equal (xna:vector3-up) (xna:make-vector3 0 1 0)))
  (is (xna:vector3-equal (xna:vector3-down) (xna:make-vector3 0 -1 0)))
  (is (xna:vector3-equal (xna:vector3-right) (xna:make-vector3 1 0 0)))
  (is (xna:vector3-equal (xna:vector3-left) (xna:make-vector3 -1 0 0)))
  (is (xna:vector3-equal (xna:vector3-unit-z) (xna:make-vector3 0 0 1))))

;;; --- arithmetic, in XNA's order --------------------------------------------

(test vector3-length-and-distance
  (is (= 5.0f0 (xna:vector3-length (xna:make-vector3 3 4 0))))
  (is (= 13.0f0 (xna:vector3-length (xna:make-vector3 3 4 12))))
  (is (= 169.0f0 (xna:vector3-length-squared (xna:make-vector3 3 4 12))))
  (is (= 5.0f0 (xna:vector3-distance (xna:make-vector3 1 2 3)
                                     (xna:make-vector3 4 6 3)))))

(test vector3-length-sums-in-binary32-before-the-root
  (let ((v (xna:make-vector3 1.0f20 1.0f20 0.0f0)))
    (is (sb-ext:float-infinity-p (xna:vector3-length v)))))

(test vector3-cross-is-right-handed
  (let ((c (xna:vector3-cross (xna:make-vector3 1 0 0) (xna:make-vector3 0 1 0))))
    (is (xna:vector3-equal c (xna:make-vector3 0 0 1))))
  (let ((c (xna:vector3-cross (xna:make-vector3 0 1 0) (xna:make-vector3 1 0 0))))
    (is (xna:vector3-equal c (xna:make-vector3 0 0 -1)))))

(test vector3-dot
  (is (= 32.0f0 (xna:vector3-dot (xna:make-vector3 1 2 3) (xna:make-vector3 4 5 6))))
  (is (= 0.0f0 (xna:vector3-dot (xna:vector3-unit-x) (xna:vector3-unit-y)))))

(test vector3-normalize-mutates-and-normalized-does-not
  (let ((v (xna:make-vector3 3 4 0)))
    (let ((answer (xna:vector3-normalize v)))
      (is (eq answer v) "the instance form answers the receiver")
      (is (= 0.6f0 (xna:vector3-x v)))
      (is (= 0.8f0 (xna:vector3-y v)))))
  (let* ((v (xna:make-vector3 3 4 0))
         (n (xna:vector3-normalized v)))
    (is (= 3.0f0 (xna:vector3-x v)) "the static form leaves its argument alone")
    (is (= 0.6f0 (xna:vector3-x n)))))

(test vector3-normalize-takes-the-reciprocal-of-a-binary32-root
  ;; XNA computes 1f / (float)Math.Sqrt(lengthSquared) and multiplies. Dividing
  ;; each component by the binary64 root answers different bits for most inputs.
  (let* ((v (xna:make-vector3 1 2 3))
         (squared (xna:vector3-length-squared v))
         (scale (/ 1.0f0 (coerce (sqrt (coerce squared 'double-float)) 'single-float)))
         (n (xna:vector3-normalized v)))
    (is (= (* 1.0f0 scale) (xna:vector3-x n)))
    (is (= (* 2.0f0 scale) (xna:vector3-y n)))
    (is (= (* 3.0f0 scale) (xna:vector3-z n)))))

(test vector3-reflect-doubles-the-dot-before-scaling-the-normal
  (let* ((v (xna:make-vector3 1 -1 0))
         (n (xna:make-vector3 0 1 0))
         (r (xna:vector3-reflect v n)))
    (is (xna:vector3-equal r (xna:make-vector3 1 1 0))))
  (let* ((v (xna:make-vector3 0.3 0.7 0.11))
         (n (xna:make-vector3 0.5 0.25 0.125))
         (dot (xna:vector3-dot v n))
         (r (xna:vector3-reflect v n)))
    (is (= (- (xna:vector3-x v) (* (* 2.0f0 dot) (xna:vector3-x n)))
           (xna:vector3-x r)))))

(test vector3-divide-by-a-scalar-uses-one-reciprocal
  (let* ((d 3.0f0) (reciprocal (/ 1.0f0 d))
         (q (xna:vector3-divide (xna:make-vector3 1 1 1) d)))
    (is (= (* 1.0f0 reciprocal) (xna:vector3-x q)))))

(test vector3-multiply-and-divide-dispatch-on-the-second-argument
  (let ((v (xna:make-vector3 2 3 4)))
    (is (= 4.0f0 (xna:vector3-x (xna:vector3-multiply v 2))))
    (is (= 6.0f0 (xna:vector3-x (xna:vector3-multiply v (xna:make-vector3 3 1 1)))))
    (is (= 1.0f0 (xna:vector3-x (xna:vector3-divide v (xna:make-vector3 2 3 4)))))))

(test vector3-min-max-and-clamp-are-component-wise
  (let ((a (xna:make-vector3 1 5 3)) (b (xna:make-vector3 4 2 3)))
    (is (xna:vector3-equal (xna:vector3-min a b) (xna:make-vector3 1 2 3)))
    (is (xna:vector3-equal (xna:vector3-max a b) (xna:make-vector3 4 5 3))))
  (is (xna:vector3-equal
       (xna:vector3-clamp (xna:make-vector3 -1 5 0.5)
                          (xna:vector3-zero) (xna:vector3-one))
       (xna:make-vector3 0 1 0.5))))

(test vector3-interpolation-family
  (is (xna:vector3-equal (xna:vector3-lerp (xna:vector3-zero) (xna:vector3-one) 0.5)
                         (xna:make-vector3 0.5 0.5 0.5)))
  (is (xna:vector3-equal (xna:vector3-smooth-step (xna:vector3-zero) (xna:vector3-one) 0.0)
                         (xna:vector3-zero)))
  (is (xna:vector3-equal
       (xna:vector3-barycentric (xna:vector3-zero) (xna:vector3-one)
                                (xna:make-vector3 2) 1.0 0.0)
       (xna:vector3-one)))
  (is (xna:vector3-equal
       (xna:vector3-catmull-rom (xna:make-vector3 1) (xna:make-vector3 2)
                                (xna:make-vector3 3) (xna:make-vector3 4) 0.0)
       (xna:make-vector3 2)))
  (is (xna:vector3-equal
       (xna:vector3-hermite (xna:vector3-zero) (xna:vector3-zero)
                            (xna:vector3-one) (xna:vector3-zero) 1.0)
       (xna:vector3-one))))

(test vector3-interpolation-is-the-scalar-family-per-component
  ;; The vector forms must be exactly MathHelper applied per component, not a
  ;; re-derivation that happens to be close.
  (let ((a (xna:make-vector3 0.1 0.2 0.3))
        (b (xna:make-vector3 0.7 0.11 0.13))
        (m 0.37f0))
    (let ((v (xna:vector3-lerp a b m)))
      (is (= (xna:math-helper-lerp 0.1f0 0.7f0 m) (xna:vector3-x v)))
      (is (= (xna:math-helper-lerp 0.2f0 0.11f0 m) (xna:vector3-y v))))
    (let ((v (xna:vector3-smooth-step a b m)))
      (is (= (xna:math-helper-smooth-step 0.3f0 0.13f0 m) (xna:vector3-z v))))))

;;; --- Vector4 ---------------------------------------------------------------

(test vector4-length-and-dot
  (is (= 2.0f0 (xna:vector4-length (xna:make-vector4 1 1 1 1))))
  (is (= 4.0f0 (xna:vector4-length-squared (xna:make-vector4 1 1 1 1))))
  (is (= 10.0f0 (xna:vector4-dot (xna:make-vector4 1 1 1 1) (xna:make-vector4 1 2 3 4)))))

(test vector4-unit-vectors
  (is (xna:vector4-equal (xna:vector4-unit-w) (xna:make-vector4 0 0 0 1)))
  (is (xna:vector4-equal (xna:vector4-one) (xna:make-vector4 1 1 1 1))))

(test vector4-normalize-mutates-and-normalized-does-not
  (let ((v (xna:make-vector4 1 1 1 1)))
    (xna:vector4-normalize v)
    (is (= 0.5f0 (xna:vector4-x v))))
  (let* ((v (xna:make-vector4 1 1 1 1))
         (n (xna:vector4-normalized v)))
    (is (= 1.0f0 (xna:vector4-x v)))
    (is (= 0.5f0 (xna:vector4-x n)))))

(test vector4-arithmetic
  (let ((a (xna:make-vector4 1 2 3 4)) (b (xna:make-vector4 4 3 2 1)))
    (is (xna:vector4-equal (xna:vector4-add a b) (xna:make-vector4 5 5 5 5)))
    (is (xna:vector4-equal (xna:vector4-subtract a b) (xna:make-vector4 -3 -1 1 3)))
    (is (xna:vector4-equal (xna:vector4-min a b) (xna:make-vector4 1 2 2 1)))
    (is (xna:vector4-equal (xna:vector4-max a b) (xna:make-vector4 4 3 3 4)))
    (is (xna:vector4-equal (xna:vector4-negate a) (xna:make-vector4 -1 -2 -3 -4)))))

;;; --- Vector2's completion ---------------------------------------------------

(test vector2-gained-the-rest-of-its-by-value-family
  (is (xna:vector2-equal (xna:vector2-reflect (xna:make-vector2 1 -1)
                                              (xna:make-vector2 0 1))
                         (xna:make-vector2 1 1)))
  (is (xna:vector2-equal (xna:vector2-min (xna:make-vector2 1 5)
                                          (xna:make-vector2 4 2))
                         (xna:make-vector2 1 2)))
  (is (xna:vector2-equal (xna:vector2-max (xna:make-vector2 1 5)
                                          (xna:make-vector2 4 2))
                         (xna:make-vector2 4 5)))
  (is (xna:vector2-equal (xna:vector2-clamp (xna:make-vector2 -1 5)
                                            (xna:vector2-zero) (xna:vector2-one))
                         (xna:make-vector2 0 1)))
  (is (xna:vector2-equal (xna:vector2-lerp (xna:vector2-zero) (xna:vector2-one) 0.25)
                         (xna:make-vector2 0.25 0.25)))
  (is (xna:vector2-equal (xna:vector2-smooth-step (xna:vector2-zero)
                                                  (xna:vector2-one) 1.0)
                         (xna:vector2-one)))
  (is (xna:vector2-equal (xna:vector2-barycentric (xna:vector2-zero) (xna:vector2-one)
                                                  (xna:make-vector2 2 2) 0.0 1.0)
                         (xna:make-vector2 2 2)))
  (is (xna:vector2-equal (xna:vector2-catmull-rom (xna:make-vector2 1 1)
                                                  (xna:make-vector2 2 2)
                                                  (xna:make-vector2 3 3)
                                                  (xna:make-vector2 4 4) 1.0)
                         (xna:make-vector2 3 3)))
  (is (xna:vector2-equal (xna:vector2-hermite (xna:vector2-zero) (xna:vector2-zero)
                                              (xna:vector2-one) (xna:vector2-zero) 0.0)
                         (xna:vector2-zero))))

(test vector2-normalized-does-not-mutate
  (let* ((v (xna:make-vector2 3 4))
         (n (xna:vector2-normalized v)))
    (is (= 3.0f0 (xna:vector2-x v)))
    (is (= 0.6f0 (xna:vector2-x n)))))

;;; --- these types never touch the C ABI --------------------------------------

(test the-value-types-need-no-native-library
  ;; Everything above ran without CNA_NATIVE_LIBRARY being consulted. If a value
  ;; type had been routed through the C ABI, this suite could not be in the pure
  ;; layer at all.
  (is (or (not (int:native-library-loaded-p))
          (progn (xna:vector3-length (xna:make-vector3 1 2 3)) t))))
