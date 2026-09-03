;;;; vector4.lisp --- Microsoft.Xna.Framework.Vector4.
;;;;
;;;; The same treatment as Vector3, read from the same pinned XNA 4.0 Windows IL,
;;;; with a fourth component and without Cross and Reflect, which Vector4 does not
;;;; have.

(in-package #:microsoft.xna.framework)

(defstruct (vector4 (:constructor %make-vector4 (x y z w)) (:copier copy-vector4))
  "Microsoft.Xna.Framework.Vector4: a four-component binary32 vector."
  (x 0.0f0 :type single-float)
  (y 0.0f0 :type single-float)
  (z 0.0f0 :type single-float)
  (w 0.0f0 :type single-float))

(defun make-vector4 (&optional (x 0.0f0) (y nil y-supplied-p) (z 0.0f0) (w 0.0f0))
  "Vector4(float, float, float, float), and Vector4(float) when only one value is
given. The Vector2 and Vector3 constructors are MAKE-VECTOR4-FROM-VECTOR2 and
MAKE-VECTOR4-FROM-VECTOR3."
  (if y-supplied-p
      (%make-vector4 (f x) (f y) (f z) (f w))
      (let ((v (f x))) (%make-vector4 v v v v))))

(defun make-vector4-from-vector2 (vector2 z w)
  "Vector4(Vector2, float, float)."
  (%make-vector4 (vector2-x vector2) (vector2-y vector2) (f z) (f w)))

(defun make-vector4-from-vector3 (vector3 w)
  "Vector4(Vector3, float)."
  (%make-vector4 (vector3-x vector3) (vector3-y vector3) (vector3-z vector3) (f w)))

(defun vector4-zero ()   (%make-vector4 0.0f0 0.0f0 0.0f0 0.0f0))
(defun vector4-one ()    (%make-vector4 1.0f0 1.0f0 1.0f0 1.0f0))
(defun vector4-unit-x () (%make-vector4 1.0f0 0.0f0 0.0f0 0.0f0))
(defun vector4-unit-y () (%make-vector4 0.0f0 1.0f0 0.0f0 0.0f0))
(defun vector4-unit-z () (%make-vector4 0.0f0 0.0f0 1.0f0 0.0f0))
(defun vector4-unit-w () (%make-vector4 0.0f0 0.0f0 0.0f0 1.0f0))

(defmacro %with-v4 ((x y z w) vector &body body)
  `(let ((,x (vector4-x ,vector)) (,y (vector4-y ,vector))
         (,z (vector4-z ,vector)) (,w (vector4-w ,vector)))
     ,@body))

(defun vector4-length-squared (vector)
  "Vector4.LengthSquared."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v4 (x y z w) vector (+ (+ (+ (* x x) (* y y)) (* z z)) (* w w)))))

(defun vector4-length (vector)
  "Vector4.Length."
  (%sqrt-as-xna (vector4-length-squared vector)))

(defun vector4-distance-squared (left right)
  "Vector4.DistanceSquared."
  (cna-lisp.internal:with-binary32-semantics
    (let ((dx (- (vector4-x left) (vector4-x right)))
          (dy (- (vector4-y left) (vector4-y right)))
          (dz (- (vector4-z left) (vector4-z right)))
          (dw (- (vector4-w left) (vector4-w right))))
      (+ (+ (+ (* dx dx) (* dy dy)) (* dz dz)) (* dw dw)))))

(defun vector4-distance (left right)
  "Vector4.Distance."
  (%sqrt-as-xna (vector4-distance-squared left right)))

(defun vector4-dot (left right)
  "Vector4.Dot."
  (cna-lisp.internal:with-binary32-semantics
    (+ (+ (+ (* (vector4-x left) (vector4-x right))
             (* (vector4-y left) (vector4-y right)))
          (* (vector4-z left) (vector4-z right)))
       (* (vector4-w left) (vector4-w right)))))

(defun vector4-normalize (vector)
  "Vector4.Normalize(), the instance method: mutates VECTOR and answers it."
  (cna-lisp.internal:with-binary32-semantics
    (let ((scale (/ 1.0f0 (%sqrt-as-xna (vector4-length-squared vector)))))
      (setf (vector4-x vector) (* (vector4-x vector) scale)
            (vector4-y vector) (* (vector4-y vector) scale)
            (vector4-z vector) (* (vector4-z vector) scale)
            (vector4-w vector) (* (vector4-w vector) scale))
      vector)))

(defun vector4-normalized (vector)
  "Vector4.Normalize(Vector4), the static method: answers a new vector.

See VECTOR3-NORMALIZED for why the static and instance forms have different
names."
  (vector4-normalize (copy-vector4 vector)))

(macrolet ((component-wise (name documentation operation)
             `(defun ,name (left right)
                ,documentation
                (cna-lisp.internal:with-binary32-semantics
                  (%make-vector4 (,operation (vector4-x left) (vector4-x right))
                                 (,operation (vector4-y left) (vector4-y right))
                                 (,operation (vector4-z left) (vector4-z right))
                                 (,operation (vector4-w left) (vector4-w right)))))))
  (component-wise vector4-add "Vector4.Add." +)
  (component-wise vector4-subtract "Vector4.Subtract." -)
  (component-wise vector4-min "Vector4.Min, component by component." math-helper-min)
  (component-wise vector4-max "Vector4.Max, component by component." math-helper-max))

(defun vector4-negate (vector)
  "Vector4.Negate."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v4 (x y z w) vector (%make-vector4 (- x) (- y) (- z) (- w)))))

(defgeneric vector4-multiply (vector factor)
  (:documentation "Vector4.Multiply, by a scalar or component-wise by a vector."))

(defmethod vector4-multiply ((vector vector4) (factor real))
  (cna-lisp.internal:with-binary32-semantics
    (let ((s (f factor)))
      (%with-v4 (x y z w) vector (%make-vector4 (* x s) (* y s) (* z s) (* w s))))))

(defmethod vector4-multiply ((vector vector4) (factor vector4))
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector4 (* (vector4-x vector) (vector4-x factor))
                   (* (vector4-y vector) (vector4-y factor))
                   (* (vector4-z vector) (vector4-z factor))
                   (* (vector4-w vector) (vector4-w factor)))))

(defgeneric vector4-divide (vector divisor)
  (:documentation "Vector4.Divide, by a scalar or component-wise by a vector."))

(defmethod vector4-divide ((vector vector4) (divisor real))
  (cna-lisp.internal:with-binary32-semantics
    (let ((reciprocal (/ 1.0f0 (f divisor))))
      (%with-v4 (x y z w) vector
        (%make-vector4 (* x reciprocal) (* y reciprocal)
                       (* z reciprocal) (* w reciprocal))))))

(defmethod vector4-divide ((vector vector4) (divisor vector4))
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector4 (/ (vector4-x vector) (vector4-x divisor))
                   (/ (vector4-y vector) (vector4-y divisor))
                   (/ (vector4-z vector) (vector4-z divisor))
                   (/ (vector4-w vector) (vector4-w divisor)))))

(macrolet ((per-component (name documentation scalar arguments)
             (flet ((axis (reader)
                      `(,scalar ,@(loop for argument in arguments
                                        collect (if (member argument
                                                            '(amount amount1 amount2))
                                                    argument
                                                    `(,reader ,argument))))))
               `(defun ,name (,@arguments)
                  ,documentation
                  (%make-vector4 ,(axis 'vector4-x) ,(axis 'vector4-y)
                                 ,(axis 'vector4-z) ,(axis 'vector4-w))))))
  (per-component vector4-lerp "Vector4.Lerp." math-helper-lerp (value1 value2 amount))
  (per-component vector4-smooth-step "Vector4.SmoothStep." math-helper-smooth-step
                 (value1 value2 amount))
  (per-component vector4-barycentric "Vector4.Barycentric." math-helper-barycentric
                 (value1 value2 value3 amount1 amount2))
  (per-component vector4-catmull-rom "Vector4.CatmullRom." math-helper-catmull-rom
                 (value1 value2 value3 value4 amount))
  (per-component vector4-hermite "Vector4.Hermite." math-helper-hermite
                 (value1 tangent1 value2 tangent2 amount)))

(defun vector4-clamp (value min max)
  "Vector4.Clamp, component by component."
  (%make-vector4 (math-helper-clamp (vector4-x value) (vector4-x min) (vector4-x max))
                 (math-helper-clamp (vector4-y value) (vector4-y min) (vector4-y max))
                 (math-helper-clamp (vector4-z value) (vector4-z min) (vector4-z max))
                 (math-helper-clamp (vector4-w value) (vector4-w min) (vector4-w max))))

(defun vector4-equal (left right)
  "Vector4.Equals."
  (cna-lisp.internal:with-binary32-semantics
    (and (= (vector4-x left) (vector4-x right))
         (= (vector4-y left) (vector4-y right))
         (= (vector4-z left) (vector4-z right))
         (= (vector4-w left) (vector4-w right)))))
