;;;; structs.generated.lisp --- GENERATED FILE, DO NOT EDIT.
;;;;
;;;; Produced by tools/native-abi/generate.py from tools/native-abi/manifest.json
;;;; and the canonical CNA C headers.  Edit the manifest, then regenerate:
;;;;
;;;;   python3 tools/native-abi/generate.py --headers <cna>/modules/c-api/include \
;;;;       --baseline <cna>/tools/c-api/abi_baseline.json
;;;;
;;;; tests/structure/generated-files.lisp fails if this file is stale.

(in-package #:cna-lisp.internal.ffi)

;;; CNA_ErrorInfo -- 24 bytes, 8-byte aligned, from core.h.
(defcstruct (cna-error-info :size 24)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (result :uint32 :offset 8)
  (category :uint32 :offset 12)
  (message-byte-length :uint64 :offset 16))

(defconstant +sizeof-cna-error-info+ 24)
(defconstant +alignof-cna-error-info+ 8)

;;; CNA_StringView -- 16 bytes, 8-byte aligned, from core.h.
;;; Passed by value as :pointer :uint64 (System V AMD64 eightbyte classes: INTEGER INTEGER).
(defcstruct (cna-string-view :size 16)
  (data :pointer :offset 0)
  (byte-length :uint64 :offset 8))

(defconstant +sizeof-cna-string-view+ 16)
(defconstant +alignof-cna-string-view+ 8)

;;; CNA_Color -- 4 bytes, 1-byte aligned, from core.h.
;;; Passed by value as :uint32 (System V AMD64 eightbyte classes: INTEGER).
(defcstruct (cna-color :size 4)
  (r :uint8 :offset 0)
  (g :uint8 :offset 1)
  (b :uint8 :offset 2)
  (a :uint8 :offset 3))

(defconstant +sizeof-cna-color+ 4)
(defconstant +alignof-cna-color+ 1)

;;; CNA_Rectangle -- 16 bytes, 4-byte aligned, from core.h.
;;; Passed by value as :uint64 :uint64 (System V AMD64 eightbyte classes: INTEGER INTEGER).
(defcstruct (cna-rectangle :size 16)
  (x :int32 :offset 0)
  (y :int32 :offset 4)
  (width :int32 :offset 8)
  (height :int32 :offset 12))

(defconstant +sizeof-cna-rectangle+ 16)
(defconstant +alignof-cna-rectangle+ 4)

;;; CNA_Point -- 8 bytes, 4-byte aligned, from math_values.h.
(defcstruct (cna-point :size 8)
  (x :int32 :offset 0)
  (y :int32 :offset 4))

(defconstant +sizeof-cna-point+ 8)
(defconstant +alignof-cna-point+ 4)

;;; CNA_Vector2 -- 8 bytes, 4-byte aligned, from core.h.
(defcstruct (cna-vector-2 :size 8)
  (x :float :offset 0)
  (y :float :offset 4))

(defconstant +sizeof-cna-vector-2+ 8)
(defconstant +alignof-cna-vector-2+ 4)

;;; CNA_Viewport -- 24 bytes, 4-byte aligned, from graphics_device.h.
(defcstruct (cna-viewport :size 24)
  (x :int32 :offset 0)
  (y :int32 :offset 4)
  (width :int32 :offset 8)
  (height :int32 :offset 12)
  (min-depth :float :offset 16)
  (max-depth :float :offset 20))

(defconstant +sizeof-cna-viewport+ 24)
(defconstant +alignof-cna-viewport+ 4)

;;; CNA_GameTime -- 24 bytes, 8-byte aligned, from runtime.h.
(defcstruct (cna-game-time :size 24)
  (total-game-time-ticks :int64 :offset 0)
  (elapsed-game-time-ticks :int64 :offset 8)
  (is-running-slowly :uint8 :offset 16)
  (reserved :uint8 :offset 17 :count 7))

(defconstant +sizeof-cna-game-time+ 24)
(defconstant +alignof-cna-game-time+ 8)

;;; CNA_CallbackError -- 24 bytes, 8-byte aligned, from runtime.h.
(defcstruct (cna-callback-error :size 24)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (message (:struct cna-string-view) :offset 8))

(defconstant +sizeof-cna-callback-error+ 24)
(defconstant +alignof-cna-callback-error+ 8)

;;; CNA_GameCallbacks -- 56 bytes, 8-byte aligned, from runtime.h.
(defcstruct (cna-game-callbacks :size 56)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (load-content :pointer :offset 8)
  (update :pointer :offset 16)
  (draw :pointer :offset 24)
  (unload-content :pointer :offset 32)
  (exiting :pointer :offset 40)
  (context :pointer :offset 48))

(defconstant +sizeof-cna-game-callbacks+ 56)
(defconstant +alignof-cna-game-callbacks+ 8)

;;; CNA_GameFrameHooks -- 56 bytes, 8-byte aligned, from runtime.h.
(defcstruct (cna-game-frame-hooks :size 56)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (initialize :pointer :offset 8)
  (begin-run :pointer :offset 16)
  (end-run :pointer :offset 24)
  (begin-draw :pointer :offset 32)
  (end-draw :pointer :offset 40)
  (context :pointer :offset 48))

(defconstant +sizeof-cna-game-frame-hooks+ 56)
(defconstant +alignof-cna-game-frame-hooks+ 8)

;;; CNA_GameCreateInfo -- 48 bytes, 8-byte aligned, from runtime.h.
(defcstruct (cna-game-create-info :size 48)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (is-fixed-time-step :uint8 :offset 8)
  (reserved :uint8 :offset 9 :count 7)
  (target-elapsed-time-ticks :int64 :offset 16)
  (window-title (:struct cna-string-view) :offset 24)
  (callbacks :pointer :offset 40))

(defconstant +sizeof-cna-game-create-info+ 48)
(defconstant +alignof-cna-game-create-info+ 8)

;;; CNA_TextureInfo -- 16 bytes, 4-byte aligned, from texture.h.
(defcstruct (cna-texture-info :size 16)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (level-count :uint32 :offset 8)
  (format :uint32 :offset 12))

(defconstant +sizeof-cna-texture-info+ 16)
(defconstant +alignof-cna-texture-info+ 4)

;;; CNA_Texture2DDecodeInfo -- 24 bytes, 4-byte aligned, from texture.h.
(defcstruct (cna-texture-2d-decode-info :size 24)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (width :uint32 :offset 8)
  (height :uint32 :offset 12)
  (zoom :uint8 :offset 16)
  (reserved :uint8 :offset 17 :count 7))

(defconstant +sizeof-cna-texture-2d-decode-info+ 24)
(defconstant +alignof-cna-texture-2d-decode-info+ 4)

;;; CNA_Texture2DStorageInfo -- 16 bytes, 4-byte aligned, from texture.h.
(defcstruct (cna-texture-2d-storage-info :size 16)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (has-renderer :uint8 :offset 8)
  (has-cpu-shadow :uint8 :offset 9)
  (reserved :uint8 :offset 10 :count 6))

(defconstant +sizeof-cna-texture-2d-storage-info+ 16)
(defconstant +alignof-cna-texture-2d-storage-info+ 4)

;;; CNA_SpriteCommand -- 72 bytes, 8-byte aligned, from graphics.h.
(defcstruct (cna-sprite-command :size 72)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (texture :uint64 :offset 8)
  (destination (:struct cna-rectangle) :offset 16)
  (source (:struct cna-rectangle) :offset 32)
  (color (:struct cna-color) :offset 48)
  (rotation :float :offset 52)
  (origin (:struct cna-vector-2) :offset 56)
  (effects :uint32 :offset 64)
  (layer-depth :float :offset 68))

(defconstant +sizeof-cna-sprite-command+ 72)
(defconstant +alignof-cna-sprite-command+ 8)

;;; CNA_KeyboardState -- 40 bytes, 8-byte aligned, from input.h.
(defcstruct (cna-keyboard-state :size 40)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (pressed-key-words :uint64 :offset 8 :count 4))

(defconstant +sizeof-cna-keyboard-state+ 40)
(defconstant +alignof-cna-keyboard-state+ 8)

;;; CNA_MouseState -- 32 bytes, 4-byte aligned, from input.h.
(defcstruct (cna-mouse-state :size 32)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (x :int32 :offset 8)
  (y :int32 :offset 12)
  (scroll-wheel :int32 :offset 16)
  (horizontal-scroll-wheel :int32 :offset 20)
  (pressed-buttons :uint32 :offset 24)
  (reserved :uint32 :offset 28))

(defconstant +sizeof-cna-mouse-state+ 32)
(defconstant +alignof-cna-mouse-state+ 4)

;;; CNA_GamePadAnalogState -- 24 bytes, 4-byte aligned, from input.h.
(defcstruct (cna-game-pad-analog-state :size 24)
  (left-thumb-stick (:struct cna-vector-2) :offset 0)
  (right-thumb-stick (:struct cna-vector-2) :offset 8)
  (left-trigger :float :offset 16)
  (right-trigger :float :offset 20))

(defconstant +sizeof-cna-game-pad-analog-state+ 24)
(defconstant +alignof-cna-game-pad-analog-state+ 4)

;;; CNA_GamePadState -- 48 bytes, 4-byte aligned, from input.h.
(defcstruct (cna-game-pad-state :size 48)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (is-connected :uint8 :offset 8)
  (reserved-0 :uint8 :offset 9 :count 3)
  (packet-number :int32 :offset 12)
  (pressed-buttons :uint32 :offset 16)
  (reserved-1 :uint32 :offset 20)
  (analog (:struct cna-game-pad-analog-state) :offset 24))

(defconstant +sizeof-cna-game-pad-state+ 48)
(defconstant +alignof-cna-game-pad-state+ 4)

;;; CNA_GamePadCapabilities -- 48 bytes, 4-byte aligned, from input_gamepad.h.
(defcstruct (cna-game-pad-capabilities :size 48)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (gamepad-type :uint32 :offset 8)
  (is-connected :uint8 :offset 12)
  (has-a-button :uint8 :offset 13)
  (has-b-button :uint8 :offset 14)
  (has-x-button :uint8 :offset 15)
  (has-y-button :uint8 :offset 16)
  (has-back-button :uint8 :offset 17)
  (has-start-button :uint8 :offset 18)
  (has-big-button :uint8 :offset 19)
  (has-dpad-up-button :uint8 :offset 20)
  (has-dpad-down-button :uint8 :offset 21)
  (has-dpad-left-button :uint8 :offset 22)
  (has-dpad-right-button :uint8 :offset 23)
  (has-left-shoulder-button :uint8 :offset 24)
  (has-right-shoulder-button :uint8 :offset 25)
  (has-left-stick-button :uint8 :offset 26)
  (has-right-stick-button :uint8 :offset 27)
  (has-left-x-thumb-stick :uint8 :offset 28)
  (has-left-y-thumb-stick :uint8 :offset 29)
  (has-right-x-thumb-stick :uint8 :offset 30)
  (has-right-y-thumb-stick :uint8 :offset 31)
  (has-left-trigger :uint8 :offset 32)
  (has-right-trigger :uint8 :offset 33)
  (has-left-vibration-motor :uint8 :offset 34)
  (has-right-vibration-motor :uint8 :offset 35)
  (has-voice-support :uint8 :offset 36)
  (has-light-bar-ext :uint8 :offset 37)
  (has-trigger-vibration-motors-ext :uint8 :offset 38)
  (has-misc-1-ext :uint8 :offset 39)
  (has-paddle-1-ext :uint8 :offset 40)
  (has-paddle-2-ext :uint8 :offset 41)
  (has-paddle-3-ext :uint8 :offset 42)
  (has-paddle-4-ext :uint8 :offset 43)
  (has-touchpad-ext :uint8 :offset 44)
  (has-gyro-ext :uint8 :offset 45)
  (has-accelerometer-ext :uint8 :offset 46)
  (reserved :uint8 :offset 47 :count 1))

(defconstant +sizeof-cna-game-pad-capabilities+ 48)
(defconstant +alignof-cna-game-pad-capabilities+ 4)

;;; CNA_TouchLocation -- 32 bytes, 4-byte aligned, from input.h.
(defcstruct (cna-touch-location :size 32)
  (id :int32 :offset 0)
  (state :uint32 :offset 4)
  (position (:struct cna-vector-2) :offset 8)
  (previous-state :uint32 :offset 16)
  (previous-position (:struct cna-vector-2) :offset 20)
  (pressure :float :offset 28))

(defconstant +sizeof-cna-touch-location+ 32)
(defconstant +alignof-cna-touch-location+ 4)

;;; CNA_TouchState -- 272 bytes, 4-byte aligned, from input.h.
(defcstruct (cna-touch-state :size 272)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (is-connected :uint8 :offset 8)
  (reserved :uint8 :offset 9 :count 3)
  (touch-count :uint32 :offset 12)
  (touches (:struct cna-touch-location) :offset 16 :count 8))

(defconstant +sizeof-cna-touch-state+ 272)
(defconstant +alignof-cna-touch-state+ 4)

;;; CNA_TouchCapabilities -- 16 bytes, 4-byte aligned, from input.h.
(defcstruct (cna-touch-capabilities :size 16)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (is-connected :uint8 :offset 8)
  (reserved :uint8 :offset 9 :count 3)
  (maximum-touch-count :uint32 :offset 12))

(defconstant +sizeof-cna-touch-capabilities+ 16)
(defconstant +alignof-cna-touch-capabilities+ 4)

;;; CNA_GestureSample -- 64 bytes, 8-byte aligned, from input_touch.h.
(defcstruct (cna-gesture-sample :size 64)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (gesture-type :uint32 :offset 8)
  (finger-id-ext :int32 :offset 12)
  (finger-id-2-ext :int32 :offset 16)
  (reserved :uint32 :offset 20)
  (timestamp-ticks :int64 :offset 24)
  (position (:struct cna-vector-2) :offset 32)
  (position-2 (:struct cna-vector-2) :offset 40)
  (delta (:struct cna-vector-2) :offset 48)
  (delta-2 (:struct cna-vector-2) :offset 56))

(defconstant +sizeof-cna-gesture-sample+ 64)
(defconstant +alignof-cna-gesture-sample+ 8)

;;; CNA_RendererInfo -- 32 bytes, 8-byte aligned, from graphics.h.
(defcstruct (cna-renderer-info :size 32)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (renderer-name-byte-length :uint64 :offset 8)
  (capability-flags :uint64 :offset 16)
  (renderer-type :uint32 :offset 24)
  (max-texture-dimension :uint32 :offset 28))

(defconstant +sizeof-cna-renderer-info+ 32)
(defconstant +alignof-cna-renderer-info+ 8)

;;; CNA_SpriteScaledCommand -- 72 bytes, 8-byte aligned, from graphics.h.
(defcstruct (cna-sprite-scaled-command :size 72)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (texture :uint64 :offset 8)
  (position (:struct cna-vector-2) :offset 16)
  (source (:struct cna-rectangle) :offset 24)
  (color (:struct cna-color) :offset 40)
  (rotation :float :offset 44)
  (origin (:struct cna-vector-2) :offset 48)
  (scale (:struct cna-vector-2) :offset 56)
  (effects :uint32 :offset 64)
  (layer-depth :float :offset 68))

(defconstant +sizeof-cna-sprite-scaled-command+ 72)
(defconstant +alignof-cna-sprite-scaled-command+ 8)

;;; CNA_BlendState -- 56 bytes, 4-byte aligned, from graphics_state.h.
(defcstruct (cna-blend-state :size 56)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (alpha-blend-function :uint32 :offset 8)
  (alpha-destination-blend :uint32 :offset 12)
  (alpha-source-blend :uint32 :offset 16)
  (color-blend-function :uint32 :offset 20)
  (color-destination-blend :uint32 :offset 24)
  (color-source-blend :uint32 :offset 28)
  (color-write-channels :uint32 :offset 32)
  (color-write-channels-1 :uint32 :offset 36)
  (color-write-channels-2 :uint32 :offset 40)
  (color-write-channels-3 :uint32 :offset 44)
  (blend-factor (:struct cna-color) :offset 48)
  (multi-sample-mask :int32 :offset 52))

(defconstant +sizeof-cna-blend-state+ 56)
(defconstant +alignof-cna-blend-state+ 4)

;;; CNA_DepthStencilState -- 64 bytes, 4-byte aligned, from graphics_state.h.
(defcstruct (cna-depth-stencil-state :size 64)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (depth-buffer-enable :uint8 :offset 8)
  (depth-buffer-write-enable :uint8 :offset 9)
  (stencil-enable :uint8 :offset 10)
  (two-sided-stencil-mode :uint8 :offset 11)
  (depth-buffer-function :uint32 :offset 12)
  (stencil-function :uint32 :offset 16)
  (stencil-mask :int32 :offset 20)
  (stencil-write-mask :int32 :offset 24)
  (reference-stencil :int32 :offset 28)
  (stencil-fail :uint32 :offset 32)
  (stencil-depth-buffer-fail :uint32 :offset 36)
  (stencil-pass :uint32 :offset 40)
  (counter-clockwise-stencil-function :uint32 :offset 44)
  (counter-clockwise-stencil-fail :uint32 :offset 48)
  (counter-clockwise-stencil-depth-buffer-fail :uint32 :offset 52)
  (counter-clockwise-stencil-pass :uint32 :offset 56)
  (reserved :uint32 :offset 60))

(defconstant +sizeof-cna-depth-stencil-state+ 64)
(defconstant +alignof-cna-depth-stencil-state+ 4)

;;; CNA_RasterizerState -- 28 bytes, 4-byte aligned, from graphics_state.h.
(defcstruct (cna-rasterizer-state :size 28)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (cull-mode :uint32 :offset 8)
  (fill-mode :uint32 :offset 12)
  (depth-bias :float :offset 16)
  (slope-scale-depth-bias :float :offset 20)
  (multi-sample-anti-alias :uint8 :offset 24)
  (scissor-test-enable :uint8 :offset 25)
  (reserved :uint8 :offset 26 :count 2))

(defconstant +sizeof-cna-rasterizer-state+ 28)
(defconstant +alignof-cna-rasterizer-state+ 4)

;;; CNA_SamplerState -- 40 bytes, 4-byte aligned, from graphics_state.h.
(defcstruct (cna-sampler-state :size 40)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (address-u :uint32 :offset 8)
  (address-v :uint32 :offset 12)
  (address-w :uint32 :offset 16)
  (filter :uint32 :offset 20)
  (max-anisotropy :int32 :offset 24)
  (max-mip-level :int32 :offset 28)
  (mip-map-level-of-detail-bias :float :offset 32)
  (reserved :uint32 :offset 36))

(defconstant +sizeof-cna-sampler-state+ 40)
(defconstant +alignof-cna-sampler-state+ 4)

;;; Offsets and sizes the ABI gate re-checks against CFFI's own view.
(defparameter *native-struct-layouts*
  '(
    (cna-error-info 24 8 ((struct-size 0 4) (struct-version 4 4) (result 8 4) (category 12 4) (message-byte-length 16 8)))
    (cna-string-view 16 8 ((data 0 8) (byte-length 8 8)))
    (cna-color 4 1 ((r 0 1) (g 1 1) (b 2 1) (a 3 1)))
    (cna-rectangle 16 4 ((x 0 4) (y 4 4) (width 8 4) (height 12 4)))
    (cna-point 8 4 ((x 0 4) (y 4 4)))
    (cna-vector-2 8 4 ((x 0 4) (y 4 4)))
    (cna-viewport 24 4 ((x 0 4) (y 4 4) (width 8 4) (height 12 4) (min-depth 16 4) (max-depth 20 4)))
    (cna-game-time 24 8 ((total-game-time-ticks 0 8) (elapsed-game-time-ticks 8 8) (is-running-slowly 16 1) (reserved 17 7)))
    (cna-callback-error 24 8 ((struct-size 0 4) (struct-version 4 4) (message 8 16)))
    (cna-game-callbacks 56 8 ((struct-size 0 4) (struct-version 4 4) (load-content 8 8) (update 16 8) (draw 24 8) (unload-content 32 8) (exiting 40 8) (context 48 8)))
    (cna-game-frame-hooks 56 8 ((struct-size 0 4) (struct-version 4 4) (initialize 8 8) (begin-run 16 8) (end-run 24 8) (begin-draw 32 8) (end-draw 40 8) (context 48 8)))
    (cna-game-create-info 48 8 ((struct-size 0 4) (struct-version 4 4) (is-fixed-time-step 8 1) (reserved 9 7) (target-elapsed-time-ticks 16 8) (window-title 24 16) (callbacks 40 8)))
    (cna-texture-info 16 4 ((struct-size 0 4) (struct-version 4 4) (level-count 8 4) (format 12 4)))
    (cna-texture-2d-decode-info 24 4 ((struct-size 0 4) (struct-version 4 4) (width 8 4) (height 12 4) (zoom 16 1) (reserved 17 7)))
    (cna-texture-2d-storage-info 16 4 ((struct-size 0 4) (struct-version 4 4) (has-renderer 8 1) (has-cpu-shadow 9 1) (reserved 10 6)))
    (cna-sprite-command 72 8 ((struct-size 0 4) (struct-version 4 4) (texture 8 8) (destination 16 16) (source 32 16) (color 48 4) (rotation 52 4) (origin 56 8) (effects 64 4) (layer-depth 68 4)))
    (cna-keyboard-state 40 8 ((struct-size 0 4) (struct-version 4 4) (pressed-key-words 8 32)))
    (cna-mouse-state 32 4 ((struct-size 0 4) (struct-version 4 4) (x 8 4) (y 12 4) (scroll-wheel 16 4) (horizontal-scroll-wheel 20 4) (pressed-buttons 24 4) (reserved 28 4)))
    (cna-game-pad-analog-state 24 4 ((left-thumb-stick 0 8) (right-thumb-stick 8 8) (left-trigger 16 4) (right-trigger 20 4)))
    (cna-game-pad-state 48 4 ((struct-size 0 4) (struct-version 4 4) (is-connected 8 1) (reserved-0 9 3) (packet-number 12 4) (pressed-buttons 16 4) (reserved-1 20 4) (analog 24 24)))
    (cna-game-pad-capabilities 48 4 ((struct-size 0 4) (struct-version 4 4) (gamepad-type 8 4) (is-connected 12 1) (has-a-button 13 1) (has-b-button 14 1) (has-x-button 15 1) (has-y-button 16 1) (has-back-button 17 1) (has-start-button 18 1) (has-big-button 19 1) (has-dpad-up-button 20 1) (has-dpad-down-button 21 1) (has-dpad-left-button 22 1) (has-dpad-right-button 23 1) (has-left-shoulder-button 24 1) (has-right-shoulder-button 25 1) (has-left-stick-button 26 1) (has-right-stick-button 27 1) (has-left-x-thumb-stick 28 1) (has-left-y-thumb-stick 29 1) (has-right-x-thumb-stick 30 1) (has-right-y-thumb-stick 31 1) (has-left-trigger 32 1) (has-right-trigger 33 1) (has-left-vibration-motor 34 1) (has-right-vibration-motor 35 1) (has-voice-support 36 1) (has-light-bar-ext 37 1) (has-trigger-vibration-motors-ext 38 1) (has-misc-1-ext 39 1) (has-paddle-1-ext 40 1) (has-paddle-2-ext 41 1) (has-paddle-3-ext 42 1) (has-paddle-4-ext 43 1) (has-touchpad-ext 44 1) (has-gyro-ext 45 1) (has-accelerometer-ext 46 1) (reserved 47 1)))
    (cna-touch-location 32 4 ((id 0 4) (state 4 4) (position 8 8) (previous-state 16 4) (previous-position 20 8) (pressure 28 4)))
    (cna-touch-state 272 4 ((struct-size 0 4) (struct-version 4 4) (is-connected 8 1) (reserved 9 3) (touch-count 12 4) (touches 16 256)))
    (cna-touch-capabilities 16 4 ((struct-size 0 4) (struct-version 4 4) (is-connected 8 1) (reserved 9 3) (maximum-touch-count 12 4)))
    (cna-gesture-sample 64 8 ((struct-size 0 4) (struct-version 4 4) (gesture-type 8 4) (finger-id-ext 12 4) (finger-id-2-ext 16 4) (reserved 20 4) (timestamp-ticks 24 8) (position 32 8) (position-2 40 8) (delta 48 8) (delta-2 56 8)))
    (cna-renderer-info 32 8 ((struct-size 0 4) (struct-version 4 4) (renderer-name-byte-length 8 8) (capability-flags 16 8) (renderer-type 24 4) (max-texture-dimension 28 4)))
    (cna-sprite-scaled-command 72 8 ((struct-size 0 4) (struct-version 4 4) (texture 8 8) (position 16 8) (source 24 16) (color 40 4) (rotation 44 4) (origin 48 8) (scale 56 8) (effects 64 4) (layer-depth 68 4)))
    (cna-blend-state 56 4 ((struct-size 0 4) (struct-version 4 4) (alpha-blend-function 8 4) (alpha-destination-blend 12 4) (alpha-source-blend 16 4) (color-blend-function 20 4) (color-destination-blend 24 4) (color-source-blend 28 4) (color-write-channels 32 4) (color-write-channels-1 36 4) (color-write-channels-2 40 4) (color-write-channels-3 44 4) (blend-factor 48 4) (multi-sample-mask 52 4)))
    (cna-depth-stencil-state 64 4 ((struct-size 0 4) (struct-version 4 4) (depth-buffer-enable 8 1) (depth-buffer-write-enable 9 1) (stencil-enable 10 1) (two-sided-stencil-mode 11 1) (depth-buffer-function 12 4) (stencil-function 16 4) (stencil-mask 20 4) (stencil-write-mask 24 4) (reference-stencil 28 4) (stencil-fail 32 4) (stencil-depth-buffer-fail 36 4) (stencil-pass 40 4) (counter-clockwise-stencil-function 44 4) (counter-clockwise-stencil-fail 48 4) (counter-clockwise-stencil-depth-buffer-fail 52 4) (counter-clockwise-stencil-pass 56 4) (reserved 60 4)))
    (cna-rasterizer-state 28 4 ((struct-size 0 4) (struct-version 4 4) (cull-mode 8 4) (fill-mode 12 4) (depth-bias 16 4) (slope-scale-depth-bias 20 4) (multi-sample-anti-alias 24 1) (scissor-test-enable 25 1) (reserved 26 2)))
    (cna-sampler-state 40 4 ((struct-size 0 4) (struct-version 4 4) (address-u 8 4) (address-v 12 4) (address-w 16 4) (filter 20 4) (max-anisotropy 24 4) (max-mip-level 28 4) (mip-map-level-of-detail-bias 32 4) (reserved 36 4))))
  "NAME SIZE ALIGN ((FIELD OFFSET SIZE)...) for every bound native struct.")

