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

;;; CNA_Result cna_game_subscribe(CNA_Handle game, CNA_GameEvent event, CNA_GameEventCallback callback, void* context, CNA_GameEventRegistrationHandle* out_registration)
(defcfun ("cna_game_subscribe" %game-subscribe) :uint32
  (game :uint64) (event :uint32) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_game_unsubscribe(CNA_GameEventRegistrationHandle registration)
(defcfun ("cna_game_unsubscribe" %game-unsubscribe) :uint32
  (registration :uint64))

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

;;; CNA_Result cna_graphics_device_manager_subscribe(CNA_GraphicsDeviceManagerHandle manager, CNA_GraphicsDeviceManagerEvent event, CNA_GameEventCallback callback, void* context, CNA_GameEventRegistrationHandle* out_registration)
(defcfun ("cna_graphics_device_manager_subscribe" %graphics-device-manager-subscribe) :uint32
  (manager :uint64) (event :uint32) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_graphics_resource_get_is_disposed(CNA_Handle resource, CNA_Bool* out_is_disposed)
(defcfun ("cna_graphics_resource_get_is_disposed" %graphics-resource-get-is-disposed) :uint32
  (resource :uint64) (out-is-disposed :pointer))

;;; CNA_Result cna_graphics_resource_get_name_byte_count(CNA_Handle resource, uint64_t* out_byte_count)
(defcfun ("cna_graphics_resource_get_name_byte_count" %graphics-resource-get-name-byte-count) :uint32
  (resource :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_graphics_resource_copy_name(CNA_Handle resource, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_graphics_resource_copy_name" %graphics-resource-copy-name) :uint32
  (resource :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_graphics_resource_set_name(CNA_Handle resource, CNA_StringView name)
(defcfun ("cna_graphics_resource_set_name" %graphics-resource-set-name) :uint32
  (resource :uint64) (name-0 :pointer) (name-1 :uint64))

;;; CNA_Result cna_graphics_resource_get_graphics_device(CNA_Handle resource, CNA_Handle* out_graphics_device)
(defcfun ("cna_graphics_resource_get_graphics_device" %graphics-resource-get-graphics-device) :uint32
  (resource :uint64) (out-graphics-device :pointer))

;;; CNA_Result cna_graphics_resource_subscribe_disposing(CNA_Handle resource, CNA_GraphicsResourceDisposingCallback callback, void* context, CNA_GraphicsResourceEventRegistrationHandle* out_registration)
(defcfun ("cna_graphics_resource_subscribe_disposing" %graphics-resource-subscribe-disposing) :uint32
  (resource :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_graphics_resource_unsubscribe_disposing(CNA_GraphicsResourceEventRegistrationHandle registration)
(defcfun ("cna_graphics_resource_unsubscribe_disposing" %graphics-resource-unsubscribe-disposing) :uint32
  (registration :uint64))

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

;;; CNA_Result cna_touch_get_state(CNA_Handle game, CNA_TouchState* out_state)
(defcfun ("cna_touch_get_state" %touch-get-state) :uint32
  (game :uint64) (out-state :pointer))

;;; CNA_Result cna_touch_get_capabilities(CNA_Handle game, CNA_TouchCapabilities* out_capabilities)
(defcfun ("cna_touch_get_capabilities" %touch-get-capabilities) :uint32
  (game :uint64) (out-capabilities :pointer))

;;; CNA_Result cna_touch_panel_get_enabled_gestures(CNA_Handle game, CNA_GestureType* out_gestures)
(defcfun ("cna_touch_panel_get_enabled_gestures" %touch-panel-get-enabled-gestures) :uint32
  (game :uint64) (out-gestures :pointer))

;;; CNA_Result cna_touch_panel_set_enabled_gestures(CNA_Handle game, CNA_GestureType gestures)
(defcfun ("cna_touch_panel_set_enabled_gestures" %touch-panel-set-enabled-gestures) :uint32
  (game :uint64) (gestures :uint32))

;;; CNA_Result cna_touch_panel_get_is_gesture_available(CNA_Handle game, CNA_Bool* out_available)
(defcfun ("cna_touch_panel_get_is_gesture_available" %touch-panel-get-is-gesture-available) :uint32
  (game :uint64) (out-available :pointer))

;;; CNA_Result cna_touch_panel_read_gesture(CNA_Handle game, CNA_GestureSample* out_sample)
(defcfun ("cna_touch_panel_read_gesture" %touch-panel-read-gesture) :uint32
  (game :uint64) (out-sample :pointer))

;;; CNA_Result cna_touch_panel_get_display_width(CNA_Handle game, int32_t* out_width)
(defcfun ("cna_touch_panel_get_display_width" %touch-panel-get-display-width) :uint32
  (game :uint64) (out-width :pointer))

;;; CNA_Result cna_touch_panel_set_display_width(CNA_Handle game, int32_t width)
(defcfun ("cna_touch_panel_set_display_width" %touch-panel-set-display-width) :uint32
  (game :uint64) (width :int32))

;;; CNA_Result cna_touch_panel_get_display_height(CNA_Handle game, int32_t* out_height)
(defcfun ("cna_touch_panel_get_display_height" %touch-panel-get-display-height) :uint32
  (game :uint64) (out-height :pointer))

;;; CNA_Result cna_touch_panel_set_display_height(CNA_Handle game, int32_t height)
(defcfun ("cna_touch_panel_set_display_height" %touch-panel-set-display-height) :uint32
  (game :uint64) (height :int32))

;;; CNA_Result cna_touch_panel_get_display_orientation(CNA_Handle game, CNA_DisplayOrientation* out_orientation)
(defcfun ("cna_touch_panel_get_display_orientation" %touch-panel-get-display-orientation) :uint32
  (game :uint64) (out-orientation :pointer))

;;; CNA_Result cna_touch_panel_set_display_orientation(CNA_Handle game, CNA_DisplayOrientation orientation)
(defcfun ("cna_touch_panel_set_display_orientation" %touch-panel-set-display-orientation) :uint32
  (game :uint64) (orientation :uint32))

;;; CNA_Result cna_blend_state_init(CNA_BlendStatePreset preset, CNA_BlendState* out_state)
(defcfun ("cna_blend_state_init" %blend-state-init) :uint32
  (preset :uint32) (out-state :pointer))

;;; CNA_Result cna_depth_stencil_state_init(CNA_DepthStencilStatePreset preset, CNA_DepthStencilState* out_state)
(defcfun ("cna_depth_stencil_state_init" %depth-stencil-state-init) :uint32
  (preset :uint32) (out-state :pointer))

;;; CNA_Result cna_rasterizer_state_init(CNA_RasterizerStatePreset preset, CNA_RasterizerState* out_state)
(defcfun ("cna_rasterizer_state_init" %rasterizer-state-init) :uint32
  (preset :uint32) (out-state :pointer))

;;; CNA_Result cna_sampler_state_init(CNA_SamplerStatePreset preset, CNA_SamplerState* out_state)
(defcfun ("cna_sampler_state_init" %sampler-state-init) :uint32
  (preset :uint32) (out-state :pointer))

;;; CNA_Result cna_graphics_device_get_blend_state(CNA_Handle graphics_device, CNA_BlendState* out_state)
(defcfun ("cna_graphics_device_get_blend_state" %graphics-device-get-blend-state) :uint32
  (graphics-device :uint64) (out-state :pointer))

;;; CNA_Result cna_graphics_device_set_blend_state(CNA_Handle graphics_device, const CNA_BlendState* state)
(defcfun ("cna_graphics_device_set_blend_state" %graphics-device-set-blend-state) :uint32
  (graphics-device :uint64) (state :pointer))

;;; CNA_Result cna_graphics_device_get_depth_stencil_state(CNA_Handle graphics_device, CNA_DepthStencilState* out_state)
(defcfun ("cna_graphics_device_get_depth_stencil_state" %graphics-device-get-depth-stencil-state) :uint32
  (graphics-device :uint64) (out-state :pointer))

;;; CNA_Result cna_graphics_device_set_depth_stencil_state(CNA_Handle graphics_device, const CNA_DepthStencilState* state)
(defcfun ("cna_graphics_device_set_depth_stencil_state" %graphics-device-set-depth-stencil-state) :uint32
  (graphics-device :uint64) (state :pointer))

;;; CNA_Result cna_graphics_device_get_rasterizer_state(CNA_Handle graphics_device, CNA_RasterizerState* out_state)
(defcfun ("cna_graphics_device_get_rasterizer_state" %graphics-device-get-rasterizer-state) :uint32
  (graphics-device :uint64) (out-state :pointer))

;;; CNA_Result cna_graphics_device_set_rasterizer_state(CNA_Handle graphics_device, const CNA_RasterizerState* state)
(defcfun ("cna_graphics_device_set_rasterizer_state" %graphics-device-set-rasterizer-state) :uint32
  (graphics-device :uint64) (state :pointer))

;;; CNA_Result cna_graphics_device_get_sampler_state(CNA_Handle graphics_device, CNA_ShaderStage stage, uint32_t slot, CNA_SamplerState* out_state)
(defcfun ("cna_graphics_device_get_sampler_state" %graphics-device-get-sampler-state) :uint32
  (graphics-device :uint64) (stage :uint32) (slot :uint32) (out-state :pointer))

;;; CNA_Result cna_graphics_device_set_sampler_state(CNA_Handle graphics_device, CNA_ShaderStage stage, uint32_t slot, const CNA_SamplerState* state)
(defcfun ("cna_graphics_device_set_sampler_state" %graphics-device-set-sampler-state) :uint32
  (graphics-device :uint64) (stage :uint32) (slot :uint32) (state :pointer))

;;; CNA_Result cna_sprite_batch_begin_with_states(CNA_Handle sprite_batch, CNA_SpriteSortMode sort_mode, const CNA_BlendState* blend_state, const CNA_SamplerState* sampler_state, const CNA_DepthStencilState* depth_stencil_state, const CNA_RasterizerState* rasterizer_state)
(defcfun ("cna_sprite_batch_begin_with_states" %sprite-batch-begin-with-states) :uint32
  (sprite-batch :uint64) (sort-mode :uint32) (blend-state :pointer) (sampler-state :pointer) (depth-stencil-state :pointer) (rasterizer-state :pointer))

;;; CNA_Result cna_graphics_device_get_blend_factor(CNA_Handle graphics_device, CNA_Color* out_blend_factor)
(defcfun ("cna_graphics_device_get_blend_factor" %graphics-device-get-blend-factor) :uint32
  (graphics-device :uint64) (out-blend-factor :pointer))

;;; CNA_Result cna_graphics_device_set_blend_factor(CNA_Handle graphics_device, CNA_Color blend_factor)
(defcfun ("cna_graphics_device_set_blend_factor" %graphics-device-set-blend-factor) :uint32
  (graphics-device :uint64) (blend-factor-0 :uint32))

;;; CNA_Result cna_graphics_device_get_multi_sample_mask(CNA_Handle graphics_device, int32_t* out_multi_sample_mask)
(defcfun ("cna_graphics_device_get_multi_sample_mask" %graphics-device-get-multi-sample-mask) :uint32
  (graphics-device :uint64) (out-multi-sample-mask :pointer))

;;; CNA_Result cna_graphics_device_set_multi_sample_mask(CNA_Handle graphics_device, int32_t multi_sample_mask)
(defcfun ("cna_graphics_device_set_multi_sample_mask" %graphics-device-set-multi-sample-mask) :uint32
  (graphics-device :uint64) (multi-sample-mask :int32))

;;; CNA_Result cna_graphics_device_get_reference_stencil(CNA_Handle graphics_device, int32_t* out_reference_stencil)
(defcfun ("cna_graphics_device_get_reference_stencil" %graphics-device-get-reference-stencil) :uint32
  (graphics-device :uint64) (out-reference-stencil :pointer))

;;; CNA_Result cna_graphics_device_set_reference_stencil(CNA_Handle graphics_device, int32_t reference_stencil)
(defcfun ("cna_graphics_device_set_reference_stencil" %graphics-device-set-reference-stencil) :uint32
  (graphics-device :uint64) (reference-stencil :int32))

;;; CNA_Result cna_graphics_device_get_scissor_rectangle(CNA_Handle graphics_device, CNA_Rectangle* out_scissor_rectangle)
(defcfun ("cna_graphics_device_get_scissor_rectangle" %graphics-device-get-scissor-rectangle) :uint32
  (graphics-device :uint64) (out-scissor-rectangle :pointer))

;;; CNA_Result cna_graphics_device_set_scissor_rectangle(CNA_Handle graphics_device, CNA_Rectangle scissor_rectangle)
(defcfun ("cna_graphics_device_set_scissor_rectangle" %graphics-device-set-scissor-rectangle) :uint32
  (graphics-device :uint64) (scissor-rectangle-0 :uint64) (scissor-rectangle-1 :uint64))

;;; CNA_Result cna_graphics_device_get_texture(CNA_Handle graphics_device, CNA_ShaderStage stage, uint32_t slot, CNA_TextureSlotInfo* out_info)
(defcfun ("cna_graphics_device_get_texture" %graphics-device-get-texture) :uint32
  (graphics-device :uint64) (stage :uint32) (slot :uint32) (out-info :pointer))

;;; CNA_Result cna_graphics_device_set_texture(CNA_Handle graphics_device, CNA_ShaderStage stage, uint32_t slot, CNA_Handle texture)
(defcfun ("cna_graphics_device_set_texture" %graphics-device-set-texture) :uint32
  (graphics-device :uint64) (stage :uint32) (slot :uint32) (texture :uint64))

;;; CNA_Result cna_vertex_type_get_stride(CNA_VertexType type, uint32_t* out_stride)
(defcfun ("cna_vertex_type_get_stride" %vertex-type-get-stride) :uint32
  (type :uint32) (out-stride :pointer))

;;; CNA_Result cna_vertex_type_copy_elements(CNA_VertexType type, CNA_VertexElement* destination, uint64_t capacity, uint64_t* out_element_count)
(defcfun ("cna_vertex_type_copy_elements" %vertex-type-copy-elements) :uint32
  (type :uint32) (destination :pointer) (capacity :uint64) (out-element-count :pointer))

;;; CNA_Result cna_graphics_device_get_backbuffer_data_window(CNA_Handle graphics_device, const CNA_BackBufferReadback* readback, CNA_Color* destination, uint64_t capacity)
(defcfun ("cna_graphics_device_get_backbuffer_data_window" %graphics-device-get-backbuffer-data-window) :uint32
  (graphics-device :uint64) (readback :pointer) (destination :pointer) (capacity :uint64))

;;; CNA_Result cna_vertex_declaration_create(const CNA_VertexElement* elements, uint64_t element_count, CNA_VertexDeclarationHandle* out_declaration)
(defcfun ("cna_vertex_declaration_create" %vertex-declaration-create) :uint32
  (elements :pointer) (element-count :uint64) (out-declaration :pointer))

;;; CNA_Result cna_vertex_declaration_create_with_stride(int32_t vertex_stride, const CNA_VertexElement* elements, uint64_t element_count, CNA_VertexDeclarationHandle* out_declaration)
(defcfun ("cna_vertex_declaration_create_with_stride" %vertex-declaration-create-with-stride) :uint32
  (vertex-stride :int32) (elements :pointer) (element-count :uint64) (out-declaration :pointer))

;;; CNA_Result cna_vertex_declaration_destroy(CNA_VertexDeclarationHandle declaration)
(defcfun ("cna_vertex_declaration_destroy" %vertex-declaration-destroy) :uint32
  (declaration :uint64))

;;; CNA_Result cna_vertex_buffer_create(CNA_Handle graphics_device, const CNA_VertexBufferCreateInfo* create_info, CNA_VertexBufferHandle* out_vertex_buffer)
(defcfun ("cna_vertex_buffer_create" %vertex-buffer-create) :uint32
  (graphics-device :uint64) (create-info :pointer) (out-vertex-buffer :pointer))

;;; CNA_Result cna_vertex_buffer_destroy(CNA_VertexBufferHandle vertex_buffer)
(defcfun ("cna_vertex_buffer_destroy" %vertex-buffer-destroy) :uint32
  (vertex-buffer :uint64))

;;; CNA_Result cna_vertex_buffer_get_info(CNA_VertexBufferHandle vertex_buffer, CNA_VertexBufferInfo* out_info)
(defcfun ("cna_vertex_buffer_get_info" %vertex-buffer-get-info) :uint32
  (vertex-buffer :uint64) (out-info :pointer))

;;; CNA_Result cna_vertex_buffer_copy_declaration_elements(CNA_VertexBufferHandle vertex_buffer, CNA_VertexElement* destination, uint64_t capacity, uint64_t* out_element_count)
(defcfun ("cna_vertex_buffer_copy_declaration_elements" %vertex-buffer-copy-declaration-elements) :uint32
  (vertex-buffer :uint64) (destination :pointer) (capacity :uint64) (out-element-count :pointer))

;;; CNA_Result cna_vertex_buffer_set_data_raw(CNA_VertexBufferHandle vertex_buffer, const void* data, uint64_t data_byte_count, uint64_t vertex_count, uint32_t vertex_stride)
(defcfun ("cna_vertex_buffer_set_data_raw" %vertex-buffer-set-data-raw) :uint32
  (vertex-buffer :uint64) (data :pointer) (data-byte-count :uint64) (vertex-count :uint64) (vertex-stride :uint32))

;;; CNA_Result cna_vertex_buffer_set_data_raw_at(CNA_VertexBufferHandle vertex_buffer, uint64_t buffer_offset_in_bytes, const void* data, uint64_t data_byte_count, uint64_t vertex_count, uint32_t vertex_stride)
(defcfun ("cna_vertex_buffer_set_data_raw_at" %vertex-buffer-set-data-raw-at) :uint32
  (vertex-buffer :uint64) (buffer-offset-in-bytes :uint64) (data :pointer) (data-byte-count :uint64) (vertex-count :uint64) (vertex-stride :uint32))

;;; CNA_Result cna_vertex_buffer_set_data_raw_with_options(CNA_VertexBufferHandle vertex_buffer, const void* data, uint64_t data_byte_count, uint64_t vertex_count, uint32_t vertex_stride, CNA_SetDataOptions options)
(defcfun ("cna_vertex_buffer_set_data_raw_with_options" %vertex-buffer-set-data-raw-with-options) :uint32
  (vertex-buffer :uint64) (data :pointer) (data-byte-count :uint64) (vertex-count :uint64) (vertex-stride :uint32) (options :uint32))

;;; CNA_Result cna_vertex_buffer_set_data_raw_at_with_options(CNA_VertexBufferHandle vertex_buffer, uint64_t buffer_offset_in_bytes, const void* data, uint64_t data_byte_count, uint64_t vertex_count, uint32_t vertex_stride, CNA_SetDataOptions options)
(defcfun ("cna_vertex_buffer_set_data_raw_at_with_options" %vertex-buffer-set-data-raw-at-with-options) :uint32
  (vertex-buffer :uint64) (buffer-offset-in-bytes :uint64) (data :pointer) (data-byte-count :uint64) (vertex-count :uint64) (vertex-stride :uint32) (options :uint32))

;;; CNA_Result cna_vertex_buffer_get_data_raw(CNA_VertexBufferHandle vertex_buffer, uint64_t buffer_offset_in_bytes, void* destination, uint64_t destination_byte_count, uint64_t vertex_count, uint32_t vertex_stride)
(defcfun ("cna_vertex_buffer_get_data_raw" %vertex-buffer-get-data-raw) :uint32
  (vertex-buffer :uint64) (buffer-offset-in-bytes :uint64) (destination :pointer) (destination-byte-count :uint64) (vertex-count :uint64) (vertex-stride :uint32))

;;; CNA_Result cna_index_buffer_create(CNA_Handle graphics_device, const CNA_IndexBufferCreateInfo* create_info, CNA_IndexBufferHandle* out_index_buffer)
(defcfun ("cna_index_buffer_create" %index-buffer-create) :uint32
  (graphics-device :uint64) (create-info :pointer) (out-index-buffer :pointer))

;;; CNA_Result cna_index_buffer_destroy(CNA_IndexBufferHandle index_buffer)
(defcfun ("cna_index_buffer_destroy" %index-buffer-destroy) :uint32
  (index-buffer :uint64))

;;; CNA_Result cna_index_buffer_get_info(CNA_IndexBufferHandle index_buffer, CNA_IndexBufferInfo* out_info)
(defcfun ("cna_index_buffer_get_info" %index-buffer-get-info) :uint32
  (index-buffer :uint64) (out-info :pointer))

;;; CNA_Result cna_index_buffer_set_data(CNA_IndexBufferHandle index_buffer, const CNA_IndexBufferTransfer* transfer, const void* data, uint64_t capacity)
(defcfun ("cna_index_buffer_set_data" %index-buffer-set-data) :uint32
  (index-buffer :uint64) (transfer :pointer) (data :pointer) (capacity :uint64))

;;; CNA_Result cna_index_buffer_set_data_at(CNA_IndexBufferHandle index_buffer, uint64_t buffer_offset_in_bytes, const CNA_IndexBufferTransfer* transfer, const void* data, uint64_t capacity)
(defcfun ("cna_index_buffer_set_data_at" %index-buffer-set-data-at) :uint32
  (index-buffer :uint64) (buffer-offset-in-bytes :uint64) (transfer :pointer) (data :pointer) (capacity :uint64))

;;; CNA_Result cna_index_buffer_get_data(CNA_IndexBufferHandle index_buffer, const CNA_IndexBufferTransfer* transfer, void* destination, uint64_t capacity, uint64_t* out_element_count)
(defcfun ("cna_index_buffer_get_data" %index-buffer-get-data) :uint32
  (index-buffer :uint64) (transfer :pointer) (destination :pointer) (capacity :uint64) (out-element-count :pointer))

;;; CNA_Result cna_graphics_device_set_vertex_buffer(CNA_Handle graphics_device, CNA_VertexBufferHandle vertex_buffer)
(defcfun ("cna_graphics_device_set_vertex_buffer" %graphics-device-set-vertex-buffer) :uint32
  (graphics-device :uint64) (vertex-buffer :uint64))

;;; CNA_Result cna_graphics_device_set_vertex_buffer_offset(CNA_Handle graphics_device, CNA_VertexBufferHandle vertex_buffer, int32_t vertex_offset)
(defcfun ("cna_graphics_device_set_vertex_buffer_offset" %graphics-device-set-vertex-buffer-offset) :uint32
  (graphics-device :uint64) (vertex-buffer :uint64) (vertex-offset :int32))

;;; CNA_Result cna_graphics_device_set_vertex_buffers(CNA_Handle graphics_device, const CNA_VertexBufferBinding* bindings, uint64_t binding_count)
(defcfun ("cna_graphics_device_set_vertex_buffers" %graphics-device-set-vertex-buffers) :uint32
  (graphics-device :uint64) (bindings :pointer) (binding-count :uint64))

;;; CNA_Result cna_graphics_device_get_vertex_buffer_count(CNA_Handle graphics_device, uint64_t* out_count)
(defcfun ("cna_graphics_device_get_vertex_buffer_count" %graphics-device-get-vertex-buffer-count) :uint32
  (graphics-device :uint64) (out-count :pointer))

;;; CNA_Result cna_graphics_device_copy_vertex_buffers(CNA_Handle graphics_device, CNA_VertexBufferBinding* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_graphics_device_copy_vertex_buffers" %graphics-device-copy-vertex-buffers) :uint32
  (graphics-device :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_graphics_device_set_index_buffer(CNA_Handle graphics_device, CNA_IndexBufferHandle index_buffer)
(defcfun ("cna_graphics_device_set_index_buffer" %graphics-device-set-index-buffer) :uint32
  (graphics-device :uint64) (index-buffer :uint64))

;;; CNA_Result cna_graphics_device_get_index_buffer(CNA_Handle graphics_device, CNA_IndexBufferHandle* out_index_buffer)
(defcfun ("cna_graphics_device_get_index_buffer" %graphics-device-get-index-buffer) :uint32
  (graphics-device :uint64) (out-index-buffer :pointer))

;;; CNA_Result cna_graphics_device_draw_primitives(CNA_Handle graphics_device, CNA_PrimitiveType primitive_type, int32_t vertex_start, int32_t primitive_count)
(defcfun ("cna_graphics_device_draw_primitives" %graphics-device-draw-primitives) :uint32
  (graphics-device :uint64) (primitive-type :uint32) (vertex-start :int32) (primitive-count :int32))

;;; CNA_Result cna_graphics_device_draw_indexed_primitives(CNA_Handle graphics_device, CNA_PrimitiveType primitive_type, int32_t base_vertex, int32_t min_vertex_index, int32_t num_vertices, int32_t start_index, int32_t primitive_count)
(defcfun ("cna_graphics_device_draw_indexed_primitives" %graphics-device-draw-indexed-primitives) :uint32
  (graphics-device :uint64) (primitive-type :uint32) (base-vertex :int32) (min-vertex-index :int32) (num-vertices :int32) (start-index :int32) (primitive-count :int32))

;;; CNA_Result cna_graphics_device_draw_user_primitives(CNA_Handle graphics_device, const CNA_UserPrimitives* primitives)
(defcfun ("cna_graphics_device_draw_user_primitives" %graphics-device-draw-user-primitives) :uint32
  (graphics-device :uint64) (primitives :pointer))

;;; CNA_Result cna_graphics_device_draw_user_indexed_primitives(CNA_Handle graphics_device, const CNA_UserPrimitives* primitives, const CNA_UserIndices* indices)
(defcfun ("cna_graphics_device_draw_user_indexed_primitives" %graphics-device-draw-user-indexed-primitives) :uint32
  (graphics-device :uint64) (primitives :pointer) (indices :pointer))

;;; CNA_Result cna_vertex_buffer_subscribe_content_lost(CNA_VertexBufferHandle vertex_buffer, CNA_VertexBufferContentLostCallback callback, void* context, CNA_VertexBufferEventRegistrationHandle* out_registration)
(defcfun ("cna_vertex_buffer_subscribe_content_lost" %vertex-buffer-subscribe-content-lost) :uint32
  (vertex-buffer :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_vertex_buffer_unsubscribe_content_lost(CNA_VertexBufferEventRegistrationHandle registration)
(defcfun ("cna_vertex_buffer_unsubscribe_content_lost" %vertex-buffer-unsubscribe-content-lost) :uint32
  (registration :uint64))

;;; CNA_Result cna_index_buffer_subscribe_content_lost(CNA_IndexBufferHandle index_buffer, CNA_IndexBufferContentLostCallback callback, void* context, CNA_IndexBufferEventRegistrationHandle* out_registration)
(defcfun ("cna_index_buffer_subscribe_content_lost" %index-buffer-subscribe-content-lost) :uint32
  (index-buffer :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_index_buffer_unsubscribe_content_lost(CNA_IndexBufferEventRegistrationHandle registration)
(defcfun ("cna_index_buffer_unsubscribe_content_lost" %index-buffer-unsubscribe-content-lost) :uint32
  (registration :uint64))

;;; CNA_Result cna_basic_effect_create(CNA_Handle graphics_device, CNA_EffectHandle* out_effect)
(defcfun ("cna_basic_effect_create" %basic-effect-create) :uint32
  (graphics-device :uint64) (out-effect :pointer))

;;; CNA_Result cna_effect_create_compiled(CNA_Handle graphics_device, const uint8_t* effect_code, uint64_t effect_code_count, CNA_EffectHandle* out_effect)
(defcfun ("cna_effect_create_compiled" %effect-create-compiled) :uint32
  (graphics-device :uint64) (effect-code :pointer) (effect-code-count :uint64) (out-effect :pointer))

;;; CNA_Result cna_effect_destroy(CNA_EffectHandle effect)
(defcfun ("cna_effect_destroy" %effect-destroy) :uint32
  (effect :uint64))

;;; CNA_Result cna_effect_dispose(CNA_EffectHandle effect)
(defcfun ("cna_effect_dispose" %effect-dispose) :uint32
  (effect :uint64))

;;; CNA_Result cna_effect_clone(CNA_EffectHandle effect, CNA_EffectHandle* out_clone)
(defcfun ("cna_effect_clone" %effect-clone) :uint32
  (effect :uint64) (out-clone :pointer))

;;; CNA_Result cna_effect_get_parameters(CNA_EffectHandle effect, CNA_EffectParameterCollectionHandle* out_collection)
(defcfun ("cna_effect_get_parameters" %effect-get-parameters) :uint32
  (effect :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_get_techniques(CNA_EffectHandle effect, CNA_EffectTechniqueCollectionHandle* out_collection)
(defcfun ("cna_effect_get_techniques" %effect-get-techniques) :uint32
  (effect :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_get_current_technique(CNA_EffectHandle effect, CNA_EffectTechniqueHandle* out_technique)
(defcfun ("cna_effect_get_current_technique" %effect-get-current-technique) :uint32
  (effect :uint64) (out-technique :pointer))

;;; CNA_Result cna_effect_set_current_technique(CNA_EffectHandle effect, CNA_EffectTechniqueHandle technique)
(defcfun ("cna_effect_set_current_technique" %effect-set-current-technique) :uint32
  (effect :uint64) (technique :uint64))

;;; CNA_Result cna_effect_technique_collection_get_count(CNA_EffectTechniqueCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_effect_technique_collection_get_count" %effect-technique-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_effect_technique_collection_get_at(CNA_EffectTechniqueCollectionHandle collection, uint64_t index, CNA_EffectTechniqueHandle* out_technique)
(defcfun ("cna_effect_technique_collection_get_at" %effect-technique-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-technique :pointer))

;;; CNA_Result cna_effect_technique_collection_destroy(CNA_EffectTechniqueCollectionHandle collection)
(defcfun ("cna_effect_technique_collection_destroy" %effect-technique-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_effect_technique_get_name_byte_count(CNA_EffectTechniqueHandle technique, uint64_t* out_byte_count)
(defcfun ("cna_effect_technique_get_name_byte_count" %effect-technique-get-name-byte-count) :uint32
  (technique :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_technique_copy_name(CNA_EffectTechniqueHandle technique, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_technique_copy_name" %effect-technique-copy-name) :uint32
  (technique :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_technique_get_identity(CNA_EffectTechniqueHandle technique, uint64_t* out_identity)
(defcfun ("cna_effect_technique_get_identity" %effect-technique-get-identity) :uint32
  (technique :uint64) (out-identity :pointer))

;;; CNA_Result cna_effect_technique_get_passes(CNA_EffectTechniqueHandle technique, CNA_EffectPassCollectionHandle* out_collection)
(defcfun ("cna_effect_technique_get_passes" %effect-technique-get-passes) :uint32
  (technique :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_technique_get_annotations(CNA_EffectTechniqueHandle technique, CNA_EffectAnnotationCollectionHandle* out_collection)
(defcfun ("cna_effect_technique_get_annotations" %effect-technique-get-annotations) :uint32
  (technique :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_technique_destroy(CNA_EffectTechniqueHandle technique)
(defcfun ("cna_effect_technique_destroy" %effect-technique-destroy) :uint32
  (technique :uint64))

;;; CNA_Result cna_effect_pass_collection_get_count(CNA_EffectPassCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_effect_pass_collection_get_count" %effect-pass-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_effect_pass_collection_get_at(CNA_EffectPassCollectionHandle collection, uint64_t index, CNA_EffectPassHandle* out_pass)
(defcfun ("cna_effect_pass_collection_get_at" %effect-pass-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-pass :pointer))

;;; CNA_Result cna_effect_pass_collection_destroy(CNA_EffectPassCollectionHandle collection)
(defcfun ("cna_effect_pass_collection_destroy" %effect-pass-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_effect_pass_get_name_byte_count(CNA_EffectPassHandle pass, uint64_t* out_byte_count)
(defcfun ("cna_effect_pass_get_name_byte_count" %effect-pass-get-name-byte-count) :uint32
  (pass :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_pass_copy_name(CNA_EffectPassHandle pass, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_pass_copy_name" %effect-pass-copy-name) :uint32
  (pass :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_pass_get_annotations(CNA_EffectPassHandle pass, CNA_EffectAnnotationCollectionHandle* out_collection)
(defcfun ("cna_effect_pass_get_annotations" %effect-pass-get-annotations) :uint32
  (pass :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_pass_apply(CNA_EffectPassHandle pass)
(defcfun ("cna_effect_pass_apply" %effect-pass-apply) :uint32
  (pass :uint64))

;;; CNA_Result cna_effect_pass_destroy(CNA_EffectPassHandle pass)
(defcfun ("cna_effect_pass_destroy" %effect-pass-destroy) :uint32
  (pass :uint64))

;;; CNA_Result cna_effect_annotation_collection_get_count(CNA_EffectAnnotationCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_effect_annotation_collection_get_count" %effect-annotation-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_effect_annotation_collection_get_at(CNA_EffectAnnotationCollectionHandle collection, uint64_t index, CNA_EffectAnnotationHandle* out_annotation)
(defcfun ("cna_effect_annotation_collection_get_at" %effect-annotation-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-annotation :pointer))

;;; CNA_Result cna_effect_annotation_collection_destroy(CNA_EffectAnnotationCollectionHandle collection)
(defcfun ("cna_effect_annotation_collection_destroy" %effect-annotation-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_effect_annotation_get_info(CNA_EffectAnnotationHandle annotation, CNA_EffectAnnotationInfo* out_info)
(defcfun ("cna_effect_annotation_get_info" %effect-annotation-get-info) :uint32
  (annotation :uint64) (out-info :pointer))

;;; CNA_Result cna_effect_annotation_get_name_byte_count(CNA_EffectAnnotationHandle annotation, uint64_t* out_byte_count)
(defcfun ("cna_effect_annotation_get_name_byte_count" %effect-annotation-get-name-byte-count) :uint32
  (annotation :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_annotation_copy_name(CNA_EffectAnnotationHandle annotation, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_annotation_copy_name" %effect-annotation-copy-name) :uint32
  (annotation :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_annotation_get_semantic_byte_count(CNA_EffectAnnotationHandle annotation, uint64_t* out_byte_count)
(defcfun ("cna_effect_annotation_get_semantic_byte_count" %effect-annotation-get-semantic-byte-count) :uint32
  (annotation :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_annotation_copy_semantic(CNA_EffectAnnotationHandle annotation, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_annotation_copy_semantic" %effect-annotation-copy-semantic) :uint32
  (annotation :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_annotation_get_value_string_byte_count(CNA_EffectAnnotationHandle annotation, uint64_t* out_byte_count)
(defcfun ("cna_effect_annotation_get_value_string_byte_count" %effect-annotation-get-value-string-byte-count) :uint32
  (annotation :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_annotation_copy_value_string(CNA_EffectAnnotationHandle annotation, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_annotation_copy_value_string" %effect-annotation-copy-value-string) :uint32
  (annotation :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_annotation_get_value_boolean(CNA_EffectAnnotationHandle annotation, CNA_Bool* out_value)
(defcfun ("cna_effect_annotation_get_value_boolean" %effect-annotation-get-value-boolean) :uint32
  (annotation :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_annotation_get_value_int32(CNA_EffectAnnotationHandle annotation, int32_t* out_value)
(defcfun ("cna_effect_annotation_get_value_int32" %effect-annotation-get-value-int-32) :uint32
  (annotation :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_annotation_get_value_single(CNA_EffectAnnotationHandle annotation, float* out_value)
(defcfun ("cna_effect_annotation_get_value_single" %effect-annotation-get-value-single) :uint32
  (annotation :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_annotation_get_value_vector2(CNA_EffectAnnotationHandle annotation, CNA_Vector2* out_value)
(defcfun ("cna_effect_annotation_get_value_vector2" %effect-annotation-get-value-vector-2) :uint32
  (annotation :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_annotation_get_value_vector3(CNA_EffectAnnotationHandle annotation, CNA_Vector3* out_value)
(defcfun ("cna_effect_annotation_get_value_vector3" %effect-annotation-get-value-vector-3) :uint32
  (annotation :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_annotation_get_value_vector4(CNA_EffectAnnotationHandle annotation, CNA_Vector4* out_value)
(defcfun ("cna_effect_annotation_get_value_vector4" %effect-annotation-get-value-vector-4) :uint32
  (annotation :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_annotation_get_value_matrix(CNA_EffectAnnotationHandle annotation, CNA_Matrix* out_value)
(defcfun ("cna_effect_annotation_get_value_matrix" %effect-annotation-get-value-matrix) :uint32
  (annotation :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_annotation_destroy(CNA_EffectAnnotationHandle annotation)
(defcfun ("cna_effect_annotation_destroy" %effect-annotation-destroy) :uint32
  (annotation :uint64))

;;; CNA_Result cna_effect_parameter_collection_get_count(CNA_EffectParameterCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_effect_parameter_collection_get_count" %effect-parameter-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_effect_parameter_collection_get_at(CNA_EffectParameterCollectionHandle collection, uint64_t index, CNA_EffectParameterHandle* out_parameter)
(defcfun ("cna_effect_parameter_collection_get_at" %effect-parameter-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-parameter :pointer))

;;; CNA_Result cna_effect_parameter_collection_find_name(CNA_EffectParameterCollectionHandle collection, CNA_StringView name, CNA_Bool* out_found, CNA_EffectParameterHandle* out_parameter)
(defcfun ("cna_effect_parameter_collection_find_name" %effect-parameter-collection-find-name) :uint32
  (collection :uint64) (name-0 :pointer) (name-1 :uint64) (out-found :pointer) (out-parameter :pointer))

;;; CNA_Result cna_effect_parameter_collection_find_semantic(CNA_EffectParameterCollectionHandle collection, CNA_StringView semantic, CNA_Bool* out_found, CNA_EffectParameterHandle* out_parameter)
(defcfun ("cna_effect_parameter_collection_find_semantic" %effect-parameter-collection-find-semantic) :uint32
  (collection :uint64) (semantic-0 :pointer) (semantic-1 :uint64) (out-found :pointer) (out-parameter :pointer))

;;; CNA_Result cna_effect_parameter_collection_destroy(CNA_EffectParameterCollectionHandle collection)
(defcfun ("cna_effect_parameter_collection_destroy" %effect-parameter-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_effect_parameter_get_info(CNA_EffectParameterHandle parameter, CNA_EffectParameterInfo* out_info)
(defcfun ("cna_effect_parameter_get_info" %effect-parameter-get-info) :uint32
  (parameter :uint64) (out-info :pointer))

;;; CNA_Result cna_effect_parameter_get_name_byte_count(CNA_EffectParameterHandle parameter, uint64_t* out_byte_count)
(defcfun ("cna_effect_parameter_get_name_byte_count" %effect-parameter-get-name-byte-count) :uint32
  (parameter :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_parameter_copy_name(CNA_EffectParameterHandle parameter, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_parameter_copy_name" %effect-parameter-copy-name) :uint32
  (parameter :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_parameter_get_semantic_byte_count(CNA_EffectParameterHandle parameter, uint64_t* out_byte_count)
(defcfun ("cna_effect_parameter_get_semantic_byte_count" %effect-parameter-get-semantic-byte-count) :uint32
  (parameter :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_parameter_copy_semantic(CNA_EffectParameterHandle parameter, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_parameter_copy_semantic" %effect-parameter-copy-semantic) :uint32
  (parameter :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_parameter_get_elements(CNA_EffectParameterHandle parameter, CNA_EffectParameterCollectionHandle* out_collection)
(defcfun ("cna_effect_parameter_get_elements" %effect-parameter-get-elements) :uint32
  (parameter :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_parameter_get_structure_members(CNA_EffectParameterHandle parameter, CNA_EffectParameterCollectionHandle* out_collection)
(defcfun ("cna_effect_parameter_get_structure_members" %effect-parameter-get-structure-members) :uint32
  (parameter :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_parameter_get_annotations(CNA_EffectParameterHandle parameter, CNA_EffectAnnotationCollectionHandle* out_collection)
(defcfun ("cna_effect_parameter_get_annotations" %effect-parameter-get-annotations) :uint32
  (parameter :uint64) (out-collection :pointer))

;;; CNA_Result cna_effect_parameter_get_value(CNA_EffectParameterHandle parameter, CNA_EffectValueType value_type, void* out_value)
(defcfun ("cna_effect_parameter_get_value" %effect-parameter-get-value) :uint32
  (parameter :uint64) (value-type :uint32) (out-value :pointer))

;;; CNA_Result cna_effect_parameter_set_value(CNA_EffectParameterHandle parameter, CNA_EffectValueType value_type, const void* value)
(defcfun ("cna_effect_parameter_set_value" %effect-parameter-set-value) :uint32
  (parameter :uint64) (value-type :uint32) (value :pointer))

;;; CNA_Result cna_effect_parameter_get_values(CNA_EffectParameterHandle parameter, CNA_EffectValueType value_type, uint64_t requested_count, void* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_effect_parameter_get_values" %effect-parameter-get-values) :uint32
  (parameter :uint64) (value-type :uint32) (requested-count :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_effect_parameter_set_values(CNA_EffectParameterHandle parameter, CNA_EffectValueType value_type, const void* values, uint64_t count)
(defcfun ("cna_effect_parameter_set_values" %effect-parameter-set-values) :uint32
  (parameter :uint64) (value-type :uint32) (values :pointer) (count :uint64))

;;; CNA_Result cna_effect_parameter_get_value_string_byte_count(CNA_EffectParameterHandle parameter, uint64_t* out_byte_count)
(defcfun ("cna_effect_parameter_get_value_string_byte_count" %effect-parameter-get-value-string-byte-count) :uint32
  (parameter :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_parameter_copy_value_string(CNA_EffectParameterHandle parameter, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_parameter_copy_value_string" %effect-parameter-copy-value-string) :uint32
  (parameter :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_parameter_set_value_string(CNA_EffectParameterHandle parameter, CNA_StringView value)
(defcfun ("cna_effect_parameter_set_value_string" %effect-parameter-set-value-string) :uint32
  (parameter :uint64) (value-0 :pointer) (value-1 :uint64))

;;; CNA_Result cna_effect_parameter_get_value_texture(CNA_EffectParameterHandle parameter, CNA_EffectTextureType texture_type, CNA_Handle* out_texture)
(defcfun ("cna_effect_parameter_get_value_texture" %effect-parameter-get-value-texture) :uint32
  (parameter :uint64) (texture-type :uint32) (out-texture :pointer))

;;; CNA_Result cna_effect_parameter_set_value_texture(CNA_EffectParameterHandle parameter, CNA_EffectTextureType texture_type, CNA_Handle texture)
(defcfun ("cna_effect_parameter_set_value_texture" %effect-parameter-set-value-texture) :uint32
  (parameter :uint64) (texture-type :uint32) (texture :uint64))

;;; CNA_Result cna_effect_parameter_destroy(CNA_EffectParameterHandle parameter)
(defcfun ("cna_effect_parameter_destroy" %effect-parameter-destroy) :uint32
  (parameter :uint64))

;;; CNA_Result cna_effect_matrices_get_world(CNA_EffectHandle effect, CNA_Matrix* out_value)
(defcfun ("cna_effect_matrices_get_world" %effect-matrices-get-world) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_matrices_get_view(CNA_EffectHandle effect, CNA_Matrix* out_value)
(defcfun ("cna_effect_matrices_get_view" %effect-matrices-get-view) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_matrices_get_projection(CNA_EffectHandle effect, CNA_Matrix* out_value)
(defcfun ("cna_effect_matrices_get_projection" %effect-matrices-get-projection) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_fog_get_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_effect_fog_get_color" %effect-fog-get-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_fog_set_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_effect_fog_set_color" %effect-fog-set-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_effect_fog_get_enabled(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_effect_fog_get_enabled" %effect-fog-get-enabled) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_fog_set_enabled(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_effect_fog_set_enabled" %effect-fog-set-enabled) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_effect_fog_get_start(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_effect_fog_get_start" %effect-fog-get-start) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_fog_set_start(CNA_EffectHandle effect, float value)
(defcfun ("cna_effect_fog_set_start" %effect-fog-set-start) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_effect_fog_get_end(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_effect_fog_get_end" %effect-fog-get-end) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_fog_set_end(CNA_EffectHandle effect, float value)
(defcfun ("cna_effect_fog_set_end" %effect-fog-set-end) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_effect_lights_get_ambient_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_effect_lights_get_ambient_color" %effect-lights-get-ambient-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_lights_set_ambient_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_effect_lights_set_ambient_color" %effect-lights-set-ambient-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_effect_lights_get_enabled(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_effect_lights_get_enabled" %effect-lights-get-enabled) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_effect_lights_set_enabled(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_effect_lights_set_enabled" %effect-lights-set-enabled) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_effect_lights_get_directional_light(CNA_EffectHandle effect, uint32_t index, CNA_DirectionalLightHandle* out_light)
(defcfun ("cna_effect_lights_get_directional_light" %effect-lights-get-directional-light) :uint32
  (effect :uint64) (index :uint32) (out-light :pointer))

;;; CNA_Result cna_effect_lights_enable_default(CNA_EffectHandle effect)
(defcfun ("cna_effect_lights_enable_default" %effect-lights-enable-default) :uint32
  (effect :uint64))

;;; CNA_Result cna_directional_light_destroy(CNA_DirectionalLightHandle light)
(defcfun ("cna_directional_light_destroy" %directional-light-destroy) :uint32
  (light :uint64))

;;; CNA_Result cna_directional_light_get_diffuse_color(CNA_DirectionalLightHandle light, CNA_Vector3* out_value)
(defcfun ("cna_directional_light_get_diffuse_color" %directional-light-get-diffuse-color) :uint32
  (light :uint64) (out-value :pointer))

;;; CNA_Result cna_directional_light_set_diffuse_color(CNA_DirectionalLightHandle light, CNA_Vector3 value)
(defcfun ("cna_directional_light_set_diffuse_color" %directional-light-set-diffuse-color) :uint32
  (light :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_directional_light_get_direction(CNA_DirectionalLightHandle light, CNA_Vector3* out_value)
(defcfun ("cna_directional_light_get_direction" %directional-light-get-direction) :uint32
  (light :uint64) (out-value :pointer))

;;; CNA_Result cna_directional_light_set_direction(CNA_DirectionalLightHandle light, CNA_Vector3 value)
(defcfun ("cna_directional_light_set_direction" %directional-light-set-direction) :uint32
  (light :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_directional_light_get_specular_color(CNA_DirectionalLightHandle light, CNA_Vector3* out_value)
(defcfun ("cna_directional_light_get_specular_color" %directional-light-get-specular-color) :uint32
  (light :uint64) (out-value :pointer))

;;; CNA_Result cna_directional_light_set_specular_color(CNA_DirectionalLightHandle light, CNA_Vector3 value)
(defcfun ("cna_directional_light_set_specular_color" %directional-light-set-specular-color) :uint32
  (light :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_directional_light_get_enabled(CNA_DirectionalLightHandle light, CNA_Bool* out_value)
(defcfun ("cna_directional_light_get_enabled" %directional-light-get-enabled) :uint32
  (light :uint64) (out-value :pointer))

;;; CNA_Result cna_directional_light_set_enabled(CNA_DirectionalLightHandle light, CNA_Bool value)
(defcfun ("cna_directional_light_set_enabled" %directional-light-set-enabled) :uint32
  (light :uint64) (value :uint8))

;;; CNA_Result cna_basic_effect_get_alpha(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_basic_effect_get_alpha" %basic-effect-get-alpha) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_alpha(CNA_EffectHandle effect, float value)
(defcfun ("cna_basic_effect_set_alpha" %basic-effect-set-alpha) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_basic_effect_get_diffuse_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_basic_effect_get_diffuse_color" %basic-effect-get-diffuse-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_diffuse_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_basic_effect_set_diffuse_color" %basic-effect-set-diffuse-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_basic_effect_get_emissive_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_basic_effect_get_emissive_color" %basic-effect-get-emissive-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_emissive_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_basic_effect_set_emissive_color" %basic-effect-set-emissive-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_basic_effect_get_specular_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_basic_effect_get_specular_color" %basic-effect-get-specular-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_specular_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_basic_effect_set_specular_color" %basic-effect-set-specular-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_basic_effect_get_specular_power(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_basic_effect_get_specular_power" %basic-effect-get-specular-power) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_specular_power(CNA_EffectHandle effect, float value)
(defcfun ("cna_basic_effect_set_specular_power" %basic-effect-set-specular-power) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_basic_effect_get_texture(CNA_EffectHandle effect, CNA_Bool* out_has_texture, CNA_Handle* out_texture)
(defcfun ("cna_basic_effect_get_texture" %basic-effect-get-texture) :uint32
  (effect :uint64) (out-has-texture :pointer) (out-texture :pointer))

;;; CNA_Result cna_basic_effect_set_texture(CNA_EffectHandle effect, CNA_Handle texture)
(defcfun ("cna_basic_effect_set_texture" %basic-effect-set-texture) :uint32
  (effect :uint64) (texture :uint64))

;;; CNA_Result cna_basic_effect_get_texture_enabled(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_basic_effect_get_texture_enabled" %basic-effect-get-texture-enabled) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_texture_enabled(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_basic_effect_set_texture_enabled" %basic-effect-set-texture-enabled) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_basic_effect_get_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_basic_effect_get_vertex_color_enabled" %basic-effect-get-vertex-color-enabled) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_basic_effect_set_vertex_color_enabled" %basic-effect-set-vertex-color-enabled) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_basic_effect_get_prefer_per_pixel_lighting(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_basic_effect_get_prefer_per_pixel_lighting" %basic-effect-get-prefer-per-pixel-lighting) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_basic_effect_set_prefer_per_pixel_lighting(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_basic_effect_set_prefer_per_pixel_lighting" %basic-effect-set-prefer-per-pixel-lighting) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_sprite_batch_begin_with_effect(CNA_Handle sprite_batch, CNA_SpriteSortMode sort_mode, const CNA_BlendState* blend_state, const CNA_SamplerState* sampler_state, const CNA_DepthStencilState* depth_stencil_state, const CNA_RasterizerState* rasterizer_state, CNA_Handle effect, const CNA_Matrix* transform_matrix)
(defcfun ("cna_sprite_batch_begin_with_effect" %sprite-batch-begin-with-effect) :uint32
  (sprite-batch :uint64) (sort-mode :uint32) (blend-state :pointer) (sampler-state :pointer) (depth-stencil-state :pointer) (rasterizer-state :pointer) (effect :uint64) (transform-matrix :pointer))

;;; CNA_Result cna_effect_parameter_create(const CNA_EffectParameterCreateInfo* create_info, CNA_EffectParameterHandle* out_parameter)
(defcfun ("cna_effect_parameter_create" %effect-parameter-create) :uint32
  (create-info :pointer) (out-parameter :pointer))

;;; CNA_Result cna_effect_parameter_collection_create(CNA_EffectParameterCollectionHandle* out_collection)
(defcfun ("cna_effect_parameter_collection_create" %effect-parameter-collection-create) :uint32
  (out-collection :pointer))

;;; CNA_Result cna_effect_parameter_collection_add_create(CNA_EffectParameterCollectionHandle collection, const CNA_EffectParameterCreateInfo* create_info, CNA_EffectParameterHandle* out_parameter)
(defcfun ("cna_effect_parameter_collection_add_create" %effect-parameter-collection-add-create) :uint32
  (collection :uint64) (create-info :pointer) (out-parameter :pointer))

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
    ("cna_game_subscribe" %game-subscribe :uint32 (:uint64 :uint32 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_game_unsubscribe" %game-unsubscribe :uint32 (:uint64) :thread :owner :ownership "destroys")
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
    ("cna_graphics_device_manager_subscribe" %graphics-device-manager-subscribe :uint32 (:uint64 :uint32 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_graphics_resource_get_is_disposed" %graphics-resource-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_resource_get_name_byte_count" %graphics-resource-get-name-byte-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_resource_copy_name" %graphics-resource-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_resource_set_name" %graphics-resource-set-name :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_graphics_resource_get_graphics_device" %graphics-resource-get-graphics-device :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_resource_subscribe_disposing" %graphics-resource-subscribe-disposing :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_graphics_resource_unsubscribe_disposing" %graphics-resource-unsubscribe-disposing :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_texture2d_create_from_encoded_memory" %texture-2d-create-from-encoded-memory :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:texture-2d:child-of-game")
    ("cna_texture2d_create_from_file_with_device" %texture-2d-create-from-file-with-device :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:texture-2d:child-of-game")
    ("cna_texture2d_destroy" %texture-2d-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:texture-2d")
    ("cna_texture2d_get_storage_info" %texture-2d-get-storage-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texture2d_get_type_name_byte_count" %texture-2d-get-type-name-byte-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texture2d_copy_type_name" %texture-2d-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texture_get_info" %texture-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_batch_create" %sprite-batch-create :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:sprite-batch:child-of-game")
    ("cna_sprite_batch_destroy" %sprite-batch-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:sprite-batch")
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
    ("cna_gamepad_set_vibration" %gamepad-set-vibration :uint32 (:uint64 :uint32 :float :float :pointer) :thread :owner :ownership "none")
    ("cna_touch_get_state" %touch-get-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_get_capabilities" %touch-get-capabilities :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_panel_get_enabled_gestures" %touch-panel-get-enabled-gestures :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_panel_set_enabled_gestures" %touch-panel-set-enabled-gestures :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_touch_panel_get_is_gesture_available" %touch-panel-get-is-gesture-available :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_panel_read_gesture" %touch-panel-read-gesture :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_panel_get_display_width" %touch-panel-get-display-width :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_panel_set_display_width" %touch-panel-set-display-width :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_touch_panel_get_display_height" %touch-panel-get-display-height :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_panel_set_display_height" %touch-panel-set-display-height :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_touch_panel_get_display_orientation" %touch-panel-get-display-orientation :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_touch_panel_set_display_orientation" %touch-panel-set-display-orientation :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_blend_state_init" %blend-state-init :uint32 (:uint32 :pointer) :thread :any :ownership "none")
    ("cna_depth_stencil_state_init" %depth-stencil-state-init :uint32 (:uint32 :pointer) :thread :any :ownership "none")
    ("cna_rasterizer_state_init" %rasterizer-state-init :uint32 (:uint32 :pointer) :thread :any :ownership "none")
    ("cna_sampler_state_init" %sampler-state-init :uint32 (:uint32 :pointer) :thread :any :ownership "none")
    ("cna_graphics_device_get_blend_state" %graphics-device-get-blend-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_blend_state" %graphics-device-set-blend-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_depth_stencil_state" %graphics-device-get-depth-stencil-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_depth_stencil_state" %graphics-device-set-depth-stencil-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_rasterizer_state" %graphics-device-get-rasterizer-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_rasterizer_state" %graphics-device-set-rasterizer-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_sampler_state" %graphics-device-get-sampler-state :uint32 (:uint64 :uint32 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_sampler_state" %graphics-device-set-sampler-state :uint32 (:uint64 :uint32 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_batch_begin_with_states" %sprite-batch-begin-with-states :uint32 (:uint64 :uint32 :pointer :pointer :pointer :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_blend_factor" %graphics-device-get-blend-factor :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_blend_factor" %graphics-device-set-blend-factor :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_graphics_device_get_multi_sample_mask" %graphics-device-get-multi-sample-mask :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_multi_sample_mask" %graphics-device-set-multi-sample-mask :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_get_reference_stencil" %graphics-device-get-reference-stencil :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_reference_stencil" %graphics-device-set-reference-stencil :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_get_scissor_rectangle" %graphics-device-get-scissor-rectangle :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_scissor_rectangle" %graphics-device-set-scissor-rectangle :uint32 (:uint64 :uint64 :uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_get_texture" %graphics-device-get-texture :uint32 (:uint64 :uint32 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_texture" %graphics-device-set-texture :uint32 (:uint64 :uint32 :uint32 :uint64) :thread :owner :ownership "none")
    ("cna_vertex_type_get_stride" %vertex-type-get-stride :uint32 (:uint32 :pointer) :thread :any :ownership "none")
    ("cna_vertex_type_copy_elements" %vertex-type-copy-elements :uint32 (:uint32 :pointer :uint64 :pointer) :thread :any :ownership "none")
    ("cna_graphics_device_get_backbuffer_data_window" %graphics-device-get-backbuffer-data-window :uint32 (:uint64 :pointer :pointer :uint64) :thread :owner :ownership "none")
    ("cna_vertex_declaration_create" %vertex-declaration-create :uint32 (:pointer :uint64 :pointer) :thread :any :ownership "creates-owned:vertex-declaration:rootless")
    ("cna_vertex_declaration_create_with_stride" %vertex-declaration-create-with-stride :uint32 (:int32 :pointer :uint64 :pointer) :thread :any :ownership "creates-owned:vertex-declaration:rootless")
    ("cna_vertex_declaration_destroy" %vertex-declaration-destroy :uint32 (:uint64) :thread :any :ownership "destroys:vertex-declaration")
    ("cna_vertex_buffer_create" %vertex-buffer-create :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:vertex-buffer:child-of-game")
    ("cna_vertex_buffer_destroy" %vertex-buffer-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:vertex-buffer")
    ("cna_vertex_buffer_get_info" %vertex-buffer-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_vertex_buffer_copy_declaration_elements" %vertex-buffer-copy-declaration-elements :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_vertex_buffer_set_data_raw" %vertex-buffer-set-data-raw :uint32 (:uint64 :pointer :uint64 :uint64 :uint32) :thread :owner :ownership "none")
    ("cna_vertex_buffer_set_data_raw_at" %vertex-buffer-set-data-raw-at :uint32 (:uint64 :uint64 :pointer :uint64 :uint64 :uint32) :thread :owner :ownership "none")
    ("cna_vertex_buffer_set_data_raw_with_options" %vertex-buffer-set-data-raw-with-options :uint32 (:uint64 :pointer :uint64 :uint64 :uint32 :uint32) :thread :owner :ownership "none")
    ("cna_vertex_buffer_set_data_raw_at_with_options" %vertex-buffer-set-data-raw-at-with-options :uint32 (:uint64 :uint64 :pointer :uint64 :uint64 :uint32 :uint32) :thread :owner :ownership "none")
    ("cna_vertex_buffer_get_data_raw" %vertex-buffer-get-data-raw :uint32 (:uint64 :uint64 :pointer :uint64 :uint64 :uint32) :thread :owner :ownership "none")
    ("cna_index_buffer_create" %index-buffer-create :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:index-buffer:child-of-game")
    ("cna_index_buffer_destroy" %index-buffer-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:index-buffer")
    ("cna_index_buffer_get_info" %index-buffer-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_index_buffer_set_data" %index-buffer-set-data :uint32 (:uint64 :pointer :pointer :uint64) :thread :owner :ownership "none")
    ("cna_index_buffer_set_data_at" %index-buffer-set-data-at :uint32 (:uint64 :uint64 :pointer :pointer :uint64) :thread :owner :ownership "none")
    ("cna_index_buffer_get_data" %index-buffer-get-data :uint32 (:uint64 :pointer :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_vertex_buffer" %graphics-device-set-vertex-buffer :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_set_vertex_buffer_offset" %graphics-device-set-vertex-buffer-offset :uint32 (:uint64 :uint64 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_set_vertex_buffers" %graphics-device-set-vertex-buffers :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_get_vertex_buffer_count" %graphics-device-get-vertex-buffer-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_copy_vertex_buffers" %graphics-device-copy-vertex-buffers :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_index_buffer" %graphics-device-set-index-buffer :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_get_index_buffer" %graphics-device-get-index-buffer :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_draw_primitives" %graphics-device-draw-primitives :uint32 (:uint64 :uint32 :int32 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_draw_indexed_primitives" %graphics-device-draw-indexed-primitives :uint32 (:uint64 :uint32 :int32 :int32 :int32 :int32 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_draw_user_primitives" %graphics-device-draw-user-primitives :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_draw_user_indexed_primitives" %graphics-device-draw-user-indexed-primitives :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_vertex_buffer_subscribe_content_lost" %vertex-buffer-subscribe-content-lost :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "none")
    ("cna_vertex_buffer_unsubscribe_content_lost" %vertex-buffer-unsubscribe-content-lost :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_index_buffer_subscribe_content_lost" %index-buffer-subscribe-content-lost :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "none")
    ("cna_index_buffer_unsubscribe_content_lost" %index-buffer-unsubscribe-content-lost :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_basic_effect_create" %basic-effect-create :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_create_compiled" %effect-create-compiled :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_destroy" %effect-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_dispose" %effect-dispose :uint32 (:uint64) :thread :game :ownership "none")
    ("cna_effect_clone" %effect-clone :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_get_parameters" %effect-get-parameters :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_get_techniques" %effect-get-techniques :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_get_current_technique" %effect-get-current-technique :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_set_current_technique" %effect-set-current-technique :uint32 (:uint64 :uint64) :thread :game :ownership "none")
    ("cna_effect_technique_collection_get_count" %effect-technique-collection-get-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_technique_collection_get_at" %effect-technique-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_technique_collection_destroy" %effect-technique-collection-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_technique_get_name_byte_count" %effect-technique-get-name-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_technique_copy_name" %effect-technique-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_technique_get_identity" %effect-technique-get-identity :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_technique_get_passes" %effect-technique-get-passes :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_technique_get_annotations" %effect-technique-get-annotations :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_technique_destroy" %effect-technique-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_pass_collection_get_count" %effect-pass-collection-get-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_pass_collection_get_at" %effect-pass-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_pass_collection_destroy" %effect-pass-collection-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_pass_get_name_byte_count" %effect-pass-get-name-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_pass_copy_name" %effect-pass-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_pass_get_annotations" %effect-pass-get-annotations :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_pass_apply" %effect-pass-apply :uint32 (:uint64) :thread :game :ownership "none")
    ("cna_effect_pass_destroy" %effect-pass-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_annotation_collection_get_count" %effect-annotation-collection-get-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_collection_get_at" %effect-annotation-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_annotation_collection_destroy" %effect-annotation-collection-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_annotation_get_info" %effect-annotation-get-info :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_name_byte_count" %effect-annotation-get-name-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_copy_name" %effect-annotation-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_semantic_byte_count" %effect-annotation-get-semantic-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_copy_semantic" %effect-annotation-copy-semantic :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_string_byte_count" %effect-annotation-get-value-string-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_copy_value_string" %effect-annotation-copy-value-string :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_boolean" %effect-annotation-get-value-boolean :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_int32" %effect-annotation-get-value-int-32 :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_single" %effect-annotation-get-value-single :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_vector2" %effect-annotation-get-value-vector-2 :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_vector3" %effect-annotation-get-value-vector-3 :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_vector4" %effect-annotation-get-value-vector-4 :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_get_value_matrix" %effect-annotation-get-value-matrix :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_annotation_destroy" %effect-annotation-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_parameter_collection_get_count" %effect-parameter-collection-get-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_collection_get_at" %effect-parameter-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_parameter_collection_find_name" %effect-parameter-collection-find-name :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :game :ownership "owns")
    ("cna_effect_parameter_collection_find_semantic" %effect-parameter-collection-find-semantic :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :game :ownership "owns")
    ("cna_effect_parameter_collection_destroy" %effect-parameter-collection-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_parameter_get_info" %effect-parameter-get-info :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_get_name_byte_count" %effect-parameter-get-name-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_copy_name" %effect-parameter-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_get_semantic_byte_count" %effect-parameter-get-semantic-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_copy_semantic" %effect-parameter-copy-semantic :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_get_elements" %effect-parameter-get-elements :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_parameter_get_structure_members" %effect-parameter-get-structure-members :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_parameter_get_annotations" %effect-parameter-get-annotations :uint32 (:uint64 :pointer) :thread :game :ownership "owns")
    ("cna_effect_parameter_get_value" %effect-parameter-get-value :uint32 (:uint64 :uint32 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_set_value" %effect-parameter-set-value :uint32 (:uint64 :uint32 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_get_values" %effect-parameter-get-values :uint32 (:uint64 :uint32 :uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_set_values" %effect-parameter-set-values :uint32 (:uint64 :uint32 :pointer :uint64) :thread :game :ownership "none")
    ("cna_effect_parameter_get_value_string_byte_count" %effect-parameter-get-value-string-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_copy_value_string" %effect-parameter-copy-value-string :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_set_value_string" %effect-parameter-set-value-string :uint32 (:uint64 :pointer :uint64) :thread :game :ownership "none")
    ("cna_effect_parameter_get_value_texture" %effect-parameter-get-value-texture :uint32 (:uint64 :uint32 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_set_value_texture" %effect-parameter-set-value-texture :uint32 (:uint64 :uint32 :uint64) :thread :game :ownership "none")
    ("cna_effect_parameter_destroy" %effect-parameter-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_effect_matrices_get_world" %effect-matrices-get-world :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_matrices_get_view" %effect-matrices-get-view :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_matrices_get_projection" %effect-matrices-get-projection :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_fog_get_color" %effect-fog-get-color :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_fog_set_color" %effect-fog-set-color :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_effect_fog_get_enabled" %effect-fog-get-enabled :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_fog_set_enabled" %effect-fog-set-enabled :uint32 (:uint64 :uint8) :thread :game :ownership "none")
    ("cna_effect_fog_get_start" %effect-fog-get-start :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_fog_set_start" %effect-fog-set-start :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_effect_fog_get_end" %effect-fog-get-end :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_fog_set_end" %effect-fog-set-end :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_effect_lights_get_ambient_color" %effect-lights-get-ambient-color :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_lights_set_ambient_color" %effect-lights-set-ambient-color :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_effect_lights_get_enabled" %effect-lights-get-enabled :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_lights_set_enabled" %effect-lights-set-enabled :uint32 (:uint64 :uint8) :thread :game :ownership "none")
    ("cna_effect_lights_get_directional_light" %effect-lights-get-directional-light :uint32 (:uint64 :uint32 :pointer) :thread :game :ownership "owns")
    ("cna_effect_lights_enable_default" %effect-lights-enable-default :uint32 (:uint64) :thread :game :ownership "none")
    ("cna_directional_light_destroy" %directional-light-destroy :uint32 (:uint64) :thread :game :ownership "releases")
    ("cna_directional_light_get_diffuse_color" %directional-light-get-diffuse-color :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_directional_light_set_diffuse_color" %directional-light-set-diffuse-color :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_directional_light_get_direction" %directional-light-get-direction :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_directional_light_set_direction" %directional-light-set-direction :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_directional_light_get_specular_color" %directional-light-get-specular-color :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_directional_light_set_specular_color" %directional-light-set-specular-color :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_directional_light_get_enabled" %directional-light-get-enabled :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_directional_light_set_enabled" %directional-light-set-enabled :uint32 (:uint64 :uint8) :thread :game :ownership "none")
    ("cna_basic_effect_get_alpha" %basic-effect-get-alpha :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_alpha" %basic-effect-set-alpha :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_basic_effect_get_diffuse_color" %basic-effect-get-diffuse-color :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_diffuse_color" %basic-effect-set-diffuse-color :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_basic_effect_get_emissive_color" %basic-effect-get-emissive-color :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_emissive_color" %basic-effect-set-emissive-color :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_basic_effect_get_specular_color" %basic-effect-get-specular-color :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_specular_color" %basic-effect-set-specular-color :uint32 (:uint64 :double :float) :thread :game :ownership "none")
    ("cna_basic_effect_get_specular_power" %basic-effect-get-specular-power :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_specular_power" %basic-effect-set-specular-power :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_basic_effect_get_texture" %basic-effect-get-texture :uint32 (:uint64 :pointer :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_texture" %basic-effect-set-texture :uint32 (:uint64 :uint64) :thread :game :ownership "none")
    ("cna_basic_effect_get_texture_enabled" %basic-effect-get-texture-enabled :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_texture_enabled" %basic-effect-set-texture-enabled :uint32 (:uint64 :uint8) :thread :game :ownership "none")
    ("cna_basic_effect_get_vertex_color_enabled" %basic-effect-get-vertex-color-enabled :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_vertex_color_enabled" %basic-effect-set-vertex-color-enabled :uint32 (:uint64 :uint8) :thread :game :ownership "none")
    ("cna_basic_effect_get_prefer_per_pixel_lighting" %basic-effect-get-prefer-per-pixel-lighting :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_basic_effect_set_prefer_per_pixel_lighting" %basic-effect-set-prefer-per-pixel-lighting :uint32 (:uint64 :uint8) :thread :game :ownership "none")
    ("cna_sprite_batch_begin_with_effect" %sprite-batch-begin-with-effect :uint32 (:uint64 :uint32 :pointer :pointer :pointer :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_parameter_create" %effect-parameter-create :uint32 (:pointer :pointer) :thread :any :ownership "owns")
    ("cna_effect_parameter_collection_create" %effect-parameter-collection-create :uint32 (:pointer) :thread :any :ownership "owns")
    ("cna_effect_parameter_collection_add_create" %effect-parameter-collection-add-create :uint32 (:uint64 :pointer :pointer) :thread :any :ownership "owns"))
  "Every native route this binding may call: C name, Lisp name, and bound CFFI shape.")

