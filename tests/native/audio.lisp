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
;;;;
;;;; **Every test that needs a playback device branches on whether one opened, and
;;;; both branches assert.** This is the rasterizer lane's rule applied to audio,
;;;; and for the same reason: a lane that cannot fail for the right reason proves
;;;; nothing. `cna_audio_get_capabilities' reports `is_playback_available' as
;;;; *data* -- it answers `CNA_RESULT_SUCCESS` either way and its header says so --
;;;; so the branch is a measurement rather than a guess.
;;;;
;;;;   playback available    the full behaviour is asserted
;;;;   playback unavailable  **AUDIO_UNAVAILABLE**: creating an effect must fail
;;;;                         with exactly NO-AUDIO-HARDWARE-ERROR, and does
;;;;
;;;; Neither branch is a skip. A GitHub runner has no sound card and takes the
;;;; second branch; a developer's machine takes the first. The runner prints which
;;;; one ran, because a summary that did not say so would let the unavailable
;;;; branch be read as though the available one had passed.

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
       (%tear-down-audio-game ,variable))))

(defun %tear-down-audio-game (game)
  "Dispose GAME, and **say so loudly** if it cannot be disposed.

A game that will not go leaves CNA holding the process's one active game, and
every later test then fails to create one with \"Only one C-owned CNA game may be
active at a time\". A silent `IGNORE-ERRORS' here turned one unbound variable in
one test into fifty-four unrelated failures, with nothing in the output pointing
at the cause. So the refusal is printed, and the game is invalidated anyway so the
next test can still start."
  (handler-case (xna:dispose game)
    (error (condition)
      (format *debug-io*
              "~&;; AUDIO FIXTURE: the game could not be disposed -- ~a: ~a~%~
               ;; Disposing its live children and retrying, so one test cannot ~
               cascade into every later one.~%"
              (type-of condition) condition)
      ;; **Invalidating the Lisp object is not a recovery**: CNA would still hold
      ;; the process's one native game and every later `make-instance' would fail
      ;; with "Only one C-owned CNA game may be active at a time". The children
      ;; are what block the disposal, so they are what have to go -- newest first,
      ;; which is leaf-first, and then the game itself.
      (dolist (child (copy-list (int:children-of game)))
        (ignore-errors (xna:dispose child)))
      (handler-case (xna:dispose game)
        (error (again)
          (format *debug-io*
                  "~&;; AUDIO FIXTURE: it still would not go -- ~a: ~a~%"
                  (type-of again) again))))))

(defmacro with-sound-effect ((variable &rest initargs) &body body)
  "Build a SOUND-EFFECT, run BODY, and dispose it however BODY ends."
  `(let ((,variable (make-instance 'audio:sound-effect ,@initargs)))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

(defvar *audio-evidence* '()
  "What the audio tests actually proved, newest first: a list of (LEVEL . DESCRIPTION).

  :structural   reached with no device and no game -- enumerations, arithmetic,
                the condition hierarchy, the listener and emitter defaults
  :unavailable  a device could not be opened, and creating a SoundEffect failed
                with exactly NO-AUDIO-HARDWARE-ERROR
  :state-machine a device opened and the play/pause/resume/stop transitions were
                observed on it
  :dynamic-unavailable  a device could not be opened and the **streaming**
                constructor succeeded anyway -- CNA's create route needs no device
                where SoundEffect's does -- with the refusal arriving at Play
  :dynamic-streaming  generated PCM16 was submitted to a
                DynamicSoundEffectInstance and the native streaming state machine
                consumed it -- the pending-buffer count rose and then fell while
                the game loop ran

Kept apart for the reason the rasterization kinds are: proving the unavailable
branch says nothing about the state machine, proving the state machine says
nothing about the buffer queue, and a summary that collapsed them would let one
be read as another. **None of them is a claim that a sound was heard**, and the
streaming one least of all: `dummy device != speaker', and the strongest thing
it supports is that generated PCM was accepted and consumed by the native
streaming state machine.")

(defun note-audio (level description &rest arguments)
  "Record LEVEL once. Sixteen tests take the unavailable branch and they are all
the same evidence; the summary says what was proved, not how many tests proved it."
  (unless (assoc level *audio-evidence*)
    (push (cons level (apply #'format nil description arguments)) *audio-evidence*)))

(defun audio-proved-p (level)
  (assoc level *audio-evidence*))

(defun audio-playback-available-p ()
  "Whether CNA could open a playback device, measured through the active game.

Answers NIL when the capability call itself fails, which is not the same thing --
but the caller treats both as \"no device\", and the capability test asserts the
call succeeds separately so a failing probe cannot hide here."
  (multiple-value-bind (result available) (%probe-audio-capabilities)
    (and (eql 0 result) available)))

(defun %assert-no-audio-hardware ()
  "The AUDIO_UNAVAILABLE assertion: building a valid effect fails, and with the
XNA-visible condition rather than a generic native failure.

This is a **positive qualification of the unavailable branch**, not a skip. The
effect it tries to build is the one every available-branch test starts from, so
the two branches are testing the same operation."
  (signals audio:no-audio-hardware-error
    (make-instance 'audio:sound-effect :buffer (pcm16-silence 8000)
                                       :sample-rate +fixture-sample-rate+
                                       :channels :mono))
  ;; and it is not merely *some* refusal: a generic native failure would be a
  ;; different condition, and the hierarchy test pins that they are different.
  (handler-case
      (make-instance 'audio:sound-effect :buffer (pcm16-silence 8000)
                                         :sample-rate +fixture-sample-rate+
                                         :channels :mono)
    (audio:no-audio-hardware-error ()
      (note-audio :unavailable
                  "no playback device opened, and SoundEffect creation failed with ~
                   NO-AUDIO-HARDWARE-ERROR -- CNA_RESULT_NOT_SUPPORTED, which its ~
                   header documents as the machine having no audio hardware")
      t)
    (error (condition)
      (fail "expected NO-AUDIO-HARDWARE-ERROR with no device, got ~a" (type-of condition))))
  ;; **The streaming constructor is the asymmetry, and it is measured here rather
  ;; than assumed.** `cna_sound_effect_create_pcm16_range_ext' needs a device and
  ;; answers CNA_RESULT_NOT_SUPPORTED without one;
  ;; `cna_dynamic_sound_effect_instance_create' does **not** -- it answers
  ;; CNA_RESULT_SUCCESS and a usable handle on a machine with no playback device,
  ;; and buffers can be submitted to it. The refusal appears at PLAY.
  ;;
  ;; XNA's own answer is not establishable: its constructor calls AllocateVoice,
  ;; which calls CreateDynamicSoundEffectInstance, whose body is native code
  ;; inside the mixed-mode assembly rather than IL. What the IL does establish is
  ;; that XACT result 0x8ac70017 becomes NoAudioHardwareException, so the shape of
  ;; the failure is XNA's even where the trigger is unknown. The member is
  ;; recorded partial for that reason; docs/limitations.md has it.
  (let ((instance (make-instance 'audio:dynamic-sound-effect-instance
                                 :sample-rate +fixture-sample-rate+ :channels :mono)))
    (unwind-protect
         (progn
           (is (not (audio:is-disposed instance))
               "CNA's streaming constructor needs no playback device")
           (is (= 0 (audio:pending-buffer-count instance)))
           (audio:submit-buffer instance (pcm16-silence 400))
           (is (= 1 (audio:pending-buffer-count instance))
               "and it takes buffers without one")
           (signals audio:no-audio-hardware-error (audio:play instance)))
      (xna:dispose instance)))
  ;; The argument checks still run *first*, because they are before the route in
  ;; the IL: a machine with no sound card must not turn a wrong argument into a
  ;; hardware report.
  (signals xna:cna-argument-out-of-range-error
    (make-instance 'audio:dynamic-sound-effect-instance
                   :sample-rate 10 :channels :mono))
  ;; A level of its own, because NOTE-AUDIO records each one once and this is a
  ;; different claim from the SoundEffect one above: the two constructors do not
  ;; behave the same way without a device, and a summary that folded them together
  ;; would report the stronger of the two.
  (note-audio :dynamic-unavailable
              "DynamicSoundEffectInstance's constructor **succeeded** with no ~
               playback device and took a buffer, which is CNA's asymmetry rather ~
               than XNA's; the refusal arrives at PLAY, as NO-AUDIO-HARDWARE-ERROR. ~
               Its argument checks ran first either way"))

(defmacro define-audio-device-test (name docstring &body body)
  "Define a test that needs a playback device, and say what happened when there is none.

BODY runs with a live game bound to GAME and a device that opened. With no device,
BODY does not run and the unavailable branch is asserted instead -- which is a
result, not a skip, and is what a GitHub runner produces.

GAME is bound to that name deliberately rather than to a gensym: two of these
tests dispose it on purpose, to prove the ownership order refuses them."
  `(define-native-test ,name ,docstring
     (with-audio-game (game)
       (if (audio-playback-available-p)
           (progn ,@body)
           (%assert-no-audio-hardware)))))

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
    (is (eql 5000000 (audio:sound-effect-get-sample-duration bytes 8000 :mono))))
  (note-audio :structural
              "the enumerations, the sample arithmetic and the condition hierarchy ~
               were checked with no playback device and no game -- none of them ~
               needs one"))

;;; --- construction, and every boundary the IL names ---------------------------

(define-audio-device-test a-sound-effect-is-built-from-pcm16-and-reports-its-duration
  "The short constructor over one second of mono silence at 8000 Hz. One second is
10,000,000 ticks, and the duration comes from CNA rather than from this
arithmetic -- so the two agreeing is the assertion."

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
      (is (eql 5000000 (audio:duration effect)))))

(define-audio-device-test the-sound-effect-constructor-refuses-exactly-what-xna-refuses
  "Every check is `SoundEffect.FromBuffer' in the pinned assembly, and the order
matters: which exception a doubly-invalid call gets is decided by the order the
checks run in. Sample rate first, then channels, then the buffer, then the offset,
then the count, then the loop region."

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
      ;; The range checks all need the seven-argument constructor, whose keyword
      ;; set is complete: :OFFSET and :COUNT without the loop region is not one
      ;; of XNA's two shapes, and is refused before any of these run.
      (let ((buffer (pcm16-silence 100)))
        (flet ((range (&rest overrides)
                 ;; Overrides first: an initarg supplied twice takes its *first*
                 ;; value, so the defaults have to come second to be defaults.
                 (apply #'build (append overrides
                                        (list :buffer buffer :offset 0 :count 4
                                              :sample-rate 8000 :channels :mono
                                              :loop-start 0 :loop-length 0)))))
          ;; offset: negative, past the end, or misaligned
          (signals xna:cna-argument-error (range :offset -2))
          (signals xna:cna-argument-error (range :offset (length buffer) :count 2))
          (signals xna:cna-argument-error (range :offset 1))
          ;; count: zero, negative, misaligned, or running past the end
          (signals xna:cna-argument-error (range :count 0))
          (signals xna:cna-argument-error (range :count -2))
          (signals xna:cna-argument-error (range :count 3))
          (signals xna:cna-argument-error (range :offset 2 :count (length buffer)))
          ;; offset + count exactly filling the buffer is legal, and is the boundary
          (let ((exact (range :offset 2 :count (- (length buffer) 2))))
            ;; 198 bytes is 99 mono frames, which at 8000 Hz is 12.375 ms --
            ;; and TimeSpan.FromMilliseconds truncates 12.875 to 12, so 120000
            ;; ticks. The *range's* duration, not the 200-byte buffer's.
            (is (eql 120000 (audio:duration exact))
                "the range constructor's duration is the range's, not the buffer's")
            (is (eql (audio:sound-effect-get-sample-duration 198 8000 :mono)
                     (audio:duration exact))
                "and it agrees with the static computation over the same byte count")
            (xna:dispose exact))))))

(define-audio-device-test the-loop-region-is-measured-in-frames-and-checked-against-the-range
  "loopStart and loopLength are **sample frames**, not bytes: XNA divides the byte
count by BlockAlign before checking them. So a 100-frame mono range accepts a loop
of 100 and refuses one of 101, and the same range in stereo holds 50 frames and
refuses a loop of 51 -- the same byte count, a different limit."

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
                 :sample-rate 8000 :channels :stereo :loop-start 0 :loop-length 51)))))

;;; --- Name round-trips through CNA -------------------------------------------

(define-audio-device-test a-sound-effects-name-round-trips
  "XNA's Name setter is a bare `stfld' and takes any string; CNA stores it and
hands it back. Non-ASCII goes through the same UTF-8 boundary every other name in
this binding uses."

    (with-sound-effect (effect :buffer (pcm16-silence 100)
                               :sample-rate 8000 :channels :mono)
      (is (string= "" (audio:name effect)))
      (setf (audio:name effect) "footstep")
      (is (string= "footstep" (audio:name effect)))
      (setf (audio:name effect) "kroky – přes UTF-8")
      (is (string= "kroky – přes UTF-8" (audio:name effect)))
      (setf (audio:name effect) "")
      (is (string= "" (audio:name effect)))))

;;; --- the instance state machine ---------------------------------------------

(define-audio-device-test the-instance-state-machine-is-the-one-cna-documents
  "Measured rather than assumed, and over a **one-second looped** fixture rather
than a short one-shot: a 20 ms sound can finish between the call and the
observation, and a test that raced would be green for the wrong reason. Looping
means the instance stays PLAYING until something stops it.

    :stopped --play--> :playing --pause--> :paused
             --resume--> :playing --stop--> :stopped"

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
                   "a non-immediate stop leaves the loop and may finish naturally")
               (note-audio :state-machine
                           "a playback device opened, and a looped one-second effect ~
                            went stopped -> playing -> paused -> playing -> stopped ~
                            through Play, Pause, Resume and Stop. Nothing here is a ~
                            claim that a sound was heard"))
          (ignore-errors (xna:dispose instance))))))

(define-audio-device-test is-looped-is-refused-once-playback-has-begun
  "XNA throws InvalidOperationException(InvalidIsLoopedCall) once its packet has
been submitted, and CNA answers CNA_RESULT_INVALID_STATE 'after playback has
begun'. The two are the same refusal, so the projected condition is the state
error either way -- and it is **not** an INSTANCE-PLAY-LIMIT-ERROR, which is the
distinction the play routes' own error mapping has to preserve."

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
          (ignore-errors (xna:dispose instance))))))

;;; --- the three bounded setters, and the NaN answers --------------------------

(define-audio-device-test instance-setters-enforce-xnas-bounds-and-not-cnas
  "The bounds are XNA's, and the divergence is real in two of the three: CNA's
volume route is an unclamped pass-through and its pitch route **clamps**, so a
value of 2.0 would be silently accepted as 2.0 and silently clamped to 1.0
respectively. XNA throws for both, so the checks run before the route."

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
          (ignore-errors (xna:dispose instance))))))

;;; --- the four process-wide statics ------------------------------------------

(define-audio-device-test the-static-audio-properties-are-xnas-defaults-and-xnas-guards
  "XNA's static initialiser writes 343.5, 1, 1 and 1, and CNA's own defaults are
the same four numbers -- measured, not assumed, because a CNA that changed one
would change this binding's public API silently.

The NaN answers are the part worth pinning: three of the four compare with an
unordered branch and refuse a NaN, and **DistanceScale alone stores one**, because
its guard is `bge.un' and the clamp that follows is ordered. Four properties, three
NaN refusals and one NaN store, all read from the IL."

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
               (ignore-errors (setf (audio:sound-effect-speed-of-sound) 343.5))))))

(define-native-test the-static-audio-properties-survive-one-game-and-the-next
  "XNA's four are `static' fields and CNA's routes are process-wide -- its header
calls them 'canonical statics: they belong to the process, not to a sound effect,
and the game handle is taken for thread affinity only'. So a value set through one
game is still there when a second game reads it. Measured, because the alternative
-- a value that resets per game -- would be a divergence worth documenting, and it
is not what happens."
  (let ((available (with-audio-game (probe) (audio-playback-available-p))))
    (if (not available)
        ;; **Three of the four statics still work with no device, and one does
        ;; not.** Measured rather than assumed: `DistanceScale', `DopplerScale'
        ;; and `SpeedOfSound' are 3D parameters CNA keeps in process state and
        ;; answers without opening anything, while `MasterVolume' reaches the
        ;; mixer and so answers NOT_SUPPORTED -- which this binding maps to
        ;; NO-AUDIO-HARDWARE-ERROR, as XNA's own error-code mapping does. So the
        ;; unavailable branch asserts both halves rather than a blanket refusal.
        (with-audio-game (none)
          (signals audio:no-audio-hardware-error (audio:sound-effect-master-volume))
          (signals audio:no-audio-hardware-error
            (setf (audio:sound-effect-master-volume) 0.5))
          (is (= 343.5 (audio:sound-effect-speed-of-sound))
              "SpeedOfSound is process state and answers with no device")
          (unwind-protect
               (progn (setf (audio:sound-effect-speed-of-sound) 300.0)
                      (is (= 300.0 (audio:sound-effect-speed-of-sound))
                          "and it round-trips with no device too"))
            (ignore-errors (setf (audio:sound-effect-speed-of-sound) 343.5))))
        (unwind-protect
             (progn
               (with-audio-game (first)
                 (setf (audio:sound-effect-speed-of-sound) 300.0)
                 (is (= 300.0 (audio:sound-effect-speed-of-sound))))
               (with-audio-game (second)
                 (is (= 300.0 (audio:sound-effect-speed-of-sound))
                     "the value belongs to the process, not to the game it was set through")))
          (with-audio-game (restore)
            (ignore-errors (setf (audio:sound-effect-speed-of-sound) 343.5)))))))

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

(define-audio-device-test apply-3d-submits-both-overloads-and-refuses-an-empty-array
  "**This proves submission, not perception.** A successful call means the values
reached CNA and the route accepted them; where a human would hear the sound is not
something this or any test here establishes.

Both overloads are exercised because they are two CLOS methods over two different
CNA routes, and an empty sequence is refused rather than guessed at."

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
          (ignore-errors (xna:dispose instance))))))

(define-audio-device-test pan-is-refused-on-an-instance-that-has-played-and-been-positioned
  "XNA's Pan setter throws InvalidOperationException once `is3d' is set, and
`is3d' is only cleared for an instance that has **never played** -- traced through
the IL, `isPacketSubmitted' is set on the first Play and cleared only when the
voice is deallocated, which nothing but Dispose does. So a Stop does not make Pan
legal again, which is the part a state-based guess gets wrong.

CNA's behaviour is the quiet version of the same rule -- its header says a
positioned instance's pan 'stops reaching the output' -- and silently doing
nothing is worse than refusing, so XNA wins."

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
          (ignore-errors (xna:dispose instance))))))

;;; --- where CNA and XNA disagree, and XNA wins --------------------------------

(define-audio-device-test xna-quantises-a-duration-to-whole-milliseconds-and-cna-does-not
  "**Two measured divergences, pinned on both sides, and both were misread once.**

XNA's `GetSampleDuration' is `AudioFormat.DurationFromSize': integer-divide the
byte count by the block align, multiply by 1000 and divide by the sample rate in
binary32, and hand the result to `TimeSpan.FromMilliseconds'. What that last step
does is the part this test exists for. It is `TimeSpan.Interval(v, 1)' in the
pinned mscorlib:

    millis = v + (v >= 0 ? 0.5 : -0.5)
    ticks  = (long)millis * 10000

-- the half is added to the **millisecond** count and the truncation applies to
*that*, before the multiplication. So the answer is always a whole number of
milliseconds, rounded half away from zero, and 12.5 ms is **130000** ticks.

This binding used to compute `(long)(v * 10000 + 0.5)' and answer 125000, and the
comment beside it called that 'the exact 12.5 ms the buffer holds'. It is the
exact 12.5 ms, and it is not what `TimeSpan.FromMilliseconds' returns.

  1. `cna_sound_effect_get_sample_duration_ticks' answers **120000** -- 12 ms,
     truncated rather than rounded.
  2. `cna_sound_effect_get_duration_ticks', the effect's own, answers **125000**
     -- the exact tick count, not quantised at all. This one was previously
     recorded as agreeing with XNA to the tick; it agreed with the *old*
     arithmetic, which was wrong, and it does not agree with XNA.

So all three differ, and the binding computes the value itself wherever it knows
the format -- which is both constructors and FromStream. A CNA that changed
either route fails here rather than passing silently, the same treatment
`DepthStencilState''s stencil masks get."

    ;; XNA's answer, which is this binding's.
    (is (eql 130000 (audio:sound-effect-get-sample-duration 200 8000 :mono))
        "TimeSpan.FromMilliseconds rounds 12.5 ms up to 13 whole milliseconds")
    ;; CNA's static route, which truncates to whole milliseconds.
    (cffi:with-foreign-object (ticks :int64)
      (int:check-result
       (ffi::%sound-effect-get-sample-duration-ticks 200 8000 1 ticks)
       "cna_sound_effect_get_sample_duration_ticks")
      (is (eql 120000 (cffi:mem-ref ticks :int64))
          "CNA truncates this computation to whole milliseconds; XNA rounds"))
    ;; Where the byte count is a whole number of milliseconds all three agree,
    ;; which is why the divergence survived the first probe.
    (is (eql 5000000 (audio:sound-effect-get-sample-duration 8000 8000 :mono)))
    (cffi:with-foreign-object (ticks :int64)
      (int:check-result
       (ffi::%sound-effect-get-sample-duration-ticks 8000 8000 1 ticks)
       "cna_sound_effect_get_sample_duration_ticks")
      (is (eql 5000000 (cffi:mem-ref ticks :int64))))
    ;; And the effect's own duration: computed, because CNA's route does not
    ;; quantise and XNA does.
    (with-sound-effect (effect :buffer (pcm16-silence 100)
                               :sample-rate 8000 :channels :mono)
      (is (eql 130000 (audio:duration effect))
          "Duration is XNA's DurationFromSize, which the constructor knows the format for")
      (cffi:with-foreign-object (ticks :int64)
        (int:check-result
         (ffi::%sound-effect-get-duration-ticks (int:handle-of effect) ticks)
         "cna_sound_effect_get_duration_ticks")
        (is (eql 125000 (cffi:mem-ref ticks :int64))
            "CNA's own route answers the exact tick count, which XNA never does")))
    ;; A stereo case where the exact count is not a whole millisecond either.
    (with-sound-effect (effect :buffer (pcm16-silence 1000 :stereo)
                               :sample-rate 22050 :channels :stereo)
      (is (eql 450000 (audio:duration effect))
          "1000 frames at 22050 Hz is 45.35 ms, which XNA rounds to 45")))

;;; --- Play, and the two conditions the audio surface owns ---------------------

(define-audio-device-test sound-effect-play-validates-all-three-settings
  "SoundEffect.Play's numeric rules, read from the pinned IL rather than from CNA.

**`Play(float, float, float)' validates nothing itself.** Its body takes a
SoundEffectInstance from the pool and calls `set_Volume', `set_Pitch' and
`set_Pan' on it in that order, then `Play()'. So its rules are exactly those three
setters' -- volume in [0, 1], pitch in [-1, 1], pan in [-1, 1], each comparing
with `blt.un'/`bgt.un' so a NaN takes the throwing branch -- and its *order* is
theirs too.

This previously checked pan alone and documented pitch as clamped. That was CNA's
behaviour: `cna_sound_effect_play_with_settings' clamps a pitch it is given, which
is precisely why the range has to be enforced here or nowhere. Volume was not
checked at all.

`Play()' is `Play(1.0f, 0.0f, 0.0f)' in the same IL, so the no-argument form is
inside every range by construction."

    (with-sound-effect (effect :buffer (pcm16-ramp 800)
                               :sample-rate 8000 :channels :mono)
      (is (member (audio:play effect) '(t nil))
          "Play answers whether playback started")
      (is (member (audio:play effect :volume 1.0 :pitch 0.0 :pan 0.0) '(t nil)))
      ;; the closed ends of each range are inside it
      (is (member (audio:play effect :volume 0.0 :pitch -1.0 :pan -1.0) '(t nil)))
      (is (member (audio:play effect :volume 1.0 :pitch 1.0 :pan 1.0) '(t nil)))
      ;; volume: [0, 1]
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume -0.001 :pitch 0.0 :pan 0.0))
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume 1.001 :pitch 0.0 :pan 0.0))
      ;; pitch: [-1, 1] -- refused, not clamped
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume 1.0 :pitch 5.0 :pan 0.0))
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume 1.0 :pitch -5.0 :pan 0.0))
      ;; pan: [-1, 1]
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume 1.0 :pitch 0.0 :pan 2.0))
      (signals xna:cna-argument-out-of-range-error
        (audio:play effect :volume 1.0 :pitch 0.0 :pan -2.0))
      ;; a NaN in any of the three, because all three comparisons are unordered
      (let ((nan (int:bits-single-float #x7FC00000)))
        (signals xna:cna-argument-out-of-range-error
          (audio:play effect :volume nan :pitch 0.0 :pan 0.0))
        (signals xna:cna-argument-out-of-range-error
          (audio:play effect :volume 1.0 :pitch nan :pan 0.0))
        (signals xna:cna-argument-out-of-range-error
          (audio:play effect :volume 1.0 :pitch 0.0 :pan nan)))
      ;; and the order is set_Volume, set_Pitch, set_Pan: a call wrong in two of
      ;; them names the first, which is the observable consequence of the order.
      (is (equal "volume"
                 (handler-case (audio:play effect :volume 9.0 :pitch 9.0 :pan 9.0)
                   (xna:cna-argument-out-of-range-error (c)
                     (xna:cna-error-parameter-name c))))
          "a call wrong in volume and pitch reports volume, as set_Volume runs first")
      (is (equal "pitch"
                 (handler-case (audio:play effect :volume 1.0 :pitch 9.0 :pan 9.0)
                   (xna:cna-argument-out-of-range-error (c)
                     (xna:cna-error-parameter-name c))))
          "and one wrong in pitch and pan reports pitch")))

(define-audio-device-test a-disposed-sound-effect-refuses-rather-than-answering-false
  "CNA's `cna_sound_effect_play' documents 'a disposed effect answers CNA_FALSE
rather than failing, which is the canonical behavior'. **It is not**:
SoundEffect.Play opens with an IsDisposed test and throws ObjectDisposedException.
This binding's disposal check runs first, so the public behaviour is XNA's and
CNA's CNA_FALSE branch is never reached from here. Recorded in
docs/limitations.md as a place CNA's header is wrong about XNA."

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
      (is (eql 130000 (audio:duration effect))
          "Duration is readable after disposal, because XNA's getter is a bare field read")))

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

(define-audio-device-test the-audio-ownership-graph-is-game-effect-instance
  "CNA's own words: an instance is 'an explicitly ordered C child: destroy it
before its sound effect. It also remains a child of the game that owns the
effect.' So the order is instance, then effect, then game.

**The effect disposes its instances rather than refusing, and that is XNA's
behaviour rather than a convenience.** `SoundEffect.Dispose(bool)' in the pinned
assembly snapshots its `children' list and calls `Dispose()' on every live
instance in it before releasing its own handle. Reproducing that satisfies CNA's
child-before-parent rule rather than fighting it: each voice is deallocated first
and the effect's handle last. The *game* still refuses, because nothing in XNA
makes a game dispose a SoundEffect it did not create -- so the two directions of
the graph are deliberately not the same, and this pins both."

    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        ;; the game will not go while either lives, and does not cascade
        (signals xna:cna-ownership-error (xna:dispose game))
        ;; the effect *does* go, and takes its instance with it
        (xna:dispose effect)
        (is (audio:is-disposed effect))
        (is (audio:is-disposed instance)
            "SoundEffect.Dispose disposes its live instances, as the pinned IL does")
        (is (null (int:children-of effect))
            "and unregisters them, so nothing is left for CNA to destroy twice"))))

(define-audio-device-test a-cascaded-instance-behaves-as-a-disposed-one
  "What 'invalidated' means observably, read from the two Dispose bodies.

`SoundEffectInstance.Dispose(bool)' sets `disposed', tells its effect through
`ChildDestroyed', and deallocates its voice. So after the parent's cascade the
instance is disposed in exactly the sense a directly disposed one is, and every
member that opens with an `IsDisposed' test throws `ObjectDisposedException' --
`State', the transport, `Apply3D' and the three settings' setters.

**The four settings are the exception, and the IL is why**: `get_Volume',
`get_Pitch', `get_Pan' and `get_IsLooped' are each a seven-byte `ldfld' with no
disposal test, so they answer the last value stored. They are managed slots here
for that reason and this test is where the difference is visible -- it used to
assert the opposite, that all four refused, and called that a divergence in its
own comment while the compatibility report went on calling the members complete.

Disposing the instance again afterwards is legal and does nothing, because
`Dispose(bool)' returns early when `IsDisposed' is already true."

    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        (setf (audio:volume instance) 0.25
              (audio:pitch instance) -0.5
              (audio:pan instance) 0.75
              (audio:is-looped instance) t)
        (xna:dispose effect)
        (is (audio:is-disposed instance))
        ;; the four bare field reads keep answering, exactly as XNA's do
        (is (= 0.25 (audio:volume instance)))
        (is (= -0.5 (audio:pitch instance)))
        (is (= 0.75 (audio:pan instance)))
        (is (audio:is-looped instance))
        ;; every member that XNA guards with IsDisposed
        (signals xna:cna-disposed-error (audio:state instance))
        (signals xna:cna-disposed-error (audio:play instance))
        (signals xna:cna-disposed-error (audio:pause instance))
        (signals xna:cna-disposed-error (audio:resume instance))
        (signals xna:cna-disposed-error (audio:stop instance))
        (signals xna:cna-disposed-error (setf (audio:volume instance) 0.5))
        (signals xna:cna-disposed-error (setf (audio:pitch instance) 0.0))
        (signals xna:cna-disposed-error (setf (audio:pan instance) 0.0))
        (signals xna:cna-disposed-error (setf (audio:is-looped instance) t))
        ;; and disposing it again is a no-op rather than a second native destroy
        (xna:dispose instance)
        (is (audio:is-disposed instance)))))

(define-audio-device-test the-four-settings-are-managed-fields-that-cna-agrees-with

  "The other half of the managed-slot decision, and the half that could go wrong
quietly.

Answering a disposed instance is only correct if the answer was correct while it
was alive, so this reads both sides: the public getter, and
`cna_sound_effect_instance_get_info' through the private macro. They must agree
on a fresh instance -- at XNA's constructor defaults, 1, 0, 0 and false -- and
after each setter.

**APPLY-3D is where they are allowed to part, and only there.** XNA's
`UnsafeApply3D' stores `is3d' and `listenerData' and nothing else; CNA's mixer
recomputes pan and pitch from the emitter's position and reports those through
`get_info'. So after a positioning the public `PAN' must still be the value the
caller assigned. This asserts that it is, and does not assert what CNA's number
became -- that is the mixer's business and pinning it would be pinning CNA's
spatial arithmetic to this test."

    (with-sound-effect (effect :buffer (pcm16-silence 8000)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        (unwind-protect
             (flet ((native ()
                      (audio::%with-instance-info (info instance "test")
                        (list (info cna-lisp.internal.ffi::volume)
                              (info cna-lisp.internal.ffi::pitch)
                              (info cna-lisp.internal.ffi::pan)
                              (not (zerop (info cna-lisp.internal.ffi::is-looped)))))))
               ;; XNA's constructor sets currentVolume to 1 and then calls
               ;; set_Volume(1), set_Pitch(0), set_Pan(0) and stores looped false.
               ;; The slots start there; CNA's fresh instance has to agree, or the
               ;; defaults would be this binding's invention rather than XNA's.
               (is (equal (list 1.0 0.0 0.0 nil)
                          (multiple-value-list
                           (audio::%instance-managed-settings instance)))
                   "a fresh instance is at XNA's four constructor defaults")
               (is (equal (list 1.0 0.0 0.0 nil) (native))
                   "and CNA's own info agrees with them")
               (setf (audio:volume instance) 0.5)
               (setf (audio:pitch instance) 0.25)
               (setf (audio:pan instance) -0.75)
               (setf (audio:is-looped instance) t)
               (is (equal (list 0.5 0.25 -0.75 t)
                          (multiple-value-list
                           (audio::%instance-managed-settings instance))))
               (is (equal (list 0.5 0.25 -0.75 t) (native))
                   "every setter reached CNA as well as the slot")
               ;; A refused set leaves the old value readable, because XNA's
               ;; `stfld' is after its native call and after the rethrow.
               (signals xna:cna-argument-out-of-range-error
                 (setf (audio:volume instance) 2.0))
               (is (= 0.5 (audio:volume instance))
                   "a refused setter does not disturb the value")
               ;; And the one place the two are allowed to disagree.
               (audio:apply-3d instance
                               (make-instance 'audio:audio-listener)
                               (let ((emitter (make-instance 'audio:audio-emitter)))
                                 (setf (audio:position emitter)
                                       (xna:make-vector3 10.0 0.0 0.0))
                                 emitter))
               (is (= -0.75 (audio:pan instance))
                   "Apply3D does not write currentPan, so PAN is still the assignment")
               (is (= 0.5 (audio:volume instance)))
               (is (= 0.25 (audio:pitch instance))))
          (ignore-errors (xna:dispose instance))))))

(define-audio-device-test disposing-an-instance-twice-destroys-its-handle-once
  "Disposal is idempotent at the Lisp level and must not reach CNA twice: a second
destroy on a released handle is exactly the double-free the ownership machinery
exists to prevent."

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
        (is (audio:is-disposed effect)))))

(define-audio-device-test many-instances-of-one-effect-all-go-back
  "The registry has to return to its baseline: an effect with several live
instances releases every one of them, and the game then shuts down cleanly. A
handle left behind would make the game's own disposal fail, which is the symptom
this catches."

    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instances (loop repeat 8 collect (audio:create-instance effect))))
        (is (= 8 (length instances)))
        ;; Seven disposed by hand and one left live, so the cascade has real work
        ;; to do and the seven already-disposed children are not destroyed twice.
        (dolist (instance (rest instances)) (xna:dispose instance))
        (xna:dispose effect)
        (is (audio:is-disposed effect))
        (is (every #'audio:is-disposed instances)
            "the cascade disposed the one that was still live, and left the rest alone")))
    ;; The game is disposed by WITH-AUDIO-GAME; that it can be is the assertion.
    (xna:dispose game)
    (is (xna:disposed-p game)))

(define-condition sound-instance-destroy-refused (error)
  ((label :initarg :label :reader sound-instance-destroy-refused-label))
  (:report (lambda (condition stream)
             (format stream "the ~a instance reported a failed destroy"
                     (sound-instance-destroy-refused-label condition))))
  (:documentation "The injected failure the cascade test needs.

A *deterministic* one, which a real backend cannot be made to produce on demand:
`cna_sound_effect_instance_destroy' documents only `CNA_RESULT_SUCCESS' and
handle, thread and native failures, and none of those can be arranged from a
test without corrupting something the rest of the suite shares."))

(defclass refusing-sound-effect-instance (audio:sound-effect-instance)
  ((label :initarg :label :reader refusing-instance-label))
  (:documentation "A SOUND-EFFECT-INSTANCE whose native destruction reports a failure.

**It releases the handle first and then signals**, which is what makes this an
injection of a *reported* failure rather than a leak: CNA is left holding
nothing, so the rest of the suite is unaffected, while the binding sees exactly
what it would see if the route had answered a failure code."))

(defmethod int:destroy-native ((instance refusing-sound-effect-instance))
  (call-next-method)
  (error 'sound-instance-destroy-refused :label (refusing-instance-label instance)))

(define-audio-device-test a-cascade-attempts-every-child-after-one-refuses
  "One instance failing to release must not leave every later instance alive.

That property was this cascade's own documented claim and its `DOLIST' was
refuting it: the first signalled condition left the loop, and every instance
after the failing one stayed live. The policy is now stated where the code is,
and it is this:

  * every live instance is attempted, in the recorded child-before-parent order;
  * the **first** condition is kept and no later one replaces it;
  * a failure re-signals from DISPOSE-OWNED-CHILDREN, which runs *before*
    DISPOSE's own UNWIND-PROTECT, so the effect is left undisposed;
  * a retry then releases it, because the children are gone.

Children are recorded newest-first, so an effect given A, B, C cascades over
C, B, A -- and two of the three refuse, which is what proves the *first* one is
the one the caller is told about."

    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let* ((first-made (make-instance 'refusing-sound-effect-instance
                                        :sound-effect effect :label :first-made))
             (middle (audio:create-instance effect))
             (last-made (make-instance 'refusing-sound-effect-instance
                                       :sound-effect effect :label :last-made)))
        (is (= 3 (length (xna::%live-owned-children effect))))
        (let ((condition (handler-case (progn (xna:dispose effect) nil)
                           (sound-instance-destroy-refused (c) c))))
          (is (typep condition 'sound-instance-destroy-refused)
              "the caller is told that a child refused")
          ;; LAST-MADE is disposed first, so its failure is the first failure and
          ;; FIRST-MADE's -- which happens later -- must not replace it.
          (is (eq :last-made (sound-instance-destroy-refused-label condition))
              "the first failure reaches the caller, not the last")
          ;; All three were attempted: the one before the first failure, the one
          ;; between the two failures, and the one after both.
          (is (audio:is-disposed last-made) "the failing child was attempted")
          (is (audio:is-disposed middle)
              "a child after the first failure was still attempted")
          (is (audio:is-disposed first-made)
              "and so was the child after the second failure")
          ;; The Lisp registry is coherent: a child whose destroy reported a
          ;; failure is still invalidated, because DISPOSE invalidates through an
          ;; UNWIND-PROTECT, so nothing is left pointing at a released handle.
          (is (null (xna::%live-owned-children effect)))
          (is (null (audio::%sound-effect-instances effect)))
          ;; The conservative half of the policy: the parent is *not* disposed.
          (is (not (audio:is-disposed effect))
              "a reported child failure leaves the effect undisposed, so a retry can \
release it")
          ;; And the retry does, because the children are gone.
          (xna:dispose effect)
          (is (audio:is-disposed effect) "the retry released the effect"))))
    ;; Teardown is still recoverable, which is the property the whole policy is
    ;; for: a game that cannot be disposed poisons every later test.
    (xna:dispose game)
    (is (xna:disposed-p game)))

;;; --- DynamicSoundEffectInstance ----------------------------------------------
;;;
;;; **Streaming, qualified with no speaker and no recording.** Every buffer below
;;; is PCM16 this file computes, and the only thing any assertion claims is that
;;; the bytes were accepted, that the queue depth moved the way CNA's header says
;;; it moves, and that the buffer-needed event reached Lisp. A dummy audio device
;;; is not audible hardware and nothing here says a sound was heard.
;;;
;;; The queue is advanced by the **game loop**: CNA's header says
;;; `cna_framework_dispatcher_update' drives every live streaming instance, so
;;; these tests run frames rather than sleeping, and they poll with a bound rather
;;; than asserting a frame count.

(defun dynamic-pcm (frames &optional (channels :mono))
  "FRAMES sample frames of a computed PCM16 sawtooth, as bytes.

The same shape PCM16-RAMP produces for SoundEffect, generated here rather than
reused so the two closures' fixtures cannot drift into each other."
  (let* ((per-frame (if (eq channels :stereo) 2 1))
         (bytes (make-array (* 2 per-frame frames) :element-type '(unsigned-byte 8)))
         (i 0))
    (dotimes (frame frames bytes)
      (dotimes (channel per-frame)
        (let ((sample (- (mod (+ (* frame 137) (* channel 4099)) 65536) 32768)))
          (setf (aref bytes i) (ldb (byte 8 0) sample)
                (aref bytes (1+ i)) (ldb (byte 8 8) (ldb (byte 16 0) sample))
                i (+ i 2)))))))

(defmacro with-dynamic-instance ((variable &rest initargs) &body body)
  `(let ((,variable (make-instance 'audio:dynamic-sound-effect-instance ,@initargs)))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

(defun %run-frames-until (game predicate &key (limit 600))
  "Run frames until PREDICATE answers true, or LIMIT frames have run.

Bounded polling rather than a frame count, because buffer consumption is
playback: how many frames half a second of audio takes depends on the frame rate
and on nothing this test controls. Answers how many frames it took, or NIL."
  (loop for frame from 0 below limit
        when (funcall predicate) return frame
        do (xna:run-one-frame game)
        finally (return (when (funcall predicate) frame))))

(define-audio-device-test the-dynamic-constructor-validates-exactly-what-xna-validates
  "DynamicSoundEffectInstance(int sampleRate, AudioChannels channels), from the IL.

    base()                                     -- the parameterless SoundEffectInstance ctor
    sampleRate < 0x1f40 || > 0xbb80  -> ArgumentOutOfRangeException(\"sampleRate\")
    channels   < 1      || > 2       -> ArgumentOutOfRangeException(\"channels\")
    format = AudioFormat.Create(sampleRate, channels, 16)
    AllocateVoice()                            -- the native handle, last

The order is observable and is asserted: a call wrong in both is told about the
**sample rate**, because that test comes first. The bounds are 8000 and 48000,
the same pair the SoundEffect constructors use.

The keyword shape is the other half. XNA has one public constructor and no other,
so :SAMPLE-RATE alone and :CHANNELS alone name no member and are refused rather
than defaulted -- the mistake %CHECK-OVERLOAD-KEYWORDS exists for."

    (progn
      (signals xna:cna-argument-out-of-range-error
        (make-instance 'audio:dynamic-sound-effect-instance
                       :sample-rate 7999 :channels :mono))
      (signals xna:cna-argument-out-of-range-error
        (make-instance 'audio:dynamic-sound-effect-instance
                       :sample-rate 48001 :channels :mono))
      (signals xna:cna-argument-out-of-range-error
        (make-instance 'audio:dynamic-sound-effect-instance
                       :sample-rate 8000 :channels :quadraphonic))
      ;; The order: wrong in both, and the parameter named is the sample rate.
      (handler-case (progn (make-instance 'audio:dynamic-sound-effect-instance
                                          :sample-rate 1 :channels :quadraphonic)
                           (fail "a doubly-wrong constructor was accepted"))
        (xna:cna-argument-out-of-range-error (condition)
          (is (string= "sample-rate" (xna:cna-error-parameter-name condition))
              "sampleRate is checked before channels, so it is the one named")))
      ;; Both keywords or neither is not a shape: there is no other overload.
      (signals xna:cna-usage-error
        (make-instance 'audio:dynamic-sound-effect-instance :sample-rate 8000))
      (signals xna:cna-usage-error
        (make-instance 'audio:dynamic-sound-effect-instance :channels :mono))
      (signals xna:cna-usage-error
        (make-instance 'audio:dynamic-sound-effect-instance))
      ;; And both bounds inclusive, which is what `blt'/`bgt' rather than
      ;; `ble'/`bge' means.
      (with-dynamic-instance (low :sample-rate 8000 :channels :mono)
        (is (not (audio:is-disposed low))))
      (with-dynamic-instance (high :sample-rate 48000 :channels :stereo)
        (is (not (audio:is-disposed high))))))

(define-audio-device-test a-dynamic-instance-does-not-run-the-ordinary-constructor
  "The architectural assertion, and the one a `(defclass d (sound-effect-instance))'
would have failed.

The base class's construction used to be hard-wired to the ordinary kind: require
`:SOUND-EFFECT', call `cna_sound_effect_create_instance', make the effect the
owner, push onto its instance list. That method runs for a subclass too, so a
`DynamicSoundEffectInstance' defined over it would have executed the wrong
constructor -- and XNA's does not: its `.ctor(int, AudioChannels)' calls the
**parameterless** `SoundEffectInstance.ctor()', which stores nothing and
allocates nothing, and then its own overridden `AllocateVoice'.

What is asserted is the observable consequence of the right one having run:

  * the instance has **no** parent SoundEffect, and the private slot is NIL
    rather than unbound -- XNA's `effect' field is null for this class too, and
    its `Dispose(bool)' reads it and skips `ChildDestroyed';
  * the game owns it directly, so the graph is Game -> DynamicSoundEffectInstance
    with nothing between;
  * a SoundEffect that exists alongside it is not its parent and does not list it
    among its instances, so the ordinary path was not taken by another name."

    (with-sound-effect (effect :buffer (pcm16-silence 800)
                               :sample-rate 8000 :channels :mono)
      (let ((ordinary (audio:create-instance effect)))
        (with-dynamic-instance (dynamic :sample-rate 8000 :channels :mono)
          ;; the ordinary kind: parent effect, and on the effect's own list
          (is (eq effect (audio::%instance-sound-effect ordinary)))
          (is (member ordinary (audio::%sound-effect-instances effect)))
          (is (member ordinary (int:children-of effect)))
          ;; the dynamic kind: no effect at all, and a child of the game
          (is (null (audio::%instance-sound-effect dynamic))
              "a DynamicSoundEffectInstance has no parent SoundEffect")
          (is (not (member dynamic (audio::%sound-effect-instances effect)))
              "and is not on any effect's instance list")
          (is (not (member dynamic (int:children-of effect)))
              "and is not a child of any effect")
          (is (eq game (int:owner-of dynamic))
              "the game owns it directly")
          (is (member dynamic (int:children-of game)))
          ;; It is a SOUND-EFFECT-INSTANCE all the same, which is what makes the
          ;; inherited surface legitimate rather than accidental.
          (is (typep dynamic 'audio:sound-effect-instance)))
        (xna:dispose ordinary))))

(define-audio-device-test dynamic-destruction-uses-the-ordinary-instance-route
  "There is no dynamic destroy route in either admitted ABI, and that is not an
omission.

`cna_dynamic_sound_effect_instance_create' says what its handle is: \"The handle
is a **sound-effect instance**: every `cna_sound_effect_instance_*' route accepts
it, including the transport, the mixing setters and
`cna_sound_effect_instance_destroy'.\" So the destruction hook's base method is
the one this class uses, and the evidence is the header rather than the fact that
CLOS would inherit it.

What is asserted is that disposal works, that it is idempotent, that the handle
goes back exactly once -- a second native destroy on a released handle is the
double free the ownership machinery exists to prevent -- and that the game can
then shut down, which it cannot do while a child handle lives."

    (let ((before (length (int:children-of game))))
      (let ((dynamic (make-instance 'audio:dynamic-sound-effect-instance
                                    :sample-rate 8000 :channels :mono)))
        (is (= (1+ before) (length (int:children-of game))))
        (xna:dispose dynamic)
        (is (audio:is-disposed dynamic))
        (is (= before (length (int:children-of game))))
        ;; idempotent, and not a second native call
        (xna:dispose dynamic)
        (is (audio:is-disposed dynamic))))
    (xna:dispose game)
    (is (xna:disposed-p game)))

(define-audio-device-test the-dynamic-state-machine-is-the-inherited-one-where-xna-says-so
  "**Inheritance is not evidence.** CLOS gives this class every method
SOUND-EFFECT-INSTANCE has, and the pinned metadata decides which of them XNA
gives it. Of the inherited surface, XNA overrides exactly two -- `Play' and
`IsLooped' -- and leaves the transport, the three settings and `Apply3D' alone,
so those are asserted as inherited and the two overrides are asserted as
different.

`Play' is inherited here even though XNA overrides it, and the reason is in the
override: the base `Play()' submits the parent effect's packet when
`isPacketSubmitted' is false, this one has no packet, and this binding's base
method never had a packet to submit either -- CNA exposes none and
`cna_sound_effect_instance_play' accepts a streaming handle. One method is both,
and this pins the behaviour rather than the inheritance."

    (with-dynamic-instance (d :sample-rate 8000 :channels :mono)
      ;; The four settings start at XNA's SoundEffectInstance constructor defaults,
      ;; because that constructor is the one this class's base call runs.
      (is (= 1.0 (audio:volume d)))
      (is (= 0.0 (audio:pitch d)))
      (is (= 0.0 (audio:pan d)))
      (is (eq :stopped (audio:state d)) "a fresh streaming instance is stopped")
      ;; IsLooped is overridden: false always, and true is refused.
      (is (not (audio:is-looped d)))
      (is (null (setf (audio:is-looped d) nil))
          "assigning false is XNA's no-op, not a refusal")
      (is (not (audio:is-looped d)))
      (signals xna:cna-invalid-state-error (setf (audio:is-looped d) t))
      (is (not (audio:is-looped d))
          "the refused assignment stored nothing, which is what `ret' after the throw means")
      ;; The three settings are inherited, ranges and all.
      (setf (audio:volume d) 0.5)
      (is (= 0.5 (audio:volume d)))
      (signals xna:cna-argument-out-of-range-error (setf (audio:volume d) 1.5))
      (setf (audio:pitch d) -0.25)
      (is (= -0.25 (audio:pitch d)))
      (signals xna:cna-argument-out-of-range-error (setf (audio:pitch d) 2.0))
      (setf (audio:pan d) 0.75)
      (is (= 0.75 (audio:pan d)))
      (signals xna:cna-argument-out-of-range-error (setf (audio:pan d) -1.5))
      ;; Play refuses every keyword, exactly as the base class's does: congruence
      ;; forces the lambda list to accept SoundEffect's three, and accepting is
      ;; not having.
      (signals xna:cna-usage-error (audio:play d :volume 0.5))
      ;; The transport, over a submitted buffer so there is something to play.
      (audio:submit-buffer d (dynamic-pcm 4000))
      (audio:play d)
      (is (eq :playing (audio:state d)))
      (audio:pause d)
      (is (eq :paused (audio:state d)))
      (audio:resume d)
      (is (eq :playing (audio:state d)))
      (audio:stop d)
      (is (eq :stopped (audio:state d)))
      ;; Apply3D is inherited and is legal: XNA does not override it, and CNA's
      ;; header says every cna_sound_effect_instance_* route accepts this handle.
      (audio:apply-3d d (make-instance 'audio:audio-listener)
                      (make-instance 'audio:audio-emitter))
      ;; and the inherited managed getters keep answering after disposal, because
      ;; they are the base class's bare field reads.
      (xna:dispose d)
      (is (audio:is-disposed d))
      (is (= 0.5 (audio:volume d)))
      (is (= -0.25 (audio:pitch d)))
      (is (= 0.75 (audio:pan d)))
      ;; IsLooped is the exception, and it is the override that makes it one: this
      ;; class's getter tests IsDisposed where the base class's does not.
      (signals xna:cna-disposed-error (audio:is-looped d))
      (signals xna:cna-disposed-error (audio:state d))
      (signals xna:cna-disposed-error (audio:pending-buffer-count d))
      (signals xna:cna-disposed-error (audio:submit-buffer d (dynamic-pcm 100)))
      (signals xna:cna-disposed-error (audio:get-sample-duration d 400))
      (signals xna:cna-disposed-error (audio:get-sample-size-in-bytes d 10000))))

(define-audio-device-test buffer-submission-validates-exactly-what-xna-validates
  "SubmitBuffer's five checks, in the pinned IL's order.

    disposed                                 -> ObjectDisposedException
    buffer null / empty / length misaligned  -> ArgumentException(InvalidAudioBuffer)
    offset < 0 || >= length || misaligned    -> ArgumentException(InvalidAudioBufferOffset)
    checked(offset + count) overflows        -> ArgumentException(InvalidOffsetCountLength)
    count <= 0 || offset+count > length
      || count misaligned                    -> ArgumentException(InvalidOffsetCountLength)

`IsAligned(v)' is `v % BlockAlign == 0', and `BlockAlign' for the format this
class always builds -- `AudioFormat.Create(sampleRate, channels, 16)' -- is
`2 * channels'. So a mono instance refuses an odd length and a stereo one refuses
anything not a multiple of four, and that is asserted on both.

The overload shape is the other half: XNA has `SubmitBuffer(byte[])' and
`SubmitBuffer(byte[], int, int)' and nothing between them, so `:OFFSET' alone and
`:COUNT' alone name no member."

    (with-dynamic-instance (mono :sample-rate 8000 :channels :mono)
      (let ((pcm (dynamic-pcm 100)))          ; 200 bytes, block align 2
        ;; the shapes that exist
        (audio:submit-buffer mono pcm)
        (audio:submit-buffer mono pcm :offset 0 :count 200)
        (audio:submit-buffer mono pcm :offset 100 :count 100)
        ;; and the four that do not
        (signals xna:cna-usage-error (audio:submit-buffer mono pcm :offset 0))
        (signals xna:cna-usage-error (audio:submit-buffer mono pcm :count 100))
        (signals xna:cna-usage-error
          (audio:submit-buffer mono pcm :offset 0 :count 100 :loop-start 0))
        ;; the buffer itself
        (signals xna:cna-argument-error (audio:submit-buffer mono nil))
        (signals xna:cna-argument-error
          (audio:submit-buffer mono (make-array 0 :element-type '(unsigned-byte 8))))
        (signals xna:cna-argument-error
          (audio:submit-buffer mono (make-array 3 :element-type '(unsigned-byte 8)
                                                  :initial-element 0))
          "an odd length is not a whole number of 2-byte mono frames")
        ;; the offset
        (signals xna:cna-argument-error (audio:submit-buffer mono pcm :offset -2 :count 10))
        (signals xna:cna-argument-error (audio:submit-buffer mono pcm :offset 200 :count 2))
        (signals xna:cna-argument-error (audio:submit-buffer mono pcm :offset 1 :count 10)
          "an odd offset is not frame-aligned")
        ;; the count
        (signals xna:cna-argument-error (audio:submit-buffer mono pcm :offset 0 :count 0))
        (signals xna:cna-argument-error (audio:submit-buffer mono pcm :offset 0 :count -2))
        (signals xna:cna-argument-error (audio:submit-buffer mono pcm :offset 0 :count 3)
          "an odd count is not frame-aligned")
        (signals xna:cna-argument-error (audio:submit-buffer mono pcm :offset 100 :count 200)
          "offset + count must not run past the end")
        ;; the overflow branch, which is the same exception by another road
        (signals xna:cna-argument-error
          (audio:submit-buffer mono pcm :offset 0 :count most-positive-fixnum))))
    ;; and a stereo instance aligns to four rather than to two
    (with-dynamic-instance (stereo :sample-rate 8000 :channels :stereo)
      (audio:submit-buffer stereo (dynamic-pcm 50 :stereo))
      (signals xna:cna-argument-error
        (audio:submit-buffer stereo (make-array 6 :element-type '(unsigned-byte 8)
                                                  :initial-element 0))
        "6 bytes is not a whole number of 4-byte stereo frames")
      (signals xna:cna-argument-error
        (audio:submit-buffer stereo (dynamic-pcm 50 :stereo) :offset 2 :count 4)
        "an offset of 2 is not frame-aligned for stereo")))

(define-audio-device-test pending-buffers-rise-on-submission-and-fall-on-playback
  "**AUDIO_DYNAMIC_STREAMING.** The evidence that a buffer was taken *and consumed*.

`cna_dynamic_sound_effect_instance_get_pending_buffer_count' documents what the
number means, and it is the reason this member is worth a lane of its own: the
count \"only shrinks once a buffer has actually been **consumed by playback**, not
merely handed to the mixer, which is the canonical contract\". So the fall is a
statement about the native streaming state machine rather than about this
binding.

The assertion is a state transition, not a duration:

    pending = 0
    submit half a second of generated PCM16   -> pending = 1
    submit a second block                     -> pending = 2
    play, and run frames                      -> pending falls to 0

Half a second rather than a few frames' worth, so that the rise cannot be raced
by the fall -- and the fall is polled with a **bound** rather than asserted at a
frame count, because how many frames half a second of audio takes depends on the
frame rate and on nothing this test controls. Nothing here claims a sound was
heard: the SDL `dummy' driver opens a device with no speaker behind it."

    (with-dynamic-instance (d :sample-rate 8000 :channels :mono)
      (is (= 0 (audio:pending-buffer-count d)) "nothing submitted, nothing pending")
      ;; 4000 mono frames at 8000 Hz is half a second.
      (audio:submit-buffer d (dynamic-pcm 4000))
      (is (= 1 (audio:pending-buffer-count d)) "a submitted buffer is pending")
      (audio:submit-buffer d (dynamic-pcm 4000))
      (is (= 2 (audio:pending-buffer-count d)) "and a second one is pending too")
      ;; Nothing is consumed before playback starts, which is what makes the two
      ;; assertions above safe from a race rather than lucky.
      (is (= 2 (audio:pending-buffer-count d))
          "a stopped instance consumes nothing")
      (audio:play d)
      (let ((frames (%run-frames-until game (lambda () (zerop (audio:pending-buffer-count d))))))
        (is (not (null frames))
            "the streaming state machine consumed both buffers within the bound; ~
             ~d still pending" (audio:pending-buffer-count d))
        (is (= 0 (audio:pending-buffer-count d))))
      (note-audio :dynamic-streaming
                  "generated PCM16 was submitted to a DynamicSoundEffectInstance, the ~
                   pending-buffer count rose to two, and the native streaming state ~
                   machine consumed both while the game loop ran. A dummy device is ~
                   not a speaker and nothing here is a claim that a sound was heard")))

(define-audio-device-test buffer-needed-reaches-lisp-and-stops-at-disposal
  "The BufferNeeded event: add, remove, containment and lifetime.

**No FiveAM assertion runs inside the callback.** The handler records what it
saw and the assertions run after control is back in Lisp, which is the rule every
callback test here follows: a condition signalled inside a C callback would cross
the containment layer rather than fail the test.

What is asserted:

  * the handler is called, with the **instance** as its sender -- XNA's
    `OnBufferNeeded' invokes `handler(this, EventArgs.Empty)', and the empty
    argument is not projected;
  * removing it stops the calls, and removing it twice answers NIL rather than
    refusing, which is what `-=' against a delegate that no longer holds it does;
  * the callback registry returns to the size it was, so no token is left rooted;
  * **no callback arrives after disposal**, which is XNA's own ordering: its
    `Dispose(bool)' removes the instance from the table its native callback looks
    it up in before the base disposal deallocates the voice.

Neither framework publishes a queue-depth threshold, so nothing here asserts one:
several callbacks may arrive before a submission and that is not a defect."

    (let ((before (int:callback-registry-count))
          (seen '()))
      (with-dynamic-instance (d :sample-rate 8000 :channels :mono)
        (let ((note (lambda (sender) (push sender seen))))
          (audio:add-buffer-needed-handler d note)
          (is (= (1+ before) (int:callback-registry-count))
              "the subscription rooted exactly one token")
          (audio:submit-buffer d (dynamic-pcm 800))
          (audio:play d)
          (%run-frames-until game (lambda () (not (null seen))) :limit 300)
          (is (not (null seen)) "the buffer-needed event reached Lisp")
          (is (every (lambda (sender) (eq sender d)) seen)
              "and its sender is the instance, as OnBufferNeeded's `handler(this, ...)' is")
          ;; removal
          (is (audio:remove-buffer-needed-handler d note)
              "removal reports that it found a handler to remove")
          (is (= before (int:callback-registry-count))
              "and the token is no longer rooted")
          (setf seen '())
          (dotimes (frame 20) (xna:run-one-frame game))
          (is (null seen) "a removed handler is not called")
          (is (null (audio:remove-buffer-needed-handler d note))
              "removing it again finds nothing, and says so rather than refusing")
          ;; and a live subscription must not survive the object
          (audio:add-buffer-needed-handler d note)
          (is (= (1+ before) (int:callback-registry-count)))
          (setf seen '())
          (xna:dispose d)
          (is (= before (int:callback-registry-count))
              "disposal released the registration and unrooted its token")
          (dotimes (frame 20) (xna:run-one-frame game))
          (is (null seen) "no callback arrives after disposal")))
      (is (= before (int:callback-registry-count))))
    (xna:dispose game)
    (is (xna:disposed-p game)))

(define-audio-device-test the-dynamic-sample-computations-are-xnas-and-cnas-are-pinned
  "Both sides, exactly as the two static computations on SoundEffect pin both.

XNA's are `AudioFormat.DurationFromSize' and `SizeFromDuration' over the
instance's own format, so this binding computes them rather than taking CNA's
route -- `DurationFromSize' ends in `TimeSpan.FromMilliseconds', which rounds to
a whole millisecond, and CNA's route does not round the same way.

Pinning CNA's answer as well is what makes that a measurement rather than a
preference: a CNA that changed fails this test rather than silently changing the
binding's public behaviour. Where the two agree, this asserts that they agree.

The arithmetic a reader can redo: 8000 bytes of mono PCM16 is 4000 frames, and
4000 frames at 8000 Hz is 500 ms, which is 5,000,000 ticks. One second of stereo
at 44100 Hz is 44100 frames of 4 bytes, which is 176,400."

    (with-dynamic-instance (mono :sample-rate 8000 :channels :mono)
      (is (= 5000000 (audio:get-sample-duration mono 8000)))
      (is (= 0 (audio:get-sample-duration mono 0)) "zero bytes is TimeSpan.Zero")
      (signals xna:cna-argument-error (audio:get-sample-duration mono -2)
        "a negative size is ArgumentException(InvalidBufferSize)")
      (is (= 16000 (audio:get-sample-size-in-bytes mono 10000000)))
      (is (= 0 (audio:get-sample-size-in-bytes mono 0)) "TimeSpan.Zero is zero bytes")
      (signals xna:cna-argument-out-of-range-error
        (audio:get-sample-size-in-bytes mono -1))
      ;; and CNA's own routes, so a change in them is a failure rather than a drift
      (cffi:with-foreign-object (ticks :int64)
        (int:check-result
         (cna-lisp.internal.ffi::%dynamic-sound-effect-instance-get-sample-duration-ticks
          (int:handle-of mono) 8000 ticks)
         "test")
        (is (= 5000000 (cffi:mem-ref ticks :int64))
            "CNA agrees with XNA on this size, and the test says so rather than assuming it"))
      (cffi:with-foreign-object (bytes :int32)
        (int:check-result
         (cna-lisp.internal.ffi::%dynamic-sound-effect-instance-get-sample-size-in-bytes
          (int:handle-of mono) 10000000 bytes)
         "test")
        (is (= 16000 (cffi:mem-ref bytes :int32)))))
    (with-dynamic-instance (stereo :sample-rate 44100 :channels :stereo)
      (is (= 176400 (audio:get-sample-size-in-bytes stereo 10000000)))
      (is (= 10000000 (audio:get-sample-duration stereo 176400)))))

(define-condition dynamic-subclass-blew-up (error) ()
  (:report (lambda (condition stream)
             (declare (ignore condition))
             (format stream "boom, from a DynamicSoundEffectInstance subclass"))))

(defclass exploding-dynamic-instance (audio:dynamic-sound-effect-instance) ())
(defmethod initialize-instance :after ((object exploding-dynamic-instance) &key)
  (declare (ignore object))
  (error 'dynamic-subclass-blew-up))

(defclass exploding-subscribed-dynamic-instance (audio:dynamic-sound-effect-instance) ())
(defmethod initialize-instance :after ((object exploding-subscribed-dynamic-instance) &key)
  "Subscribe, and *then* fail -- so the rollback has a registration to undo as
well as a handle."
  (audio:add-buffer-needed-handler object (lambda (sender) (declare (ignore sender))))
  (error 'dynamic-subclass-blew-up))

(define-audio-device-test a-failed-dynamic-subclass-gives-back-handle-and-registration
  "Construction atomicity for the new kind, at both of its injection points.

The generic framework in `tests/native/construction-atomicity.lisp' covers a
subclass that fails after the handle exists. This class has a second thing a
construction can acquire -- a BufferNeeded registration and the callback token
that roots it -- so the second subclass here subscribes before it fails, and the
assertions are the same four either way:

  * the caller sees the subclass's own condition, not a rollback's;
  * the game is left owning no live child of that type;
  * the callback registry is the size it was, so no token stays rooted;
  * the game shuts down, which it cannot do while a child handle lives."

    (let ((children (length (int:children-of game)))
          (tokens (int:callback-registry-count)))
      (signals dynamic-subclass-blew-up
        (make-instance 'exploding-dynamic-instance :sample-rate 8000 :channels :mono))
      (is (= children (length (int:children-of game)))
          "the handle went back, so the game owns no more children than before")
      (is (= tokens (int:callback-registry-count)))
      (signals dynamic-subclass-blew-up
        (make-instance 'exploding-subscribed-dynamic-instance
                       :sample-rate 8000 :channels :mono))
      (is (= children (length (int:children-of game)))
          "and so did the one that had already subscribed")
      (is (= tokens (int:callback-registry-count))
          "with its registration released and its token unrooted"))
    (xna:dispose game)
    (is (xna:disposed-p game)))

(define-audio-device-test a-live-subscription-does-not-prevent-teardown
  "Ownership stress with the subscription left live on purpose.

A consumer's program does not unsubscribe before disposing; it disposes. So the
qualification has to be that disposal releases the registration itself, over
enough cycles that a leak would show, and that the game still goes at the end.
Twenty cycles rather than one, for the reason the ownership stress test uses
twenty: a single cycle cannot distinguish a leak from a coincidence."

    (let ((baseline (int:callback-registry-count)))
      (dotimes (cycle 20)
        (let ((d (make-instance 'audio:dynamic-sound-effect-instance
                                :sample-rate 8000 :channels :mono)))
          (audio:add-buffer-needed-handler d (lambda (sender) (declare (ignore sender))))
          (audio:submit-buffer d (dynamic-pcm 400))
          (audio:play d)
          (xna:run-one-frame game)
          ;; no unsubscribe: disposal is what has to release it
          (xna:dispose d)))
      (is (= baseline (int:callback-registry-count))
          "twenty subscribed-and-disposed instances left no token rooted"))
    (xna:dispose game)
    (is (xna:disposed-p game)))

;;; --- ContentManager.Load<SoundEffect> ----------------------------------------
;;;
;;; The fixture is `tests/fixtures/test-tone.wav', generated byte for byte by
;;; `tools/qualification/make-audio-fixtures.py': a canonical 44-byte RIFF/WAVE
;;; header over exactly one second of the same computed sawtooth PCM16-RAMP
;;; produces. **No recording is stored in this repository**, and the payload is
;;; arithmetic in two places rather than a blob in one, so neither can drift
;;; without the duration assertion below failing.

(defclass sound-content-game (xna:game)
  ((asset :initarg :asset :initform "test-tone" :accessor asset)
   (first-load :initform nil :accessor first-load)
   (second-load :initform nil :accessor second-load)
   (load-error :initform nil :accessor load-error)
   (children-before :initform nil :accessor children-before)
   (children-after :initform nil :accessor children-after))
  (:documentation "Loads a sound through the game's own ContentManager."))

(defun %sound-content-root ()
  "The directory the audio fixture lives in, as CNA's root directory."
  (let ((path (truename (fixture-path "test-tone.wav"))))
    (namestring (make-pathname :name nil :type nil :defaults path))))

(defmethod xna:load-content ((game sound-content-game))
  (let ((content (xna:content game)))
    (setf (xna.content:root-directory content) (%sound-content-root)
          (children-before game) (length (int:children-of game)))
    (handler-case
        (setf (first-load game)
              (xna.content:load-asset content 'audio:sound-effect (asset game))
              (second-load game)
              (xna.content:load-asset content 'audio:sound-effect (asset game)))
      (error (condition) (setf (load-error game) condition)))
    (setf (children-after game) (length (int:children-of game))))
  (xna:exit game))

(defmacro with-sound-content-game ((variable &rest initargs) &body body)
  `(let ((,variable (make-instance 'sound-content-game ,@initargs)))
     (unwind-protect (progn (xna:run ,variable) ,@body)
       ;; **Unload before disposing the game**, which is what a consumer does:
       ;; a loaded effect is a child of the game, CNA refuses to destroy a parent
       ;; with live children, and this binding does not cascade on a program's
       ;; behalf. `Unload' is the member that gives them back.
       (ignore-errors (xna.content:unload (xna:content ,variable)))
       (%tear-down-audio-game ,variable))))

(define-native-test sound-effect-is-a-loadable-asset-type
  "The loader table is what makes `Load<T>' one member rather than five
differently-named functions, and it is dumped into the generated documentation.
A loader that landed without a documentation change leaves the rendered block
stale and `verify-numbers.py' red; this asserts the table itself."
  (is (member 'audio:sound-effect (xna.content:loadable-asset-types))
      "SoundEffect must be in the loadable set: ~s"
      (xna.content:loadable-asset-types)))

(define-native-test loading-a-sound-effect-answers-one-cached-object
  "**CNA's route does not cache and XNA's `Load<T>' does, so the managed cache
wins.** `cna_content_manager_load_sound_effect' says so itself -- \"the canonical
Load<SoundEffect> specialization, which deliberately does not cache: every
successful call returns an independently owned sound effect\" -- and XNA's
`ContentManager.Load<T>' looks the cleaned name up in `loadedAssets' before
reading anything, whatever T is.

So two loads of one name answer **one** object here, and a program has one thing
to dispose rather than two. Letting CNA's per-call route through would answer two.

The duration is the fixture's own: 8000 frames at 8000 Hz is exactly one second,
which is 10,000,000 ticks."
  (let ((available (with-audio-game (probe) (audio-playback-available-p))))
    (if (not available)
        ;; With no device CNA cannot decode into a device-backed effect, so the
        ;; load fails. That is the unavailable branch of this test, and it is a
        ;; result: the game must still be left owning nothing.
        (with-sound-content-game (game)
          (is (null (first-load game)) "no device, so nothing loaded")
          (is (not (null (load-error game))) "and the load reported why")
          (is (= (children-before game) (children-after game))
              "a failed load changed the game's children from ~d to ~d"
              (children-before game) (children-after game)))
        (with-sound-content-game (game)
          (is (null (load-error game)) "the load failed: ~a" (load-error game))
          (is (typep (first-load game) 'audio:sound-effect))
          (is (eq (first-load game) (second-load game))
              "two loads of one asset name must answer one object")
          (is (eql 10000000 (audio:duration (first-load game)))
              "the fixture is exactly one second of 8000 Hz mono PCM16")))))

(define-native-test unloading-disposes-a-loaded-sound-effect
  "`Unload' disposes what the manager loaded, and `Game.Content.Dispose()' is
`Unload' plus being finished -- which is all XNA's is. The effect is a child of
the game, so a leaked one would stop the game shutting down; that it shuts down is
the other half of this assertion."
  (let ((available (with-audio-game (probe) (audio-playback-available-p))))
    (when available
      (with-sound-content-game (game)
        (is (null (load-error game)) "the load failed: ~a" (load-error game))
        (let ((effect (first-load game)))
          (is (not (audio:is-disposed effect)))
          (xna.content:unload (xna:content game))
          (is (audio:is-disposed effect)
              "Unload must dispose the sound effect it loaded"))))))

(define-native-test a-missing-sound-asset-fails-and-leaves-the-game-owning-nothing
  "A failed load is all-or-nothing: the game must not be left owning an effect the
caller never received.

**The condition is CNA's own choice and is worth naming.** A missing *font* gives
`CNA_RESULT_IO', and `cna_content_manager_load_sound_effect''s header documents
`CNA_RESULT_IO' for \"a missing or undecodable asset\" too -- but measured against
0.21.0 a missing sound answers `CNA_RESULT_NOT_SUPPORTED', with a message naming
the file it could not open. So this asserts what CNA does rather than what its
header says, and a corrected CNA will fail here rather than passing silently.

It is deliberately **not** mapped to NO-AUDIO-HARDWARE-ERROR: NOT_SUPPORTED from
this route means either no device or no file, and the result code alone cannot
tell them apart. Guessing would name the wrong cause half the time."
  (with-sound-content-game (game :asset "no-such-sound")
    (is (null (first-load game)))
    (is (not (null (load-error game))) "a missing asset must fail")
    (is (typep (load-error game) 'xna:cna-native-error)
        "a missing asset gave ~a" (type-of (load-error game)))
    (is (not (typep (load-error game) 'audio:no-audio-hardware-error))
        "a missing file must not be reported as missing audio hardware")
    (is (= (children-before game) (children-after game))
        "a failed load changed the game's children from ~d to ~d"
        (children-before game) (children-after game))))

;;; --- construction and content atomicity --------------------------------------
;;;
;;; **The machinery is the existing generic one**, not an audio-specific copy:
;;; `tests/native/content-atomicity.lisp' owns the destroy log, the
;;; `*EXPLODING-STEP*' seam and the `ATOMIC-LOAD-GAME' fixture, and this file adds
;;; the audio cases to them. `%SOUND-EFFECT-DESTROY' joined the logged routes and
;;; `%READ-SOUND-EFFECT-DURATION' grew the `:around' that fails it -- which is why
;;; that function is a generic function at all.
;;;
;;; Four states a failure can happen in, and all four have to give everything
;;; back exactly once:
;;;
;;;   1. the effect's native handle exists, and a subclass initializer signals
;;;   2. the instance's native handle exists, and a subclass initializer signals
;;;   3. a load has the handle and the duration, and the cache insertion fails
;;;   4. a load has the handle, and reading the duration fails

(define-condition audio-subclass-blew-up (error) ()
  (:report (lambda (c stream) (declare (ignore c))
             (format stream "boom, from an audio subclass initializer"))))

(defclass exploding-sound-effect (audio:sound-effect) ())
(defmethod initialize-instance :after ((object exploding-sound-effect) &key)
  (declare (ignore object))
  (error 'audio-subclass-blew-up))

(defclass exploding-sound-effect-instance (audio:sound-effect-instance) ())
(defmethod initialize-instance :after ((object exploding-sound-effect-instance) &key)
  (declare (ignore object))
  (error 'audio-subclass-blew-up))

(define-audio-device-test a-failed-sound-effect-subclass-gives-the-handle-back
  "Case 1: `SoundEffect''s own initializer has finished, so CNA is holding a
handle, and then the consumer's subclass signals.

CLOS runs `:after' methods least-specific-first, so a subclass's own runs *last*
-- after the handle exists and after the effect is registered as a child of the
game. Without the construction ledger the game would be left owning a sound
effect the caller never received, and the symptom would appear at shutdown rather
than here."
  (let ((before (length (int:children-of game)))
        (registry-before (int:callback-registry-count)))
    (call-with-destroy-log
     (lambda (log)
       (signals audio-subclass-blew-up
         (make-instance 'exploding-sound-effect
                        :buffer (pcm16-silence 800)
                        :sample-rate +fixture-sample-rate+ :channels :mono))
       (let ((entries (destroys-of (funcall log) 'ffi::%sound-effect-destroy)))
         (is (= 1 (length entries))
             "the effect handle was destroyed ~d time(s), not once" (length entries))
         (is (plusp (cdr (first entries))) "a zero handle was handed back"))))
    (is (= before (length (int:children-of game)))
        "the game was left owning ~d child/children it never handed out"
        (- (length (int:children-of game)) before))
    (is (= registry-before (int:callback-registry-count)))))

(define-audio-device-test a-failed-instance-subclass-leaves-the-effect-disposable
  "Case 2: the instance's handle exists and its subclass signals.

The consequence a leak has here is specific and worse than a stranded object: CNA
refuses to destroy a sound effect that still has live instances, so an instance
left behind makes its *parent* undisposable, and the game after it. That the
effect still disposes is the assertion."
  (with-sound-effect (effect :buffer (pcm16-silence 800)
                             :sample-rate +fixture-sample-rate+ :channels :mono)
    (let ((before (length (int:children-of effect))))
      (call-with-destroy-log
       (lambda (log)
         (signals audio-subclass-blew-up
           (make-instance 'exploding-sound-effect-instance :sound-effect effect))
         (let ((entries (destroys-of (funcall log)
                                     'ffi::%sound-effect-instance-destroy)))
           (is (= 1 (length entries))
               "the instance handle was destroyed ~d time(s), not once"
               (length entries)))))
      (is (= before (length (int:children-of effect)))
          "the effect was left owning ~d instance(s) it never handed out"
          (- (length (int:children-of effect)) before))
      ;; The proof that nothing is stranded: the effect goes back, which CNA
      ;; would refuse if an instance were still alive.
      (xna:dispose effect)
      (is (audio:is-disposed effect)))))

(define-native-test a-sound-load-whose-caching-fails-keeps-none-of-it
  "Case 3: everything worked and the commit failed.

By the time the effect reaches the cache CNA has handed the handle over, the
duration is read, the object is built and the game owns it. All of it has to come
apart, and the manager has to keep neither a cache entry nor a disposal-list
entry -- an entry left on the second would make `Unload' dispose a handle that
had already gone back."
  (when (with-audio-game (probe) (audio-playback-available-p))
    (with-atomic-load-game (game :asset-type 'audio:sound-effect
                                 :asset-name "test-tone"
                                 :step-to-blow :cache-insertion)
      (let ((log (destroy-log game))
            (content (xna:content game)))
        (is (typep (condition-seen game) 'content-step-blew-up)
            "the caller saw ~a" (type-of (condition-seen game)))
        (is (eq :cache-insertion (blown-step (condition-seen game))))
        (is (destroyed-exactly-once-p log 'ffi::%sound-effect-destroy)
            "the effect handle was destroyed ~d time(s), not once"
            (length (destroys-of log 'ffi::%sound-effect-destroy)))
        (is (= (children-before game) (children-after game))
            "the adopted effect was left registered as a live child of the game")
        (is (= (registry-before game) (registry-after game)))
        (is (zerop (hash-table-count (xna.content::%content-loaded-assets content)))
            "a failed load left ~d cache entry/entries behind"
            (hash-table-count (xna.content::%content-loaded-assets content)))
        (is (null (xna.content::%content-disposable-assets content))
            "a failed load left ~d asset(s) on the manager's disposal list"
            (length (xna.content::%content-disposable-assets content)))))))

(define-native-test a-sound-load-that-fails-after-its-handle-strands-nothing
  "Case 4: CNA handed the handle over and the very next step failed.

This is the narrowest window in the load -- the loader's ledger owns a handle and
no object exists yet -- and it is the one the single-ledger rule exists for. A
second ledger recording the same handle would destroy it twice here."
  (when (with-audio-game (probe) (audio-playback-available-p))
    (with-atomic-load-game (game :asset-type 'audio:sound-effect
                                 :asset-name "test-tone"
                                 :step-to-blow :sound-effect-duration)
      (let ((log (destroy-log game))
            (content (xna:content game)))
        (is (typep (condition-seen game) 'content-step-blew-up)
            "the caller saw ~a" (type-of (condition-seen game)))
        (is (eq :sound-effect-duration (blown-step (condition-seen game))))
        (is (destroyed-exactly-once-p log 'ffi::%sound-effect-destroy)
            "the effect handle was destroyed ~d time(s), not once"
            (length (destroys-of log 'ffi::%sound-effect-destroy)))
        (is (= (children-before game) (children-after game)))
        (is (zerop (hash-table-count (xna.content::%content-loaded-assets content))))
        (is (null (xna.content::%content-disposable-assets content)))))))

(define-native-test a-successful-sound-load-destroys-nothing
  "The control. Without it every assertion above would still pass if
`Load<SoundEffect>' had simply stopped working."
  (when (with-audio-game (probe) (audio-playback-available-p))
    (with-atomic-load-game (game :asset-type 'audio:sound-effect
                                 :asset-name "test-tone"
                                 :step-to-blow nil)
      (is (null (condition-seen game)) "the control load failed: ~a" (condition-seen game))
      (is (null (destroys-of (destroy-log game) 'ffi::%sound-effect-destroy))
          "a successful load destroyed ~d handle(s)"
          (length (destroys-of (destroy-log game) 'ffi::%sound-effect-destroy)))
      (is (= 1 (- (children-after game) (children-before game)))
          "a successful load added ~d child/children, not one"
          (- (children-after game) (children-before game)))
      (is (= 1 (hash-table-count
                (xna.content::%content-loaded-assets (xna:content game))))
          "a successful load left ~d cache entry/entries"
          (hash-table-count (xna.content::%content-loaded-assets (xna:content game))))
      ;; and the loaded effect is disposed here rather than in the teardown: it
      ;; is a live child of the game, and CNA refuses to destroy a parent that
      ;; still has one. The control is the only case with anything left to give
      ;; back -- every failing case above already gave it back.
      (xna:dispose (first (load-result game))))))

;;; --- SoundEffect.FromStream, and the wave contract it accepts ----------------
;;;
;;; **Why this corpus exists.** CNA's decode route accepts "whatever the audio
;;; backend can decode ... which is more than the raw PCM the other creation
;;; routes take" -- its own header -- and XNA's `FromStream' accepts one shape,
;;; parsed by a private `WavFile' whose IL is transcribed in `src/audio/wave.lisp'.
;;; Handing the bytes straight to CNA therefore *added* formats to the member.
;;; Every case below is generated here rather than stored: no recording is in this
;;; repository, and a reviewer can check each header field against the IL without
;;; opening an audio editor.

(defun %u16le (n) (list (ldb (byte 8 0) n) (ldb (byte 8 8) n)))
(defun %u32le (n)
  (list (ldb (byte 8 0) n) (ldb (byte 8 8) n) (ldb (byte 8 16) n) (ldb (byte 8 24) n)))
(defun %ascii (string) (map 'list #'char-code string))

(defun %octets (&rest pieces)
  (let ((flat (apply #'append (mapcar (lambda (p) (if (listp p) p (coerce p 'list)))
                                      pieces))))
    (make-array (length flat) :element-type '(unsigned-byte 8)
                              :initial-contents flat)))

(defun %fmt-chunk (&key (format-tag 1) (channels 1) (sample-rate 8000) (bits 16)
                        (block-align nil) (size 16))
  "A `fmt ' chunk, with every field settable so a single wrong one can be tested."
  (let* ((align (or block-align (floor (* channels bits) 8)))
         (byte-rate (* sample-rate align))
         (body (%octets (%u16le format-tag) (%u16le channels) (%u32le sample-rate)
                        (%u32le byte-rate) (%u16le align) (%u16le bits)
                        (make-list (max 0 (- size 16)) :initial-element 0))))
    (%octets (%ascii "fmt ") (%u32le (length body)) body)))

(defun %data-chunk (pcm) (%octets (%ascii "data") (%u32le (length pcm)) pcm))

(defun %riff (&rest chunks)
  "Wrap CHUNKS in a RIFF/WAVE container whose declared size matches the stream.

`ParseWavHeader' compares the size field against `BaseStream.Length - 8' exactly,
so this computes it rather than taking it as an argument -- a test that wants a
wrong one corrupts the result."
  (let ((body (apply #'%octets (%ascii "WAVE") chunks)))
    (%octets (%ascii "RIFF") (%u32le (length body)) body)))

(defun %valid-wave (&rest fmt-arguments)
  (let* ((channels (or (getf fmt-arguments :channels) 1))
         (bits (or (getf fmt-arguments :bits) 16))
         (frames 64)
         (pcm (make-array (* frames channels (floor bits 8))
                          :element-type '(unsigned-byte 8) :initial-element 0)))
    (%riff (apply #'%fmt-chunk fmt-arguments) (%data-chunk pcm))))

(defmacro %with-wave-stream ((variable octets) &body body)
  "Present OCTETS to BODY as a binary input stream, through a scratch file.

%SCRATCH-PATH is `tests/native/texture-streams.lisp''s, which puts the file in
the shared `build-probe' directory rather than anywhere per-run.

Common Lisp has no portable in-memory binary stream and this binding deliberately
takes an ordinary one, so the corpus is written and read back. The path is one
file reused by every case, in the shared probe directory."
  (let ((path (gensym "PATH")) (bytes (gensym "BYTES")))
    `(let ((,path (%scratch-path "audio-from-stream-case.bin"))
           (,bytes ,octets))
       (with-open-file (out ,path :direction :output :element-type '(unsigned-byte 8)
                                  :if-exists :supersede)
         (write-sequence ,bytes out))
       (with-open-file (,variable ,path :element-type '(unsigned-byte 8))
         ,@body))))


(defun %from-stream-outcome (octets)
  "What SOUND-EFFECT-FROM-STREAM does with OCTETS: :LOADED or the condition type."
  (%with-wave-stream (in octets)
    (handler-case (let ((effect (audio:sound-effect-from-stream in)))
                    (xna:dispose effect)
                    :loaded)
      (error (condition) (type-of condition)))))

(define-audio-device-test from-stream-accepts-exactly-xnas-wave-shape
  "The accepted surface, and the two exceptions the rejections divide into.

`WavFile.ParseWavHeader' runs **outside** the chunk loop, so its
`InvalidOperationException' -- CNA-USAGE-ERROR here -- propagates: a stream that
is not RIFF, whose declared size disagrees with its length, or whose form is not
WAVE. Everything below the header is raised inside
`try { ReadChunk(); } catch (object) { break; }', so it merely ends the loop and
the caller sees `ArgumentException(InvalidWaveStream)' -- CNA-ARGUMENT-ERROR --
from the `format == null || buffer == null' test that follows.

That two-way split is the observable behaviour of one member and is why both are
asserted rather than a single \"it was refused\"."

    ;; --- what XNA accepts ---------------------------------------------------
    (is (eq :loaded (%from-stream-outcome (%valid-wave)))
        "PCM16 mono 8000 Hz is the canonical accepted shape")
    (is (eq :loaded (%from-stream-outcome (%valid-wave :channels 2)))
        "stereo")
    (is (eq :loaded (%from-stream-outcome (%valid-wave :bits 8)))
        "8-bit, which the constructors cannot take and FromStream can")
    (is (eq :loaded (%from-stream-outcome (%valid-wave :sample-rate 8000)))
        "the lower sample-rate bound")
    (is (eq :loaded (%from-stream-outcome (%valid-wave :sample-rate 48000)))
        "and the upper one")
    ;; A longer fmt chunk is legal: ParseFormat requires >= 16 and reads what is
    ;; there. An unknown chunk is skipped, and an odd-length one is padded.
    (is (eq :loaded (%from-stream-outcome (%valid-wave :size 18)))
        "an 18-byte fmt chunk, which is WAVEFORMATEX with a zero extension")
    (is (eq :loaded
            (%from-stream-outcome
             (%riff (%fmt-chunk)
                    (%octets (%ascii "LIST") (%u32le 5) (%ascii "abcde") '(0))
                    (%data-chunk (make-array 128 :element-type '(unsigned-byte 8)
                                                 :initial-element 0)))))
        "an unknown odd-length chunk is skipped and its pad byte consumed")

    ;; --- ParseWavHeader: InvalidOperationException --------------------------
    (is (eq 'xna:cna-usage-error
            (%from-stream-outcome (%octets (%ascii "RIFX") (%u32le 4) (%ascii "WAVE"))))
        "not a RIFF chunk")
    (is (eq 'xna:cna-usage-error
            (%from-stream-outcome (%octets (%ascii "RIFF") (%u32le 999) (%ascii "WAVE"))))
        "a declared size that is not the stream's length minus eight")
    (is (eq 'xna:cna-usage-error
            (%from-stream-outcome (%octets (%ascii "RIFF") (%u32le 4) (%ascii "AVI "))))
        "a RIFF form that is not WAVE")
    (is (eq 'xna:cna-usage-error
            (%from-stream-outcome (%octets (%ascii "RIF"))))
        "a stream too short to hold a RIFF header at all")

    ;; --- below the header: ArgumentException --------------------------------
    (is (eq 'xna:cna-argument-error (%from-stream-outcome (%riff)))
        "no fmt chunk and no data chunk")
    (is (eq 'xna:cna-argument-error (%from-stream-outcome (%riff (%fmt-chunk))))
        "a fmt chunk and no data chunk")
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome
             (%riff (%data-chunk (make-array 8 :element-type '(unsigned-byte 8)
                                               :initial-element 0)))))
        "a data chunk and no fmt chunk")
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome
             (%riff (%data-chunk (make-array 8 :element-type '(unsigned-byte 8)
                                               :initial-element 0))
                    (%fmt-chunk))))
        "data *before* fmt, which ParseData refuses and so ends the loop")
    (is (eq 'xna:cna-argument-error (%from-stream-outcome (%valid-wave :channels 3)))
        "three channels")
    (is (eq 'xna:cna-argument-error (%from-stream-outcome (%valid-wave :channels 0)))
        "no channels")
    (is (eq 'xna:cna-argument-error (%from-stream-outcome (%valid-wave :sample-rate 7999)))
        "one hertz below XNA's lower bound")
    (is (eq 'xna:cna-argument-error (%from-stream-outcome (%valid-wave :sample-rate 48001)))
        "one hertz above its upper bound")
    (is (eq 'xna:cna-argument-error (%from-stream-outcome (%valid-wave :bits 24)))
        "24-bit samples, which XNA does not read")
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome (%valid-wave :block-align 7)))
        "a block alignment that contradicts the channels and sample width")
    ;; A `fmt ' chunk whose *declared* size is under sixteen: ParseFormat's
    ;; "if (size < 16) throw" is the first thing it does.
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome
             (%riff (%octets (%ascii "fmt ") (%u32le 12)
                             (%u16le 1) (%u16le 1) (%u32le 8000) (%u16le 2))
                    (%data-chunk (make-array 8 :element-type '(unsigned-byte 8)
                                               :initial-element 0)))))
        "a fmt chunk shorter than WAVEFORMAT's fixed 16 bytes")
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome
             (%riff (%fmt-chunk)
                    (%octets (%ascii "data") (%u32le 1) '(0)))))
        "a data chunk smaller than one sample frame")
    ;; A fmt chunk whose declared size runs past the end of the stream. The RIFF
    ;; size still matches -- %RIFF computes it -- so the header passes and the
    ;; chunk loop is where this ends, with no format.
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome
             (%riff (%octets (%ascii "fmt ") (%u32le 16) '(1 0 1 0)))))
        "a truncated fmt chunk, which ends the loop with no format")

    ;; --- the argument checks in front of the parser -------------------------
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome (make-array 0 :element-type '(unsigned-byte 8))))
        "an empty stream, which WavFile refuses before reading anything")
    ;; Random bytes fail at the RIFF tag, which is ParseWavHeader and therefore
    ;; the *usage* error rather than the wave-stream one. Which of the two a
    ;; caller gets is decided by how far the parse got, and this is the case that
    ;; makes that concrete: a file that is not a wave file at all never reaches
    ;; the chunk loop.
    (is (eq 'xna:cna-usage-error
            (%from-stream-outcome
             (make-array 64 :element-type '(unsigned-byte 8) :initial-element 219)))
        "random bytes fail at the RIFF tag, before the chunk loop")
    (signals xna:cna-argument-error (audio:sound-effect-from-stream nil))
    (let ((path (%scratch-path "audio-from-stream-case.bin")))
      (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)
                                :if-exists :supersede)
        (write-sequence (%valid-wave) out))
      ;; a stream that is not an input stream, and one that is closed
      (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)
                                :if-exists :append)
        (signals xna:cna-argument-error (audio:sound-effect-from-stream out)))
      (let ((closed (open path :element-type '(unsigned-byte 8))))
        (close closed)
        (signals error (audio:sound-effect-from-stream closed)))))

(define-audio-device-test from-stream-refuses-a-wave-cna-would-have-decoded
  "**The case the whole wave parser exists for.** A 32-bit IEEE-float WAV is a
well-formed RIFF/WAVE file that SDL -- and therefore CNA's decode route -- reads
happily, and that XNA does not: `ParseFormat' refuses every FormatTag but 1, so
`format' stays null and `FromStream' throws `ArgumentException'.

This test asserts **both halves**, because only the pair is evidence. If CNA ever
stopped decoding the payload the first assertion fails and this stops being the
case it claims to be; if the binding ever stopped refusing it, the second fails.
An 8-bit ADPCM tag is checked too, as a format nothing here can decode either
way -- it must be refused for the *format* reason and not for a decode failure."

    (let ((float-wave (%valid-wave :format-tag 3 :bits 32)))
      ;; The binding refuses it, before CNA sees a byte.
      (is (eq 'xna:cna-argument-error (%from-stream-outcome float-wave))
          "an IEEE-float WAV is not a stream XNA's FromStream reads")
      ;; And CNA, handed the same bytes directly, decodes them -- which is what
      ;; makes the refusal above a narrowing rather than a coincidence.
      (cffi:with-foreign-object (raw :uint8 (length float-wave))
        (dotimes (i (length float-wave))
          (setf (cffi:mem-aref raw :uint8 i) (aref float-wave i)))
        (cffi:with-foreign-object (out :uint64)
          (let ((code (ffi::%sound-effect-create-from-encoded-ext
                       (int:handle-of game) raw (length float-wave) out)))
            (is (eql code ffi::+result-success+)
                "CNA decodes the IEEE-float WAV this binding refuses: ~
                 the refusal is the projection narrowing, not CNA agreeing")
            (when (eql code ffi::+result-success+)
              (ffi::%sound-effect-destroy (cffi:mem-ref out :uint64)))))))
    ;; And a tag neither reads, refused for the format reason.
    (is (eq 'xna:cna-argument-error
            (%from-stream-outcome (%valid-wave :format-tag 2 :bits 8)))
        "an ADPCM tag is refused by the format check"))

(define-audio-device-test a-malformed-wave-is-not-a-no-audio-hardware-failure
  "`CNA_RESULT_NOT_SUPPORTED' means two things -- no audio device, and bytes the
decoder cannot read -- and mapping both onto NO-AUDIO-HARDWARE-ERROR told a
program with a broken asset that its machine had no sound card. Since the wave is
parsed first, a malformed one never reaches the route, so it can no longer be
reported as missing hardware.

This runs on a machine that *has* a device, so a NO-AUDIO-HARDWARE-ERROR here
would be unambiguously wrong."

    (dolist (bytes (list (%valid-wave :format-tag 3 :bits 32)
                         (%valid-wave :sample-rate 96000)
                         (%valid-wave :channels 6)
                         (make-array 32 :element-type '(unsigned-byte 8)
                                        :initial-element 7)))
      (let ((outcome (%from-stream-outcome bytes)))
        (is (not (eq outcome 'audio:no-audio-hardware-error))
            "a malformed or unsupported wave must not be reported as missing hardware")
        (is (member outcome '(xna:cna-argument-error xna:cna-usage-error))
            "it is one of the two exceptions XNA's own parser produces, not a third"))))

;;; --- ContentManager.Unload while an instance is still playing ----------------

(defclass unload-with-instance-game (xna:game)
  ((effect :initform nil :accessor effect)
   (instance :initform nil :accessor instance)
   (unload-error :initform nil :accessor unload-error)
   (children-before :initform nil :accessor children-before)
   (children-after :initform nil :accessor children-after)
   (cache-after :initform nil :accessor cache-after))
  (:documentation
   "Loads a SoundEffect, makes an instance of it, and Unloads the manager."))

(defmethod xna:load-content ((game unload-with-instance-game))
  (let ((content (xna:content game)))
    (setf (xna.content:root-directory content) (%sound-content-root)
          (children-before game) (length (int:children-of game)))
    (handler-case
        (progn
          (setf (effect game)
                (xna.content:load-asset content 'audio:sound-effect "test-tone"))
          (setf (instance game) (audio:create-instance (effect game)))
          ;; The member under test. Nothing is disposed by hand first, which is
          ;; the whole point: the manager owns the effect, the effect owns the
          ;; instance, and Unload has to reach both.
          (xna.content:unload content))
      (error (condition) (setf (unload-error game) condition)))
    (setf (children-after game) (length (int:children-of game))
          (cache-after game)
          (hash-table-count (xna.content::%content-loaded-assets content))))
  (xna:exit game))

(define-native-test content-unload-releases-an-effect-and-its-live-instances
  "**The same question as direct disposal, reached along the other path.**

`ContentManager.Unload' disposes what it loaded, and what it loaded here is a
SoundEffect with a live SoundEffectInstance. XNA's `SoundEffect.Dispose' cascades,
so `Unload' cascades -- not because ContentManager knows anything about audio, but
because it calls the same `Dispose'. That is the property worth pinning: direct
disposal and Unload must not grow two ownership semantics, and they cannot here
because there is one implementation between them.

The postconditions are the ones that matter for the ABI rather than for XNA:
no instance handle left, no effect handle left, no game child left, an empty
cache, the instance observably disposed, and a game that can shut down. The last
is not decoration -- CNA refuses to destroy a game with live children, so a
handle left behind fails the teardown rather than this assertion."

  ;; Its own game, because the load has to happen inside LoadContent -- and CNA
  ;; permits one active game per process, so this cannot nest inside another.
  (let ((available (with-audio-game (probe) (audio-playback-available-p))))
    (if (not available)
        ;; With no device the load fails and there is no effect to cascade from,
        ;; which is a result rather than a skip: the unavailable branch of this
        ;; test is that Unload still leaves the game able to shut down.
        (let ((probe (make-instance 'unload-with-instance-game)))
          (unwind-protect (xna:run probe) (%tear-down-audio-game probe))
          (is (null (effect probe)) "no device, so nothing loaded")
          (is (eql (children-before probe) (children-after probe))
              "and a failed load left no child behind")
          (is (xna:disposed-p probe)))
        (let ((probe (make-instance 'unload-with-instance-game)))
          (unwind-protect (xna:run probe) (%tear-down-audio-game probe))
          (is (null (unload-error probe))
              "Unload with a live instance signalled: ~a" (unload-error probe))
          (is (audio:is-disposed (effect probe))
              "the effect the manager loaded was disposed")
          (is (audio:is-disposed (instance probe))
              "and so was the instance it owned, through the same cascade")
          (is (eql (children-before probe) (children-after probe))
              "no child handle is left for CNA to refuse the game's disposal over: ~
               ~d before the load, ~d after the unload"
              (children-before probe) (children-after probe))
          (is (eql 0 (cache-after probe))
              "and the manager's cache is empty")
          (signals xna:cna-disposed-error (audio:state (instance probe)))
          (is (xna:disposed-p probe)
              "the game shut down, which a leaked handle would have prevented")))))

;;; --- the overload shapes, which a keyword lambda list cannot enforce ---------

(define-native-test the-sound-effect-constructor-has-exactly-two-shapes
  "XNA has `SoundEffect(Byte[], Int32, AudioChannels)' and
`SoundEffect(Byte[], Int32, Int32, Int32, AudioChannels, Int32, Int32)' and
nothing between them. A `&key' lambda list with `(offset 0)' and `(loop-length 0)'
accepted everything between: `:OFFSET' on its own became the seven-argument
constructor with the rest defaulted, which is a call no XNA program can write.

Needs no device and no game: the shape is checked before either is resolved,
which is itself part of the contract -- an illegal shape is a usage error on any
machine rather than an audio failure on one without a sound card."
  (let ((buffer (pcm16-silence 100)))
    (flet ((refused-p (&rest initargs)
             (handler-case (progn (apply #'make-instance 'audio:sound-effect initargs)
                                  nil)
               (xna:cna-usage-error () :shape)
               (error () nil))))
      ;; the six partial combinations the task named, each refused for its shape
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000 :channels :mono
                                :offset 0)))
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000 :channels :mono
                                :count 4)))
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000 :channels :mono
                                :loop-start 0)))
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000 :channels :mono
                                :loop-length 0)))
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000 :channels :mono
                                :offset 0 :count 4)))
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000 :channels :mono
                                :offset 0 :count 4 :loop-start 0)))
      ;; a keyword belonging to no constructor at all, which &allow-other-keys
      ;; used to swallow
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000 :channels :mono
                                :gain 1.0)))
      ;; and a missing one
      (is (eq :shape (refused-p :buffer buffer :sample-rate 8000)))
      (is (eq :shape (refused-p :sample-rate 8000 :channels :mono)))
      ;; the two legal shapes are *not* refused for their shape: with no game
      ;; they fail later, which is what proves the shape check passed.
      (is (null (refused-p :buffer buffer :sample-rate 8000 :channels :mono))
          "the short constructor's shape is accepted")
      (is (null (refused-p :buffer buffer :offset 0 :count 4 :sample-rate 8000
                           :channels :mono :loop-start 0 :loop-length 0))
          "and the long one's"))))

(define-audio-device-test the-two-play-shapes-are-the-only-two
  "`SoundEffect.Play()' and `SoundEffect.Play(float, float, float)'. The three
settings are one indivisible overload: the method used to decide it had been
given the long form from whether `:VOLUME' was supplied and default the other two
to zero, which made six shapes out of two.

`SoundEffectInstance.Play()' takes nothing at all, and CLOS congruence forces its
method to *accept* the three names because the generic function is shared. It
refuses them by name instead of ignoring them, which is the same rule the
buffer/texture split in SET-DATA follows."

    (with-sound-effect (effect :buffer (pcm16-ramp 800)
                               :sample-rate 8000 :channels :mono)
      (let ((instance (audio:create-instance effect)))
        (unwind-protect
             (flet ((shape-refused-p (thunk)
                      (handler-case (progn (funcall thunk) nil)
                        (xna:cna-usage-error () :shape)
                        (error () nil))))
               ;; the two legal shapes
               (is (null (shape-refused-p (lambda () (audio:play effect)))))
               (is (null (shape-refused-p
                          (lambda () (audio:play effect :volume 1.0 :pitch 0.0
                                                        :pan 0.0)))))
               ;; the six that are neither
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play effect :volume 1.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play effect :pitch 0.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play effect :pan 0.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play effect :volume 1.0
                                                             :pitch 0.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play effect :volume 1.0
                                                             :pan 0.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play effect :pitch 0.0
                                                             :pan 0.0)))))
               ;; SoundEffectInstance.Play takes nothing, and says so
               (is (null (shape-refused-p (lambda () (audio:play instance)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play instance :volume 1.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play instance :pitch 0.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play instance :pan 0.0)))))
               (is (eq :shape (shape-refused-p
                               (lambda () (audio:play instance :volume 1.0
                                                               :pitch 0.0
                                                               :pan 0.0)))))
               ;; and the volume it was handed is not quietly applied
               (is (eql 1.0f0 (audio:volume instance))
                   "a refused (play instance :volume ...) changed nothing"))
          (xna:dispose instance)))))

;;; --- the sample-size boundary, which was documented and not implemented ------

(define-native-test the-sample-size-upper-bound-is-int32-maxvalue-milliseconds
  "`GetSampleSizeInBytes' has four guards and this binding implemented two.

The IL is `TotalMilliseconds < 0' then `!(TotalMilliseconds <= 2147483647)' --
`Int32.MaxValue' as a float64 -- then the sample rate, then the channels; and the
computation that follows is `checked', with `catch (OverflowException)' rethrowing
`ArgumentOutOfRangeException(\"duration\")'. The upper bound and the overflow were
both described in the docstring and neither existed, so a duration of a thousand
years answered a bignum.

`TotalMilliseconds' is `(double)ticks * 0.0001', so the largest accepted tick
count is 21474836470000 -- computed, not assumed: it multiplies to exactly
2147483647.0 and the tick above it to 2147483647.0001001."
  (flet ((size (d sr ch) (audio:sound-effect-get-sample-size-in-bytes d sr ch)))
    (is (eql 0 (size 0 8000 :mono)) "a zero duration is zero bytes")
    (signals xna:cna-argument-out-of-range-error (size -1 8000 :mono))
    ;; The two guards are distinguishable, and both are reachable.
    (is (search "tick count in"
                (handler-case (progn (size 21474836470001 8000 :mono) "")
                  (error (c) (princ-to-string c))))
        "one tick past the maximum is refused by the duration range guard")
    (is (search "outside Int32"
                (handler-case (progn (size 1342177280000 8000 :mono) "")
                  (error (c) (princ-to-string c))))
        "and a duration whose byte size overflows Int32 is refused as a duration")
    ;; The largest duration whose size still fits, and one millisecond more.
    (is (eql 2147483632 (size 1342177270000 8000 :mono))
        "the largest byte count Int32 can hold for this format")
    (signals xna:cna-argument-out-of-range-error (size 1342177280000 8000 :mono))
    (signals xna:cna-argument-out-of-range-error (size 21474836470000 8000 :mono))
    (signals xna:cna-argument-out-of-range-error (size 21474836470001 8000 :mono))
    ;; mono and stereo at both ends of the accepted sample-rate range
    (is (eql 16000 (size 10000000 8000 :mono)))
    (is (eql 32000 (size 10000000 8000 :stereo)))
    (is (eql 96000 (size 10000000 48000 :mono)))
    (is (eql 192000 (size 10000000 48000 :stereo)))
    ;; and the guard order: a call wrong in the duration *and* the rate reports
    ;; the duration, because TotalMilliseconds is tested first.
    (is (equal "duration"
               (handler-case (progn (size -1 7999 :mono) nil)
                 (xna:cna-argument-out-of-range-error (c)
                   (xna:cna-error-parameter-name c))))
        "the duration is checked before the sample rate")
    (is (equal "sample-rate"
               (handler-case (progn (size 10000 7999 :quadraphonic) nil)
                 (xna:cna-argument-out-of-range-error (c)
                   (xna:cna-error-parameter-name c))))
        "and the sample rate before the channels")))
