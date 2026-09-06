;;;; dynamic-sound-effect-instance.lisp --- Microsoft.Xna.Framework.Audio.DynamicSoundEffectInstance.
;;;;
;;;; A `SoundEffectInstance' the program feeds PCM to, rather than one built from
;;;; a `SoundEffect'. XNA's own type is `sealed' and derives from
;;;; `SoundEffectInstance'; the pinned contract says so, and so does its IL:
;;;;
;;;;     .class public auto ansi sealed
;;;;            Microsoft.Xna.Framework.Audio.DynamicSoundEffectInstance
;;;;            extends Microsoft.Xna.Framework.Audio.SoundEffectInstance
;;;;
;;;; **It does not construct itself the way its base class does, and that is the
;;;; architectural fact this file exists around.** XNA's `SoundEffectInstance' has
;;;; two constructors: a public-to-the-assembly `(SoundEffect, bool)' that stores
;;;; the parent effect and allocates a voice from it, and a **parameterless**
;;;; `.ctor()' that stores nothing and allocates nothing. `DynamicSoundEffectInstance'
;;;; calls the second, validates its own two arguments, builds an `AudioFormat',
;;;; and only then calls the virtual `AllocateVoice()' -- which it overrides with
;;;; `CreateDynamicSoundEffectInstance'. So the base class's construction is
;;;; *already* polymorphic in the original, and this projection makes it
;;;; polymorphic here too rather than smuggling a `TYPEP' into the base method.
;;;;
;;;; **CNA agrees, and its header is what settles the sharing.**
;;;; `cna_dynamic_sound_effect_instance_create' says of the handle it answers:
;;;;
;;;;     The handle is a **sound-effect instance**: every `cna_sound_effect_instance_*'
;;;;     route accepts it, including the transport, the mixing setters and
;;;;     `cna_sound_effect_instance_destroy'. What this kind adds is the buffer
;;;;     queue below. Unlike an instance created from a sound effect, it has no
;;;;     parent effect -- the caller is the source.
;;;;
;;;; That sentence is **byte for byte the same in CNA 0.21.0 and 0.22.0** -- the
;;;; whole of `audio.h' is identical between the two admitted versions -- so the
;;;; transport, the four settings, `Apply3D' and disposal are inherited on
;;;; evidence rather than on the accident that CLOS would inherit them anyway.
;;;;
;;;; **The owner is the game, not a sound effect.** The creation route takes a game
;;;; handle and there is no effect to be a child of, so the ownership graph for
;;;; this kind is `Game -> DynamicSoundEffectInstance' with no middle. XNA's own
;;;; `Dispose(bool)' is written for exactly that: it reads `effect' and skips
;;;; `ChildDestroyed' when the field is null.
;;;;
;;;; **What is not inherited, and why each one is not:**
;;;;
;;;;   IsLooped   overridden in XNA. The getter answers `false' unconditionally --
;;;;              after an `IsDisposed' test, which the base class's getter does
;;;;              **not** have -- and the setter throws
;;;;              `InvalidOperationException(InvalidDynamicIsLoopedCall)' for a
;;;;              true value and does nothing at all for a false one. It never
;;;;              stores anything, so the base class's `looped' field is dead here.
;;;;   Play       overridden in XNA, and the override is what the base class's
;;;;              projection already does: the base `Play()' submits the effect's
;;;;              packet on the first call and this one has no packet to submit,
;;;;              so both reach the same native `Play' and both set
;;;;              `isPacketSubmitted'. The projection inherits it, and
;;;;              `tests/native/audio.lisp' pins the behaviour rather than the
;;;;              inheritance.
;;;;
;;;; **No test here claims a sound was heard.** The streaming lane submits
;;;; generated PCM through SDL's `dummy' driver, which opens a device with no
;;;; speaker behind it. What is proved is that the bytes were accepted, that the
;;;; queue depth moved, and that the buffer-needed event reached Lisp.

(in-package #:microsoft.xna.framework.audio)

(defclass dynamic-sound-effect-instance (sound-effect-instance)
  ((%sample-rate :reader %dynamic-sample-rate
                 :documentation "The sample rate this instance was created with.")
   (%channels :reader %dynamic-channels
              :documentation "The AUDIO-CHANNELS this instance was created with.")
   (event-handlers :initform '()
                   :accessor microsoft.xna.framework::%event-handlers))
  (:documentation
   "Microsoft.Xna.Framework.Audio.DynamicSoundEffectInstance: streamed playback.

    (make-instance 'dynamic-sound-effect-instance :sample-rate 44100 :channels :stereo)

XNA's one public constructor, and the only shape this accepts: both keywords or
neither is not a choice -- there is no other overload, so a partial set names no
member and is refused rather than defaulted.

The buffers are **PCM16, little-endian, interleaved**, which is the one format
XNA's constructor can build: it calls `AudioFormat.Create(sampleRate, channels, 16)'
with the bit depth written into the call site. A whole sample frame is therefore
`2 * channels' bytes, and every length, offset and count `SUBMIT-BUFFER' takes
must be a whole number of them.

`PENDING-BUFFER-COUNT' is what makes streaming observable: CNA's route documents
that the count \"only shrinks once a buffer has actually been **consumed by
playback**, not merely handed to the mixer\", so a fall in that number is evidence
about the runtime rather than about this binding.

`ADD-BUFFER-NEEDED-HANDLER' subscribes to the event CNA raises when the queue runs
low. The queue is advanced by the game loop -- CNA's own header says
`cna_framework_dispatcher_update' drives it for every live instance -- so a
program that never runs a frame never sees the event, exactly as an XNA program
that never pumps its dispatcher does not."))

;;; --- construction ----------------------------------------------------------

(defparameter *dynamic-instance-constructor-overloads*
  '((:plain "sample-rate" "channels"))
  "XNA's one public DynamicSoundEffectInstance constructor.

    DynamicSoundEffectInstance(Int32 sampleRate, AudioChannels channels)

One entry, and the list is still a list for the reason SoundEffect's is: the
refusal a caller reads names every shape that exists, and a member with one shape
has to be able to say so.")

(defmethod %initialize-native-sound-instance
    ((instance dynamic-sound-effect-instance)
     &rest initargs &key sample-rate channels &allow-other-keys)
  "DynamicSoundEffectInstance(int, AudioChannels), in the pinned IL's order.

    base()                                        -- stores nothing, allocates nothing
    sampleRate < 0x1f40 || > 0xbb80  -> ArgumentOutOfRangeException(\"sampleRate\")
    channels   < 1      || > 2       -> ArgumentOutOfRangeException(\"channels\")
    format = AudioFormat.Create(sampleRate, channels, 16)
    AllocateVoice()                               -- the native handle, last

The order is observable: `(make-instance ... :sample-rate 1 :channels :quad)' is
about the **sample rate**, because that test comes first. The bounds are the same
[8000, 48000] and [1, 2] the `SoundEffect' constructors use -- one fact in the
pinned assembly appearing in five places, which is why %CHECK-SAMPLE-RATE and
%CHECK-CHANNELS are shared rather than restated.

**The handle is taken last, and the ledger has it before anything else can
fail.** A subclass initializer that signals after this gives the instance back
rather than leaving CNA holding a stream nobody received."
  (let ((operation "make-instance dynamic-sound-effect-instance")
        (type 'dynamic-sound-effect-instance))
    (xna::%check-overload-keywords
     operation (%sound-effect-supplied-initargs initargs)
     *dynamic-instance-constructor-overloads* :object-type type)
    (%check-sample-rate sample-rate operation :object-type type)
    (%check-channels channels operation :object-type type)
    (let ((game (%active-game operation)))
      (cffi:with-foreign-object (out :uint64)
        ;; CNA_RESULT_NOT_SUPPORTED here means "the machine has no audio
        ;; hardware", which the route's own documentation says and which XNA
        ;; reports as NoAudioHardwareException out of AllocateVoice.
        (%check-audio-result
         (cna-lisp.internal.ffi::%dynamic-sound-effect-instance-create
          (cna-lisp.internal:handle-of game) sample-rate
          (audio-channels-value channels) out)
         operation :object-type type)
        (setf (slot-value instance '%sample-rate) sample-rate
              (slot-value instance '%channels) channels)
        (%adopt-sound-effect-instance instance game (cffi:mem-ref out :uint64))))))

(defmethod %release-sound-instance-registrations
    ((instance dynamic-sound-effect-instance))
  "Give every BufferNeeded registration back before the instance handle goes.

XNA does the same thing in the same order and for the same reason: its
`Dispose(bool)' removes the instance from the static `allInstances' table --
which is what `RaiseBufferNeededOnInstance' looks it up in -- **before** calling
the base `Dispose(bool)' that deallocates the voice. So no handler can be reached
after disposal, and neither can one here: the registration is released, the
callback token is dropped from the registry, and only then is the native instance
destroyed."
  (xna::%release-event-handlers instance))

;;; --- IsLooped, which is a different member on this class --------------------

(defmethod is-looped ((instance dynamic-sound-effect-instance))
  "DynamicSoundEffectInstance.IsLooped's getter: always false, and **guarded**.

    IL_0000: ldarg.0
    IL_0001: call   instance bool SoundEffectInstance::get_IsDisposed()
    IL_0006: brfalse.s IL_001e
    ...        throw ObjectDisposedException
    IL_001e: ldc.i4.0
    IL_001f: ret

This is the one place where the subclass is stricter than its base. The base
class's `get_IsLooped' is a bare `ldfld' that answers after disposal; this one
tests `IsDisposed' first and then answers a constant. A streamed instance has no
loop to report, so the field is never read -- and the two getters must not be
confused, which is why CLOS dispatch decides rather than a shared body."
  (cna-lisp.internal:check-usable instance "is-looped")
  nil)

(defmethod (setf is-looped) (value (instance dynamic-sound-effect-instance))
  "DynamicSoundEffectInstance.IsLooped's setter: false is a no-op, true is refused.

    disposed        -> ObjectDisposedException
    value == true   -> InvalidOperationException(InvalidDynamicIsLoopedCall)
    value == false  -> ret

It stores nothing in either branch, so the base class's `looped' field stays
false for the life of the object and the getter above never has to consult it.
Assigning false is legal and does nothing, which is not the same as being
ignored: a program that assigns true is told, and CNA is never asked to loop a
stream it cannot loop."
  (let ((operation "setf is-looped"))
    (cna-lisp.internal:check-usable instance operation)
    (when value
      (error 'xna:cna-invalid-state-error
             :operation operation :object-type 'dynamic-sound-effect-instance
             :format-control
             "a DynamicSoundEffectInstance cannot loop: it plays the buffers the ~
              program submits and there is no region to return to. XNA throws ~
              InvalidOperationException here, and assigning NIL is the no-op it ~
              is there."))
    nil))

;;; --- SubmitBuffer -----------------------------------------------------------

(defparameter *submit-buffer-overloads*
  '((:whole) (:range "offset" "count"))
  "XNA's two SubmitBuffer overloads, as the keyword sets that spell them.

    SubmitBuffer(Byte[])
    SubmitBuffer(Byte[], Int32 offset, Int32 count)

The buffer is positional in both and is therefore in neither set. `:OFFSET' alone
and `:COUNT' alone are shapes XNA has not got: its short overload is literally
`SubmitBuffer(buffer, 0, buffer.Length)', so there is no member between the two
and %CHECK-OVERLOAD-KEYWORDS refuses the halves rather than completing them.")

(defgeneric submit-buffer (instance buffer &key &allow-other-keys)
  (:documentation
   "DynamicSoundEffectInstance.SubmitBuffer(Byte[]) and its ranged overload.

    (submit-buffer instance pcm)
    (submit-buffer instance pcm :offset 0 :count 800)

BUFFER holds **PCM16LE sample frames**, interleaved when the instance is stereo.
Answers no value, as XNA's `void' does.

The bytes are copied during the call -- CNA's route says so in as many words --
so the buffer may be reused or freed the moment this returns."))

(defmethod submit-buffer ((instance dynamic-sound-effect-instance) buffer
                          &rest settings &key offset count &allow-other-keys)
  "The pinned IL's five checks, in its order, and then the route.

    disposed                                 -> ObjectDisposedException
    buffer null / empty / length misaligned  -> ArgumentException(InvalidAudioBuffer)
    offset < 0 || >= length || misaligned    -> ArgumentException(InvalidAudioBufferOffset)
    checked(offset + count) overflows        -> ArgumentException(InvalidOffsetCountLength)
    count <= 0 || offset+count > length
      || count misaligned                    -> ArgumentException(InvalidOffsetCountLength)

Those are the same three `FrameworkResources' strings, in the same order, that
`SoundEffect''s seven-argument constructor uses, so %CHECK-BUFFER, %CHECK-OFFSET
and %CHECK-COUNT are the same three functions rather than three more.
`IsAligned(v)' is `v % BlockAlign == 0' and `BlockAlign' for the format this
class always builds is `2 * channels'.

**The overflow branch needs no separate test, and %CHECK-COUNT already says why.**
`checked(offset + count)' is what raises `OverflowException' in the original, and
its `catch' turns that into the *same* `ArgumentException(InvalidOffsetCountLength)'
the range test below it raises -- so the two branches are one observable outcome.
Common Lisp integers do not overflow, and every value the overflow would have
caught is outside `offset + count <= buffer.Length' anyway.

`SubmitBuffer(null)' is worth a sentence, because the two overloads do not agree
about it: the short one evaluates `buffer.Length' to build the long call and
throws `NullReferenceException' before any check runs, while the long one reaches
`ArgumentException'. Both are refusals of the same call and Common Lisp has no
null array, so both spellings answer the one condition the long overload gives."
  (let* ((operation "submit-buffer")
         (type 'dynamic-sound-effect-instance)
         (shape (xna::%check-overload-keywords
                 operation
                 (loop for (key nil) on settings by #'cddr
                       collect (string-downcase (symbol-name key)))
                 *submit-buffer-overloads* :object-type type)))
    (cna-lisp.internal:check-usable instance operation)
    (let ((block-align (%block-align (%dynamic-channels instance))))
      (%check-buffer buffer block-align operation :object-type type)
      (let ((offset (if (eq shape :range) offset 0))
            (count (if (eq shape :range) count (length buffer))))
        (%check-offset offset buffer block-align operation :object-type type)
        (%check-count offset count buffer block-align operation :object-type type)
        (let ((length (length buffer)))
          (cffi:with-foreign-object (bytes :uint8 length)
            (dotimes (i length)
              (setf (cffi:mem-aref bytes :uint8 i) (aref buffer i)))
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%dynamic-sound-effect-instance-submit-buffer
              (cna-lisp.internal:handle-of instance) bytes length offset count)
             operation :object-type type)))))
    (values)))

;;; --- the two instance sample computations -----------------------------------
;;;
;;; **Instance methods, not the statics of the same name.** CNA's header says so
;;; itself -- "unlike the sound-effect computations, these two are instance
;;; methods: they use the sample rate and channel count this instance was created
;;; with rather than taking them as arguments" -- and XNA agrees: both call
;;; `AudioFormat.DurationFromSize' / `SizeFromDuration' on the instance's own
;;; format.
;;;
;;; **The arithmetic is XNA's and is computed here**, for the reason the two
;;; statics on `SoundEffect' are: `AudioFormat.DurationFromSize' ends in
;;; `TimeSpan.FromMilliseconds', which rounds to a whole millisecond, and CNA's
;;; route does not quantise the same way. Those two functions are the same
;;; arithmetic on the same fields, so this reuses them rather than transcribing
;;; the IL a second time. The routes stay bound and `tests/native/audio.lisp'
;;; pins **both** answers, so a CNA that changed fails a test rather than
;;; silently changing this binding's public behaviour.
;;;
;;; What differs from the statics is the *guards*, and only the guards: these two
;;; take no rate or channel count, so they cannot refuse one, and each opens with
;;; the `IsDisposed' test its IL opens with.

(defgeneric get-sample-duration (instance size-in-bytes)
  (:documentation
   "DynamicSoundEffectInstance.GetSampleDuration(Int32), in 100-nanosecond ticks.

TimeSpan is projected as an exact tick count throughout this binding rather than
as a type, so this answers an integer. A size of zero answers zero, which is
`TimeSpan.Zero' and XNA's own early return."))

(defmethod get-sample-duration ((instance dynamic-sound-effect-instance) size-in-bytes)
  "    disposed        -> ObjectDisposedException
    sizeInBytes < 0 -> ArgumentException(InvalidBufferSize)
    sizeInBytes = 0 -> TimeSpan.Zero
    otherwise          format.DurationFromSize(sizeInBytes)

Note which exception the negative case is: `ArgumentException', not the
`ArgumentOutOfRangeException' the constructor's two guards raise. The IL builds
it from `FrameworkResources.InvalidBufferSize' and carries no parameter name."
  (let ((operation "get-sample-duration"))
    (cna-lisp.internal:check-usable instance operation)
    (unless (and (integerp size-in-bytes)
                 (<= 0 size-in-bytes +int32-maximum+))
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "size-in-bytes"
             :object-type 'dynamic-sound-effect-instance
             :format-control
             "size-in-bytes is an Int32 and must not be negative; it must lie in ~
              [0, ~d] and ~s was given."
             :format-arguments (list +int32-maximum+ size-in-bytes)))
    (if (zerop size-in-bytes)
        0
        (sound-effect-get-sample-duration size-in-bytes
                                          (%dynamic-sample-rate instance)
                                          (%dynamic-channels instance)))))

(defgeneric get-sample-size-in-bytes (instance duration)
  (:documentation
   "DynamicSoundEffectInstance.GetSampleSizeInBytes(TimeSpan).

DURATION is a tick count, for the reason GET-SAMPLE-DURATION answers one."))

(defmethod get-sample-size-in-bytes ((instance dynamic-sound-effect-instance) duration)
  "    disposed                        -> ObjectDisposedException
    TotalMilliseconds < 0           -> ArgumentOutOfRangeException(\"duration\")
    TotalMilliseconds > 2147483647  -> ArgumentOutOfRangeException(\"duration\")
    duration = TimeSpan.Zero        -> 0
    otherwise                          checked(format.SizeFromDuration(duration)),
                                       whose OverflowException becomes the same
                                       ArgumentOutOfRangeException"
  (let ((operation "get-sample-size-in-bytes"))
    (cna-lisp.internal:check-usable instance operation)
    (sound-effect-get-sample-size-in-bytes duration
                                           (%dynamic-sample-rate instance)
                                           (%dynamic-channels instance))))

;;; --- PendingBufferCount -----------------------------------------------------

(defgeneric pending-buffer-count (instance)
  (:documentation
   "DynamicSoundEffectInstance.PendingBufferCount: submitted buffers not yet played.

**The member that makes streaming observable.** CNA's route documents exactly
what the number means -- it \"only shrinks once a buffer has actually been
consumed by playback, not merely handed to the mixer, which is the canonical
contract\" -- so a fall in it is evidence about the runtime rather than about this
binding.

The queue is advanced by the game loop: CNA's own header says
`cna_framework_dispatcher_update' drives every live streaming instance, so a
program that submits a buffer and never runs a frame will watch this number stay
where it is."))

(defmethod pending-buffer-count ((instance dynamic-sound-effect-instance))
  "Guarded, as its IL is: it takes voiceHandleLock and throws
ObjectDisposedException before reading anything."
  (let ((operation "pending-buffer-count"))
    (cna-lisp.internal:check-usable instance operation)
    (cffi:with-foreign-object (out :int32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%dynamic-sound-effect-instance-get-pending-buffer-count
        (cna-lisp.internal:handle-of instance) out)
       operation :object-type 'dynamic-sound-effect-instance)
      (cffi:mem-ref out :int32))))

;;; --- the BufferNeeded event -------------------------------------------------
;;;
;;; Projected through the machinery every other CLR event here uses, because
;;; CNA's audio subscription has the same three parts as the game's: a
;;; `void (*)(void*)' callback, an integer context this binding resolves back to
;;; a rooted Lisp object, and an owned registration handle. **No Lisp object is
;;; ever handed to C**; the context is a small integer token, exactly as
;;; docs/callbacks-and-threading.md requires.
;;;
;;; What is different is the two routes, and that is what the two methods below
;;; say: `cna_dynamic_sound_effect_instance_subscribe_buffer_needed' takes the
;;; callback and context directly rather than an event identity, and the
;;; registration is released by `cna_audio_unsubscribe_ext' rather than by
;;; `cna_game_unsubscribe'.
;;;
;;; **XNA's own semantics, from the IL:**
;;;
;;;   sender      the instance. `OnBufferNeeded' invokes `handler(this, args)'.
;;;   args        `EventArgs.Empty', which carries nothing -- so the projected
;;;               handler takes the sender and nothing else, the same decision
;;;               every other event here makes.
;;;   add/remove  ordinary `Delegate.Combine'/`Remove' against the private
;;;               `BufferNeeded' field, through an `Interlocked.CompareExchange'
;;;               loop, with **no** `IsDisposed' test and no other call at all --
;;;               and `Dispose(bool)' removes the instance from `allInstances'
;;;               and never touches that field. So both are legal on a disposed
;;;               instance there, `-=' still finds a handler `+=' put there
;;;               before the disposal, and neither reaches anything native.
;;;
;;;               **Both are legal here, and this is what that costs.** A live
;;;               subscription is two things -- the logical handler list and a
;;;               CNA registration -- and only the first of them survives
;;;               disposal. Adding to a disposed instance updates the list and
;;;               acquires nothing, which is honest rather than convenient: no
;;;               event can be raised on a destroyed instance, so there is
;;;               nothing to register for and faking a registration against a
;;;               dead handle would be inventing one. %EVENT-SOURCE-DISPOSED-P in
;;;               src/runtime/event-machinery.lisp is the seam, and it is shared
;;;               because the audit that found this found the same twenty-one
;;;               accessors behaving the same way across all three assemblies.
;;;   raising     a static `RaiseBufferNeededOnInstance(handle)' looks the
;;;               instance up in a table keyed by voice handle and calls
;;;               `OnBufferNeeded' on it. `Dispose(bool)' removes it from that
;;;               table **before** the base disposal deallocates the voice, so no
;;;               handler can be reached after disposal. That ordering is
;;;               reproduced by %RELEASE-SOUND-INSTANCE-REGISTRATIONS above.
;;;   threshold   XNA raises when its queue runs low, from whichever thread
;;;               pumps the dispatcher; CNA's route says the same in the same
;;;               words -- "raised from whichever thread advances the queue,
;;;               which is the game thread when the loop runs". **How low is
;;;               low is neither framework's public contract**, and nothing here
;;;               claims a depth: the qualification asserts that the event
;;;               arrives and that it stops arriving after disposal.

(xna::%define-event-pair add-buffer-needed-handler remove-buffer-needed-handler
  "DynamicSoundEffectInstance.BufferNeeded's `+=': call HANDLER when the queue runs low.

    (add-buffer-needed-handler instance
                               (lambda (instance)
                                 (submit-buffer instance (next-block))))

HANDLER takes the sender and nothing else, because XNA passes `EventArgs.Empty'
and a second always-empty argument would be one every handler had to write and
ignore.

It is called on the thread that advances the buffer queue, which is the game
thread while the loop runs. A condition it signals cannot be reported to CNA --
the callback answers `void' -- so it is contained there and re-signalled by the
first native call that returns to your program afterwards, which for a handler
reached during the loop is the RUN, RUN-ONE-FRAME or TICK that was running. The
condition object itself arrives, not a description of it; if a native call fails
in the same breath, that failure is what is signalled and the handler's condition
is its CNA-ERROR-CAUSE.

Legal on a disposed instance, and purely managed there: XNA's `+=' is
`Delegate.Combine' against a field its disposal never clears, so the handler list
outlives the instance even though nothing can raise the event any more.")

(defparameter *dynamic-instance-event-values*
  (list (cons :buffer-needed 0))
  "The one event a DynamicSoundEffectInstance raises.

The value is unused and is zero: CNA's audio subscription names the event by
*route* rather than by an identity passed to a shared one, so there is no
constant to carry. The table is still a table because %SUBSCRIBE-EVENT looks the
keyword up in it to decide whether the object raises the event at all.")

(defmethod xna::%event-table ((instance dynamic-sound-effect-instance))
  *dynamic-instance-event-values*)

(defmethod xna::%subscribe-natively ((instance dynamic-sound-effect-instance)
                                     value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%dynamic-sound-effect-instance-subscribe-buffer-needed
   (cna-lisp.internal:handle-of instance)
   (cna-lisp.internal.ffi:audio-event-callback-pointer)
   (cffi:make-pointer token)
   registration))

(defmethod xna::%unsubscribe-natively ((instance dynamic-sound-effect-instance)
                                       registration)
  "Audio registrations are released by their own route.

`cna_audio_unsubscribe_ext' takes \"an owned registration handle from any audio
subscribe route\"; `cna_game_unsubscribe', which the default method calls, does
not accept one."
  (cna-lisp.internal.ffi::%audio-unsubscribe-ext registration))

(xna::%define-event-methods dynamic-sound-effect-instance :buffer-needed
                            add-buffer-needed-handler remove-buffer-needed-handler)
