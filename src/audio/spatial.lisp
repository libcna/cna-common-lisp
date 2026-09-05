;;;; spatial.lisp --- Microsoft.Xna.Framework.Audio.AudioListener and AudioEmitter.
;;;;
;;;; **Neither is a native resource, and neither holds a handle.** Both are
;;;; ordinary managed objects in XNA -- a public parameterless constructor and
;;;; four or five settable Vector3/float properties, with no `Dispose', no
;;;; `IDisposable' and nothing native behind them -- and CNA agrees: its own
;;;; header calls `CNA_AudioListener' and `CNA_AudioEmitter' "a fixed value here
;;;; rather than a handle" because "the canonical emitter is a plain settings
;;;; object with no behavior of its own". So these are CLOS objects over Lisp
;;;; slots, and the C struct is built at the `Apply3D' boundary and thrown away
;;;; when the call returns. No `CNA_AudioListener' or `CNA_AudioEmitter' is ever
;;;; public, and neither type is a NATIVE-OBJECT.
;;;;
;;;; **The defaults are XNA's, and CNA agrees.** `PresentationParameters' takes
;;;; its defaults from `cna_presentation_parameters_init' rather than restating
;;;; them, and the reason there was that a list of numbers restated in Lisp can
;;;; drift. The trade goes the other way here, because these two constructors take
;;;; no game: reading defaults through CNA would make `(make-instance
;;;; \='audio-listener)' require a live native library, and XNA's requires nothing.
;;;; So the initforms are the pinned IL's, and `tests/native/audio.lisp' calls
;;;; `cna_audio_listener_init' and `cna_audio_emitter_init' and asserts the two
;;;; authorities still agree. Measured against 0.21.0 and against the IL:
;;;;
;;;;   Position (0 0 0)   Velocity (0 0 0)   Forward (0 0 -1)   Up (0 1 0)
;;;;   AudioEmitter.DopplerScale 1.0
;;;;
;;;; which is `Vector3.Zero', `Vector3.Zero', `Vector3.Forward' and `Vector3.Up'
;;;; -- XNA's own constructor, member for member. A test asserts the agreement
;;;; rather than trusting it, because a CNA that changed its defaults would
;;;; otherwise change this binding's public API silently.
;;;;
;;;; **One thing XNA does that is deliberately not reproduced, because it is not
;;;; observable.** XNA stores all four vectors with the Z component negated --
;;;; `UnsafeNativeStructures.FlipHandedness', which is XACT's left-handed space --
;;;; and negates it again on the way out of every getter. The flip is its own
;;;; inverse, so the public value round-trips exactly and no program can tell it
;;;; happened. CNA takes these vectors in XNA's own space: its `init' routes write
;;;; `forward = (0 0 -1)', which is `Vector3.Forward' unflipped. So the value a
;;;; program sets is the value stored and the value CNA is handed. Do not
;;;; introduce a flip here to "match XNA" -- it would match XNA's private storage
;;;; and break XNA's public behaviour.

(in-package #:microsoft.xna.framework.audio)

;;; XNA's own defaults, from the pinned IL: `Vector3.Zero', `Vector3.Zero',
;;; `Vector3.Forward', `Vector3.Up', and 1.0 for the emitter's Doppler scale.
;;; They are written as initforms below rather than read out of CNA, so that a
;;; listener can be constructed with **no native library loaded at all** -- XNA's
;;; constructors take no game and neither do these, and a default that could only
;;; be read through CNA would have quietly made them need one.
;;;
;;; `tests/native/audio.lisp' calls `cna_audio_listener_init' and
;;; `cna_audio_emitter_init' and asserts that CNA writes the same nine values.
;;; That is the check that keeps the two authorities honest without making the
;;; public API depend on one of them.

;;; --- the two classes -----------------------------------------------------

(defclass audio-listener ()
  ((position :initform (xna:vector3-zero) :accessor position)
   (velocity :initform (xna:vector3-zero) :accessor velocity)
   (forward  :initform (xna:vector3-forward) :accessor forward)
   (up       :initform (xna:vector3-up) :accessor up))
  (:documentation
   "Microsoft.Xna.Framework.Audio.AudioListener: where the ears are, and how they move.

`(make-instance \='audio-listener)' is XNA's parameterless constructor, and its
four properties are the ordinary readers and `SETF' writers XNA's are. None of
them validates: XNA's four setters are bare `stfld' after the handedness flip, so
any Vector3 is stored, NaN and infinity included, and this stores them too.

The type is not sealed in XNA and is not sealed here; it holds no native handle,
so nothing needs disposing."))

(defclass audio-emitter ()
  ((position :initform (xna:vector3-zero) :accessor position)
   (velocity :initform (xna:vector3-zero) :accessor velocity)
   (forward  :initform (xna:vector3-forward) :accessor forward)
   (up       :initform (xna:vector3-up) :accessor up)
   (doppler-scale :initform 1.0f0 :reader doppler-scale))
  (:documentation
   "Microsoft.Xna.Framework.Audio.AudioEmitter: where a sound is, and how it moves.

An `AudioListener' with one property more, and that property is the only one on
either type that refuses a value. See `(setf doppler-scale)'."))

;;; --- the one setter that validates ---------------------------------------

(defmethod (setf doppler-scale) (value (emitter audio-emitter))
  "AudioEmitter.DopplerScale's setter, which is the one spatial setter with a guard.

XNA refuses a **negative** scale with `ArgumentOutOfRangeException(\"value\")',
and the comparison is `bge.un' -- unordered -- so a NaN takes the accepting
branch and is stored. That is not a slip to correct: `SoundEffect.DopplerScale',
the process-wide static, uses `blt.un' instead and therefore *throws* on NaN. Two
properties of the same name, two different NaN answers, both read from the IL and
both pinned by a test.

Zero is accepted. Positive infinity is accepted."
  (let ((v (xna::f value)))
    ;; NaN is **stored**, so it must not reach the comparison: XNA's guard here is
    ;; `bge.un', the accepting branch, unlike the static SoundEffect.DopplerScale
    ;; whose `blt.un' throws. Testing for it explicitly is what keeps the two
    ;; readable apart -- and keeps the check off the FPU trap state.
    (when (and (not (cna-lisp.internal:nan-p v)) (< v 0.0f0))
      (error 'xna:cna-argument-out-of-range-error
             :operation "setf doppler-scale"
             :parameter-name "value"
             :object-type 'audio-emitter
             :format-control
             "AudioEmitter.DopplerScale must not be negative; ~a was given. ~
              XNA refuses a negative scale and accepts every other binary32 ~
              value, a NaN included."
             :format-arguments (list v)))
    (setf (slot-value emitter 'doppler-scale) v)))

;;; --- the boundary: managed object in, C struct out -----------------------

(defmacro %with-listener-struct ((var listener) &body body)
  "Bind VAR to a filled `CNA_AudioListener' for the duration of BODY.

The struct is stack-allocated, versioned as CNA requires, and gone when BODY
returns. It never escapes and is never public."
  (let ((l (gensym "LISTENER")))
    `(let ((,l ,listener))
       (check-type ,l audio-listener)
       (cffi:with-foreign-object (,var '(:struct cna-lisp.internal.ffi::cna-audio-listener))
         (%fill-listener ,var ,l)
         ,@body))))

(defun %fill-vector3 (raw struct-type slot vector)
  (let ((p (cffi:foreign-slot-pointer raw struct-type slot)))
    (setf (cffi:mem-aref p :float 0) (xna:vector3-x vector)
          (cffi:mem-aref p :float 1) (xna:vector3-y vector)
          (cffi:mem-aref p :float 2) (xna:vector3-z vector))))

(defun %fill-listener (raw listener)
  "Write LISTENER into a caller-provided CNA_AudioListener."
  (let ((type '(:struct cna-lisp.internal.ffi::cna-audio-listener)))
    (cffi:foreign-funcall "memset" :pointer raw :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-audio-listener+ :void)
    (setf (cffi:foreign-slot-value raw type 'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-audio-listener+
          (cffi:foreign-slot-value raw type 'cna-lisp.internal.ffi::struct-version) 1)
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::position (position listener))
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::velocity (velocity listener))
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::forward  (forward listener))
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::up       (up listener))
    raw))

(defun %fill-emitter (raw emitter)
  "Write EMITTER into a caller-provided CNA_AudioEmitter."
  (let ((type '(:struct cna-lisp.internal.ffi::cna-audio-emitter)))
    (cffi:foreign-funcall "memset" :pointer raw :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-audio-emitter+ :void)
    (setf (cffi:foreign-slot-value raw type 'cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-audio-emitter+
          (cffi:foreign-slot-value raw type 'cna-lisp.internal.ffi::struct-version) 1
          (cffi:foreign-slot-value raw type 'cna-lisp.internal.ffi::doppler-scale)
          (doppler-scale emitter))
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::position (position emitter))
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::velocity (velocity emitter))
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::forward  (forward emitter))
    (%fill-vector3 raw type 'cna-lisp.internal.ffi::up       (up emitter))
    raw))

(defmacro %with-emitter-struct ((var emitter) &body body)
  "Bind VAR to a filled `CNA_AudioEmitter' for the duration of BODY."
  (let ((e (gensym "EMITTER")))
    `(let ((,e ,emitter))
       (check-type ,e audio-emitter)
       (cffi:with-foreign-object (,var '(:struct cna-lisp.internal.ffi::cna-audio-emitter))
         (%fill-emitter ,var ,e)
         ,@body))))
