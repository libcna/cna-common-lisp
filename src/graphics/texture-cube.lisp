;;;; texture-cube.lisp --- TextureCube and CubeMapFace.
;;;;
;;;; Six square faces of one size, addressed by face rather than by index. The
;;;; shape follows `Texture2D`'s data surface exactly -- the same three transfer
;;;; overloads, the same narrow rule about proven layouts -- with a face selecting
;;;; the subresource.
;;;;
;;;; **One divergence from XNA, and it is CNA's.** XNA's `SetData<T>' and
;;;; `GetData<T>' are generic over anything blittable, as `Texture2D`'s are, and
;;;; `Texture2D`'s projection here accepts five element types because
;;;; `cna_texture2d_set_data' takes a texel *kind*. `cna_texturecube_set_data'
;;;; does not: its data parameter is `const CNA_Color*' and there is no kind
;;;; argument, so a cube face can only be transferred as `Color'. That is a real
;;;; narrowing of a member rather than a missing one, so the two transfer families
;;;; are reported **partial** and `docs/limitations.md' says exactly what is
;;;; missing from them.

(in-package #:microsoft.xna.framework.graphics)

(microsoft.xna.framework::define-xna-enum cube-map-face
  '((:positive-x . 0) (:negative-x . 1) (:positive-y . 2)
    (:negative-y . 3) (:positive-z . 4) (:negative-z . 5))
  :documentation "Microsoft.Xna.Framework.Graphics.CubeMapFace.")

(defclass texture-cube (texture)
  ((%size :initarg :size :initform 0 :reader texture-cube-size)
   (%level-count :initarg :level-count :initform 1 :reader %cube-level-count)
   (%format :initarg :format :initform :color :reader %cube-format))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.TextureCube: six square faces of one size.

    (make-instance 'texture-cube :graphics-device device :size 8)

A TEXTURE, as XNA's is, and not a TEXTURE-2D: a cube has no single width and
height, it has a SIZE that is the edge of every face. Transfers name a
CUBE-MAP-FACE.

Owned by the game and disposed with MICROSOFT.XNA.FRAMEWORK:DISPOSE, before it."))

(defun %texture-cube-info (handle operation)
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-texture-cube-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-texture-cube-info+ :void)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   info '(:struct cna-lisp.internal.ffi::cna-texture-cube-info) ',name)))
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-texture-cube-info+
            (slot cna-lisp.internal.ffi::struct-version) 1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%texturecube-get-info handle info)
       operation :object-type 'texture-cube)
      (values (slot cna-lisp.internal.ffi::size)
              (slot cna-lisp.internal.ffi::level-count)
              (surface-format-from-value (slot cna-lisp.internal.ffi::format))))))

(defmethod initialize-instance :after ((texture texture-cube)
                                       &key graphics-device size
                                            (mip-map nil) (format :color))
  "TextureCube(GraphicsDevice, Int32, Boolean, SurfaceFormat)."
  (when graphics-device
    (check-type size (integer 1))
    (check-type format surface-format)
    (let ((device-handle (device-handle-for-child graphics-device
                                                  "make-instance 'texture-cube"))
          (game (cna-lisp.internal:owner-of graphics-device)))
      (cffi:with-foreign-object
          (info '(:struct cna-lisp.internal.ffi::cna-texture-cube-create-info))
        (cffi:foreign-funcall
         "memset" :pointer info :int 0
         :size cna-lisp.internal.ffi::+sizeof-cna-texture-cube-create-info+ :void)
        (macrolet ((slot (name)
                     `(cffi:foreign-slot-value
                       info '(:struct cna-lisp.internal.ffi::cna-texture-cube-create-info)
                       ',name)))
          (setf (slot cna-lisp.internal.ffi::struct-size)
                cna-lisp.internal.ffi::+sizeof-cna-texture-cube-create-info+
                (slot cna-lisp.internal.ffi::struct-version) 1
                (slot cna-lisp.internal.ffi::size) size
                (slot cna-lisp.internal.ffi::mip-map)
                (cna-lisp.internal.ffi:cna-bool-of mip-map)
                (slot cna-lisp.internal.ffi::format) (surface-format-value format)))
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%texturecube-create device-handle info out)
           "make-instance 'texture-cube" :object-type 'texture-cube)
          (let ((handle (cffi:mem-ref out :uint64))
                (constructed nil))
            (unwind-protect
                 (multiple-value-bind (granted-size levels granted-format)
                     (%texture-cube-info handle "make-instance 'texture-cube")
                   (setf (cna-lisp.internal:handle-of texture) handle
                         (slot-value texture 'cna-lisp.internal::owner) game
                         (slot-value texture 'cna-lisp.internal::owner-thread)
                         (cna-lisp.internal:owner-thread-of game)
                         (slot-value texture '%size) granted-size
                         (slot-value texture '%level-count) levels
                         (slot-value texture '%format) granted-format)
                   (cna-lisp.internal:register-child game texture)
                   (setf constructed t))
              (unless constructed
                (ignore-errors
                 (cna-lisp.internal.ffi::%texturecube-destroy handle))))))))))

(defun %adopt-loaded-texture-cube (game handle)
  "Wrap a cube a ContentManager created.

Unlike a Texture2D, a cube *can* report its own shape: `cna_texturecube_get_info'
answers the edge size, the level count and the format, so a loaded cube is as
complete as a constructed one."
  (cna-lisp.internal:with-native-rollback (record)
    (funcall record (lambda () (cna-lisp.internal.ffi::%texturecube-destroy handle)))
    (multiple-value-bind (size levels format)
        (%texture-cube-info handle "load-asset 'texture-cube")
      (let ((texture (make-instance 'texture-cube
                                    :handle handle
                                    :ownership :owned
                                    :owner game
                                    :owner-thread (cna-lisp.internal:owner-thread-of game)
                                    :size size :level-count levels :format format)))
        (cna-lisp.internal:register-child game texture)
        (funcall record (lambda () (cna-lisp.internal:unregister-child game texture)))
        texture))))

(defmethod cna-lisp.internal:destroy-native ((texture texture-cube))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%texturecube-destroy (cna-lisp.internal:handle-of texture))
   "dispose" :object-type 'texture-cube))

(defmacro %with-cube-transfer ((pointer face level rectangle element-count) &body body)
  `(cffi:with-foreign-object
       (,pointer '(:struct cna-lisp.internal.ffi::cna-texture-cube-transfer))
     (cffi:foreign-funcall "memset" :pointer ,pointer :int 0
                           :size cna-lisp.internal.ffi::+sizeof-cna-texture-cube-transfer+
                           :void)
     (macrolet ((slot (name)
                  `(cffi:foreign-slot-value
                    ,',pointer '(:struct cna-lisp.internal.ffi::cna-texture-cube-transfer)
                    ',name)))
       (setf (slot cna-lisp.internal.ffi::struct-size)
             cna-lisp.internal.ffi::+sizeof-cna-texture-cube-transfer+
             (slot cna-lisp.internal.ffi::struct-version) 1
             (slot cna-lisp.internal.ffi::face) (cube-map-face-value ,face)
             (slot cna-lisp.internal.ffi::level) ,level
             (slot cna-lisp.internal.ffi::has-rectangle)
             (cna-lisp.internal.ffi:cna-bool-of ,rectangle)
             (slot cna-lisp.internal.ffi::start-index) 0
             (slot cna-lisp.internal.ffi::element-count) ,element-count))
     (when ,rectangle
       (%write-rectangle
        (cffi:foreign-slot-pointer
         ,pointer '(:struct cna-lisp.internal.ffi::cna-texture-cube-transfer)
         'cna-lisp.internal.ffi::rectangle)
        ,rectangle))
     ,@body))

(defun %check-cube-colors (operation sequence start count)
  "Refuse anything but a COLOR sequence, and say why.

`cna_texturecube_set_data' takes `const CNA_Color*' and no texel-kind argument,
so a cube face is transferable only as Color -- unlike a Texture2D, whose route
names the kind. That is CNA's limit rather than a decision here, and it is named
rather than worked around."
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
                    "a TextureCube transfer takes COLOR elements and this one is ~a. ~
                     XNA's SetData<T> is generic, and CNA's cube route is not: it takes ~
                     `const CNA_Color*' with no texel-kind argument, unlike the ~
                     Texture2D route. docs/limitations.md records the divergence."
                    :format-arguments (list (type-of element)))))

(defgeneric set-cube-data (texture face data &key)
  (:documentation
   "TextureCube.SetData, all three overloads, with the face XNA's every overload
takes as its first argument.

    (set-cube-data cube :positive-x data)
    (set-cube-data cube :positive-x data :start-index i :element-count n)
    (set-cube-data cube :positive-x data :level l :source rect
                                         :start-index i :element-count n)

DATA is a sequence of COLORs, and only of COLORs: see the file header."))

(defgeneric get-cube-data (texture face into &key)
  (:documentation
   "TextureCube.GetData, all three overloads, reading into INTO."))

(defmethod set-cube-data ((texture texture-cube) face data
                          &key level source start-index element-count)
  (check-type face cube-map-face)
  (%check-texture-transfer-shape "set-cube-data" level source start-index element-count nil)
  (cna-lisp.internal:check-usable texture "set-cube-data")
  (let* ((start (or start-index 0))
         (count (or element-count (- (length data) start))))
    (%check-cube-colors "set-cube-data" data start count)
    (cffi:with-foreign-object (buffer '(:struct cna-lisp.internal.ffi::cna-color)
                                      (max 1 count))
      (dotimes (index count)
        (setf (cffi:mem-aref buffer :uint32 index)
              (microsoft.xna.framework:color-packed-value (elt data (+ start index)))))
      (%with-cube-transfer (transfer face (or level 0) source count)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%texturecube-set-data
          (cna-lisp.internal:handle-of texture) transfer buffer count)
         "set-cube-data" :object-type 'texture-cube))))
  (values))

(defmethod get-cube-data ((texture texture-cube) face into
                          &key level source start-index element-count)
  (check-type face cube-map-face)
  (%check-texture-transfer-shape "get-cube-data" level source start-index element-count nil)
  (cna-lisp.internal:check-usable texture "get-cube-data")
  (let* ((start (or start-index 0))
         (count (or element-count (- (length into) start))))
    (%check-cube-colors "get-cube-data" into start count)
    (cffi:with-foreign-object (buffer '(:struct cna-lisp.internal.ffi::cna-color)
                                      (max 1 count))
      (cffi:with-foreign-object (required :uint64)
        (%with-cube-transfer (transfer face (or level 0) source count)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%texturecube-get-data
            (cna-lisp.internal:handle-of texture) transfer buffer count required)
           "get-cube-data" :object-type 'texture-cube)))
      (dotimes (index count)
        (setf (elt into (+ start index))
              (microsoft.xna.framework:color-from-packed-value
               (cffi:mem-aref buffer :uint32 index))))))
  into)

(defmethod print-object ((texture texture-cube) stream)
  (print-unreadable-object (texture stream :type t)
    (format stream "~d~:[~; disposed~]" (texture-cube-size texture)
            (cna-lisp.internal:disposed-state-of texture))))
