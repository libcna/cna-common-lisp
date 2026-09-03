;;;; float-semantics.lisp --- IEEE 754 default semantics for XNA arithmetic.
;;;;
;;;; XNA computes in binary32 under the CLR's floating-point rules, which are
;;;; IEEE 754's *default* rules: an overflow answers an infinity, an invalid
;;;; operation answers a NaN, and nothing is signalled. SBCL, by contrast, traps
;;;; overflow, invalid and divide-by-zero by default, so the same expression that
;;;; answers +Inf in C# would signal FLOATING-POINT-OVERFLOW here.
;;;;
;;;; A binding that let that difference through would answer a condition where
;;;; XNA answers a number, which is a behavioural divergence and not a detail. So
;;;; every projected arithmetic operation runs inside WITH-BINARY32-SEMANTICS.
;;;;
;;;; This is the one place that knows how a particular implementation spells
;;;; "mask the floating-point traps".

(in-package #:cna-lisp.internal)

(defmacro with-binary32-semantics (&body body)
  "Evaluate BODY under IEEE 754 default exception handling, as the CLR does.

Overflow answers an infinity, an invalid operation answers a NaN, and division
by zero answers an infinity -- none of them signals. This is what makes
`(vector2-length (make-vector2 1f20 1f20))' answer +Inf here, exactly as it does
in XNA, instead of signalling."
  #+sbcl `(sb-int:with-float-traps-masked (:overflow :underflow :invalid :divide-by-zero
                                           :inexact)
            ,@body)
  #-sbcl `(progn
            ;; Only SBCL is qualified. On another implementation this is a plain
            ;; PROGN, and the arithmetic will signal where XNA would answer an
            ;; infinity or a NaN -- which is exactly why no other implementation
            ;; is claimed.
            ,@body))
