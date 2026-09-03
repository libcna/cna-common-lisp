;;;; bounding-frustum.lisp --- BoundingFrustum, and the members that need it.
;;;;
;;;; BoundingFrustum is the one XNA bounding volume that is a class rather than
;;;; a value type: two variables can name the same frustum, and assigning its
;;;; Matrix recomputes its six planes and eight corners in place. So it is a
;;;; CLOS class here, and the only one in the framework package with no native
;;;; handle behind it.
;;;;
;;;; Two things about it are unlike the other three volumes.
;;;;
;;;; The corners are not stored: they are derived, three planes at a time, by
;;;; intersecting a plane with the line where two others meet. That is why a
;;;; frustum built from a singular matrix answers corners full of infinities and
;;;; NaNs rather than signalling -- the arithmetic is IEEE 754's, and XNA lets it
;;;; run.
;;;;
;;;; And the convex tests are not plane tests. `Intersects' runs a
;;;; Gilbert-Johnson-Keerthi iteration over the Minkowski difference of the two
;;;; bodies (gjk.lisp) and stops when the closest point stops moving, by two
;;;; relative tolerances: 1e-5 of the previous distance, and 4e-5 of the largest
;;;; support point seen. Those tolerances are the contract, not an
;;;; implementation choice, so they are transcribed rather than chosen.
;;;;
;;;; `Contains' is different again, and cheaper: it is a plane test, and it is
;;;; *not* the same answer as GJK on a boundary. That asymmetry is XNA's.

(in-package #:microsoft.xna.framework)

(defconstant +bounding-frustum-corner-count+ 8
  "BoundingFrustum.CornerCount.")

(defconstant +bounding-frustum-plane-count+ 6
  "The number of planes a frustum has. XNA keeps the equivalent constant
private; CNA-Lisp exports it as a declared extension because the plane readers
are public and a caller iterating them needs the count.")

;;; Plane order in the array, as the assembly's private index constants name it.
(defconstant +frustum-near+ 0)
(defconstant +frustum-far+ 1)
(defconstant +frustum-left+ 2)
(defconstant +frustum-right+ 3)
(defconstant +frustum-top+ 4)
(defconstant +frustum-bottom+ 5)

(defclass bounding-frustum ()
  ((matrix :initarg :matrix :accessor %frustum-matrix)
   (planes :reader %frustum-planes
           :initform (make-array +bounding-frustum-plane-count+ :initial-element nil))
   (corners :reader %frustum-corners
            :initform (make-array +bounding-frustum-corner-count+ :initial-element nil))
   (gjk :initform nil :accessor %frustum-gjk))
  (:documentation
   "Microsoft.Xna.Framework.BoundingFrustum: the six planes of a view volume.

Constructed from a view-projection matrix:

    (make-instance 'bounding-frustum :matrix (matrix-multiply view projection))

Setting BOUNDING-FRUSTUM-MATRIX recomputes the planes and corners, as XNA's
Matrix property setter does."))

(defmethod initialize-instance :after ((frustum bounding-frustum) &key)
  ;; XNA has no parameterless public constructor: a frustum without a matrix has
  ;; no planes, so refuse it here rather than answering eight unbound corners.
  (unless (slot-boundp frustum 'matrix)
    (error 'cna-usage-error
           :operation "make-instance bounding-frustum"
           :format-control "a bounding-frustum needs :matrix, the view-projection matrix it bounds."))
  (check-type (%frustum-matrix frustum) matrix)
  (%frustum-set-matrix frustum (copy-matrix (%frustum-matrix frustum))))

;;; ------------------------------------------------------- deriving the planes

(defun %frustum-compute-intersection-line (p1 p2)
  "BoundingFrustum.ComputeIntersectionLine: the line where two planes meet."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((direction (vector3-cross (plane-normal p1) (plane-normal p2)))
           (length-squared (vector3-length-squared direction))
           (position (vector3-divide
                      (vector3-cross
                       (vector3-add (vector3-multiply (plane-normal p2) (- (plane-d p1)))
                                    (vector3-multiply (plane-normal p1) (plane-d p2)))
                       direction)
                      length-squared)))
      (%make-ray position direction))))

(defun %frustum-compute-intersection (plane ray)
  "BoundingFrustum.ComputeIntersection: where a line meets a plane.

No guard on a parallel line: XNA divides anyway and lets the result be an
infinity or a NaN."
  (cna-lisp.internal:with-binary32-semantics
    (let ((distance (/ (- (- (plane-d plane))
                          (vector3-dot (plane-normal plane) (ray-position ray)))
                       (vector3-dot (plane-normal plane) (ray-direction ray)))))
      (vector3-add (ray-position ray)
                   (vector3-multiply (ray-direction ray) distance)))))

(defun %frustum-set-matrix (frustum value)
  "BoundingFrustum.SetMatrix: six planes from the matrix, then eight corners."
  (cna-lisp.internal:with-binary32-semantics
    (let ((planes (%frustum-planes frustum))
          (corners (%frustum-corners frustum)))
      (setf (%frustum-matrix frustum) value)
      (flet ((plane-of (nx ny nz d) (make-plane nx ny nz d)))
        (setf (aref planes +frustum-left+)
              (plane-of (- (- (matrix-m14 value)) (matrix-m11 value))
                        (- (- (matrix-m24 value)) (matrix-m21 value))
                        (- (- (matrix-m34 value)) (matrix-m31 value))
                        (- (- (matrix-m44 value)) (matrix-m41 value)))
              (aref planes +frustum-right+)
              (plane-of (+ (- (matrix-m14 value)) (matrix-m11 value))
                        (+ (- (matrix-m24 value)) (matrix-m21 value))
                        (+ (- (matrix-m34 value)) (matrix-m31 value))
                        (+ (- (matrix-m44 value)) (matrix-m41 value)))
              (aref planes +frustum-top+)
              (plane-of (+ (- (matrix-m14 value)) (matrix-m12 value))
                        (+ (- (matrix-m24 value)) (matrix-m22 value))
                        (+ (- (matrix-m34 value)) (matrix-m32 value))
                        (+ (- (matrix-m44 value)) (matrix-m42 value)))
              (aref planes +frustum-bottom+)
              (plane-of (- (- (matrix-m14 value)) (matrix-m12 value))
                        (- (- (matrix-m24 value)) (matrix-m22 value))
                        (- (- (matrix-m34 value)) (matrix-m32 value))
                        (- (- (matrix-m44 value)) (matrix-m42 value)))
              (aref planes +frustum-near+)
              (plane-of (- (matrix-m13 value)) (- (matrix-m23 value))
                        (- (matrix-m33 value)) (- (matrix-m43 value)))
              (aref planes +frustum-far+)
              (plane-of (+ (- (matrix-m14 value)) (matrix-m13 value))
                        (+ (- (matrix-m24 value)) (matrix-m23 value))
                        (+ (- (matrix-m34 value)) (matrix-m33 value))
                        (+ (- (matrix-m44 value)) (matrix-m43 value)))))
      ;; Normalised in place, dividing D by the same length -- not
      ;; Plane.Normalize, which is the same arithmetic written differently.
      (dotimes (i +bounding-frustum-plane-count+)
        (let* ((plane (aref planes i))
               (length (vector3-length (plane-normal plane))))
          (setf (aref planes i)
                (%make-plane (vector3-divide (plane-normal plane) length)
                             (/ (plane-d plane) length)))))
      ;; Four edge lines, each cut by the top and the bottom plane. The pairing
      ;; below is the assembly's, and it is what fixes the corner order.
      (flet ((edge (a b top-corner bottom-corner)
               (let ((line (%frustum-compute-intersection-line
                            (aref planes a) (aref planes b))))
                 (setf (aref corners top-corner)
                       (%frustum-compute-intersection (aref planes +frustum-top+) line)
                       (aref corners bottom-corner)
                       (%frustum-compute-intersection (aref planes +frustum-bottom+) line)))))
        (edge +frustum-near+ +frustum-left+ 0 3)
        (edge +frustum-right+ +frustum-near+ 1 2)
        (edge +frustum-left+ +frustum-far+ 4 7)
        (edge +frustum-far+ +frustum-right+ 5 6))
      frustum)))

;;; ---------------------------------------------------------- public accessors

(defun bounding-frustum-matrix (frustum)
  "BoundingFrustum.Matrix."
  (copy-matrix (%frustum-matrix frustum)))

(defun (setf bounding-frustum-matrix) (value frustum)
  "BoundingFrustum.Matrix setter: recomputes the planes and the corners."
  (%frustum-set-matrix frustum (copy-matrix value))
  value)

(macrolet ((reader (name index doc)
             `(defun ,name (frustum) ,doc (copy-plane (aref (%frustum-planes frustum) ,index)))))
  (reader bounding-frustum-near +frustum-near+ "BoundingFrustum.Near.")
  (reader bounding-frustum-far +frustum-far+ "BoundingFrustum.Far.")
  (reader bounding-frustum-left +frustum-left+ "BoundingFrustum.Left.")
  (reader bounding-frustum-right +frustum-right+ "BoundingFrustum.Right.")
  (reader bounding-frustum-top +frustum-top+ "BoundingFrustum.Top.")
  (reader bounding-frustum-bottom +frustum-bottom+ "BoundingFrustum.Bottom."))

(defun bounding-frustum-get-corners (frustum &optional destination)
  "BoundingFrustum.GetCorners.

With no DESTINATION, answers a fresh eight-element array, as XNA's no-argument
overload does by cloning. With one, fills it and answers it; it must hold at
least eight elements."
  (let ((corners (%frustum-corners frustum)))
    (cond ((null destination)
           (let ((fresh (make-array +bounding-frustum-corner-count+)))
             (dotimes (i +bounding-frustum-corner-count+ fresh)
               (setf (aref fresh i) (copy-vector3 (aref corners i))))))
          (t
           (unless (>= (length destination) +bounding-frustum-corner-count+)
             (error 'cna-argument-out-of-range-error
                    :operation "bounding-frustum-get-corners"
                    :parameter-name "corners"
                    :format-control "the destination holds ~d element~:p, and a frustum has ~d corners."
                    :format-arguments (list (length destination)
                                            +bounding-frustum-corner-count+)))
           (dotimes (i +bounding-frustum-corner-count+ destination)
             (setf (aref destination i) (copy-vector3 (aref corners i))))))))

(defun bounding-frustum-equal (left right)
  "BoundingFrustum.Equals: two frustums are equal when their matrices are."
  (and (typep left 'bounding-frustum) (typep right 'bounding-frustum)
       (matrix-equal (%frustum-matrix left) (%frustum-matrix right))))

;;; ------------------------------------------------------------ support points

(defun %frustum-support-mapping (frustum direction)
  "BoundingFrustum.SupportMapping: the corner furthest along DIRECTION.

The comparison is strict, so the lowest-numbered corner wins a tie."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((corners (%frustum-corners frustum))
           (best 0)
           (best-dot (vector3-dot (aref corners 0) direction)))
      (loop for i from 1 below +bounding-frustum-corner-count+
            do (let ((d (vector3-dot (aref corners i) direction)))
                 (when (> d best-dot)
                   (setf best i best-dot d))))
      (aref corners best))))

(defun %box-support-mapping (box direction)
  "BoundingBox.SupportMapping: the corner on the positive side of each axis."
  (let ((lo (bounding-box-min box)) (hi (bounding-box-max box)))
    (%make-vector3 (if (>= (vector3-x direction) 0.0f0) (vector3-x hi) (vector3-x lo))
                   (if (>= (vector3-y direction) 0.0f0) (vector3-y hi) (vector3-y lo))
                   (if (>= (vector3-z direction) 0.0f0) (vector3-z hi) (vector3-z lo)))))

(defun %sphere-support-mapping (sphere direction)
  "BoundingSphere.SupportMapping: the surface point along DIRECTION."
  (cna-lisp.internal:with-binary32-semantics
    (let ((scale (/ (bounding-sphere-radius sphere) (vector3-length direction))))
      (vector3-add (bounding-sphere-center sphere)
                   (vector3-multiply direction scale)))))

(defun %frustum-gjk-intersects (frustum seed other-support)
  "The shared body of BoundingFrustum.Intersects for a convex body.

SEED is the first search direction and OTHER-SUPPORT maps a direction to the
other body's support point. The loop is XNA's: refuse as soon as the support
point of the Minkowski difference lies on the far side of the search direction,
and accept once the closest point stops moving by either tolerance."
  (cna-lisp.internal:with-binary32-semantics
    (let ((gjk (or (%frustum-gjk frustum)
                   (setf (%frustum-gjk frustum) (%make-gjk))))
          (v seed)
          (previous 0.0f0)
          (distance 3.40282347f38))
      (%gjk-reset gjk)
      (loop
        (let* ((negated (vector3-negate v))
               (mine (%frustum-support-mapping frustum negated))
               (theirs (funcall other-support v))
               (support (vector3-subtract mine theirs)))
          (when (> (+ (* (vector3-x v) (vector3-x support))
                      (* (vector3-y v) (vector3-y support))
                      (* (vector3-z v) (vector3-z support)))
                   0.0f0)
            (return nil))
          (%gjk-add-support-point gjk support)
          (setf v (gjk-closest-point gjk)
                previous distance
                distance (vector3-length-squared v))
          (unless (> (- previous distance) (* 1.0f-5 previous))
            (return nil))
          (when (or (%gjk-full-simplex-p gjk)
                    (< distance (* 4.0f-5 (gjk-max-length-sq gjk))))
            (return t)))))))

;;; ------------------------------------------------------------------ contains

(defgeneric bounding-frustum-contains (frustum other)
  (:documentation
   "BoundingFrustum.Contains: a CONTAINMENT-TYPE for a point, a box, a sphere or
another frustum."))

(defmethod bounding-frustum-contains ((frustum bounding-frustum) (point vector3))
  ;; A point exactly on a plane is inside: the rejection threshold is 1e-5, not
  ;; zero, and it is the only place in the type where a point gets that slack.
  (cna-lisp.internal:with-binary32-semantics
    (let ((planes (%frustum-planes frustum)))
      (dotimes (i +bounding-frustum-plane-count+ :contains)
        (let ((plane (aref planes i)))
          (when (> (+ (vector3-dot (plane-normal plane) point) (plane-d plane)) 1.0f-5)
            (return :disjoint)))))))

(defmethod bounding-frustum-contains ((frustum bounding-frustum) (box bounding-box))
  (let ((intersects nil))
    (dotimes (i +bounding-frustum-plane-count+
                (if intersects :intersects :contains))
      (let ((side (bounding-box-intersects box (aref (%frustum-planes frustum) i))))
        (case side
          (:front (return :disjoint))
          (:intersecting (setf intersects t)))))))

(defmethod bounding-frustum-contains ((frustum bounding-frustum) (sphere bounding-sphere))
  ;; Not the point test with a radius added: the threshold here is the radius
  ;; itself, with no epsilon, and containment needs every plane strictly clear.
  (cna-lisp.internal:with-binary32-semantics
    (let ((center (bounding-sphere-center sphere))
          (radius (bounding-sphere-radius sphere))
          (inside 0)
          (planes (%frustum-planes frustum)))
      (dotimes (i +bounding-frustum-plane-count+
                  (if (= inside +bounding-frustum-plane-count+) :contains :intersects))
        (let* ((plane (aref planes i))
               (distance (+ (vector3-dot (plane-normal plane) center) (plane-d plane))))
          (when (> distance radius) (return :disjoint))
          (when (< distance (- radius)) (incf inside)))))))

(defmethod bounding-frustum-contains ((frustum bounding-frustum) (other bounding-frustum))
  (if (not (bounding-frustum-intersects frustum other))
      :disjoint
      (let ((corners (%frustum-corners other)))
        (dotimes (i +bounding-frustum-corner-count+ :contains)
          (when (eq :disjoint (bounding-frustum-contains frustum (aref corners i)))
            (return :intersects))))))

;;; ---------------------------------------------------------------- intersects

(defgeneric bounding-frustum-intersects (frustum other)
  (:documentation
   "BoundingFrustum.Intersects: a Boolean for a box, a sphere or another
frustum, a PLANE-INTERSECTION-TYPE for a plane, and a distance or NIL for a
ray."))

(defmethod bounding-frustum-intersects ((frustum bounding-frustum) (box bounding-box))
  (let* ((corners (%frustum-corners frustum))
         (from-min (vector3-subtract (aref corners 0) (bounding-box-min box)))
         (seed (if (< (vector3-length-squared from-min) 1.0f-5)
                   (vector3-subtract (aref corners 0) (bounding-box-max box))
                   from-min)))
    (%frustum-gjk-intersects frustum seed
                             (lambda (direction) (%box-support-mapping box direction)))))

(defmethod bounding-frustum-intersects ((frustum bounding-frustum) (sphere bounding-sphere))
  (let* ((corners (%frustum-corners frustum))
         (from-center (vector3-subtract (aref corners 0) (bounding-sphere-center sphere)))
         (seed (if (< (vector3-length-squared from-center) 1.0f-5)
                   (vector3-unit-x)
                   from-center)))
    (%frustum-gjk-intersects frustum seed
                             (lambda (direction) (%sphere-support-mapping sphere direction)))))

(defmethod bounding-frustum-intersects ((frustum bounding-frustum) (other bounding-frustum))
  (let* ((mine (%frustum-corners frustum))
         (theirs (%frustum-corners other))
         (from-first (vector3-subtract (aref mine 0) (aref theirs 0)))
         (seed (if (< (vector3-length-squared from-first) 1.0f-5)
                   (vector3-subtract (aref mine 0) (aref theirs 1))
                   from-first)))
    (%frustum-gjk-intersects frustum seed
                             (lambda (direction)
                               (%frustum-support-mapping other direction)))))

(defmethod bounding-frustum-intersects ((frustum bounding-frustum) (plane plane))
  ;; Answers as soon as corners have been seen on both sides; otherwise the side
  ;; every corner fell on.
  (cna-lisp.internal:with-binary32-semantics
    (let ((sides 0)
          (corners (%frustum-corners frustum)))
      (dotimes (i +bounding-frustum-corner-count+ (if (= sides 1) :front :back))
        (let ((distance (+ (vector3-dot (aref corners i) (plane-normal plane))
                           (plane-d plane))))
          (setf sides (logior sides (if (> distance 0.0f0) 1 2)))
          (when (= sides 3) (return :intersecting)))))))

(defmethod bounding-frustum-intersects ((frustum bounding-frustum) (ray ray))
  ;; A ray that starts inside answers 0. Otherwise the usual near/far clipping
  ;; against the six planes, with 1e-5 deciding what counts as parallel -- and a
  ;; final answer of the near distance if it is positive, else the far one.
  (cna-lisp.internal:with-binary32-semantics
    (if (eq :contains (bounding-frustum-contains frustum (ray-position ray)))
        0.0f0
        (let ((near -3.40282347f38)
              (far 3.40282347f38)
              (planes (%frustum-planes frustum)))
          (dotimes (i +bounding-frustum-plane-count+)
            (let* ((plane (aref planes i))
                   (normal (plane-normal plane))
                   (along (vector3-dot (ray-direction ray) normal))
                   (offset (+ (vector3-dot (ray-position ray) normal) (plane-d plane))))
              (if (< (abs along) 1.0f-5)
                  (when (> offset 0.0f0) (return-from bounding-frustum-intersects nil))
                  (let ((distance (/ (- offset) along)))
                    (if (< along 0.0f0)
                        (progn
                          (when (> distance far) (return-from bounding-frustum-intersects nil))
                          (when (> distance near) (setf near distance)))
                        (progn
                          (when (< distance near) (return-from bounding-frustum-intersects nil))
                          (when (< distance far) (setf far distance))))))))
          (let ((answer (if (>= near 0.0f0) near far)))
            (if (< answer 0.0f0) nil answer))))))

;;; ----------------------------------------- the members the other types owed

(defmethod bounding-box-intersects ((box bounding-box) (frustum bounding-frustum))
  (bounding-frustum-intersects frustum box))

(defmethod bounding-box-contains ((box bounding-box) (frustum bounding-frustum))
  ;; Note the asymmetry with BoundingFrustum.Contains(BoundingBox): this one
  ;; starts from the GJK test and then checks the frustum's corners, so a box
  ;; and a frustum can disagree about a touching case. That is XNA's shape.
  (if (not (bounding-frustum-intersects frustum box))
      :disjoint
      (let ((corners (%frustum-corners frustum)))
        (dotimes (i +bounding-frustum-corner-count+ :contains)
          (when (eq :disjoint (bounding-box-contains box (aref corners i)))
            (return :intersects))))))

(defmethod bounding-sphere-intersects ((sphere bounding-sphere) (frustum bounding-frustum))
  (bounding-frustum-intersects frustum sphere))

(defmethod bounding-sphere-contains ((sphere bounding-sphere) (frustum bounding-frustum))
  (if (not (bounding-frustum-intersects frustum sphere))
      :disjoint
      (cna-lisp.internal:with-binary32-semantics
        (let ((radius-squared (* (bounding-sphere-radius sphere)
                                 (bounding-sphere-radius sphere)))
              (center (bounding-sphere-center sphere))
              (corners (%frustum-corners frustum)))
          (dotimes (i +bounding-frustum-corner-count+ :contains)
            (when (> (vector3-length-squared
                      (vector3-subtract (aref corners i) center))
                     radius-squared)
              (return :intersects)))))))

(defmethod ray-intersects ((ray ray) (frustum bounding-frustum))
  (bounding-frustum-intersects frustum ray))

(defmethod plane-intersects ((plane plane) (frustum bounding-frustum))
  (bounding-frustum-intersects frustum plane))

(defun bounding-sphere-create-from-frustum (frustum)
  "BoundingSphere.CreateFromFrustum: the sphere over the frustum's eight corners."
  (check-type frustum bounding-frustum)
  (bounding-sphere-create-from-points (bounding-frustum-get-corners frustum)))
