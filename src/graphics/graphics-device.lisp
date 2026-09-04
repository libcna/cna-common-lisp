;;;; graphics-device.lisp --- Microsoft.Xna.Framework.Graphics.GraphicsDevice.
;;;;
;;;; CNA lends the graphics device only from inside a game lifecycle callback,
;;;; and the handle it lends is valid only until that callback returns. So this
;;;; class stores no handle at all: it is a parent-owned facade over the game,
;;;; and every operation resolves a fresh borrowed handle at the moment it is
;;;; performed. Keeping the borrowed handle in a slot would be the classic bug
;;;; -- it would look like it worked, right up to the first use after the frame
;;;; that produced it.
;;;;
;;;; A device operation attempted outside a callback is refused by CNA-Lisp with
;;;; a CNA-SCOPE-ERROR before anything reaches the ABI.

(in-package #:microsoft.xna.framework.graphics)

(defclass graphics-device (cna-lisp.internal:native-object)
  (;; The four collection properties answer the same object every time, as XNA's
   ;; do, and each collection is the record of what this binding bound into its
   ;; slots. See src/graphics/state-collections.lisp.
   (sampler-states :initform nil)
   (vertex-sampler-states :initform nil)
   (textures :initform nil)
   (vertex-textures :initform nil))
  (:default-initargs :ownership :parent-owned)
  (:documentation
   "The game's graphics device. Instances are produced by the runtime and reached
through MICROSOFT.XNA.FRAMEWORK:GRAPHICS-DEVICE; a consumer does not create one.

Every operation on a graphics device is legal only inside a game lifecycle
method -- LOAD-CONTENT, UPDATE, DRAW and their neighbours -- because that is the
only time CNA lends the device out."))

(defun %resolve-device-handle (device operation)
  "The borrowed native handle of DEVICE, valid for this operation only."
  (cna-lisp.internal:check-live device operation)
  (cna-lisp.internal:check-owner-thread
   (cna-lisp.internal:owner-thread-of device) operation :object-type 'graphics-device)
  (unless (cna-lisp.internal:in-callback-scope-p)
    (error 'microsoft.xna.framework:cna-scope-error
           :operation operation
           :object-type 'graphics-device
           :format-control
           "~a is only legal inside a game lifecycle method. CNA lends the graphics device ~
            for the duration of a callback and no longer, so there is no valid device ~
            handle outside one. Do graphics work in LOAD-CONTENT, DRAW or another ~
            lifecycle method."
           :format-arguments (list operation)))
  (let ((game (cna-lisp.internal:owner-of device)))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-get-graphics-device
        (cna-lisp.internal:handle-of game) out)
       operation :object-type 'graphics-device)
      (mem-ref-handle out))))

(defun mem-ref-handle (pointer)
  (cffi:mem-ref pointer :uint64))

(defgeneric clear (graphics-device color)
  (:documentation
   "GraphicsDevice.Clear(Color): clear the current render target to COLOR."))

(defmethod clear ((device graphics-device) (color microsoft.xna.framework:color))
  ;; The device route takes four normalised channels, and XNA's Clear(Color)
  ;; converts the colour the same way: each byte divided by 255 in binary32,
  ;; which is exactly Color.ToVector4.
  (flet ((channel (byte) (/ (coerce byte 'single-float) 255.0f0)))
    (let ((handle (%resolve-device-handle device "clear")))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-clear-rgba
        handle
        (channel (microsoft.xna.framework:color-r color))
        (channel (microsoft.xna.framework:color-g color))
        (channel (microsoft.xna.framework:color-b color))
        (channel (microsoft.xna.framework:color-a color)))
       "clear" :object-type 'graphics-device)))
  (values))

(defgeneric viewport (graphics-device)
  (:documentation
   "GraphicsDevice.Viewport.

The reader is unconditional. The setter needs the optional private shim, because
`cna_graphics_device_set_viewport' takes CNA_Viewport by value and at 24 bytes the
System V AMD64 ABI passes it in memory, which CFFI cannot express without
cffi-libffi. See docs/native-abi.md."))

(defmethod viewport ((device graphics-device))
  (let ((handle (%resolve-device-handle device "viewport")))
    (cffi:with-foreign-object (vp '(:struct cna-lisp.internal.ffi::cna-viewport))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-viewport handle vp)
       "viewport" :object-type 'graphics-device)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     vp '(:struct cna-lisp.internal.ffi::cna-viewport) ',name)))
        (make-viewport (slot cna-lisp.internal.ffi::x)
                       (slot cna-lisp.internal.ffi::y)
                       (slot cna-lisp.internal.ffi::width)
                       (slot cna-lisp.internal.ffi::height)
                       (slot cna-lisp.internal.ffi::min-depth)
                       (slot cna-lisp.internal.ffi::max-depth))))))

(defgeneric renderer-name (graphics-device)
  (:documentation
   "The name of the renderer behind this device.

A CNA-Lisp addition, not an XNA member: XNA has no equivalent, and knowing which
renderer is present is what makes a headless qualification run interpretable."))

(defmethod renderer-name ((device graphics-device))
  (let ((handle (%resolve-device-handle device "renderer-name")))
    (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-renderer-info))
      (cffi:foreign-funcall "memset" :pointer info :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-renderer-info+ :void)
      (setf (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-renderer-info)
                                     'cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-renderer-info+
            (cffi:foreign-slot-value info '(:struct cna-lisp.internal.ffi::cna-renderer-info)
                                     'cna-lisp.internal.ffi::struct-version)
            1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-renderer-info handle info)
       "renderer-name" :object-type 'graphics-device)
      (let ((size (cffi:foreign-slot-value
                   info '(:struct cna-lisp.internal.ffi::cna-renderer-info)
                   'cna-lisp.internal.ffi::renderer-name-byte-length)))
        (if (zerop size)
            ""
            (cffi:with-foreign-object (buffer :uint8 size)
              (cffi:with-foreign-object (written :uint64)
                (cna-lisp.internal:check-result
                 (cna-lisp.internal.ffi::%graphics-device-copy-renderer-name
                  handle buffer size written)
                 "renderer-name" :object-type 'graphics-device)
                (let ((n (cffi:mem-ref written :uint64)))
                  (cna-lisp.internal:utf8-octets-to-string
                   (let ((v (make-array n :element-type '(unsigned-byte 8))))
                     (dotimes (i n v)
                       (setf (aref v i) (cffi:mem-aref buffer :uint8 i))))))))))))) 

(defparameter +viewport-shim-reason+
  "cna_graphics_device_set_viewport takes CNA_Viewport by value, and at 24 bytes the System V
AMD64 ABI passes it in memory rather than in registers -- which CFFI cannot express without
cffi-libffi, a dependency a released CNA-Lisp must not have."
  "Why the viewport setter is the one member that needs the optional shim.")

(defgeneric (setf viewport) (viewport graphics-device)
  (:documentation
   "GraphicsDevice.Viewport's setter.

This is the one member of the projection that goes through the optional private
shim: the route takes CNA_Viewport by value, and the System V AMD64 ABI passes a
24-byte aggregate in memory, which CFFI cannot do without cffi-libffi. Without the
shim it refuses with a CNA-NOT-SUPPORTED-ERROR saying how to build one; the reader
and everything else work regardless."))

(defmethod (setf viewport) (new-viewport (device graphics-device))
  (let ((entry (cna-lisp.internal:shim-entry-point
                "cna_lisp_shim_cna_graphics_device_set_viewport")))
    (unless entry
      (cna-lisp.internal:refuse-without-shim
       "(setf viewport)" "cna_lisp_shim_cna_graphics_device_set_viewport"
       +viewport-shim-reason+))
    (let ((handle (%resolve-device-handle device "(setf viewport)")))
      (cffi:with-foreign-object (vp '(:struct cna-lisp.internal.ffi::cna-viewport))
        (macrolet ((slot (name)
                     `(cffi:foreign-slot-value
                       vp '(:struct cna-lisp.internal.ffi::cna-viewport) ',name)))
          (setf (slot cna-lisp.internal.ffi::x) (viewport-x new-viewport)
                (slot cna-lisp.internal.ffi::y) (viewport-y new-viewport)
                (slot cna-lisp.internal.ffi::width) (viewport-width new-viewport)
                (slot cna-lisp.internal.ffi::height) (viewport-height new-viewport)
                (slot cna-lisp.internal.ffi::min-depth) (viewport-min-depth new-viewport)
                (slot cna-lisp.internal.ffi::max-depth) (viewport-max-depth new-viewport)))
        (cna-lisp.internal:check-result
         (cffi:foreign-funcall-pointer
          entry ()
          :pointer (cffi:foreign-symbol-pointer "cna_graphics_device_set_viewport")
          :uint64 handle
          :pointer vp
          :uint32)
         "(setf viewport)" :object-type 'graphics-device))))
  new-viewport)

(defgeneric present (graphics-device)
  (:documentation "GraphicsDevice.Present()."))

(defmethod present ((device graphics-device))
  (let ((handle (%resolve-device-handle device "present")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-present handle)
     "present" :object-type 'graphics-device))
  (values))

(defun device-handle-for-child (device operation)
  "The borrowed device handle a child resource is created against.

Exported to the rest of CNA-Lisp only; a consumer never sees it."
  (%resolve-device-handle device operation))


;;; --- the device's own state ---------------------------------------------------
;;;
;;; Setting one of these three is XNA's Apply: the state object is copied into the
;;; device and becomes read-only, permanently, for exactly the reason XNA gives --
;;; a caller who could still mutate it would be editing a value the device had
;;; already taken. A null is refused rather than defaulted: XNA's setters throw
;;; ArgumentNullException, and it is SpriteBatch.Begin, not the device, that turns
;;; a missing state into AlphaBlend.

(macrolet
    ((define-state-property (name class getter setter writer reader struct size doc)
       (let ((operation (string-downcase (symbol-name name)))
             (setf-operation (format nil "(setf ~(~a~))" name)))
         `(progn
            (defgeneric ,name (graphics-device) (:documentation ,doc))
            (defmethod ,name ((device graphics-device))
              (let ((handle (%resolve-device-handle device ,operation)))
                (%with-state-descriptor (pointer ,struct ,size)
                  (cna-lisp.internal:check-result
                   (,getter handle pointer)
                   ,operation :object-type 'graphics-device)
                  ;; The device answers a *copy*: a caller who mutates it is
                  ;; describing what to apply next, not editing what is applied.
                  (,reader pointer))))
            (defgeneric (setf ,name) (state graphics-device)
              (:documentation
               ,(format nil "GraphicsDevice.~a's setter. Refuses NIL, and latches ~
                             the state object read-only as XNA's Apply does."
                        (symbol-name name))))
            (defmethod (setf ,name) (state (device graphics-device))
              (unless state
                (error 'microsoft.xna.framework:cna-argument-out-of-range-error
                       :operation ,setf-operation
                       :parameter-name ,(string-downcase (symbol-name class))
                       :object-type 'graphics-device
                       :format-control
                       "GraphicsDevice.~a does not accept NIL; XNA throws ~
                        ArgumentNullException here. SpriteBatch.Begin is where a ~
                        null state means \"use the default\"."
                       :format-arguments (list ,(symbol-name name))))
              (check-type state ,class)
              (let ((handle (%resolve-device-handle device ,setf-operation)))
                (%with-state-descriptor (pointer ,struct ,size)
                  (,writer pointer state)
                  (cna-lisp.internal:check-result
                   (,setter handle pointer)
                   ,setf-operation :object-type 'graphics-device)))
              (%mark-bound state)
              state)))))
  (define-state-property blend-state blend-state
    cna-lisp.internal.ffi::%graphics-device-get-blend-state
    cna-lisp.internal.ffi::%graphics-device-set-blend-state
    %write-blend-state %read-blend-state
    cna-lisp.internal.ffi::cna-blend-state
    cna-lisp.internal.ffi::+sizeof-cna-blend-state+
    "GraphicsDevice.BlendState.")
  (define-state-property depth-stencil-state depth-stencil-state
    cna-lisp.internal.ffi::%graphics-device-get-depth-stencil-state
    cna-lisp.internal.ffi::%graphics-device-set-depth-stencil-state
    %write-depth-stencil-state %read-depth-stencil-state
    cna-lisp.internal.ffi::cna-depth-stencil-state
    cna-lisp.internal.ffi::+sizeof-cna-depth-stencil-state+
    "GraphicsDevice.DepthStencilState.")
  (define-state-property rasterizer-state rasterizer-state
    cna-lisp.internal.ffi::%graphics-device-get-rasterizer-state
    cna-lisp.internal.ffi::%graphics-device-set-rasterizer-state
    %write-rasterizer-state %read-rasterizer-state
    cna-lisp.internal.ffi::cna-rasterizer-state
    cna-lisp.internal.ffi::+sizeof-cna-rasterizer-state+
    "GraphicsDevice.RasterizerState."))

;;; --- the three scalar pieces of device state ----------------------------------
;;;
;;; XNA keeps these on the device as well as on the state object that carries
;;; them: applying a BlendState copies its BlendFactor and MultiSampleMask into
;;; the device, and applying a DepthStencilState copies its ReferenceStencil, but
;;; each can also be set on its own afterwards.

(macrolet ((define-integer-property (name getter setter doc)
             (let ((operation (string-downcase (symbol-name name)))
                   (setf-operation (format nil "(setf ~(~a~))" name)))
               ;; No DEFGENERIC: BlendState and DepthStencilState carry members of
               ;; the same names, so the generic function already exists and this
               ;; adds a method to it. XNA has the same property in a different
               ;; shape -- applying a BlendState copies its MultiSampleMask into
               ;; the device -- and one generic function with two methods says
               ;; that better than two names would. DOC is the member's, kept on
               ;; the method.
               `(progn
                  (defmethod ,name ((device graphics-device))
                    ,doc
                    (let ((handle (%resolve-device-handle device ,operation)))
                      (cffi:with-foreign-object (out :int32)
                        (cna-lisp.internal:check-result
                         (,getter handle out) ,operation :object-type 'graphics-device)
                        (cffi:mem-ref out :int32))))
                  (defmethod (setf ,name) (value (device graphics-device))
                    (check-type value (signed-byte 32))
                    (let ((handle (%resolve-device-handle device ,setf-operation)))
                      (cna-lisp.internal:check-result
                       (,setter handle value) ,setf-operation
                       :object-type 'graphics-device))
                    value)))))
  (define-integer-property multi-sample-mask
      cna-lisp.internal.ffi::%graphics-device-get-multi-sample-mask
      cna-lisp.internal.ffi::%graphics-device-set-multi-sample-mask
    "GraphicsDevice.MultiSampleMask.")
  (define-integer-property reference-stencil
      cna-lisp.internal.ffi::%graphics-device-get-reference-stencil
      cna-lisp.internal.ffi::%graphics-device-set-reference-stencil
    "GraphicsDevice.ReferenceStencil."))

(defmethod blend-factor ((device graphics-device))
  "GraphicsDevice.BlendFactor. A method on BlendState's generic function, because
applying a blend state is what copies its factor into the device."
  (let ((handle (%resolve-device-handle device "blend-factor")))
    (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-color))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-blend-factor handle out)
       "blend-factor" :object-type 'graphics-device)
      (microsoft.xna.framework:color-from-packed-value (cffi:mem-ref out :uint32)))))

(defmethod (setf blend-factor) (color (device graphics-device))
  (check-type color microsoft.xna.framework:color)
  (let ((handle (%resolve-device-handle device "(setf blend-factor)")))
    ;; CNA_Color is one INTEGER eightbyte, so the by-value parameter is the packed
    ;; value itself; docs/native-abi.md has the flattening rule and its proof.
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-set-blend-factor
      handle (microsoft.xna.framework:color-packed-value color))
     "(setf blend-factor)" :object-type 'graphics-device))
  color)

(defgeneric scissor-rectangle (graphics-device)
  (:documentation "GraphicsDevice.ScissorRectangle."))

(defmethod scissor-rectangle ((device graphics-device))
  (let ((handle (%resolve-device-handle device "scissor-rectangle")))
    (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-rectangle))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-scissor-rectangle handle out)
       "scissor-rectangle" :object-type 'graphics-device)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     out '(:struct cna-lisp.internal.ffi::cna-rectangle) ',name)))
        (microsoft.xna.framework:make-rectangle
         (slot cna-lisp.internal.ffi::x) (slot cna-lisp.internal.ffi::y)
         (slot cna-lisp.internal.ffi::width) (slot cna-lisp.internal.ffi::height))))))

(defgeneric (setf scissor-rectangle) (rectangle graphics-device))

(defmethod (setf scissor-rectangle) (rectangle (device graphics-device))
  (check-type rectangle microsoft.xna.framework:rectangle)
  (let ((handle (%resolve-device-handle device "(setf scissor-rectangle)")))
    ;; CNA_Rectangle is 16 bytes of four int32: two INTEGER eightbytes, so it is
    ;; passed as two uint64 arguments, x and y in the first and width and height
    ;; in the second. tools/native-abi/valueprobe.generated.c proves the shape at
    ;; run time rather than leaving it asserted here.
    (cffi:with-foreign-object (packed '(:struct cna-lisp.internal.ffi::cna-rectangle))
      (%write-rectangle packed rectangle)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-set-scissor-rectangle
        handle
        (cffi:mem-aref packed :uint64 0)
        (cffi:mem-aref packed :uint64 1))
       "(setf scissor-rectangle)" :object-type 'graphics-device)))
  rectangle)

;;; --- reading the back buffer -----------------------------------------------------
;;;
;;; This is the one member of the projection that can answer *pixels*, and it is
;;; therefore the one that can prove a renderer rasterised anything. Under the
;;; HEADLESS renderer CNA answers CNA_RESULT_NOT_SUPPORTED, in its own words
;;; "when the active renderer has no honest back-buffer readback", and the
;;; refusal is the honest answer rather than a buffer of zeroes. Under a
;;; rasterising renderer -- SOFTWARE, say -- it answers what was drawn.
;;;
;;; XNA's GetBackBufferData is generic over the element type. There is no type
;;; parameter to instantiate in Common Lisp, and CNA's route produces RGBA8
;;; pixels and nothing else, so this answers a simple-vector of COLOR. XNA's
;;; other element types are the same bytes read differently, which a caller does
;;; with COLOR-PACKED-VALUE.

(defgeneric get-back-buffer-data (graphics-device &key source start-index element-count)
  (:documentation
   "GraphicsDevice.GetBackBufferData: the back buffer's pixels, as a vector of COLOR.

    (get-back-buffer-data device)
    (get-back-buffer-data device :start-index i :element-count n)
    (get-back-buffer-data device :source rectangle :start-index i :element-count n)

Those are XNA's three overloads. :START-INDEX and :ELEMENT-COUNT are one group,
because XNA has no overload that carries one without the other; :SOURCE may be
given with them or alone. With nothing supplied the whole back buffer is read.

**Under a renderer with no honest readback this signals**
CNA-NOT-SUPPORTED-ERROR rather than answering zeroes -- which is what makes the
member usable as evidence that pixels were produced. See docs/limitations.md."))

(defmethod get-back-buffer-data ((device graphics-device)
                                 &key source
                                      (start-index nil start-index-p)
                                      (element-count nil element-count-p))
  (when (and (or start-index-p element-count-p)
             (not (and start-index-p element-count-p)))
    (error 'microsoft.xna.framework:cna-usage-error
           :operation "get-back-buffer-data"
           :format-control
           ":START-INDEX and :ELEMENT-COUNT are one group: XNA has no ~
            GetBackBufferData overload that carries one without the other."))
  (when source (check-type source microsoft.xna.framework:rectangle))
  (let* ((viewport (viewport device))
         (pixels (if element-count-p
                     (+ (or start-index 0) element-count)
                     (if source
                         (* (microsoft.xna.framework:rectangle-width source)
                            (microsoft.xna.framework:rectangle-height source))
                         (* (viewport-width viewport) (viewport-height viewport)))))
         (start (if start-index-p start-index 0))
         (count (if element-count-p element-count (- pixels start))))
    (when (or (minusp start) (minusp count))
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation "get-back-buffer-data"
             :parameter-name (if (minusp start) "start-index" "element-count")
             :format-control "a back-buffer window cannot start at ~d and run for ~d."
             :format-arguments (list start count)))
    (let ((handle (%resolve-device-handle device "get-back-buffer-data"))
          (result (make-array (+ start count))))
      (cffi:with-foreign-object (readback '(:struct cna-lisp.internal.ffi::cna-back-buffer-readback))
        (cffi:foreign-funcall
         "memset" :pointer readback :int 0
         :size cna-lisp.internal.ffi::+sizeof-cna-back-buffer-readback+ :void)
        (macrolet ((slot (name)
                     `(cffi:foreign-slot-value
                       readback '(:struct cna-lisp.internal.ffi::cna-back-buffer-readback)
                       ',name)))
          (setf (slot cna-lisp.internal.ffi::struct-size)
                cna-lisp.internal.ffi::+sizeof-cna-back-buffer-readback+
                (slot cna-lisp.internal.ffi::struct-version) 1
                (slot cna-lisp.internal.ffi::has-source-rectangle)
                (cna-lisp.internal.ffi:cna-bool-of source)
                (slot cna-lisp.internal.ffi::start-index) start
                (slot cna-lisp.internal.ffi::element-count) count))
        (when source
          (%write-rectangle (cffi:foreign-slot-pointer
                             readback
                             '(:struct cna-lisp.internal.ffi::cna-back-buffer-readback)
                             'cna-lisp.internal.ffi::source-rectangle)
                            source))
        (cffi:with-foreign-object (destination :uint32 (max 1 (length result)))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%graphics-device-get-backbuffer-data-window
            handle readback destination (length result))
           "get-back-buffer-data" :object-type 'graphics-device)
          ;; CNA_Color is four bytes in R G B A order, which is the packed value.
          (dotimes (index (length result) result)
            (setf (aref result index)
                  (microsoft.xna.framework:color-from-packed-value
                   (cffi:mem-aref destination :uint32 index)))))))))
