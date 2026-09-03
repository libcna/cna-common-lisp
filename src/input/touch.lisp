;;;; touch.lisp --- Microsoft.Xna.Framework.Input.Touch.
;;;;
;;;; XNA puts the touch panel in its own namespace and its own assembly, and so
;;;; does this: MICROSOFT.XNA.FRAMEWORK.INPUT.TOUCH is a package of its own.
;;;;
;;;; Two shapes here are unlike the rest of the input surface.
;;;;
;;;; `TouchCollection' is a **mutable value type**: a snapshot of the touch
;;;; points that also implements the whole `IList<TouchLocation>' interface, so a
;;;; caller may add to and remove from a copy of what the panel reported. That is
;;;; odd, it is the contract, and it is projected as it stands.
;;;;
;;;; `TouchLocation' carries an optional *previous* location -- the same touch
;;;; one frame earlier -- and `TryGetPreviousLocation' answers whether there is
;;;; one. It is a Boolean and an out parameter in the original, so it is two
;;;; values here, the Boolean first.

(in-package #:microsoft.xna.framework.input.touch)

(microsoft.xna.framework::define-xna-enum touch-location-state
  '((:invalid . 0) (:released . 1) (:pressed . 2) (:moved . 3))
  :documentation "Microsoft.Xna.Framework.Input.Touch.TouchLocationState.")

(microsoft.xna.framework::define-xna-enum gesture-type
  '((:none . 0) (:tap . #x001) (:double-tap . #x002) (:hold . #x004)
    (:horizontal-drag . #x008) (:vertical-drag . #x010) (:free-drag . #x020)
    (:pinch . #x040) (:flick . #x080) (:drag-complete . #x100)
    (:pinch-complete . #x200))
  :documentation
  "Microsoft.Xna.Framework.Input.Touch.GestureType, a flags enum.

Its zero member is None, and it is in the table, so reading a zero back answers
`(:none)' -- the same shape SpriteEffects uses. Passing the empty list means the
same thing on the way in."
  :flags t)

;;; --- TouchLocation ----------------------------------------------------------

(defstruct (touch-location
            (:constructor %make-touch-location
                (id state position previous-state previous-position))
            (:copier copy-touch-location))
  "Microsoft.Xna.Framework.Input.Touch.TouchLocation: one touch point."
  (id 0 :type (signed-byte 32))
  (state :invalid :type keyword)
  (position (xna:make-vector2) :type xna:vector2)
  (previous-state :invalid :type keyword)
  (previous-position (xna:make-vector2) :type xna:vector2))

(defun make-touch-location (id state position
                            &optional (previous-state :invalid)
                                      (previous-position (xna:make-vector2)))
  "TouchLocation(int, TouchLocationState, Vector2) and the five-argument form.

The two overloads differ only by the trailing previous state and position, so
they are trailing optional arguments rather than two functions."
  (check-type state touch-location-state)
  (check-type previous-state touch-location-state)
  (%make-touch-location id state (xna:copy-vector2 position)
                        previous-state (xna:copy-vector2 previous-position)))

(defun touch-location-try-get-previous-location (location)
  "TouchLocation.TryGetPreviousLocation.

Answers two values: whether there is a previous location, and the location. The
Boolean comes first because the original's does, and because a caller who takes
only the second value gets an invalid location rather than being told there is
none."
  (let ((found (not (eq :invalid (touch-location-previous-state location)))))
    (values found
            (%make-touch-location (touch-location-id location)
                                  (touch-location-previous-state location)
                                  (xna:copy-vector2
                                   (touch-location-previous-position location))
                                  :invalid (xna:make-vector2)))))

(defun touch-location-equal (left right)
  "TouchLocation.Equals and op_Equality."
  (and (= (touch-location-id left) (touch-location-id right))
       (eq (touch-location-state left) (touch-location-state right))
       (xna:vector2-equal (touch-location-position left)
                          (touch-location-position right))))

;;; --- TouchCollection --------------------------------------------------------

(defstruct (touch-collection (:constructor %make-touch-collection (locations connected))
                             (:copier %copy-touch-collection))
  "Microsoft.Xna.Framework.Input.Touch.TouchCollection: the touch points at one
instant, and a mutable list of them."
  (locations (make-array 0 :adjustable t :fill-pointer 0) :type (and vector (not simple-vector)))
  (connected nil :type boolean))

(defun make-touch-collection (&optional locations)
  "TouchCollection(TouchLocation[])."
  (let ((store (make-array (length locations) :adjustable t :fill-pointer 0)))
    (map nil (lambda (location)
               (check-type location touch-location)
               (vector-push-extend location store))
         locations)
    (%make-touch-collection store t)))

(defun copy-touch-collection (collection)
  "A copy of COLLECTION. Value semantics: adding to the copy does not add to the
original, which a shared adjustable vector would."
  (%make-touch-collection
   (let ((store (make-array (length (touch-collection-locations collection))
                            :adjustable t :fill-pointer 0)))
     (loop for location across (touch-collection-locations collection)
           do (vector-push-extend location store))
     store)
   (touch-collection-connected collection)))

(defun touch-collection-count (collection)
  "TouchCollection.Count."
  (length (touch-collection-locations collection)))

(defun touch-collection-is-connected (collection)
  "TouchCollection.IsConnected."
  (touch-collection-connected collection))

(defun touch-collection-is-read-only (collection)
  "TouchCollection.IsReadOnly, which is always false -- see the file header."
  (declare (ignore collection))
  nil)

(defun %check-touch-index (collection index operation &optional (limit nil))
  (let ((count (or limit (touch-collection-count collection))))
    (unless (and (integerp index) (<= 0 index) (< index count))
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name "index"
             :format-control "the collection holds ~d touch~:p and the index is ~s."
             :format-arguments (list (touch-collection-count collection) index)))))

(defun touch-collection-item (collection index)
  "TouchCollection.Item."
  (%check-touch-index collection index "touch-collection-item")
  (aref (touch-collection-locations collection) index))

(defun (setf touch-collection-item) (location collection index)
  "TouchCollection.Item setter."
  (check-type location touch-location)
  (%check-touch-index collection index "touch-collection-item")
  (setf (aref (touch-collection-locations collection) index) location))

(defun touch-collection-index-of (collection location)
  "TouchCollection.IndexOf, or NIL when it is not there."
  (position location (touch-collection-locations collection) :test #'touch-location-equal))

(defun touch-collection-contains (collection location)
  "TouchCollection.Contains."
  (and (touch-collection-index-of collection location) t))

(defun touch-collection-add (collection location)
  "TouchCollection.Add."
  (check-type location touch-location)
  (vector-push-extend location (touch-collection-locations collection))
  (values))

(defun touch-collection-insert (collection index location)
  "TouchCollection.Insert."
  (check-type location touch-location)
  (%check-touch-index collection index "touch-collection-insert"
                      (1+ (touch-collection-count collection)))
  (let* ((store (touch-collection-locations collection))
         (count (length store)))
    (vector-push-extend location store)
    (replace store store :start1 (1+ index) :start2 index :end2 count)
    (setf (aref store index) location))
  (values))

(defun touch-collection-remove-at (collection index)
  "TouchCollection.RemoveAt."
  (%check-touch-index collection index "touch-collection-remove-at")
  (let ((store (touch-collection-locations collection)))
    (replace store store :start1 index :start2 (1+ index))
    (decf (fill-pointer store)))
  (values))

(defun touch-collection-remove (collection location)
  "TouchCollection.Remove: answers whether it found one to remove."
  (let ((index (touch-collection-index-of collection location)))
    (when index (touch-collection-remove-at collection index) t)))

(defun touch-collection-clear (collection)
  "TouchCollection.Clear."
  (setf (fill-pointer (touch-collection-locations collection)) 0)
  (values))

(defun touch-collection-copy-to (collection array index)
  "TouchCollection.CopyTo."
  (let ((store (touch-collection-locations collection)))
    (unless (and (integerp index) (>= index 0)
                 (>= (- (length array) index) (length store)))
      (error 'xna:cna-argument-out-of-range-error
             :operation "touch-collection-copy-to" :parameter-name "index"
             :format-control "~d touch~:p do not fit in an array of ~d from index ~s."
             :format-arguments (list (length store) (length array) index)))
    (replace array store :start1 index))
  (values))

(defun touch-collection-locations-vector (collection)
  "TouchCollection.GetEnumerator, as a fresh vector of the locations.

Common Lisp has no enumerator object, and a Lisp caller iterates a sequence."
  (coerce (touch-collection-locations collection) 'simple-vector))

(defun touch-collection-find-by-id (collection id)
  "TouchCollection.FindById.

Answers two values -- whether a touch with that id is in the collection, and the
touch -- because the original answers a Boolean and an out parameter."
  (let ((found (find id (touch-collection-locations collection)
                     :key #'touch-location-id)))
    (values (and found t)
            (or found (%make-touch-location 0 :invalid (xna:make-vector2)
                                            :invalid (xna:make-vector2))))))

;;; --- TouchPanelCapabilities and GestureSample -------------------------------

(defstruct (touch-panel-capabilities
            (:constructor %make-touch-panel-capabilities (connected maximum-touch-count))
            (:copier copy-touch-panel-capabilities))
  "Microsoft.Xna.Framework.Input.Touch.TouchPanelCapabilities.

No public constructor in XNA -- TOUCH-PANEL-GET-CAPABILITIES is the only way to
obtain one -- and none here."
  (connected nil :type boolean)
  (maximum-touch-count 0 :type (unsigned-byte 32)))

(defun touch-panel-capabilities-is-connected (capabilities)
  "TouchPanelCapabilities.IsConnected."
  (touch-panel-capabilities-connected capabilities))

(defstruct (gesture-sample
            (:constructor %make-gesture-sample
                (gesture-type timestamp position position-2 delta delta-2))
            (:copier copy-gesture-sample))
  "Microsoft.Xna.Framework.Input.Touch.GestureSample: one recognised gesture."
  (gesture-type '() :type list)
  (timestamp 0 :type integer)
  (position (xna:make-vector2) :type xna:vector2)
  (position-2 (xna:make-vector2) :type xna:vector2)
  (delta (xna:make-vector2) :type xna:vector2)
  (delta-2 (xna:make-vector2) :type xna:vector2))

(defun make-gesture-sample (gesture-type timestamp position position-2 delta delta-2)
  "GestureSample(GestureType, TimeSpan, Vector2, Vector2, Vector2, Vector2).

TIMESTAMP is a TimeSpan, which this projection carries as an integer count of
100-nanosecond ticks, as GAME-TIME does."
  (check-type timestamp integer)
  (%make-gesture-sample (if (listp gesture-type) gesture-type (list gesture-type))
                        timestamp
                        (xna:copy-vector2 position) (xna:copy-vector2 position-2)
                        (xna:copy-vector2 delta) (xna:copy-vector2 delta-2)))

;;; --- TouchPanel -------------------------------------------------------------

(defun %panel-game-handle (operation)
  (let ((game (cna-lisp.internal:active-game)))
    (unless game
      (error 'xna:cna-invalid-state-error
             :operation operation
             :format-control
             "~a needs a live game: CNA reads the touch panel through the active ~
              game, and there is none."
             :format-arguments (list operation)))
    (cna-lisp.internal:check-usable game operation)
    (cna-lisp.internal:handle-of game)))

(defmacro %with-out (type var &body body)
  `(cffi:with-foreign-object (,var ,type) ,@body))

(defun touch-panel-get-state ()
  "TouchPanel.GetState."
  (let ((handle (%panel-game-handle "touch-panel-get-state")))
    (cffi:with-foreign-object (state '(:struct cna-lisp.internal.ffi::cna-touch-state))
      (cffi:foreign-funcall "memset" :pointer state :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-touch-state+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     state '(:struct cna-lisp.internal.ffi::cna-touch-state) ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-touch-state+
              (slot cna-lisp.internal.ffi::struct-version) 1)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%touch-get-state handle state)
         "touch-panel-get-state")
        (let* ((count (slot cna-lisp.internal.ffi::touch-count))
               (base (cffi:foreign-slot-pointer
                      state '(:struct cna-lisp.internal.ffi::cna-touch-state)
                      'cna-lisp.internal.ffi::touches))
               (store (make-array count :adjustable t :fill-pointer 0)))
          (dotimes (i count)
            (let ((entry (cffi:inc-pointer
                          base (* i cna-lisp.internal.ffi::+sizeof-cna-touch-location+))))
              (macrolet ((touch-slot (name)
                           `(cffi:foreign-slot-value
                             entry '(:struct cna-lisp.internal.ffi::cna-touch-location)
                             ',name))
                         (touch-vector (name)
                           `(let ((pointer (cffi:foreign-slot-pointer
                                            entry
                                            '(:struct cna-lisp.internal.ffi::cna-touch-location)
                                            ',name)))
                              (xna:make-vector2 (cffi:mem-aref pointer :float 0)
                                                (cffi:mem-aref pointer :float 1)))))
                (vector-push-extend
                 (%make-touch-location
                  (touch-slot cna-lisp.internal.ffi::id)
                  (touch-location-state-from-value (touch-slot cna-lisp.internal.ffi::state))
                  (touch-vector cna-lisp.internal.ffi::position)
                  (touch-location-state-from-value
                   (touch-slot cna-lisp.internal.ffi::previous-state))
                  (touch-vector cna-lisp.internal.ffi::previous-position))
                 store))))
          (%make-touch-collection
           store
           (cna-lisp.internal.ffi:cna-true-p (slot cna-lisp.internal.ffi::is-connected))))))))

(defun touch-panel-get-capabilities ()
  "TouchPanel.GetCapabilities."
  (let ((handle (%panel-game-handle "touch-panel-get-capabilities")))
    (cffi:with-foreign-object
        (caps '(:struct cna-lisp.internal.ffi::cna-touch-capabilities))
      (cffi:foreign-funcall
       "memset" :pointer caps :int 0
       :size cna-lisp.internal.ffi::+sizeof-cna-touch-capabilities+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     caps '(:struct cna-lisp.internal.ffi::cna-touch-capabilities) ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-touch-capabilities+
              (slot cna-lisp.internal.ffi::struct-version) 1)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%touch-get-capabilities handle caps)
         "touch-panel-get-capabilities")
        (%make-touch-panel-capabilities
         (cna-lisp.internal.ffi:cna-true-p (slot cna-lisp.internal.ffi::is-connected))
         (slot cna-lisp.internal.ffi::maximum-touch-count))))))

(defun touch-panel-is-gesture-available ()
  "TouchPanel.IsGestureAvailable."
  (let ((handle (%panel-game-handle "touch-panel-is-gesture-available")))
    (cffi:with-foreign-object (available :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%touch-panel-get-is-gesture-available handle available)
       "touch-panel-is-gesture-available")
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref available :uint8)))))

(defun touch-panel-read-gesture ()
  "TouchPanel.ReadGesture."
  (let ((handle (%panel-game-handle "touch-panel-read-gesture")))
    (cffi:with-foreign-object (sample '(:struct cna-lisp.internal.ffi::cna-gesture-sample))
      (cffi:foreign-funcall "memset" :pointer sample :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-gesture-sample+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     sample '(:struct cna-lisp.internal.ffi::cna-gesture-sample) ',name))
                 (sample-vector (name)
                   `(let ((pointer (cffi:foreign-slot-pointer
                                    sample
                                    '(:struct cna-lisp.internal.ffi::cna-gesture-sample)
                                    ',name)))
                      (xna:make-vector2 (cffi:mem-aref pointer :float 0)
                                        (cffi:mem-aref pointer :float 1)))))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-gesture-sample+
              (slot cna-lisp.internal.ffi::struct-version) 1)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%touch-panel-read-gesture handle sample)
         "touch-panel-read-gesture")
        (%make-gesture-sample
         (gesture-type-from-value (slot cna-lisp.internal.ffi::gesture-type))
         (slot cna-lisp.internal.ffi::timestamp-ticks)
         (sample-vector cna-lisp.internal.ffi::position)
         (sample-vector cna-lisp.internal.ffi::position-2)
         (sample-vector cna-lisp.internal.ffi::delta)
         (sample-vector cna-lisp.internal.ffi::delta-2))))))

(defun touch-panel-enabled-gestures ()
  "TouchPanel.EnabledGestures."
  (let ((handle (%panel-game-handle "touch-panel-enabled-gestures")))
    (cffi:with-foreign-object (gestures :uint32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%touch-panel-get-enabled-gestures handle gestures)
       "touch-panel-enabled-gestures")
      (gesture-type-from-value (cffi:mem-ref gestures :uint32)))))

(defun (setf touch-panel-enabled-gestures) (gestures)
  "TouchPanel.EnabledGestures setter. The empty list is GestureType.None."
  (let ((handle (%panel-game-handle "touch-panel-enabled-gestures")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%touch-panel-set-enabled-gestures
      handle (gesture-type-value gestures))
     "touch-panel-enabled-gestures"))
  gestures)

(macrolet ((integer-property (name getter setter documentation)
             `(progn
                (defun ,name ()
                  ,documentation
                  (let ((handle (%panel-game-handle ,(string-downcase (symbol-name name)))))
                    (cffi:with-foreign-object (value :int32)
                      (cna-lisp.internal:check-result
                       (,getter handle value)
                       ,(string-downcase (symbol-name name)))
                      (cffi:mem-ref value :int32))))
                (defun (setf ,name) (value)
                  ,documentation
                  (check-type value integer)
                  (let ((handle (%panel-game-handle ,(string-downcase (symbol-name name)))))
                    (cna-lisp.internal:check-result
                     (,setter handle value)
                     ,(string-downcase (symbol-name name))))
                  value))))
  (integer-property touch-panel-display-width
                    cna-lisp.internal.ffi::%touch-panel-get-display-width
                    cna-lisp.internal.ffi::%touch-panel-set-display-width
                    "TouchPanel.DisplayWidth.")
  (integer-property touch-panel-display-height
                    cna-lisp.internal.ffi::%touch-panel-get-display-height
                    cna-lisp.internal.ffi::%touch-panel-set-display-height
                    "TouchPanel.DisplayHeight."))

(defun touch-panel-display-orientation ()
  "TouchPanel.DisplayOrientation."
  (let ((handle (%panel-game-handle "touch-panel-display-orientation")))
    (cffi:with-foreign-object (value :uint32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%touch-panel-get-display-orientation handle value)
       "touch-panel-display-orientation")
      (xna:display-orientation-from-value
       (cffi:mem-ref value :uint32)))))

(defun (setf touch-panel-display-orientation) (orientation)
  "TouchPanel.DisplayOrientation setter."
  (let ((handle (%panel-game-handle "touch-panel-display-orientation")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%touch-panel-set-display-orientation
      handle (xna:display-orientation-value orientation))
     "touch-panel-display-orientation"))
  orientation)
