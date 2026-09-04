;;;; vertex-types.lisp --- VertexElement, VertexDeclaration, the four standard
;;;; vertex value types, and the IVertexType projection.
;;;;
;;;; All of it pure managed, and all of it read out of the pinned
;;;; Microsoft.Xna.Framework.Graphics assembly. CNA has routes of its own --
;;;; cna_vertex_type_get_stride and cna_vertex_type_copy_elements -- and they are
;;;; bound so the two can be compared in tests/native/vertex-types.lisp. They are
;;;; not what the projection computes from, for the same reason the math types do
;;;; not go through CNA: routing the contract through the runtime being tested
;;;; leaves nothing to cross-check.
;;;;
;;;; The interesting part is `VertexElementValidator', which XNA runs from both
;;;; VertexDeclaration constructors. Its five refusals are in a fixed order, each
;;;; with a different exception, and reproducing the order matters because an
;;;; element can fail more than one of them at once.

(in-package #:microsoft.xna.framework.graphics)

;;; --- VertexElement ------------------------------------------------------------

(defstruct (vertex-element (:constructor make-vertex-element
                               (offset vertex-element-format vertex-element-usage
                                &optional (usage-index 0)))
                           (:copier copy-vertex-element))
  "Microsoft.Xna.Framework.Graphics.VertexElement: one field of a vertex.

XNA's constructor takes all four, in this order, and does no validation of its
own -- an element only has to make sense once a VertexDeclaration is built from
it, which is where VertexElementValidator runs."
  (offset 0 :type (signed-byte 32))
  (vertex-element-format :single :type vertex-element-format)
  (vertex-element-usage :position :type vertex-element-usage)
  (usage-index 0 :type (signed-byte 32)))

(defun vertex-element-equal (left right)
  "VertexElement.Equals and op_Equality: all four components."
  (and (= (vertex-element-offset left) (vertex-element-offset right))
       (eq (vertex-element-vertex-element-format left)
           (vertex-element-vertex-element-format right))
       (eq (vertex-element-vertex-element-usage left)
           (vertex-element-vertex-element-usage right))
       (= (vertex-element-usage-index left) (vertex-element-usage-index right))))

;;; --- the validator ------------------------------------------------------------

(defparameter %vertex-element-format-sizes
  '((:single . 4) (:vector2 . 8) (:vector3 . 12) (:vector4 . 16) (:color . 4)
    (:byte4 . 4) (:short2 . 4) (:short4 . 8) (:normalized-short2 . 4)
    (:normalized-short4 . 8) (:half-vector2 . 4) (:half-vector4 . 8))
  "VertexElementValidator.GetTypeSize, exactly as its switch answers.

Two of these are the ones a reconstruction gets wrong by reasoning from the name:
Color is **4** bytes, not sixteen -- it is a packed BGRA, not four floats -- and
HalfVector4 is **8**, not sixteen, because a half is two bytes.")

(defun vertex-element-format-size (format)
  "The size in bytes of one element of FORMAT."
  (or (cdr (assoc format %vertex-element-format-sizes))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "vertex-element-format-size"
             :format-control "~s is not a VertexElementFormat member."
             :format-arguments (list format))))

(defun %vertex-stride-of (elements)
  "VertexElementValidator.GetVertexStride: the largest end of any element.

Not the sum of the sizes, and not the end of the last element: the maximum of
`offset + size' over all of them, which is what lets a declaration list its
elements in any order."
  (reduce #'max elements :initial-value 0
          :key (lambda (element)
                 (+ (vertex-element-offset element)
                    (vertex-element-format-size
                     (vertex-element-vertex-element-format element))))))

(defun %refuse-declaration (format-control &rest format-arguments)
  (error 'microsoft.xna.framework:cna-usage-error
         :operation "make-instance vertex-declaration"
         :format-control format-control
         :format-arguments format-arguments))

(defun %validate-vertex-elements (vertex-stride elements)
  "VertexElementValidator.Validate, in its own order.

The order is part of the contract, because an element can fail more than one of
these at once and XNA reports the first:

  1. a stride that is not positive;
  2. a stride that is not a multiple of four;
  then, per element and in this order:
  3. a usage outside the enumeration;
  4. an element that starts before zero or ends past the stride;
  5. an offset that is not a multiple of four;
  6. an earlier element with the same usage *and* the same usage index;
  7. an overlap with any byte an earlier element already claimed."
  (unless (plusp vertex-stride)
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "make-instance vertex-declaration"
           :parameter-name "vertex-stride"
           :format-control "a vertex stride must be positive; ~d is not."
           :format-arguments (list vertex-stride)))
  (unless (zerop (logand vertex-stride 3))
    (%refuse-declaration "a vertex stride must be a multiple of four; ~d is not."
                         vertex-stride))
  ;; One entry per *byte* of the vertex, holding the index of the element that
  ;; claimed it. XNA allocates exactly this array and fills it with -1.
  (let ((owner (make-array vertex-stride :initial-element nil)))
    (loop for element in elements
          for index from 0
          for offset = (vertex-element-offset element)
          for usage = (vertex-element-vertex-element-usage element)
          for size = (vertex-element-format-size
                      (vertex-element-vertex-element-format element))
          do (unless (typep usage 'vertex-element-usage)
               (%refuse-declaration "~s is not a VertexElementUsage member." usage))
             (when (or (minusp offset) (> (+ offset size) vertex-stride))
               (%refuse-declaration
                "the ~s element at usage index ~d runs from ~d to ~d, which is ~
                 outside a vertex of ~d bytes."
                usage (vertex-element-usage-index element)
                offset (+ offset size) vertex-stride))
             (unless (zerop (logand offset 3))
               (%refuse-declaration
                "a vertex element offset must be a multiple of four; ~d is not."
                offset))
             (loop for earlier in elements
                   for earlier-index from 0 below index
                   when (and (eq usage (vertex-element-vertex-element-usage earlier))
                             (= (vertex-element-usage-index element)
                                (vertex-element-usage-index earlier)))
                     do (%refuse-declaration
                         "two elements declare ~s at usage index ~d; a usage and a ~
                          usage index together name one element."
                         usage (vertex-element-usage-index element)))
             (loop for byte from offset below (+ offset size)
                   for claimed = (aref owner byte)
                   do (when claimed
                        (%refuse-declaration
                         "the ~s element at usage index ~d overlaps the ~s element at ~
                          usage index ~d, at byte ~d."
                         (vertex-element-vertex-element-usage (nth claimed elements))
                         (vertex-element-usage-index (nth claimed elements))
                         usage (vertex-element-usage-index element) byte))
                      (setf (aref owner byte) index))))
  (values))

;;; --- VertexDeclaration ---------------------------------------------------------

(defclass vertex-declaration ()
  ((elements :reader %declaration-elements)
   (vertex-stride :reader vertex-stride)
   (label :initform nil :reader %declaration-label))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.VertexDeclaration.

Constructed with a list of VERTEX-ELEMENTs and optionally a stride:

    (make-instance 'vertex-declaration :elements list)
    (make-instance 'vertex-declaration :elements list :vertex-stride 32)

Without a stride, the declaration computes one the way XNA's constructor does --
the largest `offset + size' over the elements. With one, the stride is taken as
given and the elements are validated against it, which is how a vertex with
padding at the end is declared.

XNA's VertexDeclaration derives from GraphicsResource. This one does not, for the
reason src/capabilities.lisp records for the state objects: CNA has no handle for
a vertex declaration, and a handle this binding invented would be a fake."))

(defmethod initialize-instance :after ((declaration vertex-declaration)
                                       &key elements (vertex-stride nil stride-supplied-p))
  (unless (and elements (listp elements))
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "make-instance vertex-declaration"
           :parameter-name "elements"
           :format-control
           "a vertex declaration needs at least one element; XNA throws ~
            ArgumentNullException for both a null array and an empty one."))
  (dolist (element elements)
    (check-type element vertex-element))
  ;; XNA clones the array, so a caller mutating theirs afterwards cannot change
  ;; the declaration. The elements themselves are value types, so copying the
  ;; list and each element is the same guarantee.
  (let* ((copied (mapcar #'copy-vertex-element elements))
         (stride (if stride-supplied-p vertex-stride (%vertex-stride-of copied))))
    (when stride-supplied-p
      (check-type vertex-stride (signed-byte 32)))
    (setf (slot-value declaration 'elements) copied
          (slot-value declaration 'vertex-stride) stride)
    (%validate-vertex-elements stride copied)))

(defgeneric get-vertex-elements (vertex-declaration)
  (:documentation
   "VertexDeclaration.GetVertexElements(): the declaration's elements.

A fresh list of fresh elements each call, as XNA's returns a fresh array: a
caller who mutates what they were given must not be able to change the
declaration."))

(defmethod get-vertex-elements ((declaration vertex-declaration))
  (mapcar #'copy-vertex-element (%declaration-elements declaration)))

;;; --- the four standard vertex value types ---------------------------------------

(defmacro %define-vertex-type (name (&rest fields) elements label)
  "Define one of XNA's standard vertex structs and its static VertexDeclaration.

FIELDS is (SLOT TYPE) per public field, in declaration order. ELEMENTS is the
element list of the static VertexDeclaration, read from the type's own class
constructor in the pinned assembly."
  (let* ((sname (symbol-name name))
         (constructor (intern (format nil "MAKE-~a" sname)))
         (equal-fn (intern (format nil "~a-EQUAL" sname)))
         (declaration-fn (intern (format nil "~a-VERTEX-DECLARATION" sname)))
         (cache (intern (format nil "*~a-VERTEX-DECLARATION*" sname)))
         (accessors (mapcar (lambda (f) (intern (format nil "~a-~a" sname (first f))))
                            fields)))
    `(progn
       (defstruct (,name (:constructor ,constructor (,@(mapcar #'first fields)))
                         (:copier ,(intern (format nil "COPY-~a" sname))))
         ,(format nil "Microsoft.Xna.Framework.Graphics.~a." sname)
         ,@(mapcar (lambda (f) (list (first f) nil :type (second f))) fields))
       (defun ,equal-fn (left right)
         ,(format nil "~a.Equals and op_Equality: every field." sname)
         (and ,@(loop for accessor in accessors
                      for (nil type) in fields
                      collect (ecase type
                                (microsoft.xna.framework:vector3
                                 `(microsoft.xna.framework:vector3-equal
                                   (,accessor left) (,accessor right)))
                                (microsoft.xna.framework:vector2
                                 `(microsoft.xna.framework:vector2-equal
                                   (,accessor left) (,accessor right)))
                                (microsoft.xna.framework:color
                                 `(microsoft.xna.framework:color-equal
                                   (,accessor left) (,accessor right)))))))
       (defvar ,cache nil)
       (defun ,declaration-fn ()
         ,(format nil "~a.VertexDeclaration: the static declaration, read from the ~
                       type's own class constructor in the pinned assembly.

The same object every call, as a `public static initonly' field is." sname)
         (or ,cache
             (setf ,cache
                   (let ((declaration
                           (make-instance 'vertex-declaration
                                          :elements (list ,@(loop for (offset format usage index)
                                                                    in elements
                                                                  collect `(make-vertex-element
                                                                            ,offset ,format ,usage
                                                                            ,index))))))
                     (setf (slot-value declaration 'label) ,label)
                     declaration))))
       (defmethod vertex-declaration-of ((value ,name)) (,declaration-fn))
       ',name)))

(defgeneric vertex-declaration-of (value)
  (:documentation
   "Microsoft.Xna.Framework.Graphics.IVertexType.VertexDeclaration.

XNA's IVertexType is a one-member interface whose only purpose is to let a
generic method ask a vertex value for its declaration. Common Lisp has no
interfaces and needs none: the projection is this generic function, with a method
on each vertex type, which is what the interface is for and is dispatched the
same way.

The name carries -OF because VERTEX-DECLARATION is the class."))

(%define-vertex-type vertex-position-color
    ((position microsoft.xna.framework:vector3)
     (color microsoft.xna.framework:color))
  ((0 :vector3 :position 0)
   (12 :color :color 0))
  "VertexPositionColor.VertexDeclaration")

(%define-vertex-type vertex-position-texture
    ((position microsoft.xna.framework:vector3)
     (texture-coordinate microsoft.xna.framework:vector2))
  ((0 :vector3 :position 0)
   (12 :vector2 :texture-coordinate 0))
  "VertexPositionTexture.VertexDeclaration")

(%define-vertex-type vertex-position-color-texture
    ((position microsoft.xna.framework:vector3)
     (color microsoft.xna.framework:color)
     (texture-coordinate microsoft.xna.framework:vector2))
  ((0 :vector3 :position 0)
   (12 :color :color 0)
   (16 :vector2 :texture-coordinate 0))
  "VertexPositionColorTexture.VertexDeclaration")

(%define-vertex-type vertex-position-normal-texture
    ((position microsoft.xna.framework:vector3)
     (normal microsoft.xna.framework:vector3)
     (texture-coordinate microsoft.xna.framework:vector2))
  ((0 :vector3 :position 0)
   (12 :vector3 :normal 0)
   (24 :vector2 :texture-coordinate 0))
  "VertexPositionNormalTexture.VertexDeclaration")

;;; --- translation to CNA's own vertex vocabulary ----------------------------------
;;;
;;; By name, as everywhere else in this binding, and for the reason the state
;;; enumerations made concrete: XNA and CNA happen to agree on these numbers, and
;;; a numeric pass-through would look correct right up to the first time they did
;;; not. These tables are private; nothing in the public API reaches CNA for a
;;; vertex declaration, because XNA is the authority for what one contains.
;;; tests/native/vertex-types.lisp is where the two are compared.

(defparameter %vertex-element-format-to-native
  `((:single . ,cna-lisp.internal.ffi::+vertex-element-format-single+)
    (:vector2 . ,cna-lisp.internal.ffi::+vertex-element-format-vector2+)
    (:vector3 . ,cna-lisp.internal.ffi::+vertex-element-format-vector3+)
    (:vector4 . ,cna-lisp.internal.ffi::+vertex-element-format-vector4+)
    (:color . ,cna-lisp.internal.ffi::+vertex-element-format-color+)
    (:byte4 . ,cna-lisp.internal.ffi::+vertex-element-format-byte4+)
    (:short2 . ,cna-lisp.internal.ffi::+vertex-element-format-short2+)
    (:short4 . ,cna-lisp.internal.ffi::+vertex-element-format-short4+)
    (:normalized-short2 . ,cna-lisp.internal.ffi::+vertex-element-format-normalized-short2+)
    (:normalized-short4 . ,cna-lisp.internal.ffi::+vertex-element-format-normalized-short4+)
    (:half-vector2 . ,cna-lisp.internal.ffi::+vertex-element-format-half-vector2+)
    (:half-vector4 . ,cna-lisp.internal.ffi::+vertex-element-format-half-vector4+)))

(defparameter %vertex-element-usage-to-native
  `((:position . ,cna-lisp.internal.ffi::+vertex-element-usage-position+)
    (:color . ,cna-lisp.internal.ffi::+vertex-element-usage-color+)
    (:texture-coordinate . ,cna-lisp.internal.ffi::+vertex-element-usage-texture-coordinate+)
    (:normal . ,cna-lisp.internal.ffi::+vertex-element-usage-normal+)
    (:binormal . ,cna-lisp.internal.ffi::+vertex-element-usage-binormal+)
    (:tangent . ,cna-lisp.internal.ffi::+vertex-element-usage-tangent+)
    (:blend-indices . ,cna-lisp.internal.ffi::+vertex-element-usage-blend-indices+)
    (:blend-weight . ,cna-lisp.internal.ffi::+vertex-element-usage-blend-weight+)
    (:depth . ,cna-lisp.internal.ffi::+vertex-element-usage-depth+)
    (:fog . ,cna-lisp.internal.ffi::+vertex-element-usage-fog+)
    (:point-size . ,cna-lisp.internal.ffi::+vertex-element-usage-point-size+)
    (:sample . ,cna-lisp.internal.ffi::+vertex-element-usage-sample+)
    (:tessellate-factor . ,cna-lisp.internal.ffi::+vertex-element-usage-tessellate-factor+)))
