;;;; sound-effect.lisp --- Microsoft.Xna.Framework.Audio.SoundEffect.
;;;;
;;;; **XNA's constructors take no game, and neither do these.** CNA's creation
;;;; routes all take one -- `cna_sound_effect_create_pcm16_range_ext' takes a game
;;;; handle "for lifetime and creation-thread scope" -- and the gap is closed the
;;;; way `Keyboard.GetState' closes it: CNA permits one active game per process,
;;;; so there is exactly one game a constructor could mean, and CNA-Lisp resolves
;;;; it. Adding a `:game' initarg would change XNA's public API to accommodate
;;;; CNA, which is the one thing this projection does not do.
;;;;
;;;; **The validation is XNA's, transcribed from the IL, and the order matters.**
;;;; Every check below is `SoundEffect.FromBuffer' in the pinned assembly, in the
;;;; order that method performs them, because which exception a doubly-invalid
;;;; call gets is decided by the order. CNA validates too, and differently -- it
;;;; would answer `CNA_RESULT_INVALID_ARGUMENT' for most of these -- so the checks
;;;; run *before* the route rather than being inferred from it. Where the two
;;;; disagree, XNA wins publicly and `docs/limitations.md' records the difference.
;;;;
;;;; **One divergence worth naming here, because it is CNA's header that is
;;;; wrong about XNA.** `cna_sound_effect_play' documents "A disposed effect
;;;; answers `CNA_FALSE' rather than failing, which is the canonical behavior".
;;;; It is not: `SoundEffect.Play' opens with an `IsDisposed' test and throws
;;;; `ObjectDisposedException'. CNA-Lisp's disposal check runs first and signals
;;;; `CNA-DISPOSED-ERROR', so the public behaviour is XNA's and the route's
;;;; `CNA_FALSE' branch is never reached from here.

(in-package #:microsoft.xna.framework.audio)

;;; --- resolving the one active game ---------------------------------------

(defun %active-game (operation)
  "The process's one active game, or a refusal naming what is missing.

This is the same resolution `Keyboard.GetState' performs, and it exists for the
same reason: the XNA member takes no game and CNA's route needs one. A program
that has not created a game yet gets a condition that says so rather than a null
handle."
  (let ((game (cna-lisp.internal:active-game)))
    (unless game
      (error 'xna:cna-invalid-state-error
             :operation operation
             :format-control
             "~a needs a live game: XNA's audio API is process-global and CNA ~
              reaches audio through the active game, and there is none. Create a ~
              game before using SoundEffect. docs/limitations.md records this as ~
              a runtime projection limit."
             :format-arguments (list operation)))
    (cna-lisp.internal:check-usable game operation)
    game))

(defun %active-game-handle (operation)
  (cna-lisp.internal:handle-of (%active-game operation)))

;;; --- the result codes the audio surface gives its own conditions to -------

(defun %check-audio-result (code operation &key object-type (limit-is-play-limit nil))
  "CHECK-RESULT, with the two XNA-visible audio failures given their own classes.

Two CNA result codes mean something specific inside this namespace and generic
outside it, so they are translated here rather than in the shared result table:

  CNA_RESULT_NOT_SUPPORTED   from a creation route  -> NO-AUDIO-HARDWARE-ERROR
  CNA_RESULT_INVALID_STATE   from a play route      -> INSTANCE-PLAY-LIMIT-ERROR

LIMIT-IS-PLAY-LIMIT gates the second, because `CNA_RESULT_INVALID_STATE' is also
what a refused `IS-LOOPED' setter and a mis-ordered `APPLY-3D' answer, and
neither of those is a play limit. Only the two play routes pass it.

Everything else goes to CHECK-RESULT unchanged, so a generic native failure stays
the generic condition it is -- which is the distinction the qualification has to
prove."
  (cond
    ((= code cna-lisp.internal.ffi::+result-success+) t)
    ((= code cna-lisp.internal.ffi::+result-not-supported+)
     (error 'no-audio-hardware-error
            :operation operation :object-type object-type
            :%result code
            :native-message (cna-lisp.internal:last-native-message)))
    ((and limit-is-play-limit
          (= code cna-lisp.internal.ffi::+result-invalid-state+))
     (error 'instance-play-limit-error
            :operation operation :object-type object-type
            :%result code
            :native-message (cna-lisp.internal:last-native-message)))
    (t (cna-lisp.internal:check-result code operation :object-type object-type))))

;;; --- the class -------------------------------------------------------------

(defclass sound-effect (cna-lisp.internal:native-object)
  ((duration :reader duration
             :documentation "The TimeSpan this effect plays for, read once at construction.")
   (%instances :initform '() :accessor %sound-effect-instances
               :documentation "Live SOUND-EFFECT-INSTANCEs, for ordered teardown."))
  (:documentation
   "Microsoft.Xna.Framework.Audio.SoundEffect: a decoded sound, and the source of instances.

Two public constructors, both taking PCM16 bytes:

    (make-instance 'sound-effect :buffer bytes :sample-rate 22050 :channels :mono)
    (make-instance 'sound-effect :buffer bytes :offset 0 :count 4410
                                 :sample-rate 22050 :channels :stereo
                                 :loop-start 0 :loop-length 0)

and a third way in, `SOUND-EFFECT-FROM-STREAM', which is XNA's static
`FromStream' over an ordinary Common Lisp binary stream. Neither constructor
takes a game: see the file header.

The effect is a child of the active game and the parent of every instance it
creates. CNA requires that ordering -- \"destroyed after all instances created
from it and before the game\" -- and this binding enforces it before the ABI
does, so a wrong order is a condition naming both types rather than a native
failure later.

`sealed' in XNA. CLOS has no `sealed', so a subclass is possible; the
construction ledger makes a failing subclass initializer give the handle back."))

;;; --- constructor validation, transcribed ----------------------------------

(defconstant +minimum-sample-rate+ 8000
  "SoundEffect's lowest accepted sample rate: `0x1f40' in the pinned IL.")
(defconstant +maximum-sample-rate+ 48000
  "SoundEffect's highest accepted sample rate: `0xbb80' in the pinned IL.")

(defun %check-sample-rate (sample-rate operation)
  "`sampleRate < 8000 || sampleRate > 48000' -> ArgumentOutOfRangeException(\"sampleRate\")."
  (unless (and (integerp sample-rate)
               (<= +minimum-sample-rate+ sample-rate +maximum-sample-rate+))
    (error 'xna:cna-argument-out-of-range-error
           :operation operation :parameter-name "sample-rate"
           :object-type 'sound-effect
           :format-control
           "sample-rate must be an integer in [~d, ~d]; ~s was given."
           :format-arguments (list +minimum-sample-rate+ +maximum-sample-rate+ sample-rate))))

(defun %check-channels (channels operation)
  "`channels < 1 || channels > 2' -> ArgumentOutOfRangeException(\"channels\").

The projection makes this a keyword, so a value outside the enumeration cannot be
spelled at all; the check is still here because a caller can pass a non-member
keyword and XNA's answer to an out-of-range channel count is this exception rather
than a type error."
  (unless (typep channels 'audio-channels)
    (error 'xna:cna-argument-out-of-range-error
           :operation operation :parameter-name "channels"
           :object-type 'sound-effect
           :format-control "channels must be :MONO or :STEREO; ~s was given."
           :format-arguments (list channels))))

(defun %check-buffer (buffer block-align operation)
  "`buffer == null || buffer.Length == 0 || !IsAligned(buffer.Length)'
-> ArgumentException(InvalidAudioBuffer)."
  (unless (and buffer
               (typep buffer '(vector (unsigned-byte 8)))
               (plusp (length buffer))
               (zerop (mod (length buffer) block-align)))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "buffer"
           :object-type 'sound-effect
           :format-control
           "buffer must be a non-empty (VECTOR (UNSIGNED-BYTE 8)) whose length is a ~
            whole number of ~d-byte sample frames; ~@[~d byte(s) were given~]."
           :format-arguments
           (list block-align (when (typep buffer 'vector) (length buffer))))))

(defun %check-offset (offset buffer block-align operation)
  "`offset < 0 || offset >= buffer.Length || !IsAligned(offset)'
-> ArgumentException(InvalidAudioBufferOffset)."
  (unless (and (integerp offset)
               (<= 0 offset)
               (< offset (length buffer))
               (zerop (mod offset block-align)))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "offset"
           :object-type 'sound-effect
           :format-control
           "offset must be a sample-frame-aligned index in [0, ~d); ~s was given."
           :format-arguments (list (length buffer) offset))))

(defun %check-count (offset count buffer block-align operation)
  "`offset + count > buffer.Length || count <= 0 || !IsAligned(count)'
-> ArgumentException(InvalidOffsetCountLength).

XNA reaches the same exception two ways: a `checked' overflow adding offset to
count, and the range test that follows it. Lisp integers do not overflow, so the
arithmetic cannot trap; the range test is what remains and it refuses everything
the overflow would have."
  (unless (and (integerp count)
               (plusp count)
               (zerop (mod count block-align))
               (<= (+ offset count) (length buffer)))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "count"
           :object-type 'sound-effect
           :format-control
           "count must be a positive whole number of ~d-byte sample frames with ~
            offset + count <= ~d; offset ~s and count ~s were given."
           :format-arguments (list block-align (length buffer) offset count))))

(defun %check-loop-region (loop-start loop-length sample-frames operation)
  "`loopStart < 0 || loopLength < 0 || loopStart + loopLength > sampleFrames'
-> ArgumentException(InvalidLoopRegion).

SAMPLE-FRAMES is `count / BlockAlign', which is the unit the loop region is
measured in -- frames, not bytes. Answers the pair XNA substitutes when
`loopLength' is zero: the whole range."
  (unless (and (integerp loop-start) (integerp loop-length)
               (<= 0 loop-start) (<= 0 loop-length)
               (<= (+ loop-start loop-length) sample-frames))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "loop-length"
           :object-type 'sound-effect
           :format-control
           "the loop region must be non-negative and lie inside the ~d sample ~
            frame(s) the range holds; loop-start ~s and loop-length ~s were given."
           :format-arguments (list sample-frames loop-start loop-length)))
  ;; "if (loopLength == 0) { loopStart = 0; loopLength = sampleFrames; }"
  (if (zerop loop-length)
      (values 0 sample-frames)
      (values loop-start loop-length)))

;;; --- construction ----------------------------------------------------------

(defun %adopt-sound-effect (effect game handle)
  "Take ownership of HANDLE, recording both halves in the construction ledger."
  (cna-lisp.internal:record-construction-undo
   effect (lambda () (cna-lisp.internal.ffi::%sound-effect-destroy handle)))
  (setf (cna-lisp.internal:handle-of effect) handle
        (slot-value effect 'cna-lisp.internal::owner) game
        (slot-value effect 'cna-lisp.internal::owner-thread)
        (cna-lisp.internal:owner-thread-of game))
  (cna-lisp.internal:register-child game effect)
  (cna-lisp.internal:record-construction-undo
   effect (lambda () (cna-lisp.internal:invalidate effect)))
  effect)

(defgeneric %read-sound-effect-duration (effect handle operation)
  (:documentation
   "Read the effect's duration back, after its handle exists.

A generic function on unspecialised arguments for the reason
%READ-FONT-GLYPH-TABLE is one: this is the step that runs *after* the native
handle has been acquired, which makes it the window a failure-injection test has
to be able to open. Nothing public overrides it.")
  (:method (effect handle operation)
    (declare (ignore effect))
    (cffi:with-foreign-object (ticks :int64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%sound-effect-get-duration-ticks handle ticks)
       operation :object-type 'sound-effect)
      (cffi:mem-ref ticks :int64))))

(defmethod initialize-instance :after
    ((effect sound-effect)
     &key buffer (offset 0) (count nil count-supplied) sample-rate channels
          (loop-start 0) (loop-length 0) (%handle nil))
  "SoundEffect(byte[], int, AudioChannels) and its seven-argument sibling.

Both XNA constructors funnel into `FromBuffer', so both funnel into this: the
three-argument form is this one with `offset' 0, `count' the buffer's length and
an empty loop region, which is exactly the argument list XNA's three-argument
constructor passes down. The one thing the short constructor does *first* is
reject a null or empty buffer with `ArgumentException' before any other check --
and %CHECK-BUFFER answers the same exception for the same inputs, so the
distinction does not survive into the projection.

%HANDLE is the private path `ContentManager.Load<SoundEffect>' and
`FromStream' arrive by: the handle already exists and only the adoption and the
duration read remain."
  (let ((operation "make-instance sound-effect"))
    (if %handle
        (let ((game (%active-game operation)))
          (%adopt-sound-effect effect game %handle)
          (setf (slot-value effect 'duration)
                (%read-sound-effect-duration effect %handle operation)))
        (let* ((game (%active-game operation)))
          (%check-sample-rate sample-rate operation)
          (%check-channels channels operation)
          (let ((block-align (%block-align channels)))
            (%check-buffer buffer block-align operation)
            (let ((count (if count-supplied count (length buffer))))
              (%check-offset offset buffer block-align operation)
              (%check-count offset count buffer block-align operation)
              (multiple-value-bind (start len)
                  (%check-loop-region loop-start loop-length
                                      (floor count block-align) operation)
                (%create-sound-effect effect game buffer offset count sample-rate
                                      channels start len operation))))))))

(defun %create-sound-effect (effect game buffer offset count sample-rate channels
                             loop-start loop-length operation)
  "Call the canonical seven-argument creation route and adopt what it answers."
  (let ((length (length buffer)))
    (cffi:with-foreign-object (pcm :uint8 length)
      (dotimes (i length)
        (setf (cffi:mem-aref pcm :uint8 i) (aref buffer i)))
      (cffi:with-foreign-object
          (info '(:struct cna-lisp.internal.ffi::cna-sound-effect-create-info))
        (cffi:foreign-funcall
         "memset" :pointer info :int 0
         :size cna-lisp.internal.ffi::+sizeof-cna-sound-effect-create-info+ :void)
        (macrolet ((slot (name)
                     `(cffi:foreign-slot-value
                       info '(:struct cna-lisp.internal.ffi::cna-sound-effect-create-info)
                       ',name)))
          (setf (slot cna-lisp.internal.ffi::struct-size)
                cna-lisp.internal.ffi::+sizeof-cna-sound-effect-create-info+
                (slot cna-lisp.internal.ffi::struct-version) 1
                (slot cna-lisp.internal.ffi::sample-rate) sample-rate
                (slot cna-lisp.internal.ffi::channels) (audio-channels-value channels)
                (slot cna-lisp.internal.ffi::reserved) 0))
        (cffi:with-foreign-object (out :uint64)
          (%check-audio-result
           (cna-lisp.internal.ffi::%sound-effect-create-pcm-16-range-ext
            (cna-lisp.internal:handle-of game) info pcm length
            offset count loop-start loop-length out)
           operation :object-type 'sound-effect)
          (let ((handle (cffi:mem-ref out :uint64)))
            (%adopt-sound-effect effect game handle)
            (setf (slot-value effect 'duration)
                  (%read-sound-effect-duration effect handle operation))))))))

;;; --- FromStream ------------------------------------------------------------

(defun sound-effect-from-stream (stream)
  "SoundEffect.FromStream(Stream).

STREAM is an ordinary Common Lisp binary stream, which is what `System.IO.Stream'
projects onto here -- see `docs/limitations.md'. XNA reads it to the end and
decodes whatever it holds; `cna_sound_effect_create_from_encoded_ext' takes the
bytes CNA would have read, because \"the canonical operation takes a C++ stream
and reads it to the end, so C takes the bytes it would have read\".

Whatever the audio backend can decode is accepted, which is more than the raw
PCM the constructors take. A payload it cannot decode answers
`CNA_RESULT_NOT_SUPPORTED', which is the same code a machine with no audio device
answers -- so this signals NO-AUDIO-HARDWARE-ERROR for both, and the condition's
report carries CNA's own message, which distinguishes them."
  (let* ((operation "sound-effect-from-stream")
         (game (%active-game operation))
         (bytes (xna::%read-stream-octets stream operation)))
    (when (zerop (length bytes))
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "stream"
             :object-type 'sound-effect
             :format-control
             "the stream held no bytes. CNA's decode route refuses a zero byte ~
              count, and there is nothing for XNA's decoder to read either."))
    (cffi:with-foreign-object (raw :uint8 (length bytes))
      (dotimes (i (length bytes))
        (setf (cffi:mem-aref raw :uint8 i) (aref bytes i)))
      (cffi:with-foreign-object (out :uint64)
        (%check-audio-result
         (cna-lisp.internal.ffi::%sound-effect-create-from-encoded-ext
          (cna-lisp.internal:handle-of game) raw (length bytes) out)
         operation :object-type 'sound-effect)
        (make-instance 'sound-effect :%handle (cffi:mem-ref out :uint64))))))

;;; --- readers ---------------------------------------------------------------

(defmethod is-disposed ((effect sound-effect))
  "SoundEffect.IsDisposed.

Answered from this binding's own disposal state, not from
`cna_sound_effect_get_is_disposed': the handle is gone once DISPOSE has run, so
there would be nothing left to ask. A test asserts the two agree while the object
is alive."
  (and (cna-lisp.internal:disposed-state-of effect) t))

(defmethod name ((effect sound-effect))
  "SoundEffect.Name's getter. XNA initialises it to String.Empty, and so does CNA."
  (let ((operation "name"))
    (cna-lisp.internal:check-usable effect operation)
    (cna-lisp.internal:count-then-copy-string
     (lambda (out-bytes)
       (cna-lisp.internal.ffi::%sound-effect-get-name-size
        (cna-lisp.internal:handle-of effect) out-bytes))
     (lambda (destination capacity out-bytes)
       (cna-lisp.internal.ffi::%sound-effect-copy-name
        (cna-lisp.internal:handle-of effect) destination capacity out-bytes))
     operation)))

(defmethod (setf name) (value (effect sound-effect))
  "SoundEffect.Name's setter. XNA's is a bare `stfld' and takes any string."
  (let ((operation "setf name"))
    (check-type value string)
    (cna-lisp.internal:check-usable effect operation)
    (cna-lisp.internal:with-utf8-view (bytes length value)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%sound-effect-set-name
        (cna-lisp.internal:handle-of effect) bytes length)
       operation :object-type 'sound-effect))
    value))

;;; --- Play ------------------------------------------------------------------

(defmethod play ((effect sound-effect) &key (volume nil volume-supplied) pitch pan)
  "SoundEffect.Play() and SoundEffect.Play(float, float, float).

One generic function with an optional settings triple, because XNA gives the two
overloads one name and the no-argument form is exactly
`Play(1.0f, 0.0f, 0.0f)' -- which is what its IL does, and what this does when
no settings are given.

Answers T when playback started and NIL when it did not. A disposed effect
signals `CNA-DISPOSED-ERROR' rather than answering NIL: CNA's route documents the
`CNA_FALSE' answer as canonical and it is not -- `SoundEffect.Play' opens with an
`IsDisposed' test and throws. See the file header.

`INSTANCE-PLAY-LIMIT-ERROR' is signalled when the platform's voice limit is
reached, which is XNA's `InstancePlayLimitException'. The asymmetry in the
three-argument form is CNA's and XNA's alike: **pan is range-checked and pitch is
clamped**, so a pan outside [-1, 1] is refused and a pitch outside it is not."
  (let ((operation "play"))
    (cna-lisp.internal:check-usable effect operation)
    (cffi:with-foreign-object (played :uint32)
      (%check-audio-result
       (cna-lisp.internal:with-binary32-semantics
        (if volume-supplied
           (let ((v (xna::f volume)) (p (xna::f (or pitch 0.0f0)))
                 (n (xna::f (or pan 0.0f0))))
             (when (or (cna-lisp.internal:nan-p n) (< n -1.0f0) (> n 1.0f0))
               (error 'xna:cna-argument-out-of-range-error
                      :operation operation :parameter-name "pan"
                      :object-type 'sound-effect
                      :format-control "pan must be in [-1, 1]; ~a was given."
                      :format-arguments (list n)))
             (cna-lisp.internal.ffi::%sound-effect-play-with-settings
              (cna-lisp.internal:handle-of effect) v p n played))
           (cna-lisp.internal.ffi::%sound-effect-play
            (cna-lisp.internal:handle-of effect) played)))
       operation :object-type 'sound-effect :limit-is-play-limit t)
      (not (zerop (cffi:mem-ref played :uint32))))))

;;; --- CreateInstance --------------------------------------------------------

(defmethod create-instance ((effect sound-effect))
  "SoundEffect.CreateInstance().

Answers a SOUND-EFFECT-INSTANCE that is a child of this effect. CNA's route makes
the same relation -- \"an explicitly ordered C child: destroy it before its sound
effect\" -- so the instance must be disposed before the effect and the effect
before the game."
  (cna-lisp.internal:check-usable effect "create-instance")
  (make-instance 'sound-effect-instance :sound-effect effect))

;;; --- disposal --------------------------------------------------------------

(defmethod cna-lisp.internal:destroy-native ((effect sound-effect))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%sound-effect-destroy (cna-lisp.internal:handle-of effect))
   "dispose" :object-type 'sound-effect))

;;; --- the two static sample computations ------------------------------------
;;;
;;; **These are computed here, not through CNA, and that is a measurement rather
;;; than a preference.** `cna_sound_effect_get_sample_duration_ticks' truncates to
;;; whole milliseconds and XNA does not: measured against 0.21.0, 200 bytes of
;;; mono PCM16 at 8000 Hz answers 120000 ticks through the route and **125000**
;;; through XNA's own arithmetic, which is the exact 12.5 ms the buffer holds. The
;;; effect's *own* duration route agrees with XNA to the tick, so the divergence
;;; is in this one computation and not in CNA's audio generally.
;;;
;;; So the projection does what the math types do: "CNA has routes for all of it,
;;; and using them would make the binding's arithmetic CNA's rather than XNA's".
;;; The two routes stay bound and `tests/native/audio.lisp' pins **both sides**, so
;;; a corrected CNA fails a test rather than passing silently -- the same treatment
;;; `DepthStencilState''s stencil masks get.
;;;
;;; Transcribed from `AudioFormat.DurationFromSize' and `SizeFromDuration', in the
;;; order they compute, binary32 where the IL is binary32:
;;;
;;;   DurationFromSize:  frames = size / blockAlign         (integer division)
;;;                      ms     = (float32)frames * 1000f / (float32)sampleRate
;;;                      ticks  = TimeSpan.FromMilliseconds(ms)
;;;
;;;   SizeFromDuration:  n      = (int)(totalMs * (float32)(sampleRate / 1000f))
;;;                      bytes  = (n + n % channels) * blockAlign
;;;
;;; Neither takes a game: XNA's are static and this needs no CNA at all.

(defun %ticks-from-milliseconds (milliseconds)
  "System.TimeSpan.FromMilliseconds, which rounds half away from zero.

.NET computes `(long)(value * TicksPerMillisecond + (value >= 0 ? 0.5 : -0.5))'.
The rounding is why 12.5 ms is exactly 125000 ticks rather than 124999, and why
truncating -- which is what CNA's route does -- is a different answer."
  (let ((scaled (* (coerce milliseconds 'double-float) 10000.0d0)))
    (truncate (+ scaled (if (minusp scaled) -0.5d0 0.5d0)))))

(defun sound-effect-get-sample-duration (size-in-bytes sample-rate channels)
  "SoundEffect.GetSampleDuration(int, int, AudioChannels), in 100-nanosecond ticks.

TimeSpan is projected as an exact tick count throughout this binding rather than
as a type, so this answers an integer. A size of zero answers zero, which is
`TimeSpan.Zero' and XNA's own early return."
  (let ((operation "sound-effect-get-sample-duration"))
    (unless (and (integerp size-in-bytes) (<= 0 size-in-bytes))
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "size-in-bytes"
             :object-type 'sound-effect
             :format-control "size-in-bytes must not be negative; ~s was given."
             :format-arguments (list size-in-bytes)))
    (%check-sample-rate sample-rate operation)
    (%check-channels channels operation)
    (if (zerop size-in-bytes)
        0
        (let* ((frames (floor size-in-bytes (%block-align channels)))
               (milliseconds (xna::f (/ (* (xna::f frames) 1000.0f0)
                                        (xna::f sample-rate)))))
          (%ticks-from-milliseconds milliseconds)))))

(defun sound-effect-get-sample-size-in-bytes (duration sample-rate channels)
  "SoundEffect.GetSampleSizeInBytes(TimeSpan, int, AudioChannels).

DURATION is a tick count, for the reason GetSampleDuration answers one. XNA
refuses a negative duration and one longer than its own maximum with
`ArgumentOutOfRangeException'; a zero duration answers zero bytes."
  (let ((operation "sound-effect-get-sample-size-in-bytes"))
    (unless (and (integerp duration) (<= 0 duration))
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name "duration"
             :object-type 'sound-effect
             :format-control "duration must not be negative; ~s was given."
             :format-arguments (list duration)))
    (%check-sample-rate sample-rate operation)
    (%check-channels channels operation)
    (if (zerop duration)
        0
        (let* ((total-milliseconds (/ (coerce duration 'double-float) 10000.0d0))
               (per-millisecond (xna::f (/ (xna::f sample-rate) 1000.0f0)))
               (n (truncate (* total-milliseconds (coerce per-millisecond 'double-float))))
               (channel-count (%channel-count channels)))
          (* (+ n (mod n channel-count)) (%block-align channels))))))

;;; --- the four process-wide statics -----------------------------------------
;;;
;;; XNA's are `static' properties over `static' fields, and CNA's routes are
;;; process-wide too: its header calls them "canonical **statics**: they belong to
;;; the process, not to a sound effect, and the game handle is taken for thread
;;; affinity only". So the game the value is read through does not own it, and the
;;; projection is four `SETF'-able package functions, which is what the naming
;;; rule makes a static member of a non-static class.
;;;
;;; The validation is XNA's and each of the four is different. Read from the IL,
;;; and the NaN answers are the part worth stating, because three of the four
;;; compare with an *unordered* branch and one does not:
;;;
;;;   MasterVolume   [0, 1]     NaN throws     (blt.un / bgt.un to the throw)
;;;   DopplerScale   [0, inf)   NaN throws     (blt.un to the throw)
;;;   SpeedOfSound   (0, inf)   NaN throws     (ble.un to the throw)
;;;   DistanceScale  [0, inf)   NaN **stored** (bge.un to the accepting branch)
;;;
;;; and DistanceScale alone then clamps: a value at or below `float.Epsilon'
;;; becomes `float.Epsilon', because a zero distance scale would divide by zero
;;; in the attenuation. A test pins all four, NaN included.

(defmacro %define-audio-static (name route-get route-set docstring &body validate)
  "Define one of SoundEffect's four process-wide static properties."
  `(progn
     (defun ,name ()
       ,docstring
       (let ((operation ,(string-downcase (symbol-name name))))
         (cffi:with-foreign-object (out :float)
           ;; NOT_SUPPORTED reaches these too on a machine with no audio device,
           ;; and XNA's own static setters route their error code through
           ;; `Helpers.ThrowExceptionFromErrorCode', which is where
           ;; NoAudioHardwareException is built. So the same mapping applies here.
           (%check-audio-result
            (,route-get (%active-game-handle operation) out) operation
            :object-type 'sound-effect)
           (cffi:mem-ref out :float))))
     (defun (setf ,name) (value)
       ,docstring
       ;; Each guard tests for a NaN **explicitly** rather than letting a
       ;; comparison decide. XNA's guards branch on unordered comparisons, so
       ;; whether a NaN is refused is a per-property fact and not a side effect;
       ;; writing it out is what makes the three that refuse and the one that
       ;; stores legible side by side. It also keeps the check independent of the
       ;; FPU trap state, which masking alone does not: SBCL leaves the invalid
       ;; flag accrued after a masked comparison, so the *next* operation traps
       ;; once traps come back on.
       (let* ((operation ,(format nil "setf ~(~a~)" (symbol-name name)))
              (v (xna::f value)))
         (declare (ignorable operation))
         (setf v (progn ,@validate))
         ;; The **route call** is what needs the traps masked, not the guard
         ;; above. `DistanceScale' stores a NaN, so a NaN crosses into C -- and
         ;; CNA then does binary32 arithmetic with it and raises the IEEE invalid
         ;; operation in hardware. SBCL leaves FP traps enabled, so that hardware
         ;; exception surfaces here as FLOATING-POINT-INVALID-OPERATION out of a
         ;; foreign call, which is not a condition this API may signal: the CLR
         ;; masks these, XNA stores the NaN, and so must this. Measured, not
         ;; guessed -- the trap reproduces from a bare `setf' with no Lisp
         ;; comparison anywhere in the path.
         (cna-lisp.internal:with-binary32-semantics
           (%check-audio-result
            (,route-set (%active-game-handle operation) v) operation
            :object-type 'sound-effect))
         v))))

(defun %refuse-static (operation value control &rest arguments)
  (error 'xna:cna-argument-out-of-range-error
         :operation operation :parameter-name "value" :object-type 'sound-effect
         :format-control control
         :format-arguments (append arguments (list value))))

(%define-audio-static sound-effect-master-volume
    cna-lisp.internal.ffi::%sound-effect-get-master-volume
    cna-lisp.internal.ffi::%sound-effect-set-master-volume
  "SoundEffect.MasterVolume: the process-wide volume every effect is scaled by.

Accepts [0, 1]. Refuses everything outside it **and NaN**, which XNA refuses
because its range test branches on an unordered comparison. Defaults to 1.0."
  (when (or (cna-lisp.internal:nan-p v) (< v 0.0f0) (> v 1.0f0))
    (%refuse-static operation v "MasterVolume must be in [0, 1] and not NaN; ~a was given."))
  v)

(%define-audio-static sound-effect-distance-scale
    cna-lisp.internal.ffi::%sound-effect-get-distance-scale
    cna-lisp.internal.ffi::%sound-effect-set-distance-scale
  "SoundEffect.DistanceScale: the process-wide 3D distance scale. Defaults to 1.0.

Refuses a negative value. **Accepts NaN**, alone among the four, because XNA's
guard is `bge.un' and a NaN takes its accepting branch -- and then survives the
clamp below, whose comparison is ordered. A value in [0, float.Epsilon] is raised
to `float.Epsilon' rather than refused, because a zero scale would divide by zero
in the attenuation."
  ;; The one guard of the four that lets a NaN through, and then the clamp lets
  ;; it through too: XNA's `bge.un' accepts it and the `ble' that follows is
  ;; ordered, so a NaN is stored unchanged.
  (cond ((cna-lisp.internal:nan-p v) v)
        ((< v 0.0f0)
         (%refuse-static operation v "DistanceScale must not be negative; ~a was given."))
        ((<= v least-positive-single-float) least-positive-single-float)
        (t v)))

(%define-audio-static sound-effect-doppler-scale
    cna-lisp.internal.ffi::%sound-effect-get-doppler-scale
    cna-lisp.internal.ffi::%sound-effect-set-doppler-scale
  "SoundEffect.DopplerScale: the process-wide Doppler multiplier. Defaults to 1.0.

Refuses a negative value **and NaN**. Zero is accepted, and so is infinity. Note
that `AudioEmitter.DopplerScale' -- the per-emitter one -- has the same range and
the opposite NaN answer; both are read from the IL and both are pinned."
  (when (or (cna-lisp.internal:nan-p v) (< v 0.0f0))
    (%refuse-static operation v "DopplerScale must not be negative or NaN; ~a was given."))
  v)

(%define-audio-static sound-effect-speed-of-sound
    cna-lisp.internal.ffi::%sound-effect-get-speed-of-sound
    cna-lisp.internal.ffi::%sound-effect-set-speed-of-sound
  "SoundEffect.SpeedOfSound: the process-wide speed of sound. Defaults to 343.5.

Refuses zero, a negative value **and NaN**: XNA's guard is `ble.un', so the only
accepted values are strictly positive. 343.5 is XNA's own static initialiser and
CNA's own default, measured to agree."
  (when (or (cna-lisp.internal:nan-p v) (<= v 0.0f0))
    (%refuse-static operation v "SpeedOfSound must be strictly positive; ~a was given."))
  v)
