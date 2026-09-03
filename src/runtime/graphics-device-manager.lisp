;;;; graphics-device-manager.lisp --- Microsoft.Xna.Framework.GraphicsDeviceManager.
;;;;
;;;; Creating one registers it as the game's graphics device manager and graphics
;;;; device service, which is what makes it a real object rather than a bag of
;;;; preferences. A game accepts exactly one; a second is refused by CNA and, so
;;;; that the diagnostic names the Lisp object, by CNA-Lisp first.

(in-package #:microsoft.xna.framework)

(defclass graphics-device-manager (cna-lisp.internal:native-object)
  ((game :initarg :game :initform nil :reader game)
   (event-handlers :initform '() :accessor %event-handlers
                   :documentation
                   "One entry per live event subscription, in the shape
runtime/events.lisp defines."))
  (:documentation
   "Microsoft.Xna.Framework.GraphicsDeviceManager.

Create one in a GAME subclass's INITIALIZE-INSTANCE :AFTER method, as XNA
constructs one in the game's constructor:

    (defmethod initialize-instance :after ((game hello-game) &key)
      (setf (graphics-manager game)
            (make-instance 'graphics-device-manager :game game)))

Dispose it before the game it belongs to."))

(defmethod initialize-instance :after ((manager graphics-device-manager) &key game)
  (unless game
    (error 'cna-usage-error
           :operation "make-instance graphics-device-manager"
           :format-control ":GAME is required: a graphics device manager belongs to a game."))
  (cna-lisp.internal:check-usable game "make-instance graphics-device-manager")
  (when (find-if (lambda (child) (typep child 'graphics-device-manager))
                 (cna-lisp.internal:children-of game))
    (error 'cna-invalid-state-error
           :operation "make-instance graphics-device-manager"
           :object-type 'graphics-device-manager
           :format-control
           "this game already has a graphics device manager; XNA's constructor refuses a ~
            second and so does CNA."))
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-manager-create
      (cna-lisp.internal:handle-of game) out)
     "make-instance graphics-device-manager" :object-type 'graphics-device-manager)
    (setf (cna-lisp.internal:handle-of manager) (cffi:mem-ref out :uint64)
          (slot-value manager 'cna-lisp.internal::owner) game
          (slot-value manager 'cna-lisp.internal::owner-thread)
          (cna-lisp.internal:owner-thread-of game)))
  (cna-lisp.internal:register-child game manager))

(defmethod graphics-device ((manager graphics-device-manager))
  "GraphicsDeviceManager.GraphicsDevice: the device the manager manages.

It is the game's own device, borrowed on the same terms, so this answers the
game's GRAPHICS-DEVICE facade rather than a second object with a second lifetime."
  (graphics-device (game manager)))

(defgeneric apply-changes (manager)
  (:documentation "GraphicsDeviceManager.ApplyChanges()."))

(defmethod apply-changes ((manager graphics-device-manager))
  (cna-lisp.internal:check-usable manager "apply-changes")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%graphics-device-manager-apply-changes
    (cna-lisp.internal:handle-of manager))
   "apply-changes" :object-type 'graphics-device-manager)
  (values))

(defgeneric toggle-full-screen (manager)
  (:documentation "GraphicsDeviceManager.ToggleFullScreen()."))

(defmethod toggle-full-screen ((manager graphics-device-manager))
  (cna-lisp.internal:check-usable manager "toggle-full-screen")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%graphics-device-manager-toggle-full-screen
    (cna-lisp.internal:handle-of manager))
   "toggle-full-screen" :object-type 'graphics-device-manager)
  (values))

(macrolet ((define-manager-property (name kind getter setter doc)
             (let ((op (string-downcase (symbol-name name)))
                   (set-op (format nil "(setf ~(~a~))" name)))
               `(progn
                  (defgeneric ,name (manager) (:documentation ,doc))
                  (defmethod ,name ((manager graphics-device-manager))
                    (cna-lisp.internal:check-usable manager ,op)
                    (cffi:with-foreign-object (out ,(ecase kind
                                                      (:boolean :uint8)
                                                      (:integer :int32)))
                      (cna-lisp.internal:check-result
                       (,getter (cna-lisp.internal:handle-of manager) out)
                       ,op :object-type 'graphics-device-manager)
                      ,(ecase kind
                         (:boolean '(cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))
                         (:integer '(cffi:mem-ref out :int32)))))
                  (defgeneric (setf ,name) (value manager))
                  (defmethod (setf ,name) (value (manager graphics-device-manager))
                    (cna-lisp.internal:check-usable manager ,set-op)
                    (cna-lisp.internal:check-result
                     (,setter (cna-lisp.internal:handle-of manager)
                              ,(ecase kind
                                 (:boolean '(cna-lisp.internal.ffi:cna-bool-of value))
                                 (:integer 'value)))
                     ,set-op :object-type 'graphics-device-manager)
                    value)))))
  (define-manager-property is-full-screen :boolean
    cna-lisp.internal.ffi::%graphics-device-manager-get-is-full-screen
    cna-lisp.internal.ffi::%graphics-device-manager-set-is-full-screen
    "GraphicsDeviceManager.IsFullScreen.")
  (define-manager-property preferred-back-buffer-width :integer
    cna-lisp.internal.ffi::%graphics-device-manager-get-preferred-back-buffer-width
    cna-lisp.internal.ffi::%graphics-device-manager-set-preferred-back-buffer-width
    "GraphicsDeviceManager.PreferredBackBufferWidth.")
  (define-manager-property preferred-back-buffer-height :integer
    cna-lisp.internal.ffi::%graphics-device-manager-get-preferred-back-buffer-height
    cna-lisp.internal.ffi::%graphics-device-manager-set-preferred-back-buffer-height
    "GraphicsDeviceManager.PreferredBackBufferHeight.")
  (define-manager-property synchronize-with-vertical-retrace :boolean
    cna-lisp.internal.ffi::%graphics-device-manager-get-synchronize-with-vertical-retrace
    cna-lisp.internal.ffi::%graphics-device-manager-set-synchronize-with-vertical-retrace
    "GraphicsDeviceManager.SynchronizeWithVerticalRetrace."))

(defmethod cna-lisp.internal:destroy-native ((manager graphics-device-manager))
  (unwind-protect
       (cna-lisp.internal:check-result
        (cna-lisp.internal.ffi::%graphics-device-manager-destroy
         (cna-lisp.internal:handle-of manager))
        "dispose" :object-type 'graphics-device-manager)
    ;; After the destroy, as for the game: the manager's Disposed event is
    ;; raised inside it, and releasing the subscriptions first would swallow it.
    (%release-event-handlers manager)))
