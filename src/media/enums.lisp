;;;; enums.lisp --- the one selected Microsoft.Xna.Framework.Media enumeration.
;;;;
;;;; Projected the way every enumeration here is: a keyword per member, with the
;;;; exact contract values kept privately in the table. Read from the pinned IL
;;;; rather than from CNA's header, and then checked against it:
;;;;
;;;;   MediaState   Stopped 0   Playing 1   Paused 2
;;;;
;;;; CNA numbers it identically -- `CNA_MEDIA_STATE_STOPPED' is 0. **That
;;;; agreement is not why the translation is by name.** `BlendFunction' is the
;;;; standing counterexample: XNA numbers Min 3 and Max 4, CNA numbers them the
;;;; other way round, and every other enumeration in this binding happened to
;;;; agree -- which is exactly how a numeric pass-through survives to the one
;;;; place it turns a minimum into a maximum. So this translates through an
;;;; explicit table like all the others, and a test asserts the two sides agree
;;;; rather than assuming it.

(in-package #:microsoft.xna.framework.media)

(xna::define-xna-enum media-state
  '((:stopped . 0)
    (:playing . 1)
    (:paused  . 2))
  :documentation
  "Microsoft.Xna.Framework.Media.MediaState: what the media player is doing.

**It is a third numbering, and it is not `SoundState''s.** Audio's `SoundState'
puts Playing 0, Paused 1, Stopped 2; this one puts Stopped 0, Playing 1, Paused
2. The two share every member name and agree on none of their values, so nothing
may be read across from one to the other -- which is why they are separate tables
in separate packages rather than one shared translation.

The numbering is observable in the pinned IL rather than cosmetic:
`MediaPlayer.Stop' tests the state with a `brfalse', taking the zero branch when
it is already `Stopped', and `MediaPlayer.Pause' compares against `ldc.i4.1' for
`Playing'. A projection that renumbered the trio would invert both tests.")
