;;;; game-components.lisp --- the component engine, driven by CNA.
;;;;
;;;; The claim these tests exist to check is that the engine is **wired up**, not
;;;; that the members exist. A component whose UPDATE is exported and never called
;;;; would pass a surface audit and fail every test here: the counts a component
;;;; records are the evidence, and they are counted inside CNA's own game loop.
;;;;
;;;; Every count is read after RUN has returned. A FiveAM assertion inside a
;;;; component's UPDATE would be a test-framework restart crossing the callback
;;;; containment layer, which exists for application conditions.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass counting-component (xna:game-component)
  ((initializes :initform 0 :accessor component-initializes)
   (updates :initform 0 :accessor component-updates)
   (disposes :initform 0 :accessor component-disposes)
   (seen-time :initform nil :accessor component-seen-time)
   (label :initarg :label :initform :a :reader component-label)
   (order-log :initarg :order-log :initform nil :accessor order-log))
  (:documentation "A component that counts every call CNA makes to it."))

(defmethod xna:initialize ((component counting-component))
  (incf (component-initializes component)))

(defmethod xna:update ((component counting-component) game-time)
  (incf (component-updates component))
  (setf (component-seen-time component) game-time)
  (let ((log (order-log component)))
    (when log (push (component-label component) (cdr log)))))

(defmethod xna:component-dispose ((component counting-component))
  (incf (component-disposes component)))

(defclass counting-drawable (xna:drawable-game-component)
  ((initializes :initform 0 :accessor component-initializes)
   (updates :initform 0 :accessor component-updates)
   (draws :initform 0 :accessor component-draws)
   (loads :initform 0 :accessor component-loads)
   (unloads :initform 0 :accessor component-unloads)
   (device-inside-draw :initform nil :accessor device-inside-draw))
  (:documentation "A drawable component that counts every call CNA makes to it."))

(defmethod xna:initialize ((component counting-drawable))
  (incf (component-initializes component)))
(defmethod xna:update ((component counting-drawable) game-time)
  (declare (ignore game-time))
  (incf (component-updates component)))
(defmethod xna:load-content ((component counting-drawable))
  (incf (component-loads component)))
(defmethod xna:unload-content ((component counting-drawable))
  (incf (component-unloads component)))

(defmethod xna:draw ((component counting-drawable) game-time)
  (declare (ignore game-time))
  (incf (component-draws component))
  ;; The device is lent for a callback's duration, and a component's DRAW is
  ;; inside one. Recorded rather than asserted here.
  (unless (device-inside-draw component)
    (setf (device-inside-draw component)
          (handler-case (progn (xna:graphics-device component) :borrowed)
            (error (c) (type-of c))))))

(defclass component-game (graphics-game)
  ((made :initform '() :accessor made-components)
   (make-components :initarg :make-components :initform nil :accessor make-components)
   (build-where :initarg :build-where :initform :initialize :accessor build-where)
   (build-error :initform nil :accessor build-error))
  (:documentation
   "A game that builds and adds components at a chosen point in its lifecycle.

**Which point matters**, and not for a reason anybody would guess. XNA's
`Game.Run' sets `inRun` *after* `Initialize()` returns, `Initialize()` calls
`LoadContent()` at its end, and `GameComponentAdded` only initializes a component
when `inRun` is already true. So a component added inside `LoadContent' lands on
`notYetInitialized' after the drain loop that empties it has finished, and is
never initialized -- while still being updated and drawn. Read from
`Game::Initialize' and `Game::GameComponentAdded' in the pinned assembly, and CNA
does the same thing. `:INITIALIZE' is therefore the default here, and the
LoadContent case has a test of its own."))

(defun %build-components (game)
  (handler-case
      (when (make-components game)
        (setf (made-components game) (funcall (make-components game) game)))
    (error (condition) (setf (build-error game) condition))))

(defmethod xna:initialize ((game component-game))
  (call-next-method)
  (when (eq (build-where game) :initialize) (%build-components game)))

(defmethod xna:load-content ((game component-game))
  (call-next-method)
  (when (eq (build-where game) :load-content) (%build-components game)))

(defmacro with-component-game ((game maker &rest initargs) &body body)
  `(let ((,game (make-instance 'component-game :exit-after 3
                               :make-components ,maker ,@initargs)))
     (unwind-protect
          (progn (xna:run ,game)
                 (when (build-error ,game) (error (build-error ,game)))
                 ,@body)
       (progn
         (dolist (component (made-components ,game))
           (ignore-errors (xna:dispose component)))
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (ignore-errors (xna:dispose ,game))))))

;;; --- the engine actually runs -------------------------------------------------

(define-native-test the-game-really-drives-a-component
  "The whole point. A component added to the collection is initialized once and
updated once per frame, by CNA's own loop -- not by anything in this binding."
  (with-component-game (game (lambda (g)
                               (let ((c (make-instance 'counting-component :game g)))
                                 (xna:add-component (xna:components g) c)
                                 (list c))))
    (let ((component (first (made-components game))))
      (is (= 1 (component-initializes component))
          "the component was initialized ~d time(s)" (component-initializes component))
      (is (plusp (component-updates component))
          "the component was never updated, so nothing here is driving it")
      ;; One update per update of the game, which under variable timing is one per
      ;; frame. Not compared against the *draw* count: the loop updates before it
      ;; draws and the exit happens in a draw, so the two legitimately differ by
      ;; one at the end of a run.
      (is (= (updates game) (component-updates component))
          "the game updated ~d time(s) and the component ~d"
          (updates game) (component-updates component))
      ;; And it received a real GameTime, not a placeholder.
      (is (typep (component-seen-time component) 'xna:game-time))
      (is (>= (xna:total-game-time (component-seen-time component)) 0)))))

(define-native-test a-component-added-during-load-content-is-never-initialized
  "Surprising, XNA's, and reproduced by CNA. `Game.Run' sets `inRun' *after*
`Initialize()' returns; `Initialize()' calls `LoadContent()' at its very end; and
`GameComponentAdded' initializes a component only when `inRun' is already true.
So a component added inside LoadContent goes onto `notYetInitialized' after the
loop that drains it has finished, and stays there -- updated every frame,
initialized never.

Read from `Game::Initialize' and `Game::GameComponentAdded' in the pinned
`Microsoft.Xna.Framework.Game' assembly, and measured to be CNA's behaviour too.
Pinned here so a CNA that changed it would fail rather than pass quietly."
  (with-component-game (game (lambda (g)
                               (let ((c (make-instance 'counting-component :game g)))
                                 (xna:add-component (xna:components g) c)
                                 (list c)))
                             :build-where :load-content)
    (let ((component (first (made-components game))))
      (is (zerop (component-initializes component))
          "a component added in LoadContent was initialized ~d time(s); XNA never ~
           initializes one" (component-initializes component))
      (is (plusp (component-updates component))
          "and it should still be updated, which is what makes the absence odd"))))

(define-native-test a-drawable-component-is-drawn-and-loaded
  "DrawableGameComponent adds Draw, LoadContent and UnloadContent, and CNA calls
all three. The device it borrows inside Draw is a real one."
  (with-component-game (game (lambda (g)
                               (let ((c (make-instance 'counting-drawable :game g)))
                                 (xna:add-component (xna:components g) c)
                                 (list c))))
    (let ((component (first (made-components game))))
      (is (= 1 (component-initializes component)))
      (is (plusp (component-updates component)))
      (is (plusp (component-draws component))
          "a drawable component was never drawn")
      (is (= 1 (component-loads component))
          "LoadContent ran ~d time(s)" (component-loads component))
      (is (eq :borrowed (device-inside-draw component))
          "the graphics device inside a component's Draw answered ~s"
          (device-inside-draw component)))))

(define-native-test a-disabled-component-is-not-updated
  "Enabled is not decoration: CNA skips a disabled component's Update, and the
count is how we know rather than the setter round-tripping."
  (with-component-game (game (lambda (g)
                               (let ((c (make-instance 'counting-component :game g)))
                                 (setf (xna:component-enabled c) nil)
                                 (xna:add-component (xna:components g) c)
                                 (list c))))
    (let ((component (first (made-components game))))
      (is (null (xna:component-enabled component)))
      (is (zerop (component-updates component))
          "a disabled component was updated ~d time(s)" (component-updates component))
      ;; It is still initialized: XNA initializes a component whether or not it
      ;; is enabled, and so does CNA.
      (is (= 1 (component-initializes component))))))

(define-native-test an-invisible-drawable-component-is-not-drawn
  (with-component-game (game (lambda (g)
                               (let ((c (make-instance 'counting-drawable :game g)))
                                 (setf (xna:component-visible c) nil)
                                 (xna:add-component (xna:components g) c)
                                 (list c))))
    (let ((component (first (made-components game))))
      (is (null (xna:component-visible component)))
      (is (zerop (component-draws component))
          "an invisible component was drawn ~d time(s)" (component-draws component))
      ;; but it is still updated, because Visible is not Enabled
      (is (plusp (component-updates component))))))

(define-native-test update-order-decides-which-component-runs-first
  "UpdateOrder is the ordering the engine really applies. Two components record
the order they were called in, and the lower UpdateOrder must come first --
whichever order they were added in."
  (let ((log (cons :log '())))
    (with-component-game (game (lambda (g)
                                 (let ((late (make-instance 'counting-component
                                                            :game g :label :late
                                                            :order-log log))
                                       (early (make-instance 'counting-component
                                                             :game g :label :early
                                                             :order-log log)))
                                   ;; Added late-first on purpose: if the engine
                                   ;; ignored UpdateOrder the log would follow
                                   ;; insertion order instead.
                                   (setf (xna:update-order late) 10
                                         (xna:update-order early) 1)
                                   (xna:add-component (xna:components g) late)
                                   (xna:add-component (xna:components g) early)
                                   (list late early))))
      (let ((calls (reverse (cdr log))))
        (is (plusp (length calls)) "neither component was updated")
        (is (evenp (length calls))
            "the two components were updated ~d times between them" (length calls))
        (loop for (first second) on calls by #'cddr
              while second
              do (is (and (eq first :early) (eq second :late))
                     "a frame updated ~s before ~s; UpdateOrder says otherwise"
                     first second))))))

;;; --- the collection ---------------------------------------------------------------

(define-native-test the-components-collection-is-one-object-and-answers-its-contents
  (with-component-game (game (lambda (g)
                               (let ((a (make-instance 'counting-component :game g))
                                     (b (make-instance 'counting-component :game g)))
                                 (xna:add-component (xna:components g) a)
                                 (xna:add-component (xna:components g) b)
                                 (list a b))))
    (let ((collection (xna:components game)))
      (is (eq collection (xna:components game))
          "Game.Components must answer the same object every time")
      (destructuring-bind (a b) (made-components game)
        (is (= 2 (xna:component-count collection)))
        (is (eq a (xna:component-at collection 0)))
        (is (eq b (xna:component-at collection 1)))
        (is (equal (list a b) (xna:components-of collection)))
        (is (eq t (xna:contains-component collection a)))
        (is (= 0 (xna:component-index collection a)))
        (is (= 1 (xna:component-index collection b)))))))

(define-native-test removing-a-component-stops-the-game-driving-it
  "The engine's answer, not the collection's: after a removal the component's
update count must stop moving while the game keeps running."
  (with-component-game (game (lambda (g)
                               (let ((c (make-instance 'counting-component :game g)))
                                 (xna:add-component (xna:components g) c)
                                 (list c))))
    (let* ((collection (xna:components game))
           (component (first (made-components game)))
           (before (component-updates component)))
      (is (plusp before))
      (is (eq t (xna:remove-component collection component)))
      (is (zerop (xna:component-count collection)))
      (is (null (xna:contains-component collection component)))
      (is (null (xna:component-index collection component))
          "IndexOf answers NIL for an absent component, which is XNA's -1")
      ;; Removing one that is not there is not an error and answers NIL.
      (is (null (xna:remove-component collection component))))))

(define-native-test a-component-can-be-inserted-and-the-collection-cleared
  (with-component-game (game (lambda (g)
                               (let ((a (make-instance 'counting-component :game g))
                                     (b (make-instance 'counting-component :game g)))
                                 (xna:add-component (xna:components g) a)
                                 (xna:insert-component (xna:components g) 0 b)
                                 (list a b))))
    (let ((collection (xna:components game)))
      (destructuring-bind (a b) (made-components game)
        (is (eq b (xna:component-at collection 0)) "the insert went to the front")
        (is (eq a (xna:component-at collection 1)))
        (xna:remove-component-at collection 0)
        (is (= 1 (xna:component-count collection)))
        (is (eq a (xna:component-at collection 0)))
        (xna:clear-components collection)
        (is (zerop (xna:component-count collection)))))))

(define-native-test a-component-belonging-to-another-game-is-refused
  (with-component-game (game (lambda (g)
                               (list (make-instance 'counting-component :game g))))
    ;; The game is still alive here, so a second one cannot be made -- CNA allows
    ;; one active game per process. What can be checked is that the collection
    ;; refuses something that is not a component of its game at all.
    (signals error (xna:add-component (xna:components game) :not-a-component))))

;;; --- the collection's events -------------------------------------------------------

(define-native-test the-collection-raises-component-added-and-removed
  "The one event pair in this binding whose argument is not empty: the handler
receives the collection and a GameComponentCollectionEventArgs carrying the
component."
  (let ((added '()) (removed '()))
    (with-component-game (game (lambda (g)
                                 (let ((collection (xna:components g))
                                       (c (make-instance 'counting-component :game g)))
                                   (xna:add-component-added-handler
                                    collection
                                    (lambda (sender args)
                                      (push (cons sender (xna:event-args-game-component args))
                                            added)))
                                   (xna:add-component-removed-handler
                                    collection
                                    (lambda (sender args)
                                      (push (cons sender (xna:event-args-game-component args))
                                            removed)))
                                   (xna:add-component collection c)
                                   (xna:remove-component collection c)
                                   (list c))))
      (let ((collection (xna:components game))
            (component (first (made-components game))))
        (is (= 1 (length added)) "ComponentAdded fired ~d time(s)" (length added))
        (is (= 1 (length removed)) "ComponentRemoved fired ~d time(s)" (length removed))
        (is (eq collection (car (first added))) "the sender is the collection")
        (is (eq component (cdr (first added))) "the args carry the component")
        (is (eq component (cdr (first removed))))))))

;;; --- a component's own events --------------------------------------------------------

(define-native-test a-component-raises-its-order-and-state-events
  (let ((fired '()))
    (with-component-game (game (lambda (g)
                                 (let ((c (make-instance 'counting-drawable :game g)))
                                   (xna:add-enabled-changed-handler
                                    c (lambda (s) (push (cons :enabled s) fired)))
                                   (xna:add-update-order-changed-handler
                                    c (lambda (s) (push (cons :update-order s) fired)))
                                   (xna:add-draw-order-changed-handler
                                    c (lambda (s) (push (cons :draw-order s) fired)))
                                   (xna:add-visible-changed-handler
                                    c (lambda (s) (push (cons :visible s) fired)))
                                   (setf (xna:component-enabled c) nil
                                         (xna:update-order c) 7
                                         (xna:draw-order c) 9
                                         (xna:component-visible c) nil)
                                   (xna:add-component (xna:components g) c)
                                   (list c))))
      (let ((component (first (made-components game))))
        (dolist (event '(:enabled :update-order :draw-order :visible))
          (is (assoc event fired) "~s never fired" event))
        (dolist (entry fired)
          (is (eq component (cdr entry))
              "~s was raised with ~s rather than the component" (car entry) (cdr entry)))
        ;; And the values really changed.
        (is (= 7 (xna:update-order component)))
        (is (= 9 (xna:draw-order component)))))))

;;; --- shapes the contract does not have ------------------------------------------------

(define-native-test a-plain-component-has-no-drawing-surface
  "GameComponent implements IUpdateable and not IDrawable, so Visible and
DrawOrder have no applicable method for one -- exactly as XNA has no such member
on it."
  (with-component-game (game (lambda (g)
                               (list (make-instance 'counting-component :game g))))
    (let ((component (first (made-components game))))
      (signals error (xna:component-visible component))
      (signals error (xna:draw-order component))
      (signals error (xna:graphics-device component)))))

(define-native-test a-component-reports-the-game-it-was-made-against
  (with-component-game (game (lambda (g)
                               (list (make-instance 'counting-component :game g))))
    (is (eq game (xna:component-game (first (made-components game)))))))

;;; --- ownership ---------------------------------------------------------------------

(define-native-test a-component-is-a-game-child-disposed-before-it
  (with-component-game (game (lambda (g)
                               (list (make-instance 'counting-component :game g))))
    (let ((component (first (made-components game))))
      (signals xna:cna-ownership-error (xna:dispose game))
      (xna:dispose component)
      (is (xna:disposed-p component))
      (is (= 1 (component-disposes component))
          "CNA should have called the component's dispose hook once; it called it ~d ~
           time(s)" (component-disposes component))
      (finishes (xna:dispose component))
      (signals xna:cna-disposed-error (xna:component-enabled component)))))

(define-native-test disposing-a-component-empties-its-registry-entry
  "The registry is what roots a callback target. A component whose entry outlived
it would be a leak with no other symptom, so the count is checked directly."
  (let ((before (int:callback-registry-count)))
    (with-component-game (game (lambda (g)
                                 (list (make-instance 'counting-component :game g))))
      (is (> (int:callback-registry-count) before)
          "a live component should be rooted in the registry")
      (xna:dispose (first (made-components game))))
    (is (= before (int:callback-registry-count))
        "the registry kept ~d entr(y/ies) after everything was disposed"
        (- (int:callback-registry-count) before))))

;;; --- LaunchParameters -----------------------------------------------------------------

(define-native-test launch-parameters-are-a-string-map-and-one-object
  "XNA derives LaunchParameters from Dictionary<string,string> and adds nothing.
CNA has no route that reports a game's, so it is empty unless the program fills
it -- which docs/limitations.md records rather than leaving to be discovered."
  (with-component-game (game nil)
    (let ((parameters (xna:launch-parameters game)))
      (is (eq parameters (xna:launch-parameters game))
          "Game.LaunchParameters must answer the same object every time")
      (is (null (xna:launch-parameter-names parameters))
          "CNA reports no launch parameters, so a game's start empty")
      (setf (xna:launch-parameter parameters "level") "3")
      (is (string= "3" (xna:launch-parameter parameters "level")))
      (is (equal '("level") (xna:launch-parameter-names parameters)))
      (setf (xna:launch-parameter parameters "level") nil)
      (is (null (xna:launch-parameter parameters "level")))
      (is (null (xna:launch-parameter-names parameters))))))

;;; --- a subclass initializer that fails after the native handle exists ------------
;;;
;;; The realistic shape of this leak, and the reason the rollback is an `:around'
;;; rather than an `unwind-protect' inside the `:after': a subclass's own
;;; `initialize-instance :after' runs *last*, after GAME-COMPONENT's has created
;;; the native component and registered it as a game child. One that signals used
;;; to leave CNA holding a component the caller never received.

(define-condition component-construction-blew-up (error) ())

(defclass exploding-component (xna:game-component) ())

(defmethod initialize-instance :after ((component exploding-component) &key)
  (error 'component-construction-blew-up))

(define-native-test a-failed-component-construction-leaves-nothing-behind
  ;; As with the Effect rollback, the assertion that matters most is the
  ;; fixture's teardown: CNA refuses to destroy a game while a child handle is
  ;; alive, so a leak here shows up there.
  (let ((signalled nil) (children-after nil) (registry-after nil) (before nil))
    (with-component-game (game nil)
      ;; Measured *inside* the fixture: the game itself is a callback target, so a
      ;; baseline taken before it exists would count the game's own entry as a
      ;; leak.
      (setf before (int:callback-registry-count))
      (handler-case (make-instance 'exploding-component :game game)
        (component-construction-blew-up () (setf signalled t)))
      (setf children-after
            (count-if (lambda (child)
                        (and (typep child 'xna:game-component)
                             (not (xna:disposed-p child))))
                      (int:children-of game))
            registry-after (int:callback-registry-count))
      ;; The collection must not be holding it either.
      (is (zerop (xna:component-count (xna:components game)))
          "the game's collection kept ~d component(s) after a failed construction"
          (xna:component-count (xna:components game))))
    (is-true signalled "the subclass initializer did not signal")
    (is (= 0 children-after)
        "the game was left owning ~d live component(s) it never handed out"
        children-after)
    (is (= before registry-after)
        "a failed construction left ~d callback registry entr(y/ies) behind"
        (- registry-after before))))
