;;;; device-selection.lisp --- GraphicsDeviceInformation, the mutable
;;;; PreparingDeviceSettings event, and the manager's protected virtual surface.
;;;;
;;;; **The suppression tests are the ones that matter here.** Making the five
;;;; `On*' methods callable would be easy and would prove nothing: in XNA their
;;;; purpose is that a subclass which overrides one and does *not* call the base
;;;; implementation stops the public event, and a binding where CNA calls every
;;;; handler directly cannot do that at all. So each seam is tested twice, with
;;;; and without CALL-NEXT-METHOD, and the discriminating assertion is the second.
;;;;
;;;; **And the mutation test is not `a callback ran'.** A handler changes a
;;;; discriminating setting, and what is asserted is the state the *device* is in
;;;; afterwards -- a direct device-information observation rather than an
;;;; inference from pixels. Both branches assert: with the handler the device
;;;; follows the handler, without it the device follows the preference.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

;;; --- GraphicsDeviceInformation ----------------------------------------------

(defclass information-game (managed-game)
  ((findings :initform '() :accessor findings))
  (:documentation
   "A game that builds GraphicsDeviceInformation objects inside a lifecycle
method, because their constructor resolves the default adapter and every adapter
route takes the callback-scoped device handle."))

(defmethod xna:load-content ((game information-game))
  (let* ((one (make-instance 'xna:graphics-device-information))
         (two (make-instance 'xna:graphics-device-information))
         (pp (xna:presentation-parameters-of one)))
    (setf (gfx:back-buffer-width pp) 1024
          (gfx:back-buffer-height pp) 768
          (xna:graphics-profile-of one) :hi-def)
    (let ((clone (xna:clone-graphics-device-information one)))
      (setf (findings game)
            (list :fresh-adapter-is-an-object
                  (typep (xna:adapter-of two) 'gfx:graphics-adapter)
                  :adapters-are-interned (eq (xna:adapter-of one) (xna:adapter-of two))
                  :adapter-is-the-devices
                  (eq (xna:adapter-of two) (gfx:adapter (xna:graphics-device game)))
                  :default-profile (xna:graphics-profile-of two)
                  :clone-is-a-new-object (not (eq clone one))
                  :clone-shares-the-adapter (eq (xna:adapter-of clone)
                                                (xna:adapter-of one))
                  :clone-copies-the-parameters
                  (not (eq (xna:presentation-parameters-of clone)
                           (xna:presentation-parameters-of one)))
                  :clone-copied-the-values
                  (list (gfx:back-buffer-width (xna:presentation-parameters-of clone))
                        (gfx:back-buffer-height (xna:presentation-parameters-of clone))
                        (xna:graphics-profile-of clone))
                  :clone-is-equal (xna:graphics-device-information-equal-p clone one)
                  :equal-hashes-match
                  (= (xna:graphics-device-information-hash-code clone)
                     (xna:graphics-device-information-hash-code one))
                  ;; The parameters are compared field by field, so an independent
                  ;; object with equal settings is equal.
                  :independent-equal-parameters-are-equal
                  (let ((other (xna:clone-graphics-device-information one)))
                    (setf (xna:presentation-parameters-of other)
                          (gfx:clone-presentation-parameters
                           (xna:presentation-parameters-of one)))
                    (xna:graphics-device-information-equal-p other one))
                  :one-differing-field-is-unequal
                  (let ((other (xna:clone-graphics-device-information one)))
                    (setf (gfx:back-buffer-width
                           (xna:presentation-parameters-of other))
                          999)
                    (xna:graphics-device-information-equal-p other one))
                  :differing-profile-is-unequal
                  (let ((other (xna:clone-graphics-device-information one)))
                    (setf (xna:graphics-profile-of other) :reach)
                    (xna:graphics-device-information-equal-p other one))
                  :a-non-information-is-unequal
                  (xna:graphics-device-information-equal-p one :not-an-information)
                  ;; XNA's setter tests the field it is about to overwrite, so a
                  ;; first NIL succeeds and the *next* assignment throws.
                  :null-adapter-succeeds-once
                  (handler-case (progn (setf (xna:adapter-of two) nil) t)
                    (xna:cna-argument-error () nil))
                  :the-next-assignment-throws
                  (handler-case (progn (setf (xna:adapter-of two)
                                             (xna:adapter-of one))
                                       nil)
                    (xna:cna-argument-error () t))
                  ;; The other two setters have no guard at all in the IL.
                  :parameters-accept-nil
                  (handler-case (let ((other (make-instance
                                              'xna:graphics-device-information)))
                                  (setf (xna:presentation-parameters-of other) nil)
                                  t)
                    (error () nil))
                  :type-name (xna:graphics-device-information-clr-type-name)))))
  (xna:exit game))

(define-native-test graphics-device-information-reproduces-the-pinned-object-model
  "DEVICE_SELECTION: the constructor's defaults, Clone's exact sharing, Equals's
exact comparison, and the setter defect XNA really has.

Every claim is the IL's. The three that would not be guessed:

  * **Clone shares the adapter and copies the parameters.** It stores
    `this.presentationParameters.Clone()' and `this.adapter' unchanged.
  * **Equals compares the parameters field by field**, not by reference, so two
    informations holding different parameter objects with equal settings are
    equal.
  * **`set_Adapter' tests the wrong operand** -- `ldarg.0; ldfld adapter;
    brtrue.s' -- so assigning NIL succeeds once and the next assignment of
    anything throws. Reproduced rather than corrected.

**The adapter is a `GraphicsAdapter' object and never CNA's index**, and it is
the same object the device answers, because adapter identity is what
`Equals' rests on: XNA's `GraphicsAdapter' overrides neither `Equals' nor
`GetHashCode', and its static adapter list is built once."
  (let ((game (make-instance 'information-game)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((f (findings game)))
             (is-true (getf f :fresh-adapter-is-an-object)
                      "GraphicsDeviceInformation.Adapter is a GraphicsAdapter,
                       not an adapter index")
             (is-true (getf f :adapters-are-interned)
                      "two informations built separately share one adapter object,
                       which is what makes XNA's reference comparison work")
             (is-true (getf f :adapter-is-the-devices))
             (is (eq :reach (getf f :default-profile))
                 "the profile field is never assigned by the constructor, so it is
                  the enumeration's zero")
             (is-true (getf f :clone-is-a-new-object))
             (is-true (getf f :clone-shares-the-adapter)
                      "Clone stores this.adapter unchanged")
             (is-true (getf f :clone-copies-the-parameters)
                      "Clone stores this.presentationParameters.Clone()")
             (is (equal '(1024 768 :hi-def) (getf f :clone-copied-the-values)))
             (is-true (getf f :clone-is-equal))
             (is-true (getf f :equal-hashes-match)
                      "equal informations hash equally, which is the whole of what
                       a hash code must guarantee")
             (is-true (getf f :independent-equal-parameters-are-equal))
             (is-false (getf f :one-differing-field-is-unequal))
             (is-false (getf f :differing-profile-is-unequal))
             (is-false (getf f :a-non-information-is-unequal))
             (is-true (getf f :null-adapter-succeeds-once)
                      "XNA's setter checks the field it is about to overwrite")
             (is-true (getf f :the-next-assignment-throws)
                      "so the refusal arrives one assignment later than a reader
                       expects -- the defect, reproduced")
             (is-true (getf f :parameters-accept-nil)
                      "set_PresentationParameters has no guard in the IL")
             (is (equal "Microsoft.Xna.Framework.GraphicsDeviceInformation"
                        (getf f :type-name))
                 "CNA names the same type this projects")
             (note-services :device-information
                            "GraphicsDeviceInformation answered a GraphicsAdapter ~
                             object rather than CNA's adapter index, Clone shared ~
                             the adapter and copied the parameters as the IL does, ~
                             Equals compared the parameters field by field, and the ~
                             Adapter setter's wrong-operand defect was reproduced")))
      (progn (ignore-errors (xna:dispose (game-manager game)))
             (ignore-errors (xna:dispose game))))))

;;; --- PREPARING_DEVICE_SETTINGS ----------------------------------------------

(defclass preparing-settings-game (managed-game)
  ((findings :initform '() :accessor findings)
   (calls :initform 0 :accessor settings-calls))
  (:documentation "A game that drives the mutable device-settings event."))

(defun %device-size (game)
  "The back-buffer size the device is actually configured with."
  (let ((pp (gfx:presentation-parameters (xna:graphics-device game))))
    (list (gfx:back-buffer-width pp) (gfx:back-buffer-height pp))))

(defmethod xna:load-content ((game preparing-settings-game))
  (let* ((manager (game-manager game))
         (sender-was nil)
         (args-were nil)
         (info-stable nil)
         (handler (lambda (sender args)
                    (incf (settings-calls game))
                    (setf sender-was sender
                          args-were args
                          info-stable (eq (xna:graphics-device-information args)
                                          (xna:graphics-device-information args)))
                    (let ((pp (xna:presentation-parameters-of
                               (xna:graphics-device-information args))))
                      (setf (gfx:back-buffer-width pp) 1234
                            (gfx:back-buffer-height pp) 567)))))
    ;; 1. No handler: the device follows the manager's preference.
    (setf (xna:preferred-back-buffer-width manager) 640
          (xna:preferred-back-buffer-height manager) 480)
    (xna:apply-changes manager)
    (let ((without (%device-size game)))
      ;; 2. With the handler: the device follows the *handler*, not the preference.
      (xna:add-preparing-device-settings-handler manager handler)
      (setf (xna:preferred-back-buffer-width manager) 800
            (xna:preferred-back-buffer-height manager) 600)
      (xna:apply-changes manager)
      (let ((with (%device-size game))
            (calls-with (settings-calls game)))
        ;; 3. Handler removed: the mutation stops.
        (let ((removed (xna:remove-preparing-device-settings-handler manager handler)))
          (setf (xna:preferred-back-buffer-width manager) 720
                (xna:preferred-back-buffer-height manager) 400)
          (xna:apply-changes manager)
          (setf (findings game)
                (list :without-handler without
                      :with-handler with
                      :after-removal (%device-size game)
                      :removed removed
                      :calls-with calls-with
                      :calls-after-removal (settings-calls game)
                      :sender-eq-manager (eq sender-was manager)
                      :args-type (type-of args-were)
                      :info-stable info-stable
                      :removing-again
                      (xna:remove-preparing-device-settings-handler manager handler)))))))
  (xna:exit game))

(define-native-test a-preparing-device-settings-handler-changes-the-device-that-is-made
  "PREPARING_DEVICE_SETTINGS: the proposal is genuinely mutable, and the proof is
the device rather than the callback.

Three passes through real device preparation, entered through `APPLY-CHANGES':

  1. **no handler** -- the device takes the manager's preference, 640x480;
  2. **a handler writing 1234x567 while the preference says 800x600** -- the
     device takes **1234x567**, so what CNA created the device from is the
     handler's write and not the preference;
  3. **the handler removed, preference 720x400** -- the device takes 720x400,
     so the mutation stopped when the subscription did.

Pass 2 is the claim. Passes 1 and 3 are what stop it from being a coincidence:
without them, a device that happened to be 1234x567 for some other reason would
satisfy the test.

Over `cna_graphics_device_manager_subscribe_preparing_device_settings_ext', the
mutable route. The observation-only sibling is not bound at all."
  (let ((game (make-instance 'preparing-settings-game)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((f (findings game)))
             (is (equal '(640 480) (getf f :without-handler))
                 "with no handler the device follows the preference")
             (is (equal '(1234 567) (getf f :with-handler))
                 "with a handler the device follows the handler, not the 800x600
                  preference that was set beside it")
             (is (equal '(720 400) (getf f :after-removal))
                 "removing the handler stopped the mutation")
             (is-true (getf f :removed) "the removal reported that it found one")
             (is (plusp (getf f :calls-with)) "the handler really ran")
             (is (= (getf f :calls-with) (getf f :calls-after-removal))
                 "and did not run again after it was removed")
             (is-true (getf f :sender-eq-manager)
                      "every raise site in the assembly passes `this'")
             (is (eq 'xna:preparing-device-settings-event-args (getf f :args-type)))
             (is-true (getf f :info-stable)
                      "the event args answer the same information object for the
                       life of the callback, which is what makes a mutation stick")
             (is-false (getf f :removing-again)
                       "a second removal finds nothing and says so")
             (note-services :preparing-device-settings
                            "a handler wrote 1234x567 into the candidate while the ~
                             manager's preference said 800x600, and the device CNA ~
                             then made was 1234x567 -- with the no-handler and ~
                             handler-removed passes asserted beside it so the ~
                             mutation is the reason rather than a coincidence")))
      (progn (ignore-errors (xna:dispose (game-manager game)))
             (ignore-errors (xna:dispose game))))))

;;; --- GDM_VIRTUAL_EVENTS: the protected raisers are real seams ----------------

(defclass overriding-manager (xna:graphics-device-manager)
  ((raiser-calls :initform 0 :accessor raiser-calls)
   (suppress :initarg :suppress :initform nil :accessor suppress-p))
  (:documentation
   "A manager whose ON-DEVICE-CREATED override optionally does not call the next
method, which in XNA suppresses the public event."))

(defmethod xna:on-device-created ((manager overriding-manager) sender)
  (incf (raiser-calls manager))
  (unless (suppress-p manager)
    (call-next-method)))

(defclass suppressing-settings-manager (xna:graphics-device-manager)
  ((raiser-calls :initform 0 :accessor raiser-calls)
   (suppress :initarg :suppress :initform nil :accessor suppress-p)
   (own-width :initarg :own-width :initform nil :accessor own-width))
  (:documentation
   "A manager that overrides the device-settings raiser, optionally without
calling the next method, and optionally writes a setting of its own."))

(defmethod xna:on-preparing-device-settings
    ((manager suppressing-settings-manager) sender args)
  (incf (raiser-calls manager))
  (when (own-width manager)
    (setf (gfx:back-buffer-width
           (xna:presentation-parameters-of (xna:graphics-device-information args)))
          (own-width manager)))
  (unless (suppress-p manager)
    (call-next-method)))

(defclass virtual-event-game (xna:game)
  ((manager :initform nil :accessor game-manager)
   (manager-class :initarg :manager-class :initform 'overriding-manager
                  :reader manager-class)
   (manager-initargs :initarg :manager-initargs :initform '()
                     :reader manager-initargs)
   (handler-calls :initform 0 :accessor handler-calls)
   (findings :initform '() :accessor findings)))

(defmethod initialize-instance :after ((game virtual-event-game) &key)
  (setf (game-manager game)
        (apply #'make-instance (manager-class game) :game game
               (manager-initargs game))))

(defmethod xna:load-content ((game virtual-event-game))
  (let ((manager (game-manager game)))
    (xna:add-device-created-handler
     manager (lambda (sender) (declare (ignore sender)) (incf (handler-calls game))))
    ;; CREATE-DEVICE enters real device creation, which raises DeviceCreated.
    (xna:create-device manager)
    (setf (findings game)
          (list :raiser-calls (raiser-calls manager)
                :handler-calls (handler-calls game))))
  (xna:exit game))

(defun %run-virtual-event-game (class &rest initargs)
  (let ((game (make-instance 'virtual-event-game
                             :manager-class class :manager-initargs initargs)))
    (unwind-protect (progn (xna:run game) (findings game))
      (progn (ignore-errors (xna:dispose (game-manager game)))
             (ignore-errors (xna:dispose game))))))

(define-native-test on-device-created-is-a-real-virtual-seam
  "GDM_VIRTUAL_EVENTS: an override that calls the next method lets the public
event through, and one that does not stops it.

XNA's base implementation is the only thing that invokes the handler list:

    if (deviceCreated != null) deviceCreated(sender, args);

so suppression is not a property this binding invented -- it is what a
`protected virtual' raiser is for. **Case B is the discriminating one**: a
binding that gave every user handler its own CNA registration would pass case A
and fail case B, because CNA would call the handler directly and the override
could never get in the way."
  ;; Case A: the override records and calls the next method.
  (let ((a (%run-virtual-event-game 'overriding-manager :suppress nil)))
    (is (plusp (getf a :raiser-calls)) "the override ran")
    (is (plusp (getf a :handler-calls))
        "and CALL-NEXT-METHOD let the public handler run"))
  ;; Case B: the override records and does not.
  (let ((b (%run-virtual-event-game 'overriding-manager :suppress t)))
    (is (plusp (getf b :raiser-calls)) "the override ran")
    (is (zerop (getf b :handler-calls))
        "and without CALL-NEXT-METHOD the public event was suppressed, which is
         what XNA does and what a registration-per-handler design cannot do")
    (note-services :virtual-events
                   "a GraphicsDeviceManager subclass overriding OnDeviceCreated saw ~
                    the public event raised when it called CALL-NEXT-METHOD and ~
                    suppressed when it did not, which is what makes the protected ~
                    raiser a seam rather than a callable function")))

(defclass settings-seam-game (xna:game)
  ((manager :initform nil :accessor game-manager)
   (manager-initargs :initarg :manager-initargs :initform '()
                     :reader manager-initargs)
   (handler-calls :initform 0 :accessor handler-calls)
   (findings :initform '() :accessor findings)))

(defmethod initialize-instance :after ((game settings-seam-game) &key)
  (setf (game-manager game)
        (apply #'make-instance 'suppressing-settings-manager :game game
               (manager-initargs game))))

(defmethod xna:load-content ((game settings-seam-game))
  (let ((manager (game-manager game)))
    (xna:add-preparing-device-settings-handler
     manager (lambda (sender args)
               (declare (ignore sender))
               (incf (handler-calls game))
               (setf (gfx:back-buffer-width
                      (xna:presentation-parameters-of
                       (xna:graphics-device-information args)))
                     1111)))
    (setf (xna:preferred-back-buffer-width manager) 640
          (xna:preferred-back-buffer-height manager) 480)
    (xna:apply-changes manager)
    (setf (findings game)
          (list :raiser-calls (raiser-calls manager)
                :handler-calls (handler-calls game)
                :device-size (%device-size game))))
  (xna:exit game))

(defun %run-settings-seam-game (&rest initargs)
  (let ((game (make-instance 'settings-seam-game :manager-initargs initargs)))
    (unwind-protect (progn (xna:run game) (findings game))
      (progn (ignore-errors (xna:dispose (game-manager game)))
             (ignore-errors (xna:dispose game))))))

(define-native-test on-preparing-device-settings-is-a-seam-that-keeps-its-own-writes
  "The same seam for the event that carries mutable state, which is a second
claim and not the same one.

Case A: the override calls the next method, and the public handler's 1111 is what
the device is made from.

Case B: the override does not, and its **own** write of 2222 is what the device
is made from -- the public handler never ran, and the write-back into CNA's
borrowed structure happens after the generic function returns, so an override can
both replace the handlers' say and have one of its own. That is the difference
between suppressing an event and suppressing a mutation, and only a test that
writes from inside the override can tell them apart."
  (let ((a (%run-settings-seam-game :suppress nil :own-width nil)))
    (is (plusp (getf a :raiser-calls)))
    (is (plusp (getf a :handler-calls)) "CALL-NEXT-METHOD let the handler run")
    (is (equal '(1111 480) (getf a :device-size))
        "and the handler's write is what the device was made from"))
  (let ((b (%run-settings-seam-game :suppress t :own-width 2222)))
    (is (plusp (getf b :raiser-calls)))
    (is (zerop (getf b :handler-calls)) "the public event was suppressed")
    (is (equal '(2222 480) (getf b :device-size))
        "and the override's own write still reached the device")))

;;; --- the device-selection surface, and its honest limit ----------------------

(defclass selection-manager (xna:graphics-device-manager)
  ((rank-calls :initform 0 :accessor rank-calls)
   (find-calls :initform 0 :accessor find-calls)
   (reset-calls :initform 0 :accessor reset-calls))
  (:documentation "A manager that counts and re-orders the selection virtuals."))

(defmethod xna:rank-devices ((manager selection-manager) candidates)
  (incf (rank-calls manager))
  ;; A discriminating override: reverse whatever the base method ranked.
  (reverse (call-next-method)))

(defmethod xna:find-best-device ((manager selection-manager) any)
  (incf (find-calls manager))
  (call-next-method))

(defmethod xna:can-reset-device ((manager selection-manager) information)
  (incf (reset-calls manager))
  (call-next-method))

(defclass selection-game (xna:game)
  ((manager :initform nil :accessor game-manager)
   (findings :initform '() :accessor findings)))

(defmethod initialize-instance :after ((game selection-game) &key)
  (setf (game-manager game) (make-instance 'selection-manager :game game)))

(defmethod xna:load-content ((game selection-game))
  (let* ((manager (game-manager game))
         (best (xna:find-best-device manager nil))
         (candidates (list best (xna:clone-graphics-device-information best)))
         (device-profile (gfx:graphics-profile (xna:graphics-device game))))
    (setf (xna:graphics-profile-of (second candidates)) :hi-def)
    (let ((ranked (xna:rank-devices manager candidates))
          (matching (make-instance 'xna:graphics-device-information))
          (differing (make-instance 'xna:graphics-device-information)))
      (setf (xna:graphics-profile-of matching) device-profile
            (xna:graphics-profile-of differing)
            (if (eq device-profile :reach) :hi-def :reach))
      (let ((can-reset-matching (xna:can-reset-device manager matching))
            (can-reset-differing (xna:can-reset-device manager differing)))
        ;; **The limit, measured.** Every direct call is already made; from here
        ;; on only the framework runs, so any movement in these counters would be
        ;; CNA calling one of the three. The window is deliberately narrow: a
        ;; `before' taken any earlier would be measuring this test's own calls.
        (let ((before (list (find-calls manager) (rank-calls manager)
                            (reset-calls manager))))
          (setf (xna:preferred-back-buffer-width manager) 640)
          (xna:apply-changes manager)
          (xna:create-device manager)
          (setf (findings game)
                (list :best-is-an-information
                      (typep best 'xna:graphics-device-information)
                      :best-has-an-adapter (typep (xna:adapter-of best)
                                                  'gfx:graphics-adapter)
                      :best-profile-is-the-managers
                      (eq (xna:graphics-profile-of best)
                          (xna:graphics-profile manager))
                      :find-called (plusp (find-calls manager))
                      :rank-called-by-find (plusp (rank-calls manager))
                      :ranked-length (length ranked)
                      :ranked-is-a-list (listp ranked)
                      :can-reset-matching can-reset-matching
                      :can-reset-differing can-reset-differing
                      :calls-before before
                      :calls-after (list (find-calls manager) (rank-calls manager)
                                         (reset-calls manager))))))))
  (xna:exit game))

(define-native-test the-device-selection-virtuals-answer-xna-and-do-not-reach-cnas-flow
  "The three protected selection members, and **the exact limit they are partial
for**.

What works: `FIND-BEST-DEVICE' builds candidates from the adapters CNA
enumerates, ranks them through the *virtual* `RANK-DEVICES' -- so the override
below really runs as part of the algorithm -- and answers a
`GraphicsDeviceInformation' whose adapter is an ordinary `GraphicsAdapter'.
`CAN-RESET-DEVICE' reproduces XNA's whole body: the profiles match or they do
not, and nothing else is consulted.

**What does not work, and is measured rather than assumed**: no admitted CNA ABI
calls any of the three during device creation. All three are `virtual' in CNA's
own C++ and `GraphicsDeviceManager.cpp' has no call site for any of them; none is
exposed as a C route in 0.21.0, 0.22.0 or 0.23.0. So the last assertion is the
honest one: a real `APPLY-CHANGES' and a real `CREATE-DEVICE' run, and the
override counters **do not move**. That is why all three are reported partial
rather than complete, and a binding that called them from its own
`APPLY-CHANGES' to make the counters move would be inventing a flow the runtime
does not have."
  (let ((game (make-instance 'selection-game)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((f (findings game)))
             (is-true (getf f :best-is-an-information))
             (is-true (getf f :best-has-an-adapter)
                      "the candidate's adapter is a GraphicsAdapter, not an index")
             (is-true (getf f :best-profile-is-the-managers))
             (is-true (getf f :find-called))
             (is-true (getf f :rank-called-by-find)
                      "FIND-BEST-DEVICE ranks through the virtual member, so a
                       subclass's RANK-DEVICES override participates in the
                       algorithm XNA gives it")
             (is (= 2 (getf f :ranked-length))
                 "ranking answers every candidate it was given")
             (is-true (getf f :ranked-is-a-list)
                      "a list stays a list: List<T> is not projected as a BCL type")
             (is-true (getf f :can-reset-matching)
                      "XNA's whole body is device.GraphicsProfile == info.GraphicsProfile")
             (is-false (getf f :can-reset-differing))
             (is (equal (getf f :calls-before) (getf f :calls-after))
                 "**the limit**: a real ApplyChanges and a real CreateDevice ran and
                  called none of the three, because no admitted CNA ABI has a seam
                  for them. This is what the partial status records.")
             (note-services :device-selection
                            "FindBestDevice built candidates from the adapters CNA ~
                             enumerates and ranked them through the virtual ~
                             RankDevices, and CanResetDevice reproduced XNA's ~
                             profile comparison -- and a real ApplyChanges and ~
                             CreateDevice called none of the three, which is the ~
                             measured limit all three are partial for")))
      (progn (ignore-errors (xna:dispose (game-manager game)))
             (ignore-errors (xna:dispose game))))))

;;; --- ownership ---------------------------------------------------------------

(define-native-test a-manager-that-fails-after-registering-its-services-leaves-none
  "OWNERSHIP: the construction is transactional across the managed registration.

A subclass whose own initializer signals runs *after* the manager has registered
itself under both service keys, because CLOS runs `:after' methods
least-specific-first. So the rollback has to remove both entries -- and it must
remove exactly those, not mirror a native removal CNA's own destroy is already
going to make.

Four things are asserted, and the last is the one that used to be impossible: the
game shuts down, which it cannot do while a child handle lives."
  (let ((game (make-instance 'xna:game)))
    (unwind-protect
         (let ((container (xna:services game))
               (before (int:callback-registry-count)))
           (signals subclass-initializer-blew-up
             (make-instance 'exploding-graphics-device-manager :game game))
           (is (null (xna:get-service container 'xna:igraphics-device-manager))
               "the rollback removed the manager registration")
           (is (null (xna:get-service container 'xna:igraphics-device-service))
               "and the service registration")
           (is (null (xna:service-types container))
               "and left the container exactly as empty as it found it")
           (is (null (remove-if-not (lambda (child)
                                      (typep child 'xna:graphics-device-manager))
                                    (int:children-of game)))
               "and no live child")
           (is (= before (int:callback-registry-count))
               "and no callback registry entry")
           ;; A second manager is creatable, which proves the first left nothing
           ;; registered on either side.
           (let ((manager (make-instance 'xna:graphics-device-manager :game game)))
             (is (eq manager (xna:get-service container 'xna:igraphics-device-manager)))
             (is-true (xna:native-service-present-p game 'xna:igraphics-device-manager))
             (xna:dispose manager)))
      (ignore-errors (xna:dispose game)))
    (is (xna:disposed-p game) "the game shut down")))

(define-native-test manager-event-registrations-return-to-their-baseline
  "OWNERSHIP: one native registration per event kind, released with the last handler.

The manager's events are the only ones in this binding that do not take a CNA
registration per handler, so the property every other event lane asserts has to be
asserted again here: subscribing and unsubscribing leaves the callback registry
where it found it, and a second handler on the same event does not take a second
registration."
  (with-managed-game (game)
    (let* ((manager (game-manager game))
           (baseline (int:callback-registry-count))
           (one (lambda (sender) (declare (ignore sender))))
           (two (lambda (sender) (declare (ignore sender)))))
      (xna:add-device-created-handler manager one)
      (let ((after-one (int:callback-registry-count)))
        (is (= (1+ baseline) after-one) "one event kind, one registration")
        (xna:add-device-created-handler manager two)
        (is (= after-one (int:callback-registry-count))
            "a second handler on the same event adds no second registration")
        (xna:add-device-reset-handler manager one)
        (is (= (1+ after-one) (int:callback-registry-count))
            "a different event kind does")
        (is-true (xna:remove-device-created-handler manager two))
        (is (= (1+ after-one) (int:callback-registry-count))
            "the registration stays while a handler remains")
        (is-true (xna:remove-device-created-handler manager one))
        (is (= after-one (int:callback-registry-count))
            "and goes with the last one")
        (is-true (xna:remove-device-reset-handler manager one))
        (is (= baseline (int:callback-registry-count)))
        (is-false (xna:remove-device-created-handler manager one)
                  "removing what is not there answers NIL, as every -= here does")))))
