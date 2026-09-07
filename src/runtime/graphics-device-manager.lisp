;;;; graphics-device-manager.lisp --- Microsoft.Xna.Framework.GraphicsDeviceManager.
;;;;
;;;; Creating one registers it as the game's graphics device manager and graphics
;;;; device service, which is what makes it a real object rather than a bag of
;;;; preferences. A game accepts exactly one; a second is refused by CNA and, so
;;;; that the diagnostic names the Lisp object, by CNA-Lisp first.

(in-package #:microsoft.xna.framework)

(defclass graphics-device-manager (cna-lisp.internal:native-object)
  ((game :initarg :game :initform nil :reader game)
   ;; **Two structures rather than one, and they are two because a manager's
   ;; events do not work the way every other event in this binding does.** The
   ;; handler lists are managed state that outlives disposal, as a CLR delegate
   ;; field does; the raisers are the *one* CNA registration per event kind that
   ;; makes the framework call the virtual `On*' method. See manager-events.lisp
   ;; for why one registration per kind rather than one per handler.
   (%handler-lists :initform '() :accessor %manager-handler-lists
                   :documentation
                   "Alist EVENT -> the handler list, newest first. Raised oldest
first, which is a multicast delegate's own order.")
   (%raisers :initform '() :accessor %manager-raisers
             :documentation
             "Alist EVENT -> (TOKEN . REGISTRATION-HANDLE), at most one per event."))
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
  ;; **XNA's own duplicate check, and it is a service lookup rather than a scan.**
  ;; The constructor reads `game.Services.GetService(typeof(IGraphicsDeviceManager))'
  ;; and throws `ArgumentException(GraphicsDeviceManagerAlreadyPresent)' when it
  ;; answers non-null -- note that it tests only that one key, not both. Before
  ;; `Game.Services' existed here this had to scan the ownership graph for a live
  ;; manager instead; now the original's own test is available and is what runs,
  ;; with CNA's refusal still behind it.
  (when (get-service (services game) 'igraphics-device-manager)
    (error 'cna-invalid-state-error
           :operation "make-instance graphics-device-manager"
           :object-type 'graphics-device-manager
           :format-control
           "this game already has a graphics device manager registered under ~s; XNA's ~
            constructor refuses a second and so does CNA."
           :format-arguments (list 'igraphics-device-manager)))
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
  ;; **The managed service registration, and it is the construction's fifth step
  ;; rather than something a caller does afterwards.** XNA's constructor adds the
  ;; manager under both interface keys, in this order, immediately after storing
  ;; the game -- `AddService(typeof(IGraphicsDeviceManager), this)' then
  ;; `AddService(typeof(IGraphicsDeviceService), this)'. CNA has already made the
  ;; two *native* registrations inside `cna_graphics_device_manager_create'; these
  ;; are the managed ones, and the cross-check below is what says the two agree.
  (let ((container (services game)))
    (add-service container 'igraphics-device-manager manager)
    (cna-lisp.internal:record-construction-undo
     manager
     ;; Undoes exactly what was done here and no more: the *native* slot was
     ;; registered by CNA inside its create route and is given back by the native
     ;; destroy undo recorded above, so mirroring the removal would be undoing
     ;; something this binding did not do -- and would do it twice.
     (lambda () (remhash 'igraphics-device-manager (%service-table container))))
    (add-service container 'igraphics-device-service manager)
    (cna-lisp.internal:record-construction-undo
     manager
     (lambda () (remhash 'igraphics-device-service (%service-table container)))))
  (%cross-check-canonical-services game manager "make-instance graphics-device-manager")
  (cna-lisp.internal:register-child game manager)
  (cna-lisp.internal:record-construction-undo
   manager (lambda () (cna-lisp.internal:invalidate manager))))

;;; --- the two interfaces the manager implements -------------------------------
;;;
;;; Declared rather than inferred, because `AddService' checks assignability and
;;; a protocol has no class to test with TYPEP. This is what makes
;;; `(add-service container 'igraphics-device-service manager)' legal and
;;; `(add-service container 'igraphics-device-service "not a manager")' refused.

(declare-service-protocol-implementor 'igraphics-device-manager 'graphics-device-manager)
(declare-service-protocol-implementor 'igraphics-device-service 'graphics-device-manager)

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
  "XNA's `Dispose(bool disposing)', in its order, and it is not the symmetric
undo of the constructor.

The IL, read rather than assumed, and two things in it are surprising enough that
a careless disposal would get both wrong:

    if (game != null) {
        if (game.Services.GetService(typeof(IGraphicsDeviceService)) == this)
            game.Services.RemoveService(typeof(IGraphicsDeviceService));
        ... unsubscribe the three window events ...
    }
    if (device != null) { device.Dispose(); device = null; }
    if (Disposed != null) Disposed(this, EventArgs.Empty);

**It removes only `IGraphicsDeviceService`.** `IGraphicsDeviceManager' is added by
the constructor and never removed by anything -- the token appears in `Dispose'
nowhere -- so a disposed manager is still registered under that key. That
asymmetry is XNA's and is reproduced.

**And it removes it only if the entry is still this manager.** The `bne.un.s'
skips the removal when the service under that key is something else, so a program
that removed the canonical service and put its own provider there keeps its
provider across the manager's disposal. A disposal that removed the key
unconditionally would silently delete a user's service.

CNA's own destroy unregisters *both* native slots regardless, so after a disposal
the managed container and CNA's two slots deliberately disagree about
`IGraphicsDeviceManager'. That is the managed side being right: the container is
the public authority and CNA's slots are a cross-check, and the cross-check is
made at construction, where both sides are supposed to agree."
  (let ((game (game manager)))
    (when (and game
               (not (cna-lisp.internal:disposed-state-of game))
               (eq (get-service (services game) 'igraphics-device-service) manager))
      (remove-service (services game) 'igraphics-device-service)))
  (unwind-protect
       (cna-lisp.internal:check-result
        (cna-lisp.internal.ffi::%graphics-device-manager-destroy
         (cna-lisp.internal:handle-of manager))
        "dispose" :object-type 'graphics-device-manager)
    ;; After the destroy, as for the game: the manager's Disposed event is
    ;; raised inside it, and releasing the registrations first would swallow it.
    (%release-manager-raisers manager)))

;;; --- IGraphicsDeviceManager's three members ----------------------------------
;;;
;;; The interface has exactly three, verified against the pinned assembly's own
;;; declaration rather than counted off CNA's route list:
;;;
;;;     .class interface public abstract auto ansi IGraphicsDeviceManager
;;;       CreateDevice() : void
;;;       BeginDraw()    : bool
;;;       EndDraw()      : void
;;;
;;; XNA implements all three *explicitly* -- `private hidebysig newslot virtual
;;; final instance void Microsoft.Xna.Framework.IGraphicsDeviceManager.CreateDevice()'
;;; -- so in C# they are reachable only through the interface. Common Lisp has no
;;; explicit implementation: a generic function is reached the same way whatever
;;; the caller thinks it is holding, which `docs/common-lisp-mapping.md' records.

(defmethod create-device ((manager graphics-device-manager))
  (cna-lisp.internal:check-usable manager "create-device")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%graphics-device-manager-create-device
    (cna-lisp.internal:handle-of manager))
   "create-device" :object-type 'graphics-device-manager)
  (values))

(defmethod begin-draw-device ((manager graphics-device-manager))
  (cna-lisp.internal:check-usable manager "begin-draw-device")
  (cffi:with-foreign-object (out :uint8)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-manager-begin-draw
      (cna-lisp.internal:handle-of manager) out)
     "begin-draw-device" :object-type 'graphics-device-manager)
    (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8))))

(defmethod end-draw-device ((manager graphics-device-manager))
  (cna-lisp.internal:check-usable manager "end-draw-device")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%graphics-device-manager-end-draw
    (cna-lisp.internal:handle-of manager))
   "end-draw-device" :object-type 'graphics-device-manager)
  (values))

(defmethod clr-type-name ((manager graphics-device-manager))
  (cna-lisp.internal:check-usable manager "clr-type-name")
  (let ((handle (cna-lisp.internal:handle-of manager)))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%graphics-device-manager-get-type-name-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%graphics-device-manager-copy-type-name
        handle buffer capacity out))
     "clr-type-name")))

;;; --- the protected device-selection surface ----------------------------------
;;;
;;; `FindBestDevice', `CanResetDevice' and `RankDevices' are `family hidebysig
;;; newslot virtual' -- protected virtual -- and in XNA they are called from
;;; `ChangeDevice(bool)', which is the private method behind both `ApplyChanges'
;;; and device creation:
;;;
;;;     GraphicsDeviceInformation best = FindBestDevice(forceCreate);
;;;     game.Window.BeginScreenDeviceChange(best.PresentationParameters.IsFullScreen);
;;;     if (!forceCreate && device != null) {
;;;         OnPreparingDeviceSettings(this, new PreparingDeviceSettingsEventArgs(best));
;;;         if (CanResetDevice(best)) { ... device.Reset(...) }
;;;     }
;;;
;;; and `FindBestDevice' -> `FindBestPlatformDevice' -> `AddDevices' ->
;;; `RankDevices(foundDevices)' -> `foundDevices[0]'.
;;;
;;; **All three are partial here, for two independent measured reasons**, and
;;; both are worth stating because either alone would be enough.
;;;
;;; **1. No admitted CNA ABI has a seam to insert them into device creation.**
;;; The three are `virtual' in CNA's own C++ (`GraphicsDeviceManager.hpp' declares
;;; them so) and `grep' over `GraphicsDeviceManager.cpp' finds **no call site for
;;; any of them** outside their own definitions: CNA's `CreateDevice' and
;;; `ApplyChanges' go through `INTERNAL_CreateGraphicsDeviceInformation', which
;;; calls none of the three. Nor is any of them exposed as a C route in 0.21.0,
;;; 0.22.0 or 0.23.0. So a subclass may override these and call them, and the
;;; override will not change which device is created. In XNA it would.
;;;
;;; **2. XNA's own bodies reach two members this binding reports missing.**
;;; `AddDevices' reads `game.Window.Handle' and writes
;;; `PresentationParameters.DeviceWindowHandle', and both are absent here for
;;; reasons of their own -- CNA answers the window handle with
;;; `CNA_RESULT_NOT_SUPPORTED' by design, "a native window handle is not something
;;; the stable C boundary hands out". The candidate enumeration below is therefore
;;; XNA's shape without XNA's window filtering, which is a different function of
;;; the adapters and is described as one.
;;;
;;; They are implemented rather than left absent because the *members* are
;;; genuinely useful and genuinely XNA-shaped -- `CanResetDevice' reproduces its
;;; body exactly, and ranking a candidate list is a real operation a program can
;;; do. What is not claimed is that overriding them changes anything the framework
;;; does. `docs/limitations.md' carries the classification.

(defgeneric can-reset-device (manager information)
  (:documentation
   "GraphicsDeviceManager.CanResetDevice(GraphicsDeviceInformation).

    (can-reset-device manager candidate)

XNA's whole body, which is three instructions and one comparison:

    device.GraphicsProfile == newDeviceInfo.GraphicsProfile

-- true when the existing device's profile equals the candidate's, false
otherwise. Nothing else is consulted. Notably it does **not** consider the back
buffer, the format or the adapter, so a candidate that differs in every one of
those is still resettable as long as the profile matches.

Protected and virtual in XNA, so a subclass may override it, and a CLOS method is
that override. **Partial**: no admitted CNA ABI calls this during device change,
so an override does not affect whether a device is reset. See this file's comment
on the device-selection surface.

Refuses when there is no device yet, because XNA's body dereferences the field
and would throw `NullReferenceException'; a condition naming the reason is the
projection of that.")
  (:method ((manager graphics-device-manager) information)
    (cna-lisp.internal:check-usable manager "can-reset-device")
    (check-type information graphics-device-information)
    (let ((device (graphics-device manager)))
      (unless device
        (error 'cna-invalid-state-error
               :operation "can-reset-device" :object-type 'graphics-device-manager
               :format-control
               "there is no graphics device to compare against. XNA reads
                `device.GraphicsProfile' with no null test and throws
                NullReferenceException here."))
      (eq (microsoft.xna.framework.graphics:graphics-profile device)
          (graphics-profile-of information)))))

(defgeneric rank-devices (manager candidates)
  (:documentation
   "GraphicsDeviceManager.RankDevices(List<GraphicsDeviceInformation>).

    (setf candidates (rank-devices manager candidates))

**Answers the ranked sequence, and callers must use the answer.** XNA's signature
returns void and sorts the caller's `List<T>' in place -- `RankDevicesPlatform' is
`foundDevices.Sort(new GraphicsDeviceInformationComparer(this))' -- and
`FindBestPlatformDevice' then takes `foundDevices[0]' from the list it passed in.
A Common Lisp list cannot be reordered in place in a way a caller's variable would
see, and `SORT' is permitted to destroy its argument, so this projection is
explicit about both halves: the argument may be destroyed, and the ranked sequence
is the return value. A caller that ignores the answer has ignored the ranking,
which is exactly the failure a silent temporary copy would have hidden.

A list stays a list and a vector stays a vector; `List<GraphicsDeviceInformation>'
is not projected as a BCL type, for the reason no other generic collection here is.

The order is XNA's `GraphicsDeviceInformationComparer', which is a private type
and therefore not a member of anything -- see %RANK-DEVICE-CANDIDATES for the
comparison it makes and which parts of it this binding can reproduce.

Protected and virtual in XNA, so a subclass may override it. **Partial**: no
admitted CNA ABI calls this during device change.")
  (:method ((manager graphics-device-manager) candidates)
    (cna-lisp.internal:check-usable manager "rank-devices")
    (%rank-device-candidates manager candidates)))

(defun %device-candidate-rank-key (manager information)
  "The sort key XNA's private comparer orders candidates by, as far as it applies.

`GraphicsDeviceInformationComparer.Compare' is a chain of tie-breaks, and this
reproduces the ones whose inputs exist in this projection, in its order:

  1. the higher `GraphicsProfile' first -- `HiDef' before `Reach';
  2. the candidate whose `IsFullScreen' matches the manager's preference first;
  3. the higher-ranked back-buffer format first, by the comparer's own
     `RankFormat';
  4. the higher `MultiSampleCount' first;
  5. the candidate whose aspect ratio is closest to the preferred one, where the
     comparer treats differences within `0.2' as a tie and falls back to the
     preferred back-buffer size when none was set.

The tie-breaks after those read `Adapter.CurrentDisplayMode' and the window
handle, and the window half has no counterpart here; ranking stops where its
inputs do rather than inventing an order."
  (let* ((pp (presentation-parameters-of information))
         (preferred-width (preferred-back-buffer-width manager))
         (preferred-height (preferred-back-buffer-height manager))
         (preferred-ratio
           (if (and (plusp preferred-width) (plusp preferred-height))
               (/ (float preferred-width 1.0f0) (float preferred-height 1.0f0))
               (/ (float (graphics-device-manager-default-back-buffer-width) 1.0f0)
                  (float (graphics-device-manager-default-back-buffer-height) 1.0f0))))
         (width (microsoft.xna.framework.graphics:back-buffer-width pp))
         (height (microsoft.xna.framework.graphics:back-buffer-height pp))
         (ratio (if (plusp height)
                    (/ (float width 1.0f0) (float height 1.0f0))
                    preferred-ratio)))
    (list (- (microsoft.xna.framework.graphics:graphics-profile-value
              (graphics-profile-of information)))
          (if (eq (not (microsoft.xna.framework.graphics:is-full-screen pp))
                  (not (is-full-screen manager)))
              0 1)
          (- (%rank-surface-format
              (microsoft.xna.framework.graphics:back-buffer-format pp)))
          (- (microsoft.xna.framework.graphics:multi-sample-count pp))
          ;; The comparer calls differences below 0.2 a tie, so the key is
          ;; quantised to that step rather than being the raw distance.
          (floor (abs (- ratio preferred-ratio)) 0.2f0))))

(defun %rank-surface-format (format)
  "The comparer's `RankFormat', as far as the selected profile's formats reach.

XNA's private `RankFormat' walks a fixed preference order over the D3D9-era
back-buffer formats. The three the selected profile can actually present are
ranked in that relative order and everything else ranks below them, which is what
the original's default arm does."
  (case format
    (:color 3)
    (:bgr565 2)
    (:bgra5551 1)
    (t 0)))

(defun %rank-device-candidates (manager candidates)
  "Sort CANDIDATES by %DEVICE-CANDIDATE-RANK-KEY, best first. May destroy them."
  (let ((keyed (map 'list (lambda (candidate)
                            (cons (%device-candidate-rank-key manager candidate)
                                  candidate))
                    candidates)))
    (let ((ranked (mapcar #'cdr (stable-sort keyed
                                             (lambda (a b)
                                               (loop for x in a for y in b
                                                     do (cond ((< x y) (return t))
                                                              ((> x y) (return nil)))
                                                     finally (return nil)))
                                             :key #'car))))
      (if (listp candidates)
          ranked
          (map (type-of candidates) #'identity ranked)))))

(defgeneric find-best-device (manager any-suitable-device)
  (:documentation
   "GraphicsDeviceManager.FindBestDevice(Boolean).

    (find-best-device manager nil)   ; => a GRAPHICS-DEVICE-INFORMATION

XNA's `FindBestPlatformDevice' in shape:

  1. build a candidate for every adapter that supports the manager's profile;
  2. if none and `PreferMultiSampling' is set, **clear it and try again** -- a
     side effect on the manager, and one the IL really has: `set_PreferMultiSampling(false)';
  3. if still none, refuse;
  4. `RANK-DEVICES' the candidates -- the virtual one, so a subclass's override
     runs here;
  5. answer the first.

ANY-SUITABLE-DEVICE is XNA's `anySuitableDevice', which there means \"do not
restrict to adapters the game's window is on\". **This binding cannot make that
restriction either way**: it needs `GameWindow.Handle', which is a missing member
because CNA answers the window handle with `CNA_RESULT_NOT_SUPPORTED' by design.
So the argument is accepted, is part of the member's shape, and does not change
the answer -- which is why the member is reported partial rather than complete,
alongside the seam reason this file's comment gives.

Protected and virtual in XNA, so a subclass may override it. Nothing in any
admitted CNA ABI calls it during device creation.")
  (:method ((manager graphics-device-manager) any-suitable-device)
    (declare (ignore any-suitable-device))
    (cna-lisp.internal:check-usable manager "find-best-device")
    (let ((candidates (%device-candidates manager)))
      (when (and (null candidates) (prefer-multi-sampling manager))
        (setf (prefer-multi-sampling manager) nil)
        (setf candidates (%device-candidates manager)))
      (unless candidates
        (error 'cna-invalid-state-error
               :operation "find-best-device" :object-type 'graphics-device-manager
               :format-control
               "no adapter supports the ~s profile. XNA throws
                NoSuitableGraphicsDeviceException here, with the profile in the message."
               :format-arguments (list (graphics-profile manager))))
      (let ((ranked (rank-devices manager candidates)))
        (unless (and ranked (plusp (length ranked)))
          (error 'cna-invalid-state-error
                 :operation "find-best-device" :object-type 'graphics-device-manager
                 :format-control
                 "ranking left no candidate. XNA throws NoSuitableGraphicsDeviceException
                  here too, with a different message, because a RankDevices override may
                  empty the list."))
        (elt ranked 0)))))

(defun %device-candidates (manager)
  "One candidate per adapter that supports the manager's profile, XNA's fields set.

`AddDevices' builds each candidate from the manager's own preferences -- the
profile, the full-screen flag, the multisample preference and the presentation
interval -- and this sets the same ones. The two it also sets are
`PresentationParameters.DeviceWindowHandle' and the window-on-adapter filter, and
both are the missing window handle."
  (let ((profile (graphics-profile manager)))
    (loop for adapter in (microsoft.xna.framework.graphics:graphics-adapter-adapters)
          when (microsoft.xna.framework.graphics:graphics-adapter-is-profile-supported
                adapter profile)
            collect (let* ((info (make-instance 'graphics-device-information
                                                :adapter adapter
                                                :graphics-profile profile))
                           (pp (presentation-parameters-of info)))
                      (setf (microsoft.xna.framework.graphics:multi-sample-count pp)
                            (if (prefer-multi-sampling manager) 16 0)
                            (microsoft.xna.framework.graphics:is-full-screen pp)
                            (is-full-screen manager)
                            (microsoft.xna.framework.graphics:presentation-interval pp)
                            (if (synchronize-with-vertical-retrace manager)
                                :one :immediate))
                      info))))
