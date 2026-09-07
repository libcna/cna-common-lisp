;;;; game-service-sync.lisp --- CNA's two canonical service slots, as a
;;;; cross-check.
;;;;
;;;; **The managed `GameServiceContainer' is the authority and this file does not
;;;; change that.** `GET-SERVICE' reads the Lisp dictionary and never asks CNA;
;;;; what is here is the other direction -- the two identities CNA *can* name are
;;;; checked against the container, and a removal of one of them is mirrored into
;;;; the native slot so the two do not silently drift.
;;;;
;;;; Three measured facts shape everything below, and none of them is a guess.
;;;;
;;;; **1. CNA registers both services inside `cna_graphics_device_manager_create'.**
;;;; `runtime_graphics_manager.h': "Creating the manager registers it as the
;;;; game's graphics device manager and graphics device service, which is what
;;;; `cna_game_services_contains_ext' then reports." So by the time the Lisp
;;;; constructor has a handle, the native side already holds both -- which is why
;;;; the cross-check is an assertion about agreement rather than a second
;;;; registration.
;;;;
;;;; **2. There is deliberately no native registration route, and re-adding one
;;;; through the public container is still legal.** `runtime_components.h' calls
;;;; the absence "a decision, not a gap", for the same reason the container
;;;; cannot be projected onto two slots: a C caller "cannot name a C++ type to
;;;; key the entry by, and cannot author an object implementing the C++
;;;; interface". So `ADD-SERVICE' under a canonical key after a removal succeeds
;;;; in the managed container and mirrors nothing. That is not this binding
;;;; choosing the managed side over the native one; it is the only side that can
;;;; hold the entry.
;;;;
;;;; **3. Nothing selected reads CNA's service table after initialisation**, so
;;;; (2) costs no observable behaviour, and this was checked in both runtimes
;;;; rather than assumed:
;;;;
;;;;   * CNA's own C++ caches it. `cna_graphics_device_manager_destroy''s
;;;;     documentation: "the canonical game caches a raw pointer to the graphics
;;;;     device service the first time it resolves one and never clears it", and
;;;;     `cna_game_services_remove_ext''s: "the game keeps working off the
;;;;     pointers it resolved while initializing, so what a removal changes is
;;;;     what a **later** lookup finds."
;;;;   * XNA's managed side caches it in exactly the same shape.
;;;;     `Game.get_GraphicsDevice' reads its `graphicsDeviceService' field and
;;;;     only resolves through `Services' when that field is null, then keeps the
;;;;     result.
;;;;
;;;;   So a removal changes later *lookups* in both, and neither re-resolves for
;;;;   an operation this binding projects. `GRAPHICS-DEVICE' keeps working, which
;;;;   is what XNA does too. Nothing here is classified partial for it.

(in-package #:microsoft.xna.framework)

(defparameter *canonical-service-types*
  (list (cons 'igraphics-device-manager
              cna-lisp.internal.ffi::+game-service-type-graphics-device-manager+)
        (cons 'igraphics-device-service
              cna-lisp.internal.ffi::+game-service-type-graphics-device-service+))
  "The two service identities CNA's C ABI can name, and their `CNA_GameServiceType'.

`CNA_GAME_SERVICE_TYPE_MAXIMUM' is the second of them, so this list is CNA's
whole service vocabulary. It is **not** the container's: every other key a
program uses lives only in the managed dictionary, which is the point of the
projection.")

(defun %canonical-service-value (type)
  "TYPE's `CNA_GameServiceType', or NIL when CNA cannot name it."
  (cdr (assoc type *canonical-service-types* :test #'eq)))

(defun %native-service-present-p (game type-value operation)
  "Ask `cna_game_services_contains_ext' whether TYPE-VALUE is registered."
  (cffi:with-foreign-object (out :uint8)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-services-contains-ext
      (cna-lisp.internal:handle-of game) type-value out)
     operation :object-type 'game-service-container)
    (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8))))

(defun native-service-present-p (game service-type)
  "Whether CNA reports SERVICE-TYPE registered with GAME's native game.

A CNA-Lisp addition and a **cross-check**, not the way to read a service: it can
answer for exactly the two identities CNA can name, and `GET-SERVICE' is what
answers for the container. Refuses a service type CNA has no identity for, rather
than answering false and letting a caller read that as \"not registered\"."
  (let* ((type (%service-type-designator service-type "native-service-present-p" "type"))
         (value (%canonical-service-value type)))
    (unless value
      (error 'cna-usage-error
             :operation "native-service-present-p" :object-type 'game-service-container
             :format-control
             "CNA has no service identity for ~s. Its `CNA_GameServiceType' has exactly ~
              two values -- the graphics device manager and the graphics device service ~
              -- so this cross-check can only answer for those. Every other service key ~
              lives in the managed container, which GET-SERVICE reads."
             :format-arguments (list type)))
    (cna-lisp.internal:check-usable game "native-service-present-p")
    (%native-service-present-p game value "native-service-present-p")))

(defun %cross-check-canonical-services (game manager operation)
  "Assert that the managed container and CNA's two slots agree, or refuse.

Called once, when a manager has just been created. **A disagreement is signalled
rather than resolved**: the two sides are supposed to describe one fact, and
picking a winner would turn a broken invariant into a silently wrong answer."
  (let ((container (services game)))
    (loop for (type . value) in *canonical-service-types*
          for managed = (get-service container type)
          for native = (%native-service-present-p game value operation)
          do (unless (and (eq managed manager) native)
               (error 'cna-invalid-state-error
                      :operation operation :object-type 'graphics-device-manager
                      :format-control
                      "the managed service container and CNA disagree about ~s: the ~
                       container answers ~s and CNA reports the native registration ~
                       ~:[absent~;present~]. Creating a manager registers both on both ~
                       sides, so this is an internal inconsistency rather than something ~
                       a program can cause."
                      :format-arguments (list type managed native))))
    t))

(defmethod %remove-service-entry ((container game-service-container) type)
  "Remove TYPE, mirroring CNA's slot when TYPE is one of the two it can name.

**The native removal goes first**, and the order is the whole of the design
rather than a preference. `cna_game_services_remove_ext' can fail -- an invalid
handle, or a call from a thread that is not the game's -- and a managed removal
already committed would leave the container saying the service is gone while CNA
still holds it, with nothing left to signal about. Removing natively first means
a failure propagates with **both** sides still holding the entry, which is a
state the program can retry from.

The reverse order has no such recovery, and a rollback would need a registration
route that CNA deliberately does not have.

A removal of a key CNA cannot name, or on a container with no game, is purely
managed -- there is nothing to mirror. So is a removal of an entry that is not
there, which XNA calls an ordinary success and which therefore must not reach the
native route at all."
  (let ((game (%service-container-game container))
        (value (%canonical-service-value type)))
    (when (and game value (nth-value 1 (gethash type (%service-table container)))
               (not (cna-lisp.internal:disposed-state-of game))
               (not (zerop (cna-lisp.internal:handle-of game))))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-services-remove-ext
        (cna-lisp.internal:handle-of game) value)
       "remove-service" :object-type 'game-service-container))
    (remhash type (%service-table container))
    (values)))
