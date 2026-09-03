;;;; corpus.lisp --- the behaviour corpus.
;;;;
;;;; Every observation records where it came from. That distinction is the whole
;;;; point: an observation derived from the Microsoft XNA contract says something
;;;; about compatibility, and an observation about how CNA-Lisp maps a thing says
;;;; something about this binding. Mixing them would let the binding appear to
;;;; prove its own compatibility.
;;;;
;;;;   :xna-derived      derived from the selected Microsoft XNA 4.0 Windows
;;;;                     public contract. CNA is never the authority here.
;;;;   :mapping          a CNA-Lisp mapping decision, qualified against itself.
;;;;   :abi-derived      a fact about the CNA C ABI's own published contract,
;;;;                     read from its canonical headers.
;;;;
;;;; An :xna-derived entry that CNA also answers may be cross-checked against
;;;; CNA. It is never *established* by CNA.

(in-package #:cna-common-lisp.tests)
(in-suite behavior-tests)

(defstruct observation
  id origin subject statement thunk)

(defparameter *corpus* '())

(defmacro defobservation (id origin subject statement &body body)
  `(progn
     (setf *corpus*
           (append (remove ,id *corpus* :key #'observation-id :test #'equal)
                   (list (make-observation :id ,id :origin ,origin :subject ,subject
                                           :statement ,statement
                                           :thunk (lambda () ,@body)))))
     ,id))

;;; --- XNA-derived ---------------------------------------------------------

(defobservation "color.packed-order" :xna-derived "Microsoft.Xna.Framework.Color"
  "PackedValue holds R in the low byte and A in the high byte."
  (= #x04030201 (xna:color-packed-value (xna:make-color 1 2 3 4))))

(defobservation "color.cornflower-blue" :xna-derived "Microsoft.Xna.Framework.Color"
  "CornflowerBlue is (100, 149, 237, 255)."
  (let ((c (xna:cornflower-blue)))
    (and (= 100 (xna:color-r c)) (= 149 (xna:color-g c))
         (= 237 (xna:color-b c)) (= 255 (xna:color-a c)))))

(defobservation "color.value-semantics" :xna-derived "Microsoft.Xna.Framework.Color"
  "A predefined colour is a value: mutating a read of it cannot affect the next read."
  (let ((c (xna:white)))
    (setf (xna:color-r c) 0)
    (= 255 (xna:color-r (xna:white)))))

(defobservation "rectangle.center-truncates" :xna-derived "Microsoft.Xna.Framework.Rectangle"
  "Center halves the extents with integer division, so an odd extent truncates."
  (let ((c (xna:rectangle-center (xna:make-rectangle 0 0 5 7))))
    (and (= 2 (xna:point-x c)) (= 3 (xna:point-y c)))))

(defobservation "rectangle.is-empty-is-all-four" :xna-derived
    "Microsoft.Xna.Framework.Rectangle"
  "IsEmpty requires all four components to be zero, not merely zero area."
  (and (xna:rectangle-is-empty (xna:rectangle-empty))
       (not (xna:rectangle-is-empty (xna:make-rectangle 5 5 0 0)))))

(defobservation "rectangle.contains-half-open" :xna-derived
    "Microsoft.Xna.Framework.Rectangle"
  "Contains includes the left and top edges and excludes the right and bottom."
  (let ((r (xna:make-rectangle 0 0 10 10)))
    (and (xna:rectangle-contains-coordinates r 0 0)
         (xna:rectangle-contains-coordinates r 9 9)
         (not (xna:rectangle-contains-coordinates r 10 10)))))

(defobservation "vector2.length-order" :xna-derived "Microsoft.Xna.Framework.Vector2"
  "Length sums the squares in binary32 and only then promotes to binary64 for
   the square root, so an input whose square overflows binary32 answers an
   infinity where a binary64 computation answers a finite number."
  (let ((v (xna:make-vector2 1.0f20 1.0f20)))
    (and (sb-ext:float-infinity-p (xna:vector2-length v))
         (not (sb-ext:float-infinity-p
               (coerce (sqrt (+ (* 1.0d20 1.0d20) (* 1.0d20 1.0d20))) 'single-float))))))

(defobservation "clr.ieee-default-exceptions" :xna-derived "the CLR numeric contract"
  "Floating-point arithmetic uses IEEE 754 default exception handling: an
   overflow answers an infinity and nothing is raised."
  (sb-ext:float-infinity-p (xna:vector2-length-squared (xna:make-vector2 1.0f20 1.0f20))))

(defobservation "vector2.divide-reciprocal" :xna-derived "Microsoft.Xna.Framework.Vector2"
  "Divide by a scalar takes the reciprocal once and multiplies."
  (let ((v (xna:vector2-divide (xna:make-vector2 1.0 1.0) 3.0f0)))
    (= (* 1.0f0 (/ 1.0f0 3.0f0)) (xna:vector2-x v))))

(defobservation "viewport.title-safe-threshold" :xna-derived
    "Microsoft.Xna.Framework.Graphics.Viewport"
  "TitleSafeArea insets only once the viewport is at least 640x480; below that
   the whole viewport is title safe."
  (let ((small (gfx:viewport-title-safe-area (gfx:make-viewport 0 0 320 240)))
        (large (gfx:viewport-title-safe-area (gfx:make-viewport 0 0 640 480))))
    (and (= 320 (xna:rectangle-width small))
         (= 0 (xna:rectangle-x small))
         (< (xna:rectangle-width large) 640)
         (> (xna:rectangle-x large) 0))))

(defobservation "viewport.aspect-ratio-zero" :xna-derived
    "Microsoft.Xna.Framework.Graphics.Viewport"
  "AspectRatio answers zero when either extent is zero rather than dividing."
  (= 0.0f0 (gfx:viewport-aspect-ratio (gfx:make-viewport 0 0 0 480))))

(defobservation "gametime.timespan-is-ticks" :xna-derived
    "Microsoft.Xna.Framework.GameTime"
  "TotalGameTime is a TimeSpan, an exact count of 100-nanosecond ticks."
  (= 10000000 xna:+ticks-per-second+))

(defobservation "game.default-fixed-step" :xna-derived "Microsoft.Xna.Framework.Game"
  "The default TargetElapsedTime is 1/60 second, 166667 ticks."
  (= 166667 xna:+default-target-elapsed-time-ticks+))

(defobservation "keyboardstate.duplicates-once" :xna-derived
    "Microsoft.Xna.Framework.Input.KeyboardState"
  "A duplicate key in the set-taking constructor contributes once."
  (equal '(:a) (input:get-pressed-keys (input:make-keyboard-state '(:a :a)))))

;;; --- XNA-derived, read from the pinned IL --------------------------------
;;;
;;; Each of these was read out of the disassembled Microsoft.Xna.Framework.dll
;;; pinned in tools/api-compat/reference/XNA_IL_PROVENANCE.md, and each is a fact
;;; a plausible-looking reimplementation gets wrong.

(defobservation "mathhelper.pi-is-binary32" :xna-derived "Microsoft.Xna.Framework.MathHelper"
  "Pi is the binary32 3.14159274f, not a narrowed binary64 pi."
  (= 3.14159274f0 xna:+math-helper-pi+))

(defobservation "mathhelper.to-radians-multiplies" :xna-derived
    "Microsoft.Xna.Framework.MathHelper"
  "ToRadians multiplies by the binary32 constant 0.0174532924f; it does not divide
   by 180."
  (= (* 90.0f0 0.0174532924f0) (xna:math-helper-to-radians 90)))

(defobservation "mathhelper.lerp-shape" :xna-derived "Microsoft.Xna.Framework.MathHelper"
  "Lerp is value1 + (value2 - value1) * amount."
  (= (+ 1.0f0 (* (- 3.0f0 1.0f0) 0.1f0)) (xna:math-helper-lerp 1.0 3.0 0.1)))

(defobservation "mathhelper.clamp-nan" :xna-derived "Microsoft.Xna.Framework.MathHelper"
  "Clamp compares against the maximum first with ordered comparisons, so a NaN
   fails both and passes through unchanged."
  (sb-int:with-float-traps-masked (:invalid)
    (sb-ext:float-nan-p (xna:math-helper-clamp (sb-kernel:make-single-float -1) 0.0 1.0))))

(defobservation "mathhelper.clamp-inverted-range" :xna-derived
    "Microsoft.Xna.Framework.MathHelper"
  "With an inverted range the minimum wins, because it is applied second."
  (= 10.0f0 (xna:math-helper-clamp 3.0 10.0 0.0)))

(defobservation "bcl.math-min-is-not-ieee-min-num" :xna-derived "System.Math"
  "Math.Min(Single,Single) in .NET 4 answers the second argument when neither the
   less-than test nor the NaN test on the first holds, which makes
   Max(+0.0, -0.0) answer -0.0."
  (minusp (float-sign (xna:math-helper-max 0.0f0 -0.0f0))))

(defobservation "vector3.forward-is-negative-z" :xna-derived
    "Microsoft.Xna.Framework.Vector3"
  "Vector3.Forward is (0, 0, -1) and Backward is (0, 0, 1): XNA is right-handed."
  (and (xna:vector3-equal (xna:vector3-forward) (xna:make-vector3 0 0 -1))
       (xna:vector3-equal (xna:vector3-backward) (xna:make-vector3 0 0 1))))

(defobservation "vector3.normalize-reciprocal" :xna-derived
    "Microsoft.Xna.Framework.Vector3"
  "Normalize takes the reciprocal of the *binary32* square root and multiplies;
   it does not divide each component by a binary64 root."
  (let* ((v (xna:make-vector3 1 2 3))
         (scale (/ 1.0f0 (coerce (sqrt (coerce (xna:vector3-length-squared v)
                                               'double-float))
                                 'single-float)))
         (n (xna:vector3-normalized v)))
    (and (= (* 1.0f0 scale) (xna:vector3-x n))
         (= (* 3.0f0 scale) (xna:vector3-z n)))))

(defobservation "vector3.normalize-instance-mutates" :xna-derived
    "Microsoft.Xna.Framework.Vector3"
  "The instance Normalize mutates the receiver; the static one answers a new
   vector and leaves its argument alone."
  (let ((v (xna:make-vector3 3 4 0)))
    (xna:vector3-normalize v)
    (and (= 0.6f0 (xna:vector3-x v))
         (let ((w (xna:make-vector3 3 4 0)))
           (xna:vector3-normalized w)
           (= 3.0f0 (xna:vector3-x w))))))

(defobservation "vector3.cross-right-handed" :xna-derived "Microsoft.Xna.Framework.Vector3"
  "UnitX cross UnitY is UnitZ."
  (xna:vector3-equal (xna:vector3-cross (xna:vector3-unit-x) (xna:vector3-unit-y))
                     (xna:vector3-unit-z)))

(defobservation "vector3.reflect-shape" :xna-derived "Microsoft.Xna.Framework.Vector3"
  "Reflect doubles the dot product before scaling the normal: v - (2 * d) * n."
  (let* ((v (xna:make-vector3 0.3 0.7 0.11))
         (n (xna:make-vector3 0.5 0.25 0.125))
         (d (xna:vector3-dot v n)))
    (= (- (xna:vector3-x v) (* (* 2.0f0 d) (xna:vector3-x n)))
       (xna:vector3-x (xna:vector3-reflect v n)))))

(defobservation "vector.divide-scalar-reciprocal" :xna-derived
    "Microsoft.Xna.Framework.Vector3"
  "Divide by a scalar takes one reciprocal and multiplies."
  (= (* 1.0f0 (/ 1.0f0 3.0f0))
     (xna:vector3-x (xna:vector3-divide (xna:make-vector3 1 1 1) 3.0f0))))

(defobservation "quaternion.concatenate-reverses" :xna-derived
    "Microsoft.Xna.Framework.Quaternion"
  "Concatenate(a, b) is the Hamilton product with the operands reversed: it reads
   its *second* argument into the slots Multiply reads its first from."
  (let ((a (xna:quaternion-create-from-axis-angle (xna:vector3-unit-x) 0.5))
        (b (xna:quaternion-create-from-axis-angle (xna:vector3-unit-y) 0.7)))
    (xna:quaternion-equal (xna:quaternion-concatenate a b)
                          (xna:quaternion-multiply b a))))

(defobservation "quaternion.inverse-divides-by-length-squared" :xna-derived
    "Microsoft.Xna.Framework.Quaternion"
  "Inverse scales the conjugate by the reciprocal of the *squared* length; no
   square root is taken."
  (= 0.5f0 (xna:quaternion-w (xna:quaternion-inverse (xna:make-quaternion 0 0 0 2)))))

(defobservation "quaternion.slerp-threshold" :xna-derived
    "Microsoft.Xna.Framework.Quaternion"
  "Slerp treats quaternions whose dot product exceeds 0.999999f as parallel and
   interpolates linearly without normalising."
  (let* ((a (xna:quaternion-identity))
         (b (xna:quaternion-identity))
         (mid (xna:quaternion-slerp a b 0.5)))
    (= 1.0f0 (xna:quaternion-w mid))))

(defobservation "matrix.translation-in-the-fourth-row" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "XNA matrices are row-major and multiplied on the left by a row vector, so the
   translation is M41 M42 M43 -- not the fourth column."
  (let ((m (xna:matrix-create-translation (xna:make-vector3 1 2 3))))
    (and (= 1.0f0 (xna:matrix-m41 m)) (= 0.0f0 (xna:matrix-m14 m)))))

(defobservation "matrix.multiply-applies-the-left-first" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "Multiply(a, b) applies a and then b."
  (let ((point (xna:make-vector3 1 0 0)))
    (xna:vector3-equal
     (xna:vector3-transform point (xna:matrix-multiply
                                   (xna:matrix-create-scale 2)
                                   (xna:matrix-create-translation
                                    (xna:make-vector3 1 0 0))))
     (xna:make-vector3 3 0 0))))

(defobservation "matrix.forward-is-negated-third-row" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "Matrix.Forward is the negated third row and Backward is the third row."
  (let ((m (xna:matrix-identity)))
    (and (xna:vector3-equal (xna:matrix-forward m) (xna:make-vector3 0 0 -1))
         (xna:vector3-equal (xna:matrix-backward m) (xna:make-vector3 0 0 1)))))

(defobservation "matrix.perspective-range-checks" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "CreatePerspectiveFieldOfView refuses a field of view outside (0, pi), a
   non-positive plane distance, and a near plane at or beyond the far plane."
  (flet ((refused (&rest arguments)
           (handler-case (progn (apply #'xna:matrix-create-perspective-field-of-view
                                       arguments)
                                nil)
             (xna:cna-argument-out-of-range-error () t))))
    (and (refused 0.0 1.0 1.0 100.0)
         (refused xna:+math-helper-pi+ 1.0 1.0 100.0)
         (refused 1.0 1.0 0.0 100.0)
         (refused 1.0 1.0 100.0 1.0))))

(defobservation "matrix.perspective-clip-volume" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "XNA's clip space runs z from 0 at the near plane to w at the far plane, unlike
   OpenGL's -w to w."
  (let* ((projection (xna:matrix-create-perspective-field-of-view
                      xna:+math-helper-pi-over4+ 1.0 1.0 100.0))
         (near (xna:vector4-transform (xna:make-vector3 0 0 -1) projection)))
    (< (abs (xna:vector4-z near)) 1.0e-4)))

(defobservation "vector4.transform-extends-with-w-one" :xna-derived
    "Microsoft.Xna.Framework.Vector4"
  "A Vector2 or Vector3 transformed into a Vector4 is extended with W = 1, so the
   translation applies; a Vector4 keeps its own W."
  (let ((m (xna:matrix-create-translation (xna:make-vector3 1 2 3))))
    (and (= 1.0f0 (xna:vector4-x (xna:vector4-transform (xna:make-vector2 0 0) m)))
         (= 0.0f0 (xna:vector4-x (xna:vector4-transform (xna:make-vector4 0 0 0 0) m))))))

;;; --- ABI-derived ---------------------------------------------------------

(defobservation "abi.keys-values" :abi-derived "CNA_KEY_*"
  "Keys carries the Windows virtual-key values: Escape is 27 and A is 65."
  (and (= 27 (input:keys-value :escape)) (= 65 (input:keys-value :a))))

(defobservation "abi.sprite-effects-flags" :abi-derived "CNA_SPRITE_EFFECT_*"
  "SpriteEffects is a real flags enum: the two flips are bit 0 and bit 1."
  (and (= 1 (gfx:sprite-effects-value :flip-horizontally))
       (= 2 (gfx:sprite-effects-value :flip-vertically))))

(defobservation "abi.color-is-four-bytes" :abi-derived "CNA_Color"
  "CNA_Color is four bytes, one per channel, so its packed value is one 32-bit
   store."
  (= 4 (second (assoc 'ffi::cna-color ffi:*native-struct-layouts*))))

(defobservation "abi.string-view-is-pointer-and-length" :abi-derived "CNA_StringView"
  "CNA_StringView is sixteen bytes: a pointer at 0 and a byte count at 8."
  (let ((row (assoc 'ffi::cna-string-view ffi:*native-struct-layouts*)))
    (and (= 16 (second row))
         (equal '(0 8) (list (second (assoc 'ffi::data (fourth row)))
                             (second (assoc 'ffi::byte-length (fourth row))))))))

;;; --- mapping decisions ---------------------------------------------------

(defobservation "mapping.enum-is-a-keyword" :mapping "enumerations"
  "An enum member is a keyword and its type is a Common Lisp type."
  (and (typep :deferred 'gfx:sprite-sort-mode)
       (not (typep :nonsense 'gfx:sprite-sort-mode))))

(defobservation "mapping.flags-are-lists" :mapping "flags enumerations"
  "A flags enum member set is a list of keywords."
  (= 3 (gfx:sprite-effects-value '(:flip-horizontally :flip-vertically))))

(defobservation "mapping.static-class-prefix" :mapping "static classes"
  "A static class member is a package function named <class>-<member>."
  (fboundp 'input:keyboard-get-state))

(defobservation "mapping.overload-split" :mapping
    "Microsoft.Xna.Framework.Rectangle.Contains"
  "The three-argument overload is a separate function, because it cannot share a
   congruent generic function with the two-argument ones."
  (and (typep (fdefinition 'xna:rectangle-contains) 'generic-function)
       (not (typep (fdefinition 'xna:rectangle-contains-coordinates)
                   'generic-function))))

(defobservation "mapping.conditions-not-codes" :mapping "failures"
  "Failures are conditions; no result code is publicly readable."
  (and (subtypep 'xna:cna-native-error 'xna:cna-error)
       (null (find-symbol "CNA-ERROR-RESULT" '#:microsoft.xna.framework))))

;;; --- running the corpus --------------------------------------------------

(test the-behaviour-corpus-holds
  (let ((failures '()))
    (dolist (observation *corpus*)
      (handler-case
          (unless (funcall (observation-thunk observation))
            (push (observation-id observation) failures))
        (error (condition)
          (push (list (observation-id observation) condition) failures))))
    (is (null failures) "behaviour observations that do not hold: ~s" failures)))

(test the-corpus-records-an-origin-for-every-observation
  (dolist (observation *corpus*)
    (is (member (observation-origin observation) '(:xna-derived :mapping :abi-derived))
        "~a has no recognised origin" (observation-id observation))))

(test the-corpus-separates-xna-from-mapping
  ;; If every observation were a mapping observation the corpus would be
  ;; measuring the binding against itself.
  (let ((xna (count :xna-derived *corpus* :key #'observation-origin)))
    (is (plusp xna) "the corpus records no XNA-derived observation at all")))
