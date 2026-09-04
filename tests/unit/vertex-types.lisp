;;;; vertex-types.lisp --- VertexElement, VertexDeclaration and the four standard
;;;; vertex value types.
;;;;
;;;; The discriminating cases are the validator's, and its refusal *order*: an
;;;; element can fail more than one check at once and XNA reports the first.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

;;; V3 is tests/unit/bounding-volumes.lisp's, which loads first. One helper, not
;;; two definitions of one name.

(defun element (offset format usage &optional (index 0))
  (gfx:make-vertex-element offset format usage index))

;;; --- the element sizes ---------------------------------------------------------

(test the-element-format-sizes-are-xnas
  ;; Two of these are wrong under any reasoning from the name. Color is four
  ;; bytes, because it is a packed BGRA and not four floats; HalfVector4 is
  ;; eight, because a half is two bytes.
  (is (= 4 (gfx:vertex-element-format-size :single)))
  (is (= 8 (gfx:vertex-element-format-size :vector2)))
  (is (= 12 (gfx:vertex-element-format-size :vector3)))
  (is (= 16 (gfx:vertex-element-format-size :vector4)))
  (is (= 4 (gfx:vertex-element-format-size :color)))
  (is (= 4 (gfx:vertex-element-format-size :byte4)))
  (is (= 4 (gfx:vertex-element-format-size :short2)))
  (is (= 8 (gfx:vertex-element-format-size :short4)))
  (is (= 4 (gfx:vertex-element-format-size :normalized-short2)))
  (is (= 8 (gfx:vertex-element-format-size :normalized-short4)))
  (is (= 4 (gfx:vertex-element-format-size :half-vector2)))
  (is (= 8 (gfx:vertex-element-format-size :half-vector4))))

(test the-vertex-enumerations-carry-xnas-values
  (is (= 0 (gfx:vertex-element-format-value :single)))
  (is (= 4 (gfx:vertex-element-format-value :color)))
  (is (= 11 (gfx:vertex-element-format-value :half-vector4)))
  (is (= 0 (gfx:vertex-element-usage-value :position)))
  (is (= 2 (gfx:vertex-element-usage-value :texture-coordinate)))
  (is (= 12 (gfx:vertex-element-usage-value :tessellate-factor))))

;;; --- the stride, which is a maximum and not a sum --------------------------------

(test the-stride-is-the-largest-end-not-the-sum
  ;; GetVertexStride takes the maximum of offset + size, which is what lets a
  ;; declaration list its elements out of order, and is not the same as adding
  ;; the sizes up when there is padding or an overlap-free gap.
  (let ((declaration (make-instance 'gfx:vertex-declaration
                                    :elements (list (element 16 :vector2 :texture-coordinate)
                                                    (element 0 :vector3 :position)))))
    (is (= 24 (gfx:vertex-stride declaration))))
  ;; A gap between elements is legal and counts toward the stride.
  (let ((declaration (make-instance 'gfx:vertex-declaration
                                    :elements (list (element 0 :single :position)
                                                    (element 16 :single :fog)))))
    (is (= 20 (gfx:vertex-stride declaration)))))

(test an-explicit-stride-is-taken-as-given
  ;; The two-argument constructor validates against the stride it is given rather
  ;; than computing one, which is how trailing padding is declared.
  (let ((declaration (make-instance 'gfx:vertex-declaration
                                    :vertex-stride 32
                                    :elements (list (element 0 :vector3 :position)))))
    (is (= 32 (gfx:vertex-stride declaration)))))

;;; --- the validator, and the order it refuses in ----------------------------------

(test a-declaration-refuses-what-xna-refuses
  ;; Not a multiple of four.
  (signals xna:cna-usage-error
    (make-instance 'gfx:vertex-declaration :vertex-stride 13
                   :elements (list (element 0 :single :position))))
  ;; Not positive. XNA throws ArgumentOutOfRangeException here and
  ;; ArgumentException for the rest, and the two are different conditions.
  (signals xna:cna-argument-out-of-range-error
    (make-instance 'gfx:vertex-declaration :vertex-stride 0
                   :elements (list (element 0 :single :position))))
  (signals xna:cna-argument-out-of-range-error
    (make-instance 'gfx:vertex-declaration :vertex-stride -4
                   :elements (list (element 0 :single :position))))
  ;; An element that ends past the stride.
  (signals xna:cna-usage-error
    (make-instance 'gfx:vertex-declaration :vertex-stride 8
                   :elements (list (element 0 :vector3 :position))))
  ;; A negative offset.
  (signals xna:cna-usage-error
    (make-instance 'gfx:vertex-declaration :vertex-stride 16
                   :elements (list (element -4 :single :position))))
  ;; An offset that is not a multiple of four.
  (signals xna:cna-usage-error
    (make-instance 'gfx:vertex-declaration :vertex-stride 16
                   :elements (list (element 2 :single :position))))
  ;; No elements at all: XNA throws ArgumentNullException for a null array *and*
  ;; for an empty one.
  (signals xna:cna-argument-out-of-range-error
    (make-instance 'gfx:vertex-declaration :elements '()))
  (signals xna:cna-argument-out-of-range-error
    (make-instance 'gfx:vertex-declaration :elements nil)))

(test a-usage-and-a-usage-index-together-name-one-element
  ;; The same usage twice is legal when the usage indices differ, and refused
  ;; when they do not. A validator that keyed on the usage alone would refuse the
  ;; two-texture-coordinate vertex every second game declares.
  (finishes
    (make-instance 'gfx:vertex-declaration
                   :elements (list (element 0 :vector3 :position)
                                   (element 12 :vector2 :texture-coordinate 0)
                                   (element 20 :vector2 :texture-coordinate 1))))
  (signals xna:cna-usage-error
    (make-instance 'gfx:vertex-declaration
                   :elements (list (element 0 :vector2 :texture-coordinate 0)
                                   (element 8 :vector2 :texture-coordinate 0)))))

(test overlapping-elements-are-refused-byte-by-byte
  ;; The overlap check is per byte, not per element start: two elements at
  ;; different offsets still overlap when the first is long enough to reach the
  ;; second, and a declaration that only compared offsets would let this through.
  (signals xna:cna-usage-error
    (make-instance 'gfx:vertex-declaration
                   :elements (list (element 0 :vector4 :position)
                                   (element 4 :single :fog))))
  ;; Touching without overlapping is fine.
  (finishes
    (make-instance 'gfx:vertex-declaration
                   :elements (list (element 0 :vector4 :position)
                                   (element 16 :single :fog)))))

(test a-declaration-owns-its-elements
  ;; XNA clones the array. A caller who mutates what they passed, or what
  ;; GetVertexElements answered, must not be able to change the declaration.
  (let* ((given (list (element 0 :vector3 :position) (element 12 :color :color)))
         (declaration (make-instance 'gfx:vertex-declaration :elements given)))
    (setf (gfx:vertex-element-offset (first given)) 999)
    (is (= 0 (gfx:vertex-element-offset (first (gfx:get-vertex-elements declaration)))))
    (let ((answered (gfx:get-vertex-elements declaration)))
      (setf (gfx:vertex-element-offset (first answered)) 777)
      (is (= 0 (gfx:vertex-element-offset
                (first (gfx:get-vertex-elements declaration))))))))

(test vertex-elements-compare-on-all-four-components
  (is (gfx:vertex-element-equal (element 0 :vector3 :position 0)
                                (element 0 :vector3 :position 0)))
  (is (not (gfx:vertex-element-equal (element 0 :vector3 :position 0)
                                     (element 4 :vector3 :position 0))))
  (is (not (gfx:vertex-element-equal (element 0 :vector3 :position 0)
                                     (element 0 :vector4 :position 0))))
  (is (not (gfx:vertex-element-equal (element 0 :vector3 :position 0)
                                     (element 0 :vector3 :normal 0))))
  (is (not (gfx:vertex-element-equal (element 0 :vector3 :position 0)
                                     (element 0 :vector3 :position 1)))))

;;; --- the four standard vertex types ---------------------------------------------

(test the-standard-vertex-declarations-are-the-ones-in-the-assembly
  ;; Offsets, formats, usages and strides read out of each type's own class
  ;; constructor. The strides are 16, 20, 24 and 32; a reconstruction that made
  ;; Color sixteen bytes would answer 28 for the first.
  (let ((declaration (gfx:vertex-position-color-vertex-declaration)))
    (is (= 16 (gfx:vertex-stride declaration)))
    (is (equal '((0 :vector3 :position 0) (12 :color :color 0))
               (mapcar (lambda (e) (list (gfx:vertex-element-offset e)
                                         (gfx:vertex-element-vertex-element-format e)
                                         (gfx:vertex-element-vertex-element-usage e)
                                         (gfx:vertex-element-usage-index e)))
                       (gfx:get-vertex-elements declaration)))))
  (is (= 20 (gfx:vertex-stride (gfx:vertex-position-texture-vertex-declaration))))
  (is (= 24 (gfx:vertex-stride (gfx:vertex-position-color-texture-vertex-declaration))))
  (is (= 32 (gfx:vertex-stride (gfx:vertex-position-normal-texture-vertex-declaration))))
  ;; The normal-texture one puts the texture coordinate at 24, not at 16: the
  ;; normal is a Vector3 and occupies twelve bytes.
  (is (= 24 (gfx:vertex-element-offset
             (third (gfx:get-vertex-elements
                     (gfx:vertex-position-normal-texture-vertex-declaration)))))))

(test a-standard-declaration-is-the-same-object-every-time
  (is (eq (gfx:vertex-position-color-vertex-declaration)
          (gfx:vertex-position-color-vertex-declaration)))
  (is (not (eq (gfx:vertex-position-color-vertex-declaration)
               (gfx:vertex-position-texture-vertex-declaration)))))

(test the-ivertextype-projection-answers-the-types-own-declaration
  ;; IVertexType is one property, and a generic function with a method per vertex
  ;; type is what it is for.
  (let ((vertex (gfx:make-vertex-position-color (v3 1 2 3) (xna:white))))
    (is (eq (gfx:vertex-position-color-vertex-declaration)
            (gfx:vertex-declaration-of vertex))))
  (let ((vertex (gfx:make-vertex-position-normal-texture
                 (v3 1 2 3) (v3 0 1 0) (xna:make-vector2 0.5f0 0.25f0))))
    (is (eq (gfx:vertex-position-normal-texture-vertex-declaration)
            (gfx:vertex-declaration-of vertex)))))

(test a-vertex-value-compares-on-every-field
  (let ((a (gfx:make-vertex-position-color-texture
            (v3 1 2 3) (xna:white) (xna:make-vector2 0.5f0 0.25f0)))
        (b (gfx:make-vertex-position-color-texture
            (v3 1 2 3) (xna:white) (xna:make-vector2 0.5f0 0.25f0)))
        (c (gfx:make-vertex-position-color-texture
            (v3 1 2 3) (xna:black) (xna:make-vector2 0.5f0 0.25f0))))
    (is (gfx:vertex-position-color-texture-equal a b))
    (is (not (gfx:vertex-position-color-texture-equal a c)))))

(test a-vertex-value-has-mutable-public-fields
  ;; XNA's are public fields, not properties, so they are settable.
  (let ((vertex (gfx:make-vertex-position-color (v3 0 0 0) (xna:white))))
    (setf (gfx:vertex-position-color-position vertex) (v3 4 5 6))
    (is (xna:vector3-equal (v3 4 5 6) (gfx:vertex-position-color-position vertex)))
    (setf (gfx:vertex-position-color-color vertex) (xna:cornflower-blue))
    (is (xna:color-equal (xna:cornflower-blue)
                         (gfx:vertex-position-color-color vertex)))))
