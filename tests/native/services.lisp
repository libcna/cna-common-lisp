;;;; services.lisp --- Game.Services, the two canonical registrations, and the
;;;; canonical ContentManager constructors.
;;;;
;;;; **What these lanes are for is proving the container is XNA's and not CNA's.**
;;;; CNA's C ABI can name exactly two services, and the easy wrong implementation
;;;; is a two-slot object wearing `GameServiceContainer''s name. The arbitrary
;;;; user-service tests are what tell the two apart: they use keys CNA has no
;;;; identity for, and they must work with no native route involved at all.
;;;;
;;;; The rest is XNA's exact guard order, read from the pinned
;;;; `Microsoft.Xna.Framework.Game.dll' and asserted rather than described.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defvar *services-evidence* '()
  "What the services and device-selection lanes actually proved, level by level.

**Six levels and they are six claims**, for the reason the audio, microphone,
media and storage lanes each keep theirs apart: a container that holds arbitrary
services says nothing about whether the manager registered under both canonical
keys; a manager that registered says nothing about whether the mutable
device-settings event changes the device; and a protected raiser that runs says
nothing about whether *not* calling it suppresses anything. Reading one of these
out of another is exactly what a single `device-settings works' line would do.")

(defun note-services (level description &rest arguments)
  "Record LEVEL once."
  (unless (assoc level *services-evidence*)
    (push (cons level (apply #'format nil description arguments)) *services-evidence*)))

(defun services-proved-p (level)
  (assoc level *services-evidence*))

;;; --- fixtures ---------------------------------------------------------------

(defclass service-alpha () ()
  (:documentation "A user service type CNA has no identity for."))
(defclass service-beta () ()
  (:documentation "A second one, to prove one removal does not disturb another."))
(defclass service-alpha-subclass (service-alpha) ()
  (:documentation "For the assignability guard: a subclass is assignable."))

(defclass service-stand-in () ()
  (:documentation
   "A program's own graphics-device-service provider.

Declared an implementor of the protocol below, because that is what a program
would have to do to put its own object under a canonical key: `AddService'
applies XNA's assignability guard, so an undeclared object is refused there
exactly as an unrelated class is refused by `IsAssignableFrom'."))

(xna:declare-service-protocol-implementor 'xna:igraphics-device-service
                                          'service-stand-in)

(defmethod xna:graphics-device ((provider service-stand-in))
  "The protocol's one property. Answers nothing, which is a legal answer: XNA's
own content path treats a service whose GraphicsDevice is null as a distinct
failure from a service that is absent."
  nil)

(defclass managed-game (xna:game)
  ((manager :initform nil :accessor game-manager))
  (:documentation "A game that makes its manager the way XNA's constructor does."))

(defmethod initialize-instance :after ((game managed-game) &key)
  (setf (game-manager game) (make-instance 'xna:graphics-device-manager :game game)))

(defmacro with-managed-game ((variable) &body body)
  "A game with a manager, disposed in CNA's required order."
  `(let ((,variable (make-instance 'managed-game)))
     (unwind-protect (progn ,@body)
       (progn (ignore-errors (xna:dispose (game-manager ,variable)))
              (ignore-errors (xna:dispose ,variable))))))

;;; --- SERVICES_MANAGED: an arbitrary type-keyed container ---------------------

(define-native-test the-service-container-is-the-same-object-every-read
  "Game.Services is a field read, not a lazily built facade.

`get_Services' is `ldarg.0; ldfld gameServices; ret' and the field is filled in
the constructor's *prologue*, before `Object..ctor()' -- which is why a
`GraphicsDeviceManager' can register into it from its own constructor."
  (with-counting-game (game)
    (let ((container (xna:services game)))
      (is (typep container 'xna:game-service-container))
      (is (eq container (xna:services game)))
      (is (eq container (xna:services game))))))

(define-native-test an-arbitrary-user-service-round-trips-with-no-native-route
  "SERVICES_MANAGED: two user-defined service types CNA cannot name.

**This is the test that says the container is not CNA's two slots.**
`SERVICE-ALPHA' and `SERVICE-BETA' have no `CNA_GameServiceType', no route and no
native representation of any kind; if the container were a projection of CNA's
two-slot table, none of this could work."
  (with-counting-game (game)
    (let ((container (xna:services game))
          (alpha (make-instance 'service-alpha))
          (beta (make-instance 'service-beta)))
      (is (null (xna:service-types container)) "a fresh game registers nothing")
      (xna:add-service container 'service-alpha alpha)
      (xna:add-service container 'service-beta beta)
      (is (eq alpha (xna:get-service container 'service-alpha)))
      (is (eq beta (xna:get-service container 'service-beta)))
      (is (equal '(service-alpha service-beta)
                 (sort (xna:service-types container) #'string< :key #'symbol-name)))
      ;; One removal, and the other entry is untouched.
      (xna:remove-service container 'service-alpha)
      (is (null (xna:get-service container 'service-alpha))
          "XNA's GetService returns ldnull for an absent key rather than throwing")
      (is (eq beta (xna:get-service container 'service-beta)))
      ;; Re-adding after a removal is legal and installs the *new* provider.
      (let ((replacement (make-instance 'service-alpha)))
        (xna:add-service container 'service-alpha replacement)
        (is (eq replacement (xna:get-service container 'service-alpha)))
        (is (not (eq alpha (xna:get-service container 'service-alpha)))
            "the re-added provider is the one just added, not the one removed"))
      (note-services :managed
                     "two user-defined service types CNA has no identity for were ~
                      added, read back by identity, removed one at a time and ~
                      re-added with a different provider -- with no native route ~
                      involved, which is what says the container is XNA's arbitrary ~
                      dictionary and not a projection of CNA's two slots"))))

(define-native-test a-clos-class-object-keys-the-same-entry-as-its-name
  "The designator is normalised: a class and its name are one key.

Both are admitted spellings and both must reach one entry, or a program could
register twice under what XNA would call one `System.Type'."
  (with-counting-game (game)
    (let ((container (xna:services game))
          (alpha (make-instance 'service-alpha)))
      (xna:add-service container (find-class 'service-alpha) alpha)
      (is (eq alpha (xna:get-service container 'service-alpha))
          "added by class object, read by symbol")
      (signals xna:cna-argument-error
        (xna:add-service container 'service-alpha (make-instance 'service-alpha))
        "the class object and the symbol are the same key, so this is a duplicate")
      (xna:remove-service container (find-class 'service-alpha))
      (is (null (xna:get-service container 'service-alpha))))))

(define-native-test the-service-container-reproduces-xnas-guards-in-xnas-order
  "AddService's four guards, RemoveService's one and GetService's one.

The IL's order, and the order matters: a null provider is reported before a
duplicate type, and a duplicate type before an unassignable provider. A binding
that checked assignability first would refuse a different call than XNA does."
  (with-counting-game (game)
    (let ((container (xna:services game))
          (alpha (make-instance 'service-alpha)))
      ;; 1. null type, in all three members.
      (signals xna:cna-argument-error (xna:add-service container nil alpha))
      (signals xna:cna-argument-error (xna:get-service container nil))
      (signals xna:cna-argument-error (xna:remove-service container nil))
      ;; 2. null provider.
      (signals xna:cna-argument-error (xna:add-service container 'service-alpha nil))
      ;; 3. duplicate.
      (xna:add-service container 'service-alpha alpha)
      (signals xna:cna-argument-error
        (xna:add-service container 'service-alpha (make-instance 'service-alpha)))
      (is (eq alpha (xna:get-service container 'service-alpha))
          "the refused duplicate left the original entry alone")
      ;; 4. assignability -- XNA really checks it, and so does this.
      (signals xna:cna-argument-error
        (xna:add-service container 'service-beta alpha)
        "a SERVICE-ALPHA is not assignable to SERVICE-BETA")
      ;; A subclass *is* assignable, which is what IsAssignableFrom means.
      (xna:add-service container 'service-beta (make-instance 'service-beta))
      (xna:remove-service container 'service-alpha)
      (xna:add-service container 'service-alpha (make-instance 'service-alpha-subclass))
      (is (typep (xna:get-service container 'service-alpha) 'service-alpha-subclass))
      ;; A designator naming neither a class nor a protocol is refused, because
      ;; the assignability guard could not be applied to it.
      (signals xna:cna-argument-error
        (xna:add-service container 'no-such-type-anywhere alpha))
      ;; Removing what is not there is an ordinary success: the IL pops the
      ;; boolean Dictionary.Remove answers.
      (finishes (xna:remove-service container 'service-beta))
      (finishes (xna:remove-service container 'service-beta)))))

(define-native-test the-service-container-is-not-a-native-object
  "It has no handle, no native destruction and no child registration.

Its lifetime is the game's managed object graph, which is what XNA's is. A
retained container is still an ordinary Lisp object after the game is gone, and
the custom services in it are still there -- XNA's `Game.Dispose' never clears
the dictionary."
  (let ((container nil) (alpha (make-instance 'service-alpha)))
    (with-counting-game (game)
      (setf container (xna:services game))
      (xna:add-service container 'service-alpha alpha)
      (is (not (typep container 'int:native-object))))
    ;; The game is disposed. The container is not, because there is nothing to
    ;; dispose, and its purely managed entries survive.
    (is (eq alpha (xna:get-service container 'service-alpha))
        "XNA's Game disposal does not empty the service dictionary, and neither
         does this")
    (finishes (xna:add-service container 'service-beta (make-instance 'service-beta)))))

;;; --- SERVICES_CANONICAL: the two interface identities ------------------------

(define-native-test the-manager-registers-under-both-canonical-interfaces
  "SERVICES_CANONICAL: one manager, two keys, and CNA agrees.

XNA's constructor calls `AddService(typeof(IGraphicsDeviceManager), this)' and
then `AddService(typeof(IGraphicsDeviceService), this)'. **The same object under
both**, and no second wrapper: the manager implements both interfaces itself."
  (with-managed-game (game)
    (let ((container (xna:services game))
          (manager (game-manager game)))
      (is (eq manager (xna:get-service container 'xna:igraphics-device-manager)))
      (is (eq manager (xna:get-service container 'xna:igraphics-device-service)))
      (is (eq (xna:get-service container 'xna:igraphics-device-manager)
              (xna:get-service container 'xna:igraphics-device-service))
          "both keys answer one object, not two equal ones")
      ;; The native cross-check: CNA registered both inside its create route.
      (is-true (xna:native-service-present-p game 'xna:igraphics-device-manager))
      (is-true (xna:native-service-present-p game 'xna:igraphics-device-service))
      ;; And CNA can answer for nothing else, which is the point of the whole
      ;; design: the cross-check refuses rather than answering false.
      (signals xna:cna-usage-error
        (xna:native-service-present-p game 'service-alpha))
      (note-services :canonical
                     "a GraphicsDeviceManager registered itself under both ~
                      IGraphicsDeviceManager and IGraphicsDeviceService, both keys ~
                      answered the same object, and CNA's own ~
                      cna_game_services_contains_ext agreed about both"))))

(define-native-test the-manager-is-a-declared-implementor-of-both-protocols
  "The two protocols are real Common Lisp types, and the manager satisfies both.

That is what makes `AddService''s assignability guard one `TYPEP' for a protocol
and for a class alike, rather than a branch that could drift."
  (with-managed-game (game)
    (let ((manager (game-manager game)))
      (is-true (typep manager 'xna:igraphics-device-manager))
      (is-true (typep manager 'xna:igraphics-device-service))
      (is (member 'xna:graphics-device-manager
                  (xna:service-protocol-implementors 'xna:igraphics-device-manager)))
      (is-false (typep (make-instance 'service-alpha) 'xna:igraphics-device-service))
      ;; So a non-manager cannot be registered under a canonical key.
      (signals xna:cna-argument-error
        (xna:add-service (xna:services game) 'xna:igraphics-device-manager
                         (make-instance 'service-alpha))))))

(define-native-test a-second-manager-is-refused-by-xnas-own-service-lookup
  "XNA's duplicate check is `Services.GetService(typeof(IGraphicsDeviceManager))'.

It tests that one key only -- not both -- and throws `ArgumentException'."
  (with-managed-game (game)
    (signals xna:cna-invalid-state-error
      (make-instance 'xna:graphics-device-manager :game game))
    (is (eq (game-manager game)
            (xna:get-service (xna:services game) 'xna:igraphics-device-manager))
        "the refusal left the first manager's registration standing")))

(define-native-test the-canonical-services-can-be-removed-and-cna-follows
  "A manual removal of a canonical key mirrors into CNA's slot.

The managed container is the public authority, and for the two identities CNA
*can* name the removal is mirrored so the two do not drift. Native first: if
`cna_game_services_remove_ext' failed, both sides would still hold the entry and
the program could retry."
  (with-managed-game (game)
    (let ((container (xna:services game)))
      (xna:remove-service container 'xna:igraphics-device-service)
      (is (null (xna:get-service container 'xna:igraphics-device-service)))
      (is-false (xna:native-service-present-p game 'xna:igraphics-device-service)
                "the managed removal reached CNA's slot")
      (is (eq (game-manager game)
              (xna:get-service container 'xna:igraphics-device-manager))
          "the other canonical key is untouched")
      (is-true (xna:native-service-present-p game 'xna:igraphics-device-manager)))))

(define-native-test a-removed-canonical-service-can-be-re-added-managed-only
  "**CNA has no registration route, and the public container still accepts one.**

`runtime_components.h' calls the absence of an add route \"a decision, not a
gap\", because a C caller cannot name a C++ type or author an object implementing
a C++ interface. So a re-add lives in the managed container alone -- and that
costs no observable behaviour, because *nothing selected re-resolves the native
service after initialisation*:

  * CNA caches it -- `cna_graphics_device_manager_destroy' says the game \"caches
    a raw pointer to the graphics device service the first time it resolves one
    and never clears it\", and `cna_game_services_remove_ext' says a removal
    changes \"what a **later** lookup finds\";
  * XNA caches it the same way -- `Game.get_GraphicsDevice' reads its
    `graphicsDeviceService' field and only resolves through `Services' when that
    field is null.

The assertion that this costs nothing is the last one: the game's graphics device
still answers with both native slots empty."
  (with-managed-game (game)
    (let ((container (xna:services game))
          (replacement (make-instance 'service-stand-in)))
      (xna:remove-service container 'xna:igraphics-device-service)
      (is-false (xna:native-service-present-p game 'xna:igraphics-device-service))
      ;; The public container takes a replacement CNA could never register.
      (xna:add-service container 'xna:igraphics-device-service replacement)
      (is (eq replacement (xna:get-service container 'xna:igraphics-device-service)))
      (is-false (xna:native-service-present-p game 'xna:igraphics-device-service)
                "the re-add is managed only: CNA has no registration route, by
                 decision rather than by omission")
      ;; And nothing selected got worse for it.
      (is-true (xna:graphics-device game)
               "Game.GraphicsDevice works off the pointer resolved at
                initialisation, in CNA and in XNA alike"))))

(define-native-test manager-disposal-removes-only-the-service-key-and-only-its-own
  "`Dispose(bool)' read from the IL, and both of its surprises asserted.

    if (game.Services.GetService(typeof(IGraphicsDeviceService)) == this)
        game.Services.RemoveService(typeof(IGraphicsDeviceService));

**It never removes `IGraphicsDeviceManager'** -- that token appears nowhere in
`Dispose' -- so a disposed manager is still registered under that key. And it
removes the service key **only when the entry is still this manager**, so a
program that put its own provider there keeps it.

CNA's destroy unregisters both native slots regardless, so the managed container
and CNA's two slots deliberately disagree afterwards. The container is the public
authority; the cross-check is made at construction, where both sides do agree."
  (let ((game (make-instance 'managed-game)))
    (unwind-protect
         (let ((container (xna:services game))
               (manager (game-manager game)))
           (xna:dispose manager)
           (is (eq manager (xna:get-service container 'xna:igraphics-device-manager))
               "XNA's Dispose does not remove the manager key")
           (is (null (xna:get-service container 'xna:igraphics-device-service))
               "XNA's Dispose does remove the service key")
           (is-false (xna:native-service-present-p game 'xna:igraphics-device-manager)
                     "CNA's destroy unregisters both, which is where the two sides
                      part company")
           (is-false (xna:native-service-present-p game 'xna:igraphics-device-service)))
      (ignore-errors (xna:dispose game)))))

(define-native-test manager-disposal-does-not-delete-a-users-replacement-service
  "The adversarial sequence, and a careless disposal fails it.

    manager registers itself
    user removes IGraphicsDeviceService
    user adds a replacement provider under that key
    manager.Dispose()

XNA's `bne.un.s' skips the removal because the entry is no longer `this', so the
replacement survives. A disposal that removed the key unconditionally would
silently delete the program's own service."
  (let ((game (make-instance 'managed-game)))
    (unwind-protect
         (let ((container (xna:services game))
               (manager (game-manager game))
               (replacement (make-instance 'service-stand-in)))
           (xna:remove-service container 'xna:igraphics-device-service)
           (xna:add-service container 'xna:igraphics-device-service replacement)
           (xna:dispose manager)
           (is (eq replacement
                   (xna:get-service container 'xna:igraphics-device-service))
               "the user's replacement outlived the manager's disposal"))
      (ignore-errors (xna:dispose game)))))

;;; --- SERVICES_CONTENT: the canonical ContentManager constructors -------------

(define-native-test the-games-content-manager-answers-the-games-services
  "Game.Content's provider is Game.Services, by identity.

The pinned `Game' constructor loads `this.gameServices' and passes it to
`ContentManager..ctor(IServiceProvider)'. So there is exactly one container, and
repeated reads of both members are stable."
  (with-managed-game (game)
    (let ((content (xna:content game))
          (container (xna:services game)))
      (is (eq container (xna.content:service-provider content)))
      (is (eq content (xna:content game)) "Game.Content is a field, not a factory")
      (is (eq container (xna:services game))))))

(defclass content-service-game (managed-game)
  ((findings :initform '() :accessor findings))
  (:documentation
   "A game that exercises the canonical ContentManager constructors in
LOAD-CONTENT, because a content manager needs the graphics-device handle CNA
lends only for the duration of a callback."))

(defmethod xna:load-content ((game content-service-game))
  (let* ((container (xna:services game))
         (one (make-instance 'xna.content:content-manager :service-provider container))
         (two (make-instance 'xna.content:content-manager
                             :service-provider container :root-directory "Content"))
         (extension (make-instance 'xna.content:content-manager
                                   :graphics-device (xna:graphics-device game))))
    (unwind-protect
         (setf (findings game)
               (list :one-provider-eq (eq container (xna.content:service-provider one))
                     :one-root (xna.content:root-directory one)
                     :two-provider-eq (eq container (xna.content:service-provider two))
                     :two-root (xna.content:root-directory two)
                     :extension-provider (xna.content:service-provider extension)
                     :extension-root (xna.content:root-directory extension)
                     :no-service-refused
                     (handler-case
                         (progn (make-instance 'xna.content:content-manager
                                               :service-provider
                                               (make-instance 'xna:game-service-container))
                                nil)
                       (xna:cna-invalid-state-error () t))
                     :null-provider-refused
                     (handler-case (progn (make-instance 'xna.content:content-manager
                                                         :service-provider nil)
                                          nil)
                       (xna:cna-argument-error () t))
                     :device-service-only-refused
                     (handler-case
                         (let ((bare (make-instance 'xna:game-service-container)))
                           (xna:add-service bare 'xna:igraphics-device-service
                                            (make-instance 'service-stand-in))
                           (make-instance 'xna.content:content-manager
                                          :service-provider bare)
                           nil)
                       (xna:cna-invalid-state-error () t))))
      (progn (ignore-errors (xna:dispose one))
             (ignore-errors (xna:dispose two))
             (ignore-errors (xna:dispose extension)))))
  (xna:exit game))

(define-native-test the-canonical-content-constructors-resolve-through-the-provider
  "SERVICES_CONTENT: both `IServiceProvider' shapes, and the extension beside them.

XNA's one-argument constructor delegates to the two-argument one with
`String.Empty', so the root directory of the short shape is empty rather than
absent -- that is the IL's `ldsfld String::Empty', not a default invented here.

**The extension constructor still works and answers no provider**, which is the
honest answer: `cna_content_manager_create' takes a graphics device and cannot
carry a provider at all, so there is none to report.

The three refusals are the resolution XNA does at load time and CNA must do at
construction, because a native manager cannot exist before a device is resolved:
a null provider, a provider with no `IGraphicsDeviceService', and a provider
whose service answers no device. XNA distinguishes the last two as well -- its
`GraphicsDeviceFromContentReader' raises `ContentLoadException' separately for
each -- so the distinction is preserved, only earlier."
  (let ((game (make-instance 'content-service-game)))
    (unwind-protect
         (progn
           (xna:run game)
           (let ((f (findings game)))
             (is-true (getf f :one-provider-eq)
                      "ServiceProvider answers the exact object it was given")
             (is (equal "" (getf f :one-root))
                 "the one-argument constructor passes String.Empty")
             (is-true (getf f :two-provider-eq))
             (is (equal "Content" (getf f :two-root)))
             (is (null (getf f :extension-provider))
                 "the extension constructor has no provider to answer")
             (is (equal "" (getf f :extension-root)))
             (is-true (getf f :null-provider-refused))
             (is-true (getf f :no-service-refused)
                      "a provider with no IGraphicsDeviceService is refused")
             (is-true (getf f :device-service-only-refused)
                      "a service that answers no graphics device is refused too,
                       which is the second of XNA's two content-load failures")
             (note-services :content
                            "both canonical ContentManager constructors resolved a ~
                             graphics device through the IServiceProvider protocol, ~
                             ServiceProvider answered the exact object each was ~
                             given, and the graphics-device extension constructor ~
                             still works beside them")))
      (progn (ignore-errors (xna:dispose (game-manager game)))
             (ignore-errors (xna:dispose game))))))

(define-native-test the-content-constructor-shapes-are-exact
  "Four constructor shapes and nothing between them.

`:SERVICE-PROVIDER' with `:GRAPHICS-DEVICE' names no constructor, and neither
does no keyword at all. This is the rule `%CHECK-OVERLOAD-KEYWORDS' exists for,
and it is checked before anything is resolved, so it needs no live device."
  (with-managed-game (game)
    (let ((container (xna:services game)))
      (signals xna:cna-usage-error
        (make-instance 'xna.content:content-manager
                       :service-provider container
                       :graphics-device (xna:graphics-device game))
        "the canonical and the extension shapes do not blend")
      (signals xna:cna-usage-error
        (make-instance 'xna.content:content-manager)
        "no keyword at all names no constructor")
      (signals xna:cna-usage-error
        (make-instance 'xna.content:content-manager :root-directory "Content")
        "a root directory alone names no constructor either"))))
