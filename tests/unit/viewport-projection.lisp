;;;; viewport-projection.lisp --- Viewport.Project and Viewport.Unproject.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defun projection-fixtures ()
  (values (gfx:make-viewport 0 0 800 480)
          (xna:matrix-create-perspective-field-of-view
           xna:+math-helper-pi-over4+ (/ 800.0 480.0) 1.0 100.0)
          (xna:matrix-create-look-at (v3 0 0 10) (v3 0 0 0) (v3 0 1 0))
          (xna:matrix-identity)))

(test a-viewport-from-a-rectangle-takes-the-full-depth-range
  (let ((viewport (gfx:make-viewport-from-bounds (xna:make-rectangle 10 20 640 480))))
    (is (= 10 (gfx:viewport-x viewport)))
    (is (= 20 (gfx:viewport-y viewport)))
    (is (= 640 (gfx:viewport-width viewport)))
    (is (= 480 (gfx:viewport-height viewport)))
    (is (= 0.0f0 (gfx:viewport-min-depth viewport)))
    (is (= 1.0f0 (gfx:viewport-max-depth viewport)))))

(test projecting-the-origin-lands-in-the-middle-of-the-viewport
  (multiple-value-bind (viewport projection view world) (projection-fixtures)
    (let ((screen (gfx:viewport-project viewport (v3 0 0 0) projection view world)))
      (is (~= 400.0f0 (xna:vector3-x screen) 1.0e-3))
      (is (~= 240.0f0 (xna:vector3-y screen) 1.0e-3))
      (is (< 0.0f0 (xna:vector3-z screen) 1.0f0)))))

(test the-screen-y-axis-points-the-other-way
  ;; Clip-space Y grows upwards and screen Y grows down, so a point above the
  ;; camera's centre projects to a *smaller* Y.
  (multiple-value-bind (viewport projection view world) (projection-fixtures)
    (let ((up (gfx:viewport-project viewport (v3 0 1 0) projection view world))
          (centre (gfx:viewport-project viewport (v3 0 0 0) projection view world)))
      (is (< (xna:vector3-y up) (xna:vector3-y centre)))
      (is (~= (xna:vector3-x up) (xna:vector3-x centre) 1.0e-3)))))

(test project-and-unproject-are-inverses
  (multiple-value-bind (viewport projection view world) (projection-fixtures)
    (dolist (point (list (v3 0 0 0) (v3 1 2 -3) (v3 -4 1.5 2)))
      (let* ((screen (gfx:viewport-project viewport point projection view world))
             (back (gfx:viewport-unproject viewport screen projection view world)))
        (is (vector3~= point back 1.0e-2)
            "~a projected and unprojected to ~a" point back)))))

(test the-viewport-offset-and-depth-range-move-the-answer
  (multiple-value-bind (viewport projection view world) (projection-fixtures)
    (declare (ignore viewport))
    (let* ((offset (gfx:make-viewport 100 50 800 480 0.25 0.75))
           (screen (gfx:viewport-project offset (v3 0 0 0) projection view world)))
      (is (~= 500.0f0 (xna:vector3-x screen) 1.0e-3) "X carries the viewport's X")
      (is (~= 290.0f0 (xna:vector3-y screen) 1.0e-3))
      (is (< 0.25f0 (xna:vector3-z screen) 0.75f0)
          "and the depth lands inside the viewport's own range")
      ;; The round trip still holds with an offset viewport and a narrow range.
      (is (vector3~= (v3 0 0 0)
                     (gfx:viewport-unproject offset screen projection view world)
                     1.0e-2)))))

(test the-perspective-divide-is-skipped-only-on-an-exact-one
  ;; XNA's WithinEpsilon uses 1.401298e-45, the smallest positive subnormal, so
  ;; for any ordinary number it is exact equality. An identity transform gives
  ;; w = 1 exactly and is left alone; anything else divides.
  (let ((viewport (gfx:make-viewport 0 0 2 2))
        (identity (xna:matrix-identity)))
    (let ((screen (gfx:viewport-project viewport (v3 0.5 0.25 0.75)
                                        identity identity identity)))
      ;; x = (0.5 + 1) * 0.5 * 2 + 0 = 1.5; y = (-0.25 + 1) * 0.5 * 2 = 0.75
      (is (= 1.5f0 (xna:vector3-x screen)))
      (is (= 0.75f0 (xna:vector3-y screen)))
      (is (= 0.75f0 (xna:vector3-z screen))))))
