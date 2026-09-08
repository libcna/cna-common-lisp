;;;; owned-graphics-device.lisp --- the GraphicsDevice a caller constructs.
;;;;
;;;; `GraphicsDevice(GraphicsAdapter, GraphicsProfile, PresentationParameters)'
;;;; and `GraphicsDevice.Dispose()', which are the same public type as
;;;; `graphics-device.lisp' and a separate file for the reason
;;;; `GraphicsDevice.Reset' lives in `graphics-adapter.lisp': the constructor
;;;; takes a `GRAPHICS-ADAPTER' and a `PRESENTATION-PARAMETERS', and both of
;;;; those classes are declared after `graphics-device.lisp' loads.
;;;;
;;;; Nothing here is a second class. `%DEVICE-LIFETIME-MODE' is the whole
;;;; difference and `graphics-device.lisp' explains it; this file is the two
;;;; members only a caller-owned device has, plus the disposal that is the other
;;;; half of owning one.

(in-package #:microsoft.xna.framework.graphics)

;;; --- the canonical constructor -------------------------------------------------
;;;
;;; `GraphicsDevice(GraphicsAdapter, GraphicsProfile, PresentationParameters)',
;;; read from the pinned Graphics assembly instruction by instruction. The order
;;; below is that order, and it is not the order the arguments are written in.

(defun %validate-owned-device-arguments (adapter graphics-profile presentation-parameters)
  "XNA's constructor guards, in XNA's order, before anything native happens.

The IL is explicit about an order a reader would guess wrong:

    IL_0013  ldarg.3  brtrue  ->  ArgumentNullException(\"presentationParameters\")
    IL_0026  ldarg.1  brtrue  ->  ArgumentNullException(\"adapter\")

**The third argument is tested first.** So `(make-instance 'graphics-device)'
with neither an adapter nor parameters names the *parameters*, not the adapter,
and a binding that checked left to right would name the wrong one.

The profile is not tested here at all, because XNA does not test it here: it is
stored raw into `_graphicsProfile' and then handed to
`ProfileCapabilities.GetInstance', whose `switch' has two arms and whose default
throws `ArgumentOutOfRangeException(\"graphicsProfile\")'. That is reproduced as
the CHECK-TYPE below rather than as a null test, and it comes after both null
tests for the same reason."
  (unless presentation-parameters
    (error 'microsoft.xna.framework:cna-argument-error
           :operation "make-instance 'graphics-device"
           :object-type 'graphics-device
           :parameter-name "presentation-parameters"
           :format-control
           "a graphics device needs presentation parameters. XNA tests this argument ~
            *first*, before the adapter, so this is the refusal even when the adapter ~
            is missing too."
           :format-arguments '()))
  (check-type presentation-parameters presentation-parameters)
  (unless adapter
    (error 'microsoft.xna.framework:cna-argument-error
           :operation "make-instance 'graphics-device"
           :object-type 'graphics-device
           :parameter-name "adapter"
           :format-control
           "a graphics device needs the adapter to create it on. Reach one with ~
            GRAPHICS-ADAPTER-ADAPTERS or GRAPHICS-ADAPTER-DEFAULT-ADAPTER."
           :format-arguments '()))
  (check-type adapter graphics-adapter)
  (unless (member graphics-profile (all-graphics-profile))
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "make-instance 'graphics-device"
           :object-type 'graphics-device
           :parameter-name "graphics-profile"
           :format-control
           "~s is not a GraphicsProfile. XNA's ProfileCapabilities.GetInstance has an ~
            arm for Reach and one for HiDef and throws ArgumentOutOfRangeException for ~
            anything else; the members are ~{~s~^ and ~}."
           :format-arguments (list graphics-profile (all-graphics-profile))))
  (values))

(defun %create-owned-device (device adapter graphics-profile presentation-parameters)
  "Take the native device, and record everything XNA's constructor records.

Runs under the construction ledger, so a failure anywhere after
`cna_graphics_device_create' -- a later initializer of a subclass included --
gives the device back rather than leaking one CNA will hold until the process
exits. Measured: `cna_graphics_device_destroy' on a device with no children is
SUCCESS on every admitted ABI."
  (cffi:with-foreign-objects
      ((native '(:struct cna-lisp.internal.ffi::cna-presentation-parameters))
       (out :uint64))
    (%write-presentation-parameters native presentation-parameters)
    ;; Building a renderer context is where the GL driver raises: measured, Mesa
    ;; llvmpipe raises `invalid' and `divide-by-zero' inside this call. See
    ;; src/internal/float-semantics.lisp.
    (cna-lisp.internal:check-result
     (cna-lisp.internal:with-foreign-float-environment
       (cna-lisp.internal.ffi::%graphics-device-create
        (%adapter-index adapter) (graphics-profile-value graphics-profile) native out))
     "make-instance 'graphics-device" :object-type 'graphics-device)
    (let ((handle (cffi:mem-ref out :uint64)))
      (cna-lisp.internal:record-construction-undo
       device (lambda () (cna-lisp.internal.ffi::%graphics-device-destroy handle)))
      (setf (cna-lisp.internal:handle-of device) handle
            ;; `IL_0084: ldarg.1; stfld pCurrentAdapter' -- the caller's own
            ;; object, stored by reference. XNA's GraphicsAdapter overrides
            ;; neither Equals nor GetHashCode, so ADAPTER on this device must be
            ;; EQ to what was passed and not a fresh wrapper for the same index.
            (slot-value device '%owned-adapter) adapter
            ;; `IL_0046: ldarg.2; stfld _graphicsProfile' -- the requested value,
            ;; stored before any validation and never re-read from the device.
            (slot-value device '%owned-profile) graphics-profile
            ;; **Two Clones, and the second is the one the property answers.**
            ;; `IL_0093' clones into pInternalCachedParams and `IL_009f' clones
            ;; again into pPublicCachedParams, and `get_PresentationParameters'
            ;; is `ldfld pPublicCachedParams'. So the device neither shares the
            ;; caller's object nor shares one clone between both fields:
            ;; mutating what was passed in changes nothing here, which is the
            ;; half a program can observe.
            (slot-value device '%owned-presentation-parameters)
            (clone-presentation-parameters presentation-parameters))
      (cna-lisp.internal:record-construction-undo
       device (lambda () (cna-lisp.internal:invalidate device)))
      device)))

(defmethod initialize-instance :after ((device graphics-device)
                                       &key (adapter nil adapter-p)
                                            (graphics-profile nil profile-p)
                                            (presentation-parameters nil parameters-p)
                                            ((:%transient transient) nil)
                                       &allow-other-keys)
  "GraphicsDevice(GraphicsAdapter, GraphicsProfile, PresentationParameters).

The one public constructor. XNA has exactly this argument list and nothing
shorter, so the three keywords are a *complete argument list* rather than a bag
of options: any subset, any superset and any mixture is refused, through the
same %CHECK-OVERLOAD-KEYWORDS every other collapsed overload in this binding
goes through.

**Supplying them is what makes the device an owned one.** The class defaults to
:PARENT-OWNED because the runtime's device is the common case and is built with
no initargs at all; a constructor call switches the lifetime rather than asking
the caller to name it, because naming it would be an initarg XNA does not have.

A game's device does not come this way. It is built by the runtime, takes none
of these keywords, and is reached with MICROSOFT.XNA.FRAMEWORK:GRAPHICS-DEVICE."
  (cond
    ;; %MAKE-TRANSIENT-ENUMERATION-DEVICE built the handle itself, because there
    ;; is no GraphicsAdapter to hand this constructor yet -- that is the loop it
    ;; exists to break. It takes none of the public keywords, answers no adapter
    ;; and no parameters, and is disposed inside the one call that made it.
    (transient
     (cna-lisp.internal:record-construction-undo
      device (let ((handle (cna-lisp.internal:handle-of device)))
               (lambda () (cna-lisp.internal.ffi::%graphics-device-destroy handle))))
     (%register-owned-device device)
     (cna-lisp.internal:record-construction-undo
      device (lambda () (%unregister-owned-device device))))
    ((or adapter-p profile-p parameters-p)
     (setf (slot-value device 'cna-lisp.internal::ownership) :owned)
     (microsoft.xna.framework::%check-overload-keywords
      "make-instance 'graphics-device"
      (microsoft.xna.framework::%supplied-keywords
       "adapter" adapter-p
       "graphics-profile" profile-p
       "presentation-parameters" parameters-p)
      '((:canonical "adapter" "graphics-profile" "presentation-parameters"))
      :object-type 'graphics-device)
     ;; **Before the first native route, and this surface has no game to have
     ;; done it.** Storage established the pattern: a no-game surface loads the
     ;; library and admits its ABI itself, so a mismatched library is the
     ;; binding's ordinary ABI diagnostic rather than an undefined foreign
     ;; symbol from the middle of a constructor.
     (cna-lisp.internal:ensure-abi-admitted)
     (%validate-owned-device-arguments adapter graphics-profile presentation-parameters)
     (%create-owned-device device adapter graphics-profile presentation-parameters)
     (%register-owned-device device)
     ;; **Recorded last, so it is undone first.** A subclass initializer that
     ;; signals runs after this method returns, and without this the rollback
     ;; would give the native device back and leave the CLOS object in the live
     ;; registry -- where an adapter query would find it and ask a question
     ;; through a handle that had already gone back to CNA.
     (cna-lisp.internal:record-construction-undo
      device (lambda () (%unregister-owned-device device))))
    ((%owned-device-p device)
     (error 'microsoft.xna.framework:cna-usage-error
            :operation "make-instance 'graphics-device"
            :object-type 'graphics-device
            :format-control
            "a GRAPHICS-DEVICE cannot be made by naming its ownership. Pass :ADAPTER, ~
             :GRAPHICS-PROFILE and :PRESENTATION-PARAMETERS together, which is XNA's ~
             only constructor."
            :format-arguments '()))))

;;; --- disposal ------------------------------------------------------------------
;;;
;;; `GraphicsDevice.Dispose()' is `Dispose(true)' and `GC.SuppressFinalize', and
;;; `Dispose(true)' is `~GraphicsDevice()'. That method, in the pinned assembly:
;;;
;;;     if (isDisposed) return;                          <- idempotent
;;;     !GraphicsDevice();                               <- the native release
;;;     Disposing?.Invoke(this, EventArgs.Empty);        <- last, and only then
;;;
;;; and `!GraphicsDevice()' is:
;;;
;;;     if (isDisposed) return;
;;;     isDisposed = true;                               <- FIRST, before any release
;;;     pResourceManager.ReleaseAllDeviceResources();    <- the children
;;;     vertexDeclarationManager.ReleaseAllDeclarations();
;;;     ... release the depth surface, the state tracker, the device ...
;;;
;;; So the order is: mark disposed, release the children, release the device,
;;; *then* raise Disposing. CNA's measured order for
;;; `cna_graphics_device_destroy' is the same shape -- each live child's
;;; Disposing, then the device's -- which is why the binding can let one native
;;; call do the whole thing rather than walking the children itself.
;;;
;;; **XNA and CNA differ inside the child, and the difference is public.** XNA
;;; calls `IGraphicsResource::ReleaseNativeObject(false)' on each child, which
;;; releases the native object and does *not* touch `isDisposed' and does *not*
;;; raise the child's `Disposing'; the child is left reporting `IsDisposed ==
;;; false' over a null `pComPtr', so every member guarded by
;;; `Helpers.CheckDisposed(this, pComPtr)' throws while the plain field reads
;;; keep answering. CNA disposes the child properly: `is_disposed' goes 0 -> 1
;;; and the child's Disposing fires. `docs/compatibility.md' records the
;;; divergence; this binding follows CNA, because a CLOS wrapper that reported
;;; itself live over a handle CNA has disposed is the zombie the whole
;;; ownership architecture exists to prevent.

(defmethod microsoft.xna.framework::dispose-owned-children
    ((device graphics-device) children)
  "An owned GraphicsDevice disposes its live graphics resources, as XNA's does.

**The second type in this binding to override the no-cascade default, and for
the same kind of reason as the first.** `SoundEffect' cascades because its
pinned `Dispose(bool)' walks its children and disposes them; this one cascades
because `!GraphicsDevice' calls `ReleaseAllDeviceResources' before it releases
the device, so a binding that refused here would refuse a call XNA accepts.

The disposal is left to `cna_graphics_device_destroy', which was measured doing
exactly it -- each live child's Disposing, then the device's. What this method
does is bring the *CLOS* side with it: a child whose native object CNA has just
released must not be left looking live, because the next thing a program does
with it would reach a handle that is gone. So each child is invalidated here,
before the native destroy, and in leaf-first order.

A parent-owned facade never reaches this method: %CHECK-DISPOSABLE refuses its
disposal before DISPOSE gets this far."
  (unless (%owned-device-p device)
    (return-from microsoft.xna.framework::dispose-owned-children
      (call-next-method)))
  ;; Newest first, which is leaf-first: a resource made later may be the child
  ;; of one made earlier -- a SpriteFont of its atlas -- and CNA refuses a
  ;; parent destroyed before its child.
  (dolist (child children)
    (cna-lisp.internal:invalidate child))
  (values))

(defmethod cna-lisp.internal:destroy-native ((device graphics-device))
  "Release the native device an :OWNED GRAPHICS-DEVICE holds.

Only reached for an owned device: %CHECK-DISPOSABLE refuses the facade's
disposal earlier, and DISPOSE never gets here for one.

`cna_graphics_device_destroy' is the only route -- measured, and worth stating
because there is an obvious wrong candidate:
`cna_graphics_device_dispose' answers `CNA_RESULT_NOT_SUPPORTED' for a
caller-created device exactly as it does for a borrowed one. Destroying the same
handle twice answers INVALID_HANDLE, so this is never called twice: DISPOSE's
own guard is what makes `Dispose()' idempotent, as IDisposable requires and as
`~GraphicsDevice''s `if (isDisposed) return' does there."
  (unwind-protect
       (cna-lisp.internal:check-result
        (cna-lisp.internal.ffi::%graphics-device-destroy
         (cna-lisp.internal:handle-of device))
        "dispose" :object-type 'graphics-device)
    ;; Off the registry whether or not CNA accepted the destroy: the handle is
    ;; not usable either way, and an adapter that resolved through it afterwards
    ;; would be asking through something that is gone.
    (%unregister-owned-device device)))
