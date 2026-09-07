;;;; packages.lisp --- the public Common Lisp packages of CNA-Lisp.
;;;;
;;;; One XNA namespace maps to one Common Lisp package. The export lists below
;;;; are the whole public surface of CNA-Lisp: tests/structure/public-surface.lisp
;;;; reads them out of the live image and fails on any symbol it cannot account
;;;; for, and on any private symbol that has leaked into one of them.
;;;;
;;;; A consumer is expected to reach these through local nicknames:
;;;;
;;;;   (defpackage #:my-game
;;;;     (:use #:cl)
;;;;     (:local-nicknames (#:xna   #:microsoft.xna.framework)
;;;;                       (#:gfx   #:microsoft.xna.framework.graphics)
;;;;                       (#:input #:microsoft.xna.framework.input)))
;;;;
;;;; Nothing here mentions the CNA C ABI. See docs/common-lisp-mapping.md for the
;;;; rules these names follow.

(in-package #:cl-user)

(defpackage #:microsoft.xna.framework
  (:documentation "Common Lisp projection of the Microsoft.Xna.Framework namespace.")
  (:use #:cl)
  (:export
   ;; --- Point -------------------------------------------------------------
   #:point #:make-point #:point-p #:copy-point #:point-x #:point-y
   #:point-zero #:point-equal
   ;; --- Rectangle ---------------------------------------------------------
   #:rectangle #:make-rectangle #:rectangle-p #:copy-rectangle
   #:rectangle-x #:rectangle-y #:rectangle-width #:rectangle-height
   #:rectangle-left #:rectangle-right #:rectangle-top #:rectangle-bottom
   #:rectangle-center #:rectangle-location #:rectangle-is-empty #:rectangle-empty
   #:rectangle-contains #:rectangle-contains-coordinates #:rectangle-intersects
   #:rectangle-offset #:rectangle-offset-by-point #:rectangle-inflate
   #:rectangle-intersect #:rectangle-union #:rectangle-equal
   ;; --- Vector2 -----------------------------------------------------------
   #:vector2 #:make-vector2 #:vector2-p #:copy-vector2 #:vector2-x #:vector2-y
   #:vector2-zero #:vector2-one #:vector2-unit-x #:vector2-unit-y
   #:vector2-add #:vector2-subtract #:vector2-multiply #:vector2-divide
   #:vector2-negate #:vector2-length #:vector2-length-squared
   #:vector2-distance #:vector2-distance-squared #:vector2-dot
   #:vector2-normalize #:vector2-normalized #:vector2-equal #:vector2-reflect
   #:vector2-min #:vector2-max #:vector2-clamp
   #:vector2-lerp #:vector2-smooth-step #:vector2-barycentric
   #:vector2-catmull-rom #:vector2-hermite
   ;; --- Vector3 -----------------------------------------------------------
   #:vector3 #:make-vector3 #:vector3-p #:copy-vector3 #:make-vector3-from-vector2
   #:vector3-x #:vector3-y #:vector3-z
   #:vector3-zero #:vector3-one #:vector3-unit-x #:vector3-unit-y #:vector3-unit-z
   #:vector3-up #:vector3-down #:vector3-right #:vector3-left
   #:vector3-forward #:vector3-backward
   #:vector3-length #:vector3-length-squared
   #:vector3-distance #:vector3-distance-squared #:vector3-dot #:vector3-cross
   #:vector3-normalize #:vector3-normalized #:vector3-reflect
   #:vector3-add #:vector3-subtract #:vector3-negate
   #:vector3-multiply #:vector3-divide
   #:vector3-min #:vector3-max #:vector3-clamp
   #:vector3-lerp #:vector3-smooth-step #:vector3-barycentric
   #:vector3-catmull-rom #:vector3-hermite #:vector3-equal
   ;; --- Vector4 -----------------------------------------------------------
   #:vector4 #:make-vector4 #:vector4-p #:copy-vector4
   #:make-vector4-from-vector2 #:make-vector4-from-vector3
   #:vector4-x #:vector4-y #:vector4-z #:vector4-w
   #:vector4-zero #:vector4-one
   #:vector4-unit-x #:vector4-unit-y #:vector4-unit-z #:vector4-unit-w
   #:vector4-length #:vector4-length-squared
   #:vector4-distance #:vector4-distance-squared #:vector4-dot
   #:vector4-normalize #:vector4-normalized
   #:vector4-add #:vector4-subtract #:vector4-negate
   #:vector4-multiply #:vector4-divide
   #:vector4-min #:vector4-max #:vector4-clamp
   #:vector4-lerp #:vector4-smooth-step #:vector4-barycentric
   #:vector4-catmull-rom #:vector4-hermite #:vector4-equal
   ;; --- Quaternion --------------------------------------------------------
   #:quaternion #:make-quaternion #:quaternion-p #:copy-quaternion
   #:make-quaternion-from-vector3
   #:quaternion-x #:quaternion-y #:quaternion-z #:quaternion-w
   #:quaternion-identity #:quaternion-length #:quaternion-length-squared
   #:quaternion-normalize #:quaternion-normalized
   #:quaternion-conjugate #:quaternion-conjugated #:quaternion-inverse
   #:quaternion-dot #:quaternion-concatenate
   #:quaternion-create-from-axis-angle #:quaternion-create-from-yaw-pitch-roll
   #:quaternion-create-from-rotation-matrix
   #:quaternion-add #:quaternion-subtract #:quaternion-negate
   #:quaternion-multiply #:quaternion-divide
   #:quaternion-lerp #:quaternion-slerp #:quaternion-equal
   ;; --- Matrix ------------------------------------------------------------
   #:matrix #:make-matrix #:matrix-p #:copy-matrix #:matrix-identity
   #:matrix-m11 #:matrix-m12 #:matrix-m13 #:matrix-m14
   #:matrix-m21 #:matrix-m22 #:matrix-m23 #:matrix-m24
   #:matrix-m31 #:matrix-m32 #:matrix-m33 #:matrix-m34
   #:matrix-m41 #:matrix-m42 #:matrix-m43 #:matrix-m44
   #:matrix-up #:matrix-down #:matrix-right #:matrix-left
   #:matrix-forward #:matrix-backward #:matrix-translation
   #:matrix-create-translation #:matrix-create-scale
   #:matrix-create-rotation-x #:matrix-create-rotation-y #:matrix-create-rotation-z
   #:matrix-create-from-axis-angle #:matrix-create-from-quaternion
   #:matrix-create-from-yaw-pitch-roll
   #:matrix-create-perspective-field-of-view #:matrix-create-perspective
   #:matrix-create-perspective-off-center
   #:matrix-create-orthographic #:matrix-create-orthographic-off-center
   #:matrix-create-look-at #:matrix-create-world #:matrix-create-billboard
   #:matrix-create-constrained-billboard #:matrix-decompose
   #:matrix-transpose #:matrix-determinant #:matrix-invert
   #:matrix-add #:matrix-subtract #:matrix-negate
   #:matrix-multiply #:matrix-divide #:matrix-lerp #:matrix-transform
   #:matrix-equal
   ;; --- Plane and the geometry enums --------------------------------------
   #:plane #:make-plane #:plane-p #:copy-plane
   #:make-plane-from-normal #:make-plane-from-vector4 #:make-plane-from-points
   #:plane-normal #:plane-d #:+plane-normalize-epsilon+
   #:plane-normalize #:plane-normalized
   #:plane-dot #:plane-dot-coordinate #:plane-dot-normal
   #:plane-transform #:plane-equal
   #:curve #:curve-pre-loop #:curve-post-loop #:curve-keys #:curve-is-constant
   #:curve-clone #:curve-evaluate #:curve-compute-tangent #:curve-compute-tangents
   #:curve-key #:curve-key-position #:curve-key-value
   #:curve-key-tangent-in #:curve-key-tangent-out #:curve-key-continuity
   #:curve-key-clone #:curve-key-equal #:curve-key-compare-to
   #:curve-key-collection #:curve-key-collection-count
   #:curve-key-collection-is-read-only #:curve-key-collection-item
   #:curve-key-collection-add #:curve-key-collection-remove-at
   #:curve-key-collection-index-of #:curve-key-collection-contains
   #:curve-key-collection-remove #:curve-key-collection-clear
   #:curve-key-collection-keys #:curve-key-collection-copy-to
   #:curve-key-collection-clone
   #:curve-continuity #:curve-continuity-value #:curve-continuity-from-value
   #:all-curve-continuity
   #:curve-loop-type #:curve-loop-type-value #:curve-loop-type-from-value
   #:all-curve-loop-type
   #:curve-tangent #:curve-tangent-value #:curve-tangent-from-value
   #:all-curve-tangent
   #:display-orientation #:display-orientation-value
   #:display-orientation-from-value #:all-display-orientation
   #:containment-type #:containment-type-value #:containment-type-from-value
   #:all-containment-type
   #:plane-intersection-type #:plane-intersection-type-value
   #:plane-intersection-type-from-value #:all-plane-intersection-type
   #:matrix-create-reflection #:matrix-create-shadow
   ;; --- Ray, BoundingBox, BoundingSphere ----------------------------------
   #:ray #:make-ray #:ray-p #:copy-ray #:ray-position #:ray-direction
   #:ray-intersects #:ray-equal
   #:bounding-box #:make-bounding-box #:bounding-box-p #:copy-bounding-box
   #:bounding-box-min #:bounding-box-max #:+bounding-box-corner-count+
   #:bounding-box-get-corners #:bounding-box-create-merged
   #:bounding-box-create-from-sphere #:bounding-box-create-from-points
   #:bounding-box-intersects #:bounding-box-contains #:bounding-box-equal
   #:bounding-sphere #:make-bounding-sphere #:bounding-sphere-p
   #:copy-bounding-sphere
   #:bounding-sphere-center #:bounding-sphere-radius
   #:bounding-sphere-create-merged #:bounding-sphere-create-from-bounding-box
   #:bounding-sphere-create-from-points #:bounding-sphere-transform
   #:bounding-sphere-intersects #:bounding-sphere-contains #:bounding-sphere-equal
   #:bounding-sphere-create-from-frustum
   #:bounding-frustum #:bounding-frustum-matrix #:bounding-frustum-equal
   #:bounding-frustum-near #:bounding-frustum-far
   #:bounding-frustum-left #:bounding-frustum-right
   #:bounding-frustum-top #:bounding-frustum-bottom
   #:bounding-frustum-get-corners
   #:bounding-frustum-intersects #:bounding-frustum-contains
   #:+bounding-frustum-corner-count+ #:+bounding-frustum-plane-count+
   #:plane-intersects
   ;; --- transforms --------------------------------------------------------
   #:vector2-transform #:vector2-transform-normal
   #:vector2-transform-array #:vector2-transform-normal-array
   #:vector3-transform #:vector3-transform-normal
   #:vector3-transform-array #:vector3-transform-normal-array
   #:vector4-transform #:vector4-transform-array
   ;; --- MathHelper --------------------------------------------------------
   #:+math-helper-e+ #:+math-helper-log2e+ #:+math-helper-log10e+
   #:+math-helper-pi+ #:+math-helper-two-pi+
   #:+math-helper-pi-over2+ #:+math-helper-pi-over4+
   #:math-helper-to-radians #:math-helper-to-degrees
   #:math-helper-distance #:math-helper-min #:math-helper-max #:math-helper-clamp
   #:math-helper-lerp #:math-helper-barycentric #:math-helper-smooth-step
   #:math-helper-catmull-rom #:math-helper-hermite #:math-helper-wrap-angle
   ;; --- Color -------------------------------------------------------------
   #:color #:make-color #:color-p #:copy-color #:color-from-packed-value
   #:make-color-from-floats #:make-color-from-vector3 #:make-color-from-vector4
   #:color-from-non-premultiplied-vector4 #:color-to-vector3 #:color-to-vector4
   #:color-lerp
   #:color-r #:color-g #:color-b #:color-a #:color-packed-value
   #:color-equal #:color-from-non-premultiplied #:color-multiply
   #:predefined-color #:predefined-color-names
   #:cornflower-blue #:white #:black #:transparent #:red #:green #:blue
   #:yellow #:magenta #:cyan #:gray #:orange #:purple
   ;; --- PlayerIndex -------------------------------------------------------
   #:player-index #:player-index-value #:player-index-from-value
   ;; --- GameTime ----------------------------------------------------------
   #:game-time #:total-game-time #:elapsed-game-time #:is-running-slowly
   #:total-game-time-seconds #:elapsed-game-time-seconds
   #:+ticks-per-second+
   ;; --- GameWindow ---------------------------------------------------------
   #:game-window #:window #:title #:allow-user-resizing #:client-bounds
   #:current-orientation #:screen-device-name
   #:begin-screen-device-change #:end-screen-device-change
   #:add-client-size-changed-handler #:remove-client-size-changed-handler
   #:add-orientation-changed-handler #:remove-orientation-changed-handler
   #:add-screen-device-name-changed-handler #:remove-screen-device-name-changed-handler
   ;; --- TitleContainer ----------------------------------------------------
   #:title-container-open-stream
   ;; --- GraphicsDeviceManager's preference surface -------------------------
   #:graphics-profile
   #:prefer-multi-sampling #:preferred-back-buffer-format
   #:preferred-depth-stencil-format #:supported-orientations
   #:graphics-device-manager-default-back-buffer-width
   #:graphics-device-manager-default-back-buffer-height
   ;; --- Game --------------------------------------------------------------
   #:game
   #:initialize #:load-content #:unload-content
   #:begin-run #:end-run #:update #:begin-draw #:draw #:end-draw #:on-exiting
   #:content
   #:run #:run-one-frame #:tick #:exit #:suppress-draw #:reset-elapsed-time
   #:graphics-device #:is-active #:is-mouse-visible #:is-fixed-time-step
   #:target-elapsed-time #:inactive-sleep-time #:window-title #:clr-type-name
   #:+default-target-elapsed-time-ticks+
   ;; --- GameServiceContainer and the service-type protocol ----------------
   #:game-service-container #:services
   #:add-service #:get-service #:remove-service #:service-types
   #:define-service-protocol #:declare-service-protocol-implementor
   #:service-protocol-p #:service-protocol-implementors
   #:native-service-present-p
   ;; --- the two interfaces GraphicsDeviceManager implements ---------------
   #:igraphics-device-manager #:igraphics-device-service
   #:create-device #:begin-draw-device #:end-draw-device
   ;; --- GraphicsDeviceInformation -----------------------------------------
   #:graphics-device-information
   #:adapter-of #:graphics-profile-of #:presentation-parameters-of
   #:clone-graphics-device-information
   #:graphics-device-information-equal-p #:graphics-device-information-hash-code
   #:graphics-device-information-clr-type-name
   ;; --- PreparingDeviceSettings -------------------------------------------
   #:preparing-device-settings-event-args #:graphics-device-information
   #:add-preparing-device-settings-handler
   #:remove-preparing-device-settings-handler
   #:on-preparing-device-settings
   ;; --- GraphicsDeviceManager ---------------------------------------------
   #:graphics-device-manager #:game
   #:apply-changes #:toggle-full-screen #:is-full-screen
   #:preferred-back-buffer-width #:preferred-back-buffer-height
   #:synchronize-with-vertical-retrace
   #:on-device-created #:on-device-disposing
   #:on-device-reset #:on-device-resetting
   ;; --- events ------------------------------------------------------------
   #:add-activated-handler #:remove-activated-handler
   #:add-deactivated-handler #:remove-deactivated-handler
   #:add-exiting-handler #:remove-exiting-handler
   #:add-disposed-handler #:remove-disposed-handler
   #:add-device-created-handler #:remove-device-created-handler
   #:add-device-resetting-handler #:remove-device-resetting-handler
   #:add-device-reset-handler #:remove-device-reset-handler
   #:add-device-disposing-handler #:remove-device-disposing-handler
   ;; --- lifetime ----------------------------------------------------------
   #:dispose #:disposed-p #:with-disposal
   ;; --- conditions --------------------------------------------------------
   #:cna-error #:cna-native-error #:cna-usage-error
   #:cna-invalid-argument-error #:cna-invalid-object-error
   #:cna-invalid-state-error #:cna-out-of-memory-error #:cna-io-error
   #:cna-not-supported-error #:cna-platform-error #:cna-thread-error
   #:cna-callback-error #:cna-overflow-error #:cna-encoding-error
   #:cna-internal-error #:cna-shutting-down-error #:cna-buffer-too-small-error
   ;; --- the component engine ----------------------------------------------
   #:game-component #:drawable-game-component #:game-component-collection
   #:game-component-collection-event-args #:event-args-game-component
   #:component-enabled #:update-order #:component-visible #:draw-order
   #:component-game #:component-dispose
   #:components #:component-count #:component-at #:components-of
   #:add-component #:insert-component #:remove-component #:remove-component-at
   #:clear-components #:contains-component #:component-index
   #:add-enabled-changed-handler #:remove-enabled-changed-handler
   #:add-update-order-changed-handler #:remove-update-order-changed-handler
   #:add-draw-order-changed-handler #:remove-draw-order-changed-handler
   #:add-visible-changed-handler #:remove-visible-changed-handler
   #:add-component-added-handler #:remove-component-added-handler
   #:add-component-removed-handler #:remove-component-removed-handler
   #:launch-parameters #:launch-parameter #:launch-parameter-names
   #:cna-argument-error #:cna-argument-out-of-range-error #:cna-error-parameter-name
   #:cna-disposed-error #:cna-ownership-error #:cna-scope-error
   #:cna-native-library-error #:cna-abi-rejected-error #:cna-invalid-cast-error
   #:cna-error-operation #:cna-error-native-message #:cna-error-object-type
   #:cna-error-cause
   #:cna-abi-found-version #:cna-abi-admitted-versions #:cna-native-library-path
   #:cna-callback-underlying-condition))

(defpackage #:microsoft.xna.framework.graphics
  (:documentation "Common Lisp projection of the Microsoft.Xna.Framework.Graphics namespace.")
  (:use #:cl)
  (:export
   ;; --- GraphicsResource --------------------------------------------------
   #:graphics-resource #:graphics-resource-name #:graphics-resource-is-disposed
   #:graphics-resource-graphics-device #:tag
   #:add-disposing-handler #:remove-disposing-handler
   ;; --- Viewport ----------------------------------------------------------
   #:viewport #:make-viewport #:viewport-p #:copy-viewport
   #:viewport-x #:viewport-y #:viewport-width #:viewport-height
   #:viewport-min-depth #:viewport-max-depth
   #:viewport-aspect-ratio #:viewport-bounds #:viewport-title-safe-area
   #:viewport-equal #:make-viewport-from-bounds
   #:viewport-project #:viewport-unproject
   ;; --- enums -------------------------------------------------------------
   #:sprite-sort-mode #:sprite-sort-mode-value #:sprite-sort-mode-from-value
   #:all-sprite-sort-mode
   #:sprite-effects #:sprite-effects-value #:sprite-effects-from-value
   #:all-sprite-effects
   #:surface-format #:surface-format-value #:surface-format-from-value
   #:all-surface-format
   #:blend #:blend-value #:blend-from-value #:all-blend
   #:blend-function #:blend-function-value #:blend-function-from-value
   #:all-blend-function
   #:color-write-channels #:color-write-channels-value
   #:color-write-channels-from-value #:all-color-write-channels
   #:compare-function #:compare-function-value #:compare-function-from-value
   #:all-compare-function
   #:stencil-operation #:stencil-operation-value #:stencil-operation-from-value
   #:all-stencil-operation
   #:cull-mode #:cull-mode-value #:cull-mode-from-value #:all-cull-mode
   #:fill-mode #:fill-mode-value #:fill-mode-from-value #:all-fill-mode
   #:texture-address-mode #:texture-address-mode-value
   #:texture-address-mode-from-value #:all-texture-address-mode
   #:texture-filter #:texture-filter-value #:texture-filter-from-value
   #:all-texture-filter
   ;; --- the graphics state objects ----------------------------------------
   #:blend-state
   #:color-source-blend #:color-destination-blend #:color-blend-function
   #:alpha-source-blend #:alpha-destination-blend #:alpha-blend-function
   #:color-write-channels-1 #:color-write-channels-2 #:color-write-channels-3
   #:blend-factor #:multi-sample-mask
   #:blend-state-opaque #:blend-state-alpha-blend #:blend-state-additive
   #:blend-state-non-premultiplied
   #:depth-stencil-state
   #:depth-buffer-enable #:depth-buffer-write-enable #:depth-buffer-function
   #:stencil-enable #:stencil-function #:stencil-pass #:stencil-fail
   #:stencil-depth-buffer-fail #:two-sided-stencil-mode
   #:counter-clockwise-stencil-function #:counter-clockwise-stencil-pass
   #:counter-clockwise-stencil-fail #:counter-clockwise-stencil-depth-buffer-fail
   #:stencil-mask #:stencil-write-mask #:reference-stencil
   #:depth-stencil-state-none #:depth-stencil-state-default
   #:depth-stencil-state-depth-read
   #:rasterizer-state
   #:scissor-test-enable #:multi-sample-anti-alias
   #:depth-bias #:slope-scale-depth-bias
   #:rasterizer-state-cull-none #:rasterizer-state-cull-clockwise
   #:rasterizer-state-cull-counter-clockwise
   #:sampler-state
   #:filter #:address-u #:address-v #:address-w
   #:max-anisotropy #:max-mip-level #:mip-map-level-of-detail-bias
   #:sampler-state-point-wrap #:sampler-state-point-clamp
   #:sampler-state-linear-wrap #:sampler-state-linear-clamp
   #:sampler-state-anisotropic-wrap #:sampler-state-anisotropic-clamp
   ;; --- vertex declarations and the standard vertex types -------------------
   #:vertex-element-format #:vertex-element-format-value
   #:vertex-element-format-from-value #:all-vertex-element-format
   #:vertex-element-usage #:vertex-element-usage-value
   #:vertex-element-usage-from-value #:all-vertex-element-usage
   #:vertex-element #:make-vertex-element #:vertex-element-p #:copy-vertex-element
   #:vertex-element-offset #:vertex-element-vertex-element-format
   #:vertex-element-vertex-element-usage #:vertex-element-usage-index
   #:vertex-element-equal #:vertex-element-format-size
   #:vertex-declaration #:vertex-stride #:get-vertex-elements
   #:vertex-declaration-of
   #:vertex-position-color #:make-vertex-position-color #:vertex-position-color-p
   #:copy-vertex-position-color #:vertex-position-color-position
   #:vertex-position-color-color #:vertex-position-color-equal
   #:vertex-position-color-vertex-declaration
   #:vertex-position-texture #:make-vertex-position-texture
   #:vertex-position-texture-p #:copy-vertex-position-texture
   #:vertex-position-texture-position #:vertex-position-texture-texture-coordinate
   #:vertex-position-texture-equal #:vertex-position-texture-vertex-declaration
   #:vertex-position-color-texture #:make-vertex-position-color-texture
   #:vertex-position-color-texture-p #:copy-vertex-position-color-texture
   #:vertex-position-color-texture-position #:vertex-position-color-texture-color
   #:vertex-position-color-texture-texture-coordinate
   #:vertex-position-color-texture-equal
   #:vertex-position-color-texture-vertex-declaration
   #:vertex-position-normal-texture #:make-vertex-position-normal-texture
   #:vertex-position-normal-texture-p #:copy-vertex-position-normal-texture
   #:vertex-position-normal-texture-position
   #:vertex-position-normal-texture-normal
   #:vertex-position-normal-texture-texture-coordinate
   #:vertex-position-normal-texture-equal
   #:vertex-position-normal-texture-vertex-declaration
   ;; --- buffers, bindings and primitive drawing -----------------------------
   #:buffer-usage #:buffer-usage-value #:buffer-usage-from-value #:all-buffer-usage
   #:index-element-size #:index-element-size-value #:index-element-size-from-value
   #:all-index-element-size
   #:set-data-options #:set-data-options-value #:set-data-options-from-value
   #:all-set-data-options
   #:primitive-type #:primitive-type-value #:primitive-type-from-value
   #:all-primitive-type
   #:vertex-buffer #:dynamic-vertex-buffer #:vertex-count
   #:index-buffer #:dynamic-index-buffer #:index-count
   #:set-data #:get-data #:is-content-lost
   #:add-content-lost-handler #:remove-content-lost-handler
   #:vertex-buffer-binding #:make-vertex-buffer-binding #:vertex-buffer-binding-p
   #:copy-vertex-buffer-binding #:vertex-buffer-binding-vertex-buffer
   #:vertex-buffer-binding-vertex-offset #:vertex-buffer-binding-instance-frequency
   #:set-vertex-buffer #:set-vertex-buffers #:get-vertex-buffers #:indices
   #:draw-primitives #:draw-indexed-primitives #:draw-instanced-primitives
   #:draw-user-primitives #:draw-user-indexed-primitives
   ;; --- Effect and its object graph ----------------------------------------
   #:effect #:basic-effect #:effect-techniques #:effect-parameters
   #:effect-current-technique #:clone-effect
   #:effect-technique #:effect-technique-name #:effect-technique-passes
   #:effect-technique-annotations
   #:effect-pass #:effect-pass-name #:effect-pass-annotations #:apply-effect-pass
   #:effect-technique-collection #:effect-pass-collection
   #:effect-parameter-collection #:effect-annotation-collection
   #:collection-count #:collection-item #:collection-elements
   #:collection-parameter-by-semantic
   #:effect-annotation #:effect-annotation-name #:effect-annotation-semantic
   #:effect-annotation-row-count #:effect-annotation-column-count
   #:effect-annotation-parameter-class #:effect-annotation-parameter-type
   #:effect-annotation-value-boolean #:effect-annotation-value-int32
   #:effect-annotation-value-single #:effect-annotation-value-vector2
   #:effect-annotation-value-vector3 #:effect-annotation-value-vector4
   #:effect-annotation-value-matrix #:effect-annotation-value-string
   #:effect-parameter #:effect-parameter-name #:effect-parameter-semantic
   #:effect-parameter-row-count #:effect-parameter-column-count
   #:effect-parameter-parameter-class #:effect-parameter-parameter-type
   #:effect-parameter-elements #:effect-parameter-structure-members
   #:effect-parameter-annotations
   #:effect-parameter-value #:effect-parameter-values
   #:effect-parameter-value-string #:effect-parameter-value-texture
   #:effect-parameter-value-texture-cube
   #:effect-parameter-class #:effect-parameter-class-value
   #:effect-parameter-class-from-value #:all-effect-parameter-class
   #:effect-parameter-type #:effect-parameter-type-value
   #:effect-parameter-type-from-value #:all-effect-parameter-type
   ;; --- IEffectMatrices, IEffectLights, IEffectFog and DirectionalLight -----
   #:effect-world #:effect-view #:effect-projection
   #:effect-fog-enabled #:effect-fog-start #:effect-fog-end #:effect-fog-color
   #:effect-lighting-enabled #:effect-ambient-light-color #:enable-default-lighting
   #:directional-light-0 #:directional-light-1 #:directional-light-2
   #:directional-light #:directional-light-enabled #:directional-light-direction
   #:directional-light-diffuse-color #:directional-light-specular-color
   #:effect-alpha #:effect-diffuse-color #:effect-emissive-color
   #:effect-specular-color #:effect-specular-power #:effect-texture
   #:effect-texture-enabled #:effect-vertex-color-enabled
   #:effect-prefer-per-pixel-lighting
   ;; --- the Model family ---------------------------------------------------
   #:model #:model-bones #:model-meshes #:model-root
   #:copy-bone-transforms-to #:copy-absolute-bone-transforms-to
   #:copy-bone-transforms-from #:draw-model
   #:model-bone #:model-bone-name #:model-bone-index #:model-bone-transform
   #:model-bone-parent #:model-bone-children
   #:model-mesh #:model-mesh-name #:model-mesh-parent-bone
   #:model-mesh-bounding-sphere #:model-mesh-parts #:model-mesh-effects
   #:draw-model-mesh
   #:model-mesh-part #:model-mesh-part-start-index #:model-mesh-part-primitive-count
   #:model-mesh-part-vertex-offset #:model-mesh-part-num-vertices
   #:model-mesh-part-index-buffer #:model-mesh-part-vertex-buffer
   #:model-mesh-part-effect
   #:model-bone-collection #:model-mesh-collection #:model-mesh-part-collection
   #:model-effect-collection
   #:model-bone-collection-enumerator #:model-mesh-collection-enumerator
   #:model-mesh-part-collection-enumerator #:model-effect-collection-enumerator
   #:collection-try-get-value #:collection-enumerator
   #:enumerator-move-next #:enumerator-current
   ;; --- the device's state and texture collections -------------------------
   #:sampler-state-collection #:texture-collection #:item
   #:sampler-states #:vertex-sampler-states #:textures #:vertex-textures
   ;; --- GraphicsDevice ----------------------------------------------------
   #:graphics-device #:clear #:present #:renderer-name #:scissor-rectangle
   #:get-back-buffer-data
   ;; --- Texture and Texture2D ---------------------------------------------
   #:texture #:texture-2d
   #:texture-2d-from-png-file #:texture-2d-from-png-bytes
   #:texture-2d-from-stream #:save-as-png #:save-as-jpeg
   #:graphics-profile #:graphics-profile-value #:graphics-profile-from-value
   #:all-graphics-profile
   #:clear-options #:clear-options-value #:clear-options-from-value
   #:all-clear-options
   #:draw-instanced-primitives
   #:is-disposed #:add-device-lost-handler #:remove-device-lost-handler
   #:add-device-reset-handler #:remove-device-reset-handler
   #:add-device-resetting-handler #:remove-device-resetting-handler
   #:present-interval #:present-interval-value #:present-interval-from-value
   #:all-present-interval
   #:graphics-device-status #:graphics-device-status-value
   #:graphics-device-status-from-value #:all-graphics-device-status
   ;; --- GraphicsAdapter ----------------------------------------------------
   #:graphics-adapter #:adapter #:reset-graphics-device
   #:graphics-adapter-adapters #:graphics-adapter-default-adapter
   #:graphics-adapter-description #:graphics-adapter-device-name
   #:graphics-adapter-is-default-adapter #:graphics-adapter-is-wide-screen
   #:graphics-adapter-vendor-id #:graphics-adapter-device-id
   #:graphics-adapter-revision #:graphics-adapter-sub-system-id
   #:graphics-adapter-use-null-device #:graphics-adapter-use-reference-device
   #:graphics-adapter-current-display-mode #:graphics-adapter-supported-display-modes
   #:graphics-adapter-is-profile-supported
   #:graphics-adapter-query-back-buffer-format
   #:graphics-adapter-query-render-target-format
   #:display-mode-collection #:display-mode-collection-modes-vector
   #:display-mode-collection-item
   ;; --- DisplayMode and PresentationParameters -----------------------------
   #:display-mode #:display-mode-width #:display-mode-height #:display-mode-format
   #:display-mode-aspect-ratio #:display-mode-title-safe-area
   #:presentation-parameters #:back-buffer-width #:back-buffer-height
   #:back-buffer-format #:depth-stencil-format #:multi-sample-count
   #:display-orientation #:presentation-interval #:render-target-usage
   #:is-full-screen #:clone-presentation-parameters #:presentation-parameters-bounds
   #:width #:height #:level-count #:format-of #:bounds
   ;; --- SpriteBatch -------------------------------------------------------
   ;; --- RenderTarget2D ----------------------------------------------------
   #:render-target-2d #:render-target-usage #:depth-format
   #:render-target-usage-value #:render-target-usage-from-value #:all-render-target-usage
   #:depth-format-value #:depth-format-from-value #:all-depth-format
   #:multi-sample-count #:depth-stencil-format #:set-render-target
   #:sprite-batch #:begin #:end #:draw-texture #:draw-string
   ;; --- the other stock effects -------------------------------------------
   #:texture-cube #:cube-map-face #:texture-cube-size
   #:cube-map-face-value #:cube-map-face-from-value #:all-cube-map-face
   #:set-cube-data #:get-cube-data
   #:environment-map-effect #:effect-environment-map
   #:effect-environment-map-amount #:effect-environment-map-specular
   #:effect-fresnel-factor
   #:alpha-test-effect #:effect-alpha-function #:effect-reference-alpha
   #:dual-texture-effect #:effect-texture-2
   #:skinned-effect #:effect-weights-per-vertex
   #:set-bone-transforms #:get-bone-transforms #:+skinned-effect-max-bones+
   ;; --- RenderTargetCube and RenderTargetBinding --------------------------
   #:render-target-cube
   #:render-target-binding #:make-render-target-binding #:render-target-binding-p
   #:copy-render-target-binding #:render-target-binding-equal
   #:render-target-binding-target #:render-target-binding-cube-map-face
   #:set-render-targets #:get-render-targets
   ;; --- SpriteFont --------------------------------------------------------
   #:sprite-font #:line-spacing #:spacing #:default-character #:characters
   #:measure-string))

(defpackage #:microsoft.xna.framework.content
  (:documentation
   "Common Lisp projection of the Microsoft.Xna.Framework.Content namespace.

Content is where this binding gets to use the one thing C could not: Common Lisp
can name a type. XNA's `Load<T>' is generic over the asset type, and the C ABI
has to spell that as a separate route per asset -- `cna_content_manager_load_
texture2d', `..._load_sprite_font', `..._load_texture_cube'. LOAD-ASSET takes the
type as its argument, so `Load<SpriteFont>(name)' reads as
`(load-asset manager \='sprite-font name)' rather than as a differently-named
function.")
  (:use #:cl)
  (:export
   ;; --- ContentManager ----------------------------------------------------
   #:content-manager #:root-directory #:load-asset #:unload
   #:loadable-asset-types))

(defpackage #:microsoft.xna.framework.graphics.packed-vector
  (:documentation
   "Common Lisp projection of the Microsoft.Xna.Framework.Graphics.PackedVector
namespace: seventeen packed value types and nothing else.")
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework))
  (:export
   #:alpha8 #:make-alpha8 #:alpha8-p #:copy-alpha8
   #:alpha8-packed-value #:alpha8-to-alpha #:alpha8-equal
   #:bgr565 #:make-bgr565 #:bgr565-p #:copy-bgr565
   #:bgr565-packed-value #:bgr565-to-vector3 #:bgr565-equal
   #:make-bgr565-from-vector
   #:bgra4444 #:make-bgra4444 #:bgra4444-p #:copy-bgra4444
   #:bgra4444-packed-value #:bgra4444-to-vector4 #:bgra4444-equal
   #:make-bgra4444-from-vector
   #:bgra5551 #:make-bgra5551 #:bgra5551-p #:copy-bgra5551
   #:bgra5551-packed-value #:bgra5551-to-vector4 #:bgra5551-equal
   #:make-bgra5551-from-vector
   #:byte4 #:make-byte4 #:byte4-p #:copy-byte4
   #:byte4-packed-value #:byte4-to-vector4 #:byte4-equal
   #:make-byte4-from-vector
   #:half-single #:make-half-single #:half-single-p #:copy-half-single
   #:half-single-packed-value #:half-single-to-single #:half-single-equal
   #:half-vector2 #:make-half-vector2 #:half-vector2-p #:copy-half-vector2
   #:half-vector2-packed-value #:half-vector2-to-vector2 #:half-vector2-equal
   #:make-half-vector2-from-vector
   #:half-vector4 #:make-half-vector4 #:half-vector4-p #:copy-half-vector4
   #:half-vector4-packed-value #:half-vector4-to-vector4 #:half-vector4-equal
   #:make-half-vector4-from-vector
   #:normalized-byte2 #:make-normalized-byte2 #:normalized-byte2-p #:copy-normalized-byte2
   #:normalized-byte2-packed-value #:normalized-byte2-to-vector2 #:normalized-byte2-equal
   #:make-normalized-byte2-from-vector
   #:normalized-byte4 #:make-normalized-byte4 #:normalized-byte4-p #:copy-normalized-byte4
   #:normalized-byte4-packed-value #:normalized-byte4-to-vector4 #:normalized-byte4-equal
   #:make-normalized-byte4-from-vector
   #:normalized-short2 #:make-normalized-short2 #:normalized-short2-p #:copy-normalized-short2
   #:normalized-short2-packed-value #:normalized-short2-to-vector2 #:normalized-short2-equal
   #:make-normalized-short2-from-vector
   #:normalized-short4 #:make-normalized-short4 #:normalized-short4-p #:copy-normalized-short4
   #:normalized-short4-packed-value #:normalized-short4-to-vector4 #:normalized-short4-equal
   #:make-normalized-short4-from-vector
   #:rg32 #:make-rg32 #:rg32-p #:copy-rg32
   #:rg32-packed-value #:rg32-to-vector2 #:rg32-equal
   #:make-rg32-from-vector
   #:rgba1010102 #:make-rgba1010102 #:rgba1010102-p #:copy-rgba1010102
   #:rgba1010102-packed-value #:rgba1010102-to-vector4 #:rgba1010102-equal
   #:make-rgba1010102-from-vector
   #:rgba64 #:make-rgba64 #:rgba64-p #:copy-rgba64
   #:rgba64-packed-value #:rgba64-to-vector4 #:rgba64-equal
   #:make-rgba64-from-vector
   #:short2 #:make-short2 #:short2-p #:copy-short2
   #:short2-packed-value #:short2-to-vector2 #:short2-equal
   #:make-short2-from-vector
   #:short4 #:make-short4 #:short4-p #:copy-short4
   #:short4-packed-value #:short4-to-vector4 #:short4-equal
   #:make-short4-from-vector))

(defpackage #:microsoft.xna.framework.input.touch
  (:documentation
   "Common Lisp projection of the Microsoft.Xna.Framework.Input.Touch namespace.")
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework))
  (:export
   ;; --- enumerations ------------------------------------------------------
   #:touch-location-state #:touch-location-state-value
   #:touch-location-state-from-value #:all-touch-location-state
   #:gesture-type #:gesture-type-value #:gesture-type-from-value #:all-gesture-type
   ;; --- TouchLocation -----------------------------------------------------
   #:touch-location #:make-touch-location #:touch-location-p #:copy-touch-location
   #:touch-location-id #:touch-location-state #:touch-location-position
   #:touch-location-try-get-previous-location #:touch-location-equal
   ;; --- TouchCollection ---------------------------------------------------
   #:touch-collection #:make-touch-collection #:touch-collection-p
   #:copy-touch-collection #:touch-collection-count #:touch-collection-is-connected
   #:touch-collection-is-read-only #:touch-collection-item
   #:touch-collection-index-of #:touch-collection-contains #:touch-collection-add
   #:touch-collection-insert #:touch-collection-remove-at #:touch-collection-remove
   #:touch-collection-clear #:touch-collection-copy-to
   #:touch-collection-locations-vector #:touch-collection-find-by-id
   ;; --- TouchPanelCapabilities and GestureSample --------------------------
   #:touch-panel-capabilities #:touch-panel-capabilities-p
   #:copy-touch-panel-capabilities #:touch-panel-capabilities-is-connected
   #:touch-panel-capabilities-maximum-touch-count
   #:gesture-sample #:make-gesture-sample #:gesture-sample-p #:copy-gesture-sample
   #:gesture-sample-gesture-type #:gesture-sample-timestamp
   #:gesture-sample-position #:gesture-sample-position-2
   #:gesture-sample-delta #:gesture-sample-delta-2
   ;; --- TouchPanel --------------------------------------------------------
   #:touch-panel-get-state #:touch-panel-get-capabilities
   #:touch-panel-read-gesture #:touch-panel-is-gesture-available
   #:touch-panel-enabled-gestures #:touch-panel-display-width
   #:touch-panel-display-height #:touch-panel-display-orientation))

(defpackage #:microsoft.xna.framework.input
  (:documentation "Common Lisp projection of the Microsoft.Xna.Framework.Input namespace.")
  (:use #:cl)
  (:export
   ;; --- Keys and KeyState -------------------------------------------------
   #:keys #:keysp #:keys-value #:keys-from-value #:all-keys
   #:key-state #:key-state-value #:key-state-from-value
   ;; --- KeyboardState -----------------------------------------------------
   #:keyboard-state #:make-keyboard-state #:keyboard-state-p #:copy-keyboard-state
   #:is-key-down #:is-key-up #:get-key-state #:get-pressed-keys
   #:keyboard-state-equal
   ;; --- Keyboard ----------------------------------------------------------
   #:keyboard-get-state
   ;; --- ButtonState -------------------------------------------------------
   #:button-state #:button-state-value #:button-state-from-value #:all-button-state
   ;; --- MouseState --------------------------------------------------------
   #:mouse-state #:make-mouse-state #:mouse-state-p #:copy-mouse-state
   #:mouse-state-x #:mouse-state-y #:mouse-state-scroll-wheel-value
   #:mouse-state-left-button #:mouse-state-middle-button #:mouse-state-right-button
   #:mouse-state-x-button-1 #:mouse-state-x-button-2 #:mouse-state-equal
   ;; --- Mouse -------------------------------------------------------------
   #:mouse-get-state #:mouse-set-position
   ;; --- gamepad enumerations ----------------------------------------------
   #:buttons #:buttons-value #:buttons-from-value #:all-buttons
   #:game-pad-type #:game-pad-type-value #:game-pad-type-from-value
   #:all-game-pad-type
   #:game-pad-dead-zone #:game-pad-dead-zone-value #:game-pad-dead-zone-from-value
   #:all-game-pad-dead-zone
   ;; --- GamePadButtons ----------------------------------------------------
   #:game-pad-buttons #:make-game-pad-buttons #:game-pad-buttons-p
   #:copy-game-pad-buttons #:game-pad-buttons-equal
   #:game-pad-buttons-a #:game-pad-buttons-b #:game-pad-buttons-x #:game-pad-buttons-y
   #:game-pad-buttons-back #:game-pad-buttons-start #:game-pad-buttons-big-button
   #:game-pad-buttons-left-shoulder #:game-pad-buttons-right-shoulder
   #:game-pad-buttons-left-stick #:game-pad-buttons-right-stick
   ;; --- GamePadDPad -------------------------------------------------------
   #:game-pad-dpad #:make-game-pad-dpad #:game-pad-dpad-p #:copy-game-pad-dpad
   #:game-pad-dpad-up #:game-pad-dpad-down #:game-pad-dpad-left #:game-pad-dpad-right
   #:game-pad-dpad-equal
   ;; --- GamePadThumbSticks and GamePadTriggers ----------------------------
   #:game-pad-thumb-sticks #:make-game-pad-thumb-sticks #:game-pad-thumb-sticks-p
   #:copy-game-pad-thumb-sticks #:game-pad-thumb-sticks-left
   #:game-pad-thumb-sticks-right #:game-pad-thumb-sticks-equal
   #:game-pad-triggers #:make-game-pad-triggers #:game-pad-triggers-p
   #:copy-game-pad-triggers #:game-pad-triggers-left #:game-pad-triggers-right
   #:game-pad-triggers-equal
   ;; --- GamePadState ------------------------------------------------------
   #:game-pad-state #:make-game-pad-state #:make-game-pad-state-from-values
   #:game-pad-state-p #:copy-game-pad-state #:game-pad-state-equal
   #:game-pad-state-is-connected #:game-pad-state-packet-number
   #:game-pad-state-buttons #:game-pad-state-dpad
   #:game-pad-state-thumb-sticks #:game-pad-state-triggers
   #:game-pad-state-is-button-down #:game-pad-state-is-button-up
   ;; --- GamePadCapabilities -----------------------------------------------
   #:game-pad-capabilities #:game-pad-capabilities-p #:copy-game-pad-capabilities
   #:game-pad-capabilities-game-pad-type #:game-pad-capabilities-is-connected
   #:game-pad-capabilities-has-a-button #:game-pad-capabilities-has-b-button
   #:game-pad-capabilities-has-x-button #:game-pad-capabilities-has-y-button
   #:game-pad-capabilities-has-back-button #:game-pad-capabilities-has-start-button
   #:game-pad-capabilities-has-big-button
   #:game-pad-capabilities-has-dpad-up-button #:game-pad-capabilities-has-dpad-down-button
   #:game-pad-capabilities-has-dpad-left-button
   #:game-pad-capabilities-has-dpad-right-button
   #:game-pad-capabilities-has-left-shoulder-button
   #:game-pad-capabilities-has-right-shoulder-button
   #:game-pad-capabilities-has-left-stick-button
   #:game-pad-capabilities-has-right-stick-button
   #:game-pad-capabilities-has-left-x-thumb-stick
   #:game-pad-capabilities-has-left-y-thumb-stick
   #:game-pad-capabilities-has-right-x-thumb-stick
   #:game-pad-capabilities-has-right-y-thumb-stick
   #:game-pad-capabilities-has-left-trigger #:game-pad-capabilities-has-right-trigger
   #:game-pad-capabilities-has-left-vibration-motor
   #:game-pad-capabilities-has-right-vibration-motor
   #:game-pad-capabilities-has-voice-support
   ;; --- GamePad -----------------------------------------------------------
   #:game-pad-get-state #:game-pad-get-capabilities #:game-pad-set-vibration))

(defpackage #:microsoft.xna.framework.audio
  (:documentation
   "Common Lisp projection of the Microsoft.Xna.Framework.Audio namespace.

The **selected** part of it: `SoundEffect' and `SoundEffectInstance', the
`AudioListener' and `AudioEmitter' that position one in space, the `SoundState'
and `AudioChannels' enumerations, and the two exceptions XNA's audio surface
raises on its own behalf. XACT -- `AudioEngine', `SoundBank', `WaveBank', `Cue',
`AudioCategory' and `RendererDetail' -- is not selected, and CNA has no route for
any of it. `DynamicSoundEffectInstance' is selected and is the streaming half of
this namespace; the microphone family has a full CNA route family and is a
closure of its own, and half of it cannot be qualified without a capture device.

**No public member of this package takes a game.** XNA's audio API has no game
argument -- its constructors and its four static properties take none -- and CNA's
routes need a game handle for lifetime and thread affinity. The gap is closed the
way `Keyboard.GetState' closes it: CNA permits one active game per process, so
there is exactly one game a static audio operation could mean, and CNA-Lisp
resolves it. With no live game the operation signals `CNA-INVALID-STATE-ERROR'
naming what is missing, which is a projection limit and is written down in
`docs/limitations.md' as one.")
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework))
  ;; `AudioListener.Position' and `AudioEmitter.Position' are reference-type
  ;; members, so the naming rule makes them the bare reader POSITION -- and
  ;; `CL:POSITION' is a standard sequence function. Shadowing is the honest
  ;; answer: it keeps the projected name the rule's name, and a program that
  ;; wants the sequence function still has `CL:POSITION' by its own package
  ;; qualifier. The alternative -- renaming the member to AUDIO-LISTENER-POSITION
  ;; -- would apply the *value type* rule to a class, and this binding has one
  ;; naming rule per kind on purpose.
  (:shadow #:position)
  (:export
   ;; --- enumerations ------------------------------------------------------
   #:sound-state #:sound-state-value #:sound-state-from-value #:all-sound-state
   #:audio-channels #:audio-channels-value #:audio-channels-from-value
   #:all-audio-channels
   ;; --- the two exceptions XNA's audio surface raises ----------------------
   #:no-audio-hardware-error #:instance-play-limit-error
   ;; --- AudioListener and AudioEmitter -------------------------------------
   #:audio-listener #:audio-emitter
   #:position #:velocity #:forward #:up #:doppler-scale
   ;; --- SoundEffect --------------------------------------------------------
   #:sound-effect
   #:name #:duration #:is-disposed #:create-instance #:play
   #:sound-effect-from-stream
   #:sound-effect-get-sample-duration #:sound-effect-get-sample-size-in-bytes
   #:sound-effect-master-volume #:sound-effect-distance-scale
   #:sound-effect-doppler-scale #:sound-effect-speed-of-sound
   ;; --- SoundEffectInstance -------------------------------------------------
   #:sound-effect-instance
   #:state #:is-looped #:volume #:pitch #:pan
   #:pause #:resume #:stop #:apply-3d
   ;; --- DynamicSoundEffectInstance ------------------------------------------
   #:dynamic-sound-effect-instance
   #:submit-buffer #:pending-buffer-count
   #:get-sample-duration #:get-sample-size-in-bytes
   #:add-buffer-needed-handler #:remove-buffer-needed-handler
   ;; --- Microphone -----------------------------------------------------------
   ;; `MICROPHONE-ALL' and `MICROPHONE-DEFAULT' carry the class prefix because
   ;; they project *static* members, which is the naming rule for those; the
   ;; instance members are bare readers because that is the rule for a reference
   ;; type's. `NAME', `STATE', `STOP', `GET-SAMPLE-DURATION' and
   ;; `GET-SAMPLE-SIZE-IN-BYTES' are already exported above and gain a microphone
   ;; method rather than a second symbol.
   #:microphone #:microphone-all #:microphone-default
   #:microphone-state #:microphone-state-value #:microphone-state-from-value
   #:all-microphone-state
   #:no-microphone-connected-error
   #:sample-rate #:is-headset #:buffer-duration #:start #:get-data
   #:add-buffer-ready-handler #:remove-buffer-ready-handler))

(defpackage #:microsoft.xna.framework.media
  (:documentation
   "Common Lisp projection of the Microsoft.Xna.Framework.Media namespace.

The **playback** part of it: `MediaPlayer', the one `MediaQueue' it owns, `Song'
and `SongCollection', the `MediaState' enumeration and the `VisualizationData'
buffer pair. That is the closure a game reaches to play background music, and it
is dependency-complete once three members of `Song' are set aside -- see below.

**`MediaLibrary` is not selected, and neither are the four types it owns.**
`Album', `Artist', `Genre' and `AlbumCollection' are *media-library* entities:
their CNA routes live in `media_library.h' rather than in `media.h', and
`cna_song_get_album' and its two siblings say in as many words that only a song
obtained from a media library has one -- a song a caller created from a file path
has no library context. So `Song.Artist', `Song.Album' and `Song.Genre' are
declared missing under DEPENDENCY_NOT_SELECTED, exactly as
`EffectParameter.GetValueTexture3D' is for `Texture3D'. Selecting the four types
to satisfy three members would add fifty-three members that nothing in this
repository could exercise, which is the reason the library closure was not chosen.

**`MediaPlayer' is a static class and its two events are static.** Its members are
therefore named `MEDIA-PLAYER-<member>', the static-class naming rule, and its
event handlers take **no sender**: XNA raises both with `handler(null, args)',
because there is no instance to be one. CNA agrees -- its two subscribe routes
take a callback and a context and **no game handle at all**, the only
subscription in this binding that does.

**No public member of this package takes a game.** XNA's media API has no game
argument, and CNA's routes need one for lifetime and thread affinity. The gap is
closed the way `Keyboard.GetState' and the whole Audio surface close it: CNA
permits one active game per process, so there is exactly one game a media
operation could mean. With no live game the operation signals
`CNA-INVALID-STATE-ERROR' naming what is missing, which is a projection limit and
is written down in `docs/limitations.md' as one.")
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework))
  (:export
   ;; --- MediaState ---------------------------------------------------------
   #:media-state #:media-state-value #:media-state-from-value #:all-media-state
   ;; --- VisualizationData ---------------------------------------------------
   #:visualization-data #:make-visualization-data #:frequencies #:samples
   ;; --- Song ----------------------------------------------------------------
   #:song #:song-from-uri
   #:name #:duration #:is-rated #:rating #:play-count #:track-number
   #:is-protected #:is-disposed #:song-equal
   ;; --- SongCollection ------------------------------------------------------
   #:song-collection #:count-of #:item #:songs-vector
   ;; --- MediaQueue ----------------------------------------------------------
   #:media-queue #:active-song-index #:active-song
   ;; --- MediaPlayer ---------------------------------------------------------
   #:media-player-play #:media-player-pause #:media-player-resume
   #:media-player-stop #:media-player-move-next #:media-player-move-previous
   #:media-player-get-visualization-data
   #:media-player-is-shuffled #:media-player-is-repeating
   #:media-player-queue #:media-player-state #:media-player-play-position
   #:media-player-volume #:media-player-is-muted
   #:media-player-is-visualization-enabled #:media-player-game-has-control
   #:media-player-add-active-song-changed-handler
   #:media-player-remove-active-song-changed-handler
   #:media-player-add-media-state-changed-handler
   #:media-player-remove-media-state-changed-handler))

(defpackage #:microsoft.xna.framework.storage
  (:documentation
   "Common Lisp projection of the Microsoft.Xna.Framework.Storage namespace.

All three of its types: `StorageDevice', `StorageContainer' and
`StorageDeviceNotConnectedException'.

**Two design questions had to be answered before any of this could be written**,
and both are answered from the pinned IL rather than from taste.
`docs/limitations.md' carries the full argument; the decisions are:

**XNA's async is a fiction, so the projection keeps the pair and invents no
concurrency.** `StorageDeviceAsyncResult.CompletedSynchronously' is a literal
`true', its wait handle is constructed already-signalled so `IsCompleted' is
always true, `Begin' invokes the caller's callback **before it returns**, and
`End' is what does the work -- with a call-once guard. CNA collapses the pair for
exactly that reason. So both members are projected, the callback still fires
inside `Begin', `End' still does the work and still refuses a second call, and
**no promise, future or thread is invented for work that never pends**. The
`IAsyncResult' becomes an opaque object carrying the caller's state; it is not a
projected type, the way `System.IO.Stream' is not.

**`OpenFile' answers a real Common Lisp stream.** `System.IO.Stream' already
projects onto an ordinary CL stream everywhere else in this binding --
`Texture2D.FromStream' and `SaveAsPng' say so -- and Storage is the first place a
*CNA-owned* one has to cross the boundary. Answering a second, parallel
stream-like API would have made that existing statement false, so the streams
here are Gray streams and `READ-SEQUENCE', `WRITE-SEQUENCE', `FILE-POSITION',
`FILE-LENGTH', `READ-BYTE', `WRITE-BYTE', `FORCE-OUTPUT' and `CLOSE' all work on
them.

**`FileMode', `FileAccess' and `FileShare' are base-class-library enumerations**,
not XNA types, so they are not in the selection and are not projected as types.
Their values are keywords, in tables of the usual shape, and the keywords are
declared binding extensions.

**No public member of this package takes a game**, and unlike the audio and media
surfaces most of them need none: `storage.h`'s routes take a device, a container
or a stream and never a game handle. The selector routes are the exception and
they take none either. So a storage program needs no game at all.")
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework))
  ;; `StorageContainer.DeleteFile' is a reference-type member, so the naming rule
  ;; makes it the bare `DELETE-FILE' -- and `CL:DELETE-FILE' is a standard
  ;; function. Shadowing is the honest answer, the same one
  ;; `microsoft.xna.framework.audio' gives for `POSITION': it keeps the projected
  ;; name the rule's name, and a program that wants the standard function still
  ;; has `CL:DELETE-FILE' by its own package qualifier. Renaming the member to
  ;; `STORAGE-CONTAINER-DELETE-FILE' would apply the *static class* rule to an
  ;; instance member, and this binding has one naming rule per kind on purpose.
  (:shadow #:delete-file)
  (:export
   ;; --- the base-class-library enumerations, as keywords -------------------
   #:file-mode #:file-mode-value #:file-mode-from-value #:all-file-mode
   #:file-access #:file-access-value #:file-access-from-value #:all-file-access
   #:file-share #:file-share-value #:file-share-from-value #:all-file-share
   ;; --- the exception -------------------------------------------------------
   #:storage-device-not-connected-error
   ;; --- StorageDevice -------------------------------------------------------
   #:storage-device
   #:storage-device-begin-show-selector #:storage-device-end-show-selector
   #:begin-open-container #:end-open-container #:delete-container
   #:free-space #:total-space #:is-connected
   #:storage-device-add-device-changed-handler
   #:storage-device-remove-device-changed-handler
   #:async-state
   ;; --- StorageContainer ----------------------------------------------------
   #:storage-container
   #:display-name #:is-disposed
   #:directory-exists #:file-exists #:create-directory #:delete-directory
   #:create-file #:open-file #:delete-file
   #:get-directory-names #:get-file-names
   #:add-disposing-handler #:remove-disposing-handler
   ;; --- the stream ----------------------------------------------------------
   #:storage-stream
   ;; --- where the saves go, which XNA never had to say -----------------------
   #:set-storage-application-name #:storage-root))
