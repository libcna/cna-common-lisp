;;;; stress.lisp --- repeated create / run / destroy, with collections.
;;;;
;;;; One clean run is not ownership qualification. This is twenty full cycles,
;;;; with a full collection inside each, asserting that nothing accumulates.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defparameter +stress-cycles+ 20)

(define-native-test twenty-create-run-destroy-cycles-leave-nothing-behind
  (is (zerop (int:callback-registry-count)))
  (dotimes (cycle +stress-cycles+)
    (let ((game (make-instance 'counting-game
                               :exit-after 3
                               :window-title (format nil "cycle ~d" cycle))))
      (unwind-protect
           (progn
             (xna:run game)
             ;; At least three, not exactly three. The default time step is
             ;; fixed, so a frame that overran its target is followed by
             ;; catch-up updates, and one of those can land after the third
             ;; update has asked the game to exit. This assertion held for a
             ;; long time and then failed once on a busier machine, which is
             ;; exactly how a timing assumption fails.
             (is (>= (updates game) 3) "cycle ~d ran ~d updates" cycle (updates game))
             (is (= 1 (begin-runs game)))
             (is (= 1 (end-runs game)))
             (sb-ext:gc :full t))
        (xna:dispose game))
      (is (xna:disposed-p game))
      (is (zerop (int:callback-registry-count))
          "cycle ~d left ~d registry entry/entries" cycle (int:callback-registry-count))))
  (sb-ext:gc :full t)
  (is (zerop (int:callback-registry-count))))

(define-native-test twenty-graphics-cycles-leave-nothing-behind
  ;; The same, with real native children each time: a texture, a sprite batch and
  ;; a graphics device manager per cycle.
  (dotimes (cycle +stress-cycles+)
    (let ((game (make-instance 'graphics-game :exit-after 2)))
      (unwind-protect
           (progn
             (xna:run game)
             (is (null (draw-error game)) "cycle ~d: ~a" cycle (draw-error game))
             (is (typep (texture game) 'gfx:texture-2d))
             (sb-ext:gc :full t))
        (progn
          (when (batch game) (xna:dispose (batch game)))
          (when (texture game) (xna:dispose (texture game)))
          (when (manager game) (xna:dispose (manager game)))
          (xna:dispose game)))
      (is (zerop (int:callback-registry-count))
          "graphics cycle ~d left ~d registry entry/entries"
          cycle (int:callback-registry-count))))
  (sb-ext:gc :full t)
  (is (zerop (int:callback-registry-count))))

(define-native-test a-failed-cycle-does-not-poison-the-next-one
  (dotimes (cycle 5)
    (let ((game (make-instance 'counting-game :fail-on-update 1)))
      (signals xna:cna-callback-error (xna:run-one-frame game))
      (xna:dispose game))
    (let ((game (make-instance 'counting-game :exit-after 2)))
      ;; Variable timing, for the reason `graphics-game' gives and
      ;; `game-lifecycle.lisp' and `ownership.lisp' already apply: **a fixed time
      ;; step does not make a frame count an update count.** A frame that
      ;; overruns its 60 Hz budget is followed by catch-up updates with no draws
      ;; of their own, and the *first* frame is where CNA does one-time native
      ;; work -- so on a loaded machine this game reached three updates before
      ;; the exit took effect and the assertion below failed. It was a latent
      ;; flake rather than a regression: the claim here is that the cycle after a
      ;; failed one runs normally, which "exactly two updates" only expresses
      ;; when one frame is one update.
      (setf (xna:is-fixed-time-step game) nil)
      (unwind-protect (progn (xna:run game) (is (= 2 (updates game))))
        (xna:dispose game))))
  (is (zerop (int:callback-registry-count))))
