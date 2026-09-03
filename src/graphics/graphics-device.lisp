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
  ()
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

(defgeneric viewport-of (graphics-device)
  (:documentation "GraphicsDevice.Viewport."))

(defmethod viewport-of ((device graphics-device))
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
