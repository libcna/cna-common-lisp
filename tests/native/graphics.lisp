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
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game)))

(defmethod xna:load-content ((game graphics-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    (setf (renderer game) (gfx:renderer-name device)
          (viewport game) (gfx:viewport-of device)
          (texture game) (gfx:texture-2d-from-png-file device (fixture-path "cna-lisp-mark.png"))
          (batch game) (make-instance 'gfx:sprite-batch :graphics-device device))))

(defmethod xna:draw ((game graphics-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (handler-case
      (progn
        (gfx:clear (xna:graphics-device game) (xna:cornflower-blue))
        (gfx:begin (batch game) :sort-mode :deferred)
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
      (signals xna:cna-scope-error (gfx:viewport-of device))
      (signals xna:cna-scope-error (gfx:renderer-name device)))))

(define-native-test the-graphics-device-is-the-same-object-every-time
  ;; Game.GraphicsDevice answers the same device; reference identity is preserved
  ;; where XNA preserves it.
  (with-counting-game (game)
    (is (eq (xna:graphics-device game) (xna:graphics-device game)))))

(define-native-test the-manager-answers-the-games-own-device
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (is (eq (xna:graphics-device game) (xna:graphics-device-of (manager game))))))

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
