;;;; gjk.lisp --- the private distance solver BoundingFrustum tests with.
;;;;
;;;; `BoundingFrustum.Intersects' does not test planes against planes. It runs a
;;;; Gilbert-Johnson-Keerthi iteration on the Minkowski difference of the two
;;;; bodies, and asks whether the closest point of that difference has reached
;;;; the origin. XNA ships a private `Gjk' class to do it, with Johnson's
;;;; sub-distance algorithm over a bitset simplex, and the frustum's answers are
;;;; that class's answers -- including where it stops iterating.
;;;;
;;;; So this is a transcription, not an implementation of the published
;;;; algorithm. It is private: nothing here is exported, and the only caller is
;;;; bounding-frustum.lisp.
;;;;
;;;; Three details are load-bearing and are easy to lose:
;;;;
;;;;   * the simplex is a four-bit set, and `*gjk-bits-to-indices*' unpacks it
;;;;     into octal digits holding index+1, low digit first. It is a table in
;;;;     the assembly's metadata, reproduced here with the check that generates
;;;;     it, so a typo cannot survive;
;;;;   * `%gjk-satisfies-rule-p' uses unordered comparisons, so a NaN determinant
;;;;     *accepts* the subset rather than rejecting it;
;;;;   * the determinant recurrence divides by an edge chosen as the shortest of
;;;;     the candidates, and the comparison order decides which of two equal-
;;;;     length edges wins.

(in-package #:microsoft.xna.framework)

(defconstant +gjk-max-points+ 4)

(defparameter *gjk-bits-to-indices*
  (make-array 16 :element-type 'fixnum
                 :initial-contents '(#o0 #o1 #o2 #o21 #o3 #o31 #o32 #o321
                                     #o4 #o41 #o42 #o421 #o43 #o431 #o432 #o4321))
  "Gjk.BitsToIndices, read from the assembly's static array data.

Entry N lists the members of the four-bit set N as octal digits holding
index+1, least significant digit first, so 0 terminates the list. The
initialiser above is the shape the table has; the unit test regenerates it from
that rule and refuses any entry that disagrees.")

(defstruct (gjk (:constructor %make-gjk ()) (:copier nil))
  "Microsoft.Xna.Framework.Gjk: private, and reused across calls on one frustum."
  (closest-point (%make-vector3 0.0f0 0.0f0 0.0f0) :type vector3)
  (y (let ((a (make-array +gjk-max-points+)))
       (dotimes (i +gjk-max-points+ a) (setf (aref a i) (%make-vector3 0.0f0 0.0f0 0.0f0))))
     :type simple-vector)
  (y-length-sq (make-array +gjk-max-points+ :element-type 'single-float
                                            :initial-element 0.0f0)
   :type (simple-array single-float (*)))
  (edges (let ((a (make-array +gjk-max-points+)))
           (dotimes (i +gjk-max-points+ a)
             (setf (aref a i)
                   (let ((row (make-array +gjk-max-points+)))
                     (dotimes (j +gjk-max-points+ row)
                       (setf (aref row j) (%make-vector3 0.0f0 0.0f0 0.0f0)))))))
   :type simple-vector)
  (edge-length-sq (let ((a (make-array +gjk-max-points+)))
                    (dotimes (i +gjk-max-points+ a)
                      (setf (aref a i)
                            (make-array +gjk-max-points+ :element-type 'single-float
                                                         :initial-element 0.0f0))))
   :type simple-vector)
  (det (let ((a (make-array 16)))
         (dotimes (i 16 a)
           (setf (aref a i) (make-array +gjk-max-points+ :element-type 'single-float
                                                         :initial-element 0.0f0))))
   :type simple-vector)
  (simplex-bits 0 :type (unsigned-byte 4))
  (max-length-sq 0.0f0 :type single-float))

(declaim (inline %gjk-det %gjk-set-det %gjk-elsq %gjk-full-simplex-p))

(defun %gjk-det (gjk bits index)
  (aref (the (simple-array single-float (*)) (svref (gjk-det gjk) bits)) index))

(defun %gjk-set-det (gjk bits index value)
  (setf (aref (the (simple-array single-float (*)) (svref (gjk-det gjk) bits)) index)
        value))

(defun %gjk-elsq (gjk i j)
  (aref (the (simple-array single-float (*)) (svref (gjk-edge-length-sq gjk) i)) j))

(defun %gjk-full-simplex-p (gjk)
  "Gjk.FullSimplex: the simplex holds all four points."
  (= 15 (gjk-simplex-bits gjk)))

(defun %gjk-reset (gjk)
  "Gjk.Reset."
  (setf (gjk-simplex-bits gjk) 0
        (gjk-max-length-sq gjk) 0.0f0)
  gjk)

(defmacro %do-gjk-indices ((index bits) &body body)
  "Walk the members of the four-bit set BITS, low index first."
  (let ((packed (gensym "PACKED")))
    `(let ((,packed (aref *gjk-bits-to-indices* ,bits)))
       (loop until (zerop ,packed)
             do (let ((,index (- (logand ,packed 7) 1)))
                  ,@body)
                (setf ,packed (ash ,packed -3))))))

(defun %gjk-nearest-edge-index (gjk candidates target)
  "The candidate whose edge to TARGET is shortest.

The assembly spells the choice out as a comparison chain rather than a loop, and
the chain's order decides the tie: with two equal-length edges the *later*
candidate wins. CANDIDATES is in the assembly's order, which is not always
ascending, so it is passed in rather than derived."
  (let ((a (first candidates))
        (b (second candidates))
        (c (third candidates)))
    (if (null c)
        (if (< (%gjk-elsq gjk a target) (%gjk-elsq gjk b target)) a b)
        (if (< (%gjk-elsq gjk a target) (%gjk-elsq gjk b target))
            (if (< (%gjk-elsq gjk a target) (%gjk-elsq gjk c target)) a c)
            (if (< (%gjk-elsq gjk b target) (%gjk-elsq gjk c target)) b c)))))

(defun %gjk-edge-dot (gjk edge-from edge-to point)
  "Dot(edges[EDGE-FROM][EDGE-TO], y[POINT])."
  (vector3-dot (svref (svref (gjk-edges gjk) edge-from) edge-to)
               (svref (gjk-y gjk) point)))

(defun %gjk-update-determinant (gjk new-index)
  "Gjk.UpdateDeterminant: extend the determinant table with the new point.

Johnson's recurrence, with det[{t}][t] = 1 and

    det[X + {t}][t] = sum over o in X of det[X][o] * Dot(edges[k][t], y[o])

where k is the candidate in X whose edge to t is shortest. Only the subsets that
contain the new point are recomputed; the others were computed by earlier calls
and the points they name have not moved."
  (let ((new-bit (ash 1 new-index))
        (simplex (gjk-simplex-bits gjk)))
    (%gjk-set-det gjk new-bit new-index 1.0f0)
    (let ((position 0))
      (%do-gjk-indices (i simplex)
        (let* ((i-bit (ash 1 i))
               (pair (logior i-bit new-bit)))
          (%gjk-set-det gjk pair i (%gjk-edge-dot gjk new-index i new-index))
          (%gjk-set-det gjk pair new-index (%gjk-edge-dot gjk i new-index i))
          ;; The inner walk stops at the outer walk's position, so each unordered
          ;; pair of old points is handled exactly once.
          (let ((seen 0))
            (%do-gjk-indices (j simplex)
              (when (>= seen position) (return))
              (let* ((j-bit (ash 1 j))
                     (triple (logior pair j-bit)))
                (let ((k (%gjk-nearest-edge-index gjk (list i new-index) j)))
                  (%gjk-set-det gjk triple j
                                (+ (* (%gjk-det gjk pair i) (%gjk-edge-dot gjk k j i))
                                   (* (%gjk-det gjk pair new-index)
                                      (%gjk-edge-dot gjk k j new-index)))))
                (let ((k (%gjk-nearest-edge-index gjk (list j new-index) i))
                      (other (logior j-bit new-bit)))
                  (%gjk-set-det gjk triple i
                                (+ (* (%gjk-det gjk other j) (%gjk-edge-dot gjk k i j))
                                   (* (%gjk-det gjk other new-index)
                                      (%gjk-edge-dot gjk k i new-index)))))
                (let ((k (%gjk-nearest-edge-index gjk (list i j) new-index))
                      (other (logior i-bit j-bit)))
                  (%gjk-set-det gjk triple new-index
                                (+ (* (%gjk-det gjk other j) (%gjk-edge-dot gjk k new-index j))
                                   (* (%gjk-det gjk other i)
                                      (%gjk-edge-dot gjk k new-index i))))))
              (incf seen)))
          (incf position))))
    (when (= 15 (logior simplex new-bit))
      ;; The four-point case is written out in the assembly rather than folded
      ;; into the loop, and the candidate order is ascending here.
      (dotimes (target 4)
        (let* ((others (remove target '(0 1 2 3)))
               (without (logxor 15 (ash 1 target)))
               (k (%gjk-nearest-edge-index gjk others target))
               (sum 0.0f0))
          (dolist (o others)
            (setf sum (+ sum (* (%gjk-det gjk without o) (%gjk-edge-dot gjk k target o)))))
          (%gjk-set-det gjk 15 target sum))))
    gjk))

(defun %gjk-satisfies-rule-p (gjk x-bits y-bits)
  "Gjk.IsSatisfiesRule: is X-BITS the subset whose barycentric region holds the
origin?

Every member of X-BITS must have a strictly positive determinant, and every
member of Y-BITS outside it a non-positive one. Both tests are written with
unordered branches in the assembly, so a NaN determinant satisfies the rule
rather than breaking it -- which is why the comparisons below are negated
instead of being written the obvious way round."
  (let ((satisfied t))
    (%do-gjk-indices (i y-bits)
      (let ((bit (ash 1 i)))
        (if (logtest bit x-bits)
            (when (<= (%gjk-det gjk x-bits i) 0.0f0)
              (setf satisfied nil)
              (return))
            (when (> (%gjk-det gjk (logior x-bits bit) i) 0.0f0)
              (setf satisfied nil)
              (return)))))
    satisfied))

(defun %gjk-compute-closest-point (gjk)
  "Gjk.ComputeClosestPoint: the barycentric combination the determinants name."
  (let ((sum 0.0f0)
        (point (vector3-zero)))
    (setf (gjk-max-length-sq gjk) 0.0f0)
    (%do-gjk-indices (i (gjk-simplex-bits gjk))
      (let ((weight (%gjk-det gjk (gjk-simplex-bits gjk) i)))
        (setf sum (+ sum weight))
        (setf point (vector3-add point (vector3-multiply (svref (gjk-y gjk) i) weight)))
        (setf (gjk-max-length-sq gjk)
              (math-helper-max (gjk-max-length-sq gjk)
                               (aref (gjk-y-length-sq gjk) i)))))
    (vector3-divide point sum)))

(defun %gjk-update-simplex (gjk new-index)
  "Gjk.UpdateSimplex: keep the smallest subset that still holds the origin.

The search counts *down* from the current simplex, so the largest admissible
subset wins; the single new point is tried last."
  (let ((y-bits (logior (gjk-simplex-bits gjk) (ash 1 new-index)))
        (new-bit (ash 1 new-index)))
    (loop for candidate downfrom (gjk-simplex-bits gjk) above 0
          do (when (and (= (logand candidate y-bits) candidate)
                        (%gjk-satisfies-rule-p gjk (logior candidate new-bit) y-bits))
               (setf (gjk-simplex-bits gjk) (logior candidate new-bit)
                     (gjk-closest-point gjk) (%gjk-compute-closest-point gjk))
               (return-from %gjk-update-simplex t)))
    (when (%gjk-satisfies-rule-p gjk new-bit y-bits)
      (setf (gjk-simplex-bits gjk) new-bit
            (gjk-closest-point gjk) (copy-vector3 (svref (gjk-y gjk) new-index))
            (gjk-max-length-sq gjk) (aref (gjk-y-length-sq gjk) new-index))
      t)))

(defun %gjk-add-support-point (gjk new-point)
  "Gjk.AddSupportPoint: put NEW-POINT in the free slot and re-solve."
  (let ((index (- (logand (aref *gjk-bits-to-indices*
                                (logxor (gjk-simplex-bits gjk) 15))
                          7)
                  1)))
    (setf (svref (gjk-y gjk) index) (copy-vector3 new-point)
          (aref (gjk-y-length-sq gjk) index) (vector3-length-squared new-point))
    (%do-gjk-indices (j (gjk-simplex-bits gjk))
      (let ((edge (vector3-subtract (svref (gjk-y gjk) j) new-point)))
        (setf (svref (svref (gjk-edges gjk) j) index) edge
              (svref (svref (gjk-edges gjk) index) j) (vector3-negate edge))
        (let ((length-squared (vector3-length-squared edge)))
          (setf (aref (the (simple-array single-float (*))
                           (svref (gjk-edge-length-sq gjk) index))
                      j)
                length-squared
                (aref (the (simple-array single-float (*))
                           (svref (gjk-edge-length-sq gjk) j))
                      index)
                length-squared))))
    (%gjk-update-determinant gjk index)
    (%gjk-update-simplex gjk index)))
