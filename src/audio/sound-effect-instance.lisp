;;;; sound-effect-instance.lisp --- Microsoft.Xna.Framework.Audio.SoundEffectInstance.
;;;;
;;;; A controllable playback of a `SoundEffect', and a native child of it. CNA's
;;;; `cna_sound_effect_create_instance' says the relation plainly -- "an
;;;; explicitly ordered C child: destroy it before its sound effect. It also
;;;; remains a child of the game that owns the effect" -- so the ownership graph
;;;; is `Game -> SoundEffect -> SoundEffectInstance', and this binding enforces
;;;; it before the ABI does.
;;;;
;;;; **`SoundEffectInstance' is the one audio class XNA does not seal.**
;;;; `DynamicSoundEffectInstance' derives from it. That subclass is not in this
;;;; selection, but the shape has to leave room for it, which is why `Dispose(bool)'
;;;; is `not-applicable' rather than projected: Common Lisp has no finalizers here
;;;; by policy, so the disposing/finalizing distinction the protected overload
;;;; exists for has nothing to express.
;;;;
;;;; **Three setters validate, and their bounds are XNA's, not CNA's.** The
;;;; divergence is real and goes both ways:
;;;;
;;;;   Volume   XNA refuses outside [0, 1];  CNA passes any finite value through
;;;;   Pitch    XNA refuses outside [-1, 1]; CNA **clamps** to [-1, 1]
;;;;   Pan      XNA refuses outside [-1, 1]; CNA refuses too
;;;;
;;;; so two of the three would silently accept a value XNA throws on. The checks
;;;; therefore run here, before the route. All three use an unordered comparison
;;;; in the IL, so **NaN is refused by all three**.
;;;;
;;;; **"Aim before you play", and it is XNA's rule as much as CNA's.** CNA's
;;;; `apply_3d' refuses an instance that is already playing and was never
;;;; positioned, because the reference implementation submits its audio packet on
;;;; the first play. XNA's own `Pan' setter has the mirror image of that rule: once
;;;; an instance is positioned, `Pan' throws `InvalidOperationException' rather
;;;; than being ignored. Both directions are projected.

(in-package #:microsoft.xna.framework.audio)

(defclass sound-effect-instance (cna-lisp.internal:native-object)
  ((%effect :initarg :sound-effect :reader %instance-sound-effect
            :documentation "The parent SOUND-EFFECT. Not public: XNA's SoundEffect
property on this type is `assembly'-visible, not public, and is not in the
selected contract.")
   (%positioned :initform nil :accessor %instance-positioned-p
                :documentation "True once APPLY-3D has succeeded on this instance.
XNA calls this `is3d' and uses it for exactly one thing: refusing the Pan setter.")
   (%played :initform nil :accessor %instance-played-p
            :documentation "True once PLAY has been called on this instance, ever.

XNA calls this `isPacketSubmitted' and it is **not** a playing/stopped flag:
traced through the IL, it is set false when the voice is allocated, set true in
`Play' just after the packet is submitted, and set false again only in
`DeallocateVoice', which nothing but `Dispose' calls. `Stop' does not touch it.
So it means \"this instance has played at least once in its life\", and using the
live `State' for it -- which is the obvious wrong guess -- makes the Pan setter
legal again after a Stop, where XNA keeps refusing it."))
  (:documentation
   "Microsoft.Xna.Framework.Audio.SoundEffectInstance: one controllable playback.

Obtained from `(create-instance effect)', which is XNA's `SoundEffect.CreateInstance()'.
There is no public constructor in XNA and none here.

The measured state machine, against CNA 0.21.0 -- a fresh instance is `:STOPPED',
and every transition below was observed rather than assumed:

    :stopped --play--> :playing --pause--> :paused
    :paused  --resume--> :playing --stop--> :stopped

`IS-LOOPED' may only be set **before playback has begun**; afterwards CNA answers
`CNA_RESULT_INVALID_STATE' and XNA throws `InvalidOperationException', which is
the same refusal, so the projected condition is `CNA-INVALID-STATE-ERROR'."))

;;; --- construction ----------------------------------------------------------

(defmethod initialize-instance :after ((instance sound-effect-instance)
                                       &key sound-effect &allow-other-keys)
  "Create the native instance as a child of SOUND-EFFECT.

The whole construction is one ledger, as every native construction here is: the
handle is recorded before anything that can still fail, so a failing subclass
initializer gives it back rather than leaving CNA holding an instance the caller
never received -- and leaving the *effect* undisposable, since CNA refuses to
destroy a sound effect that still has live instances."
  (let ((operation "create-instance"))
    (unless (typep sound-effect 'sound-effect)
      (error 'xna:cna-usage-error
             :operation operation
             :format-control
             "a sound effect instance needs the SOUND-EFFECT it plays; ~s was given."
             :format-arguments (list sound-effect)))
    (cna-lisp.internal:check-usable sound-effect operation)
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%sound-effect-create-instance
        (cna-lisp.internal:handle-of sound-effect) out)
       operation :object-type 'sound-effect-instance)
      (let ((handle (cffi:mem-ref out :uint64)))
        (cna-lisp.internal:record-construction-undo
         instance
         (lambda () (cna-lisp.internal.ffi::%sound-effect-instance-destroy handle)))
        (setf (cna-lisp.internal:handle-of instance) handle
              (slot-value instance 'cna-lisp.internal::owner) sound-effect
              (slot-value instance 'cna-lisp.internal::owner-thread)
              (cna-lisp.internal:owner-thread-of sound-effect))
        (cna-lisp.internal:register-child sound-effect instance)
        (push instance (%sound-effect-instances sound-effect))
        (cna-lisp.internal:record-construction-undo
         instance
         (lambda ()
           (setf (%sound-effect-instances sound-effect)
                 (remove instance (%sound-effect-instances sound-effect) :test #'eq))
           (cna-lisp.internal:invalidate instance)))))))

(defmethod cna-lisp.internal:destroy-native ((instance sound-effect-instance))
  (let ((effect (%instance-sound-effect instance)))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sound-effect-instance-destroy
      (cna-lisp.internal:handle-of instance))
     "dispose" :object-type 'sound-effect-instance)
    (when effect
      (setf (%sound-effect-instances effect)
            (remove instance (%sound-effect-instances effect) :test #'eq)))))

;;; --- the info snapshot the readers come from -------------------------------

(defmacro %with-instance-info ((var instance operation) &body body)
  "Read `cna_sound_effect_instance_get_info' and bind VAR to a reader macro.

CNA answers state, looping, volume, pitch and pan in one versioned struct, so
five readers are one call rather than five. `(VAR slot)' reads a field."
  (let ((raw (gensym "INFO")) (i (gensym "INSTANCE")) (op (gensym "OP")))
    `(let ((,i ,instance) (,op ,operation))
       (cna-lisp.internal:check-usable ,i ,op)
       (cffi:with-foreign-object
           (,raw '(:struct cna-lisp.internal.ffi::cna-sound-effect-instance-info))
         (cffi:foreign-funcall
          "memset" :pointer ,raw :int 0
          :size cna-lisp.internal.ffi::+sizeof-cna-sound-effect-instance-info+ :void)
         (setf (cffi:foreign-slot-value
                ,raw '(:struct cna-lisp.internal.ffi::cna-sound-effect-instance-info)
                'cna-lisp.internal.ffi::struct-size)
               cna-lisp.internal.ffi::+sizeof-cna-sound-effect-instance-info+
               (cffi:foreign-slot-value
                ,raw '(:struct cna-lisp.internal.ffi::cna-sound-effect-instance-info)
                'cna-lisp.internal.ffi::struct-version)
               1)
         (cna-lisp.internal:check-result
          (cna-lisp.internal.ffi::%sound-effect-instance-get-info
           (cna-lisp.internal:handle-of ,i) ,raw)
          ,op :object-type 'sound-effect-instance)
         (macrolet ((,var (slot)
                      `(cffi:foreign-slot-value
                        ,',raw
                        '(:struct cna-lisp.internal.ffi::cna-sound-effect-instance-info)
                        ',(intern (symbol-name slot) '#:cna-lisp.internal.ffi))))
           ,@body)))))

;;; --- readers ---------------------------------------------------------------

(defmethod state ((instance sound-effect-instance))
  "SoundEffectInstance.State: :PLAYING, :PAUSED or :STOPPED.

Translated **by name** through the enumeration table rather than passed through
as a number. XNA and CNA happen to agree on all three values here; `BlendFunction'
is why agreement is not a reason to skip the table."
  (%with-instance-info (info instance "state")
    (sound-state-from-value (info state))))

(defmethod is-looped ((instance sound-effect-instance))
  "SoundEffectInstance.IsLooped's getter."
  (%with-instance-info (info instance "is-looped")
    (not (zerop (info is-looped)))))

(defmethod volume ((instance sound-effect-instance))
  "SoundEffectInstance.Volume's getter."
  (%with-instance-info (info instance "volume") (info volume)))

(defmethod pitch ((instance sound-effect-instance))
  "SoundEffectInstance.Pitch's getter."
  (%with-instance-info (info instance "pitch") (info pitch)))

(defmethod pan ((instance sound-effect-instance))
  "SoundEffectInstance.Pan's getter."
  (%with-instance-info (info instance "pan") (info pan)))

(defmethod is-disposed ((instance sound-effect-instance))
  "SoundEffectInstance.IsDisposed, from this binding's own disposal state."
  (and (cna-lisp.internal:disposed-state-of instance) t))

;;; --- the three bounded setters ---------------------------------------------

(defun %check-unit-range (value low high parameter operation)
  "Refuse VALUE outside [LOW, HIGH], **NaN included**.

XNA's three bounded setters all compare with `blt.un'/`bgt.un', so a NaN takes
the throwing branch. Written as one negated range test, which refuses NaN for the
same reason: every comparison with a NaN is false."
  (let ((v (xna::f value)))
    ;; The NaN test is explicit rather than a consequence of the range test: XNA
    ;; refuses a NaN here because its comparisons are unordered, and saying so is
    ;; clearer than relying on a comparison -- and on the FPU trap state, which a
    ;; masked comparison leaves accrued for the next operation to trip over.
    (when (or (cna-lisp.internal:nan-p v) (< v low) (> v high))
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name parameter
             :object-type 'sound-effect-instance
             :format-control "~a must be in [~a, ~a] and not NaN; ~a was given."
             :format-arguments (list parameter low high v)))
    v))

(defmethod (setf volume) (value (instance sound-effect-instance))
  "SoundEffectInstance.Volume's setter: [0, 1], NaN refused.

CNA's route passes any finite value through unclamped -- its own header says
\"CNA's unclamped pass-through behavior\" -- so the range is enforced here or
nowhere."
  (let* ((operation "setf volume")
         (v (%check-unit-range value 0.0f0 1.0f0 "volume" operation)))
    (cna-lisp.internal:check-usable instance operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sound-effect-instance-set-volume
      (cna-lisp.internal:handle-of instance) v)
     operation :object-type 'sound-effect-instance)
    v))

(defmethod (setf pitch) (value (instance sound-effect-instance))
  "SoundEffectInstance.Pitch's setter: [-1, 1], NaN refused.

**CNA clamps and XNA throws**, so this refuses before the route is reached. A
value of 2.0 is a silent 1.0 through CNA and an `ArgumentOutOfRangeException'
in XNA; the public behaviour here is XNA's."
  (let* ((operation "setf pitch")
         (v (%check-unit-range value -1.0f0 1.0f0 "pitch" operation)))
    (cna-lisp.internal:check-usable instance operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sound-effect-instance-set-pitch
      (cna-lisp.internal:handle-of instance) v)
     operation :object-type 'sound-effect-instance)
    v))

(defmethod (setf pan) (value (instance sound-effect-instance))
  "SoundEffectInstance.Pan's setter: [-1, 1], NaN refused, and refused outright
on a positioned instance.

XNA's setter does three things in order, and all three are here. It resets its
`is3d' flag when playback has **not** begun -- so positioning an instance, then
stopping it before it ever played, makes Pan legal again. It then refuses a
positioned instance with `InvalidOperationException'. Only then does it check the
range.

CNA's behaviour is the quiet version of the same rule: its header says that once
an instance is positioned the spatial values are latched and \"`..._set_pan' stops
reaching the output\". Silently doing nothing is worse than refusing, and XNA
refuses, so this refuses."
  (let ((operation "setf pan"))
    (cna-lisp.internal:check-usable instance operation)
    ;; "if (!isPacketSubmitted) is3d = false;" -- an instance that has **never
    ;; played** discards its aim here, so positioning one and then setting Pan on
    ;; it before it ever plays is legal and the positioning is thrown away. Once
    ;; it has played once, the flag sticks for the rest of its life and Pan is
    ;; refused from the next APPLY-3D onwards -- a Stop does not restore it.
    (unless (%instance-played-p instance)
      (setf (%instance-positioned-p instance) nil))
    (when (%instance-positioned-p instance)
      (error 'xna:cna-invalid-state-error
             :operation operation :object-type 'sound-effect-instance
             :format-control
             "Pan cannot be set on an instance that has been positioned with ~
              APPLY-3D: its pan is computed from the emitter's offset against the ~
              listener's right axis from then on. Stop the instance and position ~
              it again, or do not mix the two."))
    (let ((v (%check-unit-range value -1.0f0 1.0f0 "pan" operation)))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%sound-effect-instance-set-pan
        (cna-lisp.internal:handle-of instance) v)
       operation :object-type 'sound-effect-instance)
      v)))

(defmethod (setf is-looped) (value (instance sound-effect-instance))
  "SoundEffectInstance.IsLooped's setter, which is legal **only before playback**.

XNA throws `InvalidOperationException(InvalidIsLoopedCall)' once its packet has
been submitted; CNA answers `CNA_RESULT_INVALID_STATE' for the same reason and in
the same words -- \"after playback has begun\". Measured: a fresh instance accepts
it, and the same instance after one `PLAY' answers result 3. The projected
condition is `CNA-INVALID-STATE-ERROR' either way, so the two agree without this
having to detect the state itself."
  (let ((operation "setf is-looped"))
    (cna-lisp.internal:check-usable instance operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sound-effect-instance-set-is-looped
      (cna-lisp.internal:handle-of instance)
      (cna-lisp.internal.ffi:cna-bool-of value))
     operation :object-type 'sound-effect-instance)
    (and value t)))

;;; --- the transport ---------------------------------------------------------

(defmethod play ((instance sound-effect-instance)
                 &rest settings &key &allow-other-keys)
  "SoundEffectInstance.Play(). Answers no value, as XNA's `void' does.

**It takes no argument, and this refuses every keyword rather than ignoring it.**
`PLAY' is one generic function shared with `SOUND-EFFECT', whose long overload is
spelled `:VOLUME :PITCH :PAN', and CLOS lambda-list congruence therefore forces
this method to *accept* those three names. Accepting is not having: XNA's
`SoundEffectInstance' has a single `Play()' and three separate properties, so

    (play instance :volume 0.5)

is not a quieter way of setting the volume -- it is a member that does not exist,
and silently discarding the 0.5 would be the worst of the three possible answers.
An instance's volume is set through `(setf (volume instance) 0.5)', which is what
XNA's property is.

The same rule and the same reason as the buffer/texture split in SET-DATA: a
generic function shared between classes must refuse the other class's keywords by
name rather than let congruence turn them into no-ops."
  (let ((operation "play"))
    (when settings
      (xna::%check-overload-keywords
       operation
       (loop for (key nil) on settings by #'cddr
             collect (string-downcase (symbol-name key)))
       '((:plain)) :object-type 'sound-effect-instance))
    (cna-lisp.internal:check-usable instance operation)
    (%check-audio-result
     (cna-lisp.internal.ffi::%sound-effect-instance-play
      (cna-lisp.internal:handle-of instance))
     operation :object-type 'sound-effect-instance :limit-is-play-limit t)
    ;; XNA sets `isPacketSubmitted' immediately after the packet reaches the
    ;; native voice, so this is recorded after the route succeeded, not before.
    (setf (%instance-played-p instance) t)
    (values)))

(defmethod pause ((instance sound-effect-instance))
  "SoundEffectInstance.Pause()."
  (let ((operation "pause"))
    (cna-lisp.internal:check-usable instance operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sound-effect-instance-pause
      (cna-lisp.internal:handle-of instance))
     operation :object-type 'sound-effect-instance)
    (values)))

(defmethod resume ((instance sound-effect-instance))
  "SoundEffectInstance.Resume().

CNA's route \"resumes a paused instance, or starts one that has not played\", which
is XNA's behaviour too."
  (let ((operation "resume"))
    (cna-lisp.internal:check-usable instance operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sound-effect-instance-resume
      (cna-lisp.internal:handle-of instance))
     operation :object-type 'sound-effect-instance)
    (values)))

(defmethod stop ((instance sound-effect-instance) &optional (immediate t))
  "SoundEffectInstance.Stop() and SoundEffectInstance.Stop(bool).

One generic function with an optional argument, because XNA gives the two
overloads one name and the no-argument form is `Stop(true)'. IMMEDIATE false
means \"stop looping and finish naturally\", which is CNA's own wording for the
same flag."
  (let ((operation "stop"))
    (cna-lisp.internal:check-usable instance operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%sound-effect-instance-stop
      (cna-lisp.internal:handle-of instance)
      (cna-lisp.internal.ffi:cna-bool-of immediate))
     operation :object-type 'sound-effect-instance)
    (values)))

;;; --- Apply3D ---------------------------------------------------------------

(defgeneric apply-3d (instance listeners emitter)
  (:documentation
   "SoundEffectInstance.Apply3D(AudioListener, AudioEmitter) and its array overload.

**Two CLR overloads, two CLOS methods**, told apart by the declared type of the
second argument: one `AUDIO-LISTENER', or a sequence of them. That is ordinary
CLOS dispatch rather than a `TYPECASE' inside one method, so the two overloads
stay two things a program can specialise and the projection loses neither.

LISTENERS is one listener or a sequence. A single listener takes
`cna_sound_effect_instance_apply_3d'; a sequence takes `..._apply_3d_multi_ext'.

**An empty sequence is refused**, and that is CNA's decision, adopted: XNA reaches
XACT with a count of zero and surfaces whatever XACT returns, which is not an
established outcome, so a count of zero is a condition here rather than a guess.

**Aim before you play.** An instance that is already playing and was never
positioned is refused by CNA with `CNA_RESULT_INVALID_STATE', because the audio
packet was submitted on the first `PLAY' and the choice between 3D and pan is
fixed for that playback. Position first and then play, or stop, position and play
again.

**What this proves and does not.** A successful call means the values reached CNA
and the route accepted them. It is not a claim about where a human would hear the
sound; no test here makes one. How several listeners combine is CNA's own
approximation -- it evaluates each and lets the **nearest** decide -- and its
header says so; that is not XACT's per-listener output matrix and must not be
described as one."))

(defun %apply-3d-prologue (instance emitter operation)
  (cna-lisp.internal:check-usable instance operation)
  (check-type emitter audio-emitter))

(defmethod apply-3d ((instance sound-effect-instance) (listener audio-listener) emitter)
  "Apply3D(AudioListener, AudioEmitter): the single-listener overload."
  (let ((operation "apply-3d"))
    (%apply-3d-prologue instance emitter operation)
    ;; Masked for the reason the static setters are: XNA's listener and emitter
    ;; setters store a NaN without complaint, so one can reach CNA's 3D
    ;; arithmetic, and the IEEE invalid operation it raises there would otherwise
    ;; surface as FLOATING-POINT-INVALID-OPERATION out of a foreign call.
    (cna-lisp.internal:with-binary32-semantics
      (%with-emitter-struct (native-emitter emitter)
        (%with-listener-struct (native-listener listener)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%sound-effect-instance-apply-3d
            (cna-lisp.internal:handle-of instance) native-listener native-emitter)
           operation :object-type 'sound-effect-instance))))
    (setf (%instance-positioned-p instance) t)
    (values)))

(defmethod apply-3d ((instance sound-effect-instance) (listeners sequence) emitter)
  "Apply3D(AudioListener[], AudioEmitter): the several-listener overload."
  (let* ((operation "apply-3d")
         (all (coerce listeners 'vector))
         (count (length all)))
    (%apply-3d-prologue instance emitter operation)
    (when (zerop count)
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "listeners"
             :object-type 'sound-effect-instance
             :format-control
             "APPLY-3D needs at least one listener. CNA refuses a count of zero ~
              rather than guessing at it, because XNA reaches XACT with zero and ~
              surfaces whatever XACT returns -- an outcome this binding has not ~
              established."))
    (map nil (lambda (l) (check-type l audio-listener)) all)
    (cna-lisp.internal:with-binary32-semantics
      (%with-emitter-struct (native-emitter emitter)
        (cffi:with-foreign-object
            (block '(:struct cna-lisp.internal.ffi::cna-audio-listener) count)
          (dotimes (i count)
            (%fill-listener
             (cffi:mem-aptr block '(:struct cna-lisp.internal.ffi::cna-audio-listener) i)
             (aref all i)))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%sound-effect-instance-apply-3d-multi-ext
            (cna-lisp.internal:handle-of instance) block count native-emitter)
           operation :object-type 'sound-effect-instance))))
    (setf (%instance-positioned-p instance) t)
    (values)))
