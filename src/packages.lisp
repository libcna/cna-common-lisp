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
  (:shadow #:exit)
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
   #:vector2-normalize #:vector2-equal
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
   #:total-game-time-ticks #:elapsed-game-time-ticks
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
   #:graphics-device-manager #:game-of #:graphics-device-of
   #:apply-changes #:toggle-full-screen #:is-full-screen
   #:preferred-back-buffer-width #:preferred-back-buffer-height
   #:synchronize-with-vertical-retrace
   ;; --- lifetime ----------------------------------------------------------
   #:dispose #:disposed-p #:with-disposal
   ;; --- conditions --------------------------------------------------------
   #:cna-error #:cna-native-error #:cna-usage-error
   #:cna-invalid-argument-error #:cna-invalid-handle-error
   #:cna-invalid-state-error #:cna-out-of-memory-error #:cna-io-error
   #:cna-not-supported-error #:cna-platform-error #:cna-thread-error
   #:cna-callback-error #:cna-overflow-error #:cna-encoding-error
   #:cna-internal-error #:cna-shutting-down-error #:cna-buffer-too-small-error
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
   #:graphics-device #:clear #:viewport-of #:present #:renderer-name
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
