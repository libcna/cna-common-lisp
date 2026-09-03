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
  "Color(int, int, int, int) with A defaulting to fully opaque.

Arguments outside 0-255 are clamped, which is what the original does: it checks
whether any argument has a bit above the low byte and, if so, clamps each one
through a 64-bit range check before packing. For the float constructors, see
MAKE-COLOR-FROM-FLOATS -- they are a different overload with a different scale,
and `(make-color 1 1 1)' is very nearly black where
`(make-color-from-floats 1.0 1.0 1.0)' is white."
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

(declaim (inline %clamp-to-byte))
(defun %clamp-to-byte (n)
  "Color.ClampToByte32/64: an integer into 0-255, without rounding."
  (cond ((< n 0) 0) ((> n 255) 255) (t n)))

(defun color-from-non-premultiplied (r g b a)
  "Color.FromNonPremultiplied(int, int, int, int).

Each colour channel is multiplied by the *unclamped* alpha and divided by 255 in
integer arithmetic -- truncating, not rounding -- and only the quotient is
clamped. Alpha is clamped on its own. Both details are visible: 5 at alpha 200
answers 3 and not 4, and 300 at alpha 100 answers 117 and not 100."
  (%make-color (logior (%clamp-to-byte (truncate (* r a) 255))
                       (ash (%clamp-to-byte (truncate (* g a) 255)) 8)
                       (ash (%clamp-to-byte (truncate (* b a) 255)) 16)
                       (ash (%clamp-to-byte a) 24))))

(defun color-multiply (color scale)
  "Color.Multiply(Color, float).

Not a float scale rounded back to bytes: the original converts SCALE to a 16.16
fixed-point factor by truncation, multiplies each channel in integer arithmetic,
shifts right by 16 -- which floors -- and only then clamps at 255. So scaling
white by 0.5 answers 127, where rounding the float would answer 128.

A NaN scale is left unspecified by the original, which converts it to an
unsigned integer without a defined result; this projection answers a scale of
zero rather than inventing one."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((scaled (* (f scale) 65536.0f0))
           (factor (cond ((cna-lisp.internal:nan-p scaled) 0)
                         ((< scaled 0.0f0) 0)
                         ((> scaled 16777215.0f0) #xFFFFFF)
                         (t (truncate scaled))))
           (packed (color-packed-value color)))
      (flet ((channel (shift)
               (min 255 (ash (* (ldb (byte 8 shift) packed) factor) -16))))
        (%make-color (logior (channel 0)
                             (ash (channel 8) 8)
                             (ash (channel 16) 16)
                             (ash (channel 24) 24)))))))

;;; --- the float and vector forms -------------------------------------------
;;;
;;; XNA's float constructors do not clamp-and-scale the way the integer ones
;;; clamp: they go through PackUtils.PackUNorm, which multiplies by 255, then
;;; clamps into [0, 255], then rounds with `Math.Round(double)' -- and that
;;; rounds halves **to even**, so 0.5/255 packs to 0 and 1.5/255 packs to 2. It
;;; also has answers for the values arithmetic can produce and a byte cannot: a
;;; NaN packs to 0, +Inf to 255 and -Inf to 0.

(defun %pack-unorm (bitmask value)
  "PackUtils.PackUNorm(BITMASK, VALUE), for the 255 the colour channels use."
  (cna-lisp.internal:with-binary32-semantics
    (let ((scaled (* (f value) (f bitmask))))
      (cond ((cna-lisp.internal:nan-p scaled) 0)
            ((cna-lisp.internal:infinity-p scaled) (if (plusp scaled) (round bitmask) 0))
            ((< scaled 0.0f0) 0)
            ((> scaled (f bitmask)) (round bitmask))
            ;; CL's ROUND is round-half-to-even, which is what Math.Round(double)
            ;; does. Rounding half away from zero here would shift a whole class
            ;; of colours by one.
            (t (round (float scaled 1.0d0)))))))

(defun %pack-color (x y z w)
  "Color.PackHelper: four unit floats to one packed RGBA value."
  (logior (%pack-unorm 255.0f0 x)
          (ash (%pack-unorm 255.0f0 y) 8)
          (ash (%pack-unorm 255.0f0 z) 16)
          (ash (%pack-unorm 255.0f0 w) 24)))

(defun make-color-from-floats (r g b &optional (a 1.0f0))
  "Color(float, float, float) and Color(float, float, float, float).

A separate constructor from MAKE-COLOR rather than a type-dispatching one: XNA
tells the two apart by static type, and Common Lisp would have to tell `1' from
`1.0' at run time to do the same. Those two mean almost opposite colours, so the
distinction is a name here rather than a numeric type nobody can see."
  (%make-color (%pack-color r g b a)))

(defun make-color-from-vector3 (vector)
  "Color(Vector3), with alpha fully opaque."
  (%make-color (%pack-color (vector3-x vector) (vector3-y vector) (vector3-z vector)
                            1.0f0)))

(defun make-color-from-vector4 (vector)
  "Color(Vector4)."
  (%make-color (%pack-color (vector4-x vector) (vector4-y vector) (vector4-z vector)
                            (vector4-w vector))))

(defun color-from-non-premultiplied-vector4 (vector)
  "Color.FromNonPremultiplied(Vector4): multiply RGB by alpha, then pack.

A separate name from COLOR-FROM-NON-PREMULTIPLIED because the two overloads do
not agree beyond their name: the integer one truncates an integer quotient and
this one packs unit floats through PackUNorm."
  (cna-lisp.internal:with-binary32-semantics
    (let ((w (vector4-w vector)))
      (%make-color (%pack-color (* (vector4-x vector) w)
                                (* (vector4-y vector) w)
                                (* (vector4-z vector) w)
                                w)))))

(defun %unpack-unorm (value)
  "PackUtils.UnpackUNorm(255, VALUE): a channel byte back to a unit float."
  (cna-lisp.internal:with-binary32-semantics
    (/ (float (logand value 255) 1.0f0) 255.0f0)))

(defun color-to-vector3 (color)
  "Color.ToVector3: R, G and B as unit floats. Alpha is dropped, not carried."
  (let ((packed (color-packed-value color)))
    (make-vector3 (%unpack-unorm packed)
                  (%unpack-unorm (ash packed -8))
                  (%unpack-unorm (ash packed -16)))))

(defun color-to-vector4 (color)
  "Color.ToVector4: all four channels as unit floats."
  (let ((packed (color-packed-value color)))
    (make-vector4 (%unpack-unorm packed)
                  (%unpack-unorm (ash packed -8))
                  (%unpack-unorm (ash packed -16))
                  (%unpack-unorm (ash packed -24)))))

(defun color-lerp (value1 value2 amount)
  "Color.Lerp.

Not a float interpolation rounded back to bytes: the original converts AMOUNT to
a 16.16 fixed-point weight with PackUNorm(65536, amount) and interpolates each
channel in integer arithmetic, shifting right by 16. That shift is *arithmetic*,
so it floors, and a channel that is falling interpolates a half-step lower than
a channel that is rising. Reproduced, because a float version would disagree by
one on a large fraction of the inputs."
  (let* ((packed1 (color-packed-value value1))
         (packed2 (color-packed-value value2))
         (weight (%pack-unorm 65536.0f0 amount)))
    (flet ((channel (shift)
             (let ((from (ldb (byte 8 shift) packed1))
                   (to (ldb (byte 8 shift) packed2)))
               (+ from (ash (* (- to from) weight) -16)))))
      (%make-color (logior (channel 0)
                           (ash (channel 8) 8)
                           (ash (channel 16) 16)
                           (ash (channel 24) 24))))))
