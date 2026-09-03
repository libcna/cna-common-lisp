;;;; packed-vector.lisp --- the seventeen packed value types.
;;;;
;;;; The bit layouts are checked against the exact packed value, not against a
;;;; round trip, because a round trip through a wrong-but-symmetric layout still
;;;; comes back right. The rest of the file is the parts of the packing that a
;;;; reimplementation gets differently: the reserved code point in the signed
;;;; normalised formats, half-to-even rounding, and a 16-bit float format that is
;;;; not binary16.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test packed-vector-bit-layouts
  ;; Pure red, fully opaque, in each format that has a documented layout.
  (is (= #xFF (pv:alpha8-packed-value (pv:make-alpha8 1.0))))
  (is (= #xF800 (pv:bgr565-packed-value (pv:make-bgr565 1.0 0.0 0.0)))
      "5 bits of red at the top, 6 of green, 5 of blue")
  (is (= #x07E0 (pv:bgr565-packed-value (pv:make-bgr565 0.0 1.0 0.0))))
  (is (= #x001F (pv:bgr565-packed-value (pv:make-bgr565 0.0 0.0 1.0))))
  (is (= #xFF00 (pv:bgra4444-packed-value (pv:make-bgra4444 1.0 0.0 0.0 1.0)))
      "alpha at the top, then red, green, blue")
  (is (= #xFC00 (pv:bgra5551-packed-value (pv:make-bgra5551 1.0 0.0 0.0 1.0))))
  (is (= #x000000FF (pv:byte4-packed-value (pv:make-byte4 255.0 0.0 0.0 0.0))))
  (is (= #xFF000000 (pv:byte4-packed-value (pv:make-byte4 0.0 0.0 0.0 255.0))))
  (is (= #xC00003FF (pv:rgba1010102-packed-value
                     (pv:make-rgba1010102 1.0 0.0 0.0 1.0)))
      "ten bits each for R, G and B, and two for alpha at the top")
  (is (= #xFFFF000000000000 (pv:rgba64-packed-value (pv:make-rgba64 0.0 0.0 0.0 1.0))))
  (is (= #x0000FFFF (pv:rg32-packed-value (pv:make-rg32 1.0 0.0)))))

(test packed-vectors-round-trip-their-components
  (macrolet ((round-trips (make convert &rest components)
               `(let ((back (,convert (,make ,@components))))
                  (declare (ignorable back))
                  back)))
    (let ((v (pv:bgra4444-to-vector4 (pv:make-bgra4444 1.0 0.0 0.0 1.0))))
      (is (= 1.0f0 (xna:vector4-x v)))
      (is (= 0.0f0 (xna:vector4-y v)))
      (is (= 1.0f0 (xna:vector4-w v))))
    (let ((v (pv:rgba64-to-vector4 (pv:make-rgba64 1.0 0.5 0.0 1.0))))
      (is (= 1.0f0 (xna:vector4-x v)))
      (is (~= 0.5f0 (xna:vector4-y v) 1.0e-4)))
    (let ((v (pv:half-vector4-to-vector4 (pv:make-half-vector4 1.0 -2.0 0.5 0.25))))
      (is (= 1.0f0 (xna:vector4-x v)))
      (is (= -2.0f0 (xna:vector4-y v)))
      (is (= 0.5f0 (xna:vector4-z v)))
      (is (= 0.25f0 (xna:vector4-w v)))
      "the half format is exact on small powers of two")
    (is (= 0.5f0 (pv:half-single-to-single (pv:make-half-single 0.5))))
    (is (= 0.5f0 (xna:vector2-y (pv:half-vector2-to-vector2
                                 (pv:make-half-vector2 -1.0 0.5)))))))

(test unsigned-packed-formats-clamp-rather-than-wrap
  ;; Byte4 stores raw values, not normalised ones, so 300 clamps to 255 and a
  ;; negative clamps to 0 -- it does not wrap round.
  (let ((v (pv:byte4-to-vector4 (pv:make-byte4 1.0 200.0 300.0 -5.0))))
    (is (= 1.0f0 (xna:vector4-x v)))
    (is (= 200.0f0 (xna:vector4-y v)))
    (is (= 255.0f0 (xna:vector4-z v)))
    (is (= 0.0f0 (xna:vector4-w v))))
  ;; The unit-normalised formats clamp their input to [0, 1] the same way.
  (is (= 1.0f0 (xna:vector4-x (pv:rgba64-to-vector4 (pv:make-rgba64 5.0 0 0 0)))))
  (is (= 0.0f0 (xna:vector4-x (pv:rgba64-to-vector4 (pv:make-rgba64 -5.0 0 0 0))))))

(test signed-packed-formats-reserve-their-most-negative-code-point
  ;; PackSNorm clamps to [-max, max] where max is half the range, so the pattern
  ;; one step below -1.0 is never produced -- and UnpackSNorm reads that reserved
  ;; pattern back as exactly -1.0 rather than as the value below it. Both halves
  ;; of that arrangement are visible here.
  (is (= #x81 (pv:normalized-byte2-packed-value (pv:make-normalized-byte2 -1.0 0.0)))
      "-1.0 packs to 0x81, not to 0x80")
  (is (= -1.0f0 (xna:vector2-x (pv:normalized-byte2-to-vector2
                                (pv:make-normalized-byte2 -1.0 0.0)))))
  (is (= -1.0f0 (xna:vector2-x (pv:normalized-byte2-to-vector2
                                (pv:make-normalized-byte2 -5.0 0.0))))
      "and anything below -1 clamps there")
  (is (= 1.0f0 (xna:vector2-x (pv:normalized-byte2-to-vector2
                               (pv:make-normalized-byte2 5.0 0.0)))))
  ;; 0.5 is not representable: the scale is 127, so it comes back a little high.
  (is (~= 0.503937f0 (xna:vector2-x (pv:normalized-byte2-to-vector2
                                     (pv:make-normalized-byte2 0.5 0.0)))
          1.0e-6)))

(test the-signed-integer-formats-are-not-normalised
  ;; Short2 and Short4 store the numbers themselves, clamped to a signed 16-bit
  ;; range, and read them back sign-extended.
  (let ((v (pv:short2-to-vector2 (pv:make-short2 -32768.0 32767.0))))
    (is (= -32768.0f0 (xna:vector2-x v)))
    (is (= 32767.0f0 (xna:vector2-y v))))
  (is (= #x7FFF8000 (pv:short2-packed-value (pv:make-short2 -32768.0 32767.0))))
  (let ((v (pv:short2-to-vector2 (pv:make-short2 -100000.0 100000.0))))
    (is (= -32768.0f0 (xna:vector2-x v)) "clamped, not wrapped")
    (is (= 32767.0f0 (xna:vector2-y v))))
  (let ((v (pv:short4-to-vector4 (pv:make-short4 -1.0 1.0 0.0 -32768.0))))
    (is (= -1.0f0 (xna:vector4-x v)))
    (is (= -32768.0f0 (xna:vector4-w v)))))

(test packed-conversions-round-half-to-even
  ;; Every conversion goes through Math.Round(double), which rounds halves to
  ;; even. In an 8-bit unit format the half-way inputs are odd multiples of
  ;; 1/510, and they land on the even code point either side.
  (is (= 0 (pv:alpha8-packed-value (pv:make-alpha8 (/ 0.5 255.0)))))
  (is (= 2 (pv:alpha8-packed-value (pv:make-alpha8 (/ 1.5 255.0)))))
  (is (= 2 (pv:alpha8-packed-value (pv:make-alpha8 (/ 2.5 255.0)))))
  (is (= 4 (pv:alpha8-packed-value (pv:make-alpha8 (/ 3.5 255.0))))))

(test packing-a-nan-or-an-infinity-answers-a-number
  ;; PackUtils has an answer for each: a NaN is zero and the infinities are the
  ;; ends of the range. Nothing signals, because nothing signals in XNA either.
  (let ((nan (int:bits-single-float #x7FC00000))
        (+inf (int:bits-single-float #x7F800000))
        (-inf (int:bits-single-float #xFF800000)))
    (is (= 0 (pv:alpha8-packed-value (pv:make-alpha8 nan))))
    (is (= 255 (pv:alpha8-packed-value (pv:make-alpha8 +inf))))
    (is (= 0 (pv:alpha8-packed-value (pv:make-alpha8 -inf))))
    (is (= 255.0f0 (xna:vector4-x (pv:byte4-to-vector4 (pv:make-byte4 +inf 0 0 0)))))))

(test xna-halves-are-not-binary16
  ;; XNA's sixteen bits have no infinity and no NaN: an exponent of 31 means 2^16
  ;; rather than a special value, so the top pattern is an ordinary number and
  ;; the format reaches 131008 where IEEE 754 binary16 stops at 65504. Anything
  ;; larger, and both infinities, and a NaN, all saturate there.
  (let ((+inf (int:bits-single-float #x7F800000))
        (-inf (int:bits-single-float #xFF800000))
        (nan (int:bits-single-float #x7FC00000)))
    (is (= 65504.0f0 (pv:half-single-to-single (pv:make-half-single 65504.0)))
        "binary16's largest finite value is exact here too")
    (is (= 70016.0f0 (pv:half-single-to-single (pv:make-half-single 70000.0)))
        "and so is a value binary16 could not represent at all")
    (is (= 131008.0f0 (pv:half-single-to-single (pv:make-half-single 200000.0))))
    (is (= 131008.0f0 (pv:half-single-to-single (pv:make-half-single +inf))))
    (is (= -131008.0f0 (pv:half-single-to-single (pv:make-half-single -inf))))
    (is (= 131008.0f0 (pv:half-single-to-single (pv:make-half-single nan)))
        "a NaN saturates rather than propagating"))
  ;; Signed zero survives, and the subnormal range works.
  (is (= #x8000 (pv:half-single-packed-value (pv:make-half-single -0.0))))
  (is (= 0 (pv:half-single-packed-value (pv:make-half-single 1.0e-8))))
  (is (~= 5.9604645e-8 (pv:half-single-to-single
                        (pv:make-half-single 5.9604645e-8))
          1.0e-12)))

(test packed-vectors-are-values-with-value-equality
  (is (pv:alpha8-equal (pv:make-alpha8 1.0) (pv:make-alpha8 1.0)))
  (is (not (pv:alpha8-equal (pv:make-alpha8 1.0) (pv:make-alpha8 0.0))))
  (is (pv:rgba64-equal (pv:make-rgba64 1.0 0.5 0.0 1.0)
                       (pv:make-rgba64 1.0 0.5 0.0 1.0)))
  (let* ((v (pv:make-short4 1.0 2.0 3.0 4.0))
         (copy (pv:copy-short4 v)))
    (is (pv:short4-equal v copy))
    (setf (pv:short4-packed-value copy) 0)
    (is (not (pv:short4-equal v copy)) "a copy is a copy, not an alias")))
