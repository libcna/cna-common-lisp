;;;; mouse.lisp --- real CNA mouse state through the static projection.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass mouse-game (counting-game)
  ((captured :initform nil :accessor captured)
   (second-capture :initform nil :accessor second-capture)
   (moved :initform nil :accessor moved)))

(defmethod xna:update ((game mouse-game) game-time)
  (call-next-method)
  (setf (captured game) (input:mouse-get-state))
  (unless (moved game)
    (input:mouse-set-position 40 30)
    (setf (moved game) t))
  (setf (second-capture game) (input:mouse-get-state)))

(define-native-test the-mouse-answers-a-real-snapshot
  (let ((game (make-instance 'mouse-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((state (captured game)))
             (is (typep state 'input:mouse-state))
             (is (integerp (input:mouse-state-x state)))
             (is (integerp (input:mouse-state-y state)))
             (is (integerp (input:mouse-state-scroll-wheel-value state)))
             (dolist (reader (list #'input:mouse-state-left-button
                                   #'input:mouse-state-middle-button
                                   #'input:mouse-state-right-button
                                   #'input:mouse-state-x-button-1
                                   #'input:mouse-state-x-button-2))
               (is (member (funcall reader state) '(:pressed :released))))))
      (xna:dispose game))))

(define-native-test a-mouse-snapshot-outlives-the-frame-it-came-from
  (let ((game (make-instance 'mouse-game :exit-after 1))
        (snapshot nil))
    (unwind-protect
         (progn (xna:run game) (setf snapshot (captured game)))
      (xna:dispose game))
    (is (typep snapshot 'input:mouse-state))
    (is (eq :released (input:mouse-state-left-button snapshot)))
    (is (input:mouse-state-equal snapshot (input:copy-mouse-state snapshot)))))

(define-native-test reading-the-mouse-without-a-game-is-refused
  (is (null (int:active-game)))
  (signals xna:cna-invalid-state-error (input:mouse-get-state))
  (signals xna:cna-invalid-state-error (input:mouse-set-position 0 0)))
