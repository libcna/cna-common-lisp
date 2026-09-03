;;;; value-types.lisp --- Point, Rectangle and Vector2, including binary32.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

;;; --- Point --------------------------------------------------------------

(test point-zero-answers-a-fresh-value-every-time
  ;; XNA's Point.Zero is a property on a value type: every read is a copy, so
  ;; mutating what one read answered cannot reach the next read.
  (let ((first (xna:point-zero)))
    (setf (xna:point-x first) 42)
    (is (= 0 (xna:point-x (xna:point-zero))))))

(test point-equality
  (is (xna:point-equal (xna:make-point 3 4) (xna:make-point 3 4)))
  (is (not (xna:point-equal (xna:make-point 3 4) (xna:make-point 4 3)))))

;;; --- Rectangle ----------------------------------------------------------

(test rectangle-edges
  (let ((r (xna:make-rectangle 10 20 30 40)))
    (is (= 10 (xna:rectangle-left r)))
    (is (= 40 (xna:rectangle-right r)))
    (is (= 20 (xna:rectangle-top r)))
    (is (= 60 (xna:rectangle-bottom r)))))

(test rectangle-center-halves-with-integer-division
  ;; XNA divides by 2 in integer arithmetic; an odd extent truncates.
  (let ((c (xna:rectangle-center (xna:make-rectangle 0 0 5 7))))
    (is (= 2 (xna:point-x c)))
    (is (= 3 (xna:point-y c)))))

(test rectangle-is-empty-means-all-four-components-zero
  (is (xna:rectangle-is-empty (xna:rectangle-empty)))
  ;; Zero area is not emptiness: a zero-size rectangle at (5,5) is not empty.
  (is (not (xna:rectangle-is-empty (xna:make-rectangle 5 5 0 0))))
  (is (not (xna:rectangle-is-empty (xna:make-rectangle 0 0 1 0)))))

(test rectangle-contains-is-half-open
  (let ((r (xna:make-rectangle 0 0 10 10)))
    (is (xna:rectangle-contains-coordinates r 0 0))
    (is (xna:rectangle-contains-coordinates r 9 9))
    (is (not (xna:rectangle-contains-coordinates r 10 5)))
    (is (not (xna:rectangle-contains-coordinates r 5 10)))
    (is (not (xna:rectangle-contains-coordinates r -1 5)))))

(test rectangle-contains-dispatches-on-argument-type
  (let ((r (xna:make-rectangle 0 0 10 10)))
    (is (xna:rectangle-contains r (xna:make-point 5 5)))
    (is (xna:rectangle-contains r (xna:make-rectangle 2 2 3 3)))
    (is (not (xna:rectangle-contains r (xna:make-rectangle 2 2 30 3))))))

(test rectangle-intersects-excludes-touching-edges
  (is (xna:rectangle-intersects (xna:make-rectangle 0 0 10 10)
                                (xna:make-rectangle 5 5 10 10)))
  (is (not (xna:rectangle-intersects (xna:make-rectangle 0 0 10 10)
                                     (xna:make-rectangle 10 0 10 10)))))

(test rectangle-offset-and-inflate-mutate-in-place
  ;; Both are void instance methods on a value type in XNA, and mutate.
  (let ((r (xna:make-rectangle 1 2 3 4)))
    (xna:rectangle-offset r 10 20)
    (is (= 11 (xna:rectangle-x r)))
    (is (= 22 (xna:rectangle-y r)))
    (xna:rectangle-inflate r 1 2)
    (is (= 10 (xna:rectangle-x r)))
    (is (= 20 (xna:rectangle-y r)))
    (is (= 5 (xna:rectangle-width r)))
    (is (= 8 (xna:rectangle-height r)))))

;;; --- Vector2, in binary32 ------------------------------------------------

(test vector2-components-are-single-floats
  (let ((v (xna:make-vector2 1 2)))
    (is (typep (xna:vector2-x v) 'single-float))
    (is (typep (xna:vector2-y v) 'single-float))))

(test vector2-length-matches-xnas-order-of-operations
  ;; XNA: float num = x*x + y*y; return (float) Math.Sqrt((double) num);
  ;; The squares are summed in binary32 and only then promoted. For x = 1e20 the
  ;; binary32 square overflows, so XNA's order answers an infinity -- while the
  ;; same computation carried out in binary64 and narrowed at the end answers
  ;; 1.41e20, which binary32 represents perfectly well. The order is the whole
  ;; difference between an infinity and a number.
  (let* ((x 1.0f20)
         (v (xna:make-vector2 x x))
         (all-binary64 (coerce (sqrt (+ (* (coerce x 'double-float) (coerce x 'double-float))
                                        (* (coerce x 'double-float) (coerce x 'double-float))))
                               'single-float)))
    (is (sb-ext:float-infinity-p (xna:vector2-length v))
        "XNA's order overflows binary32 and answers an infinity")
    (is (not (sb-ext:float-infinity-p all-binary64))
        "the same computation in binary64 does not overflow, which is why the
         order of operations is part of the contract")
    (is (< 1.4f20 all-binary64 1.5f20))))

(test vector2-length-of-ordinary-inputs-is-exact
  (is (= 5.0f0 (xna:vector2-length (xna:make-vector2 3 4))))
  (is (= 13.0f0 (xna:vector2-length (xna:make-vector2 5 12))))
  (is (= 25.0f0 (xna:vector2-distance (xna:make-vector2 0 0) (xna:make-vector2 7 24)))))

(test binary32-overflow-answers-an-infinity-rather-than-signalling
  ;; XNA computes under IEEE 754 default exception handling: an overflow answers
  ;; an infinity and nothing is raised. SBCL traps by default, so every projected
  ;; arithmetic operation runs with the traps masked. Without that, this would
  ;; signal FLOATING-POINT-OVERFLOW where a C# program answers +Inf.
  (let ((v (xna:make-vector2 1.0f20 1.0f20)))
    (is (sb-ext:float-infinity-p (xna:vector2-length-squared v)))
    (is (sb-ext:float-infinity-p (xna:vector2-length v)))
    (is (sb-ext:float-infinity-p
         (xna:vector2-x (xna:vector2-multiply v 1.0f20))))))

(test binary32-divide-by-zero-answers-an-infinity
  (let ((v (xna:vector2-divide (xna:make-vector2 1.0 -1.0) 0.0f0)))
    (is (sb-ext:float-infinity-p (xna:vector2-x v)))
    (is (plusp (xna:vector2-x v)))
    (is (minusp (xna:vector2-y v)))))

(test vector2-divide-by-scalar-uses-one-reciprocal
  ;; XNA divides once and multiplies twice; x*(1/d) and x/d are not the same
  ;; binary32 for every d, and this is one of the d for which they differ.
  (let* ((d 3.0f0) (x 1.0f0)
         (reciprocal (/ 1.0f0 d))
         (v (xna:vector2-divide (xna:make-vector2 x x) d)))
    (is (= (* x reciprocal) (xna:vector2-x v)))))

(test vector2-multiply-dispatches-on-scalar-or-vector
  (let ((v (xna:make-vector2 2 3)))
    (is (= 4.0f0 (xna:vector2-x (xna:vector2-multiply v 2))))
    (is (= 6.0f0 (xna:vector2-x (xna:vector2-multiply v (xna:make-vector2 3 1)))))))

(test vector2-signed-zero-is-preserved
  (let ((v (xna:vector2-negate (xna:make-vector2 0.0f0 0.0f0))))
    (is (minusp (float-sign (xna:vector2-x v))))
    (is (= 0.0f0 (xna:vector2-x v)))))

(test vector2-equal-is-false-for-nan
  ;; XNA's Equals uses ==, so a NaN component is not equal to itself. Comparing
  ;; a NaN raises the invalid-operation flag, which SBCL traps by default, so the
  ;; comparison is made with that trap masked -- the way a C# program's would be.
  (sb-int:with-float-traps-masked (:invalid)
    (let ((nan (sb-kernel:make-single-float -1)))
      (is (sb-ext:float-nan-p nan))
      (let ((v (xna:make-vector2 nan 0.0f0)))
        (is (not (xna:vector2-equal v v)))))))

(test vector2-constants-are-fresh-values
  (let ((one (xna:vector2-one)))
    (setf (xna:vector2-x one) 99.0f0)
    (is (= 1.0f0 (xna:vector2-x (xna:vector2-one))))))
