;;;; game-lifecycle.lisp --- a real CNA game driving real CLOS methods.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(define-native-test a-first-frame-delivers-the-canonical-order
  ;; initialize, load-content, begin-run, update, begin-draw, draw, end-draw --
  ;; and RUN-ONE-FRAME delivers no begin-run, because that hook belongs to RUN.
  (with-counting-game (game)
    (xna:run-one-frame game)
    (is (= 1 (initializes game)))
    (is (= 1 (loads game)))
    (is (= 0 (begin-runs game)))
    (is (= 1 (updates game)))
    (is (= 1 (begin-draws game)))
    (is (= 1 (draws game)))
    (is (= 1 (end-draws game)))))

(define-native-test run-delivers-begin-run-and-end-run-exactly-once
  ;; Variable timing, because two of these four are exact counts and a fixed step
  ;; does not deliver one update per frame: CNA's `Game::Tick' runs its catch-up
  ;; `while' loop to the end without re-reading the exit request, so a frame that
  ;; overran its target can update again after EXIT was called. See
  ;; A-FIXED-STEP-MAY-DELIVER-CATCH-UP-UPDATES, which pins that on purpose.
  (with-counting-game (game :exit-after 5)
    (setf (xna:is-fixed-time-step game) nil)
    (xna:run game)
    (is (= 1 (begin-runs game)))
    (is (= 1 (end-runs game)))
    (is (= 5 (updates game)))
    (is (= 4 (draws game)) "exit is requested during the fifth update, so the
                            fifth frame does not draw")))

(define-native-test the-callbacks-resolve-to-the-right-clos-object
  "A native callback token resolves to the CLOS object that registered it, and a
new object's callbacks do not resolve to a destroyed one's.

Two games cannot be live at once, so identity is checked by running two in
sequence. **Frames are stepped explicitly, one at a time.** This used to call RUN
with an exit-after count and assert that count as the update count, and it failed
once under load and passed on the re-run -- which is the failure this repository
already has a rule about: a fixed time step runs catch-up updates after a frame
that overran its target, so a frame count is not an update count and the exit
request only ends the frame it is made in. Nothing about token identity needed
the loop. RUN-ONE-FRAME delivers exactly one update per call, which makes the
count a fact about dispatch rather than about how busy the machine was.

The discriminating assertion is the last one: the first game's counter must not
move while the second game is the one running frames. A binding that resolved
every token to the most recently registered object, or to the first, would pass
the other three and fail that."
  (let (first-updates)
    (with-counting-game (first)
      ;; Variable timing: under a fixed step one frame is not one update, which
      ;; A-FIXED-STEP-MAY-DELIVER-CATCH-UP-UPDATES measures. Identity has nothing
      ;; to do with the clock, so the clock is taken out of it.
      (setf (xna:is-fixed-time-step first) nil)
      (xna:run-one-frame first)
      (is (= 1 (updates first)) "one explicit frame is one update")
      (setf first-updates (updates first))
      (xna:dispose first)
      (with-counting-game (second)
        (setf (xna:is-fixed-time-step second) nil)
        (xna:run-one-frame second)
        (xna:run-one-frame second)
        (is (= 2 (updates second))
            "the second game counted its own two frames and nothing else")
        (is (= first-updates (updates first))
            "and the first game's counter did not move: its callbacks were not ~
             delivered to it, and the second's were not delivered to it either")))))

(define-native-test update-receives-a-real-game-time
  (with-counting-game (game :exit-after 3)
    (xna:run game)
    (let ((gt (last-game-time game)))
      (is (typep gt 'xna:game-time))
      (is (integerp (xna:total-game-time gt)))
      (is (integerp (xna:elapsed-game-time gt)))
      (is (>= (xna:total-game-time gt) 0))
      (is (member (xna:is-running-slowly gt) '(t nil))))))

(define-native-test the-elapsed-time-matches-the-fixed-step
  (with-counting-game (game :exit-after 2)
    (is (xna:is-fixed-time-step game))
    (is (= xna:+default-target-elapsed-time-ticks+ (xna:target-elapsed-time game)))
    (xna:run game)
    (is (= xna:+default-target-elapsed-time-ticks+
           (xna:elapsed-game-time (last-game-time game))))))

(define-native-test begin-draw-answering-nil-skips-the-frames-drawing
  (let ((game (make-instance 'skipping-game :exit-after 4)))
    (unwind-protect
         (progn
           (xna:run game)
           ;; The exact update count is not pinned: with no drawing to do the
           ;; loop reaches its next update sooner, and how many it fits before
           ;; the exit request takes effect is a timing question. What is pinned
           ;; is that BEGIN-DRAW ran and DRAW did not.
           (is (>= (updates game) 4))
           (is (plusp (begin-draws game)))
           (is (= 0 (draws game)) "drawing was skipped, so DRAW never ran")
           (is (= 0 (end-draws game))))
      (xna:dispose game))))

(define-native-test game-properties-round-trip-through-cna
  (with-counting-game (game)
    (setf (xna:is-fixed-time-step game) nil)
    (is (not (xna:is-fixed-time-step game)))
    (setf (xna:is-fixed-time-step game) t)
    (is (xna:is-fixed-time-step game))
    (setf (xna:target-elapsed-time game) 333333)
    (is (= 333333 (xna:target-elapsed-time game)))
    (setf (xna:inactive-sleep-time game) 200000)
    (is (= 200000 (xna:inactive-sleep-time game)))
    (setf (xna:is-mouse-visible game) t)
    (is (xna:is-mouse-visible game))
    (is (member (xna:is-active game) '(t nil)))))

(define-native-test a-non-positive-target-step-is-refused-by-cna
  (with-counting-game (game)
    (signals xna:cna-invalid-argument-error
      (setf (xna:target-elapsed-time game) 0))
    ;; And the refusal left the game usable.
    (is (plusp (xna:target-elapsed-time game)))))

(define-native-test tick-is-a-frame-step-distinct-from-run-one-frame
  (with-counting-game (game)
    (xna:run-one-frame game)
    (xna:tick game)
    (is (= 2 (updates game)))
    (is (= 2 (draws game)))))

(define-native-test suppress-draw-skips-the-next-frames-drawing
  (with-counting-game (game)
    (xna:run-one-frame game)
    (is (= 1 (draws game)))
    (xna:suppress-draw game)
    (xna:tick game)
    (is (= 2 (updates game)))
    (is (= 1 (draws game)) "the suppressed frame updated but did not draw")))

(define-native-test a-condition-in-update-is-contained-and-re-signalled
  ;; The whole containment contract in one test: nothing unwinds through C, CNA
  ;; sees a callback failure, and the original condition arrives on the Lisp side
  ;; attached to a CNA-CALLBACK-ERROR.
  (with-counting-game (game :fail-on-update 2)
    (handler-case (progn (xna:run game) (fail "the failing callback did not stop the run"))
      (xna:cna-callback-error (condition)
        (let ((original (xna:cna-callback-underlying-condition condition)))
          (is (typep original 'simple-error)
              "the original condition was not preserved; got ~s" original)
          (is (search "deliberate failure in update on frame 2"
                      (princ-to-string original)))
          ;; CNA's own diagnostic carries the text the callback supplied.
          (is (search "deliberate failure in update on frame 2"
                      (or (xna:cna-error-native-message condition) ""))
              "CNA did not receive the callback diagnostic"))))
    (is (= 2 (updates game)) "the game stopped on the failing frame")))

(define-native-test a-contained-condition-does-not-poison-the-next-call
  (with-counting-game (game :fail-on-update 1)
    (signals xna:cna-callback-error (xna:run-one-frame game))
    (is (null int:*pending-callback-condition*)
        "the contained condition was left pending after it was reported")))

(define-native-test re-entering-the-loop-from-a-callback-is-refused
  (let ((game (make-instance 'reentrant-game)))
    (unwind-protect
         (handler-case (progn (xna:run-one-frame game) (fail "re-entry was allowed"))
           (xna:cna-callback-error (condition)
             (is (typep (xna:cna-callback-underlying-condition condition)
                        'xna:cna-scope-error))))
      (xna:dispose game))))

(define-native-test the-window-title-is-what-it-was-created-with
  (let ((game (make-instance 'counting-game :window-title "a title")))
    (unwind-protect (is (string= "a title" (xna:window-title game)))
      (xna:dispose game))))

(define-native-test a-second-live-game-is-refused
  (with-counting-game (game)
    (is (typep game 'counting-game))
    (signals xna:cna-invalid-state-error (make-instance 'counting-game))))

(define-native-test a-fixed-step-may-deliver-catch-up-updates
  ;; Measured, and it is why the template's deterministic modes use variable
  ;; timing: under a fixed step a frame that took longer than the target step is
  ;; followed by extra updates, so a frame count is not an update count. Drawing
  ;; stays one per frame in both modes.
  (with-counting-game (game)
    (is (xna:is-fixed-time-step game))
    (dotimes (i 6)
      (xna:run-one-frame game)
      (sb-ext:gc :full t))
    (is (= 6 (draws game)) "a frame draws exactly once, whatever the timing mode")
    (is (>= (updates game) 6))))

(define-native-test variable-timing-makes-a-frame-exactly-one-update
  (with-counting-game (game)
    (setf (xna:is-fixed-time-step game) nil)
    (is (not (xna:is-fixed-time-step game)))
    (dotimes (i 60)
      (xna:run-one-frame game)
      (when (zerop (mod i 20)) (sb-ext:gc :full t)))
    (is (= 60 (updates game)) "variable timing delivers exactly one update per frame")
    (is (= 60 (draws game)))))
