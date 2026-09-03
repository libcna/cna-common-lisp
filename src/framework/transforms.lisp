;;;; transforms.lisp --- transforming vectors by matrices and quaternions.
;;;;
;;;; These live in their own file because they are the one place where the vector
;;;; types and the rotation types meet, and neither can be said to come first.
;;;; Every expression is read out of the pinned XNA 4.0 Windows IL; the row-vector
;;;; convention -- a point multiplied on the *left* of a row-major matrix, so the
;;;; translation comes from M41 M42 M43 -- is what most of these encode.

(in-package #:microsoft.xna.framework)

;;; --- rotation by a quaternion, shared -------------------------------------

(defmacro %with-rotation-terms (quaternion &body body)
  "Bind the twelve products XNA computes once per quaternion rotation.

The framework computes them in this order and reuses them across the three (or
two) components; recomputing them per component would answer the same real
numbers and different binary32."
  `(%with-q (qx qy qz qw) ,quaternion
     (let* ((x2 (+ qx qx)) (y2 (+ qy qy)) (z2 (+ qz qz))
            (wx (* qw x2)) (wy (* qw y2)) (wz (* qw z2))
            (xx (* qx x2)) (xy (* qx y2)) (xz (* qx z2))
            (yy (* qy y2)) (yz (* qy z2)) (zz (* qz z2)))
       (declare (ignorable wx wy wz xx xy xz yy yz zz))
       ,@body)))

;;; --- Vector2 ---------------------------------------------------------------

(defgeneric vector2-transform (value transform)
  (:documentation
   "Vector2.Transform, by a Matrix or by a Quaternion.

The matrix form includes the translation row; VECTOR2-TRANSFORM-NORMAL is the one
that does not."))

(defmethod vector2-transform ((value vector2) (transform matrix))
  (cna-lisp.internal:with-binary32-semantics
    (let ((x (vector2-x value)) (y (vector2-y value)))
      (%make-vector2
       (+ (+ (* x (matrix-m11 transform)) (* y (matrix-m21 transform)))
          (matrix-m41 transform))
       (+ (+ (* x (matrix-m12 transform)) (* y (matrix-m22 transform)))
          (matrix-m42 transform))))))

(defmethod vector2-transform ((value vector2) (transform quaternion))
  (cna-lisp.internal:with-binary32-semantics
    (%with-rotation-terms transform
      (let ((x (vector2-x value)) (y (vector2-y value)))
        (%make-vector2
         (+ (* x (- (- 1.0f0 yy) zz)) (* y (- xy wz)))
         (+ (* x (+ xy wz)) (* y (- (- 1.0f0 xx) zz))))))))

(defun vector2-transform-normal (normal matrix)
  "Vector2.TransformNormal: the matrix form without the translation."
  (cna-lisp.internal:with-binary32-semantics
    (let ((x (vector2-x normal)) (y (vector2-y normal)))
      (%make-vector2 (+ (* x (matrix-m11 matrix)) (* y (matrix-m21 matrix)))
                     (+ (* x (matrix-m12 matrix)) (* y (matrix-m22 matrix)))))))

;;; --- Vector3 ---------------------------------------------------------------

(defgeneric vector3-transform (value transform)
  (:documentation "Vector3.Transform, by a Matrix or by a Quaternion."))

(defmethod vector3-transform ((value vector3) (transform matrix))
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (x y z) value
      (%make-vector3
       (+ (+ (+ (* x (matrix-m11 transform)) (* y (matrix-m21 transform)))
             (* z (matrix-m31 transform)))
          (matrix-m41 transform))
       (+ (+ (+ (* x (matrix-m12 transform)) (* y (matrix-m22 transform)))
             (* z (matrix-m32 transform)))
          (matrix-m42 transform))
       (+ (+ (+ (* x (matrix-m13 transform)) (* y (matrix-m23 transform)))
             (* z (matrix-m33 transform)))
          (matrix-m43 transform))))))

(defmethod vector3-transform ((value vector3) (transform quaternion))
  (cna-lisp.internal:with-binary32-semantics
    (%with-rotation-terms transform
      (%with-v3 (x y z) value
        (%make-vector3
         (+ (+ (* x (- (- 1.0f0 yy) zz)) (* y (- xy wz))) (* z (+ xz wy)))
         (+ (+ (* x (+ xy wz)) (* y (- (- 1.0f0 xx) zz))) (* z (- yz wx)))
         (+ (+ (* x (- xz wy)) (* y (+ yz wx))) (* z (- (- 1.0f0 xx) yy))))))))

(defun vector3-transform-normal (normal matrix)
  "Vector3.TransformNormal: the matrix form without the translation."
  (cna-lisp.internal:with-binary32-semantics
    (%with-v3 (x y z) normal
      (%make-vector3
       (+ (+ (* x (matrix-m11 matrix)) (* y (matrix-m21 matrix)))
          (* z (matrix-m31 matrix)))
       (+ (+ (* x (matrix-m12 matrix)) (* y (matrix-m22 matrix)))
          (* z (matrix-m32 matrix)))
       (+ (+ (* x (matrix-m13 matrix)) (* y (matrix-m23 matrix)))
          (* z (matrix-m33 matrix)))))))

;;; --- Vector4 ---------------------------------------------------------------

(defgeneric vector4-transform (value transform)
  (:documentation
   "Vector4.Transform: a Vector2, Vector3 or Vector4 by a Matrix or a Quaternion,
answering a Vector4.

The shorter inputs are extended the way the framework extends them: a Vector2 or
Vector3 rotated by a quaternion answers W = 1, while a Vector4 keeps its own W."))

(macrolet ((define-matrix-transform (specializer x y z w)
             `(defmethod vector4-transform ((value ,specializer) (transform matrix))
                (cna-lisp.internal:with-binary32-semantics
                  (let ((x ,x) (y ,y) (z ,z) (w ,w))
                    (declare (ignorable z w))
                    (macrolet ((column (c1 c2 c3 c4)
                                 `(+ (+ (+ (* x (,c1 transform)) (* y (,c2 transform)))
                                        (* z (,c3 transform)))
                                     (* w (,c4 transform)))))
                      (%make-vector4
                       (column matrix-m11 matrix-m21 matrix-m31 matrix-m41)
                       (column matrix-m12 matrix-m22 matrix-m32 matrix-m42)
                       (column matrix-m13 matrix-m23 matrix-m33 matrix-m43)
                       (column matrix-m14 matrix-m24 matrix-m34 matrix-m44))))))))
  (define-matrix-transform vector2 (vector2-x value) (vector2-y value) 0.0f0 1.0f0)
  (define-matrix-transform vector3 (vector3-x value) (vector3-y value)
    (vector3-z value) 1.0f0)
  (define-matrix-transform vector4 (vector4-x value) (vector4-y value)
    (vector4-z value) (vector4-w value)))

(macrolet ((define-quaternion-transform (specializer x y z w)
             `(defmethod vector4-transform ((value ,specializer) (transform quaternion))
                (cna-lisp.internal:with-binary32-semantics
                  (%with-rotation-terms transform
                    (let ((x ,x) (y ,y) (z ,z))
                      (%make-vector4
                       (+ (+ (* x (- (- 1.0f0 yy) zz)) (* y (- xy wz))) (* z (+ xz wy)))
                       (+ (+ (* x (+ xy wz)) (* y (- (- 1.0f0 xx) zz))) (* z (- yz wx)))
                       (+ (+ (* x (- xz wy)) (* y (+ yz wx))) (* z (- (- 1.0f0 xx) yy)))
                       ,w)))))))
  (define-quaternion-transform vector2 (vector2-x value) (vector2-y value) 0.0f0 1.0f0)
  (define-quaternion-transform vector3 (vector3-x value) (vector3-y value)
    (vector3-z value) 1.0f0)
  (define-quaternion-transform vector4 (vector4-x value) (vector4-y value)
    (vector4-z value) (vector4-w value)))

;;; --- the bulk forms ---------------------------------------------------------
;;;
;;; XNA has a three-argument overload that transforms whole arrays and a
;;; six-argument one that transforms a window of them. They differ only by
;;; trailing parameters, so one function with keyword arguments expresses both.

(defmacro %define-array-transform (name element-transform documentation)
  `(defun ,name (source transform destination
                 &key (source-index 0) (destination-index 0) length)
     ,documentation
     (check-type source sequence)
     (check-type destination sequence)
     (let ((count (or length (- (length source) source-index))))
       (when (< (- (length source) source-index) count)
         (error 'cna-argument-out-of-range-error
                :operation ,(string-downcase (symbol-name name))
                :parameter-name "source"
                :format-control "the source holds ~d element~:p from index ~d, not ~d"
                :format-arguments (list (- (length source) source-index)
                                        source-index count)))
       (when (< (- (length destination) destination-index) count)
         (error 'cna-argument-out-of-range-error
                :operation ,(string-downcase (symbol-name name))
                :parameter-name "destination"
                :format-control "the destination holds ~d element~:p from index ~d, not ~d"
                :format-arguments (list (- (length destination) destination-index)
                                        destination-index count)))
       (dotimes (i count destination)
         (setf (elt destination (+ destination-index i))
               (,element-transform (elt source (+ source-index i)) transform))))))

(%define-array-transform vector2-transform-array vector2-transform
  "Vector2.Transform over an array, by a Matrix or a Quaternion.

SOURCE-INDEX, DESTINATION-INDEX and LENGTH express the windowed overload; with
none of them the whole of SOURCE is transformed. DESTINATION is answered.")

(%define-array-transform vector2-transform-normal-array vector2-transform-normal
  "Vector2.TransformNormal over an array. See VECTOR2-TRANSFORM-ARRAY.")

(%define-array-transform vector3-transform-array vector3-transform
  "Vector3.Transform over an array, by a Matrix or a Quaternion.
See VECTOR2-TRANSFORM-ARRAY.")

(%define-array-transform vector3-transform-normal-array vector3-transform-normal
  "Vector3.TransformNormal over an array. See VECTOR2-TRANSFORM-ARRAY.")

(%define-array-transform vector4-transform-array vector4-transform
  "Vector4.Transform over an array, by a Matrix or a Quaternion.
See VECTOR2-TRANSFORM-ARRAY.")
