;;;; stock-effects.lisp --- AlphaTestEffect, DualTextureEffect and SkinnedEffect.
;;;;
;;;; Three more of XNA's built-in effects, over the same `Effect' machinery
;;;; `BasicEffect' already uses: the same handle ledger, the same construction
;;;; rollback, the same technique/pass/parameter graph, the same disposal. Each
;;;; adds a `%create-effect-handle' method naming its own CNA create route and
;;;; the properties its own contract has, and inherits everything else.
;;;;
;;;; **They do not differ only by property count.** Reading each type's pinned
;;;; metadata separately is what shows it:
;;;;
;;;; * `AlphaTestEffect' and `DualTextureEffect' implement `IEffectFog' and
;;;;   `IEffectMatrices' and **not** `IEffectLights' -- no ambient colour, no
;;;;   directional lights, no `EnableDefaultLighting'. That is why the lights are
;;;;   on a private mixin rather than on `Effect': a generic function specialised
;;;;   on `Effect' would have given these two an applicable method for a member
;;;;   they have not got.
;;;; * `SkinnedEffect' implements `IEffectLights', but *explicitly*, so
;;;;   `LightingEnabled' is not in its public contract -- and it is the only
;;;;   effect here with a bone palette, a weights-per-vertex setting and a public
;;;;   constant.
;;;; * `AlphaTestEffect' is the only one with a comparison function and a
;;;;   reference alpha; `DualTextureEffect' is the only one with two texture
;;;;   layers and has neither an emissive nor a specular colour.
;;;;
;;;; `EnvironmentMapEffect' is the fourth stock effect and is **not** here: its
;;;; `EnvironmentMap' is a `TextureCube', which this milestone does not project,
;;;; and a closure is added only when every member of it can be finished. See
;;;; `docs/limitations.md'.

(in-package #:microsoft.xna.framework.graphics)

;;; --- shapes the three share, and BasicEffect did not need -------------------

(defmacro %define-effect-int32 (name getter-route setter-route documentation class)
  "An Int32 effect property. `ReferenceAlpha' and `WeightsPerVertex' are the two."
  `(progn
     (defgeneric ,name (effect) (:documentation ,documentation))
     (defgeneric (setf ,name) (value effect)
       (:documentation ,(format nil "~a's setter." documentation)))
     (defmethod ,name ((effect ,class))
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (cffi:with-foreign-object (out :int32)
         (cna-lisp.internal:check-result
          (,getter-route (cna-lisp.internal:handle-of effect) out)
          ,(string-downcase (symbol-name name)) :object-type (type-of effect))
         (cffi:mem-ref out :int32)))
     (defmethod (setf ,name) (value (effect ,class))
       (check-type value (signed-byte 32))
       (cna-lisp.internal:check-usable effect ,(string-downcase (symbol-name name)))
       (cna-lisp.internal:check-result
        (,setter-route (cna-lisp.internal:handle-of effect) value)
        ,(string-downcase (symbol-name name)) :object-type (type-of effect))
       value)))

;;; --- AlphaTestEffect --------------------------------------------------------

(defclass alpha-test-effect (effect)
  ((%texture :initform nil :accessor %alpha-test-effect-texture))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.AlphaTestEffect.

    (make-instance 'alpha-test-effect :graphics-device device)

Transforms, fog, a texture, per-vertex colour and an alpha test. It satisfies
IEffectMatrices and IEffectFog and **not** IEffectLights, so EFFECT-AMBIENT-LIGHT-COLOR,
DIRECTIONAL-LIGHT-0 and ENABLE-DEFAULT-LIGHTING have no applicable method for it,
exactly as XNA has no such member on it."))

(defmethod %effect-takes-code-p ((effect alpha-test-effect)) nil)

(defmethod %create-effect-handle ((effect alpha-test-effect) device-handle effect-code)
  (declare (ignore effect-code))
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%alpha-test-effect-create device-handle out)
     "make-instance 'alpha-test-effect" :object-type 'alpha-test-effect)
    (cffi:mem-ref out :uint64)))

(%define-effect-single effect-alpha
    cna-lisp.internal.ffi::%alpha-test-effect-get-alpha
    cna-lisp.internal.ffi::%alpha-test-effect-set-alpha
    "AlphaTestEffect.Alpha"
    alpha-test-effect nil)
(%define-effect-vector3 effect-diffuse-color
    cna-lisp.internal.ffi::%alpha-test-effect-get-diffuse-color
    cna-lisp.internal.ffi::%alpha-test-effect-set-diffuse-color
    "AlphaTestEffect.DiffuseColor"
    alpha-test-effect nil)
(%define-effect-boolean effect-vertex-color-enabled
    cna-lisp.internal.ffi::%alpha-test-effect-get-vertex-color-enabled
    cna-lisp.internal.ffi::%alpha-test-effect-set-vertex-color-enabled
    "AlphaTestEffect.VertexColorEnabled"
    alpha-test-effect nil)
(%define-effect-int32 effect-reference-alpha
    cna-lisp.internal.ffi::%alpha-test-effect-get-reference-alpha
    cna-lisp.internal.ffi::%alpha-test-effect-set-reference-alpha
    "AlphaTestEffect.ReferenceAlpha, which XNA stores without clamping."
    alpha-test-effect)

(defgeneric effect-alpha-function (effect)
  (:documentation
   "AlphaTestEffect.AlphaFunction: the comparison the alpha test performs.

A CompareFunction, translated **by name** through the projected enumeration
rather than passed through as an integer. Every enumeration in this binding does
that, for the reason `BlendFunction' gives: XNA numbers Min 3 and Max 4 and CNA
numbers them the other way round, so a numeric pass-through happens to work
everywhere else and turns a minimum into a maximum there."))

(defgeneric (setf effect-alpha-function) (value effect)
  (:documentation "AlphaTestEffect.AlphaFunction's setter."))

(defmethod effect-alpha-function ((effect alpha-test-effect))
  (cna-lisp.internal:check-usable effect "effect-alpha-function")
  (cffi:with-foreign-object (out :uint32)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%alpha-test-effect-get-alpha-function
      (cna-lisp.internal:handle-of effect) out)
     "effect-alpha-function" :object-type 'alpha-test-effect)
    (compare-function-from-value (cffi:mem-ref out :uint32))))

(defmethod (setf effect-alpha-function) (value (effect alpha-test-effect))
  (check-type value compare-function)
  (cna-lisp.internal:check-usable effect "(setf effect-alpha-function)")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%alpha-test-effect-set-alpha-function
    (cna-lisp.internal:handle-of effect) (compare-function-value value))
   "(setf effect-alpha-function)" :object-type 'alpha-test-effect)
  value)

(defmethod effect-texture ((effect alpha-test-effect))
  (%effect-texture-of effect #'cna-lisp.internal.ffi::%alpha-test-effect-get-texture
                      (%alpha-test-effect-texture effect) "effect-texture"))

(defmethod (setf effect-texture) (texture (effect alpha-test-effect))
  (setf (%alpha-test-effect-texture effect)
        (%set-effect-texture effect #'cna-lisp.internal.ffi::%alpha-test-effect-set-texture
                             texture "(setf effect-texture)")))

(defmethod clone-effect ((effect alpha-test-effect))
  (let ((clone (call-next-method)))
    (setf (%alpha-test-effect-texture clone) (%alpha-test-effect-texture effect))
    clone))

;;; --- DualTextureEffect ------------------------------------------------------

(defclass dual-texture-effect (effect)
  ((%textures :initform (vector nil nil) :accessor %dual-texture-effect-textures))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.DualTextureEffect.

    (make-instance 'dual-texture-effect :graphics-device device)

Two texture layers blended together, with transforms, fog and per-vertex colour.
Like ALPHA-TEST-EFFECT it satisfies IEffectMatrices and IEffectFog and not
IEffectLights, and unlike every other stock effect here it has neither an
emissive nor a specular colour.

XNA spells its two layers as two properties, `Texture' and `Texture2'; CNA spells
them as one route taking a layer index of zero or one. The two are mapped by an
explicit pair of methods rather than by exposing the index, because XNA's public
surface has no index and inventing one would be inventing a member."))

(defmethod %effect-takes-code-p ((effect dual-texture-effect)) nil)

(defmethod %create-effect-handle ((effect dual-texture-effect) device-handle effect-code)
  (declare (ignore effect-code))
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%dual-texture-effect-create device-handle out)
     "make-instance 'dual-texture-effect" :object-type 'dual-texture-effect)
    (cffi:mem-ref out :uint64)))

(%define-effect-single effect-alpha
    cna-lisp.internal.ffi::%dual-texture-effect-get-alpha
    cna-lisp.internal.ffi::%dual-texture-effect-set-alpha
    "DualTextureEffect.Alpha"
    dual-texture-effect nil)
(%define-effect-vector3 effect-diffuse-color
    cna-lisp.internal.ffi::%dual-texture-effect-get-diffuse-color
    cna-lisp.internal.ffi::%dual-texture-effect-set-diffuse-color
    "DualTextureEffect.DiffuseColor"
    dual-texture-effect nil)
(%define-effect-boolean effect-vertex-color-enabled
    cna-lisp.internal.ffi::%dual-texture-effect-get-vertex-color-enabled
    cna-lisp.internal.ffi::%dual-texture-effect-set-vertex-color-enabled
    "DualTextureEffect.VertexColorEnabled"
    dual-texture-effect nil)

(defun %dual-texture-layer (effect layer operation)
  (cna-lisp.internal:check-usable effect operation)
  (cffi:with-foreign-objects ((out :uint64) (has :uint8))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%dual-texture-effect-get-texture
      (cna-lisp.internal:handle-of effect) layer has out)
     operation :object-type 'dual-texture-effect)
    (let ((native (if (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref has :uint8))
                      (cffi:mem-ref out :uint64)
                      0))
          (remembered (aref (%dual-texture-effect-textures effect) layer)))
      (cond ((zerop native) nil)
            ((and remembered
                  (not (microsoft.xna.framework:disposed-p remembered))
                  (= native (cna-lisp.internal:handle-of remembered)))
             remembered)
            (t
             (error 'microsoft.xna.framework:cna-invalid-state-error
                    :operation operation :object-type 'dual-texture-effect
                    :format-control
                    "CNA reports a texture on layer ~d that this binding did not set. ~
                     There is no way back from a native texture handle to the object ~
                     that names it, so this refuses rather than answering a Texture2D ~
                     it would have to invent."
                    :format-arguments (list layer)))))))

(defun %set-dual-texture-layer (effect layer texture operation)
  (cna-lisp.internal:check-usable effect operation)
  (when texture (check-type texture texture-2d))
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%dual-texture-effect-set-texture
    (cna-lisp.internal:handle-of effect) layer
    (if texture
        (progn (cna-lisp.internal:check-usable texture operation)
               (cna-lisp.internal:handle-of texture))
        0))
   operation :object-type 'dual-texture-effect)
  (setf (aref (%dual-texture-effect-textures effect) layer) texture))

(defmethod effect-texture ((effect dual-texture-effect))
  (%dual-texture-layer effect 0 "effect-texture"))

(defmethod (setf effect-texture) (texture (effect dual-texture-effect))
  (%set-dual-texture-layer effect 0 texture "(setf effect-texture)"))

(defgeneric effect-texture-2 (effect)
  (:documentation
   "DualTextureEffect.Texture2: the second texture layer.

CNA's layer one. A separate generic function rather than an index argument,
because XNA's public surface has two properties and no index."))

(defgeneric (setf effect-texture-2) (texture effect)
  (:documentation "DualTextureEffect.Texture2's setter. NIL clears it."))

(defmethod effect-texture-2 ((effect dual-texture-effect))
  (%dual-texture-layer effect 1 "effect-texture-2"))

(defmethod (setf effect-texture-2) (texture (effect dual-texture-effect))
  (%set-dual-texture-layer effect 1 texture "(setf effect-texture-2)"))

(defmethod clone-effect ((effect dual-texture-effect))
  (let ((clone (call-next-method)))
    (setf (%dual-texture-effect-textures clone)
          (copy-seq (%dual-texture-effect-textures effect)))
    clone))

;;; --- SkinnedEffect ----------------------------------------------------------

(defconstant +skinned-effect-max-bones+ cna-lisp.internal.ffi::+skinned-effect-max-bones+
  "SkinnedEffect.MaxBones: the largest bone palette the effect can hold.

XNA's is a public const field. The value here is read from the CNA header rather
than written down, and the two agree at 72; a build whose header said otherwise
would change this constant rather than leave it wrong.")

(defclass skinned-effect (%effect-with-lights)
  ((%texture :initform nil :accessor %skinned-effect-texture))
  (:documentation
   "Microsoft.Xna.Framework.Graphics.SkinnedEffect.

    (make-instance 'skinned-effect :graphics-device device)

Skeletal animation: a palette of up to +SKINNED-EFFECT-MAX-BONES+ bone
transforms, one to four weights per vertex, and the lighting, fog, transform and
material surface of a stock effect.

It implements IEffectLights, so it answers EFFECT-AMBIENT-LIGHT-COLOR, the three
directional lights and ENABLE-DEFAULT-LIGHTING. It does **not** answer
EFFECT-LIGHTING-ENABLED: XNA implements that member of the interface explicitly,
so it is not part of SkinnedEffect's public contract and the pinned metadata does
not list it."))

(defmethod %effect-takes-code-p ((effect skinned-effect)) nil)

(defmethod %create-effect-handle ((effect skinned-effect) device-handle effect-code)
  (declare (ignore effect-code))
  (cffi:with-foreign-object (out :uint64)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%skinned-effect-create device-handle out)
     "make-instance 'skinned-effect" :object-type 'skinned-effect)
    (cffi:mem-ref out :uint64)))

(%define-effect-single effect-alpha
    cna-lisp.internal.ffi::%skinned-effect-get-alpha
    cna-lisp.internal.ffi::%skinned-effect-set-alpha
    "SkinnedEffect.Alpha"
    skinned-effect nil)
(%define-effect-single effect-specular-power
    cna-lisp.internal.ffi::%skinned-effect-get-specular-power
    cna-lisp.internal.ffi::%skinned-effect-set-specular-power
    "SkinnedEffect.SpecularPower"
    skinned-effect nil)
(%define-effect-vector3 effect-diffuse-color
    cna-lisp.internal.ffi::%skinned-effect-get-diffuse-color
    cna-lisp.internal.ffi::%skinned-effect-set-diffuse-color
    "SkinnedEffect.DiffuseColor"
    skinned-effect nil)
(%define-effect-vector3 effect-emissive-color
    cna-lisp.internal.ffi::%skinned-effect-get-emissive-color
    cna-lisp.internal.ffi::%skinned-effect-set-emissive-color
    "SkinnedEffect.EmissiveColor"
    skinned-effect nil)
(%define-effect-vector3 effect-specular-color
    cna-lisp.internal.ffi::%skinned-effect-get-specular-color
    cna-lisp.internal.ffi::%skinned-effect-set-specular-color
    "SkinnedEffect.SpecularColor"
    skinned-effect nil)
(%define-effect-boolean effect-vertex-color-enabled
    cna-lisp.internal.ffi::%skinned-effect-get-vertex-color-enabled
    cna-lisp.internal.ffi::%skinned-effect-set-vertex-color-enabled
    "SkinnedEffect.VertexColorEnabled"
    skinned-effect nil)
(%define-effect-boolean effect-prefer-per-pixel-lighting
    cna-lisp.internal.ffi::%skinned-effect-get-prefer-per-pixel-lighting
    cna-lisp.internal.ffi::%skinned-effect-set-prefer-per-pixel-lighting
    "SkinnedEffect.PreferPerPixelLighting"
    skinned-effect nil)
(%define-effect-int32 effect-weights-per-vertex
    cna-lisp.internal.ffi::%skinned-effect-get-weights-per-vertex
    cna-lisp.internal.ffi::%skinned-effect-set-weights-per-vertex
    "SkinnedEffect.WeightsPerVertex: one, two or four."
    skinned-effect)

(defmethod effect-texture ((effect skinned-effect))
  (%effect-texture-of effect #'cna-lisp.internal.ffi::%skinned-effect-get-texture
                      (%skinned-effect-texture effect) "effect-texture"))

(defmethod (setf effect-texture) (texture (effect skinned-effect))
  (setf (%skinned-effect-texture effect)
        (%set-effect-texture effect #'cna-lisp.internal.ffi::%skinned-effect-set-texture
                             texture "(setf effect-texture)")))

(defgeneric set-bone-transforms (effect transforms)
  (:documentation
   "SkinnedEffect.SetBoneTransforms(Matrix[]).

TRANSFORMS is a sequence of at least one and at most +SKINNED-EFFECT-MAX-BONES+
matrices, and it is copied: CNA takes the array by pointer and reads it during
the call, so nothing of the caller's is retained."))

(defgeneric get-bone-transforms (effect count)
  (:documentation
   "SkinnedEffect.GetBoneTransforms(Int32): the leading COUNT bone transforms.

Answers a fresh simple vector of COUNT matrices. XNA answers a `Matrix[]', and
this copies for the same reason `VertexDeclaration.GetVertexElements' does:
a caller must not be able to reach back into the effect through what it was
given."))

(defmethod set-bone-transforms ((effect skinned-effect) transforms)
  (cna-lisp.internal:check-usable effect "set-bone-transforms")
  (let* ((matrices (coerce transforms 'vector))
         (count (length matrices)))
    (unless (<= 1 count +skinned-effect-max-bones+)
      (error 'microsoft.xna.framework:cna-argument-out-of-range-error
             :operation "set-bone-transforms" :parameter-name "transforms"
             :format-control
             "a bone palette holds between one and ~d transforms; ~d were given."
             :format-arguments (list +skinned-effect-max-bones+ count)))
    (cffi:with-foreign-object (array '(:struct cna-lisp.internal.ffi::cna-matrix) count)
      (dotimes (index count)
        (let ((matrix (aref matrices index)))
          (check-type matrix microsoft.xna.framework:matrix)
          (%write-matrix (cffi:mem-aptr
                          array '(:struct cna-lisp.internal.ffi::cna-matrix) index)
                         matrix)))
      ;; By pointer, so unlike the three IEffectMatrices setters this needs no shim.
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%skinned-effect-set-bone-transforms
        (cna-lisp.internal:handle-of effect) array count)
       "set-bone-transforms" :object-type 'skinned-effect)))
  (values))

(defmethod get-bone-transforms ((effect skinned-effect) count)
  (check-type count (signed-byte 32))
  (cna-lisp.internal:check-usable effect "get-bone-transforms")
  (unless (<= 1 count +skinned-effect-max-bones+)
    (error 'microsoft.xna.framework:cna-argument-out-of-range-error
           :operation "get-bone-transforms" :parameter-name "count"
           :format-control
           "a bone palette holds between one and ~d transforms; ~d were asked for."
           :format-arguments (list +skinned-effect-max-bones+ count)))
  (cffi:with-foreign-object (array '(:struct cna-lisp.internal.ffi::cna-matrix) count)
    (cffi:with-foreign-object (written :uint64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%skinned-effect-copy-bone-transforms
        (cna-lisp.internal:handle-of effect) count array count written)
       "get-bone-transforms" :object-type 'skinned-effect)
      (let ((result (make-array (cffi:mem-ref written :uint64))))
        (dotimes (index (length result) result)
          (setf (aref result index)
                (%read-matrix (cffi:mem-aptr
                               array '(:struct cna-lisp.internal.ffi::cna-matrix)
                               index))))))))

(defmethod clone-effect ((effect skinned-effect))
  (let ((clone (call-next-method)))
    (setf (%skinned-effect-texture clone) (%skinned-effect-texture effect))
    clone))
