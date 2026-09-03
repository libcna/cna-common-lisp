;;;; bounding-frustum.lisp --- BoundingFrustum and the GJK solver behind it.
;;;;
;;;; Two things here are worth more than the geometry. The first is the
;;;; determinant table: it is a transcription of a private class, so the tests
;;;; check the table it indexes with against the rule that generates it rather
;;;; than trusting sixteen transcribed literals. The second is that XNA's
;;;; `Contains' and `Intersects' answer *different questions* about a frustum
;;;; and a box -- one is a plane test, the other is GJK with a tolerance -- and
;;;; they disagree in both directions. Those disagreements are pinned, because a
;;;; reimplementation that made them agree would be wrong in a way nobody would
;;;; notice until a game culled the wrong object.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defun test-frustum (&key (far 20.0) (aspect 1.0))
  "A frustum looking down -Z from (0, 0, 5), near 1."
  (make-instance 'xna:bounding-frustum
                 :matrix (xna:matrix-multiply
                          (xna:matrix-create-look-at (v3 0 0 5) (v3 0 0 0) (v3 0 1 0))
                          (xna:matrix-create-perspective-field-of-view
                           xna:+math-helper-pi-over4+ aspect 1.0 far))))

(test the-gjk-index-table-matches-the-rule-that-generates-it
  ;; Entry N lists the members of the four-bit set N as octal digits holding
  ;; index+1, least significant first. Sixteen transcribed literals are exactly
  ;; the kind of thing a typo survives in, so they are regenerated here.
  (let ((table (symbol-value (find-symbol "*GJK-BITS-TO-INDICES*"
                                          '#:microsoft.xna.framework))))
    (is (= 16 (length table)))
    (dotimes (bits 16)
      (let ((expected 0) (shift 0))
        (dotimes (index 4)
          (when (logbitp index bits)
            (setf expected (logior expected (ash (1+ index) shift)))
            (incf shift 3)))
        (is (= expected (aref table bits))
            "entry ~d is ~o, and the rule gives ~o" bits (aref table bits) expected)))))

(test a-frustum-derives-its-planes-and-corners-from-the-matrix
  (let* ((frustum (test-frustum))
         (corners (xna:bounding-frustum-get-corners frustum)))
    (is (= 8 (length corners)))
    (is (= 8 xna:+bounding-frustum-corner-count+))
    (is (= 6 xna:+bounding-frustum-plane-count+))
    ;; The camera sits at z = 5 looking at the origin, so near is z = 4 and far
    ;; is z = -15. Corners 0..3 are the near face, 4..7 the far one, and each
    ;; face runs top-left, top-right, bottom-right, bottom-left.
    (dotimes (i 4)
      (is (~= 4.0f0 (xna:vector3-z (aref corners i))))
      ;; The far corners come out at -14.999987, not -15: they are derived by
      ;; intersecting three normalised planes, and that loses about a part in
      ;; 10^6 of the far distance. The framework does the same arithmetic, so
      ;; the looser tolerance here is the honest one rather than a concession.
      (is (~= -15.0f0 (xna:vector3-z (aref corners (+ i 4))) 1.0e-4)))
    (is (< (xna:vector3-x (aref corners 0)) 0))
    (is (> (xna:vector3-y (aref corners 0)) 0))
    (is (> (xna:vector3-x (aref corners 1)) 0))
    (is (> (xna:vector3-y (aref corners 1)) 0))
    (is (> (xna:vector3-x (aref corners 2)) 0))
    (is (< (xna:vector3-y (aref corners 2)) 0))
    (is (< (xna:vector3-x (aref corners 3)) 0))
    (is (< (xna:vector3-y (aref corners 3)) 0))
    ;; The far face is the near one scaled out from the eye.
    (is (> (abs (xna:vector3-x (aref corners 4))) (abs (xna:vector3-x (aref corners 0)))))))

(test the-six-planes-are-normalised-and-face-outwards
  (let ((frustum (test-frustum)))
    (dolist (reader (list #'xna:bounding-frustum-near #'xna:bounding-frustum-far
                          #'xna:bounding-frustum-left #'xna:bounding-frustum-right
                          #'xna:bounding-frustum-top #'xna:bounding-frustum-bottom))
      (let ((plane (funcall reader frustum)))
        (is (~= 1.0f0 (xna:vector3-length (xna:plane-normal plane)))
            "the planes are normalised as they are built, not on demand")
        ;; Outward-facing: a point inside is on the negative side of every plane.
        (is (< (+ (xna:vector3-dot (xna:plane-normal plane) (v3 0 0 0))
                  (xna:plane-d plane))
               0.0f0))))
    (let ((near (xna:bounding-frustum-near frustum)))
      (is (vector3~= (xna:plane-normal near) (v3 0 0 1)))
      (is (~= -4.0f0 (xna:plane-d near))))))

(test setting-the-matrix-rebuilds-the-frustum
  (let* ((frustum (test-frustum))
         (before (xna:bounding-frustum-get-corners frustum)))
    (setf (xna:bounding-frustum-matrix frustum)
          (xna:matrix-multiply
           (xna:matrix-create-look-at (v3 0 0 50) (v3 0 0 0) (v3 0 1 0))
           (xna:matrix-create-perspective-field-of-view
            xna:+math-helper-pi-over4+ 1.0 1.0 20.0)))
    (let ((after (xna:bounding-frustum-get-corners frustum)))
      (is (~= 49.0f0 (xna:vector3-z (aref after 0))))
      (is (not (vector3~= (aref before 0) (aref after 0)))))))

(test a-frustum-is-a-reference-type
  ;; XNA's BoundingFrustum is a class, not a value type: two names for one
  ;; frustum see one another's changes, and this projection keeps that.
  (let* ((frustum (test-frustum))
         (alias frustum))
    (setf (xna:bounding-frustum-matrix alias)
          (xna:matrix-multiply
           (xna:matrix-create-look-at (v3 0 0 9) (v3 0 0 0) (v3 0 1 0))
           (xna:matrix-create-perspective-field-of-view
            xna:+math-helper-pi-over4+ 1.0 1.0 20.0)))
    (is (~= 8.0f0 (xna:vector3-z (aref (xna:bounding-frustum-get-corners frustum) 0))))
    (is (xna:bounding-frustum-equal frustum alias))
    (is (not (xna:bounding-frustum-equal frustum (test-frustum :far 30.0))))))

(test a-frustum-needs-a-matrix
  (signals xna:cna-usage-error (make-instance 'xna:bounding-frustum)))

(test bounding-frustum-get-corners-fills-a-supplied-array
  (let ((frustum (test-frustum))
        (destination (make-array 8 :initial-element nil)))
    (is (eq destination (xna:bounding-frustum-get-corners frustum destination)))
    (is (~= 4.0f0 (xna:vector3-z (aref destination 0))))
    (signals xna:cna-argument-out-of-range-error
      (xna:bounding-frustum-get-corners frustum (make-array 7)))))

(test a-frustum-contains-points-with-a-small-slack
  (let ((frustum (test-frustum)))
    (is (eq :contains (xna:bounding-frustum-contains frustum (v3 0 0 0))))
    (is (eq :disjoint (xna:bounding-frustum-contains frustum (v3 0 0 50)))
        "behind the eye is outside")
    (is (eq :disjoint (xna:bounding-frustum-contains frustum (v3 100 0 0))))
    ;; The point test rejects at 1e-5 rather than at 0, so a point exactly on
    ;; the near plane is inside. No other Contains overload has that slack.
    (is (eq :contains (xna:bounding-frustum-contains frustum (v3 0 0 4))))
    (is (eq :disjoint (xna:bounding-frustum-contains frustum (v3 0 0 4.001))))))

(test a-frustum-contains-boxes-spheres-and-frustums
  (let ((frustum (test-frustum)))
    (is (eq :contains (xna:bounding-frustum-contains
                       frustum (xna:make-bounding-box (v3 -0.2 -0.2 -0.2)
                                                      (v3 0.2 0.2 0.2)))))
    (is (eq :intersects (xna:bounding-frustum-contains
                         frustum (xna:make-bounding-box (v3 -100 -100 -100)
                                                        (v3 100 100 100)))))
    (is (eq :disjoint (xna:bounding-frustum-contains
                       frustum (xna:make-bounding-box (v3 500 500 500)
                                                      (v3 501 501 501)))))
    (is (eq :contains (xna:bounding-frustum-contains
                       frustum (xna:make-bounding-sphere (v3 0 0 0) 0.5))))
    (is (eq :disjoint (xna:bounding-frustum-contains
                       frustum (xna:make-bounding-sphere (v3 0 0 500) 1.0))))
    (is (eq :contains (xna:bounding-frustum-contains frustum frustum)))
    (is (eq :contains (xna:bounding-frustum-contains
                       (test-frustum :far 40.0) (test-frustum :far 20.0)))
        "a longer frustum contains the shorter one it shares a near face with")))

(test a-frustum-intersects-convex-bodies-through-gjk
  (let ((frustum (test-frustum)))
    (is (xna:bounding-frustum-intersects
         frustum (xna:make-bounding-box (v3 -1 -1 -1) (v3 1 1 1))))
    (is (not (xna:bounding-frustum-intersects
              frustum (xna:make-bounding-box (v3 500 500 500) (v3 501 501 501)))))
    (is (xna:bounding-frustum-intersects
         frustum (xna:make-bounding-sphere (v3 0 0 0) 1.0)))
    (is (not (xna:bounding-frustum-intersects
              frustum (xna:make-bounding-sphere (v3 0 0 500) 1.0))))
    (is (xna:bounding-frustum-intersects frustum frustum))
    (is (not (xna:bounding-frustum-intersects
              frustum
              (make-instance 'xna:bounding-frustum
                             :matrix (xna:matrix-multiply
                                      (xna:matrix-create-look-at
                                       (v3 0 0 -500) (v3 0 0 -600) (v3 0 1 0))
                                      (xna:matrix-create-perspective-field-of-view
                                       xna:+math-helper-pi-over4+ 1.0 1.0 20.0))))))))

(test contains-and-intersects-answer-different-questions-about-a-box
  ;; Contains(BoundingBox) tests the box against the six planes one at a time,
  ;; which reports Intersects for a box in a corner region that touches no plane
  ;; slab jointly. Intersects(BoundingBox) runs GJK, which is exact but accepts
  ;; once the squared closest distance falls under 4e-5 of the largest support
  ;; length. So the two disagree in *both* directions, and this is XNA.
  (let ((frustum (test-frustum)))
    (let ((corner-box (xna:make-bounding-box (v3 -7.3 -12.3 -17.8)
                                             (v3 -3.7 -8.7 -14.2))))
      (is (eq :intersects (xna:bounding-frustum-contains frustum corner-box)))
      (is (not (xna:bounding-frustum-intersects frustum corner-box))
          "the plane test says maybe and GJK says no")))
  (let ((wide (make-instance 'xna:bounding-frustum
                             :matrix (xna:matrix-multiply
                                      (xna:matrix-create-look-at
                                       (v3 0 0 5) (v3 0 0 0) (v3 0 1 0))
                                      (xna:matrix-create-perspective-field-of-view
                                       xna:+math-helper-pi-over4+ 1.3 1.0 40.0))))
        (near-miss (xna:make-bounding-box (v3 3.410936 -11.468305 -4.1628323)
                                          (v3 11.094515 -3.9038002 2.6530204))))
    (is (eq :disjoint (xna:bounding-frustum-contains wide near-miss)))
    (is (xna:bounding-frustum-intersects wide near-miss)
        "GJK's tolerance accepts a gap of about a tenth of a unit here")))

(test a-frustum-sorts-a-plane-into-front-back-or-intersecting
  (let ((frustum (test-frustum)))
    (is (eq :intersecting (xna:bounding-frustum-intersects frustum (xna:make-plane 0 1 0 0))))
    (is (eq :back (xna:bounding-frustum-intersects frustum (xna:make-plane 0 1 0 -500))))
    (is (eq :front (xna:bounding-frustum-intersects frustum (xna:make-plane 0 1 0 500))))))

(test a-frustum-clips-a-ray
  (let ((frustum (test-frustum)))
    (is (~= 196.0f0 (xna:bounding-frustum-intersects
                     frustum (xna:make-ray (v3 0 0 200) (v3 0 0 -1))))
        "the ray enters at the near plane, z = 4")
    (is (= 0.0f0 (xna:bounding-frustum-intersects
                  frustum (xna:make-ray (v3 0 0 0) (v3 0 0 -1))))
        "a ray whose position is already inside answers zero")
    (is (null (xna:bounding-frustum-intersects
               frustum (xna:make-ray (v3 0 500 200) (v3 0 0 -1)))))
    (is (null (xna:bounding-frustum-intersects
               frustum (xna:make-ray (v3 0 0 200) (v3 0 0 1))))
        "pointing away misses")))

(test the-other-volumes-answer-the-frustum-members-they-owed
  (let* ((frustum (test-frustum))
         (inside (xna:make-bounding-box (v3 -0.2 -0.2 -0.2) (v3 0.2 0.2 0.2)))
         (outside (xna:make-bounding-box (v3 500 500 500) (v3 501 501 501)))
         (huge (xna:make-bounding-box (v3 -1000 -1000 -1000) (v3 1000 1000 1000)))
         (sphere (xna:make-bounding-sphere (v3 0 0 0) 0.5))
         (big-sphere (xna:make-bounding-sphere (v3 0 -5 -5) 100.0)))
    (is (xna:bounding-box-intersects inside frustum))
    (is (not (xna:bounding-box-intersects outside frustum)))
    (is (eq :contains (xna:bounding-box-contains huge frustum)))
    (is (eq :intersects (xna:bounding-box-contains inside frustum)))
    (is (eq :disjoint (xna:bounding-box-contains outside frustum)))
    (is (xna:bounding-sphere-intersects sphere frustum))
    (is (eq :contains (xna:bounding-sphere-contains big-sphere frustum)))
    (is (eq :disjoint (xna:bounding-sphere-contains
                       (xna:make-bounding-sphere (v3 0 0 900) 1.0) frustum)))
    (is (~= 196.0f0 (xna:ray-intersects (xna:make-ray (v3 0 0 200) (v3 0 0 -1)) frustum)))
    (is (eq :intersecting (xna:plane-intersects (xna:make-plane 0 1 0 0) frustum)))
    (let ((sphere (xna:bounding-sphere-create-from-frustum frustum)))
      (loop for corner across (xna:bounding-frustum-get-corners frustum)
            do (is (<= (xna:vector3-distance corner (xna:bounding-sphere-center sphere))
                       (+ (xna:bounding-sphere-radius sphere) 1.0e-3))
                   "~a is outside the sphere over the frustum's corners" corner)))))
