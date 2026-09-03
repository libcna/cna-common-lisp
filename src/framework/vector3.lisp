;;;; vector3.lisp --- Microsoft.Xna.Framework.Vector3.
;;;;
;;;; Read from the pinned XNA 4.0 Windows IL, one method at a time, and written in
;;;; the order the IL performs the arithmetic. Where the IL narrows a binary64
;;;; square root back to binary32 before dividing -- which Normalize does -- so
;;;; does this.
;;;;
;;;; Nothing here goes through the C ABI. CNA has routes for all of it, and using
;;;; them would make the binding's arithmetic CNA's rather than XNA's.

(in-package #:microsoft.xna.framework)

(defstruct (vector3 (:constructor %make-vector3 (x y z)) (:copier copy-vector3))
  "Microsoft.Xna.Framework.Vector3: a three-component binary32 vector."
  (x 0.0f0 :type single-float)
  (y 0.0f0 :type single-float)
  (z 0.0f0 :type single-float))

(defun make-vector3 (&optional (x 0.0f0) (y nil y-supplied-p) (z 0.0f0))
  "Vector3(float, float, float), and Vector3(float) when only one value is given.

The Vector2-and-Z constructor is MAKE-VECTOR3-FROM-VECTOR2; a two-argument call
here would be ambiguous between it and the one-value form."
  (if y-supplied-p
      (%make-vector3 (f x) (f y) (f z))
      (let ((v (f x))) (%make-vector3 v v v))))

(defun make-vector3-from-vector2 (vector2 z)
  "Vector3(Vector2, float)."
  (%make-vector3 (vector2-x vector2) (vector2-y vector2) (f z)))

;;; --- the predefined directions, exactly as the static constructor sets them ---

(defun vector3-zero ()     (%make-vector3 0.0f0 0.0f0 0.0f0))
(defun vector3-one ()      (%make-vector3 1.0f0 1.0f0 1.0f0))
(defun vector3-unit-x ()   (%make-vector3 1.0f0 0.0f0 0.0f0))
(defun vector3-unit-y ()   (%make-vector3 0.0f0 1.0f0 0.0f0))
(defun vector3-unit-z ()   (%make-vector3 0.0f0 0.0f0 1.0f0))
(defun vector3-up ()       (%make-vector3 0.0f0 1.0f0 0.0f0))
(defun vector3-down ()     (%make-vector3 0.0f0 -1.0f0 0.0f0))
(defun vector3-right ()    (%make-vector3 1.0f0 0.0f0 0.0f0))
(defun vector3-left ()     (%make-vector3 -1.0f0 0.0f0 0.0f0))
(defun vector3-forward ()  (%make-vector3 0.0f0 0.0f0 -1.0f0))
(defun vector3-backward () (%make-vector3 0.0f0 0.0f0 1.0f0))

(defmacro %with-v3 ((x y z) vector &body body)
  `(let ((,x (vector3-x ,vector)) (,y (vector3-y ,vector)) (,z (vector3-z ,vector)))
     ,@body))

;;; --- length, distance, dot, cross ----------------------------------------

(defun vector3-length-squared (vector)
  "Vector3.LengthSquared."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (x y z) vector (+ (+ (* x x) (* y y)) (* z z)))))

(defun vector3-length (vector)
  "Vector3.Length: the squares are summed in binary32 and only the square root is
taken in binary64."
  (%sqrt-as-xna (vector3-length-squared vector)))

(defun vector3-distance-squared (left right)
  "Vector3.DistanceSquared."
  (cna-lisp.internal:with-binary32-semantics
    (let ((dx (- (vector3-x left) (vector3-x right)))
          (dy (- (vector3-y left) (vector3-y right)))
          (dz (- (vector3-z left) (vector3-z right))))
      (+ (+ (* dx dx) (* dy dy)) (* dz dz)))))

(defun vector3-distance (left right)
  "Vector3.Distance."
  (%sqrt-as-xna (vector3-distance-squared left right)))

(defun vector3-dot (left right)
  "Vector3.Dot."
  (cna-lisp.internal:with-binary32-semantics
    (+ (+ (* (vector3-x left) (vector3-x right))
          (* (vector3-y left) (vector3-y right)))
       (* (vector3-z left) (vector3-z right)))))

(defun vector3-cross (left right)
  "Vector3.Cross."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (ax ay az) left
      (%with-v3 (bx by bz) right
        (%make-vector3 (- (* ay bz) (* az by))
                       (- (* az bx) (* ax bz))
                       (- (* ax by) (* ay bx)))))))

(defun vector3-normalize (vector)
  "Vector3.Normalize(), the instance method: mutates VECTOR and answers it.

The reciprocal is taken of the *binary32* square root, which is what the IL does
and is not the same as dividing each component by a binary64 root."
  (cna-lisp.internal:with-binary32-semantics
    (let ((scale (/ 1.0f0 (%sqrt-as-xna (vector3-length-squared vector)))))
      (setf (vector3-x vector) (* (vector3-x vector) scale)
            (vector3-y vector) (* (vector3-y vector) scale)
            (vector3-z vector) (* (vector3-z vector) scale))
      vector)))

(defun vector3-normalized (vector)
  "Vector3.Normalize(Vector3), the static method: answers a new vector and leaves
VECTOR alone.

A separate name because the instance method mutates and the static one does not,
and one Lisp function cannot be both without the caller having to know which."
  (vector3-normalize (copy-vector3 vector)))

(defun vector3-reflect (vector normal)
  "Vector3.Reflect: v - (2 * (v . n)) * n, with the doubling done before the
multiplication by the normal, as the IL does it."
  (cna-lisp.internal:with-binary32-semantics
    (let ((dot (vector3-dot vector normal)))
      (%with-v3 (x y z) vector
        (%with-v3 (nx ny nz) normal
          (%make-vector3 (- x (* (* 2.0f0 dot) nx))
                         (- y (* (* 2.0f0 dot) ny))
                         (- z (* (* 2.0f0 dot) nz))))))))

;;; --- component-wise families ---------------------------------------------

(macrolet ((component-wise (name documentation operation)
             `(defun ,name (left right)
                ,documentation
                (cna-lisp.internal:with-binary32-semantics
                  (%make-vector3 (,operation (vector3-x left) (vector3-x right))
                                 (,operation (vector3-y left) (vector3-y right))
                                 (,operation (vector3-z left) (vector3-z right)))))))
  (component-wise vector3-add "Vector3.Add." +)
  (component-wise vector3-subtract "Vector3.Subtract." -)
  (component-wise vector3-min "Vector3.Min, component by component." math-helper-min)
  (component-wise vector3-max "Vector3.Max, component by component." math-helper-max))

(defun vector3-negate (vector)
  "Vector3.Negate."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (x y z) vector (%make-vector3 (- x) (- y) (- z)))))

(defgeneric vector3-multiply (vector factor)
  (:documentation "Vector3.Multiply, by a scalar or component-wise by a vector."))

(defmethod vector3-multiply ((vector vector3) (factor real))
  (cna-lisp.internal:with-binary32-semantics
    (let ((s (f factor)))
      (%with-v3 (x y z) vector (%make-vector3 (* x s) (* y s) (* z s))))))

(defmethod vector3-multiply ((vector vector3) (factor vector3))
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector3 (* (vector3-x vector) (vector3-x factor))
                   (* (vector3-y vector) (vector3-y factor))
                   (* (vector3-z vector) (vector3-z factor)))))

(defgeneric vector3-divide (vector divisor)
  (:documentation "Vector3.Divide, by a scalar or component-wise by a vector."))

(defmethod vector3-divide ((vector vector3) (divisor real))
  ;; One reciprocal, three multiplications: the IL's own shape.
  (cna-lisp.internal:with-binary32-semantics
    (let ((reciprocal (/ 1.0f0 (f divisor))))
      (%with-v3 (x y z) vector
        (%make-vector3 (* x reciprocal) (* y reciprocal) (* z reciprocal))))))

(defmethod vector3-divide ((vector vector3) (divisor vector3))
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector3 (/ (vector3-x vector) (vector3-x divisor))
                   (/ (vector3-y vector) (vector3-y divisor))
                   (/ (vector3-z vector) (vector3-z divisor)))))

;;; --- interpolation --------------------------------------------------------

(macrolet ((per-component (name documentation scalar arguments)
             `(defun ,name (,@arguments)
                ,documentation
                (%make-vector3
                 (,scalar ,@(loop for argument in arguments
                                  collect (if (member argument '(amount amount1 amount2))
                                              argument
                                              `(vector3-x ,argument))))
                 (,scalar ,@(loop for argument in arguments
                                  collect (if (member argument '(amount amount1 amount2))
                                              argument
                                              `(vector3-y ,argument))))
                 (,scalar ,@(loop for argument in arguments
                                  collect (if (member argument '(amount amount1 amount2))
                                              argument
                                              `(vector3-z ,argument))))))))
  (per-component vector3-lerp "Vector3.Lerp." math-helper-lerp (value1 value2 amount))
  (per-component vector3-smooth-step "Vector3.SmoothStep." math-helper-smooth-step
                 (value1 value2 amount))
  (per-component vector3-barycentric "Vector3.Barycentric." math-helper-barycentric
                 (value1 value2 value3 amount1 amount2))
  (per-component vector3-catmull-rom "Vector3.CatmullRom." math-helper-catmull-rom
                 (value1 value2 value3 value4 amount))
  (per-component vector3-hermite "Vector3.Hermite." math-helper-hermite
                 (value1 tangent1 value2 tangent2 amount)))

(defun vector3-clamp (value min max)
  "Vector3.Clamp, component by component."
  (%make-vector3 (math-helper-clamp (vector3-x value) (vector3-x min) (vector3-x max))
                 (math-helper-clamp (vector3-y value) (vector3-y min) (vector3-y max))
                 (math-helper-clamp (vector3-z value) (vector3-z min) (vector3-z max))))

(defun vector3-equal (left right)
  "Vector3.Equals."
  (cna-lisp.internal:with-binary32-semantics
    (and (= (vector3-x left) (vector3-x right))
         (= (vector3-y left) (vector3-y right))
         (= (vector3-z left) (vector3-z right)))))
