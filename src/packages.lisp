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
   #:rectangle-offset #:rectangle-inflate #:rectangle-equal
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
   #:containment-type #:containment-type-value #:containment-type-from-value
   #:all-containment-type
   #:plane-intersection-type #:plane-intersection-type-value
   #:plane-intersection-type-from-value #:all-plane-intersection-type
   #:matrix-create-reflection #:matrix-create-shadow
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
   ;; --- Viewport ----------------------------------------------------------
   #:viewport #:make-viewport #:viewport-p #:copy-viewport
   #:viewport-x #:viewport-y #:viewport-width #:viewport-height
   #:viewport-min-depth #:viewport-max-depth
   #:viewport-aspect-ratio #:viewport-bounds #:viewport-title-safe-area
   #:viewport-equal
   ;; --- enums -------------------------------------------------------------
   #:sprite-sort-mode #:sprite-sort-mode-value #:sprite-sort-mode-from-value
   #:all-sprite-sort-mode
   #:sprite-effects #:sprite-effects-value #:sprite-effects-from-value
   #:all-sprite-effects
   #:surface-format #:surface-format-value #:surface-format-from-value
   #:all-surface-format
   ;; --- GraphicsDevice ----------------------------------------------------
   #:graphics-device #:clear #:present #:renderer-name
   ;; --- Texture and Texture2D ---------------------------------------------
   #:texture #:texture-2d
   #:texture-2d-from-png-file #:texture-2d-from-png-bytes
   #:width #:height #:level-count #:format-of #:bounds
   ;; --- SpriteBatch -------------------------------------------------------
   #:sprite-batch #:begin #:end #:draw-texture))

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
   #:keyboard-get-state))
