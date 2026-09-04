;;;; buffers.lisp --- VertexBuffer, IndexBuffer and their dynamic subclasses.
;;;;
;;;; These are GraphicsResources with real CNA handles, so they are on the
;;;; %NATIVE-GRAPHICS-RESOURCE branch and get the whole ownership machinery:
;;;; owner thread, generation, parent/child registration and deterministic
;;;; destruction, children destroyed before the game.
;;;;
;;;; Three things about the mapping are worth stating.
;;;;
;;;; **A VertexDeclaration is copied into the buffer, so the handle is
;;;; transient.** CNA's create route takes a CNA_VertexDeclarationHandle and its
;;;; header says the declaration is *copied* into the buffer. CNA-Lisp's
;;;; VERTEX-DECLARATION is a managed-only GraphicsResource with no handle, so the
;;;; constructor builds a native declaration from the elements, hands it over and
;;;; destroys it immediately. Nothing native outlives the call, and the buffer's
;;;; own VertexDeclaration property answers the Lisp object it was given -- which
;;;; is what XNA's answers.
;;;;
;;;; **All transfer goes through the raw routes.** CNA has a typed path keyed on
;;;; its seven built-in vertex identities, and using it would mean the four
;;;; standard vertex types went one way and everything else another. The raw
;;;; routes take bytes, a count and a stride, and src/graphics/buffer-data.lisp
;;;; packs the bytes from a layout it can prove -- so one path serves the
;;;; standard types, the scalar types and an octet vector a caller packed
;;;; themselves, and an element type with no proven layout is refused rather
;;;; than written.
;;;;
;;;; **IsContentLost is a real read of a value CNA never sets.** CNA_VertexBufferInfo
;;;; documents its is_content_lost field as "currently always false". The
;;;; property reads it rather than returning a literal, so a future CNA that does
;;;; report loss is reported here without a change; and docs/limitations.md
;;;; records that today the answer is always false and ContentLost never fires.

(in-package #:microsoft.xna.framework.graphics)

;;; --- the native vocabulary --------------------------------------------------------

(defparameter %buffer-usage-to-native
  `((:none . ,cna-lisp.internal.ffi::+buffer-usage-none+)
    (:write-only . ,cna-lisp.internal.ffi::+buffer-usage-write-only+)))

(defparameter %index-element-size-to-native
  `((:sixteen-bits . ,cna-lisp.internal.ffi::+index-element-size-sixteen-bits+)
    (:thirty-two-bits . ,cna-lisp.internal.ffi::+index-element-size-thirty-two-bits+)))

(defparameter %set-data-options-to-native
  `((:none . ,cna-lisp.internal.ffi::+set-data-none+)
    (:discard . ,cna-lisp.internal.ffi::+set-data-discard+)
    (:no-overwrite . ,cna-lisp.internal.ffi::+set-data-no-overwrite+)))

(defparameter %primitive-type-to-native
  `((:triangle-list . ,cna-lisp.internal.ffi::+primitive-triangle-list+)
    (:triangle-strip . ,cna-lisp.internal.ffi::+primitive-triangle-strip+)
    (:line-list . ,cna-lisp.internal.ffi::+primitive-line-list+)
    (:line-strip . ,cna-lisp.internal.ffi::+primitive-line-strip+)))

;;; --- the shared half -------------------------------------------------------------

(defclass %buffer (%native-graphics-resource)
  ((buffer-usage :reader buffer-usage
                 :documentation "BufferUsage, as the buffer was created with."))
  (:documentation "What VertexBuffer and IndexBuffer share: a usage and a handle."))

(defun %buffer-device-handle (graphics-device operation)
  "The borrowed device handle a buffer is created against, with its game."
  (values (device-handle-for-child graphics-device operation)
          (cna-lisp.internal:owner-of graphics-device)))

(defun %adopt-buffer (buffer game handle)
  (setf (cna-lisp.internal:handle-of buffer) handle
        (slot-value buffer 'cna-lisp.internal::owner) game
        (slot-value buffer 'cna-lisp.internal::owner-thread)
        (cna-lisp.internal:owner-thread-of game))
  (cna-lisp.internal:register-child game buffer)
  buffer)

;;; --- VertexBuffer ----------------------------------------------------------------

(defclass vertex-buffer (%buffer)
  ((vertex-declaration :reader vertex-declaration
                       :documentation "The declaration this buffer was created with.")
   (vertex-count :reader vertex-count))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.VertexBuffer.

    (make-instance 'vertex-buffer :graphics-device device
                                  :vertex-declaration declaration
                                  :vertex-count 3
                                  :buffer-usage :none)

XNA has two constructors, one taking a VertexDeclaration and one taking a
`Type' whose vertex declaration is looked up through IVertexType. Common Lisp has
no `typeof', so the second is expressed by passing a vertex *type name* as
:VERTEX-TYPE, which is resolved through the same VERTEX-DECLARATION-OF
projection IVertexType became."))

(defclass dynamic-vertex-buffer (vertex-buffer)
  ()
  (:documentation
   "Microsoft.Xna.Framework.Graphics.DynamicVertexBuffer.

Adds the SetDataOptions overloads, IsContentLost and the ContentLost event. See
docs/limitations.md for what CNA currently reports for content loss."))

(defun %declaration-for (vertex-declaration vertex-type operation)
  "The declaration a buffer constructor was given, whichever way it was given."
  (cond ((and vertex-declaration vertex-type)
         (error 'microsoft.xna.framework:cna-usage-error
                :operation operation
                :format-control
                "give either :VERTEX-DECLARATION or :VERTEX-TYPE, not both: they are ~
                 XNA's two constructors and the second finds the first."))
        (vertex-declaration
         (check-type vertex-declaration vertex-declaration)
         vertex-declaration)
        (vertex-type
         (let ((prototype (%vertex-prototype vertex-type operation)))
           (vertex-declaration-of prototype)))
        (t
         (error 'microsoft.xna.framework:cna-usage-error
                :operation operation
                :format-control
                "a vertex buffer needs a layout: give :VERTEX-DECLARATION, or ~
                 :VERTEX-TYPE naming one of the standard vertex types."))))

(defun %vertex-prototype (vertex-type operation)
  "A zero-valued instance of VERTEX-TYPE, for the layout generic functions.

XNA's `Type' argument is resolved through IVertexType; this resolves a Lisp class
name through the same projection. A type with no VERTEX-DECLARATION-OF method is
refused by name."
  (let ((zero3 (microsoft.xna.framework:make-vector3 0.0f0 0.0f0 0.0f0))
        (zero2 (microsoft.xna.framework:make-vector2 0.0f0 0.0f0))
        (white (microsoft.xna.framework:white)))
    (case vertex-type
      (vertex-position-color (make-vertex-position-color zero3 white))
      (vertex-position-texture (make-vertex-position-texture zero3 zero2))
      (vertex-position-color-texture
       (make-vertex-position-color-texture zero3 white zero2))
      (vertex-position-normal-texture
       (make-vertex-position-normal-texture zero3 zero3 zero2))
      (t (error 'microsoft.xna.framework:cna-usage-error
                :operation operation
                :format-control
                "~s is not a vertex type this binding knows a declaration for. ~
                 XNA resolves the Type argument through IVertexType; the projected ~
                 types are VERTEX-POSITION-COLOR, VERTEX-POSITION-TEXTURE, ~
                 VERTEX-POSITION-COLOR-TEXTURE and VERTEX-POSITION-NORMAL-TEXTURE. ~
                 For any other layout, pass :VERTEX-DECLARATION."
                :format-arguments (list vertex-type))))))

(defun %native-declaration (declaration operation)
  "A CNA vertex-declaration handle for DECLARATION. The caller destroys it.

Transient by design: CNA copies the declaration into the buffer, and CNA-Lisp's
VertexDeclaration has no handle of its own to keep."
  (let* ((elements (%declaration-elements declaration))
         (count (length elements)))
    (cffi:with-foreign-object (buffer '(:struct cna-lisp.internal.ffi::cna-vertex-element)
                                      (max 1 count))
      (loop for element in elements
            for index from 0
            for pointer = (cffi:mem-aptr
                           buffer '(:struct cna-lisp.internal.ffi::cna-vertex-element) index)
            do (macrolet ((slot (name)
                            `(cffi:foreign-slot-value
                              pointer '(:struct cna-lisp.internal.ffi::cna-vertex-element)
                              ',name)))
                 (setf (slot cna-lisp.internal.ffi::offset)
                       (vertex-element-offset element)
                       (slot cna-lisp.internal.ffi::format)
                       (%native-of %vertex-element-format-to-native
                                   (vertex-element-vertex-element-format element)
                                   "vertex-element-format")
                       (slot cna-lisp.internal.ffi::usage)
                       (%native-of %vertex-element-usage-to-native
                                   (vertex-element-vertex-element-usage element)
                                   "vertex-element-usage")
                       (slot cna-lisp.internal.ffi::usage-index)
                       (vertex-element-usage-index element))))
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%vertex-declaration-create-with-stride
          (vertex-stride declaration) buffer count out)
         operation)
        (cffi:mem-ref out :uint64)))))

(defmacro %with-native-declaration ((variable declaration operation) &body body)
  "Hold a transient native VertexDeclaration for the dynamic extent of BODY.

The release is **checked**, not ignored. It used to be wrapped in IGNORE-ERRORS,
which did not merely swallow a Lisp condition -- it never looked at the CNA result
code at all, so a declaration CNA refused to take back was a handle nobody would
ever hear about. That is the same defect the Effect view handles had, one size
smaller: a handle meant to be short-lived is still a handle CNA is owed.

WITH-TRANSIENT-NATIVE has the ordering: a failure in BODY keeps its own condition
and the release goes quiet, because the original failure is what matters; a BODY
that succeeded makes a failing release the news, because nothing else will report
it."
  `(let ((,variable (%native-declaration ,declaration ,operation)))
     (cna-lisp.internal:with-transient-native
         ((cna-lisp.internal.ffi::%vertex-declaration-destroy ,variable)
          ,operation :object-type 'vertex-declaration)
       ,@body)))

(defmethod initialize-instance :after ((buffer vertex-buffer)
                                       &key graphics-device vertex-declaration
                                            vertex-type vertex-count
                                            (buffer-usage :none))
  (let ((operation "make-instance vertex-buffer"))
    (unless graphics-device
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control "a vertex buffer needs a :GRAPHICS-DEVICE."))
    (let ((declaration (%declaration-for vertex-declaration vertex-type operation)))
      (check-type vertex-count (integer 0))
      (check-type buffer-usage buffer-usage)
      (multiple-value-bind (device-handle game)
          (%buffer-device-handle graphics-device operation)
        (%with-native-declaration (native declaration operation)
          (cffi:with-foreign-object
              (info '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-create-info))
            (cffi:foreign-funcall
             "memset" :pointer info :int 0
             :size cna-lisp.internal.ffi::+sizeof-cna-vertex-buffer-create-info+ :void)
            (macrolet ((slot (name)
                         `(cffi:foreign-slot-value
                           info
                           '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-create-info)
                           ',name)))
              (setf (slot cna-lisp.internal.ffi::struct-size)
                    cna-lisp.internal.ffi::+sizeof-cna-vertex-buffer-create-info+
                    (slot cna-lisp.internal.ffi::struct-version) 1
                    (slot cna-lisp.internal.ffi::vertex-declaration) native
                    (slot cna-lisp.internal.ffi::vertex-count) vertex-count
                    (slot cna-lisp.internal.ffi::buffer-usage)
                    (%native-of %buffer-usage-to-native buffer-usage "buffer-usage")
                    (slot cna-lisp.internal.ffi::dynamic)
                    (cna-lisp.internal.ffi:cna-bool-of
                     (typep buffer 'dynamic-vertex-buffer))))
            (cffi:with-foreign-object (out :uint64)
              (cna-lisp.internal:check-result
               (cna-lisp.internal.ffi::%vertex-buffer-create device-handle info out)
               operation :object-type (type-of buffer))
              (%adopt-buffer buffer game (cffi:mem-ref out :uint64)))))
        (setf (slot-value buffer 'vertex-declaration) declaration
              (slot-value buffer 'vertex-count) vertex-count
              (slot-value buffer 'buffer-usage) buffer-usage
              (%resource-device buffer) graphics-device)))))

(defmethod cna-lisp.internal:destroy-native ((buffer vertex-buffer))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%vertex-buffer-destroy (cna-lisp.internal:handle-of buffer))
   "dispose" :object-type (type-of buffer)))

;;; --- IndexBuffer -----------------------------------------------------------------

(defclass index-buffer (%buffer)
  ((index-element-size :reader index-element-size)
   (index-count :reader index-count))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.IndexBuffer.

    (make-instance 'index-buffer :graphics-device device
                                 :index-element-size :sixteen-bits
                                 :index-count 3
                                 :buffer-usage :none)

XNA's second constructor takes a `Type' -- `typeof(short)' or `typeof(int)' --
which is the same choice spelled differently; :INDEX-TYPE takes the Lisp type
specifier `(unsigned-byte 16)' or `(unsigned-byte 32)' for callers who would
rather say it that way."))

(defclass dynamic-index-buffer (index-buffer)
  ()
  (:documentation "Microsoft.Xna.Framework.Graphics.DynamicIndexBuffer."))

(defun %index-element-size-for (index-element-size index-type operation)
  (cond ((and index-element-size index-type)
         (error 'microsoft.xna.framework:cna-usage-error
                :operation operation
                :format-control
                "give either :INDEX-ELEMENT-SIZE or :INDEX-TYPE, not both."))
        (index-element-size
         (check-type index-element-size index-element-size)
         index-element-size)
        (index-type
         (cond ((subtypep index-type '(unsigned-byte 16)) :sixteen-bits)
               ((subtypep index-type '(unsigned-byte 32)) :thirty-two-bits)
               (t (error 'microsoft.xna.framework:cna-usage-error
                         :operation operation
                         :format-control
                         "~s is not an index element type; XNA takes typeof(short) ~
                          or typeof(int), which are (UNSIGNED-BYTE 16) and ~
                          (UNSIGNED-BYTE 32) here."
                         :format-arguments (list index-type)))))
        (t (error 'microsoft.xna.framework:cna-usage-error
                  :operation operation
                  :format-control
                  "an index buffer needs :INDEX-ELEMENT-SIZE or :INDEX-TYPE."))))

(defmethod initialize-instance :after ((buffer index-buffer)
                                       &key graphics-device index-element-size
                                            index-type index-count
                                            (buffer-usage :none))
  (let ((operation "make-instance index-buffer"))
    (unless graphics-device
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control "an index buffer needs a :GRAPHICS-DEVICE."))
    (let ((size (%index-element-size-for index-element-size index-type operation)))
      (check-type index-count (integer 0))
      (check-type buffer-usage buffer-usage)
      (multiple-value-bind (device-handle game)
          (%buffer-device-handle graphics-device operation)
        (cffi:with-foreign-object
            (info '(:struct cna-lisp.internal.ffi::cna-index-buffer-create-info))
          (cffi:foreign-funcall
           "memset" :pointer info :int 0
           :size cna-lisp.internal.ffi::+sizeof-cna-index-buffer-create-info+ :void)
          (macrolet ((slot (name)
                       `(cffi:foreign-slot-value
                         info
                         '(:struct cna-lisp.internal.ffi::cna-index-buffer-create-info)
                         ',name)))
            (setf (slot cna-lisp.internal.ffi::struct-size)
                  cna-lisp.internal.ffi::+sizeof-cna-index-buffer-create-info+
                  (slot cna-lisp.internal.ffi::struct-version) 1
                  (slot cna-lisp.internal.ffi::index-count) index-count
                  (slot cna-lisp.internal.ffi::index-element-size)
                  (%native-of %index-element-size-to-native size "index-element-size")
                  (slot cna-lisp.internal.ffi::buffer-usage)
                  (%native-of %buffer-usage-to-native buffer-usage "buffer-usage")
                  (slot cna-lisp.internal.ffi::dynamic)
                  (cna-lisp.internal.ffi:cna-bool-of
                   (typep buffer 'dynamic-index-buffer))))
          (cffi:with-foreign-object (out :uint64)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%index-buffer-create device-handle info out)
             operation :object-type (type-of buffer))
            (%adopt-buffer buffer game (cffi:mem-ref out :uint64))))
        (setf (slot-value buffer 'index-element-size) size
              (slot-value buffer 'index-count) index-count
              (slot-value buffer 'buffer-usage) buffer-usage
              (%resource-device buffer) graphics-device)))))

(defmethod cna-lisp.internal:destroy-native ((buffer index-buffer))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%index-buffer-destroy (cna-lisp.internal:handle-of buffer))
   "dispose" :object-type (type-of buffer)))

;;; --- SetData and GetData ----------------------------------------------------------
;;;
;;; XNA's overloads, and the keyword shapes that express them:
;;;
;;;   SetData(T[])                                        -- none
;;;   SetData(T[], int, int)                              :start-index :element-count
;;;   SetData(int, T[], int, int, int)                    + :offset-in-bytes
;;;                                                         + :vertex-stride  (vertex)
;;;   SetData(int, T[], int, int)                         + :offset-in-bytes  (index)
;;;   SetData(T[], int, int, SetDataOptions)              + :options   (dynamic)
;;;   SetData(int, T[], int, int, int, SetDataOptions)    + both       (dynamic)
;;;
;;; :START-INDEX and :ELEMENT-COUNT are one group, because XNA has no overload
;;; carrying one without the other. :OPTIONS is only on the dynamic subclasses,
;;; and giving it to a non-dynamic buffer is refused rather than ignored -- XNA
;;; has no such overload on VertexBuffer, and CNA's own routes say a non-None
;;; option "requires a supported dynamic-buffer overload".

(defun %check-transfer-shape (operation start-index-p element-count-p)
  (when (and (or start-index-p element-count-p)
             (not (and start-index-p element-count-p)))
    (error 'microsoft.xna.framework:cna-usage-error
           :operation operation
           :format-control
           ":START-INDEX and :ELEMENT-COUNT are one group: XNA has no SetData or ~
            GetData overload that carries one without the other.")))

(defun %check-options-shape (buffer options options-p operation dynamic-class)
  (when (and options-p (not (typep buffer dynamic-class)))
    (error 'microsoft.xna.framework:cna-usage-error
           :operation operation
           :format-control
           ":OPTIONS is a ~a overload only. XNA's ~a has no SetData taking ~
            SetDataOptions, and CNA refuses a non-None option on a buffer that is ~
            not dynamic."
           :format-arguments (list (string-downcase (symbol-name dynamic-class))
                                   (string-downcase (type-of buffer)))))
  (when options-p (check-type options set-data-options))
  (if options-p options :none))

;;; SET-DATA and GET-DATA are defined in buffer-data.lisp: two unrelated
;;; closures answer them, and a generic function defined twice is one whose
;;; lambda list depends on load order.

(defmethod set-data ((buffer vertex-buffer) data
                     &key (start-index nil start-index-p)
                          (element-count nil element-count-p)
                          (offset-in-bytes nil offset-p)
                          (vertex-stride nil stride-p)
                          (options nil options-p)
                          (level nil level-p) (source nil source-p))
  (declare (ignore level source))
  ;; SET-DATA and GET-DATA are shared with Texture2D, so CLOS congruence makes
  ;; every method accept every keyword any of them uses. A texture's two are
  ;; refused here by name rather than ignored: silently ignoring one would invent
  ;; a buffer overload XNA has not got.
  (when (or level-p source-p)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "set-data"
           :format-control
           ":LEVEL and :SOURCE are a *texture* transfer's -- a mip level and a texel ~
            rectangle. A buffer has neither."))
  (let ((operation "set-data"))
    (%check-transfer-shape operation start-index-p element-count-p)
    (when (and stride-p (not offset-p))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control
             ":VERTEX-STRIDE belongs to the overload that also takes ~
              :OFFSET-IN-BYTES; XNA has no SetData carrying one without the other."))
    (let ((options (%check-options-shape buffer options options-p operation
                                         'dynamic-vertex-buffer)))
      (cna-lisp.internal:check-usable buffer operation)
      (let ((start (if start-index-p start-index 0))
            (count (if element-count-p element-count (length data))))
        (multiple-value-bind (bytes size)
            (%pack-sequence data start count operation :stride vertex-stride)
          (declare (ignorable size))
          (let ((stride (or vertex-stride (if (plusp count) (/ (length bytes) count) 0))))
            (cffi:with-foreign-object (raw :uint8 (max 1 (length bytes)))
              (dotimes (index (length bytes))
                (setf (cffi:mem-aref raw :uint8 index) (aref bytes index)))
              ;; The *_with_options routes are the dynamic-buffer overloads and
              ;; CNA refuses them on a static buffer even for :NONE -- "A static
              ;; VertexBuffer has no SetDataOptions overload", which is XNA's
              ;; rule too. So the route is chosen by what the buffer is.
              (cna-lisp.internal:check-result
               (let ((handle (cna-lisp.internal:handle-of buffer))
                     (native-options
                       (%native-of %set-data-options-to-native options
                                   "set-data-options")))
                 (if (typep buffer 'dynamic-vertex-buffer)
                     (if offset-p
                         (cna-lisp.internal.ffi::%vertex-buffer-set-data-raw-at-with-options
                          handle offset-in-bytes raw (length bytes) count stride
                          native-options)
                         (cna-lisp.internal.ffi::%vertex-buffer-set-data-raw-with-options
                          handle raw (length bytes) count stride native-options))
                     (if offset-p
                         (cna-lisp.internal.ffi::%vertex-buffer-set-data-raw-at
                          handle offset-in-bytes raw (length bytes) count stride)
                         (cna-lisp.internal.ffi::%vertex-buffer-set-data-raw
                          handle raw (length bytes) count stride))))
               operation :object-type (type-of buffer))))))))
  data)

(defmethod get-data ((buffer vertex-buffer) into
                     &key (start-index nil start-index-p)
                          (element-count nil element-count-p)
                          (offset-in-bytes nil offset-p)
                          (vertex-stride nil stride-p)
                          (level nil level-p) (source nil source-p))
  (declare (ignorable stride-p))
  (declare (ignore level source))
  ;; SET-DATA and GET-DATA are shared with Texture2D, so CLOS congruence makes
  ;; every method accept every keyword any of them uses. A texture's two are
  ;; refused here by name rather than ignored: silently ignoring one would invent
  ;; a buffer overload XNA has not got.
  (when (or level-p source-p)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "get-data"
           :format-control
           ":LEVEL and :SOURCE are a *texture* transfer's -- a mip level and a texel ~
            rectangle. A buffer has neither."))
  (let ((operation "get-data"))
    (%check-transfer-shape operation start-index-p element-count-p)
    (cna-lisp.internal:check-usable buffer operation)
    (multiple-value-bind (sample size) (%sequence-layout into operation)
      (let* ((start (if start-index-p start-index 0))
             (count (if element-count-p element-count (length into)))
             (stride (or vertex-stride size)))
        (unless (and (<= 0 start) (<= 0 count) (<= (+ start count) (length into)))
          (error 'microsoft.xna.framework:cna-argument-out-of-range-error
                 :operation operation :parameter-name "element-count"
                 :format-control "~d element(s) from index ~d is outside a sequence of ~d."
                 :format-arguments (list count start (length into))))
        (cffi:with-foreign-object (raw :uint8 (max 1 (* stride count)))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%vertex-buffer-get-data-raw
            (cna-lisp.internal:handle-of buffer)
            (if offset-p offset-in-bytes 0) raw (* stride count) count stride)
           operation :object-type (type-of buffer))
          (%unpack-into into start count raw stride sample)))))
  into)

(defun %index-transfer (pointer element-size options start-index element-count)
  (cffi:foreign-funcall "memset" :pointer pointer :int 0
                        :size cna-lisp.internal.ffi::+sizeof-cna-index-buffer-transfer+
                        :void)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-index-buffer-transfer)
                 ',name)))
    (setf (slot cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-index-buffer-transfer+
          (slot cna-lisp.internal.ffi::struct-version) 1
          (slot cna-lisp.internal.ffi::index-element-size)
          (%native-of %index-element-size-to-native element-size "index-element-size")
          (slot cna-lisp.internal.ffi::options)
          (%native-of %set-data-options-to-native options "set-data-options")
          (slot cna-lisp.internal.ffi::start-index) start-index
          (slot cna-lisp.internal.ffi::element-count) element-count))
  pointer)

(defun %index-element-width (buffer)
  (ecase (index-element-size buffer) (:sixteen-bits 2) (:thirty-two-bits 4)))

(defun %check-index-width (buffer data operation)
  "The array's own element width must be the buffer's index width.

CNA's transfer names the width of the elements it is given, and a mismatch would
be a silent reinterpretation of the caller's numbers. An unspecialised vector
says nothing about its width, so it is taken as the buffer's."
  (let ((declared (%declared-integer-width data))
        (expected (%index-element-width buffer)))
    (when (and declared (/= declared expected))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control
             "this buffer stores ~a indices (~d bytes) and the array holds ~d-byte ~
              elements. Reinterpreting one as the other would change every index."
             :format-arguments (list (index-element-size buffer) expected declared)))
    expected))

(defmethod set-data ((buffer index-buffer) data
                     &key (start-index nil start-index-p)
                          (element-count nil element-count-p)
                          (offset-in-bytes nil offset-p)
                          (vertex-stride nil stride-p)
                          (options nil options-p)
                          (level nil level-p) (source nil source-p))
  (declare (ignore level source) (ignorable vertex-stride))
  ;; SET-DATA and GET-DATA are shared with Texture2D, so CLOS congruence makes
  ;; every method accept every keyword any of them uses. A texture's two are
  ;; refused here by name rather than ignored: silently ignoring one would invent
  ;; a buffer overload XNA has not got.
  (when (or level-p source-p)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "set-data"
           :format-control
           ":LEVEL and :SOURCE are a *texture* transfer's -- a mip level and a texel ~
            rectangle. A buffer has neither."))

  (when stride-p
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "set-data"
           :format-control
           ":VERTEX-STRIDE is a vertex-buffer parameter; an index buffer's element ~
            width is its IndexElementSize."))
  (let ((operation "set-data"))
    (%check-transfer-shape operation start-index-p element-count-p)
    (let ((options (%check-options-shape buffer options options-p operation
                                         'dynamic-index-buffer)))
      (cna-lisp.internal:check-usable buffer operation)
      (let* ((width (%check-index-width buffer data operation))
             (start (if start-index-p start-index 0))
             (count (if element-count-p element-count (length data))))
        (unless (and (<= 0 start) (<= 0 count) (<= (+ start count) (length data)))
          (error 'microsoft.xna.framework:cna-argument-out-of-range-error
                 :operation operation :parameter-name "element-count"
                 :format-control "~d index/indices from ~d is outside a sequence of ~d."
                 :format-arguments (list count start (length data))))
        (cffi:with-foreign-object (raw :uint8 (max 1 (* width count)))
          (dotimes (index count)
            (let ((value (elt data (+ start index))))
              (check-type value (integer 0))
              (if (= width 2)
                  (setf (cffi:mem-aref raw :uint16 index) value)
                  (setf (cffi:mem-aref raw :uint32 index) value))))
          (cffi:with-foreign-object
              (transfer '(:struct cna-lisp.internal.ffi::cna-index-buffer-transfer))
            ;; The transfer's start-index is into the *native* array this just
            ;; packed, which begins at the caller's start-index; the windowing was
            ;; done above so that a Lisp sequence of any kind can be the source.
            (%index-transfer transfer (index-element-size buffer) options 0 count)
            (cna-lisp.internal:check-result
             (if offset-p
                 (cna-lisp.internal.ffi::%index-buffer-set-data-at
                  (cna-lisp.internal:handle-of buffer) offset-in-bytes transfer
                  raw count)
                 (cna-lisp.internal.ffi::%index-buffer-set-data
                  (cna-lisp.internal:handle-of buffer) transfer raw count))
             operation :object-type (type-of buffer)))))))
  data)

(defmethod get-data ((buffer index-buffer) into
                     &key (start-index nil start-index-p)
                          (element-count nil element-count-p)
                          (offset-in-bytes nil offset-p)
                          (vertex-stride nil stride-p)
                          (level nil level-p) (source nil source-p))
  (declare (ignore level source) (ignorable vertex-stride offset-in-bytes))
  ;; SET-DATA and GET-DATA are shared with Texture2D, so CLOS congruence makes
  ;; every method accept every keyword any of them uses. A texture's two are
  ;; refused here by name rather than ignored: silently ignoring one would invent
  ;; a buffer overload XNA has not got.
  (when (or level-p source-p)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "get-data"
           :format-control
           ":LEVEL and :SOURCE are a *texture* transfer's -- a mip level and a texel ~
            rectangle. A buffer has neither."))

  (when (or stride-p offset-p)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "get-data"
           :format-control
           "IndexBuffer.GetData has no offset-in-bytes or stride overload in this ~
            binding: CNA's index read route takes a transfer window and no byte ~
            offset."))
  (let ((operation "get-data"))
    (%check-transfer-shape operation start-index-p element-count-p)
    (cna-lisp.internal:check-usable buffer operation)
    (let* ((width (%check-index-width buffer into operation))
           (start (if start-index-p start-index 0))
           (count (if element-count-p element-count (length into))))
      (unless (and (<= 0 start) (<= 0 count) (<= (+ start count) (length into)))
        (error 'microsoft.xna.framework:cna-argument-out-of-range-error
               :operation operation :parameter-name "element-count"
               :format-control "~d index/indices from ~d is outside a sequence of ~d."
               :format-arguments (list count start (length into))))
      (cffi:with-foreign-object (raw :uint8 (max 1 (* width count)))
        (cffi:with-foreign-object
            (transfer '(:struct cna-lisp.internal.ffi::cna-index-buffer-transfer))
          (%index-transfer transfer (index-element-size buffer) :none 0 count)
          (cffi:with-foreign-object (written :uint64)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%index-buffer-get-data
              (cna-lisp.internal:handle-of buffer) transfer raw count written)
             operation :object-type (type-of buffer))))
        (dotimes (index count)
          (setf (elt into (+ start index))
                (if (= width 2)
                    (cffi:mem-aref raw :uint16 index)
                    (cffi:mem-aref raw :uint32 index)))))))
  into)

;;; --- the dynamic half -------------------------------------------------------------
;;;
;;; IsContentLost reads CNA's own field. CNA documents it as "currently always
;;; false", so the answer is always NIL today and ContentLost never fires -- that
;;; is a runtime capability CNA does not have yet, recorded in
;;; docs/limitations.md, and not a value this binding invents.

(defgeneric is-content-lost (buffer)
  (:documentation
   "DynamicVertexBuffer.IsContentLost and DynamicIndexBuffer.IsContentLost.

Reads the buffer's own state from CNA. CNA's header documents the field as
currently always false, so this answers NIL today for every buffer; it is a read
of the runtime rather than a literal, so a CNA that starts reporting loss is
reported here without a change here."))

(defmethod is-content-lost ((buffer dynamic-vertex-buffer))
  (cna-lisp.internal:check-usable buffer "is-content-lost")
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-vertex-buffer-info+
                          :void)
    (setf (cffi:foreign-slot-value
           info '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-info)
           'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-vertex-buffer-info+
          (cffi:foreign-slot-value
           info '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-info)
           'cna-lisp.internal.ffi::struct-version)
          1)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%vertex-buffer-get-info
      (cna-lisp.internal:handle-of buffer) info)
     "is-content-lost" :object-type (type-of buffer))
    (cna-lisp.internal.ffi:cna-true-p
     (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-info)
                              'cna-lisp.internal.ffi::is-content-lost))))

(defmethod is-content-lost ((buffer dynamic-index-buffer))
  (cna-lisp.internal:check-usable buffer "is-content-lost")
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-index-buffer-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-index-buffer-info+
                          :void)
    (setf (cffi:foreign-slot-value
           info '(:struct cna-lisp.internal.ffi::cna-index-buffer-info)
           'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-index-buffer-info+
          (cffi:foreign-slot-value
           info '(:struct cna-lisp.internal.ffi::cna-index-buffer-info)
           'cna-lisp.internal.ffi::struct-version)
          1)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%index-buffer-get-info
      (cna-lisp.internal:handle-of buffer) info)
     "is-content-lost" :object-type (type-of buffer))
    (cna-lisp.internal.ffi:cna-true-p
     (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-index-buffer-info)
                              'cna-lisp.internal.ffi::is-content-lost))))

;;; --- the ContentLost event -----------------------------------------------------
;;;
;;; CNA has real subscription routes for it, and they are used: the event is
;;; wired the same way every other CLR event in this binding is, through the same
;;; registry and the same one top-level callback. What CNA does *not* have is a
;;; reason to raise it -- its buffer info documents is_content_lost as "currently
;;; always false" -- so a handler subscribed here is never called today. The
;;; subscription is real, the release is real, and the absence of a raise is
;;; CNA's, recorded in docs/limitations.md rather than papered over with a
;;; handler list nothing would ever have called.

(defparameter microsoft.xna.framework::*buffer-event-values*
  '((:content-lost . 0))
  "A buffer raises one event, and CNA gives it a route of its own rather than an
identity in a table.")

(defmethod microsoft.xna.framework::%event-table ((object %buffer))
  microsoft.xna.framework::*buffer-event-values*)

(defmethod microsoft.xna.framework::%subscribe-natively
    ((object vertex-buffer) value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%vertex-buffer-subscribe-content-lost
   (cna-lisp.internal:handle-of object)
   (cna-lisp.internal.ffi:content-lost-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod microsoft.xna.framework::%unsubscribe-natively
    ((object vertex-buffer) registration)
  (cna-lisp.internal.ffi::%vertex-buffer-unsubscribe-content-lost registration))

(defmethod microsoft.xna.framework::%subscribe-natively
    ((object index-buffer) value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%index-buffer-subscribe-content-lost
   (cna-lisp.internal:handle-of object)
   (cna-lisp.internal.ffi:content-lost-callback-pointer)
   (cffi:make-pointer token) registration))

(defmethod microsoft.xna.framework::%unsubscribe-natively
    ((object index-buffer) registration)
  (cna-lisp.internal.ffi::%index-buffer-unsubscribe-content-lost registration))

(microsoft.xna.framework::%define-event-pair
 add-content-lost-handler remove-content-lost-handler
 "DynamicVertexBuffer.ContentLost and DynamicIndexBuffer.ContentLost.

HANDLER is called with the buffer. **CNA does not raise this today**: its buffer
info reports content loss as always false, so a subscription is accepted, held
and released correctly and is never invoked. See docs/limitations.md.")

(microsoft.xna.framework::%define-event-methods
 dynamic-vertex-buffer :content-lost add-content-lost-handler remove-content-lost-handler)
(microsoft.xna.framework::%define-event-methods
 dynamic-index-buffer :content-lost add-content-lost-handler remove-content-lost-handler)

(setf cna-lisp.internal.ffi:*buffer-content-lost-dispatcher*
      #'microsoft.xna.framework::%dispatch-game-event)
