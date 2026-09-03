;;;; hello-cna.lisp --- the smallest complete CNA-Lisp program.
;;;;
;;;; Load CNA-Lisp, then this file, then call (hello-cna:main). Or, from a shell:
;;;;
;;;;   CNA_NATIVE_LIBRARY=/absolute/path/to/libcna_c_api.so \
;;;;   CL_SOURCE_REGISTRY="$PWD//" \
;;;;     sbcl --non-interactive \
;;;;          --eval '(asdf:load-system "cna-common-lisp")' \
;;;;          --load examples/hello-cna.lisp \
;;;;          --eval '(hello-cna:main 60)'
;;;;
;;;; It is deliberately the same shape as the template repository's game, minus
;;;; the canary machinery: a CLOS subclass, methods on the lifecycle generic
;;;; functions, and disposal in the documented order.

(defpackage #:hello-cna
  (:use #:cl)
  (:local-nicknames (#:xna   #:microsoft.xna.framework)
                    (#:gfx   #:microsoft.xna.framework.graphics)
                    (#:input #:microsoft.xna.framework.input))
  (:export #:hello-game #:main))

(in-package #:hello-cna)

(defclass hello-game (xna:game)
  ((manager      :initform nil :accessor manager)
   (sprite-batch :initform nil :accessor sprite-batch)
   (texture      :initform nil :accessor texture)
   (frames       :initarg :frames :initform nil :reader frames)
   (drawn        :initform 0 :accessor drawn)))

(defmethod initialize-instance :after ((game hello-game) &key)
  ;; XNA constructs the graphics device manager in the game's constructor.
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game)))

(defmethod xna:load-content ((game hello-game))
  (let ((device (xna:graphics-device game)))
    (format t "~&renderer: ~a~%" (gfx:renderer-name device))
    (setf (texture game)
          (gfx:texture-2d-from-png-file
           device (namestring (asdf:system-relative-pathname
                               "cna-common-lisp" "tests/fixtures/cna-lisp-mark.png")))
          (sprite-batch game)
          (make-instance 'gfx:sprite-batch :graphics-device device))))

(defmethod xna:update ((game hello-game) game-time)
  (declare (ignore game-time))
  (unless (frames game)
    (when (input:is-key-down (input:keyboard-get-state) :escape)
      (xna:exit game))))

(defmethod xna:draw ((game hello-game) game-time)
  (declare (ignore game-time))
  (incf (drawn game))
  (gfx:clear (xna:graphics-device game) (xna:cornflower-blue))
  (gfx:begin (sprite-batch game))
  (unwind-protect
       (gfx:draw-texture (sprite-batch game) (texture game)
                         :position (xna:make-vector2 100.0 100.0)
                         :color (xna:white))
    (gfx:end (sprite-batch game))))

(defun main (&optional frames)
  "Run the game. With FRAMES, run exactly that many; otherwise until Escape.

A deterministic run uses variable timing: under a fixed time step a frame that
overran its target is followed by catch-up updates, so a frame count would not be
an update count."
  (let ((game (make-instance 'hello-game :frames frames
                                         :window-title "Hello CNA-Lisp")))
    (unwind-protect
         (if frames
             (progn (setf (xna:is-fixed-time-step game) nil)
                    (dotimes (i frames) (xna:run-one-frame game)))
             (xna:run game))
      ;; Children before parent: CNA refuses the other order, and CNA-Lisp
      ;; refuses it one step earlier with a diagnosable condition.
      (progn
        (when (sprite-batch game) (xna:dispose (sprite-batch game)))
        (when (texture game) (xna:dispose (texture game)))
        (when (manager game) (xna:dispose (manager game)))
        (xna:dispose game)))
    (format t "~&drew ~d frame~:p~%" (drawn game))
    (drawn game)))
