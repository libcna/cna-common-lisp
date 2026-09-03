;;;; matrix.lisp --- Microsoft.Xna.Framework.Matrix.
;;;;
;;;; Row-major, row-vector convention: a point is a row and is multiplied on the
;;;; left, the translation lives in M41 M42 M43, and `Multiply(a, b)' applies a
;;;; first. Getting that wrong is the single most common way a matrix library
;;;; disagrees with XNA while every individual formula looks right, so the whole
;;;; of this file was read out of the pinned IL rather than derived.

(in-package #:microsoft.xna.framework)

(defstruct (matrix
            (:constructor %make-matrix (m11 m12 m13 m14 m21 m22 m23 m24
                                        m31 m32 m33 m34 m41 m42 m43 m44))
            (:copier copy-matrix))
  "Microsoft.Xna.Framework.Matrix: a 4x4 binary32 matrix, row-major."
  (m11 0.0f0 :type single-float) (m12 0.0f0 :type single-float)
  (m13 0.0f0 :type single-float) (m14 0.0f0 :type single-float)
  (m21 0.0f0 :type single-float) (m22 0.0f0 :type single-float)
  (m23 0.0f0 :type single-float) (m24 0.0f0 :type single-float)
  (m31 0.0f0 :type single-float) (m32 0.0f0 :type single-float)
  (m33 0.0f0 :type single-float) (m34 0.0f0 :type single-float)
  (m41 0.0f0 :type single-float) (m42 0.0f0 :type single-float)
  (m43 0.0f0 :type single-float) (m44 0.0f0 :type single-float))

(defun make-matrix (&optional (m11 0.0f0) (m12 0.0f0) (m13 0.0f0) (m14 0.0f0)
                              (m21 0.0f0) (m22 0.0f0) (m23 0.0f0) (m24 0.0f0)
                              (m31 0.0f0) (m32 0.0f0) (m33 0.0f0) (m34 0.0f0)
                              (m41 0.0f0) (m42 0.0f0) (m43 0.0f0) (m44 0.0f0))
  "Matrix(float x 16), in row order."
  (%make-matrix (f m11) (f m12) (f m13) (f m14) (f m21) (f m22) (f m23) (f m24)
                (f m31) (f m32) (f m33) (f m34) (f m41) (f m42) (f m43) (f m44)))

(defun matrix-identity ()
  "Matrix.Identity."
  (%make-matrix 1.0f0 0.0f0 0.0f0 0.0f0
                0.0f0 1.0f0 0.0f0 0.0f0
                0.0f0 0.0f0 1.0f0 0.0f0
                0.0f0 0.0f0 0.0f0 1.0f0))

(defmacro %with-m (matrix &body body)
  "Bind M11 .. M44 to the components of MATRIX."
  `(let ,(loop for row from 1 to 4
               append (loop for column from 1 to 4
                            for name = (intern (format nil "M~d~d" row column))
                            collect `(,name (,(intern (format nil "MATRIX-M~d~d" row column))
                                             ,matrix))))
     (declare (ignorable ,@(loop for row from 1 to 4
                                 append (loop for column from 1 to 4
                                              collect (intern (format nil "M~d~d" row column))))))
     ,@body))

;;; --- the basis rows -------------------------------------------------------

(macrolet ((define-row (name row negate documentation)
             (let ((x (intern (format nil "MATRIX-M~d1" row)))
                   (y (intern (format nil "MATRIX-M~d2" row)))
                   (z (intern (format nil "MATRIX-M~d3" row))))
               `(progn
                  (defun ,name (matrix)
                    ,documentation
                    ,(if negate
                         `(%make-vector3 (- (,x matrix)) (- (,y matrix)) (- (,z matrix)))
                         `(%make-vector3 (,x matrix) (,y matrix) (,z matrix))))
                  (defun (setf ,name) (vector matrix)
                    (setf (,x matrix) ,(if negate `(- (vector3-x vector)) `(vector3-x vector))
                          (,y matrix) ,(if negate `(- (vector3-y vector)) `(vector3-y vector))
                          (,z matrix) ,(if negate `(- (vector3-z vector)) `(vector3-z vector)))
                    vector)))))
  (define-row matrix-right 1 nil "Matrix.Right: the first row's vector part.")
  (define-row matrix-left 1 t "Matrix.Left: the negated first row.")
  (define-row matrix-up 2 nil "Matrix.Up: the second row's vector part.")
  (define-row matrix-down 2 t "Matrix.Down: the negated second row.")
  (define-row matrix-backward 3 nil "Matrix.Backward: the third row's vector part.")
  (define-row matrix-forward 3 t "Matrix.Forward: the negated third row.")
  (define-row matrix-translation 4 nil "Matrix.Translation: the fourth row's vector part."))

;;; --- factories -------------------------------------------------------------

(defgeneric matrix-create-translation (x &optional y z)
  (:documentation "Matrix.CreateTranslation, from a Vector3 or from three floats."))

(defmethod matrix-create-translation ((position vector3) &optional y z)
  (declare (ignore y z))
  (matrix-create-translation (vector3-x position) (vector3-y position) (vector3-z position)))

(defmethod matrix-create-translation ((x real) &optional (y 0.0f0) (z 0.0f0))
  (%make-matrix 1.0f0 0.0f0 0.0f0 0.0f0
                0.0f0 1.0f0 0.0f0 0.0f0
                0.0f0 0.0f0 1.0f0 0.0f0
                (f x) (f y) (f z) 1.0f0))

(defgeneric matrix-create-scale (x &optional y z)
  (:documentation
   "Matrix.CreateScale, from a Vector3, from three floats, or from one uniform
float."))

(defmethod matrix-create-scale ((scale vector3) &optional y z)
  (declare (ignore y z))
  (matrix-create-scale (vector3-x scale) (vector3-y scale) (vector3-z scale)))

(defmethod matrix-create-scale ((x real) &optional (y nil y-supplied-p) z)
  (let* ((sx (f x))
         (sy (if y-supplied-p (f y) sx))
         (sz (if y-supplied-p (f (or z 0.0f0)) sx)))
    (%make-matrix sx 0.0f0 0.0f0 0.0f0
                  0.0f0 sy 0.0f0 0.0f0
                  0.0f0 0.0f0 sz 0.0f0
                  0.0f0 0.0f0 0.0f0 1.0f0)))

(defmacro %sin-cos ((sine cosine) angle &body body)
  (let ((radians (gensym "RADIANS")))
    `(let* ((,radians (coerce (f ,angle) 'double-float))
            (,cosine (f (cos ,radians)))
            (,sine (f (sin ,radians))))
       ,@body)))

(defun matrix-create-rotation-x (radians)
  "Matrix.CreateRotationX."
  (cna-lisp.internal:with-binary32-semantics
    (%sin-cos (s c) radians
      (%make-matrix 1.0f0 0.0f0 0.0f0 0.0f0
                    0.0f0 c s 0.0f0
                    0.0f0 (- s) c 0.0f0
                    0.0f0 0.0f0 0.0f0 1.0f0))))

(defun matrix-create-rotation-y (radians)
  "Matrix.CreateRotationY."
  (cna-lisp.internal:with-binary32-semantics
    (%sin-cos (s c) radians
      (%make-matrix c 0.0f0 (- s) 0.0f0
                    0.0f0 1.0f0 0.0f0 0.0f0
                    s 0.0f0 c 0.0f0
                    0.0f0 0.0f0 0.0f0 1.0f0))))

(defun matrix-create-rotation-z (radians)
  "Matrix.CreateRotationZ."
  (cna-lisp.internal:with-binary32-semantics
    (%sin-cos (s c) radians
      (%make-matrix c s 0.0f0 0.0f0
                    (- s) c 0.0f0 0.0f0
                    0.0f0 0.0f0 1.0f0 0.0f0
                    0.0f0 0.0f0 0.0f0 1.0f0))))

(defun matrix-create-from-axis-angle (axis angle)
  "Matrix.CreateFromAxisAngle."
  (cna-lisp.internal:with-binary32-semantics
    (%sin-cos (s c) angle
      (let* ((x (vector3-x axis)) (y (vector3-y axis)) (z (vector3-z axis))
             (xx (* x x)) (yy (* y y)) (zz (* z z))
             (xy (* x y)) (xz (* x z)) (yz (* y z)))
        (%make-matrix (+ xx (* c (- 1.0f0 xx)))
                      (+ (- xy (* c xy)) (* s z))
                      (- (- xz (* c xz)) (* s y))
                      0.0f0
                      (- (- xy (* c xy)) (* s z))
                      (+ yy (* c (- 1.0f0 yy)))
                      (+ (- yz (* c yz)) (* s x))
                      0.0f0
                      (+ (- xz (* c xz)) (* s y))
                      (- (- yz (* c yz)) (* s x))
                      (+ zz (* c (- 1.0f0 zz)))
                      0.0f0
                      0.0f0 0.0f0 0.0f0 1.0f0)))))

(defun matrix-create-from-quaternion (quaternion)
  "Matrix.CreateFromQuaternion."
  (cna-lisp.internal:with-binary32-semantics
    (%with-q (x y z w) quaternion
      (let ((xx (* x x)) (yy (* y y)) (zz (* z z))
            (xy (* x y)) (zw (* z w)) (zx (* z x))
            (yw (* y w)) (yz (* y z)) (xw (* x w)))
        (%make-matrix (- 1.0f0 (* 2.0f0 (+ yy zz)))
                      (* 2.0f0 (+ xy zw))
                      (* 2.0f0 (- zx yw))
                      0.0f0
                      (* 2.0f0 (- xy zw))
                      (- 1.0f0 (* 2.0f0 (+ zz xx)))
                      (* 2.0f0 (+ yz xw))
                      0.0f0
                      (* 2.0f0 (+ zx yw))
                      (* 2.0f0 (- yz xw))
                      (- 1.0f0 (* 2.0f0 (+ yy xx)))
                      0.0f0
                      0.0f0 0.0f0 0.0f0 1.0f0)))))

(defun quaternion-create-from-rotation-matrix (matrix)
  "Quaternion.CreateFromRotationMatrix.

Four branches on the matrix trace and its diagonal, in the framework's own order.
The largest diagonal term decides which component is recovered from a square root
and which three are recovered from off-diagonal differences, which is what keeps
the result stable."
  (cna-lisp.internal:with-binary32-semantics
    (macrolet ((m (name) `(,(intern (format nil "MATRIX-~a" name)
                                    '#:microsoft.xna.framework)
                           matrix)))
      (let ((trace (+ (+ (m m11) (m m22)) (m m33))))
        (cond
          ((> trace 0.0f0)
           (let* ((root (%sqrt-as-xna (+ trace 1.0f0)))
                  (w (* root 0.5f0))
                  (scale (/ 0.5f0 root)))
             (%make-quaternion (* (- (m m23) (m m32)) scale)
                               (* (- (m m31) (m m13)) scale)
                               (* (- (m m12) (m m21)) scale)
                               w)))
          ((and (>= (m m11) (m m22)) (>= (m m11) (m m33)))
           (let* ((root (%sqrt-as-xna (- (- (+ 1.0f0 (m m11)) (m m22)) (m m33))))
                  (scale (/ 0.5f0 root)))
             (%make-quaternion (* 0.5f0 root)
                               (* (+ (m m12) (m m21)) scale)
                               (* (+ (m m13) (m m31)) scale)
                               (* (- (m m23) (m m32)) scale))))
          ((> (m m22) (m m33))
           (let* ((root (%sqrt-as-xna (- (- (+ 1.0f0 (m m22)) (m m11)) (m m33))))
                  (scale (/ 0.5f0 root)))
             (%make-quaternion (* (+ (m m21) (m m12)) scale)
                               (* 0.5f0 root)
                               (* (+ (m m32) (m m23)) scale)
                               (* (- (m m31) (m m13)) scale))))
          (t
           (let* ((root (%sqrt-as-xna (- (- (+ 1.0f0 (m m33)) (m m11)) (m m22))))
                  (scale (/ 0.5f0 root)))
             (%make-quaternion (* (+ (m m31) (m m13)) scale)
                               (* (+ (m m32) (m m23)) scale)
                               (* 0.5f0 root)
                               (* (- (m m12) (m m21)) scale)))))))))

(defun matrix-create-from-yaw-pitch-roll (yaw pitch roll)
  "Matrix.CreateFromYawPitchRoll: the quaternion of the same name, as a matrix."
  (matrix-create-from-quaternion
   (quaternion-create-from-yaw-pitch-roll yaw pitch roll)))

(defun %out-of-range (parameter format-control &rest format-arguments)
  (error 'cna-argument-out-of-range-error
         :operation "matrix factory"
         :parameter-name parameter
         :format-control format-control
         :format-arguments format-arguments))

(defun matrix-create-perspective-field-of-view (field-of-view aspect-ratio
                                                near-plane-distance far-plane-distance)
  "Matrix.CreatePerspectiveFieldOfView.

The four range checks are the framework's own, and each refuses with the name of
the argument it is about, as ArgumentOutOfRangeException does there."
  (cna-lisp.internal:with-binary32-semantics
    (let ((fov (f field-of-view)) (aspect (f aspect-ratio))
          (near (f near-plane-distance)) (far (f far-plane-distance)))
      (when (or (<= fov 0.0f0) (>= fov +math-helper-pi+))
        (%out-of-range "field-of-view"
                       "the field of view must be greater than zero and less than pi; it is ~a"
                       fov))
      (when (<= near 0.0f0)
        (%out-of-range "near-plane-distance"
                       "the near plane distance must be positive; it is ~a" near))
      (when (<= far 0.0f0)
        (%out-of-range "far-plane-distance"
                       "the far plane distance must be positive; it is ~a" far))
      (when (>= near far)
        (%out-of-range "near-plane-distance"
                       "the near plane distance ~a must be less than the far plane distance ~a"
                       near far))
      (let* ((focal (/ 1.0f0 (f (tan (coerce (* fov 0.5f0) 'double-float)))))
             (scaled (/ focal aspect)))
        (%make-matrix scaled 0.0f0 0.0f0 0.0f0
                      0.0f0 focal 0.0f0 0.0f0
                      0.0f0 0.0f0 (/ far (- near far)) -1.0f0
                      0.0f0 0.0f0 (/ (* near far) (- near far)) 0.0f0)))))

(defun matrix-create-perspective (width height near-plane-distance far-plane-distance)
  "Matrix.CreatePerspective."
  (cna-lisp.internal:with-binary32-semantics
    (let ((w (f width)) (h (f height)) (near (f near-plane-distance))
          (far (f far-plane-distance)))
      (when (<= near 0.0f0)
        (%out-of-range "near-plane-distance"
                       "the near plane distance must be positive; it is ~a" near))
      (when (<= far 0.0f0)
        (%out-of-range "far-plane-distance"
                       "the far plane distance must be positive; it is ~a" far))
      (when (>= near far)
        (%out-of-range "near-plane-distance"
                       "the near plane distance ~a must be less than the far plane distance ~a"
                       near far))
      (%make-matrix (/ (* 2.0f0 near) w) 0.0f0 0.0f0 0.0f0
                    0.0f0 (/ (* 2.0f0 near) h) 0.0f0 0.0f0
                    0.0f0 0.0f0 (/ far (- near far)) -1.0f0
                    0.0f0 0.0f0 (/ (* near far) (- near far)) 0.0f0))))

(defun matrix-create-perspective-off-center (left right bottom top
                                             near-plane-distance far-plane-distance)
  "Matrix.CreatePerspectiveOffCenter."
  (cna-lisp.internal:with-binary32-semantics
    (let ((l (f left)) (r (f right)) (b (f bottom)) (tp (f top))
          (near (f near-plane-distance)) (far (f far-plane-distance)))
      (when (<= near 0.0f0)
        (%out-of-range "near-plane-distance"
                       "the near plane distance must be positive; it is ~a" near))
      (when (<= far 0.0f0)
        (%out-of-range "far-plane-distance"
                       "the far plane distance must be positive; it is ~a" far))
      (when (>= near far)
        (%out-of-range "near-plane-distance"
                       "the near plane distance ~a must be less than the far plane distance ~a"
                       near far))
      (%make-matrix (/ (* 2.0f0 near) (- r l)) 0.0f0 0.0f0 0.0f0
                    0.0f0 (/ (* 2.0f0 near) (- tp b)) 0.0f0 0.0f0
                    (/ (+ l r) (- r l)) (/ (+ tp b) (- tp b))
                    (/ far (- near far)) -1.0f0
                    0.0f0 0.0f0 (/ (* near far) (- near far)) 0.0f0))))

(defun matrix-create-orthographic (width height z-near-plane z-far-plane)
  "Matrix.CreateOrthographic."
  (cna-lisp.internal:with-binary32-semantics
    (let ((w (f width)) (h (f height)) (near (f z-near-plane)) (far (f z-far-plane)))
      (%make-matrix (/ 2.0f0 w) 0.0f0 0.0f0 0.0f0
                    0.0f0 (/ 2.0f0 h) 0.0f0 0.0f0
                    0.0f0 0.0f0 (/ 1.0f0 (- near far)) 0.0f0
                    0.0f0 0.0f0 (/ near (- near far)) 1.0f0))))

(defun matrix-create-orthographic-off-center (left right bottom top
                                              z-near-plane z-far-plane)
  "Matrix.CreateOrthographicOffCenter."
  (cna-lisp.internal:with-binary32-semantics
    (let ((l (f left)) (r (f right)) (b (f bottom)) (tp (f top))
          (near (f z-near-plane)) (far (f z-far-plane)))
      (%make-matrix (/ 2.0f0 (- r l)) 0.0f0 0.0f0 0.0f0
                    0.0f0 (/ 2.0f0 (- tp b)) 0.0f0 0.0f0
                    0.0f0 0.0f0 (/ 1.0f0 (- near far)) 0.0f0
                    (/ (+ l r) (- l r)) (/ (+ tp b) (- b tp))
                    (/ near (- near far)) 1.0f0))))

(defun matrix-create-look-at (camera-position camera-target camera-up-vector)
  "Matrix.CreateLookAt."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((forward (vector3-normalized (vector3-subtract camera-position camera-target)))
           (right (vector3-normalized (vector3-cross camera-up-vector forward)))
           (up (vector3-cross forward right)))
      (%make-matrix (vector3-x right) (vector3-x up) (vector3-x forward) 0.0f0
                    (vector3-y right) (vector3-y up) (vector3-y forward) 0.0f0
                    (vector3-z right) (vector3-z up) (vector3-z forward) 0.0f0
                    (- (vector3-dot right camera-position))
                    (- (vector3-dot up camera-position))
                    (- (vector3-dot forward camera-position))
                    1.0f0))))

(defun matrix-create-world (position forward up)
  "Matrix.CreateWorld.

The third row is the *negated, normalised* forward vector: XNA's world matrices
look down -Z."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((backward (vector3-normalized (vector3-negate forward)))
           (right (vector3-normalized (vector3-cross up backward)))
           (real-up (vector3-cross backward right)))
      (%make-matrix (vector3-x right) (vector3-y right) (vector3-z right) 0.0f0
                    (vector3-x real-up) (vector3-y real-up) (vector3-z real-up) 0.0f0
                    (vector3-x backward) (vector3-y backward) (vector3-z backward) 0.0f0
                    (vector3-x position) (vector3-y position) (vector3-z position) 1.0f0))))

(defun matrix-create-billboard (object-position camera-position camera-up-vector
                                &optional camera-forward-vector)
  "Matrix.CreateBillboard.

CAMERA-FORWARD-VECTOR is XNA's `Vector3?': NIL is the absent value, and it is
consulted only when the object and the camera are closer together than the
framework's own 0.0001f squared-distance threshold."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((delta (vector3-subtract object-position camera-position))
           (squared (vector3-length-squared delta))
           (forward (if (< squared 0.0001f0)
                        (if camera-forward-vector
                            (vector3-negate camera-forward-vector)
                            (vector3-forward))
                        (vector3-multiply delta
                                          (/ 1.0f0 (%sqrt-as-xna squared)))))
           (right (vector3-normalize (vector3-cross camera-up-vector forward)))
           (up (vector3-cross forward right)))
      (%make-matrix (vector3-x right) (vector3-y right) (vector3-z right) 0.0f0
                    (vector3-x up) (vector3-y up) (vector3-z up) 0.0f0
                    (vector3-x forward) (vector3-y forward) (vector3-z forward) 0.0f0
                    (vector3-x object-position) (vector3-y object-position)
                    (vector3-z object-position) 1.0f0))))

(defun %rank-by-magnitude (x y z)
  "The indices of the largest, the middle and the smallest of three values.

Written as the framework's own comparison chain rather than a sort, because the
chain decides the ties: each test is `less than', so equal values keep the order
0 < 1 < 2, and a NaN is treated as not-less-than everything it is compared with."
  (if (< x y)
      (if (< y z)
          (values 2 1 0)
          (if (< x z) (values 1 2 0) (values 1 0 2)))
      (if (< x z)
          (values 2 0 1)
          (if (< y z) (values 0 2 1) (values 0 1 2)))))

(defun %smallest-absolute-axis (vector)
  "The index of VECTOR's smallest component in absolute value, by the same chain."
  (let ((ax (abs (vector3-x vector)))
        (ay (abs (vector3-y vector)))
        (az (abs (vector3-z vector))))
    (if (< ax ay)
        (if (< ay az) 0 (if (< ax az) 0 2))
        (if (< ax az) 1 (if (< ay az) 1 2)))))

(defun matrix-decompose (matrix)
  "Matrix.Decompose.

Answers four values: whether the decomposition succeeded, then the scale, the
rotation and the translation -- XNA's return value first and its three `out'
parameters in their declared order.

**A false first value still comes with the other three.** When the rotation part
is not a rotation, the framework leaves the scale and the translation it computed
and sets the rotation to the identity quaternion. A caller that ignores the flag
gets a plausible-looking answer, so the flag is first.

The interesting half of this member is what it does with a matrix that has a
degenerate axis. It ranks the three axes by length, and for each one shorter than
1e-4 substitutes: the canonical unit axis for the longest, the cross product of
the longest axis with whichever canonical axis is most nearly perpendicular to it
for the middle one, and the cross product of the other two for the shortest. Then
it checks the determinant's sign, flips the longest axis and its scale if the
matrix is left-handed, and finally refuses -- identity rotation, false -- when the
determinant is not within 1e-4 of 1 after squaring the difference. All of that is
transcribed from the assembly; an implementation that agreed on well-conditioned
matrices and diverged here would be worse than none."
  (cna-lisp.internal:with-binary32-semantics
    (%with-m matrix
      (let* ((rows (vector (%make-vector3 m11 m12 m13)
                           (%make-vector3 m21 m22 m23)
                           (%make-vector3 m31 m32 m33)))
             (canonical (vector (vector3-unit-x) (vector3-unit-y) (vector3-unit-z)))
             (scale (make-array 3 :element-type 'single-float
                                  :initial-contents
                                  (list (vector3-length (aref rows 0))
                                        (vector3-length (aref rows 1))
                                        (vector3-length (aref rows 2)))))
             (translation (%make-vector3 m41 m42 m43)))
        (multiple-value-bind (a b c)
            (%rank-by-magnitude (aref scale 0) (aref scale 1) (aref scale 2))
          (when (< (aref scale a) 1.0f-4)
            (setf (aref rows a) (copy-vector3 (aref canonical a))))
          (vector3-normalize (aref rows a))
          (when (< (aref scale b) 1.0f-4)
            (setf (aref rows b)
                  (vector3-cross (aref rows a)
                                 (aref canonical (%smallest-absolute-axis (aref rows a))))))
          (vector3-normalize (aref rows b))
          (when (< (aref scale c) 1.0f-4)
            (setf (aref rows c) (vector3-cross (aref rows a) (aref rows b))))
          (vector3-normalize (aref rows c))
          (flet ((basis ()
                   ;; The rows sit in an otherwise identity matrix, so its
                   ;; determinant is the 3x3's.
                   (%make-matrix (vector3-x (aref rows 0)) (vector3-y (aref rows 0))
                                 (vector3-z (aref rows 0)) 0.0f0
                                 (vector3-x (aref rows 1)) (vector3-y (aref rows 1))
                                 (vector3-z (aref rows 1)) 0.0f0
                                 (vector3-x (aref rows 2)) (vector3-y (aref rows 2))
                                 (vector3-z (aref rows 2)) 0.0f0
                                 0.0f0 0.0f0 0.0f0 1.0f0)))
            (let ((determinant (matrix-determinant (basis))))
              (when (< determinant 0.0f0)
                ;; Left-handed: flip the longest axis and its scale, and take the
                ;; determinant's sign with it rather than recomputing it.
                (setf (aref scale a) (- (aref scale a))
                      (aref rows a) (vector3-negate (aref rows a))
                      determinant (- determinant)))
              (let ((error-squared (let ((d (- determinant 1.0f0))) (* d d)))
                    (scale-vector (%make-vector3 (aref scale 0) (aref scale 1)
                                                 (aref scale 2))))
                (if (< 1.0f-4 error-squared)
                    (values nil scale-vector (quaternion-identity) translation)
                    (values t scale-vector
                            (quaternion-create-from-rotation-matrix (basis))
                            translation))))))))))

(defconstant +billboard-degenerate-axis-threshold+ 0.998254657f0
  "The dot product past which a constrained billboard's axis counts as parallel
to the view direction. XNA's literal, not a rounded cosine.")

(defun matrix-create-constrained-billboard (object-position camera-position rotate-axis
                                            &optional camera-forward-vector
                                                      object-forward-vector)
  "Matrix.CreateConstrainedBillboard.

Like MATRIX-CREATE-BILLBOARD, except the billboard may only turn about
ROTATE-AXIS. When the view direction is within 0.998254657 of parallel to that
axis the rotation is unconstrained by the view, and the framework then picks a
substitute forward direction through three nested tests -- which is the whole
difficulty of this member and the reason it is transcribed rather than derived:

  * OBJECT-FORWARD-VECTOR if it was given and is itself not parallel to the axis;
  * otherwise `Vector3.Forward', unless the axis is parallel to *that* too;
  * and in that last case `Vector3.Right'.

Both optional arguments are XNA's `Vector3?': NIL is the absent value.
CAMERA-FORWARD-VECTOR is consulted only when the object and the camera are
closer together than 0.0001f squared."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((delta (vector3-subtract object-position camera-position))
           (squared (vector3-length-squared delta))
           (view (if (< squared 0.0001f0)
                     (if camera-forward-vector
                         (vector3-negate camera-forward-vector)
                         (vector3-forward))
                     (vector3-multiply delta (/ 1.0f0 (%sqrt-as-xna squared)))))
           (up (copy-vector3 rotate-axis))
           right backward)
      (flet ((parallel-p (vector)
               (> (abs (vector3-dot rotate-axis vector))
                  +billboard-degenerate-axis-threshold+)))
        (if (parallel-p view)
            (let ((substitute
                    (cond ((and object-forward-vector
                                (not (parallel-p object-forward-vector)))
                           object-forward-vector)
                          ((parallel-p (vector3-forward)) (vector3-right))
                          (t (vector3-forward)))))
              (setf right (vector3-normalize (vector3-cross rotate-axis substitute))
                    backward (vector3-normalize (vector3-cross right rotate-axis))))
            (setf right (vector3-normalize (vector3-cross rotate-axis view))
                  backward (vector3-normalize (vector3-cross right up)))))
      (%make-matrix (vector3-x right) (vector3-y right) (vector3-z right) 0.0f0
                    (vector3-x up) (vector3-y up) (vector3-z up) 0.0f0
                    (vector3-x backward) (vector3-y backward) (vector3-z backward) 0.0f0
                    (vector3-x object-position) (vector3-y object-position)
                    (vector3-z object-position) 1.0f0))))

;;; --- arithmetic -------------------------------------------------------------

(defun matrix-transpose (matrix)
  "Matrix.Transpose."
  (%with-m matrix
    (%make-matrix m11 m21 m31 m41
                  m12 m22 m32 m42
                  m13 m23 m33 m43
                  m14 m24 m34 m44)))

(defun matrix-determinant (matrix)
  "Matrix.Determinant, by the framework's own cofactor expansion."
  (cna-lisp.internal:with-binary32-semantics
    (%with-m matrix
      (let ((a (- (* m33 m44) (* m34 m43)))
            (b (- (* m32 m44) (* m34 m42)))
            (c (- (* m32 m43) (* m33 m42)))
            (d (- (* m31 m44) (* m34 m41)))
            (e (- (* m31 m43) (* m33 m41)))
            (g (- (* m31 m42) (* m32 m41))))
        (- (+ (- (* m11 (+ (- (* m22 a) (* m23 b)) (* m24 c)))
                 (* m12 (+ (- (* m21 a) (* m23 d)) (* m24 e))))
              (* m13 (+ (- (* m21 b) (* m22 d)) (* m24 g))))
           (* m14 (+ (- (* m21 c) (* m22 e)) (* m23 g))))))))

(defun matrix-invert (matrix)
  "Matrix.Invert, by the framework's own cofactor expansion.

A singular matrix answers a matrix of infinities and NaNs rather than signalling,
because the framework divides by the determinant without checking it and IEEE 754
default handling is what the CLR uses."
  (cna-lisp.internal:with-binary32-semantics
    (%with-m matrix
      (let* ((a (- (* m33 m44) (* m34 m43)))
             (b (- (* m32 m44) (* m34 m42)))
             (c (- (* m32 m43) (* m33 m42)))
             (d (- (* m31 m44) (* m34 m41)))
             (e (- (* m31 m43) (* m33 m41)))
             (g (- (* m31 m42) (* m32 m41)))
             (c11 (+ (- (* m22 a) (* m23 b)) (* m24 c)))
             (c21 (- (+ (- (* m21 a) (* m23 d)) (* m24 e))))
             (c31 (+ (- (* m21 b) (* m22 d)) (* m24 g)))
             (c41 (- (+ (- (* m21 c) (* m22 e)) (* m23 g))))
             (scale (/ 1.0f0 (+ (+ (+ (* m11 c11) (* m12 c21)) (* m13 c31)) (* m14 c41))))
             (h (- (* m23 m44) (* m24 m43)))
             (i (- (* m22 m44) (* m24 m42)))
             (j (- (* m22 m43) (* m23 m42)))
             (k (- (* m21 m44) (* m24 m41)))
             (l (- (* m21 m43) (* m23 m41)))
             (n (- (* m21 m42) (* m22 m41)))
             (o (- (* m23 m34) (* m24 m33)))
             (p (- (* m22 m34) (* m24 m32)))
             (q (- (* m22 m33) (* m23 m32)))
             (r (- (* m21 m34) (* m24 m31)))
             (s (- (* m21 m33) (* m23 m31)))
             (u (- (* m21 m32) (* m22 m31))))
        (%make-matrix
         (* c11 scale)
         (* (- (+ (- (* m12 a) (* m13 b)) (* m14 c))) scale)
         (* (+ (- (* m12 h) (* m13 i)) (* m14 j)) scale)
         (* (- (+ (- (* m12 o) (* m13 p)) (* m14 q))) scale)
         (* c21 scale)
         (* (+ (- (* m11 a) (* m13 d)) (* m14 e)) scale)
         (* (- (+ (- (* m11 h) (* m13 k)) (* m14 l))) scale)
         (* (+ (- (* m11 o) (* m13 r)) (* m14 s)) scale)
         (* c31 scale)
         (* (- (+ (- (* m11 b) (* m12 d)) (* m14 g))) scale)
         (* (+ (- (* m11 i) (* m12 k)) (* m14 n)) scale)
         (* (- (+ (- (* m11 p) (* m12 r)) (* m14 u))) scale)
         (* c41 scale)
         (* (+ (- (* m11 c) (* m12 e)) (* m13 g)) scale)
         (* (- (+ (- (* m11 j) (* m12 l)) (* m13 n))) scale)
         (* (+ (- (* m11 q) (* m12 s)) (* m13 u)) scale))))))

(defmacro %matrix-component-wise (name documentation operation)
  `(defun ,name (left right)
     ,documentation
     (cna-lisp.internal:with-binary32-semantics
       (%make-matrix
        ,@(loop for row from 1 to 4
                append (loop for column from 1 to 4
                             for reader = (intern (format nil "MATRIX-M~d~d" row column))
                             collect `(,operation (,reader left) (,reader right))))))))

(%matrix-component-wise matrix-add "Matrix.Add." +)
(%matrix-component-wise matrix-subtract "Matrix.Subtract." -)

(defun matrix-negate (matrix)
  "Matrix.Negate."
  (cna-lisp.internal:with-binary32-semantics
    (%with-m matrix
      (%make-matrix (- m11) (- m12) (- m13) (- m14)
                    (- m21) (- m22) (- m23) (- m24)
                    (- m31) (- m32) (- m33) (- m34)
                    (- m41) (- m42) (- m43) (- m44)))))

(defun %matrix-product (a b)
  (cna-lisp.internal:with-binary32-semantics
    (macrolet ((entry (row column)
                 `(+ (+ (+ (* (,(intern (format nil "MATRIX-M~d1" row)) a)
                              (,(intern (format nil "MATRIX-M1~d" column)) b))
                           (* (,(intern (format nil "MATRIX-M~d2" row)) a)
                              (,(intern (format nil "MATRIX-M2~d" column)) b)))
                        (* (,(intern (format nil "MATRIX-M~d3" row)) a)
                           (,(intern (format nil "MATRIX-M3~d" column)) b)))
                     (* (,(intern (format nil "MATRIX-M~d4" row)) a)
                        (,(intern (format nil "MATRIX-M4~d" column)) b)))))
      (%make-matrix (entry 1 1) (entry 1 2) (entry 1 3) (entry 1 4)
                    (entry 2 1) (entry 2 2) (entry 2 3) (entry 2 4)
                    (entry 3 1) (entry 3 2) (entry 3 3) (entry 3 4)
                    (entry 4 1) (entry 4 2) (entry 4 3) (entry 4 4)))))

(defgeneric matrix-multiply (matrix factor)
  (:documentation
   "Matrix.Multiply, by another matrix or by a scalar.

`(matrix-multiply a b)' applies A first and then B, because these are row-major
matrices multiplied on the left by a row vector."))

(defmethod matrix-multiply ((matrix matrix) (factor matrix))
  (%matrix-product matrix factor))

(defmethod matrix-multiply ((matrix matrix) (factor real))
  (cna-lisp.internal:with-binary32-semantics
    (let ((s (f factor)))
      (%with-m matrix
        (%make-matrix (* m11 s) (* m12 s) (* m13 s) (* m14 s)
                      (* m21 s) (* m22 s) (* m23 s) (* m24 s)
                      (* m31 s) (* m32 s) (* m33 s) (* m34 s)
                      (* m41 s) (* m42 s) (* m43 s) (* m44 s))))))

(defgeneric matrix-divide (matrix divisor)
  (:documentation "Matrix.Divide, component-wise or by a scalar."))

(defmethod matrix-divide ((matrix matrix) (divisor matrix))
  (cna-lisp.internal:with-binary32-semantics
    (%make-matrix
     (/ (matrix-m11 matrix) (matrix-m11 divisor)) (/ (matrix-m12 matrix) (matrix-m12 divisor))
     (/ (matrix-m13 matrix) (matrix-m13 divisor)) (/ (matrix-m14 matrix) (matrix-m14 divisor))
     (/ (matrix-m21 matrix) (matrix-m21 divisor)) (/ (matrix-m22 matrix) (matrix-m22 divisor))
     (/ (matrix-m23 matrix) (matrix-m23 divisor)) (/ (matrix-m24 matrix) (matrix-m24 divisor))
     (/ (matrix-m31 matrix) (matrix-m31 divisor)) (/ (matrix-m32 matrix) (matrix-m32 divisor))
     (/ (matrix-m33 matrix) (matrix-m33 divisor)) (/ (matrix-m34 matrix) (matrix-m34 divisor))
     (/ (matrix-m41 matrix) (matrix-m41 divisor)) (/ (matrix-m42 matrix) (matrix-m42 divisor))
     (/ (matrix-m43 matrix) (matrix-m43 divisor)) (/ (matrix-m44 matrix) (matrix-m44 divisor)))))

(defmethod matrix-divide ((matrix matrix) (divisor real))
  ;; One reciprocal, sixteen multiplications: the framework's own shape.
  (cna-lisp.internal:with-binary32-semantics
    (matrix-multiply matrix (/ 1.0f0 (f divisor)))))

(defun matrix-lerp (matrix1 matrix2 amount)
  "Matrix.Lerp, component by component."
  (cna-lisp.internal:with-binary32-semantics
    (let ((m (f amount)))
      (macrolet ((entry (name)
                   `(+ (,name matrix1) (* (- (,name matrix2) (,name matrix1)) m))))
        (%make-matrix (entry matrix-m11) (entry matrix-m12)
                      (entry matrix-m13) (entry matrix-m14)
                      (entry matrix-m21) (entry matrix-m22)
                      (entry matrix-m23) (entry matrix-m24)
                      (entry matrix-m31) (entry matrix-m32)
                      (entry matrix-m33) (entry matrix-m34)
                      (entry matrix-m41) (entry matrix-m42)
                      (entry matrix-m43) (entry matrix-m44))))))

(defun matrix-transform (matrix rotation)
  "Matrix.Transform: MATRIX rotated by a quaternion."
  (%matrix-product matrix (matrix-create-from-quaternion rotation)))

(defun matrix-equal (left right)
  "Matrix.Equals."
  (cna-lisp.internal:with-binary32-semantics
    (macrolet ((same (name) `(= (,name left) (,name right))))
      (and (same matrix-m11) (same matrix-m12) (same matrix-m13) (same matrix-m14)
           (same matrix-m21) (same matrix-m22) (same matrix-m23) (same matrix-m24)
           (same matrix-m31) (same matrix-m32) (same matrix-m33) (same matrix-m34)
           (same matrix-m41) (same matrix-m42) (same matrix-m43) (same matrix-m44)))))
