;;;; drawing.lisp --- VertexBufferBinding, the device's buffer state, and the
;;;; primitive draw calls.
;;;;
;;;; XNA validates its draw arguments before it reaches the driver, and the
;;;; checks are not the ones CNA makes: `DrawPrimitives' refuses a
;;;; `primitiveCount' that is not positive with an ArgumentOutOfRangeException
;;;; naming the parameter, `DrawIndexedPrimitives' refuses `numVertices' the same
;;;; way, and both refuse to run at all while a vertex stream is bound with a
;;;; non-zero instance frequency. Those are reproduced here, from the IL, because
;;;; a binding that forwarded straight to CNA would accept calls XNA rejects and
;;;; report a different failure for the ones it does reject.
;;;;
;;;; What is *not* reproduced: XNA's profile capability cap on primitive count.
;;;; It is a property of the GraphicsProfile, which is not projected yet, and
;;;; inventing a limit would be worse than letting CNA answer.

(in-package #:microsoft.xna.framework.graphics)

;;; --- VertexBufferBinding ----------------------------------------------------------

(defstruct (vertex-buffer-binding
            (:constructor %make-vertex-buffer-binding
                (vertex-buffer vertex-offset instance-frequency))
            (:copier copy-vertex-buffer-binding))
  "Microsoft.Xna.Framework.Graphics.VertexBufferBinding.

Built with MAKE-VERTEX-BUFFER-BINDING, which validates as XNA's constructors do."
  (vertex-buffer nil :read-only t)
  (vertex-offset 0 :type (signed-byte 32) :read-only t)
  (instance-frequency 0 :type (signed-byte 32) :read-only t))

(defun make-vertex-buffer-binding (vertex-buffer &optional (vertex-offset 0)
                                                           (instance-frequency 0))
  "VertexBufferBinding's three constructors, which differ only in what they default.

XNA validates in this order, and the order is reproduced because a call can fail
more than one check at once:

  1. a null buffer is an ArgumentNullException;
  2. a vertex offset below zero or **not below the buffer's VertexCount** is an
     ArgumentOutOfRangeException -- note the bound is exclusive, so an offset
     equal to the count is refused;
  3. a negative instance frequency is an ArgumentOutOfRangeException."
  (let ((operation "make-vertex-buffer-binding"))
    (unless vertex-buffer
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation operation :parameter-name "vertex-buffer"
             :format-control "a vertex buffer binding needs a buffer; XNA throws ~
                              ArgumentNullException for a null one."))
    (check-type vertex-buffer vertex-buffer)
    (check-type vertex-offset (signed-byte 32))
    (check-type instance-frequency (signed-byte 32))
    (unless (and (<= 0 vertex-offset) (< vertex-offset (vertex-count vertex-buffer)))
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation operation :parameter-name "vertex-offset"
             :format-control
             "a vertex offset must be at least 0 and less than the buffer's ~d ~
              vertices; ~d is not."
             :format-arguments (list (vertex-count vertex-buffer) vertex-offset)))
    (unless (<= 0 instance-frequency)
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation operation :parameter-name "instance-frequency"
             :format-control "an instance frequency cannot be negative; ~d is."
             :format-arguments (list instance-frequency)))
    (%make-vertex-buffer-binding vertex-buffer vertex-offset instance-frequency)))

;;; --- the device's buffer state ------------------------------------------------------

(defgeneric set-vertex-buffer (graphics-device vertex-buffer &optional vertex-offset)
  (:documentation
   "GraphicsDevice.SetVertexBuffer(VertexBuffer) and its (VertexBuffer, Int32) form.

NIL unbinds every stream, which is what XNA's null does."))

(defmethod set-vertex-buffer ((device graphics-device) vertex-buffer
                              &optional (vertex-offset nil offset-p))
  (let ((handle (%resolve-device-handle device "set-vertex-buffer")))
    (when vertex-buffer
      (check-type vertex-buffer vertex-buffer)
      (cna-lisp.internal:check-usable vertex-buffer "set-vertex-buffer"))
    (cna-lisp.internal:check-result
     (if offset-p
         (progn
           (unless vertex-buffer
             (error 'microsoft.xna.framework:cna-usage-error
                    :operation "set-vertex-buffer"
                    :format-control
                    "an offset needs a buffer to be an offset into; XNA's ~
                     SetVertexBuffer(null, n) has no meaning."))
           (unless (and (<= 0 vertex-offset)
                        (< vertex-offset (vertex-count vertex-buffer)))
             (error 'microsoft.xna.framework:cna-argument-out-of-range-error
                    :operation "set-vertex-buffer" :parameter-name "vertex-offset"
                    :format-control
                    "a vertex offset must be at least 0 and less than the buffer's ~
                     ~d vertices; ~d is not."
                    :format-arguments (list (vertex-count vertex-buffer) vertex-offset)))
           (cna-lisp.internal.ffi::%graphics-device-set-vertex-buffer-offset
            handle (cna-lisp.internal:handle-of vertex-buffer) vertex-offset))
         (cna-lisp.internal.ffi::%graphics-device-set-vertex-buffer
          handle (if vertex-buffer (cna-lisp.internal:handle-of vertex-buffer) 0)))
     "set-vertex-buffer" :object-type 'graphics-device))
  ;; The device remembers what this binding bound, so GetVertexBuffers can answer
  ;; the objects rather than handles CNA cannot map back. See the note there.
  (setf (%bound-vertex-buffers device)
        (if vertex-buffer
            (list (make-vertex-buffer-binding vertex-buffer (if offset-p vertex-offset 0)))
            '()))
  (values))

(defgeneric set-vertex-buffers (graphics-device bindings)
  (:documentation
   "GraphicsDevice.SetVertexBuffers(params VertexBufferBinding[]).

An empty list unbinds every stream, which is what XNA's empty array does."))

(defmethod set-vertex-buffers ((device graphics-device) bindings)
  (let ((bindings (coerce bindings 'list)))
    (dolist (binding bindings)
      (check-type binding vertex-buffer-binding)
      (cna-lisp.internal:check-usable (vertex-buffer-binding-vertex-buffer binding)
                                      "set-vertex-buffers"))
    (let ((handle (%resolve-device-handle device "set-vertex-buffers"))
          (count (length bindings)))
      (cffi:with-foreign-object
          (array '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-binding) (max 1 count))
        (loop for binding in bindings
              for index from 0
              for pointer = (cffi:mem-aptr
                             array
                             '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-binding)
                             index)
              do (macrolet ((slot (name)
                              `(cffi:foreign-slot-value
                                pointer
                                '(:struct cna-lisp.internal.ffi::cna-vertex-buffer-binding)
                                ',name)))
                   (setf (slot cna-lisp.internal.ffi::vertex-buffer)
                         (cna-lisp.internal:handle-of
                          (vertex-buffer-binding-vertex-buffer binding))
                         (slot cna-lisp.internal.ffi::vertex-offset)
                         (vertex-buffer-binding-vertex-offset binding)
                         (slot cna-lisp.internal.ffi::instance-frequency)
                         (vertex-buffer-binding-instance-frequency binding))))
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%graphics-device-set-vertex-buffers handle array count)
         "set-vertex-buffers" :object-type 'graphics-device)))
    (setf (%bound-vertex-buffers device) bindings))
  (values))

(defgeneric get-vertex-buffers (graphics-device)
  (:documentation
   "GraphicsDevice.GetVertexBuffers(): the bindings currently set, as a list.

Answered from what this binding bound, and checked against the count CNA
reports. The same reason TextureCollection keeps a cache applies: CNA's ABI has
no route from a native object back to a handle, so a binding CNA holds that this
binding did not set cannot be answered as an object. There is no way to set one
except through this device, so the two agree in every reachable case; if the
counts ever disagree, this refuses rather than answering a list it cannot
substantiate."))

(defmethod get-vertex-buffers ((device graphics-device))
  (let ((handle (%resolve-device-handle device "get-vertex-buffers")))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-vertex-buffer-count handle out)
       "get-vertex-buffers" :object-type 'graphics-device)
      (let ((native (cffi:mem-ref out :uint64))
            (remembered (%bound-vertex-buffers device)))
        (unless (= native (length remembered))
          (error 'microsoft.xna.framework:cna-invalid-state-error
                 :operation "get-vertex-buffers" :object-type 'graphics-device
                 :format-control
                 "CNA reports ~d bound vertex stream(s) and this binding set ~d. ~
                  Something bound a stream through another route, and there is no ~
                  way back from a native buffer to the object that names it."
                 :format-arguments (list native (length remembered))))
        (copy-list remembered)))))

(defgeneric indices (graphics-device)
  (:documentation "GraphicsDevice.Indices: the bound index buffer, or NIL."))

(defgeneric (setf indices) (index-buffer graphics-device)
  (:documentation "GraphicsDevice.Indices' setter. NIL unbinds, as XNA's null does."))

(defmethod indices ((device graphics-device))
  ;; Answered from what this binding bound, for the reason GET-VERTEX-BUFFERS
  ;; gives, and cross-checked against whether CNA has one bound at all.
  (let ((handle (%resolve-device-handle device "indices")))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%graphics-device-get-index-buffer handle out)
       "indices" :object-type 'graphics-device)
      (let ((native (cffi:mem-ref out :uint64))
            (remembered (%bound-index-buffer device)))
        (cond ((zerop native) (setf (%bound-index-buffer device) nil))
              ((and remembered
                    (not (cna-lisp.internal:disposed-state-of remembered))
                    (= native (cna-lisp.internal:handle-of remembered)))
               remembered)
              (t (setf (%bound-index-buffer device) nil)))))))

(defmethod (setf indices) (index-buffer (device graphics-device))
  (when index-buffer
    (check-type index-buffer index-buffer)
    (cna-lisp.internal:check-usable index-buffer "(setf indices)"))
  (let ((handle (%resolve-device-handle device "(setf indices)")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-set-index-buffer
      handle (if index-buffer (cna-lisp.internal:handle-of index-buffer) 0))
     "(setf indices)" :object-type 'graphics-device))
  (setf (%bound-index-buffer device) index-buffer)
  index-buffer)

;;; --- the draw calls ------------------------------------------------------------------

(defun %check-primitive-count (operation primitive-count)
  (unless (plusp primitive-count)
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation operation :parameter-name "primitive-count"
           :format-control
           "a draw must draw something: XNA refuses a primitive count of ~d with ~
            ArgumentOutOfRangeException."
           :format-arguments (list primitive-count))))

(defun %check-no-instancing (device operation)
  "XNA refuses a non-instanced draw while a stream has a non-zero frequency."
  (when (find-if (lambda (binding)
                   (plusp (vertex-buffer-binding-instance-frequency binding)))
                 (%bound-vertex-buffers device))
    (error 'microsoft.xna.framework:cna-invalid-state-error
           :operation operation :object-type 'graphics-device
           :format-control
           "a vertex stream is bound with a non-zero instance frequency, and this ~
            draw is not the instanced one. XNA throws InvalidOperationException ~
            here.")))

(defgeneric draw-primitives (graphics-device primitive-type vertex-start primitive-count)
  (:documentation
   "GraphicsDevice.DrawPrimitives(PrimitiveType, Int32, Int32)."))

(defmethod draw-primitives ((device graphics-device) primitive-type
                            vertex-start primitive-count)
  (check-type primitive-type primitive-type)
  (check-type vertex-start (signed-byte 32))
  (check-type primitive-count (signed-byte 32))
  (%check-primitive-count "draw-primitives" primitive-count)
  (%check-no-instancing device "draw-primitives")
  (let ((handle (%resolve-device-handle device "draw-primitives")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-draw-primitives
      handle (%native-of %primitive-type-to-native primitive-type "primitive-type")
      vertex-start primitive-count)
     "draw-primitives" :object-type 'graphics-device))
  (values))

(defgeneric draw-indexed-primitives (graphics-device primitive-type base-vertex
                                     min-vertex-index num-vertices start-index
                                     primitive-count)
  (:documentation
   "GraphicsDevice.DrawIndexedPrimitives(PrimitiveType, Int32, Int32, Int32, Int32, Int32)."))

(defmethod draw-indexed-primitives ((device graphics-device) primitive-type base-vertex
                                    min-vertex-index num-vertices start-index
                                    primitive-count)
  (check-type primitive-type primitive-type)
  (dolist (value (list base-vertex min-vertex-index num-vertices start-index
                       primitive-count))
    (check-type value (signed-byte 32)))
  ;; XNA checks numVertices before primitiveCount, and both before anything else.
  (unless (plusp num-vertices)
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "draw-indexed-primitives" :parameter-name "num-vertices"
           :format-control
           "an indexed draw must span at least one vertex: XNA refuses ~d with ~
            ArgumentOutOfRangeException."
           :format-arguments (list num-vertices)))
  (%check-primitive-count "draw-indexed-primitives" primitive-count)
  (%check-no-instancing device "draw-indexed-primitives")
  (let ((handle (%resolve-device-handle device "draw-indexed-primitives")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%graphics-device-draw-indexed-primitives
      handle (%native-of %primitive-type-to-native primitive-type "primitive-type")
      base-vertex min-vertex-index num-vertices start-index primitive-count)
     "draw-indexed-primitives" :object-type 'graphics-device))
  (values))

;;; --- the user-primitive draws ---------------------------------------------------
;;;
;;; These are the ones a consumer reaches for first: a triangle from a list of
;;; ordinary projected vertex objects, with no buffer to create and dispose. The
;;; C ABI's temporary-upload mechanism is not exposed -- the caller passes a Lisp
;;; sequence, this packs it through the same proven layouts SET-DATA uses, and
;;; the bytes live only for the duration of the call.
;;;
;;; The vertex declaration is required rather than inferred when the sequence
;;; holds something other than a standard vertex type, and is inferred through
;;; VERTEX-DECLARATION-OF -- the IVertexType projection -- when it holds one.
;;; That is exactly XNA's split between the overloads with and without a
;;; VertexDeclaration argument.

(defun %user-primitive-vertex-count (primitive-type primitive-count operation)
  "How many vertices PRIMITIVE-COUNT primitives of PRIMITIVE-TYPE span."
  (ecase primitive-type
    (:triangle-list (* 3 primitive-count))
    (:triangle-strip (+ 2 primitive-count))
    (:line-list (* 2 primitive-count))
    (:line-strip (+ 1 primitive-count))
    (t (error 'microsoft.xna.framework:cna-usage-error
              :operation operation
              :format-control "~s is not a PrimitiveType."
              :format-arguments (list primitive-type)))))

(defun %declaration-of-sequence (data vertex-declaration operation)
  "The declaration a user-primitive draw uses, given or inferred.

XNA has an overload with a VertexDeclaration and one without; the one without
finds it through IVertexType, which is VERTEX-DECLARATION-OF here. A sequence of
something with no declaration and no :VERTEX-DECLARATION is refused, because
there is nothing to infer a layout from."
  (or vertex-declaration
      (let ((sample (elt data 0)))
        (handler-case (vertex-declaration-of sample)
          (error ()
            (error 'microsoft.xna.framework:cna-usage-error
                   :operation operation
                   :format-control
                   "~a is not one of the standard vertex types, so its layout ~
                    cannot be inferred: pass :VERTEX-DECLARATION, which is XNA's ~
                    other overload."
                   :format-arguments (list (type-of sample))))))))

(defgeneric draw-user-primitives (graphics-device primitive-type data
                                  &key vertex-offset primitive-count vertex-declaration)
  (:documentation
   "GraphicsDevice.DrawUserPrimitives, both overloads.

    (draw-user-primitives device :triangle-list vertices :primitive-count 1)
    (draw-user-primitives device :triangle-list raw-bytes
                          :primitive-count 1 :vertex-declaration declaration)

DATA is a Lisp sequence whose layout this binding can prove -- see
src/graphics/buffer-data.lisp. Without :VERTEX-DECLARATION the layout comes from
the elements' own declaration through VERTEX-DECLARATION-OF, which is XNA's
IVertexType overload; with one it is used as given, which is XNA's other.

Nothing native outlives the call: the packed bytes are stack-allocated for its
duration, which is what XNA's own user-primitive path does."))

(defmethod draw-user-primitives ((device graphics-device) primitive-type data
                                 &key (vertex-offset 0) primitive-count
                                      vertex-declaration)
  (let ((operation "draw-user-primitives"))
    (check-type primitive-type primitive-type)
    (unless primitive-count
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control ":PRIMITIVE-COUNT is required; XNA has no overload without it."))
    (check-type vertex-offset (integer 0))
    (check-type primitive-count (signed-byte 32))
    (%check-primitive-count operation primitive-count)
    (%check-no-instancing device operation)
    (let* ((declaration (%declaration-of-sequence data vertex-declaration operation))
           (needed (%user-primitive-vertex-count primitive-type primitive-count operation))
           (available (- (length data) vertex-offset)))
      (when (< available needed)
        (error 'microsoft.xna.framework:cna-argument-out-of-range-error
               :operation operation :parameter-name "primitive-count"
               :format-control
               "~d ~(~a~) primitive(s) need ~d vertices and there are ~d after the ~
                offset."
               :format-arguments (list primitive-count primitive-type needed available)))
      (multiple-value-bind (bytes) (%pack-sequence data vertex-offset needed operation)
        (%with-native-declaration (native declaration operation)
          (let ((handle (%resolve-device-handle device operation)))
            (cffi:with-foreign-object (raw :uint8 (max 1 (length bytes)))
              (dotimes (index (length bytes))
                (setf (cffi:mem-aref raw :uint8 index) (aref bytes index)))
              (cffi:with-foreign-object
                  (primitives '(:struct cna-lisp.internal.ffi::cna-user-primitives))
                (%write-user-primitives primitives primitive-type raw native
                                        0 needed primitive-count)
                (cna-lisp.internal:check-result
                 (cna-lisp.internal.ffi::%graphics-device-draw-user-primitives
                  handle primitives)
                 operation :object-type 'graphics-device))))))))
  (values))

(defun %write-user-primitives (pointer primitive-type data declaration
                               vertex-offset num-vertices primitive-count)
  (cffi:foreign-funcall "memset" :pointer pointer :int 0
                        :size cna-lisp.internal.ffi::+sizeof-cna-user-primitives+ :void)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-user-primitives) ',name)))
    (setf (slot cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-user-primitives+
          (slot cna-lisp.internal.ffi::struct-version) 1
          (slot cna-lisp.internal.ffi::primitive-type)
          (%native-of %primitive-type-to-native primitive-type "primitive-type")
          ;; Always the raw stream: the bytes were packed here, from a layout this
          ;; binding proved, and the declaration says how to read them. Using
          ;; CNA's typed identities instead would send the four standard vertex
          ;; types down one path and everything else down another.
          (slot cna-lisp.internal.ffi::vertex-source)
          cna-lisp.internal.ffi::+user-vertex-source-raw-stream+
          (slot cna-lisp.internal.ffi::vertex-data) data
          (slot cna-lisp.internal.ffi::vertex-declaration) declaration
          (slot cna-lisp.internal.ffi::vertex-offset) vertex-offset
          (slot cna-lisp.internal.ffi::num-vertices) num-vertices
          (slot cna-lisp.internal.ffi::primitive-count) primitive-count))
  pointer)

(defgeneric draw-user-indexed-primitives (graphics-device primitive-type data indices
                                          &key vertex-offset num-vertices index-offset
                                               primitive-count vertex-declaration)
  (:documentation
   "GraphicsDevice.DrawUserIndexedPrimitives, all four overloads.

INDICES is a sequence of non-negative integers; a specialised (unsigned-byte 16)
or (unsigned-byte 32) array chooses the index width, and an unspecialised one
defaults to sixteen bits, which is what XNA's Int16 overload uses.

:NUM-VERTICES is XNA's numVertices and is required, as it is there."))

(defmethod draw-user-indexed-primitives ((device graphics-device) primitive-type
                                         data indices
                                         &key (vertex-offset 0) num-vertices
                                              (index-offset 0) primitive-count
                                              vertex-declaration)
  (let ((operation "draw-user-indexed-primitives"))
    (check-type primitive-type primitive-type)
    (unless (and num-vertices primitive-count)
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control
             ":NUM-VERTICES and :PRIMITIVE-COUNT are both required; every XNA ~
              DrawUserIndexedPrimitives overload takes both."))
    (check-type vertex-offset (integer 0))
    (check-type index-offset (integer 0))
    (check-type num-vertices (signed-byte 32))
    (check-type primitive-count (signed-byte 32))
    (unless (plusp num-vertices)
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation operation :parameter-name "num-vertices"
             :format-control "an indexed draw must span at least one vertex; ~d does not."
             :format-arguments (list num-vertices)))
    (%check-primitive-count operation primitive-count)
    (%check-no-instancing device operation)
    (let* ((declaration (%declaration-of-sequence data vertex-declaration operation))
           (needed (%user-primitive-vertex-count primitive-type primitive-count operation))
           (width (or (%declared-integer-width indices) 2))
           (index-count (- (length indices) index-offset)))
      (when (< index-count needed)
        (error 'microsoft.xna.framework:cna-argument-out-of-range-error
               :operation operation :parameter-name "primitive-count"
               :format-control
               "~d ~(~a~) primitive(s) need ~d index/indices and there are ~d after ~
                the offset."
               :format-arguments (list primitive-count primitive-type needed index-count)))
      (multiple-value-bind (bytes) (%pack-sequence data vertex-offset
                                                   (min num-vertices
                                                        (- (length data) vertex-offset))
                                                   operation)
        (%with-native-declaration (native declaration operation)
          (let ((handle (%resolve-device-handle device operation)))
            (cffi:with-foreign-object (raw :uint8 (max 1 (length bytes)))
              (dotimes (index (length bytes))
                (setf (cffi:mem-aref raw :uint8 index) (aref bytes index)))
              (cffi:with-foreign-object (index-data :uint8 (max 1 (* width needed)))
                (dotimes (index needed)
                  (let ((value (elt indices (+ index-offset index))))
                    (check-type value (integer 0))
                    (if (= width 2)
                        (setf (cffi:mem-aref index-data :uint16 index) value)
                        (setf (cffi:mem-aref index-data :uint32 index) value))))
                (cffi:with-foreign-object
                    (primitives '(:struct cna-lisp.internal.ffi::cna-user-primitives))
                  (cffi:with-foreign-object
                      (user-indices '(:struct cna-lisp.internal.ffi::cna-user-indices))
                    (%write-user-primitives primitives primitive-type raw native
                                            0 num-vertices primitive-count)
                    (cffi:foreign-funcall
                     "memset" :pointer user-indices :int 0
                     :size cna-lisp.internal.ffi::+sizeof-cna-user-indices+ :void)
                    (macrolet ((slot (name)
                                 `(cffi:foreign-slot-value
                                   user-indices
                                   '(:struct cna-lisp.internal.ffi::cna-user-indices)
                                   ',name)))
                      (setf (slot cna-lisp.internal.ffi::struct-size)
                            cna-lisp.internal.ffi::+sizeof-cna-user-indices+
                            (slot cna-lisp.internal.ffi::struct-version) 1
                            (slot cna-lisp.internal.ffi::index-element-size)
                            (%native-of %index-element-size-to-native
                                        (if (= width 2) :sixteen-bits :thirty-two-bits)
                                        "index-element-size")
                            (slot cna-lisp.internal.ffi::index-offset) 0
                            (slot cna-lisp.internal.ffi::index-data) index-data))
                    (cna-lisp.internal:check-result
                     (cna-lisp.internal.ffi::%graphics-device-draw-user-indexed-primitives
                      handle primitives user-indices)
                     operation :object-type 'graphics-device))))))))))
  (values))
