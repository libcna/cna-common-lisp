;;;; game-pad.lisp --- real CNA gamepad state through the static projection.
;;;;
;;;; No controller is attached to the machine that runs these, so what they can
;;;; check is that the routes work and that a disconnected slot answers a
;;;; well-formed disconnected snapshot rather than failing or returning rubbish.
;;;; They do not claim a controller was read; see docs/limitations.md.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass game-pad-game (counting-game)
  ((captured :initform nil :accessor captured)
   (with-dead-zone :initform nil :accessor with-dead-zone)
   (capabilities :initform nil :accessor capabilities)
   (vibrated :initform :unset :accessor vibrated)))

(defmethod xna:update ((game game-pad-game) game-time)
  (call-next-method)
  (setf (captured game) (input:game-pad-get-state :one)
        (with-dead-zone game) (input:game-pad-get-state :one :circular)
        (capabilities game) (input:game-pad-get-capabilities :one)
        (vibrated game) (input:game-pad-set-vibration :one 0.0 0.0)))

(define-native-test the-gamepad-answers-a-well-formed-snapshot
  (let ((game (make-instance 'game-pad-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((state (captured game)))
             (is (typep state 'input:game-pad-state))
             (is (member (input:game-pad-state-is-connected state) '(t nil)))
             (is (integerp (input:game-pad-state-packet-number state)))
             (is (typep (input:game-pad-state-buttons state) 'input:game-pad-buttons))
             (is (typep (input:game-pad-state-dpad state) 'input:game-pad-dpad))
             (let ((triggers (input:game-pad-state-triggers state)))
               (is (<= 0.0f0 (input:game-pad-triggers-left triggers) 1.0f0))
               (is (<= 0.0f0 (input:game-pad-triggers-right triggers) 1.0f0)))
             (let ((sticks (input:game-pad-state-thumb-sticks state)))
               (is (<= -1.0f0 (xna:vector2-x (input:game-pad-thumb-sticks-left sticks))
                       1.0f0))
               (is (<= -1.0f0 (xna:vector2-y (input:game-pad-thumb-sticks-right sticks))
                       1.0f0)))
             ;; With no controller attached the slot reads disconnected, and
             ;; every button reads up rather than the call failing.
             (unless (input:game-pad-state-is-connected state)
               (is (input:game-pad-state-is-button-up state :a))
               (is (input:game-pad-state-is-button-up state :start))))
           ;; The dead-zone overload is a different route and answers the same
           ;; shape.
           (is (typep (with-dead-zone game) 'input:game-pad-state))
           (let ((caps (capabilities game)))
             (is (typep caps 'input:game-pad-capabilities))
             (is (member (input:game-pad-capabilities-game-pad-type caps)
                         (input:all-game-pad-type)))
             (is (member (input:game-pad-capabilities-is-connected caps) '(t nil)))
             (is (member (input:game-pad-capabilities-has-a-button caps) '(t nil))))
           (is (member (vibrated game) '(t nil))
               "SetVibration answers whether it was applied, not whether it failed"))
      (xna:dispose game))))

(define-native-test reading-a-gamepad-without-a-game-is-refused
  (is (null (int:active-game)))
  (signals xna:cna-invalid-state-error (input:game-pad-get-state :one))
  (signals xna:cna-invalid-state-error (input:game-pad-get-capabilities :one))
  (signals xna:cna-invalid-state-error (input:game-pad-set-vibration :one 0.0 0.0)))

(define-native-test a-bad-player-index-is-refused-before-the-native-call
  (let ((game (make-instance 'counting-game :exit-after 1)))
    (unwind-protect
         (progn
           (xna:run game)
           (signals xna:cna-usage-error (input:game-pad-get-state :five)))
      (xna:dispose game))))
