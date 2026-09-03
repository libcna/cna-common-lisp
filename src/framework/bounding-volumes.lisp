;;;; bounding-volumes.lisp --- Ray, BoundingBox and BoundingSphere.
;;;;
;;;; Read from the pinned XNA 4.0 Windows IL. These are the types where the
;;;; interesting part is never the formula: it is which comparison is strict,
;;;; which epsilon the framework chose, and which of Disjoint / Contains /
;;;; Intersects a boundary case answers. Two examples that a reimplementation
;;;; gets differently:
;;;;
;;;;   * `BoundingSphere.Contains(Vector3)' compares the squared distance with
;;;;     **strictly less than**, so a point exactly on the surface is Disjoint.
;;;;   * `BoundingBox.Contains(BoundingSphere)' checks `Max.X - Min.X > radius'
;;;;     **twice** -- once for X and once again where the Z extent belongs. That
;;;;     is in the assembly, so it is here, marked as what it is.
;;;;
;;;; The members that take a BoundingFrustum are not here: that type is the next
;;;; closure, and half a frustum would make every cross-product member wrong
;;;; rather than absent.

(in-package #:microsoft.xna.framework)

;;; ------------------------------------------------------------------- Ray

(defconstant +bounding-box-corner-count+ 8
  "BoundingBox.CornerCount.")

(defstruct (ray (:constructor %make-ray (position direction)) (:copier copy-ray))
  "Microsoft.Xna.Framework.Ray: a position and a direction."
  (position (%make-vector3 0.0f0 0.0f0 0.0f0) :type vector3)
  (direction (%make-vector3 0.0f0 0.0f0 0.0f0) :type vector3))

(defstruct (bounding-box (:constructor %make-bounding-box (min max))
                         (:copier copy-bounding-box))
  "Microsoft.Xna.Framework.BoundingBox: an axis-aligned box as two corners."
  (min (%make-vector3 0.0f0 0.0f0 0.0f0) :type vector3)
  (max (%make-vector3 0.0f0 0.0f0 0.0f0) :type vector3))

(defstruct (bounding-sphere (:constructor %make-bounding-sphere (center radius))
                            (:copier copy-bounding-sphere))
  "Microsoft.Xna.Framework.BoundingSphere: a centre and a radius."
  (center (%make-vector3 0.0f0 0.0f0 0.0f0) :type vector3)
  (radius 0.0f0 :type single-float))

(defun make-ray (&optional (position (vector3-zero)) (direction (vector3-zero)))
  "Ray(Vector3, Vector3)."
  (%make-ray (copy-vector3 position) (copy-vector3 direction)))

(defun ray-equal (left right)
  "Ray.Equals."
  (and (vector3-equal (ray-position left) (ray-position right))
       (vector3-equal (ray-direction left) (ray-direction right))))

;;; -------------------------------------------------------------- BoundingBox

(defun make-bounding-box (&optional (min (vector3-zero)) (max (vector3-zero)))
  "BoundingBox(Vector3, Vector3)."
  (%make-bounding-box (copy-vector3 min) (copy-vector3 max)))

(defun bounding-box-equal (left right)
  "BoundingBox.Equals."
  (and (vector3-equal (bounding-box-min left) (bounding-box-min right))
       (vector3-equal (bounding-box-max left) (bounding-box-max right))))

(defun bounding-box-get-corners (box &optional corners)
  "BoundingBox.GetCorners, in the framework's own order.

The order is a contract, not an implementation detail -- code indexes into it --
so it is reproduced exactly: the four corners at maximum Z first, counting from
the one at minimum X and maximum Y, then the same four at minimum Z. CORNERS, when
given, is filled and answered; otherwise a fresh vector of eight is made."
  (let ((result (or corners (make-array +bounding-box-corner-count+))))
    (when (< (length result) +bounding-box-corner-count+)
      (error 'cna-argument-out-of-range-error
             :operation "bounding-box-get-corners"
             :parameter-name "corners"
             :format-control "the destination holds ~d element~:p, and a box has ~d corners."
             :format-arguments (list (length result) +bounding-box-corner-count+)))
    (let ((lo (bounding-box-min box)) (hi (bounding-box-max box)))
      (macrolet ((corner (index x y z)
                   `(setf (elt result ,index)
                          (%make-vector3 (vector3-x ,x) (vector3-y ,y) (vector3-z ,z)))))
        (corner 0 lo hi hi) (corner 1 hi hi hi) (corner 2 hi lo hi) (corner 3 lo lo hi)
        (corner 4 lo hi lo) (corner 5 hi hi lo) (corner 6 hi lo lo) (corner 7 lo lo lo)))
    result))

(defun bounding-box-create-merged (original additional)
  "BoundingBox.CreateMerged: the smallest box containing both."
  (%make-bounding-box
   (vector3-min (bounding-box-min original) (bounding-box-min additional))
   (vector3-max (bounding-box-max original) (bounding-box-max additional))))

(defun bounding-box-create-from-sphere (sphere)
  "BoundingBox.CreateFromSphere."
  (cna-lisp.internal:with-binary32-semantics
    (let ((center (bounding-sphere-center sphere))
          (radius (bounding-sphere-radius sphere)))
      (%make-bounding-box
       (%make-vector3 (- (vector3-x center) radius) (- (vector3-y center) radius)
                      (- (vector3-z center) radius))
       (%make-vector3 (+ (vector3-x center) radius) (+ (vector3-y center) radius)
                      (+ (vector3-z center) radius))))))

(defun bounding-box-create-from-points (points)
  "BoundingBox.CreateFromPoints.

The accumulators start at plus and minus the largest finite binary32, which is
what the framework starts them at -- not at the first point -- so a sequence of
one point answers a degenerate box rather than a box around the extremes."
  (check-type points sequence)
  (cna-lisp.internal:with-binary32-semantics
    (let ((lo (%make-vector3 3.40282347f38 3.40282347f38 3.40282347f38))
          (hi (%make-vector3 -3.40282347f38 -3.40282347f38 -3.40282347f38))
          (any nil))
      (map nil (lambda (point)
                 (setf any t
                       lo (vector3-min lo point)
                       hi (vector3-max hi point)))
           points)
      (unless any
        (error 'cna-usage-error
               :operation "bounding-box-create-from-points"
               :format-control "a bounding box needs at least one point."))
      (%make-bounding-box lo hi))))

;;; ----------------------------------------------------------- BoundingSphere

(defun make-bounding-sphere (&optional (center (vector3-zero)) (radius 0.0f0))
  "BoundingSphere(Vector3, float)."
  (%make-bounding-sphere (copy-vector3 center) (f radius)))

(defun bounding-sphere-equal (left right)
  "BoundingSphere.Equals."
  (and (vector3-equal (bounding-sphere-center left) (bounding-sphere-center right))
       (cna-lisp.internal:with-binary32-semantics
         (= (bounding-sphere-radius left) (bounding-sphere-radius right)))))

(defun bounding-sphere-create-from-bounding-box (box)
  "BoundingSphere.CreateFromBoundingBox: the sphere around a box's diagonal."
  (cna-lisp.internal:with-binary32-semantics
    (%make-bounding-sphere
     (vector3-lerp (bounding-box-min box) (bounding-box-max box) 0.5f0)
     (* (vector3-distance (bounding-box-min box) (bounding-box-max box)) 0.5f0))))

(defun bounding-sphere-create-merged (original additional)
  "BoundingSphere.CreateMerged."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((offset (vector3-subtract (bounding-sphere-center additional)
                                     (bounding-sphere-center original)))
           (distance (vector3-length offset))
           (r1 (bounding-sphere-radius original))
           (r2 (bounding-sphere-radius additional)))
      (if (>= (+ r1 r2) distance)
          (cond ((>= (- r1 r2) distance) (copy-bounding-sphere original))
                ((>= (- r2 r1) distance) (copy-bounding-sphere additional))
                (t (%merge-spheres original offset distance r1 r2)))
          (%merge-spheres original offset distance r1 r2)))))

(defun %merge-spheres (original offset distance r1 r2)
  (cna-lisp.internal:with-binary32-semantics
    (let* ((direction (vector3-multiply offset (/ 1.0f0 distance)))
           (near (math-helper-min (- r1) (- distance r2)))
           (far (math-helper-max r1 (+ distance r2)))
           (radius (* (- far near) 0.5f0)))
      (%make-bounding-sphere
       (vector3-add (bounding-sphere-center original)
                    (vector3-multiply direction (+ radius near)))
       radius))))

(defun bounding-sphere-create-from-points (points)
  "BoundingSphere.CreateFromPoints.

The framework's own two passes: take the six axis-extreme points, start from the
widest of the three pairs, then grow the sphere over every point that falls
outside it. Not a bounding box's diagonal, and not an exact minimal sphere."
  (check-type points sequence)
  (when (zerop (length points))
    (error 'cna-usage-error
           :operation "bounding-sphere-create-from-points"
           :format-control "a bounding sphere needs at least one point."))
  (cna-lisp.internal:with-binary32-semantics
    (let* ((first-point (elt points 0))
           (min-x first-point) (max-x first-point)
           (min-y first-point) (max-y first-point)
           (min-z first-point) (max-z first-point))
      (map nil (lambda (point)
                 (when (< (vector3-x point) (vector3-x min-x)) (setf min-x point))
                 (when (> (vector3-x point) (vector3-x max-x)) (setf max-x point))
                 (when (< (vector3-y point) (vector3-y min-y)) (setf min-y point))
                 (when (> (vector3-y point) (vector3-y max-y)) (setf max-y point))
                 (when (< (vector3-z point) (vector3-z min-z)) (setf min-z point))
                 (when (> (vector3-z point) (vector3-z max-z)) (setf max-z point)))
           points)
      (let ((dx (vector3-distance max-x min-x))
            (dy (vector3-distance max-y min-y))
            (dz (vector3-distance max-z min-z)))
        (multiple-value-bind (center radius)
            (if (> dx dy)
                (if (> dx dz)
                    (values (vector3-lerp max-x min-x 0.5f0) (* dx 0.5f0))
                    (values (vector3-lerp max-z min-z 0.5f0) (* dz 0.5f0)))
                (if (> dy dz)
                    (values (vector3-lerp max-y min-y 0.5f0) (* dy 0.5f0))
                    (values (vector3-lerp max-z min-z 0.5f0) (* dz 0.5f0))))
          (map nil (lambda (point)
                     (let* ((offset (vector3-subtract point center))
                            (distance (vector3-length offset)))
                       (when (> distance radius)
                         (setf radius (* (+ radius distance) 0.5f0)
                               center (vector3-add
                                       center
                                       (vector3-multiply
                                        offset (- 1.0f0 (/ radius distance))))))))
               points)
          (%make-bounding-sphere center radius))))))

(defun bounding-sphere-transform (sphere matrix)
  "BoundingSphere.Transform.

The radius is scaled by the largest of the three row lengths, so a non-uniform
scale answers a sphere that still contains the transformed one."
  (cna-lisp.internal:with-binary32-semantics
    (%with-m matrix
      (let* ((row1 (+ (+ (* m11 m11) (* m12 m12)) (* m13 m13)))
             (row2 (+ (+ (* m21 m21) (* m22 m22)) (* m23 m23)))
             (row3 (+ (+ (* m31 m31) (* m32 m32)) (* m33 m33)))
             (largest (math-helper-max row1 (math-helper-max row2 row3))))
        (%make-bounding-sphere
         (vector3-transform (bounding-sphere-center sphere) matrix)
         (* (bounding-sphere-radius sphere) (%sqrt-as-xna largest)))))))

;;; --------------------------------------------------------------- Ray tests

(defgeneric ray-intersects (ray other)
  (:documentation
   "Ray.Intersects: the distance along the ray to the first intersection, or NIL.

NIL is XNA's `float?' with no value. A ray that starts inside the volume answers
zero, not the distance to the far side."))

(defmethod ray-intersects ((ray ray) (plane plane))
  (cna-lisp.internal:with-binary32-semantics
    (let ((along (vector3-dot (plane-normal plane) (ray-direction ray))))
      ;; The framework's own epsilon: a ray this close to parallel misses.
      (when (< (abs along) 1.0f-5)
        (return-from ray-intersects nil))
      (let* ((from (vector3-dot (plane-normal plane) (ray-position ray)))
             (distance (/ (- (- (plane-d plane)) from) along)))
        (when (< distance 0.0f0)
          ;; Just behind the origin counts as zero; further behind misses.
          (when (< distance -1.0f-5)
            (return-from ray-intersects nil))
          (setf distance 0.0f0))
        distance))))

(defmethod ray-intersects ((ray ray) (sphere bounding-sphere))
  (cna-lisp.internal:with-binary32-semantics
    (let* ((offset (vector3-subtract (bounding-sphere-center sphere) (ray-position ray)))
           (squared (vector3-length-squared offset))
           (radius-squared (* (bounding-sphere-radius sphere)
                              (bounding-sphere-radius sphere))))
      (cond
        ((<= squared radius-squared) 0.0f0)
        (t (let ((along (vector3-dot offset (ray-direction ray))))
             (cond ((< along 0.0f0) nil)
                   (t (let ((perpendicular (- squared (* along along))))
                        (cond ((> perpendicular radius-squared) nil)
                              (t (- along (%sqrt-as-xna
                                           (- radius-squared perpendicular)))))))))))))) 

(defmethod ray-intersects ((ray ray) (box bounding-box))
  (bounding-box-intersects box ray))

;;; ------------------------------------------------------- BoundingBox tests

(defgeneric bounding-box-intersects (box other)
  (:documentation
   "BoundingBox.Intersects: a Boolean for a box or a sphere, a
PLANE-INTERSECTION-TYPE for a plane, and a distance or NIL for a ray."))

(defmethod bounding-box-intersects ((box bounding-box) (other bounding-box))
  (cna-lisp.internal:with-binary32-semantics
    (let ((lo (bounding-box-min box)) (hi (bounding-box-max box))
          (lo2 (bounding-box-min other)) (hi2 (bounding-box-max other)))
      (not (or (< (vector3-x hi) (vector3-x lo2)) (> (vector3-x lo) (vector3-x hi2))
               (< (vector3-y hi) (vector3-y lo2)) (> (vector3-y lo) (vector3-y hi2))
               (< (vector3-z hi) (vector3-z lo2)) (> (vector3-z lo) (vector3-z hi2)))))))

(defmethod bounding-box-intersects ((box bounding-box) (sphere bounding-sphere))
  (cna-lisp.internal:with-binary32-semantics
    (let* ((center (bounding-sphere-center sphere))
           (nearest (vector3-clamp center (bounding-box-min box) (bounding-box-max box)))
           (squared (vector3-distance-squared center nearest))
           (radius (bounding-sphere-radius sphere)))
      (<= squared (* radius radius)))))

(defun %plane-box-intersection (plane box)
  "The shared body of Plane.Intersects(BoundingBox) and its mirror on the box.

Tests the box vertex furthest along the negative normal first: if that one is in
front, the whole box is."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((normal (plane-normal plane))
           (lo (bounding-box-min box)) (hi (bounding-box-max box))
           (d (plane-d plane)))
      (flet ((pick (component low high)
               (if (>= component 0.0f0) low high)))
        (let ((near (%make-vector3 (pick (vector3-x normal) (vector3-x lo) (vector3-x hi))
                                   (pick (vector3-y normal) (vector3-y lo) (vector3-y hi))
                                   (pick (vector3-z normal) (vector3-z lo) (vector3-z hi))))
              (far (%make-vector3 (pick (vector3-x normal) (vector3-x hi) (vector3-x lo))
                                  (pick (vector3-y normal) (vector3-y hi) (vector3-y lo))
                                  (pick (vector3-z normal) (vector3-z hi) (vector3-z lo)))))
          (cond ((> (+ (vector3-dot normal near) d) 0.0f0) :front)
                ((< (+ (vector3-dot normal far) d) 0.0f0) :back)
                (t :intersecting)))))))

(defmethod bounding-box-intersects ((box bounding-box) (plane plane))
  (%plane-box-intersection plane box))

(defmethod bounding-box-intersects ((box bounding-box) (ray ray))
  "The slab method, with the framework's 1e-6 parallel-axis epsilon."
  (cna-lisp.internal:with-binary32-semantics
    (let ((near 0.0f0)
          (far 3.40282347f38)
          (origin (ray-position ray))
          (direction (ray-direction ray))
          (lo (bounding-box-min box))
          (hi (bounding-box-max box)))
      (macrolet ((axis (reader)
                   `(let ((component (,reader direction))
                          (start (,reader origin))
                          (low (,reader lo))
                          (high (,reader hi)))
                      (if (< (abs component) 1.0f-6)
                          (when (or (< start low) (> start high))
                            (return-from bounding-box-intersects nil))
                          (let* ((inverse (/ 1.0f0 component))
                                 (enter (* (- low start) inverse))
                                 (exit (* (- high start) inverse)))
                            (when (> enter exit) (rotatef enter exit))
                            (setf near (math-helper-max enter near)
                                  far (math-helper-min exit far))
                            (when (> near far)
                              (return-from bounding-box-intersects nil)))))))
        (axis vector3-x)
        (axis vector3-y)
        (axis vector3-z))
      near)))

(defgeneric bounding-box-contains (box other)
  (:documentation
   "BoundingBox.Contains: a CONTAINMENT-TYPE for a point, a box or a sphere."))

(defmethod bounding-box-contains ((box bounding-box) (point vector3))
  (cna-lisp.internal:with-binary32-semantics
    (let ((lo (bounding-box-min box)) (hi (bounding-box-max box)))
      (if (or (> (vector3-x lo) (vector3-x point)) (> (vector3-x point) (vector3-x hi))
              (> (vector3-y lo) (vector3-y point)) (> (vector3-y point) (vector3-y hi))
              (> (vector3-z lo) (vector3-z point)) (> (vector3-z point) (vector3-z hi)))
          :disjoint
          :contains))))

(defmethod bounding-box-contains ((box bounding-box) (other bounding-box))
  (cna-lisp.internal:with-binary32-semantics
    (let ((lo (bounding-box-min box)) (hi (bounding-box-max box))
          (lo2 (bounding-box-min other)) (hi2 (bounding-box-max other)))
      (cond
        ((or (< (vector3-x hi) (vector3-x lo2)) (> (vector3-x lo) (vector3-x hi2))
             (< (vector3-y hi) (vector3-y lo2)) (> (vector3-y lo) (vector3-y hi2))
             (< (vector3-z hi) (vector3-z lo2)) (> (vector3-z lo) (vector3-z hi2)))
         :disjoint)
        ((and (<= (vector3-x lo) (vector3-x lo2)) (<= (vector3-x hi2) (vector3-x hi))
              (<= (vector3-y lo) (vector3-y lo2)) (<= (vector3-y hi2) (vector3-y hi))
              (<= (vector3-z lo) (vector3-z lo2)) (<= (vector3-z hi2) (vector3-z hi)))
         :contains)
        (t :intersects)))))

(defmethod bounding-box-contains ((box bounding-box) (sphere bounding-sphere))
  (cna-lisp.internal:with-binary32-semantics
    (let* ((center (bounding-sphere-center sphere))
           (radius (bounding-sphere-radius sphere))
           (nearest (vector3-clamp center (bounding-box-min box) (bounding-box-max box)))
           (squared (vector3-distance-squared center nearest))
           (lo (bounding-box-min box)) (hi (bounding-box-max box)))
      (cond
        ((> squared (* radius radius)) :disjoint)
        ((and (<= (+ (vector3-x lo) radius) (vector3-x center))
              (<= (vector3-x center) (- (vector3-x hi) radius))
              (> (- (vector3-x hi) (vector3-x lo)) radius)
              (<= (+ (vector3-y lo) radius) (vector3-y center))
              (<= (vector3-y center) (- (vector3-y hi) radius))
              (> (- (vector3-y hi) (vector3-y lo)) radius)
              (<= (+ (vector3-z lo) radius) (vector3-z center))
              (<= (vector3-z center) (- (vector3-z hi) radius))
              ;; The X extent again. IL_0116 of the assembly loads Max.X and
              ;; Min.X where the Z extent belongs. The two center tests above
              ;; already imply an extent of at least twice the radius, so this
              ;; only changes the answer when the radius is zero and the box is
              ;; degenerate in Z: XNA then reports Contains where the Z extent
              ;; test it meant to make would have reported Intersects.
              ;; Reproduced because it is what XNA answers; recorded because it
              ;; is a defect, not a rule.
              (> (- (vector3-x hi) (vector3-x lo)) radius))
         :contains)
        (t :intersects)))))

;;; ---------------------------------------------------- BoundingSphere tests

(defgeneric bounding-sphere-intersects (sphere other)
  (:documentation
   "BoundingSphere.Intersects: a Boolean for a box or a sphere, a
PLANE-INTERSECTION-TYPE for a plane, and a distance or NIL for a ray."))

(defmethod bounding-sphere-intersects ((sphere bounding-sphere) (other bounding-sphere))
  (cna-lisp.internal:with-binary32-semantics
    (let ((squared (vector3-distance-squared (bounding-sphere-center sphere)
                                             (bounding-sphere-center other)))
          (r1 (bounding-sphere-radius sphere))
          (r2 (bounding-sphere-radius other)))
      (> (+ (+ (* r1 r1) (* (* 2.0f0 r1) r2)) (* r2 r2)) squared))))

(defmethod bounding-sphere-intersects ((sphere bounding-sphere) (box bounding-box))
  (bounding-box-intersects box sphere))

(defmethod bounding-sphere-intersects ((sphere bounding-sphere) (ray ray))
  (ray-intersects ray sphere))

(defun %plane-sphere-intersection (plane sphere)
  (cna-lisp.internal:with-binary32-semantics
    (let* ((distance (+ (vector3-dot (bounding-sphere-center sphere) (plane-normal plane))
                        (plane-d plane)))
           (radius (bounding-sphere-radius sphere)))
      (cond ((> distance radius) :front)
            ((< distance (- radius)) :back)
            (t :intersecting)))))

(defmethod bounding-sphere-intersects ((sphere bounding-sphere) (plane plane))
  (%plane-sphere-intersection plane sphere))

(defgeneric bounding-sphere-contains (sphere other)
  (:documentation
   "BoundingSphere.Contains: a CONTAINMENT-TYPE for a point, a box or a sphere."))

(defmethod bounding-sphere-contains ((sphere bounding-sphere) (point vector3))
  (cna-lisp.internal:with-binary32-semantics
    ;; Strictly less than: a point exactly on the surface is Disjoint.
    (if (< (vector3-distance-squared point (bounding-sphere-center sphere))
           (* (bounding-sphere-radius sphere) (bounding-sphere-radius sphere)))
        :contains
        :disjoint)))

(defmethod bounding-sphere-contains ((sphere bounding-sphere) (other bounding-sphere))
  (cna-lisp.internal:with-binary32-semantics
    (let ((distance (vector3-distance (bounding-sphere-center sphere)
                                      (bounding-sphere-center other)))
          (r1 (bounding-sphere-radius sphere))
          (r2 (bounding-sphere-radius other)))
      (cond ((< (+ r1 r2) distance) :disjoint)
            ((< (- r1 r2) distance) :intersects)
            (t :contains)))))

(defmethod bounding-sphere-contains ((sphere bounding-sphere) (box bounding-box))
  (cna-lisp.internal:with-binary32-semantics
    (if (not (bounding-sphere-intersects sphere box))
        :disjoint
        (let ((radius-squared (* (bounding-sphere-radius sphere)
                                 (bounding-sphere-radius sphere)))
              (center (bounding-sphere-center sphere)))
          (if (every (lambda (corner)
                       (<= (vector3-length-squared (vector3-subtract center corner))
                           radius-squared))
                     (bounding-box-get-corners box))
              :contains
              :intersects)))))

;;; ------------------------------------------------- the Plane side of it all

(defgeneric plane-intersects (plane volume)
  (:documentation
   "Plane.Intersects: which side of the plane a volume lies on, as a
PLANE-INTERSECTION-TYPE."))

(defmethod plane-intersects ((plane plane) (box bounding-box))
  (%plane-box-intersection plane box))

(defmethod plane-intersects ((plane plane) (sphere bounding-sphere))
  (%plane-sphere-intersection plane sphere))
