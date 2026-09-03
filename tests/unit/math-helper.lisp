;;;; math-helper.lisp --- MathHelper, against the pinned IL.
;;;;
;;;; Each test names the property of the original it pins. A test that only
;;;; checked "Lerp interpolates" would pass for an implementation that does not
;;;; answer XNA's bits.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test math-helper-constants-are-the-assemblys-binary32-values
  (is (= 2.71828175f0 xna:+math-helper-e+))
  (is (= 1.442695f0 xna:+math-helper-log2e+))
  (is (= 0.4342945f0 xna:+math-helper-log10e+))
  (is (= 3.14159274f0 xna:+math-helper-pi+))
  (is (= 6.28318548f0 xna:+math-helper-two-pi+))
  (is (= 1.57079637f0 xna:+math-helper-pi-over2+))
  (is (= 0.7853982f0 xna:+math-helper-pi-over4+))
  (dolist (constant (list xna:+math-helper-pi+ xna:+math-helper-e+))
    (is (typep constant 'single-float))))

(test to-radians-is-one-multiplication-not-a-division
  ;; The IL multiplies by the binary32 constant 0.0174532924f. Dividing by 180
  ;; answers a different value for most inputs.
  (is (= (* 90.0f0 0.0174532924f0) (xna:math-helper-to-radians 90)))
  (is (= (* 57.2957764f0 1.0f0) (xna:math-helper-to-degrees 1)))
  (is (typep (xna:math-helper-to-radians 90) 'single-float)))

(test lerp-is-value1-plus-difference-times-amount
  ;; Not v1*(1-t) + v2*t: for these inputs the two forms differ in the last bit.
  (let ((v1 1.0f0) (v2 3.0f0) (amount 0.1f0))
    (is (= (+ v1 (* (- v2 v1) amount)) (xna:math-helper-lerp v1 v2 amount))))
  (is (= 0.0f0 (xna:math-helper-lerp 0.0 1.0 0.0)))
  (is (= 1.0f0 (xna:math-helper-lerp 0.0 1.0 1.0))))

(test clamp-compares-against-the-maximum-first
  (is (= 5.0f0 (xna:math-helper-clamp 10.0 0.0 5.0)))
  (is (= 0.0f0 (xna:math-helper-clamp -10.0 0.0 5.0)))
  (is (= 3.0f0 (xna:math-helper-clamp 3.0 0.0 5.0)))
  ;; An inverted range: the maximum is applied first, so the minimum wins.
  (is (= 10.0f0 (xna:math-helper-clamp 3.0 10.0 0.0))))

(test clamp-passes-a-nan-through
  ;; Both comparisons in the IL are ordered, so a NaN fails each of them and is
  ;; returned unchanged. An implementation using MIN and MAX would answer a bound.
  (sb-int:with-float-traps-masked (:invalid)
    (let ((nan (sb-kernel:make-single-float -1)))
      (is (sb-ext:float-nan-p (xna:math-helper-clamp nan 0.0 1.0))))))

(test min-and-max-follow-the-dotnet-definition
  ;; System.Math.Min(Single, Single) in .NET 4 is
  ;;     if (a < b) return a; if (IsNaN(a)) return a; return b;
  ;; which is *not* IEEE minNum. Every consequence below follows from that shape
  ;; and would be wrong under a naive (if (< a b) a b).
  (is (= 1.0f0 (xna:math-helper-min 1.0 2.0)))
  (is (= 2.0f0 (xna:math-helper-max 1.0 2.0)))
  ;; Neither comparison holds for two zeros of opposite sign, so the *second*
  ;; argument is answered -- which makes Max(0.0, -0.0) answer -0.0.
  (is (not (minusp (float-sign (xna:math-helper-min -0.0f0 0.0f0)))))
  (is (minusp (float-sign (xna:math-helper-min 0.0f0 -0.0f0))))
  (is (minusp (float-sign (xna:math-helper-max 0.0f0 -0.0f0))))
  (is (not (minusp (float-sign (xna:math-helper-max -0.0f0 0.0f0)))))
  (sb-int:with-float-traps-masked (:invalid)
    (let ((nan (sb-kernel:make-single-float -1)))
      ;; A NaN propagates from either side: from the first through the explicit
      ;; IsNaN test, from the second because no comparison against it holds.
      (is (sb-ext:float-nan-p (xna:math-helper-min nan 1.0)))
      (is (sb-ext:float-nan-p (xna:math-helper-min 1.0 nan)))
      (is (sb-ext:float-nan-p (xna:math-helper-max nan 1.0)))
      (is (sb-ext:float-nan-p (xna:math-helper-max 1.0 nan))))))

(test distance-is-the-absolute-difference
  (is (= 3.0f0 (xna:math-helper-distance 1.0 4.0)))
  (is (= 3.0f0 (xna:math-helper-distance 4.0 1.0))))

(test smooth-step-clamps-then-applies-the-cubic
  (is (= 0.0f0 (xna:math-helper-smooth-step 0.0 1.0 -1.0)))
  (is (= 1.0f0 (xna:math-helper-smooth-step 0.0 1.0 2.0)))
  (is (= 0.5f0 (xna:math-helper-smooth-step 0.0 1.0 0.5)))
  (let ((m 0.25f0))
    (is (= (xna:math-helper-lerp 0.0 1.0 (* (* m m) (- 3.0f0 (* 2.0f0 m))))
           (xna:math-helper-smooth-step 0.0 1.0 m)))))

(test barycentric-is-v1-plus-two-weighted-differences
  (is (= 1.0f0 (xna:math-helper-barycentric 1.0 2.0 3.0 0.0 0.0)))
  (is (= 2.0f0 (xna:math-helper-barycentric 1.0 2.0 3.0 1.0 0.0)))
  (is (= 3.0f0 (xna:math-helper-barycentric 1.0 2.0 3.0 0.0 1.0))))

(test catmull-rom-passes-through-its-control-points
  (is (= 2.0f0 (xna:math-helper-catmull-rom 1.0 2.0 3.0 4.0 0.0)))
  (is (= 3.0f0 (xna:math-helper-catmull-rom 1.0 2.0 3.0 4.0 1.0))))

(test hermite-matches-its-endpoints-and-tangents
  (is (= 0.0f0 (xna:math-helper-hermite 0.0 1.0 1.0 1.0 0.0)))
  (is (= 1.0f0 (xna:math-helper-hermite 0.0 1.0 1.0 1.0 1.0)))
  ;; With both tangents zero the curve is the smooth-step polynomial.
  (is (= 0.5f0 (xna:math-helper-hermite 0.0 0.0 1.0 0.0 0.5))))

(test wrap-angle-brings-an-angle-into-minus-pi-to-pi
  (is (= 0.0f0 (xna:math-helper-wrap-angle 0.0)))
  (let ((wrapped (xna:math-helper-wrap-angle (* 3 xna:+math-helper-two-pi+))))
    (is (<= (abs wrapped) xna:+math-helper-pi+)))
  (let ((wrapped (xna:math-helper-wrap-angle (+ xna:+math-helper-pi+ 0.5f0))))
    (is (<= (abs wrapped) xna:+math-helper-pi+))
    (is (minusp wrapped)))
  (is (= xna:+math-helper-pi+ (xna:math-helper-wrap-angle xna:+math-helper-pi+))))

(test math-helper-is-a-static-class-projection
  ;; Its members are package functions named math-helper-<member>, and its
  ;; constant fields are Lisp constants. There is no MATH-HELPER type.
  (is (null (find-class 'xna::math-helper nil)))
  (is (fboundp 'xna:math-helper-lerp))
  (is (constantp 'xna:+math-helper-pi+)))
