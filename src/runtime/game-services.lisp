;;;; game-services.lisp --- Microsoft.Xna.Framework.GameServiceContainer.
;;;;
;;;; **This is a managed Common Lisp dictionary and it reaches no native code**,
;;;; which is the one thing to understand before reading anything else here.
;;;;
;;;; CNA's C ABI has exactly two service identities --
;;;; `CNA_GAME_SERVICE_TYPE_GRAPHICS_DEVICE_MANAGER' and
;;;; `..._GRAPHICS_DEVICE_SERVICE' -- reachable through
;;;; `cna_game_services_contains_ext' and `cna_game_services_remove_ext'. There
;;;; is no registration route and no way to name a third service. It would be
;;;; easy to read that as the shape of the type and project a two-slot object,
;;;; and it would be wrong: `runtime_components.h' says why in its own words.
;;;; The canonical container "is keyed by C++ type identity, which has no C
;;;; expression: a C consumer cannot name a type, and cannot author an object
;;;; implementing a C++ interface to register under one", and a consumer that
;;;; "keeps its own service container beside this one is not working around a
;;;; missing feature; it is holding the only kind of service C can express".
;;;;
;;;; Common Lisp does not have C's limitation. A Lisp program can name a type and
;;;; can define an object that answers a protocol, so the container here is what
;;;; XNA's is -- an arbitrary type-keyed dictionary -- and CNA's two slots become
;;;; a **native cross-check** rather than the universe of keys. That is the same
;;;; shape `StorageContainer.StorageDevice' already has, whose managed answer is
;;;; checked against `cna_storage_container_get_storage_device' rather than read
;;;; out of it.
;;;;
;;;; The pinned IL is the authority for every guard below, and it had two
;;;; surprises worth naming here because a reader would otherwise assume them
;;;; away:
;;;;
;;;; * **`AddService' really does check assignability.** After the null and
;;;;   duplicate guards it calls `type.IsAssignableFrom(provider.GetType())' and
;;;;   throws `ArgumentException' when it fails. So the guard is reproduced
;;;;   rather than skipped -- and reproducing it is what forces the designator
;;;;   policy below to be a policy rather than "whatever the caller passed".
;;;; * **`RemoveService' of an absent key is an ordinary success**: the IL calls
;;;;   `Dictionary.Remove' and `pop's the boolean it answers.

(in-package #:microsoft.xna.framework)

;;; --- the service type designator -------------------------------------------
;;;
;;; XNA keys the dictionary by `System.Type'. Projecting `System.Type' itself
;;; would mean projecting CLR reflection, which is neither in the selected
;;; profile nor anything a Common Lisp program wants; and using the provider
;;; object's identity as the key would be a different data structure, because the
;;; key is a *type* and one type may hold different providers over time.
;;;
;;; So there is one normalisation rule and it has two admitted kinds:
;;;
;;;   a CLOS class, or a symbol naming one   -> the class's name
;;;   a symbol naming a declared service protocol -> that symbol
;;;
;;; Both are canonical symbols, so equality is EQ, hashing is EQ, and duplicate
;;; detection is the hash table's own. Both are also *testable*, which is what
;;; keeps XNA's assignability guard real: a class tests with TYPEP, and a
;;; protocol tests with the implementor registry DEFINE-SERVICE-PROTOCOL builds.
;;;
;;; A symbol naming neither is **refused**. That is deliberate and it is the
;;; narrow choice: a bare uninterned key would work as a dictionary key but would
;;; make `IsAssignableFrom' unanswerable, and this binding does not project a
;;; guard it cannot then apply.

(defvar *service-protocols* (make-hash-table :test #'eq)
  "Declared service protocols: NAME -> the list of implementing class names.

A *protocol* is this projection's counterpart to a CLR interface. XNA's two
service interfaces -- `IGraphicsDeviceManager' and `IGraphicsDeviceService' --
are interfaces rather than classes, and this binding projects an interface as a
set of generic functions rather than as a class, so `FIND-CLASS' cannot answer
for them and a designator policy built only on classes would not be able to name
the two keys the framework itself uses.")

(defun service-protocol-p (designator)
  "Whether DESIGNATOR is a declared service protocol name."
  (and (symbolp designator) (nth-value 1 (gethash designator *service-protocols*))))

(defun %service-protocol-satisfied-p (protocol object)
  "Whether OBJECT is an instance of some class declared to implement PROTOCOL.

Subclasses count and cost no metaobject protocol to count: this is `TYPEP'
against each declared implementor, and `TYPEP' already answers true for a
subclass. That is what `IsAssignableFrom' does for an interface a base class
implements."
  (and (some (lambda (implementor) (typep object implementor))
             (gethash protocol *service-protocols*))
       t))

(defmacro define-service-protocol (name)
  "Declare NAME as a service type designator standing for a protocol.

The projection of a CLR interface used as a service key. A class states that it
answers the protocol with DECLARE-SERVICE-PROTOCOL-IMPLEMENTOR.

**NAME becomes a real Common Lisp type**, and that is what keeps XNA's
assignability guard honest rather than special-cased: `(typep provider
'igraphics-device-service)' answers, so `AddService' can apply
`type.IsAssignableFrom(provider.GetType())' with one `TYPEP' whether the
designator names a class or a protocol. A `DEFTYPE' rather than a class because
an interface is not a superclass here -- this binding projects one as generic
functions, and a class would force every implementor to inherit from something
XNA does not make them inherit from.

Defines an internal predicate beside it, because `(satisfies ...)' needs a
function to name. It is not exported: the type is the public thing."
  (let ((predicate (intern (format nil "%~a-SERVICE-PROTOCOL-P" (symbol-name name))
                           (symbol-package name))))
    `(progn
       (eval-when (:compile-toplevel :load-toplevel :execute)
         (unless (nth-value 1 (gethash ',name *service-protocols*))
           (setf (gethash ',name *service-protocols*) '())))
       (defun ,predicate (object)
         ,(format nil "Whether OBJECT implements the ~a service protocol." name)
         (%service-protocol-satisfied-p ',name object))
       (deftype ,name () '(satisfies ,predicate))
       ',name)))

(defun declare-service-protocol-implementor (protocol class-name)
  "Record that CLASS-NAME's instances answer PROTOCOL.

Subclasses count, and they cost no metaobject protocol to count: membership is
tested with `TYPEP' against each declared implementor, and `TYPEP' already
answers true for a subclass. That is what `IsAssignableFrom' does for an
interface a base class implements."
  (unless (service-protocol-p protocol)
    (error 'cna-usage-error
           :operation "declare-service-protocol-implementor"
           :format-control "~s is not a declared service protocol."
           :format-arguments (list protocol)))
  (pushnew class-name (gethash protocol *service-protocols*) :test #'eq)
  protocol)

(defun service-protocol-implementors (protocol)
  "The class names declared to implement PROTOCOL, newest first.

A CNA-Lisp addition: the registry is what makes `(typep x 'a-protocol)' answer,
and a test that wants to say which classes were declared needs to read it."
  (unless (service-protocol-p protocol)
    (error 'cna-usage-error
           :operation "service-protocol-implementors"
           :format-control "~s is not a declared service protocol."
           :format-arguments (list protocol)))
  (copy-list (gethash protocol *service-protocols*)))

(defun %service-type-designator (designator operation parameter)
  "Normalise DESIGNATOR to the canonical symbol this container keys by.

Refuses anything that is neither a class nor a declared service protocol, and
says which two kinds it accepts: a designator whose membership cannot be tested
would make XNA's assignability guard unanswerable, and a guard that silently
stops applying is worse than one that never existed."
  (when (null designator)
    ;; XNA's first guard in all three members, and it is first in all three.
    (error 'cna-argument-error
           :operation operation :object-type 'game-service-container
           :parameter-name parameter
           :format-control
           "~a must not be NIL: XNA throws ArgumentNullException with the message ~
            \"The service type cannot be null.\""
           :format-arguments (list parameter)))
  (let ((name (cond ((typep designator 'class) (class-name designator))
                    ((symbolp designator) designator)
                    (t nil))))
    (cond ((and name (service-protocol-p name)) name)
          ((and name (find-class name nil)) name)
          (t
           (error 'cna-argument-error
                  :operation operation :object-type 'game-service-container
                  :parameter-name parameter
                  :format-control
                  "~s does not name a service type. A service type designator is a ~
                   CLOS class, a symbol naming one, or a symbol naming a protocol ~
                   declared with DEFINE-SERVICE-PROTOCOL -- XNA keys this container by ~
                   `System.Type', and this projection admits the two kinds of type a ~
                   Lisp program can test membership of, because `AddService' checks ~
                   `type.IsAssignableFrom(provider.GetType())' and a key nothing can ~
                   be tested against would make that guard unanswerable."
                  :format-arguments (list designator))))))

(defun %service-assignable-p (type provider)
  "XNA's `type.IsAssignableFrom(provider.GetType())', over this projection's types.

**One `TYPEP' for both kinds of designator**, because DEFINE-SERVICE-PROTOCOL
makes a protocol a real Common Lisp type. So this binding needed no metaobject
protocol and no dependency to reproduce the guard, and there is no branch here
that could drift between the two kinds."
  (typep provider type))

;;; --- IServiceProvider, as a language protocol -------------------------------
;;;
;;; `System.IServiceProvider' is a base-class-library interface with one member,
;;; and it is **not** added to the selected profile: a BCL type is not projected
;;; merely because a signature mentions it, which is the same rule that keeps
;;; `System.IO.Stream' out and answers `OpenFile' with an ordinary Lisp stream.
;;; What the closure needs is its *observable semantics*, and that is one generic
;;; function.

(defgeneric get-service (provider service-type)
  (:documentation
   "IServiceProvider.GetService(Type): the service registered under SERVICE-TYPE,
or NIL.

This is the whole of `System.IServiceProvider' as this binding projects it -- one
generic function rather than an imported interface hierarchy, because that is
what the interface is. Anything that answers it is a service provider here, so a
`ContentManager' built with `:SERVICE-PROVIDER' takes any object with a method on
this, not only a GAME-SERVICE-CONTAINER.

SERVICE-TYPE is a service type designator: a CLOS class, a symbol naming one, or
a symbol naming a protocol declared with DEFINE-SERVICE-PROTOCOL.

NIL for a service that is not registered, which is what XNA's answers -- the IL
tests `ContainsKey' and returns `ldnull' when it fails, rather than throwing."))

;;; --- GameServiceContainer ---------------------------------------------------

(defclass game-service-container ()
  ((%services :initform (make-hash-table :test #'eq) :reader %service-table)
   ;; NIL for a container a program made itself -- XNA's constructor is public
   ;; and parameterless, so a bare one is a legal object with no game behind it.
   ;; A game's own container carries the game so that removing one of CNA's two
   ;; canonical service identities can be mirrored into the native slot; see
   ;; `runtime/game-service-sync.lisp'.
   (%game :initarg :game :initform nil :reader %service-container-game))
  (:documentation
   "Microsoft.Xna.Framework.GameServiceContainer: a game's type-keyed services.

    (add-service (services game) 'my-audio-mixer mixer)
    (get-service (services game) 'my-audio-mixer)      ; => mixer
    (remove-service (services game) 'my-audio-mixer)

An arbitrary dictionary keyed by service type, exactly as XNA's is, and **not**
narrowed to the two services CNA's C ABI can name. It holds no native handle, is
not a child of the game, and is not disposed: its lifetime is the game's managed
object graph, which is what XNA's is too.

A `GRAPHICS-DEVICE-MANAGER' registers itself here under both
`IGRAPHICS-DEVICE-MANAGER' and `IGRAPHICS-DEVICE-SERVICE' when it is created,
and both keys answer the same manager object.

Implements the one-member `IServiceProvider' protocol -- see GET-SERVICE."))

(defmethod print-object ((container game-service-container) stream)
  (print-unreadable-object (container stream :type t)
    (format stream "~d service~:p" (hash-table-count (%service-table container)))))

(defgeneric add-service (container service-type provider)
  (:documentation
   "GameServiceContainer.AddService(Type, Object).

XNA's guards, in XNA's order, all four of them:

  1. a null service type is an ArgumentNullException naming \"type\";
  2. a null provider is an ArgumentNullException naming \"provider\";
  3. a type already present is an ArgumentException naming \"type\" -- so this is
     *not* an upsert, and re-registering needs a REMOVE-SERVICE first;
  4. a provider the type cannot hold is an ArgumentException. XNA really does
     check `type.IsAssignableFrom(provider.GetType())', and this reproduces it:
     a class designator tests with TYPEP, a protocol designator tests against the
     classes declared to implement it.

Answers no values, as the original returns void."))

(defgeneric remove-service (container service-type)
  (:documentation
   "GameServiceContainer.RemoveService(Type).

A null service type is an ArgumentNullException naming \"type\". **Removing a
type that is not registered is an ordinary success** and not an error: the IL
calls `Dictionary.Remove' and discards the boolean it answers.

Answers no values, as the original returns void."))

(defmethod add-service ((container game-service-container) service-type provider)
  (let ((type (%service-type-designator service-type "add-service" "type")))
    (unless provider
      (error 'cna-argument-error
             :operation "add-service" :object-type 'game-service-container
             :parameter-name "provider"
             :format-control
             "provider must not be NIL: XNA throws ArgumentNullException with the ~
              message \"The service provider cannot be null.\""))
    (when (nth-value 1 (gethash type (%service-table container)))
      (error 'cna-argument-error
             :operation "add-service" :object-type 'game-service-container
             :parameter-name "type"
             :format-control
             "a service is already registered under ~s. XNA throws ArgumentException ~
              here rather than replacing the entry; remove it first."
             :format-arguments (list type)))
    (unless (%service-assignable-p type provider)
      (error 'cna-argument-error
             :operation "add-service" :object-type 'game-service-container
             :parameter-name "provider"
             :format-control
             "~s cannot be registered under ~s: XNA checks ~
              `type.IsAssignableFrom(provider.GetType())' and throws ArgumentException ~
              when it fails."
             :format-arguments (list (type-of provider) type)))
    (setf (gethash type (%service-table container)) provider)
    (values)))

(defmethod get-service ((container game-service-container) service-type)
  (let ((type (%service-type-designator service-type "get-service" "type")))
    (values (gethash type (%service-table container)))))

(defmethod remove-service ((container game-service-container) service-type)
  (let ((type (%service-type-designator service-type "remove-service" "type")))
    (%remove-service-entry container type)
    (values)))

(defgeneric %remove-service-entry (container type)
  (:documentation
   "Drop TYPE's entry, with TYPE already normalised.

A generic function so that the game's own container can synchronise CNA's two
canonical slots without REMOVE-SERVICE having to know that some keys are special
-- see `runtime/game-service-sync.lisp', which defines its one method.

Declared here and specialised there so that this file, which is the whole managed
container, stays free of every native call."))

(defun service-types (container)
  "Every service type registered in CONTAINER, as a fresh list.

A CNA-Lisp addition rather than an XNA member: XNA's container has no
enumeration at all, and a test that wants to say \"exactly these two keys\" needs
one. The list is fresh, so mutating it cannot reach the container."
  (check-type container game-service-container)
  (loop for type being the hash-keys of (%service-table container) collect type))
