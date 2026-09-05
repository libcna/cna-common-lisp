;;;; viewport.lisp --- Microsoft.Xna.Framework.Graphics.Viewport.

(in-package #:microsoft.xna.framework.graphics)

(defstruct (viewport
            (:constructor make-viewport
                (&optional (x 0) (y 0) (width 0) (height 0)
                           (min-depth 0.0f0) (max-depth 1.0f0)))
            (:copier copy-viewport))
  "Microsoft.Xna.Framework.Graphics.Viewport: a render-target rectangle and a
depth range. A value type, copied in and out of the objects that store it."
  (x 0 :type (signed-byte 32))
  (y 0 :type (signed-byte 32))
  (width 0 :type (signed-byte 32))
  (height 0 :type (signed-byte 32))
  (min-depth 0.0f0 :type single-float)
  (max-depth 1.0f0 :type single-float))

(defun viewport-aspect-ratio (viewport)
  "Viewport.AspectRatio. Zero when either extent is zero, exactly as XNA's is,
rather than a division by zero."
  (let ((w (viewport-width viewport)) (h (viewport-height viewport)))
    (if (or (zerop w) (zerop h))
        0.0f0
        (cna-lisp.internal:with-binary32-semantics
          (/ (coerce w 'single-float) (coerce h 'single-float))))))

(defun viewport-bounds (viewport)
  "Viewport.Bounds."
  (microsoft.xna.framework:make-rectangle
   (viewport-x viewport) (viewport-y viewport)
   (viewport-width viewport) (viewport-height viewport)))

(defun (setf viewport-bounds) (rectangle viewport)
  "Viewport.Bounds's setter: the position and extents follow the rectangle."
  (setf (viewport-x viewport) (microsoft.xna.framework:rectangle-x rectangle)
        (viewport-y viewport) (microsoft.xna.framework:rectangle-y rectangle)
        (viewport-width viewport) (microsoft.xna.framework:rectangle-width rectangle)
        (viewport-height viewport) (microsoft.xna.framework:rectangle-height rectangle))
  rectangle)

(defun %title-safe-area (x y width height)
  "Viewport.GetTitleSafeArea, which DisplayMode.TitleSafeArea also calls.

XNA insets by one twentieth on each axis only once the area is at least 640x480;
below that the whole area is title safe. The arithmetic is the original's integer
arithmetic. Shared by VIEWPORT-TITLE-SAFE-AREA and DISPLAY-MODE-TITLE-SAFE-AREA
because in the assembly they are literally the same static method."
  (if (and (>= width 640) (>= height 480))
      (let ((dx (+ (truncate (* width 5) 100) x))
            (dy (+ (truncate (* height 5) 100) y)))
        (microsoft.xna.framework:make-rectangle
         dx dy (- width (* 2 (- dx x))) (- height (* 2 (- dy y)))))
      (microsoft.xna.framework:make-rectangle x y width height)))

(defun viewport-title-safe-area (viewport)
  "Viewport.TitleSafeArea.

The arithmetic is `Viewport.GetTitleSafeArea', a static method
`DisplayMode.TitleSafeArea' calls too -- so it lives in one place here as well.
See %TITLE-SAFE-AREA in src/graphics/display.lisp."
  (%title-safe-area (viewport-x viewport) (viewport-y viewport)
                    (viewport-width viewport) (viewport-height viewport)))

(defun viewport-equal (left right)
  (and (= (viewport-x left) (viewport-x right))
       (= (viewport-y left) (viewport-y right))
       (= (viewport-width left) (viewport-width right))
       (= (viewport-height left) (viewport-height right))
       (= (viewport-min-depth left) (viewport-min-depth right))
       (= (viewport-max-depth left) (viewport-max-depth right))))

;;; --- projecting into and out of the viewport --------------------------------

(defun %within-epsilon (a b)
  "Viewport.WithinEpsilon.

Not an epsilon in any useful sense: the tolerance is 1.401298e-45, the smallest
positive subnormal binary32, so for any ordinary number this is exact equality.
The consequence is visible below -- the perspective divide is skipped only when
w is *exactly* one, not merely close to it -- and it is XNA's, so it is here."
  (cna-lisp.internal:with-binary32-semantics
    (let ((difference (- a b)))
      (and (<= -1.401298f-45 difference) (not (> difference 1.401298f-45))))))

(defun make-viewport-from-bounds (bounds)
  "Viewport(Rectangle): the rectangle's position and size, depth 0 to 1.

A separate name from MAKE-VIEWPORT, as MAKE-PLANE-FROM-VECTOR4 is: one function
taking either four integers or one rectangle would be telling two constructors
apart by the run-time type of an argument."
  (make-viewport (microsoft.xna.framework:rectangle-x bounds)
                 (microsoft.xna.framework:rectangle-y bounds)
                 (microsoft.xna.framework:rectangle-width bounds)
                 (microsoft.xna.framework:rectangle-height bounds)
                 0.0f0 1.0f0))

(defun %viewport-combined-matrix (projection view world)
  "The world-view-projection product, in the order the original multiplies it."
  (microsoft.xna.framework:matrix-multiply
   (microsoft.xna.framework:matrix-multiply world view) projection))

(defun %perspective-divide (vector w)
  (if (%within-epsilon w 1.0f0)
      vector
      (microsoft.xna.framework:vector3-divide vector w)))

(defun %homogeneous-w (source matrix)
  (cna-lisp.internal:with-binary32-semantics
    (+ (+ (+ (* (microsoft.xna.framework:vector3-x source)
                (microsoft.xna.framework:matrix-m14 matrix))
             (* (microsoft.xna.framework:vector3-y source)
                (microsoft.xna.framework:matrix-m24 matrix)))
          (* (microsoft.xna.framework:vector3-z source)
             (microsoft.xna.framework:matrix-m34 matrix)))
       (microsoft.xna.framework:matrix-m44 matrix))))

(defun viewport-project (viewport source projection view world)
  "Viewport.Project: a world-space point to screen coordinates.

The Y axis is flipped -- screen Y grows downwards where clip-space Y grows up --
and the depth is mapped into MIN-DEPTH..MAX-DEPTH rather than left in 0..1."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((matrix (%viewport-combined-matrix projection view world))
           (transformed (microsoft.xna.framework:vector3-transform source matrix))
           (w (%homogeneous-w source matrix))
           (v (%perspective-divide transformed w)))
      (microsoft.xna.framework:make-vector3
       (+ (* (* (+ (microsoft.xna.framework:vector3-x v) 1.0f0) 0.5f0)
             (float (viewport-width viewport) 1.0f0))
          (float (viewport-x viewport) 1.0f0))
       (+ (* (* (+ (- (microsoft.xna.framework:vector3-y v)) 1.0f0) 0.5f0)
             (float (viewport-height viewport) 1.0f0))
          (float (viewport-y viewport) 1.0f0))
       (+ (* (microsoft.xna.framework:vector3-z v)
             (- (viewport-max-depth viewport) (viewport-min-depth viewport)))
          (viewport-min-depth viewport))))))

(defun viewport-unproject (viewport source projection view world)
  "Viewport.Unproject: a screen-space point back to world coordinates.

The homogeneous divisor is computed from the *normalised* source -- the point
after it has been mapped back into clip space -- not from the screen coordinates
the caller passed, which is easy to get backwards."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((matrix (microsoft.xna.framework:matrix-invert
                    (%viewport-combined-matrix projection view world)))
           (normalised
             (microsoft.xna.framework:make-vector3
              (- (* (/ (- (microsoft.xna.framework:vector3-x source)
                          (float (viewport-x viewport) 1.0f0))
                       (float (viewport-width viewport) 1.0f0))
                    2.0f0)
                 1.0f0)
              (- (- (* (/ (- (microsoft.xna.framework:vector3-y source)
                             (float (viewport-y viewport) 1.0f0))
                          (float (viewport-height viewport) 1.0f0))
                       2.0f0)
                    1.0f0))
              (/ (- (microsoft.xna.framework:vector3-z source)
                    (viewport-min-depth viewport))
                 (- (viewport-max-depth viewport) (viewport-min-depth viewport)))))
           (transformed (microsoft.xna.framework:vector3-transform normalised matrix))
           (w (%homogeneous-w normalised matrix)))
      (%perspective-divide transformed w))))
