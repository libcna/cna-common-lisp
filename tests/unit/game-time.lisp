;;;; game-time.lisp --- GameTime as a class, with exact tick counts.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test game-time-is-a-class-not-a-structure
  ;; GameTime is a class in XNA, not a struct, and so it is here.
  (is (typep (find-class 'xna:game-time) 'standard-class)))

(test game-time-carries-exact-ticks
  ;; A TimeSpan is an exact count of 100-nanosecond ticks. Projecting it as a
  ;; float would lose the value the runtime actually has.
  (let ((gt (make-instance 'xna:game-time
                           :total-game-time-ticks 166667
                           :elapsed-game-time-ticks 166667)))
    (is (= 166667 (xna:total-game-time gt)))
    (is (integerp (xna:total-game-time gt)))
    (is (= 166667 (xna:elapsed-game-time gt)))
    (is (not (xna:is-running-slowly gt)))))

(test game-time-seconds-are-derived-from-the-ticks
  (let ((gt (make-instance 'xna:game-time :total-game-time-ticks 10000000)))
    (is (= 1.0d0 (xna:total-game-time-seconds gt)))))

(test ticks-per-second-is-the-timespan-constant
  (is (= 10000000 xna:+ticks-per-second+)))

(test default-target-elapsed-time-is-one-sixtieth
  ;; XNA's default fixed step, in ticks.
  (is (= 166667 xna:+default-target-elapsed-time-ticks+)))
