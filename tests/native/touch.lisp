;;;; touch.lisp --- the real touch panel routes.
;;;;
;;;; No touch device is attached to the machine that runs these. What they check
;;;; is that all nine routes work and answer well-formed values for a panel with
;;;; nothing on it. See docs/limitations.md.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass touch-game (counting-game)
  ((state :initform nil :accessor touch-state)
   (caps :initform nil :accessor touch-caps)
   (available :initform :unset :accessor gesture-available)
   (width :initform nil :accessor panel-width)
   (orientation :initform nil :accessor panel-orientation)
   (gestures :initform :unset :accessor enabled-gestures)))

(defmethod xna:update ((game touch-game) game-time)
  (call-next-method)
  (setf (touch-state game) (touch:touch-panel-get-state)
        (touch-caps game) (touch:touch-panel-get-capabilities)
        (gesture-available game) (touch:touch-panel-is-gesture-available))
  (setf (touch:touch-panel-enabled-gestures) '(:tap :hold))
  (setf (enabled-gestures game) (touch:touch-panel-enabled-gestures))
  (setf (touch:touch-panel-display-width) 640)
  (setf (panel-width game) (touch:touch-panel-display-width))
  (setf (touch:touch-panel-display-orientation) :portrait)
  (setf (panel-orientation game) (touch:touch-panel-display-orientation)))

(define-native-test the-touch-panel-answers-well-formed-values
  (let ((game (make-instance 'touch-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((state (touch-state game)))
             (is (typep state 'touch:touch-collection))
             (is (integerp (touch:touch-collection-count state)))
             (is (<= 0 (touch:touch-collection-count state) 8)
                 "CNA carries at most eight touches in one snapshot")
             (is (member (touch:touch-collection-is-connected state) '(t nil))))
           (let ((caps (touch-caps game)))
             (is (typep caps 'touch:touch-panel-capabilities))
             (is (member (touch:touch-panel-capabilities-is-connected caps) '(t nil)))
             (is (integerp (touch:touch-panel-capabilities-maximum-touch-count caps))))
           (is (member (gesture-available game) '(t nil)))
           ;; The settable properties round-trip through CNA.
           (is (equal '(:tap :hold) (enabled-gestures game)))
           (is (= 640 (panel-width game)))
           (is (equal '(:portrait) (panel-orientation game))
               "DisplayOrientation is a flags enum, so one member is a one-element list"))
      (xna:dispose game))))

(define-native-test reading-the-touch-panel-without-a-game-is-refused
  (is (null (int:active-game)))
  (signals xna:cna-invalid-state-error (touch:touch-panel-get-state))
  (signals xna:cna-invalid-state-error (touch:touch-panel-get-capabilities))
  (signals xna:cna-invalid-state-error (touch:touch-panel-is-gesture-available))
  (signals xna:cna-invalid-state-error (touch:touch-panel-display-width)))
