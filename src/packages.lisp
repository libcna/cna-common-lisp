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
   ;; --- Game --------------------------------------------------------------
   #:game
   #:initialize #:load-content #:unload-content
   #:begin-run #:end-run #:update #:begin-draw #:draw #:end-draw #:on-exiting
   #:run #:run-one-frame #:tick #:exit #:suppress-draw #:reset-elapsed-time
   #:graphics-device #:is-active #:is-mouse-visible #:is-fixed-time-step
   #:target-elapsed-time #:inactive-sleep-time #:window-title #:clr-type-name
   #:+default-target-elapsed-time-ticks+
   ;; --- GraphicsDeviceManager ---------------------------------------------
   #:graphics-device-manager #:game
   #:apply-changes #:toggle-full-screen #:is-full-screen
   #:preferred-back-buffer-width #:preferred-back-buffer-height
   #:synchronize-with-vertical-retrace
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
   #:cna-argument-out-of-range-error #:cna-error-parameter-name
   #:cna-disposed-error #:cna-ownership-error #:cna-scope-error
   #:cna-native-library-error #:cna-abi-rejected-error
   #:cna-error-operation #:cna-error-native-message #:cna-error-object-type
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
   ;; --- the device's state and texture collections -------------------------
   #:sampler-state-collection #:texture-collection #:item
   #:sampler-states #:vertex-sampler-states #:textures #:vertex-textures
   ;; --- GraphicsDevice ----------------------------------------------------
   #:graphics-device #:clear #:present #:renderer-name #:scissor-rectangle
   ;; --- Texture and Texture2D ---------------------------------------------
   #:texture #:texture-2d
   #:texture-2d-from-png-file #:texture-2d-from-png-bytes
   #:width #:height #:level-count #:format-of #:bounds
   ;; --- SpriteBatch -------------------------------------------------------
   #:sprite-batch #:begin #:end #:draw-texture))

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
