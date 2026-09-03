;;;; binary32.lisp --- the arithmetic every projected value type shares.
;;;;
;;;; XNA computes in IEEE 754 binary32. These three definitions are what makes
;;;; that literal here rather than approximate, and they live in their own file
;;;; because MathHelper and the vector types both need them and neither can be
;;;; said to come first.

(in-package #:microsoft.xna.framework)

(deftype xna-float ()
  "The floating-point type XNA computes in: IEEE 754 binary32."
  'single-float)

(declaim (inline f))
(defun f (number)
  "NUMBER as the binary32 value XNA would hold."
  (coerce number 'single-float))

(defun %sqrt-as-xna (single)
  "Math.Sqrt on a binary32 argument, cast back to binary32.

The square root itself is computed in binary64 because that is the only overload
the framework calls; the result is then narrowed. Doing the whole computation in
binary64 answers different bits, which is exactly what the vector length tests
pin."
  (cna-lisp.internal:with-binary32-semantics
    (f (sqrt (coerce single 'double-float)))))
