;;;; state-objects.lisp --- BlendState, DepthStencilState, RasterizerState and
;;;; SamplerState.
;;;;
;;;; These four are the mutable descriptors XNA hands to a GraphicsDevice and to
;;;; SpriteBatch.Begin. Everything about them here was read out of the pinned
;;;; Microsoft.Xna.Framework.Graphics assembly rather than inferred, because a
;;;; plausible reconstruction gets several of them wrong:
;;;;
;;;; * every setter calls ThrowIfBound first, so a state object becomes
;;;;   permanently read-only the moment it is applied to a device -- and the
;;;;   predefined ones are constructed already bound, which is why
;;;;   `BlendState.Opaque.ColorSourceBlend = ...' throws;
;;;; * RasterizerState's MultiSampleAntiAlias default is *true*, not false;
;;;; * SamplerState's MaxAnisotropy default is 4, not 1 and not 16;
;;;; * DepthStencilState's StencilMask and StencilWriteMask default to -1, the
;;;;   all-ones mask, not to 0 and not to #xFF;
;;;; * BlendState's MultiSampleMask likewise defaults to -1;
;;;; * BlendState.BlendFactor defaults to Color.White;
;;;; * the four predefined blend states set the colour *and* the alpha pair to
;;;;   the same two factors and change nothing else, so Opaque is (One, Zero) on
;;;;   both and NonPremultiplied is (SourceAlpha, InverseSourceAlpha) on both.
;;;;
;;;; **CNA's own presets are not the authority for any of that.** They are bound
;;;; -- cna_blend_state_init and its three companions -- so the two can be
;;;; compared, and tests/native/graphics-state.lisp does compare them. Where they
;;;; disagree, XNA wins in the public API and the divergence is recorded in
;;;; docs/limitations.md.
;;;;
;;;; The one disagreement found so far is BlendFunction: XNA numbers Min 3 and
;;;; Max 4, CNA numbers CNA_BLEND_FUNCTION_MAX 3 and CNA_BLEND_FUNCTION_MIN 4.
;;;; +BLEND-FUNCTION-TO-NATIVE+ below is where the two are reconciled, by name
;;;; rather than by value, so the public enum keeps XNA's numbering.

(in-package #:microsoft.xna.framework.graphics)

;;; --- the private base ---------------------------------------------------------
;;;
;;; XNA's state objects derive from GraphicsResource. CNA-Lisp's do not, and the
;;; reason is not a shortcut: CNA-Lisp's GRAPHICS-RESOURCE is a NATIVE-OBJECT with
;;; a CNA handle, and CNA models a state object as a versioned C descriptor with
;;; no handle at all -- there is no cna_blend_state_create and nothing to
;;; destroy. Giving these four a handle they do not have would be the fake this
;;; binding does not do. The inherited surface (Name, Tag, GraphicsDevice,
;;; Disposing, Dispose) is therefore absent, and src/capabilities.lisp records it.

(defclass %state-object ()
  ((bound :initform nil :accessor %state-bound-p)
   ;; No :initarg. MAKE-INSTANCE is XNA's public constructor for these four,
   ;; and it takes no arguments there, so it takes none here either.
   (label :initform nil :reader %state-label))
  (:documentation
   "The behaviour XNA's four state objects share: a read-only latch, and a name
the predefined instances carry."))

(defun %throw-if-bound (state operation)
  "XNA's ThrowIfBound: a state object that has been applied is read-only.

The message names the object the same way XNA's does -- by its type -- and adds
the label when the object is one of the predefined instances, because
`BlendState.Opaque' is the case a caller is most likely to hit by accident."
  (when (%state-bound-p state)
    (error 'microsoft.xna.framework:cna-invalid-state-error
           :operation operation
           :object-type (type-of state)
           :format-control
           "~a is bound to a graphics device and cannot be modified.~@[ It is ~a.~]"
           :format-arguments (list (type-of state) (%state-label state)))))

(defun %mark-bound (state)
  "Latch a state object read-only, as XNA's Apply does. Answers the state."
  (when state
    (setf (%state-bound-p state) t))
  state)

(defmacro %define-state-class (name (&rest properties) &key documentation)
  "Define one XNA state object: a class, a reader per property, and a setter that
refuses once the object is bound.

Each PROPERTY is (LISP-NAME DEFAULT TYPE &optional SINGLE), where TYPE is the
Common Lisp type the setter checks and SINGLE says the value is a System.Single
and is stored coerced to binary32.

The reader and the writer are generic functions, so a property two types share --
GraphicsDevice also has a MultiSampleMask -- is one generic function with a
method each rather than two names for one idea."
  `(progn
     (defclass ,name (%state-object)
       ,(mapcar (lambda (p) (list (first p) :initform (second p))) properties)
       (:documentation ,documentation))
     ,@(loop for (accessor default type single) in properties
             for operation = (string-downcase (symbol-name accessor))
             append
             `((defgeneric ,accessor (state)
                 (:documentation
                  ,(format nil "~a.~a. Defaults to ~a."
                           (symbol-name name) (symbol-name accessor)
                           (if (and (consp default) (eq (first default) 'quote))
                               (second default)
                               default))))
               (defmethod ,accessor ((state ,name)) (slot-value state ',accessor))
               (defgeneric (setf ,accessor) (value state)
                 (:documentation
                  ,(format nil "~a.~a setter. Refuses once the state is bound."
                           (symbol-name name) (symbol-name accessor))))
               (defmethod (setf ,accessor) (value (state ,name))
                 (%throw-if-bound state ,operation)
                 (check-type value ,type)
                 ;; A System.Single property takes any real and stores binary32,
                 ;; because that is what the CLR conversion does at the call site
                 ;; and refusing 1 where 1.0f0 is meant would be this binding's
                 ;; invention rather than XNA's rule.
                 (setf (slot-value state ',accessor)
                       ,(if single `(coerce value 'single-float) 'value))))
             )
     ',name))

;;; A ColorWriteChannels value is a flags enum, so a list of members; a bare
;;; member is accepted as the one-element list it means.
(deftype color-write-channels-designator ()
  "A ColorWriteChannels value: a list of members, or one member on its own."
  '(or color-write-channels list))

;;; --- BlendState ---------------------------------------------------------------

(%define-state-class blend-state
    ((color-source-blend :one blend)
     (color-destination-blend :zero blend)
     (color-blend-function :add blend-function)
     (alpha-source-blend :one blend)
     (alpha-destination-blend :zero blend)
     (alpha-blend-function :add blend-function)
     (color-write-channels '(:all) color-write-channels-designator)
     (color-write-channels-1 '(:all) color-write-channels-designator)
     (color-write-channels-2 '(:all) color-write-channels-designator)
     (color-write-channels-3 '(:all) color-write-channels-designator)
     (blend-factor nil microsoft.xna.framework:color)
     (multi-sample-mask -1 (signed-byte 32)))
  :documentation
  "Microsoft.Xna.Framework.Graphics.BlendState.

Every default is the one BlendState::SetDefaults writes: One/Zero and Add on both
the colour and the alpha pair, all four write masks All, a white BlendFactor and
a MultiSampleMask of -1.")

;;; BLEND-FACTOR's default is Color.White, which is a function call rather than a
;;; literal, so it is filled in after construction instead of in the slot.
(defmethod initialize-instance :after ((state blend-state) &key)
  (unless (slot-value state 'blend-factor)
    (setf (slot-value state 'blend-factor) (microsoft.xna.framework:white))))

;;; --- DepthStencilState --------------------------------------------------------

(%define-state-class depth-stencil-state
    ((depth-buffer-enable t boolean)
     (depth-buffer-write-enable t boolean)
     (depth-buffer-function :less-equal compare-function)
     (stencil-enable nil boolean)
     (stencil-function :always compare-function)
     (stencil-pass :keep stencil-operation)
     (stencil-fail :keep stencil-operation)
     (stencil-depth-buffer-fail :keep stencil-operation)
     (two-sided-stencil-mode nil boolean)
     (counter-clockwise-stencil-function :always compare-function)
     (counter-clockwise-stencil-pass :keep stencil-operation)
     (counter-clockwise-stencil-fail :keep stencil-operation)
     (counter-clockwise-stencil-depth-buffer-fail :keep stencil-operation)
     (stencil-mask -1 (signed-byte 32))
     (stencil-write-mask -1 (signed-byte 32))
     (reference-stencil 0 (signed-byte 32)))
  :documentation
  "Microsoft.Xna.Framework.Graphics.DepthStencilState.

DepthBufferFunction defaults to LessEqual, and both stencil masks to -1 -- the
all-ones mask -- which is what DepthStencilState::SetDefaults writes.")

;;; --- RasterizerState ----------------------------------------------------------

(%define-state-class rasterizer-state
    ((cull-mode :cull-counter-clockwise-face cull-mode)
     (fill-mode :solid fill-mode)
     (scissor-test-enable nil boolean)
     (multi-sample-anti-alias t boolean)
     (depth-bias 0.0f0 real t)
     (slope-scale-depth-bias 0.0f0 real t))
  :documentation
  "Microsoft.Xna.Framework.Graphics.RasterizerState.

MultiSampleAntiAlias defaults to **true**, which is the one default here a
reconstruction is most likely to get backwards.")

;;; --- SamplerState -------------------------------------------------------------

(%define-state-class sampler-state
    ((filter :linear texture-filter)
     (address-u :wrap texture-address-mode)
     (address-v :wrap texture-address-mode)
     (address-w :wrap texture-address-mode)
     (max-anisotropy 4 (signed-byte 32))
     (max-mip-level 0 (signed-byte 32))
     (mip-map-level-of-detail-bias 0.0f0 real t))
  :documentation
  "Microsoft.Xna.Framework.Graphics.SamplerState.

MaxAnisotropy defaults to 4, which is SamplerState::SetDefaults' literal.")

;;; --- the predefined instances -------------------------------------------------
;;;
;;; XNA's are `public static initonly' fields, so the same object every time and
;;; read-only from construction: their private constructors set isBound before
;;; anyone can reach them. These are memoised for the same two reasons -- a
;;; caller comparing `(eq (blend-state-opaque) (blend-state-opaque))' gets what
;;; the CLR gives, and the object cannot be mutated out from under the next
;;; caller.

(defmacro %define-predefined-state (function class label &body initialisation)
  (let ((cache (intern (format nil "*~a*" (symbol-name function)))))
    `(progn
       (defvar ,cache nil)
       (defun ,function ()
         ,(format nil "~a: the predefined instance, read-only as XNA's is.

The same object every call, which is what a `public static initonly' field gives."
                  label)
         (or ,cache
             (setf ,cache
                   (let ((state (make-instance ',class)))
                     (setf (slot-value state 'label) ,label)
                     ,@initialisation
                     (%mark-bound state))))))))

(%define-predefined-state blend-state-opaque blend-state "BlendState.Opaque"
  (setf (slot-value state 'color-source-blend) :one
        (slot-value state 'color-destination-blend) :zero
        (slot-value state 'alpha-source-blend) :one
        (slot-value state 'alpha-destination-blend) :zero))

(%define-predefined-state blend-state-alpha-blend blend-state "BlendState.AlphaBlend"
  (setf (slot-value state 'color-source-blend) :one
        (slot-value state 'color-destination-blend) :inverse-source-alpha
        (slot-value state 'alpha-source-blend) :one
        (slot-value state 'alpha-destination-blend) :inverse-source-alpha))

(%define-predefined-state blend-state-additive blend-state "BlendState.Additive"
  (setf (slot-value state 'color-source-blend) :source-alpha
        (slot-value state 'color-destination-blend) :one
        (slot-value state 'alpha-source-blend) :source-alpha
        (slot-value state 'alpha-destination-blend) :one))

(%define-predefined-state blend-state-non-premultiplied blend-state
    "BlendState.NonPremultiplied"
  (setf (slot-value state 'color-source-blend) :source-alpha
        (slot-value state 'color-destination-blend) :inverse-source-alpha
        (slot-value state 'alpha-source-blend) :source-alpha
        (slot-value state 'alpha-destination-blend) :inverse-source-alpha))

(%define-predefined-state depth-stencil-state-none depth-stencil-state
    "DepthStencilState.None"
  (setf (slot-value state 'depth-buffer-enable) nil
        (slot-value state 'depth-buffer-write-enable) nil))

(%define-predefined-state depth-stencil-state-default depth-stencil-state
    "DepthStencilState.Default"
  (setf (slot-value state 'depth-buffer-enable) t
        (slot-value state 'depth-buffer-write-enable) t))

(%define-predefined-state depth-stencil-state-depth-read depth-stencil-state
    "DepthStencilState.DepthRead"
  (setf (slot-value state 'depth-buffer-enable) t
        (slot-value state 'depth-buffer-write-enable) nil))

(%define-predefined-state rasterizer-state-cull-none rasterizer-state
    "RasterizerState.CullNone"
  (setf (slot-value state 'cull-mode) :none))

(%define-predefined-state rasterizer-state-cull-clockwise rasterizer-state
    "RasterizerState.CullClockwise"
  (setf (slot-value state 'cull-mode) :cull-clockwise-face))

(%define-predefined-state rasterizer-state-cull-counter-clockwise rasterizer-state
    "RasterizerState.CullCounterClockwise"
  (setf (slot-value state 'cull-mode) :cull-counter-clockwise-face))

(macrolet ((define-sampler-preset (function label filter address)
             `(%define-predefined-state ,function sampler-state ,label
                (setf (slot-value state 'filter) ,filter
                      (slot-value state 'address-u) ,address
                      (slot-value state 'address-v) ,address
                      (slot-value state 'address-w) ,address))))
  ;; The private constructor takes one address mode and writes it to U, V and W.
  (define-sampler-preset sampler-state-point-wrap "SamplerState.PointWrap" :point :wrap)
  (define-sampler-preset sampler-state-point-clamp "SamplerState.PointClamp" :point :clamp)
  (define-sampler-preset sampler-state-linear-wrap "SamplerState.LinearWrap" :linear :wrap)
  (define-sampler-preset sampler-state-linear-clamp "SamplerState.LinearClamp" :linear :clamp)
  (define-sampler-preset sampler-state-anisotropic-wrap "SamplerState.AnisotropicWrap"
    :anisotropic :wrap)
  (define-sampler-preset sampler-state-anisotropic-clamp "SamplerState.AnisotropicClamp"
    :anisotropic :clamp))

;;; --- translation to the CNA descriptors ---------------------------------------
;;;
;;; By name, never by value. Every other enum in this binding happens to share
;;; CNA's numbering, so a numeric pass-through would have worked and would have
;;; hidden the one place it does not: BlendFunction. These tables make the
;;; correspondence explicit for all of them, so the next divergence is a table
;;; entry rather than a silent wrong answer.

(defparameter %blend-to-native
  `((:one . ,cna-lisp.internal.ffi::+blend-one+)
    (:zero . ,cna-lisp.internal.ffi::+blend-zero+)
    (:source-color . ,cna-lisp.internal.ffi::+blend-source-color+)
    (:inverse-source-color . ,cna-lisp.internal.ffi::+blend-inverse-source-color+)
    (:source-alpha . ,cna-lisp.internal.ffi::+blend-source-alpha+)
    (:inverse-source-alpha . ,cna-lisp.internal.ffi::+blend-inverse-source-alpha+)
    (:destination-color . ,cna-lisp.internal.ffi::+blend-destination-color+)
    (:inverse-destination-color . ,cna-lisp.internal.ffi::+blend-inverse-destination-color+)
    (:destination-alpha . ,cna-lisp.internal.ffi::+blend-destination-alpha+)
    (:inverse-destination-alpha . ,cna-lisp.internal.ffi::+blend-inverse-destination-alpha+)
    (:blend-factor . ,cna-lisp.internal.ffi::+blend-factor+)
    (:inverse-blend-factor . ,cna-lisp.internal.ffi::+blend-inverse-factor+)
    (:source-alpha-saturation . ,cna-lisp.internal.ffi::+blend-source-alpha-saturation+)))

(defparameter %blend-function-to-native
  `((:add . ,cna-lisp.internal.ffi::+blend-function-add+)
    (:subtract . ,cna-lisp.internal.ffi::+blend-function-subtract+)
    (:reverse-subtract . ,cna-lisp.internal.ffi::+blend-function-reverse-subtract+)
    ;; The divergence. XNA numbers Min 3 and Max 4; CNA numbers them the other way
    ;; round. Mapping by name is what keeps a CNA-Lisp Min a minimum.
    (:min . ,cna-lisp.internal.ffi::+blend-function-min+)
    (:max . ,cna-lisp.internal.ffi::+blend-function-max+)))

(defparameter %compare-function-to-native
  `((:always . ,cna-lisp.internal.ffi::+compare-always+)
    (:never . ,cna-lisp.internal.ffi::+compare-never+)
    (:less . ,cna-lisp.internal.ffi::+compare-less+)
    (:less-equal . ,cna-lisp.internal.ffi::+compare-less-equal+)
    (:equal . ,cna-lisp.internal.ffi::+compare-equal+)
    (:greater-equal . ,cna-lisp.internal.ffi::+compare-greater-equal+)
    (:greater . ,cna-lisp.internal.ffi::+compare-greater+)
    (:not-equal . ,cna-lisp.internal.ffi::+compare-not-equal+)))

(defparameter %stencil-operation-to-native
  `((:keep . ,cna-lisp.internal.ffi::+stencil-keep+)
    (:zero . ,cna-lisp.internal.ffi::+stencil-zero+)
    (:replace . ,cna-lisp.internal.ffi::+stencil-replace+)
    (:increment . ,cna-lisp.internal.ffi::+stencil-increment+)
    (:decrement . ,cna-lisp.internal.ffi::+stencil-decrement+)
    (:increment-saturation . ,cna-lisp.internal.ffi::+stencil-increment-saturation+)
    (:decrement-saturation . ,cna-lisp.internal.ffi::+stencil-decrement-saturation+)
    (:invert . ,cna-lisp.internal.ffi::+stencil-invert+)))

(defparameter %cull-mode-to-native
  `((:none . ,cna-lisp.internal.ffi::+cull-none+)
    (:cull-clockwise-face . ,cna-lisp.internal.ffi::+cull-clockwise-face+)
    (:cull-counter-clockwise-face . ,cna-lisp.internal.ffi::+cull-counter-clockwise-face+)))

(defparameter %fill-mode-to-native
  `((:solid . ,cna-lisp.internal.ffi::+fill-solid+)
    (:wire-frame . ,cna-lisp.internal.ffi::+fill-wireframe+)))

(defparameter %texture-address-mode-to-native
  `((:wrap . ,cna-lisp.internal.ffi::+texture-address-wrap+)
    (:clamp . ,cna-lisp.internal.ffi::+texture-address-clamp+)
    (:mirror . ,cna-lisp.internal.ffi::+texture-address-mirror+)))

(defparameter %texture-filter-to-native
  `((:linear . ,cna-lisp.internal.ffi::+texture-filter-linear+)
    (:point . ,cna-lisp.internal.ffi::+texture-filter-point+)
    (:anisotropic . ,cna-lisp.internal.ffi::+texture-filter-anisotropic+)
    (:linear-mip-point . ,cna-lisp.internal.ffi::+texture-filter-linear-mip-point+)
    (:point-mip-linear . ,cna-lisp.internal.ffi::+texture-filter-point-mip-linear+)
    (:min-linear-mag-point-mip-linear
     . ,cna-lisp.internal.ffi::+texture-filter-min-linear-mag-point-mip-linear+)
    (:min-linear-mag-point-mip-point
     . ,cna-lisp.internal.ffi::+texture-filter-min-linear-mag-point-mip-point+)
    (:min-point-mag-linear-mip-linear
     . ,cna-lisp.internal.ffi::+texture-filter-min-point-mag-linear-mip-linear+)
    (:min-point-mag-linear-mip-point
     . ,cna-lisp.internal.ffi::+texture-filter-min-point-mag-linear-mip-point+)))

(defparameter %color-write-channel-to-native
  `((:none . ,cna-lisp.internal.ffi::+color-write-none+)
    (:red . ,cna-lisp.internal.ffi::+color-write-red+)
    (:green . ,cna-lisp.internal.ffi::+color-write-green+)
    (:blue . ,cna-lisp.internal.ffi::+color-write-blue+)
    (:alpha . ,cna-lisp.internal.ffi::+color-write-alpha+)
    (:all . ,cna-lisp.internal.ffi::+color-write-all+)))

(defun %native-of (table member what)
  (or (cdr (assoc member table))
      (error 'microsoft.xna.framework:cna-usage-error
             :operation what
             :format-control "~s is not a ~a member."
             :format-arguments (list member what))))

(defun %native-write-channels (value)
  "The CNA bit set for a ColorWriteChannels value, which may be a list or one member."
  (let ((members (if (listp value) value (list value))))
    (if (null members)
        cna-lisp.internal.ffi::+color-write-none+
        (reduce #'logior members :initial-value 0
                :key (lambda (m) (%native-of %color-write-channel-to-native m
                                             "color-write-channels"))))))

(defmacro %with-state-descriptor ((pointer struct size-constant) &body body)
  "Allocate one zeroed, versioned CNA state descriptor for the duration of BODY."
  `(cffi:with-foreign-object (,pointer '(:struct ,struct))
     (cffi:foreign-funcall "memset" :pointer ,pointer :int 0 :size ,size-constant :void)
     (setf (cffi:foreign-slot-value ,pointer '(:struct ,struct)
                                    'cna-lisp.internal.ffi::struct-size)
           ,size-constant
           (cffi:foreign-slot-value ,pointer '(:struct ,struct)
                                    'cna-lisp.internal.ffi::struct-version)
           1)
     ,@body))

(defun %write-blend-state (pointer state)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-blend-state) ',name)))
    (setf (slot cna-lisp.internal.ffi::color-source-blend)
          (%native-of %blend-to-native (color-source-blend state) "blend")
          (slot cna-lisp.internal.ffi::color-destination-blend)
          (%native-of %blend-to-native (color-destination-blend state) "blend")
          (slot cna-lisp.internal.ffi::color-blend-function)
          (%native-of %blend-function-to-native (color-blend-function state) "blend-function")
          (slot cna-lisp.internal.ffi::alpha-source-blend)
          (%native-of %blend-to-native (alpha-source-blend state) "blend")
          (slot cna-lisp.internal.ffi::alpha-destination-blend)
          (%native-of %blend-to-native (alpha-destination-blend state) "blend")
          (slot cna-lisp.internal.ffi::alpha-blend-function)
          (%native-of %blend-function-to-native (alpha-blend-function state) "blend-function")
          (slot cna-lisp.internal.ffi::color-write-channels)
          (%native-write-channels (color-write-channels state))
          (slot cna-lisp.internal.ffi::color-write-channels-1)
          (%native-write-channels (color-write-channels-1 state))
          (slot cna-lisp.internal.ffi::color-write-channels-2)
          (%native-write-channels (color-write-channels-2 state))
          (slot cna-lisp.internal.ffi::color-write-channels-3)
          (%native-write-channels (color-write-channels-3 state))
          (slot cna-lisp.internal.ffi::multi-sample-mask) (multi-sample-mask state)))
  (%write-packed-color pointer 'cna-lisp.internal.ffi::cna-blend-state
                       'cna-lisp.internal.ffi::blend-factor (blend-factor state))
  pointer)

(defun %write-depth-stencil-state (pointer state)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-depth-stencil-state) ',name))
             (compare (reader)
               `(%native-of %compare-function-to-native (,reader state) "compare-function"))
             (op (reader)
               `(%native-of %stencil-operation-to-native (,reader state) "stencil-operation")))
    (setf (slot cna-lisp.internal.ffi::depth-buffer-enable)
          (cna-lisp.internal.ffi:cna-bool-of (depth-buffer-enable state))
          (slot cna-lisp.internal.ffi::depth-buffer-write-enable)
          (cna-lisp.internal.ffi:cna-bool-of (depth-buffer-write-enable state))
          (slot cna-lisp.internal.ffi::stencil-enable)
          (cna-lisp.internal.ffi:cna-bool-of (stencil-enable state))
          (slot cna-lisp.internal.ffi::two-sided-stencil-mode)
          (cna-lisp.internal.ffi:cna-bool-of (two-sided-stencil-mode state))
          (slot cna-lisp.internal.ffi::depth-buffer-function) (compare depth-buffer-function)
          (slot cna-lisp.internal.ffi::stencil-function) (compare stencil-function)
          (slot cna-lisp.internal.ffi::stencil-mask) (stencil-mask state)
          (slot cna-lisp.internal.ffi::stencil-write-mask) (stencil-write-mask state)
          (slot cna-lisp.internal.ffi::reference-stencil) (reference-stencil state)
          (slot cna-lisp.internal.ffi::stencil-fail) (op stencil-fail)
          (slot cna-lisp.internal.ffi::stencil-depth-buffer-fail) (op stencil-depth-buffer-fail)
          (slot cna-lisp.internal.ffi::stencil-pass) (op stencil-pass)
          (slot cna-lisp.internal.ffi::counter-clockwise-stencil-function)
          (compare counter-clockwise-stencil-function)
          (slot cna-lisp.internal.ffi::counter-clockwise-stencil-fail)
          (op counter-clockwise-stencil-fail)
          (slot cna-lisp.internal.ffi::counter-clockwise-stencil-depth-buffer-fail)
          (op counter-clockwise-stencil-depth-buffer-fail)
          (slot cna-lisp.internal.ffi::counter-clockwise-stencil-pass)
          (op counter-clockwise-stencil-pass)))
  pointer)

(defun %write-rasterizer-state (pointer state)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-rasterizer-state) ',name)))
    (setf (slot cna-lisp.internal.ffi::cull-mode)
          (%native-of %cull-mode-to-native (cull-mode state) "cull-mode")
          (slot cna-lisp.internal.ffi::fill-mode)
          (%native-of %fill-mode-to-native (fill-mode state) "fill-mode")
          (slot cna-lisp.internal.ffi::depth-bias) (depth-bias state)
          (slot cna-lisp.internal.ffi::slope-scale-depth-bias) (slope-scale-depth-bias state)
          (slot cna-lisp.internal.ffi::multi-sample-anti-alias)
          (cna-lisp.internal.ffi:cna-bool-of (multi-sample-anti-alias state))
          (slot cna-lisp.internal.ffi::scissor-test-enable)
          (cna-lisp.internal.ffi:cna-bool-of (scissor-test-enable state))))
  pointer)

(defun %write-sampler-state (pointer state)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-sampler-state) ',name))
             (address (reader)
               `(%native-of %texture-address-mode-to-native (,reader state)
                            "texture-address-mode")))
    (setf (slot cna-lisp.internal.ffi::address-u) (address address-u)
          (slot cna-lisp.internal.ffi::address-v) (address address-v)
          (slot cna-lisp.internal.ffi::address-w) (address address-w)
          (slot cna-lisp.internal.ffi::filter)
          (%native-of %texture-filter-to-native (filter state) "texture-filter")
          (slot cna-lisp.internal.ffi::max-anisotropy) (max-anisotropy state)
          (slot cna-lisp.internal.ffi::max-mip-level) (max-mip-level state)
          (slot cna-lisp.internal.ffi::mip-map-level-of-detail-bias)
          (mip-map-level-of-detail-bias state)))
  pointer)

;;; --- reading a CNA descriptor back --------------------------------------------
;;;
;;; Only the reverse direction the device getters need. A CNA value that no XNA
;;; member names is a native error rather than a silently substituted default:
;;; answering a plausible member for a number the ABI did not promise would be
;;; the binding inventing a fact.

(defun %member-of (table value what)
  (or (car (rassoc value table))
      (error 'microsoft.xna.framework:cna-native-error
             :operation what
             :format-control "the native ~a value ~d names no ~a member."
             :format-arguments (list what value what))))

(defun %read-blend-state (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-blend-state) ',name)))
    (let ((state (make-instance 'blend-state)))
      (setf (slot-value state 'color-source-blend)
            (%member-of %blend-to-native (slot cna-lisp.internal.ffi::color-source-blend) "blend")
            (slot-value state 'color-destination-blend)
            (%member-of %blend-to-native
                        (slot cna-lisp.internal.ffi::color-destination-blend) "blend")
            (slot-value state 'color-blend-function)
            (%member-of %blend-function-to-native
                        (slot cna-lisp.internal.ffi::color-blend-function) "blend-function")
            (slot-value state 'alpha-source-blend)
            (%member-of %blend-to-native
                        (slot cna-lisp.internal.ffi::alpha-source-blend) "blend")
            (slot-value state 'alpha-destination-blend)
            (%member-of %blend-to-native
                        (slot cna-lisp.internal.ffi::alpha-destination-blend) "blend")
            (slot-value state 'alpha-blend-function)
            (%member-of %blend-function-to-native
                        (slot cna-lisp.internal.ffi::alpha-blend-function) "blend-function")
            (slot-value state 'color-write-channels)
            (%write-channels-of (slot cna-lisp.internal.ffi::color-write-channels))
            (slot-value state 'color-write-channels-1)
            (%write-channels-of (slot cna-lisp.internal.ffi::color-write-channels-1))
            (slot-value state 'color-write-channels-2)
            (%write-channels-of (slot cna-lisp.internal.ffi::color-write-channels-2))
            (slot-value state 'color-write-channels-3)
            (%write-channels-of (slot cna-lisp.internal.ffi::color-write-channels-3))
            (slot-value state 'multi-sample-mask)
            (slot cna-lisp.internal.ffi::multi-sample-mask)
            (slot-value state 'blend-factor)
            (microsoft.xna.framework:color-from-packed-value
             (cffi:mem-ref (cffi:foreign-slot-pointer
                            pointer '(:struct cna-lisp.internal.ffi::cna-blend-state)
                            'cna-lisp.internal.ffi::blend-factor)
                           :uint32)))
      state)))

(defun %write-channels-of (bits)
  "The ColorWriteChannels member list a CNA bit set names."
  (cond ((= bits cna-lisp.internal.ffi::+color-write-none+) '(:none))
        ((= bits cna-lisp.internal.ffi::+color-write-all+) '(:all))
        (t (loop for (member . value) in %color-write-channel-to-native
                 when (and (plusp value) (/= value cna-lisp.internal.ffi::+color-write-all+)
                           (= value (logand bits value)))
                   collect member))))

(defun %read-depth-stencil-state (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-depth-stencil-state) ',name))
             (compare (name)
               `(%member-of %compare-function-to-native (slot ,name) "compare-function"))
             (op (name)
               `(%member-of %stencil-operation-to-native (slot ,name) "stencil-operation"))
             (flag (name)
               `(cna-lisp.internal.ffi:cna-true-p (slot ,name))))
    (let ((state (make-instance 'depth-stencil-state)))
      (setf (slot-value state 'depth-buffer-enable)
            (flag cna-lisp.internal.ffi::depth-buffer-enable)
            (slot-value state 'depth-buffer-write-enable)
            (flag cna-lisp.internal.ffi::depth-buffer-write-enable)
            (slot-value state 'stencil-enable) (flag cna-lisp.internal.ffi::stencil-enable)
            (slot-value state 'two-sided-stencil-mode)
            (flag cna-lisp.internal.ffi::two-sided-stencil-mode)
            (slot-value state 'depth-buffer-function)
            (compare cna-lisp.internal.ffi::depth-buffer-function)
            (slot-value state 'stencil-function) (compare cna-lisp.internal.ffi::stencil-function)
            (slot-value state 'stencil-mask) (slot cna-lisp.internal.ffi::stencil-mask)
            (slot-value state 'stencil-write-mask)
            (slot cna-lisp.internal.ffi::stencil-write-mask)
            (slot-value state 'reference-stencil) (slot cna-lisp.internal.ffi::reference-stencil)
            (slot-value state 'stencil-fail) (op cna-lisp.internal.ffi::stencil-fail)
            (slot-value state 'stencil-depth-buffer-fail)
            (op cna-lisp.internal.ffi::stencil-depth-buffer-fail)
            (slot-value state 'stencil-pass) (op cna-lisp.internal.ffi::stencil-pass)
            (slot-value state 'counter-clockwise-stencil-function)
            (compare cna-lisp.internal.ffi::counter-clockwise-stencil-function)
            (slot-value state 'counter-clockwise-stencil-fail)
            (op cna-lisp.internal.ffi::counter-clockwise-stencil-fail)
            (slot-value state 'counter-clockwise-stencil-depth-buffer-fail)
            (op cna-lisp.internal.ffi::counter-clockwise-stencil-depth-buffer-fail)
            (slot-value state 'counter-clockwise-stencil-pass)
            (op cna-lisp.internal.ffi::counter-clockwise-stencil-pass))
      state)))

(defun %read-rasterizer-state (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-rasterizer-state) ',name)))
    (let ((state (make-instance 'rasterizer-state)))
      (setf (slot-value state 'cull-mode)
            (%member-of %cull-mode-to-native (slot cna-lisp.internal.ffi::cull-mode) "cull-mode")
            (slot-value state 'fill-mode)
            (%member-of %fill-mode-to-native (slot cna-lisp.internal.ffi::fill-mode) "fill-mode")
            (slot-value state 'depth-bias) (slot cna-lisp.internal.ffi::depth-bias)
            (slot-value state 'slope-scale-depth-bias)
            (slot cna-lisp.internal.ffi::slope-scale-depth-bias)
            (slot-value state 'multi-sample-anti-alias)
            (cna-lisp.internal.ffi:cna-true-p
             (slot cna-lisp.internal.ffi::multi-sample-anti-alias))
            (slot-value state 'scissor-test-enable)
            (cna-lisp.internal.ffi:cna-true-p (slot cna-lisp.internal.ffi::scissor-test-enable)))
      state)))

(defun %read-sampler-state (pointer)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-sampler-state) ',name))
             (address (name)
               `(%member-of %texture-address-mode-to-native (slot ,name)
                            "texture-address-mode")))
    (let ((state (make-instance 'sampler-state)))
      (setf (slot-value state 'address-u) (address cna-lisp.internal.ffi::address-u)
            (slot-value state 'address-v) (address cna-lisp.internal.ffi::address-v)
            (slot-value state 'address-w) (address cna-lisp.internal.ffi::address-w)
            (slot-value state 'filter)
            (%member-of %texture-filter-to-native (slot cna-lisp.internal.ffi::filter)
                        "texture-filter")
            (slot-value state 'max-anisotropy) (slot cna-lisp.internal.ffi::max-anisotropy)
            (slot-value state 'max-mip-level) (slot cna-lisp.internal.ffi::max-mip-level)
            (slot-value state 'mip-map-level-of-detail-bias)
            (slot cna-lisp.internal.ffi::mip-map-level-of-detail-bias))
      state)))
