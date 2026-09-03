;;;; functions.generated.lisp --- GENERATED FILE, DO NOT EDIT.
;;;;
;;;; Produced by tools/native-abi/generate.py from tools/native-abi/manifest.json
;;;; and the canonical CNA C headers.  Edit the manifest, then regenerate:
;;;;
;;;;   python3 tools/native-abi/generate.py --headers <cna>/modules/c-api/include \
;;;;       --baseline <cna>/tools/c-api/abi_baseline.json
;;;;
;;;; tests/structure/generated-files.lisp fails if this file is stale.

(in-package #:cna-lisp.internal.ffi)

;;; One DEFCFUN per bound native route. A by-value aggregate parameter
;;; appears as one scalar per System V AMD64 eightbyte; see
;;; docs/native-abi.md for why, and tools/native-abi/valueprobe.generated.c
;;; for the run-time proof that it is exact.

;;; uint32_t cna_get_abi_version(void)
(defcfun ("cna_get_abi_version" %get-abi-version) :uint32)

;;; CNA_Result cna_error_get_last_info(CNA_ErrorInfo* out_info)
(defcfun ("cna_error_get_last_info" %error-get-last-info) :uint32
  (out-info :pointer))

;;; CNA_Result cna_error_get_last_message_size(uint64_t* out_bytes)
(defcfun ("cna_error_get_last_message_size" %error-get-last-message-size) :uint32
  (out-bytes :pointer))

;;; CNA_Result cna_error_copy_last_message(char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_error_copy_last_message" %error-copy-last-message) :uint32
  (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_game_create(const CNA_GameCreateInfo* create_info, CNA_Handle* out_game)
(defcfun ("cna_game_create" %game-create) :uint32
  (create-info :pointer) (out-game :pointer))

;;; CNA_Result cna_game_destroy(CNA_Handle game)
(defcfun ("cna_game_destroy" %game-destroy) :uint32
  (game :uint64))

;;; CNA_Result cna_game_run(CNA_Handle game)
(defcfun ("cna_game_run" %game-run) :uint32
  (game :uint64))

;;; CNA_Result cna_game_run_one_frame(CNA_Handle game)
(defcfun ("cna_game_run_one_frame" %game-run-one-frame) :uint32
  (game :uint64))

;;; CNA_Result cna_game_tick(CNA_Handle game)
(defcfun ("cna_game_tick" %game-tick) :uint32
  (game :uint64))

;;; CNA_Result cna_game_request_exit(CNA_Handle game)
(defcfun ("cna_game_request_exit" %game-request-exit) :uint32
  (game :uint64))

;;; CNA_Result cna_game_suppress_draw(CNA_Handle game)
(defcfun ("cna_game_suppress_draw" %game-suppress-draw) :uint32
  (game :uint64))

;;; CNA_Result cna_game_reset_elapsed_time(CNA_Handle game)
(defcfun ("cna_game_reset_elapsed_time" %game-reset-elapsed-time) :uint32
  (game :uint64))

;;; CNA_Result cna_game_clear(CNA_Handle game, CNA_Color color)
(defcfun ("cna_game_clear" %game-clear) :uint32
  (game :uint64) (color-0 :uint32))

;;; CNA_Result cna_game_set_window_title(CNA_Handle game, CNA_StringView title)
(defcfun ("cna_game_set_window_title" %game-set-window-title) :uint32
  (game :uint64) (title-0 :pointer) (title-1 :uint64))

;;; CNA_Result cna_game_set_frame_hooks_ext(CNA_Handle game, const CNA_GameFrameHooks* hooks)
(defcfun ("cna_game_set_frame_hooks_ext" %game-set-frame-hooks-ext) :uint32
  (game :uint64) (hooks :pointer))

;;; CNA_Result cna_game_get_is_active(CNA_Handle game, CNA_Bool* out_active)
(defcfun ("cna_game_get_is_active" %game-get-is-active) :uint32
  (game :uint64) (out-active :pointer))

;;; CNA_Result cna_game_get_is_mouse_visible(CNA_Handle game, CNA_Bool* out_visible)
(defcfun ("cna_game_get_is_mouse_visible" %game-get-is-mouse-visible) :uint32
  (game :uint64) (out-visible :pointer))

;;; CNA_Result cna_game_set_is_mouse_visible(CNA_Handle game, CNA_Bool visible)
(defcfun ("cna_game_set_is_mouse_visible" %game-set-is-mouse-visible) :uint32
  (game :uint64) (visible :uint8))

;;; CNA_Result cna_game_get_is_fixed_time_step(CNA_Handle game, CNA_Bool* out_fixed)
(defcfun ("cna_game_get_is_fixed_time_step" %game-get-is-fixed-time-step) :uint32
  (game :uint64) (out-fixed :pointer))

;;; CNA_Result cna_game_set_is_fixed_time_step(CNA_Handle game, CNA_Bool fixed)
(defcfun ("cna_game_set_is_fixed_time_step" %game-set-is-fixed-time-step) :uint32
  (game :uint64) (fixed :uint8))

;;; CNA_Result cna_game_get_target_elapsed_time_ticks(CNA_Handle game, int64_t* out_ticks)
(defcfun ("cna_game_get_target_elapsed_time_ticks" %game-get-target-elapsed-time-ticks) :uint32
  (game :uint64) (out-ticks :pointer))

;;; CNA_Result cna_game_set_target_elapsed_time_ticks(CNA_Handle game, int64_t ticks)
(defcfun ("cna_game_set_target_elapsed_time_ticks" %game-set-target-elapsed-time-ticks) :uint32
  (game :uint64) (ticks :int64))

;;; CNA_Result cna_game_get_inactive_sleep_time_ticks(CNA_Handle game, int64_t* out_ticks)
(defcfun ("cna_game_get_inactive_sleep_time_ticks" %game-get-inactive-sleep-time-ticks) :uint32
  (game :uint64) (out-ticks :pointer))

;;; CNA_Result cna_game_set_inactive_sleep_time_ticks(CNA_Handle game, int64_t ticks)
(defcfun ("cna_game_set_inactive_sleep_time_ticks" %game-set-inactive-sleep-time-ticks) :uint32
  (game :uint64) (ticks :int64))

;;; CNA_Result cna_game_get_type_name_size(CNA_Handle game, uint64_t* out_bytes)
(defcfun ("cna_game_get_type_name_size" %game-get-type-name-size) :uint32
  (game :uint64) (out-bytes :pointer))

;;; CNA_Result cna_game_copy_type_name(CNA_Handle game, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_game_copy_type_name" %game-copy-type-name) :uint32
  (game :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_game_get_graphics_device(CNA_Handle game, CNA_Handle* out_graphics_device)
(defcfun ("cna_game_get_graphics_device" %game-get-graphics-device) :uint32
  (game :uint64) (out-graphics-device :pointer))

;;; CNA_Result cna_graphics_device_get_viewport(CNA_Handle graphics_device, CNA_Viewport* out_viewport)
(defcfun ("cna_graphics_device_get_viewport" %graphics-device-get-viewport) :uint32
  (graphics-device :uint64) (out-viewport :pointer))

;;; CNA_Result cna_graphics_device_clear_rgba(CNA_Handle graphics_device, float r, float g, float b, float a)
(defcfun ("cna_graphics_device_clear_rgba" %graphics-device-clear-rgba) :uint32
  (graphics-device :uint64) (r :float) (g :float) (b :float) (a :float))

;;; CNA_Result cna_graphics_device_present(CNA_Handle graphics_device)
(defcfun ("cna_graphics_device_present" %graphics-device-present) :uint32
  (graphics-device :uint64))

;;; CNA_Result cna_graphics_device_get_renderer_info(CNA_Handle graphics_device, CNA_RendererInfo* out_info)
(defcfun ("cna_graphics_device_get_renderer_info" %graphics-device-get-renderer-info) :uint32
  (graphics-device :uint64) (out-info :pointer))

;;; CNA_Result cna_graphics_device_copy_renderer_name(CNA_Handle graphics_device, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_graphics_device_copy_renderer_name" %graphics-device-copy-renderer-name) :uint32
  (graphics-device :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_device_get_type_name_size(CNA_Handle graphics_device, uint64_t* out_bytes)
(defcfun ("cna_graphics_device_get_type_name_size" %graphics-device-get-type-name-size) :uint32
  (graphics-device :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_device_copy_type_name(CNA_Handle graphics_device, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_graphics_device_copy_type_name" %graphics-device-copy-type-name) :uint32
  (graphics-device :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_device_manager_create(CNA_Handle game, CNA_GraphicsDeviceManagerHandle* out_manager)
(defcfun ("cna_graphics_device_manager_create" %graphics-device-manager-create) :uint32
  (game :uint64) (out-manager :pointer))

;;; CNA_Result cna_graphics_device_manager_destroy(CNA_GraphicsDeviceManagerHandle manager)
(defcfun ("cna_graphics_device_manager_destroy" %graphics-device-manager-destroy) :uint32
  (manager :uint64))

;;; CNA_Result cna_graphics_device_manager_apply_changes(CNA_GraphicsDeviceManagerHandle manager)
(defcfun ("cna_graphics_device_manager_apply_changes" %graphics-device-manager-apply-changes) :uint32
  (manager :uint64))

;;; CNA_Result cna_graphics_device_manager_toggle_full_screen(CNA_GraphicsDeviceManagerHandle manager)
(defcfun ("cna_graphics_device_manager_toggle_full_screen" %graphics-device-manager-toggle-full-screen) :uint32
  (manager :uint64))

;;; CNA_Result cna_graphics_device_manager_get_is_full_screen(CNA_GraphicsDeviceManagerHandle manager, CNA_Bool* out_full_screen)
(defcfun ("cna_graphics_device_manager_get_is_full_screen" %graphics-device-manager-get-is-full-screen) :uint32
  (manager :uint64) (out-full-screen :pointer))

;;; CNA_Result cna_graphics_device_manager_set_is_full_screen(CNA_GraphicsDeviceManagerHandle manager, CNA_Bool full_screen)
(defcfun ("cna_graphics_device_manager_set_is_full_screen" %graphics-device-manager-set-is-full-screen) :uint32
  (manager :uint64) (full-screen :uint8))

;;; CNA_Result cna_graphics_device_manager_get_preferred_back_buffer_width(CNA_GraphicsDeviceManagerHandle manager, int32_t* out_width)
(defcfun ("cna_graphics_device_manager_get_preferred_back_buffer_width" %graphics-device-manager-get-preferred-back-buffer-width) :uint32
  (manager :uint64) (out-width :pointer))

;;; CNA_Result cna_graphics_device_manager_set_preferred_back_buffer_width(CNA_GraphicsDeviceManagerHandle manager, int32_t width)
(defcfun ("cna_graphics_device_manager_set_preferred_back_buffer_width" %graphics-device-manager-set-preferred-back-buffer-width) :uint32
  (manager :uint64) (width :int32))

;;; CNA_Result cna_graphics_device_manager_get_preferred_back_buffer_height(CNA_GraphicsDeviceManagerHandle manager, int32_t* out_height)
(defcfun ("cna_graphics_device_manager_get_preferred_back_buffer_height" %graphics-device-manager-get-preferred-back-buffer-height) :uint32
  (manager :uint64) (out-height :pointer))

;;; CNA_Result cna_graphics_device_manager_set_preferred_back_buffer_height(CNA_GraphicsDeviceManagerHandle manager, int32_t height)
(defcfun ("cna_graphics_device_manager_set_preferred_back_buffer_height" %graphics-device-manager-set-preferred-back-buffer-height) :uint32
  (manager :uint64) (height :int32))

;;; CNA_Result cna_graphics_device_manager_get_synchronize_with_vertical_retrace(CNA_GraphicsDeviceManagerHandle manager, CNA_Bool* out_synchronize)
(defcfun ("cna_graphics_device_manager_get_synchronize_with_vertical_retrace" %graphics-device-manager-get-synchronize-with-vertical-retrace) :uint32
  (manager :uint64) (out-synchronize :pointer))

;;; CNA_Result cna_graphics_device_manager_set_synchronize_with_vertical_retrace(CNA_GraphicsDeviceManagerHandle manager, CNA_Bool synchronize)
(defcfun ("cna_graphics_device_manager_set_synchronize_with_vertical_retrace" %graphics-device-manager-set-synchronize-with-vertical-retrace) :uint32
  (manager :uint64) (synchronize :uint8))

;;; CNA_Result cna_graphics_device_manager_get_graphics_device(CNA_GraphicsDeviceManagerHandle manager, CNA_Handle* out_graphics_device)
(defcfun ("cna_graphics_device_manager_get_graphics_device" %graphics-device-manager-get-graphics-device) :uint32
  (manager :uint64) (out-graphics-device :pointer))

;;; CNA_Result cna_texture2d_create_from_encoded_memory(CNA_Handle graphics_device, const uint8_t* encoded_data, uint64_t encoded_byte_count, const CNA_Texture2DDecodeInfo* decode_info, CNA_Handle* out_texture)
(defcfun ("cna_texture2d_create_from_encoded_memory" %texture-2d-create-from-encoded-memory) :uint32
  (graphics-device :uint64) (encoded-data :pointer) (encoded-byte-count :uint64) (decode-info :pointer) (out-texture :pointer))

;;; CNA_Result cna_texture2d_create_from_file_with_device(CNA_Handle graphics_device, CNA_StringView path, CNA_Handle* out_texture)
(defcfun ("cna_texture2d_create_from_file_with_device" %texture-2d-create-from-file-with-device) :uint32
  (graphics-device :uint64) (path-0 :pointer) (path-1 :uint64) (out-texture :pointer))

;;; CNA_Result cna_texture2d_destroy(CNA_Handle texture)
(defcfun ("cna_texture2d_destroy" %texture-2d-destroy) :uint32
  (texture :uint64))

;;; CNA_Result cna_texture2d_get_storage_info(CNA_Handle texture, CNA_Texture2DStorageInfo* out_info)
(defcfun ("cna_texture2d_get_storage_info" %texture-2d-get-storage-info) :uint32
  (texture :uint64) (out-info :pointer))

;;; CNA_Result cna_texture2d_get_type_name_byte_count(CNA_Handle texture, uint64_t* out_byte_count)
(defcfun ("cna_texture2d_get_type_name_byte_count" %texture-2d-get-type-name-byte-count) :uint32
  (texture :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_texture2d_copy_type_name(CNA_Handle texture, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_texture2d_copy_type_name" %texture-2d-copy-type-name) :uint32
  (texture :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_texture_get_info(CNA_Handle texture, CNA_TextureInfo* out_info)
(defcfun ("cna_texture_get_info" %texture-get-info) :uint32
  (texture :uint64) (out-info :pointer))

;;; CNA_Result cna_sprite_batch_create(CNA_Handle graphics_device, CNA_Handle* out_sprite_batch)
(defcfun ("cna_sprite_batch_create" %sprite-batch-create) :uint32
  (graphics-device :uint64) (out-sprite-batch :pointer))

;;; CNA_Result cna_sprite_batch_destroy(CNA_Handle sprite_batch)
(defcfun ("cna_sprite_batch_destroy" %sprite-batch-destroy) :uint32
  (sprite-batch :uint64))

;;; CNA_Result cna_sprite_batch_begin(CNA_Handle sprite_batch, const CNA_SpriteBatchBeginInfo* begin_info)
(defcfun ("cna_sprite_batch_begin" %sprite-batch-begin) :uint32
  (sprite-batch :uint64) (begin-info :pointer))

;;; CNA_Result cna_sprite_batch_submit_many(CNA_Handle sprite_batch, const CNA_SpriteCommand* commands, uint64_t command_count)
(defcfun ("cna_sprite_batch_submit_many" %sprite-batch-submit-many) :uint32
  (sprite-batch :uint64) (commands :pointer) (command-count :uint64))

;;; CNA_Result cna_sprite_batch_submit_scaled_many(CNA_Handle sprite_batch, const CNA_SpriteScaledCommand* commands, uint64_t command_count)
(defcfun ("cna_sprite_batch_submit_scaled_many" %sprite-batch-submit-scaled-many) :uint32
  (sprite-batch :uint64) (commands :pointer) (command-count :uint64))

;;; CNA_Result cna_sprite_batch_end(CNA_Handle sprite_batch)
(defcfun ("cna_sprite_batch_end" %sprite-batch-end) :uint32
  (sprite-batch :uint64))

;;; CNA_Result cna_sprite_batch_get_type_name_size(CNA_Handle sprite_batch, uint64_t* out_bytes)
(defcfun ("cna_sprite_batch_get_type_name_size" %sprite-batch-get-type-name-size) :uint32
  (sprite-batch :uint64) (out-bytes :pointer))

;;; CNA_Result cna_sprite_batch_copy_type_name(CNA_Handle sprite_batch, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_sprite_batch_copy_type_name" %sprite-batch-copy-type-name) :uint32
  (sprite-batch :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_keyboard_get_state(CNA_Handle game, CNA_KeyboardState* out_state)
(defcfun ("cna_keyboard_get_state" %keyboard-get-state) :uint32
  (game :uint64) (out-state :pointer))

;;; CNA_Result cna_keyboard_get_state_for_player(CNA_Handle game, CNA_PlayerIndex player_index, CNA_KeyboardState* out_state)
(defcfun ("cna_keyboard_get_state_for_player" %keyboard-get-state-for-player) :uint32
  (game :uint64) (player-index :uint32) (out-state :pointer))

;;; CNA_Result cna_keyboard_state_init(CNA_KeyboardState* out_state)
(defcfun ("cna_keyboard_state_init" %keyboard-state-init) :uint32
  (out-state :pointer))

;;; CNA_Result cna_keyboard_state_init_from_keys(const CNA_Key* keys, uint64_t count, CNA_KeyboardState* out_state)
(defcfun ("cna_keyboard_state_init_from_keys" %keyboard-state-init-from-keys) :uint32
  (keys :pointer) (count :uint64) (out-state :pointer))

;;; CNA_Result cna_keyboard_state_get_key_state(const CNA_KeyboardState* state, CNA_Key key, CNA_KeyState* out_key_state)
(defcfun ("cna_keyboard_state_get_key_state" %keyboard-state-get-key-state) :uint32
  (state :pointer) (key :uint32) (out-key-state :pointer))

;;; CNA_Result cna_keyboard_state_equals(const CNA_KeyboardState* left, const CNA_KeyboardState* right, CNA_Bool* out_equals)
(defcfun ("cna_keyboard_state_equals" %keyboard-state-equals) :uint32
  (left :pointer) (right :pointer) (out-equals :pointer))

;;; CNA_Result cna_keyboard_state_get_hash_code(const CNA_KeyboardState* state, int32_t* out_hash)
(defcfun ("cna_keyboard_state_get_hash_code" %keyboard-state-get-hash-code) :uint32
  (state :pointer) (out-hash :pointer))

;;; CNA_Result cna_mouse_get_state(CNA_Handle game, CNA_MouseState* out_state)
(defcfun ("cna_mouse_get_state" %mouse-get-state) :uint32
  (game :uint64) (out-state :pointer))

;;; CNA_Result cna_mouse_set_position(CNA_Handle game, int32_t x, int32_t y)
(defcfun ("cna_mouse_set_position" %mouse-set-position) :uint32
  (game :uint64) (x :int32) (y :int32))

;;; CNA_Result cna_mouse_state_init(CNA_MouseState* out_state)
(defcfun ("cna_mouse_state_init" %mouse-state-init) :uint32
  (out-state :pointer))

;;; CNA_Result cna_mouse_state_init_from_values(int32_t x, int32_t y, int32_t scroll_wheel, CNA_MouseButtonFlags pressed_buttons, CNA_MouseState* out_state)
(defcfun ("cna_mouse_state_init_from_values" %mouse-state-init-from-values) :uint32
  (x :int32) (y :int32) (scroll-wheel :int32) (pressed-buttons :uint32) (out-state :pointer))

;;; CNA_Result cna_mouse_state_equals(const CNA_MouseState* left, const CNA_MouseState* right, CNA_Bool* out_equals)
(defcfun ("cna_mouse_state_equals" %mouse-state-equals) :uint32
  (left :pointer) (right :pointer) (out-equals :pointer))

;;; CNA_Result cna_gamepad_get_state(CNA_Handle game, CNA_PlayerIndex player_index, CNA_GamePadState* out_state)
(defcfun ("cna_gamepad_get_state" %gamepad-get-state) :uint32
  (game :uint64) (player-index :uint32) (out-state :pointer))

;;; CNA_Result cna_gamepad_get_state_with_dead_zone(CNA_Handle game, CNA_PlayerIndex player_index, CNA_GamePadDeadZone dead_zone_mode, CNA_GamePadState* out_state)
(defcfun ("cna_gamepad_get_state_with_dead_zone" %gamepad-get-state-with-dead-zone) :uint32
  (game :uint64) (player-index :uint32) (dead-zone-mode :uint32) (out-state :pointer))

;;; CNA_Result cna_gamepad_get_capabilities(CNA_Handle game, CNA_PlayerIndex player_index, CNA_GamePadCapabilities* out_capabilities)
(defcfun ("cna_gamepad_get_capabilities" %gamepad-get-capabilities) :uint32
  (game :uint64) (player-index :uint32) (out-capabilities :pointer))

;;; CNA_Result cna_gamepad_set_vibration(CNA_Handle game, CNA_PlayerIndex player_index, float left_motor, float right_motor, CNA_Bool* out_applied)
(defcfun ("cna_gamepad_set_vibration" %gamepad-set-vibration) :uint32
  (game :uint64) (player-index :uint32) (left-motor :float) (right-motor :float) (out-applied :pointer))

(defparameter *bound-native-functions*
  '(("cna_get_abi_version" %get-abi-version :uint32 () :thread :any :ownership "none")
    ("cna_error_get_last_info" %error-get-last-info :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_error_get_last_message_size" %error-get-last-message-size :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_error_copy_last_message" %error-copy-last-message :uint32 (:pointer :uint64 :pointer) :thread :any :ownership "none")
    ("cna_game_create" %game-create :uint32 (:pointer :pointer) :thread :creates-affinity :ownership "creates-owned:game")
    ("cna_game_destroy" %game-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:game")
    ("cna_game_run" %game-run :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_run_one_frame" %game-run-one-frame :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_tick" %game-tick :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_request_exit" %game-request-exit :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_suppress_draw" %game-suppress-draw :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_reset_elapsed_time" %game-reset-elapsed-time :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_clear" %game-clear :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_game_set_window_title" %game-set-window-title :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_game_set_frame_hooks_ext" %game-set-frame-hooks-ext :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows-table:copied-during-call")
    ("cna_game_get_is_active" %game-get-is-active :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_get_is_mouse_visible" %game-get-is-mouse-visible :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_set_is_mouse_visible" %game-set-is-mouse-visible :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_game_get_is_fixed_time_step" %game-get-is-fixed-time-step :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_set_is_fixed_time_step" %game-set-is-fixed-time-step :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_game_get_target_elapsed_time_ticks" %game-get-target-elapsed-time-ticks :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_set_target_elapsed_time_ticks" %game-set-target-elapsed-time-ticks :uint32 (:uint64 :int64) :thread :owner :ownership "none")
    ("cna_game_get_inactive_sleep_time_ticks" %game-get-inactive-sleep-time-ticks :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_set_inactive_sleep_time_ticks" %game-set-inactive-sleep-time-ticks :uint32 (:uint64 :int64) :thread :owner :ownership "none")
    ("cna_game_get_type_name_size" %game-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_copy_type_name" %game-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_get_graphics_device" %game-get-graphics-device :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows-callback-scoped:graphics-device")
    ("cna_graphics_device_get_viewport" %graphics-device-get-viewport :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_clear_rgba" %graphics-device-clear-rgba :uint32 (:uint64 :float :float :float :float) :thread :owner :ownership "none")
    ("cna_graphics_device_present" %graphics-device-present :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_get_renderer_info" %graphics-device-get-renderer-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_copy_renderer_name" %graphics-device-copy-renderer-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_type_name_size" %graphics-device-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_copy_type_name" %graphics-device-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_create" %graphics-device-manager-create :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:graphics-device-manager")
    ("cna_graphics_device_manager_destroy" %graphics-device-manager-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:graphics-device-manager")
    ("cna_graphics_device_manager_apply_changes" %graphics-device-manager-apply-changes :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_toggle_full_screen" %graphics-device-manager-toggle-full-screen :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_is_full_screen" %graphics-device-manager-get-is-full-screen :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_is_full_screen" %graphics-device-manager-set-is-full-screen :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_preferred_back_buffer_width" %graphics-device-manager-get-preferred-back-buffer-width :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_preferred_back_buffer_width" %graphics-device-manager-set-preferred-back-buffer-width :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_preferred_back_buffer_height" %graphics-device-manager-get-preferred-back-buffer-height :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_preferred_back_buffer_height" %graphics-device-manager-set-preferred-back-buffer-height :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_synchronize_with_vertical_retrace" %graphics-device-manager-get-synchronize-with-vertical-retrace :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_synchronize_with_vertical_retrace" %graphics-device-manager-set-synchronize-with-vertical-retrace :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_graphics_device" %graphics-device-manager-get-graphics-device :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows-callback-scoped:graphics-device")
    ("cna_texture2d_create_from_encoded_memory" %texture-2d-create-from-encoded-memory :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:texture-2d:child-of-game")
    ("cna_texture2d_create_from_file_with_device" %texture-2d-create-from-file-with-device :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:texture-2d:child-of-game")
    ("cna_texture2d_destroy" %texture-2d-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:texture-2d")
    ("cna_texture2d_get_storage_info" %texture-2d-get-storage-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texture2d_get_type_name_byte_count" %texture-2d-get-type-name-byte-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texture2d_copy_type_name" %texture-2d-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texture_get_info" %texture-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_batch_create" %sprite-batch-create :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:sprite-batch:child-of-game")
    ("cna_sprite_batch_destroy" %sprite-batch-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:sprite-batch")
    ("cna_sprite_batch_begin" %sprite-batch-begin :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_batch_submit_many" %sprite-batch-submit-many :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_sprite_batch_submit_scaled_many" %sprite-batch-submit-scaled-many :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_sprite_batch_end" %sprite-batch-end :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_sprite_batch_get_type_name_size" %sprite-batch-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_batch_copy_type_name" %sprite-batch-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_keyboard_get_state" %keyboard-get-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_keyboard_get_state_for_player" %keyboard-get-state-for-player :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_keyboard_state_init" %keyboard-state-init :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_keyboard_state_init_from_keys" %keyboard-state-init-from-keys :uint32 (:pointer :uint64 :pointer) :thread :any :ownership "none")
    ("cna_keyboard_state_get_key_state" %keyboard-state-get-key-state :uint32 (:pointer :uint32 :pointer) :thread :any :ownership "none")
    ("cna_keyboard_state_equals" %keyboard-state-equals :uint32 (:pointer :pointer :pointer) :thread :any :ownership "none")
    ("cna_keyboard_state_get_hash_code" %keyboard-state-get-hash-code :uint32 (:pointer :pointer) :thread :any :ownership "none")
    ("cna_mouse_get_state" %mouse-get-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_mouse_set_position" %mouse-set-position :uint32 (:uint64 :int32 :int32) :thread :owner :ownership "none")
    ("cna_mouse_state_init" %mouse-state-init :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_mouse_state_init_from_values" %mouse-state-init-from-values :uint32 (:int32 :int32 :int32 :uint32 :pointer) :thread :any :ownership "none")
    ("cna_mouse_state_equals" %mouse-state-equals :uint32 (:pointer :pointer :pointer) :thread :any :ownership "none")
    ("cna_gamepad_get_state" %gamepad-get-state :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_gamepad_get_state_with_dead_zone" %gamepad-get-state-with-dead-zone :uint32 (:uint64 :uint32 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_gamepad_get_capabilities" %gamepad-get-capabilities :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_gamepad_set_vibration" %gamepad-set-vibration :uint32 (:uint64 :uint32 :float :float :pointer) :thread :owner :ownership "none"))
  "Every native route this binding may call: C name, Lisp name, and bound CFFI shape.")

