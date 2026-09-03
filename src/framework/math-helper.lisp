;;;; math-helper.lisp --- Microsoft.Xna.Framework.MathHelper.
;;;;
;;;; A static class, so its members are package functions named
;;;; `math-helper-<member>' and its constant fields are Lisp constants named
;;;; `+math-helper-<field>+'.
;;;;
;;;; Every algorithm here is read from the pinned XNA 4.0 Windows IL, instruction
;;;; by instruction, and reproduced in the same order and the same precision. The
;;;; order is not decoration: `Lerp' is `value1 + (value2 - value1) * amount', not
;;;; `value1 * (1 - amount) + value2 * amount', and the two answer different
;;;; binary32 for most inputs.

(in-package #:microsoft.xna.framework)

;;; The constants are the decimal renderings ildasm prints for the exact binary32
;;; literals in the assembly; reading them back answers the same bits.

(defconstant +math-helper-e+ 2.71828175f0
  "MathHelper.E.")
(defconstant +math-helper-log2e+ 1.442695f0
  "MathHelper.Log2E.")
(defconstant +math-helper-log10e+ 0.4342945f0
  "MathHelper.Log10E.")
(defconstant +math-helper-pi+ 3.14159274f0
  "MathHelper.Pi.")
(defconstant +math-helper-two-pi+ 6.28318548f0
  "MathHelper.TwoPi.")
(defconstant +math-helper-pi-over2+ 1.57079637f0
  "MathHelper.PiOver2.")
(defconstant +math-helper-pi-over4+ 0.7853982f0
  "MathHelper.PiOver4.")

(defun math-helper-to-radians (degrees)
  "MathHelper.ToRadians. One multiplication by the binary32 constant the assembly
holds, not a division by 180."
  (cna-lisp.internal:with-binary32-semantics
    (* (f degrees) 0.0174532924f0)))

(defun math-helper-to-degrees (radians)
  "MathHelper.ToDegrees."
  (cna-lisp.internal:with-binary32-semantics
    (* (f radians) 57.2957764f0)))

(defun math-helper-distance (value1 value2)
  "MathHelper.Distance: the absolute difference."
  (cna-lisp.internal:with-binary32-semantics
    (abs (- (f value1) (f value2)))))

(defun math-helper-min (value1 value2)
  "MathHelper.Min, which is System.Math.Min(Single, Single).

The .NET definition is `if (a < b) a; else if (IsNaN(a)) a; else b', which is why
a NaN first argument wins and why Min(-0.0, 0.0) answers +0.0 while
Min(0.0, -0.0) answers -0.0. Reproduced, not approximated by a comparison."
  (cna-lisp.internal:with-binary32-semantics
    (let ((a (f value1)) (b (f value2)))
      (cond ((< a b) a)
            ((cna-lisp.internal:nan-p a) a)
            (t b)))))

(defun math-helper-max (value1 value2)
  "MathHelper.Max, which is System.Math.Max(Single, Single). See MATH-HELPER-MIN."
  (cna-lisp.internal:with-binary32-semantics
    (let ((a (f value1)) (b (f value2)))
      (cond ((> a b) a)
            ((cna-lisp.internal:nan-p a) a)
            (t b)))))

(defun math-helper-clamp (value min max)
  "MathHelper.Clamp.

The IL compares against the maximum first and the minimum second, and both
comparisons are ordered: a NaN fails each of them and passes through unchanged.
Clamping in the other order, or with an unordered comparison, would answer
something else for a NaN and for an inverted range."
  (cna-lisp.internal:with-binary32-semantics
    (let ((v (f value)) (lo (f min)) (hi (f max)))
      (let ((v (if (> v hi) hi v)))
        (if (< v lo) lo v)))))

(defun math-helper-lerp (value1 value2 amount)
  "MathHelper.Lerp: value1 + (value2 - value1) * amount."
  (cna-lisp.internal:with-binary32-semantics
    (let ((a (f value1)) (b (f value2)) (m (f amount)))
      (+ a (* (- b a) m)))))

(defun math-helper-barycentric (value1 value2 value3 amount1 amount2)
  "MathHelper.Barycentric: v1 + (v2 - v1) * a1 + (v3 - v1) * a2."
  (cna-lisp.internal:with-binary32-semantics
    (let ((v1 (f value1)) (v2 (f value2)) (v3 (f value3))
          (a1 (f amount1)) (a2 (f amount2)))
      (+ (+ v1 (* a1 (- v2 v1))) (* a2 (- v3 v1))))))

(defun math-helper-smooth-step (value1 value2 amount)
  "MathHelper.SmoothStep: Lerp with the amount clamped to [0,1] and passed through
the cubic 3t^2 - 2t^3, written as t*t*(3 - 2*t) exactly as the IL does."
  (cna-lisp.internal:with-binary32-semantics
    (let ((m (math-helper-clamp amount 0.0f0 1.0f0)))
      (math-helper-lerp value1 value2 (* (* m m) (- 3.0f0 (* 2.0f0 m)))))))

(defun math-helper-catmull-rom (value1 value2 value3 value4 amount)
  "MathHelper.CatmullRom."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((v1 (f value1)) (v2 (f value2)) (v3 (f value3)) (v4 (f value4))
           (m (f amount))
           (m2 (* m m))
           (m3 (* m m2)))
      (* 0.5f0
         (+ (+ (+ (* 2.0f0 v2)
                  (* (+ (- v1) v3) m))
               (* (- (+ (- (* 2.0f0 v1) (* 5.0f0 v2)) (* 4.0f0 v3)) v4) m2))
            (* (+ (- (+ (- v1) (* 3.0f0 v2)) (* 3.0f0 v3)) v4) m3))))))

(defun math-helper-hermite (value1 tangent1 value2 tangent2 amount)
  "MathHelper.Hermite."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((v1 (f value1)) (t1 (f tangent1)) (v2 (f value2)) (t2 (f tangent2))
           (s (f amount))
           (s2 (* s s))
           (s3 (* s s2))
           (h1 (+ (- (* 2.0f0 s3) (* 3.0f0 s2)) 1.0f0))
           (h2 (+ (* -2.0f0 s3) (* 3.0f0 s2)))
           (h3 (+ (- s3 (* 2.0f0 s2)) s))
           (h4 (- s3 s2)))
      (+ (+ (+ (* v1 h1) (* v2 h2)) (* t1 h3)) (* t2 h4)))))

(defun %ieee-remainder (x y)
  "System.Math.IEEERemainder for binary64, reproduced from the .NET definition.

Not `x - y * round(x / y)': the framework starts from the truncated remainder and
only consults the quotient to break the tie, which keeps the answer exact for a
large x where computing x / y would already have lost bits."
  (cna-lisp.internal:with-binary32-semantics
    (let ((regular (rem x y)))
      (cond
        ;; The framework answers Double.NaN here; REGULAR already is one, and a
        ;; NaN payload is not observable through this API.
        ((cna-lisp.internal:nan-p regular) regular)
        ((and (zerop regular) (or (minusp x) (cna-lisp.internal:negative-zero-p x)))
         -0.0d0)
        (t
         (let ((alternative (- regular (* (abs y) (cond ((plusp x) 1.0d0)
                                                        ((minusp x) -1.0d0)
                                                        (t 0.0d0))))))
           (cond
             ((= (abs alternative) (abs regular))
              (let* ((quotient (/ x y))
                     (rounded (fround quotient)))
                (if (> (abs rounded) (abs quotient)) alternative regular)))
             ((< (abs alternative) (abs regular)) alternative)
             (t regular))))))))

(defun math-helper-wrap-angle (angle)
  "MathHelper.WrapAngle.

The remainder is taken in binary64, exactly as the IL does -- it calls
Math.IEEERemainder(double, double) with the widened angle and the binary64
rendering of two pi -- and only then narrowed. Both comparisons that follow are
unordered, so a NaN passes through unchanged."
  (cna-lisp.internal:with-binary32-semantics
    (let ((a (f (%ieee-remainder (coerce (f angle) 'double-float)
                                 6.2831854820251465d0))))
      (cond ((<= a -3.14159274f0) (+ a 6.28318548f0))
            ((> a 3.14159274f0) (- a 6.28318548f0))
            (t a)))))
