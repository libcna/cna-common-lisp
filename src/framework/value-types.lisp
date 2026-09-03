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

(deftype xna-float ()
  "The floating-point type XNA computes in: IEEE 754 binary32."
  'single-float)

(declaim (inline f))
(defun f (number)
  "NUMBER as the binary32 value XNA would hold."
  (coerce number 'single-float))

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
  (%make-vector2 (+ (vector2-x left) (vector2-x right))
                 (+ (vector2-y left) (vector2-y right))))

(defun vector2-subtract (left right)
  (%make-vector2 (- (vector2-x left) (vector2-x right))
                 (- (vector2-y left) (vector2-y right))))

(defgeneric vector2-multiply (vector factor)
  (:documentation "Vector2.Multiply, by a scalar or component-wise by another vector."))

(defmethod vector2-multiply ((vector vector2) (factor real))
  (let ((s (f factor)))
    (%make-vector2 (* (vector2-x vector) s) (* (vector2-y vector) s))))

(defmethod vector2-multiply ((vector vector2) (factor vector2))
  (%make-vector2 (* (vector2-x vector) (vector2-x factor))
                 (* (vector2-y vector) (vector2-y factor))))

(defgeneric vector2-divide (vector divisor)
  (:documentation "Vector2.Divide, by a scalar or component-wise by another vector."))

(defmethod vector2-divide ((vector vector2) (divisor real))
  ;; XNA divides once and multiplies twice; reproducing that order matters,
  ;; because x * (1/d) and x / d do not always answer the same binary32.
  (let ((reciprocal (/ 1.0f0 (f divisor))))
    (%make-vector2 (* (vector2-x vector) reciprocal) (* (vector2-y vector) reciprocal))))

(defmethod vector2-divide ((vector vector2) (divisor vector2))
  (%make-vector2 (/ (vector2-x vector) (vector2-x divisor))
                 (/ (vector2-y vector) (vector2-y divisor))))

(defun vector2-negate (vector)
  (%make-vector2 (- (vector2-x vector)) (- (vector2-y vector))))

(defun vector2-dot (left right)
  (+ (* (vector2-x left) (vector2-x right))
     (* (vector2-y left) (vector2-y right))))

(defun vector2-length-squared (vector)
  (+ (* (vector2-x vector) (vector2-x vector))
     (* (vector2-y vector) (vector2-y vector))))

(defun %sqrt-as-xna (single)
  "Math.Sqrt on a binary32 argument, cast back to binary32.

The square root itself is computed in binary64 because that is the only overload
the original calls; the result is then narrowed. Doing the whole computation in
binary64 would answer different bits."
  (f (sqrt (coerce single 'double-float))))

(defun vector2-length (vector)
  (%sqrt-as-xna (vector2-length-squared vector)))

(defun vector2-distance-squared (left right)
  (let ((dx (- (vector2-x left) (vector2-x right)))
        (dy (- (vector2-y left) (vector2-y right))))
    (+ (* dx dx) (* dy dy))))

(defun vector2-distance (left right)
  (%sqrt-as-xna (vector2-distance-squared left right)))

(defun vector2-normalize (vector)
  "Vector2.Normalize. Mutates VECTOR, exactly as the instance method does."
  (let ((scale (/ 1.0f0 (%sqrt-as-xna (vector2-length-squared vector)))))
    (setf (vector2-x vector) (* (vector2-x vector) scale)
          (vector2-y vector) (* (vector2-y vector) scale))
    vector))

(defun vector2-equal (left right)
  "Vector2.Equals. Uses = on binary32, so a NaN component is never equal to
itself -- which is what the original answers too."
  (and (= (vector2-x left) (vector2-x right))
       (= (vector2-y left) (vector2-y right))))

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
