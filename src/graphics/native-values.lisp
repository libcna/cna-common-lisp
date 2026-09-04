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
