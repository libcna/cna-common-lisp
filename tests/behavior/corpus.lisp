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

(defobservation "boundingsphere.contains-point-is-strict" :xna-derived
    "Microsoft.Xna.Framework.BoundingSphere"
  "Contains(Vector3) compares the squared distance with a strict <, so a point
   exactly on the surface is Disjoint, not Contains."
  (let ((unit (xna:make-bounding-sphere (xna:make-vector3 0 0 0) 1.0)))
    (and (eq :contains (xna:bounding-sphere-contains unit (xna:make-vector3 0.5 0 0)))
         (eq :disjoint (xna:bounding-sphere-contains unit (xna:make-vector3 1 0 0))))))

(defobservation "boundingbox.contains-point-is-inclusive" :xna-derived
    "Microsoft.Xna.Framework.BoundingBox"
  "Contains(Vector3) is inclusive on every face, unlike BoundingSphere's."
  (eq :contains (xna:bounding-box-contains
                 (xna:make-bounding-box (xna:make-vector3 0 0 0) (xna:make-vector3 1 1 1))
                 (xna:make-vector3 1 1 1))))

(defobservation "boundingbox.corner-order" :xna-derived
    "Microsoft.Xna.Framework.BoundingBox"
  "GetCorners returns the eight corners in a fixed order beginning
   (Min.X, Max.Y, Max.Z) and ending (Min.X, Min.Y, Min.Z); callers index into it."
  (let ((corners (xna:bounding-box-get-corners
                  (xna:make-bounding-box (xna:make-vector3 -1 -2 -3)
                                         (xna:make-vector3 1 2 3)))))
    (and (= 8 (length corners))
         (= -1.0f0 (xna:vector3-x (aref corners 0)))
         (=  3.0f0 (xna:vector3-z (aref corners 0)))
         (= -3.0f0 (xna:vector3-z (aref corners 7)))
         (= -2.0f0 (xna:vector3-y (aref corners 7))))))

(defobservation "boundingbox.contains-sphere-repeats-the-x-extent" :xna-derived
    "Microsoft.Xna.Framework.BoundingBox"
  "Contains(BoundingSphere) tests Max.X - Min.X against the radius twice, the
   second time where the Z extent belongs. The only inputs that can see the
   difference are a zero radius against a box with no thickness in Z, where XNA
   answers Contains."
  (eq :contains
      (xna:bounding-box-contains
       (xna:make-bounding-box (xna:make-vector3 -10 -10 5) (xna:make-vector3 10 10 5))
       (xna:make-bounding-sphere (xna:make-vector3 0 0 5) 0.0))))

(defobservation "ray.intersects-plane-clamps-a-small-negative" :xna-derived
    "Microsoft.Xna.Framework.Ray"
  "Intersects(Plane) rejects a direction within 1e-5 of parallel, and clamps a
   distance between -1e-5 and 0 up to 0 rather than reporting a miss."
  (let ((plane (xna:make-plane 0 1 0 0)))
    (and (null (xna:ray-intersects (xna:make-ray (xna:make-vector3 0 5 0)
                                                 (xna:make-vector3 1 0 0))
                                   plane))
         (eql 0.0f0 (xna:ray-intersects (xna:make-ray (xna:make-vector3 0 0 0)
                                                      (xna:make-vector3 0 -1 0))
                                        plane)))))

(defobservation "ray.starting-inside-answers-zero" :xna-derived
    "Microsoft.Xna.Framework.Ray"
  "A ray whose position is already inside a sphere or a box answers 0, not the
   distance to the far surface."
  (and (eql 0.0f0 (xna:ray-intersects
                   (xna:make-ray (xna:make-vector3 0 0 0) (xna:make-vector3 1 0 0))
                   (xna:make-bounding-sphere (xna:make-vector3 0 0 0) 1.0)))
       (eql 0.0f0 (xna:ray-intersects
                   (xna:make-ray (xna:make-vector3 0 0 0) (xna:make-vector3 1 0 0))
                   (xna:make-bounding-box (xna:make-vector3 -1 -1 -1)
                                          (xna:make-vector3 1 1 1))))))

(defobservation "boundingsphere.transform-uses-the-largest-row" :xna-derived
    "Microsoft.Xna.Framework.BoundingSphere"
  "Transform scales the radius by the longest of the matrix's three basis rows,
   so a non-uniform scale grows the sphere to the largest axis."
  (let ((scaled (xna:bounding-sphere-transform
                 (xna:make-bounding-sphere (xna:make-vector3 0 0 0) 2.0)
                 (xna:matrix-create-scale 1 3 2))))
    (< (abs (- 6.0f0 (xna:bounding-sphere-radius scaled))) 1.0e-5)))

(defobservation "boundingsphere.merge-keeps-the-containing-sphere" :xna-derived
    "Microsoft.Xna.Framework.BoundingSphere"
  "CreateMerged returns the original sphere unchanged when one already contains
   the other, in either argument order."
  (let ((big (xna:make-bounding-sphere (xna:make-vector3 0 0 0) 5.0))
        (small (xna:make-bounding-sphere (xna:make-vector3 1 0 0) 1.0)))
    (and (xna:bounding-sphere-equal (xna:bounding-sphere-create-merged big small) big)
         (xna:bounding-sphere-equal (xna:bounding-sphere-create-merged small big) big))))

(defobservation "boundingfrustum.is-a-reference-type" :xna-derived
    "Microsoft.Xna.Framework.BoundingFrustum"
  "BoundingFrustum is a class, not a value type: two names for one frustum see
   one another's changes, and assigning Matrix rebuilds its planes and corners."
  (let* ((frustum (make-instance 'xna:bounding-frustum
                                 :matrix (xna:matrix-create-perspective-field-of-view
                                          xna:+math-helper-pi-over4+ 1.0 1.0 20.0)))
         (alias frustum)
         (before (xna:vector3-z (aref (xna:bounding-frustum-get-corners frustum) 4))))
    (setf (xna:bounding-frustum-matrix alias)
          (xna:matrix-create-perspective-field-of-view
           xna:+math-helper-pi-over4+ 1.0 1.0 40.0))
    (/= before (xna:vector3-z (aref (xna:bounding-frustum-get-corners frustum) 4)))))

(defobservation "boundingfrustum.corner-order" :xna-derived
    "Microsoft.Xna.Framework.BoundingFrustum"
  "GetCorners answers the near face first (0-3) and the far face second (4-7),
   each running top-left, top-right, bottom-right, bottom-left."
  (let* ((frustum (make-instance 'xna:bounding-frustum
                                 :matrix (xna:matrix-multiply
                                          (xna:matrix-create-look-at
                                           (xna:make-vector3 0 0 5)
                                           (xna:make-vector3 0 0 0)
                                           (xna:make-vector3 0 1 0))
                                          (xna:matrix-create-perspective-field-of-view
                                           xna:+math-helper-pi-over4+ 1.0 1.0 20.0))))
         (c (xna:bounding-frustum-get-corners frustum)))
    (and (= 8 (length c))
         (< (abs (- 4.0f0 (xna:vector3-z (aref c 0)))) 1.0e-4)
         (< (abs (- -15.0f0 (xna:vector3-z (aref c 4)))) 1.0e-3)
         (< (xna:vector3-x (aref c 0)) 0) (> (xna:vector3-y (aref c 0)) 0)
         (> (xna:vector3-x (aref c 2)) 0) (< (xna:vector3-y (aref c 2)) 0))))

(defobservation "boundingfrustum.planes-are-normalised-and-outward" :xna-derived
    "Microsoft.Xna.Framework.BoundingFrustum"
  "The six planes are normalised as the frustum is built, and they face
   outwards: a point inside is on the negative side of every one."
  (let ((frustum (make-instance 'xna:bounding-frustum
                                :matrix (xna:matrix-multiply
                                         (xna:matrix-create-look-at
                                          (xna:make-vector3 0 0 5)
                                          (xna:make-vector3 0 0 0)
                                          (xna:make-vector3 0 1 0))
                                         (xna:matrix-create-perspective-field-of-view
                                          xna:+math-helper-pi-over4+ 1.0 1.0 20.0)))))
    (every (lambda (reader)
             (let ((plane (funcall reader frustum)))
               (and (< (abs (- 1.0f0 (xna:vector3-length (xna:plane-normal plane))))
                       1.0e-5)
                    (< (+ (xna:vector3-dot (xna:plane-normal plane)
                                           (xna:make-vector3 0 0 0))
                          (xna:plane-d plane))
                       0.0f0))))
           (list #'xna:bounding-frustum-near #'xna:bounding-frustum-far
                 #'xna:bounding-frustum-left #'xna:bounding-frustum-right
                 #'xna:bounding-frustum-top #'xna:bounding-frustum-bottom))))

(defobservation "boundingfrustum.contains-and-intersects-disagree" :xna-derived
    "Microsoft.Xna.Framework.BoundingFrustum"
  "Contains(BoundingBox) is a plane-by-plane test and Intersects(BoundingBox) is
   a GJK iteration with a relative tolerance, so the two answer different
   questions and disagree in both directions on boxes near the boundary."
  (let ((frustum (make-instance 'xna:bounding-frustum
                                :matrix (xna:matrix-multiply
                                         (xna:matrix-create-look-at
                                          (xna:make-vector3 0 0 5)
                                          (xna:make-vector3 0 0 0)
                                          (xna:make-vector3 0 1 0))
                                         (xna:matrix-create-perspective-field-of-view
                                          xna:+math-helper-pi-over4+ 1.0 1.0 20.0))))
        (corner-box (xna:make-bounding-box (xna:make-vector3 -7.3 -12.3 -17.8)
                                           (xna:make-vector3 -3.7 -8.7 -14.2))))
    (and (eq :intersects (xna:bounding-frustum-contains frustum corner-box))
         (not (xna:bounding-frustum-intersects frustum corner-box)))))

(defobservation "boundingfrustum.ray-inside-answers-zero" :xna-derived
    "Microsoft.Xna.Framework.BoundingFrustum"
  "Intersects(Ray) answers 0 for a ray whose position the frustum Contains, and
   otherwise the distance to the entry plane."
  (let ((frustum (make-instance 'xna:bounding-frustum
                                :matrix (xna:matrix-multiply
                                         (xna:matrix-create-look-at
                                          (xna:make-vector3 0 0 5)
                                          (xna:make-vector3 0 0 0)
                                          (xna:make-vector3 0 1 0))
                                         (xna:matrix-create-perspective-field-of-view
                                          xna:+math-helper-pi-over4+ 1.0 1.0 20.0)))))
    (and (eql 0.0f0 (xna:bounding-frustum-intersects
                     frustum (xna:make-ray (xna:make-vector3 0 0 0)
                                           (xna:make-vector3 0 0 -1))))
         (< (abs (- 196.0f0 (xna:bounding-frustum-intersects
                             frustum (xna:make-ray (xna:make-vector3 0 0 200)
                                                   (xna:make-vector3 0 0 -1)))))
            1.0e-3))))

(defobservation "color.float-constructors-round-half-to-even" :xna-derived
    "Microsoft.Xna.Framework.Color"
  "The float constructors pack through PackUNorm, which multiplies by 255 and
   rounds with Math.Round(double) -- half to even. So 0.5/255 packs to 0 and
   1.5/255 packs to 2."
  (and (= 0 (xna:color-r (xna:make-color-from-floats (/ 0.5 255.0) 0.0 0.0)))
       (= 2 (xna:color-r (xna:make-color-from-floats (/ 1.5 255.0) 0.0 0.0)))
       (= 2 (xna:color-r (xna:make-color-from-floats (/ 2.5 255.0) 0.0 0.0)))))

(defobservation "color.multiply-is-fixed-point" :xna-derived
    "Microsoft.Xna.Framework.Color"
  "Multiply truncates the scale into a 16.16 fixed-point factor and shifts the
   integer product right by 16, so half of white is 127 rather than 128."
  (= 127 (xna:color-r (xna:color-multiply (xna:white) 0.5))))

(defobservation "color.from-non-premultiplied-truncates" :xna-derived
    "Microsoft.Xna.Framework.Color"
  "FromNonPremultiplied(int, int, int, int) multiplies the unclamped channel by
   the unclamped alpha, divides by 255 with integer truncation, and clamps only
   the quotient."
  (and (= 3 (xna:color-r (xna:color-from-non-premultiplied 5 0 0 200)))
       (= 117 (xna:color-r (xna:color-from-non-premultiplied 300 0 0 100)))))

(defobservation "color.lerp-shift-floors" :xna-derived
    "Microsoft.Xna.Framework.Color"
  "Lerp interpolates in integer arithmetic with an arithmetic right shift, which
   floors: a thousandth of the way from white to black already costs a level,
   while the same step up from black costs nothing."
  (and (= 254 (xna:color-r (xna:color-lerp (xna:white) (xna:black) 0.001)))
       (= 0 (xna:color-r (xna:color-lerp (xna:black) (xna:white) 0.001)))))

(defobservation "rectangle.intersect-loses-its-position" :xna-derived
    "Microsoft.Xna.Framework.Rectangle"
  "Intersect answers Rectangle(0, 0, 0, 0) when the two do not overlap, so an
   empty intersection has no position -- and touching edges do not overlap."
  (let ((none (xna:rectangle-intersect (xna:make-rectangle 100 100 10 10)
                                       (xna:make-rectangle 500 500 10 10))))
    (and (xna:rectangle-equal (xna:make-rectangle 0 0 0 0) none)
         (xna:rectangle-is-empty
          (xna:rectangle-intersect (xna:make-rectangle 0 0 10 10)
                                   (xna:make-rectangle 10 0 10 10))))))

(defobservation "rectangle.union-has-no-empty-case" :xna-derived
    "Microsoft.Xna.Framework.Rectangle"
  "Union computes over the four edges with no special case, so a union with the
   all-zero rectangle stretches the answer to the origin."
  (xna:rectangle-equal (xna:make-rectangle 0 0 110 110)
                       (xna:rectangle-union (xna:make-rectangle 100 100 10 10)
                                            (xna:make-rectangle 0 0 0 0))))

(defobservation "matrix.decompose-fills-in-on-failure" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "Decompose answers false for a matrix with no scale-rotate-translate form, and
   still fills in the scale and the translation it computed, with the rotation
   set to the identity."
  (multiple-value-bind (ok scale rotation translation)
      (xna:matrix-decompose (xna:make-matrix 1 1 0 0  0 1 0 0  0 0 1 0  0 0 0 1))
    (declare (ignore translation))
    (and (null ok)
         (< (abs (- (sqrt 2.0f0) (xna:vector3-x scale))) 1.0e-5)
         (= 1.0f0 (xna:quaternion-w rotation)))))

(defobservation "matrix.decompose-reports-a-mirror-as-negative-scale" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "A left-handed matrix is not refused: Decompose flips the longest axis and its
   scale, so a mirror answers a negative scale and no rotation."
  (multiple-value-bind (ok scale rotation)
      (xna:matrix-decompose (xna:matrix-create-scale -1 1 1))
    (and ok (= -1.0f0 (xna:vector3-x scale))
         (< (abs (- 1.0f0 (abs (xna:quaternion-w rotation)))) 1.0e-5))))

(defobservation "matrix.constrained-billboard-substitution-order" :xna-derived
    "Microsoft.Xna.Framework.Matrix"
  "When the view direction is parallel to the rotation axis, CreateConstrainedBillboard
   substitutes the object's forward vector, or Vector3.Forward when that is
   parallel to the axis too, or Vector3.Right when the axis is parallel to
   Forward."
  (let ((from-object (xna:matrix-create-constrained-billboard
                      (xna:make-vector3 0 0 0) (xna:make-vector3 0 10 0)
                      (xna:make-vector3 0 1 0) nil (xna:make-vector3 1 0 0)))
        (from-forward (xna:matrix-create-constrained-billboard
                       (xna:make-vector3 0 0 0) (xna:make-vector3 0 10 0)
                       (xna:make-vector3 0 1 0)))
        (from-right (xna:matrix-create-constrained-billboard
                     (xna:make-vector3 0 0 0) (xna:make-vector3 0 0 0)
                     (xna:make-vector3 0 0 1))))
    (and (< (abs (- -1.0f0 (xna:matrix-m13 from-object))) 1.0e-5)
         (< (abs (- -1.0f0 (xna:matrix-m11 from-forward))) 1.0e-5)
         (< (abs (- 1.0f0 (xna:matrix-m12 from-right))) 1.0e-5))))

(defobservation "curve.step-continuity-steps-at-the-segment-end" :xna-derived
    "Microsoft.Xna.Framework.Curve"
  "A key with CurveContinuity.Step makes the segment after it hold that key's
   value until the next key, because the test is `amount < 1' rather than a
   midpoint."
  (let ((curve (make-instance 'xna:curve)))
    (xna:curve-key-collection-add (xna:curve-keys curve)
                                  (make-instance 'xna:curve-key :position 0.0 :value 0.0
                                                                :continuity :step))
    (xna:curve-key-collection-add (xna:curve-keys curve)
                                  (make-instance 'xna:curve-key :position 1.0 :value 10.0))
    (and (= 0.0f0 (xna:curve-evaluate curve 0.999))
         (= 10.0f0 (xna:curve-evaluate curve 1.0)))))

(defobservation "curve.cycle-offset-drifts" :xna-derived
    "Microsoft.Xna.Framework.Curve"
  "CurveLoopType.CycleOffset folds the position back into the key range like
   Cycle and then adds one whole first-to-last value change per cycle, so a
   looping curve drifts instead of repeating."
  (let ((curve (make-instance 'xna:curve)))
    (dolist (spec '((0.0 0.0) (1.0 2.0) (2.0 3.0)))
      (xna:curve-key-collection-add
       (xna:curve-keys curve)
       (make-instance 'xna:curve-key :position (first spec) :value (second spec))))
    (xna:curve-compute-tangents curve :linear)
    (setf (xna:curve-post-loop curve) :cycle)
    (let ((cycled (xna:curve-evaluate curve 2.5)))
      (setf (xna:curve-post-loop curve) :cycle-offset)
      (< (abs (- (+ cycled 3.0f0) (xna:curve-evaluate curve 2.5))) 1.0e-4))))

(defobservation "curve.smooth-tangent-is-flat-at-an-end-key" :xna-derived
    "Microsoft.Xna.Framework.Curve"
  "ComputeTangents(Smooth) scales the neighbouring value change by each side's
   share of the neighbouring position span, and an end key's neighbour on the
   outer side is itself, so that tangent is zero rather than a mirror."
  (let ((curve (make-instance 'xna:curve)))
    (dolist (spec '((0.0 0.0) (1.0 1.0) (2.0 0.0)))
      (xna:curve-key-collection-add
       (xna:curve-keys curve)
       (make-instance 'xna:curve-key :position (first spec) :value (second spec))))
    (xna:curve-compute-tangents curve :smooth)
    (let ((first-key (xna:curve-key-collection-item (xna:curve-keys curve) 0)))
      (and (= 0.0f0 (xna:curve-key-tangent-in first-key))
           (= 1.0f0 (xna:curve-key-tangent-out first-key))))))

(defobservation "curvekeycollection.duplicate-positions-go-last" :xna-derived
    "Microsoft.Xna.Framework.CurveKeyCollection"
  "The collection sorts by position, allows duplicates, and inserts a new key
   after every key already at its position."
  (let ((keys (make-instance 'xna:curve-key-collection)))
    (dolist (spec '((1.0 10.0) (0.0 0.0) (1.0 99.0)))
      (xna:curve-key-collection-add
       keys (make-instance 'xna:curve-key :position (first spec) :value (second spec))))
    (and (= 3 (xna:curve-key-collection-count keys))
         (= 0.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 0)))
         (= 10.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 1)))
         (= 99.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 2))))))

(defobservation "packedvector.half-is-not-binary16" :xna-derived
    "Microsoft.Xna.Framework.Graphics.PackedVector.HalfSingle"
  "XNA's 16-bit half has no infinity and no NaN: an exponent of 31 means 2^16
   rather than a special value, so the format reaches 131008 where IEEE 754
   binary16 stops at 65504, and anything larger saturates there."
  (and (= 65504.0f0 (pv:half-single-to-single (pv:make-half-single 65504.0)))
       (= 70016.0f0 (pv:half-single-to-single (pv:make-half-single 70000.0)))
       (= 131008.0f0 (pv:half-single-to-single (pv:make-half-single 200000.0)))
       (= 131008.0f0 (pv:half-single-to-single
                      (pv:make-half-single
                       (cna-lisp.internal:bits-single-float #x7F800000))))))

(defobservation "packedvector.signed-normalised-reserves-a-code-point" :xna-derived
    "Microsoft.Xna.Framework.Graphics.PackedVector.NormalizedByte2"
  "PackSNorm clamps to plus or minus half the range, so -1.0 packs to 0x81 and
   the pattern below it is never produced; UnpackSNorm reads that reserved
   pattern back as exactly -1.0."
  (and (= #x81 (pv:normalized-byte2-packed-value (pv:make-normalized-byte2 -1.0 0.0)))
       (= -1.0f0 (xna:vector2-x (pv:normalized-byte2-to-vector2
                                 (pv:make-normalized-byte2 -1.0 0.0))))))

(defobservation "packedvector.rounds-half-to-even" :xna-derived
    "Microsoft.Xna.Framework.Graphics.PackedVector.Alpha8"
  "Every packed conversion rounds through Math.Round(double), which rounds halves
   to even, so the half-way inputs land on the even code point either side."
  (and (= 0 (pv:alpha8-packed-value (pv:make-alpha8 (/ 0.5 255.0))))
       (= 2 (pv:alpha8-packed-value (pv:make-alpha8 (/ 1.5 255.0))))
       (= 2 (pv:alpha8-packed-value (pv:make-alpha8 (/ 2.5 255.0))))))

(defobservation "packedvector.bgr565-layout" :xna-derived
    "Microsoft.Xna.Framework.Graphics.PackedVector.Bgr565"
  "Bgr565 puts five bits of X at the top of the word, six of Y in the middle and
   five of Z at the bottom -- the reverse of the component order every non-Bgr
   packed type uses."
  (and (= #xF800 (pv:bgr565-packed-value (pv:make-bgr565 1.0 0.0 0.0)))
       (= #x07E0 (pv:bgr565-packed-value (pv:make-bgr565 0.0 1.0 0.0)))
       (= #x001F (pv:bgr565-packed-value (pv:make-bgr565 0.0 0.0 1.0)))))

(defobservation "gamepad.buttons-values-are-the-contracts" :xna-derived
    "Microsoft.Xna.Framework.Input.Buttons"
  "The Buttons flags enum's values are XNA's own, so a saved input binding keeps
   meaning the same thing: A is 0x1000, DPadUp is 1, LeftTrigger is 0x800000."
  (and (= #x1000 (input:buttons-value :a))
       (= #x8000 (input:buttons-value :y))
       (= 1 (input:buttons-value :dpad-up))
       (= #x800000 (input:buttons-value :left-trigger))
       (= 25 (length (input:all-buttons)))))

(defobservation "gamepad.type-values-jump-at-big-button-pad" :xna-derived
    "Microsoft.Xna.Framework.Input.GamePadType"
  "GamePadType runs 0 through 8 and then jumps to 0x300 for BigButtonPad, which
   is not the consecutive numbering the C ABI uses."
  (and (= 8 (input:game-pad-type-value :drum-kit))
       (= #x300 (input:game-pad-type-value :big-button-pad))))

(defobservation "gamepad.buttons-cannot-hold-a-dpad-bit" :xna-derived
    "Microsoft.Xna.Framework.Input.GamePadButtons"
  "GamePadButtons is eleven separate ButtonState fields, so it has nowhere to put
   a directional-pad member and its equality cannot see one."
  (input:game-pad-buttons-equal (input:make-game-pad-buttons '(:a :dpad-up))
                                (input:make-game-pad-buttons '(:a))))

(defobservation "touch.collection-is-a-mutable-value" :xna-derived
    "Microsoft.Xna.Framework.Input.Touch.TouchCollection"
  "TouchCollection is a value type that also implements IList<TouchLocation>, so
   a caller may add to and remove from a copy of what the panel reported, and a
   copy is a copy rather than an alias."
  (let* ((original (touch:make-touch-collection
                    (list (touch:make-touch-location 1 :pressed (xna:make-vector2)))))
         (copy (touch:copy-touch-collection original)))
    (touch:touch-collection-add
     copy (touch:make-touch-location 2 :pressed (xna:make-vector2)))
    (and (= 1 (touch:touch-collection-count original))
         (= 2 (touch:touch-collection-count copy))
         (not (touch:touch-collection-is-read-only original)))))

(defobservation "touch.location-equality-ignores-the-previous-location" :xna-derived
    "Microsoft.Xna.Framework.Input.Touch.TouchLocation"
  "TouchLocation compares its id, its state and its position, so two snapshots of
   one finger differ only when the finger did -- the previous location it carries
   is not part of the comparison."
  (touch:touch-location-equal
   (touch:make-touch-location 1 :moved (xna:make-vector2 5.0 5.0))
   (touch:make-touch-location 1 :moved (xna:make-vector2 5.0 5.0)
                              :pressed (xna:make-vector2 0.0 0.0))))

(defobservation "displayorientation.portrait-is-four" :xna-derived
    "Microsoft.Xna.Framework.DisplayOrientation"
  "DisplayOrientation is a flags enum: Default 0, LandscapeLeft 1,
   LandscapeRight 2 and Portrait 4 -- not the consecutive 3 a plain enum would
   give it."
  (and (= 0 (xna:display-orientation-value :default))
       (= 1 (xna:display-orientation-value :landscape-left))
       (= 2 (xna:display-orientation-value :landscape-right))
       (= 4 (xna:display-orientation-value :portrait))))

(defobservation "viewport.project-flips-the-y-axis" :xna-derived
    "Microsoft.Xna.Framework.Graphics.Viewport"
  "Project maps clip space to screen coordinates with Y inverted -- a point above
   the camera's centre projects to a smaller screen Y -- and maps depth into the
   viewport's own MinDepth..MaxDepth rather than leaving it in 0 to 1."
  (let ((viewport (gfx:make-viewport 0 0 800 480 0.25 0.75))
        (projection (xna:matrix-create-perspective-field-of-view
                     xna:+math-helper-pi-over4+ (/ 800.0 480.0) 1.0 100.0))
        (view (xna:matrix-create-look-at (xna:make-vector3 0 0 10)
                                         (xna:make-vector3 0 0 0)
                                         (xna:make-vector3 0 1 0)))
        (world (xna:matrix-identity)))
    (let ((up (gfx:viewport-project viewport (xna:make-vector3 0 1 0)
                                    projection view world))
          (centre (gfx:viewport-project viewport (xna:make-vector3 0 0 0)
                                        projection view world)))
      (and (< (xna:vector3-y up) (xna:vector3-y centre))
           (< 0.25f0 (xna:vector3-z centre) 0.75f0)))))

(defobservation "viewport.within-epsilon-is-exact-equality" :xna-derived
    "Microsoft.Xna.Framework.Graphics.Viewport"
  "Project skips the perspective divide only when the homogeneous w is exactly
   one: WithinEpsilon compares against 1.401298e-45, the smallest positive
   subnormal, which for any ordinary number is exact equality. Under an identity
   transform the arithmetic is therefore exact."
  (let ((screen (gfx:viewport-project (gfx:make-viewport 0 0 2 2)
                                      (xna:make-vector3 0.5 0.25 0.75)
                                      (xna:matrix-identity) (xna:matrix-identity)
                                      (xna:matrix-identity))))
    (and (= 1.5f0 (xna:vector3-x screen))
         (= 0.75f0 (xna:vector3-y screen))
         (= 0.75f0 (xna:vector3-z screen)))))

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
