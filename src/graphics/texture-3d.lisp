;;;; texture-3d.lisp --- Texture3D: a volume of texels, and the guards XNA keeps.
;;;;
;;;; A `Texture3D` is the one texture family whose transfers name a **box** --
;;;; seven coordinates rather than a nullable rectangle, because XNA's three
;;;; overloads take exactly `level, left, top, right, bottom, front, back'. The
;;;; shape otherwise follows `Texture2D`'s: the same three transfer overloads,
;;;; the same rule about proven layouts, the same ownership.
;;;;
;;;; **This type was ruled out of the selection for months, and the reason was a
;;;; measurement error.** `cna_texture3d_create' answered CNA_RESULT_NOT_SUPPORTED
;;;; on the HEADLESS and SOFTWARE renderers, on all three admitted ABIs, and that
;;;; was recorded as "CNA cannot make a Texture3D". What it says is that *those
;;;; two renderers* have no volume storage, which is what the route's own
;;;; documentation says it means. CNA's EasyGL family has it on every non-ES2 GL
;;;; profile, and the whole surface below was measured there, on Mesa llvmpipe
;;;; under Xvfb, on each admitted ABI. `docs/texture3d-audit.md' is the audit and
;;;; `tools/qualification/texture3d-matrix.sh' takes the measurement again.
;;;;
;;;; **Two divergences, both CNA's and both named rather than worked around.**
;;;;
;;;; * `cna_texture3d_set_data' takes `const CNA_Color*' and
;;;;   `cna_texture3d_get_data' a `CNA_Color*', with no texel-kind argument -- so
;;;;   a volume is transferable only as `Color', exactly as a `TextureCube' face
;;;;   is, where a `Texture2D' takes five element types because its route names
;;;;   the kind. The six transfer members are **partial** for that reason.
;;;; * CNA creates a `Texture3D` on the **Reach** profile and at extents past
;;;;   XNA's `MaxVolumeExtent'. XNA does neither, so those guards are applied
;;;;   here: see %VOLUME-PROFILE-CAPABILITIES.

(in-package #:microsoft.xna.framework.graphics)

(defclass texture-3d (texture)
  ((%width :initarg :width :initform 0 :reader %volume-width)
   (%height :initarg :height :initform 0 :reader %volume-height)
   (%depth :initarg :depth :initform 0 :reader depth)
   (%level-count :initarg :level-count :initform 1 :reader level-count)
   (%format :initarg :format :initform :color :reader format-of))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.Texture3D: a volume of texels.

    (make-instance 'texture-3d :graphics-device device
                               :width 4 :height 3 :depth 2)

A TEXTURE, as XNA's is. WIDTH, HEIGHT and DEPTH are its extents, LEVEL-COUNT the
number of mip levels the renderer allocated and FORMAT-OF the surface format it
granted; all five are read back from CNA at construction rather than assumed from
what was asked for.

Transfers name a mip **box** -- :LEVEL, :LEFT, :TOP, :RIGHT, :BOTTOM, :FRONT and
:BACK -- because XNA's box overload does. DATA is a sequence of COLORs and only
of COLORs; see the file header.

**Needs a renderer with volume storage.** The two renderers CNA-Lisp's ordinary
qualification uses have none, and constructing one against them refuses with
CNA-NOT-SUPPORTED-ERROR, which is a truthful answer rather than a defect.

Owned by whatever owns the GraphicsDevice it was made from -- the game for a
game's device, the device itself for a caller-owned one -- and disposed with
MICROSOFT.XNA.FRAMEWORK:DISPOSE, before it."))

;;; XNA's ProfileCapabilities, for the three fields a Texture3D constructor
;;; reads. Extracted from the class constructor of ProfileCapabilities in the
;;; hash-pinned `Microsoft.Xna.Framework.Graphics.dll'
;;; (SHA-256 560080fc39021c611ca9d076dcebed312faf6d7d1413c2dc523683ea635e9f55),
;;; never from CNA -- and the difference is not theoretical:
;;;
;;;   * CNA creates a Texture3D on the **Reach** profile. XNA cannot: Reach's
;;;     MaxVolumeExtent is 0 and `Texture3D::CreateTexture' throws
;;;     NotSupportedException before it reaches the device.
;;;   * CNA creates a 257-wide volume on HiDef. XNA's MaxVolumeExtent is 256 and
;;;     it throws NotSupportedException (ProfileTooBig).
;;;
;;; Both measured on all three admitted ABIs; `docs/texture3d-audit.md' has the
;;; table. So these guards live here or nowhere.
(defparameter %volume-profile-capabilities
  '((:reach :max-volume-extent 0
            :max-texture-aspect-ratio 2048
            :valid-volume-formats ())
    (:hi-def :max-volume-extent 256
             :max-texture-aspect-ratio 2048
             :valid-volume-formats (:color :bgr565 :bgra5551 :bgra4444
                                    :rgba1010102 :rg32 :rgba64 :alpha8
                                    :single :vector2 :vector4 :half-single
                                    :half-vector2 :half-vector4 :hdr-blendable)))
  "The pinned XNA ProfileCapabilities fields Texture3D's constructor reads.")

(defun %volume-capability (profile key)
  (getf (cdr (assoc profile %volume-profile-capabilities)) key))

(defun %texture-3d-info (handle operation)
  "Read a volume's granted extents, level count and format back out of CNA."
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-texture-3d-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-texture-3d-info+ :void)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   info '(:struct cna-lisp.internal.ffi::cna-texture-3d-info) ',name)))
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-texture-3d-info+
            (slot cna-lisp.internal.ffi::struct-version) 1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%texture-3d-get-info handle info)
       operation :object-type 'texture-3d)
      (values (slot cna-lisp.internal.ffi::width)
              (slot cna-lisp.internal.ffi::height)
              (slot cna-lisp.internal.ffi::depth)
              (slot cna-lisp.internal.ffi::level-count)
              (surface-format-from-value (slot cna-lisp.internal.ffi::format))))))

(defun %check-volume-construction (graphics-device width height depth format operation)
  "XNA's Texture3D constructor guards, in XNA's order and with XNA's names.

Read from `Texture3D::CreateTexture' in the pinned Graphics assembly, which
refuses in exactly this sequence and stops at the first refusal:

    graphicsDevice null   ArgumentNullException(\"graphicsDevice\")
    width  <= 0           ArgumentOutOfRangeException(\"width\")
    height <= 0           ArgumentOutOfRangeException(\"height\")
    depth  <= 0           ArgumentOutOfRangeException(\"depth\")
    MaxVolumeExtent == 0  NotSupportedException  -- the whole type, on Reach
    format not valid      NotSupportedException
    any extent too big    NotSupportedException
    aspect ratio too big  NotSupportedException

The order is the observable part: a call that is wrong in two ways has to say
which one XNA would have named first."
  (unless graphics-device
    (error 'microsoft.xna.framework:cna-argument-error
           :operation operation :parameter-name "graphicsDevice"
           :format-control "a graphics device is required to create a resource."))
  (loop for (value name) in (list (list width "width") (list height "height")
                                  (list depth "depth"))
        do (unless (and (integerp value) (plusp value))
             (error 'microsoft.xna.framework:cna-argument-out-of-range-error
                    :operation operation :parameter-name name
                    :format-control "~a must be greater than zero, and is ~s."
                    :format-arguments (list name value))))
  (check-type format surface-format)
  (let* ((profile (graphics-profile graphics-device))
         (extent (%volume-capability profile :max-volume-extent))
         (formats (%volume-capability profile :valid-volume-formats))
         (ratio (%volume-capability profile :max-texture-aspect-ratio)))
    (when (zerop extent)
      (error 'microsoft.xna.framework:cna-not-supported-error
             :operation operation :object-type 'texture-3d
             :format-control
             "the ~s profile does not support Texture3D at all: XNA's ~
              ProfileCapabilities gives it MaxVolumeExtent 0, so its constructor ~
              refuses before touching the device. Create the device with :HI-DEF. ~
              CNA does create one here, which is why this guard is the binding's."
             :format-arguments (list profile)))
    (unless (member format formats)
      (error 'microsoft.xna.framework:cna-not-supported-error
             :operation operation :object-type 'texture-3d
             :format-control
             "~s is not a valid volume format for the ~s profile. XNA's ~
              ValidVolumeFormats for it are ~{~s~^, ~}."
             :format-arguments (list format profile formats)))
    (when (or (> width extent) (> height extent) (> depth extent))
      (error 'microsoft.xna.framework:cna-not-supported-error
             :operation operation :object-type 'texture-3d
             :format-control
             "~dx~dx~d is larger than the ~s profile's MaxVolumeExtent of ~d. ~
              CNA does create one this size, which is why this guard is the ~
              binding's."
             :format-arguments (list width height depth profile extent)))
    ;; XNA's own arithmetic, kept literally: the larger extent divided by the
    ;; smaller, rounded up, against MaxTextureAspectRatio.
    (let* ((largest (max width height depth))
           (smallest (min width height depth))
           (aspect (floor (+ largest smallest -1) smallest)))
      (when (> aspect ratio)
        (error 'microsoft.xna.framework:cna-not-supported-error
               :operation operation :object-type 'texture-3d
               :format-control
               "~dx~dx~d has an aspect ratio of ~d, past the ~s profile's ~
                MaxTextureAspectRatio of ~d."
               :format-arguments (list width height depth aspect profile ratio))))))

(defmethod initialize-instance :after ((texture texture-3d)
                                       &key graphics-device width height depth
                                            (mip-map nil) (format :color))
  "Texture3D(GraphicsDevice, Int32, Int32, Int32, Boolean, SurfaceFormat).

**A NIL device reaches XNA's null check rather than skipping construction**, and
that is the one place this differs in shape from TEXTURE-2D and TEXTURE-CUBE.
Those two guard on `graphics-device' being given, because a content-loaded
texture is adopted through the same constructor with a handle and no device.
`Texture3D' has no such path -- no content reader here makes one -- so a missing
device is what XNA says it is: ArgumentNullException(\"graphicsDevice\")."
  (when (zerop (cna-lisp.internal:handle-of texture))
    (let ((operation "make-instance 'texture-3d"))
      (%check-volume-construction graphics-device width height depth format operation)
      (let ((device-handle (device-handle-for-child graphics-device operation)))
        (cffi:with-foreign-object
            (info '(:struct cna-lisp.internal.ffi::cna-texture-3d-create-info))
          (cffi:foreign-funcall
           "memset" :pointer info :int 0
           :size cna-lisp.internal.ffi::+sizeof-cna-texture-3d-create-info+ :void)
          (macrolet ((slot (name)
                       `(cffi:foreign-slot-value
                         info '(:struct cna-lisp.internal.ffi::cna-texture-3d-create-info)
                         ',name)))
            (setf (slot cna-lisp.internal.ffi::struct-size)
                  cna-lisp.internal.ffi::+sizeof-cna-texture-3d-create-info+
                  (slot cna-lisp.internal.ffi::struct-version) 1
                  (slot cna-lisp.internal.ffi::width) width
                  (slot cna-lisp.internal.ffi::height) height
                  (slot cna-lisp.internal.ffi::depth) depth
                  (slot cna-lisp.internal.ffi::mip-map)
                  (cna-lisp.internal.ffi:cna-bool-of mip-map)
                  (slot cna-lisp.internal.ffi::format) (surface-format-value format)))
          (cffi:with-foreign-object (out :uint64)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%texture-3d-create device-handle info out)
             operation :object-type 'texture-3d)
            (let ((handle (cffi:mem-ref out :uint64)))
              (cna-lisp.internal:record-construction-undo
               texture (lambda () (cna-lisp.internal.ffi::%texture-3d-destroy handle)))
              (multiple-value-bind (granted-width granted-height granted-depth
                                    levels granted-format)
                  (%texture-3d-info handle operation)
                (setf (cna-lisp.internal:handle-of texture) handle
                      (slot-value texture '%width) granted-width
                      (slot-value texture '%height) granted-height
                      (slot-value texture '%depth) granted-depth
                      (slot-value texture '%level-count) levels
                      (slot-value texture '%format) granted-format)
                (adopt-native-resource texture graphics-device)
                (cna-lisp.internal:record-construction-undo
                 texture (lambda () (cna-lisp.internal:invalidate texture)))))))))))

;;; WIDTH, HEIGHT and DEPTH are **bare managed-field reads in XNA** --
;;; `get_Width' is `ldarg.0; ldfld _width; ret' with no CheckDisposed anywhere --
;;; and so are LEVEL-COUNT and FORMAT-OF on `Texture'. So they answer after
;;; disposal here too, and the disposed guard belongs on the transfers, which is
;;; where XNA puts it: `CopyData' calls `Helpers::CheckDisposed' first.
;;;
;;; WIDTH and HEIGHT are TEXTURE-2D's generic functions, so a volume answers them
;;; through methods of its own rather than a second name. DEPTH, LEVEL-COUNT and
;;; FORMAT-OF are slot readers on the class.

(defmethod width ((texture texture-3d))
  (%volume-width texture))

(defmethod height ((texture texture-3d))
  (%volume-height texture))

(defmethod cna-lisp.internal:destroy-native ((texture texture-3d))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%texture-3d-destroy (cna-lisp.internal:handle-of texture))
   "dispose" :object-type 'texture-3d))

(defmacro %with-volume-transfer ((pointer level left top right bottom front back
                                  element-count)
                                 &body body)
  "Fill a CNA_Texture3DTransfer for the dynamic extent of BODY."
  `(cffi:with-foreign-object (,pointer '(:struct cna-lisp.internal.ffi::cna-texture-3d-transfer))
     (cffi:foreign-funcall "memset" :pointer ,pointer :int 0
                           :size cna-lisp.internal.ffi::+sizeof-cna-texture-3d-transfer+
                           :void)
     (macrolet ((slot (name)
                  `(cffi:foreign-slot-value
                    ,',pointer '(:struct cna-lisp.internal.ffi::cna-texture-3d-transfer)
                    ',name)))
       (setf (slot cna-lisp.internal.ffi::struct-size)
             cna-lisp.internal.ffi::+sizeof-cna-texture-3d-transfer+
             (slot cna-lisp.internal.ffi::struct-version) 1
             (slot cna-lisp.internal.ffi::level) ,level
             (slot cna-lisp.internal.ffi::left) ,left
             (slot cna-lisp.internal.ffi::top) ,top
             (slot cna-lisp.internal.ffi::right) ,right
             (slot cna-lisp.internal.ffi::bottom) ,bottom
             (slot cna-lisp.internal.ffi::front) ,front
             (slot cna-lisp.internal.ffi::back) ,back
             ;; The caller's window is applied here, not in CNA: the buffer this
             ;; binding hands over always starts at its own element zero.
             (slot cna-lisp.internal.ffi::start-index) 0
             (slot cna-lisp.internal.ffi::element-count) ,element-count))
     ,@body))

(defun %check-volume-transfer-shape (operation box start-index element-count
                                     buffer-keywords plane-keywords)
  "Refuse every keyword combination XNA's three Texture3D overloads do not have.

    (data)                          SetData(T[])
    (data :start-index i :element-count n)
                                    SetData(T[], Int32, Int32)
    (data :level l :left a :top b :right c :bottom d :front e :back f
          :start-index i :element-count n)
                                    SetData(Int32 x7, T[], Int32, Int32)

The seven box coordinates are **all or none**: XNA has no overload naming some of
them, because they are seven separate parameters of one overload rather than a
nullable region. `Texture2D`'s `:SOURCE' is that nullable region and is refused
here by name, the way a buffer's keywords are."
  (flet ((refuse (control &rest arguments)
           (error 'microsoft.xna.framework:cna-usage-error
                  :operation operation :format-control control
                  :format-arguments arguments)))
    (when buffer-keywords
      (refuse "~{:~a~^, ~} belong~:[~;s~] to a *buffer* transfer, not a texture's. ~
               A byte offset, a vertex stride and SetDataOptions are VertexBuffer's ~
               and IndexBuffer's."
              (mapcar #'symbol-name buffer-keywords) (= 1 (length buffer-keywords))))
    (when plane-keywords
      (refuse "~{:~a~^, ~} belong~:[~;s~] to a *Texture2D* transfer. XNA's ~
               Texture3D.SetData names a mip box with :LEFT, :TOP, :RIGHT, ~
               :BOTTOM, :FRONT and :BACK; it has no nullable Rectangle."
              (mapcar #'symbol-name plane-keywords) (= 1 (length plane-keywords))))
    (when (and (or start-index element-count) (not (and start-index element-count)))
      (refuse ":START-INDEX and :ELEMENT-COUNT are one pair: XNA has no transfer ~
               overload that takes either without the other."))
    (let ((given (remove nil box :key #'cdr)))
      (when (and given (< (length given) 7))
        (refuse "a Texture3D box is seven coordinates and ~d ~:[were~;was~] given ~
                 (~{:~a~^, ~}). XNA's overload takes level, left, top, right, ~
                 bottom, front and back together; it has no partial box."
                (length given) (= 1 (length given))
                (mapcar (lambda (pair) (symbol-name (car pair))) given)))
      (when (and given (not (and start-index element-count)))
        (refuse "a Texture3D box belongs to the overload that also takes ~
                 :START-INDEX and :ELEMENT-COUNT; XNA has no transfer that names ~
                 a box and no window into the caller's array.")))))

(defun %check-volume-colors (operation sequence start count)
  "Refuse anything but a COLOR sequence, and say why.

`cna_texture3d_set_data' takes `const CNA_Color*' and `cna_texture3d_get_data' a
`CNA_Color*', neither with a texel-kind argument, so a volume is transferable
only as Color -- unlike a Texture2D, whose route names the kind. That is CNA's
limit rather than a decision here, and it is named rather than worked around.

XNA's own rule, from `Texture3D::GetAndValidateSizes<T>' in the pinned assembly,
is broader: `T' is accepted when `sizeof(T)' equals the format's byte size or
divides it exactly, so a Color volume there takes four-, two- and one-byte
elements. Reinterpreting an arbitrary element as a CNA_Color is refused rather
than attempted; `docs/limitations.md' records the divergence."
  (unless (and (<= 0 start) (<= 0 count) (<= (+ start count) (length sequence)))
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation operation :parameter-name "element-count"
           :format-control "~d element(s) from index ~d is outside a sequence of ~d."
           :format-arguments (list count start (length sequence))))
  (loop for index from start below (+ start count)
        for element = (elt sequence index)
        unless (typep element 'microsoft.xna.framework:color)
          do (error 'microsoft.xna.framework:cna-usage-error
                    :operation operation
                    :format-control
                    "a Texture3D transfer takes COLOR elements and this one is ~a. ~
                     XNA's SetData<T> is generic, and CNA's volume routes are not: ~
                     both take CNA_Color with no texel-kind argument, unlike the ~
                     Texture2D route. docs/limitations.md records the divergence."
                    :format-arguments (list (type-of element)))))

(defun %volume-box (texture level left top right bottom front back)
  "The seven coordinates a transfer uses: the caller's, or the whole of level 0.

XNA's two windowless overloads pass `0, 0, 0, _width, _height, 0, _depth' to the
seven-coordinate one -- the whole of level zero, read from the managed fields --
so this answers exactly that when no box was named."
  (if left
      (values level left top right bottom front back)
      (values 0 0 0 (%volume-width texture) (%volume-height texture)
              0 (depth texture))))

(defun %volume-voxel-count (left top right bottom front back)
  (* (max 0 (- right left)) (max 0 (- bottom top)) (max 0 (- back front))))

(defmethod set-data ((texture texture-3d) data
                     &key level start-index element-count
                          (source nil source-p)
                          (offset-in-bytes nil offset-p) (vertex-stride nil stride-p)
                          (options nil options-p)
                          left top right bottom front back)
  (declare (ignore source offset-in-bytes vertex-stride options))
  (%check-volume-transfer-shape
   "set-data" (list (cons 'level level) (cons 'left left) (cons 'top top)
                    (cons 'right right) (cons 'bottom bottom)
                    (cons 'front front) (cons 'back back))
   start-index element-count
   (append (when offset-p '(offset-in-bytes)) (when stride-p '(vertex-stride))
           (when options-p '(options)))
   (when source-p '(source)))
  (cna-lisp.internal:check-usable texture "set-data")
  (let* ((start (or start-index 0))
         (count (or element-count (- (length data) start))))
    (when (zerop count)
      ;; XNA's CopyData refuses a null *or empty* array with
      ;; ArgumentNullException("data"), before it looks at anything else.
      (error 'microsoft.xna.framework:cna-argument-error
             :operation "set-data" :parameter-name "data"
             :format-control
             "a Texture3D transfer of no elements writes nothing, and XNA refuses ~
              an empty array here as it refuses a null one."))
    (%check-volume-colors "set-data" data start count)
    (multiple-value-bind (l0 x0 y0 x1 y1 z0 z1)
        (%volume-box texture (or level 0) left top right bottom front back)
      (cffi:with-foreign-object (buffer '(:struct cna-lisp.internal.ffi::cna-color)
                                        (max 1 count))
        (dotimes (index count)
          (setf (cffi:mem-aref buffer :uint32 index)
                (microsoft.xna.framework:color-packed-value (elt data (+ start index)))))
        (%with-volume-transfer (transfer l0 x0 y0 x1 y1 z0 z1 count)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%texture-3d-set-data
            (cna-lisp.internal:handle-of texture) transfer buffer count)
           "set-data" :object-type 'texture-3d)))))
  (values))

(defmethod get-data ((texture texture-3d) into
                     &key level start-index element-count
                          (source nil source-p)
                          (offset-in-bytes nil offset-p) (vertex-stride nil stride-p)
                          (options nil options-p)
                          left top right bottom front back)
  (declare (ignore source offset-in-bytes vertex-stride options))
  (%check-volume-transfer-shape
   "get-data" (list (cons 'level level) (cons 'left left) (cons 'top top)
                    (cons 'right right) (cons 'bottom bottom)
                    (cons 'front front) (cons 'back back))
   start-index element-count
   (append (when offset-p '(offset-in-bytes)) (when stride-p '(vertex-stride))
           (when options-p '(options)))
   (when source-p '(source)))
  (cna-lisp.internal:check-usable texture "get-data")
  (let* ((start (or start-index 0))
         (count (or element-count (- (length into) start))))
    (when (zerop count)
      (error 'microsoft.xna.framework:cna-argument-error
             :operation "get-data" :parameter-name "data"
             :format-control
             "a Texture3D transfer of no elements reads nothing, and XNA refuses ~
              an empty array here as it refuses a null one."))
    (%check-volume-colors "get-data" into start count)
    (multiple-value-bind (l0 x0 y0 x1 y1 z0 z1)
        (%volume-box texture (or level 0) left top right bottom front back)
      (cffi:with-foreign-object (buffer '(:struct cna-lisp.internal.ffi::cna-color)
                                        (max 1 count))
        (cffi:with-foreign-object (required :uint64)
          (%with-volume-transfer (transfer l0 x0 y0 x1 y1 z0 z1 count)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%texture-3d-get-data
              (cna-lisp.internal:handle-of texture) transfer buffer count required)
             "get-data" :object-type 'texture-3d)))
        ;; Only after the native call succeeded: CNA leaves the destination
        ;; untouched on refusal and so does this.
        (dotimes (index count)
          (setf (elt into (+ start index))
                (microsoft.xna.framework:color-from-packed-value
                 (cffi:mem-aref buffer :uint32 index)))))))
  into)

(defmethod print-object ((texture texture-3d) stream)
  (print-unreadable-object (texture stream :type t)
    (format stream "~dx~dx~d~:[~; disposed~]"
            (%volume-width texture) (%volume-height texture) (depth texture)
            (cna-lisp.internal:disposed-state-of texture))))
