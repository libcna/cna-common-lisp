;;;; conditions.lisp --- the two exceptions XNA's audio surface raises.
;;;;
;;;; `NoAudioHardwareException' and `InstancePlayLimitException' are the only two
;;;; exception *types* in the selected contract: everything else the selection
;;;; throws is a base-class-library exception, and those project onto the
;;;; conditions in `framework/conditions.lisp' rather than onto classes of their
;;;; own. These two are XNA's own, `sealed', and both extend
;;;; `System.Runtime.InteropServices.ExternalException' -- the CLR's "a native
;;;; call failed" base, which is exactly what `CNA-NATIVE-ERROR' already is here.
;;;;
;;;; **So they are not new machinery, they are two more leaves.** Each one
;;;; subclasses the condition CNA-Lisp already signals for the CNA result code
;;;; that produces it:
;;;;
;;;;   NoAudioHardwareException     <- CNA-NOT-SUPPORTED-ERROR   (CNA_RESULT_NOT_SUPPORTED)
;;;;   InstancePlayLimitException   <- CNA-INVALID-STATE-ERROR   (CNA_RESULT_INVALID_STATE)
;;;;
;;;; That is deliberate and it buys three things. A program that wants XNA's
;;;; distinction handles the exact class, as it would there. A program that
;;;; handles CNA-Lisp's result-code condition keeps catching it, so the "one
;;;; condition class per CNA result code" property this binding has everywhere
;;;; else is not broken by the audio namespace. And a *generic* native failure --
;;;; `CNA-INTERNAL-ERROR', say -- is neither of the two, which is the distinction
;;;; the qualification actually has to prove.
;;;;
;;;; Read from the IL rather than from a description: `Helpers.GetExceptionFromResult'
;;;; is XNA's own error-code-to-exception map, and it is where both are built --
;;;; one code answers `new NoAudioHardwareException()' with no message, and one
;;;; answers `new InstancePlayLimitException(FrameworkResources.InstancePlayFailedDueToLimit)'.
;;;; Neither is thrown from anywhere else in the assembly.

(in-package #:microsoft.xna.framework.audio)

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
     (format stream "~@[~a: ~]no audio playback device is available. ~
                     CNA answered CNA_RESULT_NOT_SUPPORTED, which its header ~
                     documents as the machine having no audio hardware this ~
                     build can open.~@[ ~a~]"
             (xna:cna-error-operation condition)
             (xna:cna-error-native-message condition)))))

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
     (format stream "~@[~a: ~]the sound effect could not be played because too ~
                     many instances are already playing.~@[ ~a~]"
             (xna:cna-error-operation condition)
             (xna:cna-error-native-message condition)))))
