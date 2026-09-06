;;;; visualization-data.lisp --- Microsoft.Xna.Framework.Media.VisualizationData.
;;;;
;;;; **A pair of buffers a caller allocates and the player fills**, and that is
;;;; the whole of it. XNA's type has a public parameterless constructor, two
;;;; `float32[]' fields and two `ReadOnlyCollection<float>' properties over them;
;;;; `MediaPlayer.GetVisualizationData(vd)' hands the two arrays to native code,
;;;; which writes into them in place.
;;;;
;;;; CNA models the same thing as a **by-value struct** rather than a handle, and
;;;; its header says why in as many words: "there is nothing variable to
;;;; describe". `CNA_VisualizationData' is `struct_size', `struct_version' and
;;;; two 256-element float arrays, 2056 bytes in total.
;;;;
;;;; So this is a plain CLOS object holding two Lisp vectors, and it owns no
;;;; native anything. It is not a NATIVE-OBJECT, it has no handle and there is no
;;;; disposal -- XNA has none either.
;;;;
;;;; **The size is CNA's constant, not a number written here.**
;;;; `CNA_VISUALIZATION_DATA_SIZE' is 256 and is generated into the foreign layer;
;;;; XNA's own arrays are allocated by its constructor at whatever size its native
;;;; layer wants, and the pinned IL shows `GetVisualizationData' passing
;;;; `frequencies.Length' and `samples.Length' rather than a constant -- so the
;;;; length is a property of the buffer, and taking CNA's is the faithful thing.

(in-package #:microsoft.xna.framework.media)

(deftype visualization-sample-vector ()
  "The element type both buffers hold: XNA's `float32[]' as a binary32 vector."
  '(simple-array single-float (*)))

(defclass visualization-data ()
  ((frequencies :initarg :frequencies :reader %visualization-frequencies
                :type visualization-sample-vector
                :documentation "XNA's `frequencies' field, a binary32 vector.")
   (samples :initarg :samples :reader %visualization-samples
            :type visualization-sample-vector
            :documentation "XNA's `samples' field, a binary32 vector."))
  (:documentation
   "Microsoft.Xna.Framework.Media.VisualizationData: two buffers the player fills.

    (let ((data (make-visualization-data)))
      (setf (media-player-is-visualization-enabled) t)
      (media-player-get-visualization-data data)
      (frequencies data))

**Not sealed in XNA**, which is unusual for this namespace and is reproduced by
leaving the class open: a program may subclass it, and `GetVisualizationData'
takes whatever it is given.

It owns nothing native. `MAKE-VISUALIZATION-DATA' allocates the two buffers at
the size CNA's own `CNA_VISUALIZATION_DATA_SIZE' names, and
`MEDIA-PLAYER-GET-VISUALIZATION-DATA' writes into them in place -- so the object
a program keeps is the object that gets filled, exactly as in XNA."))

(defun make-visualization-data ()
  "VisualizationData(): two zeroed buffers, ready to be filled.

XNA's one public constructor takes no arguments and allocates both arrays. The
length is `CNA_VISUALIZATION_DATA_SIZE', which is CNA's own constant rather than
a number chosen here.

**Zeroed, and that is CNA's documented initial value**, not an accident of
allocation: `cna_visualization_data_init' \"receives both buffers zeroed\", and a
Lisp vector made with `:initial-element 0.0f0' is the same value without a
foreign call for something this binding can state exactly."
  (flet ((buffer ()
           (make-array cna-lisp.internal.ffi::+visualization-data-size+
                       :element-type 'single-float :initial-element 0.0f0)))
    (make-instance 'visualization-data
                   :frequencies (buffer) :samples (buffer))))

(defgeneric frequencies (visualization-data)
  (:documentation
   "VisualizationData.Frequencies: the frequency-domain buffer.

XNA's property is a `ReadOnlyCollection<float>' over the object's own
`float32[]' field. This answers **the buffer itself**, which is the same
projection `SpriteFont.Characters' declares for a `ReadOnlyCollection<T>' of a
value type: Common Lisp has no read-only vector, and a fresh copy per call would
break the one thing the type is for -- `GetVisualizationData' fills the object's
buffers in place, and a caller reads them afterwards.

So the vector is live: read it, do not write it. Writing it does not corrupt
anything native -- there is nothing native -- it only writes over data the next
`GetVisualizationData' will overwrite anyway."))

(defgeneric samples (visualization-data)
  (:documentation
   "VisualizationData.Samples: the sample-domain buffer. See `FREQUENCIES'."))

(defmethod frequencies ((data visualization-data))
  (%visualization-frequencies data))

(defmethod samples ((data visualization-data))
  (%visualization-samples data))

(defmethod print-object ((data visualization-data) stream)
  (print-unreadable-object (data stream :type t)
    (format stream "~d frequency, ~d sample"
            (length (%visualization-frequencies data))
            (length (%visualization-samples data)))))
