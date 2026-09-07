;;;; game-device-events.lisp --- Game's private device-event wiring, against a
;;;; real CNA runtime.
;;;;
;;;; **This whole file is about a member that does not exist.** `Game' subscribes
;;;; to `IGraphicsDeviceService' from the private `HookDeviceEvents', and none of
;;;; the four handlers it installs is a public XNA member -- so nothing here moves
;;;; a compatibility cell, and the lane exists because a lifecycle invariant with
;;;; no scoreboard row is still a lifecycle invariant. Before this wiring existed,
;;;; a game whose graphics device was disposed kept every asset its content
;;;; manager had loaded, and no test in the repository could tell.
;;;;
;;;; The claims are kept apart for the reason the services, storage and
;;;; owned-device lanes keep theirs apart. That the private handler *runs* says
;;;; nothing about whether it read the **current** `Game.Content'; that it read
;;;; the current one says nothing about whether a real loaded asset actually
;;;; reached its disposed state; and none of those says anything about what
;;;; happens when an asset's disposal signals inside a callback that arrived
;;;; through C.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defvar *device-wiring-evidence* '()
  "What the Game device-wiring lane actually proved, level by level.")

(defun note-device-wiring (level description &rest arguments)
  "Record LEVEL once."
  (unless (assoc level *device-wiring-evidence*)
    (push (cons level (apply #'format nil description arguments))
          *device-wiring-evidence*)))

(defun device-wiring-proved-p (level)
  (assoc level *device-wiring-evidence*))

;;; --- fixtures ---------------------------------------------------------------

(defun %wiring-content-root ()
  (let ((path (truename (fixture-path "test-font.cnj"))))
    (namestring (make-pathname :name nil :type nil :defaults path))))

(defclass device-wiring-game (counting-game)
  ((manager :initform nil :accessor manager)
   (observations :initform '() :accessor observations)
   (font :initform nil :accessor loaded-font)
   (atlas :initform nil :accessor loaded-atlas)
   (load-error :initform nil :accessor load-error))
  (:documentation
   "A game that loads a real SpriteFont through `Game.Content'.

A font rather than a texture because it is **two** disposables for one asset name
-- the font and the atlas it keeps alive -- so the lane can watch an order and
not just a count."))

(defmethod initialize-instance :after ((game device-wiring-game) &key)
  (setf (manager game) (make-instance 'xna:graphics-device-manager :game game))
  (setf (xna:is-fixed-time-step game) nil))

(defmethod xna:load-content ((game device-wiring-game))
  (call-next-method)
  (handler-case
      (let ((content (xna:content game)))
        (setf (xna.content:root-directory content) (%wiring-content-root))
        (multiple-value-bind (font atlas)
            (xna.content:load-asset content 'gfx:sprite-font "test-font")
          (setf (loaded-font game) font
                (loaded-atlas game) atlas)))
    (error (condition) (setf (load-error game) condition))))

(defun %release-wiring-game (game)
  "Dispose GAME and everything it may still own, in the only order CNA accepts."
  (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
  (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
  (when (manager game) (ignore-errors (xna:dispose (manager game))))
  (ignore-errors (xna:dispose game)))

;;; --- 1. the hook is installed where XNA installs it -------------------------

(define-native-test the-private-device-hook-is-installed-by-initialize
  "`HookDeviceEvents' runs from `Initialize', not from the constructor.

The pinned `Game::Initialize' opens with `call instance void
Game::HookDeviceEvents()' before anything else it does, and `Game::RunGame' calls
`CreateDevice()' *before* `Initialize()'. So a freshly constructed game has found
no service and holds no subscriptions, and a game that has run has four.

Four is the count `HookDeviceEvents' installs -- DeviceCreated, DeviceResetting,
DeviceReset and DeviceDisposing -- and asserting the number rather than
`non-empty' is what makes this evidence that the whole method was reproduced."
  (let ((game (make-instance 'device-wiring-game :exit-after 2)))
    (unwind-protect
         (progn
           (is (null (xna::%game-graphics-device-service game))
               "a constructed game has hooked nothing: XNA hooks from Initialize")
           (is (zerop (length (xna::%game-device-event-listeners game))))
           (xna:run game)
           (is (null (load-error game)) "the fixture failed to load: ~a"
               (load-error game))
           (is (eq (manager game) (xna::%game-graphics-device-service game))
               "the service the game hooked is the GraphicsDeviceManager itself, ~
                which is the object Game.Services answers for ~
                IGraphicsDeviceService -- not a second event source")
           (is (= 4 (length (xna::%game-device-event-listeners game)))
               "HookDeviceEvents installs exactly four subscriptions")
           (note-device-wiring
            :hook-installation
            "Initialize installed four private subscriptions on the same ~
             GraphicsDeviceManager that Game.Services answers"))
      (%release-wiring-game game))))

(define-native-test a-game-with-no-graphics-device-manager-hooks-nothing
  "`if (this.graphicsDeviceService == null) return;' -- and it is not an error.

XNA's `HookDeviceEvents' stores the service lookup's result and returns when it
is null, so a game with no `GraphicsDeviceManager' subscribes to nothing and runs
and tears down normally. `isinst' answers null rather than throwing, which is why
an absent service is a quiet NIL here too."
  (let ((game (make-instance 'counting-game :exit-after 2)))
    (unwind-protect
         (progn
           (finishes (xna:run game))
           (is (null (xna::%game-graphics-device-service game))
               "no manager, so no service, so nothing hooked")
           (is (null (xna::%game-device-event-listeners game))))
      (ignore-errors (xna:dispose game)))))

;;; --- 2. a real asset reaches its disposed state -----------------------------

(define-native-test disposing-the-device-unloads-what-game-content-loaded
  "The invariant, proved on a real asset rather than on a method call.

`Game::DeviceDisposing' is `this.content.Unload(); this.UnloadContent();'. CNA's
native game already drives the second half at exactly this point -- measured:
disposing the manager produces `device-disposing', then CNA's own
`unload-content' callback, then `disposed' -- so the binding supplies the first
half and the pair lands in XNA's order.

What is asserted is the consequence and not the call: a `SpriteFont' and the
atlas it keeps alive are loaded through `Game.Content', are alive after the run,
and are **both disposed** once the graphics device manager is disposed, with the
manager's cache and disposal list emptied and the game still able to tear down."
  (let ((game (make-instance 'device-wiring-game :exit-after 2)))
    (unwind-protect
         (let (content)
           (xna:run game)
           (is (null (load-error game)) "the fixture failed to load: ~a"
               (load-error game))
           (setf content (xna:content game))
           (is-false (xna:disposed-p (loaded-font game))
                     "the font is alive before the device is disposed")
           (is-false (xna:disposed-p (loaded-atlas game))
                     "the atlas is alive before the device is disposed")
           (is (= 1 (hash-table-count (xna.content::%content-loaded-assets content)))
               "one asset name is cached")
           (is (= 2 (length (xna.content::%content-disposable-assets content)))
               "two disposables for that one name: the font and its atlas")
           ;; The real path. Nothing here calls UNLOAD, and nothing raises a
           ;; synthetic event: the manager is disposed, CNA raises
           ;; DeviceDisposing, and the private handler is what runs.
           (xna:dispose (manager game))
           (is-true (xna:disposed-p (loaded-font game))
                    "the font reached its disposed state through the device event")
           (is-true (xna:disposed-p (loaded-atlas game))
                    "and so did the atlas it kept alive -- one asset name, two ~
                     resources, both released")
           (is (zerop (hash-table-count (xna.content::%content-loaded-assets content)))
               "the managed cache is empty")
           (is (zerop (length (xna.content::%content-disposable-assets content)))
               "and so is the disposal list")
           (note-device-wiring
            :content-unload
            "a SpriteFont and its atlas, loaded through Game.Content, were both ~
             disposed and both collections emptied when the device was disposed"))
      (%release-wiring-game game))))

(define-native-test a-game-torn-down-after-a-device-unload-still-disposes
  "The teardown after the event still works, which is the other half of the claim.

An `Unload' that released the assets but left the game unable to be destroyed
would have moved the leak rather than closed it."
  (let ((game (make-instance 'device-wiring-game :exit-after 2)))
    (xna:run game)
    (xna:dispose (manager game))
    (finishes (xna:dispose game))
    (is-true (xna:disposed-p game))
    (note-device-wiring
     :teardown
     "the game was destroyed cleanly after the device-driven unload")))

;;; --- 3. the CURRENT reference is the one unloaded ---------------------------

(defclass reassigning-wiring-game (device-wiring-game)
  ((facade :initform nil :accessor original-facade)
   (replacement :initform nil :accessor replacement-manager)
   (replacement-texture :initform nil :accessor replacement-texture)
   (setter-error :initform nil :accessor setter-error))
  (:documentation
   "Loads an asset through `Game.Content', then assigns a *different* manager
that has an asset of its own.

Both must exist and both must hold something, or the test cannot tell reading the
current reference from reading the original one."))

(defmethod xna:load-content ((game reassigning-wiring-game))
  ;; The font goes into the facade first, through the inherited method.
  (call-next-method)
  (handler-case
      (let* ((device (xna:graphics-device game))
             (mine (make-instance 'xna.content:content-manager
                                  :graphics-device device)))
        (setf (original-facade game) (xna:content game))
        (setf (xna.content:root-directory mine) (%wiring-content-root)
              (replacement-manager game) mine)
        (setf (replacement-texture game)
              (xna.content:load-asset mine 'gfx:texture-2d "cna-lisp-mark"))
        ;; XNA's `stfld', and the whole of the setter.
        (setf (xna:content game) mine))
    (error (condition) (setf (setter-error game) condition))))

(define-native-test the-device-handler-unloads-the-current-game-content
  "`ldarg.0; ldfld content; callvirt Unload()' -- the field read when the event
arrives, not when the handler was installed.

This is the test the `Game.Content' setter made possible and made necessary. A
game loads a font through the facade `A', then assigns a second manager `B' that
has a texture of its own, then has its device disposed.

**Only `B' is unloaded.** `A' keeps its font and its atlas, because `A' is no
longer what the field holds -- and a handler that had closed over the manager it
was installed with would get this exactly backwards, which is why the assertion
is on both managers and not just on one."
  (let ((game (make-instance 'reassigning-wiring-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (load-error game)) "the font failed to load: ~a" (load-error game))
           (is (null (setter-error game)) "the reassignment lane failed: ~a"
               (setter-error game))
           (let ((a (original-facade game))
                 (b (replacement-manager game)))
             (is (eq b (xna:content game)) "B is what the property answers")
             (is (not (eq a b)) "A and B are two managers")
             (is-false (xna:disposed-p (loaded-font game)))
             (is-false (xna:disposed-p (replacement-texture game)))
             (xna:dispose (manager game))
             ;; The discriminating pair.
             (is-true (xna:disposed-p (replacement-texture game))
                      "B -- the CURRENT Game.Content -- received the unload")
             (is-false (xna:disposed-p (loaded-font game))
                       "A -- replaced by assignment -- did NOT: reference ~
                        assignment is not adoption, and the handler acts on ~
                        whichever reference is current when the event arrives")
             (is-false (xna:disposed-p (loaded-atlas game))
                       "and neither did the atlas A still holds")
             (note-device-wiring
              :current-reference
              "after Game.Content was reassigned from A to B, the device event ~
               unloaded B and left A's font and atlas untouched")))
      (progn
        (when (replacement-texture game)
          (ignore-errors (xna:dispose (replacement-texture game))))
        (when (replacement-manager game)
          (ignore-errors (xna:dispose (replacement-manager game))))
        (%release-wiring-game game)))))

;;; --- 4. the private subscription is not a public handler --------------------

(define-native-test a-user-removing-a-handler-does-not-remove-the-private-one
  "XNA's `-=' takes a delegate, and a program cannot name the framework's.

The private subscription is framework state. A program that adds its own
DeviceDisposing handler and removes it again must be left with the game's own
subscription intact -- and the asset it loaded must still be released."
  (let ((game (make-instance 'device-wiring-game :exit-after 2)))
    (unwind-protect
         (let ((mine (lambda (sender) (declare (ignore sender)) nil)))
           (xna:run game)
           (xna:add-device-disposing-handler (manager game) mine)
           (is-true (xna:remove-device-disposing-handler (manager game) mine)
                    "the program's own handler came off")
           (is (= 4 (length (xna::%game-device-event-listeners game)))
               "and the framework's four are untouched")
           (xna:dispose (manager game))
           (is-true (xna:disposed-p (loaded-font game))
                    "the private subscription still fired after the program's ~
                     handler was removed")
           (note-device-wiring
            :private-subscription
            "a program's add/remove pair left the game's four private ~
             subscriptions in place and the unload still happened"))
      (%release-wiring-game game))))

(define-native-test disposing-the-game-gives-back-its-private-subscriptions
  "`UnhookDeviceEvents()', from `Game.Dispose'.

XNA removes the same four in the same order and leaves the field alone. Here the
listener list is emptied, so a disposed game holds no subscription that could
still name it."
  (let ((game (make-instance 'device-wiring-game :exit-after 2)))
    (xna:run game)
    (is (= 4 (length (xna::%game-device-event-listeners game))))
    (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
    (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
    (xna:dispose (manager game))
    (xna:dispose game)
    (is (null (xna::%game-device-event-listeners game))
        "the game gave its private subscriptions back when it was disposed")
    (note-device-wiring
     :unhook "Game disposal removed the four private subscriptions")))

;;; --- 5. invocation order is subscription order ------------------------------

(defclass traced-content-manager (xna.content:content-manager)
  ((trace-sink :initarg :trace-sink :reader trace-sink))
  (:documentation
   "A `ContentManager' that records when its `UNLOAD' ran.

A subclass rather than a method on the base class: the framework's listener calls
`UNLOAD' on whatever `Game.Content' answers, so making *that object* the observer
records the framework's position without adding behaviour to every other manager
in the image."))

(defmethod xna.content:unload ((manager traced-content-manager))
  (push :framework (cdr (trace-sink manager)))
  (call-next-method))

(defclass ordering-wiring-game (device-wiring-game)
  ((sink  :initform (cons :trace '()) :reader trace-sink)
   (mine  :initform nil :accessor own-manager)
   (early :initform nil :accessor early-handler)
   (late  :initform nil :accessor late-handler)
   (order-error :initform nil :accessor order-error))
  (:documentation
   "Subscribes one handler before `Initialize' and one after it.

XNA puts the framework's private handler into the **same** multicast delegate as
the program's, and a delegate invokes its list in subscription order. So the
question `does the framework run first?' has no fixed answer: it runs where it
subscribed. `HookDeviceEvents' subscribes from `Initialize', which is after the
constructor and before `LoadContent', and this fixture brackets exactly that."))

(defmethod initialize-instance :after ((game ordering-wiring-game) &key)
  ;; Before Initialize, so before the framework's own subscription. An XNA game
  ;; constructs its `GraphicsDeviceManager' in its own constructor, so a handler
  ;; added here is the ordinary case rather than a contrived one.
  (setf (early-handler game)
        (lambda (sender) (declare (ignore sender))
          (push :early (cdr (trace-sink game)))))
  (xna:add-device-disposing-handler (manager game) (early-handler game)))

(defmethod xna:load-content ((game ordering-wiring-game))
  (call-next-method)
  (handler-case
      (let ((mine (make-instance 'traced-content-manager
                                 :graphics-device (xna:graphics-device game)
                                 :trace-sink (trace-sink game))))
        (setf (own-manager game) mine)
        ;; The observer has to be what Game.Content answers, because that is the
        ;; object the private handler calls UNLOAD on.
        (setf (xna:content game) mine)
        ;; After Initialize, so after the framework's subscription.
        (setf (late-handler game)
              (lambda (sender) (declare (ignore sender))
                (push :late (cdr (trace-sink game)))))
        (xna:add-device-disposing-handler (manager game) (late-handler game)))
    (error (condition) (setf (order-error game) condition))))

(define-native-test the-private-handler-runs-where-it-subscribed
  "One multicast list, in subscription order, with the framework's entry in it.

A handler added before `Initialize' runs **before** the game's private one; a
handler added after it runs **after**. Neither `internal first' nor `public
first' is the rule -- the rule is when each `+=' happened, and this asserts the
whole sandwich rather than a preference."
  (let ((game (make-instance 'ordering-wiring-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (order-error game)) "the ordering lane failed: ~a"
               (order-error game))
           (setf (cdr (trace-sink game)) '())
           (xna:dispose (manager game))
           (let ((observed (reverse (cdr (trace-sink game)))))
             (is (equal '(:early :framework :late) observed)
                 "subscription order, with the framework's private listener ~
                  where Initialize put it: ~s" observed)
             (note-device-wiring
              :event-order
              "DeviceDisposing ran :early, then the framework's private ~
               listener, then :late -- one multicast list in subscription ~
               order, with HookDeviceEvents' entry at Initialize's position")))
      (progn
        (when (own-manager game) (ignore-errors (xna:dispose (own-manager game))))
        (%release-wiring-game game)))))

;;; --- 6. a failing unload does not unwind through C --------------------------

(define-condition wiring-disposal-failure (error) ()
  (:report (lambda (c s) (declare (ignore c))
             (format s "the asset refused to be disposed"))))

(defclass exploding-asset () ()
  (:documentation "A disposable whose DISPOSE always signals."))

(defmethod xna:dispose ((asset exploding-asset))
  (error 'wiring-disposal-failure))

(defmethod xna:disposed-p ((asset exploding-asset)) nil)

(defclass failing-unload-game (device-wiring-game) ()
  (:documentation
   "Puts an asset that cannot be disposed into `Game.Content''s disposal list.

The failure has to be *inside* `Unload', because that is where the device event
takes it: the condition is signalled on a stack whose caller is a C frame."))

(defmethod xna:load-content ((game failing-unload-game))
  (call-next-method)
  ;; Newest first, so the exploding one goes before the font and the atlas and
  ;; the lane can prove the cleanup continued past it.
  (push (make-instance 'exploding-asset)
        (xna.content::%content-disposable-assets (xna:content game))))

(define-native-test a-failing-unload-inside-the-device-event-is-contained
  "`ContentManager.Unload' can signal, and the event arrives through C.

A Lisp condition must never unwind through a C frame, so this goes through the
callback-condition machinery the binding already has: the condition is contained
where it is signalled, the remaining cleanup runs to `ContentManager''s existing
policy, and the condition is delivered once at the next Lisp boundary.

What is asserted is `UNLOAD''s existing contract reached through the new path,
not a second cleanup algorithm: **every later asset is still disposed** even
though the first one failed, and both collections are still emptied."
  (let ((game (make-instance 'failing-unload-game :exit-after 2)))
    (unwind-protect
         (let ((content nil))
           (xna:run game)
           (is (null (load-error game)) "the fixture failed to load: ~a"
               (load-error game))
           (setf content (xna:content game))
           (is (= 3 (length (xna.content::%content-disposable-assets content)))
               "the exploding asset, the font and the atlas")
           ;; **Two claims, and they are two.** The condition must not unwind
           ;; through the C frame that raised the event -- what would fail
           ;; without that is the process, not an assertion -- *and* it must
           ;; still reach the caller. `CNA_GameEventCallback' returns void, so
           ;; there is no result code to carry it: it is contained where it was
           ;; signalled and re-signalled by the native call that returns to Lisp,
           ;; as the original object rather than a description of it.
           (let ((delivered nil))
             (handler-case (xna:dispose (manager game))
               (wiring-disposal-failure (condition) (setf delivered condition)))
             (is-true delivered
                      "the condition reached Lisp, at the first native call to ~
                       return after the callback")
             (is (typep delivered 'wiring-disposal-failure)
                 "and it is the original condition object"))
           (is-true (xna:disposed-p (loaded-font game))
                    "the font was disposed even though an earlier asset's ~
                     disposal signalled -- ContentManager's `continue cleanup' ~
                     policy, unchanged by the new caller")
           (is-true (xna:disposed-p (loaded-atlas game))
                    "and so was the atlas")
           (is (zerop (length (xna.content::%content-disposable-assets content)))
               "the disposal list is empty however the unload ended")
           (is (zerop (hash-table-count (xna.content::%content-loaded-assets content)))
               "and so is the cache")
           (note-device-wiring
            :failure-containment
            "an asset whose disposal signalled inside the device-driven unload ~
             did not unwind through C, the later assets were still released, ~
             and both collections were still emptied"))
      (%release-wiring-game game))))
