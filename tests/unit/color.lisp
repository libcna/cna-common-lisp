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
    (is (= 128 (xna:color-r c)))))

(test color-multiply-clamps
  (let ((c (xna:color-multiply (xna:make-color 200 100 50 255) 2.0)))
    (is (= 255 (xna:color-r c)))
    (is (= 200 (xna:color-g c)))
    (is (= 100 (xna:color-b c)))))

(test color-equality-is-on-the-packed-value
  (is (xna:color-equal (xna:make-color 1 2 3 4) (xna:color-from-packed-value #x04030201)))
  (is (not (xna:color-equal (xna:white) (xna:black)))))
