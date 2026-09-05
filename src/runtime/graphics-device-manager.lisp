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
    (let ((handle (cffi:mem-ref out :uint64)))
      (cna-lisp.internal:record-construction-undo
       manager
       (lambda () (cna-lisp.internal.ffi::%graphics-device-manager-destroy handle)))
      (setf (cna-lisp.internal:handle-of manager) handle
            (slot-value manager 'cna-lisp.internal::owner) game
            (slot-value manager 'cna-lisp.internal::owner-thread)
            (cna-lisp.internal:owner-thread-of game))))
  (cna-lisp.internal:register-child game manager)
  (cna-lisp.internal:record-construction-undo
   manager (lambda () (cna-lisp.internal:invalidate manager))))

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

(macrolet ((define-manager-property (name kind getter setter doc
                                    &optional to-value from-value)
             ;; KIND :ENUM takes the enum's own two conversion functions, so the
             ;; number never appears here: a preference is a keyword, or a list
             ;; of them for a flags enum, exactly as it is everywhere else in
             ;; this projection.
             (let ((op (string-downcase (symbol-name name)))
                   (set-op (format nil "(setf ~(~a~))" name)))
               `(progn
                  (defgeneric ,name (manager) (:documentation ,doc))
                  (defmethod ,name ((manager graphics-device-manager))
                    (cna-lisp.internal:check-usable manager ,op)
                    (cffi:with-foreign-object (out ,(ecase kind
                                                      (:boolean :uint8)
                                                      (:integer :int32)
                                                      (:enum :uint32)))
                      (cna-lisp.internal:check-result
                       (,getter (cna-lisp.internal:handle-of manager) out)
                       ,op :object-type 'graphics-device-manager)
                      ,(ecase kind
                         (:boolean '(cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))
                         (:integer '(cffi:mem-ref out :int32))
                         (:enum `(,from-value (cffi:mem-ref out :uint32))))))
                  (defgeneric (setf ,name) (value manager))
                  (defmethod (setf ,name) (value (manager graphics-device-manager))
                    (cna-lisp.internal:check-usable manager ,set-op)
                    (cna-lisp.internal:check-result
                     (,setter (cna-lisp.internal:handle-of manager)
                              ,(ecase kind
                                 (:boolean '(cna-lisp.internal.ffi:cna-bool-of value))
                                 (:integer 'value)
                                 (:enum `(,to-value value))))
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
    "GraphicsDeviceManager.SynchronizeWithVerticalRetrace.")
  (define-manager-property prefer-multi-sampling :boolean
    cna-lisp.internal.ffi::%graphics-device-manager-get-prefer-multi-sampling
    cna-lisp.internal.ffi::%graphics-device-manager-set-prefer-multi-sampling
    "GraphicsDeviceManager.PreferMultiSampling.")
  (define-manager-property graphics-profile :enum
    cna-lisp.internal.ffi::%graphics-device-manager-get-graphics-profile
    cna-lisp.internal.ffi::%graphics-device-manager-set-graphics-profile
    "GraphicsDeviceManager.GraphicsProfile: :REACH or :HI-DEF."
    microsoft.xna.framework.graphics:graphics-profile-value
    microsoft.xna.framework.graphics:graphics-profile-from-value)
  (define-manager-property preferred-back-buffer-format :enum
    cna-lisp.internal.ffi::%graphics-device-manager-get-preferred-back-buffer-format
    cna-lisp.internal.ffi::%graphics-device-manager-set-preferred-back-buffer-format
    "GraphicsDeviceManager.PreferredBackBufferFormat, a SurfaceFormat."
    microsoft.xna.framework.graphics:surface-format-value
    microsoft.xna.framework.graphics:surface-format-from-value)
  (define-manager-property preferred-depth-stencil-format :enum
    cna-lisp.internal.ffi::%graphics-device-manager-get-preferred-depth-stencil-format
    cna-lisp.internal.ffi::%graphics-device-manager-set-preferred-depth-stencil-format
    "GraphicsDeviceManager.PreferredDepthStencilFormat, a DepthFormat."
    microsoft.xna.framework.graphics:depth-format-value
    microsoft.xna.framework.graphics:depth-format-from-value)
  (define-manager-property supported-orientations :enum
    cna-lisp.internal.ffi::%graphics-device-manager-get-supported-orientations
    cna-lisp.internal.ffi::%graphics-device-manager-set-supported-orientations
    "GraphicsDeviceManager.SupportedOrientations, a DisplayOrientation flags set.

A *list* of keywords, because DisplayOrientation is a flags enum: `(:landscape-left
:landscape-right)' is the two-bit mask, and the empty list is `Default', which is
the named zero."
    display-orientation-value
    display-orientation-from-value))

;;; --- the two static fields ---------------------------------------------------
;;;
;;; `DefaultBackBufferWidth' and `DefaultBackBufferHeight' are `static initonly'
;;; fields, not constants and not instance properties, and their values are read
;;; from the pinned Game assembly's class constructor: `ldc.i4 0x320' and
;;; `ldc.i4 0x1e0'. Worth reading rather than assuming, because `GameWindow' in
;;; the same assembly has same-shaped defaults that are **not** the same numbers
;;; -- 0x320 by 0x258, 800 by 600.

(defun graphics-device-manager-default-back-buffer-width ()
  "GraphicsDeviceManager.DefaultBackBufferWidth: 800.

A static field, so a function of no arguments rather than a constant: XNA's is
`static initonly' and not `const', and a constant here would promise an
immutability the CLR field does not have."
  800)

(defun graphics-device-manager-default-back-buffer-height ()
  "GraphicsDeviceManager.DefaultBackBufferHeight: 480. See the width."
  480)

(defmethod cna-lisp.internal:destroy-native ((manager graphics-device-manager))
  (unwind-protect
       (cna-lisp.internal:check-result
        (cna-lisp.internal.ffi::%graphics-device-manager-destroy
         (cna-lisp.internal:handle-of manager))
        "dispose" :object-type 'graphics-device-manager)
    ;; After the destroy, as for the game: the manager's Disposed event is
    ;; raised inside it, and releasing the subscriptions first would swallow it.
    (%release-event-handlers manager)))
