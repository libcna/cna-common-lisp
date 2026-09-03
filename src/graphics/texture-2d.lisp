;;;; texture-2d.lisp --- Microsoft.Xna.Framework.Graphics.Texture2D.
;;;;
;;;; A texture is created against the graphics device, but CNA owns it as a child
;;;; of the *game*: it outlives the callback that created it, and the game refuses
;;;; to be destroyed while it is alive. CNA-Lisp records that ownership so
;;;; disposal order is checked here rather than discovered as a native failure.

(in-package #:microsoft.xna.framework.graphics)

(defclass texture (cna-lisp.internal:native-object)
  ()
  (:documentation
   "Microsoft.Xna.Framework.Graphics.Texture: the abstract base of the texture
family. Present so TEXTURE-2D has the superclass the contract gives it; it has no
members of its own in this milestone."))

(defclass texture-2d (texture)
  ((width :initarg :width :initform 0 :reader width)
   (height :initarg :height :initform 0 :reader height)
   (level-count :initarg :level-count :initform 1 :reader level-count)
   (format :initarg :format :initform :color :reader format-of))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.Texture2D.

Created from image data through TEXTURE-2D-FROM-PNG-BYTES or
TEXTURE-2D-FROM-PNG-FILE, which project XNA's Texture2D.FromStream over CNA's
decode routes. Disposed with MICROSOFT.XNA.FRAMEWORK:DISPOSE, before the game
that owns it."))

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

(defun %make-texture-2d (device handle width height)
  (multiple-value-bind (levels format) (%texture-storage-dimensions handle)
    (let* ((game (cna-lisp.internal:owner-of device))
           (texture (make-instance 'texture-2d
                                   :handle handle
                                   :ownership :owned
                                   :owner game
                                   :owner-thread (cna-lisp.internal:owner-thread-of game)
                                   :width width :height height
                                   :level-count levels :format format)))
      (cna-lisp.internal:register-child game texture)
      texture)))

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

(defun %decoded-dimensions (bytes)
  "The pixel dimensions a PNG header declares.

CNA has no route that reports a texture's extent, so the extent is read from the
image the caller supplied rather than invented. A payload that is not a PNG
answers zero and zero, and WIDTH and HEIGHT then report what is actually known:
nothing."
  (if (and (>= (length bytes) 24)
           (equalp (subseq bytes 0 8) #(137 80 78 71 13 10 26 10)))
      (flet ((be32 (offset)
               (logior (ash (aref bytes offset) 24)
                       (ash (aref bytes (+ offset 1)) 16)
                       (ash (aref bytes (+ offset 2)) 8)
                       (aref bytes (+ offset 3)))))
        (values (be32 16) (be32 20)))
      (values 0 0)))

(defun bounds (texture)
  "Texture2D.Bounds."
  (microsoft.xna.framework:make-rectangle 0 0 (width texture) (height texture)))

(defmethod cna-lisp.internal:destroy-native ((texture texture-2d))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%texture-2d-destroy (cna-lisp.internal:handle-of texture))
   "dispose" :object-type 'texture-2d))

(defmethod print-object ((texture texture-2d) stream)
  (print-unreadable-object (texture stream :type t)
    (format stream "~dx~d ~a~:[~; disposed~]"
            (width texture) (height texture) (format-of texture)
            (cna-lisp.internal:disposed-state-of texture))))
