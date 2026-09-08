;;;; texture-2d.lisp --- Microsoft.Xna.Framework.Graphics.Texture2D.
;;;;
;;;; A texture is created against the graphics device, but CNA owns it as a child
;;;; of the *game*: it outlives the callback that created it, and the game refuses
;;;; to be destroyed while it is alive. CNA-Lisp records that ownership so
;;;; disposal order is checked here rather than discovered as a native failure.

(in-package #:microsoft.xna.framework.graphics)

(defclass texture (%native-graphics-resource)
  ()
  (:documentation
   "Microsoft.Xna.Framework.Graphics.Texture: the abstract base of the texture
family. Present so TEXTURE-2D has the superclass the contract gives it; it has no
members of its own in this milestone."))

(defclass texture-2d (texture)
  ((width :initarg :width :initform 0 :reader %texture-width)
   (height :initarg :height :initform 0 :reader %texture-height)
   (level-count :initarg :level-count :initform 1 :reader level-count)
   (format :initarg :format :initform :color :reader format-of))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.Texture2D.

Created from image data through TEXTURE-2D-FROM-PNG-BYTES or
TEXTURE-2D-FROM-PNG-FILE, which project XNA's Texture2D.FromStream over CNA's
decode routes. Disposed with MICROSOFT.XNA.FRAMEWORK:DISPOSE, before the game
that owns it."))

(defgeneric width (texture)
  (:documentation
   "Texture2D.Width, in pixels.

**Refuses on a content-loaded texture**, and that is CNA's limit rather than a
decision here: ABI 0.21.0 has no route that reports a Texture2D's dimensions.
`cna_texture_get_info' answers the level count and the surface format,
`cna_texture2d_get_storage_info' answers which storage is retained, and neither
answers a width. A texture decoded through TEXTURE-2D-FROM-PNG-BYTES knows its
size because this binding read it out of the image header on the way past; a
texture the content manager loaded was never handed to this binding as bytes, so
there is nothing to have read. Answering zero would be a lie that draws
wrong-sized quads; refusing says what is missing."))

(defgeneric height (texture)
  (:documentation "Texture2D.Height, in pixels. See WIDTH for when it refuses."))

(defun %texture-dimension (texture value name)
  (or value
      (error 'microsoft.xna.framework:cna-not-supported-error
             :operation name
             :object-type (type-of texture)
             :format-control
             "this texture's ~a is not known. It was loaded through a ContentManager, and ~
              CNA ABI 0.21.0 has no route that reports a Texture2D's dimensions -- ~
              `cna_texture_get_info' answers the level count and format and nothing else. ~
              A texture decoded from image bytes knows its size because this binding read ~
              it from the image header. docs/limitations.md records it."
             :format-arguments (list name))))

(defmethod width ((texture texture-2d))
  (%texture-dimension texture (%texture-width texture) "width"))

(defmethod height ((texture texture-2d))
  (%texture-dimension texture (%texture-height texture) "height"))

(defun %adopt-texture-2d (device handle record &key width height (class 'texture-2d))
  "Build the CLOS Texture2D over a handle the caller's transaction already owns.

RECORD is that transaction's recorder, and the division of labour is the rule
that keeps one asset load to one ledger:

  **whoever receives a handle from CNA records its destruction.**

This function did not receive HANDLE from CNA -- the decoder or the content
loader did -- so it records only the undo for the *Lisp* state it creates: the
object, and its registration as a child of its owner. Recording the handle here
too is the bug this shape exists to make unsayable, because a handle owned by two
nested ledgers is destroyed twice when the inner one runs first.

DEVICE is the public GRAPHICS-DEVICE the texture belongs to, and which native
object owns it follows from that through ADOPT-NATIVE-RESOURCE. It used to be
the game, which was the same thing while a game's device was the only device.

The undo is INVALIDATE rather than UNREGISTER-CHILD. An abandoned object is not
merely unowned: its handle is about to be destroyed by the step recorded before
it, so anything still holding a reference must find a disposed object rather than
a live-looking one over a dead handle."
  (let* ((owner (native-resource-owner-for-device device))
         (texture (make-instance class
                                 :handle handle
                                 :ownership :owned
                                 :owner owner
                                 :owner-thread (cna-lisp.internal:owner-thread-of owner)
                                 :width width :height height)))
    (%read-texture-storage texture)
    (adopt-native-resource texture device)
    (funcall record (lambda () (cna-lisp.internal:invalidate texture)))
    texture))

(defun %adopt-loaded-texture-2d (device handle record)
  "Wrap a texture a ContentManager created, whose dimensions CNA will not report.

The width and height are NIL rather than zero, so WIDTH and HEIGHT refuse rather
than answering a plausible wrong number. See WIDTH. RECORD is the enclosing
load transaction's recorder; see %ADOPT-TEXTURE-2D for what is recorded where."
  (%adopt-texture-2d device handle record :width nil :height nil))

(defun %texture-storage-dimensions (handle)
  "Read a freshly created texture's dimensions and format back out of CNA."
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-texture-2d-storage-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-texture-2d-storage-info+ :void)
    (setf (cffi:foreign-slot-value
           info '(:struct cna-lisp.internal.ffi::cna-texture-2d-storage-info)
           'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-texture-2d-storage-info+
          (cffi:foreign-slot-value
           info '(:struct cna-lisp.internal.ffi::cna-texture-2d-storage-info)
           'cna-lisp.internal.ffi::struct-version)
          1)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%texture-2d-get-storage-info handle info)
     "texture-2d storage info" :object-type 'texture-2d))
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-texture-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-texture-info+ :void)
    (setf (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-texture-info)
                                   'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-texture-info+
          (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-texture-info)
                                   'cna-lisp.internal.ffi::struct-version)
          1)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%texture-get-info handle info)
     "texture info" :object-type 'texture-2d)
    (values (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-texture-info)
                                     'cna-lisp.internal.ffi::level-count)
            (surface-format-from-value
             (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-texture-info)
                                      'cna-lisp.internal.ffi::format)))))

(defgeneric %read-texture-storage (texture)
  (:documentation
   "Fill TEXTURE's level count and surface format from CNA.

A generic function, and separate from construction, for two reasons. It runs
*after* the handle is acquired, so it is inside the rollback and a failure here
gives the handle back. And it is the step a test can make fail: overriding it on
a subclass is how `tests/native/graphics.lisp' proves the rollback, the same way
an exploding subclass proves Effect's.")
  (:method ((texture texture-2d))
    (multiple-value-bind (levels format)
        (%texture-storage-dimensions (cna-lisp.internal:handle-of texture))
      (setf (slot-value texture 'level-count) levels
            (slot-value texture 'format) format)
      texture)))

(defun %make-texture-2d (device handle width height &key (class 'texture-2d))
  "Wrap a freshly decoded native texture, transactionally.

The handle exists before this is called, so everything here is inside a rollback:
reading the storage metadata is a native call of its own and can fail, and before
this was staged a failure there left CNA holding a texture nobody would ever
destroy -- which surfaces much later as a game that will not shut down.

CLASS exists for the failure-injection test and defaults to TEXTURE-2D; nothing
public passes it."
  (cna-lisp.internal:with-native-rollback (record)
    (funcall record (lambda () (cna-lisp.internal.ffi::%texture-2d-destroy handle)))
    (%adopt-texture-2d device handle record
                       :width width :height height :class class)))

(defun texture-2d-from-png-bytes (graphics-device octets)
  "Decode an encoded image held in memory into a real native Texture2D.

This is CNA-Lisp's projection of Texture2D.FromStream over CNA's encoded-memory
decode route. OCTETS is any (VECTOR (UNSIGNED-BYTE 8)); PNG is what this
milestone qualifies."
  (check-type octets sequence)
  (let* ((bytes (coerce octets '(vector (unsigned-byte 8))))
         (n (length bytes)))
    (when (zerop n)
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "texture-2d-from-png-bytes"
             :format-control "an encoded image cannot be empty."))
    (let ((device-handle (device-handle-for-child graphics-device
                                                  "texture-2d-from-png-bytes")))
      (cffi:with-foreign-object (buffer :uint8 n)
        (dotimes (i n) (setf (cffi:mem-aref buffer :uint8 i) (aref bytes i)))
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%texture-2d-create-from-encoded-memory
            device-handle buffer n (cffi:null-pointer) out)
           "texture-2d-from-png-bytes" :object-type 'texture-2d)
          (let ((handle (cffi:mem-ref out :uint64)))
            (multiple-value-bind (w h) (%decoded-dimensions bytes)
              (%make-texture-2d graphics-device handle w h))))))))

(defun texture-2d-from-png-file (graphics-device path)
  "Decode a PNG file into a real native Texture2D."
  (texture-2d-from-png-bytes
   graphics-device
   (with-open-file (stream path :element-type '(unsigned-byte 8))
     (let ((bytes (make-array (file-length stream) :element-type '(unsigned-byte 8))))
       (read-sequence bytes stream)
       bytes))))

;;; --- Texture2D.FromStream ---------------------------------------------------
;;;
;;; Both overloads, one function, the keywords selecting between them. XNA has
;;; `FromStream(GraphicsDevice, Stream)' and
;;; `FromStream(GraphicsDevice, Stream, Int32, Int32, Boolean)', and read from the
;;; assembly they are the same private constructor with different arguments: the
;;; two-argument one passes the profile's `MaxTextureSize' for both extents and
;;; operation 0, the five-argument one passes the caller's extents and
;;; `zoom ? 3 : 1'. CNA's `CNA_Texture2DDecodeInfo' is exactly the second shape --
;;; a width, a height and a `zoom' flag documented as "true to cover-and-crop;
;;; false to fit while preserving aspect ratio" -- and a null one "preserves source
;;; dimensions", which is the first shape *without* the MaxTextureSize fit.

(defun %decode-info-pointer (info width height zoom)
  "Fill a CNA_Texture2DDecodeInfo at INFO and answer it."
  (cffi:foreign-funcall "memset" :pointer info :int 0
                        :size cna-lisp.internal.ffi::+sizeof-cna-texture-2d-decode-info+
                        :void)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 info '(:struct cna-lisp.internal.ffi::cna-texture-2d-decode-info) ',name)))
    (setf (slot cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-texture-2d-decode-info+
          (slot cna-lisp.internal.ffi::struct-version) 1
          (slot cna-lisp.internal.ffi::width) width
          (slot cna-lisp.internal.ffi::height) height
          (slot cna-lisp.internal.ffi::zoom) (cna-lisp.internal.ffi:cna-bool-of zoom)))
  info)

(defun %decode-encoded-texture (graphics-device octets width height zoom resizing)
  "Decode OCTETS into a native Texture2D, resizing when RESIZING."
  (let ((operation "texture-2d-from-stream")
        (n (length octets)))
    (when (zerop n)
      (error 'microsoft.xna.framework:cna-argument-error
             :operation operation :parameter-name "stream"
             :format-control "the stream held no bytes; there is no image to decode."))
    (let ((device-handle (device-handle-for-child graphics-device operation)))
      (cffi:with-foreign-object (buffer :uint8 n)
        (dotimes (i n) (setf (cffi:mem-aref buffer :uint8 i) (aref octets i)))
        (cffi:with-foreign-object
            (info '(:struct cna-lisp.internal.ffi::cna-texture-2d-decode-info))
          (cffi:with-foreign-object (out :uint64)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%texture-2d-create-from-encoded-memory
              device-handle buffer n
              (if resizing
                  (%decode-info-pointer info width height zoom)
                  (cffi:null-pointer))
              out)
             operation :object-type 'texture-2d)
            (let ((handle (cffi:mem-ref out :uint64)))
              ;; What the finished texture may honestly say about its own extent,
              ;; which is not the same in all three shapes. Without a decode info
              ;; CNA preserves the source dimensions, and the image header says
              ;; what those are. Zooming covers and crops, so the result is
              ;; exactly what was asked for. *Fitting* answers something no larger
              ;; than what was asked for and this binding cannot know what -- ABI
              ;; 0.21.0 reports no texture extent -- so the reader refuses rather
              ;; than answering the request as though it were the result.
              (multiple-value-bind (known-width known-height)
                  (cond ((not resizing) (%decoded-dimensions octets))
                        (zoom (values width height))
                        (t (values nil nil)))
                (%make-texture-2d graphics-device handle known-width known-height)))))))))

(defun texture-2d-from-stream (graphics-device stream
                               &key (width nil width-supplied)
                                    (height nil height-supplied)
                                    (zoom nil zoom-supplied))
  "Texture2D.FromStream: decode an image a Common Lisp binary stream holds.

    (texture-2d-from-stream device stream)
    (texture-2d-from-stream device stream :width 64 :height 64 :zoom t)

The first is `FromStream(GraphicsDevice, Stream)'; the second is
`FromStream(GraphicsDevice, Stream, Int32, Int32, Boolean)'. XNA has no overload
taking some of the three and not the others, so neither does this: all three or
none, and anything between is refused rather than treated as one of the two
shapes that exist. `:ZOOM NIL' is a value and not an absence, exactly as it is a
`false' and not a missing argument there.

STREAM is read to its end and is **not closed**: it is the caller's, as it is in
XNA. See `src/framework/streams.lisp' for what a Common Lisp stream has to be."
  (let ((supplied (count t (list width-supplied height-supplied zoom-supplied))))
    (unless (or (zerop supplied) (= 3 supplied))
      (error 'microsoft.xna.framework:cna-argument-error
             :operation "texture-2d-from-stream"
             :parameter-name (cond ((not width-supplied) "width")
                                   ((not height-supplied) "height")
                                   (t "zoom"))
             :format-control
             "XNA has two FromStream overloads and no overload between them: either none ~
              of :WIDTH, :HEIGHT and :ZOOM, or all three. ~d of the three were given."
             :format-arguments (list supplied)))
    (when (plusp supplied)
      (check-type width (integer 1))
      (check-type height (integer 1)))
    (%decode-encoded-texture graphics-device
                             (microsoft.xna.framework::%read-stream-octets
                              stream "texture-2d-from-stream")
                             width height zoom (plusp supplied))))

;;; --- Texture2D.SaveAsPng and SaveAsJpeg -------------------------------------

(defun %save-texture-as (texture stream width height format operation)
  "Encode TEXTURE at WIDTH by HEIGHT and write the bytes to STREAM.

The count/copy pair, which is how every sized read in this ABI works: ask for the
byte count, allocate exactly that, copy into it. A capacity that is too small
performs no partial write, so a count that moved between the two calls is a
refusal rather than a truncated image."
  (cna-lisp.internal:check-usable texture operation)
  (microsoft.xna.framework::%check-stream-argument stream operation :output)
  (check-type width (integer 1))
  (check-type height (integer 1))
  (let ((handle (cna-lisp.internal:handle-of texture)))
    (cffi:with-foreign-object (out :uint64)
      (setf (cffi:mem-ref out :uint64) 0)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%texture-2d-get-encoded-byte-count
        handle format width height out)
       operation :object-type (type-of texture))
      (let ((count (cffi:mem-ref out :uint64)))
        (when (zerop count)
          (error 'microsoft.xna.framework:cna-internal-error
                 :operation operation :object-type (type-of texture)
                 :format-control "CNA reported an encoded size of zero bytes."))
        (cffi:with-foreign-object (buffer :uint8 count)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%texture-2d-copy-encoded
            handle format width height buffer count out)
           operation :object-type (type-of texture))
          (let* ((written (cffi:mem-ref out :uint64))
                 (octets (make-array written :element-type '(unsigned-byte 8))))
            (dotimes (i written)
              (setf (aref octets i) (cffi:mem-aref buffer :uint8 i)))
            (microsoft.xna.framework::%write-stream-octets stream octets operation))))))
  (values))

(defgeneric save-as-png (texture stream width height)
  (:documentation
   "Texture2D.SaveAsPng(Stream, Int32, Int32): encode this texture as a PNG.

    (with-open-file (out \"shot.png\" :direction :output
                                     :element-type '(unsigned-byte 8))
      (save-as-png texture out 64 64))

WIDTH and HEIGHT are the *encoded* extent, which is what XNA's are: the texture is
resampled to them by CNA. The stream is written and left open, as XNA leaves it."))

(defgeneric save-as-jpeg (texture stream width height)
  (:documentation
   "Texture2D.SaveAsJpeg(Stream, Int32, Int32): encode this texture as a JPEG.

The quality is CNA's configured default, which is the same thing XNA's is: the
member takes no quality argument on either side. See SAVE-AS-PNG."))

(defmethod save-as-png ((texture texture-2d) stream width height)
  (%save-texture-as texture stream width height
                    cna-lisp.internal.ffi::+texture-image-format-png+ "save-as-png"))

(defmethod save-as-jpeg ((texture texture-2d) stream width height)
  (%save-texture-as texture stream width height
                    cna-lisp.internal.ffi::+texture-image-format-jpeg+ "save-as-jpeg"))

(defun %decoded-dimensions (bytes)
  "The pixel dimensions a PNG header declares, or NIL and NIL for anything else.

CNA has no route that reports a texture's extent, so the extent is read from the
image the caller supplied rather than invented. **A payload that is not a PNG
answers NIL**, and WIDTH and HEIGHT then refuse -- which is what reporting what
is actually known, namely nothing, has to mean. It used to answer zero and zero, which is a
number, and a number is what a caller draws a quad with. CNA decodes JPEG and DDS
as well as PNG, so this is reachable: a JPEG handed to TEXTURE-2D-FROM-STREAM
decodes into a real texture whose size this binding has not been told."
  (if (and (>= (length bytes) 24)
           (equalp (subseq bytes 0 8) #(137 80 78 71 13 10 26 10)))
      (flet ((be32 (offset)
               (logior (ash (aref bytes offset) 24)
                       (ash (aref bytes (+ offset 1)) 16)
                       (ash (aref bytes (+ offset 2)) 8)
                       (aref bytes (+ offset 3)))))
        (values (be32 16) (be32 20)))
      (values nil nil)))

(defun bounds (texture)
  "Texture2D.Bounds."
  (microsoft.xna.framework:make-rectangle 0 0 (width texture) (height texture)))

(defmethod cna-lisp.internal:destroy-native ((texture texture-2d))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%texture-2d-destroy (cna-lisp.internal:handle-of texture))
   "dispose" :object-type 'texture-2d))

(defmethod print-object ((texture texture-2d) stream)
  ;; The raw slots rather than WIDTH and HEIGHT: printing must never signal, and
  ;; a content-loaded texture has no dimensions to print. See WIDTH.
  (print-unreadable-object (texture stream :type t)
    (format stream "~@[~dx~]~@[~d ~]~a~:[~; disposed~]"
            (%texture-width texture) (%texture-height texture) (format-of texture)
            (cna-lisp.internal:disposed-state-of texture))))

;;; --- construction, and the data surface -------------------------------------
;;;
;;; XNA's `SetData<T>' and `GetData<T>' are generic over anything blittable, and
;;; this projection is as narrow here as it is for a buffer: **a transfer is
;;; accepted only when the binding can prove the binary layout of every element**.
;;; `src/graphics/buffer-data.lisp' is where those layouts live and why, and this
;;; reuses them rather than growing a second opinion about how a Color is packed.
;;;
;;; CNA's route takes the element type as an identity of its own -- a texel is
;;; four bytes of Color or one byte of Alpha8 and the ABI has to be told which --
;;; so the Lisp element type is translated **by name** into a
;;; `CNA_TEXTURE_DATA_*' identity, the way every enumeration here is translated,
;;; rather than passed through as a size.

(defparameter %texture-data-types
  `((microsoft.xna.framework:color . ,cna-lisp.internal.ffi::+texture-data-color+)
    ((unsigned-byte 8) . ,cna-lisp.internal.ffi::+texture-data-byte+)
    (single-float . ,cna-lisp.internal.ffi::+texture-data-single+)
    (microsoft.xna.framework:vector2 . ,cna-lisp.internal.ffi::+texture-data-vector2+)
    (microsoft.xna.framework:vector4 . ,cna-lisp.internal.ffi::+texture-data-vector4+))
  "Lisp element type -> CNA texel identity, by name and not by size.

CNA distinguishes texel *kinds* that happen to share a byte count -- an
Alpha8 byte and a raw byte, a Color and an Rgba1010102 -- so the identity is
chosen from the element's own type rather than computed from
%ELEMENT-BYTE-SIZE.")

(defun %texture-data-type-for (sample operation)
  "The CNA texel identity SAMPLE's Lisp type stands for."
  (let ((entry (find-if (lambda (row) (typep sample (car row))) %texture-data-types)))
    (unless entry
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control
             "a texture transfer cannot take ~a elements. CNA names a texel kind ~
              rather than a byte count, so this projects the kinds it can name: ~
              COLOR, (UNSIGNED-BYTE 8), SINGLE-FLOAT, VECTOR2 and VECTOR4."
             :format-arguments (list (type-of sample))))
    (cdr entry)))

(defmacro %with-texture-transfer ((pointer level rectangle start-index element-count)
                                  &body body)
  "Fill a CNA_Texture2DTransfer for the dynamic extent of BODY."
  `(cffi:with-foreign-object (,pointer '(:struct cna-lisp.internal.ffi::cna-texture-2d-transfer))
     (cffi:foreign-funcall "memset" :pointer ,pointer :int 0
                           :size cna-lisp.internal.ffi::+sizeof-cna-texture-2d-transfer+
                           :void)
     (macrolet ((slot (name)
                  `(cffi:foreign-slot-value
                    ,',pointer '(:struct cna-lisp.internal.ffi::cna-texture-2d-transfer)
                    ',name)))
       (setf (slot cna-lisp.internal.ffi::struct-size)
             cna-lisp.internal.ffi::+sizeof-cna-texture-2d-transfer+
             (slot cna-lisp.internal.ffi::struct-version) 1
             (slot cna-lisp.internal.ffi::level) ,level
             (slot cna-lisp.internal.ffi::has-rectangle)
             (cna-lisp.internal.ffi:cna-bool-of ,rectangle)
             (slot cna-lisp.internal.ffi::start-index) ,start-index
             (slot cna-lisp.internal.ffi::element-count) ,element-count))
     (when ,rectangle
       (%write-rectangle
        (cffi:foreign-slot-pointer
         ,pointer '(:struct cna-lisp.internal.ffi::cna-texture-2d-transfer)
         'cna-lisp.internal.ffi::rectangle)
        ,rectangle))
     ,@body))

(defun %check-texture-transfer-shape (operation level rectangle start-index element-count
                                     buffer-keywords &optional volume-keywords)
  "Refuse every keyword combination XNA's three overloads do not have.

    (data)                          SetData(T[])
    (data :start-index i :element-count n)
                                    SetData(T[], Int32, Int32)
    (data :level l :source r :start-index i :element-count n)
                                    SetData(Int32, Rectangle?, T[], Int32, Int32)

`:LEVEL' and `:SOURCE' belong to the third overload only, and `:START-INDEX' and
`:ELEMENT-COUNT' come as a pair: XNA has no overload carrying one without the
other."
  (declare (ignore rectangle))
  (flet ((refuse (control &rest arguments)
           (error 'microsoft.xna.framework:cna-usage-error
                  :operation operation :format-control control
                  :format-arguments arguments)))
    ;; SET-DATA and GET-DATA are one generic function each, shared with the vertex
    ;; and index buffers, so CLOS congruence makes every method accept every
    ;; keyword any of them uses. Accepting is not the same as having: a buffer's
    ;; keywords are refused here by name rather than ignored, because silently
    ;; ignoring one would be inventing a texture overload XNA has not got.
    (when buffer-keywords
      (refuse "~{:~a~^, ~} belong~:[~;s~] to a *buffer* transfer, not a texture's. ~
               XNA's Texture2D.SetData and GetData take a mip level and a source ~
               rectangle; a byte offset, a vertex stride and SetDataOptions are ~
               VertexBuffer's and IndexBuffer's."
              (mapcar #'symbol-name buffer-keywords) (= 1 (length buffer-keywords))))
    (when volume-keywords
      (refuse "~{:~a~^, ~} belong~:[~;s~] to a *Texture3D* transfer, not a ~
               Texture2D's. XNA's Texture3D.SetData names a mip box with seven ~
               coordinates; a Texture2D's overload takes a nullable Rectangle, ~
               which is :SOURCE."
              (mapcar #'symbol-name volume-keywords) (= 1 (length volume-keywords))))
    (when (and (or start-index element-count) (not (and start-index element-count)))
      (refuse ":START-INDEX and :ELEMENT-COUNT are one pair: XNA has no transfer ~
               overload that takes either without the other."))
    (when (and level (not (and start-index element-count)))
      (refuse ":LEVEL belongs to the overload that also takes :START-INDEX and ~
               :ELEMENT-COUNT; XNA has no transfer that names a mip level and no ~
               window into the caller's array."))))

(defmethod set-data ((texture texture-2d) data
                     &key level source start-index element-count
                          (offset-in-bytes nil offset-p) (vertex-stride nil stride-p)
                          (options nil options-p)
                          (left nil left-p) (top nil top-p)
                          (right nil right-p) (bottom nil bottom-p)
                          (front nil front-p) (back nil back-p))
  (declare (ignore offset-in-bytes vertex-stride options
                   left top right bottom front back))
  (%check-texture-transfer-shape
   "set-data" level source start-index element-count
   (append (when offset-p '(offset-in-bytes)) (when stride-p '(vertex-stride))
           (when options-p '(options)))
   (append (when left-p '(left)) (when top-p '(top)) (when right-p '(right))
           (when bottom-p '(bottom)) (when front-p '(front)) (when back-p '(back))))
  (cna-lisp.internal:check-usable texture "set-data")
  (let* ((start (or start-index 0))
         (count (or element-count (length data))))
    (when (zerop count)
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation "set-data" :parameter-name "element-count"
             :format-control "a texture transfer of no elements writes nothing."))
    (multiple-value-bind (bytes size sample)
        (%pack-sequence data start count "set-data")
      (declare (ignore size))
      (let ((identity (%texture-data-type-for sample "set-data")))
        (cffi:with-foreign-object (buffer :uint8 (max 1 (length bytes)))
          (dotimes (index (length bytes))
            (setf (cffi:mem-aref buffer :uint8 index) (aref bytes index)))
          (%with-texture-transfer (transfer (or level 0) source 0 count)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%texture-2d-set-data
              (cna-lisp.internal:handle-of texture) identity transfer
              buffer (length bytes))
             "set-data" :object-type 'texture-2d))))))
  (values))

(defmethod get-data ((texture texture-2d) into
                     &key level source start-index element-count
                          (offset-in-bytes nil offset-p) (vertex-stride nil stride-p)
                          (options nil options-p)
                          (left nil left-p) (top nil top-p)
                          (right nil right-p) (bottom nil bottom-p)
                          (front nil front-p) (back nil back-p))
  (declare (ignore offset-in-bytes vertex-stride options
                   left top right bottom front back))
  (%check-texture-transfer-shape
   "get-data" level source start-index element-count
   (append (when offset-p '(offset-in-bytes)) (when stride-p '(vertex-stride))
           (when options-p '(options)))
   (append (when left-p '(left)) (when top-p '(top)) (when right-p '(right))
           (when bottom-p '(bottom)) (when front-p '(front)) (when back-p '(back))))
  (cna-lisp.internal:check-usable texture "get-data")
  (when (zerop (length into))
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "get-data" :parameter-name "into"
           :format-control
           "GET-DATA fills a sequence and reads the texel kind from its first ~
            element, so an empty one says nothing about what to read."))
  (let* ((start (or start-index 0))
         (count (or element-count (- (length into) start)))
         (sample (elt into 0))
         (identity (%texture-data-type-for sample "get-data"))
         (stride (%element-byte-size sample)))
    (unless (and (<= 0 start) (<= 0 count) (<= (+ start count) (length into)))
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation "get-data" :parameter-name "element-count"
             :format-control "~d element(s) from index ~d is outside a sequence of ~d."
             :format-arguments (list count start (length into))))
    (cffi:with-foreign-object (buffer :uint8 (max 1 (* stride count)))
      (cffi:foreign-funcall "memset" :pointer buffer :int 0
                            :size (max 1 (* stride count)) :void)
      (cffi:with-foreign-object (required :uint64)
        (%with-texture-transfer (transfer (or level 0) source 0 count)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%texture-2d-get-data
            (cna-lisp.internal:handle-of texture) identity transfer
            buffer count required)
           "get-data" :object-type 'texture-2d)))
      (%unpack-into into start count buffer stride sample))
    into))

(defgeneric %texture-makes-own-storage-p (texture)
  (:documentation
   "True when this kind of texture creates its own native storage.

RENDER-TARGET-2D is a TEXTURE-2D and makes its storage with
`cna_render_target2d_create', so the base class's constructor must not make a
plain texture underneath it first -- which is exactly what an inherited
`initialize-instance :after' would do, and did. The same shape `Effect' uses for
`%EFFECT-TAKES-CODE-P': the base asks, and a subclass that is different says so.")
  (:method ((texture texture-2d)) nil))

(defmethod initialize-instance :after ((texture texture-2d)
                                       &key graphics-device width height
                                            (mip-map nil) (format :color))
  "Texture2D(GraphicsDevice, Int32, Int32) and its five-argument sibling.

The three-argument overload is not `everything zero': XNA fills in no mip map and
`SurfaceFormat.Color', which is what the defaults here are."
  (when (and graphics-device
             (not (%texture-makes-own-storage-p texture))
             (zerop (cna-lisp.internal:handle-of texture)))
    (check-type width (integer 1))
    (check-type height (integer 1))
    (check-type format surface-format)
    (let ((device-handle (device-handle-for-child graphics-device
                                                  "make-instance 'texture-2d")))
      (cffi:with-foreign-object
          (info '(:struct cna-lisp.internal.ffi::cna-texture-2d-create-info))
        (cffi:foreign-funcall
         "memset" :pointer info :int 0
         :size cna-lisp.internal.ffi::+sizeof-cna-texture-2d-create-info+ :void)
        (macrolet ((slot (name)
                     `(cffi:foreign-slot-value
                       info '(:struct cna-lisp.internal.ffi::cna-texture-2d-create-info)
                       ',name)))
          (setf (slot cna-lisp.internal.ffi::struct-size)
                cna-lisp.internal.ffi::+sizeof-cna-texture-2d-create-info+
                (slot cna-lisp.internal.ffi::struct-version) 1
                (slot cna-lisp.internal.ffi::width) width
                (slot cna-lisp.internal.ffi::height) height
                (slot cna-lisp.internal.ffi::mip-map)
                (cna-lisp.internal.ffi:cna-bool-of mip-map)
                (slot cna-lisp.internal.ffi::format) (surface-format-value format)))
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%texture-2d-create device-handle info out)
           "make-instance 'texture-2d" :object-type 'texture-2d)
          (let ((handle (cffi:mem-ref out :uint64)))
            (cna-lisp.internal:record-construction-undo
             texture (lambda () (cna-lisp.internal.ffi::%texture-2d-destroy handle)))
            (multiple-value-bind (levels granted)
                (%texture-storage-dimensions handle)
              (setf (cna-lisp.internal:handle-of texture) handle
                    (slot-value texture 'width) width
                    (slot-value texture 'height) height
                    (slot-value texture 'level-count) levels
                    (slot-value texture 'format) granted)
              (adopt-native-resource texture graphics-device)
              (cna-lisp.internal:record-construction-undo
               texture (lambda () (cna-lisp.internal:invalidate texture))))))))))
