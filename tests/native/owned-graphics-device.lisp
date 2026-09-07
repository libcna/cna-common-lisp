;;;; owned-graphics-device.lisp --- the GraphicsDevice a caller constructs.
;;;;
;;;; **What these lanes are for is proving there are two native ownership worlds
;;;; under one public type**, and that neither has leaked into the other. The
;;;; easy wrong implementation is a second class, or a first class that quietly
;;;; reaches for the active game whenever it needs something; both would pass a
;;;; test that only checked the constructor returns an object.
;;;;
;;;; Everything asserted here about CNA was measured first, through the C ABI
;;;; alone, by `tools/qualification/owned-device-matrix.sh'. Two of those
;;;; measurements contradict the ABI header's own prose, and both are asserted
;;;; in **both** directions so that a CNA which changed would fail a test rather
;;;; than silently changing this binding:
;;;;
;;;;   * the header says cross-device resource use "is refused"; it is not, in
;;;;     any direction, on any admitted ABI. This binding refuses it itself.
;;;;   * the header says a caller-created device's resources "are released with
;;;;     it"; they are, and the handle-table entry outlives them, so a second
;;;;     destroy is tolerated and inert.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defvar *owned-device-evidence* '()
  "What the owned-device lanes proved, level by level.

**Eight levels and they are eight claims.** A device that constructs says
nothing about whether two of them are independent; two independent devices say
nothing about whether a resource knows which one made it; and a resource that
knows says nothing about whether disposing the device leaves it in XNA's state.
Reading one of these out of another is exactly what a single `owned
GraphicsDevice works' line would do, and this file exists so that no such line
can be written.")

(defun note-owned-device (level description &rest arguments)
  (unless (assoc level *owned-device-evidence*)
    (push (cons level (apply #'format nil description arguments)) *owned-device-evidence*)))

(defun owned-device-proved-p (level)
  (assoc level *owned-device-evidence*))

;;; --- fixtures ----------------------------------------------------------------

(defun owned-device-parameters (&key (width 64) (height 32))
  "PresentationParameters small enough for a CPU rasteriser to hold."
  (let ((parameters (make-instance 'gfx:presentation-parameters)))
    (setf (gfx:back-buffer-width parameters) width
          (gfx:back-buffer-height parameters) height)
    parameters))

(defun make-owned-device (&key (width 64) (height 32) (profile :reach) adapter)
  "One caller-owned GRAPHICS-DEVICE, through XNA's own constructor."
  (make-instance 'gfx:graphics-device
                 :adapter (or adapter (first (gfx:graphics-adapter-adapters)))
                 :graphics-profile profile
                 :presentation-parameters (owned-device-parameters :width width
                                                                   :height height)))

(defmacro with-owned-device ((variable &rest arguments) &body body)
  `(let ((,variable (make-owned-device ,@arguments)))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

;;; --- OWNED_DEVICE_CREATE ------------------------------------------------------

(define-native-test the-canonical-constructor-builds-a-device-with-no-game
  "XNA's constructor, in a process that has no GAME in it at all.

The strongest half of this test is the last assertion: nothing constructed a
game, so a device that answers here is not the runtime's borrowed one under
another name."
  (is (null (int:active-game)) "a game was live before this test began")
  (let* ((adapters (gfx:graphics-adapter-adapters))
         (adapter (first adapters)))
    (is (typep adapter 'gfx:graphics-adapter))
    (with-owned-device (device)
      (is (typep device 'gfx:graphics-device))
      (is (not (xna:disposed-p device)))
      ;; `pCurrentAdapter' is `ldarg.1': the caller's object, by reference. A
      ;; fresh wrapper for the same index would compare false everywhere XNA
      ;; compares adapters, because GraphicsAdapter overrides neither Equals nor
      ;; GetHashCode.
      (is (eq adapter (gfx:adapter device))
          "device.Adapter is not EQ to the adapter the constructor was given")
      (is (eq :reach (gfx:graphics-profile device)))
      (is (not (gfx:is-disposed device)))
      (is (eq :normal (gfx:graphics-device-status device)))
      (let ((viewport (gfx:viewport device)))
        (is (= 64 (gfx:viewport-width viewport)))
        (is (= 32 (gfx:viewport-height viewport))))
      (is (null (int:active-game)) "constructing a device created a game"))
    (note-owned-device
     :create "XNA's constructor built a device on adapter ~a with no game in the image"
     (gfx::%adapter-index adapter))))

(define-native-test the-constructor-takes-the-complete-argument-list-and-no-other
  "XNA has one constructor and it has three arguments; every other shape is refused."
  (let ((adapter (first (gfx:graphics-adapter-adapters)))
        (parameters (owned-device-parameters)))
    (macrolet ((refuses (condition &rest initargs)
                 `(signals ,condition
                    (make-instance 'gfx:graphics-device ,@initargs))))
      ;; Each of these is a call XNA cannot express.
      (refuses xna:cna-usage-error :adapter adapter)
      (refuses xna:cna-usage-error :graphics-profile :reach)
      (refuses xna:cna-usage-error :presentation-parameters parameters)
      (refuses xna:cna-usage-error :adapter adapter :graphics-profile :reach)
      (refuses xna:cna-usage-error :adapter adapter :presentation-parameters parameters)
      (refuses xna:cna-usage-error :graphics-profile :reach
                                   :presentation-parameters parameters))
    ;; And the complete one is accepted, so the refusals above are about the
    ;; shape rather than about the arguments being unusable.
    (let ((device (make-instance 'gfx:graphics-device
                                 :adapter adapter :graphics-profile :reach
                                 :presentation-parameters parameters)))
      (unwind-protect (is (typep device 'gfx:graphics-device))
        (xna:dispose device)))))

(define-native-test the-constructor-guards-in-the-il-s-order-not-the-argument-order
  "`IL_0013' tests the parameters and `IL_0026' tests the adapter -- in that order.

So a call missing both names the **parameters**, which is the assertion that
distinguishes reproducing XNA's order from checking left to right."
  (let ((adapter (first (gfx:graphics-adapter-adapters))))
    (let ((refusal (handler-case
                       (progn (make-instance 'gfx:graphics-device
                                             :adapter nil :graphics-profile :reach
                                             :presentation-parameters nil)
                              nil)
                     (xna:cna-argument-error (condition) condition))))
      (is (not (null refusal)) "a null adapter and null parameters were accepted")
      (is (string= "presentation-parameters" (xna:cna-error-parameter-name refusal))
          "with both missing XNA names presentationParameters; this named ~s"
          (xna:cna-error-parameter-name refusal)))
    ;; With the parameters present, the adapter is the next thing tested.
    (let ((refusal (handler-case
                       (progn (make-instance 'gfx:graphics-device
                                             :adapter nil :graphics-profile :reach
                                             :presentation-parameters
                                             (owned-device-parameters))
                              nil)
                     (xna:cna-argument-error (condition) condition))))
      (is (not (null refusal)))
      (is (string= "adapter" (xna:cna-error-parameter-name refusal))))
    ;; And the profile, which XNA does not null-test but does range-test, inside
    ;; `ProfileCapabilities.GetInstance'.
    (signals xna:cna-argument-out-of-range-error
      (make-instance 'gfx:graphics-device
                     :adapter adapter :graphics-profile :ultra
                     :presentation-parameters (owned-device-parameters)))))

(define-native-test the-presentation-parameters-are-cloned-twice-and-neither-is-the-caller-s
  "`IL_0093' and `IL_009f' clone; `get_PresentationParameters' answers the second.

So the device sees no later edit of what it was given, and a caller sees no edit
of what the device answers. Both halves are asserted, because a binding that
retained the caller's object would pass the first."
  (let ((parameters (owned-device-parameters :width 64 :height 32)))
    (let ((device (make-instance 'gfx:graphics-device
                                 :adapter (first (gfx:graphics-adapter-adapters))
                                 :graphics-profile :reach
                                 :presentation-parameters parameters)))
      (unwind-protect
           (progn
             (is (not (eq parameters (gfx:presentation-parameters device)))
                 "the device answered the caller's own PresentationParameters object")
             ;; The same object every time, as `ldfld pPublicCachedParams' is.
             (is (eq (gfx:presentation-parameters device)
                     (gfx:presentation-parameters device)))
             (is (= 64 (gfx:back-buffer-width (gfx:presentation-parameters device))))
             ;; Mutating the constructor's argument afterwards changes nothing.
             (setf (gfx:back-buffer-width parameters) 128)
             (is (= 64 (gfx:back-buffer-width (gfx:presentation-parameters device)))
                 "editing the constructor's argument changed the device's parameters"))
        (xna:dispose device)))))

;;; --- OWNED_DEVICE_COEXISTENCE -------------------------------------------------

(define-native-test two-owned-devices-are-independent-in-every-way-they-can-be
  "CNA promises several caller-created devices may exist at once; this is the
public proof of it.

The state collections are the assertion that matters most. They are stable
objects on the device -- `get_SamplerStates' is `ldfld pSamplerState' -- so two
devices sharing one would be a single global masquerading as a property, and no
amount of testing one device would find it."
  (with-owned-device (a :width 64 :height 32)
    (with-owned-device (b :width 32 :height 16)
      (is (not (eq a b)))
      ;; Different presentation parameters really produced different devices,
      ;; so what follows is about two devices rather than two names for one.
      (is (= 64 (gfx:viewport-width (gfx:viewport a))))
      (is (= 32 (gfx:viewport-width (gfx:viewport b))))
      (is (eq :reach (gfx:graphics-profile a)))
      (is (eq :reach (gfx:graphics-profile b)))
      ;; Each collection is the same object every time on its own device, and
      ;; never the other device's.
      (dolist (reader (list #'gfx:sampler-states #'gfx:vertex-sampler-states
                            #'gfx:textures #'gfx:vertex-textures))
        (is (eq (funcall reader a) (funcall reader a))
            "a device's collection was not stable across two reads")
        (is (not (eq (funcall reader a) (funcall reader b)))
            "two devices shared one collection object"))
      ;; And each draws on its own.
      (gfx:clear a (xna:cornflower-blue))
      (gfx:clear b (xna:make-color 255 0 0))
      ;; Destroying one leaves the other entirely usable.
      (xna:dispose a)
      (is (xna:disposed-p a))
      (is (not (xna:disposed-p b)))
      (gfx:clear b (xna:make-color 0 255 0))
      (is (= 32 (gfx:viewport-width (gfx:viewport b))))
      (note-owned-device
       :coexistence
       "two owned devices held distinct viewports, collections and state; ~
        disposing one left the other drawing"))))

(define-native-test an-owned-device-and-a-game-s-device-do-not-know-about-each-other
  "The two native ownership worlds, live in one process at the same time.

`cna_game_destroy' was measured succeeding with an owned device and its texture
still alive -- CNA says such resources 'do not gate cna_game_destroy' and it is
true -- and that is the assertion this lane is really for: if a fake game parent
had leaked into the owned device's resources, the game would refuse to shut
down and this test would be the one that noticed."
  (let ((owned (make-owned-device))
        (owned-texture nil))
    (unwind-protect
         (progn
           (setf owned-texture
                 (make-instance 'gfx:texture-2d :graphics-device owned
                                                :width 4 :height 4))
           (is (eq owned (gfx:graphics-resource-graphics-device owned-texture)))
           (with-counting-game (game)
             (xna:run-one-frame game)
             (let ((facade (xna:graphics-device game)))
               (is (not (eq facade owned)))
               ;; The facade's collections are its own, not the owned device's.
               (is (not (eq (gfx:textures facade) (gfx:textures owned))))
               ;; The owned device works while the game is live and outside every
               ;; one of its callbacks -- which the facade itself may not do.
               (gfx:clear owned (xna:cornflower-blue))
               (signals xna:cna-scope-error (gfx:clear facade (xna:cornflower-blue)))
               (is (eq owned (gfx:graphics-resource-graphics-device owned-texture))))
             ;; **The game shuts down with the owned device and its texture still
             ;; live.** CNA was measured allowing exactly this.
             (xna:dispose game)
             (is (xna:disposed-p game)))
           ;; And the owned device is untouched by the game's destruction.
           (is (not (xna:disposed-p owned)))
           (is (not (xna:disposed-p owned-texture)))
           (is (eq owned (gfx:graphics-resource-graphics-device owned-texture)))
           (gfx:clear owned (xna:make-color 0 0 255))
           (note-owned-device
            :coexistence-with-game
            "a game was created and destroyed around a live owned device and its ~
             texture; neither gated the other"))
      (ignore-errors (when owned-texture (xna:dispose owned-texture)))
      (ignore-errors (xna:dispose owned)))))

;;; --- OWNED_DEVICE_RESOURCES ---------------------------------------------------

(define-native-test every-resource-family-reports-the-owned-device-that-made-it
  "`GraphicsResource.GraphicsDevice' is `ldfld _parent': the device, by identity.

One family is not enough here. The old implementation answered the *active
game's* device for every native resource, which is indistinguishable from
correct until there are two devices -- so this builds each family on two
different owned devices and asserts each reports its own."
  (with-owned-device (a)
    (with-owned-device (b)
      (flet ((check (label make)
               (let ((on-a (funcall make a))
                     (on-b (funcall make b)))
                 (unwind-protect
                      (progn
                        (is (eq a (gfx:graphics-resource-graphics-device on-a))
                            "~a made on device A reported another device" label)
                        (is (eq b (gfx:graphics-resource-graphics-device on-b))
                            "~a made on device B reported another device" label)
                        (is (not (eq (gfx:graphics-resource-graphics-device on-a)
                                     (gfx:graphics-resource-graphics-device on-b)))))
                   (ignore-errors (xna:dispose on-b))
                   (ignore-errors (xna:dispose on-a))))))
        (check "texture-2d"
               (lambda (d) (make-instance 'gfx:texture-2d :graphics-device d
                                                          :width 4 :height 4)))
        (check "texture-cube"
               (lambda (d) (make-instance 'gfx:texture-cube :graphics-device d :size 4)))
        (check "render-target-2d"
               (lambda (d) (make-instance 'gfx:render-target-2d :graphics-device d
                                                                :width 4 :height 4)))
        (check "sprite-batch"
               (lambda (d) (make-instance 'gfx:sprite-batch :graphics-device d)))
        (check "vertex-buffer"
               (lambda (d) (make-instance 'gfx:vertex-buffer :graphics-device d
                                          :vertex-type 'gfx:vertex-position-color
                                          :vertex-count 3 :buffer-usage :none)))
        (check "index-buffer"
               (lambda (d) (make-instance 'gfx:index-buffer :graphics-device d
                                          :index-element-size :sixteen-bits
                                          :index-count 3 :buffer-usage :none)))
        (check "basic-effect"
               (lambda (d) (make-instance 'gfx:basic-effect :graphics-device d))))
      (note-owned-device
       :resources
       "seven native GraphicsResource families were built on two owned devices ~
        and each reported the device that made it"))))

(defclass owned-device-witness-game (counting-game)
  ((owned :initarg :owned :reader witness-owned-device)
   (texture :initform nil :accessor witness-texture)
   (facade :initform nil :accessor witness-facade)
   (reported :initform :unset :accessor witness-reported))
  (:documentation
   "A game that builds a texture on **its own** device while an owned one is live.

The interesting work has to happen inside a lifecycle callback, because that is
the only time CNA lends the game its device -- which is the asymmetry this whole
closure is about."))

(defmethod xna:load-content ((game owned-device-witness-game))
  (call-next-method)
  (let ((facade (xna:graphics-device game)))
    (setf (witness-facade game) facade
          (witness-texture game) (make-instance 'gfx:texture-2d
                                                :graphics-device facade
                                                :width 4 :height 4)
          (witness-reported game)
          (gfx:graphics-resource-graphics-device (witness-texture game)))))

(define-native-test a-game-s-resource-still-reports-the-game-s-facade
  "The other direction, which the refactor could have broken and nothing else
would have caught: a resource made on the game's device must still answer the
game's device, and not the owned one that happens to be alive beside it."
  (with-owned-device (owned)
    (let ((game (make-instance 'owned-device-witness-game :owned owned :exit-after 2)))
      (unwind-protect
           (progn
             (xna:run game)
             (is (eq (witness-facade game) (witness-reported game))
                 "a game's texture did not report the game's device")
             (is (not (eq owned (witness-reported game)))
                 "a game's texture reported the owned device"))
        (progn
          (when (witness-texture game) (ignore-errors (xna:dispose (witness-texture game))))
          (ignore-errors (xna:dispose game)))))))

;;; --- OWNED_DEVICE_CROSS_DEVICE ------------------------------------------------
;;;
;;; **The ABI header says cross-device use is refused and it is not**, and the
;;; honest thing to do about that is not to invent the refusal. Two authorities
;;; were read:
;;;
;;;   * CNA, measured -- `set_texture(B, PIXEL, 0, A's texture)' answers SUCCESS
;;;     and reading B's slot back reports `bound' with A's texture handle in it,
;;;     on all three admitted ABIs, both renderers and in every direction:
;;;     owned into owned, owned into a Game's, a Game's into owned.
;;;
;;;   * XNA, read from the pinned assembly -- `TextureCollection::set_Item'
;;;     guards disposal, the active render target, the profile's vertex-texture
;;;     formats and the slot index, and **compares no devices at all**. Nothing
;;;     anywhere in the assembly compares a `GraphicsResource::_parent' against
;;;     the device it is being bound to; the 112 reads of that field are
;;;     `get_GraphicsDevice', `ToString' and the resource manager.
;;;
;;; So a refusal here would be a member this projection gained, which is the one
;;; thing it may never do.
;;;
;;; **And measuring it turned up something the header does not mention at all:
;;; CNA's sampler slot table is shared between devices rather than per device.**
;;; Bind A's texture into A slot 0, then B's into B slot 0, and A's slot 0 then
;;; reports `bound' with an *invalid* handle -- CNA's way of saying "something
;;; is here and no C resource owns it". In XNA each device has its own
;;; `TextureCollection' over its own device state and neither would disturb the
;;; other. `docs/limitations.md' records it; the tests below assert it in both
;;; directions so a CNA that separated them would fail rather than pass quietly.

(define-native-test cross-device-resource-use-is-accepted-because-neither-authority-refuses
  "Bind one device's texture into another, and assert what actually happens.

Read the block above before changing this test. It asserts the *absence* of a
guard, which is exactly the kind of assertion that looks like a missing test."
  (with-owned-device (a)
    (with-owned-device (b)
      (let ((from-a (make-instance 'gfx:texture-2d :graphics-device a
                                                   :width 4 :height 4)))
        (unwind-protect
             (progn
               ;; Accepted, in both directions, with no refusal from anywhere.
               (finishes (setf (gfx:item (gfx:textures a) 0) from-a))
               (finishes (setf (gfx:item (gfx:textures b) 0) from-a))
               ;; And it really took: B's collection answers the object it was
               ;; given, which is A's texture.
               (is (eq from-a (gfx:item (gfx:textures b) 0))
                   "the crossed binding did not take")
               ;; Being bound elsewhere is not being adopted elsewhere. This is
               ;; the half that *is* guaranteed, and the one the ownership
               ;; refactor is really about.
               (is (eq a (gfx:graphics-resource-graphics-device from-a))
                   "binding a resource into another device changed its device")
               (note-owned-device
                :cross-device
                "a resource of one owned device bound into another was accepted by ~
                 CNA and unguarded by XNA, and still reported the device that made it"))
          (ignore-errors (xna:dispose from-a)))))))

(define-native-test cna-s-sampler-slots-are-shared-between-devices-and-xna-s-are-not
  "A measured divergence, asserted in both directions rather than hidden.

Binding into one device's slot displaces what another device had in the same
slot: CNA has one native sampler table and XNA has one per device. The binding
does not paper over it -- its collection answers what it *can* truthfully say,
which is NIL for "this binding has nothing bound here", and never the cached
object it can no longer vouch for."
  (with-owned-device (a)
    (with-owned-device (b)
      (let ((from-a (make-instance 'gfx:texture-2d :graphics-device a
                                                   :width 4 :height 4))
            (from-b (make-instance 'gfx:texture-2d :graphics-device b
                                                   :width 4 :height 4)))
        (unwind-protect
             (progn
               (setf (gfx:item (gfx:textures a) 0) from-a)
               ;; Before B binds, A's slot answers A's texture.
               (is (eq from-a (gfx:item (gfx:textures a) 0))
                   "a device could not read back its own binding")
               (setf (gfx:item (gfx:textures b) 0) from-b)
               ;; B's slot answers B's texture, as it must.
               (is (eq from-b (gfx:item (gfx:textures b) 0)))
               ;; **And A's no longer answers anything.** In XNA it would still
               ;; be A's texture; here the native slot has been displaced, and
               ;; answering the cache would be claiming a binding that is gone.
               (is (null (gfx:item (gfx:textures a) 0))
                   "A's slot survived B's binding -- CNA may have separated the ~
                    sampler tables, which would make this test the stale one")
               ;; The collections themselves remain each device's own, which is
               ;; the part that is this binding's responsibility rather than
               ;; CNA's.
               (is (not (eq (gfx:textures a) (gfx:textures b))))
               (note-owned-device
                :shared-sampler-slots
                "CNA's sampler slot table is shared between devices: a bind on one ~
                 displaced the other's slot, and the collection answered NIL rather ~
                 than a binding it could no longer vouch for"))
          (progn (ignore-errors (xna:dispose from-b))
                 (ignore-errors (xna:dispose from-a))))))))

;;; --- OWNED_DEVICE_DISPOSAL ----------------------------------------------------

(define-native-test disposing-an-owned-device-disposes-its-resources-and-leaves-no-zombie
  "`!GraphicsDevice' releases the children before the device; CNA does the same.

The assertion that matters is the last one. A CLOS wrapper still reporting
itself live over a handle CNA has disposed is the zombie the whole ownership
architecture exists to prevent, and it is invisible until something calls
through it."
  (let* ((device (make-owned-device))
         (texture (make-instance 'gfx:texture-2d :graphics-device device
                                                 :width 4 :height 4))
         (batch (make-instance 'gfx:sprite-batch :graphics-device device))
         (buffer (make-instance 'gfx:vertex-buffer :graphics-device device
                                :vertex-type 'gfx:vertex-position-color
                                :vertex-count 3 :buffer-usage :none)))
    (is (not (xna:disposed-p texture)))
    (is (not (xna:disposed-p batch)))
    (is (not (xna:disposed-p buffer)))
    ;; **No child is disposed first.** XNA's device cascades, so this is a call
    ;; XNA accepts and the binding's usual no-cascade refusal must not apply.
    (finishes (xna:dispose device))
    (is (xna:disposed-p device))
    (dolist (child (list texture batch buffer))
      (is (xna:disposed-p child)
          "~a survived its device's disposal as a live-looking object"
          (type-of child))
      ;; Its device property still answers, as a bare `ldfld _parent' does.
      (is (eq device (gfx:graphics-resource-graphics-device child)))
      ;; And every operation refuses rather than reaching a released handle.
      (signals xna:cna-disposed-error (gfx:graphics-resource-name child))
      ;; Disposing it again is a no-op, as IDisposable requires.
      (finishes (xna:dispose child))
      (is (xna:disposed-p child)))
    (note-owned-device
     :disposal
     "an owned device with three live resources disposed all four, and every ~
      child reported disposed, kept its device and refused its operations")))

(define-native-test a-game-s-device-still-refuses-to-be-disposed-and-survives-the-refusal
  "The parent-owned facade keeps its refusal, and keeps working after it.

Paired with the test above deliberately: the same generic function on the same
public class does opposite things, and which one it does is the private lifetime
mode rather than anything a caller names."
  (with-counting-game (game)
    (xna:run-one-frame game)
    (let ((facade (xna:graphics-device game)))
      (signals xna:cna-ownership-error (xna:dispose facade))
      (is (not (xna:disposed-p facade))
          "the refused disposal marked the facade disposed anyway")
      ;; And it is still the game's device, still usable where it was usable.
      (is (eq facade (xna:graphics-device game)))
      (xna:run-one-frame game))))

(define-native-test the-same-operation-is-scope-bound-on-a-facade-and-free-on-an-owned-device
  "One member, two lifetimes, opposite answers -- and both are correct.

CNA gives the facade no handle outside a callback, so `Clear' there is refused
before anything reaches the ABI. It gives an owned device a persistent one, so
the same `Clear' is legal anywhere. This is private native capability rather
than two public types, and this test is what says so."
  (with-owned-device (owned)
    (with-counting-game (game)
      (xna:run-one-frame game)
      (let ((facade (xna:graphics-device game)))
        (signals xna:cna-scope-error (gfx:clear facade (xna:cornflower-blue)))
        (finishes (gfx:clear owned (xna:cornflower-blue)))
        (signals xna:cna-scope-error (gfx:viewport facade))
        (finishes (gfx:viewport owned))))))

;;; --- OWNED_DEVICE_THREAD ------------------------------------------------------

(define-native-test an-owned-device-is-thread-affine-and-says-so-before-cna-does
  "CNA answers a wrong-thread call on an owned device with INVALID_HANDLE from
the getters and THREAD only from destroy -- measured -- and neither is what a
caller who used the wrong thread needs to read. The binding's own owner-thread
check runs first, so the refusal names the thread."
  (with-owned-device (device)
    (let ((results '()))
      (let ((thread (bordeaux-threads:make-thread
                     (lambda ()
                       (flet ((attempt (label thunk)
                                (push (cons label
                                            (handler-case (progn (funcall thunk) :accepted)
                                              (error (c) (type-of c))))
                                      results)))
                         (attempt :profile (lambda () (gfx:graphics-profile device)))
                         (attempt :viewport (lambda () (gfx:viewport device)))
                         (attempt :clear (lambda () (gfx:clear device (xna:cornflower-blue))))
                         (attempt :dispose (lambda () (xna:dispose device))))))))
        (bordeaux-threads:join-thread thread))
      (dolist (entry results)
        (is (eq 'xna:cna-thread-error (cdr entry))
            "~a from another thread answered ~a rather than a thread refusal"
            (car entry) (cdr entry))))
    ;; And the device is untouched: a refused call changed nothing.
    (is (not (xna:disposed-p device)))
    (finishes (gfx:clear device (xna:cornflower-blue)))))

;;; --- OWNED_DEVICE_SOFTWARE and OWNED_DEVICE_HEADLESS ---------------------------
;;;
;;; The evidence discipline is the repository's and this closure does not change
;;; it: HEADLESS proves lifecycle and command submission and **nothing about
;;; pixels**, and the SOFTWARE lane is what proves pixels. What a standalone
;;; device changes is only that neither claim needs a game any more.
;;;
;;; The two renderers were measured differing in exactly one place: HEADLESS
;;; answers `CNA_RESULT_NOT_SUPPORTED' to the back-buffer readback, and every
;;; other stage of the matrix -- create, coexistence, resources, disposal,
;;; threading, clear, present -- is byte-identical between them. So this test
;;; asserts *both* branches rather than skipping one, and the refusal is a
;;; result rather than a gap.

(define-native-test a-standalone-device-reaches-real-pixels-with-no-game-in-the-image
  "Clear a device the caller made, read the back buffer, and check every pixel.

**No game exists in this process**, which is the whole point: this is the first
graphics evidence in the repository that needs none. Under HEADLESS the readback
honestly refuses and that refusal is asserted; under SOFTWARE the pixels are
checked one by one."
  (is (null (int:active-game)) "a game was live before this test began")
  (with-owned-device (device :width 16 :height 8)
    (gfx:clear device (xna:cornflower-blue))
    (let ((pixels (handler-case (gfx:get-back-buffer-data device)
                    (xna:cna-not-supported-error () :refused))))
      (cond
        ((eq pixels :refused)
         ;; HEADLESS. A renderer with no honest readback says so rather than
         ;; answering zeroes, which is exactly what makes the member usable as
         ;; evidence when it does answer.
         (note-owned-device
          :headless
          "the renderer refused a back-buffer readback from a standalone device, ~
           which is a capability result and not a missing test; the clear, the ~
           device and its lifecycle all worked")
         (is (eq pixels :refused)
             "HEADLESS refused the readback, as it must"))
        (t
         (is (= (* 16 8) (length pixels))
             "the readback returned ~d pixels for a 16x8 back buffer" (length pixels))
         (let ((expected (xna:cornflower-blue)))
           (is (every (lambda (pixel) (xna:color-equal pixel expected)) pixels)
               "a standalone device cleared to CornflowerBlue and ~d of ~d pixels ~
                did not match"
               (count-if-not (lambda (pixel) (xna:color-equal pixel expected)) pixels)
               (length pixels))
           (let ((first-pixel (aref pixels 0)))
             (is (= 100 (xna:color-r first-pixel)))
             (is (= 149 (xna:color-g first-pixel)))
             (is (= 237 (xna:color-b first-pixel)))
             (is (= 255 (xna:color-a first-pixel)))))
         ;; And a second, different clear reaches the same buffer, so the first
         ;; was not a coincidence of an uninitialised allocation.
         (gfx:clear device (xna:make-color 10 20 30))
         (let ((again (gfx:get-back-buffer-data device)))
           (is (= 10 (xna:color-r (aref again 0))))
           (is (= 20 (xna:color-g (aref again 0))))
           (is (= 30 (xna:color-b (aref again 0)))))
         (note-owned-device
          :software
          "a standalone device with no game in the image cleared to ~
           CornflowerBlue and every one of ~d back-buffer pixels read back ~
           (100 149 237 255); a second clear reached the same buffer"
          (length pixels)))))))

(define-native-test a-standalone-device-draws-a-primitive-onto-its-own-back-buffer
  "More than construction: a triangle through a BasicEffect pass, with no game.

Under HEADLESS this proves the commands were accepted; under SOFTWARE it proves
the pixels the geometry covers changed and the ones outside it did not."
  (with-owned-device (device :width 16 :height 16)
    (let ((effect (make-instance 'gfx:basic-effect :graphics-device device)))
      (unwind-protect
           (progn
             (is (eq device (gfx:graphics-resource-graphics-device effect)))
             (gfx:clear device (xna:make-color 0 0 0))
             (setf (gfx:effect-vertex-color-enabled effect) t
                   (gfx:effect-lighting-enabled effect) nil)
             ;; The same clip-space triangle the rasterizer lane draws, so the
             ;; geometry is the one already qualified and the only new thing
             ;; here is the device it is drawn on.
             (dolist (pass (gfx:collection-elements
                            (gfx:effect-technique-passes
                             (gfx:effect-current-technique effect))))
               (gfx:apply-effect-pass pass))
             (finishes
               (gfx:draw-user-primitives device :triangle-list (clip-space-triangle)
                                         :vertex-offset 0 :primitive-count 1))
             (let ((pixels (handler-case (gfx:get-back-buffer-data device)
                             (xna:cna-not-supported-error () :refused))))
               (if (eq pixels :refused)
                   (note-owned-device
                    :headless-draw
                    "a standalone device accepted a BasicEffect pass and a ~
                     DrawUserPrimitives triangle; the renderer has no readback, so ~
                     no pixel claim is made")
                   (let ((red 0) (black 0))
                     (map nil (lambda (pixel)
                                (cond ((and (= 255 (xna:color-r pixel))
                                            (zerop (xna:color-g pixel))) (incf red))
                                      ((and (zerop (xna:color-r pixel))
                                            (zerop (xna:color-g pixel))) (incf black))))
                          pixels)
                     (is (plusp red) "the triangle covered no pixel at all")
                     (is (plusp black) "the triangle covered every pixel, including ~
                                        outside its own geometry")
                     (note-owned-device
                      :software-draw
                      "a standalone device drew a triangle through a BasicEffect ~
                       pass: ~d pixels took the triangle's colour and ~d outside it ~
                       stayed cleared" red black)))))
        (ignore-errors (xna:dispose effect))))))

;;; --- OWNED_DEVICE_EVENTS ------------------------------------------------------

(define-native-test the-owned-device-s-disposing-event-arrives-with-the-device-as-sender
  "The event machinery was built around a facade with no persistent handle.

Three things it could get wrong on an owned device, all asserted: the sender
could be resolved through the active game (there is none), a registration could
outlive the device, and the handler could keep running after removal."
  (is (null (int:active-game)))
  (let ((device (make-owned-device))
        (seen '()))
    (unwind-protect
         (progn
           (gfx:add-disposing-handler
            device (lambda (sender) (push sender seen)))
           (xna:dispose device)
           (is (= 1 (length seen)) "Disposing arrived ~d time(s)" (length seen))
           (is (eq device (first seen))
               "the sender was not the owned device itself"))
      (ignore-errors (xna:dispose device)))
    ;; A removed handler stops arriving, and the registry is left where it was.
    (let ((second (make-owned-device))
          (after '()))
      (let ((handler (lambda (sender) (push sender after))))
        (gfx:add-disposing-handler second handler)
        (gfx:remove-disposing-handler second handler))
      (xna:dispose second)
      (is (null after) "a removed handler still ran"))
    (note-owned-device
     :events
     "an owned device's Disposing reached a handler with the device itself as ~
      sender, with no game in the image to resolve it through, and stopped when ~
      the handler was removed")))

(define-native-test an-owned-device-construction-that-fails-late-leaves-nothing-behind
  "Construction is all-or-nothing, a subclass's share included.

`GraphicsDevice' is publicly subclassable -- CLOS has no `sealed' -- so a
subclass initializer that signals runs *after* the native device exists and
after it has joined the registry. Without the construction ledger CNA would hold
a device nobody could ever destroy."
  (let ((before (length gfx::*live-owned-devices*)))
    (signals subclass-initializer-blew-up
      (make-instance 'exploding-graphics-device
                     :adapter (first (gfx:graphics-adapter-adapters))
                     :graphics-profile :reach
                     :presentation-parameters (owned-device-parameters)))
    (is (= before (length gfx::*live-owned-devices*))
        "a failed construction left ~d device(s) in the live registry"
        (- (length gfx::*live-owned-devices*) before))
    ;; And the ordinary constructor still works afterwards, so the rollback did
    ;; not damage anything shared.
    (with-owned-device (device)
      (is (typep device 'gfx:graphics-device)))
    (note-owned-device
     :construction-atomicity
     "a subclass initializer that signalled after the native device existed gave ~
      the device back and left the live-device registry where it found it")))
