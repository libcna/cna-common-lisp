;;;; microphone.lisp --- the Microphone closure against a real CNA C ABI library.
;;;;
;;;; **Nothing here is a claim that a microphone heard anything.** No assertion
;;;; below inspects a captured byte: what is asserted is *enumeration, object
;;;; identity, state, buffer arithmetic and event semantics* over whatever stream
;;;; the device produces. `docs/qualification.md' names the evidence levels;
;;;; audible correctness is not among them and no assertion below implies it.
;;;;
;;;; **Which device produces that stream is the driver's business and this file
;;;; does not choose one.** `tools/qualification/microphone.sh' does -- it runs
;;;; the suite under `SDL_AUDIODRIVER=dummy', whose capture devices produce
;;;; silence, and under a driver that does not exist -- and it is where the
;;;; strongest supportable sentence is written out in full. A developer's machine
;;;; running the suite directly may have real capture hardware; that changes
;;;; which device answered and changes none of the assertions.
;;;;
;;;; **Two branches and both assert.** This is the rule the audio and rasterizer
;;;; lanes already follow, and for the same reason: a lane that cannot fail for
;;;; the right reason proves nothing.
;;;;
;;;;   capture devices enumerated   MICROPHONE_ENUMERATION and the four lanes
;;;;                                below it are asserted
;;;;   none enumerated              **MICROPHONE_UNAVAILABLE**: `MICROPHONE-ALL'
;;;;                                must answer the empty list and
;;;;                                `MICROPHONE-DEFAULT' must answer NIL, and
;;;;                                they do
;;;;
;;;; Neither branch is a skip. `audio.h' calls a count of zero "an ordinary
;;;; answer", so the no-device branch is a *result* rather than a missing test,
;;;; and `SDL_AUDIODRIVER' chooses which branch runs deterministically and with
;;;; no hardware on either side.
;;;;
;;;; **The device's own numbers are read, not assumed.** The qualification
;;;; environment's dummy devices report 44100 Hz, and no assertion below is
;;;; written against 44100: every arithmetic expectation is computed from
;;;; `SAMPLE-RATE' as the microphone reports it, so the tests measure XNA's
;;;; arithmetic rather than one machine's device. The one place a literal appears
;;;; is beside a computed expectation, to show the reader what the numbers are on
;;;; the reference runtime.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

;;; --- what the microphone lanes prove, kept apart ---------------------------

(defvar *microphone-evidence* '()
  "What the microphone tests actually proved, newest first: (LEVEL . DESCRIPTION).

  :unavailable            no capture device was enumerated, and `MICROPHONE-ALL'
                          answered the empty list rather than failing
  :enumeration            devices were enumerated, and their object identity,
                          default selection and stored properties hold
  :capture-state-machine  `START', `STOP' and repeated calls moved `STATE'
  :capture-data           `GET-DATA' wrote captured PCM16 into exactly the range
                          it reported and advanced at the reported sample rate
  :buffer-ready           the BufferReady event reached the right object and
                          stopped when its handler was removed

Kept apart for the reason the audio and rasterization kinds are: proving that
devices enumerate says nothing about whether capture advances, proving that
capture advances says nothing about the event, and a summary that collapsed them
would let one be read as another. **None of them is a claim that a sound was
captured**: the qualification's capture device is SDL's dummy backend and every
byte it produces is zero.")

(defun note-microphone (level description &rest arguments)
  "Record LEVEL once. Many tests take the same branch and they are the same
evidence; the summary says what was proved, not how many tests proved it."
  (unless (assoc level *microphone-evidence*)
    (push (cons level (apply #'format nil description arguments))
          *microphone-evidence*)))

(defun microphone-proved-p (level)
  (assoc level *microphone-evidence*))

(defvar *microphone-divergences* '()
  "Each place CNA and the pinned XNA behaviour were measured to disagree.

**A separate list rather than another evidence level**, because these are not a
claim about what was qualified: they are the record of four decisions, each one a
place where following CNA would have been easier and would have produced a
different API from the one this binding projects. The tests assert the public
answer is XNA's; this is what makes CNA's answer visible beside it in the summary
instead of only in a comment.

Newest first. The runner prints them under the microphone evidence.")

(defun note-microphone-divergence (description &rest arguments)
  "Record one measured CNA/XNA disagreement, once."
  (let ((line (apply #'format nil description arguments)))
    (pushnew line *microphone-divergences* :test #'string=)))

;;; --- fixtures ---------------------------------------------------------------

(defmacro with-microphone-game ((variable) &body body)
  "Run BODY with a live game, so the microphone surface has one to resolve.

Every `cna_microphone_*' route takes an active owned or callback-borrowed game
handle and none of them needs to be inside a lifecycle callback, so the game is
created and destroyed rather than run -- except where a test runs frames on
purpose, which is what drives the buffer-ready dispatcher.

**The identity cache is reset around the body**, and only the tests may do that:
the cache is process-global by design, and a test that needs to observe a *first*
enumeration has to be able to have one more than once in a single image. Nothing
in the public API can reach %RESET-MICROPHONE-CACHE."
  `(let ((,variable (make-instance 'xna:game :window-title "cna-lisp microphone tests")))
     (declare (ignorable ,variable))
     (audio::%reset-microphone-cache)
     (unwind-protect (progn ,@body)
       (audio::%reset-microphone-cache)
       (%tear-down-audio-game ,variable))))

(defun microphone-or-nil (game)
  "The default capture device, or NIL when the environment has none.

Reads `MICROPHONE-DEFAULT' rather than the first of `MICROPHONE-ALL', because the
two are required to be `EQ' and a fixture that quietly used the other would hide a
failure of that requirement."
  (declare (ignore game))
  (audio:microphone-default))

;;; --- the native cross-checks -------------------------------------------------
;;;
;;; Four CNA routes the public API deliberately does **not** use for its answer:
;;; `get_is_headset_at', `get_sample_duration_ticks_at',
;;; `get_sample_size_in_bytes_at' and `set_buffer_duration_ticks_at'. They are
;;; bound so that the divergence between CNA and the pinned XNA behaviour is a
;;; *measurement* in this file rather than a sentence in a comment, and each of
;;; the tests below asserts what CNA answers beside what the binding answers.
;;;
;;; They call the generated layer directly on purpose: routing them through the
;;; public API would defeat the point, which is to observe the two sides
;;; separately.

(defun %probe-microphone-is-headset (game index)
  "Answer (values RESULT HEADSET-P) from cna_microphone_get_is_headset_at."
  (declare (ignore game))
  (cffi:with-foreign-object (out :int32)
    (let ((result (ffi::%microphone-get-is-headset-at
                   (int:handle-of (int:active-game)) index out)))
      (values result (not (zerop (cffi:mem-ref out :int32)))))))

(defun %probe-microphone-sample-duration (game index size-in-bytes)
  "Answer (values RESULT TICKS) from cna_microphone_get_sample_duration_ticks_at."
  (declare (ignore game))
  (cffi:with-foreign-object (out :int64)
    (let ((result (ffi::%microphone-get-sample-duration-ticks-at
                   (int:handle-of (int:active-game)) index size-in-bytes out)))
      (values result (cffi:mem-ref out :int64)))))

(defun %probe-microphone-sample-size (game index ticks)
  "Answer (values RESULT BYTES) from cna_microphone_get_sample_size_in_bytes_at."
  (declare (ignore game))
  (cffi:with-foreign-object (out :int32)
    (let ((result (ffi::%microphone-get-sample-size-in-bytes-at
                   (int:handle-of (int:active-game)) index ticks out)))
      (values result (cffi:mem-ref out :int32)))))

(defun %probe-microphone-set-buffer-duration (game index ticks)
  "Answer the result code from cna_microphone_set_buffer_duration_ticks_at."
  (declare (ignore game))
  (ffi::%microphone-set-buffer-duration-ticks-at
   (int:handle-of (int:active-game)) index ticks))

(defun %probe-microphone-buffer-duration (game index)
  "Answer the ticks cna_microphone_get_buffer_duration_ticks_at reports."
  (declare (ignore game))
  (cffi:with-foreign-object (out :int64)
    (ffi::%microphone-get-buffer-duration-ticks-at
     (int:handle-of (int:active-game)) index out)
    (cffi:mem-ref out :int64)))

(defun %note-unavailable ()
  "The MICROPHONE_UNAVAILABLE assertion, which is a result and not a skip."
  (is (null (audio:microphone-all))
      "no capture device was enumerated, so All must be the empty list")
  (is (null (audio:microphone-default))
      "and Default must be NIL rather than an invented object")
  (note-microphone
   :unavailable
   "no capture device was enumerated: All answered the empty list and Default ~
    answered NIL, which audio.h calls an ordinary answer rather than a failure"))

;;; --- MicrophoneState, against both authorities ------------------------------

(test the-microphone-state-enumeration-is-the-contracts
  "The exact values of the pinned contract, which is also the pinned IL:
`Started' 0 and `Stopped' 1 -- the opposite of the order a reader expects, and
not the numbering of `SoundState' next door."
  (is (= 0 (audio:microphone-state-value :started)))
  (is (= 1 (audio:microphone-state-value :stopped)))
  (is (eq :started (audio:microphone-state-from-value 0)))
  (is (eq :stopped (audio:microphone-state-from-value 1)))
  (is (equal '(:started :stopped) (audio:all-microphone-state))
      "and there are exactly two, in contract order")
  ;; The two enumerations of this namespace do not share a "stopped" value, so
  ;; nothing may be read across from one to the other.
  (is (/= (audio:microphone-state-value :stopped)
          (audio:sound-state-value :stopped))
      "MicrophoneState.Stopped is 1 and SoundState.Stopped is 2; a projection ~
       that read one for the other would be wrong in both directions"))

(test the-microphone-state-enumeration-agrees-with-cna
  "Asserted rather than assumed, for the reason `BlendFunction' exists: XNA and
CNA happen to agree here, and the one enumeration where they do not is the one
that would have been silently wrong under a numeric pass-through."
  (is (= (audio:microphone-state-value :started)
         cna-lisp.internal.ffi::+microphone-state-started+))
  (is (= (audio:microphone-state-value :stopped)
         cna-lisp.internal.ffi::+microphone-state-stopped+)))

;;; --- NoMicrophoneConnectedException -----------------------------------------

(test the-no-microphone-condition-is-a-not-supported-error
  "It subclasses the exact result-code condition CNA raises for it, so a program
can handle either the XNA-specific class or the CNA result-code class."
  (is (subtypep 'audio:no-microphone-connected-error 'xna:cna-not-supported-error))
  (is (subtypep 'audio:no-microphone-connected-error 'xna:cna-error))
  ;; And it is *not* the sibling that shares its result code: the two are
  ;; distinguished by the route that answered, so neither may catch the other.
  (is (not (subtypep 'audio:no-microphone-connected-error
                     'audio:no-audio-hardware-error)))
  (is (not (subtypep 'audio:no-audio-hardware-error
                     'audio:no-microphone-connected-error))))

(test the-no-microphone-condition-expresses-all-three-constructors
  "`new()', `new(String)' and `new(String, Exception)' are one MAKE-CONDITION
call, and each of the three has to be expressible rather than merely accepted --
which is what a `:report' that ignored its message would fail."
  (let ((plain (make-condition 'audio:no-microphone-connected-error)))
    (is (search "no microphone is connected" (princ-to-string plain))))
  (let ((with-message (make-condition 'audio:no-microphone-connected-error
                                      :format-control "the capture rig is unplugged")))
    (is (search "the capture rig is unplugged" (princ-to-string with-message))
        "new(String)'s message must be shown, not merely stored"))
  (let* ((cause (make-condition 'xna:cna-io-error :operation "probe"))
         (with-cause (make-condition 'audio:no-microphone-connected-error
                                     :format-control "outer" :cause cause)))
    (is (eq cause (xna:cna-error-cause with-cause))
        "new(String, Exception)'s inner exception must be readable back")))

;;; --- the projection needs a game, and says so -------------------------------

(test microphone-enumeration-with-no-game-signals-the-scope-condition
  "XNA's `Microphone.All' takes no game and CNA's routes need one. With no active
game the established projection-limit condition is raised, naming what is
missing -- the same one `Keyboard.GetState' and the SoundEffect surface raise,
and the same one `docs/limitations.md' records."
  (audio::%reset-microphone-cache)
  (signals xna:cna-invalid-state-error (audio:microphone-all))
  (signals xna:cna-invalid-state-error (audio:microphone-default)))

;;; --- enumeration and identity ----------------------------------------------

(define-native-test the-microphone-type-is-the-one-this-class-projects
  "CNA's own name for the type, which makes the structural claim checkable
against the runtime instead of asserted. It answers per *type*, so any facade
gives the same string."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (is (string= "Microsoft.Xna.Framework.Audio.Microphone"
                       (xna:clr-type-name microphone)))))))

(define-native-test microphone-all-preserves-object-identity
  "**The identity requirement, asserted with EQ.** XNA's enumeration is
append-only over a list its static constructor makes once, so `All[i]' is
reference-identical across every query for the life of the process. A projection
that built a fresh facade per call would pass every property test and fail this
one."
  (with-microphone-game (game)
    (let ((first-call (audio:microphone-all)))
      (if (null first-call)
          (%note-unavailable)
          (let ((second-call (audio:microphone-all)))
            (is (= (length first-call) (length second-call))
                "the count is stable across two enumerations")
            (loop for a in first-call
                  for b in second-call
                  for index from 0
                  do (is (eq a b)
                         "All[~d] must be the same object on every query; got ~s ~
                          and ~s" index a b))
            ;; The *list* is fresh even though the elements are cached, so
            ;; nothing a caller does to it can reach the cache.
            (is (not (eq first-call second-call))
                "the returned list must be fresh, so a caller cannot mutate the ~
                 identity cache through it")
            (let ((mutated (audio:microphone-all)))
              (setf (first mutated) :not-a-microphone)
              (is (eq (first first-call) (first (audio:microphone-all)))
                  "and mutating a returned list must not have reached the cache"))
            (note-microphone
             :enumeration
             "~d capture device~:p enumerated; All answered the same objects on ~
              every query and a fresh list each time"
             (length first-call)))))))

(define-native-test microphone-default-is-one-of-all-rather-than-a-copy
  "XNA's `SelectDefaultMicrophone' picks an element of the very list `All'
answers, so `Default' is `EQ' to one of them. A projection that built its own
facade from CNA's default index would have equal slots and the wrong identity,
which is the mutation this pins."
  (with-microphone-game (game)
    (let ((all (audio:microphone-all))
          (default (audio:microphone-default)))
      (if (null all)
          (%note-unavailable)
          (progn
            (is (not (null default))
                "CNA enumerated ~d device~:p, so a default is expected" (length all))
            (when default
              (is (member default all :test #'eq)
                  "Default must be EQ to an entry in All, not merely equal to one")
              ;; And it is cached, so the second read is the same object again.
              (is (eq default (audio:microphone-default)))))))))

(define-native-test a-microphone-reports-the-four-values-its-construction-stored
  "`Name', `SampleRate', `IsHeadset' and `BufferDuration' are fields XNA's
constructor fills and its getters read, so each answers without touching the
device. What is asserted here is their shape and, for `IsHeadset', its exact
value."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (progn
            (is (stringp (audio:name microphone))
                "Name is an ordinary Lisp string, not a byte vector or a handle")
            (is (plusp (length (audio:name microphone)))
                "and the device reported one")
            (is (and (integerp (audio:sample-rate microphone))
                     (plusp (audio:sample-rate microphone)))
                "SampleRate is a positive integer; this device reports ~d"
                (audio:sample-rate microphone))
            (is (and (integerp (audio:buffer-duration microphone))
                     (plusp (audio:buffer-duration microphone)))
                "BufferDuration is a positive tick count; this device reports ~d"
                (audio:buffer-duration microphone))
            ;; **The measured divergence, asserted in XNA's direction.**
            (is (eq t (audio:is-headset microphone))
                "IsHeadset is a literal `true' stored by XNA's constructor and ~
                 read by a bare ldfld; SafeIsHeadset is dead code")
            (multiple-value-bind (result native)
                (%probe-microphone-is-headset game (audio::%microphone-index microphone))
              (is (zerop result) "the native cross-check route must answer")
              (note-microphone-divergence
               "IsHeadset: XNA's constructor stores a literal true and the getter ~
                reads it, and SafeIsHeadset is dead code, so the public answer is ~
                T; cna_microphone_get_is_headset_at answers ~:[false~;true~] for ~
                this device"
               native)))))))

;;; --- BufferDuration ---------------------------------------------------------

(define-native-test the-buffer-duration-setter-is-xnas-and-not-cnas
  "**The high-risk semantic property, and the one place CNA's header is wrong.**

XNA's `set_BufferDuration' tests `TotalMilliseconds' three ways -- `< 100',
`> 1000', `% 10 != 0' -- and then stores the value it was given. It does **not**
round. CNA's route documents itself as one that \"validates and rounds\", and
measured it accepts 100.5 ms and afterwards reports 100.5 ms: it neither rounded
nor refused. So the guard has to be here, before the route, and this asserts both
halves -- that the binding refuses it, and that CNA would not have."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let ((index (audio::%microphone-index microphone)))
            ;; Accepted: the bounds themselves and a step inside them.
            (dolist (milliseconds '(100 110 500 1000))
              (let ((ticks (* milliseconds 10000)))
                (finishes (setf (audio:buffer-duration microphone) ticks))
                (is (= ticks (audio:buffer-duration microphone))
                    "the getter answers the value the setter was given, ~
                     unchanged: ~d ms" milliseconds)))
            ;; Refused, each for its own one of the three tests.
            (dolist (case '((990000    "99 ms, below the minimum")
                            (10010000  "1001 ms, above the maximum")
                            (1010000   "101 ms, not a multiple of ten")
                            (1005000   "100.5 ms, between two steps")
                            (0         "zero")
                            (-10000    "negative")))
              (destructuring-bind (ticks why) case
                (signals xna:cna-argument-out-of-range-error
                  (setf (audio:buffer-duration microphone) ticks))
                (is (stringp why) "refused ~a" why)))
            (signals xna:cna-argument-out-of-range-error
              (setf (audio:buffer-duration microphone) 1/2))
            ;; And the refusals changed nothing: the last accepted value stands.
            (is (= 10000000 (audio:buffer-duration microphone))
                "a refused setter must not have moved the stored value")
            ;; **CNA would have accepted the one between two steps.** Recorded as
            ;; a measurement so the divergence is a fact rather than a comment.
            (let ((result (%probe-microphone-set-buffer-duration game index 1005000)))
              (is (zerop result)
                  "CNA accepts 100.5 ms, which is why XNA's guard is reproduced ~
                   here rather than delegated -- got result ~d" result)
              (when (zerop result)
                (is (= 1005000 (%probe-microphone-buffer-duration game index))
                    "and CNA stored it unrounded, so its header's \"validates and ~
                     rounds\" does not describe what it does")
                (note-microphone-divergence
                 "BufferDuration: XNA validates [100, 1000] ms in steps of 10 and ~
                  does not round, so 100.5 ms is refused; ~
                  cna_microphone_set_buffer_duration_ticks_at accepts it and ~
                  stores 1005000 ticks unchanged, despite documenting itself as a ~
                  setter that \"validates and rounds\""))
              ;; Put the device back where the other tests expect it.
              (setf (audio:buffer-duration microphone) 10000000)))))))

;;; --- the capture state machine ----------------------------------------------

(define-native-test the-capture-state-machine-transitions-and-repeats
  "MICROPHONE_CAPTURE_STATE_MACHINE.

XNA's `Start' and `Stop' are the bare native calls under a lock, with no state
test before and no bookkeeping after, so what a *repeated* call does is whatever
the capture engine does -- the IL contains no idempotence rule to reproduce. This
measures CNA's answer through XNA's shape and asserts it, rather than inferring
it: both repeat, and the state does not move when they do."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (unwind-protect
               (progn
                 (audio:stop microphone)
                 (is (eq :stopped (audio:state microphone))
                     "a microphone that is not capturing reports :STOPPED")
                 (finishes (audio:start microphone))
                 (is (eq :started (audio:state microphone)))
                 (finishes (audio:start microphone))
                 (is (eq :started (audio:state microphone))
                     "a second Start is accepted and the state does not move")
                 (finishes (audio:stop microphone))
                 (is (eq :stopped (audio:state microphone)))
                 (finishes (audio:stop microphone))
                 (is (eq :stopped (audio:state microphone))
                     "a second Stop is accepted and the state does not move")
                 (finishes (audio:start microphone))
                 (is (eq :started (audio:state microphone))
                     "and Start after Stop starts it again")
                 (note-microphone
                  :capture-state-machine
                  "a capture device transitioned :STOPPED -> :STARTED -> :STOPPED ~
                   through Start and Stop, and a repeated call of either was ~
                   accepted without moving the state"))
            (ignore-errors (audio:stop microphone)))))))

(define-native-test microphone-stop-refuses-sound-effect-instances-optional
  "`Microphone.Stop' has one overload and takes no argument; the optional on this
generic function belongs to `SoundEffectInstance.Stop', whose two overloads
collapse onto it. CLOS congruence forces the parameter onto the method, so
supplying it must be **refused rather than ignored** -- a method that dropped it
would give `Microphone' a `Stop(bool)' XNA has not got."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (progn
            (signals xna:cna-usage-error (audio:stop microphone t))
            (signals xna:cna-usage-error (audio:stop microphone nil))
            (finishes (audio:stop microphone)))))))

;;; --- the sample arithmetic --------------------------------------------------

(define-native-test microphone-sample-duration-is-xnas-arithmetic
  "`GetSampleDuration' computed from the device's own rate, in XNA's binary32 and
with `TimeSpan.FromMilliseconds''s round-half-away-from-zero -- **not** CNA's
truncation, and **not** SoundEffect's guards.

The interesting number is the boundary between zero and one millisecond. At rate
R the duration of N bytes is `round(floor(N/2) * 1000 / R)' milliseconds, so the
smallest N that answers a non-zero duration is the one whose frame count reaches
R/2000. On the reference runtime's 44100 Hz devices that is 46 bytes -- 23 frames,
0.5215 ms -- while 44 bytes is 22 frames and 0.4989 ms and answers zero. Both are
computed here from the reported rate rather than written down."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let* ((rate (audio:sample-rate microphone))
                 ;; The first frame count whose duration rounds to >= 1 ms.
                 (threshold (loop for frames from 1
                                  when (plusp (audio::%microphone-duration-from-size
                                               (* 2 frames) rate))
                                    return frames)))
            (is (zerop (audio:get-sample-duration microphone 0))
                "zero bytes is TimeSpan.Zero, XNA's own early return")
            (is (zerop (audio:get-sample-duration microphone (* 2 (1- threshold))))
                "~d bytes rounds to zero" (* 2 (1- threshold)))
            (is (= 10000 (audio:get-sample-duration microphone (* 2 threshold)))
                "~d bytes is the first that rounds to one millisecond"
                (* 2 threshold))
            ;; An odd byte count truncates to whole frames, as integer division does.
            (is (= (audio:get-sample-duration microphone (* 2 threshold))
                   (audio:get-sample-duration microphone (1+ (* 2 threshold))))
                "an odd byte count is truncated to whole sample frames")
            ;; One second of capture is one second, whatever the rate.
            (is (= 10000000 (audio:get-sample-duration microphone (* 2 rate)))
                "~d bytes -- one second at ~d Hz -- is 10000000 ticks"
                (* 2 rate) rate)
            ;; The guards, and note which condition each is.
            (signals xna:cna-argument-error (audio:get-sample-duration microphone -1))
            (signals xna:cna-argument-error
              (audio:get-sample-duration microphone (expt 2 31)))
            (signals xna:cna-argument-error (audio:get-sample-duration microphone 1/2))
            ;; **CNA's own route answers differently**, and the public answer is
            ;; XNA's. Recorded rather than asserted away.
            (let ((index (audio::%microphone-index microphone))
                  (bytes (* 2 threshold)))
              (multiple-value-bind (result ticks)
                  (%probe-microphone-sample-duration game index bytes)
                (is (zerop result) "the native cross-check route must answer")
                (is (zerop ticks)
                    "CNA truncates ~d bytes to ~d ticks where XNA rounds it to ~
                     10000; the public answer is XNA's" bytes ticks)
                (note-microphone-divergence
                 "GetSampleDuration: TimeSpan.FromMilliseconds rounds half away ~
                  from zero, so ~d bytes at ~d Hz is 10000 ticks; ~
                  cna_microphone_get_sample_duration_ticks_at truncates and ~
                  answers ~d"
                 bytes (audio:sample-rate microphone) ticks))))))))

(define-native-test microphone-sample-size-is-xnas-binary32-arithmetic
  "`GetSampleSizeInBytes' computed as XNA computes it: the sample rate is divided
by 1000 in **binary32** before the multiplication, so `(float)44100 / 1000f' is
44.09999847412109375 and one second of 44.1 kHz mono PCM16 is **88198** bytes and
not 88200.

That difference is the whole reason CNA's route is not used for the public
answer, and it is asserted here against a value recomputed from the device's own
rate rather than against the literal."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let* ((rate (audio:sample-rate microphone))
                 (per-millisecond (xna::f (/ (xna::f rate) 1000.0f0)))
                 (expected-one-second
                   (* 2 (truncate (* 1000.0d0
                                     (coerce per-millisecond 'double-float))))))
            (is (zerop (audio:get-sample-size-in-bytes microphone 0))
                "TimeSpan.Zero is zero bytes, XNA's own early return")
            (is (= expected-one-second
                   (audio:get-sample-size-in-bytes microphone 10000000))
                "one second at ~d Hz is ~d bytes in XNA's binary32 arithmetic"
                rate expected-one-second)
            (is (= (* 2 (truncate (coerce per-millisecond 'double-float)))
                   (audio:get-sample-size-in-bytes microphone 10000))
                "and one millisecond is ~d bytes"
                (* 2 (truncate (coerce per-millisecond 'double-float))))
            ;; The guards, in the IL's order, and each raising the *duration*
            ;; exception rather than one named after something else.
            (signals xna:cna-argument-out-of-range-error
              (audio:get-sample-size-in-bytes microphone -10000))
            (signals xna:cna-argument-out-of-range-error
              (audio:get-sample-size-in-bytes microphone (* 10000 (expt 2 31))))
            (signals xna:cna-argument-out-of-range-error
              (audio:get-sample-size-in-bytes microphone 1/2))
            ;; **CNA's own route answers differently, twice over.**
            (let ((index (audio::%microphone-index microphone)))
              (multiple-value-bind (result bytes)
                  (%probe-microphone-sample-size game index 10000000)
                (is (zerop result) "the native cross-check route must answer")
                (is (/= bytes expected-one-second)
                    "CNA answers ~d for one second where XNA answers ~d; the ~
                     public answer is XNA's" bytes expected-one-second)
                (note-microphone-divergence
                 "GetSampleSizeInBytes: XNA divides the sample rate by 1000 in ~
                  binary32 first, so one second at ~d Hz is ~d bytes; ~
                  cna_microphone_get_sample_size_in_bytes_at answers ~d"
                 rate expected-one-second bytes))
              (multiple-value-bind (result bytes)
                  (%probe-microphone-sample-size game index -10000)
                (is (zerop result)
                    "CNA accepts a negative duration where XNA throws")
                (is (minusp bytes)
                    "and answers a negative byte count -- ~d -- which is why the ~
                     guard is reproduced here rather than delegated" bytes)
                (note-microphone-divergence
                 "GetSampleSizeInBytes: XNA throws ~
                  ArgumentOutOfRangeException(\"duration\") for a negative ~
                  duration; cna_microphone_get_sample_size_in_bytes_at accepts ~
                  one and answers ~d" bytes))))))))

;;; --- GetData ----------------------------------------------------------------

(define-native-test microphone-get-data-accepts-exactly-xnas-two-overloads
  "`GetData(Byte[])' and `GetData(Byte[], Int32, Int32)' and nothing between.
`:OFFSET' alone and `:COUNT' alone are shapes XNA has not got, and a keyword it
has never heard of is refused rather than ignored."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let ((buffer (make-array 4096 :element-type '(unsigned-byte 8)
                                         :initial-element 0)))
            (finishes (audio:get-data microphone buffer))
            (finishes (audio:get-data microphone buffer :offset 0 :count 4096))
            (signals xna:cna-usage-error (audio:get-data microphone buffer :offset 0))
            (signals xna:cna-usage-error (audio:get-data microphone buffer :count 64))
            (signals xna:cna-usage-error
              (audio:get-data microphone buffer :offset 0 :count 64 :immediate t)))))))

(define-native-test microphone-get-data-validates-in-the-pinned-order
  "Which condition a call wrong in two ways is told about is decided by the
order, so the order is what is asserted. The buffer test comes first, then the
offset test, then the count test -- and the count test carries XNA's fifth
condition, which no other member in this binding has: a count whose duration
rounds to zero is refused."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let* ((rate (audio:sample-rate microphone))
                 (threshold (loop for frames from 1
                                  when (plusp (audio::%microphone-duration-from-size
                                               (* 2 frames) rate))
                                    return frames))
                 (smallest (* 2 threshold))
                 (buffer (make-array 4096 :element-type '(unsigned-byte 8)
                                          :initial-element 0)))
            ;; the buffer
            (signals xna:cna-argument-error (audio:get-data microphone nil))
            (signals xna:cna-argument-error
              (audio:get-data microphone
                              (make-array 0 :element-type '(unsigned-byte 8))))
            (signals xna:cna-argument-error
              (audio:get-data microphone
                              (make-array 3 :element-type '(unsigned-byte 8)
                                            :initial-element 0))
              "a length that is not a whole two-byte sample frame")
            ;; the offset
            (signals xna:cna-argument-error
              (audio:get-data microphone buffer :offset -2 :count smallest))
            (signals xna:cna-argument-error
              (audio:get-data microphone buffer :offset 4096 :count smallest)
              "offset == length is refused, which is `offset >= buffer.Length'")
            (signals xna:cna-argument-error
              (audio:get-data microphone buffer :offset 1 :count smallest)
              "an odd offset is not a whole sample frame")
            ;; the count
            (signals xna:cna-argument-error
              (audio:get-data microphone buffer :offset 0 :count 0)
              "count == 0 is refused, which is `count <= 0'")
            (signals xna:cna-argument-error
              (audio:get-data microphone buffer :offset 0 :count -2))
            (signals xna:cna-argument-error
              (audio:get-data microphone buffer :offset 4094 :count 4))
            (signals xna:cna-argument-error
              (audio:get-data microphone buffer :offset 0 :count 3)
              "an odd count is not a whole sample frame")
            ;; **XNA's fifth condition**, which is this member's alone.
            (when (> smallest 2)
              (signals xna:cna-argument-error
                (audio:get-data microphone buffer :offset 0 :count (- smallest 2))
                "a count whose duration rounds to TimeSpan.Zero is refused; at ~
                 ~d Hz that is every count below ~d bytes" rate smallest))
            (finishes (audio:get-data microphone buffer :offset 0 :count smallest)))))))

(define-native-test a-microphone-that-is-not-started-answers-zero-bytes
  "XNA's last act before the native call is `if (State != Started) return 0'. So
this is an **answer** and not a refusal: no condition is signalled and the buffer
is not touched."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (progn
            (audio:stop microphone)
            (is (eq :stopped (audio:state microphone)))
            (let ((buffer (make-array 4096 :element-type '(unsigned-byte 8)
                                           :initial-element #xAB)))
              (is (zerop (audio:get-data microphone buffer))
                  "a stopped microphone answers zero rather than refusing")
              (is (every (lambda (byte) (= byte #xAB)) buffer)
                  "and it wrote nothing at all")))))))

(define-native-test microphone-capture-writes-exactly-the-range-it-reports
  "MICROPHONE_CAPTURE_DATA, and the destination-range proof §19 asks for.

Asserting `returned > 0' would not prove the destination was written correctly,
so this fills the buffer with a sentinel, reads into a *sub-range*, and proves
three things separately: the bytes before the offset are untouched, the bytes
after `offset + returned' are untouched, and the returned count never exceeds
the count that was asked for.

**The captured bytes themselves are silence**, because the qualification's device
is SDL's dummy backend. That is why this asserts the *shape* of the write and not
the content: a test that asserted the payload was zero would be asserting a
property of the dummy driver, not of the binding."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (unwind-protect
               (let* ((sentinel #xAB)
                      (size 8192)
                      (offset 1024)
                      (count 4096)
                      (buffer (make-array size :element-type '(unsigned-byte 8)
                                               :initial-element sentinel))
                      (total 0)
                      (reads 0)
                      (last 0))
                 (audio:start microphone)
                 ;; Run frames until the device has produced something, bounded
                 ;; so a device that never produces cannot hang the suite.
                 (loop repeat 240
                       until (plusp last)
                       do (xna:run-one-frame game)
                          (setf last (audio:get-data microphone buffer
                                                     :offset offset :count count))
                          (when (plusp last) (incf reads) (incf total last)))
                 (is (plusp last)
                     "the capture device produced no bytes in 240 frames, so the ~
                      destination-range proof has nothing to prove")
                 (when (plusp last)
                   (is (<= last count)
                       "a read must never report more than the count it was given")
                   (is (every (lambda (i) (= sentinel (aref buffer i)))
                              (loop for i from 0 below offset collect i))
                       "the bytes before the offset must be untouched")
                   (is (every (lambda (i) (= sentinel (aref buffer i)))
                              (loop for i from (+ offset last) below size collect i))
                       "the bytes after offset + returned must be untouched, ~
                        including the rest of the requested range on a short read")
                   ;; A short read is success, not a buffer-too-small condition.
                   (is (or (= last count) (< last count))
                       "a short read is an ordinary success")
                   (note-microphone
                    :capture-data
                    "GetData wrote captured PCM16 into exactly the [~d, ~d) range ~
                     it reported and left every byte outside it unchanged; ~d ~
                     byte~:p arrived. **The payload is not inspected**, so nothing ~
                     here is a claim about what was captured -- which device ~
                     produced the bytes is the driver's business and this suite ~
                     does not choose one"
                    offset (+ offset last) total)))
            (ignore-errors (audio:stop microphone)))))))

(define-native-test microphone-capture-advances-at-the-reported-sample-rate
  "The capture-clock proof, with an explicit and justified tolerance.

An exact byte count would be a claim about this machine's scheduler, so the
assertion is a *window*: over a bounded run of frames the device must deliver
between a quarter and twice the bytes its own `SampleRate' implies for the
elapsed time. The lower bound is loose because a loaded machine can starve the
capture thread; the upper bound is what catches a device reporting a rate it does
not keep, or a projection that counted the same bytes twice.

**This proves streaming progression and nothing about acoustics.** Every byte the
dummy backend produces is zero."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (unwind-protect
               (let* ((rate (audio:sample-rate microphone))
                      (buffer (make-array 65536 :element-type '(unsigned-byte 8)
                                                :initial-element 0))
                      (frames 180)
                      (total 0)
                      (start (get-internal-real-time)))
                 (audio:start microphone)
                 (dotimes (i frames)
                   (xna:run-one-frame game)
                   (incf total (audio:get-data microphone buffer)))
                 (let* ((elapsed (/ (float (- (get-internal-real-time) start) 1.0d0)
                                    internal-time-units-per-second))
                        ;; mono PCM16: two bytes a frame, `rate' frames a second.
                        (expected (* 2 rate elapsed)))
                   (is (plusp total)
                       "no bytes arrived in ~d frames, so no capture clock was ~
                        observed" frames)
                   (when (plusp total)
                     (is (< (* 0.25d0 expected) total (* 2.0d0 expected))
                         "~d bytes arrived over ~,3fs at ~d Hz, where the sample ~
                          rate implies about ~,0f. Outside a quarter-to-double ~
                          window the capture clock is not running at the rate the ~
                          device reports."
                         total elapsed rate expected))))
            (ignore-errors (audio:stop microphone)))))))

;;; --- BufferReady ------------------------------------------------------------

(define-native-test the-buffer-ready-event-reaches-the-object-all-hands-out
  "MICROPHONE_BUFFER_READY, and the sender-identity proof §25 asks for.

`MicrophoneCollection.OnBufferReady(handle)' walks its own list for the element
whose handle matches and raises the event on **that element**, so the sender is
the object `All' and `Default' hand out. A projection that built a fresh facade
from the device index inside the callback would deliver an object with equal
slots and the wrong identity, which is exactly what `EQ' catches here.

The buffer duration is set low on purpose: CNA raises the event once the unread
backlog reaches `BufferDuration', so a 100 ms buffer makes it due within a few
frames. **No event count is asserted** -- neither framework publishes a rate, and
CNA raises it on every buffer check until `GET-DATA' drains the backlog."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let ((before (int:callback-registry-count))
                (senders '())
                (calls 0))
            (unwind-protect
                 (let ((handler (lambda (sender) (incf calls) (push sender senders))))
                   (setf (audio:buffer-duration microphone) 1000000) ; 100 ms
                   (audio:add-buffer-ready-handler microphone handler)
                   (is (= (1+ before) (int:callback-registry-count))
                       "the subscription rooted exactly one callback target")
                   (audio:start microphone)
                   (loop repeat 240
                         until (plusp calls)
                         do (xna:run-one-frame game))
                   (is (plusp calls)
                       "BufferReady never arrived in 240 frames with a 100 ms ~
                        buffer duration")
                   (when (plusp calls)
                     (is (every (lambda (sender) (eq sender microphone)) senders)
                         "every sender must be the same object Default answered, ~
                          not a fresh facade built from the device index")
                     (is (eq microphone (first (audio:microphone-all)))
                         "and that object is still the one All hands out"))
                   ;; Removing the handler stops delivery and gives the
                   ;; registration back.
                   (is (eq t (audio:remove-buffer-ready-handler microphone handler)))
                   (is (= before (int:callback-registry-count))
                       "removing the last handler released the native registration ~
                        and forgot its token")
                   (let ((after-removal calls))
                     (dotimes (i 30) (xna:run-one-frame game))
                     (is (= after-removal calls)
                         "no further callback may arrive after the handler is ~
                          removed; ~d more did" (- calls after-removal)))
                   (is (null (audio:remove-buffer-ready-handler microphone handler))
                       "and removing it again answers NIL, as Delegate.Remove does")
                   (note-microphone
                    :buffer-ready
                    "BufferReady arrived ~d time~:p on a device with a 100 ms ~
                     buffer duration, every sender was EQ to the object All and ~
                     Default hand out, removing the handler released the native ~
                     registration and stopped delivery, and the callback registry ~
                     returned to its baseline"
                    calls))
              (ignore-errors (audio:stop microphone))
              (ignore-errors (setf (audio:buffer-duration microphone) 10000000))))))))

(define-native-test a-condition-from-a-buffer-ready-handler-uses-the-shared-rule
  "The BufferReady family uses the common callback-condition rule and does not
invent one of its own: a serious condition signalled in a handler never unwinds
through C, is preserved as the original condition object, and is re-signalled at
the next native call that returns to the program outside every callback.

One focused test, because the rule itself is owned and exhaustively tested by
`src/internal/callback-conditions.lisp' and `tests/native/events.lisp'; what is
asserted here is that this event family is wired to it."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let ((marker (make-condition 'xna:cna-io-error :operation "handler probe"))
                (handler nil))
            (unwind-protect
                 (progn
                   (setf handler (lambda (sender) (declare (ignore sender)) (error marker)))
                   (setf (audio:buffer-duration microphone) 1000000)
                   (audio:add-buffer-ready-handler microphone handler)
                   (audio:start microphone)
                   (let ((signalled nil))
                     (loop repeat 240
                           until signalled
                           do (handler-case (xna:run-one-frame game)
                                (xna:cna-error (condition) (setf signalled condition))))
                     (is (not (null signalled))
                         "the handler's condition never reached the program")
                     (when signalled
                       (is (or (eq signalled marker)
                               (eq marker (xna:cna-error-cause signalled)))
                           "the original condition object must arrive, either ~
                            itself or as the CAUSE of the native failure that ~
                            outranked it; got ~s" signalled))))
              (ignore-errors (audio:stop microphone))
              (when handler
                (ignore-errors (audio:remove-buffer-ready-handler microphone handler)))
              (ignore-errors (setf (audio:buffer-duration microphone) 10000000))))))))

(define-native-test a-refused-microphone-unsubscribe-keeps-its-registration
  "The rule the Dynamic closure fixed, asserted for this event family too.

`cna_audio_unsubscribe_ext' validates before it mutates: a call from a thread
other than the one that created the registration answers `CNA_RESULT_THREAD'
**before anything is released**, so the registration is still live and forgetting
the local row would leave CNA holding one nothing can release. This removes from
the wrong thread, proves it was refused, and then proves the subscription is
still there by removing it properly."
  (with-microphone-game (game)
    (let ((microphone (microphone-or-nil game)))
      (if (null microphone)
          (%note-unavailable)
          (let ((before (int:callback-registry-count))
                (handler (lambda (sender) (declare (ignore sender)))))
            (audio:add-buffer-ready-handler microphone handler)
            (let ((result (bordeaux-threads:join-thread
                           (bordeaux-threads:make-thread
                            (lambda ()
                              (handler-case
                                  (progn (audio:remove-buffer-ready-handler
                                          microphone handler)
                                         :accepted)
                                (xna:cna-error (condition) (type-of condition))))
                            :name "cna-lisp microphone unsubscribe wrong-thread probe"))))
              (is (not (eq result :accepted))
                  "the wrong-thread unsubscribe was accepted; CNA refuses it")
              (is (= (1+ before) (int:callback-registry-count))
                  "and the refused removal kept the rooted token, because the ~
                   native registration it did not release is still live"))
            (is (eq t (audio:remove-buffer-ready-handler microphone handler))
                "so the right thread still finds the subscription")
            (is (= before (int:callback-registry-count))
                "and removing it properly gives everything back"))))))

(define-native-test microphone-subscriptions-do-not-outlive-their-game
  "A microphone facade is process-global and a native registration is not.

The runtime owns the device and the facade survives its game, but the CNA
registration belongs to the game that created it. This proves the ordinary path
leaves nothing behind: after the handler is removed and the game is destroyed,
the callback registry is back at its baseline and a second game can be created --
which it could not be if CNA were still holding a registration."
  (let ((outside (int:callback-registry-count)))
    (with-microphone-game (game)
      (let ((microphone (microphone-or-nil game))
            ;; Taken with the game already live: creating one registers its own
            ;; callback target, so a baseline from outside would be one short.
            (before (int:callback-registry-count)))
        (when microphone
          (let ((handler (lambda (sender) (declare (ignore sender)))))
            (audio:add-buffer-ready-handler microphone handler)
            (is (= (1+ before) (int:callback-registry-count)))
            (is (eq t (audio:remove-buffer-ready-handler microphone handler)))
            (is (= before (int:callback-registry-count)))))))
    (is (= outside (int:callback-registry-count))
        "the registry is back at its baseline after the game is destroyed")
    ;; And a second game can be created, which proves CNA let the first one go.
    (with-microphone-game (second-game)
      (is (not (null second-game))))))

(define-native-test a-microphone-facade-survives-its-game-and-needs-another
  "§30: what a facade retained across game disposal may still answer.

**This is not an invention; it is what the IL does.** `Name', `SampleRate',
`IsHeadset' and `BufferDuration' are fields XNA's getters read, so they keep
answering -- there is nothing native to reach. `State' calls the device on every
read, so it needs an active game and refuses without one, with the established
projection-limit condition.

The identity question is answered by measurement rather than assumed: CNA's
device list is owned by the runtime and is identical across a game being
destroyed and another created -- same count, same names, same rates -- so the
cache is process-global and the same facade is still the right object. What is
asserted here is the *documented* behaviour, not a hope: the stored members
answer, the device members refuse, and after a new game the device members work
again on the same object."
  (let (retained)
    (with-microphone-game (game)
      (setf retained (microphone-or-nil game)))
    (if (null retained)
        ;; No device, so there is no facade to retain. The unavailable branch is
        ;; recorded by the tests that run *inside* a game; asserting it again
        ;; here would mean enumerating with none, which is a different member's
        ;; refusal and is tested where it belongs.
        (is (null retained)
            "no capture device was enumerated, so there is no facade to retain")
        (let ((name (audio:name retained))
              (rate (audio:sample-rate retained))
              (ticks (audio:buffer-duration retained)))
          ;; The stored members still answer, because they are slots.
          (is (stringp name))
          (is (plusp rate))
          (is (plusp ticks))
          (is (eq t (audio:is-headset retained)))
          ;; The device members refuse, because there is no game to resolve.
          (signals xna:cna-invalid-state-error (audio:state retained))
          (signals xna:cna-invalid-state-error (audio:start retained))
          ;; A new game, and the same facade works again.
          (let ((second (make-instance 'xna:game :window-title "cna-lisp microphone")))
            (unwind-protect
                 (progn
                   (is (eq :stopped (audio:state retained))
                       "the retained facade answers again under a new game")
                   (is (string= name (audio:name retained))
                       "and it is still the same device: the runtime owns the list ~
                        and it did not change")
                   (is (= rate (audio:sample-rate retained))))
              (%tear-down-audio-game second)))
          (audio::%reset-microphone-cache)))))

;;; --- the shrunk-list refusal ------------------------------------------------

(define-native-test a-shrunk-device-list-is-refused-rather-than-retargeted
  "XNA's `EnumerateMicrophones' throws `InvalidOperationException' when the count
is below the number already handed out, because an index names one device for the
life of the process and a shrunk list cannot be reconciled with the objects
already given out.

CNA's device list does not shrink under the qualification environment, so the
condition is provoked directly against the private enumeration rather than by
unplugging hardware: the cache is seeded with more entries than the runtime
reports. What is asserted is that the projection **refuses** rather than silently
re-targeting index 0 at a different device."
  (with-microphone-game (game)
    (let ((all (audio:microphone-all)))
      (if (null all)
          (%note-unavailable)
          (let ((audio::*microphones*
                  (append all (list (make-instance 'audio:microphone
                                                   :index (length all)
                                                   :name "a device that went away"
                                                   :sample-rate 44100
                                                   :headset t
                                                   :buffer-duration 10000000)))))
            (signals xna:cna-invalid-state-error (audio:microphone-all)))))))

;;; --- enumeration and subscription atomicity ---------------------------------

(define-native-test a-failed-enumeration-publishes-no-half-built-snapshot
  "Enumeration is several native queries per device, and any of them can fail.

A microphone has no owned handle, so there is nothing to give back -- but the
**cache** can still be corrupted, and in a worse way than a leaked handle: it is
process-global and append-only, so a snapshot published with three of five
devices in it would be a snapshot the *next* successful enumeration never fills
in, because it starts from the cached count. The device at index three would
become unreachable for the life of the process.

So %ENUMERATE-MICROPHONES builds every new facade into a fresh list and appends it
in one assignment. This asserts that: a failure part way through leaves the cache
exactly as it was, the original condition reaches the caller, and the next
enumeration -- with the fault removed -- produces the full set.

**The fault is injected by redefining a private reader**, which is invasive and
is the only way to reach this: the failure is a native query failing, and the
qualification's devices do not fail. The original definition is restored however
the test ends."
  (with-microphone-game (game)
    (let ((all (audio:microphone-all)))
      (cond
        ((null all) (%note-unavailable))
        ((< (length all) 2)
         (is (>= (length all) 1)
             "this environment enumerates one device, so a failure part way ~
              through a multi-device enumeration cannot be staged here"))
        (t
         (audio::%reset-microphone-cache)
         (let ((original #'audio::%microphone-name-at)
               (marker (make-condition 'xna:cna-io-error
                                       :operation "enumeration fault probe")))
           (unwind-protect
                (progn
                  ;; Fail on the *second* device, so the first has been built and
                  ;; would be published by a projection that appended as it went.
                  (setf (fdefinition 'audio::%microphone-name-at)
                        (lambda (handle index operation)
                          (if (plusp index)
                              (error marker)
                              (funcall original handle index operation))))
                  (let ((signalled
                          (handler-case (progn (audio:microphone-all) nil)
                            (xna:cna-error (condition) condition))))
                    (is (eq marker signalled)
                        "the original condition must reach the caller unchanged; ~
                         got ~s" signalled)))
             (setf (fdefinition 'audio::%microphone-name-at) original))
           ;; The cache is coherent: nothing was published, so it is still empty.
           (is (null audio::*microphones*)
               "a failure part way through must publish no facade at all; ~d ~
                were left behind" (length audio::*microphones*))
           (is (null audio::*default-microphone*)
               "and no half-selected Default may survive it")
           ;; And with the fault gone the full set appears, which is what a
           ;; half-published snapshot would have made impossible.
           (let ((again (audio:microphone-all)))
             (is (= (length all) (length again))
                 "the next enumeration must produce the whole set: ~d devices ~
                  before the fault and ~d after" (length all) (length again)))))))))

(define-native-test a-failed-subscribe-roots-no-callback-token
  "The first of the four subscription split-brain states: the token is registered
in Lisp and the native subscribe then fails.

`%SUBSCRIBE-EVENT' registers a callback target *before* it calls CNA, because CNA
needs the token as its context. If the route then fails, that token roots a Lisp
object nothing can ever reach -- which the ownership tests would report as a
registry that did not come back to zero. The machinery unregisters it in a
`handler-case' and re-signals; this is the microphone family's proof that it does.

The failure is provoked with a facade whose index is past CNA's count, which
`cna_microphone_subscribe_buffer_ready_at` documents as
`CNA_RESULT_INVALID_ARGUMENT`. Such a facade cannot arise from the public API --
it is built directly here -- which is exactly why it is a usable fault injector."
  (with-microphone-game (game)
    (let ((all (audio:microphone-all)))
      (if (null all)
          (%note-unavailable)
          (let ((before (int:callback-registry-count))
                (past-the-end (make-instance 'audio:microphone
                                             :index (length all)
                                             :name "not a device CNA enumerates"
                                             :sample-rate 44100
                                             :headset t
                                             :buffer-duration 10000000)))
            (signals xna:cna-error
              (audio:add-buffer-ready-handler
               past-the-end (lambda (sender) (declare (ignore sender)))))
            (is (= before (int:callback-registry-count))
                "a failed subscribe must leave no rooted callback token behind")
            (is (null (microsoft.xna.framework::%event-handlers past-the-end))
                "and no local row claiming a registration it never got"))))))
