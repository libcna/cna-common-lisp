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

;;; CNA_SpriteBatchBeginInfo -- 16 bytes, 4-byte aligned, from graphics.h.
(defcstruct (cna-sprite-batch-begin-info :size 16)
  (struct-size :uint32 :offset 0)
  (struct-version :uint32 :offset 4)
  (sort-mode :uint32 :offset 8)
  (reserved :uint32 :offset 12))

(defconstant +sizeof-cna-sprite-batch-begin-info+ 16)
(defconstant +alignof-cna-sprite-batch-begin-info+ 4)

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
    (cna-sprite-batch-begin-info 16 4 ((struct-size 0 4) (struct-version 4 4) (sort-mode 8 4) (reserved 12 4)))
    (cna-sprite-command 72 8 ((struct-size 0 4) (struct-version 4 4) (texture 8 8) (destination 16 16) (source 32 16) (color 48 4) (rotation 52 4) (origin 56 8) (effects 64 4) (layer-depth 68 4)))
    (cna-keyboard-state 40 8 ((struct-size 0 4) (struct-version 4 4) (pressed-key-words 8 32)))
    (cna-renderer-info 32 8 ((struct-size 0 4) (struct-version 4 4) (renderer-name-byte-length 8 8) (capability-flags 16 8) (renderer-type 24 4) (max-texture-dimension 28 4))))
  "NAME SIZE ALIGN ((FIELD OFFSET SIZE)...) for every bound native struct.")

