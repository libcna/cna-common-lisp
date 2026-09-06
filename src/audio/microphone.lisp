;;;; microphone.lisp --- Microsoft.Xna.Framework.Audio.Microphone.
;;;;
;;;; **A microphone is not a native object this binding owns, and that is the
;;;; whole shape of this file.** Every other CNA-Lisp type with a handle is a
;;;; NATIVE-OBJECT: it is created, it is a child of something, and it is
;;;; destroyed. `audio.h' says a microphone is none of those -- "Microphones are
;;;; addressed by **index**, like every other enumerated device in this ABI,
;;;; because the canonical list hands out pointers the runtime owns", and "The
;;;; microphone itself is owned by the runtime and outlives every registration a
;;;; caller can hold." There is no create route, no destroy route and no handle.
;;;;
;;;; XNA agrees, and the pinned IL is where that was read rather than assumed.
;;;; `Microphone' has no public constructor at all -- its `.ctor(uint32)' is
;;;; `assembly'-private -- and the only thing that calls it is
;;;; `MicrophoneCollection.EnumerateMicrophones'. So a program never makes one; it
;;;; asks the static `All' or `Default' for the ones that exist.
;;;;
;;;; What follows from that:
;;;;
;;;;   * MICROPHONE is a plain CLOS class, not a NATIVE-OBJECT. It has no handle
;;;;     slot, is not registered as a child of the game, and there is no
;;;;     DISPOSE -- because XNA has none either. Its `Finalize' is the CLR's
;;;;     finalizer, which is universally not-applicable here.
;;;;   * Identity is cached, and §"object identity" below says exactly how.
;;;;   * Its four stored members answer from slots, because in XNA they are
;;;;     *fields* read by their getters rather than native queries.
;;;;
;;;; --- object identity ------------------------------------------------------
;;;;
;;;; **This is the part that had to be read from the IL, and the IL is
;;;; unambiguous.** `MicrophoneCollection' holds a `List<Microphone>' created once
;;;; by `Microphone''s static constructor and never replaced.
;;;; `EnumerateMicrophones' is:
;;;;
;;;;     GetMicrophoneCount(out count)
;;;;     if (count < allMicrophones.Count) throw new InvalidOperationException();
;;;;     for (i = allMicrophones.Count; i < count; i++)
;;;;         if (CreateMicrophone(i, out handle) == 0)
;;;;             allMicrophones.Add(new Microphone(handle));
;;;;
;;;; -- **append-only**. An existing element is never replaced, never removed and
;;;; never re-targeted, and a count that has *shrunk* is an error rather than a
;;;; reason to rebuild. So in XNA, `Microphone.All[i]' is reference-identical
;;;; across every query for the life of the process, and this binding reproduces
;;;; that with one process-global cache keyed by index.
;;;;
;;;; **The key is the index and not the name**, deliberately: two capture devices
;;;; may share a display name, so a name is not an identity. It is not a
;;;; generation either, and inventing one would claim a hot-plug story neither
;;;; runtime has -- CNA exposes a count and an index and nothing else, no device
;;;; id and no device-changed event. What the cache does instead is refuse the one
;;;; case that would silently re-target: a count below the number already cached
;;;; is `CNA-INVALID-STATE-ERROR', which is XNA's own `InvalidOperationException'
;;;; in the same position.
;;;;
;;;; **The cache is process-global rather than per-game, and that was measured.**
;;;; Destroying a game and creating another leaves CNA's device list identical --
;;;; same count, same names, same default index, same sample rates -- and even
;;;; leaves a microphone *capturing* across the pair. The runtime owns the
;;;; devices, exactly as the header says, so a facade obtained under one game is
;;;; still the right object under the next one. That is XNA's model too, where the
;;;; collection belongs to a static field and there is no game to scope it to.
;;;;
;;;; --- the game every route needs and no member takes ------------------------
;;;;
;;;; `Microphone.All', `Microphone.Default' and every instance member take no game
;;;; in XNA. Every CNA microphone route takes one. This is the same gap
;;;; `Keyboard.GetState' and the whole SoundEffect surface already close, closed
;;;; the same way: CNA permits one active game per process, so there is exactly
;;;; one game a microphone operation could mean, and %ACTIVE-GAME resolves it.
;;;; With none, the established `CNA-INVALID-STATE-ERROR' says so. No public
;;;; member here grew a `:game' parameter to satisfy CNA.
;;;;
;;;; --- what CNA and XNA disagree about, and who wins -------------------------
;;;;
;;;; Four disagreements were measured, and the public answer is XNA's in all
;;;; four. They are listed here rather than buried at their call sites because
;;;; each one is a place where following CNA would have been easier and wrong.
;;;;
;;;;   IsHeadset            CNA reports the device's real answer. XNA's
;;;;                        constructor stores a literal `true' and the getter
;;;;                        reads that field; `SafeIsHeadset', which would ask the
;;;;                        native layer, is compiled into the assembly and
;;;;                        **never called**. See IS-HEADSET.
;;;;
;;;;   BufferDuration       CNA's header says its setter "validates and rounds"
;;;;                        the value. Measured, it accepts 100.5 ms and stores
;;;;                        100.5 ms -- neither rounding nor refusing. XNA refuses
;;;;                        anything that is not a whole multiple of 10 ms in
;;;;                        [100, 1000]. See (SETF BUFFER-DURATION).
;;;;
;;;;   GetSampleDuration    CNA truncates to whole milliseconds; XNA's
;;;;                        `TimeSpan.FromMilliseconds' rounds half away from
;;;;                        zero. 46 bytes at 44100 Hz is 0.52 ms: CNA answers 0
;;;;                        ticks and XNA answers 10000.
;;;;
;;;;   GetSampleSizeInBytes CNA computes in a wider type; XNA divides the sample
;;;;                        rate by 1000 in **binary32** first, so 44100 becomes
;;;;                        44.09999847412109375 and one second is 88198 bytes,
;;;;                        not 88200. CNA also accepts a negative duration and
;;;;                        answers a negative size, where XNA throws.
;;;;
;;;; The last two are why the two `cna_microphone_get_sample_*' routes are bound
;;;; and **not used for the public answer**: the arithmetic is XNA's, computed
;;;; here, and the routes exist so the qualification can pin the divergence as a
;;;; measurement rather than describe it in a comment.

(in-package #:microsoft.xna.framework.audio)

;;; --- the format every microphone has --------------------------------------

(defconstant +microphone-channels+ 1
  "`AudioChannels.Mono', which is the channel count XNA builds a microphone with.

`Microphone''s constructor is `AudioFormat.Create(GetSampleRate(), (AudioChannels)1, 16)'
-- the channel count and the bit depth are written into the call site as
constants, so every XNA microphone is mono PCM16 whatever the device is. That is
not a default this binding chose; it is the only format the original can produce,
and it is what makes the block alignment below a constant too.")

(defconstant +microphone-bits-per-sample+ 16
  "The bit depth written into `AudioFormat.Create' at `Microphone''s call site.")

(defconstant +microphone-block-align+ 2
  "`AudioFormat.BlockAlign' for a mono PCM16 format: `channels * bitDepth / 8'.

`AudioHelper.MakeFormat' writes the WAVEFORMATEX field as `(channels * bitDepth) / 8',
which for 1 and 16 is 2. This is the divisor of every `IsAligned' test in
`GetData' and the one in `DurationFromSize', so it is defined once and named
rather than spelled 2 at five call sites.")

;;; --- the one active game, and the index that names a device ----------------

(defun %microphone-game-handle (operation)
  "The active game's handle, or the established refusal naming what is missing.

Shared with the SoundEffect surface rather than restated: `%ACTIVE-GAME-HANDLE'
is the same resolution, raises the same condition and is documented in
`docs/limitations.md' as the same projection limit. A microphone member reaches
it for the same reason a `SoundEffect' member does -- XNA takes no game and CNA
needs one."
  (%active-game-handle operation))

(defun %check-microphone-result (code operation &key (object-type 'microphone))
  "CHECK-RESULT, with `CNA_RESULT_NOT_SUPPORTED' given the microphone's own class.

`audio.h' documents that code for exactly one microphone route --
`cna_microphone_start_at', \"when no microphone is connected\" -- and for the
sound-effect creation routes it means no *playback* device. One result code, two
meanings, decided by the family that answered: so this is a second function
beside `%CHECK-AUDIO-RESULT' rather than another keyword on it, and neither can
raise the other's class by accident.

Everything else goes to CHECK-RESULT unchanged, so a generic native failure stays
the generic condition it is."
  (cond
    ((= code cna-lisp.internal.ffi::+result-success+) t)
    ((= code cna-lisp.internal.ffi::+result-not-supported+)
     (error 'no-microphone-connected-error
            :operation operation :object-type object-type
            :%result code
            :native-message (cna-lisp.internal:last-native-message)))
    (t (cna-lisp.internal:check-result code operation :object-type object-type))))

;;; --- the facade ------------------------------------------------------------

(defclass microphone ()
  ((index :initarg :index :reader %microphone-index
          :documentation
          "The zero-based CNA device index this facade addresses.

Private. It is the cache key and the argument every `cna_microphone_*_at' route
takes, and it is not public because XNA has no such concept: there, a
`Microphone' is an object and the index is an implementation detail of the list
it lives in.")
   (name :initarg :name
         :documentation "The device name, read once at construction.")
   (sample-rate :initarg :sample-rate
                :documentation "The capture sample rate, read once at construction.")
   (headset :initarg :headset
            :documentation "XNA's stored `isHeadset', which its constructor sets to true.")
   (buffer-duration :initarg :buffer-duration :accessor %buffer-duration
                    :documentation
                    "XNA's `captureBufferDuration' field, in 100-nanosecond ticks.")
   (event-handlers :initform '()
                   :accessor microsoft.xna.framework::%event-handlers
                   :documentation "The BufferReady subscriptions, live and logical."))
  (:documentation
   "Microsoft.Xna.Framework.Audio.Microphone: one capture device the runtime owns.

**You do not make one.** XNA's constructor is assembly-private and only its
device enumeration calls it, so there is no `MAKE-INSTANCE' here either: ask
`MICROPHONE-ALL' for every device or `MICROPHONE-DEFAULT' for the preferred one,
and the objects they answer are the ones that exist.

**They are the *same* objects every time**, which is a property programs rely on
and a test asserts with `EQ': `(nth 0 (microphone-all))' twice is one object, and
`MICROPHONE-DEFAULT' is `EQ' to its entry in `MICROPHONE-ALL' rather than a
second object with equal slots. XNA's enumeration is append-only over a list its
static constructor makes once, so an index names one `Microphone' object for the
life of the process; this reproduces that.

**There is no disposal.** The runtime owns the device and outlives the game, let
alone this object, so there is nothing to give back -- and XNA offers no
`Dispose' either. `START' and `STOP' change what the device is doing; neither
ends the object.

Four of its members answer from slots filled when the facade was built --
`NAME', `SAMPLE-RATE', `IS-HEADSET' and `BUFFER-DURATION' -- because in XNA all
four are fields their getters read rather than native queries. `STATE',
`GET-DATA', `START' and `STOP' are the members that actually reach the device,
and each needs an active game for the reason this file's header gives."))

(defmethod print-object ((microphone microphone) stream)
  (print-unreadable-object (microphone stream :type t)
    (format stream "~s ~d Hz" (name microphone) (sample-rate microphone))))

;;; --- the process-global identity cache -------------------------------------

(defvar *microphones* '()
  "Every MICROPHONE facade this process has made, in index order.

The projection of XNA's static `MicrophoneCollection.allMicrophones'. It is a
list rather than a vector because it is short, append-only and always walked
whole, and it is global rather than per-game because CNA's device list is: the
runtime owns the devices and they survive a game being destroyed and another
created, which was measured rather than assumed.

Never rebound and never shortened. %ENUMERATE-MICROPHONES appends to it and
nothing else writes it, which is what makes an index name one object forever.")

(defvar *default-microphone* nil
  "The facade `MICROPHONE-DEFAULT' has selected, or NIL if it has not selected yet.

XNA's `MicrophoneCollection.defaultMic', with its caching: `get_Default' returns
this without enumerating when it is already set, and only re-selects while it is
null. That asymmetry with `get_All' -- which enumerates on every read -- is the
IL's and is reproduced rather than smoothed over.")

(defun %reset-microphone-cache ()
  "Forget every cached facade. **Not public, and not something a program may do.**

XNA has no such operation: its collection is a static field that lives as long as
the process. This exists for the test suite, which has to be able to prove what a
*first* enumeration does more than once in one image, and for nothing else."
  (setf *microphones* '() *default-microphone* nil))

(defun %microphone-count (handle operation)
  "`GetMicrophoneCount': how many capture devices CNA reports."
  (cffi:with-foreign-object (out :uint64)
    (%check-microphone-result
     (cna-lisp.internal.ffi::%microphone-get-count handle out) operation)
    (cffi:mem-ref out :uint64)))

(defun %microphone-name-at (handle index operation)
  "`GetName': one device's display name, through the ABI's count-then-copy idiom.

The two string routes stay private UTF-8 machinery and the public `NAME' is an
ordinary Lisp string, which is the rule every other name in this binding follows."
  (cna-lisp.internal:count-then-copy-string
   (lambda (out)
     (cna-lisp.internal.ffi::%microphone-get-name-size-at handle index out))
   (lambda (buffer capacity out)
     (cna-lisp.internal.ffi::%microphone-copy-name-at handle index buffer capacity out))
   operation))

(defun %microphone-sample-rate-at (handle index operation)
  "`GetSampleRate': the rate XNA's constructor puts into the format."
  (cffi:with-foreign-object (out :int32)
    (%check-microphone-result
     (cna-lisp.internal.ffi::%microphone-get-sample-rate-at handle index out) operation)
    (cffi:mem-ref out :int32)))

(defun %microphone-buffer-duration-at (handle index operation)
  "`SafeGetCaptureBufferDuration': the device's capture buffer duration, in ticks.

XNA reads an integer number of milliseconds and widens it with
`TimeSpan.FromMilliseconds'; CNA answers ticks directly, which is the same
quantity in this binding's TimeSpan projection."
  (cffi:with-foreign-object (out :int64)
    (%check-microphone-result
     (cna-lisp.internal.ffi::%microphone-get-buffer-duration-ticks-at handle index out)
     operation)
    (cffi:mem-ref out :int64)))

(defun %make-microphone (handle index operation)
  "Build one facade for INDEX, reading the four members XNA's constructor stores.

The order is the constructor's: the sample rate first, because the format is
built from it, then the name, then the headset flag, then the buffer duration.
Every one of them is a query that can fail, and a failure here leaves the cache
untouched -- see %ENUMERATE-MICROPHONES, which is where that is made true."
  (let* ((sample-rate (%microphone-sample-rate-at handle index operation))
         (name (%microphone-name-at handle index operation))
         (buffer-duration (%microphone-buffer-duration-at handle index operation)))
    (make-instance 'microphone
                   :index index
                   :name name
                   :sample-rate sample-rate
                   ;; **A literal, and the pinned IL is why.** See IS-HEADSET.
                   :headset t
                   :buffer-duration buffer-duration)))

(defun %enumerate-microphones (operation)
  "`MicrophoneCollection.EnumerateMicrophones', and its append-only rule.

Answers the cache. Reads CNA's count, refuses a count below the number already
cached, and appends a facade for each index that has appeared since the last
enumeration. An existing facade is never replaced, so an index names one object
for the life of the process.

**It publishes nothing until every new facade is built.** Enumeration is several
native queries per device, any of which can fail; building them into a fresh list
and appending it in one assignment is what stops a failure half way through
leaving a snapshot with three of five devices in it, which the next successful
enumeration would then never fill in -- because it starts from the cached count.
So the cache is coherent after a failure and the original condition is what the
caller sees."
  (let* ((handle (%microphone-game-handle operation))
         (count (%microphone-count handle operation))
         (known (length *microphones*)))
    (when (< count known)
      (error 'xna:cna-invalid-state-error
             :operation operation :object-type 'microphone
             :format-control
             "CNA reports ~d capture device~:p and this process has already ~
              handed out ~d. An index names one device for the life of the ~
              process, so a list that has shrunk cannot be reconciled with the ~
              microphones already given out, and XNA raises ~
              InvalidOperationException here for the same reason."
             :format-arguments (list count known)))
    (when (> count known)
      (let ((fresh (loop for index from known below count
                         collect (%make-microphone handle index operation))))
        (setf *microphones* (append *microphones* fresh))))
    *microphones*))

;;; --- All and Default -------------------------------------------------------

(defun microphone-all ()
  "Microphone.All: every capture device the runtime reports, as a list.

    (dolist (microphone (microphone-all))
      (format t \"~a at ~d Hz~%\" (name microphone) (sample-rate microphone)))

**A fresh list of cached objects.** The list is new on every call, so nothing a
caller does to it can reach the identity cache -- which is the property XNA gets
from `ReadOnlyCollection<Microphone>' and Common Lisp has no read-only sequence
to express. The *elements* are the cached facades, so `EQ' holds across calls:

    (eq (first (microphone-all)) (first (microphone-all)))  =>  T

A `ReadOnlyCollection<T>' projects onto a list here for the reason
`GraphicsAdapter.Adapters' does: a list is what Common Lisp reads a sequence you
must not mutate as. Ordering and count are CNA's, which are the runtime's.

Answers `NIL' on a machine with no capture device, which `audio.h' calls \"an
ordinary answer\" and is not a failure. It re-enumerates on every call, as XNA's
`get_All' does, so a device that has appeared since the last call is picked up.

Needs an active game, for the reason this file's header gives."
  (copy-list (%enumerate-microphones "microphone-all")))

(defun microphone-default ()
  "Microphone.Default: the capture device CNA reports as the default one, or NIL.

**It is `EQ' to one of `MICROPHONE-ALL''s objects**, never a second object with
equal slots. XNA's `SelectDefaultMicrophone' picks an element of the very list
`All' answers, and this does the same: it enumerates, resolves CNA's default
index, and returns the cached facade at that index.

**NIL when there is no capture device**, which is XNA's answer too -- its
selection leaves `defaultMic' null when the collection is empty, and null is what
the property then answers. It is not an exception there and it is not a condition
here.

**Cached once, exactly as XNA caches it.** `get_Default' returns its stored
`defaultMic' without enumerating whenever it is already set, and only re-selects
while it is null. So the first call needs an active game and later calls do not,
which is the IL's asymmetry with `MICROPHONE-ALL' -- that one enumerates every
time -- and is reproduced rather than tidied away.

If CNA reports a default index that its own count does not cover, that is a
native inconsistency and is signalled as one. No facade is manufactured outside
`MICROPHONE-ALL' to satisfy it."
  (or *default-microphone*
      (let* ((operation "microphone-default")
             (microphones (%enumerate-microphones operation)))
        (when microphones
          (let ((handle (%microphone-game-handle operation)))
            (cffi:with-foreign-objects ((index :uint64) (available :uint8))
              (%check-microphone-result
               (cna-lisp.internal.ffi::%microphone-get-default-index-ext
                handle index available)
               operation)
              ;; CNA reports availability separately from the index and leaves
              ;; the index untouched when there is none, so the flag is read
              ;; first and the index is only meaningful behind it.
              ;;
              ;; **`CNA_Bool' is one byte.** Reading it as four reads three bytes
              ;; the route never wrote, which is undefined behaviour that happens
              ;; to work while they are zero. CNA-TRUE-P over a `:uint8' is the
              ;; established shape and is what every other Bool here uses.
              (when (cna-lisp.internal.ffi:cna-true-p
                     (cffi:mem-ref available :uint8))
                (let ((chosen (cffi:mem-ref index :uint64)))
                  (unless (< chosen (length microphones))
                    (error 'xna:cna-invalid-state-error
                           :operation operation :object-type 'microphone
                           :format-control
                           "CNA reports capture device ~d as the default one and ~
                            enumerates only ~d. Default is one of the devices ~
                            All answers in XNA, so there is no object to give ~
                            back and none is invented."
                           :format-arguments (list chosen (length microphones))))
                  (setf *default-microphone* (nth chosen microphones))))))))))

;;; --- the four stored members ----------------------------------------------
;;;
;;; NAME, SAMPLE-RATE and IS-HEADSET are readers on the slots the facade was
;;; built with, because in XNA all three are field reads:
;;;
;;;   Name         `public initonly string', assigned once in the constructor
;;;                from `GetName()'. A readonly field, so it cannot change --
;;;                caching it is not an optimisation, it is what the member is.
;;;   SampleRate   `format.SampleRate', and the format is built once in the
;;;                constructor. The getter takes the lock and reads the field.
;;;   IsHeadset    the `isHeadset' field. See below.
;;;
;;; None of them needs an active game, and that is a consequence of the above
;;; rather than a convenience: a facade only exists because an enumeration
;;; succeeded, and after that XNA's getters touch nothing native.

(defmethod name ((microphone microphone))
  "Microphone.Name: the device's display name.

A method on the generic function `SOUND-EFFECT' already answers, because a
reference type's member is a bare reader by the naming rule and two types may
share one. It is `Microphone.Name' -- a `public initonly' **field** in the
pinned contract rather than a property, read once when the device was enumerated.
It is an ordinary Lisp string; the two CNA routes behind it are private UTF-8
machinery.

Two capture devices may carry the same name, so this is a label and not an
identity: the identity is the object, and `EQ' is how it is tested."
  (slot-value microphone 'name))

(defmethod sample-rate ((microphone microphone))
  "Microphone.SampleRate: the capture rate in hertz, as the device reported it.

XNA reads it once, in the constructor, to build the mono PCM16 format the
microphone keeps; the property then answers `format.SampleRate'. So it is a
stored value and cannot change under a facade.

It is the rate `GET-SAMPLE-DURATION' and `GET-SAMPLE-SIZE-IN-BYTES' compute
with, which is why a test asserts against *this* rather than against a literal
44100: the number is the device's, and only the arithmetic is XNA's."
  (slot-value microphone 'sample-rate))

(defmethod is-headset ((microphone microphone))
  "Microphone.IsHeadset: whether XNA considers this microphone part of a headset.

**It is always true, and that is the pinned assembly's answer rather than this
binding's.** `Microphone''s constructor is

    IL_004a:  ldarg.0
    IL_004b:  ldc.i4.1
    IL_004c:  stfld      bool Microsoft.Xna.Framework.Audio.Microphone::isHeadset

-- a literal `true' stored into the field -- and `get_IsHeadset' is a bare
`ldfld' of that field. It is the only `stfld' of `isHeadset' in the assembly.
There *is* a `SafeIsHeadset' method that asks the native layer, and it has **no
call sites at all**: it is compiled in and dead.

**CNA disagrees and does not win.** `cna_microphone_get_is_headset_at' reports
the device's real answer, and on the qualification's capture devices that answer
is false. Reporting it would be more informative and would be a different API
from the one this binding projects: a program ported from XNA that branches on
`IsHeadset' took the true branch there and must take it here. The native route is
bound and the qualification records both answers side by side, so the divergence
is a measurement rather than a footnote.

`docs/limitations.md' carries this."
  (slot-value microphone 'headset))

;;; --- BufferDuration --------------------------------------------------------

(defconstant +microphone-minimum-buffer-milliseconds+ 100
  "The lowest capture buffer duration XNA's setter accepts: `ldc.r8 100' in the IL.")

(defconstant +microphone-maximum-buffer-milliseconds+ 1000
  "The highest capture buffer duration XNA's setter accepts: `ldc.r8 1000' in the IL.")

(defconstant +microphone-buffer-milliseconds-step+ 10
  "The step XNA's setter requires: `TotalMilliseconds % 10 == 0' in the IL.")

(defparameter *microphone-buffer-duration-abi-limit*
  (cna-lisp.internal:encode-abi-version 0 21 0)
  "The one admitted ABI whose setter will not take the top of XNA's range.

**Measured across all three admitted ABIs with the same probe.** XNA accepts
[100, 1000] milliseconds in steps of ten, inclusive at both ends. CNA 0.21.0
accepts [100, **990**] and answers `CNA_RESULT_INVALID_ARGUMENT` for exactly
1000; 0.22.0 and 0.23.0 accept the whole range. Every other value behaves
identically on all three -- 99, 101, 1001, 100.5, zero and negative are refused
by each, and 100 through 990 in steps of ten are accepted by each.

**The device's own initial duration is 1000 ms on all three**, so on 0.21.0 a
microphone starts at a duration its own setter will not accept. That is CNA's
inconsistency and is recorded rather than worked around: the getter answers 1000
there, as it should, and only the setter refuses.

There is no fallback worth having. Rounding 1000 down to 990 would answer a
question the caller did not ask and would make `BufferDuration' disagree with
what was set, which is the one thing XNA's setter guarantees. So the value is
offered to CNA, and its refusal is re-raised as a condition that says whose
limit it is -- see %REFUSE-BUFFER-DURATION-ABI-LIMIT. `BufferDuration' is
therefore **partial on 0.21.0 and complete on 0.22.0 and 0.23.0**, which is what
`tools/api-compat/mapping-rules.json' declares.")

(defun %microphone-buffer-duration-abi-limit ()
  "The encoded ABI version whose setter refuses the top of XNA's range.

A reader rather than the variable, so the qualification can branch on it without
naming a special variable it does not own."
  *microphone-buffer-duration-abi-limit*)

(defun %refuse-buffer-duration-abi-limit (ticks operation)
  "Re-raise CNA's refusal of a duration XNA accepts, naming whose limit it is.

Reached only after XNA's own three tests have passed, so the caller's value is
one the original would have taken. A bare `CNA_RESULT_INVALID_ARGUMENT' would say
the argument was wrong; it was not, and the difference matters to whoever has to
decide whether to change their program or their library."
  (let ((loaded (cna-lisp.internal:loaded-abi-version)))
    (error 'xna:cna-not-supported-error
           :operation operation :object-type 'microphone
           :format-control
           "CNA ABI ~a will not set a capture buffer duration of ~d ticks (~d ~
            milliseconds). XNA accepts [~d, ~d] milliseconds in steps of ~d and ~
            this value is one of them, so the refusal is the ABI's and not your ~
            program's: 0.21.0 accepts [~d, 990] and answers ~
            CNA_RESULT_INVALID_ARGUMENT for exactly ~d, where 0.22.0 and 0.23.0 ~
            take the whole range. Run against a 0.22.0 or later library and this ~
            value works; 990 milliseconds is the highest 0.21.0 will take."
           :format-arguments
           (list (cna-lisp.internal:format-abi-version loaded)
                 ticks (round ticks 10000)
                 +microphone-minimum-buffer-milliseconds+
                 +microphone-maximum-buffer-milliseconds+
                 +microphone-buffer-milliseconds-step+
                 +microphone-minimum-buffer-milliseconds+
                 +microphone-maximum-buffer-milliseconds+))))

(defgeneric buffer-duration (microphone)
  (:documentation
   "Microphone.BufferDuration: how much audio the capture buffer holds, in ticks.

TimeSpan is projected as an exact count of 100-nanosecond ticks throughout this
binding, so this answers an integer.

**It answers the stored value, not the device.** XNA's getter reads the
`captureBufferDuration' field under the microphone's lock and never goes back to
the native layer; the field is filled in the constructor from the device and
updated by the setter. So this is a mirror of what the device was last told, and
that is what the original exposes."))

(defgeneric (setf buffer-duration) (ticks microphone)
  (:documentation
   "Microphone.BufferDuration's setter, with the pinned IL's exact validation.

Three tests, in the IL's order, all against `value.TotalMilliseconds' as a
`float64':

    < 100                 -> ArgumentOutOfRangeException(\"value\", ...)
    > 1000                -> ArgumentOutOfRangeException(\"value\", ...)
    % 10 != 0             -> ArgumentOutOfRangeException(\"value\", ...)

and then, and only then, the native setter -- after which **the value the caller
gave is stored**, unchanged. `set_BufferDuration' ends with `ldarg.0; ldarg.1;
stfld captureBufferDuration'. **XNA does not round.** It refuses anything that is
not already a whole multiple of 10 ms in [100, 1000], and a value that passes is
stored exactly.

**That matters because CNA's header says otherwise.**
`cna_microphone_set_buffer_duration_ticks_at' documents its argument as \"the
canonical setter validates and rounds it\". Measured against all three admitted
ABIs, it accepts 1005000 ticks -- 100.5 ms -- and afterwards reports 1005000: it
neither rounded nor refused. Reproducing XNA means refusing that here, before the
route is called, which is what makes CNA's rounding claim implementation support
rather than the compatibility contract. The qualification asserts the public
refusal and records CNA's acceptance beside it.

**And one value of XNA's range is unreachable on CNA 0.21.0**: exactly 1000
milliseconds, the top of it, which 0.22.0 and 0.23.0 accept. That refusal is
CNA's and is reported as such rather than as an argument error -- see
*MICROPHONE-BUFFER-DURATION-ABI-LIMIT*. It is why this member is declared
**partial on 0.21.0**; nothing is rounded down to hide it."))

(defmethod buffer-duration ((microphone microphone))
  (%buffer-duration microphone))

(defmethod (setf buffer-duration) (ticks (microphone microphone))
  (let ((operation "buffer-duration"))
    (unless (integerp ticks)
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name "value" :object-type 'microphone
             :format-control
             "the buffer duration is a TimeSpan, which this binding projects as a ~
              whole number of 100-nanosecond ticks; ~s is not one."
             :format-arguments (list ticks)))
    (let ((milliseconds (%total-milliseconds ticks)))
      (unless (and (<= (coerce +microphone-minimum-buffer-milliseconds+ 'double-float)
                       milliseconds
                       (coerce +microphone-maximum-buffer-milliseconds+ 'double-float))
                   (zerop (mod milliseconds
                               (coerce +microphone-buffer-milliseconds-step+
                                       'double-float))))
        (error 'xna:cna-argument-out-of-range-error
               :operation operation :parameter-name "value" :object-type 'microphone
               :format-control
               "the capture buffer duration must be a whole multiple of ~d ~
                milliseconds between ~d and ~d; ~s ticks is ~f milliseconds. ~
                XNA validates and does not round, so a value between two steps ~
                is refused rather than moved to one of them."
               :format-arguments (list +microphone-buffer-milliseconds-step+
                                       +microphone-minimum-buffer-milliseconds+
                                       +microphone-maximum-buffer-milliseconds+
                                       ticks milliseconds)))
      (let* ((handle (%microphone-game-handle operation))
             (code (cna-lisp.internal.ffi::%microphone-set-buffer-duration-ticks-at
                    handle (%microphone-index microphone) ticks)))
        ;; The value has already passed XNA's own three tests, so an
        ;; invalid-argument answer here is the ABI's limit rather than the
        ;; caller's mistake, and is reported as one.
        (if (= code cna-lisp.internal.ffi::+result-invalid-argument+)
            (%refuse-buffer-duration-abi-limit ticks operation)
            (%check-microphone-result code operation)))
      ;; XNA stores the value it was given, not one it read back.
      (setf (%buffer-duration microphone) ticks))))

;;; --- State, Start and Stop -------------------------------------------------

(defmethod state ((microphone microphone))
  "Microphone.State: `:STARTED' or `:STOPPED'.

The one property that asks the device rather than a slot: `get_State' calls the
native `GetState' on every read and maps its private `MicrophoneCaptureState' --
MicStarted 1, MicStopped 2 -- onto the public pair, in which Started is 0.
Translated **by name** through the enumeration table rather than passed through as
a number, for the reason `SOUND-EFFECT-INSTANCE''s `STATE' gives: agreement
between the two numberings is not a reason to skip the table.

Needs an active game."
  (let* ((operation "state")
         (handle (%microphone-game-handle operation)))
    (cffi:with-foreign-object (out :uint32)
      (%check-microphone-result
       (cna-lisp.internal.ffi::%microphone-get-state-at
        handle (%microphone-index microphone) out)
       operation)
      (microphone-state-from-value (cffi:mem-ref out :uint32)))))

(defgeneric start (microphone)
  (:documentation
   "Microphone.Start: begin capturing.

XNA's body is the native `Start' under the microphone's lock, with the result
code turned into an exception -- there is no state test before it and no
bookkeeping after it, so what a repeated `START' does is whatever the capture
engine does. Measured against all three admitted ABIs, CNA accepts it and the
state stays `:STARTED'; that is recorded as CNA's answer through XNA's shape
rather than claimed as an XNA rule the IL does not contain.

`NO-MICROPHONE-CONNECTED-ERROR' is the failure this route documents, and it is
the only microphone route that documents it.

Needs an active game."))

(defmethod start ((microphone microphone))
  (let* ((operation "start")
         (handle (%microphone-game-handle operation)))
    (%check-microphone-result
     (cna-lisp.internal.ffi::%microphone-start-at handle (%microphone-index microphone))
     operation)
    (values)))

(defmethod stop ((microphone microphone) &optional (immediate nil immediate-p))
  "Microphone.Stop: stop capturing.

Like `START' it is the bare native call under the lock, so a repeated `STOP' is
the capture engine's business; CNA accepts it and the state stays `:STOPPED'.

Captured data already in the buffer is not this operation's concern, and neither
framework says anything about it. What `STOP' ends is the capture, not the
object: the runtime owns the microphone and the facade stays usable.

**IMMEDIATE is refused rather than ignored, and that is the point of it being
here.** `SoundEffectInstance.Stop' has two overloads and this generic function's
lambda list carries the optional they collapse to; `Microphone.Stop' has **one**
overload and takes no argument. CLOS congruence forces the parameter onto this
method, so supplying it is refused -- because a method that accepted and dropped
it would give `Microphone' a `Stop(bool)' XNA has not got. This is the same rule
%CHECK-OVERLOAD-KEYWORDS enforces for keywords, in the one place an *optional*
reaches a member that has none.

Needs an active game."
  (let* ((operation "stop")
         (handle (%microphone-game-handle operation)))
    (when immediate-p
      (error 'xna:cna-usage-error
             :operation operation :object-type 'microphone
             :format-control
             "Microphone.Stop takes no argument: ~s was given. The optional ~
              belongs to SoundEffectInstance.Stop, whose two overloads share ~
              this generic function, and accepting it here would give Microphone ~
              a Stop(bool) the original has not got."
             :format-arguments (list immediate)))
    (%check-microphone-result
     (cna-lisp.internal.ffi::%microphone-stop-at handle (%microphone-index microphone))
     operation)
    (values)))

;;; --- the sample arithmetic -------------------------------------------------
;;;
;;; **Not `SoundEffect''s, and the IL is why.** The two members have the same
;;; names as the static pair on `SoundEffect' and the same names as the instance
;;; pair on `DynamicSoundEffectInstance', and all three compute through
;;; `AudioFormat'. What differs is the *guards*, and a guard is observable:
;;;
;;;   SoundEffect          checks the sample rate against [8000, 48000] and the
;;;                        channel count against [1, 2], because both are
;;;                        parameters a caller supplies.
;;;   Microphone           checks **neither**. The rate and the channel count come
;;;                        from the device's own format, so there is no argument
;;;                        to be out of range and the IL has no such test. A
;;;                        microphone whose device reported a rate outside
;;;                        SoundEffect's bounds still answers here, exactly as it
;;;                        does in XNA.
;;;
;;; So these delegate to the two `AudioFormat' primitives and not to
;;; `SOUND-EFFECT-GET-SAMPLE-DURATION', which would add a guard this member has
;;; not got.

(defun %microphone-duration-from-size (size-in-bytes sample-rate)
  "`AudioFormat.DurationFromSize', in ticks, for a mono PCM16 format.

    frames = sizeInBytes / BlockAlign          integer division, truncating
    ms     = (float)frames * 1000f / (float)sampleRate
    TimeSpan.FromMilliseconds((double)ms)

The middle line is **binary32 throughout** -- `conv.r4', `ldc.r4 1000', `mul',
`conv.r4', `div' -- and only then widened, so the rounding is single-precision
and reproducing it in double would answer different bits. `FromMilliseconds'
then rounds half away from zero to a whole millisecond, which is what
%TICKS-FROM-MILLISECONDS does and is shared with the SoundEffect surface because
it is one fact in the pinned assembly."
  (let* ((frames (truncate size-in-bytes +microphone-block-align+))
         (milliseconds (xna::f (/ (* (xna::f frames) 1000.0f0)
                                  (xna::f sample-rate)))))
    (%ticks-from-milliseconds milliseconds)))

(defun %microphone-size-from-duration (ticks sample-rate operation)
  "`AudioFormat.SizeFromDuration' for a mono PCM16 format.

    n      = checked((int)(TotalMilliseconds * (double)((float)sampleRate / 1000f)))
    result = checked(checked(n + n % Channels) * BlockAlign)

**The division is binary32 and the multiplication is binary64**, which is the
whole reason this is not `TotalMilliseconds * sampleRate / 1000': `(float)44100 /
1000f' is 44.09999847412109375, not 44.1, so one second of 44.1 kHz mono PCM16 is
88198 bytes here and in XNA -- and 88200 in CNA's own route, which is one of the
four divergences this file's header lists.

Channels is 1 for every microphone, so `n % Channels' is always zero; it is
computed rather than dropped because the term is XNA's and dropping it would make
this a different function that happens to agree."
  (let* ((total-milliseconds (%total-milliseconds ticks))
         (per-millisecond (xna::f (/ (xna::f sample-rate) 1000.0f0)))
         (n (%checked-int32 (truncate (* total-milliseconds
                                         (coerce per-millisecond 'double-float)))
                            ticks operation))
         (aligned (%checked-int32 (+ n (mod n +microphone-channels+))
                                  ticks operation)))
    (%checked-int32 (* aligned +microphone-block-align+) ticks operation)))

(defmethod get-sample-duration ((microphone microphone) size-in-bytes)
  "Microphone.GetSampleDuration(Int32): how long SIZE-IN-BYTES of capture lasts.

Answers a tick count, because TimeSpan is a tick count throughout this binding.

**Two guards and they are not SoundEffect's.** The IL's order is:

    sizeInBytes < 0   -> ArgumentException(FrameworkResources.InvalidBufferSize)
    sizeInBytes == 0  -> TimeSpan.Zero, returned early
    otherwise            format.DurationFromSize(sizeInBytes)

Note the first is an `ArgumentException', not the `ArgumentOutOfRangeException'
that `GET-SAMPLE-SIZE-IN-BYTES' raises next door -- the two members disagree about
which exception an out-of-range argument gets, and that is the original's
inconsistency rather than this projection's. There is no sample-rate guard and no
channel guard: both come from the device.

An `Int32' upper bound is enforced because `sizeInBytes' is one: Common Lisp
would otherwise accept an integer XNA cannot be handed and answer a duration no
XNA program can obtain. That is the same reason `SOUND-EFFECT-GET-SAMPLE-DURATION'
enforces it.

**CNA's own route answers differently and is not used.** It truncates where
`TimeSpan.FromMilliseconds' rounds: 46 bytes at 44100 Hz is 0.5215 ms, which CNA
reports as 0 ticks and XNA as 10000. The arithmetic here is XNA's."
  (let ((operation "get-sample-duration"))
    (unless (and (integerp size-in-bytes)
                 (<= 0 size-in-bytes +int32-maximum+))
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "size-in-bytes"
             :object-type 'microphone
             :format-control
             "size-in-bytes is an Int32 and must not be negative; it must lie in ~
              [0, ~d] and ~s was given."
             :format-arguments (list +int32-maximum+ size-in-bytes)))
    (if (zerop size-in-bytes)
        0
        (%microphone-duration-from-size size-in-bytes (sample-rate microphone)))))

(defmethod get-sample-size-in-bytes ((microphone microphone) duration)
  "Microphone.GetSampleSizeInBytes(TimeSpan): the bytes DURATION of capture needs.

DURATION is a tick count, for the reason `GET-SAMPLE-DURATION' answers one.

**Three guards, in the IL's order:**

    TotalMilliseconds < 0            -> ArgumentOutOfRangeException(\"duration\")
    TotalMilliseconds > 2147483647   -> ArgumentOutOfRangeException(\"duration\")
    duration == TimeSpan.Zero        -> 0, returned early

and then `format.SizeFromDuration' inside a `checked' region whose
`OverflowException' is caught and re-thrown as the *same* duration exception.
Again there is no sample-rate or channel guard: this is not SoundEffect's member.

**CNA's own route answers differently and is not used**, twice over: it computes
one second of 44.1 kHz mono as 88200 where XNA's binary32 division gives 88198,
and it accepts a negative duration and answers a negative byte count where XNA
throws."
  (let ((operation "get-sample-size-in-bytes"))
    (unless (integerp duration)
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name "duration"
             :object-type 'microphone
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
               :object-type 'microphone
               :format-control
               "duration must be a tick count in [0, ~d] -- that is [0, ~d] ~
                milliseconds, which is Int32.MaxValue and XNA's own upper bound; ~
                ~s was given."
               :format-arguments (list +maximum-duration-ticks+
                                       +maximum-duration-milliseconds+ duration)))
      (if (zerop duration)
          0
          (%microphone-size-from-duration duration (sample-rate microphone)
                                          operation)))))

;;; --- GetData ---------------------------------------------------------------

(defun %check-microphone-count (offset count buffer sample-rate operation)
  "`GetData''s third guard, which is `%CHECK-COUNT' plus one test XNA adds here.

The shared `%CHECK-COUNT' covers the four conditions `SoundEffect' and
`DynamicSoundEffectInstance' share -- a non-positive count, a misaligned count,
and `offset + count' past the end, which subsumes the `checked' overflow Common
Lisp integers cannot have.

`Microphone.GetData' has a **fifth** condition in the same `||' chain and no
other member does:

    format.DurationFromSize(count) == TimeSpan.Zero

-- a count whose duration rounds to zero milliseconds is refused. At 44100 Hz that
is every count below 46 bytes, because 22 sample frames is 0.4989 ms and rounds to
zero while 23 is 0.5215 ms and rounds to one. It is checked last because it is
last in the IL's chain, and it is checked at all because a projection that dropped
it would accept a two-byte read XNA refuses."
  (%check-count offset count buffer +microphone-block-align+ operation
                :object-type 'microphone)
  (when (zerop (%microphone-duration-from-size count sample-rate))
    (error 'xna:cna-argument-error
           :operation operation :parameter-name "count"
           :object-type 'microphone
           :format-control
           "count must name at least a whole millisecond of capture at this ~
            microphone's ~d Hz; ~d byte~:p rounds to a zero duration, which XNA ~
            refuses in GetData's own last test."
           :format-arguments (list sample-rate count))))

(defgeneric get-data (microphone buffer &key &allow-other-keys)
  (:documentation
   "Microphone.GetData: read captured PCM16 into BUFFER, and answer the byte count.

Two overloads, selected by the complete keyword set:

    (get-data microphone buffer)                       GetData(Byte[])
    (get-data microphone buffer :offset o :count n)    GetData(Byte[], Int32, Int32)

`:OFFSET' alone and `:COUNT' alone are shapes XNA has not got, and
%CHECK-OVERLOAD-KEYWORDS refuses them rather than defaulting the difference.

**A short read is success, including a read of zero bytes.** Capture is a stream:
`audio.h' says so in as many words -- \"a short read is **not** a failure here:
the canonical operation fills what it can and reports how much\" -- and XNA
returns the count the native layer wrote. So the answer is the number of bytes
actually written, `[offset, offset + answer)' of BUFFER holds them, and **every
other byte of BUFFER is left exactly as it was**. Nothing is filled in and a
short read is never turned into a buffer-too-small condition.

**A microphone that is not started answers 0 and reads nothing.** XNA's last act
before the native call is `if (State != Started) return 0', so this is a normal
answer rather than a refusal, and no condition is signalled.

The validation order is the pinned IL's, and which condition a call wrong in two
ways gets is decided by it:

    buffer null, empty, or length not a whole sample frame
        -> ArgumentException(InvalidAudioBuffer)
    offset < 0, offset >= length, or offset not a whole sample frame
        -> ArgumentException(InvalidAudioBufferOffset)
    count <= 0, offset + count > length, count not a whole sample frame,
    or count's duration rounding to zero
        -> ArgumentException(InvalidOffsetCountLength)

Needs an active game."))

(defparameter *microphone-get-data-overloads*
  '((:whole-buffer) (:range "offset" "count"))
  "XNA's two GetData overloads, shortest first.

    GetData(Byte[])                  no keyword at all
    GetData(Byte[], Int32, Int32)    :OFFSET and :COUNT, both or neither

The buffer is positional in both and is therefore in neither keyword set.")

(defmethod get-data ((microphone microphone) buffer
                     &rest settings &key offset count &allow-other-keys)
  (let* ((operation "get-data")
         (shape (xna::%check-overload-keywords
                 operation
                 (loop for (key nil) on settings by #'cddr
                       collect (string-downcase (symbol-name key)))
                 *microphone-get-data-overloads* :object-type 'microphone))
         (sample-rate (sample-rate microphone)))
    ;; The one-argument overload's own check runs first and is the same one, then
    ;; it calls the three-argument overload with (0, buffer.Length) -- so the
    ;; buffer test happens once here and the range is derived rather than
    ;; defaulted.
    (%check-buffer buffer +microphone-block-align+ operation :object-type 'microphone)
    (unless (eq shape :range)
      (setf offset 0 count (length buffer)))
    (%check-offset offset buffer +microphone-block-align+ operation
                   :object-type 'microphone)
    (%check-microphone-count offset count buffer sample-rate operation)
    (if (eq (state microphone) :stopped)
        ;; `if (get_State() != Started) return 0' -- an answer, not a refusal.
        0
        (let ((handle (%microphone-game-handle operation)))
          (cffi:with-foreign-object (destination :uint8 count)
            (cffi:with-foreign-object (written :uint64)
              (%check-microphone-result
               (cna-lisp.internal.ffi::%microphone-get-data-at
                handle (%microphone-index microphone) destination count written)
               operation)
              (let ((n (cffi:mem-ref written :uint64)))
                (when (> n count)
                  ;; CNA promises never to write past the capacity it was given.
                  ;; If it ever reported more than it was allowed to write, the
                  ;; bytes are already gone and the count is not usable.
                  (error 'xna:cna-invalid-state-error
                         :operation operation :object-type 'microphone
                         :format-control
                         "CNA reported ~d captured byte~:p into a ~d-byte ~
                          request, which its own route forbids."
                         :format-arguments (list n count)))
                ;; Exactly the reported range, and nothing else: the bytes
                ;; outside it are the caller's and are left alone.
                (dotimes (i n)
                  (setf (aref buffer (+ offset i))
                        (cffi:mem-aref destination :uint8 i)))
                n)))))))

;;; --- the BufferReady event -------------------------------------------------
;;;
;;; Projected through the machinery every other CLR event in this binding uses,
;;; because CNA's microphone subscription has the same three parts as the game's
;;; and the streaming instance's: a `void (*)(void*)' callback, an integer context
;;; this binding resolves back to a rooted Lisp object, and an owned registration
;;; handle released by `cna_audio_unsubscribe_ext'. **No Lisp object is ever
;;; handed to C.**
;;;
;;; **XNA's own semantics, from the IL:**
;;;
;;;   sender      the `Microphone'. `MicrophoneCollection.OnBufferReady(handle)'
;;;               walks `allMicrophones' for the element whose `Handle' matches
;;;               and calls `that.OnBufferReady(EventArgs.Empty)', which invokes
;;;               `handler(this, args)'. So the sender is **the very object the
;;;               list holds**, which is the object `All' and `Default' hand out
;;;               -- not a new wrapper built from an index. That is why the
;;;               dispatch below resolves the cached facade and the qualification
;;;               asserts it with `EQ'.
;;;   args        `EventArgs.Empty', which carries nothing -- so the projected
;;;               handler takes the sender and nothing else, the decision every
;;;               other event here makes.
;;;   add/remove  ordinary `Delegate.Combine'/`Remove' against the private
;;;               `BufferReady' field through an `Interlocked.CompareExchange'
;;;               loop, with no other call at all.
;;;   threshold   XNA raises it "when the buffer is full", which is not a number
;;;               either framework publishes. CNA raises it from
;;;               `cna_microphone_check_all_buffers_ext', which
;;;               `cna_framework_dispatcher_update' drives as part of the frame.
;;;               Measured: nothing arrives until the unread backlog reaches
;;;               `BufferDuration', and then it arrives on every check until
;;;               `GET-DATA' drains it. **That rate is not asserted anywhere**,
;;;               because it is neither framework's contract; what the
;;;               qualification asserts is that the event arrives, that its sender
;;;               is the right object, and that removing the handler stops it.
;;;
;;; **There is no disposal seam here, and that is the difference from every other
;;; event in this binding.** %EVENT-SOURCE-DISPOSED-P exists because a
;;; `GraphicsResource' or a `DynamicSoundEffectInstance' can be destroyed while
;;; its handler list survives. A microphone cannot: the runtime owns it and
;;; nothing this binding does ends it, so the default NIL is correct and a
;;; subscription is always a real native registration.

(xna::%define-event-pair add-buffer-ready-handler remove-buffer-ready-handler
  "Microphone.BufferReady's `+=': call HANDLER when captured data is ready to read.

    (add-buffer-ready-handler microphone
                              (lambda (microphone)
                                (let ((n (get-data microphone buffer)))
                                  (consume buffer n))))

HANDLER takes the sender and nothing else, because XNA passes `EventArgs.Empty'
and a second always-empty argument would be one every handler had to write and
ignore.

**The sender is the same object `MICROPHONE-ALL' and `MICROPHONE-DEFAULT' answer**,
never a fresh facade built from the device index -- `EQ' holds, and the
qualification asserts it. XNA raises the event on the element of its own device
list, and so does this.

It is called on the thread that advances the frame. A condition it signals cannot
be reported to CNA -- the callback answers `void' -- so it is contained there and
re-signalled by the first native call that returns to your program afterwards,
under the rule `src/internal/callback-conditions.lisp' owns for every callback in
this binding.

Removing the last handler releases the native registration; removing a handler
that was never added answers NIL and does nothing, which is what
`Delegate.Remove' does silently.")

(defparameter *microphone-event-values*
  (list (cons :buffer-ready 0))
  "The one event a Microphone raises.

The value is unused and is zero, for the reason `DynamicSoundEffectInstance''s
is: CNA's microphone subscription names the event by *route* rather than by an
identity passed to a shared one, so there is no constant to carry. The table is
still a table because %SUBSCRIBE-EVENT looks the keyword up in it to decide
whether the object raises the event at all.")

(defmethod xna::%event-table ((microphone microphone))
  *microphone-event-values*)

(defmethod xna::%check-event-usable ((microphone microphone) operation)
  "A microphone has no handle to check; what has to be usable is the game.

The default method is NATIVE-OBJECT's, and a MICROPHONE is not one. This is the
same seam GAME-COMPONENT-COLLECTION uses for the same reason: a facade's
usability is the usability of the object that really holds the native state."
  (%microphone-game-handle operation))

(defmethod xna::%subscribe-natively ((microphone microphone) value token registration)
  (declare (ignore value))
  (cna-lisp.internal.ffi::%microphone-subscribe-buffer-ready-at
   (%microphone-game-handle "add-buffer-ready-handler")
   (%microphone-index microphone)
   (cna-lisp.internal.ffi:audio-event-callback-pointer)
   (cffi:make-pointer token)
   registration))

(defmethod xna::%unsubscribe-natively ((microphone microphone) registration)
  "Audio registrations are released by their own route.

`cna_audio_unsubscribe_ext' takes \"an owned registration handle from any audio
subscribe route\", and `cna_microphone_subscribe_buffer_ready_at' is one of them;
`cna_game_unsubscribe', which the default method calls, does not accept one."
  (cna-lisp.internal.ffi::%audio-unsubscribe-ext registration))

(xna::%define-event-methods microphone :buffer-ready
                            add-buffer-ready-handler remove-buffer-ready-handler)

;;; --- the type's own .NET name ----------------------------------------------

(defmethod xna:clr-type-name ((microphone microphone))
  "The .NET type name CNA reports for the microphone type.

A CNA-Lisp addition rather than an XNA member, exactly as it is on GAME: it is
what makes the structural claim -- that this class projects
`Microsoft.Xna.Framework.Audio.Microphone' -- checkable against the runtime
instead of asserted.

**It belongs to the type and not to the device.** CNA's two routes take a game
and no index, so this answers the same string for every microphone and would
answer it on a machine with none; it is a method on the instance because that is
where the generic function's other methods are, and because a program with no
microphone has no object to ask."
  (let ((handle (%microphone-game-handle "clr-type-name")))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%microphone-get-type-name-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%microphone-copy-type-name handle buffer capacity out))
     "clr-type-name")))
