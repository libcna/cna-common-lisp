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

(defun %check-buffer-presence (buffer operation)
  "`buffer == null || buffer.Length == 0' -> ArgumentException(InvalidAudioBuffer).

The three-argument constructor's **own** check, which runs before it calls
`FromBuffer' and therefore before FromBuffer's sample-rate test. That ordering is
observable: `new(null, 1, AudioChannels.Mono)' is an `ArgumentException' about
the buffer in XNA, not an `ArgumentOutOfRangeException' about the rate. The
seven-argument constructor has no such pre-check and takes FromBuffer's order.

%CHECK-BUFFER repeats the same two tests later, and adds the alignment one; this
is not redundant, it is the earlier of two different positions in the order."
  (unless (and buffer
               (typep buffer '(vector (unsigned-byte 8)))
               (plusp (length buffer)))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "buffer"
           :object-type 'sound-effect
           :format-control
           "buffer must be a non-empty (VECTOR (UNSIGNED-BYTE 8)); ~
            ~:[nothing~;~:*~s~] was given."
           :format-arguments (list buffer))))

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

(defparameter *sound-effect-constructor-overloads*
  '((:short "buffer" "sample-rate" "channels")
    (:long "buffer" "offset" "count" "sample-rate" "channels"
           "loop-start" "loop-length"))
  "XNA's two public SoundEffect constructors, as the keyword sets that spell them.

    SoundEffect(Byte[], Int32, AudioChannels)
    SoundEffect(Byte[], Int32, Int32, Int32, AudioChannels, Int32, Int32)

There is nothing between them. `:OFFSET' alone, `:COUNT' alone, `:OFFSET' with
`:COUNT' and no loop region, and every other partial combination are call shapes
XNA has not got, and %CHECK-OVERLOAD-KEYWORDS refuses each of them rather than
defaulting the difference -- which is what a `&key' lambda list with `(offset 0)'
and `(loop-length 0)' did instead, quietly turning four illegal calls into the
seven-argument constructor.")

(defparameter *native-object-initargs*
  '(:handle :ownership :owner :owner-generation :owner-thread :%known-duration)
  "The private initargs, which are not part of any XNA constructor.

They are how a handle CNA already gave us is adopted -- `ContentManager.Load' and
`FromStream' both arrive that way -- so the exact-shape check has to be able to
tell an adoption from a public call rather than refusing everything that is not
one of XNA's two shapes. Making internal construction impossible would be a worse
bug than the one being fixed.")

(defun %sound-effect-supplied-initargs (initargs)
  "The keywords of INITARGS that belong to a public constructor, as strings.

Anything NATIVE-OBJECT declares is filtered out; everything else is a keyword the
caller chose, including one no constructor names -- which is the case a bare
`&allow-other-keys' swallowed."
  (loop for (key nil) on initargs by #'cddr
        unless (member key *native-object-initargs*)
          collect (string-downcase (symbol-name key))))

(defun %check-overload-shape (operation supplied)
  "Which of XNA's two constructors SUPPLIED names, or a refusal naming both."
  (xna::%check-overload-keywords operation supplied
                                 *sound-effect-constructor-overloads*
                                 :object-type 'sound-effect))

(defmethod initialize-instance :after
    ((effect sound-effect)
     &rest initargs
     &key buffer (offset 0) count sample-rate channels
          (loop-start 0) (loop-length 0)
          ((:%known-duration known-duration) nil) &allow-other-keys)
  "SoundEffect(byte[], int, AudioChannels) and its seven-argument sibling.

Both XNA constructors funnel into `FromBuffer', so both funnel into this: the
three-argument form is this one with `offset' 0, `count' the buffer's length and
an empty loop region, which is exactly the argument list XNA's three-argument
constructor passes down. The one thing the short constructor does *first* is
reject a null or empty buffer with `ArgumentException' before any other check --
and %CHECK-BUFFER answers the same exception for the same inputs, so the
distinction does not survive into the projection.

**An effect that already has a handle is being adopted, not constructed.** That
is the path `ContentManager.Load<SoundEffect>' and `FromStream' arrive by: the
caller received the handle from CNA and has already recorded its destruction in
its own ledger, so nothing here may record it a second time -- see
%ADOPT-LOADED-SOUND-EFFECT. All that is left is the duration, which is read once
and kept, because XNA's `Duration' is a field its constructor fills in."
  (let ((operation "make-instance sound-effect")
        (supplied (%sound-effect-supplied-initargs initargs)))
    (if (plusp (cna-lisp.internal:handle-of effect))
        (progn
          ;; An adoption carries no constructor argument, and one supplied here
          ;; would be silently ignored -- the handle already decides the format.
          (when supplied
            (error 'xna:cna-usage-error
                   :operation operation :object-type 'sound-effect
                   :format-control
                   "a SOUND-EFFECT built over a handle CNA has already produced ~
                    takes none of XNA's constructor arguments, and ~{:~a~^, ~} ~
                    would be ignored. That path is FromStream's and the content ~
                    loader's; a program builds one with :BUFFER."
                   :format-arguments (list (mapcar #'string-upcase supplied))))
          (setf (slot-value effect 'duration)
                (or known-duration
                    (%read-sound-effect-duration
                     effect (cna-lisp.internal:handle-of effect) operation))))
        (let ((shape (%check-overload-shape operation supplied)))
          ;; The short constructor rejects a null or empty buffer *before*
          ;; FromBuffer runs, so it beats the sample rate: `new(null, 1, :MONO)'
          ;; is ArgumentException there and would be ArgumentOutOfRangeException
          ;; if this were left to FromBuffer's order. The long one has no such
          ;; pre-check and takes FromBuffer's order exactly.
          (when (eq shape :short) (%check-buffer-presence buffer operation))
          (%check-sample-rate sample-rate operation)
          (%check-channels channels operation)
          (let ((block-align (%block-align channels)))
            (%check-buffer buffer block-align operation)
            (let ((count (if (eq shape :long) count (length buffer)))
                  (game (%active-game operation)))
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
            ;; **Computed, not read.** See %READ-SOUND-EFFECT-DURATION: XNA's
            ;; constructor fills `Duration' in from `AudioFormat.DurationFromSize'
            ;; -- the same computation `GetSampleDuration' is -- and CNA's route
            ;; answers an exact tick count where XNA quantises to a whole
            ;; millisecond. The format is known here, so the exact answer is
            ;; available and there is no reason to take the approximate one.
            (setf (slot-value effect 'duration)
                  (sound-effect-get-sample-duration count sample-rate channels))))))))

(defun %adopt-loaded-sound-effect (game handle record &optional known-duration)
  "Build the CLOS SoundEffect over a handle the caller's transaction already owns.

RECORD is that transaction's recorder, and the division of labour is the rule
that keeps one asset load to one ledger:

  **whoever receives a handle from CNA records its destruction.**

This function did not receive HANDLE from CNA -- the content loader or
`FromStream' did -- so it records only the undo for the *Lisp* state it creates:
the object, and its registration as a child of the game. Recording the handle here
too is the bug this shape exists to make unsayable, because a handle owned by two
nested ledgers is destroyed twice when the inner one runs first.

The undo is INVALIDATE rather than UNREGISTER-CHILD, for the reason
%ADOPT-TEXTURE-2D gives: an abandoned object's handle is about to be destroyed by
the step recorded before it, so anything still holding a reference must find a
disposed object rather than a live-looking one over a dead handle."
  (let ((effect (make-instance 'sound-effect
                               :handle handle
                               :ownership :owned
                               :owner game
                               :%known-duration known-duration
                               :owner-thread (cna-lisp.internal:owner-thread-of game))))
    (cna-lisp.internal:register-child game effect)
    (funcall record (lambda () (cna-lisp.internal:invalidate effect)))
    effect))

;;; --- FromStream ------------------------------------------------------------

(defun %playback-device-available-p ()
  "Whether CNA reports a playback device, as data rather than as a failure.

`cna_audio_get_capabilities' succeeds either way and answers
`is_playback_available' as a field, which is what makes it usable to tell two
meanings of one result code apart. Answers NIL when the probe itself fails, which
is the conservative direction: an unanswerable question is not evidence that a
device exists."
  (let ((game (cna-lisp.internal:active-game)))
    (and game
         (cffi:with-foreign-object
             (caps '(:struct cna-lisp.internal.ffi::cna-audio-capabilities))
           (cffi:foreign-funcall
            "memset" :pointer caps :int 0
            :size cna-lisp.internal.ffi::+sizeof-cna-audio-capabilities+ :void)
           (setf (cffi:foreign-slot-value
                  caps '(:struct cna-lisp.internal.ffi::cna-audio-capabilities)
                  'cna-lisp.internal.ffi::struct-size)
                 cna-lisp.internal.ffi::+sizeof-cna-audio-capabilities+
                 (cffi:foreign-slot-value
                  caps '(:struct cna-lisp.internal.ffi::cna-audio-capabilities)
                  'cna-lisp.internal.ffi::struct-version)
                 1)
           (and (= (cna-lisp.internal.ffi::%audio-get-capabilities
                    (cna-lisp.internal:handle-of game) caps)
                   cna-lisp.internal.ffi::+result-success+)
                (not (zerop (cffi:foreign-slot-value
                             caps '(:struct cna-lisp.internal.ffi::cna-audio-capabilities)
                             'cna-lisp.internal.ffi::is-playback-available))))))))

(defun sound-effect-from-stream (stream)
  "SoundEffect.FromStream(Stream).

STREAM is an ordinary Common Lisp binary stream, which is what `System.IO.Stream'
projects onto here -- see `docs/limitations.md'. XNA reads it to the end;
`cna_sound_effect_create_from_encoded_ext' takes the bytes CNA would have read,
because \"the canonical operation takes a C++ stream and reads it to the end, so C
takes the bytes it would have read\".

**The bytes are checked against XNA's wave contract before CNA sees them, and
that is the whole point of `audio/wave.lisp'.** CNA's route accepts \"whatever the
audio backend can decode ... which is more than the raw PCM the other creation
routes take\" -- its own header says so -- and XNA accepts one shape: a RIFF/WAVE
file whose `fmt ' chunk declares uncompressed PCM, one or two channels, 8 or 16
bits and a rate in [8000, 48000], followed by a `data' chunk. Handing an Ogg
straight to CNA and answering with a SoundEffect because SDL could decode it
would be adding a capability to `FromStream' that XNA has not got, which is the
one thing this projection does not do.

**Three different failures, three different conditions.** They used to be one:

  not RIFF/WAVE, or a declared size that disagrees with the stream
      CNA-USAGE-ERROR, XNA's InvalidOperationException from ParseWavHeader

  a wave file XNA will not read -- non-PCM, wrong channel count, wrong rate,
  wrong sample width, no fmt chunk, no data chunk, data before fmt
      CNA-ARGUMENT-ERROR, XNA's ArgumentException(InvalidWaveStream)

  a wave file XNA accepts, on a machine with no playback device
      NO-AUDIO-HARDWARE-ERROR, XNA's NoAudioHardwareException

The third used to swallow the other two, because `CNA_RESULT_NOT_SUPPORTED' is
the code for \"no audio hardware\" *and* for \"cannot decode these bytes\", and
mapping both onto NO-AUDIO-HARDWARE-ERROR told a program with a malformed asset
that its machine had no sound card. Validating first removes the ambiguity, and
what remains of it is settled by asking CNA whether a playback device exists."
  (let* ((operation "sound-effect-from-stream")
         (bytes (xna::%read-stream-octets stream operation)))
    ;; Before the game is resolved: XNA's FromStream parses the stream in the
    ;; constructor and needs no device to refuse a stream that is not a wave file.
    (multiple-value-bind (channels sample-rate bits data-length)
        (%check-wave-stream bytes operation)
      (declare (ignore bits))
     (let ((game (%active-game operation))
           ;; XNA's FromStream fills `Duration' in from `WavFile.Duration', which
           ;; is `format.DurationFromSize(Data.Length)' -- the same computation
           ;; the constructors use. The parse above knows all three arguments, so
           ;; this is XNA's exact answer rather than CNA's approximation of it.
           (known (sound-effect-get-sample-duration
                   data-length sample-rate
                   (if (= channels 2) :stereo :mono))))
      (cffi:with-foreign-object (raw :uint8 (length bytes))
        (dotimes (i (length bytes))
          (setf (cffi:mem-aref raw :uint8 i) (aref bytes i)))
        (cffi:with-foreign-object (out :uint64)
          (let ((code (cna-lisp.internal.ffi::%sound-effect-create-from-encoded-ext
                       (cna-lisp.internal:handle-of game) raw (length bytes) out)))
            (when (and (= code cna-lisp.internal.ffi::+result-not-supported+)
                       (%playback-device-available-p))
              ;; The bytes are a wave file XNA reads and a device exists, so this
              ;; is neither of the two meanings the result code carries. Saying
              ;; NO-AUDIO-HARDWARE-ERROR here would be a false statement about the
              ;; machine; the honest answer is that CNA could not decode something
              ;; XNA can, which is a divergence and not a program error.
              (error 'xna:cna-not-supported-error
                     :operation operation :object-type 'sound-effect
                     :%result code
                     :native-message (cna-lisp.internal:last-native-message)
                     :format-control
                     "CNA could not decode a wave stream this binding has checked ~
                      against XNA's own WavFile contract, and a playback device is ~
                      present -- so this is not the no-audio-hardware branch of ~
                      CNA_RESULT_NOT_SUPPORTED. It is a decoder divergence between ~
                      CNA and XNA; please report it with the stream.~@[ ~a~]"
                     :format-arguments (list (cna-lisp.internal:last-native-message))))
            (%check-audio-result code operation :object-type 'sound-effect))
          (let ((handle (cffi:mem-ref out :uint64)))
            ;; This function received the handle, so this ledger records its
            ;; destruction and the adoption records only the Lisp state.
            (cna-lisp.internal:with-native-rollback (record)
              (funcall record
                       (lambda () (cna-lisp.internal.ffi::%sound-effect-destroy handle)))
              (%adopt-loaded-sound-effect game handle record known)))))))))

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

(defparameter *sound-effect-play-overloads*
  '((:plain)
    (:settings "volume" "pitch" "pan"))
  "XNA's two Play overloads, as the keyword sets that spell them.

    Play()
    Play(Single, Single, Single)

The three settings are **one indivisible overload**, not three options. `:VOLUME'
alone, `:PITCH' alone, `:PAN' alone and the three pairs are six call shapes XNA
has not got, and each of them used to be accepted here: the method decided it had
been given the long overload from whether `:VOLUME' was supplied, and defaulted
the other two to 0.0. `Play()' *is* `Play(1f, 0f, 0f)' -- that is its whole body
in the pinned IL -- but that makes the no-argument form a shorthand for the full
triple, not a licence for the six shapes between them.")

(defmethod play ((effect sound-effect)
                 &key (volume nil volume-p) (pitch nil pitch-p) (pan nil pan-p))
  "SoundEffect.Play() and SoundEffect.Play(float, float, float).

One generic function with an optional settings triple, because XNA gives the two
overloads one name and the no-argument form is exactly `Play(1.0f, 0.0f, 0.0f)' --
which is what its IL does, and what this does when no settings are given. The
triple is all-or-nothing; see *SOUND-EFFECT-PLAY-OVERLOADS*.

Answers T when playback started and NIL when it did not. A disposed effect
signals `CNA-DISPOSED-ERROR' rather than answering NIL: CNA's route documents the
`CNA_FALSE' answer as canonical and it is not -- `SoundEffect.Play' opens with an
`IsDisposed' test and throws. See the file header.

`INSTANCE-PLAY-LIMIT-ERROR' is signalled when the platform's voice limit is
reached, which is XNA's `InstancePlayLimitException'.

**All three values are range-checked, and that is read from the IL rather than
inferred.** `Play(float, float, float)' performs no validation of its own: its
body takes an instance from the pool and calls `set_Volume', `set_Pitch' and
`set_Pan' on it, in that order, before `Play()'. So the rules are exactly those
three setters' -- volume in [0, 1], pitch in [-1, 1], pan in [-1, 1], each
comparing with `blt.un'/`bgt.un' so that a NaN takes the throwing branch -- and
the *order* is theirs too, which decides which parameter a doubly-invalid call is
told about. This previously checked `pan' only and documented pitch as clamped;
that was CNA's behaviour rather than XNA's, and CNA's clamp is exactly why the
check has to happen here."
  (let ((operation "play")
        (shape (xna::%check-overload-keywords
                "play" (xna::%supplied-keywords "volume" volume-p "pitch" pitch-p
                                                "pan" pan-p)
                *sound-effect-play-overloads* :object-type 'sound-effect)))
    (cna-lisp.internal:check-usable effect operation)
    (cffi:with-foreign-object (played :uint32)
      (%check-audio-result
       (cna-lisp.internal:with-binary32-semantics
        (if (eq shape :settings)
            ;; set_Volume, then set_Pitch, then set_Pan -- the order Play calls
            ;; them in, so a call wrong in two of them reports the first.
            (let ((v (%check-play-setting volume 0.0f0 1.0f0 "volume" operation))
                  (p (%check-play-setting pitch -1.0f0 1.0f0 "pitch" operation))
                  (n (%check-play-setting pan -1.0f0 1.0f0 "pan" operation)))
              (cna-lisp.internal.ffi::%sound-effect-play-with-settings
               (cna-lisp.internal:handle-of effect) v p n played))
            (cna-lisp.internal.ffi::%sound-effect-play
             (cna-lisp.internal:handle-of effect) played)))
       operation :object-type 'sound-effect :limit-is-play-limit t)
      (not (zerop (cffi:mem-ref played :uint32))))))

(defun %check-play-setting (value low high parameter operation)
  "One of Play's three settings, by the rule its SoundEffectInstance setter applies.

The setters are `blt.un low' then `bgt.un high', both to one
`ArgumentOutOfRangeException(\"value\")', so a NaN is refused along with anything
outside the closed range. The NaN test is written out rather than left to the
comparison for the reason %CHECK-UNIT-RANGE gives: SBCL leaves the invalid flag
accrued after a masked comparison, and the next operation would trap on it."
  (let ((v (xna::f value)))
    (when (or (cna-lisp.internal:nan-p v) (< v low) (> v high))
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name parameter
             :object-type 'sound-effect
             :format-control
             "~a must be in [~a, ~a] and not NaN; ~a was given. Play does not ~
              validate its own arguments: it assigns them to a pooled ~
              SoundEffectInstance, so this is that setter's range. CNA clamps ~
              pitch instead of refusing it, which is why the check is here and ~
              not left to the route."
             :format-arguments (list parameter low high v)))
    v))

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

(defmethod xna::dispose-owned-children ((effect sound-effect) children)
  "SoundEffect.Dispose disposes its live instances, and this is the one type that does.

**Read from the pinned IL, not from the documentation sentence about it.**
`SoundEffect.Dispose(bool)' sets its own `disposed' field, takes a snapshot of its
`children' list, and calls `Dispose()' on every weak reference in it that is still
a live `SoundEffectInstance' -- then drains its instance pool the same way, and
only then releases its own native handle. So the observable behaviour after

    effect = ...;  instance = effect.CreateInstance();  effect.Dispose();

is: `effect.IsDisposed' is true, `instance.IsDisposed' is **also** true, and every
member of the instance that opens with an `IsDisposed' test -- `State',
`Play', `Pause', `Resume', `Stop', `Apply3D' and the three settings' setters --
throws `ObjectDisposedException'. The three *getters* do not: `get_Volume',
`get_Pitch' and `get_Pan' are a bare `ldfld' with no check, and answer the last
value stored. Disposing the instance afterwards is legal and does nothing, because
`SoundEffectInstance.Dispose(bool)' returns early when already disposed.

`CNA-DISPOSED-ERROR' is this binding's `ObjectDisposedException', and it is what
the instance's operations answer here for the same reason.

**The child order is CNA's requirement and XNA's behaviour at once.** Each
instance's voice is deallocated before the effect's handle is released, which is
the \"destroyed after all instances created from it and before the game\" ordering
CNA documents -- so reproducing XNA here does not fight the ABI, it satisfies it.

DISPOSE is used rather than a private teardown so that one instance failing to
release cannot leave the rest alive: each child goes through the same idempotent,
ledger-aware path a program's own `(dispose instance)' would."
  (dolist (child children)
    (xna:dispose child))
  ;; The children unregistered themselves through INVALIDATE, so nothing is left
  ;; for DISPOSE's own check to find. Asserting it rather than assuming it: a
  ;; child that survived would be destroyed by CNA in the wrong order.
  (let ((left (xna::%live-owned-children effect)))
    (when left
      (error 'xna:cna-ownership-error
             :operation "dispose" :object-type 'sound-effect
             :format-control
             "~d SoundEffectInstance(s) were still live after the cascade that ~
              should have disposed them. CNA destroys an instance before its ~
              effect and refuses the other order, so the effect is not destroyed."
             :format-arguments (list (length left)))))
  (values))

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

(defconstant +int32-minimum+ -2147483648)
(defconstant +int32-maximum+ 2147483647
  "Int32's bounds. Both static sample computations take or answer one, and Common
Lisp integers do not, so where XNA's arithmetic is `checked' this binding has to
say so explicitly -- see %CHECKED-INT32 -- and where XNA's *parameter* is an
Int32 the range is part of the contract rather than an accident of C#.")

(defconstant +maximum-duration-milliseconds+ 2147483647
  "The largest TimeSpan `GetSampleSizeInBytes' accepts, in whole milliseconds.

`ldc.r8 2147483647; ble.un.s' in the pinned IL -- `Int32.MaxValue' as a float64,
compared against `duration.TotalMilliseconds'. The comparison is `<=', so exactly
2147483647 ms is accepted and anything above it is refused.")

(defconstant +maximum-duration-ticks+ 21474836470000
  "The same bound as a tick count, which is the unit this projection uses.

`TimeSpan.TotalMilliseconds' is `(double)_ticks * 0.0001' -- clamped to
+-922337203685477, far outside anything relevant here -- so the largest accepted
tick count is the largest whose product with 0.0001 is at most 2147483647.0.
Computed rather than assumed: 21474836470000 ticks multiply to exactly
2147483647.0 and 21474836470001 to 2147483647.0001001, so the boundary is exact
and the tick above it is refused.")

(defun %total-milliseconds (ticks)
  "System.TimeSpan.get_TotalMilliseconds, which **multiplies by 0.0001**.

Not `ticks / 10000.0'. The two differ in the last place for many tick counts --
3 ticks are 0.00030000000000000003 one way and 0.0003 the other -- and this
binding reproduces the operation the IL performs rather than the one the algebra
suggests, for the reason `MathHelper.ToRadians' multiplies by a constant instead
of dividing by 180. No input inside the accepted range was found where the
difference changes a byte count, and that is a measurement rather than a reason
to write the other one.

The clamp is XNA's too, and unreachable from the caller: the duration guard
refuses long before +-922337203685477 ms."
  (let ((v (* (coerce ticks 'double-float) 0.0001d0)))
    (cond ((> v 922337203685477.0d0) 922337203685477.0d0)
          ((< v -922337203685477.0d0) -922337203685477.0d0)
          (t v))))

(defun %checked-int32 (value duration operation)
  "One of `SizeFromDuration''s three checked operations, or XNA's rethrow.

`conv.ovf.i4', `add.ovf' and `mul.ovf' each raise `OverflowException', and
`SoundEffect.GetSampleSizeInBytes' wraps the whole computation in
`try { ... } catch (OverflowException) { throw new ArgumentOutOfRangeException(\"duration\"); }'.
So an overflow is reported to the caller as a *duration* that is out of range,
not as an arithmetic failure -- which is the one thing a Common Lisp
transcription gets wrong for free, because its integers do not overflow and the
computation simply answers a bignum."
  (unless (<= +int32-minimum+ value +int32-maximum+)
    (error 'xna:cna-argument-out-of-range-error
           :operation operation :parameter-name "duration"
           :object-type 'sound-effect
           :format-control
           "~d tick(s) at this rate and channel count needs ~d bytes, which is ~
            outside Int32. XNA computes the size with checked arithmetic and ~
            turns the OverflowException into an ArgumentOutOfRangeException ~
            about the duration, so a size that cannot be counted is a duration ~
            that is too long."
           :format-arguments (list duration value)))
  value)

(defun %ticks-from-milliseconds (milliseconds)
  "System.TimeSpan.FromMilliseconds, which rounds the **milliseconds** and then scales.

Read from the pinned mscorlib rather than from the algebra, and the two are not
the same operation. `FromMilliseconds(v)' is `Interval(v, 1)', whose body is

    millis = v * 1 + (v >= 0 ? 0.5 : -0.5)
    if (millis > 922337203685477 || !(millis >= -922337203685477)) throw OverflowException
    ticks  = (long)millis * 10000

-- so the half is added to the **millisecond** count and the `conv.i8' truncates
*that*, before the multiplication by 10000. It is round-half-away-from-zero to a
whole millisecond, not to a whole tick, and the result is therefore always a
multiple of 10000 ticks.

**This was previously computed as `(long)(v * 10000 + 0.5)', and that is a
different number.** 12.5 ms is 130000 ticks in XNA and 125000 under the old
arithmetic; the comment beside it claimed 125000 was \"the exact 12.5 ms the
buffer holds\", which is true of the buffer and false of `TimeSpan.FromMilliseconds'.
XNA quantises to whole milliseconds here just as CNA's route does -- what the two
disagree about is the direction, CNA truncating 12.5 to 12 and XNA rounding it to
13 -- so the divergence is one rounding rule rather than a lost precision, and
`tests/native/audio.lisp' pins all three numbers.

A NaN cannot reach this: XNA throws `ArgumentException(Arg_CannotBeNaN)' for one,
and the only caller divides by a sample rate already checked to be in
[8000, 48000]."
  (let* ((v (coerce milliseconds 'double-float))
         (millis (+ v (if (minusp v) -0.5d0 0.5d0))))
    (when (or (> millis 922337203685477.0d0)
              (not (>= millis -922337203685477.0d0)))
      (error 'xna:cna-overflow-error
             :operation "sound-effect-get-sample-duration"
             :object-type 'sound-effect
             :format-control
             "~a milliseconds is more than a TimeSpan can hold; XNA answers ~
              OverflowException from TimeSpan.FromMilliseconds."
             :format-arguments (list v)))
    (* (truncate millis) 10000)))

(defun sound-effect-get-sample-duration (size-in-bytes sample-rate channels)
  "SoundEffect.GetSampleDuration(int, int, AudioChannels), in 100-nanosecond ticks.

TimeSpan is projected as an exact tick count throughout this binding rather than
as a type, so this answers an integer. A size of zero answers zero, which is
`TimeSpan.Zero' and XNA's own early return.

Three guards in the pinned IL's order -- a negative size is
`ArgumentException(\"sizeInBytes\")', then the sample rate, then the channels --
and, unlike `GetSampleSizeInBytes', **no overflow path**: the IL has no `checked'
region and no `catch', because `sizeInBytes' is an `Int32' and the largest one
divides down to about 1.3e8 milliseconds, far inside a TimeSpan. That bound is
part of the contract rather than an accident of C#, so a size outside Int32 is
refused here: Common Lisp would otherwise accept an integer XNA cannot be
handed and answer a duration no XNA program can obtain."
  (let ((operation "sound-effect-get-sample-duration"))
    (unless (and (integerp size-in-bytes)
                 (<= 0 size-in-bytes +int32-maximum+))
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "size-in-bytes"
             :object-type 'sound-effect
             :format-control
             "size-in-bytes is an Int32 and must not be negative; it must lie in ~
              [0, ~d] and ~s was given."
             :format-arguments (list +int32-maximum+ size-in-bytes)))
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

DURATION is a tick count, for the reason GetSampleDuration answers one.

**Four guards, in the pinned IL's order**, because which parameter a call wrong
in two of them is told about is decided by that order:

    TotalMilliseconds < 0                  -> ArgumentOutOfRangeException(\"duration\")
    TotalMilliseconds > 2147483647         -> ArgumentOutOfRangeException(\"duration\")
    sampleRate outside [8000, 48000]       -> ArgumentOutOfRangeException(\"sampleRate\")
    channels outside [1, 2]                -> ArgumentOutOfRangeException(\"channels\")

then `duration == TimeSpan.Zero' answers 0, and only then is the size computed --
inside a `checked' region whose overflow becomes the *duration* exception again.
The upper bound and the overflow were both documented here and neither was
implemented; a duration of a thousand years answered a bignum.

NaN does not arise: a TimeSpan is an Int64 tick count, so there is no float to be
one, and inventing a NaN branch would be inventing a rule."
  (let ((operation "sound-effect-get-sample-size-in-bytes"))
    (unless (integerp duration)
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name "duration"
             :object-type 'sound-effect
             :format-control
             "duration is a TimeSpan, which this binding projects as a whole ~
              number of 100-nanosecond ticks; ~s is not one."
             :format-arguments (list duration)))
    (let ((total-milliseconds (%total-milliseconds duration)))
      (when (or (< total-milliseconds 0.0d0)
                (> total-milliseconds
                   (coerce +maximum-duration-milliseconds+ 'double-float)))
        (error 'xna:cna-argument-out-of-range-error
               :operation operation :parameter-name "duration"
               :object-type 'sound-effect
               :format-control
               "duration must be a tick count in [0, ~d] -- that is [0, ~d] ~
                milliseconds, which is Int32.MaxValue and XNA's own upper bound; ~
                ~s was given."
               :format-arguments (list +maximum-duration-ticks+
                                       +maximum-duration-milliseconds+ duration)))
      (%check-sample-rate sample-rate operation)
      (%check-channels channels operation)
      (if (zerop duration)
          0
          (let* ((per-millisecond (xna::f (/ (xna::f sample-rate) 1000.0f0)))
                 (n (%checked-int32
                     (truncate (* total-milliseconds
                                  (coerce per-millisecond 'double-float)))
                     duration operation))
                 (channel-count (%channel-count channels))
                 (aligned (%checked-int32 (+ n (mod n channel-count))
                                          duration operation)))
            (%checked-int32 (* aligned (%block-align channels))
                            duration operation))))))

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
