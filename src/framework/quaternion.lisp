;;;; quaternion.lisp --- Microsoft.Xna.Framework.Quaternion.
;;;;
;;;; Read from the pinned XNA 4.0 Windows IL. The multiplication order, the
;;;; branch conditions in Slerp and CreateFromRotationMatrix, and the exact
;;;; 0.999999f threshold are the framework's own; a quaternion library written
;;;; from first principles agrees with none of them bit for bit.

(in-package #:microsoft.xna.framework)

(defstruct (quaternion (:constructor %make-quaternion (x y z w))
                       (:copier copy-quaternion))
  "Microsoft.Xna.Framework.Quaternion."
  (x 0.0f0 :type single-float)
  (y 0.0f0 :type single-float)
  (z 0.0f0 :type single-float)
  (w 0.0f0 :type single-float))

(defun make-quaternion (&optional (x 0.0f0) (y 0.0f0) (z 0.0f0) (w 0.0f0))
  "Quaternion(float, float, float, float)."
  (%make-quaternion (f x) (f y) (f z) (f w)))

(defun make-quaternion-from-vector3 (vector3 w)
  "Quaternion(Vector3, float): the vector part and the scalar part."
  (%make-quaternion (vector3-x vector3) (vector3-y vector3) (vector3-z vector3) (f w)))

(defun quaternion-identity ()
  "Quaternion.Identity."
  (%make-quaternion 0.0f0 0.0f0 0.0f0 1.0f0))

(defmacro %with-q ((x y z w) quaternion &body body)
  `(let ((,x (quaternion-x ,quaternion)) (,y (quaternion-y ,quaternion))
         (,z (quaternion-z ,quaternion)) (,w (quaternion-w ,quaternion)))
     ,@body))

(defun quaternion-length-squared (quaternion)
  "Quaternion.LengthSquared."
  (cna-lisp.internal:with-binary32-semantics
    (%with-q (x y z w) quaternion (+ (+ (+ (* x x) (* y y)) (* z z)) (* w w)))))

(defun quaternion-length (quaternion)
  "Quaternion.Length."
  (%sqrt-as-xna (quaternion-length-squared quaternion)))

(defun quaternion-normalize (quaternion)
  "Quaternion.Normalize(), the instance method: mutates and answers the receiver."
  (cna-lisp.internal:with-binary32-semantics
    (let ((scale (/ 1.0f0 (%sqrt-as-xna (quaternion-length-squared quaternion)))))
      (setf (quaternion-x quaternion) (* (quaternion-x quaternion) scale)
            (quaternion-y quaternion) (* (quaternion-y quaternion) scale)
            (quaternion-z quaternion) (* (quaternion-z quaternion) scale)
            (quaternion-w quaternion) (* (quaternion-w quaternion) scale))
      quaternion)))

(defun quaternion-normalized (quaternion)
  "Quaternion.Normalize(Quaternion), the static method: answers a new quaternion."
  (quaternion-normalize (copy-quaternion quaternion)))

(defun quaternion-conjugate (quaternion)
  "Quaternion.Conjugate(), the instance method: negates the vector part in place."
  (cna-lisp.internal:with-binary32-semantics
    (setf (quaternion-x quaternion) (- (quaternion-x quaternion))
          (quaternion-y quaternion) (- (quaternion-y quaternion))
          (quaternion-z quaternion) (- (quaternion-z quaternion)))
    quaternion))

(defun quaternion-conjugated (quaternion)
  "Quaternion.Conjugate(Quaternion), the static method: answers a new quaternion."
  (quaternion-conjugate (copy-quaternion quaternion)))

(defun quaternion-inverse (quaternion)
  "Quaternion.Inverse: the conjugate scaled by the reciprocal of the squared
length. No square root is taken; the framework does not take one here."
  (cna-lisp.internal:with-binary32-semantics
    (let ((scale (/ 1.0f0 (quaternion-length-squared quaternion))))
      (%with-q (x y z w) quaternion
        (%make-quaternion (* (- x) scale) (* (- y) scale)
                          (* (- z) scale) (* w scale))))))

(defun quaternion-dot (left right)
  "Quaternion.Dot."
  (cna-lisp.internal:with-binary32-semantics
    (+ (+ (+ (* (quaternion-x left) (quaternion-x right))
             (* (quaternion-y left) (quaternion-y right)))
          (* (quaternion-z left) (quaternion-z right)))
       (* (quaternion-w left) (quaternion-w right)))))

(defun quaternion-create-from-axis-angle (axis angle)
  "Quaternion.CreateFromAxisAngle."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((half (* (f angle) 0.5f0))
           (s (f (sin (coerce half 'double-float))))
           (c (f (cos (coerce half 'double-float)))))
      (%make-quaternion (* (vector3-x axis) s) (* (vector3-y axis) s)
                        (* (vector3-z axis) s) c))))

(declaim (ftype function quaternion-create-from-rotation-matrix))

(defun quaternion-create-from-yaw-pitch-roll (yaw pitch roll)
  "Quaternion.CreateFromYawPitchRoll."
  (cna-lisp.internal:with-binary32-semantics
    (flet ((half-sin-cos (angle)
             (let ((half (* (f angle) 0.5f0)))
               (values (f (sin (coerce half 'double-float)))
                       (f (cos (coerce half 'double-float)))))))
      (multiple-value-bind (sr cr) (half-sin-cos roll)
        (multiple-value-bind (sp cp) (half-sin-cos pitch)
          (multiple-value-bind (sy cy) (half-sin-cos yaw)
            (%make-quaternion (+ (* (* cy sp) cr) (* (* sy cp) sr))
                              (- (* (* sy cp) cr) (* (* cy sp) sr))
                              (- (* (* cy cp) sr) (* (* sy sp) cr))
                              (+ (* (* cy cp) cr) (* (* sy sp) sr)))))))))

(defun %quaternion-product (a b)
  "The Hamilton product exactly as Quaternion.Multiply computes it."
  (cna-lisp.internal:with-binary32-semantics
    (%with-q (x1 y1 z1 w1) a
      (%with-q (x2 y2 z2 w2) b
        (let ((cx (- (* y1 z2) (* z1 y2)))
              (cy (- (* z1 x2) (* x1 z2)))
              (cz (- (* x1 y2) (* y1 x2)))
              (dot (+ (+ (* x1 x2) (* y1 y2)) (* z1 z2))))
          (%make-quaternion (+ (+ (* x1 w2) (* x2 w1)) cx)
                            (+ (+ (* y1 w2) (* y2 w1)) cy)
                            (+ (+ (* z1 w2) (* z2 w1)) cz)
                            (- (* w1 w2) dot)))))))

(defgeneric quaternion-multiply (quaternion factor)
  (:documentation "Quaternion.Multiply, by another quaternion or by a scalar."))

(defmethod quaternion-multiply ((quaternion quaternion) (factor quaternion))
  (%quaternion-product quaternion factor))

(defmethod quaternion-multiply ((quaternion quaternion) (factor real))
  (cna-lisp.internal:with-binary32-semantics
    (let ((s (f factor)))
      (%with-q (x y z w) quaternion
        (%make-quaternion (* x s) (* y s) (* z s) (* w s))))))

(defun quaternion-concatenate (value1 value2)
  "Quaternion.Concatenate: the rotation of VALUE1 followed by that of VALUE2.

It is the Hamilton product with the operands the other way round, which is
exactly what the IL does and the opposite of what the name suggests to somebody
who assumes multiplication order."
  (%quaternion-product value2 value1))

(defun quaternion-divide (left right)
  "Quaternion.Divide: LEFT times the inverse of RIGHT."
  (%quaternion-product left (quaternion-inverse right)))

(defun quaternion-add (left right)
  "Quaternion.Add."
  (cna-lisp.internal:with-binary32-semantics
    (%make-quaternion (+ (quaternion-x left) (quaternion-x right))
                      (+ (quaternion-y left) (quaternion-y right))
                      (+ (quaternion-z left) (quaternion-z right))
                      (+ (quaternion-w left) (quaternion-w right)))))

(defun quaternion-subtract (left right)
  "Quaternion.Subtract."
  (cna-lisp.internal:with-binary32-semantics
    (%make-quaternion (- (quaternion-x left) (quaternion-x right))
                      (- (quaternion-y left) (quaternion-y right))
                      (- (quaternion-z left) (quaternion-z right))
                      (- (quaternion-w left) (quaternion-w right)))))

(defun quaternion-negate (quaternion)
  "Quaternion.Negate."
  (cna-lisp.internal:with-binary32-semantics
    (%with-q (x y z w) quaternion (%make-quaternion (- x) (- y) (- z) (- w)))))

(defun quaternion-lerp (quaternion1 quaternion2 amount)
  "Quaternion.Lerp.

Linear interpolation on the shorter arc -- the second quaternion is subtracted
rather than added when the two point away from each other -- and the result is
normalised in both branches."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((m (f amount))
           (m2 (- 1.0f0 m))
           (dot (quaternion-dot quaternion1 quaternion2))
           (result
             (if (>= dot 0.0f0)
                 (%with-q (x1 y1 z1 w1) quaternion1
                   (%with-q (x2 y2 z2 w2) quaternion2
                     (%make-quaternion (+ (* m2 x1) (* m x2)) (+ (* m2 y1) (* m y2))
                                       (+ (* m2 z1) (* m z2)) (+ (* m2 w1) (* m w2)))))
                 (%with-q (x1 y1 z1 w1) quaternion1
                   (%with-q (x2 y2 z2 w2) quaternion2
                     (%make-quaternion (- (* m2 x1) (* m x2)) (- (* m2 y1) (* m y2))
                                       (- (* m2 z1) (* m z2)) (- (* m2 w1) (* m w2))))))))
      (quaternion-normalize result))))

(defun quaternion-slerp (quaternion1 quaternion2 amount)
  "Quaternion.Slerp.

Below the framework's own 0.999999f threshold the two quaternions are treated as
parallel and the interpolation degenerates to the linear one, without
normalising. That threshold is a constant in the assembly, not a tolerance chosen
here."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((m (f amount))
           (dot (quaternion-dot quaternion1 quaternion2))
           (flipped nil))
      (when (< dot 0.0f0)
        (setf flipped t dot (- dot)))
      (multiple-value-bind (scale1 scale2)
          (if (> dot 0.999999f0)
              (values (- 1.0f0 m) (if flipped (- m) m))
              (let* ((angle (f (acos (coerce dot 'double-float))))
                     (reciprocal (f (/ 1.0d0 (sin (coerce angle 'double-float)))))
                     (s1 (* (f (sin (coerce (* (- 1.0f0 m) angle) 'double-float)))
                            reciprocal))
                     (s2 (* (f (sin (coerce (* m angle) 'double-float))) reciprocal)))
                (values s1 (if flipped (- s2) s2))))
        (%with-q (x1 y1 z1 w1) quaternion1
          (%with-q (x2 y2 z2 w2) quaternion2
            (%make-quaternion (+ (* scale1 x1) (* scale2 x2))
                              (+ (* scale1 y1) (* scale2 y2))
                              (+ (* scale1 z1) (* scale2 z2))
                              (+ (* scale1 w1) (* scale2 w2)))))))))

(defun quaternion-equal (left right)
  "Quaternion.Equals."
  (cna-lisp.internal:with-binary32-semantics
    (and (= (quaternion-x left) (quaternion-x right))
         (= (quaternion-y left) (quaternion-y right))
         (= (quaternion-z left) (quaternion-z right))
         (= (quaternion-w left) (quaternion-w right)))))
