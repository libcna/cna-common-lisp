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

;;; --- the foreign boundary ----------------------------------------------
;;;
;;; **C libraries assume the IEEE traps are masked, and SBCL does not mask
;;; them.** A C program starts with every IEEE exception masked -- that is the C
;;; ecosystem's default -- so C code raises `invalid' and `divide-by-zero' freely
;;; and reads the results as NaN and infinity. SBCL instead *enables* the
;;; `:invalid', `:divide-by-zero' and `:overflow' traps, and an enabled trap
;;; inside a foreign call arrives as a Lisp condition signalled from a stack
;;; frame that has no Lisp arithmetic in it at all.
;;;
;;; Measured on 2026-09-08, SBCL 2.5.2.debian, CNA built with the OPENGL33
;;; (EasyGL) renderer on Mesa 25.0.7 llvmpipe:
;;;
;;;   * `GraphicsAdapter.Adapters' with no game and no device alive creates a
;;;     transient enumeration device, and `cna_graphics_device_create' signals
;;;     FLOATING-POINT-INVALID-OPERATION from inside the foreign call.
;;;   * The same sequence in a plain C program, with the traps masked as C leaves
;;;     them, runs to completion and answers one adapter. The same C program with
;;;     `feenableexcept(FE_INVALID)' dies with SIGFPE at the same call. **So this
;;;     is not a CNA or Mesa defect**; it is an SBCL caller environment a C
;;;     library was never written for.
;;;   * `:invalid' alone is not enough -- the call then signals DIVISION-BY-ZERO
;;;     -- and `:divide-by-zero' alone is not enough either. Both together are
;;;     enough, and adding `:overflow' changes nothing. So exactly two traps are
;;;     masked here, and no more: masking a trap that was not measured to need it
;;;     buys no compatibility and hides real arithmetic.
;;;   * The extent is narrow. With only device construction masked, a whole
;;;     Texture3D round trip -- create, SetData, GetData, Dispose -- runs with
;;;     the caller's ordinary traps live and round-trips byte for byte. The
;;;     renderer raises while it builds a context, not while it moves texels.
;;;
;;; Two directions, because CNA calls back into Lisp. A callback body running
;;; inside a masked foreign call would inherit the mask -- measured: every
;;; lifecycle method saw `traps=(:OVERFLOW)' -- and a user's Update or Draw must
;;; not silently lose the traps their own arithmetic relies on. So
;;; WITH-CALLER-FLOAT-ENVIRONMENT puts the caller's environment back for the
;;; duration of a callback, and the foreign one back on the way out.

(defvar *caller-float-environment* nil
  "The floating-point environment the Lisp caller had at the outermost boundary.

NIL outside any foreign boundary. Bound by WITH-FOREIGN-FLOAT-ENVIRONMENT to the
environment as it stood before the *first* mask, so that a nested boundary does
not record an already-masked environment as though it were the caller's.")

(defmacro with-foreign-float-environment (&body body)
  "Run BODY -- a foreign call -- with the traps C code assumes are masked.

Masks exactly `:invalid' and `:divide-by-zero', which is the measured minimum,
and restores the caller's *complete* floating-point environment afterwards:
trap enables, rounding mode, and the accrued exception flags the foreign code
raised while they were masked. A caller who deliberately runs with traps enabled
gets them back, and does not inherit Mesa's sticky flags either."
  #+sbcl
  (let ((saved (gensym "SAVED")) (outer (gensym "OUTER")))
    `(let* ((,outer *caller-float-environment*)
            (,saved (sb-int:get-floating-point-modes))
            (*caller-float-environment* (or ,outer ,saved)))
       (unwind-protect
            (sb-int:with-float-traps-masked (:invalid :divide-by-zero) ,@body)
         ;; WITH-FLOAT-TRAPS-MASKED restores the control bits but deliberately
         ;; keeps whatever accrued flags the body raised. This puts those back
         ;; too, so the boundary is reversible in full.
         (apply #'sb-int:set-floating-point-modes ,saved))))
  #-sbcl
  ;; Only SBCL is qualified as a native host. Elsewhere this is a plain PROGN
  ;; and a foreign call may signal where a C caller would not -- which is one
  ;; more reason no other implementation is claimed.
  `(progn ,@body))

(defmacro with-caller-float-environment (&body body)
  "Run BODY under the Lisp caller's own floating-point environment.

The inbound half of the boundary, for code that C calls back into: a callback
body must see the environment the program set up, not the masked one the foreign
call needed. Outside any foreign boundary this is a plain PROGN, because there is
nothing to restore."
  #+sbcl
  (let ((inner (gensym "INNER")) (caller (gensym "CALLER")))
    `(let ((,caller *caller-float-environment*))
       (if (null ,caller)
           (progn ,@body)
           (let ((,inner (sb-int:get-floating-point-modes)))
             (unwind-protect
                  (progn (apply #'sb-int:set-floating-point-modes ,caller)
                         ,@body)
               (apply #'sb-int:set-floating-point-modes ,inner))))))
  #-sbcl `(progn ,@body))

;;; Two predicates the projected arithmetic needs and Common Lisp does not define.
;;; They live here with the trap masking because they are the same kind of thing:
;;; the parts of IEEE 754 the standard leaves to the implementation.

(declaim (inline nan-p infinity-p negative-zero-p))

(defun nan-p (number)
  "True when NUMBER is a floating-point NaN."
  #+sbcl (and (floatp number) (sb-ext:float-nan-p number))
  #-sbcl (and (floatp number) (/= number number)))

(defun infinity-p (number)
  "True when NUMBER is a floating-point infinity."
  #+sbcl (and (floatp number) (sb-ext:float-infinity-p number))
  #-sbcl (and (floatp number)
              (or (> number most-positive-double-float)
                  (< number most-negative-double-float))))

(defun negative-zero-p (number)
  "True when NUMBER is the negative zero of its format."
  (and (floatp number) (zerop number) (minusp (float-sign number))))

;;; The bit pattern of a binary32, which the half-precision packed vectors need
;;; and Common Lisp does not define. Same reason as the predicates above: this is
;;; the part of IEEE 754 the standard leaves to the implementation.

(declaim (inline single-float-bits bits-single-float))

(defun single-float-bits (number)
  "NUMBER's binary32 bit pattern, as an unsigned 32-bit integer."
  #+sbcl (logand (sb-kernel:single-float-bits (float number 1.0f0)) #xFFFFFFFF)
  #-sbcl (error "no binary32 bit access on this implementation"))

(defun bits-single-float (bits)
  "The binary32 number an unsigned 32-bit pattern names."
  #+sbcl (sb-kernel:make-single-float
          (if (logbitp 31 bits) (- bits (ash 1 32)) bits))
  #-sbcl (error "no binary32 bit access on this implementation"))
