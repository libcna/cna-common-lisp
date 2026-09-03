;;;; value-types.lisp --- Point, Rectangle and Vector2.
;;;;
;;;; XNA's structs are value types: assigning one copies it, and a property that
;;;; answers one answers a copy. Common Lisp structures are references, so
;;;; CNA-Lisp restores value semantics at every boundary -- a value stored into
;;;; an object is copied in, and a value read out of one is copied out. The
;;;; copying is done by the accessors that own the storage, never by the caller.
;;;;
;;;; XNA computes in binary32. Every arithmetic step below is performed in
;;;; SINGLE-FLOAT, in the order the original performs it, with the one promotion
;;;; to double that Math.Sqrt forces and the coercion back that follows it. It is
;;;; not "compute in double and round at the end": that would answer different
;;;; bits.

(in-package #:microsoft.xna.framework)

;;; ------------------------------------------------------------------ Point

(defstruct (point (:constructor make-point (&optional (x 0) (y 0)))
                  (:copier copy-point))
  "Microsoft.Xna.Framework.Point: a two-component integer point."
  (x 0 :type (signed-byte 32))
  (y 0 :type (signed-byte 32)))

(defun point-zero ()
  "Point.Zero. A fresh value each call, because XNA's is a value type: mutating
what a property answered can never affect the property."
  (make-point 0 0))

(defun point-equal (left right)
  "Point.Equals."
  (and (= (point-x left) (point-x right))
       (= (point-y left) (point-y right))))

;;; -------------------------------------------------------------- Rectangle

(defstruct (rectangle (:constructor make-rectangle (&optional (x 0) (y 0) (width 0) (height 0)))
                      (:copier copy-rectangle))
  "Microsoft.Xna.Framework.Rectangle: an integer rectangle as position and size."
  (x 0 :type (signed-byte 32))
  (y 0 :type (signed-byte 32))
  (width 0 :type (signed-byte 32))
  (height 0 :type (signed-byte 32)))

(defun rectangle-empty ()
  "Rectangle.Empty."
  (make-rectangle 0 0 0 0))

(defun rectangle-left (rectangle) (rectangle-x rectangle))
(defun rectangle-right (rectangle) (+ (rectangle-x rectangle) (rectangle-width rectangle)))
(defun rectangle-top (rectangle) (rectangle-y rectangle))
(defun rectangle-bottom (rectangle) (+ (rectangle-y rectangle) (rectangle-height rectangle)))

(defun rectangle-center (rectangle)
  "Rectangle.Center. The halving is integer division, exactly as XNA's is."
  (make-point (+ (rectangle-x rectangle) (truncate (rectangle-width rectangle) 2))
              (+ (rectangle-y rectangle) (truncate (rectangle-height rectangle) 2))))

(defun rectangle-location (rectangle)
  "Rectangle.Location."
  (make-point (rectangle-x rectangle) (rectangle-y rectangle)))

(defun (setf rectangle-location) (point rectangle)
  (setf (rectangle-x rectangle) (point-x point)
        (rectangle-y rectangle) (point-y point))
  point)

(defun rectangle-is-empty (rectangle)
  "Rectangle.IsEmpty: all four components zero, not merely zero area."
  (and (zerop (rectangle-width rectangle))
       (zerop (rectangle-height rectangle))
       (zerop (rectangle-x rectangle))
       (zerop (rectangle-y rectangle))))

(defun rectangle-contains-coordinates (rectangle x y)
  "Rectangle.Contains(int, int).

A separate function rather than a method on RECTANGLE-CONTAINS: the coordinate
overload takes three arguments and the others take two, so no one congruent
generic function can express the family."
  (and (<= (rectangle-x rectangle) x)
       (< x (rectangle-right rectangle))
       (<= (rectangle-y rectangle) y)
       (< y (rectangle-bottom rectangle))))

(defgeneric rectangle-contains (rectangle other)
  (:documentation "Rectangle.Contains(Point) and Rectangle.Contains(Rectangle)."))

(defmethod rectangle-contains ((rectangle rectangle) (other point))
  (rectangle-contains-coordinates rectangle (point-x other) (point-y other)))

(defmethod rectangle-contains ((rectangle rectangle) (other rectangle))
  (and (<= (rectangle-x rectangle) (rectangle-x other))
       (<= (rectangle-right other) (rectangle-right rectangle))
       (<= (rectangle-y rectangle) (rectangle-y other))
       (<= (rectangle-bottom other) (rectangle-bottom rectangle))))

(defun rectangle-intersects (rectangle other)
  "Rectangle.Intersects(Rectangle)."
  (and (< (rectangle-x other) (rectangle-right rectangle))
       (< (rectangle-x rectangle) (rectangle-right other))
       (< (rectangle-y other) (rectangle-bottom rectangle))
       (< (rectangle-y rectangle) (rectangle-bottom other))))

(defun rectangle-offset (rectangle dx dy)
  "Rectangle.Offset(int, int). Mutates RECTANGLE, exactly as XNA's does."
  (incf (rectangle-x rectangle) dx)
  (incf (rectangle-y rectangle) dy)
  rectangle)

(defun rectangle-inflate (rectangle horizontal vertical)
  "Rectangle.Inflate(int, int). Mutates RECTANGLE, exactly as XNA's does."
  (decf (rectangle-x rectangle) horizontal)
  (decf (rectangle-y rectangle) vertical)
  (incf (rectangle-width rectangle) (* 2 horizontal))
  (incf (rectangle-height rectangle) (* 2 vertical))
  rectangle)

(defun rectangle-equal (left right)
  "Rectangle.Equals."
  (and (= (rectangle-x left) (rectangle-x right))
       (= (rectangle-y left) (rectangle-y right))
       (= (rectangle-width left) (rectangle-width right))
       (= (rectangle-height left) (rectangle-height right))))

;;; ---------------------------------------------------------------- Vector2
;;; The shared binary32 helpers F, XNA-FLOAT and %SQRT-AS-XNA live in binary32.lisp.

(defstruct (vector2 (:constructor %make-vector2 (x y)) (:copier copy-vector2))
  "Microsoft.Xna.Framework.Vector2: a two-component binary32 vector."
  (x 0.0f0 :type single-float)
  (y 0.0f0 :type single-float))

(defun make-vector2 (&optional (x 0.0f0) (y 0.0f0))
  "Vector2(float, float), and Vector2(float) when only one value is given."
  (%make-vector2 (f x) (f y)))

(defun vector2-zero () (%make-vector2 0.0f0 0.0f0))
(defun vector2-one () (%make-vector2 1.0f0 1.0f0))
(defun vector2-unit-x () (%make-vector2 1.0f0 0.0f0))
(defun vector2-unit-y () (%make-vector2 0.0f0 1.0f0))

(defun vector2-add (left right)
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector2 (+ (vector2-x left) (vector2-x right))
                   (+ (vector2-y left) (vector2-y right)))))

(defun vector2-subtract (left right)
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector2 (- (vector2-x left) (vector2-x right))
                   (- (vector2-y left) (vector2-y right)))))

(defgeneric vector2-multiply (vector factor)
  (:documentation "Vector2.Multiply, by a scalar or component-wise by another vector."))

(defmethod vector2-multiply ((vector vector2) (factor real))
  (cna-lisp.internal:with-binary32-semantics
    (let ((s (f factor)))
      (%make-vector2 (* (vector2-x vector) s) (* (vector2-y vector) s)))))

(defmethod vector2-multiply ((vector vector2) (factor vector2))
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector2 (* (vector2-x vector) (vector2-x factor))
                   (* (vector2-y vector) (vector2-y factor)))))

(defgeneric vector2-divide (vector divisor)
  (:documentation "Vector2.Divide, by a scalar or component-wise by another vector."))

(defmethod vector2-divide ((vector vector2) (divisor real))
  ;; XNA divides once and multiplies twice; reproducing that order matters,
  ;; because x * (1/d) and x / d do not always answer the same binary32.
  (cna-lisp.internal:with-binary32-semantics
    (let ((reciprocal (/ 1.0f0 (f divisor))))
      (%make-vector2 (* (vector2-x vector) reciprocal)
                     (* (vector2-y vector) reciprocal)))))

(defmethod vector2-divide ((vector vector2) (divisor vector2))
  (cna-lisp.internal:with-binary32-semantics
    (%make-vector2 (/ (vector2-x vector) (vector2-x divisor))
                   (/ (vector2-y vector) (vector2-y divisor)))))

(defun vector2-negate (vector)
  (%make-vector2 (- (vector2-x vector)) (- (vector2-y vector))))

(defun vector2-dot (left right)
  (cna-lisp.internal:with-binary32-semantics
    (+ (* (vector2-x left) (vector2-x right))
       (* (vector2-y left) (vector2-y right)))))

(defun vector2-length-squared (vector)
  (cna-lisp.internal:with-binary32-semantics
    (+ (* (vector2-x vector) (vector2-x vector))
       (* (vector2-y vector) (vector2-y vector)))))

(defun vector2-length (vector)
  (%sqrt-as-xna (vector2-length-squared vector)))

(defun vector2-distance-squared (left right)
  (cna-lisp.internal:with-binary32-semantics
    (let ((dx (- (vector2-x left) (vector2-x right)))
          (dy (- (vector2-y left) (vector2-y right))))
      (+ (* dx dx) (* dy dy)))))

(defun vector2-distance (left right)
  (%sqrt-as-xna (vector2-distance-squared left right)))

(defun vector2-normalize (vector)
  "Vector2.Normalize. Mutates VECTOR, exactly as the instance method does."
  (cna-lisp.internal:with-binary32-semantics
    (let ((scale (/ 1.0f0 (%sqrt-as-xna (vector2-length-squared vector)))))
      (setf (vector2-x vector) (* (vector2-x vector) scale)
            (vector2-y vector) (* (vector2-y vector) scale))
      vector)))

(defun vector2-reflect (vector normal)
  "Vector2.Reflect: v - (2 * (v . n)) * n, with the doubling done before the
multiplication by the normal, as the IL does it."
  (cna-lisp.internal:with-binary32-semantics
    (let ((dot (vector2-dot vector normal)))
      (%make-vector2 (- (vector2-x vector) (* (* 2.0f0 dot) (vector2-x normal)))
                     (- (vector2-y vector) (* (* 2.0f0 dot) (vector2-y normal)))))))

(macrolet ((component-wise (name documentation operation)
             `(defun ,name (left right)
                ,documentation
                (cna-lisp.internal:with-binary32-semantics
                  (%make-vector2 (,operation (vector2-x left) (vector2-x right))
                                 (,operation (vector2-y left) (vector2-y right)))))))
  (component-wise vector2-min "Vector2.Min, component by component." math-helper-min)
  (component-wise vector2-max "Vector2.Max, component by component." math-helper-max))

(defun vector2-clamp (value min max)
  "Vector2.Clamp, component by component."
  (%make-vector2 (math-helper-clamp (vector2-x value) (vector2-x min) (vector2-x max))
                 (math-helper-clamp (vector2-y value) (vector2-y min) (vector2-y max))))

(macrolet ((per-component (name documentation scalar arguments)
             (flet ((axis (reader)
                      `(,scalar ,@(loop for argument in arguments
                                        collect (if (member argument
                                                            '(amount amount1 amount2))
                                                    argument
                                                    `(,reader ,argument))))))
               `(defun ,name (,@arguments)
                  ,documentation
                  (%make-vector2 ,(axis 'vector2-x) ,(axis 'vector2-y))))))
  (per-component vector2-lerp "Vector2.Lerp." math-helper-lerp (value1 value2 amount))
  (per-component vector2-smooth-step "Vector2.SmoothStep." math-helper-smooth-step
                 (value1 value2 amount))
  (per-component vector2-barycentric "Vector2.Barycentric." math-helper-barycentric
                 (value1 value2 value3 amount1 amount2))
  (per-component vector2-catmull-rom "Vector2.CatmullRom." math-helper-catmull-rom
                 (value1 value2 value3 value4 amount))
  (per-component vector2-hermite "Vector2.Hermite." math-helper-hermite
                 (value1 tangent1 value2 tangent2 amount)))

(defun vector2-normalized (vector)
  "Vector2.Normalize(Vector2), the static method: answers a new vector and leaves
VECTOR alone.

A separate name from VECTOR2-NORMALIZE because the instance method mutates and
the static one does not; one Lisp function cannot be both without the caller
having to know which it got."
  (vector2-normalize (copy-vector2 vector)))

(defun vector2-equal (left right)
  "Vector2.Equals. Uses = on binary32, so a NaN component is never equal to
itself -- which is what the original answers too."
  (cna-lisp.internal:with-binary32-semantics
    (and (= (vector2-x left) (vector2-x right))
         (= (vector2-y left) (vector2-y right)))))

;;; ----------------------------------------------------------- PlayerIndex

(defparameter *player-index-table* '((:one . 0) (:two . 1) (:three . 2) (:four . 3))
  "Microsoft.Xna.Framework.PlayerIndex, with the exact values the ABI defines.")

(deftype player-index ()
  "Microsoft.Xna.Framework.PlayerIndex."
  '(member :one :two :three :four))

(defun player-index-value (member)
  "The exact value of a PlayerIndex member."
  (or (cdr (assoc member *player-index-table*))
      (error 'cna-usage-error
             :operation "player-index-value"
             :format-control "~s is not a PlayerIndex member."
             :format-arguments (list member))))

(defun player-index-from-value (value)
  "The PlayerIndex member a value names."
  (or (car (rassoc value *player-index-table*))
      (error 'cna-usage-error
             :operation "player-index-from-value"
             :format-control "~d is not a PlayerIndex value."
             :format-arguments (list value))))
