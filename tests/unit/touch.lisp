;;;; touch.lisp --- the touch value types, without a native library.

(in-package #:cna-common-lisp.tests)
(in-suite unit-tests)

(test the-touch-enumerations-match-the-contract
  (is (= 0 (touch:touch-location-state-value :invalid)))
  (is (= 1 (touch:touch-location-state-value :released)))
  (is (= 2 (touch:touch-location-state-value :pressed)))
  (is (= 3 (touch:touch-location-state-value :moved)))
  ;; GestureType is a flags enum whose zero member is None -- the empty list.
  (is (= 0 (touch:gesture-type-value '())))
  (is (= 1 (touch:gesture-type-value :tap)))
  (is (= #x200 (touch:gesture-type-value :pinch-complete)))
  (is (= 3 (touch:gesture-type-value '(:tap :double-tap))))
  (is (equal '(:tap :hold) (touch:gesture-type-from-value 5)))
  (is (equal '(:none) (touch:gesture-type-from-value 0))
      "reading a zero back answers the named zero member, as SpriteEffects does")
  (is (= 0 (touch:gesture-type-value :none)))
  ;; DisplayOrientation is a flags enum too, and Portrait is 4 rather than 3.
  (is (= 4 (xna:display-orientation-value :portrait)))
  (is (= 0 (xna:display-orientation-value :default))))

(test a-touch-location-carries-an-optional-previous-location
  (let ((bare (touch:make-touch-location 7 :pressed (xna:make-vector2 10.0 20.0))))
    (is (= 7 (touch:touch-location-id bare)))
    (is (eq :pressed (touch:touch-location-state bare)))
    (is (= 10.0f0 (xna:vector2-x (touch:touch-location-position bare))))
    (multiple-value-bind (found previous)
        (touch:touch-location-try-get-previous-location bare)
      (is (not found) "a location with no previous state has none")
      (is (eq :invalid (touch:touch-location-state previous)))))
  (let ((moved (touch:make-touch-location 7 :moved (xna:make-vector2 30.0 40.0)
                                          :pressed (xna:make-vector2 10.0 20.0))))
    (multiple-value-bind (found previous)
        (touch:touch-location-try-get-previous-location moved)
      (is (eq t found))
      (is (eq :pressed (touch:touch-location-state previous)))
      (is (= 10.0f0 (xna:vector2-x (touch:touch-location-position previous))))
      (is (= 7 (touch:touch-location-id previous)) "the previous location is the same touch")))
  (signals type-error (touch:make-touch-location 1 :nearly (xna:make-vector2))))

(test touch-location-equality-ignores-the-previous-location
  ;; The original compares the id, the state and the position, which is why two
  ;; snapshots of one finger differ only when the finger did.
  (let ((a (touch:make-touch-location 1 :moved (xna:make-vector2 5.0 5.0)))
        (b (touch:make-touch-location 1 :moved (xna:make-vector2 5.0 5.0)
                                      :pressed (xna:make-vector2 0.0 0.0))))
    (is (touch:touch-location-equal a b))
    (is (not (touch:touch-location-equal
              a (touch:make-touch-location 2 :moved (xna:make-vector2 5.0 5.0)))))
    (is (not (touch:touch-location-equal
              a (touch:make-touch-location 1 :released (xna:make-vector2 5.0 5.0)))))))

(test a-touch-collection-is-a-mutable-value
  ;; XNA's TouchCollection is a value type that also implements IList, so a
  ;; caller may add to and remove from a copy of what the panel reported.
  (let ((collection (touch:make-touch-collection
                     (list (touch:make-touch-location 1 :pressed (xna:make-vector2 1.0 1.0))
                           (touch:make-touch-location 2 :moved (xna:make-vector2 2.0 2.0))))))
    (is (= 2 (touch:touch-collection-count collection)))
    (is (touch:touch-collection-is-connected collection))
    (is (not (touch:touch-collection-is-read-only collection)))
    (is (= 1 (touch:touch-location-id (touch:touch-collection-item collection 0))))
    (signals xna:cna-argument-out-of-range-error (touch:touch-collection-item collection 2))
    ;; FindById answers two values, the flag first.
    (multiple-value-bind (found location) (touch:touch-collection-find-by-id collection 2)
      (is (eq t found))
      (is (eq :moved (touch:touch-location-state location))))
    (multiple-value-bind (found location) (touch:touch-collection-find-by-id collection 99)
      (is (not found))
      (is (eq :invalid (touch:touch-location-state location))))
    ;; The list operations.
    (touch:touch-collection-add collection
                                (touch:make-touch-location 3 :released (xna:make-vector2)))
    (is (= 3 (touch:touch-collection-count collection)))
    (touch:touch-collection-insert
     collection 0 (touch:make-touch-location 0 :pressed (xna:make-vector2)))
    (is (= 0 (touch:touch-location-id (touch:touch-collection-item collection 0))))
    (is (= 1 (touch:touch-location-id (touch:touch-collection-item collection 1))))
    (is (= 4 (touch:touch-collection-count collection)))
    (is (= 4 (length (touch:touch-collection-locations-vector collection))))
    (touch:touch-collection-remove-at collection 0)
    (is (= 1 (touch:touch-location-id (touch:touch-collection-item collection 0))))
    (is (touch:touch-collection-contains
         collection (touch:make-touch-location 2 :moved (xna:make-vector2 2.0 2.0))))
    (is (touch:touch-collection-remove
         collection (touch:make-touch-location 2 :moved (xna:make-vector2 2.0 2.0))))
    (is (not (touch:touch-collection-remove
              collection (touch:make-touch-location 99 :moved (xna:make-vector2)))))
    (let ((array (make-array 4 :initial-element nil)))
      (touch:touch-collection-copy-to collection array 1)
      (is (null (aref array 0)))
      (is (= 1 (touch:touch-location-id (aref array 1))))
      (signals xna:cna-argument-out-of-range-error
        (touch:touch-collection-copy-to collection array 3)))
    (touch:touch-collection-clear collection)
    (is (= 0 (touch:touch-collection-count collection)))))

(test copying-a-touch-collection-copies-its-touches
  ;; A shared adjustable vector would make the copy an alias, which a value type
  ;; must not be.
  (let* ((original (touch:make-touch-collection
                    (list (touch:make-touch-location 1 :pressed (xna:make-vector2)))))
         (copy (touch:copy-touch-collection original)))
    (touch:touch-collection-add copy (touch:make-touch-location 2 :pressed
                                                               (xna:make-vector2)))
    (is (= 1 (touch:touch-collection-count original)))
    (is (= 2 (touch:touch-collection-count copy)))))

(test a-gesture-sample-carries-a-timespan-as-ticks
  (let ((sample (touch:make-gesture-sample
                 '(:tap) 1234567
                 (xna:make-vector2 1.0 2.0) (xna:make-vector2 3.0 4.0)
                 (xna:make-vector2 5.0 6.0) (xna:make-vector2 7.0 8.0))))
    (is (equal '(:tap) (touch:gesture-sample-gesture-type sample)))
    (is (= 1234567 (touch:gesture-sample-timestamp sample))
        "TimeSpan is an integer count of 100-nanosecond ticks, as GameTime's are")
    (is (= 3.0f0 (xna:vector2-x (touch:gesture-sample-position-2 sample))))
    (is (= 8.0f0 (xna:vector2-y (touch:gesture-sample-delta-2 sample))))))
