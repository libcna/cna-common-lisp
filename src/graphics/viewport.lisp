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
        (/ (coerce w 'single-float) (coerce h 'single-float)))))

(defun viewport-bounds (viewport)
  "Viewport.Bounds."
  (microsoft.xna.framework:make-rectangle
   (viewport-x viewport) (viewport-y viewport)
   (viewport-width viewport) (viewport-height viewport)))

(defun viewport-title-safe-area (viewport)
  "Viewport.TitleSafeArea.

XNA insets by one twentieth on each axis only once the viewport is at least
640x480; below that the whole viewport is title safe. The arithmetic is the
original's integer arithmetic."
  (let ((x (viewport-x viewport)) (y (viewport-y viewport))
        (w (viewport-width viewport)) (h (viewport-height viewport)))
    (if (and (>= w 640) (>= h 480))
        (let ((dx (+ (truncate (* w 5) 100) x))
              (dy (+ (truncate (* h 5) 100) y)))
          (microsoft.xna.framework:make-rectangle
           dx dy (- w (* 2 (- dx x))) (- h (* 2 (- dy y)))))
        (microsoft.xna.framework:make-rectangle x y w h))))

(defun viewport-equal (left right)
  (and (= (viewport-x left) (viewport-x right))
       (= (viewport-y left) (viewport-y right))
       (= (viewport-width left) (viewport-width right))
       (= (viewport-height left) (viewport-height right))
       (= (viewport-min-depth left) (viewport-min-depth right))
       (= (viewport-max-depth left) (viewport-max-depth right))))
