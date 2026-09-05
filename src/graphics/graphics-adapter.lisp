;;;; graphics-adapter.lisp --- GraphicsAdapter and DisplayModeCollection.
;;;;
;;;; **Every adapter route takes a callback-scoped graphics-device handle**, and
;;;; that is the one thing to know before reading anything else here. XNA's
;;;; `GraphicsAdapter.Adapters` and `.DefaultAdapter` are *static* and answer
;;;; before a device exists -- that is how an XNA program chooses the adapter it
;;;; then creates a device on. CNA has no adapter query that does not go through a
;;;; device, so here the same members need a live game **and** a lifecycle
;;;; callback to be inside.
;;;;
;;;; That is a real divergence and it is recorded as one: the two static members
;;;; are reported **partial**, and the reason names the scope rather than
;;;; describing the members as complete and leaving a caller to discover it. The
;;;; instance members are complete, because reading an adapter's description
;;;; inside a draw is exactly as available here as it is there.
;;;;
;;;; An adapter holds **no handle**. CNA identifies one by a zero-based index into
;;;; its own enumeration, so this class holds that index and the game to ask
;;;; through, and every reader resolves the borrowed device handle per call --
;;;; which is also what makes the scope rule enforce itself rather than needing a
;;;; check of its own.

(in-package #:microsoft.xna.framework.graphics)

(defclass graphics-adapter ()
  ((%index :initarg :index :reader %adapter-index)
   (%game :initarg :game :reader %adapter-game))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.GraphicsAdapter: one graphics adapter.

Reached through `GRAPHICS-ADAPTER-ADAPTERS', `GRAPHICS-ADAPTER-DEFAULT-ADAPTER'
or `ADAPTER' on a device -- all of which are legal only inside a game lifecycle
method, because every CNA adapter route takes the borrowed device handle.

Holds no native resource and is not disposed: CNA names an adapter by index, and
this is that index plus the game to ask through."))

(defun %adapter-device-handle (adapter operation)
  "The borrowed device handle to ask ADAPTER's questions through."
  (let ((game (%adapter-game adapter)))
    (unless game
      (error 'microsoft.xna.framework:cna-invalid-object-error
             :operation operation :object-type 'graphics-adapter
             :format-control "this adapter has no game to ask through."))
    (%resolve-device-handle (microsoft.xna.framework:graphics-device game) operation)))

(defun %active-game-for-adapters (operation)
  "The process's one active game, which every adapter query needs."
  (or (cna-lisp.internal:active-game)
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation operation :object-type 'graphics-adapter
             :format-control
             "there is no live game, and every CNA adapter route takes a graphics-device ~
              handle. XNA's GraphicsAdapter.Adapters is static and answers before a device ~
              exists -- that is how an XNA program picks the adapter it then creates a ~
              device on -- and this binding cannot, which is why that member is reported ~
              partial rather than complete. docs/limitations.md.")))

;;; --- the info structure, read once per question ------------------------------

(defmacro %with-adapter-info ((info adapter operation) &body body)
  "Fill a CNA_GraphicsAdapterInfo for ADAPTER and run BODY with it."
  `(cffi:with-foreign-object
       (,info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info))
     (cffi:foreign-funcall
      "memset" :pointer ,info :int 0
      :size cna-lisp.internal.ffi::+sizeof-cna-graphics-adapter-info+ :void)
     (setf (cffi:foreign-slot-value
            ,info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
            'cna-lisp.internal.ffi::struct-size)
           cna-lisp.internal.ffi::+sizeof-cna-graphics-adapter-info+
           (cffi:foreign-slot-value
            ,info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
            'cna-lisp.internal.ffi::struct-version)
           1)
     (cna-lisp.internal:check-result
      (cna-lisp.internal.ffi::%graphics-adapter-get-info
       (%adapter-device-handle ,adapter ,operation) (%adapter-index ,adapter) ,info)
      ,operation :object-type 'graphics-adapter)
     ,@body))

(macrolet ((info-property (name slot documentation &key boolean)
             `(progn
                (defgeneric ,name (graphics-adapter) (:documentation ,documentation))
                (defmethod ,name ((adapter graphics-adapter))
                  (%with-adapter-info (info adapter ,(string-downcase (symbol-name name)))
                    ,(if boolean
                         `(cna-lisp.internal.ffi:cna-true-p
                           (cffi:foreign-slot-value
                            info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
                            ',slot))
                         `(cffi:foreign-slot-value
                           info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
                           ',slot)))))))
  (info-property graphics-adapter-is-default-adapter
                 cna-lisp.internal.ffi::is-default-adapter
                 "GraphicsAdapter.IsDefaultAdapter." :boolean t)
  (info-property graphics-adapter-is-wide-screen
                 cna-lisp.internal.ffi::is-wide-screen
                 "GraphicsAdapter.IsWideScreen: whether the current mode is wider than 4:3."
                 :boolean t)
  (info-property graphics-adapter-vendor-id cna-lisp.internal.ffi::vendor-id
                 "GraphicsAdapter.VendorId: the PCI vendor identifier, or zero when CNA
could not learn it -- which its own struct documents as the meaning of zero.")
  (info-property graphics-adapter-device-id cna-lisp.internal.ffi::device-id
                 "GraphicsAdapter.DeviceId: the PCI device identifier, or zero when
unavailable.")
  (info-property graphics-adapter-revision cna-lisp.internal.ffi::revision
                 "GraphicsAdapter.Revision.

**Partial, and CNA says why in its own struct**: \"Adapter revision; current CNA
returns zero\". So this answers zero on every adapter rather than the adapter's
revision. The zero is CNA's answer passed through rather than a number invented
here, and the member is reported partial for exactly that.")
  (info-property graphics-adapter-sub-system-id cna-lisp.internal.ffi::subsystem-id
                 "GraphicsAdapter.SubSystemId. Partial for the reason
GRAPHICS-ADAPTER-REVISION is: CNA's struct documents it as \"current CNA returns
zero\"."))

;;; --- the two static preference flags -----------------------------------------
;;;
;;; XNA's `UseNullDevice` and `UseReferenceDevice` are static properties; CNA
;;; carries both per adapter, in the info struct, and sets them with one route
;;; that takes both. So the pair is read from whichever adapter is asked and
;;; written together, which is what `cna_graphics_adapter_set_device_preferences`
;;; offers.

(defgeneric graphics-adapter-use-null-device (graphics-adapter)
  (:documentation "GraphicsAdapter.UseNullDevice, read from this adapter."))

(defgeneric graphics-adapter-use-reference-device (graphics-adapter)
  (:documentation "GraphicsAdapter.UseReferenceDevice, read from this adapter."))

(defmethod graphics-adapter-use-null-device ((adapter graphics-adapter))
  (%with-adapter-info (info adapter "graphics-adapter-use-null-device")
    (cna-lisp.internal.ffi:cna-true-p
     (cffi:foreign-slot-value
      info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
      'cna-lisp.internal.ffi::use-null-device))))

(defmethod graphics-adapter-use-reference-device ((adapter graphics-adapter))
  (%with-adapter-info (info adapter "graphics-adapter-use-reference-device")
    (cna-lisp.internal.ffi:cna-true-p
     (cffi:foreign-slot-value
      info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
      'cna-lisp.internal.ffi::use-reference-device))))

(defun %set-device-preferences (adapter null-device reference-device operation)
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%graphics-adapter-set-device-preferences
    (%adapter-device-handle adapter operation) (%adapter-index adapter)
    (cna-lisp.internal.ffi:cna-bool-of null-device)
    (cna-lisp.internal.ffi:cna-bool-of reference-device))
   operation :object-type 'graphics-adapter))

(defgeneric (setf graphics-adapter-use-null-device) (value graphics-adapter)
  (:documentation
   "GraphicsAdapter.UseNullDevice's setter.

CNA sets the pair together, so this reads the sibling back first and writes both
-- which is the only way to change one of them through a route that takes both."))

(defgeneric (setf graphics-adapter-use-reference-device) (value graphics-adapter)
  (:documentation "GraphicsAdapter.UseReferenceDevice's setter. See the sibling."))

(defmethod (setf graphics-adapter-use-null-device) (value (adapter graphics-adapter))
  (%set-device-preferences adapter value (graphics-adapter-use-reference-device adapter)
                           "(setf graphics-adapter-use-null-device)")
  value)

(defmethod (setf graphics-adapter-use-reference-device) (value (adapter graphics-adapter))
  (%set-device-preferences adapter (graphics-adapter-use-null-device adapter) value
                           "(setf graphics-adapter-use-reference-device)")
  value)

;;; --- the two strings ----------------------------------------------------------

(defgeneric graphics-adapter-description (graphics-adapter)
  (:documentation "GraphicsAdapter.Description."))

(defgeneric graphics-adapter-device-name (graphics-adapter)
  (:documentation "GraphicsAdapter.DeviceName."))

(defmethod graphics-adapter-description ((adapter graphics-adapter))
  (let ((handle (%adapter-device-handle adapter "graphics-adapter-description"))
        (index (%adapter-index adapter)))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (%with-adapter-info (info adapter "graphics-adapter-description")
         (setf (cffi:mem-ref out :uint64)
               (cffi:foreign-slot-value
                info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
                'cna-lisp.internal.ffi::description-byte-length))
         cna-lisp.internal:+result-success+))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%graphics-adapter-copy-description
        handle index buffer capacity out))
     "graphics-adapter-description")))

(defmethod graphics-adapter-device-name ((adapter graphics-adapter))
  (let ((handle (%adapter-device-handle adapter "graphics-adapter-device-name"))
        (index (%adapter-index adapter)))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (%with-adapter-info (info adapter "graphics-adapter-device-name")
         (setf (cffi:mem-ref out :uint64)
               (cffi:foreign-slot-value
                info '(:struct cna-lisp.internal.ffi::cna-graphics-adapter-info)
                'cna-lisp.internal.ffi::device-name-byte-length))
         cna-lisp.internal:+result-success+))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%graphics-adapter-copy-device-name
        handle index buffer capacity out))
     "graphics-adapter-device-name")))

;;; --- display modes -------------------------------------------------------------

(defgeneric graphics-adapter-current-display-mode (graphics-adapter)
  (:documentation "GraphicsAdapter.CurrentDisplayMode."))

(defmethod graphics-adapter-current-display-mode ((adapter graphics-adapter))
  (let ((operation "graphics-adapter-current-display-mode"))
    (cffi:with-foreign-object (mode '(:struct cna-lisp.internal.ffi::cna-display-mode))
      (cffi:foreign-funcall "memset" :pointer mode :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-display-mode+ :void)
      (setf (cffi:foreign-slot-value
             mode '(:struct cna-lisp.internal.ffi::cna-display-mode)
             'cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-display-mode+
            (cffi:foreign-slot-value
             mode '(:struct cna-lisp.internal.ffi::cna-display-mode)
             'cna-lisp.internal.ffi::struct-version)
            1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-adapter-get-current-display-mode
        (%adapter-device-handle adapter operation) (%adapter-index adapter) mode)
       operation :object-type 'graphics-adapter)
      (%read-display-mode mode))))

(defclass display-mode-collection ()
  ((%modes :initarg :modes :reader %display-modes))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.DisplayModeCollection: an adapter's modes.

Enumerated with `DISPLAY-MODE-COLLECTION-MODES-VECTOR' and filtered by surface
format with `DISPLAY-MODE-COLLECTION-ITEM', which are XNA's two members. A
snapshot: CNA copies the modes out when the collection is asked for, and the
collection does not go back for more."))

(defun %copy-display-modes (adapter filter-format operation)
  "Every mode of ADAPTER, optionally only those of FILTER-FORMAT."
  (let ((handle (%adapter-device-handle adapter operation))
        (index (%adapter-index adapter))
        (filter (if filter-format 1 0))
        (format (if filter-format (surface-format-value filter-format) 0)))
    (cffi:with-foreign-object (out :uint64)
      (setf (cffi:mem-ref out :uint64) 0)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-adapter-get-display-mode-count
        handle index filter format out)
       operation :object-type 'graphics-adapter)
      (let ((count (cffi:mem-ref out :uint64)))
        (if (zerop count)
            (vector)
            (cffi:with-foreign-object
                (modes '(:struct cna-lisp.internal.ffi::cna-display-mode) count)
              (dotimes (i count)
                (let ((one (cffi:mem-aptr
                            modes '(:struct cna-lisp.internal.ffi::cna-display-mode) i)))
                  (cffi:foreign-funcall
                   "memset" :pointer one :int 0
                   :size cna-lisp.internal.ffi::+sizeof-cna-display-mode+ :void)
                  (setf (cffi:foreign-slot-value
                         one '(:struct cna-lisp.internal.ffi::cna-display-mode)
                         'cna-lisp.internal.ffi::struct-size)
                        cna-lisp.internal.ffi::+sizeof-cna-display-mode+
                        (cffi:foreign-slot-value
                         one '(:struct cna-lisp.internal.ffi::cna-display-mode)
                         'cna-lisp.internal.ffi::struct-version)
                        1)))
              (cna-lisp.internal:check-result
               (cna-lisp.internal.ffi::%graphics-adapter-copy-display-modes
                handle index filter format modes count out)
               operation :object-type 'graphics-adapter)
              (let* ((written (cffi:mem-ref out :uint64))
                     (result (make-array written)))
                (dotimes (i written result)
                  (setf (aref result i)
                        (%read-display-mode
                         (cffi:mem-aptr
                          modes '(:struct cna-lisp.internal.ffi::cna-display-mode) i)))))))))))

(defgeneric graphics-adapter-supported-display-modes (graphics-adapter)
  (:documentation "GraphicsAdapter.SupportedDisplayModes."))

(defmethod graphics-adapter-supported-display-modes ((adapter graphics-adapter))
  (make-instance 'display-mode-collection
                 :modes (%copy-display-modes
                         adapter nil "graphics-adapter-supported-display-modes")))

(defun display-mode-collection-modes-vector (collection)
  "DisplayModeCollection.GetEnumerator(): a fresh vector of the modes.

Common Lisp has no enumerator object; this answers a vector, as
TOUCH-COLLECTION-LOCATIONS-VECTOR and CurveKeyCollection do."
  (copy-seq (%display-modes collection)))

(defun display-mode-collection-item (collection surface-format)
  "DisplayModeCollection's indexer: the modes of one surface format.

XNA's indexer is `this[SurfaceFormat]' answering an `IEnumerable<DisplayMode>',
which is a *filter* rather than a lookup -- so this answers a vector of the modes
whose format matches, and an empty one when none do."
  (check-type surface-format surface-format)
  (coerce (remove surface-format (%display-modes collection)
                  :key #'display-mode-format :test-not #'eq)
          'vector))

(defmethod print-object ((collection display-mode-collection) stream)
  (print-unreadable-object (collection stream :type t)
    (format stream "~d mode~:p" (length (%display-modes collection)))))

;;; --- the three negotiations ----------------------------------------------------

(defgeneric graphics-adapter-is-profile-supported (graphics-adapter graphics-profile)
  (:documentation
   "GraphicsAdapter.IsProfileSupported(GraphicsProfile)."))

(defmethod graphics-adapter-is-profile-supported ((adapter graphics-adapter) profile)
  (check-type profile graphics-profile)
  (let ((operation "graphics-adapter-is-profile-supported"))
    (cffi:with-foreign-object (out :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-adapter-is-profile-supported
        (%adapter-device-handle adapter operation) (%adapter-index adapter)
        (graphics-profile-value profile) out)
       operation :object-type 'graphics-adapter)
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))))

(defun %query-format (adapter route profile format depth-format multi-sample-count operation)
  "One of the two format negotiations, as four values."
  (check-type profile graphics-profile)
  (check-type format surface-format)
  (check-type depth-format depth-format)
  (check-type multi-sample-count (integer 0))
  (cffi:with-foreign-object
      (selection '(:struct cna-lisp.internal.ffi::cna-graphics-format-selection))
    (cffi:foreign-funcall
     "memset" :pointer selection :int 0
     :size cna-lisp.internal.ffi::+sizeof-cna-graphics-format-selection+ :void)
    (setf (cffi:foreign-slot-value
           selection '(:struct cna-lisp.internal.ffi::cna-graphics-format-selection)
           'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-graphics-format-selection+
          (cffi:foreign-slot-value
           selection '(:struct cna-lisp.internal.ffi::cna-graphics-format-selection)
           'cna-lisp.internal.ffi::struct-version)
          1)
    (cna-lisp.internal:check-result
     (funcall route (%adapter-device-handle adapter operation) (%adapter-index adapter)
              (graphics-profile-value profile) (surface-format-value format)
              (depth-format-value depth-format) multi-sample-count selection)
     operation :object-type 'graphics-adapter)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   selection '(:struct cna-lisp.internal.ffi::cna-graphics-format-selection)
                   ',name)))
      (values (cna-lisp.internal.ffi:cna-true-p (slot cna-lisp.internal.ffi::exact-match))
              (surface-format-from-value (slot cna-lisp.internal.ffi::format))
              (depth-format-from-value (slot cna-lisp.internal.ffi::depth-format))
              (slot cna-lisp.internal.ffi::multi-sample-count)))))

(defgeneric graphics-adapter-query-back-buffer-format
    (graphics-adapter graphics-profile format depth-format multi-sample-count)
  (:documentation
   "GraphicsAdapter.QueryBackBufferFormat: **four values**, the boolean first.

XNA's signature is a `bool' and three `out' parameters, and this projection is the
one TOUCH-COLLECTION-FIND-BY-ID already uses for that shape: the return value
first, then what the out parameters would have received --

    (values exact-match-p selected-format selected-depth-format
            selected-multi-sample-count)"))

(defgeneric graphics-adapter-query-render-target-format
    (graphics-adapter graphics-profile format depth-format multi-sample-count)
  (:documentation
   "GraphicsAdapter.QueryRenderTargetFormat. Four values; see the back buffer's."))

(defmethod graphics-adapter-query-back-buffer-format
    ((adapter graphics-adapter) profile format depth-format multi-sample-count)
  (%query-format adapter #'cna-lisp.internal.ffi::%graphics-adapter-query-backbuffer-format
                 profile format depth-format multi-sample-count
                 "graphics-adapter-query-back-buffer-format"))

(defmethod graphics-adapter-query-render-target-format
    ((adapter graphics-adapter) profile format depth-format multi-sample-count)
  (%query-format adapter #'cna-lisp.internal.ffi::%graphics-adapter-query-render-target-format
                 profile format depth-format multi-sample-count
                 "graphics-adapter-query-render-target-format"))

;;; --- reaching an adapter --------------------------------------------------------

(defun graphics-adapter-adapters ()
  "GraphicsAdapter.Adapters: every adapter CNA enumerates, as a list.

**Partial, and the scope is why.** XNA's is a static property that answers before
any device exists -- which is how an XNA program picks the adapter it then creates
a device on. Every CNA adapter route takes a callback-scoped graphics-device
handle, so this needs a live game *and* a lifecycle callback to be inside, and by
then the device has been created. `ReadOnlyCollection<GraphicsAdapter>' has no
counterpart here either; a list is what Common Lisp reads a sequence you must not
mutate as."
  (let* ((operation "graphics-adapter-adapters")
         (game (%active-game-for-adapters operation))
         (handle (%resolve-device-handle
                  (microsoft.xna.framework:graphics-device game) operation)))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-adapter-get-count handle out)
       operation :object-type 'graphics-adapter)
      (loop for index from 0 below (cffi:mem-ref out :uint64)
            collect (make-instance 'graphics-adapter :index index :game game)))))

(defun graphics-adapter-default-adapter ()
  "GraphicsAdapter.DefaultAdapter: the adapter CNA reports as the default one.

Partial for the reason GRAPHICS-ADAPTER-ADAPTERS is: XNA's is static and answers
without a device. Found by asking each adapter rather than assuming index zero,
because `is_default_adapter' is a field CNA fills and index zero is a guess."
  (or (find-if #'graphics-adapter-is-default-adapter (graphics-adapter-adapters))
      (error 'microsoft.xna.framework:cna-invalid-state-error
             :operation "graphics-adapter-default-adapter"
             :object-type 'graphics-adapter
             :format-control
             "CNA enumerated adapters and marked none of them the default one.")))

(defgeneric adapter (graphics-device)
  (:documentation
   "GraphicsDevice.Adapter: the adapter this device was created on.

Through `cna_graphics_device_get_adapter_index', which answers an index into the
same enumeration `GRAPHICS-ADAPTER-ADAPTERS' walks."))

(defmethod adapter ((device graphics-device))
  (let ((handle (%resolve-device-handle device "adapter")))
    (cffi:with-foreign-object (out :uint32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-adapter-index handle out)
       "adapter" :object-type 'graphics-device)
      (make-instance 'graphics-adapter
                     :index (cffi:mem-ref out :uint32)
                     :game (cna-lisp.internal:owner-of device)))))

(defmethod print-object ((adapter graphics-adapter) stream)
  (print-unreadable-object (adapter stream :type t)
    (format stream "~d" (%adapter-index adapter))))

;;; --- GraphicsDevice.Reset -------------------------------------------------------
;;;
;;; Here rather than in graphics-device.lisp because the three-argument overload
;;; takes a GRAPHICS-ADAPTER, and that class is declared above.

(defgeneric reset-graphics-device (graphics-device
                                   &key presentation-parameters adapter)
  (:documentation
   "GraphicsDevice.Reset: all three overloads, the keywords selecting between them.

    (reset-graphics-device device)
    (reset-graphics-device device :presentation-parameters p)
    (reset-graphics-device device :presentation-parameters p :adapter a)

Named for its type rather than as a bare `RESET', for the reason CLONE-EFFECT is
not `CLONE': a very general verb does not go into a package consumers use
unqualified.

`Reset()' goes to `cna_graphics_device_reset'; the other two go to
`cna_graphics_device_reset_with_parameters', whose adapter argument is a
**pointer** -- null keeps the current adapter, which is exactly what XNA's
two-argument overload means by not taking one. An :ADAPTER without
:PRESENTATION-PARAMETERS is refused, because XNA has no such overload.

A renderer that cannot reset answers `CNA_RESULT_NOT_SUPPORTED', which reaches
the caller as a CNA-NOT-SUPPORTED-ERROR rather than as a silent no-op."))

(defmethod reset-graphics-device ((device graphics-device)
                                  &key (presentation-parameters nil parameters-p)
                                       (adapter nil adapter-p))
  (when (and adapter-p (not parameters-p))
    (error 'microsoft.xna.framework:cna-argument-error
           :operation "reset-graphics-device" :parameter-name "adapter"
           :format-control
           "XNA has no Reset overload taking an adapter without presentation ~
            parameters. Pass :PRESENTATION-PARAMETERS with :ADAPTER."))
  (let ((handle (%resolve-device-handle device "reset-graphics-device")))
    (if (not parameters-p)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%graphics-device-reset handle)
         "reset-graphics-device" :object-type 'graphics-device)
        (progn
          (check-type presentation-parameters presentation-parameters)
          (when adapter-p (check-type adapter graphics-adapter))
          (cffi:with-foreign-objects
              ((native '(:struct cna-lisp.internal.ffi::cna-presentation-parameters))
               (index :uint32))
            (%write-presentation-parameters native presentation-parameters)
            (when adapter-p
              (setf (cffi:mem-ref index :uint32) (%adapter-index adapter)))
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%graphics-device-reset-with-parameters
              handle native (if adapter-p index (cffi:null-pointer)))
             "reset-graphics-device" :object-type 'graphics-device)))))
  (values))
