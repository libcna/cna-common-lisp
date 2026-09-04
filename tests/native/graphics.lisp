;;;; graphics.lisp --- the real graphics slice: device, PNG, SpriteBatch.
;;;;
;;;; HEADLESS proves that the lifecycle ran, the device was borrowed, the
;;;; commands were accepted and the resources were created and destroyed. It
;;;; proves nothing about pixels, and nothing here claims otherwise.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass graphics-game (counting-game)
  ((manager :initform nil :accessor manager)
   (batch   :initform nil :accessor batch)
   (texture :initform nil :accessor texture)
   (renderer :initform nil :accessor renderer)
   (viewport :initform nil :accessor viewport)
   (draw-error :initform nil :accessor draw-error))
  (:documentation "A game that does the whole Foundation 1 graphics slice."))

(defmethod initialize-instance :after ((game graphics-game) &key)
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game))
  ;; Variable timing, for the reason NEXT.md records: a fixed time step does not
  ;; make a frame count an update count, because a frame that overruns its target
  ;; is followed by catch-up updates with no draws of their own. This fixture
  ;; overruns a 60 Hz step on its first frame by a wide margin -- the first
  ;; state-bearing Begin is where CNA creates its native state objects, measured
  ;; here at tens of milliseconds once, and under a microsecond every frame after
  ;; -- so an exact frame claim under fixed timing would be measuring that
  ;; warm-up rather than the game loop.
  (setf (xna:is-fixed-time-step game) nil))

(defmethod xna:load-content ((game graphics-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    (setf (renderer game) (gfx:renderer-name device)
          (viewport game) (gfx:viewport device)
          (texture game) (gfx:texture-2d-from-png-file device (fixture-path "cna-lisp-mark.png"))
          (batch game) (make-instance 'gfx:sprite-batch :graphics-device device))))

(defmethod xna:draw ((game graphics-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (handler-case
      (progn
        (gfx:clear (xna:graphics-device game) (xna:cornflower-blue))
        (gfx:begin (batch game))
        (unwind-protect
             (gfx:draw-texture (batch game) (texture game)
                               :position (xna:make-vector2 10.0 20.0)
                               :source (xna:make-rectangle 0 0 32 32)
                               :color (xna:white)
                               :rotation 0.5
                               :origin (xna:make-vector2 16.0 16.0)
                               :scale 2.0
                               :effects :flip-horizontally
                               :layer-depth 0.25)
          (gfx:end (batch game))))
    (error (condition) (setf (draw-error game) condition))))

(defmacro with-graphics-game ((variable &rest initargs) &body body)
  `(let ((,variable (make-instance 'graphics-game ,@initargs)))
     (unwind-protect (progn ,@body)
       (progn
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (ignore-errors (xna:dispose ,variable))))))

(define-native-test the-whole-graphics-slice-runs
  (with-graphics-game (game :exit-after 3)
    (xna:run game)
    (is (null (draw-error game)) "drawing failed: ~a" (draw-error game))
    (is (stringp (renderer game)))
    (is (plusp (length (renderer game))))
    (is (typep (viewport game) 'gfx:viewport))
    (is (plusp (gfx:viewport-width (viewport game))))
    (is (plusp (gfx:viewport-height (viewport game))))
    (is (typep (texture game) 'gfx:texture-2d))
    (is (typep (batch game) 'gfx:sprite-batch))
    (is (not (xna:is-fixed-time-step game))
        "this fixture runs on variable timing; see the fixture's own comment")
    (is (= 3 (updates game)))
    (is (= 2 (draws game)))))

(define-native-test the-decoded-texture-reports-the-images-own-extent
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (is (= 64 (gfx:width (texture game))))
    (is (= 64 (gfx:height (texture game))))
    (is (plusp (gfx:level-count (texture game))))
    (is (typep (gfx:format-of (texture game)) 'gfx:surface-format))
    (let ((bounds (gfx:bounds (texture game))))
      (is (= 64 (xna:rectangle-width bounds)))
      (is (= 0 (xna:rectangle-x bounds))))))

(define-native-test a-texture-can-be-decoded-from-bytes
  (let ((bytes (with-open-file (stream (fixture-path "cna-lisp-mark.png")
                                       :element-type '(unsigned-byte 8))
                 (let ((v (make-array (file-length stream)
                                      :element-type '(unsigned-byte 8))))
                   (read-sequence v stream) v))))
    (is (plusp (length bytes)))
    (let ((game (make-instance 'byte-decoding-game :payload bytes :exit-after 1)))
      (unwind-protect
           (progn (xna:run game)
                  (is (typep (decoded game) 'gfx:texture-2d))
                  (is (= 64 (gfx:width (decoded game)))))
        (progn (when (decoded game) (ignore-errors (xna:dispose (decoded game))))
               (ignore-errors (xna:dispose game)))))))

(define-native-test the-graphics-device-is-refused-outside-a-callback
  ;; The device is lent for a callback's duration and no longer, so an operation
  ;; outside one is refused before anything reaches the ABI.
  (with-counting-game (game)
    (let ((device (xna:graphics-device game)))
      (is (typep device 'gfx:graphics-device))
      (handler-case (progn (gfx:clear device (xna:white))
                           (fail "the device was usable outside a callback"))
        (xna:cna-scope-error (condition)
          (is (search "lifecycle" (princ-to-string condition)))))
      (signals xna:cna-scope-error (gfx:viewport device))
      (signals xna:cna-scope-error (gfx:renderer-name device)))))

(define-native-test the-graphics-device-is-the-same-object-every-time
  ;; Game.GraphicsDevice answers the same device; reference identity is preserved
  ;; where XNA preserves it.
  (with-counting-game (game)
    (is (eq (xna:graphics-device game) (xna:graphics-device game)))))

(define-native-test the-manager-answers-the-games-own-device
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (is (eq (xna:graphics-device game) (xna:graphics-device (manager game))))))

(define-native-test manager-preferences-round-trip
  (with-graphics-game (game :exit-after 1)
    (let ((manager (manager game)))
      (setf (xna:preferred-back-buffer-width manager) 1024)
      (is (= 1024 (xna:preferred-back-buffer-width manager)))
      (setf (xna:preferred-back-buffer-height manager) 768)
      (is (= 768 (xna:preferred-back-buffer-height manager)))
      (setf (xna:synchronize-with-vertical-retrace manager) nil)
      (is (not (xna:synchronize-with-vertical-retrace manager)))
      (is (member (xna:is-full-screen manager) '(t nil))))))

(define-native-test a-second-manager-on-one-game-is-refused
  (with-graphics-game (game :exit-after 1)
    (signals xna:cna-invalid-state-error
      (make-instance 'xna:graphics-device-manager :game game))))

(define-native-test sprite-batch-refuses-an-unmatched-begin-or-end
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (let ((batch (batch game)))
      ;; END without BEGIN, outside a frame: the state check is CNA-Lisp's own
      ;; and does not need the device.
      (signals xna:cna-invalid-state-error (gfx:end batch)))))

(define-native-test drawing-refuses-both-position-and-destination
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (signals xna:cna-usage-error
      (gfx:draw-texture (batch game) (texture game)
                        :position (xna:make-vector2 0.0 0.0)
                        :destination (xna:make-rectangle 0 0 1 1)))))

(define-native-test an-empty-payload-is-refused-before-cna-sees-it
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (signals xna:cna-usage-error
      (gfx:texture-2d-from-png-bytes (xna:graphics-device game)
                                     (make-array 0 :element-type '(unsigned-byte 8))))))

;;; --- the seven Draw overloads, and only those -------------------------------

(define-native-test the-draw-overload-shapes-xna-has-are-accepted
  ;; One call per XNA texture overload, all seven, inside one frame.
  (let ((game (make-instance 'draw-shapes-game :exit-after 2)))
    (unwind-protect
         (progn (xna:run game)
                (is (null (draw-error game)) "a legal Draw shape was refused: ~a"
                    (draw-error game))
                (is (= 7 (accepted game)) "~d of the seven overloads went through"
                    (accepted game)))
      (progn
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))

(define-native-test the-draw-shapes-xna-does-not-have-are-refused
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (let ((batch (batch game)) (texture (texture game)))
      (macrolet ((refuses (why &rest arguments)
                   `(handler-case
                        (progn (gfx:draw-texture batch texture ,@arguments)
                               (fail ,why))
                      (xna:cna-usage-error () t))))
        ;; Neither a position nor a destination.
        (is (refuses "a Draw with no placement was accepted" :color (xna:white)))
        ;; Both.
        (is (refuses "a Draw with both placements was accepted"
                     :position (xna:make-vector2 0.0 0.0)
                     :destination (xna:make-rectangle 0 0 1 1)
                     :color (xna:white)))
        ;; No colour: XNA has no such overload.
        (is (refuses "a Draw without a colour was accepted"
                     :position (xna:make-vector2 0.0 0.0)))
        ;; Half the transform group.
        (is (refuses "a Draw with a rotation but no origin was accepted"
                     :position (xna:make-vector2 0.0 0.0) :color (xna:white)
                     :rotation 0.5))
        ;; Scale without the transform group.
        (is (refuses "a Draw with a scale and no transform group was accepted"
                     :position (xna:make-vector2 0.0 0.0) :color (xna:white)
                     :scale 2.0))
        ;; Scale with a destination rectangle: XNA's destination overload has none.
        (is (refuses "a Draw with both a destination and a scale was accepted"
                     :destination (xna:make-rectangle 0 0 8 8) :color (xna:white)
                     :rotation 0.0 :origin (xna:vector2-zero)
                     :effects :none :layer-depth 0.0 :scale 2.0))))))

(define-native-test a-positioned-sprite-takes-the-scaled-route
  ;; The two placements are different C ABI routes, not one with a computed
  ;; rectangle: a fractional position and a source-texture-pixel origin have no
  ;; rectangle that reproduces them.
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (let ((batch (batch game)) (texture (texture game)))
      (gfx:begin batch)
      (unwind-protect
           (finishes
             (gfx:draw-texture batch texture
                               :position (xna:make-vector2 10.25 20.75)
                               :color (xna:white)
                               :rotation 0.5
                               :origin (xna:make-vector2 16.0 16.0)
                               :scale (xna:make-vector2 1.5 2.5)
                               :effects :flip-horizontally
                               :layer-depth 0.25))
        (gfx:end batch)))))

;;; --- the viewport setter and the optional private shim -----------------------

(defclass viewport-game (graphics-game)
  ((set-result :initform nil :accessor set-result)
   (read-back  :initform nil :accessor read-back)))

(defmethod xna:draw ((game viewport-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (when (= 1 (draws game))
    (let* ((device (xna:graphics-device game))
           (original (gfx:viewport device))
           (wanted (gfx:make-viewport 4 8 64 32 0.25 0.75)))
      (handler-case
          (progn (setf (gfx:viewport device) wanted)
                 (setf (read-back game) (gfx:viewport device)
                       (set-result game) :set))
        (xna:cna-not-supported-error (condition)
          (setf (set-result game) (princ-to-string condition)))
        (error (condition) (setf (set-result game) (list :other condition))))
      (ignore-errors (setf (gfx:viewport device) original)))))

(define-native-test the-viewport-setter-works-or-says-exactly-what-it-needs
  ;; The one member that goes through the optional shim. With the shim it must
  ;; actually set the viewport; without it, it must refuse in a way that names
  ;; the environment variable and the reason. Both are real outcomes; silently
  ;; doing nothing is not.
  (let ((game (make-instance 'viewport-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((result (set-result game)))
             (is (not (null result)) "the setter was never reached")
             (cond
               ((eq result :set)
                (is (int:shim-loaded-p))
                (let ((back (read-back game)))
                  (is (= 4 (gfx:viewport-x back)))
                  (is (= 8 (gfx:viewport-y back)))
                  (is (= 64 (gfx:viewport-width back)))
                  (is (= 32 (gfx:viewport-height back)))
                  (is (= 0.25f0 (gfx:viewport-min-depth back)))
                  (is (= 0.75f0 (gfx:viewport-max-depth back)))))
               ((stringp result)
                (is (not (int:shim-loaded-p)))
                (is (search "CNA_LISP_SHIM" result)
                    "the refusal does not name the variable that supplies the shim")
                (is (search "verify.sh" result)
                    "the refusal does not say how to build the shim")
                (is (search "System V" result)
                    "the refusal does not say why a shim is needed at all"))
               (t (fail "the setter failed in an unexpected way: ~s" result)))))
      (progn
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))

(define-native-test the-shim-is-optional-and-absent-is-not-an-error
  ;; Loading CNA-Lisp must never require the shim. This asserts the loader's
  ;; contract directly: with no CNA_LISP_SHIM, ENSURE-SHIM-LIBRARY answers NIL
  ;; rather than signalling.
  (let ((int::*shim-library-handle* nil)
        (int::*shim-library-path* nil)
        (saved (uiop:getenv "CNA_LISP_SHIM")))
    (unwind-protect
         (progn (sb-posix:unsetenv "CNA_LISP_SHIM")
                (is (null (int:ensure-shim-library)))
                (is (null (int:shim-entry-point
                           "cna_lisp_shim_cna_graphics_device_set_viewport"))))
      (when (and saved (string/= saved "")) (sb-posix:setenv "CNA_LISP_SHIM" saved 1)))))

(define-native-test a-named-but-missing-shim-is-refused-by-name
  (let ((int::*shim-library-handle* nil)
        (int::*shim-library-path* nil)
        (saved (uiop:getenv "CNA_LISP_SHIM")))
    (unwind-protect
         (progn
           (sb-posix:setenv "CNA_LISP_SHIM" "/nonexistent/libcna-lisp-shim.so" 1)
           (handler-case (progn (int:ensure-shim-library)
                                (fail "a nonexistent shim path was accepted"))
             (xna:cna-native-library-error (condition)
               (is (search "/nonexistent/libcna-lisp-shim.so"
                           (princ-to-string condition))))))
      (if (and saved (string/= saved ""))
          (sb-posix:setenv "CNA_LISP_SHIM" saved 1)
          (sb-posix:unsetenv "CNA_LISP_SHIM")))))
