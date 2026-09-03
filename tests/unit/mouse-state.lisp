;;;; mouse-state.lisp --- MouseState as a value, without a native library.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test a-mouse-state-is-a-value-built-from-keywords
  ;; The original's constructor takes five ButtonStates in a row, telling each
  ;; other apart only by position. Keywords here, so a mistake is a name and not
  ;; an argument in the wrong slot.
  (let ((state (input:make-mouse-state :x 10 :y -20 :scroll-wheel 240
                                       :left-button :pressed
                                       :x-button-2 :pressed)))
    (is (= 10 (input:mouse-state-x state)))
    (is (= -20 (input:mouse-state-y state)))
    (is (= 240 (input:mouse-state-scroll-wheel-value state)))
    (is (eq :pressed (input:mouse-state-left-button state)))
    (is (eq :released (input:mouse-state-middle-button state)))
    (is (eq :released (input:mouse-state-right-button state)))
    (is (eq :released (input:mouse-state-x-button-1 state)))
    (is (eq :pressed (input:mouse-state-x-button-2 state))))
  (is (eq :released (input:mouse-state-left-button (input:make-mouse-state)))
      "every button defaults to released"))

(test mouse-state-equality-and-copying
  (let* ((state (input:make-mouse-state :x 1 :y 2 :right-button :pressed))
         (same (input:make-mouse-state :x 1 :y 2 :right-button :pressed))
         (copy (input:copy-mouse-state state)))
    (is (input:mouse-state-equal state same))
    (is (input:mouse-state-equal state copy))
    (is (not (input:mouse-state-equal
              state (input:make-mouse-state :x 1 :y 2 :left-button :pressed))))
    (is (not (input:mouse-state-equal state (input:make-mouse-state :x 1 :y 3))))
    (setf (input:mouse-state-x copy) 99)
    (is (= 1 (input:mouse-state-x state)) "a copy is a copy, not an alias")))

(test button-state-is-the-usual-enum
  (is (= 0 (input:button-state-value :released)))
  (is (= 1 (input:button-state-value :pressed)))
  (is (eq :pressed (input:button-state-from-value 1)))
  (is (equal '(:released :pressed) (input:all-button-state)))
  (signals xna:cna-usage-error (input:button-state-value :half-pressed))
  ;; A button state that is not one is refused by CHECK-TYPE, which is what the
  ;; rest of the projection uses for an argument of the wrong type.
  (signals type-error (input:make-mouse-state :left-button :maybe)))
