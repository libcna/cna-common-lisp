;;;; basic-effect.lisp --- BasicEffect, DirectionalLight and the three IEffect*
;;;; contracts.
;;;;
;;;; XNA expresses the shared parts of the stock effects as three interfaces:
;;;; `IEffectMatrices' (World, View, Projection), `IEffectLights' (three
;;;; directional lights, an ambient colour, an enable flag and
;;;; `EnableDefaultLighting') and `IEffectFog' (enabled, start, end, colour).
;;;; Common Lisp has no interfaces and needs none: **the generic function is the
;;;; contract**, exactly as it is for `IVertexType', and CLOS dispatches it. Each
;;;; of the thirteen members below is a generic function specialised on EFFECT,
;;;; so a later stock effect implements them by inheriting, and a consumer's own
;;;; method makes their type satisfy the contract with nothing to declare.
;;;;
;;;; CNA models the same split, under the same names -- `cna_effect_matrices_*',
;;;; `cna_effect_lights_*', `cna_effect_fog_*' all take a plain effect handle --
;;;; so the projection is one route per member and no dispatch table.
;;;;
;;;; **The three matrix setters are the binding's only shimmed members besides
;;;; the viewport setter**, because CNA_Matrix is 64 bytes and the System V
;;;; AMD64 ABI passes it in memory. Everything else here binds directly,
;;;; including every colour: a CNA_Vector3 is 12 bytes and travels in two SSE
;;;; registers, which tools/native-abi/generate.py flattens and
;;;; tests/native/struct-passing.lisp proves.
;;;;
;;;; **DirectionalLight is a view, not a value.** XNA's `BasicEffect.
;;;; DirectionalLight0' answers an object whose setters reach back into the
;;;; effect; CNA's `cna_effect_lights_get_directional_light' answers an owned
;;;; stable member-view handle for exactly the same reason. The three views are
;;;; built once, with the effect, and the effect gives them back when it is
;;;; destroyed.

(in-package #:microsoft.xna.framework.graphics)

;;; --- DirectionalLight ------------------------------------------------------

(defclass directional-light (%effect-view)
  ((%index :initarg :index :reader %directional-light-index))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.DirectionalLight: one of the three lights an
IEffectLights effect carries.

Reached through DIRECTIONAL-LIGHT-0, -1 and -2 on the effect. XNA's public
constructor takes three EffectParameters and a source light, and clones a light
onto a *shader's own* parameters; CNA has no route that does that -- its lights
are member views of an effect -- so that constructor is recorded missing rather
than approximated."))

(macrolet
    ((define-vector3-property (name getter-route setter-route documentation)
       (let ((setf-name (intern (format nil "SET-~a" (symbol-name name)))))
         (declare (ignore setf-name))
         `(progn
            (defgeneric ,name (light)
              (:documentation ,documentation))
            (defgeneric (setf ,name) (value light)
              (:documentation ,(format nil "~a's setter." documentation)))
            (defmethod ,name ((light directional-light))
              (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-vector-3))
                (cna-lisp.internal:check-result
                 (,getter-route (%view-handle light ,(string-downcase (symbol-name name))) out)
                 ,(string-downcase (symbol-name name)) :object-type 'directional-light)
                (%read-vector3 out)))
            (defmethod (setf ,name) (value (light directional-light))
              (check-type value microsoft.xna.framework:vector3)
              (multiple-value-bind (xy z) (%vector3-eightbytes value)
                (cna-lisp.internal:check-result
                 (,setter-route (%view-handle light ,(string-downcase (symbol-name name)))
                                xy z)
                 ,(string-downcase (symbol-name name)) :object-type 'directional-light))
              value)))))
  (define-vector3-property directional-light-diffuse-color
      cna-lisp.internal.ffi::%directional-light-get-diffuse-color
      cna-lisp.internal.ffi::%directional-light-set-diffuse-color
      "DirectionalLight.DiffuseColor")
  (define-vector3-property directional-light-specular-color
      cna-lisp.internal.ffi::%directional-light-get-specular-color
      cna-lisp.internal.ffi::%directional-light-set-specular-color
      "DirectionalLight.SpecularColor")
  (define-vector3-property directional-light-direction
      cna-lisp.internal.ffi::%directional-light-get-direction
      cna-lisp.internal.ffi::%directional-light-set-direction
      "DirectionalLight.Direction"))

(defgeneric directional-light-enabled (light)
  (:documentation "DirectionalLight.Enabled."))

(defgeneric (setf directional-light-enabled) (value light)
  (:documentation "DirectionalLight.Enabled's setter."))

(defmethod directional-light-enabled ((light directional-light))
  (cffi:with-foreign-object (out :uint8)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%directional-light-get-enabled
      (%view-handle light "directional-light-enabled") out)
     "directional-light-enabled" :object-type 'directional-light)
    (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8))))

(defmethod (setf directional-light-enabled) (value (light directional-light))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%directional-light-set-enabled
    (%view-handle light "(setf directional-light-enabled)")
    (cna-lisp.internal.ffi:cna-bool-of value))
   "(setf directional-light-enabled)" :object-type 'directional-light)
  value)

;;; --- IEffectMatrices -------------------------------------------------------

(macrolet
    ((define-matrix-property (name getter-route shim-entry documentation)
       `(progn
          (defgeneric ,name (effect)
            (:documentation ,documentation))
          (defgeneric (setf ,name) (value effect)
            (:documentation
             ,(format nil "~a's setter.~%~%One of the four members that need the ~
optional private shim: the route takes CNA_Matrix by value, and the System V ~
AMD64 ABI passes a 64-byte aggregate in memory, which CFFI cannot do without ~
cffi-libffi. Without the shim it refuses with an actionable ~
CNA-NOT-SUPPORTED-ERROR; the reader works regardless." documentation)))
          (defmethod ,name ((effect effect))
            (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
            (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-matrix))
              (cna-lisp.internal:check-result
               (,getter-route (cna-lisp.internal:handle-of effect) out)
               ,(string-downcase (symbol-name name)) :object-type (type-of effect))
              (%read-matrix out)))
          (defmethod (setf ,name) (value (effect effect))
            (check-type value microsoft.xna.framework:matrix)
            (let ((entry (cna-lisp.internal:shim-entry-point ,shim-entry)))
              (unless entry
                (cna-lisp.internal:refuse-without-shim
                 ,(format nil "(setf ~a)" (string-downcase (symbol-name name)))
                 ,shim-entry +effect-matrix-shim-reason+))
              (cna-lisp.internal:check-usable
               effect ,(format nil "(setf ~a)" (string-downcase (symbol-name name))))
              (cffi:with-foreign-object (m '(:struct cna-lisp.internal.ffi::cna-matrix))
                (%write-matrix m value)
                (cna-lisp.internal:check-result
                 (cffi:foreign-funcall-pointer
                  entry ()
                  :pointer (cffi:foreign-symbol-pointer
                            ,(concatenate 'string "cna_effect_matrices_set_"
                                          (subseq (string-downcase (symbol-name name))
                                                  (length "effect-"))))
                  :uint64 (cna-lisp.internal:handle-of effect)
                  :pointer m
                  :uint32)
                 ,(format nil "(setf ~a)" (string-downcase (symbol-name name)))
                 :object-type (type-of effect))))
            value))))
  (define-matrix-property effect-world
      cna-lisp.internal.ffi::%effect-matrices-get-world
      "cna_lisp_shim_cna_effect_matrices_set_world"
      "IEffectMatrices.World")
  (define-matrix-property effect-view
      cna-lisp.internal.ffi::%effect-matrices-get-view
      "cna_lisp_shim_cna_effect_matrices_set_view"
      "IEffectMatrices.View")
  (define-matrix-property effect-projection
      cna-lisp.internal.ffi::%effect-matrices-get-projection
      "cna_lisp_shim_cna_effect_matrices_set_projection"
      "IEffectMatrices.Projection"))

;;; --- the effect scalar, boolean and colour properties ----------------------
;;;
;;; IEffectFog, IEffectLights and BasicEffect's own are the same three shapes
;;; over and over, so they are generated from one table each rather than typed
;;; out thirty times.

(defmacro %define-effect-boolean (name getter-route setter-route documentation
                                  &optional (class 'effect) (define-generic t))
  `(progn
     ,@(when define-generic
         `((defgeneric ,name (effect) (:documentation ,documentation))
           (defgeneric (setf ,name) (value effect)
             (:documentation ,(format nil "~a's setter." documentation)))))
     (defmethod ,name ((effect ,class))
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (cffi:with-foreign-object (out :uint8)
         (cna-lisp.internal:check-result
          (,getter-route (cna-lisp.internal:handle-of effect) out)
          ,(string-downcase (symbol-name name)) :object-type (type-of effect))
         (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8))))
     (defmethod (setf ,name) (value (effect ,class))
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (cna-lisp.internal:check-result
        (,setter-route (cna-lisp.internal:handle-of effect)
                       (cna-lisp.internal.ffi:cna-bool-of value))
        ,(string-downcase (symbol-name name)) :object-type (type-of effect))
       value)))

(defmacro %define-effect-single (name getter-route setter-route documentation
                                 &optional (class 'effect) (define-generic t))
  `(progn
     ,@(when define-generic
         `((defgeneric ,name (effect) (:documentation ,documentation))
           (defgeneric (setf ,name) (value effect)
             (:documentation ,(format nil "~a's setter." documentation)))))
     (defmethod ,name ((effect ,class))
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (cffi:with-foreign-object (out :float)
         (cna-lisp.internal:check-result
          (,getter-route (cna-lisp.internal:handle-of effect) out)
          ,(string-downcase (symbol-name name)) :object-type (type-of effect))
         (cffi:mem-ref out :float)))
     (defmethod (setf ,name) (value (effect ,class))
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (cna-lisp.internal:check-result
        (,setter-route (cna-lisp.internal:handle-of effect) (float value 1.0f0))
        ,(string-downcase (symbol-name name)) :object-type (type-of effect))
       value)))

(defmacro %define-effect-vector3 (name getter-route setter-route documentation
                                  &optional (class 'effect) (define-generic t))
  `(progn
     ,@(when define-generic
         `((defgeneric ,name (effect) (:documentation ,documentation))
           (defgeneric (setf ,name) (value effect)
             (:documentation ,(format nil "~a's setter." documentation)))))
     (defmethod ,name ((effect ,class))
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (cffi:with-foreign-object (out '(:struct cna-lisp.internal.ffi::cna-vector-3))
         (cna-lisp.internal:check-result
          (,getter-route (cna-lisp.internal:handle-of effect) out)
          ,(string-downcase (symbol-name name)) :object-type (type-of effect))
         (%read-vector3 out)))
     (defmethod (setf ,name) (value (effect ,class))
       (check-type value microsoft.xna.framework:vector3)
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (multiple-value-bind (xy z) (%vector3-eightbytes value)
         (cna-lisp.internal:check-result
          (,setter-route (cna-lisp.internal:handle-of effect) xy z)
          ,(string-downcase (symbol-name name)) :object-type (type-of effect)))
       value)))

;;; IEffectFog
(%define-effect-boolean effect-fog-enabled
    cna-lisp.internal.ffi::%effect-fog-get-enabled
    cna-lisp.internal.ffi::%effect-fog-set-enabled
    "IEffectFog.FogEnabled")
(%define-effect-single effect-fog-start
    cna-lisp.internal.ffi::%effect-fog-get-start
    cna-lisp.internal.ffi::%effect-fog-set-start
    "IEffectFog.FogStart")
(%define-effect-single effect-fog-end
    cna-lisp.internal.ffi::%effect-fog-get-end
    cna-lisp.internal.ffi::%effect-fog-set-end
    "IEffectFog.FogEnd")
(%define-effect-vector3 effect-fog-color
    cna-lisp.internal.ffi::%effect-fog-get-color
    cna-lisp.internal.ffi::%effect-fog-set-color
    "IEffectFog.FogColor")

;;; --- IEffectLights, as a class rather than as every effect -------------------
;;;
;;; The other two contracts are specialised on EFFECT, because CNA's
;;; `cna_effect_matrices_*' and `cna_effect_fog_*' take any effect handle and
;;; every stock effect in the selection implements both. Lighting is not like
;;; that: `AlphaTestEffect' and `DualTextureEffect' implement neither
;;; `IEffectLights' nor any part of it, and a generic function specialised on
;;; EFFECT would have answered for them -- an applicable method for a member XNA
;;; has not got. So the lights live on a private mixin, and "implements
;;; IEffectLights" is a superclass rather than a hope.
;;;
;;; `LightingEnabled' is narrower still. `EnvironmentMapEffect' and
;;; `SkinnedEffect' implement `IEffectLights' *explicitly*, so their
;;; `LightingEnabled' is not part of their public contract and the pinned
;;; metadata does not list it; only `BasicEffect' has it publicly, and only
;;; BASIC-EFFECT answers it here.

(defclass %effect-with-lights (effect)
  ((%lights :initform #() :accessor %effect-lights))
  (:documentation
   "Private base of the effects whose public contract carries IEffectLights'
ambient colour, three directional lights and EnableDefaultLighting."))

(%define-effect-vector3 effect-ambient-light-color
    cna-lisp.internal.ffi::%effect-lights-get-ambient-color
    cna-lisp.internal.ffi::%effect-lights-set-ambient-color
    "IEffectLights.AmbientLightColor"
    %effect-with-lights)

;;; --- BasicEffect -----------------------------------------------------------

(defclass basic-effect (%effect-with-lights)
  ((%texture :initform nil :accessor %basic-effect-texture))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.BasicEffect.

    (make-instance 'basic-effect :graphics-device device)

The stock effect XNA gives a game that wants transforms, lighting, fog, a
texture and per-vertex colour without writing a shader. It satisfies all three of
IEffectMatrices, IEffectLights and IEffectFog, which here means the thirteen
generic functions those interfaces became answer for it.

**This is what makes a primitive draw legal.** CNA, like XNA's own
`VerifyCanDraw', refuses a draw until an effect pass has been applied:

    (setf (effect-vertex-color-enabled effect) t
          (effect-lighting-enabled effect) nil)
    (dolist (pass (collection-elements
                   (effect-technique-passes (effect-current-technique effect))))
      (apply-effect-pass pass)
      (draw-user-primitives device :triangle-list triangle :primitive-count 1))"))

(defmethod %effect-takes-code-p ((effect basic-effect)) nil)

(defmethod %create-effect-handle ((effect basic-effect) device-handle effect-code)
  (declare (ignore effect-code))
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%basic-effect-create device-handle out)
     "make-instance 'basic-effect" :object-type 'basic-effect)
    (cffi:mem-ref out :uint64)))

(defmethod %build-effect-extras ((effect %effect-with-lights))
  (%build-directional-lights effect))

(defun %build-directional-lights (effect)
  "Take the three stable light views once, as XNA's BasicEffect does."
  (let ((lights (make-array 3)))
    (dotimes (index 3)
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%effect-lights-get-directional-light
          (cna-lisp.internal:handle-of effect) index out)
         "directional lights" :object-type (type-of effect))
        (let ((light (make-instance 'directional-light
                                    :handle (cffi:mem-ref out :uint64)
                                    :effect effect :index index)))
          (%retain-native-part effect (cna-lisp.internal:handle-of light)
                               #'cna-lisp.internal.ffi::%directional-light-destroy)
          (%adopt-view light effect)
          (setf (aref lights index) light))))
    (setf (%effect-lights effect) lights)))

(macrolet ((define-light-reader (name index)
             `(progn
                (defgeneric ,name (effect)
                  (:documentation
                   ,(format nil "IEffectLights.DirectionalLight~d." index)))
                (defmethod ,name ((effect %effect-with-lights))
                  (cna-lisp.internal:check-live
                   effect ,(string-downcase (symbol-name name)))
                  (aref (%effect-lights effect) ,index)))))
  (define-light-reader directional-light-0 0)
  (define-light-reader directional-light-1 1)
  (define-light-reader directional-light-2 2))

;;; BasicEffect's own
(%define-effect-single effect-alpha
    cna-lisp.internal.ffi::%basic-effect-get-alpha
    cna-lisp.internal.ffi::%basic-effect-set-alpha
    "BasicEffect.Alpha"
    basic-effect)
(%define-effect-single effect-specular-power
    cna-lisp.internal.ffi::%basic-effect-get-specular-power
    cna-lisp.internal.ffi::%basic-effect-set-specular-power
    "BasicEffect.SpecularPower"
    basic-effect)
(%define-effect-vector3 effect-diffuse-color
    cna-lisp.internal.ffi::%basic-effect-get-diffuse-color
    cna-lisp.internal.ffi::%basic-effect-set-diffuse-color
    "BasicEffect.DiffuseColor"
    basic-effect)
(%define-effect-vector3 effect-emissive-color
    cna-lisp.internal.ffi::%basic-effect-get-emissive-color
    cna-lisp.internal.ffi::%basic-effect-set-emissive-color
    "BasicEffect.EmissiveColor"
    basic-effect)
(%define-effect-vector3 effect-specular-color
    cna-lisp.internal.ffi::%basic-effect-get-specular-color
    cna-lisp.internal.ffi::%basic-effect-set-specular-color
    "BasicEffect.SpecularColor"
    basic-effect)
(%define-effect-boolean effect-texture-enabled
    cna-lisp.internal.ffi::%basic-effect-get-texture-enabled
    cna-lisp.internal.ffi::%basic-effect-set-texture-enabled
    "BasicEffect.TextureEnabled"
    basic-effect)
(%define-effect-boolean effect-vertex-color-enabled
    cna-lisp.internal.ffi::%basic-effect-get-vertex-color-enabled
    cna-lisp.internal.ffi::%basic-effect-set-vertex-color-enabled
    "BasicEffect.VertexColorEnabled"
    basic-effect)
(%define-effect-boolean effect-prefer-per-pixel-lighting
    cna-lisp.internal.ffi::%basic-effect-get-prefer-per-pixel-lighting
    cna-lisp.internal.ffi::%basic-effect-set-prefer-per-pixel-lighting
    "BasicEffect.PreferPerPixelLighting"
    basic-effect)
(%define-effect-boolean effect-lighting-enabled
    cna-lisp.internal.ffi::%effect-lights-get-enabled
    cna-lisp.internal.ffi::%effect-lights-set-enabled
    "IEffectLights.LightingEnabled"
    basic-effect)

(defgeneric enable-default-lighting (effect)
  (:documentation
   "IEffectLights.EnableDefaultLighting(): XNA's standard three-point rig.

The values are the runtime's, not this binding's: CNA applies its own preset
through cna_effect_lights_enable_default, and CNA-Lisp does not second-guess it
with numbers copied out of a decompiler."))

(defmethod enable-default-lighting ((effect %effect-with-lights))
  (cna-lisp.internal:check-usable effect "enable-default-lighting")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%effect-lights-enable-default (cna-lisp.internal:handle-of effect))
   "enable-default-lighting" :object-type (type-of effect))
  (values))

;;; --- BasicEffect.Texture ---------------------------------------------------

(defgeneric effect-texture (effect)
  (:documentation
   "BasicEffect.Texture.

Answers the TEXTURE-2D this effect was last given, cross-checked against the
handle CNA reports. As with EFFECT-PARAMETER-VALUE-TEXTURE and
GET-VERTEX-BUFFERS, CNA's ABI has no route from a native handle back to the
object that names it, so this remembers rather than invents."))

(defgeneric (setf effect-texture) (texture effect)
  (:documentation "BasicEffect.Texture's setter. NIL clears it."))

(defun %effect-texture-of (effect route remembered operation)
  "The Texture2D behind a stock effect's texture property.

Shared by every stock effect that has one, because the reasoning is the same for
all of them: CNA answers a handle, its ABI has no route from a handle back to the
object that names it, so this compares the handle against the object the setter
remembered and refuses rather than inventing a Texture2D."
  (cna-lisp.internal:check-usable effect operation)
  (cffi:with-foreign-objects ((out :uint64) (has :uint8))
    (cna-lisp.internal:check-result
     (funcall route (cna-lisp.internal:handle-of effect) has out)
     operation :object-type (type-of effect))
    (let ((native (if (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref has :uint8))
                      (cffi:mem-ref out :uint64)
                      0)))
      (cond ((zerop native) nil)
            ((and remembered
                  (not (microsoft.xna.framework:disposed-p remembered))
                  (= native (cna-lisp.internal:handle-of remembered)))
             remembered)
            (t
             (error 'microsoft.xna.framework:cna-invalid-state-error
                    :operation operation :object-type (type-of effect)
                    :format-control
                    "CNA reports a texture on this effect that this binding did not ~
                     set. There is no way back from a native texture handle to the ~
                     object that names it, so this refuses rather than answering a ~
                     Texture2D it would have to invent."))))))

(defun %set-effect-texture (effect route texture operation)
  "Assign or clear a stock effect's texture. NIL is CNA_INVALID_HANDLE."
  (cna-lisp.internal:check-usable effect operation)
  (when texture (check-type texture texture-2d))
  (cna-lisp.internal:check-result
   (funcall route
            (cna-lisp.internal:handle-of effect)
            (if texture
                (progn (cna-lisp.internal:check-usable texture operation)
                       (cna-lisp.internal:handle-of texture))
                0))
   operation :object-type (type-of effect))
  texture)

(defmethod effect-texture ((effect basic-effect))
  (%effect-texture-of effect #'cna-lisp.internal.ffi::%basic-effect-get-texture
                      (%basic-effect-texture effect) "effect-texture"))

(defmethod (setf effect-texture) (texture (effect basic-effect))
  (setf (%basic-effect-texture effect)
        (%set-effect-texture effect #'cna-lisp.internal.ffi::%basic-effect-set-texture
                             texture "(setf effect-texture)")))

(defmethod cna-lisp.internal:destroy-native :before ((effect %effect-with-lights))
  ;; The handles themselves are on the effect's ledger, released with everything
  ;; else; this only drops the Lisp objects that named them.
  (setf (%effect-lights effect) #()))

(defmethod clone-effect ((effect basic-effect))
  ;; The lights come with the graph; the remembered texture does not, because it
  ;; is a Lisp-side note about which object a handle stands for.
  (let ((clone (call-next-method)))
    (setf (%basic-effect-texture clone) (%basic-effect-texture effect))
    clone))
