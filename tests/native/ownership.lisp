;;;; ownership.lisp --- disposal order, generations, threads and the registry.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(define-native-test disposing-a-game-with-live-children-is-refused
  ;; CNA destroys children before their parent and refuses the other order.
  ;; CNA-Lisp refuses one step earlier, naming what is still alive.
  (let ((game (make-instance 'graphics-game :exit-after 1)))
    (unwind-protect
         (progn
           (xna:run game)
           (handler-case (progn (xna:dispose game)
                                (fail "a game with live children was disposed"))
             (xna:cna-ownership-error (condition)
               (let ((text (princ-to-string condition)))
                 (is (search "sprite-batch" text) "the refusal does not name the children"))))
           (is (not (xna:disposed-p game)) "the refused disposal disposed it anyway"))
      (progn
        (ignore-errors (xna:dispose (batch game)))
        (ignore-errors (xna:dispose (texture game)))
        (ignore-errors (xna:dispose (manager game)))
        (ignore-errors (xna:dispose game))))))

(define-native-test children-then-parent-disposes-cleanly
  (let ((game (make-instance 'graphics-game :exit-after 1)))
    (xna:run game)
    (xna:dispose (batch game))
    (xna:dispose (texture game))
    (xna:dispose (manager game))
    (xna:dispose game)
    (is (xna:disposed-p (batch game)))
    (is (xna:disposed-p (texture game)))
    (is (xna:disposed-p (manager game)))
    (is (xna:disposed-p game))
    (is (zerop (int:callback-registry-count))
        "the callback registry still holds ~d entry/entries"
        (int:callback-registry-count))))

(define-native-test disposal-is-idempotent
  (with-counting-game (game)
    (xna:run-one-frame game)
    (xna:dispose game)
    (is (xna:disposed-p game))
    (finishes (xna:dispose game))
    (finishes (xna:dispose game))))

(define-native-test a-disposed-object-refuses-every-operation
  (let ((game (make-instance 'counting-game)))
    (xna:run-one-frame game)
    (xna:dispose game)
    (signals xna:cna-disposed-error (xna:run-one-frame game))
    (signals xna:cna-disposed-error (xna:exit game))
    (signals xna:cna-disposed-error (xna:is-active game))
    (signals xna:cna-disposed-error (setf (xna:window-title game) "x"))))

(define-native-test a-child-that-outlives-its-owner-is-stale-not-dangerous
  ;; The handle of a destroyed owner may since have been reissued, so a stale
  ;; child must never be passed through to CNA.
  (let* ((game (make-instance 'graphics-game :exit-after 1)))
    (xna:run game)
    (let ((batch (batch game))
          (texture (texture game)))
      (xna:dispose batch)
      (xna:dispose texture)
      (xna:dispose (manager game))
      (xna:dispose game)
      ;; A fresh game reuses the native handle space; the old device facade must
      ;; not be usable against it.
      (let ((second (make-instance 'counting-game)))
        (unwind-protect
             (let ((stale-device (xna:graphics-device game)))
               (signals xna:cna-ownership-error (gfx:viewport-of stale-device)))
          (xna:dispose second))))))

(define-native-test a-shutdown-callback-failure-is-reported-with-its-condition
  (let ((game (make-instance 'counting-game :fail-on-unload t)))
    (xna:run-one-frame game)
    (handler-case (progn (xna:dispose game)
                         (fail "a failing unload-content was not reported"))
      (xna:cna-callback-error (condition)
        (is (search "deliberate failure in unload-content"
                    (princ-to-string
                     (xna:cna-callback-underlying-condition condition))))))
    ;; The handle is released either way, so a failed disposal cannot leave a
    ;; stale handle reachable.
    (is (xna:disposed-p game))
    (is (zerop (int:callback-registry-count)))))

(define-native-test an-earlier-frame-failure-does-not-fail-the-disposal
  ;; cna_game_destroy answers CNA_RESULT_CALLBACK for a latched earlier failure
  ;; too. That was already signalled where it happened; re-signalling it here
  ;; would mask the original condition behind an unwind.
  (let ((game (make-instance 'counting-game :fail-on-update 1)))
    (signals xna:cna-callback-error (xna:run-one-frame game))
    (finishes (xna:dispose game))
    (is (xna:disposed-p game))))

(define-native-test a-wrong-thread-operation-is-refused-without-touching-cna
  (let ((game (make-instance 'counting-game)))
    (unwind-protect
         (let ((result :not-run))
           (xna:run-one-frame game)
           (let ((thread (bordeaux-threads:make-thread
                          (lambda ()
                            (handler-case (progn (xna:run-one-frame game) :accepted)
                              (xna:cna-thread-error (condition) (princ-to-string condition))
                              (error (condition) (list :other (type-of condition)))))
                          :name "cna-lisp wrong-thread probe")))
             (setf result (bordeaux-threads:join-thread thread)))
           (is (stringp result) "the wrong-thread call was not refused: ~s" result)
           (when (stringp result)
             (is (search "created the native object" result)))
           ;; And the game is untouched: it still runs from its own thread.
           (finishes (xna:run-one-frame game))
           (is (= 2 (updates game))))
      (xna:dispose game))))

(define-native-test the-registry-is-empty-after-shutdown
  (is (zerop (int:callback-registry-count)))
  (with-counting-game (game :exit-after 1)
    (xna:run game)
    (is (= 1 (int:callback-registry-count))))
  (is (zerop (int:callback-registry-count))))

(define-native-test a-collection-while-a-game-is-live-keeps-it-reachable
  ;; The registry holds a strong reference on purpose: it is what keeps a game
  ;; alive while CNA holds its context pointer.
  (with-counting-game (game)
    ;; Variable timing, because a full collection takes long enough that a fixed
    ;; step would deliver catch-up updates and the count would stop being a fact
    ;; about reachability. Drawing stays one per frame either way.
    (setf (xna:is-fixed-time-step game) nil)
    (dotimes (i 4)
      (xna:run-one-frame game)
      (sb-ext:gc :full t))
    (is (= 4 (updates game))
        "a full collection between frames must not lose the game the registry roots")
    (is (= 4 (draws game)))))
