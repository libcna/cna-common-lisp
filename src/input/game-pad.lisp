;;;; game-pad.lisp --- the Microsoft.Xna.Framework.Input GamePad family.
;;;;
;;;; Nine XNA types over three CNA routes. The projection is mostly mechanical,
;;;; and the two places it is not are worth saying out loud.
;;;;
;;;; **The C ABI's `GamePadType' values are not XNA's.** CNA numbers the pad
;;;; types 0 through 9 consecutively; XNA numbers them 0 through 8 and then jumps
;;;; to 0x300 for `BigButtonPad'. A projection that passed the integer through
;;;; would answer 9 where the contract says 768, so the two tables are kept apart
;;;; and the boundary translates. The button bits, by contrast, agree exactly,
;;;; and the tests check that rather than assuming it.
;;;;
;;;; **`Buttons' is a flags enum whose members include the analog directions.**
;;;; `Buttons.LeftThumbstickUp' is a *derived* bit that the platform sets from
;;;; the stick position, not a physical button, and `GamePadState.IsButtonDown'
;;;; answers it. CNA derives the same bits, so this projection reads them rather
;;;; than recomputing them from the thumbstick vectors.

(in-package #:microsoft.xna.framework.input)

(microsoft.xna.framework::define-xna-enum buttons
  '((:dpad-up . #x00000001) (:dpad-down . #x00000002)
    (:dpad-left . #x00000004) (:dpad-right . #x00000008)
    (:start . #x00000010) (:back . #x00000020)
    (:left-stick . #x00000040) (:right-stick . #x00000080)
    (:left-shoulder . #x00000100) (:right-shoulder . #x00000200)
    (:big-button . #x00000800)
    (:a . #x00001000) (:b . #x00002000) (:x . #x00004000) (:y . #x00008000)
    (:left-thumbstick-left . #x00200000)
    (:right-trigger . #x00400000) (:left-trigger . #x00800000)
    (:right-thumbstick-up . #x01000000) (:right-thumbstick-down . #x02000000)
    (:right-thumbstick-right . #x04000000) (:right-thumbstick-left . #x08000000)
    (:left-thumbstick-up . #x10000000) (:left-thumbstick-down . #x20000000)
    (:left-thumbstick-right . #x40000000))
  :documentation "Microsoft.Xna.Framework.Input.Buttons, a flags enum."
  :flags t)

(microsoft.xna.framework::define-xna-enum game-pad-type
  ;; XNA's own values. BigButtonPad is 0x300 and not 9, which is where CNA's
  ;; consecutive numbering and the contract part company.
  '((:unknown . 0) (:game-pad . 1) (:wheel . 2) (:arcade-stick . 3)
    (:flight-stick . 4) (:dance-pad . 5) (:guitar . 6) (:alternate-guitar . 7)
    (:drum-kit . 8) (:big-button-pad . #x300))
  :documentation "Microsoft.Xna.Framework.Input.GamePadType.")

(microsoft.xna.framework::define-xna-enum game-pad-dead-zone
  '((:none . 0) (:independent-axes . 1) (:circular . 2))
  :documentation "Microsoft.Xna.Framework.Input.GamePadDeadZone.")

(defparameter *game-pad-type-from-abi*
  '((0 . :unknown) (1 . :game-pad) (2 . :wheel) (3 . :arcade-stick)
    (4 . :flight-stick) (5 . :dance-pad) (6 . :guitar) (7 . :alternate-guitar)
    (8 . :drum-kit) (9 . :big-button-pad))
  "CNA's consecutive pad-type numbering, which is not XNA's.

Kept separate from *GAME-PAD-TYPE-TABLE* on purpose: the ABI's ninth value is
XNA's 0x300, and a projection that shared one table would answer whichever
number it happened to be holding.")

(defun %game-pad-type-of (abi-value)
  (or (cdr (assoc abi-value *game-pad-type-from-abi*))
      (error 'microsoft.xna.framework:cna-internal-error
             :operation "game-pad-get-capabilities"
             :format-control "CNA reported gamepad type ~d, which the ABI does not define."
             :format-arguments (list abi-value))))

;;; --- the four value types a state is made of --------------------------------

(defconstant +game-pad-button-mask+ #xFBF0
  "The eleven bits GamePadButtons holds: A, B, X, Y, Back, Start, the two
shoulders, the two sticks and the big button. A literal because a DEFCONSTANT's
value is needed at compile time and BUTTONS-VALUE is not; the unit test
recomputes it from the enum table, so it cannot quietly disagree with the members
it names.

XNA's GamePadButtons is eleven separate ButtonState fields, so it cannot carry a
directional-pad bit and its equality cannot see one. This projection keeps a bit
set instead -- eleven parallel slots are eleven chances to drift -- and masks on
the way in, which is what makes the two representations agree.")

(defconstant +game-pad-dpad-mask+ #xF
  "The four directional-pad bits, checked the same way.")

(defstruct (game-pad-buttons (:constructor %make-game-pad-buttons (mask))
                             (:copier copy-game-pad-buttons))
  "Microsoft.Xna.Framework.Input.GamePadButtons: eleven button states."
  (mask 0 :type (unsigned-byte 32)))

(defun make-game-pad-buttons (&optional pressed)
  "GamePadButtons(Buttons): the listed buttons pressed and no others.

A member outside the eleven -- a directional-pad bit, a trigger, a thumbstick
direction -- is dropped rather than stored, because the original has nowhere to
put it and its equality would not see it."
  (%make-game-pad-buttons (logand (buttons-value (or pressed '()))
                                  +game-pad-button-mask+)))

(macrolet ((reader (name member documentation)
             `(defun ,name (value)
                ,documentation
                (if (logtest (game-pad-buttons-mask value) (buttons-value ,member))
                    :pressed :released))))
  (reader game-pad-buttons-a :a "GamePadButtons.A.")
  (reader game-pad-buttons-b :b "GamePadButtons.B.")
  (reader game-pad-buttons-x :x "GamePadButtons.X.")
  (reader game-pad-buttons-y :y "GamePadButtons.Y.")
  (reader game-pad-buttons-back :back "GamePadButtons.Back.")
  (reader game-pad-buttons-start :start "GamePadButtons.Start.")
  (reader game-pad-buttons-big-button :big-button "GamePadButtons.BigButton.")
  (reader game-pad-buttons-left-shoulder :left-shoulder
          "GamePadButtons.LeftShoulder.")
  (reader game-pad-buttons-right-shoulder :right-shoulder
          "GamePadButtons.RightShoulder.")
  (reader game-pad-buttons-left-stick :left-stick "GamePadButtons.LeftStick.")
  (reader game-pad-buttons-right-stick :right-stick "GamePadButtons.RightStick."))

(defun game-pad-buttons-equal (left right)
  "GamePadButtons.Equals and op_Equality."
  (= (game-pad-buttons-mask left) (game-pad-buttons-mask right)))

(defstruct (game-pad-dpad (:constructor %make-game-pad-dpad (mask))
                          (:copier copy-game-pad-dpad))
  "Microsoft.Xna.Framework.Input.GamePadDPad: the four directional states."
  (mask 0 :type (unsigned-byte 32)))

(defun make-game-pad-dpad (&optional (up :released) (down :released)
                                     (left :released) (right :released))
  "GamePadDPad(ButtonState, ButtonState, ButtonState, ButtonState).

The original's parameter order is up, down, left, right -- not the reading order
its Up/Down/Right/Left property order might suggest."
  (flet ((bit-of (state member)
           (check-type state button-state)
           (if (eq state :pressed) (buttons-value member) 0)))
    (%make-game-pad-dpad (logior (bit-of up :dpad-up) (bit-of down :dpad-down)
                                 (bit-of left :dpad-left)
                                 (bit-of right :dpad-right)))))

(macrolet ((reader (name member documentation)
             `(defun ,name (value)
                ,documentation
                (if (logtest (game-pad-dpad-mask value) (buttons-value ,member))
                    :pressed :released))))
  (reader game-pad-dpad-up :dpad-up "GamePadDPad.Up.")
  (reader game-pad-dpad-down :dpad-down "GamePadDPad.Down.")
  (reader game-pad-dpad-left :dpad-left "GamePadDPad.Left.")
  (reader game-pad-dpad-right :dpad-right "GamePadDPad.Right."))

(defun game-pad-dpad-equal (left right)
  "GamePadDPad.Equals and op_Equality."
  (= (game-pad-dpad-mask left) (game-pad-dpad-mask right)))

(defstruct (game-pad-thumb-sticks
            (:constructor %make-game-pad-thumb-sticks (left right))
            (:copier copy-game-pad-thumb-sticks))
  "Microsoft.Xna.Framework.Input.GamePadThumbSticks: two stick positions."
  (left (microsoft.xna.framework:make-vector2)
   :type microsoft.xna.framework:vector2)
  (right (microsoft.xna.framework:make-vector2)
   :type microsoft.xna.framework:vector2))

(defun make-game-pad-thumb-sticks (&optional (left (microsoft.xna.framework:make-vector2))
                                             (right (microsoft.xna.framework:make-vector2)))
  "GamePadThumbSticks(Vector2, Vector2)."
  (%make-game-pad-thumb-sticks (microsoft.xna.framework:copy-vector2 left)
                               (microsoft.xna.framework:copy-vector2 right)))

(defun game-pad-thumb-sticks-equal (left right)
  "GamePadThumbSticks.Equals and op_Equality."
  (and (microsoft.xna.framework:vector2-equal
        (game-pad-thumb-sticks-left left) (game-pad-thumb-sticks-left right))
       (microsoft.xna.framework:vector2-equal
        (game-pad-thumb-sticks-right left) (game-pad-thumb-sticks-right right))))

(defstruct (game-pad-triggers (:constructor %make-game-pad-triggers (left right))
                              (:copier copy-game-pad-triggers))
  "Microsoft.Xna.Framework.Input.GamePadTriggers: two trigger positions."
  (left 0.0f0 :type single-float)
  (right 0.0f0 :type single-float))

(defun make-game-pad-triggers (&optional (left 0.0f0) (right 0.0f0))
  "GamePadTriggers(float, float)."
  (%make-game-pad-triggers (microsoft.xna.framework::f left)
                           (microsoft.xna.framework::f right)))

(defun game-pad-triggers-equal (left right)
  "GamePadTriggers.Equals and op_Equality."
  (and (= (game-pad-triggers-left left) (game-pad-triggers-left right))
       (= (game-pad-triggers-right left) (game-pad-triggers-right right))))

;;; --- GamePadState -----------------------------------------------------------

(defstruct (game-pad-state
            (:constructor %make-game-pad-state
                (connected packet-number mask thumb-sticks triggers))
            (:copier copy-game-pad-state))
  "Microsoft.Xna.Framework.Input.GamePadState: one controller at one instant."
  (connected nil :type boolean)
  (packet-number 0 :type (signed-byte 32))
  (mask 0 :type (unsigned-byte 32))
  (thumb-sticks (%make-game-pad-thumb-sticks (microsoft.xna.framework:make-vector2)
                                             (microsoft.xna.framework:make-vector2))
   :type game-pad-thumb-sticks)
  (triggers (%make-game-pad-triggers 0.0f0 0.0f0) :type game-pad-triggers))

(defun make-game-pad-state (&key thumb-sticks triggers buttons dpad)
  "GamePadState(GamePadThumbSticks, GamePadTriggers, GamePadButtons, GamePadDPad).

Keywords rather than four positional value types of four different types: the
original's argument order is thumbsticks, triggers, buttons, dpad, and getting it
wrong is a type error the compiler catches in C# and nothing catches here.

A constructed state is **connected**, as the original's is: only GAME-PAD-GET-STATE
answers a disconnected one."
  (let ((thumb-sticks (or thumb-sticks (make-game-pad-thumb-sticks)))
        (triggers (or triggers (make-game-pad-triggers)))
        (buttons (or buttons (make-game-pad-buttons)))
        (dpad (or dpad (make-game-pad-dpad))))
    (check-type thumb-sticks game-pad-thumb-sticks)
    (check-type triggers game-pad-triggers)
    (check-type buttons game-pad-buttons)
    (check-type dpad game-pad-dpad)
    (%make-game-pad-state t 0
                          (logior (game-pad-buttons-mask buttons)
                                  (game-pad-dpad-mask dpad))
                          thumb-sticks triggers)))

(defun make-game-pad-state-from-values (left-thumb-stick right-thumb-stick
                                        left-trigger right-trigger
                                        &optional pressed)
  "GamePadState(Vector2, Vector2, float, float, Buttons[]).

A separate name from MAKE-GAME-PAD-STATE, as MAKE-PLANE-FROM-VECTOR4 is: the two
constructors take different things, and one keyword-taking function accepting
either would be telling them apart by the run-time type of an argument."
  (%make-game-pad-state t 0 (buttons-value (or pressed '()))
                        (make-game-pad-thumb-sticks left-thumb-stick right-thumb-stick)
                        (make-game-pad-triggers left-trigger right-trigger)))

(defun game-pad-state-is-connected (state)
  "GamePadState.IsConnected."
  (game-pad-state-connected state))

(defun game-pad-state-buttons (state)
  "GamePadState.Buttons: the eleven buttons, and only those.

Masked, so that comparing two states' Buttons compares buttons -- the original's
GamePadButtons is eleven fields and has no room for the rest of the word."
  (%make-game-pad-buttons (logand (game-pad-state-mask state) +game-pad-button-mask+)))

(defun game-pad-state-dpad (state)
  "GamePadState.DPad: the four directions, and only those."
  (%make-game-pad-dpad (logand (game-pad-state-mask state) +game-pad-dpad-mask+)))

(defun game-pad-state-is-button-down (state button)
  "GamePadState.IsButtonDown.

BUTTON is one member or a list of them, and a list asks whether *every* one of
them is down -- the flags-enum reading of the original's single bit test."
  (let ((wanted (buttons-value button)))
    (= wanted (logand (game-pad-state-mask state) wanted))))

(defun game-pad-state-is-button-up (state button)
  "GamePadState.IsButtonUp: the negation of IS-BUTTON-DOWN."
  (not (game-pad-state-is-button-down state button)))

(defun game-pad-state-equal (left right)
  "GamePadState.Equals and op_Equality."
  (and (eq (game-pad-state-connected left) (game-pad-state-connected right))
       (= (game-pad-state-packet-number left) (game-pad-state-packet-number right))
       (= (game-pad-state-mask left) (game-pad-state-mask right))
       (game-pad-thumb-sticks-equal (game-pad-state-thumb-sticks left)
                                    (game-pad-state-thumb-sticks right))
       (game-pad-triggers-equal (game-pad-state-triggers left)
                               (game-pad-state-triggers right))))

;;; --- GamePadCapabilities ----------------------------------------------------

(defstruct (game-pad-capabilities
            (:constructor %make-game-pad-capabilities (type connected features))
            (:copier copy-game-pad-capabilities))
  "Microsoft.Xna.Framework.Input.GamePadCapabilities: what a controller has.

XNA gives it no public constructor -- GAME-PAD-GET-CAPABILITIES is the only way
to obtain one -- and neither does this."
  (type :unknown :type keyword)
  (connected nil :type boolean)
  (features 0 :type (unsigned-byte 32)))

(defparameter *game-pad-features*
  '(:a-button :b-button :x-button :y-button :back-button :start-button :big-button
    :dpad-up-button :dpad-down-button :dpad-left-button :dpad-right-button
    :left-shoulder-button :right-shoulder-button :left-stick-button
    :right-stick-button :left-x-thumb-stick :left-y-thumb-stick
    :right-x-thumb-stick :right-y-thumb-stick :left-trigger :right-trigger
    :left-vibration-motor :right-vibration-motor :voice-support)
  "The order the capability bits are packed in, which is the C struct's order.")

(defun %feature-bit (feature)
  (let ((position (position feature *game-pad-features*)))
    (unless position
      (error 'microsoft.xna.framework:cna-usage-error
             :operation "game-pad-capabilities"
             :format-control "~s is not a gamepad capability." :format-arguments (list feature)))
    (ash 1 position)))

(defun game-pad-capabilities-game-pad-type (capabilities)
  "GamePadCapabilities.GamePadType."
  (game-pad-capabilities-type capabilities))

(defun game-pad-capabilities-is-connected (capabilities)
  "GamePadCapabilities.IsConnected."
  (game-pad-capabilities-connected capabilities))

(macrolet ((reader (name feature documentation)
             `(defun ,name (capabilities)
                ,documentation
                (logtest (game-pad-capabilities-features capabilities)
                         (%feature-bit ,feature)))))
  (reader game-pad-capabilities-has-a-button :a-button "GamePadCapabilities.HasAButton.")
  (reader game-pad-capabilities-has-b-button :b-button "GamePadCapabilities.HasBButton.")
  (reader game-pad-capabilities-has-x-button :x-button "GamePadCapabilities.HasXButton.")
  (reader game-pad-capabilities-has-y-button :y-button "GamePadCapabilities.HasYButton.")
  (reader game-pad-capabilities-has-back-button :back-button
          "GamePadCapabilities.HasBackButton.")
  (reader game-pad-capabilities-has-start-button :start-button
          "GamePadCapabilities.HasStartButton.")
  (reader game-pad-capabilities-has-big-button :big-button
          "GamePadCapabilities.HasBigButton.")
  (reader game-pad-capabilities-has-dpad-up-button :dpad-up-button
          "GamePadCapabilities.HasDPadUpButton.")
  (reader game-pad-capabilities-has-dpad-down-button :dpad-down-button
          "GamePadCapabilities.HasDPadDownButton.")
  (reader game-pad-capabilities-has-dpad-left-button :dpad-left-button
          "GamePadCapabilities.HasDPadLeftButton.")
  (reader game-pad-capabilities-has-dpad-right-button :dpad-right-button
          "GamePadCapabilities.HasDPadRightButton.")
  (reader game-pad-capabilities-has-left-shoulder-button :left-shoulder-button
          "GamePadCapabilities.HasLeftShoulderButton.")
  (reader game-pad-capabilities-has-right-shoulder-button :right-shoulder-button
          "GamePadCapabilities.HasRightShoulderButton.")
  (reader game-pad-capabilities-has-left-stick-button :left-stick-button
          "GamePadCapabilities.HasLeftStickButton.")
  (reader game-pad-capabilities-has-right-stick-button :right-stick-button
          "GamePadCapabilities.HasRightStickButton.")
  (reader game-pad-capabilities-has-left-x-thumb-stick :left-x-thumb-stick
          "GamePadCapabilities.HasLeftXThumbStick.")
  (reader game-pad-capabilities-has-left-y-thumb-stick :left-y-thumb-stick
          "GamePadCapabilities.HasLeftYThumbStick.")
  (reader game-pad-capabilities-has-right-x-thumb-stick :right-x-thumb-stick
          "GamePadCapabilities.HasRightXThumbStick.")
  (reader game-pad-capabilities-has-right-y-thumb-stick :right-y-thumb-stick
          "GamePadCapabilities.HasRightYThumbStick.")
  (reader game-pad-capabilities-has-left-trigger :left-trigger
          "GamePadCapabilities.HasLeftTrigger.")
  (reader game-pad-capabilities-has-right-trigger :right-trigger
          "GamePadCapabilities.HasRightTrigger.")
  (reader game-pad-capabilities-has-left-vibration-motor :left-vibration-motor
          "GamePadCapabilities.HasLeftVibrationMotor.")
  (reader game-pad-capabilities-has-right-vibration-motor :right-vibration-motor
          "GamePadCapabilities.HasRightVibrationMotor.")
  (reader game-pad-capabilities-has-voice-support :voice-support
          "GamePadCapabilities.HasVoiceSupport."))

;;; --- GamePad ----------------------------------------------------------------

(defun %player-index-value (player-index operation)
  (unless (typep player-index 'microsoft.xna.framework:player-index)
    (error 'microsoft.xna.framework:cna-usage-error
           :operation operation
           :format-control "~s is not a player index." :format-arguments (list player-index)))
  (microsoft.xna.framework:player-index-value player-index))

(defun game-pad-get-state (player-index &optional dead-zone)
  "GamePad.GetState(PlayerIndex) and GamePad.GetState(PlayerIndex, GamePadDeadZone).

DEAD-ZONE is a trailing optional argument, because the two overloads differ only
by it. Without it CNA applies its own default, which is what the one-argument
overload does."
  (let ((handle (%active-game-handle "game-pad-get-state"))
        (player (%player-index-value player-index "game-pad-get-state")))
    (when dead-zone (check-type dead-zone game-pad-dead-zone))
    (cffi:with-foreign-object (state '(:struct cna-lisp.internal.ffi::cna-game-pad-state))
      (cffi:foreign-funcall "memset" :pointer state :int 0
                            :size cna-lisp.internal.ffi::+sizeof-cna-game-pad-state+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     state '(:struct cna-lisp.internal.ffi::cna-game-pad-state) ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-game-pad-state+
              (slot cna-lisp.internal.ffi::struct-version) 1)
        (cna-lisp.internal:check-result
         (if dead-zone
             (cna-lisp.internal.ffi::%gamepad-get-state-with-dead-zone
              handle player (game-pad-dead-zone-value dead-zone) state)
             (cna-lisp.internal.ffi::%gamepad-get-state handle player state))
         "game-pad-get-state")
        (let ((analog (cffi:foreign-slot-pointer
                       state '(:struct cna-lisp.internal.ffi::cna-game-pad-state)
                       'cna-lisp.internal.ffi::analog)))
          (macrolet ((analog-slot (name)
                       `(cffi:foreign-slot-value
                         analog '(:struct cna-lisp.internal.ffi::cna-game-pad-analog-state)
                         ',name)))
            (flet ((stick (name)
                     (let ((pointer (cffi:foreign-slot-pointer
                                     analog
                                     '(:struct cna-lisp.internal.ffi::cna-game-pad-analog-state)
                                     name)))
                       (microsoft.xna.framework:make-vector2
                        (cffi:mem-aref pointer :float 0)
                        (cffi:mem-aref pointer :float 1)))))
              (%make-game-pad-state
               (cna-lisp.internal.ffi:cna-true-p (slot cna-lisp.internal.ffi::is-connected))
               (slot cna-lisp.internal.ffi::packet-number)
               (slot cna-lisp.internal.ffi::pressed-buttons)
               (%make-game-pad-thumb-sticks
                (stick 'cna-lisp.internal.ffi::left-thumb-stick)
                (stick 'cna-lisp.internal.ffi::right-thumb-stick))
               (%make-game-pad-triggers
                (analog-slot cna-lisp.internal.ffi::left-trigger)
                (analog-slot cna-lisp.internal.ffi::right-trigger))))))))))

(defun game-pad-get-capabilities (player-index)
  "GamePad.GetCapabilities."
  (let ((handle (%active-game-handle "game-pad-get-capabilities"))
        (player (%player-index-value player-index "game-pad-get-capabilities")))
    (cffi:with-foreign-object
        (caps '(:struct cna-lisp.internal.ffi::cna-game-pad-capabilities))
      (cffi:foreign-funcall
       "memset" :pointer caps :int 0
       :size cna-lisp.internal.ffi::+sizeof-cna-game-pad-capabilities+ :void)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     caps '(:struct cna-lisp.internal.ffi::cna-game-pad-capabilities)
                     ',name)))
        (setf (slot cna-lisp.internal.ffi::struct-size)
              cna-lisp.internal.ffi::+sizeof-cna-game-pad-capabilities+
              (slot cna-lisp.internal.ffi::struct-version) 1)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%gamepad-get-capabilities handle player caps)
         "game-pad-get-capabilities")
        (let ((features 0))
          (macrolet ((collect (&rest pairs)
                       `(progn
                          ,@(loop for (feature field) on pairs by #'cddr
                                  collect `(when (cna-lisp.internal.ffi:cna-true-p
                                                  (slot ,field))
                                             (setf features
                                                   (logior features
                                                           (%feature-bit ,feature))))))))
            (collect :a-button cna-lisp.internal.ffi::has-a-button
                     :b-button cna-lisp.internal.ffi::has-b-button
                     :x-button cna-lisp.internal.ffi::has-x-button
                     :y-button cna-lisp.internal.ffi::has-y-button
                     :back-button cna-lisp.internal.ffi::has-back-button
                     :start-button cna-lisp.internal.ffi::has-start-button
                     :big-button cna-lisp.internal.ffi::has-big-button
                     :dpad-up-button cna-lisp.internal.ffi::has-dpad-up-button
                     :dpad-down-button cna-lisp.internal.ffi::has-dpad-down-button
                     :dpad-left-button cna-lisp.internal.ffi::has-dpad-left-button
                     :dpad-right-button cna-lisp.internal.ffi::has-dpad-right-button
                     :left-shoulder-button cna-lisp.internal.ffi::has-left-shoulder-button
                     :right-shoulder-button cna-lisp.internal.ffi::has-right-shoulder-button
                     :left-stick-button cna-lisp.internal.ffi::has-left-stick-button
                     :right-stick-button cna-lisp.internal.ffi::has-right-stick-button
                     :left-x-thumb-stick cna-lisp.internal.ffi::has-left-x-thumb-stick
                     :left-y-thumb-stick cna-lisp.internal.ffi::has-left-y-thumb-stick
                     :right-x-thumb-stick cna-lisp.internal.ffi::has-right-x-thumb-stick
                     :right-y-thumb-stick cna-lisp.internal.ffi::has-right-y-thumb-stick
                     :left-trigger cna-lisp.internal.ffi::has-left-trigger
                     :right-trigger cna-lisp.internal.ffi::has-right-trigger
                     :left-vibration-motor cna-lisp.internal.ffi::has-left-vibration-motor
                     :right-vibration-motor cna-lisp.internal.ffi::has-right-vibration-motor
                     :voice-support cna-lisp.internal.ffi::has-voice-support))
          (%make-game-pad-capabilities
           (%game-pad-type-of (slot cna-lisp.internal.ffi::gamepad-type))
           (cna-lisp.internal.ffi:cna-true-p (slot cna-lisp.internal.ffi::is-connected))
           features))))))

(defun game-pad-set-vibration (player-index left-motor right-motor)
  "GamePad.SetVibration: answers whether the vibration was applied."
  (let ((handle (%active-game-handle "game-pad-set-vibration"))
        (player (%player-index-value player-index "game-pad-set-vibration")))
    (cffi:with-foreign-object (applied :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%gamepad-set-vibration
        handle player
        (microsoft.xna.framework::f left-motor)
        (microsoft.xna.framework::f right-motor)
        applied)
       "game-pad-set-vibration")
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref applied :uint8)))))
