;;;; native-values.lisp --- writing projected value types into CNA aggregates.
;;;;
;;;; Three writers, in one place because more than one type of native descriptor
;;;; carries a Color, a Rectangle or a Vector2, and a second copy of the packing
;;;; rule is a second thing that can be wrong. They are private, and they write
;;;; into a caller-allocated foreign aggregate rather than allocating one.

(in-package #:microsoft.xna.framework.graphics)

(defun %write-packed-color (pointer struct-name slot-name color)
  "Store a Color into an aggregate field.

CNA_Color is four bytes in the order R G B A, which is exactly the packed value,
so one 32-bit store writes it."
  (setf (cffi:mem-ref (cffi:foreign-slot-pointer pointer (list :struct struct-name) slot-name)
                      :uint32)
        (microsoft.xna.framework:color-packed-value color)))

(defun %write-rectangle (pointer rectangle)
  "Store a Rectangle into an aggregate field."
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-rectangle) ',name)))
    (setf (slot cna-lisp.internal.ffi::x) (microsoft.xna.framework:rectangle-x rectangle)
          (slot cna-lisp.internal.ffi::y) (microsoft.xna.framework:rectangle-y rectangle)
          (slot cna-lisp.internal.ffi::width) (microsoft.xna.framework:rectangle-width rectangle)
          (slot cna-lisp.internal.ffi::height)
          (microsoft.xna.framework:rectangle-height rectangle))))

(defun %write-vector2 (pointer vector2)
  "Store a Vector2, or zero when there is none."
  (setf (cffi:foreign-slot-value pointer '(:struct cna-lisp.internal.ffi::cna-vector-2)
                                 'cna-lisp.internal.ffi::x)
        (if vector2 (microsoft.xna.framework:vector2-x vector2) 0.0f0)
        (cffi:foreign-slot-value pointer '(:struct cna-lisp.internal.ffi::cna-vector-2)
                                 'cna-lisp.internal.ffi::y)
        (if vector2 (microsoft.xna.framework:vector2-y vector2) 0.0f0)))

;;; --- reading CNA's vector and matrix aggregates back ------------------------
;;;
;;; The effect surface answers vectors and matrices through out-pointers, so
;;; these read a caller-allocated aggregate into the projected value type. The
;;; *writers* are not here: a Vector3 goes to CNA by value, flattened to a
;;; :double and a :float, which is a calling-convention matter and lives with the
;;; call sites that pass it.

(defun %read-vector2 (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-vector-2) ',name)))
    (microsoft.xna.framework:make-vector2 (slot cna-lisp.internal.ffi::x)
                                          (slot cna-lisp.internal.ffi::y))))

(defun %read-vector3 (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-vector-3) ',name)))
    (microsoft.xna.framework:make-vector3 (slot cna-lisp.internal.ffi::x)
                                          (slot cna-lisp.internal.ffi::y)
                                          (slot cna-lisp.internal.ffi::z))))

(defun %read-vector4 (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-vector-4) ',name)))
    (microsoft.xna.framework:make-vector4 (slot cna-lisp.internal.ffi::x)
                                          (slot cna-lisp.internal.ffi::y)
                                          (slot cna-lisp.internal.ffi::z)
                                          (slot cna-lisp.internal.ffi::w))))

(defmacro %with-matrix-slots ((pointer) &body body)
  `(macrolet ((slot (name)
                `(cffi:foreign-slot-value
                  ,',pointer '(:struct cna-lisp.internal.ffi::cna-matrix) ',name)))
     ,@body))

(defun %read-matrix (pointer)
  "CNA_Matrix and Microsoft.Xna.Framework.Matrix are both row-major m11..m44."
  (%with-matrix-slots (pointer)
    (microsoft.xna.framework:make-matrix
     (slot cna-lisp.internal.ffi::m-11) (slot cna-lisp.internal.ffi::m-12)
     (slot cna-lisp.internal.ffi::m-13) (slot cna-lisp.internal.ffi::m-14)
     (slot cna-lisp.internal.ffi::m-21) (slot cna-lisp.internal.ffi::m-22)
     (slot cna-lisp.internal.ffi::m-23) (slot cna-lisp.internal.ffi::m-24)
     (slot cna-lisp.internal.ffi::m-31) (slot cna-lisp.internal.ffi::m-32)
     (slot cna-lisp.internal.ffi::m-33) (slot cna-lisp.internal.ffi::m-34)
     (slot cna-lisp.internal.ffi::m-41) (slot cna-lisp.internal.ffi::m-42)
     (slot cna-lisp.internal.ffi::m-43) (slot cna-lisp.internal.ffi::m-44))))

(defun %write-matrix (pointer matrix)
  (%with-matrix-slots (pointer)
    (setf (slot cna-lisp.internal.ffi::m-11) (microsoft.xna.framework:matrix-m11 matrix)
          (slot cna-lisp.internal.ffi::m-12) (microsoft.xna.framework:matrix-m12 matrix)
          (slot cna-lisp.internal.ffi::m-13) (microsoft.xna.framework:matrix-m13 matrix)
          (slot cna-lisp.internal.ffi::m-14) (microsoft.xna.framework:matrix-m14 matrix)
          (slot cna-lisp.internal.ffi::m-21) (microsoft.xna.framework:matrix-m21 matrix)
          (slot cna-lisp.internal.ffi::m-22) (microsoft.xna.framework:matrix-m22 matrix)
          (slot cna-lisp.internal.ffi::m-23) (microsoft.xna.framework:matrix-m23 matrix)
          (slot cna-lisp.internal.ffi::m-24) (microsoft.xna.framework:matrix-m24 matrix)
          (slot cna-lisp.internal.ffi::m-31) (microsoft.xna.framework:matrix-m31 matrix)
          (slot cna-lisp.internal.ffi::m-32) (microsoft.xna.framework:matrix-m32 matrix)
          (slot cna-lisp.internal.ffi::m-33) (microsoft.xna.framework:matrix-m33 matrix)
          (slot cna-lisp.internal.ffi::m-34) (microsoft.xna.framework:matrix-m34 matrix)
          (slot cna-lisp.internal.ffi::m-41) (microsoft.xna.framework:matrix-m41 matrix)
          (slot cna-lisp.internal.ffi::m-42) (microsoft.xna.framework:matrix-m42 matrix)
          (slot cna-lisp.internal.ffi::m-43) (microsoft.xna.framework:matrix-m43 matrix)
          (slot cna-lisp.internal.ffi::m-44) (microsoft.xna.framework:matrix-m44 matrix)))
  pointer)

(defun %vector3-eightbytes (vector3)
  "The two scalars a CNA_Vector3 becomes when passed by value.

X and Y share one SSE eightbyte and travel as a double; Z is a trailing
four-byte eightbyte and travels as a float. See tools/native-abi/manifest.json's
by-value rule, and the proof in tests/native/struct-passing.lisp."
  (cffi:with-foreign-object (pair :float 2)
    (setf (cffi:mem-aref pair :float 0) (microsoft.xna.framework:vector3-x vector3)
          (cffi:mem-aref pair :float 1) (microsoft.xna.framework:vector3-y vector3))
    (values (cffi:mem-ref pair :double) (microsoft.xna.framework:vector3-z vector3))))
