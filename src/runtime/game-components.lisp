;;;; game-components.lisp --- GameComponent, DrawableGameComponent and the
;;;; collection the game drives them from.
;;;;
;;;; **This is the one place in the binding where the consumer provides behaviour
;;;; rather than consuming it.** Everywhere else CNA-Lisp calls CNA; a component
;;;; is an object CNA calls, once per frame, from inside the game loop. CNA's own
;;;; header explains why it is shaped as a callback set: its component types are
;;;; C++ interfaces, C cannot implement an interface, so the ABI takes handlers
;;;; and supplies the object that implements the interfaces and forwards to them.
;;;;
;;;; **The component engine is CNA's, and it is really wired up.** A component is
;;;; not a list this binding walks: `cna_game_components_add' puts it in the
;;;; collection the game drives, and CNA calls `initialize', `update', `draw',
;;;; `load-content' and `unload-content' in its own order, honouring
;;;; `UpdateOrder', `DrawOrder', `Enabled' and `Visible'. A component added after
;;;; the game has initialized is initialized when it is added, which is XNA's
;;;; behaviour and CNA's documented one.
;;;;
;;;; **The lifecycle generic functions are the same ones a Game overrides.**
;;;; XNA's `GameComponent.Update' and `Game.Update' have the same name for the
;;;; same reason, and here they are the same generic function with a method on a
;;;; different class. A consumer writes
;;;;
;;;;     (defclass spinner (xna:drawable-game-component) ())
;;;;     (defmethod xna:update ((c spinner) game-time) ...)
;;;;     (defmethod xna:draw   ((c spinner) game-time) ...)
;;;;
;;;; and nothing else. There is no register-this-method step, because CLOS is the
;;;; registration.
;;;;
;;;; **`IGameComponent', `IUpdateable' and `IDrawable' are generic functions**,
;;;; the same way the three `IEffect*' contracts are: the interface is what the
;;;; object answers, and CLOS dispatches it.
;;;;
;;;; `Game.Services' is **not** here, and the reason is CNA's container rather
;;;; than the interfaces that key it. Read from the pinned metadata:
;;;; `IGraphicsDeviceService' is `GraphicsDevice', `DeviceCreated',
;;;; `DeviceDisposing', `DeviceReset' and `DeviceResetting', and all five are
;;;; already complete on `GraphicsDeviceManager', the type that implements it.
;;;; (`GraphicsDevice' has events of its own called `DeviceReset' and
;;;; `DeviceResetting' too; they are a different set on a different type, and
;;;; confusing the two is what this comment used to do.)
;;;;
;;;; What is missing is a container. CNA has `cna_game_services_contains_ext' and
;;;; `remove_ext' over a closed enum of runtime-registered identities, and no
;;;; route that registers a service or hands one back -- so `GetService', the
;;;; member the type exists for, cannot be answered for the two services XNA
;;;; itself registers. A Lisp dictionary would answer it for services the program
;;;; added and quietly invent the rest. `docs/limitations.md' records it.

(in-package #:microsoft.xna.framework)

;;; --- the component itself ----------------------------------------------------

(defclass game-component (cna-lisp.internal:native-object)
  ((%game :initarg :game :reader game-of-component)
   (%token :initform nil :accessor %component-token)
   (%event-handlers :initform '() :accessor %event-handlers)
   (%initialized :initform nil :accessor %component-initialized-p))
  (:documentation
   "Microsoft.Xna.Framework.GameComponent: a piece of a game's behaviour the game
itself drives.

    (defclass spinner (xna:game-component) ())
    (defmethod xna:update ((c spinner) game-time) ...)

    (add-component (components game) (make-instance 'spinner :game game))

Subclass it and specialise INITIALIZE and UPDATE -- the same generic functions a
GAME specialises, because XNA gives them the same names for the same reason.

A component is created against a game and belongs to it; adding it to the game's
COMPONENTS collection is what makes the game drive it, and XNA is the same. It is
disposed with DISPOSE, before its game."))

(defclass drawable-game-component (game-component)
  ()
  (:documentation
   "Microsoft.Xna.Framework.DrawableGameComponent: a GameComponent that also
draws.

Adds DRAW, LOAD-CONTENT and UNLOAD-CONTENT -- again the same generic functions a
GAME specialises -- and the VISIBLE and DRAW-ORDER properties. The GRAPHICS-DEVICE
it answers is the game's, and like every other borrowed device it is legal only
inside a lifecycle callback."))

;;; --- construction ------------------------------------------------------------

(defun %write-component-callbacks (pointer token)
  "Fill a CNA_GameComponentCallbacks with the six top-level callbacks and TOKEN.

Every handler is supplied, including for a plain GameComponent that cannot draw:
CNA ignores the drawing handlers for an updateable component, and giving it a
handler it will not call is cheaper than two callback sets. The context is the
registry token, never a Lisp object -- a Lisp object moves."
  (cffi:foreign-funcall "memset" :pointer pointer :int 0
                        :size cna-lisp.internal.ffi::+sizeof-cna-game-component-callbacks+
                        :void)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-game-component-callbacks)
                 ',name)))
    (destructuring-bind (initialize update draw load-content unload-content dispose)
        (cna-lisp.internal.ffi:component-callback-pointers)
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-game-component-callbacks+
            (slot cna-lisp.internal.ffi::struct-version) 1
            (slot cna-lisp.internal.ffi::initialize) initialize
            (slot cna-lisp.internal.ffi::update) update
            (slot cna-lisp.internal.ffi::draw) draw
            (slot cna-lisp.internal.ffi::load-content) load-content
            (slot cna-lisp.internal.ffi::unload-content) unload-content
            (slot cna-lisp.internal.ffi::dispose) dispose
            (slot cna-lisp.internal.ffi::context) (cffi:make-pointer token))))
  pointer)

(defgeneric %component-create-route (component)
  (:documentation "The CNA route that makes this kind of component.")
  (:method ((component game-component))
    #'cna-lisp.internal.ffi::%game-component-create)
  (:method ((component drawable-game-component))
    #'cna-lisp.internal.ffi::%drawable-game-component-create))

(defmethod initialize-instance :after ((component game-component) &key game)
  (unless game
    (error 'cna-usage-error
           :operation "make-instance 'game-component"
           :format-control
           "a GameComponent is created against a Game; pass :GAME. XNA's ~
            constructor takes one too, and the component's Game property is it."))
  (check-type game game)
  (cna-lisp.internal:check-usable game "make-instance 'game-component")
  ;; The undos go in NATIVE-OBJECT's construction ledger, which is undone by the
  ;; INITIALIZE-INSTANCE :around there and therefore covers a subclass's own
  ;; `:after' as well as this one. It used to be a ledger and an `:around' of
  ;; this class's own; two ledgers for one object is the shape this binding now
  ;; refuses everywhere.
  (flet ((record (thunk) (cna-lisp.internal:record-construction-undo component thunk)))
    ;; The registry is what keeps a callback target reachable, so an entry CNA can
    ;; never call is a leak with no other symptom.
    (let ((token (cna-lisp.internal:register-callback-target component)))
      (setf (%component-token component) token)
      (record (lambda ()
                (cna-lisp.internal:unregister-callback-target token)
                (setf (%component-token component) nil)))
      (cffi:with-foreign-object
          (callbacks '(:struct cna-lisp.internal.ffi::cna-game-component-callbacks))
        (%write-component-callbacks callbacks token)
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (funcall (%component-create-route component)
                    (cna-lisp.internal:handle-of game) callbacks out)
           "make-instance 'game-component" :object-type (type-of component))
          (let ((handle (cffi:mem-ref out :uint64)))
            (setf (cna-lisp.internal:handle-of component) handle
                  (slot-value component 'cna-lisp.internal::owner) game
                  (slot-value component 'cna-lisp.internal::owner-thread)
                  (cna-lisp.internal:owner-thread-of game))
            (record (lambda ()
                      (cna-lisp.internal.ffi::%game-component-destroy handle)
                      (setf (cna-lisp.internal:handle-of component) 0))))
          (cna-lisp.internal:register-child game component)
          (record (lambda () (cna-lisp.internal:unregister-child game component)))
          (%remember-component (components game) component)
          (record (lambda () (%forget-component (components game) component))))))))

(defmethod cna-lisp.internal:destroy-native ((component game-component))
  "Dispose, then release the subscriptions, then release the handle -- in that
order, and each step is there for a reason.

CNA splits what XNA spells as one `Dispose' into two routes:
`cna_game_component_dispose' is the canonical operation, which raises the
component's `Disposed' event and calls back into its dispose hook, and
`cna_game_component_destroy' releases the handle. So the canonical one goes
first, while a handler subscribed to `Disposed' is still there to hear it.

The subscriptions come next and not last, because **a registration keeps the
component alive** -- CNA's header says so in as many words -- and a destroy with
one outstanding is refused. That is the opposite of the ordering a
GraphicsResource wants, where the Disposing event is raised *inside* the
destruction and releasing first would swallow the last thing the resource says.
Two different ABIs, two different orders, and getting this one backwards showed
up as a game that would not shut down."
  (let ((handle (cna-lisp.internal:handle-of component))
        (failure nil))
    (flet ((release (thunk operation)
             (handler-case (cna-lisp.internal:check-result (funcall thunk) operation
                                                           :object-type (type-of component))
               (error (condition) (unless failure (setf failure condition))))))
      (release (lambda () (cna-lisp.internal.ffi::%game-component-dispose handle)) "dispose")
      (handler-case (%release-event-handlers component)
        (error (condition) (unless failure (setf failure condition))))
      (release (lambda () (cna-lisp.internal.ffi::%game-component-destroy handle)) "dispose"))
    (%forget-component (components (game-of-component component)) component)
    (when (%component-token component)
      (cna-lisp.internal:unregister-callback-target (%component-token component))
      (setf (%component-token component) nil))
    (when failure (error failure))))

;;; --- what CNA calls back into ------------------------------------------------

(defgeneric component-dispose (component)
  (:documentation
   "GameComponent.Dispose(bool) as the hook a subclass overrides.

Called by CNA when the component is disposed, before its handle is released. XNA
spells the overridable half of disposal `Dispose(bool disposing)'; Common Lisp
has no protected methods, so the hook is its own generic function and DISPOSE
stays the one operation every native object here answers.")
  (:method ((component game-component)) (values)))

(defun %dispatch-component-callback (kind token game-time-pointer)
  "Run one component lifecycle handler. Called from the top-level callbacks.

A condition raised by a consumer's method has nowhere to go: CNA's component
handlers return void, so there is no result code and no diagnostic structure to
write. It is preserved and re-signalled on the Lisp side once the enclosing C
call has returned, which is the same containment every callback here gets."
  (let ((component (cna-lisp.internal:callback-target token)))
    (when component
      (handler-case
          ;; Inside a callback scope, like every other CNA callback: a component's
          ;; DRAW is exactly where a consumer reaches for the graphics device, and
          ;; the device is lent only for a callback's duration.
          (cna-lisp.internal:call-with-callback-scope
           (lambda ()
            (ecase kind
              (:initialize (setf (%component-initialized-p component) t)
                           (initialize component))
              (:update (update component (%game-time-from-pointer game-time-pointer)))
              (:draw (draw component (%game-time-from-pointer game-time-pointer)))
              (:load-content (load-content component))
              (:unload-content (unload-content component))
              (:dispose (component-dispose component)))))
        (serious-condition (condition)
          (setf cna-lisp.internal:*pending-callback-condition* condition)))))
  (values))

(setf cna-lisp.internal.ffi:*component-dispatcher* #'%dispatch-component-callback)

;;; --- IUpdateable and IDrawable, as properties ---------------------------------

(macrolet
    ((define-component-boolean (name getter setter class documentation)
       `(progn
          (defgeneric ,name (component) (:documentation ,documentation))
          (defgeneric (setf ,name) (value component)
            (:documentation ,(format nil "~a's setter." documentation)))
          (defmethod ,name ((component ,class))
            (cna-lisp.internal:check-usable component ,(string-downcase (symbol-name name)))
            (cffi:with-foreign-object (out :uint8)
              (cna-lisp.internal:check-result
               (,getter (cna-lisp.internal:handle-of component) out)
               ,(string-downcase (symbol-name name)) :object-type (type-of component))
              (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8))))
          (defmethod (setf ,name) (value (component ,class))
            (cna-lisp.internal:check-usable component ,(string-downcase (symbol-name name)))
            (cna-lisp.internal:check-result
             (,setter (cna-lisp.internal:handle-of component)
                      (cna-lisp.internal.ffi:cna-bool-of value))
             ,(string-downcase (symbol-name name)) :object-type (type-of component))
            value)))
     (define-component-int32 (name getter setter class documentation)
       `(progn
          (defgeneric ,name (component) (:documentation ,documentation))
          (defgeneric (setf ,name) (value component)
            (:documentation ,(format nil "~a's setter." documentation)))
          (defmethod ,name ((component ,class))
            (cna-lisp.internal:check-usable component ,(string-downcase (symbol-name name)))
            (cffi:with-foreign-object (out :int32)
              (cna-lisp.internal:check-result
               (,getter (cna-lisp.internal:handle-of component) out)
               ,(string-downcase (symbol-name name)) :object-type (type-of component))
              (cffi:mem-ref out :int32)))
          (defmethod (setf ,name) (value (component ,class))
            (check-type value (signed-byte 32))
            (cna-lisp.internal:check-usable component ,(string-downcase (symbol-name name)))
            (cna-lisp.internal:check-result
             (,setter (cna-lisp.internal:handle-of component) value)
             ,(string-downcase (symbol-name name)) :object-type (type-of component))
            value))))
  (define-component-boolean component-enabled
      cna-lisp.internal.ffi::%game-component-get-enabled
      cna-lisp.internal.ffi::%game-component-set-enabled
      game-component
      "IUpdateable.Enabled: whether the game calls this component's UPDATE.")
  (define-component-int32 update-order
      cna-lisp.internal.ffi::%game-component-get-update-order
      cna-lisp.internal.ffi::%game-component-set-update-order
      game-component
      "IUpdateable.UpdateOrder: lower runs first.")
  (define-component-boolean component-visible
      cna-lisp.internal.ffi::%drawable-game-component-get-visible
      cna-lisp.internal.ffi::%drawable-game-component-set-visible
      drawable-game-component
      "IDrawable.Visible: whether the game calls this component's DRAW.")
  (define-component-int32 draw-order
      cna-lisp.internal.ffi::%drawable-game-component-get-draw-order
      cna-lisp.internal.ffi::%drawable-game-component-set-draw-order
      drawable-game-component
      "IDrawable.DrawOrder: lower draws first."))

(defgeneric component-game (component)
  (:documentation
   "GameComponent.Game: the game this component was created against.

The Lisp object, cross-checked against the handle CNA reports. CNA's ABI has no
route from a game handle back to the CLOS object that owns it, so this compares
rather than invents -- the same reasoning BasicEffect.Texture uses."))

(defmethod component-game ((component game-component))
  (cna-lisp.internal:check-usable component "component-game")
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-component-get-game
      (cna-lisp.internal:handle-of component) out)
     "component-game" :object-type (type-of component))
    (let ((native (cffi:mem-ref out :uint64))
          (game (game-of-component component)))
      (unless (= native (cna-lisp.internal:handle-of game))
        (error 'cna-invalid-state-error
               :operation "component-game" :object-type (type-of component)
               :format-control
               "CNA reports this component belongs to a game this binding did not ~
                create it against."))
      game)))

(defmethod graphics-device ((component drawable-game-component))
  "DrawableGameComponent.GraphicsDevice: the game's device.

There is one device in a CNA-Lisp program and one facade for it, so this answers
the game's rather than wrapping the borrowed handle a second time."
  (cna-lisp.internal:check-live component "graphics-device")
  (graphics-device (game-of-component component)))

;;; --- the component events -----------------------------------------------------

(defparameter *game-component-event-values*
  `((:enabled-changed . ,cna-lisp.internal.ffi::+game-component-event-enabled-changed+)
    (:update-order-changed
     . ,cna-lisp.internal.ffi::+game-component-event-update-order-changed+)
    (:draw-order-changed
     . ,cna-lisp.internal.ffi::+game-component-event-draw-order-changed+)
    (:visible-changed . ,cna-lisp.internal.ffi::+game-component-event-visible-changed+)
    (:disposed . ,cna-lisp.internal.ffi::+game-component-event-disposed+))
  "The five events a component raises, by CNA's own identities.")

(defmethod %event-table ((object game-component))
  *game-component-event-values*)

(defmethod %subscribe-natively ((object game-component) value token registration)
  (cna-lisp.internal.ffi::%game-component-subscribe
   (cna-lisp.internal:handle-of object) value
   (cna-lisp.internal.ffi:component-event-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod %unsubscribe-natively ((object game-component) registration)
  (cna-lisp.internal.ffi::%game-component-unsubscribe registration))

(setf cna-lisp.internal.ffi:*component-event-dispatcher* #'%dispatch-game-event)

(%define-event-pair add-enabled-changed-handler remove-enabled-changed-handler
  "IUpdateable.EnabledChanged. HANDLER is called with the component.")
(%define-event-pair add-update-order-changed-handler remove-update-order-changed-handler
  "IUpdateable.UpdateOrderChanged. HANDLER is called with the component.")
(%define-event-pair add-draw-order-changed-handler remove-draw-order-changed-handler
  "IDrawable.DrawOrderChanged. HANDLER is called with the component.")
(%define-event-pair add-visible-changed-handler remove-visible-changed-handler
  "IDrawable.VisibleChanged. HANDLER is called with the component.")

(%define-event-methods game-component :enabled-changed
                       add-enabled-changed-handler remove-enabled-changed-handler)
(%define-event-methods game-component :update-order-changed
                       add-update-order-changed-handler
                       remove-update-order-changed-handler)
(%define-event-methods game-component :disposed
                       add-disposed-handler remove-disposed-handler)
(%define-event-methods drawable-game-component :draw-order-changed
                       add-draw-order-changed-handler remove-draw-order-changed-handler)
(%define-event-methods drawable-game-component :visible-changed
                       add-visible-changed-handler remove-visible-changed-handler)

;;; --- GameComponentCollection ---------------------------------------------------
;;;
;;; A game owns exactly one, so CNA gives it no handle of its own and every route
;;; addresses the game. The Lisp object is therefore a facade with the game
;;; behind it, made once and answered by identity -- XNA's `Game.Components' is a
;;; field and answers the same object every time, and so does this.
;;;
;;; It also keeps the handle-to-object map. CNA's `cna_game_components_get_at'
;;; answers a handle, and this ABI has no route from a handle back to the CLOS
;;; object that owns it; every component is created through this binding, so the
;;; map is complete by construction, and a handle it does not know is a real
;;; inconsistency rather than something to guess at.

(defclass game-component-collection ()
  ((%game :initarg :game :reader %collection-game)
   (%components :initform (make-hash-table :test #'eql) :reader %collection-components)
   (%event-handlers :initform '() :accessor %event-handlers))
  (:documentation
   "Microsoft.Xna.Framework.GameComponentCollection: the components a game drives.

Reached as `(components game)', which answers the same object every time.
Components are added with ADD-COMPONENT and removed with REMOVE-COMPONENT; the
game drives every one it holds, in CNA's own order, honouring UPDATE-ORDER,
DRAW-ORDER, COMPONENT-ENABLED and COMPONENT-VISIBLE.

Adding a component after the game has initialized initializes it there and then,
which is XNA's behaviour and CNA's documented one."))

(defun %remember-component (collection component)
  (setf (gethash (cna-lisp.internal:handle-of component)
                 (%collection-components collection))
        component))

(defun %forget-component (collection component)
  (remhash (cna-lisp.internal:handle-of component) (%collection-components collection)))

(defun %component-for-handle (collection handle operation)
  (or (gethash handle (%collection-components collection))
      (error 'cna-invalid-state-error
             :operation operation :object-type 'game-component-collection
             :format-control
             "the game's component collection holds a component this binding did ~
              not create. CNA has no route from a component handle back to the ~
              object that names it, so this refuses rather than answering a ~
              GameComponent it would have to invent.")))

(defun %collection-handle (collection operation)
  (let ((game (%collection-game collection)))
    (cna-lisp.internal:check-usable game operation)
    (cna-lisp.internal:handle-of game)))

(defgeneric component-count (collection)
  (:documentation "GameComponentCollection.Count."))

(defmethod component-count ((collection game-component-collection))
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-components-get-count
      (%collection-handle collection "component-count") out)
     "component-count" :object-type 'game-component-collection)
    (cffi:mem-ref out :uint64)))

(defgeneric component-at (collection index)
  (:documentation "GameComponentCollection's indexer: the component at INDEX."))

(defmethod component-at ((collection game-component-collection) index)
  (check-type index (integer 0))
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-components-get-at
      (%collection-handle collection "component-at") index out)
     "component-at" :object-type 'game-component-collection)
    (%component-for-handle collection (cffi:mem-ref out :uint64) "component-at")))

(defgeneric components-of (collection)
  (:documentation
   "Every component in the collection, in order, as a fresh list.

`Collection<T>' is enumerable; a fresh list is this binding's projection of an
enumeration, for the same reason GET-VERTEX-ELEMENTS answers a fresh array -- a
caller must not be able to reach into the collection through what it was given."))

(defmethod components-of ((collection game-component-collection))
  (loop for index below (component-count collection)
        collect (component-at collection index)))

(defgeneric add-component (collection component)
  (:documentation
   "GameComponentCollection.Add.

The collection accepts the same component twice, as XNA's does; CNA does not
invent a refusal and neither does this. A component added after the game has
initialized is initialized when it is added."))

(defgeneric insert-component (collection index component)
  (:documentation "GameComponentCollection.Insert."))

(defgeneric remove-component (collection component)
  (:documentation
   "GameComponentCollection.Remove. Answers T when the component was there."))

(defgeneric remove-component-at (collection index)
  (:documentation "GameComponentCollection.RemoveAt."))

(defgeneric clear-components (collection)
  (:documentation "GameComponentCollection.Clear."))

(defgeneric contains-component (collection component)
  (:documentation "GameComponentCollection.Contains."))

(defgeneric component-index (collection component)
  (:documentation
   "GameComponentCollection.IndexOf: the component's position, or NIL.

XNA answers -1 for absent. NIL is this binding's projection of that: a position
is a non-negative index, and -1 is a sentinel rather than one."))

(defun %component-handle-for (collection component operation)
  (check-type component game-component)
  (unless (eq (game-of-component component) (%collection-game collection))
    (error 'cna-ownership-error
           :operation operation :object-type 'game-component-collection
           :format-control
           "that component belongs to a different game. XNA's collection holds a ~
            game's own components and CNA refuses another game's."))
  (cna-lisp.internal:check-usable component operation)
  (cna-lisp.internal:handle-of component))

(defmethod add-component ((collection game-component-collection) component)
  (let ((handle (%component-handle-for collection component "add-component")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-components-add
      (%collection-handle collection "add-component") handle)
     "add-component" :object-type 'game-component-collection))
  (values))

(defmethod insert-component ((collection game-component-collection) index component)
  (check-type index (integer 0))
  (let ((handle (%component-handle-for collection component "insert-component")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-components-insert
      (%collection-handle collection "insert-component") index handle)
     "insert-component" :object-type 'game-component-collection))
  (values))

(defmethod remove-component ((collection game-component-collection) component)
  (let ((handle (%component-handle-for collection component "remove-component")))
    (cffi:with-foreign-object (removed :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-components-remove
        (%collection-handle collection "remove-component") handle removed)
       "remove-component" :object-type 'game-component-collection)
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref removed :uint8)))))

(defmethod remove-component-at ((collection game-component-collection) index)
  (check-type index (integer 0))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%game-components-remove-at
    (%collection-handle collection "remove-component-at") index)
   "remove-component-at" :object-type 'game-component-collection)
  (values))

(defmethod clear-components ((collection game-component-collection))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%game-components-clear
    (%collection-handle collection "clear-components"))
   "clear-components" :object-type 'game-component-collection)
  (values))

(defmethod contains-component ((collection game-component-collection) component)
  (let ((handle (%component-handle-for collection component "contains-component")))
    (cffi:with-foreign-object (present :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-components-contains
        (%collection-handle collection "contains-component") handle present)
       "contains-component" :object-type 'game-component-collection)
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref present :uint8)))))

(defmethod component-index ((collection game-component-collection) component)
  (let ((handle (%component-handle-for collection component "component-index")))
    (cffi:with-foreign-object (index :int32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-components-index-of
        (%collection-handle collection "component-index") handle index)
       "component-index" :object-type 'game-component-collection)
      ;; CNA answers int32 and uses -1 for absent, exactly as XNA's IndexOf does.
      (let ((value (cffi:mem-ref index :int32)))
        (if (minusp value) nil value)))))

;;; --- the collection's two events -----------------------------------------------
;;;
;;; The one event pair in this binding whose argument is not empty.
;;; `GameComponentCollectionEventArgs' carries the component, so unlike every
;;; other event here a handler takes two arguments: the collection that raised it
;;; and the args. The type is projected as a real object rather than flattened to
;;; the component, because XNA's handler really does receive one and a consumer
;;; porting code should find the member where it left it.

(defclass game-component-collection-event-args ()
  ((%component :initarg :game-component :reader event-args-game-component))
  (:documentation
   "Microsoft.Xna.Framework.GameComponentCollectionEventArgs: the argument
ComponentAdded and ComponentRemoved carry.

Its one member is the component that was added or removed."))

(defparameter *game-component-collection-event-values*
  '((:component-added . 0) (:component-removed . 1))
  "The collection's two events. CNA gives each its own subscribe route rather
than an identity in a table, so the numbers here only distinguish the two
handler lists.")

(defmethod %event-table ((object game-component-collection))
  *game-component-collection-event-values*)

(defmethod %check-event-usable ((object game-component-collection) operation)
  "The collection has no handle of its own; what must be usable is the game."
  (cna-lisp.internal:check-usable (%collection-game object) operation))

(defmethod %subscribe-natively ((object game-component-collection) value token
                                registration)
  (let ((handle (%collection-handle object "subscribe"))
        (pointer (cna-lisp.internal.ffi:component-collection-callback-pointer)))
    (if (zerop value)
        (cna-lisp.internal.ffi::%game-components-subscribe-added
         handle pointer (cffi:make-pointer token) registration)
        (cna-lisp.internal.ffi::%game-components-subscribe-removed
         handle pointer (cffi:make-pointer token) registration))))

(defmethod %unsubscribe-natively ((object game-component-collection) registration)
  ;; One release route serves both, and the component subscriptions too: CNA
  ;; hands out one registration handle type for all of them.
  (cna-lisp.internal.ffi::%game-component-unsubscribe registration))

(defun %dispatch-component-collection-event (token component-handle)
  "Invoke a ComponentAdded or ComponentRemoved handler with its real argument."
  (let ((entry (cna-lisp.internal:callback-target token)))
    (when entry
      (destructuring-bind (sender . function) entry
        (handler-case
            (funcall function sender
                     (make-instance 'game-component-collection-event-args
                                    :game-component
                                    (%component-for-handle
                                     sender component-handle "component event")))
          (serious-condition (condition)
            (setf cna-lisp.internal:*pending-callback-condition* condition)))))))

(setf cna-lisp.internal.ffi:*component-collection-dispatcher*
      #'%dispatch-component-collection-event)

(%define-event-pair add-component-added-handler remove-component-added-handler
  "GameComponentCollection.ComponentAdded.

HANDLER takes **two** arguments -- the collection and a
GAME-COMPONENT-COLLECTION-EVENT-ARGS -- because unlike every other event in this
binding this one's argument is not empty. EVENT-ARGS-GAME-COMPONENT answers the
component that was added.")

(%define-event-pair add-component-removed-handler remove-component-removed-handler
  "GameComponentCollection.ComponentRemoved. See ADD-COMPONENT-ADDED-HANDLER for
the handler's two arguments.")

(%define-event-methods game-component-collection :component-added
                       add-component-added-handler remove-component-added-handler)
(%define-event-methods game-component-collection :component-removed
                       add-component-removed-handler remove-component-removed-handler)

;;; --- LaunchParameters ------------------------------------------------------------

(defclass launch-parameters ()
  ((%table :initform (make-hash-table :test #'equal) :reader %launch-parameters-table))
  (:documentation
   "Microsoft.Xna.Framework.LaunchParameters: the command line, as a string map.

XNA derives it from `Dictionary<string, string>' and adds nothing: the type
exists to give the dictionary a name. So this is a string-keyed table with
LAUNCH-PARAMETER, its setter, and LAUNCH-PARAMETER-NAMES, and those three are
declared extensions rather than XNA members -- the members they stand for belong
to the BCL dictionary, which this binding does not project.

CNA has no route that reports a game's launch parameters, so a game's is empty
unless the program fills it. `docs/limitations.md' records that."))

(defgeneric launch-parameter (parameters name)
  (:documentation "The value NAME is bound to, or NIL."))

(defgeneric (setf launch-parameter) (value parameters name)
  (:documentation "Bind NAME. A NIL value removes it, as removing a key does."))

(defgeneric launch-parameter-names (parameters)
  (:documentation "Every bound name, as a fresh list."))

(defmethod launch-parameter ((parameters launch-parameters) name)
  (check-type name string)
  (values (gethash name (%launch-parameters-table parameters))))

(defmethod (setf launch-parameter) (value (parameters launch-parameters) name)
  (check-type name string)
  (when value (check-type value string))
  (if value
      (setf (gethash name (%launch-parameters-table parameters)) value)
      (progn (remhash name (%launch-parameters-table parameters)) nil)))

(defmethod launch-parameter-names ((parameters launch-parameters))
  (let ((names '()))
    (maphash (lambda (key value) (declare (ignore value)) (push key names))
             (%launch-parameters-table parameters))
    (nreverse names)))

;;; --- what the Game answers -------------------------------------------------------
;;;
;;; Both are made once, lazily, and answered by identity: XNA's `Game.Components'
;;; and `Game.LaunchParameters' are fields, so the same object comes back every
;;; time and a caller may hold on to one.

(defgeneric components (game)
  (:documentation
   "Game.Components: the collection of components this game drives.

The same object every time. Add to it with ADD-COMPONENT and the game starts
driving what you added -- initializing it there and then if the game has already
initialized."))

(defmethod components ((game game))
  (or (%game-components game)
      (setf (%game-components game)
            (make-instance 'game-component-collection :game game))))

(defgeneric launch-parameters (game)
  (:documentation
   "Game.LaunchParameters: the command line as a string map.

The same object every time. **CNA has no route that reports a game's launch
parameters**, so this is empty unless the program fills it; see
docs/limitations.md."))

(defmethod launch-parameters ((game game))
  (or (%game-launch-parameters game)
      (setf (%game-launch-parameters game) (make-instance 'launch-parameters))))

;;; The collection is a facade with no handle, so nothing in the ownership model
;;; would ever release *its* subscriptions: a ComponentAdded handler is rooted in
;;; the callback registry by a token, and a token nothing frees is a leak the
;;; stress tests report as a registry that did not empty. The game is what owns
;;; the collection, so releasing them is part of destroying the game -- before
;;; its own handlers, because CNA's registrations for both come from the same
;;; game handle.
(defmethod cna-lisp.internal:destroy-native :before ((game game))
  "Release the subscriptions held by the game's two facades, before CNA destroys it.

Both are facades with no handle of their own, so neither has a DESTROY-NATIVE to
release its own registrations from -- and for the graphics device this is not
tidiness but a requirement CNA states: a device event registration \"must be
released before `cna_game_destroy' succeeds\". Unsubscribing needs no callback
scope, because `cna_graphics_device_unsubscribe' takes only the registration."
  (let ((collection (%game-components game)))
    (when collection
      (ignore-errors (%release-event-handlers collection))))
  (let ((device (slot-value game 'graphics-device)))
    (when device
      (ignore-errors (%release-event-handlers device)))))
