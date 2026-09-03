;;;; events.lisp --- the CLR event projection, against a real game.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass event-game (counting-game)
  ((disposed-seen :initform 0 :accessor disposed-seen)
   (exiting-seen :initform 0 :accessor exiting-seen)
   (senders :initform '() :accessor senders)))

(define-native-test a-handler-is-called-with-the-game-that-raised-the-event
  (let* ((game (make-instance 'event-game :exit-after 2))
         (on-exiting (lambda (sender)
                       (incf (exiting-seen game))
                       (push sender (senders game))))
         (on-disposed (lambda (sender)
                        (declare (ignore sender))
                        (incf (disposed-seen game)))))
    (unwind-protect
         (progn
           (is (eq on-exiting (xna:add-exiting-handler game on-exiting))
               "adding answers the handler, so a caller can keep it to remove later")
           (xna:add-disposed-handler game on-disposed)
           (xna:run game)
           (is (= 1 (exiting-seen game)) "Exiting is raised once, when the game exits")
           (is (every (lambda (sender) (eq sender game)) (senders game))
               "and the handler receives the game itself, not an event-args object"))
      (xna:dispose game))
    (is (= 1 (disposed-seen game)) "Disposed is raised when the game is disposed")))

(define-native-test a-removed-handler-is-not-called
  (let* ((calls 0)
         (game (make-instance 'event-game :exit-after 1))
         (handler (lambda (sender) (declare (ignore sender)) (incf calls))))
    (unwind-protect
         (progn
           (xna:add-exiting-handler game handler)
           (is (eq t (xna:remove-exiting-handler game handler)))
           (is (null (xna:remove-exiting-handler game handler))
               "removing a handler that is not there answers NIL rather than failing")
           (xna:run game)
           (is (= 0 calls)))
      (xna:dispose game))))

(define-native-test two-handlers-on-one-event-are-both-called
  (let* ((first-calls 0) (second-calls 0)
         (game (make-instance 'event-game :exit-after 1))
         (first-handler (lambda (sender) (declare (ignore sender)) (incf first-calls)))
         (second-handler (lambda (sender) (declare (ignore sender)) (incf second-calls))))
    (unwind-protect
         (progn
           (xna:add-exiting-handler game first-handler)
           (xna:add-exiting-handler game second-handler)
           (xna:run game)
           (is (= 1 first-calls))
           (is (= 1 second-calls))
           ;; Removing one leaves the other subscribed.
           (is (xna:remove-exiting-handler game first-handler))
           (is (null (xna:remove-exiting-handler game first-handler))))
      (xna:dispose game))))

(define-native-test event-subscriptions-are-released-with-the-game
  ;; Every subscription roots its handler in the callback registry. A game that
  ;; left them there would leak the handler and the game with it.
  (let ((before (int:callback-registry-count))
        (game (make-instance 'event-game :exit-after 1)))
    (unwind-protect
         (progn
           (xna:add-activated-handler game (lambda (sender) (declare (ignore sender))))
           (xna:add-deactivated-handler game (lambda (sender) (declare (ignore sender))))
           (xna:add-exiting-handler game (lambda (sender) (declare (ignore sender))))
           (is (= (+ before 4) (int:callback-registry-count))
               "the game itself plus its three subscriptions")
           (xna:run game))
      (xna:dispose game))
    (is (= before (int:callback-registry-count))
        "and disposal leaves the registry exactly as it found it")))

(define-native-test subscribing-on-a-disposed-game-is-refused
  (let ((game (make-instance 'event-game :exit-after 1)))
    (xna:run game)
    (xna:dispose game)
    (signals xna:cna-disposed-error
      (xna:add-exiting-handler game (lambda (sender) (declare (ignore sender)))))))

(define-native-test a-condition-from-a-handler-does-not-cross-the-c-frame
  ;; A CNA_GameEventCallback returns void, so there is no result code to report a
  ;; failure through. The condition must not unwind through C either: it is
  ;; contained, and the game keeps running.
  (let ((game (make-instance 'event-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:add-exiting-handler
            game (lambda (sender) (declare (ignore sender)) (error "from a handler")))
           (finishes (xna:run game))
           (is (>= (updates game) 2) "the loop ran to its exit condition"))
      (ignore-errors (xna:dispose game)))))
