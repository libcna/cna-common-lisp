;;;; texture-streams.lisp --- Texture2D's four Stream members.
;;;;
;;;; `System.IO.Stream' projects onto an ordinary Common Lisp binary stream, so
;;;; these tests use ordinary Common Lisp streams: a file opened with
;;;; `:element-type '(unsigned-byte 8)'. Nothing here builds a stream object of
;;;; the binding's own, because there is not one to build.
;;;;
;;;; **The proof that matters is the round trip.** A texture is filled with known
;;;; texels, encoded to a PNG on disk through `SaveAsPng', read back through
;;;; `FromStream', and every texel is compared. That is evidence about the encoder
;;;; *and* the decoder at once, and neither could pass it by doing nothing.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defun %scratch-path (name)
  "A path under the build directory, which the qualification lanes already own."
  (merge-pathnames name (repository-path "build-probe/")))

(defclass texture-stream-game (graphics-game)
  ((round-trip :initform nil :accessor round-trip-result)
   (encoded-size :initform nil :accessor encoded-size)
   (jpeg-size :initform nil :accessor jpeg-size)
   (jpeg-decoded :initform nil :accessor jpeg-decoded-texture)
   (resized :initform nil :accessor resized-texture)
   (fitted :initform nil :accessor fitted-texture)
   (fitted-texels :initform nil :accessor fitted-texel-count)
   (wide-fitted-texels :initform nil :accessor wide-fitted-texel-count)
   (plain :initform nil :accessor plain-texture)
   (refusals :initform '() :accessor refusals)
   (failure :initform nil :accessor stream-failure))
  (:documentation
   "Encodes a known texture to disk and decodes it back, inside a callback."))

(defun %fitted-texel-count (texture)
  "How many texels TEXTURE holds, found by asking GET-DATA to fill arrays.

A decoded texture that was *fitted* cannot report its width or height -- 0.21.0
has no route for it -- but GET-DATA reads the whole texture, so the smallest
array it will fill is the texel count. Doubling until it is accepted finds that
count without needing the extent, and the count is what the fit's behaviour shows
up in."
  (loop for count = 1 then (* 2 count)
        while (<= count 65536)
        do (let ((buffer (make-array count :initial-element
                                     (xna:make-color 0 0 0 0))))
             (when (handler-case (progn (gfx:get-data texture buffer) t)
                     (error () nil))
               (return count)))
        finally (return nil)))

(defun %note-refusal (game label thunk)
  "Run THUNK and record the condition type it signalled, or :ACCEPTED."
  (push (cons label
              (handler-case (progn (funcall thunk) :accepted)
                (error (condition) (type-of condition))))
        (refusals game)))

(defparameter *stream-texels*
  (vector (xna:make-color 255 0 0 255) (xna:make-color 0 255 0 255)
          (xna:make-color 0 0 255 255) (xna:make-color 255 255 0 255))
  "A 2x2 image whose four texels are four different opaque colours, so a
round trip that transposed or flipped the image would not pass.")

(defmethod xna:load-content ((game texture-stream-game))
  (call-next-method)
  (handler-case
      (let ((device (xna:graphics-device game))
            (png (%scratch-path "texture-stream-round-trip.png"))
            (jpeg (%scratch-path "texture-stream-round-trip.jpg")))
        ;; A texture whose texels this test states, rather than a fixture read
        ;; from disk: the round trip has to compare against something known.
        (let ((source (make-instance 'gfx:texture-2d :graphics-device device
                                                     :width 2 :height 2)))
          (unwind-protect
               (progn
                 (gfx:set-data source *stream-texels*)
                 (with-open-file (out png :direction :output
                                          :element-type '(unsigned-byte 8)
                                          :if-exists :supersede)
                   (gfx:save-as-png source out 2 2))
                 (setf (encoded-size game)
                       (with-open-file (in png :element-type '(unsigned-byte 8))
                         (file-length in)))
                 (with-open-file (out jpeg :direction :output
                                           :element-type '(unsigned-byte 8)
                                           :if-exists :supersede)
                   (gfx:save-as-jpeg source out 2 2))
                 (setf (jpeg-size game)
                       (with-open-file (in jpeg :element-type '(unsigned-byte 8))
                         (file-length in)))
                 ;; Decoding the JPEG back is what makes SaveAsJpeg's claim more
                 ;; than "some bytes were written": only a real encoding decodes.
                 (setf (jpeg-decoded-texture game)
                       (with-open-file (in jpeg :element-type '(unsigned-byte 8))
                         (gfx:texture-2d-from-stream device in)))
                 ;; ...and back again, through the two-argument overload.
                 (let ((decoded (with-open-file (in png :element-type '(unsigned-byte 8))
                                  (gfx:texture-2d-from-stream device in))))
                   (setf (plain-texture game) decoded)
                   (let ((back (make-array 4 :initial-element
                                                  (xna:make-color 0 0 0 0))))
                     (gfx:get-data decoded back)
                     (setf (round-trip-result game) back)))
                 ;; the five-argument overload, both ways round
                 (setf (resized-texture game)
                       (with-open-file (in png :element-type '(unsigned-byte 8))
                         (gfx:texture-2d-from-stream device in
                                                     :width 8 :height 8 :zoom t))
                       (fitted-texture game)
                       (with-open-file (in png :element-type '(unsigned-byte 8))
                         (gfx:texture-2d-from-stream device in
                                                     :width 8 :height 8 :zoom nil)))
                 ;; **How many texels a fitting decode actually produced.** The
                 ;; texture cannot report its extent, but GET-DATA reads the whole
                 ;; of it, so the size of the array it fills is the extent's area.
                 ;; That is the only way to see the fit from the public API, and
                 ;; what it shows is the surprising part: CNA's fit *enlarges*.
                 (setf (fitted-texel-count game)
                       (%fitted-texel-count (fitted-texture game)))
                 ;; ...and with a non-square source, to see the aspect ratio too.
                 (let ((wide (make-instance 'gfx:texture-2d :graphics-device device
                                                            :width 4 :height 2))
                       (wide-png (%scratch-path "texture-stream-wide.png")))
                   (unwind-protect
                        (progn
                          (gfx:set-data wide (concatenate 'vector *stream-texels*
                                                          *stream-texels*))
                          (with-open-file (out wide-png :direction :output
                                                        :element-type '(unsigned-byte 8)
                                                        :if-exists :supersede)
                            (gfx:save-as-png wide out 4 2))
                          (let ((decoded (with-open-file (in wide-png
                                                             :element-type '(unsigned-byte 8))
                                           (gfx:texture-2d-from-stream
                                            device in :width 8 :height 8 :zoom nil))))
                            (unwind-protect
                                 (setf (wide-fitted-texel-count game)
                                       (%fitted-texel-count decoded))
                              (xna:dispose decoded))))
                     (xna:dispose wide)))
                 ;; and the shapes that must be refused
                 (%note-refusal game :partial-overload
                                (lambda ()
                                  (with-open-file (in png :element-type '(unsigned-byte 8))
                                    (gfx:texture-2d-from-stream device in :width 8))))
                 (%note-refusal game :null-stream
                                (lambda () (gfx:texture-2d-from-stream device nil)))
                 (%note-refusal game :character-stream
                                (lambda ()
                                  (with-open-file (in png :element-type 'character)
                                    (gfx:texture-2d-from-stream device in))))
                 (%note-refusal game :output-stream-to-read
                                (lambda ()
                                  (with-open-file (out (%scratch-path "unused.bin")
                                                       :direction :output
                                                       :element-type '(unsigned-byte 8)
                                                       :if-exists :supersede)
                                    (gfx:texture-2d-from-stream device out))))
                 (%note-refusal game :input-stream-to-write
                                (lambda ()
                                  (with-open-file (in png :element-type '(unsigned-byte 8))
                                    (gfx:save-as-png source in 2 2))))
                 (%note-refusal game :closed-stream
                                (lambda ()
                                  (let ((closed (open png :element-type '(unsigned-byte 8))))
                                    (close closed)
                                    (gfx:texture-2d-from-stream device closed)))))
            (xna:dispose source))))
    (error (condition) (setf (stream-failure game) condition))))

(defmacro with-texture-stream-game ((game) &body body)
  `(let ((,game (make-instance 'texture-stream-game :exit-after 2)))
     (unwind-protect
          (progn (xna:run ,game)
                 (is (null (stream-failure ,game))
                     "the fixture failed: ~a" (stream-failure ,game))
                 ,@body)
       (progn
         (dolist (accessor (list #'plain-texture #'resized-texture #'fitted-texture
                                 #'jpeg-decoded-texture))
           (let ((texture (funcall accessor ,game)))
             (when texture (ignore-errors (xna:dispose texture)))))
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (xna:dispose ,game)))))

(define-native-test a-texture-survives-a-png-round-trip-through-two-streams
  "SaveAsPng writes a real PNG to a real file, and FromStream reads it back to
the same four texels. Neither member could pass this by doing nothing: an encoder
that wrote garbage, a decoder that answered a blank texture, or either one
transposing the image, all fail on a two-by-two whose four texels differ."
  (with-texture-stream-game (game)
    (is (plusp (encoded-size game))
        "SaveAsPng wrote ~a bytes" (encoded-size game))
    (let ((back (round-trip-result game)))
      (is (= 4 (length back)))
      (dotimes (index 4)
        (is (xna:color-equal (aref *stream-texels* index) (aref back index))
            "texel ~d came back as ~a rather than ~a"
            index (aref back index) (aref *stream-texels* index))))))

(define-native-test save-as-jpeg-writes-a-second-encoding-of-the-same-texture
  "The JPEG route is the same pair of CNA calls with the other format identity.
No round trip: JPEG is lossy, so equality is the wrong claim -- what is asserted
is that a second, different encoding was produced."
  (with-texture-stream-game (game)
    (is (plusp (jpeg-size game)) "SaveAsJpeg wrote ~a bytes" (jpeg-size game))
    (is (/= (jpeg-size game) (encoded-size game))
        "the PNG and the JPEG were both ~d bytes, which one format producing ~
         both would explain" (jpeg-size game))
    ;; The stronger half: the bytes decode. A route that wrote a plausible
    ;; number of arbitrary bytes would pass the size assertions and fail this.
    (let ((decoded (jpeg-decoded-texture game)))
      (is (typep decoded 'gfx:texture-2d)
          "the JPEG did not decode back into a texture")
      ;; And it refuses to say how big it is, which is the honest answer: the
      ;; extent a decoded texture reports is read from the *image header* on the
      ;; way past, this binding parses PNG headers and not JPEG ones, and CNA
      ;; ABI 0.21.0 reports no texture extent at all. A plausible zero here would
      ;; be a number a caller draws a quad with.
      (signals xna:cna-not-supported-error (gfx:width decoded))
      (signals xna:cna-not-supported-error (gfx:height decoded)))))

(define-native-test from-streams-two-overloads-answer-what-each-can-know
  "The two-argument overload preserves the source dimensions, so the texture can
report them -- read from the image header on the way past, as the decode already
did. The five-argument one covers-and-crops when :ZOOM is true, so the result is
exactly what was asked for; when it is false CNA fits within the request and
answers something no larger, and 0.21.0 reports no texture extent, so WIDTH
refuses rather than answering the request as though it were the result."
  (with-texture-stream-game (game)
    (let ((plain (plain-texture game))
          (zoomed (resized-texture game))
          (fitted (fitted-texture game)))
      (is (= 2 (gfx:width plain)) "the plain decode reported ~a" (gfx:width plain))
      (is (= 2 (gfx:height plain)))
      (is (= 8 (gfx:width zoomed)) "the zoomed decode reported ~a" (gfx:width zoomed))
      (is (= 8 (gfx:height zoomed)))
      (signals xna:cna-not-supported-error (gfx:width fitted))
      (signals xna:cna-not-supported-error (gfx:height fitted)))))

(define-native-test the-stream-members-refuse-what-xna-refuses
  "XNA's checks, in XNA's order, plus the two a Common Lisp stream adds.

A null stream and a stream whose capability is wrong are both argument failures
naming the parameter, which is what the assembly throws. A closed stream is
disposed. A character stream has no counterpart in .NET -- one Stream carries
bytes and text there -- and is refused by name rather than read as something it
is not."
  (with-texture-stream-game (game)
    (flet ((outcome (label) (cdr (assoc label (refusals game)))))
      (is (eq 'xna:cna-argument-error (outcome :partial-overload))
          "one of three keywords gave ~a" (outcome :partial-overload))
      (is (eq 'xna:cna-argument-error (outcome :null-stream))
          "a null stream gave ~a" (outcome :null-stream))
      (is (eq 'xna:cna-argument-error (outcome :character-stream))
          "a character stream gave ~a" (outcome :character-stream))
      (is (eq 'xna:cna-argument-error (outcome :output-stream-to-read))
          "reading an output stream gave ~a" (outcome :output-stream-to-read))
      (is (eq 'xna:cna-argument-error (outcome :input-stream-to-write))
          "writing an input stream gave ~a" (outcome :input-stream-to-write))
      ;; And the one that is *not* a disposal, on either side. A disposed .NET
      ;; Stream answers false from CanRead, so the check XNA reaches first is the
      ;; capability one and what it throws is ArgumentException. Measured: SBCL's
      ;; INPUT-STREAM-P answers NIL for a closed stream too, so the same check
      ;; fires here and the two agree.
      (is (eq 'xna:cna-argument-error (outcome :closed-stream))
          "a closed stream gave ~a" (outcome :closed-stream)))))

(define-native-test a-fitting-decode-scales-in-both-directions
  "**CNA's fit enlarges as readily as it shrinks**, which is not what the word
suggests and is why the two-argument overload does not apply XNA's cap.

XNA's two-argument `FromStream' is the private constructor called with the
profile's MaxTextureSize for both extents -- 2048 for Reach, 4096 for HiDef, read
from the pinned assembly -- and image operation 0. Applying that here would mean
passing those extents to a CNA decode with `zoom' false, and this test is what
says why that would be wrong: a 2x2 source fitted into 8x8 comes back holding
**64** texels, not 4. An 8x8 PNG would come back 2048x2048.

The aspect ratio is preserved while it scales: a 4x2 source fitted into 8x8 comes
back holding 32 texels, which is 8x4 and not 8x8. So `zoom' false is a
scale-to-fit and `zoom' true is a cover-and-crop, exactly as CNA's header says --
the header simply does not say that the scaling goes both ways.

XNA's own fit happens inside a P/Invoke the pinned assembly does not contain, so
whether *it* enlarges is not answerable from the pinned authority. That is the
whole reason this member is partial rather than complete."
  (with-texture-stream-game (game)
    (is (eql 64 (fitted-texel-count game))
        "a 2x2 source fitted into 8x8 held ~a texel(s)" (fitted-texel-count game))
    (is (eql 32 (wide-fitted-texel-count game))
        "a 4x2 source fitted into 8x8 held ~a texel(s), so the aspect ratio was ~
         not preserved" (wide-fitted-texel-count game))))
