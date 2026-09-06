;;;; conditions.lisp --- the three exceptions XNA's audio surface raises.
;;;;
;;;; `NoAudioHardwareException', `InstancePlayLimitException' and
;;;; `NoMicrophoneConnectedException' are the only three exception *types* in the
;;;; selected contract: everything else the selection throws is a
;;;; base-class-library exception, and those project onto the conditions in
;;;; `framework/conditions.lisp' rather than onto classes of their own. All three
;;;; are XNA's own and `sealed'; the first two extend
;;;; `System.Runtime.InteropServices.ExternalException' -- the CLR's "a native
;;;; call failed" base, which is exactly what `CNA-NATIVE-ERROR' already is here
;;;; -- and the third extends `System.Exception' directly.
;;;;
;;;; **So they are not new machinery, they are three more leaves.** Each one
;;;; subclasses the condition CNA-Lisp already signals for the CNA result code
;;;; that produces it:
;;;;
;;;;   NoAudioHardwareException       <- CNA-NOT-SUPPORTED-ERROR (CNA_RESULT_NOT_SUPPORTED)
;;;;   InstancePlayLimitException     <- CNA-INVALID-STATE-ERROR  (CNA_RESULT_INVALID_STATE)
;;;;   NoMicrophoneConnectedException <- CNA-NOT-SUPPORTED-ERROR (CNA_RESULT_NOT_SUPPORTED)
;;;;
;;;; **The first and the third share a CNA result code and are still two
;;;; classes**, because the *route* decides which is meant: `audio.h' documents
;;;; `CNA_RESULT_NOT_SUPPORTED' from the sound-effect creation routes as "no
;;;; audio hardware" and from `cna_microphone_start_at' as "when no microphone is
;;;; connected". So the translation is per family rather than per code, which is
;;;; what `%CHECK-AUDIO-RESULT' and `%CHECK-MICROPHONE-RESULT' are two functions
;;;; for. A handler for `CNA-NOT-SUPPORTED-ERROR' still catches both.
;;;;
;;;; That is deliberate and it buys three things. A program that wants XNA's
;;;; distinction handles the exact class, as it would there. A program that
;;;; handles CNA-Lisp's result-code condition keeps catching it, so the "one
;;;; condition class per CNA result code" property this binding has everywhere
;;;; else is not broken by the audio namespace. And a *generic* native failure --
;;;; `CNA-INTERNAL-ERROR', say -- is none of the three, which is the distinction
;;;; the qualification actually has to prove.
;;;;
;;;; Read from the IL rather than from a description: `Helpers.GetExceptionFromResult'
;;;; is XNA's own error-code-to-exception map, and it is where all three are built
;;;; -- one code answers `new NoAudioHardwareException()' with no message, one
;;;; answers `new InstancePlayLimitException(FrameworkResources.InstancePlayFailedDueToLimit)',
;;;; and one answers `new NoMicrophoneConnectedException()' with no message. None
;;;; of the three is thrown from anywhere else in the assembly: each has exactly
;;;; one `newobj' site and it is that map.

(in-package #:microsoft.xna.framework.audio)

(defun %report-audio-condition (condition stream default-control)
  "Report CONDITION, preferring a message the caller supplied over DEFAULT-CONTROL.

**All three of these types declare the CLR's three-constructor set**, and the second
constructor takes a message. A `:report' that ignored `:FORMAT-CONTROL' and always
printed its own sentence would store that message and never show it, which makes
`new(String)' a constructor this projection accepts and does not express -- the
same defect `new(String, Exception)' had before CNA-ERROR gained a CAUSE slot, and
found the same way, by writing the constructor-shape test.

So a supplied message wins, the built-in explanation is what `new()' prints, and
the cause is named after either. CNA's own diagnostic text is appended when it has
any, because it says which route answered."
  (let ((control (xna::%cna-error-format-control condition)))
    (format stream "~@[~a: ~]" (xna:cna-error-operation condition))
    (if control
        (apply #'format stream control (xna::%cna-error-format-arguments condition))
        (format stream default-control))
    (let ((message (xna:cna-error-native-message condition)))
      (when message (format stream " ~a" message)))
    (let ((cause (xna:cna-error-cause condition)))
      (when cause (format stream " Caused by ~a: ~a" (type-of cause) cause)))))

(define-condition no-audio-hardware-error (xna:cna-not-supported-error) ()
  (:documentation
   "No audio playback device could be opened.

CNA-Lisp's projection of Microsoft.Xna.Framework.Audio.NoAudioHardwareException.

This is a statement about the *machine and its audio backend*, not about the
program: `cna_audio_get_capabilities' reports `is_playback_available' as data and
succeeds either way, and the creation routes answer `CNA_RESULT_NOT_SUPPORTED'
when there is no device to put a sound on. A run under
`SDL_AUDIODRIVER=nonexistent-driver' reaches this deterministically and with no
hardware, which is how the unavailable branch is qualified rather than skipped.

It is a subtype of `CNA-NOT-SUPPORTED-ERROR', so a handler for that catches it.")
  (:report
   (lambda (condition stream)
     (%report-audio-condition
      condition stream
      "no audio playback device is available. CNA answered ~
       CNA_RESULT_NOT_SUPPORTED, which its header documents as the machine ~
       having no audio hardware this build can open."))))

(define-condition instance-play-limit-error (xna:cna-invalid-state-error) ()
  (:documentation
   "Too many sound effect instances are already playing.

CNA-Lisp's projection of Microsoft.Xna.Framework.Audio.InstancePlayLimitException.

XNA raises it from `SoundEffect.Play' when the platform's voice limit is reached;
CNA answers `CNA_RESULT_INVALID_STATE' from `cna_sound_effect_play' and
`cna_sound_effect_play_with_settings' for the same reason, and its header says so
in the same words -- \"when too many instances are already playing\".

It is a subtype of `CNA-INVALID-STATE-ERROR'. Not every invalid state is this
one: the two play routes are the only place it is raised, so a refused
`IS-LOOPED' setter or a refused `APPLY-3D' stays the plain state error it is.")
  (:report
   (lambda (condition stream)
     (%report-audio-condition
      condition stream
      "the sound effect could not be played because too many instances are ~
       already playing."))))

(define-condition no-microphone-connected-error (xna:cna-not-supported-error) ()
  (:documentation
   "No capture device was connected when one was needed.

CNA-Lisp's projection of Microsoft.Xna.Framework.Audio.NoMicrophoneConnectedException.

**It is raised from `START' and from nowhere else**, because that is the one
microphone route CNA documents `CNA_RESULT_NOT_SUPPORTED' for: \"`CNA_RESULT_SUCCESS`,
`CNA_RESULT_INVALID_ARGUMENT` for an index at or past the count,
`CNA_RESULT_NOT_SUPPORTED` when no microphone is connected\". Every other
microphone route documents no such code, so translating the code everywhere would
be inventing a failure the ABI does not describe.

**Enumerating no microphone is not this condition.** A machine with no capture
device answers a count of zero, which `audio.h' calls \"an ordinary answer\", and
`MICROPHONE-ALL' answers the empty list and `MICROPHONE-DEFAULT' answers NIL.
There is no facade to call `START' on, so the deterministic no-device lane never
reaches this condition -- it proves the empty enumeration instead, which is a
different and stronger fact than an exception.

It is a subtype of `CNA-NOT-SUPPORTED-ERROR', so a handler for that catches it,
and so does one for the sibling `NO-AUDIO-HARDWARE-ERROR''s supertype -- the two
share a result code and are distinguished by the route that answered it.")
  (:report
   (lambda (condition stream)
     (%report-audio-condition
      condition stream
      "no microphone is connected. CNA answered CNA_RESULT_NOT_SUPPORTED, ~
       which its header documents for this route as there being no capture ~
       device to start."))))
