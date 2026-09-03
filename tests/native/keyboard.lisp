;;;; keyboard.lisp --- real CNA keyboard state through the static projection.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass keyboard-game (counting-game)
  ((captured :initform nil :accessor captured)
   (per-player :initform nil :accessor per-player)
   (escape-state :initform nil :accessor escape-state)))

(defmethod xna:update ((game keyboard-game) game-time)
  (call-next-method)
  (setf (captured game) (input:keyboard-get-state)
        (per-player game) (input:keyboard-get-state :one)
        (escape-state game) (input:get-key-state (captured game) :escape)))

(define-native-test the-keyboard-answers-a-real-snapshot
  (let ((game (make-instance 'keyboard-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (typep (captured game) 'input:keyboard-state))
           (is (member (escape-state game) '(:up :down)))
           (is (listp (input:get-pressed-keys (captured game))))
           ;; CNA has one keyboard, so every player slot reports the same
           ;; snapshot; that is the C ABI's documented behaviour.
           (is (input:keyboard-state-equal (captured game) (per-player game))))
      (xna:dispose game))))

(define-native-test the-snapshot-outlives-the-frame-it-came-from
  ;; KeyboardState is a value with no handle and no lifetime.
  (let ((game (make-instance 'keyboard-game :exit-after 1))
        (snapshot nil))
    (unwind-protect
         (progn (xna:run game) (setf snapshot (captured game)))
      (xna:dispose game))
    (is (typep snapshot 'input:keyboard-state))
    (is (member (input:get-key-state snapshot :a) '(:up :down)))))

(define-native-test reading-the-keyboard-without-a-game-is-refused
  ;; The static projection resolves the process's one active game; with none, it
  ;; says so rather than reaching through a stale handle.
  (is (null (int:active-game)))
  (signals xna:cna-invalid-state-error (input:keyboard-get-state)))
