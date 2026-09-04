;;;; effect-parameter.lisp --- EffectParameter and its collection.
;;;;
;;;; A shader's named inputs. XNA gives EffectParameter fifty-one public members:
;;;; eighteen `SetValue' overloads, two `SetValueTranspose', twenty-two
;;;; `GetValue*' and nine properties. CNA gives four tagged routes --
;;;; `set_value', `get_value', `set_values', `get_values', each taking a
;;;; CNA_EffectValueType -- plus a string pair and a texture pair, so the whole
;;;; surface is one table of value types and two shapes, scalar and array.
;;;;
;;;; **Three things about this surface are worth being plain about.**
;;;;
;;;; *No effect in this binding has ever been observed with a parameter.* CNA's
;;;; stock effects -- BasicEffect and its siblings -- carry no reflected
;;;; parameter graph; `cna_effect_get_parameters' answers a real, empty
;;;; collection for them. A populated one comes from compiled Effect Framework
;;;; bytecode, which needs `CNA_GRAPHICS_CAPABILITY_COMPILED_EFFECTS', which the
;;;; HEADLESS and SOFTWARE renderers used for qualification here do not have.
;;;; docs/limitations.md records that.
;;;;
;;;; *So the value surface is exercised against CNA directly.* Rather than write
;;;; fifty-one members and never once run them, the test suite builds a
;;;; standalone parameter collection through `cna_effect_parameter_create' and
;;;; round-trips every value type through this code. That proves the marshalling
;;;; -- which is the part that can be wrong in a way a reader would not see -- and
;;;; it does not prove that a real shader's parameter behaves this way, which
;;;; nothing available here could prove.
;;;;
;;;; *Two of the twenty-two getters are missing, on purpose.* XNA's
;;;; `GetValueTexture3D' and `GetValueTextureCube' return `Texture3D' and
;;;; `TextureCube', which this binding does not project. CNA has the routes; the
;;;; public types do not exist, and inventing them would be worse than the
;;;; absence. They are recorded missing, and EffectParameter is partial for it.

(in-package #:microsoft.xna.framework.graphics)

;;; --- the value-type table --------------------------------------------------
;;;
;;; One row per CNA_EffectValueType: the keyword a consumer names, the native
;;; tag, the size of one element in bytes, and how one element is read and
;;; written. Everything below is driven from it, so a value type cannot be
;;; handled two different ways in two different places.

(defstruct (%effect-value-kind (:constructor %make-effect-value-kind
                                   (keyword native size reader writer))
                               (:copier nil))
  keyword native size reader writer)

(defun %read-effect-single (pointer) (cffi:mem-ref pointer :float))
(defun %write-effect-single (pointer value)
  (setf (cffi:mem-ref pointer :float) (float value 1.0f0)))

(defun %read-effect-int32 (pointer) (cffi:mem-ref pointer :int32))
(defun %write-effect-int32 (pointer value)
  (check-type value (signed-byte 32))
  (setf (cffi:mem-ref pointer :int32) value))

(defun %read-effect-boolean (pointer)
  (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref pointer :uint8)))
(defun %write-effect-boolean (pointer value)
  (setf (cffi:mem-ref pointer :uint8) (cna-lisp.internal.ffi:cna-bool-of value)))

(defun %read-effect-quaternion (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-quaternion) ',name)))
    (microsoft.xna.framework:make-quaternion (slot cna-lisp.internal.ffi::x)
                                             (slot cna-lisp.internal.ffi::y)
                                             (slot cna-lisp.internal.ffi::z)
                                             (slot cna-lisp.internal.ffi::w))))

(defun %write-effect-quaternion (pointer value)
  (check-type value microsoft.xna.framework:quaternion)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-quaternion) ',name)))
    (setf (slot cna-lisp.internal.ffi::x) (microsoft.xna.framework:quaternion-x value)
          (slot cna-lisp.internal.ffi::y) (microsoft.xna.framework:quaternion-y value)
          (slot cna-lisp.internal.ffi::z) (microsoft.xna.framework:quaternion-z value)
          (slot cna-lisp.internal.ffi::w) (microsoft.xna.framework:quaternion-w value))))

(defun %write-effect-vector2 (pointer value)
  (check-type value microsoft.xna.framework:vector2)
  (%write-vector2 pointer value))

(defun %write-effect-vector3 (pointer value)
  (check-type value microsoft.xna.framework:vector3)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-vector-3) ',name)))
    (setf (slot cna-lisp.internal.ffi::x) (microsoft.xna.framework:vector3-x value)
          (slot cna-lisp.internal.ffi::y) (microsoft.xna.framework:vector3-y value)
          (slot cna-lisp.internal.ffi::z) (microsoft.xna.framework:vector3-z value))))

(defun %write-effect-vector4 (pointer value)
  (check-type value microsoft.xna.framework:vector4)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-vector-4) ',name)))
    (setf (slot cna-lisp.internal.ffi::x) (microsoft.xna.framework:vector4-x value)
          (slot cna-lisp.internal.ffi::y) (microsoft.xna.framework:vector4-y value)
          (slot cna-lisp.internal.ffi::z) (microsoft.xna.framework:vector4-z value)
          (slot cna-lisp.internal.ffi::w) (microsoft.xna.framework:vector4-w value))))

(defun %write-effect-matrix (pointer value)
  (check-type value microsoft.xna.framework:matrix)
  (%write-matrix pointer value))

(defparameter %effect-value-kinds
  (list (%make-effect-value-kind
         :boolean cna-lisp.internal.ffi::+effect-value-boolean+ 1
         #'%read-effect-boolean #'%write-effect-boolean)
        (%make-effect-value-kind
         :int32 cna-lisp.internal.ffi::+effect-value-int32+ 4
         #'%read-effect-int32 #'%write-effect-int32)
        (%make-effect-value-kind
         :single cna-lisp.internal.ffi::+effect-value-single+ 4
         #'%read-effect-single #'%write-effect-single)
        (%make-effect-value-kind
         :matrix cna-lisp.internal.ffi::+effect-value-matrix+
         cna-lisp.internal.ffi::+sizeof-cna-matrix+
         #'%read-matrix #'%write-effect-matrix)
        (%make-effect-value-kind
         :matrix-transpose cna-lisp.internal.ffi::+effect-value-matrix-transpose+
         cna-lisp.internal.ffi::+sizeof-cna-matrix+
         #'%read-matrix #'%write-effect-matrix)
        (%make-effect-value-kind
         :quaternion cna-lisp.internal.ffi::+effect-value-quaternion+
         cna-lisp.internal.ffi::+sizeof-cna-quaternion+
         #'%read-effect-quaternion #'%write-effect-quaternion)
        (%make-effect-value-kind
         :vector2 cna-lisp.internal.ffi::+effect-value-vector2+
         cna-lisp.internal.ffi::+sizeof-cna-vector-2+
         #'%read-vector2 #'%write-effect-vector2)
        (%make-effect-value-kind
         :vector3 cna-lisp.internal.ffi::+effect-value-vector3+
         cna-lisp.internal.ffi::+sizeof-cna-vector-3+
         #'%read-vector3 #'%write-effect-vector3)
        (%make-effect-value-kind
         :vector4 cna-lisp.internal.ffi::+effect-value-vector4+
         cna-lisp.internal.ffi::+sizeof-cna-vector-4+
         #'%read-vector4 #'%write-effect-vector4))
  "Every value shape an effect parameter can hold, and how one element travels.")

(defun %effect-value-kind (keyword operation)
  (or (find keyword %effect-value-kinds :key #'%effect-value-kind-keyword)
      (error 'microsoft.xna.framework:cna-usage-error
             :operation operation
             :format-control
             "~s is not an effect parameter value type. XNA's SetValue and GetValue ~
              overloads cover ~{~s~^, ~}."
             :format-arguments (list keyword
                                     (mapcar #'%effect-value-kind-keyword
                                             %effect-value-kinds)))))

;;; --- EffectParameter -------------------------------------------------------

(defclass effect-parameter (%effect-view)
  ((%name :reader effect-parameter-name)
   (%semantic :reader effect-parameter-semantic)
   (%row-count :reader effect-parameter-row-count)
   (%column-count :reader effect-parameter-column-count)
   (%parameter-class :reader effect-parameter-parameter-class)
   (%parameter-type :reader effect-parameter-parameter-type)
   (%elements :reader effect-parameter-elements)
   (%structure-members :reader effect-parameter-structure-members)
   (%annotations :reader effect-parameter-annotations)
   (%elements-handle :initform 0 :accessor %parameter-elements-handle)
   (%structure-members-handle :initform 0 :accessor %parameter-structure-members-handle)
   (%annotations-handle :initform 0 :accessor %parameter-annotations-handle)
   (%texture :initform nil :accessor %parameter-texture
             :documentation
             "The TEXTURE-2D last set here, so the getter can answer the object
rather than a handle. See EFFECT-PARAMETER-VALUE-TEXTURE."))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.EffectParameter: one named shader input.

XNA's overload sets collapse into two generic functions carrying the value type
as a keyword:

    (setf (effect-parameter-value parameter :vector3) v)
    (effect-parameter-value parameter :vector3)
    (setf (effect-parameter-values parameter :single) #(1.0 2.0 3.0))
    (effect-parameter-values parameter :single 3)

`SetValueTranspose' is the :MATRIX-TRANSPOSE value type rather than a second
function, because that is exactly what it is: the same value in transposed
storage, and CNA carries it as its own CNA_EffectValueType.

The array getters take a count, as XNA's do -- `GetValueSingleArray(int count)'."))

(defclass effect-parameter-collection (%effect-collection) ()
  (:documentation "Microsoft.Xna.Framework.Graphics.EffectParameterCollection."))

(defmethod %collection-element-name ((element effect-parameter))
  (effect-parameter-name element))

(defgeneric collection-parameter-by-semantic (collection semantic)
  (:documentation
   "EffectParameterCollection.GetParameterBySemantic(string).

Answers NIL when nothing carries that semantic, which is what XNA's does."))

(defmethod collection-parameter-by-semantic ((collection effect-parameter-collection)
                                             (semantic string))
  (find semantic (%collection-items collection)
        :key #'effect-parameter-semantic :test #'string=))

;;; --- reading the graph out of CNA ------------------------------------------

(defparameter +effect-parameter-nesting-limit+ 32
  "How deep a parameter's elements and structure members are followed.

An effect's parameter graph is a tree, and CNA validates the bytecode that
produces one. The limit is here so that a graph which is *not* a tree -- which
would mean a defect on the far side of the ABI -- is reported rather than
followed forever.")

(defun %read-parameter-info (handle parameter)
  (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-effect-parameter-info))
    (cffi:foreign-funcall "memset" :pointer info :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-effect-parameter-info+ :void)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   info '(:struct cna-lisp.internal.ffi::cna-effect-parameter-info) ',name)))
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-effect-parameter-info+
            (slot cna-lisp.internal.ffi::struct-version) 1)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-get-info handle info)
       "effect-parameter" :object-type 'effect-parameter)
      (setf (slot-value parameter '%row-count) (slot cna-lisp.internal.ffi::row-count)
            (slot-value parameter '%column-count) (slot cna-lisp.internal.ffi::column-count)
            (slot-value parameter '%parameter-class)
            (%effect-parameter-class-from-native (slot cna-lisp.internal.ffi::parameter-class))
            (slot-value parameter '%parameter-type)
            (%effect-parameter-type-from-native (slot cna-lisp.internal.ffi::parameter-type)))))
  parameter)

(defun %make-parameter (handle effect depth)
  (when (> depth +effect-parameter-nesting-limit+)
    (error 'microsoft.xna.framework:cna-invalid-object-error
           :operation "effect parameters"
           :object-type 'effect-parameter
           :format-control
           "an effect parameter graph nested deeper than ~d. A parameter's elements ~
            and structure members form a tree; this one does not, so it is reported ~
            rather than followed."
           :format-arguments (list +effect-parameter-nesting-limit+)))
  (let ((parameter (make-instance 'effect-parameter :handle handle :effect effect)))
    (%adopt-view parameter effect)
    (setf (slot-value parameter '%name)
          (cna-lisp.internal:count-then-copy-string
           (lambda (out)
             (cna-lisp.internal.ffi::%effect-parameter-get-name-byte-count handle out))
           (lambda (buffer capacity out)
             (cna-lisp.internal.ffi::%effect-parameter-copy-name handle buffer capacity out))
           "effect-parameter-name")
          (slot-value parameter '%semantic)
          (cna-lisp.internal:count-then-copy-string
           (lambda (out)
             (cna-lisp.internal.ffi::%effect-parameter-get-semantic-byte-count handle out))
           (lambda (buffer capacity out)
             (cna-lisp.internal.ffi::%effect-parameter-copy-semantic handle buffer capacity out))
           "effect-parameter-semantic"))
    (%read-parameter-info handle parameter)
    (macrolet ((sub-collection (route handle-accessor slot)
                 `(cffi:with-foreign-object (out :uint64)
                    (cna-lisp.internal:check-result
                     (,route handle out) "effect-parameter" :object-type 'effect-parameter)
                    (let ((child (cffi:mem-ref out :uint64)))
                      (setf (,handle-accessor parameter) child
                            (slot-value parameter ',slot)
                            (%build-parameter-collection child effect (1+ depth)))))))
      (sub-collection cna-lisp.internal.ffi::%effect-parameter-get-elements
                      %parameter-elements-handle %elements)
      (sub-collection cna-lisp.internal.ffi::%effect-parameter-get-structure-members
                      %parameter-structure-members-handle %structure-members))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-get-annotations handle out)
       "effect-parameter-annotations" :object-type 'effect-parameter)
      (let ((child (cffi:mem-ref out :uint64)))
        (setf (%parameter-annotations-handle parameter) child
              (slot-value parameter '%annotations)
              (%build-annotation-collection child effect))))
    parameter))

(defun %build-parameter-collection (collection-handle effect depth)
  (let ((count (cffi:with-foreign-object (out :uint64)
                 (cna-lisp.internal:check-result
                  (cna-lisp.internal.ffi::%effect-parameter-collection-get-count
                   collection-handle out)
                  "effect parameters" :object-type 'effect-parameter-collection)
                 (cffi:mem-ref out :uint64))))
    (let ((items (make-array count)))
      (dotimes (index count)
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%effect-parameter-collection-get-at
            collection-handle index out)
           "effect parameters" :object-type 'effect-parameter-collection)
          (setf (aref items index)
                (%make-parameter (cffi:mem-ref out :uint64) effect depth))))
      (make-instance 'effect-parameter-collection :items items))))

(defun %destroy-parameter-collection (collection)
  "Give back every handle under a parameter collection, leaves first."
  (when collection
    (loop for parameter across (%collection-items collection)
          do (loop for annotation across (%collection-items
                                          (effect-parameter-annotations parameter))
                   do (%destroy-view (cna-lisp.internal:handle-of annotation)
                                     #'cna-lisp.internal.ffi::%effect-annotation-destroy))
             (%destroy-view (%parameter-annotations-handle parameter)
                            #'cna-lisp.internal.ffi::%effect-annotation-collection-destroy)
             (%destroy-parameter-collection (effect-parameter-elements parameter))
             (%destroy-view (%parameter-elements-handle parameter)
                            #'cna-lisp.internal.ffi::%effect-parameter-collection-destroy)
             (%destroy-parameter-collection (effect-parameter-structure-members parameter))
             (%destroy-view (%parameter-structure-members-handle parameter)
                            #'cna-lisp.internal.ffi::%effect-parameter-collection-destroy)
             (%destroy-view (cna-lisp.internal:handle-of parameter)
                            #'cna-lisp.internal.ffi::%effect-parameter-destroy))))

;;; --- the value surface -----------------------------------------------------

(defgeneric effect-parameter-value (parameter value-type)
  (:documentation
   "EffectParameter's GetValue<T>() family, with the type named rather than
inferred.

    (effect-parameter-value parameter :single)     GetValueSingle()
    (effect-parameter-value parameter :matrix)     GetValueMatrix()

:MATRIX-TRANSPOSE is GetValueMatrixTranspose()."))

(defgeneric (setf effect-parameter-value) (value parameter value-type)
  (:documentation
   "EffectParameter's SetValue overloads, with the type named rather than
inferred. :MATRIX-TRANSPOSE is SetValueTranspose."))

(defmethod effect-parameter-value ((parameter effect-parameter) value-type)
  (let* ((operation "effect-parameter-value")
         (kind (%effect-value-kind value-type operation))
         (handle (%view-handle parameter operation)))
    (cffi:with-foreign-object (buffer :uint8 (%effect-value-kind-size kind))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-get-value
        handle (%effect-value-kind-native kind) buffer)
       operation :object-type 'effect-parameter)
      (funcall (%effect-value-kind-reader kind) buffer))))

(defmethod (setf effect-parameter-value) (value (parameter effect-parameter) value-type)
  (let* ((operation "(setf effect-parameter-value)")
         (kind (%effect-value-kind value-type operation))
         (handle (%view-handle parameter operation)))
    (cffi:with-foreign-object (buffer :uint8 (%effect-value-kind-size kind))
      (funcall (%effect-value-kind-writer kind) buffer value)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-set-value
        handle (%effect-value-kind-native kind) buffer)
       operation :object-type 'effect-parameter)))
  value)

(defgeneric effect-parameter-values (parameter value-type count)
  (:documentation
   "EffectParameter's GetValue*Array(int count) family.

Answers a simple vector of COUNT elements, freshly made, as XNA's does."))

(defgeneric (setf effect-parameter-values) (values parameter value-type)
  (:documentation
   "EffectParameter's array SetValue overloads.

VALUES is any Lisp sequence of the value type's elements; each is written through
the same single-element writer the scalar setter uses, so an array and a scalar
cannot disagree about a layout."))

(defmethod effect-parameter-values ((parameter effect-parameter) value-type count)
  (let* ((operation "effect-parameter-values")
         (kind (%effect-value-kind value-type operation))
         (handle (%view-handle parameter operation)))
    (check-type count (integer 0))
    (let ((size (%effect-value-kind-size kind)))
      (cffi:with-foreign-objects ((buffer :uint8 (max 1 (* size count)))
                                  (written :uint64))
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%effect-parameter-get-values
          handle (%effect-value-kind-native kind) count buffer (* size count) written)
         operation :object-type 'effect-parameter)
        (let* ((answered (cffi:mem-ref written :uint64))
               (result (make-array answered)))
          (dotimes (index answered result)
            (setf (aref result index)
                  (funcall (%effect-value-kind-reader kind)
                           (cffi:inc-pointer buffer (* index size))))))))))

(defmethod (setf effect-parameter-values) (values (parameter effect-parameter) value-type)
  (let* ((operation "(setf effect-parameter-values)")
         (kind (%effect-value-kind value-type operation))
         (handle (%view-handle parameter operation))
         (elements (coerce values 'vector))
         (size (%effect-value-kind-size kind)))
    (cffi:with-foreign-object (buffer :uint8 (max 1 (* size (length elements))))
      (dotimes (index (length elements))
        (funcall (%effect-value-kind-writer kind)
                 (cffi:inc-pointer buffer (* index size)) (aref elements index)))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-set-values
        handle (%effect-value-kind-native kind) buffer (length elements))
       operation :object-type 'effect-parameter)))
  values)

(defgeneric effect-parameter-value-string (parameter)
  (:documentation "EffectParameter.GetValueString()."))

(defgeneric (setf effect-parameter-value-string) (value parameter)
  (:documentation "EffectParameter.SetValue(string)."))

(defmethod effect-parameter-value-string ((parameter effect-parameter))
  (let ((handle (%view-handle parameter "effect-parameter-value-string")))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%effect-parameter-get-value-string-byte-count handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%effect-parameter-copy-value-string handle buffer capacity out))
     "effect-parameter-value-string")))

(defmethod (setf effect-parameter-value-string) (value (parameter effect-parameter))
  (check-type value string)
  (let ((handle (%view-handle parameter "(setf effect-parameter-value-string)")))
    (cna-lisp.internal:with-utf8-view (data length value)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-set-value-string handle data length)
       "(setf effect-parameter-value-string)" :object-type 'effect-parameter)))
  value)

(defparameter %effect-texture-slots
  `((:texture . ,cna-lisp.internal.ffi::+effect-texture-base+)
    (:texture-2d . ,cna-lisp.internal.ffi::+effect-texture-2d+))
  "The texture overloads this binding can express.

CNA also has CNA_EFFECT_TEXTURE_3D and CNA_EFFECT_TEXTURE_CUBE. XNA's
GetValueTexture3D and GetValueTextureCube return Texture3D and TextureCube, which
are not projected types here, so those two members are recorded missing rather
than answered with something invented. The base :TEXTURE slot is a setter only,
which is also what CNA says of it and what XNA's SetValue(Texture) is.")

(defgeneric effect-parameter-value-texture (parameter)
  (:documentation
   "EffectParameter.GetValueTexture2D().

Answers the TEXTURE-2D this parameter was last set to, cross-checked against the
handle CNA reports, and NIL when nothing has been set. It has to work that way
for the reason GetVertexBuffers does: CNA's ABI has no route from a native handle
back to the object that names it, so a binding can either remember what it bound
or invent an object -- and inventing one would hand back a Texture2D with no
owner, no dimensions and no disposal story.

There is no getter for the base Texture overload: XNA has none, and neither does
CNA."))

(defgeneric (setf effect-parameter-value-texture) (texture parameter)
  (:documentation
   "EffectParameter.SetValue(Texture).

The overload is chosen by what is passed: a TEXTURE-2D goes to CNA's Texture2D
slot, and any other TEXTURE to the base one, which is the distinction XNA's
single SetValue(Texture) makes internally."))

(defmethod effect-parameter-value-texture ((parameter effect-parameter))
  (let ((handle (%view-handle parameter "effect-parameter-value-texture"))
        (remembered (%parameter-texture parameter)))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-get-value-texture
        handle (cdr (assoc :texture-2d %effect-texture-slots)) out)
       "effect-parameter-value-texture" :object-type 'effect-parameter)
      (let ((native (cffi:mem-ref out :uint64)))
        (cond ((zerop native) nil)
              ((and remembered
                    (not (microsoft.xna.framework:disposed-p remembered))
                    (= native (cna-lisp.internal:handle-of remembered)))
               remembered)
              (t
               (error 'microsoft.xna.framework:cna-invalid-state-error
                      :operation "effect-parameter-value-texture"
                      :object-type 'effect-parameter
                      :format-control
                      "CNA reports a texture on this parameter that this binding did ~
                       not set. There is no way back from a native texture handle to ~
                       the object that names it, so this refuses rather than ~
                       answering a Texture2D it would have to invent.")))))))

(defmethod (setf effect-parameter-value-texture) (texture (parameter effect-parameter))
  (let ((handle (%view-handle parameter "(setf effect-parameter-value-texture)")))
    (when texture (check-type texture texture))
    (let ((slot (cdr (assoc (if (typep texture 'texture-2d) :texture-2d :texture)
                            %effect-texture-slots))))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%effect-parameter-set-value-texture
        handle slot
        (if texture
            (progn (cna-lisp.internal:check-usable texture "effect parameter texture")
                   (cna-lisp.internal:handle-of texture))
            0))
       "(setf effect-parameter-value-texture)" :object-type 'effect-parameter)
      (setf (%parameter-texture parameter) (and (typep texture 'texture-2d) texture))))
  texture)
