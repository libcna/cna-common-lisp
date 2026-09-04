;;;; vertex-types.lisp --- CNA's own vertex declarations, against XNA's.
;;;;
;;;; The projection computes nothing from CNA: XNA is the authority for what a
;;;; VertexDeclaration contains, and the four standard declarations were read out
;;;; of the pinned assembly's class constructors. CNA has the same information --
;;;; cna_vertex_type_get_stride and cna_vertex_type_copy_elements -- and this is
;;;; where the two are compared. A difference here is a finding, not a failure to
;;;; smooth over.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defparameter *native-vertex-types*
  ;; The four CNA vertex types that correspond to XNA's four standard ones. CNA
  ;; has three more -- the tangent and skinned forms -- which are CNA extensions
  ;; with no XNA counterpart and are deliberately not projected.
  (list (list ffi::+vertex-type-position-color+
              "VertexPositionColor"
              (lambda () (gfx:vertex-position-color-vertex-declaration)))
        (list ffi::+vertex-type-position-texture+
              "VertexPositionTexture"
              (lambda () (gfx:vertex-position-texture-vertex-declaration)))
        (list ffi::+vertex-type-position-color-texture+
              "VertexPositionColorTexture"
              (lambda () (gfx:vertex-position-color-texture-vertex-declaration)))
        (list ffi::+vertex-type-position-normal-texture+
              "VertexPositionNormalTexture"
              (lambda () (gfx:vertex-position-normal-texture-vertex-declaration)))))

(defun native-vertex-stride (type)
  (cffi:with-foreign-object (out :uint32)
    (int:check-result (ffi::%vertex-type-get-stride type out) "vertex-type-get-stride")
    (cffi:mem-ref out :uint32)))

(defun native-vertex-elements (type)
  "CNA's own element list for one built-in vertex type, as VERTEX-ELEMENTs."
  (let ((capacity 16))
    (cffi:with-foreign-object (buffer '(:struct ffi::cna-vertex-element) capacity)
      (cffi:with-foreign-object (count :uint64)
        (int:check-result
         (ffi::%vertex-type-copy-elements type buffer capacity count)
         "vertex-type-copy-elements")
        (loop for index from 0 below (cffi:mem-ref count :uint64)
              for pointer = (cffi:mem-aptr buffer '(:struct ffi::cna-vertex-element) index)
              collect (macrolet ((slot (name)
                                   `(cffi:foreign-slot-value
                                     pointer '(:struct ffi::cna-vertex-element) ',name)))
                        (gfx:make-vertex-element
                         (slot ffi::offset)
                         (or (car (rassoc (slot ffi::format)
                                          gfx::%vertex-element-format-to-native))
                             (error "CNA answered vertex element format ~d, which names ~
                                     no VertexElementFormat member." (slot ffi::format)))
                         (or (car (rassoc (slot ffi::usage)
                                          gfx::%vertex-element-usage-to-native))
                             (error "CNA answered vertex element usage ~d, which names ~
                                     no VertexElementUsage member." (slot ffi::usage)))
                         (slot ffi::usage-index))))))))

(define-native-test cnas-vertex-strides-agree-with-the-pinned-assembly
  (dolist (row *native-vertex-types*)
    (destructuring-bind (type name declaration) row
      (let ((xna (gfx:vertex-stride (funcall declaration)))
            (cna (native-vertex-stride type)))
        (is (= xna cna)
            "~a: XNA's stride is ~d and CNA's is ~d" name xna cna)))))

(define-native-test cnas-vertex-declarations-agree-with-the-pinned-assembly
  ;; Element for element, in order, on all four components. XNA's class
  ;; constructors are the authority; this says whether CNA agrees with them.
  (dolist (row *native-vertex-types*)
    (destructuring-bind (type name declaration) row
      (let ((xna (gfx:get-vertex-elements (funcall declaration)))
            (cna (native-vertex-elements type)))
        (is (= (length xna) (length cna))
            "~a: XNA declares ~d element(s) and CNA ~d"
            name (length xna) (length cna))
        (loop for expected in xna
              for actual in cna
              for index from 0
              do (is (gfx:vertex-element-equal expected actual)
                     "~a element ~d: XNA (~d ~s ~s ~d), CNA (~d ~s ~s ~d)"
                     name index
                     (gfx:vertex-element-offset expected)
                     (gfx:vertex-element-vertex-element-format expected)
                     (gfx:vertex-element-vertex-element-usage expected)
                     (gfx:vertex-element-usage-index expected)
                     (gfx:vertex-element-offset actual)
                     (gfx:vertex-element-vertex-element-format actual)
                     (gfx:vertex-element-vertex-element-usage actual)
                     (gfx:vertex-element-usage-index actual)))))))

(define-native-test cnas-vertex-element-numbering-agrees-with-xnas
  ;; Stated rather than assumed, as it is for the state enumerations -- where one
  ;; of them turned out not to agree.
  (dolist (row gfx::%vertex-element-format-to-native)
    (is (= (gfx:vertex-element-format-value (car row)) (cdr row))
        "VertexElementFormat ~s: XNA ~d, CNA ~d" (car row)
        (gfx:vertex-element-format-value (car row)) (cdr row)))
  (dolist (row gfx::%vertex-element-usage-to-native)
    (is (= (gfx:vertex-element-usage-value (car row)) (cdr row))
        "VertexElementUsage ~s: XNA ~d, CNA ~d" (car row)
        (gfx:vertex-element-usage-value (car row)) (cdr row))))
