;;;; buffer-data.lisp --- how a Lisp sequence becomes buffer bytes, and back.
;;;;
;;;; XNA's buffer transfer API is generic: `SetData<T>(T[] data)' will take an
;;;; array of anything blittable and copy its bytes. Common Lisp has no generic
;;;; method instantiation and no `where T : struct', so the shape of the
;;;; projection has to be decided rather than inherited, and the decision here is
;;;; deliberately narrow:
;;;;
;;;;   **A transfer is accepted only when this file can prove the binary layout
;;;;   of every element.**
;;;;
;;;; There is no "vector of anything" sink. An element type this file does not
;;;; have a layout for is refused with a condition that names it and lists what
;;;; is supported, because the alternative is writing whatever a Lisp object
;;;; happens to contain into native memory.
;;;;
;;;; What is supported, and where each layout comes from:
;;;;
;;;;   (unsigned-byte 8)   1 byte      raw bytes, the escape hatch for a layout
;;;;                                   the caller computed themselves
;;;;   (unsigned-byte 16)  2 bytes     a sixteen-bit index
;;;;   (unsigned-byte 32)  4 bytes     a thirty-two-bit index
;;;;   single-float        4 bytes     binary32, as XNA's Single
;;;;   COLOR               4 bytes     the packed R G B A value
;;;;   VECTOR2/3/4         8/12/16     consecutive binary32 components
;;;;   the four standard   the type's own VertexDeclaration stride, with each
;;;;   vertex types        field written at that declaration's own offset
;;;;
;;;; The vertex writers are driven by the declarations rather than by a
;;;; hand-copied offset, so a vertex type whose declaration says its texture
;;;; coordinate is at 24 writes it at 24. tests/unit/buffer-data.lisp asserts
;;;; the packed bytes against the declaration for all four.

(in-package #:microsoft.xna.framework.graphics)

(define-condition unsupported-element-type () ()
  (:documentation "Never signalled; see %REFUSE-ELEMENT-TYPE."))

;;; The two transfer generics, defined here because two unrelated closures answer
;;; them -- the vertex and index buffers, and Texture2D -- and a generic function
;;; defined twice is a generic function whose lambda list depends on load order.
;;; The keyword set is the union of what the two families' overloads need; each
;;; method refuses the combinations its own type has no overload for.

(defgeneric set-data (resource data &key start-index element-count offset-in-bytes
                                         vertex-stride options level source
                                         left top right bottom front back)
  (:documentation
   "SetData, on a vertex buffer, an index buffer, a Texture2D or a Texture3D.

DATA is a Lisp sequence whose element layout this binding can prove: an octet,
sixteen-bit or thirty-two-bit integer vector, a vector of SINGLE-FLOATs, COLORs,
VECTOR2/3/4s, or one of the standard vertex types. An element type with no proven
layout is refused by name rather than written into native memory.

Which keywords are legal depends on the resource, because XNA's overloads do:
`:OFFSET-IN-BYTES', `:VERTEX-STRIDE' and `:OPTIONS' are a buffer's, `:LEVEL' and
`:SOURCE' are a Texture2D's, and `:LEFT', `:TOP', `:RIGHT', `:BOTTOM', `:FRONT'
and `:BACK' are a Texture3D's -- whose box overload names seven coordinates
rather than a nullable rectangle, because XNA's does. Each method refuses the
others by name."))

(defgeneric get-data (resource into &key start-index element-count offset-in-bytes
                                         vertex-stride level source
                                         left top right bottom front back)
  (:documentation
   "GetData, on a vertex buffer, an index buffer, a Texture2D or a Texture3D,
reading into INTO.

XNA fills the caller's array, so this does too, and answers it. The element type
of INTO decides what is read, by the same proven layouts SET-DATA writes."))

(defun %refuse-element-type (operation element)
  (error 'microsoft.xna.framework:cna-usage-error
         :operation operation
         :format-control
         "a buffer transfer cannot take ~a elements: this binding writes only the ~
          layouts it can prove. Supported: (unsigned-byte 8), (unsigned-byte 16), ~
          (unsigned-byte 32), SINGLE-FLOAT, COLOR, VECTOR2, VECTOR3, VECTOR4 and ~
          the standard vertex types (VERTEX-POSITION-COLOR, ~
          VERTEX-POSITION-TEXTURE, VERTEX-POSITION-COLOR-TEXTURE, ~
          VERTEX-POSITION-NORMAL-TEXTURE). For anything else, pack it into an ~
          (unsigned-byte 8) vector yourself, where the layout is yours to state."
         :format-arguments (list (type-of element))))

(defgeneric %element-byte-size (element)
  (:documentation
   "The number of bytes one ELEMENT occupies in a buffer.

Dispatched on a *sample* element, because a Lisp sequence carries no element type
of its own. Every transfer checks that every element is of the sample's type, so
a heterogeneous sequence is refused rather than written partly."))

(defgeneric %write-element (pointer offset element)
  (:documentation "Write ELEMENT into POINTER at byte OFFSET."))

(defgeneric %read-element (pointer offset prototype)
  (:documentation
   "Read one element of PROTOTYPE's type from POINTER at byte OFFSET.

PROTOTYPE says which type to read; its value is not used."))

;;; --- the scalar layouts ---------------------------------------------------------

(macrolet ((define-scalar-layout (specialiser size cffi-type
                                  &key (write 'element) (read 'value))
             `(progn
                (defmethod %element-byte-size ((element ,specialiser))
                  (declare (ignorable element))
                  ,size)
                (defmethod %write-element (pointer offset (element ,specialiser))
                  (setf (cffi:mem-ref pointer ,cffi-type offset) ,write))
                (defmethod %read-element (pointer offset (prototype ,specialiser))
                  (declare (ignorable prototype))
                  (let ((value (cffi:mem-ref pointer ,cffi-type offset)))
                    (declare (ignorable value))
                    ,read)))))
  ;; An integer's width is not knowable from the value, so the *declared* element
  ;; type of the vector decides it. %SEQUENCE-LAYOUT below reads that; these
  ;; methods exist for the sample-dispatch path and default an integer to 32 bits,
  ;; which is what an index array without a declared element type means.
  (define-scalar-layout integer 4 :uint32)
  (define-scalar-layout single-float 4 :float)
  (define-scalar-layout double-float 4 :float
    :write (coerce element 'single-float) :read (coerce value 'double-float)))

(defmethod %element-byte-size ((element microsoft.xna.framework:color))
  (declare (ignorable element))
  4)

(defmethod %write-element (pointer offset (element microsoft.xna.framework:color))
  (setf (cffi:mem-ref pointer :uint32 offset)
        (microsoft.xna.framework:color-packed-value element)))

(defmethod %read-element (pointer offset (prototype microsoft.xna.framework:color))
  (declare (ignorable prototype))
  (microsoft.xna.framework:color-from-packed-value
   (cffi:mem-ref pointer :uint32 offset)))

(macrolet ((define-vector-layout (type size &rest accessors)
             `(progn
                (defmethod %element-byte-size ((element ,type))
                  (declare (ignorable element))
                  ,size)
                (defmethod %write-element (pointer offset (element ,type))
                  ,@(loop for accessor in accessors
                          for index from 0
                          collect `(setf (cffi:mem-ref pointer :float (+ offset ,(* 4 index)))
                                         (,accessor element))))
                (defmethod %read-element (pointer offset (prototype ,type))
                  (declare (ignorable prototype))
                  (,(intern (format nil "MAKE-~a" (symbol-name type))
                            :microsoft.xna.framework)
                   ,@(loop for index from 0 below (length accessors)
                           collect `(cffi:mem-ref pointer :float
                                                  (+ offset ,(* 4 index)))))))))
  (define-vector-layout microsoft.xna.framework:vector2 8
    microsoft.xna.framework:vector2-x microsoft.xna.framework:vector2-y)
  (define-vector-layout microsoft.xna.framework:vector3 12
    microsoft.xna.framework:vector3-x microsoft.xna.framework:vector3-y
    microsoft.xna.framework:vector3-z)
  (define-vector-layout microsoft.xna.framework:vector4 16
    microsoft.xna.framework:vector4-x microsoft.xna.framework:vector4-y
    microsoft.xna.framework:vector4-z microsoft.xna.framework:vector4-w))

;;; --- what a Lisp sequence's elements are --------------------------------------

(defun %declared-integer-width (sequence)
  "The byte width an integer vector's own element type states, or NIL.

A specialised array is the only thing that can say whether its integers are
sixteen or thirty-two bits wide, and an index buffer's element size has to match
the array it is filled from. A general vector of integers says nothing, and this
answers NIL for it so the caller can decide."
  (when (and (arrayp sequence) (not (eq (array-element-type sequence) t)))
    (let ((type (array-element-type sequence)))
      (cond ((subtypep type '(unsigned-byte 8)) 1)
            ((subtypep type '(unsigned-byte 16)) 2)
            ((subtypep type '(unsigned-byte 32)) 4)
            ((subtypep type '(signed-byte 16)) 2)
            ((subtypep type '(signed-byte 32)) 4)))))

(defun %sequence-layout (sequence operation)
  "Answer (VALUES SAMPLE BYTE-SIZE) for SEQUENCE, or refuse.

An empty sequence has no sample and no layout, which is refused rather than
guessed: a zero-element transfer with an unknown stride would be a transfer whose
shape nobody checked."
  (when (zerop (length sequence))
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation operation
           :parameter-name "data"
           :format-control
           "an empty sequence has no element layout to transfer; XNA's SetData ~
            takes an array with elements in it."))
  (let* ((sample (elt sequence 0))
         (width (and (integerp sample) (%declared-integer-width sequence)))
         (size (or width
                   (handler-case (%element-byte-size sample)
                     (error () (%refuse-element-type operation sample))))))
    ;; A heterogeneous sequence is refused: one element's layout is not the
    ;; others'. Checked here rather than discovered halfway through a write.
    (let ((expected (type-of sample)))
      (declare (ignorable expected))
      (map nil (lambda (element)
                 (unless (typep element (if (integerp sample) 'integer expected))
                   (error 'microsoft.xna.framework:cna-usage-error
                          :operation operation
                          :format-control
                          "a buffer transfer needs one element type: element 0 is ~a ~
                           and another is ~a."
                          :format-arguments (list expected (type-of element)))))
               sequence))
    (values sample size)))

(defun %pack-sequence (sequence start-index element-count operation
                       &key stride)
  "Copy ELEMENT-COUNT elements of SEQUENCE from START-INDEX into fresh bytes.

Answers (VALUES OCTET-VECTOR ELEMENT-BYTE-SIZE). STRIDE, when given, is the byte
distance between elements in the destination and must not be smaller than the
element -- that is XNA's vertexStride parameter, which is how a caller writes into
a buffer whose vertices are wider than the data they are supplying."
  (multiple-value-bind (sample size) (%sequence-layout sequence operation)
    (let ((stride (or stride size)))
      (when (< stride size)
        (error 'microsoft.xna.framework:cna-argument-out-of-range-error
               :operation operation
               :parameter-name "vertex-stride"
               :format-control
               "a stride of ~d cannot hold a ~d-byte element."
               :format-arguments (list stride size)))
      (unless (and (<= 0 start-index) (<= 0 element-count)
                   (<= (+ start-index element-count) (length sequence)))
        (error 'microsoft.xna.framework:cna-argument-out-of-range-error
               :operation operation
               :parameter-name "element-count"
               :format-control
               "~d element(s) from index ~d is outside a sequence of ~d."
               :format-arguments (list element-count start-index (length sequence))))
      (let ((bytes (make-array (* stride element-count)
                               :element-type '(unsigned-byte 8)
                               :initial-element 0)))
        (cffi:with-foreign-object (buffer :uint8 (max 1 (length bytes)))
          (cffi:foreign-funcall "memset" :pointer buffer :int 0
                                :size (max 1 (length bytes)) :void)
          (dotimes (index element-count)
            (%write-element buffer (* index stride)
                            (elt sequence (+ start-index index))))
          (dotimes (index (length bytes))
            (setf (aref bytes index) (cffi:mem-aref buffer :uint8 index))))
        (values bytes size sample)))))

(defun %unpack-into (sequence start-index element-count pointer stride prototype)
  "Read ELEMENT-COUNT elements out of POINTER into SEQUENCE at START-INDEX."
  (dotimes (index element-count sequence)
    (setf (elt sequence (+ start-index index))
          (%read-element pointer (* index stride) prototype))))

;;; --- the standard vertex types --------------------------------------------------
;;;
;;; Each writer is generated from the type's own VertexDeclaration, so the byte
;;; offset a field is written at is the offset the declaration publishes and not
;;; a second, hand-copied opinion about it.

(defmacro %define-vertex-layout (type declaration-function &rest fields)
  "Give one standard vertex type its buffer layout.

FIELDS is (ACCESSOR USAGE USAGE-INDEX) per public field, matched against the
type's declaration by usage so that the offsets come from there."
  `(progn
     (defmethod %element-byte-size ((element ,type))
       (declare (ignorable element))
       (vertex-stride (,declaration-function)))
     (defmethod %write-element (pointer offset (element ,type))
       (let ((elements (%declaration-elements (,declaration-function))))
         ,@(loop for (accessor usage index) in fields
                 collect `(%write-element
                           pointer
                           (+ offset (vertex-element-offset
                                      (%declaration-element-for elements ,usage ,index)))
                           (,accessor element)))))
     (defmethod %read-element (pointer offset (prototype ,type))
       (declare (ignorable prototype))
       (let ((elements (%declaration-elements (,declaration-function))))
         (,(intern (format nil "MAKE-~a" (symbol-name type))
                   :microsoft.xna.framework.graphics)
          ,@(loop for (accessor usage index) in fields
                  collect `(%read-element
                            pointer
                            (+ offset (vertex-element-offset
                                       (%declaration-element-for elements ,usage ,index)))
                            (,accessor prototype))))))))

(defun %declaration-element-for (elements usage usage-index)
  "The element of ELEMENTS with USAGE at USAGE-INDEX. A declaration has one."
  (or (find-if (lambda (element)
                 (and (eq usage (vertex-element-vertex-element-usage element))
                      (= usage-index (vertex-element-usage-index element))))
               elements)
      (error "no ~s element at usage index ~d in this declaration" usage usage-index)))

(%define-vertex-layout vertex-position-color vertex-position-color-vertex-declaration
  (vertex-position-color-position :position 0)
  (vertex-position-color-color :color 0))

(%define-vertex-layout vertex-position-texture vertex-position-texture-vertex-declaration
  (vertex-position-texture-position :position 0)
  (vertex-position-texture-texture-coordinate :texture-coordinate 0))

(%define-vertex-layout vertex-position-color-texture
    vertex-position-color-texture-vertex-declaration
  (vertex-position-color-texture-position :position 0)
  (vertex-position-color-texture-color :color 0)
  (vertex-position-color-texture-texture-coordinate :texture-coordinate 0))

(%define-vertex-layout vertex-position-normal-texture
    vertex-position-normal-texture-vertex-declaration
  (vertex-position-normal-texture-position :position 0)
  (vertex-position-normal-texture-normal :normal 0)
  (vertex-position-normal-texture-texture-coordinate :texture-coordinate 0))
