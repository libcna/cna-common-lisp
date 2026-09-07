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
;;;; create' takes. `Game.Content`'s *setter* is not projected either, and
;;;; that one is local work rather than an ABI limit: the reason used to be that
;;;; `cna_game_set_content_manager_ext' copies, but nothing in CNA reads the
;;;; manager it copies into, and XNA's own setter is a null check and a field
;;;; store. docs/limitations.md has the measurement.

(in-package #:microsoft.xna.framework.content)

(defclass content-manager (cna-lisp.internal:native-object)
  ((%graphics-device :initarg :graphics-device :initform nil
                     :reader content-manager-graphics-device)
   ;; **The provider the canonical constructors were given, held by identity.**
   ;; `get_ServiceProvider' is `ldarg.0; ldfld serviceProvider; ret' -- a plain
   ;; field read -- so the object a program passed is the object it reads back,
   ;; and nothing here may substitute one. CNA's
   ;; `cna_content_manager_get_has_service_provider' is deliberately not the
   ;; source of truth for it: `content.h' says a service provider "is a Sharp
   ;; Runtime object and never crosses the C boundary", so the C ABI could not
   ;; hold this even in principle.
   (%service-provider :initform nil)
   ;; XNA's two collections, and they are two rather than one for a reason: the
   ;; cache is keyed by asset name and holds whatever Load answered, while the
   ;; disposal list holds every disposable the load *created*, which for a
   ;; SpriteFont is two objects for one name.
   (%loaded-assets :initform (make-hash-table :test #'equal)
                   :reader %content-loaded-assets
                   :documentation
                   "Cleaned asset name -> the values LOAD-ASSET answered for it.
EQUAL, because XNA's Dictionary<string,object> uses the ordinal string comparer:
the key is case-sensitive there and here.")
   (%disposable-assets :initform '() :accessor %content-disposable-assets
                       :documentation
                       "Every asset this manager created, newest first, in the
order UNLOAD must dispose them: a SpriteFont before the atlas it keeps alive."))
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

(defmethod initialize-instance :after
    ((manager content-manager)
     &key (graphics-device nil graphics-device-supplied)
          (service-provider nil service-provider-supplied)
          (root-directory "" root-directory-supplied))
  "XNA's two constructors and this binding's one extension, told apart by their
complete keyword sets.

    (make-instance 'content-manager :service-provider (services game))
    (make-instance 'content-manager :service-provider (services game)
                                    :root-directory \"Content\")
    (make-instance 'content-manager :graphics-device device)
    (make-instance 'content-manager :graphics-device device
                                    :root-directory \"Content\")

The first two are `ContentManager(IServiceProvider)' and
`ContentManager(IServiceProvider, String)'. The last two are the **extension**
that has been here since before `Game.Services' existed: CNA's
`cna_content_manager_create' takes a graphics device and cannot carry a service
provider, so a manager built straight from a device was the only shape available.
It is kept rather than replaced -- a working constructor is not removed because a
better-named one arrived.

**The four shapes are exact and do not blend.** `:SERVICE-PROVIDER' with
`:GRAPHICS-DEVICE', or either with a keyword neither takes, names no constructor
and is refused rather than being filled in with a default -- the rule
`%CHECK-OVERLOAD-KEYWORDS' exists for and the one `Play(0.5f, 0, 0)' taught this
project.

A game's own manager is a fifth way in and is not one of these: it is built by
MICROSOFT.XNA.FRAMEWORK:CONTENT and by nothing else, is a facade over a handle CNA
lends, and takes no keywords at all."
  (if (eq (cna-lisp.internal:ownership-of manager) :parent-owned)
      (%initialize-content-facade manager
                                  (or graphics-device service-provider)
                                  root-directory-supplied)
      (let ((shape (microsoft.xna.framework::%check-overload-keywords
                    "make-instance 'content-manager"
                    (microsoft.xna.framework::%supplied-keywords
                     "graphics-device" graphics-device-supplied
                     "service-provider" service-provider-supplied
                     "root-directory" root-directory-supplied)
                    '((:graphics-device "graphics-device")
                      (:service-provider "service-provider")
                      (:graphics-device-rooted "graphics-device" "root-directory")
                      (:service-provider-rooted "service-provider" "root-directory"))
                    :object-type 'content-manager)))
        (ecase shape
          ((:graphics-device :graphics-device-rooted)
           (%initialize-owned-content-manager manager graphics-device root-directory))
          ((:service-provider :service-provider-rooted)
           (%initialize-canonical-content-manager
            manager service-provider root-directory))))))

(defun %initialize-canonical-content-manager (manager provider root-directory)
  "XNA's `ContentManager(IServiceProvider, String)', in its order.

The IL, which settles four questions a reader would otherwise have to guess at:

    loadedAssets     = new Dictionary<string,object>(OrdinalIgnoreCase)
    disposableAssets = new List<IDisposable>()
    Object..ctor()
    if (serviceProvider == null) throw ArgumentNullException(\"serviceProvider\")
    if (rootDirectory  == null) throw ArgumentNullException(\"rootDirectory\")
    RootDirectory = rootDirectory
    this.serviceProvider = serviceProvider

**The constructor does not resolve anything.** It stores the provider and asks it
for nothing; `ContentManager' in the pinned assembly calls `GetService' nowhere at
all. The graphics device is resolved *per load*, in the Graphics assembly's
`GraphicsContentHelper.GraphicsDeviceFromContentReader':

    contentManager.ServiceProvider.GetService(typeof(IGraphicsDeviceService))
      -> castclass IGraphicsDeviceService   // a wrong type is InvalidCastException
      -> null?          ContentLoadException
      -> .GraphicsDevice
      -> null?          ContentLoadException

So a provider whose service changes after construction is honoured on the next
load, and a provider with no graphics device service is an error at load time
rather than at construction. That is XNA's behaviour and not a convenience.

**CNA cannot be lazy in the same way**, and this is where the two runtimes have to
be reconciled rather than one being pretended into the other.
`cna_content_manager_create' takes a graphics device and makes the native manager
out of it, so a native manager cannot exist before one is resolved. This
constructor therefore resolves the service **once, here**, to build the native
manager -- and keeps the provider so that `SERVICE-PROVIDER' answers the object it
was given and a later load sees whatever the provider then holds. The difference
is confined to *when* a missing service is reported: here rather than at the first
load. It is reported with the same information either way, and the alternative --
a manager with no native object behind it, failing at its first load far from the
MAKE-INSTANCE that produced it - is the shape this file already refuses for the
extension constructor."
  (unless provider
    (error 'microsoft.xna.framework:cna-argument-error
           :operation "make-instance 'content-manager" :object-type 'content-manager
           :parameter-name "service-provider"
           :format-control
           "service-provider must not be NIL: XNA throws ArgumentNullException naming
            \"serviceProvider\"."))
  (unless root-directory
    (error 'microsoft.xna.framework:cna-argument-error
           :operation "make-instance 'content-manager" :object-type 'content-manager
           :parameter-name "root-directory"
           :format-control
           "root-directory must not be NIL: XNA throws ArgumentNullException naming
            \"rootDirectory\". The one-argument constructor passes `String.Empty', which
            is why :ROOT-DIRECTORY may be omitted but not given as NIL."))
  (check-type root-directory string)
  (let* ((service (microsoft.xna.framework:get-service
                   provider 'microsoft.xna.framework:igraphics-device-service))
         (device (and service (microsoft.xna.framework:graphics-device service))))
    (unless service
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation "make-instance 'content-manager" :object-type 'content-manager
             :format-control
             "the service provider has no ~s. XNA reports this as a ContentLoadException
              at the first load rather than here, because its constructor resolves
              nothing; CNA's `cna_content_manager_create' takes a graphics device, so a
              native manager cannot be built without one."
             :format-arguments (list 'microsoft.xna.framework:igraphics-device-service)))
    (unless device
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation "make-instance 'content-manager" :object-type 'content-manager
             :format-control
             "the graphics device service answered no graphics device. XNA raises
              ContentLoadException for this at load time, with the same two causes it
              distinguishes: no service, and a service with no device."))
    (%initialize-owned-content-manager manager device root-directory)
    ;; After the native manager exists and its undos are recorded: the provider is
    ;; managed state, and a construction that fails before this point has no
    ;; provider to forget.
    (setf (slot-value manager '%service-provider) provider)
    manager))

(defun %initialize-content-facade (manager graphics-device root-directory-supplied)
  "The game's own manager: a facade over a handle CNA lends, created by CONTENT."
  (when (or graphics-device root-directory-supplied)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "make-instance 'content-manager"
           :object-type 'content-manager
           :format-control
           "a game's own content manager is a facade over a handle CNA lends and takes ~
            neither a graphics device nor a root directory at construction. Reach it with ~
            MICROSOFT.XNA.FRAMEWORK:CONTENT and set ROOT-DIRECTORY on it."
           :format-arguments '()))
  (unless (cna-lisp.internal:owner-of manager)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "make-instance 'content-manager"
           :object-type 'content-manager
           :format-control
           "a parent-owned content manager has no game to be a facade over. This shape is ~
            produced by MICROSOFT.XNA.FRAMEWORK:CONTENT and is not a public constructor."
           :format-arguments '()))
  ;; The facade loads against its game's device, and says so rather than leaving
  ;; the slot empty for a loader to rediscover. Every loaded GraphicsResource
  ;; records the device it was loaded against, and the game's manager has to
  ;; answer that question exactly as a caller-built one does.
  (setf (slot-value manager '%graphics-device)
        (microsoft.xna.framework:graphics-device (cna-lisp.internal:owner-of manager)))
  manager)

(defun %initialize-owned-content-manager (manager graphics-device root-directory)
  "Create the native manager an owned CONTENT-MANAGER *is*, or refuse to exist."
  (unless graphics-device
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "make-instance 'content-manager"
           :object-type 'content-manager
           :format-control
           "a content manager needs the graphics device it loads against: ~
            `cna_content_manager_create' takes one, and there is no other route that ~
            makes a native manager. Without it this object would hold no handle and no ~
            owner, and would fail at its first load rather than here. Pass ~
            :GRAPHICS-DEVICE, or reach a game's own manager with ~
            MICROSOFT.XNA.FRAMEWORK:CONTENT."
           :format-arguments '()))
  (check-type root-directory string)
  (let ((device-handle
          (microsoft.xna.framework.graphics::device-handle-for-child
           graphics-device "make-instance 'content-manager"))
        ;; A ContentManager is not a GraphicsResource, so it does not go
        ;; through ADOPT-NATIVE-RESOURCE -- but it answers the same question and
        ;; must answer it the same way, or the extension constructor would build
        ;; a manager the game owns on a device the game does not.
        (owner (microsoft.xna.framework.graphics::native-resource-owner-for-device
                graphics-device)))
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
      (cna-lisp.internal:record-construction-undo
       manager (lambda () (cna-lisp.internal.ffi::%content-manager-destroy handle)))
      (setf (cna-lisp.internal:handle-of manager) handle
            (slot-value manager 'cna-lisp.internal::owner) owner
            (slot-value manager 'cna-lisp.internal::owner-thread)
            (cna-lisp.internal:owner-thread-of owner)
            (slot-value manager '%graphics-device) graphics-device)
      ;; The built-in loaders are what make Load<T> answer anything at all.
      ;; CNA registers none by default, so a manager without this call
      ;; refuses every asset with an IO failure that names nothing useful.
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%content-manager-register-builtin-loaders handle)
       "make-instance 'content-manager" :object-type 'content-manager)
      (cna-lisp.internal:register-child owner manager)
      (cna-lisp.internal:record-construction-undo
       manager (lambda () (cna-lisp.internal:invalidate manager)))
      manager)))

(defgeneric service-provider (manager)
  (:documentation
   "ContentManager.ServiceProvider: the provider this manager was built with.

    (eq (service-provider (content game)) (services game))    ; => T

**The exact object, by identity.** XNA's `get_ServiceProvider' is a plain field
read, so the object a program passed to the canonical constructor is the object
it reads back, and this answers that object rather than anything derived from it.

NIL for a manager built with the `:GRAPHICS-DEVICE' extension, which has no
provider to answer -- the extension exists because CNA's create route takes a
device and cannot carry a provider at all.

`Game.Content' answers the game's own `SERVICES', because that is what the pinned
`Game' constructor passes.

**Not read from CNA, and `cna_content_manager_get_has_service_provider' is not
its source of truth.** `content.h' says a service provider \"is a Sharp Runtime
object and never crosses the C boundary\" and that \"the field is inert on both
sides of the boundary\", so the C ABI has nothing to answer with; the managed
object is where a managed reference lives."))

(defmethod service-provider ((manager content-manager))
  (slot-value manager '%service-provider))

(defun %write-string-view (pointer data length)
  "Fill the CNA_StringView at POINTER with DATA and LENGTH."
  (setf (cffi:foreign-slot-value pointer '(:struct cna-lisp.internal.ffi::cna-string-view)
                                 'cna-lisp.internal.ffi::data)
        data
        (cffi:foreign-slot-value pointer '(:struct cna-lisp.internal.ffi::cna-string-view)
                                 'cna-lisp.internal.ffi::byte-length)
        length))

(defmethod microsoft.xna.framework::%check-disposable ((manager content-manager))
  "A content manager is disposable whichever way it was made, facade included.

The default method refuses a :PARENT-OWNED object because a facade has nothing of
its own to release. A content manager is the exception the default's wording
allows for: `Game.Content' *does* own something -- the assets it loaded -- and
XNA's `ContentManager.Dispose()' is `Unload()' followed by nulling both
collections, which is a purely managed operation that destroys no native object
at all. So disposing this facade releases its assets and marks it disposed, and
the native manager CNA lends is left alone, exactly as XNA leaves nothing native
behind either.

Specialised to *accept*, and this is the only place that is right: what makes it
right is that the disposal has real work to do, not that refusing was
inconvenient."
  (declare (ignore manager))
  nil)

(defmethod cna-lisp.internal:destroy-native ((manager content-manager))
  "XNA's Dispose(bool): Unload(), and then the object is finished.

The unload is first and is not optional -- it is what the member is *for*, and a
manager that dropped its assets on the floor here would leave CNA holding every
one of them. The native destroy runs only for a manager this binding created:
CNA lends a game's own manager as a borrowed handle that \"cannot be destroyed\",
and XNA has nothing native to destroy on either kind."
  (unload manager)
  (unless (eq (cna-lisp.internal:ownership-of manager) :parent-owned)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%content-manager-destroy (cna-lisp.internal:handle-of manager))
     "dispose" :object-type 'content-manager)))

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

**Loading the same name twice answers the same object**, which is XNA's cache and
is what the implementation below does: the cleaned name is looked up first, a hit
of the right type is answered as it stands, and only a miss reads anything. A hit
of the *wrong* type is a failure rather than a second load, because XNA's cache is
keyed by the cleaned name alone. CNA's own per-asset routes do not cache -- their
headers say so -- so the cache is this binding's, over them.

The loaded object is owned by the manager, and UNLOAD disposes it. A program may
still dispose one itself; DISPOSE is idempotent, so the manager's later pass over
it costs nothing."))

(defmethod load-asset ((manager content-manager) type (asset-name string))
  ;; XNA's Load<T>, step for step, read from the assembly:
  ;;
  ;;   loadedAssets == null            -> ObjectDisposedException
  ;;   IsNullOrEmpty(assetName)        -> ArgumentNullException("assetName")
  ;;   assetName = GetCleanPath(...)   -- TitleContainer's, literally
  ;;   TryGetValue hit, wrong type     -> ContentLoadException
  ;;   TryGetValue hit, right type     -> the cached instance
  ;;   miss                            -> read it, then Add it
  ;;
  ;; The cache is keyed by the *cleaned name alone* and not by the type, which is
  ;; why a hit of the wrong type is a failure rather than a second load.
  (cna-lisp.internal:check-live manager "load-asset")
  (when (zerop (length asset-name))
    (error 'microsoft.xna.framework:cna-argument-error
           :operation "load-asset" :parameter-name "asset-name"
           :format-control
           "an asset name is required; XNA throws ArgumentNullException for a null or ~
            empty one."))
  (let* ((key (microsoft.xna.framework::%clean-title-path asset-name))
         (cached (gethash key (%content-loaded-assets manager))))
    (when cached
      (unless (typep (first cached) type)
        (error 'microsoft.xna.framework:cna-argument-error
               :operation "load-asset" :parameter-name "type"
               :format-control
               "~s is already loaded as a ~s, and this asked for a ~s. XNA's cache is ~
                keyed by the asset name alone, so the second type is a ContentLoadException ~
                there rather than a second load; it is a failure here for the same reason."
               :format-arguments (list key (type-of (first cached)) type)))
      (return-from load-asset (values-list cached)))
    (let ((loader (cdr (assoc type *asset-loaders*))))
      (unless loader
        (error 'microsoft.xna.framework:cna-not-supported-error
               :operation "load-asset"
               :object-type 'content-manager
               :format-control
               "there is no native route that loads a ~s. CNA's ABI has one loader per asset ~
                type rather than a generic one, so the loadable set is finite: ~{~s~^, ~}."
               :format-arguments (list type (loadable-asset-types))))
      (funcall loader manager key))))

(defgeneric %commit-loaded-asset (manager asset-name record &rest values)
  (:documentation
   "The last step of a load: cache the asset and take responsibility for it.

Called from **inside the load's own rollback ledger**, with that ledger's
recorder, because it is a step that can fail like any other -- and a load whose
caching failed must give the whole asset back rather than leave CNA holding
something nobody has a name for. That is the commit in `all handles acquired ->
metadata -> objects -> registration -> cache -> COMMIT'.

VALUES is what LOAD-ASSET will answer, in order. They are pushed onto the
disposal list in reverse, so that list reads front-to-back in the order UNLOAD
must dispose them: a SpriteFont before the atlas it keeps alive, and a later
asset before an earlier one.

A generic function because it is the step a failure-injection test has to be able
to make fail, the same reason %READ-TEXTURE-STORAGE is one.")
  (:method ((manager content-manager) asset-name record &rest values)
    (setf (gethash asset-name (%content-loaded-assets manager)) values)
    (funcall record
             (lambda () (remhash asset-name (%content-loaded-assets manager))))
    (dolist (value (reverse values))
      (push value (%content-disposable-assets manager))
      (let ((value value))
        (funcall record
                 (lambda ()
                   (setf (%content-disposable-assets manager)
                         (remove value (%content-disposable-assets manager)
                                 :test #'eq :count 1))))))
    (values-list values)))

;;; --- Unload -----------------------------------------------------------------

(defgeneric unload (manager)
  (:documentation
   "ContentManager.Unload(): dispose what the manager loaded, and empty its cache.

**It does destroy the objects it handed out**, because the manager owns them at
the managed projection level and XNA's `Unload()' disposes every
`IDisposable' it loaded. The assets go front-to-back in the order they were
recorded -- a `SpriteFont' before the atlas texture it keeps alive, and a later
asset before an earlier one -- and DISPOSE is idempotent, so one the caller
already disposed costs nothing.

CNA's own note, that \"independently owned resource handles returned by the
manager are not destroyed by this call\", is about `cna_content_manager_unload'
and remains true of it: that route is called as well, so neither side is left
holding an asset the other has let go.

The cache and the disposal list are cleared however this ends. If an asset's
disposal signals, every later asset is still attempted and the **first**
condition is re-signalled once the manager is empty -- a manager that failed to
release something must not go on claiming it has it."))

(defmethod unload ((manager content-manager))
  (cna-lisp.internal:check-live manager "unload")
  (let ((assets (%content-disposable-assets manager))
        (failure nil))
    (flet ((note (condition) (unless failure (setf failure condition))))
      ;; The assets first, front-to-back, which is the order they were recorded
      ;; in: a font before the atlas it keeps alive, and a later asset before an
      ;; earlier one. DISPOSE is idempotent, so an asset the caller already
      ;; disposed costs nothing here.
      (unwind-protect
           (dolist (asset assets)
             (handler-case (microsoft.xna.framework:dispose asset)
               (error (condition) (note condition))))
        ;; Cleared in a FINALLY, as XNA clears them: a manager that failed to
        ;; release something must not go on claiming it has it.
        (progn (setf (%content-disposable-assets manager) '())
               (clrhash (%content-loaded-assets manager))))
      ;; CNA's own cache too, so neither side is left holding an asset the other
      ;; has let go.
      (handler-case
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%content-manager-unload
            (%content-manager-handle manager "unload"))
           "unload" :object-type 'content-manager)
        (error (condition) (note condition))))
    (when failure (error failure)))
  (values))

(defmethod print-object ((manager content-manager) stream)
  (print-unreadable-object (manager stream :type t)
    (format stream "~:[owned~;game's~]~:[~; disposed~]"
            (eq (cna-lisp.internal:ownership-of manager) :parent-owned)
            (cna-lisp.internal:disposed-state-of manager))))
