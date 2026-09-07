;;;; owned-graphics-device-consumer.lisp --- render without a Game, publicly.
;;;;
;;;; **What this is for.** Every other graphics program in this repository
;;;; begins with `(make-instance 'xna:game)', because until this closure the only
;;;; `GraphicsDevice' a program could have was the one the runtime creates and
;;;; lends for the duration of a lifecycle callback. This file is the evidence
;;;; that a second shape exists and is reachable from ordinary public code: it
;;;; enumerates the adapters, constructs a `GraphicsDevice' with XNA's own
;;;; constructor, draws through it *outside every callback there is not*, reads
;;;; the back buffer, checks the pixels and disposes everything -- and it makes
;;;; no `GAME' at any point.
;;;;
;;;; It is the second no-game surface in this repository after `Storage', and the
;;;; first no-game *graphics* surface.
;;;;
;;;; **The audit this file has to pass** is in the script that runs it, and it is
;;;; the same mechanical one every other consumer passes: no
;;;; `CNA-LISP.INTERNAL', no `CFFI', no handle, no result code, no private
;;;; `%'-symbol -- plus the one this consumer adds, that it never constructs a
;;;; `GAME'. If a standalone renderer needed any of those, the projection would
;;;; be incomplete and this is how that would be found.
;;;;
;;;; **What it claims depends on the renderer, and it says which.** Under a
;;;; rasterising renderer -- `-DCNA_GRAPHICS_RENDERER=SOFTWARE', which needs no
;;;; display -- it checks real pixels and reports `pixels'. Under HEADLESS the
;;;; back-buffer readback honestly refuses, and it reports `no-readback' and
;;;; makes no pixel claim at all. Neither is a claim about a physical monitor.

(defpackage #:cna-lisp-owned-graphics-device-consumer
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework)
                    (#:gfx #:microsoft.xna.framework.graphics))
  (:export #:main))

(in-package #:cna-lisp-owned-graphics-device-consumer)

(defparameter *width* 32 "Back-buffer width. Small, because the point is the pixels.")
(defparameter *height* 16 "Back-buffer height.")

(defun report (key control &rest arguments)
  "Print one machine-readable line: `OWNED-DEVICE <key> <text>'."
  (format t "~&OWNED-DEVICE ~a ~?~%" key control arguments)
  (finish-output))

(defun describe-colour (colour)
  (format nil "~d ~d ~d ~d"
          (xna:color-r colour) (xna:color-g colour)
          (xna:color-b colour) (xna:color-a colour)))

(defun make-parameters ()
  "The presentation parameters this program asks for.

`MAKE-INSTANCE' with no arguments is XNA's parameterless constructor; only the
back-buffer size is changed from the defaults."
  (let ((parameters (make-instance 'gfx:presentation-parameters)))
    (setf (gfx:back-buffer-width parameters) *width*
          (gfx:back-buffer-height parameters) *height*)
    parameters))

(defun triangle ()
  "A right triangle over the lower-left half of clip space, in its own colour."
  (let ((red (xna:make-color 255 0 0 255)))
    (vector (gfx:make-vertex-position-color (xna:make-vector3 -0.5 -0.5 0.0) red)
            (gfx:make-vertex-position-color (xna:make-vector3 -0.5 0.5 0.0) red)
            (gfx:make-vertex-position-color (xna:make-vector3 0.5 -0.5 0.0) red))))

(defun draw-through (device)
  "Clear, then draw one triangle through a BasicEffect pass. Answers nothing."
  (gfx:clear device (xna:cornflower-blue))
  (let ((effect (make-instance 'gfx:basic-effect :graphics-device device)))
    (unwind-protect
         (progn
           (report "effect-device"
                   "~a" (if (eq device (gfx:graphics-resource-graphics-device effect))
                            "the effect belongs to this device"
                            "WRONG DEVICE"))
           (setf (gfx:effect-vertex-color-enabled effect) t
                 (gfx:effect-lighting-enabled effect) nil)
           (dolist (pass (gfx:collection-elements
                          (gfx:effect-technique-passes
                           (gfx:effect-current-technique effect))))
             (gfx:apply-effect-pass pass))
           (gfx:draw-user-primitives device :triangle-list (triangle)
                                     :vertex-offset 0 :primitive-count 1)
           (report "drew" "one triangle through a BasicEffect pass"))
      (xna:dispose effect))))

(defun check-pixels (device)
  "Read the back buffer and say what is there. Answers T when pixels were checked.

Under a renderer with no honest readback this reports the refusal and answers
NIL, which is a capability result and not a failure -- and the reason the member
is worth anything as evidence when it does answer."
  (let ((pixels (handler-case (gfx:get-back-buffer-data device)
                  (xna:cna-not-supported-error ()
                    (report "no-readback"
                            "this renderer has no back-buffer readback; no pixel ~
                             claim is made")
                    (return-from check-pixels nil)))))
    (report "readback" "~d pixels" (length pixels))
    (let ((cleared 0) (drawn 0) (other 0)
          (clear-colour (xna:cornflower-blue))
          (triangle-colour (xna:make-color 255 0 0 255)))
      (map nil (lambda (pixel)
                 (cond ((xna:color-equal pixel clear-colour) (incf cleared))
                       ((xna:color-equal pixel triangle-colour) (incf drawn))
                       (t (incf other))))
           pixels)
      (report "first-pixel" "~a" (describe-colour (aref pixels 0)))
      (report "counts" "cleared=~d drawn=~d other=~d" cleared drawn other)
      ;; The two claims this program is for: the clear reached the buffer, and
      ;; the draw covered some of it and not all of it.
      (report "pixels"
              "~a" (cond ((zerop drawn) "FAIL the triangle covered no pixel")
                         ((zerop cleared) "FAIL the triangle covered every pixel")
                         (t "a clear and a draw both reached the back buffer")))
      (and (plusp drawn) (plusp cleared)))))

(defun main ()
  "Render through a device this program constructs, and print what happened.

Answers an exit code: 0 when everything this renderer can prove was proved."
  ;; **No game is constructed here or anywhere below.** The native library is
  ;; loaded and its ABI admitted by the first graphics call, exactly as the
  ;; storage surface does it.
  (let ((adapters (gfx:graphics-adapter-adapters)))
    (report "adapters" "~d" (length adapters))
    (let ((adapter (gfx:graphics-adapter-default-adapter)))
      ;; **The adapter is described after the device exists, and that order is
      ;; not a stylistic choice.** Every CNA adapter route takes a
      ;; graphics-device handle -- there is no route that does not -- so an
      ;; adapter can answer questions only while some device is alive.
      ;; Enumerating them is the one exception, and it is an exception this
      ;; binding arranges rather than one CNA offers: `Adapters' and
      ;; `DefaultAdapter' make a device for the question and dispose it again.
      ;; XNA's are static properties with no such rule, which is why both are
      ;; reported partial. See docs/limitations.md.
      (let ((device (make-instance 'gfx:graphics-device
                                   :adapter adapter
                                   :graphics-profile :reach
                                   :presentation-parameters (make-parameters))))
        (unwind-protect
             (progn
               ;; The device answers the adapter it was given, by identity --
               ;; which is what XNA's own comparisons depend on.
               (report "adapter-identity"
                       "~a" (if (eq adapter (gfx:adapter device))
                                "the device answers the adapter it was given"
                                "WRONG ADAPTER"))
               (report "adapter" "~s" (gfx:graphics-adapter-description adapter))
               (report "profile" "~s" (gfx:graphics-profile device))
               (let ((viewport (gfx:viewport device)))
                 (report "viewport" "~dx~d"
                         (gfx:viewport-width viewport) (gfx:viewport-height viewport)))
               (report "renderer" "~s" (gfx:renderer-name device))
               (draw-through device)
               (let ((checked (check-pixels device)))
                 (report "done" "~a"
                         (if checked
                             "pixels checked, with no game in this image"
                             "lifecycle and commands only, with no game in this image"))
                 0))
          (progn
            (xna:dispose device)
            (report "disposed" "~a" (if (xna:disposed-p device) "yes" "no"))))))))
