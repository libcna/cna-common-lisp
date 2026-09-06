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

(define-native-test subscribing-on-a-disposed-game-is-legal-and-purely-managed
  "XNA's `+=' and `-=' are `Delegate.Combine' and `Delegate.Remove' against a
field, through an `Interlocked.CompareExchange' loop, with no `IsDisposed' test:
`Game.add_Activated' and its seven siblings are twenty-four IL bytes each and
call nothing else. `Game.Dispose' does not clear those fields either. So both are
legal on a disposed game, and this used to refuse them.

What disposal ends is the event being *raised*, and that is what has to stay
true: the CNA registration is gone, so a purely managed add must acquire nothing
and must leave the callback registry exactly where it found it. A registration
faked against a destroyed game handle would be the wrong way to make this pass."
  (let* ((game (make-instance 'event-game :exit-after 1))
         (before-handler (lambda (sender) (declare (ignore sender))))
         (after-handler (lambda (sender) (declare (ignore sender)))))
    (xna:add-exiting-handler game before-handler)
    (xna:run game)
    (progn
      (xna:dispose game)
      (let ((registry (int:callback-registry-count)))
        (is (eq after-handler (xna:add-exiting-handler game after-handler))
            "adding to a disposed game answers the handler, as Combine does")
        (is (= registry (int:callback-registry-count))
            "and roots nothing: there is no live event for a token to serve")
        (is (eq t (xna:remove-exiting-handler game after-handler))
            "removing it finds it")
        (is (eq t (xna:remove-exiting-handler game before-handler))
            "and so does removing the one added before the disposal: XNA's Dispose
             never emptied the field, so `-=' still has something to remove")
        (is (null (xna:remove-exiting-handler game before-handler))
            "twice answers NIL, exactly as it does on a live game")
        (is (= registry (int:callback-registry-count))
            "and none of it touched the callback registry")))))

(define-native-test a-condition-from-a-handler-does-not-cross-the-c-frame
  ;; A CNA_GameEventCallback returns void, so there is no result code to report a
  ;; failure through. The condition must not unwind through C -- it is contained,
  ;; and the loop runs to its exit condition -- and it must not be *lost* either:
  ;; the call that was running is what re-signals it, with the original condition
  ;; object rather than a description of it.
  (let ((game (make-instance 'event-game :exit-after 2)))
    (unwind-protect
         (let ((raised (make-condition 'simple-error :format-control "from a handler")))
           (xna:add-exiting-handler
            game (lambda (sender) (declare (ignore sender)) (error raised)))
           (handler-case (progn (xna:run game) (fail "RUN swallowed the handler's condition"))
             (simple-error (condition)
               (is (eq raised condition)
                   "the condition object itself arrived, not a copy or a wrapper")))
           (is (>= (updates game) 2) "the loop still ran to its exit condition")
           (is (null int:*pending-event-condition*)
               "and it was delivered once: nothing is left pending"))
      (ignore-errors (xna:dispose game)))))

(define-condition second-handler-condition (error) ()
  (:report (lambda (c stream) (declare (ignore c)) (format stream "the second handler"))))

(define-native-test the-first-of-two-failing-handlers-is-the-one-delivered
  "Two handlers on one event, both signalling, inside one native call.

XNA invokes a multicast delegate and the *first* exception stops the invocation
list. Here every handler is its own CNA registration and its own callback, so
both run -- and the rule that matters is which condition the program is told
about. It is the first, because replacing it would lose the only report of the
failure that actually happened first, and because a caller can only be told once."
  (let ((game (make-instance 'event-game :exit-after 1))
        (first-raised (make-condition 'simple-error :format-control "the first handler")))
    (unwind-protect
         (progn
           (xna:add-exiting-handler
            game (lambda (sender) (declare (ignore sender)) (error first-raised)))
           (xna:add-exiting-handler
            game (lambda (sender) (declare (ignore sender))
                   (error 'second-handler-condition)))
           (handler-case (progn (xna:run game) (fail "neither condition was delivered"))
             (second-handler-condition ()
               (fail "the second handler's condition replaced the first one's"))
             (simple-error (condition)
               (is (eq first-raised condition))))
           (is (null int:*pending-event-condition*)))
      (ignore-errors (xna:dispose game)))))

;;; --- GraphicsDeviceManager's events ------------------------------------------

(defclass manager-event-game (counting-game)
  ((manager :initform nil :accessor manager)
   (created :initform 0 :accessor created-seen)
   (disposed :initform 0 :accessor manager-disposed-seen)))

(defmethod initialize-instance :after ((game manager-event-game) &key)
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game))
  (xna:add-device-created-handler
   (manager game) (lambda (sender) (declare (ignore sender)) (incf (created-seen game))))
  (xna:add-disposed-handler
   (manager game)
   (lambda (sender) (declare (ignore sender)) (incf (manager-disposed-seen game)))))

(define-native-test the-manager-raises-its-own-events
  (let ((game (make-instance 'manager-event-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (>= (created-seen game) 1)
               "DeviceCreated is raised when the manager creates the device"))
      (progn (xna:dispose (manager game)) (xna:dispose game)))
    (is (= 1 (manager-disposed-seen game))
        "and Disposed when the manager itself is disposed")))

(define-native-test one-generic-function-serves-several-types
  ;; ADD-DISPOSED-HANDLER is one generic function with a method on each type that
  ;; raises Disposed. That is the reason the event projection uses generic
  ;; functions at all, so it is worth asserting rather than assuming -- and
  ;; asserting *which* classes rather than how many, so a type gaining the event
  ;; strengthens this test instead of breaking it.
  (let* ((generic (fdefinition 'xna:add-disposed-handler))
         (classes (mapcar (lambda (method)
                            (class-name (first (sb-mop:method-specializers method))))
                          (sb-mop:generic-function-methods generic))))
    (is (typep generic 'generic-function))
    (dolist (class '(xna:game xna:graphics-device-manager xna:game-component))
      (is (member class classes)
          "~s raises Disposed but ADD-DISPOSED-HANDLER has no method for it" class))
    (is (>= (length classes) 2)
        "one generic function has to serve more than one type for this to mean ~
         anything")))

(define-native-test manager-subscriptions-are-released-with-the-manager
  (let ((before (int:callback-registry-count))
        (game (make-instance 'counting-game :exit-after 1))
        (manager nil))
    (unwind-protect
         (progn
           (setf manager (make-instance 'xna:graphics-device-manager :game game))
           (xna:add-device-reset-handler
            manager (lambda (sender) (declare (ignore sender))))
           (xna:add-device-resetting-handler
            manager (lambda (sender) (declare (ignore sender))))
           (xna:add-device-disposing-handler
            manager (lambda (sender) (declare (ignore sender))))
           (is (= (+ before 4) (int:callback-registry-count))
               "the game plus the manager's three subscriptions"))
      (progn (when manager (xna:dispose manager)) (xna:dispose game)))
    (is (= before (int:callback-registry-count)))))

;;; --- a failing unsubscribe, and what it must not forget ----------------------

(define-native-test a-refused-unsubscribe-keeps-the-registration-it-did-not-release
  "`cna_game_unsubscribe' and `cna_audio_unsubscribe_ext' have one shape: look the
registration up in the handle registry, and only then release it. Both steps are
validation before mutation, under the registry's own mutex -- an unknown handle
answers `CNA_RESULT_INVALID_HANDLE' from the lookup, and a call from a thread
other than the one that created the registration answers `CNA_RESULT_THREAD'
before anything is released. **So a failing unsubscribe means the registration is
still live**, and forgetting the local row there would leave CNA holding one
nothing can ever release -- which `cna_game_destroy' then refuses to shut down
over.

The thread failure is the reachable one, and it is reachable precisely because
removal is the one event operation that needs no handle and therefore never
checked the thread. This runs it from a second thread, and then proves the
subscription is still there by removing it properly."
  (let ((game (make-instance 'event-game :exit-after 1))
        (handler (lambda (sender) (declare (ignore sender)))))
    (unwind-protect
         (let ((result :not-run))
           (xna:add-exiting-handler game handler)
           (let ((thread (bordeaux-threads:make-thread
                          (lambda ()
                            (handler-case (progn (xna:remove-exiting-handler game handler)
                                                 :accepted)
                              (xna:cna-error (condition) (type-of condition))))
                          :name "cna-lisp unsubscribe wrong-thread probe")))
             (setf result (bordeaux-threads:join-thread thread)))
           (is (not (eq result :accepted))
               "the wrong-thread unsubscribe was accepted; CNA refuses it")
           (is (eq t (xna:remove-exiting-handler game handler))
               "the refused removal kept the subscription, so the right thread ~
                still finds it -- got ~s from the wrong thread" result)
           (is (null (xna:remove-exiting-handler game handler))
               "and removing it again answers NIL, so it really is gone now"))
      (xna:dispose game))
    (is (xna:disposed-p game)
        "and the game shuts down, which it could not if a registration had been
         forgotten while still live")))

;;; --- the void-event condition policy, pinned as a policy ---------------------

(define-native-test a-native-failure-outranks-a-pending-event-condition
  "The precedence when both happened, stated in src/internal/callback-conditions.lisp
and asserted here: the native failure is what the program's own call answered, so
it is what is signalled, and the handler's condition is attached as its CAUSE
rather than dropped or substituted.

The pending condition is planted directly rather than raised from a handler,
because what is under test is the rule and not the plumbing that fills the slot --
and because producing a route failure and an event in the same call from public
API alone would pin whichever route happened to be convenient rather than the
rule."
  (with-counting-game (game)
    (let ((planted (make-condition 'simple-error :format-control "from a handler")))
      (int:contain-event-condition planted)
      (is (eq planted int:*pending-event-condition*))
      (handler-case
          (progn (setf (xna:target-elapsed-time game) 0)
                 (fail "the native refusal did not arrive"))
        (xna:cna-invalid-argument-error (condition)
          (is (eq planted (xna:cna-error-cause condition))
              "the handler's condition was dropped instead of being attached")
          (is (search "from a handler" (princ-to-string condition))
              "and the report names it, so a reader can see both failures")))
      (is (null int:*pending-event-condition*) "delivered once, and cleared")
      ;; The refusal left the game usable, exactly as it does with nothing pending.
      (is (plusp (xna:target-elapsed-time game))))))

(define-native-test a-pending-event-condition-is-delivered-exactly-once
  "Taking it clears it, so the call after the one that reported it is ordinary."
  (with-counting-game (game)
    (let ((planted (make-condition 'simple-error :format-control "from a handler")))
      (int:contain-event-condition planted)
      (is (null (int:contain-event-condition
                 (make-condition 'simple-error :format-control "a later one")))
          "a second condition does not displace the first")
      (handler-case (progn (xna:run-one-frame game) (fail "it was not delivered"))
        (simple-error (condition) (is (eq planted condition))))
      (finishes (xna:run-one-frame game))
      (is (= 2 (updates game)) "and the frame that reported it still ran")
      (is (null int:*pending-event-condition*)))))

(defclass probing-game (counting-game)
  ((probe :initarg :probe :initform nil :accessor game-probe)
   (probe-result :initform :not-run :accessor probe-result))
  (:documentation "A game whose UPDATE runs a thunk inside the CNA callback."))

(defmethod xna:update ((game probing-game) game-time)
  (call-next-method)
  (let ((probe (game-probe game)))
    (when probe (setf (probe-result game) (funcall probe game)))))

(define-native-test a-pending-event-condition-is-never-delivered-inside-a-callback
  "Signalling from inside a callback is the one thing containment exists to stop,
so the drain refuses there and waits for the enclosing call to return.

A game's UPDATE is a real CNA callback, and a native route called from inside it
is exactly the shape that would unwind through C if the drain did not check. The
condition is planted from inside the callback, so the very next route call in the
same callback is the one that must not deliver it."
  (let* ((planted (make-condition 'simple-error :format-control "from a handler"))
         (game (make-instance
                'probing-game
                :probe (lambda (game)
                         (int:contain-event-condition planted)
                         (handler-case (progn (xna:is-fixed-time-step game) :no-condition)
                           (simple-error () :delivered-inside-the-callback))))))
    (unwind-protect
         (progn
           (handler-case (progn (xna:run-one-frame game)
                                (fail "the enclosing frame did not deliver it"))
             (simple-error (condition) (is (eq planted condition))))
           (is (eq :no-condition (probe-result game))
               "a native route inside the callback delivered the pending condition, ~
                which would have unwound through C")
           (is (null int:*pending-event-condition*)))
      (progn (setf (game-probe game) nil) (xna:dispose game)))))
