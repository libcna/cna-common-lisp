;;;; audio.lisp --- the SoundEffect closure against a real CNA C ABI library.
;;;;
;;;; **Nothing here is a claim that a sound was heard.** What these tests prove
;;;; is that the values a program supplies reach CNA, that CNA accepts them, that
;;;; the state machine transitions where its header says it does, and that the
;;;; ownership graph is the one CNA documents. `docs/qualification.md` names the
;;;; evidence levels; audible correctness is not among them and no assertion below
;;;; implies it.
;;;;
;;;; **The fixtures are generated here, in Lisp, and are silence or a computed
;;;; waveform.** No sample audio of any kind is stored in this repository. Exact
;;;; signed little-endian PCM16, byte for byte, so that every duration and every
;;;; alignment refusal below is arithmetic a reader can redo.
;;;;
;;;; **A game exists for the whole of each test.** XNA's audio API takes no game,
;;;; and CNA's routes need one; the binding resolves the process's one active game
;;;; and these tests create one for it to find. The refusal when there is none is
;;;; tested too, and that one runs with no game at all.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

;;; --- deterministic PCM16 fixtures ------------------------------------------

(defconstant +fixture-sample-rate+ 8000
  "The fixtures' sample rate. 8000 is XNA's own lower bound, so a test that
refuses 7999 is refusing exactly one below a rate that works.")

(defun pcm16-silence (frames &optional (channels :mono))
  "FRAMES frames of PCM16 silence: every byte zero, which is signed zero.

A mono frame is one 16-bit sample and a stereo frame is two, so the byte count is
`frames * channels * 2' -- the same arithmetic XNA's `AudioFormat.BlockAlign'
does and the same the alignment checks below use."
  (make-array (* frames (if (eq channels :stereo) 2 1) 2)
              :element-type '(unsigned-byte 8) :initial-element 0))

(defun pcm16-ramp (frames &optional (channels :mono))
  "FRAMES frames of a deterministic non-zero waveform, signed little-endian.

Sample n is `(n * 1031) mod 65536' reinterpreted as a signed 16-bit value, which
is not audio anybody wrote: it is a full-scale sawtooth whose step is coprime with
65536, so consecutive samples differ and no byte pair repeats within a frame. What
it is *for* is being non-zero and exactly reproducible -- a decoder that dropped
half the buffer would still make silence look right."
  (let* ((per-frame (if (eq channels :stereo) 2 1))
         (samples (* frames per-frame))
         (bytes (make-array (* samples 2) :element-type '(unsigned-byte 8))))
    (dotimes (n samples bytes)
      (let ((v (mod (* n 1031) 65536)))
        (setf (aref bytes (* n 2)) (ldb (byte 8 0) v)
              (aref bytes (1+ (* n 2))) (ldb (byte 8 8) v))))))

(defmacro with-audio-game ((variable) &body body)
  "Run BODY with a live game, so the audio surface has one to resolve.

The game is created and destroyed rather than run: every audio route below takes
an owned or callback-borrowed game handle, and `cna_sound_effect_create_pcm16_
range_ext' documents both, so none of this needs to be inside a lifecycle
callback. Keeping the assertions outside the loop is also what keeps a FiveAM
failure from crossing the callback containment layer."
  `(let ((,variable (make-instance 'xna:game :window-title "cna-lisp audio tests")))
     ;; IGNORABLE rather than a DECLARE at each call site: most of these tests
     ;; need the game to *exist* so the audio surface can resolve it, and never
     ;; name it again.
     (declare (ignorable ,variable))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

(defmacro with-sound-effect ((variable &rest initargs) &body body)
  "Build a SOUND-EFFECT, run BODY, and dispose it however BODY ends."
  `(let ((,variable (make-instance 'audio:sound-effect ,@initargs)))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

;;; --- the capability probe, which is data and not an error -------------------

(define-native-test audio-capability-is-reported-as-data-not-as-a-failure
  "cna_audio_get_capabilities answers CNA_RESULT_SUCCESS whether or not a device
opened, and its header says so. That is what makes an unavailable-audio lane
qualifiable instead of skippable: the report is a value to assert, not an error to
catch. This records what the environment the suite is running in actually says --
it does not require either answer, because requiring one would make the suite
depend on the machine having a sound card."
  (with-audio-game (game)
    (multiple-value-bind (result available) (%probe-audio-capabilities)
      (is (eql 0 result)
          "cna_audio_get_capabilities must succeed whether or not audio is available")
      (is (member available '(t nil))
          "is_playback_available is a boolean either way")
      (format *debug-io* "~&AUDIO_CAPABILITY playback-available=~a~%" available))))

(defun %probe-audio-capabilities ()
  "Answer (values RESULT AVAILABLE-P) from cna_audio_get_capabilities."
  (cffi:with-foreign-object (caps '(:struct ffi::cna-audio-capabilities))
    (cffi:foreign-funcall "memset" :pointer caps :int 0
                          :size ffi::+sizeof-cna-audio-capabilities+ :void)
    (setf (cffi:foreign-slot-value caps '(:struct ffi::cna-audio-capabilities)
                                   'ffi::struct-size)
          ffi::+sizeof-cna-audio-capabilities+
          (cffi:foreign-slot-value caps '(:struct ffi::cna-audio-capabilities)
                                   'ffi::struct-version)
          1)
    (let ((result (ffi::%audio-get-capabilities
                   (int:handle-of (int:active-game)) caps)))
      (values result
              (not (zerop (cffi:foreign-slot-value
                           caps '(:struct ffi::cna-audio-capabilities)
                           'ffi::is-playback-available)))))))

;;; --- the two enumerations agree with CNA, by value --------------------------

(define-native-test audio-enumerations-agree-with-cnas-own-constants
  "The translation is by name through an explicit table, as every enum here is.
This is the check that the table's numbers are still CNA's -- BlendFunction is
why agreement is asserted rather than assumed: XNA numbers Min 3 and Max 4 and
CNA numbers them the other way round, and every other enumeration in this binding
happens to agree, which is exactly how a numeric pass-through survives to the one
place it is wrong."
  (is (eql ffi::+sound-state-playing+ (audio:sound-state-value :playing)))
  (is (eql ffi::+sound-state-paused+  (audio:sound-state-value :paused)))
  (is (eql ffi::+sound-state-stopped+ (audio:sound-state-value :stopped)))
  (is (eql ffi::+audio-channels-mono+   (audio:audio-channels-value :mono)))
  (is (eql ffi::+audio-channels-stereo+ (audio:audio-channels-value :stereo)))
  ;; And XNA's own numbers, from the pinned IL, which is the other authority.
  (is (eql 0 (audio:sound-state-value :playing)))
  (is (eql 1 (audio:sound-state-value :paused)))
  (is (eql 2 (audio:sound-state-value :stopped)))
  (is (eql 1 (audio:audio-channels-value :mono)))
  (is (eql 2 (audio:audio-channels-value :stereo))))

;;; --- the two static sample computations -------------------------------------

(define-native-test sample-duration-and-size-are-exact-and-inverse
  "GetSampleDuration and GetSampleSizeInBytes are pure static computations -- CNA's
routes take no game handle and its header says why. TimeSpan is projected as an
exact 100-nanosecond tick count throughout this binding, so these are integers.

The numbers are arithmetic, not measurements: 8000 bytes of mono PCM16 is 4000
frames, which at 8000 Hz is half a second, which is 5,000,000 ticks."
  (is (eql 5000000 (audio:sound-effect-get-sample-duration 8000 8000 :mono)))
  (is (eql 16000 (audio:sound-effect-get-sample-size-in-bytes 10000000 8000 :mono)))
  ;; Stereo halves the frame count for the same byte count, so it halves the
  ;; duration -- a channel count that was ignored would answer the mono figure.
  (is (eql 2500000 (audio:sound-effect-get-sample-duration 8000 8000 :stereo)))
  ;; And the two are inverse over a whole number of frames.
  (let ((bytes (audio:sound-effect-get-sample-size-in-bytes 5000000 8000 :mono)))
    (is (eql 5000000 (audio:sound-effect-get-sample-duration bytes 8000 :mono)))))

;;; --- construction, and every boundary the IL names ---------------------------

(define-native-test a-sound-effect-is-built-from-pcm16-and-reports-its-duration
  "The short constructor over one second of mono silence at 8000 Hz. One second is
10,000,000 ticks, and the duration comes from CNA rather than from this
arithmetic -- so the two agreeing is the assertion."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-silence 8000)
                               :sample-rate +fixture-sample-rate+ :channels :mono)
      (is (eql 10000000 (audio:duration effect)))
      (is (not (audio:is-disposed effect)))
      (is (string= "" (audio:name effect))
          "XNA initialises Name to String.Empty, and so does CNA"))
    ;; A non-zero waveform of the same shape has the same duration: the duration
    ;; is a function of the byte count and the format, not of the content.
    (with-sound-effect (effect :buffer (pcm16-ramp 8000)
                               :sample-rate +fixture-sample-rate+ :channels :mono)
      (is (eql 10000000 (audio:duration effect))))
    ;; Stereo: the same byte count is half as many frames, so half the duration.
    (with-sound-effect (effect :buffer (pcm16-silence 4000 :stereo)
                               :sample-rate +fixture-sample-rate+ :channels :stereo)
      (is (eql 5000000 (audio:duration effect))))))

(define-native-test the-sound-effect-constructor-refuses-exactly-what-xna-refuses
  "Every check is `SoundEffect.FromBuffer' in the pinned assembly, and the order
matters: which exception a doubly-invalid call gets is decided by the order the
checks run in. Sample rate first, then channels, then the buffer, then the offset,
then the count, then the loop region."
  (with-audio-game (game)
    (flet ((build (&rest initargs)
             (apply #'make-instance 'audio:sound-effect initargs)))
      ;; sampleRate < 8000 or > 48000 -> ArgumentOutOfRangeException("sampleRate")
      (signals xna:cna-argument-out-of-range-error
        (build :buffer (pcm16-silence 100) :sample-rate 7999 :channels :mono))
      (signals xna:cna-argument-out-of-range-error
        (build :buffer (pcm16-silence 100) :sample-rate 48001 :channels :mono))
      ;; and the two bounds themselves are accepted
      (let ((low (build :buffer (pcm16-silence 100) :sample-rate 8000 :channels :mono)))
        (xna:dispose low))
      (let ((high (build :buffer (pcm16-silence 100) :sample-rate 48000 :channels :mono)))
        (xna:dispose high))
      ;; channels outside the enumeration
      (signals xna:cna-argument-out-of-range-error
        (build :buffer (pcm16-silence 100) :sample-rate 8000 :channels :quadraphonic))
      ;; a null, an empty and a misaligned buffer are all ArgumentException
      (signals xna:cna-argument-error
        (build :buffer nil :sample-rate 8000 :channels :mono))
      (signals xna:cna-argument-error
        (build :buffer (make-array 0 :element-type '(unsigned-byte 8))
               :sample-rate 8000 :channels :mono))
      (signals xna:cna-argument-error
        (build :buffer (make-array 3 :element-type '(unsigned-byte 8) :initial-element 0)
               :sample-rate 8000 :channels :mono))
      ;; a stereo frame is four bytes, so a two-byte buffer is aligned for mono
      ;; and misaligned for stereo -- which is the check noticing the format.
      (signals xna:cna-argument-error
        (build :buffer (make-array 2 :element-type '(unsigned-byte 8) :initial-element 0)
               :sample-rate 8000 :channels :stereo))
      ;; offset: negative, past the end, or misaligned
      (let ((buffer (pcm16-silence 100)))
        (signals xna:cna-argument-error
          (build :buffer buffer :offset -2 :count 4 :sample-rate 8000 :channels :mono))
        (signals xna:cna-argument-error
          (build :buffer buffer :offset (length buffer) :count 2
                 :sample-rate 8000 :channels :mono))
        (signals xna:cna-argument-error
          (build :buffer buffer :offset 1 :count 4 :sample-rate 8000 :channels :mono))
        ;; count: zero, negative, misaligned, or running past the end
        (signals xna:cna-argument-error
          (build :buffer buffer :offset 0 :count 0 :sample-rate 8000 :channels :mono))
        (signals xna:cna-argument-error
          (build :buffer buffer :offset 0 :count -2 :sample-rate 8000 :channels :mono))
        (signals xna:cna-argument-error
          (build :buffer buffer :offset 0 :count 3 :sample-rate 8000 :channels :mono))
        (signals xna:cna-argument-error
          (build :buffer buffer :offset 2 :count (length buffer)
                 :sample-rate 8000 :channels :mono))
        ;; offset + count exactly filling the buffer is legal, and is the boundary
        (let ((exact (build :buffer buffer :offset 2 :count (- (length buffer) 2)
                            :sample-rate 8000 :channels :mono)))
          ;; 198 bytes is 99 mono frames, which at 8000 Hz is 12.375 ms and so
          ;; 123750 ticks -- the *range's* duration, not the 200-byte buffer's.
          (is (eql 123750 (audio:duration exact))
              "the range constructor's duration is the range's, not the buffer's")
          (is (eql (audio:sound-effect-get-sample-duration 198 8000 :mono)
                   (audio:duration exact))
              "and it agrees with the static computation over the same byte count")
          (xna:dispose exact))))))

(define-native-test the-loop-region-is-measured-in-frames-and-checked-against-the-range
  "loopStart and loopLength are **sample frames**, not bytes: XNA divides the byte
count by BlockAlign before checking them. So a 100-frame mono range accepts a loop
of 100 and refuses one of 101, and the same range in stereo holds 50 frames and
refuses a loop of 51 -- the same byte count, a different limit."
  (with-audio-game (game)
    (flet ((build (&rest initargs)
             (apply #'make-instance 'audio:sound-effect initargs)))
      (let ((mono (pcm16-ramp 100)))
        ;; the whole range is a legal loop
        (let ((e (build :buffer mono :offset 0 :count (length mono)
                        :sample-rate 8000 :channels :mono
                        :loop-start 0 :loop-length 100)))
          (xna:dispose e))
        ;; one frame past it is not
        (signals xna:cna-argument-error
          (build :buffer mono :offset 0 :count (length mono)
                 :sample-rate 8000 :channels :mono :loop-start 0 :loop-length 101))
        ;; and the sum is what is checked, not either part
        (signals xna:cna-argument-error
          (build :buffer mono :offset 0 :count (length mono)
                 :sample-rate 8000 :channels :mono :loop-start 60 :loop-length 60))
        (signals xna:cna-argument-error
          (build :buffer mono :offset 0 :count (length mono)
                 :sample-rate 8000 :channels :mono :loop-start -1 :loop-length 10))
        (signals xna:cna-argument-error
          (build :buffer mono :offset 0 :count (length mono)
                 :sample-rate 8000 :channels :mono :loop-start 0 :loop-length -1)))
      ;; the same bytes read as stereo hold half as many frames
      (let ((stereo (pcm16-ramp 50 :stereo)))
        (let ((e (build :buffer stereo :offset 0 :count (length stereo)
                        :sample-rate 8000 :channels :stereo
                        :loop-start 0 :loop-length 50)))
          (xna:dispose e))
        (signals xna:cna-argument-error
          (build :buffer stereo :offset 0 :count (length stereo)
                 :sample-rate 8000 :channels :stereo :loop-start 0 :loop-length 51))))))

;;; --- Name round-trips through CNA -------------------------------------------

(define-native-test a-sound-effects-name-round-trips
  "XNA's Name setter is a bare `stfld' and takes any string; CNA stores it and
hands it back. Non-ASCII goes through the same UTF-8 boundary every other name in
this binding uses."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-silence 100)
                               :sample-rate 8000 :channels :mono)
      (is (string= "" (audio:name effect)))
      (setf (audio:name effect) "footstep")
      (is (string= "footstep" (audio:name effect)))
      (setf (audio:name effect) "kroky – přes UTF-8")
      (is (string= "kroky – přes UTF-8" (audio:name effect)))
      (setf (audio:name effect) "")
      (is (string= "" (audio:name effect))))))

;;; --- the instance state machine ---------------------------------------------

(define-native-test the-instance-state-machine-is-the-one-cna-documents
  "Measured rather than assumed, and over a **one-second looped** fixture rather
than a short one-shot: a 20 ms sound can finish between the call and the
observation, and a test that raced would be green for the wrong reason. Looping
means the instance stays PLAYING until something stops it.

    :stopped --play--> :playing --pause--> :paused
             --resume--> :playing --stop--> :stopped"
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-ramp 8000)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        (unwind-protect
             (progn
               (is (eq :stopped (audio:state instance)) "a fresh instance is stopped")
               (is (not (audio:is-looped instance)))
               (setf (audio:is-looped instance) t)
               (is (audio:is-looped instance))
               (audio:play instance)
               (is (eq :playing (audio:state instance)))
               (audio:pause instance)
               (is (eq :paused (audio:state instance)))
               (audio:resume instance)
               (is (eq :playing (audio:state instance)))
               (audio:stop instance)
               (is (eq :stopped (audio:state instance)))
               ;; **Resume does not restart an instance that has already stopped**,
               ;; and this is measured rather than read off CNA's header. That
               ;; header says the route "resumes a paused instance, or starts one
               ;; that has not played"; an instance that played and was then
               ;; stopped is neither of those, and it stays stopped. PLAY is what
               ;; starts it again.
               (audio:resume instance)
               (is (eq :stopped (audio:state instance))
                   "resume does not restart an instance that has already stopped")
               (audio:play instance)
               (is (eq :playing (audio:state instance)))
               (audio:stop instance nil)
               (is (member (audio:state instance) '(:stopped :playing))
                   "a non-immediate stop leaves the loop and may finish naturally"))
          (ignore-errors (xna:dispose instance)))))))

(define-native-test is-looped-is-refused-once-playback-has-begun
  "XNA throws InvalidOperationException(InvalidIsLoopedCall) once its packet has
been submitted, and CNA answers CNA_RESULT_INVALID_STATE 'after playback has
begun'. The two are the same refusal, so the projected condition is the state
error either way -- and it is **not** an INSTANCE-PLAY-LIMIT-ERROR, which is the
distinction the play routes' own error mapping has to preserve."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-ramp 8000)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        (unwind-protect
             (progn
               (setf (audio:is-looped instance) t)
               (audio:play instance)
               (signals xna:cna-invalid-state-error
                 (setf (audio:is-looped instance) nil))
               (handler-case (setf (audio:is-looped instance) nil)
                 (audio:instance-play-limit-error ()
                   (fail "a refused IS-LOOPED must not be reported as a play limit"))
                 (xna:cna-invalid-state-error () t)))
          (ignore-errors (xna:dispose instance)))))))

;;; --- the three bounded setters, and the NaN answers --------------------------

(define-native-test instance-setters-enforce-xnas-bounds-and-not-cnas
  "The bounds are XNA's, and the divergence is real in two of the three: CNA's
volume route is an unclamped pass-through and its pitch route **clamps**, so a
value of 2.0 would be silently accepted as 2.0 and silently clamped to 1.0
respectively. XNA throws for both, so the checks run before the route."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-ramp 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect))
            (nan (int:bits-single-float #x7FC00000)))
        (unwind-protect
             (progn
               (is (= 1.0 (audio:volume instance)))
               (is (= 0.0 (audio:pitch instance)))
               (is (= 0.0 (audio:pan instance)))
               ;; the bounds themselves are accepted
               (setf (audio:volume instance) 0.0) (is (= 0.0 (audio:volume instance)))
               (setf (audio:volume instance) 1.0) (is (= 1.0 (audio:volume instance)))
               (setf (audio:pitch instance) -1.0)  (is (= -1.0 (audio:pitch instance)))
               (setf (audio:pitch instance) 1.0)   (is (= 1.0 (audio:pitch instance)))
               (setf (audio:pan instance) -1.0)    (is (= -1.0 (audio:pan instance)))
               (setf (audio:pan instance) 1.0)     (is (= 1.0 (audio:pan instance)))
               ;; and everything outside them is refused, NaN included
               (signals xna:cna-argument-out-of-range-error (setf (audio:volume instance) -0.1))
               (signals xna:cna-argument-out-of-range-error (setf (audio:volume instance) 2.0))
               (signals xna:cna-argument-out-of-range-error (setf (audio:volume instance) nan))
               (signals xna:cna-argument-out-of-range-error (setf (audio:pitch instance) 2.0))
               (signals xna:cna-argument-out-of-range-error (setf (audio:pitch instance) -2.0))
               (signals xna:cna-argument-out-of-range-error (setf (audio:pitch instance) nan))
               (signals xna:cna-argument-out-of-range-error (setf (audio:pan instance) 1.5))
               (signals xna:cna-argument-out-of-range-error (setf (audio:pan instance) nan)))
          (ignore-errors (xna:dispose instance)))))))

;;; --- the four process-wide statics ------------------------------------------

(define-native-test the-static-audio-properties-are-xnas-defaults-and-xnas-guards
  "XNA's static initialiser writes 343.5, 1, 1 and 1, and CNA's own defaults are
the same four numbers -- measured, not assumed, because a CNA that changed one
would change this binding's public API silently.

The NaN answers are the part worth pinning: three of the four compare with an
unordered branch and refuse a NaN, and **DistanceScale alone stores one**, because
its guard is `bge.un' and the clamp that follows is ordered. Four properties, three
NaN refusals and one NaN store, all read from the IL."
  (with-audio-game (game)
    (let ((nan (int:bits-single-float #x7FC00000)))
      ;; the defaults, which are XNA's and CNA's alike
      (is (= 1.0 (audio:sound-effect-master-volume)))
      (is (= 1.0 (audio:sound-effect-distance-scale)))
      (is (= 1.0 (audio:sound-effect-doppler-scale)))
      (is (= 343.5 (audio:sound-effect-speed-of-sound)))
      (unwind-protect
           (progn
             ;; MasterVolume: [0, 1], NaN refused
             (setf (audio:sound-effect-master-volume) 0.5)
             (is (= 0.5 (audio:sound-effect-master-volume)))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-master-volume) -0.1))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-master-volume) 1.1))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-master-volume) nan))
             ;; DopplerScale: [0, inf), NaN refused, zero accepted
             (setf (audio:sound-effect-doppler-scale) 0.0)
             (is (= 0.0 (audio:sound-effect-doppler-scale)))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-doppler-scale) -1.0))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-doppler-scale) nan))
             ;; SpeedOfSound: strictly positive, NaN refused, zero refused
             (setf (audio:sound-effect-speed-of-sound) 300.0)
             (is (= 300.0 (audio:sound-effect-speed-of-sound)))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-speed-of-sound) 0.0))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-speed-of-sound) -1.0))
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-speed-of-sound) nan))
             ;; DistanceScale: negatives refused, zero raised to float.Epsilon,
             ;; and a NaN **stored** -- the one of the four that does.
             (signals xna:cna-argument-out-of-range-error
               (setf (audio:sound-effect-distance-scale) -1.0))
             (setf (audio:sound-effect-distance-scale) 0.0)
             (is (= least-positive-single-float (audio:sound-effect-distance-scale))
                 "a zero distance scale is raised to float.Epsilon, not refused")
             (setf (audio:sound-effect-distance-scale) nan)
             (is (int:nan-p (audio:sound-effect-distance-scale))
                 "DistanceScale stores a NaN; the other three refuse one"))
        ;; Process-wide state, so it is put back however this test ends.
        (progn (ignore-errors (setf (audio:sound-effect-master-volume) 1.0))
               (ignore-errors (setf (audio:sound-effect-distance-scale) 1.0))
               (ignore-errors (setf (audio:sound-effect-doppler-scale) 1.0))
               (ignore-errors (setf (audio:sound-effect-speed-of-sound) 343.5)))))))

(define-native-test the-static-audio-properties-survive-one-game-and-the-next
  "XNA's four are `static' fields and CNA's routes are process-wide -- its header
calls them 'canonical statics: they belong to the process, not to a sound effect,
and the game handle is taken for thread affinity only'. So a value set through one
game is still there when a second game reads it. Measured, because the alternative
-- a value that resets per game -- would be a divergence worth documenting, and it
is not what happens."
  (unwind-protect
       (progn
         (with-audio-game (first)
           (setf (audio:sound-effect-speed-of-sound) 300.0)
           (is (= 300.0 (audio:sound-effect-speed-of-sound))))
         (with-audio-game (second)
           (is (= 300.0 (audio:sound-effect-speed-of-sound))
               "the value belongs to the process, not to the game it was set through")))
    (with-audio-game (restore)
      (ignore-errors (setf (audio:sound-effect-speed-of-sound) 343.5)))))

(define-native-test audio-refuses-cleanly-when-no-game-is-active
  "The one projection limit this closure has, and it is refused rather than
crashed: XNA's audio API is process-global and CNA reaches audio through the
active game, so with no game there is no handle to use. The condition names what
is missing. This test creates no game on purpose."
  (is (null (int:active-game)) "this test needs no active game, and asserts there is none")
  (signals xna:cna-invalid-state-error (audio:sound-effect-master-volume))
  (signals xna:cna-invalid-state-error
    (make-instance 'audio:sound-effect :buffer (pcm16-silence 100)
                                       :sample-rate 8000 :channels :mono))
  ;; The two pure static computations need no game and still answer.
  (is (eql 5000000 (audio:sound-effect-get-sample-duration 8000 8000 :mono))))

;;; --- AudioListener and AudioEmitter -----------------------------------------

(define-native-test spatial-defaults-are-xnas-and-cna-agrees-with-them
  "The classes initialise to the pinned IL's defaults so that they can be built
with no native library at all. This is the other half: CNA's own `_init' routes
write the same nine values, so the two authorities have not drifted apart."
  (let ((listener (make-instance 'audio:audio-listener))
        (emitter (make-instance 'audio:audio-emitter)))
    ;; XNA's, from the IL.
    (is (xna:vector3-equal (xna:vector3-zero) (audio:position listener)))
    (is (xna:vector3-equal (xna:vector3-zero) (audio:velocity listener)))
    (is (xna:vector3-equal (xna:vector3-forward) (audio:forward listener)))
    (is (xna:vector3-equal (xna:vector3-up) (audio:up listener)))
    (is (xna:vector3-equal (xna:vector3-zero) (audio:position emitter)))
    (is (xna:vector3-equal (xna:vector3-zero) (audio:velocity emitter)))
    (is (xna:vector3-equal (xna:vector3-forward) (audio:forward emitter)))
    (is (xna:vector3-equal (xna:vector3-up) (audio:up emitter)))
    (is (= 1.0 (audio:doppler-scale emitter))))
  ;; CNA's, from the routes.
  (multiple-value-bind (position velocity forward up) (%cna-listener-defaults)
    (is (xna:vector3-equal (xna:vector3-zero) position))
    (is (xna:vector3-equal (xna:vector3-zero) velocity))
    (is (xna:vector3-equal (xna:vector3-forward) forward))
    (is (xna:vector3-equal (xna:vector3-up) up)))
  (multiple-value-bind (position velocity forward up doppler) (%cna-emitter-defaults)
    (is (xna:vector3-equal (xna:vector3-zero) position))
    (is (xna:vector3-equal (xna:vector3-zero) velocity))
    (is (xna:vector3-equal (xna:vector3-forward) forward))
    (is (xna:vector3-equal (xna:vector3-up) up))
    (is (= 1.0 doppler))))

(defun %read-cna-vector3 (raw type slot)
  (let ((p (cffi:foreign-slot-pointer raw type slot)))
    (xna:make-vector3 (cffi:mem-aref p :float 0)
                      (cffi:mem-aref p :float 1)
                      (cffi:mem-aref p :float 2))))

(defun %cna-listener-defaults ()
  (cffi:with-foreign-object (raw '(:struct ffi::cna-audio-listener))
    (cffi:foreign-funcall "memset" :pointer raw :int 0
                          :size ffi::+sizeof-cna-audio-listener+ :void)
    (int:check-result (ffi::%audio-listener-init raw) "cna_audio_listener_init")
    (let ((type '(:struct ffi::cna-audio-listener)))
      (values (%read-cna-vector3 raw type 'ffi::position)
              (%read-cna-vector3 raw type 'ffi::velocity)
              (%read-cna-vector3 raw type 'ffi::forward)
              (%read-cna-vector3 raw type 'ffi::up)))))

(defun %cna-emitter-defaults ()
  (cffi:with-foreign-object (raw '(:struct ffi::cna-audio-emitter))
    (cffi:foreign-funcall "memset" :pointer raw :int 0
                          :size ffi::+sizeof-cna-audio-emitter+ :void)
    (int:check-result (ffi::%audio-emitter-init raw) "cna_audio_emitter_init")
    (let ((type '(:struct ffi::cna-audio-emitter)))
      (values (%read-cna-vector3 raw type 'ffi::position)
              (%read-cna-vector3 raw type 'ffi::velocity)
              (%read-cna-vector3 raw type 'ffi::forward)
              (%read-cna-vector3 raw type 'ffi::up)
              (cffi:foreign-slot-value raw type 'ffi::doppler-scale)))))

(define-native-test spatial-properties-store-what-they-are-given
  "XNA's eight vector setters are bare `stfld' after a handedness flip that its
getters undo, so the public value round-trips exactly -- NaN and infinity
included. The flip is not reproduced here because it is not observable; this is
the test that says so."
  (let ((listener (make-instance 'audio:audio-listener))
        (emitter (make-instance 'audio:audio-emitter))
        (v (xna:make-vector3 1.5 -2.5 3.5)))
    (setf (audio:position listener) v)
    (is (xna:vector3-equal v (audio:position listener))
        "the Z component comes back as it went in, not negated")
    (setf (audio:velocity emitter) v)
    (is (xna:vector3-equal v (audio:velocity emitter)))
    ;; a NaN component is stored, because XNA's setters do not look at the value
    (let ((nan-vector (xna:make-vector3 0.0 0.0 (int:bits-single-float #x7FC00000))))
      (setf (audio:forward listener) nan-vector)
      (is (int:nan-p (xna:vector3-z (audio:forward listener)))))))

(define-native-test the-emitter-doppler-scale-refuses-a-negative-and-stores-a-nan
  "The per-emitter DopplerScale and the process-wide SoundEffect.DopplerScale have
the same name and the same range and **opposite NaN answers**: this one's guard is
`bge.un', which accepts a NaN, and the static one's is `blt.un', which throws. Both
are read from the IL and both are pinned, because a reader who checked one would
reasonably assume the other."
  (let ((emitter (make-instance 'audio:audio-emitter))
        (nan (int:bits-single-float #x7FC00000)))
    (is (= 1.0 (audio:doppler-scale emitter)))
    (setf (audio:doppler-scale emitter) 0.0)
    (is (= 0.0 (audio:doppler-scale emitter)))
    (setf (audio:doppler-scale emitter) 2.5)
    (is (= 2.5 (audio:doppler-scale emitter)))
    (signals xna:cna-argument-out-of-range-error
      (setf (audio:doppler-scale emitter) -0.1))
    (setf (audio:doppler-scale emitter) nan)
    (is (int:nan-p (audio:doppler-scale emitter))
        "the per-emitter scale stores a NaN; the process-wide one refuses it")))

;;; --- Apply3D -----------------------------------------------------------------

(define-native-test apply-3d-submits-both-overloads-and-refuses-an-empty-array
  "**This proves submission, not perception.** A successful call means the values
reached CNA and the route accepted them; where a human would hear the sound is not
something this or any test here establishes.

Both overloads are exercised because they are two CLOS methods over two different
CNA routes, and an empty sequence is refused rather than guessed at."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-ramp 8000)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect))
            (listener (make-instance 'audio:audio-listener))
            (emitter (make-instance 'audio:audio-emitter)))
        (unwind-protect
             (progn
               (setf (audio:position emitter) (xna:make-vector3 3.0 0.0 0.0))
               ;; the single-listener method
               (audio:apply-3d instance listener emitter)
               ;; the sequence method, with one and with several
               (audio:apply-3d instance (list listener) emitter)
               (audio:apply-3d instance (vector listener listener) emitter)
               ;; an empty sequence is a condition, not a guess
               (signals xna:cna-argument-error
                 (audio:apply-3d instance '() emitter))
               (signals xna:cna-argument-error
                 (audio:apply-3d instance (vector) emitter))
               ;; aim, then play: the order CNA requires
               (setf (audio:is-looped instance) t)
               (audio:play instance)
               (is (eq :playing (audio:state instance)))
               ;; a positioned instance keeps accepting the route while it plays
               (audio:apply-3d instance listener emitter)
               (audio:stop instance))
          (ignore-errors (xna:dispose instance)))))))

(define-native-test pan-is-refused-on-an-instance-that-has-played-and-been-positioned
  "XNA's Pan setter throws InvalidOperationException once `is3d' is set, and
`is3d' is only cleared for an instance that has **never played** -- traced through
the IL, `isPacketSubmitted' is set on the first Play and cleared only when the
voice is deallocated, which nothing but Dispose does. So a Stop does not make Pan
legal again, which is the part a state-based guess gets wrong.

CNA's behaviour is the quiet version of the same rule -- its header says a
positioned instance's pan 'stops reaching the output' -- and silently doing
nothing is worse than refusing, so XNA wins."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-ramp 8000)
                               :sample-rate 8000 :channels :mono)
      ;; First instance: aim it, pan it while it has never played -- which
      ;; discards the aim on both sides -- and then find that playing it makes
      ;; APPLY-3D refuse, because it is now playing and unpositioned.
      (let ((instance (audio:create-instance effect))
            (listener (make-instance 'audio:audio-listener))
            (emitter (make-instance 'audio:audio-emitter)))
        (unwind-protect
             (progn
               (audio:apply-3d instance listener emitter)
               (setf (audio:pan instance) 0.5)
               (is (= 0.5 (audio:pan instance))
                   "an instance that never played may still be panned after being aimed")
               (setf (audio:is-looped instance) t)
               (audio:play instance)
               ;; CNA agrees with XNA here: the pan cleared the 3D flag, so this
               ;; instance is playing and was never positioned, and the route says
               ;; so rather than quietly doing nothing.
               (signals xna:cna-invalid-state-error
                 (audio:apply-3d instance listener emitter))
               (audio:stop instance))
          (ignore-errors (xna:dispose instance))))
      ;; Second instance: aim it, play it, and keep aiming it -- which is the
      ;; order CNA asks for -- and then find Pan refused for the rest of its life.
      (let ((instance (audio:create-instance effect))
            (listener (make-instance 'audio:audio-listener))
            (emitter (make-instance 'audio:audio-emitter)))
        (unwind-protect
             (progn
               (setf (audio:is-looped instance) t)
               (audio:apply-3d instance listener emitter)
               (audio:play instance)
               (is (eq :playing (audio:state instance)))
               (audio:apply-3d instance listener emitter)
               (signals xna:cna-invalid-state-error (setf (audio:pan instance) 0.25))
               ;; and a Stop does not bring it back: `isPacketSubmitted' is cleared
               ;; only when the voice is deallocated, which nothing but Dispose does
               (audio:stop instance)
               (signals xna:cna-invalid-state-error (setf (audio:pan instance) 0.25)))
          (ignore-errors (xna:dispose instance)))))))

;;; --- where CNA and XNA disagree, and XNA wins --------------------------------

(define-native-test cnas-sample-duration-route-truncates-and-xnas-arithmetic-does-not
  "**A measured divergence, pinned on both sides.** XNA's `GetSampleDuration' is
`AudioFormat.DurationFromSize': integer-divide the byte count by the block align,
multiply by 1000 and divide by the sample rate in binary32, and hand the result to
`TimeSpan.FromMilliseconds', which rounds. 200 bytes of mono PCM16 at 8000 Hz is
100 frames, 12.5 ms, and exactly 125000 ticks.

`cna_sound_effect_get_sample_duration_ticks' answers **120000** for the same
arguments -- 12 ms, truncated. So this binding computes the value itself, as it
does for every other pure computation, and this test asserts both answers. A CNA
that fixed its route would fail here rather than passing silently, which is the
same treatment `DepthStencilState''s stencil masks get.

The effect's own duration route is **not** affected: `cna_sound_effect_get_
duration_ticks' agrees with XNA to the tick, which is why the divergence is
described as this one computation's and not as CNA's audio generally."
  (with-audio-game (game)
    ;; XNA's answer, which is this binding's.
    (is (eql 125000 (audio:sound-effect-get-sample-duration 200 8000 :mono)))
    ;; CNA's answer, read directly from the route, which is not.
    (cffi:with-foreign-object (ticks :int64)
      (int:check-result
       (ffi::%sound-effect-get-sample-duration-ticks 200 8000 1 ticks)
       "cna_sound_effect_get_sample_duration_ticks")
      (is (eql 120000 (cffi:mem-ref ticks :int64))
          "CNA truncates this computation to whole milliseconds; XNA rounds ticks"))
    ;; Where the byte count is a whole number of milliseconds the two agree, which
    ;; is why the divergence went unnoticed in the first probe.
    (is (eql 5000000 (audio:sound-effect-get-sample-duration 8000 8000 :mono)))
    (cffi:with-foreign-object (ticks :int64)
      (int:check-result
       (ffi::%sound-effect-get-sample-duration-ticks 8000 8000 1 ticks)
       "cna_sound_effect_get_sample_duration_ticks")
      (is (eql 5000000 (cffi:mem-ref ticks :int64))))
    ;; And the effect's own duration, which is the route that does agree.
    (with-sound-effect (effect :buffer (pcm16-silence 100)
                               :sample-rate 8000 :channels :mono)
      (is (eql 125000 (audio:duration effect))
          "cna_sound_effect_get_duration_ticks agrees with XNA to the tick"))))
;;; --- Play, and the two conditions the audio surface owns ---------------------

(define-native-test sound-effect-play-answers-a-boolean-and-checks-its-pan
  "SoundEffect.Play() is Play(1.0f, 0.0f, 0.0f) in XNA's own IL, and both answer
whether playback started. The asymmetry in the three-argument form is XNA's and
CNA's alike: **pan is range-checked and pitch is not**."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-ramp 800)
                               :sample-rate 8000 :channels :mono)
      (is (member (audio:play effect) '(t nil))
          "Play answers whether playback started")
      (is (member (audio:play effect :volume 1.0 :pitch 0.0 :pan 0.0) '(t nil)))
      ;; pan is range-checked
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume 1.0 :pitch 0.0 :pan 2.0))
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume 1.0 :pitch 0.0 :pan -2.0))
      ;; pitch outside [-1, 1] is *not* refused by Play, unlike the instance
      ;; setter: XNA clamps here and throws there, and both are reproduced.
      (is (member (audio:play effect :volume 1.0 :pitch 5.0 :pan 0.0) '(t nil))
          "Play clamps pitch rather than refusing it, unlike the instance setter"))))

(define-native-test a-disposed-sound-effect-refuses-rather-than-answering-false
  "CNA's `cna_sound_effect_play' documents 'a disposed effect answers CNA_FALSE
rather than failing, which is the canonical behavior'. **It is not**:
SoundEffect.Play opens with an IsDisposed test and throws ObjectDisposedException.
This binding's disposal check runs first, so the public behaviour is XNA's and
CNA's CNA_FALSE branch is never reached from here. Recorded in
docs/limitations.md as a place CNA's header is wrong about XNA."
  (with-audio-game (game)
    (let ((effect (make-instance 'audio:sound-effect :buffer (pcm16-silence 100)
                                                     :sample-rate 8000 :channels :mono)))
      (xna:dispose effect)
      (is (audio:is-disposed effect))
      (signals xna:cna-disposed-error (audio:play effect))
      (signals xna:cna-disposed-error (audio:name effect))
      (signals xna:cna-disposed-error (audio:create-instance effect))
      ;; **Duration is the exception, and XNA is why.** Its getter is a bare
      ;; `ldfld' over a field the constructor filled in -- no IsDisposed test, no
      ;; native call -- so a disposed SoundEffect still answers its duration
      ;; there. It does here too, for the same reason: the value was read once at
      ;; construction and lives in a slot. Adding a disposal guard would refuse a
      ;; program XNA runs.
      (is (eql 125000 (audio:duration effect))
          "Duration is readable after disposal, because XNA's getter is a bare field read"))))

(define-native-test the-two-audio-conditions-are-distinguishable-from-each-other
  "Three failures have to stay three: no audio hardware, an instance play limit,
and a generic CNA failure. The first two are XNA-visible exception types and are
projected as conditions that subclass the exact CNA result-code condition that
produces them, so a program can handle either the XNA-specific class or the CNA
one and both work.

The hierarchy is what is asserted here; `tools/qualification/audio.sh' produces a
real NO-AUDIO-HARDWARE-ERROR from a process with no audio driver, which is the
other half."
  (is (subtypep 'audio:no-audio-hardware-error 'xna:cna-not-supported-error))
  (is (subtypep 'audio:no-audio-hardware-error 'xna:cna-native-error))
  (is (subtypep 'audio:instance-play-limit-error 'xna:cna-invalid-state-error))
  (is (subtypep 'audio:instance-play-limit-error 'xna:cna-native-error))
  ;; and neither is the other, nor is a generic native failure either of them
  (is (not (subtypep 'audio:no-audio-hardware-error 'audio:instance-play-limit-error)))
  (is (not (subtypep 'audio:instance-play-limit-error 'audio:no-audio-hardware-error)))
  (is (not (subtypep 'xna:cna-internal-error 'audio:no-audio-hardware-error)))
  (is (not (subtypep 'xna:cna-internal-error 'audio:instance-play-limit-error))))

;;; --- ownership ---------------------------------------------------------------

(define-native-test the-audio-ownership-graph-is-game-effect-instance
  "CNA's own words: an instance is 'an explicitly ordered C child: destroy it
before its sound effect. It also remains a child of the game that owns the
effect.' So the order is instance, then effect, then game -- and the binding
refuses a wrong order before the ABI does, naming both types."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        ;; the effect will not go while its instance lives
        (signals xna:cna-ownership-error (xna:dispose effect))
        ;; nor will the game, while either lives
        (signals xna:cna-ownership-error (xna:dispose game))
        (xna:dispose instance)
        ;; and now the effect will
        (xna:dispose effect)
        (is (audio:is-disposed effect))))))

(define-native-test disposing-an-instance-twice-destroys-its-handle-once
  "Disposal is idempotent at the Lisp level and must not reach CNA twice: a second
destroy on a released handle is exactly the double-free the ownership machinery
exists to prevent."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        (xna:dispose instance)
        (is (audio:is-disposed instance))
        ;; a second dispose is a no-op, not a native call
        (xna:dispose instance)
        (is (audio:is-disposed instance))
        ;; and the effect is disposable, so nothing is still holding it
        (xna:dispose effect)
        (is (audio:is-disposed effect))))))

(define-native-test many-instances-of-one-effect-all-go-back
  "The registry has to return to its baseline: an effect with several live
instances releases every one of them, and the game then shuts down cleanly. A
handle left behind would make the game's own disposal fail, which is the symptom
this catches."
  (with-audio-game (game)
    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instances (loop repeat 8 collect (audio:create-instance effect))))
        (is (= 8 (length instances)))
        (signals xna:cna-ownership-error (xna:dispose effect))
        (dolist (instance instances) (xna:dispose instance))
        (xna:dispose effect)
        (is (audio:is-disposed effect))))
    ;; The game is disposed by WITH-AUDIO-GAME; that it can be is the assertion.
    (xna:dispose game)
    (is (xna:disposed-p game))))
