;;;; enums.lisp --- the three selected Microsoft.Xna.Framework.Audio enumerations.
;;;;
;;;; Each is projected the way every enumeration here is: a keyword per member,
;;;; with the exact contract values kept privately in the table. Read from the
;;;; pinned IL rather than from CNA's header, and then checked against it:
;;;;
;;;;   SoundState      Playing 0   Paused 1   Stopped 2
;;;;   AudioChannels   Mono    1   Stereo 2
;;;;   MicrophoneState Started 0   Stopped 1
;;;;
;;;; CNA numbers all three families identically -- `CNA_SOUND_STATE_PLAYING' is 0,
;;;; `CNA_AUDIO_CHANNELS_MONO' is 1 and `CNA_MICROPHONE_STATE_STARTED' is 0.
;;;; **That agreement is not why the translation is by name.** `BlendFunction' is
;;;; the standing counterexample: XNA numbers
;;;; Min 3 and Max 4, CNA numbers them the other way round, and every other
;;;; enumeration in this binding happened to agree -- which is exactly how a
;;;; numeric pass-through survives to the one place it turns a minimum into a
;;;; maximum. So these translate through explicit tables like all the others, and
;;;; a test asserts the two sides agree rather than assuming it.

(in-package #:microsoft.xna.framework.audio)

(xna::define-xna-enum sound-state
  '((:playing . 0)
    (:paused  . 1)
    (:stopped . 2))
  :documentation "Microsoft.Xna.Framework.Audio.SoundState: what a SoundEffectInstance is doing.")

(xna::define-xna-enum audio-channels
  '((:mono   . 1)
    (:stereo . 2))
  :documentation
  "Microsoft.Xna.Framework.Audio.AudioChannels: how many interleaved channels PCM data carries.

Note that the values are 1 and 2 rather than 0 and 1, so the member doubles as
the channel count -- which is what makes `GetSampleDuration' and
`GetSampleSizeInBytes' arithmetic rather than a lookup, there and here.")

(xna::define-xna-enum microphone-state
  '((:started . 0)
    (:stopped . 1))
  :documentation
  "Microsoft.Xna.Framework.Audio.MicrophoneState: whether a microphone is capturing.

**Started is 0 and Stopped is 1**, which is the opposite of the order a reader
expects and is what the pinned contract says. `SoundState' next door numbers
Playing 0, Paused 1, Stopped 2, so the two enumerations of this namespace do not
share a \"stopped\" value and nothing may be read across from one to the other.

The pinned IL makes the numbering observable rather than cosmetic:
`Microphone.GetData' branches on `get_State()' with a `brfalse', which takes the
zero branch -- so \"is it started\" is spelled \"is it zero\" in the original, and a
projection that renumbered the pair would invert that test.

XNA's *private* `MicrophoneCaptureState' is a third numbering again -- MicStarted
1, MicStopped 2 -- and `get_State' translates it: `captureState == MicStarted'
answers `Started', everything else answers `Stopped'. That private enumeration is
not in the public contract and is not projected; it is recorded here because it
is why the public pair is not simply the native pair renamed.")

(defconstant +minimum-sample-rate+ 8000
  "The lowest sample rate the audio surface accepts: `0x1f40' in the pinned IL.")
(defconstant +maximum-sample-rate+ 48000
  "The highest sample rate the audio surface accepts: `0xbb80' in the pinned IL.

The same pair of bounds appears in four places in the pinned assembly and is one
fact rather than four: `SoundEffect.FromBuffer', `GetSampleDuration',
`GetSampleSizeInBytes' and `WavFile.ParseFormat' all compare against `0x1f40' and
`0xbb80'. They live here, beside the channel arithmetic, because the wave parser
needs them and is loaded before SoundEffect is.")

(defun %channel-count (channels)
  "The number of interleaved channels AUDIO-CHANNELS names.

XNA's enumeration is numbered so that the member *is* the count, and its own
sample arithmetic relies on that. Kept as a named function rather than spelled
`audio-channels-value' at each call site, because the two mean different things:
one is the ABI value, this is a count of channels."
  (audio-channels-value channels))

(defun %block-align (channels)
  "Bytes in one complete PCM16 sample frame.

XNA's `AudioFormat.BlockAlign' for the 16-bit format its constructors always
create: two bytes a sample, one sample a channel. This is the divisor every
alignment check in the constructors uses, so it is defined once."
  (* 2 (%channel-count channels)))
