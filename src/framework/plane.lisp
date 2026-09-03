;;;; plane.lisp --- Microsoft.Xna.Framework.Plane, and the two geometry enums.
;;;;
;;;; Read from the pinned XNA 4.0 Windows IL. The details that matter and that a
;;;; textbook implementation gets differently: Normalize does nothing at all when
;;;; the squared length is already within one binary32 epsilon of one, and
;;;; Transform inverts the matrix and multiplies by its *rows* -- that is, by the
;;;; transpose of the inverse, which is the only thing that transforms a plane
;;;; correctly under a non-uniform scale.

(in-package #:microsoft.xna.framework)

(defparameter *containment-type-table*
  '((:disjoint . 0) (:contains . 1) (:intersects . 2))
  "Microsoft.Xna.Framework.ContainmentType.")

(deftype containment-type ()
  "Microsoft.Xna.Framework.ContainmentType."
  '(member :disjoint :contains :intersects))

(defparameter *plane-intersection-type-table*
  '((:front . 0) (:back . 1) (:intersecting . 2))
  "Microsoft.Xna.Framework.PlaneIntersectionType.")

(deftype plane-intersection-type ()
  "Microsoft.Xna.Framework.PlaneIntersectionType."
  '(member :front :back :intersecting))

(macrolet ((define-enum-conversions (name table)
             (let ((value (intern (format nil "~a-VALUE" name)))
                   (from (intern (format nil "~a-FROM-VALUE" name)))
                   (all (intern (format nil "ALL-~a" name))))
               `(progn
                  (defun ,value (member)
                    ,(format nil "The exact ABI value of a ~a member." name)
                    (or (cdr (assoc member ,table))
                        (if (eq member (car (first ,table)))
                            0
                            (error 'cna-usage-error
                                   :operation ,(string-downcase (symbol-name value))
                                   :format-control "~s is not a ~a member."
                                   :format-arguments (list member ,(symbol-name name))))))
                  (defun ,from (integer)
                    ,(format nil "The ~a member an ABI value names." name)
                    (or (car (rassoc integer ,table))
                        (error 'cna-usage-error
                               :operation ,(string-downcase (symbol-name from))
                               :format-control "~d is not a ~a value."
                               :format-arguments (list integer ,(symbol-name name)))))
                  (defun ,all ()
                    ,(format nil "Every ~a member, in value order." name)
                    (mapcar #'car ,table))))))
  (define-enum-conversions containment-type *containment-type-table*)
  (define-enum-conversions plane-intersection-type *plane-intersection-type-table*))

;;; --- Plane ------------------------------------------------------------------

(defstruct (plane (:constructor %make-plane (normal d)) (:copier copy-plane))
  "Microsoft.Xna.Framework.Plane: a normal and a distance from the origin.

The plane is the set of points p for which `(plane-dot-coordinate plane p)' is
zero."
  (normal (%make-vector3 0.0f0 0.0f0 0.0f0) :type vector3)
  (d 0.0f0 :type single-float))

(defun make-plane (&optional (a 0.0f0) (b 0.0f0) (c 0.0f0) (d 0.0f0))
  "Plane(float, float, float, float)."
  (%make-plane (%make-vector3 (f a) (f b) (f c)) (f d)))

(defun make-plane-from-normal (normal d)
  "Plane(Vector3, float)."
  (%make-plane (copy-vector3 normal) (f d)))

(defun make-plane-from-vector4 (value)
  "Plane(Vector4): the X, Y and Z become the normal and the W becomes D."
  (%make-plane (%make-vector3 (vector4-x value) (vector4-y value) (vector4-z value))
               (vector4-w value)))

(defun make-plane-from-points (point1 point2 point3)
  "Plane(Vector3, Vector3, Vector3): the plane through three points.

The normal is the cross product of the two edges from POINT1, normalised, and D
is minus its dot with POINT1. Three collinear points answer a plane of NaNs
rather than signalling, exactly as the original does."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (x1 y1 z1) point1
      (let* ((ax (- (vector3-x point2) x1))
             (ay (- (vector3-y point2) y1))
             (az (- (vector3-z point2) z1))
             (bx (- (vector3-x point3) x1))
             (by (- (vector3-y point3) y1))
             (bz (- (vector3-z point3) z1))
             (nx (- (* ay bz) (* az by)))
             (ny (- (* az bx) (* ax bz)))
             (nz (- (* ax by) (* ay bx)))
             (scale (/ 1.0f0 (%sqrt-as-xna (+ (+ (* nx nx) (* ny ny)) (* nz nz)))))
             (sx (* nx scale)) (sy (* ny scale)) (sz (* nz scale)))
        (%make-plane (%make-vector3 sx sy sz)
                     (- (+ (+ (* sx x1) (* sy y1)) (* sz z1))))))))

(defconstant +plane-normalize-epsilon+ 1.1920929f-7
  "The binary32 epsilon Plane.Normalize compares the squared length against.

A plane whose normal is already within this of unit length is left exactly as it
is -- not renormalised -- which is why normalising twice is not the same as
normalising once for a normal that is very nearly unit.")

(defun plane-normalize (plane)
  "Plane.Normalize(), the instance method: mutates PLANE and answers it.

Does nothing when the squared length of the normal is already within one binary32
epsilon of one. That early exit is the framework's, and it is observable."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((normal (plane-normal plane))
           (squared (vector3-length-squared normal)))
      (unless (< (abs (- squared 1.0f0)) +plane-normalize-epsilon+)
        (let ((scale (/ 1.0f0 (%sqrt-as-xna squared))))
          (setf (vector3-x normal) (* (vector3-x normal) scale)
                (vector3-y normal) (* (vector3-y normal) scale)
                (vector3-z normal) (* (vector3-z normal) scale)
                (plane-d plane) (* (plane-d plane) scale))))
      plane)))

(defun plane-normalized (plane)
  "Plane.Normalize(Plane), the static method: answers a new plane."
  (plane-normalize (%make-plane (copy-vector3 (plane-normal plane)) (plane-d plane))))

(defun plane-dot (plane value)
  "Plane.Dot(Vector4): the normal dotted with XYZ plus D times W."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (nx ny nz) (plane-normal plane)
      (+ (+ (+ (* nx (vector4-x value)) (* ny (vector4-y value)))
            (* nz (vector4-z value)))
         (* (plane-d plane) (vector4-w value))))))

(defun plane-dot-coordinate (plane value)
  "Plane.DotCoordinate(Vector3): the signed distance to a point, for a normalised
plane."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (nx ny nz) (plane-normal plane)
      (+ (+ (+ (* nx (vector3-x value)) (* ny (vector3-y value)))
            (* nz (vector3-z value)))
         (plane-d plane)))))

(defun plane-dot-normal (plane value)
  "Plane.DotNormal(Vector3): the normal dotted with a direction."
  (vector3-dot (plane-normal plane) value))

(defgeneric plane-transform (plane transform)
  (:documentation
   "Plane.Transform, by a Matrix or by a Quaternion.

The matrix form multiplies by the *transpose of the inverse*, which is what keeps
a plane a plane under a non-uniform scale."))

(defmethod plane-transform ((plane plane) (transform matrix))
  (cna-lisp.internal:with-binary32-semantics
    (let ((inverse (matrix-invert transform)))
      (%with-v3 (x y z) (plane-normal plane)
        (let ((d (plane-d plane)))
          (macrolet ((row (a b c e)
                       `(+ (+ (+ (* x (,a inverse)) (* y (,b inverse)))
                              (* z (,c inverse)))
                           (* d (,e inverse)))))
            (%make-plane (%make-vector3
                          (row matrix-m11 matrix-m12 matrix-m13 matrix-m14)
                          (row matrix-m21 matrix-m22 matrix-m23 matrix-m24)
                          (row matrix-m31 matrix-m32 matrix-m33 matrix-m34))
                         (row matrix-m41 matrix-m42 matrix-m43 matrix-m44))))))))

(defmethod plane-transform ((plane plane) (transform quaternion))
  (%make-plane (vector3-transform (plane-normal plane) transform) (plane-d plane)))

(defun plane-equal (left right)
  "Plane.Equals."
  (and (vector3-equal (plane-normal left) (plane-normal right))
       (cna-lisp.internal:with-binary32-semantics
         (= (plane-d left) (plane-d right)))))

;;; --- the plane-dependent factories ------------------------------------------
;;;
;;; These are Matrix members, and they live in this file because they need Plane.
;;; The dependency runs both ways -- Plane.Transform needs Matrix.Invert -- so
;;; something has to come second, and a factory is a better thing to move than a
;;; type definition: a forward reference to a structure accessor costs the
;;; compiler its inlining, and a forward reference to a function costs nothing.

(defun matrix-create-reflection (plane)
  "Matrix.CreateReflection.

The plane is normalised first -- the framework normalises the copy it was given,
so the caller's plane is untouched here too."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((p (plane-normalized plane))
           (normal (plane-normal p))
           (x (vector3-x normal)) (y (vector3-y normal)) (z (vector3-z normal))
           (d (plane-d p))
           (mx (* -2.0f0 x)) (my (* -2.0f0 y)) (mz (* -2.0f0 z)))
      (%make-matrix (+ (* mx x) 1.0f0) (* my x) (* mz x) 0.0f0
                    (* mx y) (+ (* my y) 1.0f0) (* mz y) 0.0f0
                    (* mx z) (* my z) (+ (* mz z) 1.0f0) 0.0f0
                    (* mx d) (* my d) (* mz d) 1.0f0))))

(defun matrix-create-shadow (light-direction plane)
  "Matrix.CreateShadow: flattens geometry onto a plane along a light direction.

The plane is normalised first. When the light is parallel to the plane the dot
product is zero and the matrix is degenerate -- the framework does not check, and
neither does this."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((p (plane-normalized plane))
           (normal (plane-normal p))
           (dot (vector3-dot normal light-direction))
           (nx (- (vector3-x normal))) (ny (- (vector3-y normal)))
           (nz (- (vector3-z normal))) (nd (- (plane-d p)))
           (lx (vector3-x light-direction)) (ly (vector3-y light-direction))
           (lz (vector3-z light-direction)))
      (%make-matrix (+ (* nx lx) dot) (* nx ly) (* nx lz) 0.0f0
                    (* ny lx) (+ (* ny ly) dot) (* ny lz) 0.0f0
                    (* nz lx) (* nz ly) (+ (* nz lz) dot) 0.0f0
                    (* nd lx) (* nd ly) (* nd lz) dot))))
