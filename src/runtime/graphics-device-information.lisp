;;;; graphics-device-information.lisp --- Microsoft.Xna.Framework.GraphicsDeviceInformation.
;;;;
;;;; The adapter, profile and presentation parameters a device would be made
;;;; from. **A managed, mutable object with no native handle**: XNA's is a plain
;;;; class over three fields, and CNA's `CNA_GraphicsDeviceInformation' is a
;;;; caller-initialised POD struct that its own header calls a "pure POD
;;;; operation" -- neither side has an object to own.
;;;;
;;;; **The adapter is a `GraphicsAdapter', never CNA's index.** CNA names an
;;;; adapter by a zero-based index because "a pointer into the runtime's adapter
;;;; list is nothing a C caller could hold safely"; XNA exposes the adapter
;;;; object. So the index is what crosses the boundary and never what a program
;;;; sees, and `%WRITE-GRAPHICS-DEVICE-INFORMATION' and its inverse are where
;;;; the conversion lives.
;;;;
;;;; Every guard, default and copy rule below is the pinned IL's, and three of
;;;; them would not have been guessed:
;;;;
;;;; * **`Clone' shares the adapter and copies the parameters.** The IL makes a
;;;;   new information object, then overwrites its parameters with
;;;;   `this.presentationParameters.Clone()' and its adapter with the *same*
;;;;   `adapter' reference. So the clone's `Adapter' is `EQ' to the original's
;;;;   and its `PresentationParameters' is not.
;;;; * **`Equals' does not compare the parameters by reference.** It compares ten
;;;;   named fields of them, one at a time, and `bne.un's out on the first that
;;;;   differs. Two informations with different parameter objects holding equal
;;;;   settings are equal.
;;;; * **The `Adapter' setter tests the wrong operand.** `set_Adapter' is
;;;;   `ldarg.0; ldfld adapter; brtrue.s' -- it throws `ArgumentNullException'
;;;;   when the **field it is about to overwrite** is null, not when the value
;;;;   is. So assigning NIL succeeds once and the *next* assignment of anything
;;;;   throws. That is a defect in the original and it is reproduced rather than
;;;;   corrected, for the reason this binding reproduces `Matrix.Decompose'
;;;;   writing its outputs on failure: the authority is what the assembly does.

(in-package #:microsoft.xna.framework)

(defclass graphics-device-information ()
  ((%adapter :initarg :adapter :reader adapter-of)
   (%graphics-profile :initarg :graphics-profile :accessor graphics-profile-of)
   (%presentation-parameters :initarg :presentation-parameters
                             :accessor presentation-parameters-of))
  (:documentation
   "Microsoft.Xna.Framework.GraphicsDeviceInformation: one candidate device
configuration.

    (let ((info (make-instance 'graphics-device-information)))
      (setf (graphics-profile-of info) :hi-def)
      (setf (back-buffer-width (presentation-parameters-of info)) 1280))

Mutable and managed: it holds no native handle and is not disposed. The object a
PREPARING-DEVICE-SETTINGS handler receives is this type, and what a handler
writes into it is what the device is then created from.

The three accessors are named with a `-OF' suffix because all three of
`ADAPTER', `GRAPHICS-PROFILE' and `PRESENTATION-PARAMETERS' already name members
of other types in this projection -- `GraphicsDevice.Adapter',
`GraphicsDeviceManager.GraphicsProfile' and `GraphicsDevice.
PresentationParameters' -- and XNA tells those apart by the type of the receiver,
which a Lisp reader on a shared generic function could do too but a *setter*
could not do safely across unrelated hierarchies."))

(defmethod initialize-instance :after ((info graphics-device-information) &key)
  "XNA's parameterless constructor, exactly:

    presentationParameters = new PresentationParameters()
    adapter                = GraphicsAdapter.DefaultAdapter
    graphicsProfile        = default(GraphicsProfile)

The profile default is the enumeration's zero, `Reach', because the IL never
assigns the field and a CLR field starts at zero.

**The adapter is resolved eagerly, as XNA's is**, so this constructor needs a
live game and a lifecycle callback to be inside -- the standing scope rule for
every adapter query in this binding, which is why
`GRAPHICS-ADAPTER-DEFAULT-ADAPTER' is reported partial. A caller outside that
scope gets that member's own refusal, naming the scope, rather than a half-built
object."
  (unless (slot-boundp info '%presentation-parameters)
    (setf (presentation-parameters-of info)
          (make-instance 'microsoft.xna.framework.graphics:presentation-parameters)))
  (unless (slot-boundp info '%graphics-profile)
    (setf (graphics-profile-of info) :reach))
  (unless (slot-boundp info '%adapter)
    (setf (slot-value info '%adapter)
          (microsoft.xna.framework.graphics:graphics-adapter-default-adapter))))

(defgeneric (setf adapter-of) (value info)
  (:documentation
   "GraphicsDeviceInformation.Adapter's setter.

**Reproduces a defect in the original, deliberately.** XNA's `set_Adapter' checks
the field it is about to overwrite instead of the value it was given, so it
throws `ArgumentNullException' when the *current* adapter is null and stores
whatever it was given -- including NIL. A first `(setf (adapter-of info) nil)'
therefore succeeds, and the next assignment of anything at all is refused. The
message names \"value\" and says to use the default adapter, which is the message
XNA's resource string carries.

Correcting it here would make this binding disagree with the assembly it is a
projection of, on a member whose whole observable behaviour is the guard."))

(defmethod (setf adapter-of) (value (info graphics-device-information))
  (unless (slot-value info '%adapter)
    (error 'cna-argument-error
           :operation "(setf adapter-of)" :object-type 'graphics-device-information
           :parameter-name "value"
           :format-control
           "value must not be NIL; use the default adapter. XNA throws ~
            ArgumentNullException here -- and note that it is testing the adapter this ~
            object already holds rather than the one being assigned, which is why this ~
            refusal arrives one assignment later than a reader expects. The defect is ~
            reproduced rather than corrected."))
  (setf (slot-value info '%adapter) value))

(defgeneric clone-graphics-device-information (info)
  (:documentation
   "GraphicsDeviceInformation.Clone(): a copy, with XNA's exact sharing.

    (let ((copy (clone-graphics-device-information info)))
      (eq (adapter-of copy) (adapter-of info)))                     ; => T
      (eq (presentation-parameters-of copy)
          (presentation-parameters-of info))                        ; => NIL

The adapter is **shared** and the presentation parameters are **copied**; the
profile is a keyword and copies itself. That asymmetry is the IL's, not a
simplification: `Clone' stores `this.presentationParameters.Clone()' into the new
object and `this.adapter' into it unchanged.

Named for its type, as CLONE-PRESENTATION-PARAMETERS and CLONE-EFFECT are, rather
than putting a bare CLONE into a package consumers use unqualified."))

(defmethod clone-graphics-device-information ((info graphics-device-information))
  ;; Not MAKE-INSTANCE: the parameterless constructor resolves the default
  ;; adapter, which needs the lifecycle scope, and XNA's Clone overwrites all
  ;; three fields immediately afterwards anyway. Building the object directly is
  ;; what keeps a clone possible wherever the original was reachable.
  (let ((copy (allocate-instance (find-class 'graphics-device-information))))
    (setf (slot-value copy '%adapter) (slot-value info '%adapter)
          (slot-value copy '%graphics-profile) (graphics-profile-of info)
          (slot-value copy '%presentation-parameters)
          (microsoft.xna.framework.graphics:clone-presentation-parameters
           (presentation-parameters-of info)))
    copy))

;;; --- Equals and GetHashCode --------------------------------------------------
;;;
;;; XNA compares nine presentation-parameter fields that this binding projects
;;; and a tenth it does not: `DeviceWindowHandle', which is a *missing* member of
;;; `PresentationParameters' here because CNA answers the question with
;;; `CNA_RESULT_NOT_SUPPORTED' by design. Nine of ten are compared, and the
;;; omission is the same absence rather than a second one.

(defun %presentation-parameters-settings-equal-p (a b)
  "XNA's field-by-field comparison of two PresentationParameters, in its order."
  (macrolet ((same (reader &optional (test 'eql))
               `(,test (,reader a) (,reader b))))
    (and (same microsoft.xna.framework.graphics:back-buffer-width)
         (same microsoft.xna.framework.graphics:back-buffer-height)
         (same microsoft.xna.framework.graphics:back-buffer-format eq)
         (same microsoft.xna.framework.graphics:depth-stencil-format eq)
         (same microsoft.xna.framework.graphics:multi-sample-count)
         ;; DisplayOrientation is a flags enum and projects as a *list* of
         ;; keywords, so EQUAL rather than EQ -- and the list is built in the
         ;; enumeration's own bit order by DISPLAY-ORIENTATION-FROM-VALUE, so two
         ;; equal masks always produce EQUAL lists.
         (same microsoft.xna.framework.graphics:display-orientation equal)
         (same microsoft.xna.framework.graphics:presentation-interval eq)
         (same microsoft.xna.framework.graphics:render-target-usage eq)
         (eq (not (microsoft.xna.framework.graphics:is-full-screen a))
             (not (microsoft.xna.framework.graphics:is-full-screen b))))))

(defgeneric graphics-device-information-equal-p (info other)
  (:documentation
   "GraphicsDeviceInformation.Equals(Object).

    (graphics-device-information-equal-p info other)

Anything that is not a GRAPHICS-DEVICE-INFORMATION is unequal, which is the IL's
`isinst' answering null. Otherwise: the adapters must be the same object, the
profiles must match, and nine of the presentation parameters' settings must
match one by one.

**The adapter comparison is object identity**, because XNA's is: `GraphicsAdapter'
overrides neither `Equals' nor `GetHashCode', so `Object.Equals' on it is
reference equality. This binding interns adapters for exactly that reason -- see
`*INTERNED-ADAPTERS*'.

**The parameters are compared by value, not by reference**, so two informations
holding different parameter objects with equal settings are equal. The tenth
field XNA compares is `DeviceWindowHandle', which this binding does not project
at all; the comparison is nine fields wide here for that one reason.

Named for its type rather than being a method on a general EQUAL-P, and spelled
as a predicate because Common Lisp has no `Object.Equals' to specialise."))

(defmethod graphics-device-information-equal-p ((info graphics-device-information) other)
  (and (typep other 'graphics-device-information)
       (eq (adapter-of info) (adapter-of other))
       (eq (graphics-profile-of info) (graphics-profile-of other))
       (%presentation-parameters-settings-equal-p
        (presentation-parameters-of info) (presentation-parameters-of other))
       t))

(defgeneric graphics-device-information-hash-code (info)
  (:documentation
   "GraphicsDeviceInformation.GetHashCode().

XNA exclusive-ors the profile's hash with the adapter's and with each compared
setting's. This reproduces the *shape* -- a `LOGXOR' fold over the same members,
in the same order -- and not the numbers, because the numbers are the CLR's:
`Enum.GetHashCode', `Int32.GetHashCode' and `Object.GetHashCode' are runtime
implementations, and the last of them is an object address in disguise.

What it guarantees is what a hash code has to guarantee and all XNA's guarantees
too: two informations GRAPHICS-DEVICE-INFORMATION-EQUAL-P have equal hash codes.
It is not a promise that a hash matches one computed by XNA, and no test here
asserts a literal value."))

(defmethod graphics-device-information-hash-code ((info graphics-device-information))
  (let ((pp (presentation-parameters-of info)))
    (logxor (sxhash (graphics-profile-of info))
            (sxhash (microsoft.xna.framework.graphics::%adapter-index (adapter-of info)))
            (sxhash (microsoft.xna.framework.graphics:back-buffer-width pp))
            (sxhash (microsoft.xna.framework.graphics:back-buffer-height pp))
            (sxhash (microsoft.xna.framework.graphics:back-buffer-format pp))
            (sxhash (microsoft.xna.framework.graphics:depth-stencil-format pp))
            (sxhash (microsoft.xna.framework.graphics:multi-sample-count pp))
            (sxhash (microsoft.xna.framework.graphics:display-orientation pp))
            (sxhash (microsoft.xna.framework.graphics:presentation-interval pp))
            (sxhash (microsoft.xna.framework.graphics:render-target-usage pp))
            (sxhash (and (microsoft.xna.framework.graphics:is-full-screen pp) t)))))

(defmethod print-object ((info graphics-device-information) stream)
  (print-unreadable-object (info stream :type t)
    (let ((pp (presentation-parameters-of info)))
      (format stream "~a ~dx~d"
              (graphics-profile-of info)
              (microsoft.xna.framework.graphics:back-buffer-width pp)
              (microsoft.xna.framework.graphics:back-buffer-height pp)))))

;;; --- the native bridge -------------------------------------------------------
;;;
;;; Private, and the only place `CNA_GraphicsDeviceInformation' is read or
;;; written. Both directions convert the adapter between the object a program
;;; sees and the index CNA names it by.

(defun %write-graphics-device-information (pointer info)
  "Fill a caller-initialised CNA_GraphicsDeviceInformation from INFO."
  (cffi:foreign-funcall
   "memset" :pointer pointer :int 0
   :size cna-lisp.internal.ffi::+sizeof-cna-graphics-device-information+ :void)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-graphics-device-information)
                 ',name)))
    (setf (slot cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-graphics-device-information+
          (slot cna-lisp.internal.ffi::struct-version) 1
          ;; CNA's own meaning for a negative index: "no adapter is selected".
          ;; That is the only thing a NIL adapter -- which XNA's broken setter
          ;; lets a program install -- can honestly become.
          (slot cna-lisp.internal.ffi::adapter-index)
          (let ((adapter (adapter-of info)))
            (if adapter (microsoft.xna.framework.graphics::%adapter-index adapter) -1))
          (slot cna-lisp.internal.ffi::graphics-profile)
          (microsoft.xna.framework.graphics:graphics-profile-value
           (graphics-profile-of info))))
  (microsoft.xna.framework.graphics::%write-presentation-parameters
   (cffi:foreign-slot-pointer
    pointer '(:struct cna-lisp.internal.ffi::cna-graphics-device-information)
    'cna-lisp.internal.ffi::presentation-parameters)
   (presentation-parameters-of info))
  ;; %WRITE-PRESENTATION-PARAMETERS memsets its own region, so the enclosing
  ;; struct's size and version are restored after it rather than before.
  (setf (cffi:foreign-slot-value
         pointer '(:struct cna-lisp.internal.ffi::cna-graphics-device-information)
         'cna-lisp.internal.ffi::struct-size)
        cna-lisp.internal.ffi::+sizeof-cna-graphics-device-information+
        (cffi:foreign-slot-value
         pointer '(:struct cna-lisp.internal.ffi::cna-graphics-device-information)
         'cna-lisp.internal.ffi::struct-version)
        1)
  pointer)

(defun %read-graphics-device-information (pointer game &optional into)
  "Fill INTO, or a fresh object, from a filled CNA_GraphicsDeviceInformation.

GAME is what the adapter index is resolved against, because an adapter here is an
index plus the game to ask through. A negative index is CNA's \"no adapter\" and
becomes NIL, which is the value XNA's own setter defect can produce."
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-graphics-device-information)
                 ',name)))
    (let ((info (or into (allocate-instance (find-class 'graphics-device-information))))
          (index (slot cna-lisp.internal.ffi::adapter-index)))
      (setf (slot-value info '%adapter)
            (when (>= index 0)
              (microsoft.xna.framework.graphics::%intern-graphics-adapter game index))
            (slot-value info '%graphics-profile)
            (microsoft.xna.framework.graphics:graphics-profile-from-value
             (slot cna-lisp.internal.ffi::graphics-profile))
            (slot-value info '%presentation-parameters)
            (microsoft.xna.framework.graphics::%read-presentation-parameters
             (cffi:foreign-slot-pointer
              pointer '(:struct cna-lisp.internal.ffi::cna-graphics-device-information)
              'cna-lisp.internal.ffi::presentation-parameters)
             (and into (presentation-parameters-of into))))
      info)))

(defun graphics-device-information-clr-type-name ()
  "The .NET type name CNA reports for its device-configuration type.

A CNA-Lisp addition rather than an XNA member, and the same cross-check
CLR-TYPE-NAME is for a game: it is what makes \"this projects
`Microsoft.Xna.Framework.GraphicsDeviceInformation'\" a checkable claim rather
than an asserted one. A function of no arguments because CNA's two routes take
none -- the name belongs to the type."
  (cna-lisp.internal:ensure-abi-admitted)
  (cna-lisp.internal:count-then-copy-string
   (lambda (out)
     (cna-lisp.internal.ffi::%graphics-device-information-get-type-name-size out))
   (lambda (buffer capacity out)
     (cna-lisp.internal.ffi::%graphics-device-information-copy-type-name
      buffer capacity out))
   "graphics-device-information-clr-type-name"))
