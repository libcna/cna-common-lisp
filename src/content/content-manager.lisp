;;;; content-manager.lisp --- Microsoft.Xna.Framework.Content.ContentManager.
;;;;
;;;; The type that makes a `SpriteFont' obtainable. Everything else in this
;;;; binding can be built from arguments; a font cannot, because a font is glyph
;;;; metrics and an atlas that have to come from somewhere. Until this file
;;;; existed the only producer was a test-only one, and the template could not
;;;; draw text at all.
;;;;
;;;; **`Load<T>' is where Common Lisp gets to do what C could not.** CNA's ABI
;;;; spells the generic method as one route per asset type -- `..._load_texture2d',
;;;; `..._load_sprite_font', `..._load_texture_cube' -- because a C caller cannot
;;;; name a type. Common Lisp can, so `Load<SpriteFont>("Arial")' projects as
;;;; `(load-asset content 'sprite-font "Arial")' and stays one member rather than
;;;; becoming three differently-named functions. LOADABLE-ASSET-TYPES answers
;;;; which types this binding actually has a route for; it is a declared
;;;; extension, because XNA's `Load<T>' is generic over anything with a reader
;;;; and needs no such list.
;;;;
;;;; **A game's manager is a facade, an own one is not.** CNA lends the game's
;;;; manager as a borrowed handle that "answers the same handle every time, cannot
;;;; be destroyed, and is released with its game", so MICROSOFT.XNA.FRAMEWORK:
;;;; CONTENT is a parent-owned facade over the game, resolving that handle per
;;;; call exactly as GRAPHICS-DEVICE does. A manager built here instead is an
;;;; ordinary owned child of the game and is disposed like one.
;;;;
;;;; **What is not projected, and why.** Both of XNA's constructors take an
;;;; `IServiceProvider', which this binding cannot produce -- see
;;;; `docs/limitations.md' on `Game.Services'. So construction here is a declared
;;;; extension taking the graphics device, which is what `cna_content_manager_
;;;; create' takes. `Game.Content`'s *setter* is not projected either: XNA's
;;;; assigns a reference and CNA's `cna_game_set_content_manager_ext' **copies**,
;;;; so `(setf (content game) m)' followed by `(content game)' would answer a
;;;; different object than the one assigned. A setter that silently means
;;;; something else is worse than a missing one.

(in-package #:microsoft.xna.framework.content)

(defclass content-manager (cna-lisp.internal:native-object)
  ((%graphics-device :initarg :graphics-device :initform nil
                     :reader content-manager-graphics-device))
  (:documentation
   "Microsoft.Xna.Framework.Content.ContentManager: loads assets by logical name.

Reached as a game's own manager, which is the usual way:

    (let ((content (microsoft.xna.framework:content game)))
      (setf (root-directory content) \"Content\")
      (load-asset content 'microsoft.xna.framework.graphics:sprite-font \"Arial\"))

or built over a graphics device, which is a declared extension -- XNA's two
constructors take an `IServiceProvider' and this binding has none:

    (make-instance 'content-manager :graphics-device device
                                    :root-directory \"Content\")

A game's manager is released with its game and cannot be disposed. One built
here is an owned child of the game and must be."))

;;; --- handles ----------------------------------------------------------------

(defun %content-manager-handle (manager operation)
  "The native handle for OPERATION, resolved per call for a game's own manager.

The game's manager is borrowed and CNA answers the same handle every time, so
resolving rather than storing costs one call and cannot go stale."
  (cna-lisp.internal:check-live manager operation)
  (cna-lisp.internal:check-owner-thread
   (cna-lisp.internal:owner-thread-of manager) operation :object-type 'content-manager)
  (if (eq (cna-lisp.internal:ownership-of manager) :parent-owned)
      (let ((game (cna-lisp.internal:owner-of manager)))
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%game-get-content-manager-ext
            (cna-lisp.internal:handle-of game) out)
           operation :object-type 'content-manager)
          (cffi:mem-ref out :uint64)))
      (progn
        (when (zerop (cna-lisp.internal:handle-of manager))
          (error 'microsoft.xna.framework:cna-invalid-object-error
                 :operation operation :object-type 'content-manager
                 :format-control "~a holds no native handle."
                 :format-arguments (list 'content-manager)))
        (cna-lisp.internal:handle-of manager))))

;;; --- construction -----------------------------------------------------------

(defmethod initialize-instance :after ((manager content-manager)
                                       &key graphics-device (root-directory ""))
  "A declared extension: CNA's `cna_content_manager_create' takes the device.

XNA's `ContentManager(IServiceProvider)' and `ContentManager(IServiceProvider,
String)' are both reported missing, because this binding cannot produce an
`IServiceProvider'. This is not a projection of either -- it is the constructor
CNA offers, named as such."
  (when graphics-device
    (check-type root-directory string)
    (let ((device-handle
            (microsoft.xna.framework.graphics::device-handle-for-child
             graphics-device "make-instance 'content-manager"))
          (game (cna-lisp.internal:owner-of graphics-device)))
      (cna-lisp.internal:with-native-rollback (record)
        (let ((handle
                (cffi:with-foreign-object
                    (info '(:struct cna-lisp.internal.ffi::cna-content-manager-create-info))
                  (cffi:foreign-funcall
                   "memset" :pointer info :int 0
                   :size cna-lisp.internal.ffi::+sizeof-cna-content-manager-create-info+ :void)
                  (macrolet ((slot (name)
                               `(cffi:foreign-slot-value
                                 info
                                 '(:struct cna-lisp.internal.ffi::cna-content-manager-create-info)
                                 ',name)))
                    (setf (slot cna-lisp.internal.ffi::struct-size)
                          cna-lisp.internal.ffi::+sizeof-cna-content-manager-create-info+
                          (slot cna-lisp.internal.ffi::struct-version) 1
                          (slot cna-lisp.internal.ffi::reserved) 0))
                  (cna-lisp.internal:with-utf8-view (data length root-directory)
                    (%write-string-view
                     (cffi:foreign-slot-pointer
                      info '(:struct cna-lisp.internal.ffi::cna-content-manager-create-info)
                      'cna-lisp.internal.ffi::root-directory)
                     data length)
                    (cffi:with-foreign-object (out :uint64)
                      (cna-lisp.internal:check-result
                       (cna-lisp.internal.ffi::%content-manager-create device-handle info out)
                       "make-instance 'content-manager" :object-type 'content-manager)
                      (cffi:mem-ref out :uint64))))))
          (funcall record
                   (lambda () (cna-lisp.internal.ffi::%content-manager-destroy handle)))
          (setf (cna-lisp.internal:handle-of manager) handle
                (slot-value manager 'cna-lisp.internal::owner) game
                (slot-value manager 'cna-lisp.internal::owner-thread)
                (cna-lisp.internal:owner-thread-of game)
                (slot-value manager '%graphics-device) graphics-device)
          ;; The built-in loaders are what make Load<T> answer anything at all.
          ;; CNA registers none by default, so a manager without this call
          ;; refuses every asset with an IO failure that names nothing useful.
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%content-manager-register-builtin-loaders handle)
           "make-instance 'content-manager" :object-type 'content-manager)
          (cna-lisp.internal:register-child game manager)
          manager)))))

(defun %write-string-view (pointer data length)
  "Fill the CNA_StringView at POINTER with DATA and LENGTH."
  (setf (cffi:foreign-slot-value pointer '(:struct cna-lisp.internal.ffi::cna-string-view)
                                 'cna-lisp.internal.ffi::data)
        data
        (cffi:foreign-slot-value pointer '(:struct cna-lisp.internal.ffi::cna-string-view)
                                 'cna-lisp.internal.ffi::byte-length)
        length))

(defmethod microsoft.xna.framework::%check-disposable ((manager content-manager))
  "Refuse a game's own manager here, where a refusal costs the object nothing.

Not in DESTROY-NATIVE, which is where this refusal used to live: DISPOSE
invalidates through an UNWIND-PROTECT, so refusing there marked the facade
disposed on the way out and `Game.Content' came back unusable -- over a native
manager that was, correctly, never destroyed. See %CHECK-DISPOSABLE."
  (when (eq (cna-lisp.internal:ownership-of manager) :parent-owned)
    (error 'microsoft.xna.framework:cna-ownership-error
           :operation "dispose" :object-type 'content-manager
           :format-control
           "a game's own content manager is released with its game and cannot be disposed. ~
            CNA lends it as a borrowed handle and refuses `cna_content_manager_destroy' on ~
            one. Dispose the game instead. This manager is untouched and remains usable."
           :format-arguments '())))

(defmethod cna-lisp.internal:destroy-native ((manager content-manager))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%content-manager-destroy (cna-lisp.internal:handle-of manager))
   "dispose" :object-type 'content-manager))

;;; --- RootDirectory ----------------------------------------------------------

(defgeneric root-directory (manager)
  (:documentation
   "ContentManager.RootDirectory: the directory asset names are resolved against."))

(defgeneric (setf root-directory) (value manager)
  (:documentation "ContentManager.RootDirectory setter. An empty string is legal."))

(defmethod root-directory ((manager content-manager))
  (let ((handle (%content-manager-handle manager "root-directory")))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%content-manager-get-root-directory-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%content-manager-copy-root-directory
        handle buffer capacity out))
     "root-directory")))

(defmethod (setf root-directory) (value (manager content-manager))
  (check-type value string)
  (let ((handle (%content-manager-handle manager "(setf root-directory)")))
    (cna-lisp.internal:with-utf8-view (data length value)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%content-manager-set-root-directory handle data length)
       "(setf root-directory)" :object-type 'content-manager)))
  value)

;;; --- Load<T> ----------------------------------------------------------------
;;;
;;; One member in XNA, one generic function here, and a table saying which type
;;; arguments there is a native route for. The table is the honest shape: CNA has
;;; a route per asset type rather than a generic one, so the set is finite and
;;; nameable rather than open.

(defparameter *asset-loaders* '()
  "ASSET TYPE -> loader, filled in by the graphics layer. See LOADABLE-ASSET-TYPES.")

(defun loadable-asset-types ()
  "The asset types LOAD-ASSET has a native route for, most useful first.

A declared extension. XNA's `Load<T>' is generic over any type with a content
reader and needs no such list; CNA's ABI has one route per asset type, so the set
this binding can honour is finite, and saying which types those are is better
than discovering it one failure at a time."
  (mapcar #'car *asset-loaders*))

(defgeneric load-asset (manager type asset-name)
  (:documentation
   "ContentManager.Load<T>(String): load the asset named ASSET-NAME as TYPE.

    (load-asset content 'microsoft.xna.framework.graphics:sprite-font \"Arial\")
    (load-asset content 'microsoft.xna.framework.graphics:texture-2d \"logo\")

TYPE is the Lisp type symbol XNA spells as the generic argument, which is the one
place this projection is *closer* to XNA than the C ABI can be: `Load<T>' stays a
single member instead of becoming one function per asset type.

The asset name is logical, resolved against ROOT-DIRECTORY, and its extension is
optional. LOADABLE-ASSET-TYPES answers which types are loadable.

The loaded object is owned by the game and disposed with
MICROSOFT.XNA.FRAMEWORK:DISPOSE, before it. Loading the same name twice answers
two distinct objects here, because CNA's per-asset routes each create one; XNA's
manager caches and answers the same instance. That difference is recorded in
docs/limitations.md."))

(defmethod load-asset ((manager content-manager) type (asset-name string))
  (let ((loader (cdr (assoc type *asset-loaders*))))
    (unless loader
      (error 'microsoft.xna.framework:cna-not-supported-error
             :operation "load-asset"
             :object-type 'content-manager
             :format-control
             "there is no native route that loads a ~s. CNA's ABI has one loader per asset ~
              type rather than a generic one, so the loadable set is finite: ~{~s~^, ~}."
             :format-arguments (list type (loadable-asset-types))))
    (funcall loader manager asset-name)))

;;; --- Unload -----------------------------------------------------------------

(defgeneric unload (manager)
  (:documentation
   "ContentManager.Unload(): drop what the manager has cached.

This does **not** destroy objects already handed out. Every object LOAD-ASSET
answered is an owned CNA resource with its own lifetime, and CNA's own note says
so: \"independently owned resource handles returned by the manager are not
destroyed by this call\". Dispose them yourself, as you would any other
resource."))

(defmethod unload ((manager content-manager))
  (let ((handle (%content-manager-handle manager "unload")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%content-manager-unload handle)
     "unload" :object-type 'content-manager))
  (values))

(defmethod print-object ((manager content-manager) stream)
  (print-unreadable-object (manager stream :type t)
    (format stream "~:[owned~;game's~]~:[~; disposed~]"
            (eq (cna-lisp.internal:ownership-of manager) :parent-owned)
            (cna-lisp.internal:disposed-state-of manager))))
