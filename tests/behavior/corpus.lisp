;;;; corpus.lisp --- the behaviour corpus.
;;;;
;;;; Every observation records where it came from. That distinction is the whole
;;;; point: an observation derived from the Microsoft XNA contract says something
;;;; about compatibility, and an observation about how CNA-Lisp maps a thing says
;;;; something about this binding. Mixing them would let the binding appear to
;;;; prove its own compatibility.
;;;;
;;;;   :xna-derived      derived from the selected Microsoft XNA 4.0 Windows
;;;;                     public contract. CNA is never the authority here.
;;;;   :mapping          a CNA-Lisp mapping decision, qualified against itself.
;;;;   :abi-derived      a fact about the CNA C ABI's own published contract,
;;;;                     read from its canonical headers.
;;;;
;;;; An :xna-derived entry that CNA also answers may be cross-checked against
;;;; CNA. It is never *established* by CNA.

(in-package #:cna-common-lisp.tests)
(in-suite behavior-tests)

(defstruct observation
  id origin subject statement thunk)

(defparameter *corpus* '())

(defmacro defobservation (id origin subject statement &body body)
  `(progn
     (setf *corpus*
           (append (remove ,id *corpus* :key #'observation-id :test #'equal)
                   (list (make-observation :id ,id :origin ,origin :subject ,subject
                                           :statement ,statement
                                           :thunk (lambda () ,@body)))))
     ,id))

;;; --- XNA-derived ---------------------------------------------------------

(defobservation "color.packed-order" :xna-derived "Microsoft.Xna.Framework.Color"
  "PackedValue holds R in the low byte and A in the high byte."
  (= #x04030201 (xna:color-packed-value (xna:make-color 1 2 3 4))))

(defobservation "color.cornflower-blue" :xna-derived "Microsoft.Xna.Framework.Color"
  "CornflowerBlue is (100, 149, 237, 255)."
  (let ((c (xna:cornflower-blue)))
    (and (= 100 (xna:color-r c)) (= 149 (xna:color-g c))
         (= 237 (xna:color-b c)) (= 255 (xna:color-a c)))))

(defobservation "color.value-semantics" :xna-derived "Microsoft.Xna.Framework.Color"
  "A predefined colour is a value: mutating a read of it cannot affect the next read."
  (let ((c (xna:white)))
    (setf (xna:color-r c) 0)
    (= 255 (xna:color-r (xna:white)))))

(defobservation "rectangle.center-truncates" :xna-derived "Microsoft.Xna.Framework.Rectangle"
  "Center halves the extents with integer division, so an odd extent truncates."
  (let ((c (xna:rectangle-center (xna:make-rectangle 0 0 5 7))))
    (and (= 2 (xna:point-x c)) (= 3 (xna:point-y c)))))

(defobservation "rectangle.is-empty-is-all-four" :xna-derived
    "Microsoft.Xna.Framework.Rectangle"
  "IsEmpty requires all four components to be zero, not merely zero area."
  (and (xna:rectangle-is-empty (xna:rectangle-empty))
       (not (xna:rectangle-is-empty (xna:make-rectangle 5 5 0 0)))))

(defobservation "rectangle.contains-half-open" :xna-derived
    "Microsoft.Xna.Framework.Rectangle"
  "Contains includes the left and top edges and excludes the right and bottom."
  (let ((r (xna:make-rectangle 0 0 10 10)))
    (and (xna:rectangle-contains-coordinates r 0 0)
         (xna:rectangle-contains-coordinates r 9 9)
         (not (xna:rectangle-contains-coordinates r 10 10)))))

(defobservation "vector2.length-order" :xna-derived "Microsoft.Xna.Framework.Vector2"
  "Length sums the squares in binary32 and only then promotes to binary64 for
   the square root, so an input whose square overflows binary32 answers an
   infinity where a binary64 computation answers a finite number."
  (let ((v (xna:make-vector2 1.0f20 1.0f20)))
    (and (sb-ext:float-infinity-p (xna:vector2-length v))
         (not (sb-ext:float-infinity-p
               (coerce (sqrt (+ (* 1.0d20 1.0d20) (* 1.0d20 1.0d20))) 'single-float))))))

(defobservation "clr.ieee-default-exceptions" :xna-derived "the CLR numeric contract"
  "Floating-point arithmetic uses IEEE 754 default exception handling: an
   overflow answers an infinity and nothing is raised."
  (sb-ext:float-infinity-p (xna:vector2-length-squared (xna:make-vector2 1.0f20 1.0f20))))

(defobservation "vector2.divide-reciprocal" :xna-derived "Microsoft.Xna.Framework.Vector2"
  "Divide by a scalar takes the reciprocal once and multiplies."
  (let ((v (xna:vector2-divide (xna:make-vector2 1.0 1.0) 3.0f0)))
    (= (* 1.0f0 (/ 1.0f0 3.0f0)) (xna:vector2-x v))))

(defobservation "viewport.title-safe-threshold" :xna-derived
    "Microsoft.Xna.Framework.Graphics.Viewport"
  "TitleSafeArea insets only once the viewport is at least 640x480; below that
   the whole viewport is title safe."
  (let ((small (gfx:viewport-title-safe-area (gfx:make-viewport 0 0 320 240)))
        (large (gfx:viewport-title-safe-area (gfx:make-viewport 0 0 640 480))))
    (and (= 320 (xna:rectangle-width small))
         (= 0 (xna:rectangle-x small))
         (< (xna:rectangle-width large) 640)
         (> (xna:rectangle-x large) 0))))

(defobservation "viewport.aspect-ratio-zero" :xna-derived
    "Microsoft.Xna.Framework.Graphics.Viewport"
  "AspectRatio answers zero when either extent is zero rather than dividing."
  (= 0.0f0 (gfx:viewport-aspect-ratio (gfx:make-viewport 0 0 0 480))))

(defobservation "gametime.timespan-is-ticks" :xna-derived
    "Microsoft.Xna.Framework.GameTime"
  "TotalGameTime is a TimeSpan, an exact count of 100-nanosecond ticks."
  (= 10000000 xna:+ticks-per-second+))

(defobservation "game.default-fixed-step" :xna-derived "Microsoft.Xna.Framework.Game"
  "The default TargetElapsedTime is 1/60 second, 166667 ticks."
  (= 166667 xna:+default-target-elapsed-time-ticks+))

(defobservation "keyboardstate.duplicates-once" :xna-derived
    "Microsoft.Xna.Framework.Input.KeyboardState"
  "A duplicate key in the set-taking constructor contributes once."
  (equal '(:a) (input:get-pressed-keys (input:make-keyboard-state '(:a :a)))))

;;; --- ABI-derived ---------------------------------------------------------

(defobservation "abi.keys-values" :abi-derived "CNA_KEY_*"
  "Keys carries the Windows virtual-key values: Escape is 27 and A is 65."
  (and (= 27 (input:keys-value :escape)) (= 65 (input:keys-value :a))))

(defobservation "abi.sprite-effects-flags" :abi-derived "CNA_SPRITE_EFFECT_*"
  "SpriteEffects is a real flags enum: the two flips are bit 0 and bit 1."
  (and (= 1 (gfx:sprite-effects-value :flip-horizontally))
       (= 2 (gfx:sprite-effects-value :flip-vertically))))

(defobservation "abi.color-is-four-bytes" :abi-derived "CNA_Color"
  "CNA_Color is four bytes, one per channel, so its packed value is one 32-bit
   store."
  (= 4 (second (assoc 'ffi::cna-color ffi:*native-struct-layouts*))))

(defobservation "abi.string-view-is-pointer-and-length" :abi-derived "CNA_StringView"
  "CNA_StringView is sixteen bytes: a pointer at 0 and a byte count at 8."
  (let ((row (assoc 'ffi::cna-string-view ffi:*native-struct-layouts*)))
    (and (= 16 (second row))
         (equal '(0 8) (list (second (assoc 'ffi::data (fourth row)))
                             (second (assoc 'ffi::byte-length (fourth row))))))))

;;; --- mapping decisions ---------------------------------------------------

(defobservation "mapping.enum-is-a-keyword" :mapping "enumerations"
  "An enum member is a keyword and its type is a Common Lisp type."
  (and (typep :deferred 'gfx:sprite-sort-mode)
       (not (typep :nonsense 'gfx:sprite-sort-mode))))

(defobservation "mapping.flags-are-lists" :mapping "flags enumerations"
  "A flags enum member set is a list of keywords."
  (= 3 (gfx:sprite-effects-value '(:flip-horizontally :flip-vertically))))

(defobservation "mapping.static-class-prefix" :mapping "static classes"
  "A static class member is a package function named <class>-<member>."
  (fboundp 'input:keyboard-get-state))

(defobservation "mapping.overload-split" :mapping
    "Microsoft.Xna.Framework.Rectangle.Contains"
  "The three-argument overload is a separate function, because it cannot share a
   congruent generic function with the two-argument ones."
  (and (typep (fdefinition 'xna:rectangle-contains) 'generic-function)
       (not (typep (fdefinition 'xna:rectangle-contains-coordinates)
                   'generic-function))))

(defobservation "mapping.conditions-not-codes" :mapping "failures"
  "Failures are conditions; no result code is publicly readable."
  (and (subtypep 'xna:cna-native-error 'xna:cna-error)
       (null (find-symbol "CNA-ERROR-RESULT" '#:microsoft.xna.framework))))

;;; --- running the corpus --------------------------------------------------

(test the-behaviour-corpus-holds
  (let ((failures '()))
    (dolist (observation *corpus*)
      (handler-case
          (unless (funcall (observation-thunk observation))
            (push (observation-id observation) failures))
        (error (condition)
          (push (list (observation-id observation) condition) failures))))
    (is (null failures) "behaviour observations that do not hold: ~s" failures)))

(test the-corpus-records-an-origin-for-every-observation
  (dolist (observation *corpus*)
    (is (member (observation-origin observation) '(:xna-derived :mapping :abi-derived))
        "~a has no recognised origin" (observation-id observation))))

(test the-corpus-separates-xna-from-mapping
  ;; If every observation were a mapping observation the corpus would be
  ;; measuring the binding against itself.
  (let ((xna (count :xna-derived *corpus* :key #'observation-origin)))
    (is (plusp xna) "the corpus records no XNA-derived observation at all")))
