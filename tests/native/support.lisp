;;;; support.lisp --- shared machinery for the native layer.
;;;;
;;;; A native test never skips because the library misbehaved. It skips only when
;;;; no library was named at all, and the runner reports that as NOT RUN.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-posix))

(defvar *qualified-library-path* (uiop:getenv "CNA_NATIVE_LIBRARY")
  "The library this image was told to qualify against, captured before any test
can change the environment variable.")

(defun restore-qualified-library ()
  "Put the environment and the resolver back the way the suite found them."
  (when *qualified-library-path*
    (sb-posix:setenv "CNA_NATIVE_LIBRARY" *qualified-library-path* 1))
  (setf int::*native-library-path* nil
        int::*native-library-handle* nil)
  (int:ensure-abi-admitted))

(defvar *native-tests-attempted* 0)
(defvar *native-tests-skipped* 0)

(defmacro define-native-test (name &body body)
  "Define a test that needs a real CNA C ABI library.

Without CNA_NATIVE_LIBRARY it does not run and says so. With it, it runs: a
library that cannot be loaded, or that reports an ABI this build has not
qualified, is a failure and not a skip."
  `(test ,name
     (if (native-library-requested-p)
         (progn (incf *native-tests-attempted*) ,@body)
         (progn (incf *native-tests-skipped*)
                (skip "CNA_NATIVE_LIBRARY is not set; ~a did not run" ',name)))))

(defclass counting-game (xna:game)
  ((initializes :initform 0 :accessor initializes)
   (loads       :initform 0 :accessor loads)
   (begin-runs  :initform 0 :accessor begin-runs)
   (updates     :initform 0 :accessor updates)
   (begin-draws :initform 0 :accessor begin-draws)
   (draws       :initform 0 :accessor draws)
   (end-draws   :initform 0 :accessor end-draws)
   (end-runs    :initform 0 :accessor end-runs)
   (unloads     :initform 0 :accessor unloads)
   (exitings    :initform 0 :accessor exitings)
   (exit-after  :initarg :exit-after :initform nil :accessor exit-after)
   (fail-on-update :initarg :fail-on-update :initform nil :accessor fail-on-update)
   (fail-on-unload :initarg :fail-on-unload :initform nil :accessor fail-on-unload)
   (last-game-time :initform nil :accessor last-game-time))
  (:documentation "A game that counts every lifecycle call it receives."))

;; CALL-NEXT-METHOD, and it is not optional: XNA's base `Initialize' is where
;; `HookDeviceEvents' runs, so a C# override that omits `base.Initialize()' hooks
;; no device events -- and this projection reproduces that rather than hiding it.
;; A fixture that skipped it would be a game no XNA program should be written
;; like, and every lane that disposes a graphics device manager depends on the
;; hook being installed. See src/runtime/game-device-events.lisp.
(defmethod xna:initialize    ((game counting-game))
  (incf (initializes game))
  (call-next-method))
(defmethod xna:load-content  ((game counting-game)) (incf (loads game)))
(defmethod xna:begin-run     ((game counting-game)) (incf (begin-runs game)))
(defmethod xna:end-run       ((game counting-game)) (incf (end-runs game)))
(defmethod xna:end-draw      ((game counting-game)) (incf (end-draws game)))
(defmethod xna:on-exiting    ((game counting-game)) (incf (exitings game)))

(defmethod xna:unload-content ((game counting-game))
  (incf (unloads game))
  (when (fail-on-unload game)
    (error "deliberate failure in unload-content")))

(defmethod xna:begin-draw ((game counting-game))
  (incf (begin-draws game))
  t)

(defmethod xna:update ((game counting-game) game-time)
  (incf (updates game))
  (setf (last-game-time game) game-time)
  (when (eql (fail-on-update game) (updates game))
    (error "deliberate failure in update on frame ~d" (updates game)))
  (when (and (exit-after game) (>= (updates game) (exit-after game)))
    (xna:exit game)))

(defmethod xna:draw ((game counting-game) game-time)
  (declare (ignore game-time))
  (incf (draws game)))

(defmacro with-counting-game ((variable &rest initargs) &body body)
  `(let ((,variable (make-instance 'counting-game ,@initargs)))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

(defclass skipping-game (counting-game) ()
  (:documentation "A game whose BEGIN-DRAW answers NIL, so no frame draws."))

(defmethod xna:begin-draw ((game skipping-game))
  (incf (begin-draws game))
  nil)

(defclass reentrant-game (counting-game) ()
  (:documentation "A game that tries to run a frame from inside a frame."))

(defmethod xna:update ((game reentrant-game) game-time)
  (declare (ignore game-time))
  (incf (updates game))
  (xna:tick game))

(defclass byte-decoding-game (counting-game)
  ((payload :initarg :payload :reader payload)
   (decoded :initform nil :accessor decoded))
  (:documentation "A game that decodes an in-memory image during LOAD-CONTENT."))

(defmethod xna:load-content ((game byte-decoding-game))
  (call-next-method)
  (setf (decoded game)
        (microsoft.xna.framework.graphics:texture-2d-from-png-bytes
         (xna:graphics-device game) (payload game))))

(defclass draw-shapes-game (counting-game)
  ((manager :initform nil :accessor manager)
   (batch   :initform nil :accessor batch)
   (texture :initform nil :accessor texture)
   (accepted :initform 0 :accessor accepted)
   (draw-error :initform nil :accessor draw-error))
  (:documentation
   "A game that submits one sprite per XNA texture-Draw overload, all seven."))

(defmethod initialize-instance :after ((game draw-shapes-game) &key)
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game)))

(defmethod xna:load-content ((game draw-shapes-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    (setf (texture game) (microsoft.xna.framework.graphics:texture-2d-from-png-file
                          device (fixture-path "cna-lisp-mark.png"))
          (batch game) (make-instance 'microsoft.xna.framework.graphics:sprite-batch
                                      :graphics-device device))))

(defmethod xna:draw ((game draw-shapes-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (handler-case
      (let ((batch (batch game))
            (texture (texture game))
            (position (xna:make-vector2 4.5 6.25))
            (destination (xna:make-rectangle 0 0 32 32))
            (source (xna:make-rectangle 0 0 16 16))
            (origin (xna:make-vector2 8.0 8.0)))
        (microsoft.xna.framework.graphics:begin batch)
        (unwind-protect
             (flet ((submit (&rest arguments)
                      (apply #'microsoft.xna.framework.graphics:draw-texture
                             batch texture arguments)
                      (incf (accepted game))))
               ;; Draw(t, Vector2, Color)
               (submit :position position :color (xna:white))
               ;; Draw(t, Vector2, Rectangle?, Color)
               (submit :position position :source source :color (xna:white))
               ;; Draw(t, Vector2, Rectangle?, Color, float, Vector2, float, Effects, float)
               (submit :position position :source source :color (xna:white)
                       :rotation 0.5 :origin origin :scale 2.0
                       :effects :none :layer-depth 0.25)
               ;; ... and the Vector2-scale one
               (submit :position position :source source :color (xna:white)
                       :rotation 0.5 :origin origin :scale (xna:make-vector2 1.5 2.5)
                       :effects :flip-horizontally :layer-depth 0.5)
               ;; Draw(t, Rectangle, Color)
               (submit :destination destination :color (xna:white))
               ;; Draw(t, Rectangle, Rectangle?, Color)
               (submit :destination destination :source source :color (xna:white))
               ;; Draw(t, Rectangle, Rectangle?, Color, float, Vector2, Effects, float)
               (submit :destination destination :source source :color (xna:white)
                       :rotation 0.5 :origin origin
                       :effects :flip-vertically :layer-depth 0.75))
          (microsoft.xna.framework.graphics:end batch)))
    (error (condition) (setf (draw-error game) condition))))
