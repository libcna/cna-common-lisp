;;;; buffer-data.lisp --- the layouts a buffer transfer will and will not write.
;;;;
;;;; The rule this file pins: **a transfer is accepted only when the binary
;;;; layout of every element is proved.** There is no vector-of-anything sink, and
;;;; an element type with no layout is refused by name rather than written into
;;;; native memory.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defun pack (sequence &key (start 0) count stride)
  (gfx::%pack-sequence sequence start (or count (length sequence)) "test"
                       :stride stride))

(test the-scalar-layouts-are-the-widths-xna-uses
  (is (= 4 (length (pack (vector 1.0f0)))))
  (is (= 4 (length (pack (vector (xna:white))))))
  (is (= 8 (length (pack (vector (xna:make-vector2 1.0f0 2.0f0))))))
  (is (= 12 (length (pack (vector (v3 1 2 3))))))
  (is (= 16 (length (pack (vector (xna:make-vector4 1.0f0 2.0f0 3.0f0 4.0f0))))))
  ;; An integer vector's own element type decides its width, because nothing
  ;; about the value 7 says whether it is a sixteen- or a thirty-two-bit index.
  (is (= 2 (length (pack (make-array 1 :element-type '(unsigned-byte 16)
                                       :initial-element 7)))))
  (is (= 4 (length (pack (make-array 1 :element-type '(unsigned-byte 32)
                                       :initial-element 7)))))
  (is (= 1 (length (pack (make-array 1 :element-type '(unsigned-byte 8)
                                       :initial-element 7))))))

(test a-colour-packs-as-r-g-b-a
  (let ((bytes (pack (vector (xna:make-color 1 2 3 4)))))
    (is (equalp #(1 2 3 4) bytes))))

(test a-vector3-packs-as-three-binary32s
  (let ((bytes (pack (vector (v3 1 2 3)))))
    (is (= 12 (length bytes)))
    ;; 1.0f0 is #x3F800000 little-endian.
    (is (equalp #(0 0 128 63) (subseq bytes 0 4)))))

(test an-element-type-with-no-proven-layout-is-refused-by-name
  ;; The whole point: a Lisp object whose bytes this binding cannot state is not
  ;; written into native memory on the strength of being in a vector.
  (handler-case (progn (pack (vector (list 1 2 3))) (fail "a list was accepted"))
    (xna:cna-usage-error (condition)
      (let ((text (princ-to-string condition)))
        (is (search "CONS" (string-upcase text))
            "the refusal should name the type it refused; it said: ~a" text)
        (is (search "unsigned-byte 8" (string-downcase text))
            "the refusal should say what it does accept"))))
  (signals xna:cna-usage-error (pack (vector "a string")))
  (signals xna:cna-usage-error (pack (vector (make-hash-table)))))

(test a-heterogeneous-sequence-is-refused-before-anything-is-written
  (signals xna:cna-usage-error
    (pack (vector (v3 1 2 3) (xna:white)))))

(test an-empty-sequence-has-no-layout-and-is-refused
  (signals xna:cna-argument-out-of-range-error (pack (vector))))

(test a-window-outside-the-sequence-is-refused
  (signals xna:cna-argument-out-of-range-error
    (pack (vector 1.0f0 2.0f0) :start 1 :count 5))
  (signals xna:cna-argument-out-of-range-error
    (pack (vector 1.0f0 2.0f0) :start -1 :count 1)))

(test a-stride-narrower-than-the-element-is-refused
  (signals xna:cna-argument-out-of-range-error
    (pack (vector (v3 1 2 3)) :stride 8)))

(test a-wider-stride-pads-rather-than-overlapping
  (let ((bytes (pack (vector (v3 1 2 3) (v3 4 5 6)) :stride 16)))
    (is (= 32 (length bytes)))
    ;; The four padding bytes after the first vertex are zero, and the second
    ;; vertex starts at 16 rather than at 12.
    (is (equalp #(0 0 0 0) (subseq bytes 12 16)))
    ;; The second vertex begins at 16, not at 12: its X is 4.0 and that is where
    ;; those four bytes are.
    (is (equalp (pack (vector (coerce 4 'single-float))) (subseq bytes 16 20)))
    (is (equalp (pack (vector (coerce 1 'single-float))) (subseq bytes 0 4)))))

;;; --- the standard vertex types pack as their declarations say ---------------------

(test each-standard-vertex-packs-at-its-declarations-own-offsets
  ;; The layouts are generated from each type's VertexDeclaration, so this is the
  ;; check that the generation is faithful: the field at declaration offset N is
  ;; the field whose bytes appear at N.
  (let* ((position (v3 1 2 3))
         (normal (v3 0 1 0))
         (coordinate (xna:make-vector2 0.25f0 0.5f0))
         (colour (xna:make-color 10 20 30 40)))
    (flet ((packed (vertex) (pack (vector vertex)))
           (float-bytes (value)
             (pack (vector (coerce value 'single-float)))))
      ;; VertexPositionColor: position at 0, colour at 12, stride 16.
      (let ((bytes (packed (gfx:make-vertex-position-color position colour))))
        (is (= 16 (length bytes)))
        (is (equalp (float-bytes 1) (subseq bytes 0 4)))
        (is (equalp #(10 20 30 40) (subseq bytes 12 16))))
      ;; VertexPositionTexture: position at 0, coordinate at 12, stride 20.
      (let ((bytes (packed (gfx:make-vertex-position-texture position coordinate))))
        (is (= 20 (length bytes)))
        (is (equalp (float-bytes 0.25) (subseq bytes 12 16)))
        (is (equalp (float-bytes 0.5) (subseq bytes 16 20))))
      ;; VertexPositionColorTexture: 0, 12, 16, stride 24.
      (let ((bytes (packed (gfx:make-vertex-position-color-texture
                            position colour coordinate))))
        (is (= 24 (length bytes)))
        (is (equalp #(10 20 30 40) (subseq bytes 12 16)))
        (is (equalp (float-bytes 0.25) (subseq bytes 16 20))))
      ;; VertexPositionNormalTexture: 0, 12, 24, stride 32 -- the coordinate is at
      ;; 24 and not at 16, because a normal is a Vector3.
      (let ((bytes (packed (gfx:make-vertex-position-normal-texture
                            position normal coordinate))))
        (is (= 32 (length bytes)))
        (is (equalp (float-bytes 1) (subseq bytes 16 20))
            "the normal's Y should be at 16")
        (is (equalp (float-bytes 0.25) (subseq bytes 24 28)))))))

(test the-packed-size-of-a-vertex-is-its-declarations-stride
  (dolist (row (list (list (gfx:make-vertex-position-color (v3 0 0 0) (xna:white))
                           #'gfx:vertex-position-color-vertex-declaration)
                     (list (gfx:make-vertex-position-texture
                            (v3 0 0 0) (xna:make-vector2 0.0f0 0.0f0))
                           #'gfx:vertex-position-texture-vertex-declaration)
                     (list (gfx:make-vertex-position-color-texture
                            (v3 0 0 0) (xna:white) (xna:make-vector2 0.0f0 0.0f0))
                           #'gfx:vertex-position-color-texture-vertex-declaration)
                     (list (gfx:make-vertex-position-normal-texture
                            (v3 0 0 0) (v3 0 0 0) (xna:make-vector2 0.0f0 0.0f0))
                           #'gfx:vertex-position-normal-texture-vertex-declaration)))
    (destructuring-bind (vertex declaration) row
      (is (= (gfx:vertex-stride (funcall declaration)) (length (pack (vector vertex))))
          "~a packs to a size other than its declaration's stride" (type-of vertex)))))

;;; --- VertexBufferBinding validates as XNA's constructors do ------------------------

(test a-vertex-buffer-binding-refuses-what-xna-refuses
  ;; The buffer half needs a device, so this covers only the checks that come
  ;; first -- which is the null check. The offset and frequency checks are
  ;; exercised against a real buffer in the native suite.
  (signals xna:cna-argument-out-of-range-error (gfx:make-vertex-buffer-binding nil)))

;;; --- the draw argument checks that need no device ---------------------------------

(test a-user-primitive-count-maps-to-a-vertex-count
  (is (= 3 (gfx::%user-primitive-vertex-count :triangle-list 1 "test")))
  (is (= 6 (gfx::%user-primitive-vertex-count :triangle-list 2 "test")))
  (is (= 3 (gfx::%user-primitive-vertex-count :triangle-strip 1 "test")))
  (is (= 4 (gfx::%user-primitive-vertex-count :triangle-strip 2 "test")))
  (is (= 2 (gfx::%user-primitive-vertex-count :line-list 1 "test")))
  (is (= 2 (gfx::%user-primitive-vertex-count :line-strip 1 "test")))
  (is (= 3 (gfx::%user-primitive-vertex-count :line-strip 2 "test"))))

(test the-buffer-enumerations-carry-xnas-values
  (is (= 0 (gfx:buffer-usage-value :none)))
  (is (= 1 (gfx:buffer-usage-value :write-only)))
  (is (= 0 (gfx:index-element-size-value :sixteen-bits)))
  (is (= 1 (gfx:index-element-size-value :thirty-two-bits)))
  (is (= 0 (gfx:set-data-options-value :none)))
  (is (= 1 (gfx:set-data-options-value :discard)))
  (is (= 2 (gfx:set-data-options-value :no-overwrite)))
  (is (= 0 (gfx:primitive-type-value :triangle-list)))
  (is (= 1 (gfx:primitive-type-value :triangle-strip)))
  (is (= 2 (gfx:primitive-type-value :line-list)))
  (is (= 3 (gfx:primitive-type-value :line-strip)))
  ;; XNA has four; CNA has a fifth, which is a CNA extension and is not projected.
  (is (= 4 (length (gfx:all-primitive-type)))))
