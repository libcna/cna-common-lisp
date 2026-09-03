;;;; color.lisp --- Color's packing, mutability and predefined values.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test color-packs-rgba-little-endian
  ;; R is the low byte, A the high one: the layout XNA and the CNA C ABI share.
  (let ((c (xna:make-color 1 2 3 4)))
    (is (= #x04030201 (xna:color-packed-value c)))
    (is (= 1 (xna:color-r c)))
    (is (= 2 (xna:color-g c)))
    (is (= 3 (xna:color-b c)))
    (is (= 4 (xna:color-a c)))))

(test color-alpha-defaults-to-opaque
  (is (= 255 (xna:color-a (xna:make-color 0 0 0)))))

(test color-channels-are-writable
  ;; XNA's R/G/B/A are read/write properties; the projection keeps that.
  (let ((c (xna:make-color 0 0 0 255)))
    (setf (xna:color-r c) 128)
    (is (= 128 (xna:color-r c)))
    (is (= 255 (xna:color-a c)))))

(test predefined-colours-are-fresh-values
  ;; This is why they are functions and not constants: a shared object would let
  ;; one consumer's mutation reach every later reader.
  (let ((blue (xna:cornflower-blue)))
    (setf (xna:color-r blue) 0)
    (is (/= 0 (xna:color-r (xna:cornflower-blue))))))

(test cornflower-blue-is-the-xna-value
  (let ((c (xna:cornflower-blue)))
    (is (= 100 (xna:color-r c)))
    (is (= 149 (xna:color-g c)))
    (is (= 237 (xna:color-b c)))
    (is (= 255 (xna:color-a c)))))

(test white-and-black-and-transparent
  (is (= #xFFFFFFFF (xna:color-packed-value (xna:white))))
  (is (= #xFF000000 (xna:color-packed-value (xna:black))))
  (is (= 0 (xna:color-packed-value (xna:transparent)))))

(test predefined-colour-table-is-the-abi-table
  ;; 141 named colours, generated from the CNA C ABI's own table rather than
  ;; transcribed.
  (is (= 141 (length (xna:predefined-color-names))))
  (is (member :cornflower-blue (xna:predefined-color-names))))

(test predefined-color-refuses-an-unknown-name
  (signals xna:cna-usage-error (xna:predefined-color :not-a-colour)))

(test color-from-non-premultiplied
  (let ((c (xna:color-from-non-premultiplied 255 255 255 128)))
    (is (= 128 (xna:color-a c)))
    (is (= 128 (xna:color-r c))))
  ;; The quotient truncates rather than rounding: 5 * 200 / 255 is 3.92, and the
  ;; answer is 3. An implementation that rounded would answer 4 here and agree
  ;; on almost every other input, which is why this case is written down.
  (is (= 3 (xna:color-r (xna:color-from-non-premultiplied 5 0 0 200))))
  ;; The channel is multiplied *unclamped* and only the quotient is clamped, so
  ;; an out-of-range channel does not collapse to 255 first.
  (is (= 117 (xna:color-r (xna:color-from-non-premultiplied 300 0 0 100))))
  (is (= 255 (xna:color-a (xna:color-from-non-premultiplied 0 0 0 900))))
  (is (= 0 (xna:color-r (xna:color-from-non-premultiplied -50 0 0 100)))))

(test color-multiply-is-fixed-point-and-floors
  ;; Not a float scale rounded back: the scale becomes a truncated 16.16 factor,
  ;; the multiply is integer, and the shift floors. Half of white is 127.
  (is (= 127 (xna:color-r (xna:color-multiply (xna:white) 0.5))))
  (is (= 127 (xna:color-a (xna:color-multiply (xna:white) 0.5))))
  (is (= 100 (xna:color-r (xna:color-multiply (xna:make-color 200 0 0 255) 0.5))))
  (is (= 0 (xna:color-r (xna:color-multiply (xna:white) -1.0))))
  (let ((c (xna:color-multiply (xna:make-color 200 100 50 255) 2.0)))
    (is (= 255 (xna:color-r c)))
    (is (= 200 (xna:color-g c)))
    (is (= 100 (xna:color-b c)))))

(test the-float-constructors-are-a-different-overload
  ;; `1' and `1.0' mean almost opposite colours, so the projection gives them
  ;; different names rather than telling them apart by numeric type at run time.
  (is (xna:color-equal (xna:white) (xna:make-color-from-floats 1.0 1.0 1.0)))
  (is (= 1 (xna:color-r (xna:make-color 1 1 1))))
  (is (xna:color-equal (xna:make-color 128 128 128 255)
                       (xna:make-color-from-floats 0.5 0.5 0.5)))
  (is (= 255 (xna:color-a (xna:make-color-from-floats 0.0 0.0 0.0)))
      "the three-float overload is fully opaque")
  (is (= 128 (xna:color-a (xna:make-color-from-floats 0.0 0.0 0.0 0.5)))))

(test the-float-constructors-clamp-and-round-half-to-even
  ;; PackUNorm rounds with Math.Round(double), which is round-half-to-even.
  (is (= 0 (xna:color-r (xna:make-color-from-floats (/ 0.5 255.0) 0.0 0.0))))
  (is (= 2 (xna:color-r (xna:make-color-from-floats (/ 1.5 255.0) 0.0 0.0))))
  (is (= 2 (xna:color-r (xna:make-color-from-floats (/ 2.5 255.0) 0.0 0.0))))
  (is (= 4 (xna:color-r (xna:make-color-from-floats (/ 3.5 255.0) 0.0 0.0))))
  (is (= 255 (xna:color-r (xna:make-color-from-floats 5.0 0.0 0.0))))
  (is (= 0 (xna:color-r (xna:make-color-from-floats -5.0 0.0 0.0)))))

(test colours-round-trip-through-vectors
  (let ((c (xna:make-color 10 20 30 40)))
    (is (xna:color-equal c (xna:make-color-from-vector4 (xna:color-to-vector4 c))))
    (let ((v3 (xna:color-to-vector3 c)))
      (is (= 255 (xna:color-a (xna:make-color-from-vector3 v3)))
          "Vector3 drops alpha and the constructor puts back full opacity")
      (is (= 10 (xna:color-r (xna:make-color-from-vector3 v3))))))
  (is (= 1.0f0 (xna:vector4-w (xna:color-to-vector4 (xna:white)))))
  (is (= 0.0f0 (xna:vector3-x (xna:color-to-vector3 (xna:black))))))

(test the-vector4-non-premultiplied-form-is-a-different-computation
  ;; The integer overload truncates an integer quotient; this one multiplies in
  ;; floats and packs, so they are two functions and not one.
  (let ((c (xna:color-from-non-premultiplied-vector4
            (xna:make-vector4 1.0 1.0 1.0 0.5))))
    (is (= 128 (xna:color-a c)))
    (is (= 128 (xna:color-r c))))
  (is (= 0 (xna:color-r (xna:color-from-non-premultiplied-vector4
                         (xna:make-vector4 1.0 1.0 1.0 0.0))))))

(test color-lerp-is-integer-fixed-point
  ;; Lerp weights with PackUNorm(65536, amount) and shifts right by 16. The
  ;; shift is arithmetic, so it floors, and a falling channel lands a step lower
  ;; than a rising one would.
  (is (xna:color-equal (xna:black) (xna:color-lerp (xna:black) (xna:white) 0.0)))
  (is (xna:color-equal (xna:white) (xna:color-lerp (xna:black) (xna:white) 1.0)))
  (is (= 127 (xna:color-r (xna:color-lerp (xna:black) (xna:white) 0.5)))
      "half way between 0 and 255 lands on 127, not 128")
  ;; The shift is arithmetic, so it floors rather than truncating, and that is
  ;; visible only on a falling channel: a thousandth of the way from white to
  ;; black already costs a level, while the same step up from black costs
  ;; nothing. A truncating shift would answer 255 and 0.
  (is (= 254 (xna:color-r (xna:color-lerp (xna:white) (xna:black) 0.001))))
  (is (= 0 (xna:color-r (xna:color-lerp (xna:black) (xna:white) 0.001))))
  (is (xna:color-equal (xna:black) (xna:color-lerp (xna:black) (xna:white) -1.0))
      "the weight is clamped, so an amount below zero is zero")
  (is (xna:color-equal (xna:white) (xna:color-lerp (xna:black) (xna:white) 2.0))))

(test color-equality-is-on-the-packed-value
  (is (xna:color-equal (xna:make-color 1 2 3 4) (xna:color-from-packed-value #x04030201)))
  (is (not (xna:color-equal (xna:white) (xna:black)))))
