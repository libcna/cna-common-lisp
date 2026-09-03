;;;; color.lisp --- Microsoft.Xna.Framework.Color.
;;;;
;;;; XNA's Color stores one packed 32-bit RGBA value and exposes R, G, B, A and
;;;; PackedValue as read/write properties. It is a value type, so a property that
;;;; answers a Color answers a copy and mutating that copy affects nothing. Every
;;;; predefined colour here is therefore a *function*, not a constant: a shared
;;;; constant object would let one consumer's mutation reach another's.

(in-package #:microsoft.xna.framework)

(defstruct (color (:constructor %make-color (packed-value)) (:copier copy-color))
  "Microsoft.Xna.Framework.Color: an unpacked 8-bit-per-channel RGBA colour.

The packed value is stored little-endian in the channel order R, G, B, A, which
is the layout the CNA C ABI and XNA both use."
  (packed-value 0 :type (unsigned-byte 32)))

(declaim (inline %byte))
(defun %byte (value)
  "VALUE clamped into a colour channel byte."
  (let ((n (round value)))
    (cond ((< n 0) 0) ((> n 255) 255) (t n))))

(defun make-color (&optional (r 0) (g 0) (b 0) (a 255))
  "Color(byte, byte, byte, byte) with A defaulting to fully opaque.

Real arguments outside 0-255 are clamped, which is what XNA's float constructors
do; the byte constructors take bytes and cannot be out of range at all."
  (%make-color (logior (%byte r)
                       (ash (%byte g) 8)
                       (ash (%byte b) 16)
                       (ash (%byte a) 24))))

(defun color-from-packed-value (packed)
  "A colour with exactly this packed value."
  (%make-color (logand packed #xFFFFFFFF)))

(defun color-r (color) (ldb (byte 8 0) (color-packed-value color)))
(defun color-g (color) (ldb (byte 8 8) (color-packed-value color)))
(defun color-b (color) (ldb (byte 8 16) (color-packed-value color)))
(defun color-a (color) (ldb (byte 8 24) (color-packed-value color)))

(defun (setf color-r) (value color)
  (setf (ldb (byte 8 0) (color-packed-value color)) (%byte value)) value)
(defun (setf color-g) (value color)
  (setf (ldb (byte 8 8) (color-packed-value color)) (%byte value)) value)
(defun (setf color-b) (value color)
  (setf (ldb (byte 8 16) (color-packed-value color)) (%byte value)) value)
(defun (setf color-a) (value color)
  (setf (ldb (byte 8 24) (color-packed-value color)) (%byte value)) value)

(defun color-equal (left right)
  "Color.Equals: the packed values are equal."
  (= (color-packed-value left) (color-packed-value right)))

(defun color-from-non-premultiplied (r g b a)
  "Color.FromNonPremultiplied(int, int, int, int).

XNA multiplies each channel by the alpha *after* clamping the channel, using
integer arithmetic on the clamped values."
  (let ((alpha (%byte a)))
    (make-color (round (* (%byte r) alpha) 255)
                (round (* (%byte g) alpha) 255)
                (round (* (%byte b) alpha) 255)
                alpha)))

(defun color-multiply (color scale)
  "Color.Multiply(Color, float): every channel scaled and clamped."
  (cna-lisp.internal:with-binary32-semantics
   (let ((s (coerce scale 'single-float)))
    (make-color (%byte (* (color-r color) s))
                (%byte (* (color-g color) s))
                (%byte (* (color-b color) s))
                (%byte (* (color-a color) s))))))
