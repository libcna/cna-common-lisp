;;;; curve.lisp --- Curve, CurveKey, CurveKeyCollection and the three enums.
;;;;
;;;; A Curve is a sorted set of keys with a tangent on either side of each, read
;;;; by cubic Hermite interpolation, plus a rule for what happens outside the
;;;; first and last key. Read from the pinned XNA 4.0 Windows IL, because almost
;;;; every part of it has an answer a textbook version would get differently:
;;;;
;;;;   * `CurveContinuity.Step' is not a tangent setting -- it makes the segment
;;;;     answer one endpoint or the other, and the threshold is `t < 1', so the
;;;;     step happens at the *end* of the segment, not in the middle;
;;;;   * the loop types are applied by folding the position back into the key
;;;;     range and evaluating there, and `CycleOffset' additionally adds a whole
;;;;     multiple of the total value change, so a looping curve drifts;
;;;;   * `Linear' extrapolation outside the range uses the *first* key's
;;;;     `TangentIn' before the curve and the last key's `TangentOut' after it,
;;;;     both with the same sign convention, which reads as a sign error and is
;;;;     not one;
;;;;   * a key collection sorts by position and allows duplicate positions, and a
;;;;     new key with an existing position goes *after* the ones already there.

(in-package #:microsoft.xna.framework)

(define-xna-enum curve-continuity
  '((:smooth . 0) (:step . 1))
  :documentation "Microsoft.Xna.Framework.CurveContinuity.")

(define-xna-enum curve-loop-type
  '((:constant . 0) (:cycle . 1) (:cycle-offset . 2) (:oscillate . 3) (:linear . 4))
  :documentation "Microsoft.Xna.Framework.CurveLoopType.")

(define-xna-enum curve-tangent
  '((:flat . 0) (:linear . 1) (:smooth . 2))
  :documentation "Microsoft.Xna.Framework.CurveTangent.")

;;; --- CurveKey ---------------------------------------------------------------

(defclass curve-key ()
  ((position :initarg :position :reader curve-key-position :initform 0.0f0)
   (value :initarg :value :accessor curve-key-value :initform 0.0f0)
   (tangent-in :initarg :tangent-in :accessor curve-key-tangent-in :initform 0.0f0)
   (tangent-out :initarg :tangent-out :accessor curve-key-tangent-out :initform 0.0f0)
   (continuity :initarg :continuity :accessor curve-key-continuity :initform :smooth))
  (:documentation
   "Microsoft.Xna.Framework.CurveKey: one control point of a Curve.

    (make-instance 'curve-key :position 0.0 :value 1.0)

POSITION is read-only, as it is in XNA: a key's place in its collection depends
on it, so it cannot change under the collection. The other four are settable."))

(defmethod initialize-instance :after ((key curve-key) &key)
  (with-slots (position value tangent-in tangent-out continuity) key
    (setf position (f position) value (f value)
          tangent-in (f tangent-in) tangent-out (f tangent-out))
    (check-type continuity curve-continuity)))

(defmethod (setf curve-key-value) :around (new (key curve-key))
  (call-next-method (f new) key))
(defmethod (setf curve-key-tangent-in) :around (new (key curve-key))
  (call-next-method (f new) key))
(defmethod (setf curve-key-tangent-out) :around (new (key curve-key))
  (call-next-method (f new) key))

(defun curve-key-clone (key)
  "CurveKey.Clone."
  (make-instance 'curve-key :position (curve-key-position key)
                            :value (curve-key-value key)
                            :tangent-in (curve-key-tangent-in key)
                            :tangent-out (curve-key-tangent-out key)
                            :continuity (curve-key-continuity key)))

(defun curve-key-equal (left right)
  "CurveKey.Equals and op_Equality: every field, not identity."
  (and (typep left 'curve-key) (typep right 'curve-key)
       (= (curve-key-position left) (curve-key-position right))
       (= (curve-key-value left) (curve-key-value right))
       (= (curve-key-tangent-in left) (curve-key-tangent-in right))
       (= (curve-key-tangent-out left) (curve-key-tangent-out right))
       (eq (curve-key-continuity left) (curve-key-continuity right))))

(defun curve-key-compare-to (key other)
  "CurveKey.CompareTo: -1, 0 or 1 by POSITION alone.

Ordering ignores every other field, which is why a collection can hold two keys
at the same position and why equality and ordering disagree."
  (let ((a (curve-key-position key)) (b (curve-key-position other)))
    (cond ((< a b) -1) ((> a b) 1) (t 0))))

;;; --- CurveKeyCollection -----------------------------------------------------

(defclass curve-key-collection ()
  ((keys :initform (make-array 0 :adjustable t :fill-pointer 0) :reader %collection-keys)
   (time-range :initform 0.0f0 :accessor %collection-time-range)
   (inverse-time-range :initform 0.0f0 :accessor %collection-inverse-time-range)
   (cache-valid :initform nil :accessor %collection-cache-valid))
  (:documentation
   "Microsoft.Xna.Framework.CurveKeyCollection: a Curve's keys, sorted by
position.

Duplicate positions are allowed, and a key added at a position that is already
present goes after the ones already there. The collection is not a set: adding
the same key object twice adds it twice."))

(defun curve-key-collection-count (collection)
  "CurveKeyCollection.Count."
  (length (%collection-keys collection)))

(defun curve-key-collection-is-read-only (collection)
  "CurveKeyCollection.IsReadOnly, which is always false."
  (declare (ignore collection))
  nil)

(defun %check-key-index (collection index operation)
  (unless (and (integerp index) (< -1 index (curve-key-collection-count collection)))
    (error 'cna-argument-out-of-range-error
           :operation operation
           :parameter-name "index"
           :format-control "the collection holds ~d key~:p and the index is ~s."
           :format-arguments (list (curve-key-collection-count collection) index))))

(defun curve-key-collection-item (collection index)
  "CurveKeyCollection.Item."
  (%check-key-index collection index "curve-key-collection-item")
  (aref (%collection-keys collection) index))

(defun (setf curve-key-collection-item) (key collection index)
  "CurveKeyCollection.Item setter.

Replacing a key with one at a different position does not leave it where it was:
the original removes the old key and *adds* the new one, so it lands in sorted
order and the index the caller used no longer names it."
  (check-type key curve-key)
  (%check-key-index collection index "curve-key-collection-item")
  (if (= (curve-key-position (aref (%collection-keys collection) index))
         (curve-key-position key))
      (setf (aref (%collection-keys collection) index) key)
      (progn (curve-key-collection-remove-at collection index)
             (curve-key-collection-add collection key)))
  key)

(defun curve-key-collection-add (collection key)
  "CurveKeyCollection.Add: insert in position order, after any equal positions."
  (check-type key curve-key)
  (let* ((keys (%collection-keys collection))
         (count (length keys))
         (index (or (position-if (lambda (existing)
                                   (> (curve-key-position existing)
                                      (curve-key-position key)))
                                 keys)
                    count)))
    (vector-push-extend key keys)
    (replace keys keys :start1 (1+ index) :start2 index :end2 count)
    (setf (aref keys index) key
          (%collection-cache-valid collection) nil))
  (values))

(defun curve-key-collection-remove-at (collection index)
  "CurveKeyCollection.RemoveAt."
  (%check-key-index collection index "curve-key-collection-remove-at")
  (let ((keys (%collection-keys collection)))
    (replace keys keys :start1 index :start2 (1+ index))
    (decf (fill-pointer keys))
    (setf (%collection-cache-valid collection) nil))
  (values))

(defun curve-key-collection-index-of (collection key)
  "CurveKeyCollection.IndexOf, or NIL when the key is not in the collection.

Not identity: List<T>.IndexOf uses the element type's own equality, and
CurveKey's compares fields, so this finds the first key that *equals* the one
given rather than the one that is it. NIL rather than -1, because NIL is what a
Lisp caller tests and -1 is a valid-looking index."
  (position key (%collection-keys collection) :test #'curve-key-equal))

(defun curve-key-collection-contains (collection key)
  "CurveKeyCollection.Contains."
  (and (curve-key-collection-index-of collection key) t))

(defun curve-key-collection-remove (collection key)
  "CurveKeyCollection.Remove: removes the first equal key and answers whether it
found one."
  (let ((index (curve-key-collection-index-of collection key)))
    (when index
      (curve-key-collection-remove-at collection index)
      t)))

(defun curve-key-collection-clear (collection)
  "CurveKeyCollection.Clear."
  (setf (fill-pointer (%collection-keys collection)) 0
        (%collection-cache-valid collection) nil)
  (values))

(defun curve-key-collection-keys (collection)
  "CurveKeyCollection.GetEnumerator, as a fresh vector of the keys.

Common Lisp has no enumerator object, and a Lisp caller iterates a sequence. The
sequence is a copy: the keys in it are the collection's own key objects, but
adding to or removing from the collection afterwards does not change it."
  (copy-seq (coerce (%collection-keys collection) 'simple-vector)))

(defun curve-key-collection-copy-to (collection array index)
  "CurveKeyCollection.CopyTo."
  (let ((keys (%collection-keys collection)))
    (unless (and (integerp index) (>= index 0)
                 (>= (- (length array) index) (length keys)))
      (error 'cna-argument-out-of-range-error
             :operation "curve-key-collection-copy-to"
             :parameter-name "index"
             :format-control "~d key~:p do not fit in an array of ~d from index ~s."
             :format-arguments (list (length keys) (length array) index)))
    (replace array keys :start1 index))
  (values))

(defun curve-key-collection-clone (collection)
  "CurveKeyCollection.Clone.

A shallow copy: the new collection holds the *same* key objects, so mutating a
key through one collection is visible through the other. That is what the
original does, and it is what makes CURVE-CLONE shallow too."
  (let ((copy (make-instance 'curve-key-collection)))
    (loop for key across (%collection-keys collection)
          do (vector-push-extend key (%collection-keys copy)))
    (setf (%collection-time-range copy) (%collection-time-range collection)
          (%collection-inverse-time-range copy) (%collection-inverse-time-range collection)
          ;; The original marks the clone's cache valid whether or not the
          ;; source's was, so a clone of a collection with a stale cache carries
          ;; the stale numbers.
          (%collection-cache-valid copy) t)
    copy))

(defun %compute-cache-values (collection)
  "CurveKeyCollection.ComputeCacheValues."
  (cna-lisp.internal:with-binary32-semantics
    (let ((keys (%collection-keys collection)))
      (setf (%collection-time-range collection) 0.0f0
            (%collection-inverse-time-range collection) 0.0f0)
      (when (> (length keys) 1)
        (let ((range (- (curve-key-position (aref keys (1- (length keys))))
                        (curve-key-position (aref keys 0)))))
          (setf (%collection-time-range collection) range)
          ;; The guard is against the smallest positive subnormal, not against
          ;; zero: a range below it leaves the reciprocal at zero.
          (when (> range 1.401298f-45)
            (setf (%collection-inverse-time-range collection) (/ 1.0f0 range)))))
      (setf (%collection-cache-valid collection) t))))

;;; --- Curve ------------------------------------------------------------------

(defclass curve ()
  ((pre-loop :initarg :pre-loop :accessor curve-pre-loop :initform :constant)
   (post-loop :initarg :post-loop :accessor curve-post-loop :initform :constant)
   (keys :reader curve-keys :initform (make-instance 'curve-key-collection)))
  (:documentation
   "Microsoft.Xna.Framework.Curve: a Hermite spline over a sorted key collection.

    (let ((c (make-instance 'curve)))
      (curve-key-collection-add (curve-keys c)
                                (make-instance 'curve-key :position 0.0 :value 0.0))
      (curve-key-collection-add (curve-keys c)
                                (make-instance 'curve-key :position 1.0 :value 1.0))
      (curve-compute-tangents c :smooth)
      (curve-evaluate c 0.5))"))

(defmethod initialize-instance :after ((curve curve) &key)
  (check-type (curve-pre-loop curve) curve-loop-type)
  (check-type (curve-post-loop curve) curve-loop-type))

(defun curve-is-constant (curve)
  "Curve.IsConstant: true for a curve with fewer than two keys."
  (<= (curve-key-collection-count (curve-keys curve)) 1))

(defun curve-clone (curve)
  "Curve.Clone: the loop settings, and a shallow copy of the key collection."
  (let ((copy (make-instance 'curve :pre-loop (curve-pre-loop curve)
                                    :post-loop (curve-post-loop curve))))
    (setf (slot-value copy 'keys) (curve-key-collection-clone (curve-keys curve)))
    copy))

(defun curve-compute-tangent (curve key-index tangent-in-type
                              &optional (tangent-out-type tangent-in-type))
  "Curve.ComputeTangent, in both its two- and three-type forms.

The one-type overload is the same call with the two types equal, so it is a
trailing optional argument here rather than a second function."
  (check-type tangent-in-type curve-tangent)
  (check-type tangent-out-type curve-tangent)
  (let ((keys (curve-keys curve)))
    (unless (and (integerp key-index) (< -1 key-index (curve-key-collection-count keys)))
      (error 'cna-argument-out-of-range-error
             :operation "curve-compute-tangent"
             :parameter-name "key-index"
             :format-control "the curve has ~d key~:p and the index is ~s."
             :format-arguments (list (curve-key-collection-count keys) key-index)))
    (cna-lisp.internal:with-binary32-semantics
      (let* ((key (curve-key-collection-item keys key-index))
             (self-position (curve-key-position key))
             (self-value (curve-key-value key))
             (previous-position self-position) (previous-value self-value)
             (next-position self-position) (next-value self-value))
        (when (> key-index 0)
          (let ((previous (curve-key-collection-item keys (1- key-index))))
            (setf previous-position (curve-key-position previous)
                  previous-value (curve-key-value previous))))
        (when (< (1+ key-index) (curve-key-collection-count keys))
          (let ((next (curve-key-collection-item keys (1+ key-index))))
            (setf next-position (curve-key-position next)
                  next-value (curve-key-value next))))
        ;; A smooth tangent is the whole neighbouring value change scaled by this
        ;; side's share of the neighbouring position span -- so an end key, whose
        ;; neighbour on one side is itself, gets a *smaller* tangent on that side
        ;; rather than a mirrored one. The epsilon is binary32's, and it guards
        ;; the value change, not the span.
        (let ((span (- next-position previous-position))
              (change (- next-value previous-value)))
          (setf (curve-key-tangent-in key)
                (case tangent-in-type
                  (:smooth (if (< (abs change) 1.1920929f-7)
                               0.0f0
                               (/ (* change (abs (- previous-position self-position)))
                                  span)))
                  (:linear (- self-value previous-value))
                  (t 0.0f0)))
          (setf (curve-key-tangent-out key)
                (case tangent-out-type
                  (:smooth (if (< (abs change) 1.1920929f-7)
                               0.0f0
                               (/ (* change (abs (- next-position self-position)))
                                  span)))
                  (:linear (- next-value self-value))
                  (t 0.0f0))))))
    (values)))

(defun curve-compute-tangents (curve tangent-in-type
                               &optional (tangent-out-type tangent-in-type))
  "Curve.ComputeTangents: COMPUTE-TANGENT over every key."
  (dotimes (index (curve-key-collection-count (curve-keys curve)) (values))
    (curve-compute-tangent curve index tangent-in-type tangent-out-type)))

(defun %curve-hermite (k0 k1 amount)
  "Curve.Hermite.

CurveContinuity.Step on the *first* key of the segment makes the whole segment
answer one endpoint, and the test is `amount < 1' -- so the value steps at the
end of the segment rather than at its middle."
  (cna-lisp.internal:with-binary32-semantics
    (if (eq :step (curve-key-continuity k0))
        (if (< amount 1.0f0) (curve-key-value k0) (curve-key-value k1))
        (let* ((squared (* amount amount))
               (cubed (* squared amount))
               (v0 (curve-key-value k0))
               (v1 (curve-key-value k1))
               (t0 (curve-key-tangent-out k0))
               (t1 (curve-key-tangent-in k1)))
          (+ (+ (+ (* v0 (+ (- (* 2.0f0 cubed) (* 3.0f0 squared)) 1.0f0))
                   (* v1 (+ (* -2.0f0 cubed) (* 3.0f0 squared))))
                (* t0 (+ (- cubed (* 2.0f0 squared)) amount)))
             (* t1 (- cubed squared)))))))

(defun %curve-find-segment (curve position)
  "Curve.FindSegment: the two keys around POSITION and the fraction between them.

Answers three values. The fraction is zero when the two keys are closer together
than 1e-10 *in binary64* -- the only place in the type that leaves binary32."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((keys (curve-keys curve))
           (count (curve-key-collection-count keys))
           (k0 (curve-key-collection-item keys 0))
           (k1 k0)
           (amount (f position)))
      (loop for index from 1 below count
            do (setf k1 (curve-key-collection-item keys index))
               (if (< (curve-key-position k1) position)
                   (setf k0 k1)
                   (let ((span (- (float (curve-key-position k1) 1.0d0)
                                  (float (curve-key-position k0) 1.0d0))))
                     (setf amount 0.0f0)
                     (when (> span 1.0d-10)
                       (setf amount (float (/ (- (float position 1.0d0)
                                                 (float (curve-key-position k0) 1.0d0))
                                              span)
                                           1.0f0)))
                     (return))))
      (values amount k0 k1))))

(defun %curve-cycle (curve position)
  "Curve.CalcCycle: how many whole key ranges POSITION is away from the first key.

Truncated toward zero after a subtraction of one for negatives, which is a floor
for every value except an exact integer below zero -- where it answers one less
than the floor. That is the framework's arithmetic."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((keys (curve-keys curve))
           (cycles (* (- position (curve-key-position (curve-key-collection-item keys 0)))
                      (%collection-inverse-time-range keys))))
      (when (< cycles 0.0f0)
        (setf cycles (- cycles 1.0f0)))
      (float (truncate cycles) 1.0f0))))

(defun %curve-fold (curve position first-key last-key loop-type)
  "Fold POSITION back inside the key range under LOOP-TYPE.

Answers the folded position and the value offset CycleOffset accumulates."
  (cna-lisp.internal:with-binary32-semantics
    (let ((keys (curve-keys curve)))
      (unless (%collection-cache-valid keys) (%compute-cache-values keys))
      (let* ((cycles (%curve-cycle curve position))
             (offset (- position (+ (curve-key-position first-key)
                                    (* cycles (%collection-time-range keys))))))
        (case loop-type
          (:cycle (values (+ (curve-key-position first-key) offset) 0.0f0))
          (:cycle-offset
           (values (+ (curve-key-position first-key) offset)
                   ;; The drift: one whole first-to-last value change per cycle.
                   (* (- (curve-key-value last-key) (curve-key-value first-key))
                      cycles)))
          (t
           ;; Oscillate: every other cycle runs backwards, measured from the far
           ;; end of the range.
           (values (if (zerop (logand (truncate cycles) 1))
                       (+ (curve-key-position first-key) offset)
                       (- (curve-key-position last-key) offset))
                   0.0f0)))))))

(defun curve-evaluate (curve position)
  "Curve.Evaluate.

Zero for an empty curve and the single key's value for a one-key curve; outside
the key range the PreLoop and PostLoop rules decide, and inside it a cubic
Hermite segment does."
  (cna-lisp.internal:with-binary32-semantics
    (let* ((keys (curve-keys curve))
           (count (curve-key-collection-count keys)))
      (cond
        ((zerop count) 0.0f0)
        ((= count 1) (curve-key-value (curve-key-collection-item keys 0)))
        (t
         (let* ((first-key (curve-key-collection-item keys 0))
                (last-key (curve-key-collection-item keys (1- count)))
                (at (f position))
                (offset 0.0f0))
           (cond
             ((< at (curve-key-position first-key))
              (case (curve-pre-loop curve)
                (:constant (return-from curve-evaluate (curve-key-value first-key)))
                (:linear
                 ;; TangentIn, and *minus* the distance: the same expression the
                 ;; post-loop side uses, which is why extrapolating before the
                 ;; curve follows the first key's incoming slope.
                 (return-from curve-evaluate
                   (- (curve-key-value first-key)
                      (* (curve-key-tangent-in first-key)
                         (- (curve-key-position first-key) at)))))
                (t (multiple-value-setq (at offset)
                     (%curve-fold curve at first-key last-key (curve-pre-loop curve))))))
             ((< (curve-key-position last-key) at)
              (case (curve-post-loop curve)
                (:constant (return-from curve-evaluate (curve-key-value last-key)))
                (:linear
                 (return-from curve-evaluate
                   (- (curve-key-value last-key)
                      (* (curve-key-tangent-out last-key)
                         (- (curve-key-position last-key) at)))))
                (t (multiple-value-setq (at offset)
                     (%curve-fold curve at first-key last-key
                                  (curve-post-loop curve)))))))
           (multiple-value-bind (amount k0 k1) (%curve-find-segment curve at)
             (+ offset (%curve-hermite k0 k1 amount)))))))))
