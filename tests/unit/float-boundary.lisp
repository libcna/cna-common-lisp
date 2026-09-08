;;;; float-boundary.lisp --- the foreign floating-point boundary, without CNA.
;;;;
;;;; These need no native library, so they run on **both** qualified runtimes --
;;;; the reference SBCL 2.5.2 and the distribution's own -- which is the point.
;;;; The boundary is built on SBCL internals (`SB-INT:WITH-FLOAT-TRAPS-MASKED'
;;;; and `SB-INT:SET-FLOATING-POINT-MODES'), and an internal is exactly the kind
;;;; of thing that can change between releases. The renderer half of the claim --
;;;; that masking these two traps is what Mesa needs -- belongs to the EasyGL
;;;; lane's `foreign-fp-environment' proof, which needs a GL stack. This half is
;;;; about the mechanism: what it masks, and that it puts everything back.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defun %fp-modes () (sb-int:get-floating-point-modes))
(defun %fp-traps () (getf (%fp-modes) :traps))

(test the-foreign-boundary-masks-exactly-invalid-and-divide-by-zero
  "The measured minimum, and no more.

`:invalid' alone leaves the call signalling DIVISION-BY-ZERO and
`:divide-by-zero' alone leaves it signalling FLOATING-POINT-INVALID-OPERATION;
both together are enough and `:overflow' adds nothing. Masking a trap that was
not measured to need it would hide real arithmetic for no compatibility."
  (let ((outside (%fp-traps)))
    (int:with-foreign-float-environment
      (let ((inside (%fp-traps)))
        (is (not (member :invalid inside)))
        (is (not (member :divide-by-zero inside)))
        ;; :OVERFLOW is deliberately still live inside the boundary.
        (is (eq (and (member :overflow outside) t)
                (and (member :overflow inside) t)))))))

(test the-foreign-boundary-restores-the-whole-environment
  "Trap enables, rounding mode and the accrued flags, not only the first."
  (let ((before (%fp-modes)))
    (int:with-foreign-float-environment
      ;; Raise `invalid' the way the foreign code does, while it is masked.
      (is (sb-ext:float-nan-p (/ 0f0 0f0))))
    (let ((after (%fp-modes)))
      (is (equal (getf before :traps) (getf after :traps)))
      (is (eq (getf before :rounding-mode) (getf after :rounding-mode)))
      ;; The discriminating one: SBCL's own WITH-FLOAT-TRAPS-MASKED lets the
      ;; body's accrued flags survive, so a boundary that only used it would
      ;; hand the caller `:INVALID' it never raised.
      (is (equal (getf before :accrued-exceptions)
                 (getf after :accrued-exceptions))))))

(test the-callers-traps-still-fire-after-the-foreign-boundary
  "Restored, rather than merely looking restored."
  (int:with-foreign-float-environment (/ 0f0 0f0))
  (signals floating-point-invalid-operation (/ 0f0 0f0))
  (signals division-by-zero (/ 1f0 0f0)))

(test a-deliberately-trapping-caller-keeps-its-traps
  "A caller may run with traps this binding does not enable by default.

The environment restored is the caller's own, whatever it was, not a constant."
  (sb-int:with-float-traps-masked (:overflow)
    (let ((before (%fp-modes)))
      (is (not (member :overflow (getf before :traps))))
      (int:with-foreign-float-environment (/ 0f0 0f0))
      (is (equal (getf before :traps) (%fp-traps)))
      (is (not (member :overflow (%fp-traps)))))))

(test a-callback-sees-the-callers-environment-not-the-masked-one
  "The inbound half. CNA calls Lisp back from inside a masked foreign call, and
a user's Update or Draw must not silently lose the traps their own arithmetic
relies on."
  (let ((outside (%fp-traps)) (seen nil))
    (int:with-foreign-float-environment
      (setf seen (int:with-caller-float-environment (%fp-traps))))
    (is (equal outside seen))
    (is (member :invalid seen))
    (is (member :divide-by-zero seen))))

(test a-callback-restores-the-foreign-environment-on-the-way-out
  "The callback returns into C, which still needs the masked environment."
  (int:with-foreign-float-environment
    (int:with-caller-float-environment (values))
    (let ((back (%fp-traps)))
      (is (not (member :invalid back)))
      (is (not (member :divide-by-zero back))))))

(test the-caller-environment-outside-a-boundary-is-the-current-one
  "WITH-CALLER-FLOAT-ENVIRONMENT is a PROGN when nothing is masked, so a
callback reached without a boundary above it changes nothing."
  (is (null int:*caller-float-environment*))
  (let ((traps (%fp-traps)))
    (is (equal traps (int:with-caller-float-environment (%fp-traps))))))

(test a-nested-boundary-keeps-the-outermost-callers-environment
  "The caller is the program, not the enclosing foreign call."
  (let ((outside (%fp-traps)))
    (int:with-foreign-float-environment
      (int:with-foreign-float-environment
        (is (equal outside (getf int:*caller-float-environment* :traps)))
        (is (equal outside (int:with-caller-float-environment (%fp-traps))))))
    (is (equal outside (%fp-traps)))))

(test a-condition-through-the-boundary-still-restores-the-environment
  "The restoration is an UNWIND-PROTECT, so a non-local exit does not leak it."
  (let ((before (%fp-modes)))
    (signals simple-error
      (int:with-foreign-float-environment (error "through the boundary")))
    (is (equal (getf before :traps) (%fp-traps)))
    (is (equal (getf before :accrued-exceptions)
               (getf (%fp-modes) :accrued-exceptions)))))

(test xna-arithmetic-masking-is-not-the-foreign-boundary
  "Two different reasons to mask, and neither may widen into the other.

WITH-BINARY32-SEMANTICS masks five traps because the CLR computes under IEEE
754's *default* rules, so XNA answers an infinity where SBCL would signal. That
is a projection decision about MathHelper, Vector and Matrix. The foreign
boundary masks two, because a C library assumes them masked."
  (int:with-binary32-semantics
    (let ((traps (%fp-traps)))
      (is (not (member :invalid traps)))
      (is (not (member :overflow traps)))
      (is (not (member :underflow traps)))))
  ;; And it leaves the process as it found it, exactly as the other one does.
  (is (member :overflow (%fp-traps))))
