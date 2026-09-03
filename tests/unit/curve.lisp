;;;; curve.lisp --- Curve, CurveKey and CurveKeyCollection.
;;;;
;;;; The formulas are cubic Hermite interpolation and nobody gets those wrong.
;;;; What these tests pin is everything around them: where a step continuity
;;;; steps, what each loop type does with a position outside the key range, what
;;;; a smooth tangent looks like at an end key, and how a collection orders two
;;;; keys at the same position.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(defun test-curve (&rest specs)
  (let ((curve (make-instance 'xna:curve)))
    (dolist (spec specs curve)
      (curve-key-collection-add-spec curve spec))))

(defun curve-key-collection-add-spec (curve spec)
  (destructuring-bind (position value &optional (in 0.0) (out 0.0)) spec
    (xna:curve-key-collection-add
     (xna:curve-keys curve)
     (make-instance 'xna:curve-key :position position :value value
                                   :tangent-in in :tangent-out out))))

(test an-empty-or-single-key-curve-is-constant
  (let ((empty (make-instance 'xna:curve)))
    (is (xna:curve-is-constant empty))
    (is (= 0.0f0 (xna:curve-evaluate empty 5.0)) "an empty curve answers zero"))
  (let ((one (test-curve '(3.0 7.0))))
    (is (xna:curve-is-constant one))
    (is (= 7.0f0 (xna:curve-evaluate one 100.0))
        "a one-key curve answers that key's value everywhere, loop rules and all")))

(test a-curve-key-is-ordered-by-position-and-equal-by-everything
  (let ((a (make-instance 'xna:curve-key :position 1.0 :value 2.0))
        (b (make-instance 'xna:curve-key :position 1.0 :value 9.0))
        (c (make-instance 'xna:curve-key :position 2.0 :value 2.0)))
    (is (= 0 (xna:curve-key-compare-to a b)) "ordering looks only at the position")
    (is (= -1 (xna:curve-key-compare-to a c)))
    (is (= 1 (xna:curve-key-compare-to c a)))
    (is (not (xna:curve-key-equal a b)) "and equality looks at everything")
    (is (xna:curve-key-equal a (xna:curve-key-clone a)))
    (let ((clone (xna:curve-key-clone a)))
      (setf (xna:curve-key-value clone) 5.0)
      (is (= 2.0f0 (xna:curve-key-value a)) "a clone is a copy, not an alias"))))

(test a-key-collection-sorts-and-keeps-duplicates
  (let ((curve (test-curve '(2.0 20.0) '(0.0 0.0) '(1.0 10.0))))
    (let ((keys (xna:curve-keys curve)))
      (is (= 3 (xna:curve-key-collection-count keys)))
      (is (= 0.0f0 (xna:curve-key-position (xna:curve-key-collection-item keys 0))))
      (is (= 1.0f0 (xna:curve-key-position (xna:curve-key-collection-item keys 1))))
      (is (= 2.0f0 (xna:curve-key-position (xna:curve-key-collection-item keys 2))))
      ;; A key added at a position that is already there goes *after* it.
      (xna:curve-key-collection-add
       keys (make-instance 'xna:curve-key :position 1.0 :value 99.0))
      (is (= 4 (xna:curve-key-collection-count keys)))
      (is (= 10.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 1))))
      (is (= 99.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 2))))
      (is (not (xna:curve-key-collection-is-read-only keys))))))

(test replacing-a-key-at-a-new-position-moves-it
  ;; The setter does not overwrite in place when the position differs: it removes
  ;; the old key and adds the new one, so the index the caller used stops naming
  ;; it. Overwriting in place would leave the collection unsorted.
  (let* ((curve (test-curve '(0.0 0.0) '(1.0 10.0) '(2.0 20.0)))
         (keys (xna:curve-keys curve)))
    (setf (xna:curve-key-collection-item keys 0)
          (make-instance 'xna:curve-key :position 5.0 :value 50.0))
    (is (= 3 (xna:curve-key-collection-count keys)))
    (is (= 10.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 0))))
    (is (= 50.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 2))))
    ;; Same position: a plain replacement, in place.
    (setf (xna:curve-key-collection-item keys 0)
          (make-instance 'xna:curve-key :position 1.0 :value 11.0))
    (is (= 11.0f0 (xna:curve-key-value (xna:curve-key-collection-item keys 0))))))

(test a-key-collection-removes-and-searches-by-value
  (let* ((curve (test-curve '(0.0 0.0) '(1.0 10.0) '(2.0 20.0)))
         (keys (xna:curve-keys curve))
         (equal-but-not-eq (make-instance 'xna:curve-key :position 1.0 :value 10.0)))
    (is (= 1 (xna:curve-key-collection-index-of keys equal-but-not-eq))
        "the search is by value, so a key that merely equals one in the collection finds it")
    (is (xna:curve-key-collection-contains keys equal-but-not-eq))
    (is (xna:curve-key-collection-remove keys equal-but-not-eq))
    (is (= 2 (xna:curve-key-collection-count keys)))
    (is (null (xna:curve-key-collection-index-of keys equal-but-not-eq)))
    (is (not (xna:curve-key-collection-remove keys equal-but-not-eq)))
    (signals xna:cna-argument-out-of-range-error
      (xna:curve-key-collection-item keys 7))
    (xna:curve-key-collection-clear keys)
    (is (= 0 (xna:curve-key-collection-count keys)))))

(test a-key-collection-copies-out-as-a-sequence
  (let* ((curve (test-curve '(0.0 0.0) '(1.0 10.0)))
         (keys (xna:curve-keys curve))
         (snapshot (xna:curve-key-collection-keys keys)))
    (is (= 2 (length snapshot)))
    (xna:curve-key-collection-add keys (make-instance 'xna:curve-key :position 2.0))
    (is (= 2 (length snapshot)) "the sequence is a copy, not a window")
    (let ((array (make-array 5 :initial-element nil)))
      (xna:curve-key-collection-copy-to keys array 1)
      (is (null (aref array 0)))
      (is (= 10.0f0 (xna:curve-key-value (aref array 2))))
      (signals xna:cna-argument-out-of-range-error
        (xna:curve-key-collection-copy-to keys array 4)))))

(test cloning-a-curve-shares-its-keys
  ;; Clone is shallow on both levels: the clone has its own collection holding
  ;; the same key objects, so moving a key is visible through both curves.
  (let* ((curve (test-curve '(0.0 0.0) '(1.0 10.0)))
         (clone (xna:curve-clone curve)))
    (setf (xna:curve-pre-loop clone) :cycle)
    (is (eq :constant (xna:curve-pre-loop curve)) "the loop settings are copied")
    (xna:curve-key-collection-add (xna:curve-keys clone)
                                  (make-instance 'xna:curve-key :position 2.0))
    (is (= 2 (xna:curve-key-collection-count (xna:curve-keys curve)))
        "and the collection is a separate collection")
    (setf (xna:curve-key-value (xna:curve-key-collection-item (xna:curve-keys clone) 1))
          77.0)
    (is (= 77.0f0 (xna:curve-key-value
                   (xna:curve-key-collection-item (xna:curve-keys curve) 1)))
        "holding the same key objects")))

(test smooth-tangents-are-smaller-at-an-end-key
  ;; A smooth tangent is the neighbouring value change scaled by this side's
  ;; share of the neighbouring position span. An end key's neighbour on one side
  ;; is itself, so that side's tangent is zero rather than a mirror of the other.
  (let* ((curve (test-curve '(0.0 0.0) '(1.0 1.0) '(2.0 0.0)))
         (keys (xna:curve-keys curve)))
    (xna:curve-compute-tangents curve :smooth)
    (let ((first-key (xna:curve-key-collection-item keys 0))
          (middle (xna:curve-key-collection-item keys 1))
          (last-key (xna:curve-key-collection-item keys 2)))
      (is (= 0.0f0 (xna:curve-key-tangent-in first-key)))
      (is (= 1.0f0 (xna:curve-key-tangent-out first-key)))
      ;; The middle key's neighbours have the same value, so the change is zero
      ;; and both its tangents are flat -- a peak, not a slope.
      (is (= 0.0f0 (xna:curve-key-tangent-in middle)))
      (is (= 0.0f0 (xna:curve-key-tangent-out middle)))
      (is (= -1.0f0 (xna:curve-key-tangent-in last-key)))
      (is (= 0.0f0 (abs (xna:curve-key-tangent-out last-key)))))
    (signals xna:cna-argument-out-of-range-error
      (xna:curve-compute-tangent curve 9 :smooth))))

(test linear-and-flat-tangents
  (let* ((curve (test-curve '(0.0 0.0) '(1.0 2.0) '(2.0 3.0)))
         (keys (xna:curve-keys curve)))
    (xna:curve-compute-tangents curve :linear)
    (is (= 0.0f0 (xna:curve-key-tangent-in (xna:curve-key-collection-item keys 0))))
    (is (= 2.0f0 (xna:curve-key-tangent-out (xna:curve-key-collection-item keys 0))))
    (is (= 2.0f0 (xna:curve-key-tangent-in (xna:curve-key-collection-item keys 1))))
    (is (= 1.0f0 (xna:curve-key-tangent-out (xna:curve-key-collection-item keys 1))))
    (xna:curve-compute-tangents curve :flat)
    (is (= 0.0f0 (xna:curve-key-tangent-out (xna:curve-key-collection-item keys 0))))
    ;; The two-type form: a linear tangent in and a flat one out.
    (xna:curve-compute-tangents curve :linear :flat)
    (is (= 2.0f0 (xna:curve-key-tangent-in (xna:curve-key-collection-item keys 1))))
    (is (= 0.0f0 (xna:curve-key-tangent-out (xna:curve-key-collection-item keys 1))))))

(test step-continuity-steps-at-the-end-of-its-segment
  ;; CurveContinuity.Step on a key makes the segment *after* it answer one
  ;; endpoint or the other, and the test is `t < 1' -- so the value holds the
  ;; left key right up to the next key rather than switching half way.
  (let* ((curve (test-curve '(0.0 0.0) '(1.0 10.0)))
         (keys (xna:curve-keys curve)))
    (setf (xna:curve-key-continuity (xna:curve-key-collection-item keys 0)) :step)
    (is (= 0.0f0 (xna:curve-evaluate curve 0.5)))
    (is (= 0.0f0 (xna:curve-evaluate curve 0.999)))
    (is (= 10.0f0 (xna:curve-evaluate curve 1.0)))))

(test the-five-loop-types-differ-outside-the-key-range
  (let ((curve (test-curve '(0.0 0.0) '(1.0 2.0) '(2.0 3.0))))
    (xna:curve-compute-tangents curve :linear)
    (flet ((at (loop-type position)
             (setf (xna:curve-pre-loop curve) loop-type
                   (xna:curve-post-loop curve) loop-type)
             (xna:curve-evaluate curve position)))
      ;; Constant: the nearer end key's value, flat forever.
      (is (= 0.0f0 (at :constant -0.5)))
      (is (= 3.0f0 (at :constant 2.5)))
      ;; Cycle: the position folded back into the range.
      (is (~= (at :cycle 0.5) (at :cycle 2.5)))
      (is (~= (at :cycle 0.5) (at :cycle 4.5)))
      (is (~= (at :cycle 1.5) (at :cycle -0.5)))
      ;; CycleOffset: the same fold, plus one whole first-to-last value change
      ;; per cycle, so a looping curve drifts instead of repeating.
      (is (~= (+ (at :cycle 0.5) 3.0f0) (at :cycle-offset 2.5)))
      (is (~= (+ (at :cycle 0.5) 6.0f0) (at :cycle-offset 4.5)))
      (is (~= (- (at :cycle 1.5) 3.0f0) (at :cycle-offset -0.5)))
      ;; Oscillate: every other cycle runs backwards from the far end.
      (is (~= (at :oscillate 2.5) (xna:curve-evaluate curve 1.5)))
      (is (~= (at :oscillate 4.5) (at :cycle 0.5)))
      ;; Linear: extrapolate along the end key's tangent. With linear tangents
      ;; the last key's outgoing tangent is zero, so it is flat -- set one to see
      ;; the extrapolation.
      (is (= 3.0f0 (at :linear 2.5)))
      (setf (xna:curve-key-tangent-out
             (xna:curve-key-collection-item (xna:curve-keys curve) 2))
            1.0)
      (is (~= 3.5f0 (at :linear 2.5)))
      (setf (xna:curve-key-tangent-in
             (xna:curve-key-collection-item (xna:curve-keys curve) 0))
            1.0)
      (is (~= -0.5f0 (at :linear -0.5))))))

(test a-curve-interpolates-between-its-keys
  (let ((curve (test-curve '(0.0 0.0) '(1.0 1.0) '(2.0 0.0))))
    (xna:curve-compute-tangents curve :smooth)
    (is (= 0.0f0 (xna:curve-evaluate curve 0.0)))
    (is (= 1.0f0 (xna:curve-evaluate curve 1.0)))
    (is (= 0.0f0 (xna:curve-evaluate curve 2.0)))
    (is (~= 0.625f0 (xna:curve-evaluate curve 0.5)))
    (is (~= (xna:curve-evaluate curve 0.5) (xna:curve-evaluate curve 1.5))
        "this curve is symmetric, and so is its interpolation")))
