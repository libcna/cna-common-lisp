;;;; bounding-volumes.lisp --- Ray, BoundingBox and BoundingSphere.
;;;;
;;;; The formulas here are the easy part. What these tests pin is which
;;;; comparison is strict, which epsilon the framework picked, and which of
;;;; Disjoint / Contains / Intersects a boundary case answers -- the things a
;;;; reimplementation gets subtly and invisibly wrong.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defun v3 (x y z) (xna:make-vector3 x y z))

;;; --- BoundingBox -------------------------------------------------------------

(test bounding-box-corner-order-is-the-contract
  ;; Callers index into this array, so the order is part of the API.
  (let* ((box (xna:make-bounding-box (v3 -1 -2 -3) (v3 1 2 3)))
         (corners (xna:bounding-box-get-corners box)))
    (is (= 8 (length corners)))
    (is (= 8 xna:+bounding-box-corner-count+))
    (is (vector3~= (aref corners 0) (v3 -1 2 3)))
    (is (vector3~= (aref corners 1) (v3 1 2 3)))
    (is (vector3~= (aref corners 2) (v3 1 -2 3)))
    (is (vector3~= (aref corners 3) (v3 -1 -2 3)))
    (is (vector3~= (aref corners 4) (v3 -1 2 -3)))
    (is (vector3~= (aref corners 5) (v3 1 2 -3)))
    (is (vector3~= (aref corners 6) (v3 1 -2 -3)))
    (is (vector3~= (aref corners 7) (v3 -1 -2 -3)))))

(test bounding-box-get-corners-fills-a-supplied-array
  (let ((destination (make-array 8 :initial-element nil))
        (box (xna:make-bounding-box (v3 0 0 0) (v3 1 1 1))))
    (is (eq destination (xna:bounding-box-get-corners box destination)))
    (is (vector3~= (aref destination 1) (v3 1 1 1)))
    (signals xna:cna-argument-out-of-range-error
      (xna:bounding-box-get-corners box (make-array 3)))))

(test bounding-box-create-from-points-and-sphere
  (let ((box (xna:bounding-box-create-from-points
              (list (v3 1 5 -2) (v3 -3 0 4) (v3 0 2 1)))))
    (is (vector3~= (xna:bounding-box-min box) (v3 -3 0 -2)))
    (is (vector3~= (xna:bounding-box-max box) (v3 1 5 4))))
  (signals xna:cna-usage-error (xna:bounding-box-create-from-points '()))
  (let ((box (xna:bounding-box-create-from-sphere
              (xna:make-bounding-sphere (v3 1 2 3) 2.0))))
    (is (vector3~= (xna:bounding-box-min box) (v3 -1 0 1)))
    (is (vector3~= (xna:bounding-box-max box) (v3 3 4 5)))))

(test bounding-box-create-merged
  (let ((merged (xna:bounding-box-create-merged
                 (xna:make-bounding-box (v3 -1 -1 -1) (v3 0 0 0))
                 (xna:make-bounding-box (v3 0 0 0) (v3 2 3 4)))))
    (is (vector3~= (xna:bounding-box-min merged) (v3 -1 -1 -1)))
    (is (vector3~= (xna:bounding-box-max merged) (v3 2 3 4)))))

(test bounding-box-intersects-a-box-including-touching
  (let ((unit (xna:make-bounding-box (v3 0 0 0) (v3 1 1 1))))
    (is (xna:bounding-box-intersects unit (xna:make-bounding-box (v3 0.5 0.5 0.5)
                                                                 (v3 2 2 2))))
    ;; Touching faces count as intersecting: the test is on < and >, not <= and >=.
    (is (xna:bounding-box-intersects unit (xna:make-bounding-box (v3 1 0 0) (v3 2 1 1))))
    (is (not (xna:bounding-box-intersects unit (xna:make-bounding-box (v3 1.5 0 0)
                                                                      (v3 2 1 1)))))))

(test bounding-box-contains-a-point-inclusively
  (let ((unit (xna:make-bounding-box (v3 0 0 0) (v3 1 1 1))))
    (is (eq :contains (xna:bounding-box-contains unit (v3 0.5 0.5 0.5))))
    ;; A point on a face is contained: the test rejects only strictly outside.
    (is (eq :contains (xna:bounding-box-contains unit (v3 0 0 0))))
    (is (eq :contains (xna:bounding-box-contains unit (v3 1 1 1))))
    (is (eq :disjoint (xna:bounding-box-contains unit (v3 1.5 0.5 0.5))))))

(test bounding-box-contains-a-box
  (let ((unit (xna:make-bounding-box (v3 0 0 0) (v3 4 4 4))))
    (is (eq :contains (xna:bounding-box-contains
                       unit (xna:make-bounding-box (v3 1 1 1) (v3 2 2 2)))))
    (is (eq :intersects (xna:bounding-box-contains
                         unit (xna:make-bounding-box (v3 3 3 3) (v3 5 5 5)))))
    (is (eq :disjoint (xna:bounding-box-contains
                       unit (xna:make-bounding-box (v3 9 9 9) (v3 10 10 10)))))))

(test bounding-box-contains-a-sphere-repeats-the-x-extent
  ;; The assembly tests `Max.X - Min.X > radius' twice -- once for X and once
  ;; again where the Z extent belongs. The centre tests either side of it
  ;; already imply an extent of at least twice the radius, so the substitution
  ;; is invisible unless the radius is zero and the box has no thickness in Z.
  ;; There XNA answers Contains where the test it meant to make answers
  ;; Intersects. This binding answers what XNA answers.
  (let ((flat (xna:make-bounding-box (v3 -10 -10 5) (v3 10 10 5)))
        (dot (xna:make-bounding-sphere (v3 0 0 5) 0.0)))
    (is (eq :contains (xna:bounding-box-contains flat dot))
        "reproducing the framework's repeated X extent is the point of this test")
    ;; Flat in X instead, and the duplicated test is the one that fires.
    (is (eq :intersects
            (xna:bounding-box-contains
             (xna:make-bounding-box (v3 5 -10 -10) (v3 5 10 10))
             (xna:make-bounding-sphere (v3 5 0 0) 0.0)))))
  ;; The ordinary cases still behave.
  (let ((cube (xna:make-bounding-box (v3 -10 -10 -10) (v3 10 10 10))))
    (is (eq :contains (xna:bounding-box-contains
                       cube (xna:make-bounding-sphere (v3 0 0 0) 1.0))))
    (is (eq :disjoint (xna:bounding-box-contains
                       cube (xna:make-bounding-sphere (v3 100 0 0) 1.0))))
    (is (eq :intersects (xna:bounding-box-contains
                         cube (xna:make-bounding-sphere (v3 10 0 0) 1.0))))))

;;; --- BoundingSphere ----------------------------------------------------------

(test bounding-sphere-contains-a-point-strictly
  ;; The squared distance is compared with `<'. A point exactly on the surface is
  ;; Disjoint, which is surprising and is what the framework answers.
  (let ((unit (xna:make-bounding-sphere (v3 0 0 0) 1.0)))
    (is (eq :contains (xna:bounding-sphere-contains unit (v3 0 0 0))))
    (is (eq :contains (xna:bounding-sphere-contains unit (v3 0.5 0 0))))
    (is (eq :disjoint (xna:bounding-sphere-contains unit (v3 1 0 0)))
        "a point on the surface is Disjoint, not Contains")
    (is (eq :disjoint (xna:bounding-sphere-contains unit (v3 2 0 0))))))

(test bounding-sphere-contains-and-intersects-a-sphere
  (let ((unit (xna:make-bounding-sphere (v3 0 0 0) 2.0)))
    (is (eq :contains (xna:bounding-sphere-contains
                       unit (xna:make-bounding-sphere (v3 0 0 0) 1.0))))
    (is (eq :intersects (xna:bounding-sphere-contains
                         unit (xna:make-bounding-sphere (v3 2 0 0) 1.0))))
    (is (eq :disjoint (xna:bounding-sphere-contains
                       unit (xna:make-bounding-sphere (v3 10 0 0) 1.0))))
    (is (xna:bounding-sphere-intersects unit (xna:make-bounding-sphere (v3 2.5 0 0) 1.0)))
    (is (not (xna:bounding-sphere-intersects
              unit (xna:make-bounding-sphere (v3 4 0 0) 1.0))))))

(test bounding-sphere-create-from-bounding-box
  (let ((sphere (xna:bounding-sphere-create-from-bounding-box
                 (xna:make-bounding-box (v3 -1 -1 -1) (v3 1 1 1)))))
    (is (vector3~= (xna:bounding-sphere-center sphere) (v3 0 0 0)))
    (is (~= (sqrt 3.0f0) (xna:bounding-sphere-radius sphere)))))

(test bounding-sphere-create-merged-keeps-a-contained-sphere
  (let ((big (xna:make-bounding-sphere (v3 0 0 0) 5.0))
        (small (xna:make-bounding-sphere (v3 1 0 0) 1.0)))
    (is (xna:bounding-sphere-equal (xna:bounding-sphere-create-merged big small) big))
    (is (xna:bounding-sphere-equal (xna:bounding-sphere-create-merged small big) big))))

(test bounding-sphere-create-merged-grows-to-cover-both
  (let* ((a (xna:make-bounding-sphere (v3 -2 0 0) 1.0))
         (b (xna:make-bounding-sphere (v3 2 0 0) 1.0))
         (merged (xna:bounding-sphere-create-merged a b)))
    (is (~= 3.0f0 (xna:bounding-sphere-radius merged)))
    (is (vector3~= (xna:bounding-sphere-center merged) (v3 0 0 0) 1.0e-5))))

(test bounding-sphere-create-from-points-covers-them
  (let* ((points (list (v3 -5 0 0) (v3 5 0 0) (v3 0 1 0) (v3 0 0 -1)))
         (sphere (xna:bounding-sphere-create-from-points points)))
    (dolist (point points)
      (is (<= (xna:vector3-distance point (xna:bounding-sphere-center sphere))
              (+ (xna:bounding-sphere-radius sphere) 1.0e-4))
          "~a is outside the sphere the framework's algorithm produced" point)))
  (signals xna:cna-usage-error (xna:bounding-sphere-create-from-points '())))

(test bounding-sphere-transform-scales-by-the-largest-row
  (let* ((sphere (xna:make-bounding-sphere (v3 1 0 0) 2.0))
         (scaled (xna:bounding-sphere-transform sphere (xna:matrix-create-scale 1 3 2))))
    (is (~= 6.0f0 (xna:bounding-sphere-radius scaled))
        "the radius follows the largest row length, not the average")
    (is (vector3~= (xna:bounding-sphere-center scaled) (v3 1 0 0))))
  (let* ((sphere (xna:make-bounding-sphere (v3 0 0 0) 1.0))
         (moved (xna:bounding-sphere-transform
                 sphere (xna:matrix-create-translation (v3 5 6 7)))))
    (is (vector3~= (xna:bounding-sphere-center moved) (v3 5 6 7)))
    (is (~= 1.0f0 (xna:bounding-sphere-radius moved)))))

;;; --- Ray ----------------------------------------------------------------------

(test ray-hits-a-plane-in-front-and-misses-behind
  (let ((plane (xna:make-plane 0 1 0 0)))
    (is (~= 5.0f0 (xna:ray-intersects (xna:make-ray (v3 0 5 0) (v3 0 -1 0)) plane)))
    (is (null (xna:ray-intersects (xna:make-ray (v3 0 5 0) (v3 0 1 0)) plane)))
    ;; Parallel: the framework's 1e-5 epsilon on the normal-direction dot.
    (is (null (xna:ray-intersects (xna:make-ray (v3 0 5 0) (v3 1 0 0)) plane)))
    ;; Starting on the plane answers zero, not a miss.
    (is (~= 0.0f0 (xna:ray-intersects (xna:make-ray (v3 0 0 0) (v3 0 -1 0)) plane)))))

(test ray-hits-a-sphere-and-answers-zero-from-inside
  (let ((sphere (xna:make-bounding-sphere (v3 0 0 0) 1.0)))
    (is (~= 4.0f0 (xna:ray-intersects (xna:make-ray (v3 -5 0 0) (v3 1 0 0)) sphere)))
    (is (= 0.0f0 (xna:ray-intersects (xna:make-ray (v3 0 0 0) (v3 1 0 0)) sphere))
        "a ray starting inside answers zero, not the distance to the far side")
    (is (null (xna:ray-intersects (xna:make-ray (v3 -5 0 0) (v3 -1 0 0)) sphere))
        "pointing away misses")
    (is (null (xna:ray-intersects (xna:make-ray (v3 -5 5 0) (v3 1 0 0)) sphere))
        "passing beside misses")))

(test ray-hits-a-box-by-the-slab-method
  (let ((unit (xna:make-bounding-box (v3 -1 -1 -1) (v3 1 1 1))))
    (is (~= 4.0f0 (xna:ray-intersects (xna:make-ray (v3 -5 0 0) (v3 1 0 0)) unit)))
    (is (= 0.0f0 (xna:ray-intersects (xna:make-ray (v3 0 0 0) (v3 1 0 0)) unit)))
    (is (null (xna:ray-intersects (xna:make-ray (v3 -5 0 0) (v3 -1 0 0)) unit)))
    ;; A ray parallel to an axis and outside that slab misses without dividing.
    (is (null (xna:ray-intersects (xna:make-ray (v3 -5 9 0) (v3 1 0 0)) unit)))
    ;; ... and parallel but inside the slab still hits.
    (is (~= 4.0f0 (xna:ray-intersects (xna:make-ray (v3 -5 0.5 0) (v3 1 0 0)) unit)))))

(test the-volume-tests-agree-in-both-directions
  (let ((box (xna:make-bounding-box (v3 -1 -1 -1) (v3 1 1 1)))
        (sphere (xna:make-bounding-sphere (v3 0 0 0) 0.5))
        (ray (xna:make-ray (v3 -5 0 0) (v3 1 0 0)))
        (plane (xna:make-plane 0 1 0 -10)))
    (is (eq (xna:bounding-box-intersects box sphere)
            (xna:bounding-sphere-intersects sphere box)))
    (is (equal (xna:ray-intersects ray box) (xna:bounding-box-intersects box ray)))
    (is (equal (xna:ray-intersects ray sphere) (xna:bounding-sphere-intersects sphere ray)))
    (is (eq (xna:plane-intersects plane box) (xna:bounding-box-intersects box plane)))
    (is (eq (xna:plane-intersects plane sphere)
            (xna:bounding-sphere-intersects sphere plane)))))

(test a-plane-sorts-volumes-into-front-back-and-intersecting
  (let ((plane (xna:make-plane 0 1 0 0)))
    (is (eq :front (xna:plane-intersects plane (xna:make-bounding-sphere (v3 0 5 0) 1.0))))
    (is (eq :back (xna:plane-intersects plane (xna:make-bounding-sphere (v3 0 -5 0) 1.0))))
    (is (eq :intersecting
            (xna:plane-intersects plane (xna:make-bounding-sphere (v3 0 0 0) 1.0))))
    (is (eq :front (xna:plane-intersects plane (xna:make-bounding-box (v3 -1 1 -1)
                                                                      (v3 1 3 1)))))
    (is (eq :back (xna:plane-intersects plane (xna:make-bounding-box (v3 -1 -3 -1)
                                                                     (v3 1 -1 1)))))
    (is (eq :intersecting
            (xna:plane-intersects plane (xna:make-bounding-box (v3 -1 -1 -1) (v3 1 1 1)))))))
