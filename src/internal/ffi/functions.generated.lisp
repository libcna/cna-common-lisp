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

;;; CNA_Result cna_game_window_get_title_size(CNA_Handle game, uint64_t* out_bytes)
(defcfun ("cna_game_window_get_title_size" %game-window-get-title-size) :uint32
  (game :uint64) (out-bytes :pointer))

;;; CNA_Result cna_game_window_copy_title(CNA_Handle game, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_game_window_copy_title" %game-window-copy-title) :uint32
  (game :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_game_window_get_allow_user_resizing(CNA_Handle game, CNA_Bool* out_allowed)
(defcfun ("cna_game_window_get_allow_user_resizing" %game-window-get-allow-user-resizing) :uint32
  (game :uint64) (out-allowed :pointer))

;;; CNA_Result cna_game_window_set_allow_user_resizing(CNA_Handle game, CNA_Bool allowed)
(defcfun ("cna_game_window_set_allow_user_resizing" %game-window-set-allow-user-resizing) :uint32
  (game :uint64) (allowed :uint8))

;;; CNA_Result cna_game_window_get_client_bounds(CNA_Handle game, CNA_Rectangle* out_bounds)
(defcfun ("cna_game_window_get_client_bounds" %game-window-get-client-bounds) :uint32
  (game :uint64) (out-bounds :pointer))

;;; CNA_Result cna_game_window_get_current_orientation(CNA_Handle game, CNA_DisplayOrientation* out_orientation)
(defcfun ("cna_game_window_get_current_orientation" %game-window-get-current-orientation) :uint32
  (game :uint64) (out-orientation :pointer))

;;; CNA_Result cna_game_window_get_screen_device_name_size(CNA_Handle game, uint64_t* out_bytes)
(defcfun ("cna_game_window_get_screen_device_name_size" %game-window-get-screen-device-name-size) :uint32
  (game :uint64) (out-bytes :pointer))

;;; CNA_Result cna_game_window_copy_screen_device_name(CNA_Handle game, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_game_window_copy_screen_device_name" %game-window-copy-screen-device-name) :uint32
  (game :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_game_window_begin_screen_device_change(CNA_Handle game, CNA_Bool will_be_full_screen)
(defcfun ("cna_game_window_begin_screen_device_change" %game-window-begin-screen-device-change) :uint32
  (game :uint64) (will-be-full-screen :uint8))

;;; CNA_Result cna_game_window_end_screen_device_change(CNA_Handle game, CNA_StringView screen_device_name, int32_t client_width, int32_t client_height)
(defcfun ("cna_game_window_end_screen_device_change" %game-window-end-screen-device-change) :uint32
  (game :uint64) (screen-device-name-0 :pointer) (screen-device-name-1 :uint64) (client-width :int32) (client-height :int32))

;;; CNA_Result cna_game_window_subscribe(CNA_Handle game, CNA_GameWindowEvent event, CNA_GameEventCallback callback, void* context, CNA_GameEventRegistrationHandle* out_registration)
(defcfun ("cna_game_window_subscribe" %game-window-subscribe) :uint32
  (game :uint64) (event :uint32) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_title_location_get_path_size(CNA_Handle game, uint64_t* out_bytes)
(defcfun ("cna_title_location_get_path_size" %title-location-get-path-size) :uint32
  (game :uint64) (out-bytes :pointer))

;;; CNA_Result cna_title_location_copy_path(CNA_Handle game, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_title_location_copy_path" %title-location-copy-path) :uint32
  (game :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_device_get_viewport(CNA_Handle graphics_device, CNA_Viewport* out_viewport)
(defcfun ("cna_graphics_device_get_viewport" %graphics-device-get-viewport) :uint32
  (graphics-device :uint64) (out-viewport :pointer))

;;; CNA_Result cna_graphics_device_clear_rgba(CNA_Handle graphics_device, float r, float g, float b, float a)
(defcfun ("cna_graphics_device_clear_rgba" %graphics-device-clear-rgba) :uint32
  (graphics-device :uint64) (r :float) (g :float) (b :float) (a :float))

;;; CNA_Result cna_presentation_parameters_init(CNA_PresentationParameters* out_parameters)
(defcfun ("cna_presentation_parameters_init" %presentation-parameters-init) :uint32
  (out-parameters :pointer))

;;; CNA_Result cna_presentation_parameters_clone(const CNA_PresentationParameters* source, CNA_PresentationParameters* out_parameters)
(defcfun ("cna_presentation_parameters_clone" %presentation-parameters-clone) :uint32
  (source :pointer) (out-parameters :pointer))

;;; CNA_Result cna_presentation_parameters_get_bounds(const CNA_PresentationParameters* parameters, CNA_Rectangle* out_bounds)
(defcfun ("cna_presentation_parameters_get_bounds" %presentation-parameters-get-bounds) :uint32
  (parameters :pointer) (out-bounds :pointer))

;;; CNA_Result cna_graphics_device_get_presentation_parameters(CNA_Handle graphics_device, CNA_PresentationParameters* out_parameters)
(defcfun ("cna_graphics_device_get_presentation_parameters" %graphics-device-get-presentation-parameters) :uint32
  (graphics-device :uint64) (out-parameters :pointer))

;;; CNA_Result cna_graphics_device_set_presentation_parameters(CNA_Handle graphics_device, const CNA_PresentationParameters* parameters)
(defcfun ("cna_graphics_device_set_presentation_parameters" %graphics-device-set-presentation-parameters) :uint32
  (graphics-device :uint64) (parameters :pointer))

;;; CNA_Result cna_graphics_device_get_display_mode(CNA_Handle graphics_device, CNA_DisplayMode* out_mode)
(defcfun ("cna_graphics_device_get_display_mode" %graphics-device-get-display-mode) :uint32
  (graphics-device :uint64) (out-mode :pointer))

;;; CNA_Result cna_graphics_device_get_status(CNA_Handle graphics_device, CNA_GraphicsDeviceStatus* out_status)
(defcfun ("cna_graphics_device_get_status" %graphics-device-get-status) :uint32
  (graphics-device :uint64) (out-status :pointer))

;;; CNA_Result cna_graphics_device_subscribe_event(CNA_Handle graphics_device, CNA_GraphicsDeviceEvent device_event, CNA_GraphicsDeviceEventCallback callback, void* context, CNA_GraphicsDeviceEventRegistrationHandle* out_registration)
(defcfun ("cna_graphics_device_subscribe_event" %graphics-device-subscribe-event) :uint32
  (graphics-device :uint64) (device-event :uint32) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_graphics_device_unsubscribe(CNA_GraphicsDeviceEventRegistrationHandle registration)
(defcfun ("cna_graphics_device_unsubscribe" %graphics-device-unsubscribe) :uint32
  (registration :uint64))

;;; CNA_Result cna_graphics_device_draw_instanced_primitives(CNA_Handle graphics_device, CNA_PrimitiveType primitive_type, int32_t base_vertex, int32_t min_vertex_index, int32_t num_vertices, int32_t start_index, int32_t primitive_count, int32_t instance_count)
(defcfun ("cna_graphics_device_draw_instanced_primitives" %graphics-device-draw-instanced-primitives) :uint32
  (graphics-device :uint64) (primitive-type :uint32) (base-vertex :int32) (min-vertex-index :int32) (num-vertices :int32) (start-index :int32) (primitive-count :int32) (instance-count :int32))

;;; CNA_Result cna_graphics_device_create(uint32_t adapter_index, uint32_t graphics_profile, const CNA_PresentationParameters* parameters, CNA_Handle* out_graphics_device)
(defcfun ("cna_graphics_device_create" %graphics-device-create) :uint32
  (adapter-index :uint32) (graphics-profile :uint32) (parameters :pointer) (out-graphics-device :pointer))

;;; CNA_Result cna_graphics_device_destroy(CNA_Handle graphics_device)
(defcfun ("cna_graphics_device_destroy" %graphics-device-destroy) :uint32
  (graphics-device :uint64))

;;; CNA_Result cna_graphics_device_reset(CNA_Handle graphics_device)
(defcfun ("cna_graphics_device_reset" %graphics-device-reset) :uint32
  (graphics-device :uint64))

;;; CNA_Result cna_graphics_device_reset_with_parameters(CNA_Handle graphics_device, const CNA_PresentationParameters* parameters, const uint32_t* adapter_index)
(defcfun ("cna_graphics_device_reset_with_parameters" %graphics-device-reset-with-parameters) :uint32
  (graphics-device :uint64) (parameters :pointer) (adapter-index :pointer))

;;; CNA_Result cna_graphics_device_get_is_disposed(CNA_Handle graphics_device, CNA_Bool* out_is_disposed)
(defcfun ("cna_graphics_device_get_is_disposed" %graphics-device-get-is-disposed) :uint32
  (graphics-device :uint64) (out-is-disposed :pointer))

;;; CNA_Result cna_graphics_adapter_get_count(CNA_Handle graphics_device, uint64_t* out_count)
(defcfun ("cna_graphics_adapter_get_count" %graphics-adapter-get-count) :uint32
  (graphics-device :uint64) (out-count :pointer))

;;; CNA_Result cna_graphics_adapter_get_info(CNA_Handle graphics_device, uint32_t adapter_index, CNA_GraphicsAdapterInfo* out_info)
(defcfun ("cna_graphics_adapter_get_info" %graphics-adapter-get-info) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (out-info :pointer))

;;; CNA_Result cna_graphics_adapter_copy_description(CNA_Handle graphics_device, uint32_t adapter_index, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_graphics_adapter_copy_description" %graphics-adapter-copy-description) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_adapter_copy_device_name(CNA_Handle graphics_device, uint32_t adapter_index, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_graphics_adapter_copy_device_name" %graphics-adapter-copy-device-name) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_adapter_get_current_display_mode(CNA_Handle graphics_device, uint32_t adapter_index, CNA_DisplayMode* out_mode)
(defcfun ("cna_graphics_adapter_get_current_display_mode" %graphics-adapter-get-current-display-mode) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (out-mode :pointer))

;;; CNA_Result cna_graphics_adapter_get_display_mode_count(CNA_Handle graphics_device, uint32_t adapter_index, CNA_Bool filter_by_format, CNA_SurfaceFormat format, uint64_t* out_count)
(defcfun ("cna_graphics_adapter_get_display_mode_count" %graphics-adapter-get-display-mode-count) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (filter-by-format :uint8) (format :uint32) (out-count :pointer))

;;; CNA_Result cna_graphics_adapter_copy_display_modes(CNA_Handle graphics_device, uint32_t adapter_index, CNA_Bool filter_by_format, CNA_SurfaceFormat format, CNA_DisplayMode* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_graphics_adapter_copy_display_modes" %graphics-adapter-copy-display-modes) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (filter-by-format :uint8) (format :uint32) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_graphics_adapter_set_device_preferences(CNA_Handle graphics_device, uint32_t adapter_index, CNA_Bool use_null_device, CNA_Bool use_reference_device)
(defcfun ("cna_graphics_adapter_set_device_preferences" %graphics-adapter-set-device-preferences) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (use-null-device :uint8) (use-reference-device :uint8))

;;; CNA_Result cna_graphics_adapter_is_profile_supported(CNA_Handle graphics_device, uint32_t adapter_index, CNA_GraphicsProfile profile, CNA_Bool* out_supported)
(defcfun ("cna_graphics_adapter_is_profile_supported" %graphics-adapter-is-profile-supported) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (profile :uint32) (out-supported :pointer))

;;; CNA_Result cna_graphics_adapter_query_render_target_format(CNA_Handle graphics_device, uint32_t adapter_index, CNA_GraphicsProfile profile, CNA_SurfaceFormat format, CNA_DepthFormat depth_format, int32_t multi_sample_count, CNA_GraphicsFormatSelection* out_selection)
(defcfun ("cna_graphics_adapter_query_render_target_format" %graphics-adapter-query-render-target-format) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (profile :uint32) (format :uint32) (depth-format :uint32) (multi-sample-count :int32) (out-selection :pointer))

;;; CNA_Result cna_graphics_adapter_query_backbuffer_format(CNA_Handle graphics_device, uint32_t adapter_index, CNA_GraphicsProfile profile, CNA_SurfaceFormat format, CNA_DepthFormat depth_format, int32_t multi_sample_count, CNA_GraphicsFormatSelection* out_selection)
(defcfun ("cna_graphics_adapter_query_backbuffer_format" %graphics-adapter-query-backbuffer-format) :uint32
  (graphics-device :uint64) (adapter-index :uint32) (profile :uint32) (format :uint32) (depth-format :uint32) (multi-sample-count :int32) (out-selection :pointer))

;;; CNA_Result cna_graphics_device_get_adapter_index(CNA_Handle graphics_device, uint32_t* out_adapter_index)
(defcfun ("cna_graphics_device_get_adapter_index" %graphics-device-get-adapter-index) :uint32
  (graphics-device :uint64) (out-adapter-index :pointer))

;;; CNA_Result cna_graphics_device_get_graphics_profile(CNA_Handle graphics_device, CNA_GraphicsProfile* out_profile)
(defcfun ("cna_graphics_device_get_graphics_profile" %graphics-device-get-graphics-profile) :uint32
  (graphics-device :uint64) (out-profile :pointer))

;;; CNA_Result cna_graphics_device_clear_options(CNA_Handle graphics_device, CNA_ClearOptions options, CNA_Color color, float depth, int32_t stencil)
(defcfun ("cna_graphics_device_clear_options" %graphics-device-clear-options) :uint32
  (graphics-device :uint64) (options :uint32) (color-0 :uint32) (depth :float) (stencil :int32))

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

;;; CNA_Result cna_graphics_device_information_init(CNA_GraphicsDeviceInformation* out_information)
(defcfun ("cna_graphics_device_information_init" %graphics-device-information-init) :uint32
  (out-information :pointer))

;;; CNA_Result cna_graphics_device_information_clone(const CNA_GraphicsDeviceInformation* information, CNA_GraphicsDeviceInformation* out_information)
(defcfun ("cna_graphics_device_information_clone" %graphics-device-information-clone) :uint32
  (information :pointer) (out-information :pointer))

;;; CNA_Result cna_graphics_device_information_get_type_name_size(uint64_t* out_bytes)
(defcfun ("cna_graphics_device_information_get_type_name_size" %graphics-device-information-get-type-name-size) :uint32
  (out-bytes :pointer))

;;; CNA_Result cna_graphics_device_information_copy_type_name(char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_graphics_device_information_copy_type_name" %graphics-device-information-copy-type-name) :uint32
  (destination :pointer) (capacity :uint64) (out-bytes :pointer))

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

;;; CNA_Result cna_graphics_device_manager_get_graphics_profile(CNA_GraphicsDeviceManagerHandle manager, CNA_GraphicsProfile* out_profile)
(defcfun ("cna_graphics_device_manager_get_graphics_profile" %graphics-device-manager-get-graphics-profile) :uint32
  (manager :uint64) (out-profile :pointer))

;;; CNA_Result cna_graphics_device_manager_set_graphics_profile(CNA_GraphicsDeviceManagerHandle manager, CNA_GraphicsProfile profile)
(defcfun ("cna_graphics_device_manager_set_graphics_profile" %graphics-device-manager-set-graphics-profile) :uint32
  (manager :uint64) (profile :uint32))

;;; CNA_Result cna_graphics_device_manager_get_prefer_multi_sampling(CNA_GraphicsDeviceManagerHandle manager, CNA_Bool* out_prefer)
(defcfun ("cna_graphics_device_manager_get_prefer_multi_sampling" %graphics-device-manager-get-prefer-multi-sampling) :uint32
  (manager :uint64) (out-prefer :pointer))

;;; CNA_Result cna_graphics_device_manager_set_prefer_multi_sampling(CNA_GraphicsDeviceManagerHandle manager, CNA_Bool prefer)
(defcfun ("cna_graphics_device_manager_set_prefer_multi_sampling" %graphics-device-manager-set-prefer-multi-sampling) :uint32
  (manager :uint64) (prefer :uint8))

;;; CNA_Result cna_graphics_device_manager_get_preferred_back_buffer_format(CNA_GraphicsDeviceManagerHandle manager, CNA_SurfaceFormat* out_format)
(defcfun ("cna_graphics_device_manager_get_preferred_back_buffer_format" %graphics-device-manager-get-preferred-back-buffer-format) :uint32
  (manager :uint64) (out-format :pointer))

;;; CNA_Result cna_graphics_device_manager_set_preferred_back_buffer_format(CNA_GraphicsDeviceManagerHandle manager, CNA_SurfaceFormat format)
(defcfun ("cna_graphics_device_manager_set_preferred_back_buffer_format" %graphics-device-manager-set-preferred-back-buffer-format) :uint32
  (manager :uint64) (format :uint32))

;;; CNA_Result cna_graphics_device_manager_get_preferred_depth_stencil_format(CNA_GraphicsDeviceManagerHandle manager, CNA_DepthFormat* out_format)
(defcfun ("cna_graphics_device_manager_get_preferred_depth_stencil_format" %graphics-device-manager-get-preferred-depth-stencil-format) :uint32
  (manager :uint64) (out-format :pointer))

;;; CNA_Result cna_graphics_device_manager_set_preferred_depth_stencil_format(CNA_GraphicsDeviceManagerHandle manager, CNA_DepthFormat format)
(defcfun ("cna_graphics_device_manager_set_preferred_depth_stencil_format" %graphics-device-manager-set-preferred-depth-stencil-format) :uint32
  (manager :uint64) (format :uint32))

;;; CNA_Result cna_graphics_device_manager_get_supported_orientations(CNA_GraphicsDeviceManagerHandle manager, CNA_DisplayOrientation* out_orientations)
(defcfun ("cna_graphics_device_manager_get_supported_orientations" %graphics-device-manager-get-supported-orientations) :uint32
  (manager :uint64) (out-orientations :pointer))

;;; CNA_Result cna_graphics_device_manager_set_supported_orientations(CNA_GraphicsDeviceManagerHandle manager, CNA_DisplayOrientation orientations)
(defcfun ("cna_graphics_device_manager_set_supported_orientations" %graphics-device-manager-set-supported-orientations) :uint32
  (manager :uint64) (orientations :uint32))

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

;;; CNA_Result cna_graphics_device_manager_create_device(CNA_GraphicsDeviceManagerHandle manager)
(defcfun ("cna_graphics_device_manager_create_device" %graphics-device-manager-create-device) :uint32
  (manager :uint64))

;;; CNA_Result cna_graphics_device_manager_begin_draw(CNA_GraphicsDeviceManagerHandle manager, CNA_Bool* out_should_draw)
(defcfun ("cna_graphics_device_manager_begin_draw" %graphics-device-manager-begin-draw) :uint32
  (manager :uint64) (out-should-draw :pointer))

;;; CNA_Result cna_graphics_device_manager_end_draw(CNA_GraphicsDeviceManagerHandle manager)
(defcfun ("cna_graphics_device_manager_end_draw" %graphics-device-manager-end-draw) :uint32
  (manager :uint64))

;;; CNA_Result cna_graphics_device_manager_get_type_name_size(CNA_GraphicsDeviceManagerHandle manager, uint64_t* out_bytes)
(defcfun ("cna_graphics_device_manager_get_type_name_size" %graphics-device-manager-get-type-name-size) :uint32
  (manager :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_device_manager_copy_type_name(CNA_GraphicsDeviceManagerHandle manager, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_graphics_device_manager_copy_type_name" %graphics-device-manager-copy-type-name) :uint32
  (manager :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_graphics_device_manager_subscribe_preparing_device_settings_ext(CNA_GraphicsDeviceManagerHandle manager, CNA_PreparingDeviceSettingsMutatorEXT callback, void* context, CNA_GameEventRegistrationHandle* out_registration)
(defcfun ("cna_graphics_device_manager_subscribe_preparing_device_settings_ext" %graphics-device-manager-subscribe-preparing-device-settings-ext) :uint32
  (manager :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

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

;;; CNA_Result cna_texture2d_get_encoded_byte_count(CNA_Handle texture, CNA_TextureImageFormat image_format, uint32_t target_width, uint32_t target_height, uint64_t* out_byte_count)
(defcfun ("cna_texture2d_get_encoded_byte_count" %texture-2d-get-encoded-byte-count) :uint32
  (texture :uint64) (image-format :uint32) (target-width :uint32) (target-height :uint32) (out-byte-count :pointer))

;;; CNA_Result cna_texture2d_copy_encoded(CNA_Handle texture, CNA_TextureImageFormat image_format, uint32_t target_width, uint32_t target_height, uint8_t* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_texture2d_copy_encoded" %texture-2d-copy-encoded) :uint32
  (texture :uint64) (image-format :uint32) (target-width :uint32) (target-height :uint32) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

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

;;; CNA_Result cna_effect_get_type_name_byte_count(CNA_EffectHandle effect, uint64_t* out_byte_count)
(defcfun ("cna_effect_get_type_name_byte_count" %effect-get-type-name-byte-count) :uint32
  (effect :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_effect_copy_type_name(CNA_EffectHandle effect, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_effect_copy_type_name" %effect-copy-type-name) :uint32
  (effect :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

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

;;; CNA_Result cna_sprite_font_create(const CNA_SpriteFontCreateInfo* create_info, CNA_Handle* out_sprite_font)
(defcfun ("cna_sprite_font_create" %sprite-font-create) :uint32
  (create-info :pointer) (out-sprite-font :pointer))

;;; CNA_Result cna_sprite_font_destroy(CNA_Handle sprite_font)
(defcfun ("cna_sprite_font_destroy" %sprite-font-destroy) :uint32
  (sprite-font :uint64))

;;; CNA_Result cna_sprite_font_get_info(CNA_Handle sprite_font, CNA_SpriteFontInfo* out_info)
(defcfun ("cna_sprite_font_get_info" %sprite-font-get-info) :uint32
  (sprite-font :uint64) (out-info :pointer))

;;; CNA_Result cna_sprite_font_copy_characters(CNA_Handle sprite_font, CNA_Char16* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_sprite_font_copy_characters" %sprite-font-copy-characters) :uint32
  (sprite-font :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_sprite_font_copy_glyphs(CNA_Handle sprite_font, CNA_SpriteFontGlyph* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_sprite_font_copy_glyphs" %sprite-font-copy-glyphs) :uint32
  (sprite-font :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_sprite_font_measure_utf8(CNA_Handle sprite_font, CNA_StringView text, CNA_Vector2* out_size)
(defcfun ("cna_sprite_font_measure_utf8" %sprite-font-measure-utf-8) :uint32
  (sprite-font :uint64) (text-0 :pointer) (text-1 :uint64) (out-size :pointer))

;;; CNA_Result cna_alpha_test_effect_create(CNA_Handle graphics_device, CNA_EffectHandle* out_effect)
(defcfun ("cna_alpha_test_effect_create" %alpha-test-effect-create) :uint32
  (graphics-device :uint64) (out-effect :pointer))

;;; CNA_Result cna_alpha_test_effect_get_alpha(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_alpha_test_effect_get_alpha" %alpha-test-effect-get-alpha) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_alpha_test_effect_get_alpha_function(CNA_EffectHandle effect, CNA_CompareFunction* out_value)
(defcfun ("cna_alpha_test_effect_get_alpha_function" %alpha-test-effect-get-alpha-function) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_alpha_test_effect_get_diffuse_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_alpha_test_effect_get_diffuse_color" %alpha-test-effect-get-diffuse-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_alpha_test_effect_get_reference_alpha(CNA_EffectHandle effect, int32_t* out_value)
(defcfun ("cna_alpha_test_effect_get_reference_alpha" %alpha-test-effect-get-reference-alpha) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_alpha_test_effect_get_texture(CNA_EffectHandle effect, CNA_Bool* out_has_texture, CNA_Handle* out_texture)
(defcfun ("cna_alpha_test_effect_get_texture" %alpha-test-effect-get-texture) :uint32
  (effect :uint64) (out-has-texture :pointer) (out-texture :pointer))

;;; CNA_Result cna_alpha_test_effect_get_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_alpha_test_effect_get_vertex_color_enabled" %alpha-test-effect-get-vertex-color-enabled) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_alpha_test_effect_set_alpha(CNA_EffectHandle effect, float value)
(defcfun ("cna_alpha_test_effect_set_alpha" %alpha-test-effect-set-alpha) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_alpha_test_effect_set_alpha_function(CNA_EffectHandle effect, CNA_CompareFunction value)
(defcfun ("cna_alpha_test_effect_set_alpha_function" %alpha-test-effect-set-alpha-function) :uint32
  (effect :uint64) (value :uint32))

;;; CNA_Result cna_alpha_test_effect_set_diffuse_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_alpha_test_effect_set_diffuse_color" %alpha-test-effect-set-diffuse-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_alpha_test_effect_set_reference_alpha(CNA_EffectHandle effect, int32_t value)
(defcfun ("cna_alpha_test_effect_set_reference_alpha" %alpha-test-effect-set-reference-alpha) :uint32
  (effect :uint64) (value :int32))

;;; CNA_Result cna_alpha_test_effect_set_texture(CNA_EffectHandle effect, CNA_Handle texture)
(defcfun ("cna_alpha_test_effect_set_texture" %alpha-test-effect-set-texture) :uint32
  (effect :uint64) (texture :uint64))

;;; CNA_Result cna_alpha_test_effect_set_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_alpha_test_effect_set_vertex_color_enabled" %alpha-test-effect-set-vertex-color-enabled) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_dual_texture_effect_create(CNA_Handle graphics_device, CNA_EffectHandle* out_effect)
(defcfun ("cna_dual_texture_effect_create" %dual-texture-effect-create) :uint32
  (graphics-device :uint64) (out-effect :pointer))

;;; CNA_Result cna_dual_texture_effect_get_alpha(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_dual_texture_effect_get_alpha" %dual-texture-effect-get-alpha) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_dual_texture_effect_get_diffuse_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_dual_texture_effect_get_diffuse_color" %dual-texture-effect-get-diffuse-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_dual_texture_effect_get_texture(CNA_EffectHandle effect, uint32_t texture_index, CNA_Bool* out_has_texture, CNA_Handle* out_texture)
(defcfun ("cna_dual_texture_effect_get_texture" %dual-texture-effect-get-texture) :uint32
  (effect :uint64) (texture-index :uint32) (out-has-texture :pointer) (out-texture :pointer))

;;; CNA_Result cna_dual_texture_effect_get_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_dual_texture_effect_get_vertex_color_enabled" %dual-texture-effect-get-vertex-color-enabled) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_dual_texture_effect_set_alpha(CNA_EffectHandle effect, float value)
(defcfun ("cna_dual_texture_effect_set_alpha" %dual-texture-effect-set-alpha) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_dual_texture_effect_set_diffuse_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_dual_texture_effect_set_diffuse_color" %dual-texture-effect-set-diffuse-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_dual_texture_effect_set_texture(CNA_EffectHandle effect, uint32_t texture_index, CNA_Handle texture)
(defcfun ("cna_dual_texture_effect_set_texture" %dual-texture-effect-set-texture) :uint32
  (effect :uint64) (texture-index :uint32) (texture :uint64))

;;; CNA_Result cna_dual_texture_effect_set_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_dual_texture_effect_set_vertex_color_enabled" %dual-texture-effect-set-vertex-color-enabled) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_skinned_effect_copy_bone_transforms(CNA_EffectHandle effect, uint64_t requested_count, CNA_Matrix* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_skinned_effect_copy_bone_transforms" %skinned-effect-copy-bone-transforms) :uint32
  (effect :uint64) (requested-count :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_skinned_effect_create(CNA_Handle graphics_device, CNA_EffectHandle* out_effect)
(defcfun ("cna_skinned_effect_create" %skinned-effect-create) :uint32
  (graphics-device :uint64) (out-effect :pointer))

;;; CNA_Result cna_skinned_effect_get_alpha(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_skinned_effect_get_alpha" %skinned-effect-get-alpha) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_get_diffuse_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_skinned_effect_get_diffuse_color" %skinned-effect-get-diffuse-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_get_emissive_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_skinned_effect_get_emissive_color" %skinned-effect-get-emissive-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_get_prefer_per_pixel_lighting(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_skinned_effect_get_prefer_per_pixel_lighting" %skinned-effect-get-prefer-per-pixel-lighting) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_get_specular_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_skinned_effect_get_specular_color" %skinned-effect-get-specular-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_get_specular_power(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_skinned_effect_get_specular_power" %skinned-effect-get-specular-power) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_get_texture(CNA_EffectHandle effect, CNA_Bool* out_has_texture, CNA_Handle* out_texture)
(defcfun ("cna_skinned_effect_get_texture" %skinned-effect-get-texture) :uint32
  (effect :uint64) (out-has-texture :pointer) (out-texture :pointer))

;;; CNA_Result cna_skinned_effect_get_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool* out_value)
(defcfun ("cna_skinned_effect_get_vertex_color_enabled" %skinned-effect-get-vertex-color-enabled) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_get_weights_per_vertex(CNA_EffectHandle effect, int32_t* out_value)
(defcfun ("cna_skinned_effect_get_weights_per_vertex" %skinned-effect-get-weights-per-vertex) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_skinned_effect_set_alpha(CNA_EffectHandle effect, float value)
(defcfun ("cna_skinned_effect_set_alpha" %skinned-effect-set-alpha) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_skinned_effect_set_bone_transforms(CNA_EffectHandle effect, const CNA_Matrix* transforms, uint64_t transform_count)
(defcfun ("cna_skinned_effect_set_bone_transforms" %skinned-effect-set-bone-transforms) :uint32
  (effect :uint64) (transforms :pointer) (transform-count :uint64))

;;; CNA_Result cna_skinned_effect_set_diffuse_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_skinned_effect_set_diffuse_color" %skinned-effect-set-diffuse-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_skinned_effect_set_emissive_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_skinned_effect_set_emissive_color" %skinned-effect-set-emissive-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_skinned_effect_set_prefer_per_pixel_lighting(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_skinned_effect_set_prefer_per_pixel_lighting" %skinned-effect-set-prefer-per-pixel-lighting) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_skinned_effect_set_specular_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_skinned_effect_set_specular_color" %skinned-effect-set-specular-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_skinned_effect_set_specular_power(CNA_EffectHandle effect, float value)
(defcfun ("cna_skinned_effect_set_specular_power" %skinned-effect-set-specular-power) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_skinned_effect_set_texture(CNA_EffectHandle effect, CNA_Handle texture)
(defcfun ("cna_skinned_effect_set_texture" %skinned-effect-set-texture) :uint32
  (effect :uint64) (texture :uint64))

;;; CNA_Result cna_skinned_effect_set_vertex_color_enabled(CNA_EffectHandle effect, CNA_Bool value)
(defcfun ("cna_skinned_effect_set_vertex_color_enabled" %skinned-effect-set-vertex-color-enabled) :uint32
  (effect :uint64) (value :uint8))

;;; CNA_Result cna_skinned_effect_set_weights_per_vertex(CNA_EffectHandle effect, int32_t value)
(defcfun ("cna_skinned_effect_set_weights_per_vertex" %skinned-effect-set-weights-per-vertex) :uint32
  (effect :uint64) (value :int32))

;;; CNA_Result cna_render_target2d_create(CNA_Handle graphics_device, const CNA_RenderTarget2DCreateInfo* create_info, CNA_Handle* out_render_target)
(defcfun ("cna_render_target2d_create" %render-target-2d-create) :uint32
  (graphics-device :uint64) (create-info :pointer) (out-render-target :pointer))

;;; CNA_Result cna_render_target_destroy(CNA_Handle render_target)
(defcfun ("cna_render_target_destroy" %render-target-destroy) :uint32
  (render-target :uint64))

;;; CNA_Result cna_render_target_get_info(CNA_Handle render_target, CNA_RenderTargetInfo* out_info)
(defcfun ("cna_render_target_get_info" %render-target-get-info) :uint32
  (render-target :uint64) (out-info :pointer))

;;; CNA_Result cna_graphics_device_set_render_target2d(CNA_Handle graphics_device, CNA_Handle render_target)
(defcfun ("cna_graphics_device_set_render_target2d" %graphics-device-set-render-target-2d) :uint32
  (graphics-device :uint64) (render-target :uint64))

;;; CNA_Result cna_render_target_subscribe_content_lost(CNA_Handle render_target, CNA_RenderTargetContentLostCallback callback, void* context, CNA_RenderTargetEventRegistrationHandle* out_registration)
(defcfun ("cna_render_target_subscribe_content_lost" %render-target-subscribe-content-lost) :uint32
  (render-target :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_render_target_unsubscribe_content_lost(CNA_RenderTargetEventRegistrationHandle registration)
(defcfun ("cna_render_target_unsubscribe_content_lost" %render-target-unsubscribe-content-lost) :uint32
  (registration :uint64))

;;; CNA_Result cna_game_component_callbacks_init(CNA_GameComponentCallbacks* out_callbacks)
(defcfun ("cna_game_component_callbacks_init" %game-component-callbacks-init) :uint32
  (out-callbacks :pointer))

;;; CNA_Result cna_game_component_create(CNA_Handle game, const CNA_GameComponentCallbacks* callbacks, CNA_GameComponentHandle* out_component)
(defcfun ("cna_game_component_create" %game-component-create) :uint32
  (game :uint64) (callbacks :pointer) (out-component :pointer))

;;; CNA_Result cna_drawable_game_component_create(CNA_Handle game, const CNA_GameComponentCallbacks* callbacks, CNA_GameComponentHandle* out_component)
(defcfun ("cna_drawable_game_component_create" %drawable-game-component-create) :uint32
  (game :uint64) (callbacks :pointer) (out-component :pointer))

;;; CNA_Result cna_game_component_destroy(CNA_GameComponentHandle component)
(defcfun ("cna_game_component_destroy" %game-component-destroy) :uint32
  (component :uint64))

;;; CNA_Result cna_game_component_get_is_drawable(CNA_GameComponentHandle component, CNA_Bool* out_drawable)
(defcfun ("cna_game_component_get_is_drawable" %game-component-get-is-drawable) :uint32
  (component :uint64) (out-drawable :pointer))

;;; CNA_Result cna_game_component_get_game(CNA_GameComponentHandle component, CNA_Handle* out_game)
(defcfun ("cna_game_component_get_game" %game-component-get-game) :uint32
  (component :uint64) (out-game :pointer))

;;; CNA_Result cna_game_component_get_enabled(CNA_GameComponentHandle component, CNA_Bool* out_enabled)
(defcfun ("cna_game_component_get_enabled" %game-component-get-enabled) :uint32
  (component :uint64) (out-enabled :pointer))

;;; CNA_Result cna_game_component_set_enabled(CNA_GameComponentHandle component, CNA_Bool enabled)
(defcfun ("cna_game_component_set_enabled" %game-component-set-enabled) :uint32
  (component :uint64) (enabled :uint8))

;;; CNA_Result cna_game_component_get_update_order(CNA_GameComponentHandle component, int32_t* out_order)
(defcfun ("cna_game_component_get_update_order" %game-component-get-update-order) :uint32
  (component :uint64) (out-order :pointer))

;;; CNA_Result cna_game_component_set_update_order(CNA_GameComponentHandle component, int32_t order)
(defcfun ("cna_game_component_set_update_order" %game-component-set-update-order) :uint32
  (component :uint64) (order :int32))

;;; CNA_Result cna_drawable_game_component_get_draw_order(CNA_GameComponentHandle component, int32_t* out_order)
(defcfun ("cna_drawable_game_component_get_draw_order" %drawable-game-component-get-draw-order) :uint32
  (component :uint64) (out-order :pointer))

;;; CNA_Result cna_drawable_game_component_set_draw_order(CNA_GameComponentHandle component, int32_t order)
(defcfun ("cna_drawable_game_component_set_draw_order" %drawable-game-component-set-draw-order) :uint32
  (component :uint64) (order :int32))

;;; CNA_Result cna_drawable_game_component_get_visible(CNA_GameComponentHandle component, CNA_Bool* out_visible)
(defcfun ("cna_drawable_game_component_get_visible" %drawable-game-component-get-visible) :uint32
  (component :uint64) (out-visible :pointer))

;;; CNA_Result cna_drawable_game_component_set_visible(CNA_GameComponentHandle component, CNA_Bool visible)
(defcfun ("cna_drawable_game_component_set_visible" %drawable-game-component-set-visible) :uint32
  (component :uint64) (visible :uint8))

;;; CNA_Result cna_drawable_game_component_get_graphics_device(CNA_GameComponentHandle component, CNA_Handle* out_graphics_device)
(defcfun ("cna_drawable_game_component_get_graphics_device" %drawable-game-component-get-graphics-device) :uint32
  (component :uint64) (out-graphics-device :pointer))

;;; CNA_Result cna_game_component_initialize(CNA_GameComponentHandle component)
(defcfun ("cna_game_component_initialize" %game-component-initialize) :uint32
  (component :uint64))

;;; CNA_Result cna_game_component_update(CNA_GameComponentHandle component, const CNA_GameTime* game_time)
(defcfun ("cna_game_component_update" %game-component-update) :uint32
  (component :uint64) (game-time :pointer))

;;; CNA_Result cna_drawable_game_component_draw(CNA_GameComponentHandle component, const CNA_GameTime* game_time)
(defcfun ("cna_drawable_game_component_draw" %drawable-game-component-draw) :uint32
  (component :uint64) (game-time :pointer))

;;; CNA_Result cna_game_component_dispose(CNA_GameComponentHandle component)
(defcfun ("cna_game_component_dispose" %game-component-dispose) :uint32
  (component :uint64))

;;; CNA_Result cna_game_component_subscribe(CNA_GameComponentHandle component, CNA_GameComponentEvent event, CNA_GameComponentEventCallback callback, void* context, CNA_GameComponentEventRegistrationHandle* out_registration)
(defcfun ("cna_game_component_subscribe" %game-component-subscribe) :uint32
  (component :uint64) (event :uint32) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_game_component_unsubscribe(CNA_GameComponentEventRegistrationHandle registration)
(defcfun ("cna_game_component_unsubscribe" %game-component-unsubscribe) :uint32
  (registration :uint64))

;;; CNA_Result cna_game_components_get_count(CNA_Handle game, uint64_t* out_count)
(defcfun ("cna_game_components_get_count" %game-components-get-count) :uint32
  (game :uint64) (out-count :pointer))

;;; CNA_Result cna_game_components_get_at(CNA_Handle game, uint64_t index, CNA_GameComponentHandle* out_component)
(defcfun ("cna_game_components_get_at" %game-components-get-at) :uint32
  (game :uint64) (index :uint64) (out-component :pointer))

;;; CNA_Result cna_game_components_add(CNA_Handle game, CNA_GameComponentHandle component)
(defcfun ("cna_game_components_add" %game-components-add) :uint32
  (game :uint64) (component :uint64))

;;; CNA_Result cna_game_components_insert(CNA_Handle game, uint64_t index, CNA_GameComponentHandle component)
(defcfun ("cna_game_components_insert" %game-components-insert) :uint32
  (game :uint64) (index :uint64) (component :uint64))

;;; CNA_Result cna_game_components_remove(CNA_Handle game, CNA_GameComponentHandle component, CNA_Bool* out_removed)
(defcfun ("cna_game_components_remove" %game-components-remove) :uint32
  (game :uint64) (component :uint64) (out-removed :pointer))

;;; CNA_Result cna_game_components_remove_at(CNA_Handle game, uint64_t index)
(defcfun ("cna_game_components_remove_at" %game-components-remove-at) :uint32
  (game :uint64) (index :uint64))

;;; CNA_Result cna_game_components_clear(CNA_Handle game)
(defcfun ("cna_game_components_clear" %game-components-clear) :uint32
  (game :uint64))

;;; CNA_Result cna_game_components_contains(CNA_Handle game, CNA_GameComponentHandle component, CNA_Bool* out_contains)
(defcfun ("cna_game_components_contains" %game-components-contains) :uint32
  (game :uint64) (component :uint64) (out-contains :pointer))

;;; CNA_Result cna_game_components_index_of(CNA_Handle game, CNA_GameComponentHandle component, int32_t* out_index)
(defcfun ("cna_game_components_index_of" %game-components-index-of) :uint32
  (game :uint64) (component :uint64) (out-index :pointer))

;;; CNA_Result cna_game_components_subscribe_added(CNA_Handle game, CNA_GameComponentCollectionCallback callback, void* context, CNA_GameComponentEventRegistrationHandle* out_registration)
(defcfun ("cna_game_components_subscribe_added" %game-components-subscribe-added) :uint32
  (game :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_game_components_subscribe_removed(CNA_Handle game, CNA_GameComponentCollectionCallback callback, void* context, CNA_GameComponentEventRegistrationHandle* out_registration)
(defcfun ("cna_game_components_subscribe_removed" %game-components-subscribe-removed) :uint32
  (game :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_game_services_contains_ext(CNA_Handle game, CNA_GameServiceType service, CNA_Bool* out_present)
(defcfun ("cna_game_services_contains_ext" %game-services-contains-ext) :uint32
  (game :uint64) (service :uint32) (out-present :pointer))

;;; CNA_Result cna_game_services_remove_ext(CNA_Handle game, CNA_GameServiceType service)
(defcfun ("cna_game_services_remove_ext" %game-services-remove-ext) :uint32
  (game :uint64) (service :uint32))

;;; CNA_Result cna_texture2d_create(CNA_Handle graphics_device, const CNA_Texture2DCreateInfo* create_info, CNA_Handle* out_texture)
(defcfun ("cna_texture2d_create" %texture-2d-create) :uint32
  (graphics-device :uint64) (create-info :pointer) (out-texture :pointer))

;;; CNA_Result cna_texture2d_set_data(CNA_Handle texture, CNA_TextureDataType data_type, const CNA_Texture2DTransfer* transfer, const void* data, uint64_t data_capacity)
(defcfun ("cna_texture2d_set_data" %texture-2d-set-data) :uint32
  (texture :uint64) (data-type :uint32) (transfer :pointer) (data :pointer) (data-capacity :uint64))

;;; CNA_Result cna_texture2d_get_data(CNA_Handle texture, CNA_TextureDataType data_type, const CNA_Texture2DTransfer* transfer, void* destination, uint64_t destination_capacity, uint64_t* out_required_elements)
(defcfun ("cna_texture2d_get_data" %texture-2d-get-data) :uint32
  (texture :uint64) (data-type :uint32) (transfer :pointer) (destination :pointer) (destination-capacity :uint64) (out-required-elements :pointer))

;;; CNA_Result cna_texturecube_create(CNA_Handle graphics_device, const CNA_TextureCubeCreateInfo* create_info, CNA_Handle* out_texture)
(defcfun ("cna_texturecube_create" %texturecube-create) :uint32
  (graphics-device :uint64) (create-info :pointer) (out-texture :pointer))

;;; CNA_Result cna_texturecube_destroy(CNA_Handle texture)
(defcfun ("cna_texturecube_destroy" %texturecube-destroy) :uint32
  (texture :uint64))

;;; CNA_Result cna_texturecube_get_info(CNA_Handle texture, CNA_TextureCubeInfo* out_info)
(defcfun ("cna_texturecube_get_info" %texturecube-get-info) :uint32
  (texture :uint64) (out-info :pointer))

;;; CNA_Result cna_texturecube_set_data(CNA_Handle texture, const CNA_TextureCubeTransfer* transfer, const CNA_Color* data, uint64_t data_capacity)
(defcfun ("cna_texturecube_set_data" %texturecube-set-data) :uint32
  (texture :uint64) (transfer :pointer) (data :pointer) (data-capacity :uint64))

;;; CNA_Result cna_texturecube_get_data(CNA_Handle texture, const CNA_TextureCubeTransfer* transfer, CNA_Color* destination, uint64_t destination_capacity, uint64_t* out_required_elements)
(defcfun ("cna_texturecube_get_data" %texturecube-get-data) :uint32
  (texture :uint64) (transfer :pointer) (destination :pointer) (destination-capacity :uint64) (out-required-elements :pointer))

;;; CNA_Result cna_environment_map_effect_create(CNA_Handle graphics_device, CNA_EffectHandle* out_effect)
(defcfun ("cna_environment_map_effect_create" %environment-map-effect-create) :uint32
  (graphics-device :uint64) (out-effect :pointer))

;;; CNA_Result cna_environment_map_effect_get_alpha(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_environment_map_effect_get_alpha" %environment-map-effect-get-alpha) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_environment_map_effect_get_amount(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_environment_map_effect_get_amount" %environment-map-effect-get-amount) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_environment_map_effect_get_diffuse_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_environment_map_effect_get_diffuse_color" %environment-map-effect-get-diffuse-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_environment_map_effect_get_emissive_color(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_environment_map_effect_get_emissive_color" %environment-map-effect-get-emissive-color) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_environment_map_effect_get_environment_map(CNA_EffectHandle effect, CNA_Bool* out_has_environment_map, CNA_Handle* out_environment_map)
(defcfun ("cna_environment_map_effect_get_environment_map" %environment-map-effect-get-environment-map) :uint32
  (effect :uint64) (out-has-environment-map :pointer) (out-environment-map :pointer))

;;; CNA_Result cna_environment_map_effect_get_fresnel_factor(CNA_EffectHandle effect, float* out_value)
(defcfun ("cna_environment_map_effect_get_fresnel_factor" %environment-map-effect-get-fresnel-factor) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_environment_map_effect_get_specular(CNA_EffectHandle effect, CNA_Vector3* out_value)
(defcfun ("cna_environment_map_effect_get_specular" %environment-map-effect-get-specular) :uint32
  (effect :uint64) (out-value :pointer))

;;; CNA_Result cna_environment_map_effect_get_texture(CNA_EffectHandle effect, CNA_Bool* out_has_texture, CNA_Handle* out_texture)
(defcfun ("cna_environment_map_effect_get_texture" %environment-map-effect-get-texture) :uint32
  (effect :uint64) (out-has-texture :pointer) (out-texture :pointer))

;;; CNA_Result cna_environment_map_effect_set_alpha(CNA_EffectHandle effect, float value)
(defcfun ("cna_environment_map_effect_set_alpha" %environment-map-effect-set-alpha) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_environment_map_effect_set_amount(CNA_EffectHandle effect, float value)
(defcfun ("cna_environment_map_effect_set_amount" %environment-map-effect-set-amount) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_environment_map_effect_set_diffuse_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_environment_map_effect_set_diffuse_color" %environment-map-effect-set-diffuse-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_environment_map_effect_set_emissive_color(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_environment_map_effect_set_emissive_color" %environment-map-effect-set-emissive-color) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_environment_map_effect_set_environment_map(CNA_EffectHandle effect, CNA_Handle environment_map)
(defcfun ("cna_environment_map_effect_set_environment_map" %environment-map-effect-set-environment-map) :uint32
  (effect :uint64) (environment-map :uint64))

;;; CNA_Result cna_environment_map_effect_set_fresnel_factor(CNA_EffectHandle effect, float value)
(defcfun ("cna_environment_map_effect_set_fresnel_factor" %environment-map-effect-set-fresnel-factor) :uint32
  (effect :uint64) (value :float))

;;; CNA_Result cna_environment_map_effect_set_specular(CNA_EffectHandle effect, CNA_Vector3 value)
(defcfun ("cna_environment_map_effect_set_specular" %environment-map-effect-set-specular) :uint32
  (effect :uint64) (value-0 :double) (value-1 :float))

;;; CNA_Result cna_environment_map_effect_set_texture(CNA_EffectHandle effect, CNA_Handle texture)
(defcfun ("cna_environment_map_effect_set_texture" %environment-map-effect-set-texture) :uint32
  (effect :uint64) (texture :uint64))

;;; CNA_Result cna_content_manager_create(CNA_Handle graphics_device, const CNA_ContentManagerCreateInfo* create_info, CNA_Handle* out_content_manager)
(defcfun ("cna_content_manager_create" %content-manager-create) :uint32
  (graphics-device :uint64) (create-info :pointer) (out-content-manager :pointer))

;;; CNA_Result cna_content_manager_destroy(CNA_Handle content_manager)
(defcfun ("cna_content_manager_destroy" %content-manager-destroy) :uint32
  (content-manager :uint64))

;;; CNA_Result cna_content_manager_register_builtin_loaders(CNA_Handle content_manager)
(defcfun ("cna_content_manager_register_builtin_loaders" %content-manager-register-builtin-loaders) :uint32
  (content-manager :uint64))

;;; CNA_Result cna_game_get_content_manager_ext(CNA_Handle game, CNA_Handle* out_content_manager)
(defcfun ("cna_game_get_content_manager_ext" %game-get-content-manager-ext) :uint32
  (game :uint64) (out-content-manager :pointer))

;;; CNA_Result cna_content_manager_set_root_directory(CNA_Handle content_manager, CNA_StringView root_directory)
(defcfun ("cna_content_manager_set_root_directory" %content-manager-set-root-directory) :uint32
  (content-manager :uint64) (root-directory-0 :pointer) (root-directory-1 :uint64))

;;; CNA_Result cna_content_manager_get_root_directory_size(CNA_Handle content_manager, uint64_t* out_bytes)
(defcfun ("cna_content_manager_get_root_directory_size" %content-manager-get-root-directory-size) :uint32
  (content-manager :uint64) (out-bytes :pointer))

;;; CNA_Result cna_content_manager_copy_root_directory(CNA_Handle content_manager, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_content_manager_copy_root_directory" %content-manager-copy-root-directory) :uint32
  (content-manager :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_content_manager_get_graphics_device(CNA_Handle content_manager, CNA_Handle* out_graphics_device)
(defcfun ("cna_content_manager_get_graphics_device" %content-manager-get-graphics-device) :uint32
  (content-manager :uint64) (out-graphics-device :pointer))

;;; CNA_Result cna_content_manager_get_has_service_provider(CNA_Handle content_manager, CNA_Bool* out_has_service_provider)
(defcfun ("cna_content_manager_get_has_service_provider" %content-manager-get-has-service-provider) :uint32
  (content-manager :uint64) (out-has-service-provider :pointer))

;;; CNA_Result cna_content_manager_load_texture2d(CNA_Handle content_manager, CNA_StringView asset_name, CNA_Handle* out_texture)
(defcfun ("cna_content_manager_load_texture2d" %content-manager-load-texture-2d) :uint32
  (content-manager :uint64) (asset-name-0 :pointer) (asset-name-1 :uint64) (out-texture :pointer))

;;; CNA_Result cna_content_manager_load_texture_cube(CNA_Handle content_manager, CNA_StringView asset_name, CNA_Handle* out_texture)
(defcfun ("cna_content_manager_load_texture_cube" %content-manager-load-texture-cube) :uint32
  (content-manager :uint64) (asset-name-0 :pointer) (asset-name-1 :uint64) (out-texture :pointer))

;;; CNA_Result cna_content_manager_load_sprite_font(CNA_Handle content_manager, CNA_StringView asset_name, CNA_Handle* out_sprite_font, CNA_Handle* out_texture)
(defcfun ("cna_content_manager_load_sprite_font" %content-manager-load-sprite-font) :uint32
  (content-manager :uint64) (asset-name-0 :pointer) (asset-name-1 :uint64) (out-sprite-font :pointer) (out-texture :pointer))

;;; CNA_Result cna_content_manager_load_sound_effect(CNA_Handle content_manager, CNA_StringView asset_name, CNA_Handle* out_sound_effect)
(defcfun ("cna_content_manager_load_sound_effect" %content-manager-load-sound-effect) :uint32
  (content-manager :uint64) (asset-name-0 :pointer) (asset-name-1 :uint64) (out-sound-effect :pointer))

;;; CNA_Result cna_content_manager_load_effect(CNA_Handle content_manager, CNA_StringView asset_name, CNA_EffectHandle* out_effect)
(defcfun ("cna_content_manager_load_effect" %content-manager-load-effect) :uint32
  (content-manager :uint64) (asset-name-0 :pointer) (asset-name-1 :uint64) (out-effect :pointer))

;;; CNA_Result cna_content_manager_unload(CNA_Handle content_manager)
(defcfun ("cna_content_manager_unload" %content-manager-unload) :uint32
  (content-manager :uint64))

;;; CNA_Result cna_render_target_cube_create(CNA_Handle graphics_device, const CNA_RenderTargetCubeCreateInfo* create_info, CNA_Handle* out_render_target)
(defcfun ("cna_render_target_cube_create" %render-target-cube-create) :uint32
  (graphics-device :uint64) (create-info :pointer) (out-render-target :pointer))

;;; CNA_Result cna_graphics_device_set_render_target_cube(CNA_Handle graphics_device, CNA_Handle render_target, CNA_CubeMapFace cube_map_face)
(defcfun ("cna_graphics_device_set_render_target_cube" %graphics-device-set-render-target-cube) :uint32
  (graphics-device :uint64) (render-target :uint64) (cube-map-face :uint32))

;;; CNA_Result cna_graphics_device_set_render_targets(CNA_Handle graphics_device, const CNA_RenderTargetBinding* bindings, uint64_t binding_count)
(defcfun ("cna_graphics_device_set_render_targets" %graphics-device-set-render-targets) :uint32
  (graphics-device :uint64) (bindings :pointer) (binding-count :uint64))

;;; CNA_Result cna_graphics_device_get_render_target_count(CNA_Handle graphics_device, uint64_t* out_count)
(defcfun ("cna_graphics_device_get_render_target_count" %graphics-device-get-render-target-count) :uint32
  (graphics-device :uint64) (out-count :pointer))

;;; CNA_Result cna_graphics_device_copy_render_targets(CNA_Handle graphics_device, CNA_RenderTargetBinding* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_graphics_device_copy_render_targets" %graphics-device-copy-render-targets) :uint32
  (graphics-device :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_audio_get_capabilities(CNA_Handle game, CNA_AudioCapabilities* out_capabilities)
(defcfun ("cna_audio_get_capabilities" %audio-get-capabilities) :uint32
  (game :uint64) (out-capabilities :pointer))

;;; CNA_Result cna_sound_effect_create_pcm16_range_ext(CNA_Handle game, const CNA_SoundEffectCreateInfo* create_info, const uint8_t* pcm_bytes, uint64_t byte_count, int32_t offset, int32_t count, int32_t loop_start, int32_t loop_length, CNA_Handle* out_sound_effect)
(defcfun ("cna_sound_effect_create_pcm16_range_ext" %sound-effect-create-pcm-16-range-ext) :uint32
  (game :uint64) (create-info :pointer) (pcm-bytes :pointer) (byte-count :uint64) (offset :int32) (count :int32) (loop-start :int32) (loop-length :int32) (out-sound-effect :pointer))

;;; CNA_Result cna_sound_effect_create_from_encoded_ext(CNA_Handle game, const uint8_t* bytes, uint64_t byte_count, CNA_Handle* out_sound_effect)
(defcfun ("cna_sound_effect_create_from_encoded_ext" %sound-effect-create-from-encoded-ext) :uint32
  (game :uint64) (bytes :pointer) (byte-count :uint64) (out-sound-effect :pointer))

;;; CNA_Result cna_sound_effect_destroy(CNA_Handle sound_effect)
(defcfun ("cna_sound_effect_destroy" %sound-effect-destroy) :uint32
  (sound-effect :uint64))

;;; CNA_Result cna_sound_effect_get_is_disposed(CNA_Handle sound_effect, CNA_Bool* out_disposed)
(defcfun ("cna_sound_effect_get_is_disposed" %sound-effect-get-is-disposed) :uint32
  (sound-effect :uint64) (out-disposed :pointer))

;;; CNA_Result cna_sound_effect_get_duration_ticks(CNA_Handle sound_effect, int64_t* out_duration_ticks)
(defcfun ("cna_sound_effect_get_duration_ticks" %sound-effect-get-duration-ticks) :uint32
  (sound-effect :uint64) (out-duration-ticks :pointer))

;;; CNA_Result cna_sound_effect_get_name_size(CNA_Handle sound_effect, uint64_t* out_bytes)
(defcfun ("cna_sound_effect_get_name_size" %sound-effect-get-name-size) :uint32
  (sound-effect :uint64) (out-bytes :pointer))

;;; CNA_Result cna_sound_effect_copy_name(CNA_Handle sound_effect, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_sound_effect_copy_name" %sound-effect-copy-name) :uint32
  (sound-effect :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_sound_effect_set_name(CNA_Handle sound_effect, CNA_StringView name)
(defcfun ("cna_sound_effect_set_name" %sound-effect-set-name) :uint32
  (sound-effect :uint64) (name-0 :pointer) (name-1 :uint64))

;;; CNA_Result cna_sound_effect_play(CNA_Handle sound_effect, CNA_Bool* out_played)
(defcfun ("cna_sound_effect_play" %sound-effect-play) :uint32
  (sound-effect :uint64) (out-played :pointer))

;;; CNA_Result cna_sound_effect_play_with_settings(CNA_Handle sound_effect, float volume, float pitch, float pan, CNA_Bool* out_played)
(defcfun ("cna_sound_effect_play_with_settings" %sound-effect-play-with-settings) :uint32
  (sound-effect :uint64) (volume :float) (pitch :float) (pan :float) (out-played :pointer))

;;; CNA_Result cna_sound_effect_get_sample_duration_ticks(int32_t size_in_bytes, int32_t sample_rate, CNA_AudioChannels channels, int64_t* out_ticks)
(defcfun ("cna_sound_effect_get_sample_duration_ticks" %sound-effect-get-sample-duration-ticks) :uint32
  (size-in-bytes :int32) (sample-rate :int32) (channels :uint32) (out-ticks :pointer))

;;; CNA_Result cna_sound_effect_get_sample_size_in_bytes(int64_t duration_ticks, int32_t sample_rate, CNA_AudioChannels channels, int32_t* out_bytes)
(defcfun ("cna_sound_effect_get_sample_size_in_bytes" %sound-effect-get-sample-size-in-bytes) :uint32
  (duration-ticks :int64) (sample-rate :int32) (channels :uint32) (out-bytes :pointer))

;;; CNA_Result cna_sound_effect_get_master_volume(CNA_Handle game, float* out_volume)
(defcfun ("cna_sound_effect_get_master_volume" %sound-effect-get-master-volume) :uint32
  (game :uint64) (out-volume :pointer))

;;; CNA_Result cna_sound_effect_set_master_volume(CNA_Handle game, float volume)
(defcfun ("cna_sound_effect_set_master_volume" %sound-effect-set-master-volume) :uint32
  (game :uint64) (volume :float))

;;; CNA_Result cna_sound_effect_get_distance_scale(CNA_Handle game, float* out_scale)
(defcfun ("cna_sound_effect_get_distance_scale" %sound-effect-get-distance-scale) :uint32
  (game :uint64) (out-scale :pointer))

;;; CNA_Result cna_sound_effect_set_distance_scale(CNA_Handle game, float scale)
(defcfun ("cna_sound_effect_set_distance_scale" %sound-effect-set-distance-scale) :uint32
  (game :uint64) (scale :float))

;;; CNA_Result cna_sound_effect_get_doppler_scale(CNA_Handle game, float* out_scale)
(defcfun ("cna_sound_effect_get_doppler_scale" %sound-effect-get-doppler-scale) :uint32
  (game :uint64) (out-scale :pointer))

;;; CNA_Result cna_sound_effect_set_doppler_scale(CNA_Handle game, float scale)
(defcfun ("cna_sound_effect_set_doppler_scale" %sound-effect-set-doppler-scale) :uint32
  (game :uint64) (scale :float))

;;; CNA_Result cna_sound_effect_get_speed_of_sound(CNA_Handle game, float* out_speed)
(defcfun ("cna_sound_effect_get_speed_of_sound" %sound-effect-get-speed-of-sound) :uint32
  (game :uint64) (out-speed :pointer))

;;; CNA_Result cna_sound_effect_set_speed_of_sound(CNA_Handle game, float speed)
(defcfun ("cna_sound_effect_set_speed_of_sound" %sound-effect-set-speed-of-sound) :uint32
  (game :uint64) (speed :float))

;;; CNA_Result cna_sound_effect_create_instance(CNA_Handle sound_effect, CNA_Handle* out_instance)
(defcfun ("cna_sound_effect_create_instance" %sound-effect-create-instance) :uint32
  (sound-effect :uint64) (out-instance :pointer))

;;; CNA_Result cna_sound_effect_instance_destroy(CNA_Handle instance)
(defcfun ("cna_sound_effect_instance_destroy" %sound-effect-instance-destroy) :uint32
  (instance :uint64))

;;; CNA_Result cna_sound_effect_instance_get_is_disposed(CNA_Handle instance, CNA_Bool* out_disposed)
(defcfun ("cna_sound_effect_instance_get_is_disposed" %sound-effect-instance-get-is-disposed) :uint32
  (instance :uint64) (out-disposed :pointer))

;;; CNA_Result cna_sound_effect_instance_play(CNA_Handle instance)
(defcfun ("cna_sound_effect_instance_play" %sound-effect-instance-play) :uint32
  (instance :uint64))

;;; CNA_Result cna_sound_effect_instance_pause(CNA_Handle instance)
(defcfun ("cna_sound_effect_instance_pause" %sound-effect-instance-pause) :uint32
  (instance :uint64))

;;; CNA_Result cna_sound_effect_instance_resume(CNA_Handle instance)
(defcfun ("cna_sound_effect_instance_resume" %sound-effect-instance-resume) :uint32
  (instance :uint64))

;;; CNA_Result cna_sound_effect_instance_stop(CNA_Handle instance, CNA_Bool immediate)
(defcfun ("cna_sound_effect_instance_stop" %sound-effect-instance-stop) :uint32
  (instance :uint64) (immediate :uint8))

;;; CNA_Result cna_sound_effect_instance_get_info(CNA_Handle instance, CNA_SoundEffectInstanceInfo* out_info)
(defcfun ("cna_sound_effect_instance_get_info" %sound-effect-instance-get-info) :uint32
  (instance :uint64) (out-info :pointer))

;;; CNA_Result cna_sound_effect_instance_set_volume(CNA_Handle instance, float volume)
(defcfun ("cna_sound_effect_instance_set_volume" %sound-effect-instance-set-volume) :uint32
  (instance :uint64) (volume :float))

;;; CNA_Result cna_sound_effect_instance_set_pitch(CNA_Handle instance, float pitch)
(defcfun ("cna_sound_effect_instance_set_pitch" %sound-effect-instance-set-pitch) :uint32
  (instance :uint64) (pitch :float))

;;; CNA_Result cna_sound_effect_instance_set_pan(CNA_Handle instance, float pan)
(defcfun ("cna_sound_effect_instance_set_pan" %sound-effect-instance-set-pan) :uint32
  (instance :uint64) (pan :float))

;;; CNA_Result cna_sound_effect_instance_set_is_looped(CNA_Handle instance, CNA_Bool is_looped)
(defcfun ("cna_sound_effect_instance_set_is_looped" %sound-effect-instance-set-is-looped) :uint32
  (instance :uint64) (is-looped :uint8))

;;; CNA_Result cna_sound_effect_instance_apply_3d(CNA_Handle instance, const CNA_AudioListener* listener, const CNA_AudioEmitter* emitter)
(defcfun ("cna_sound_effect_instance_apply_3d" %sound-effect-instance-apply-3d) :uint32
  (instance :uint64) (listener :pointer) (emitter :pointer))

;;; CNA_Result cna_sound_effect_instance_apply_3d_multi_ext(CNA_Handle instance, const CNA_AudioListener* listeners, uint64_t listener_count, const CNA_AudioEmitter* emitter)
(defcfun ("cna_sound_effect_instance_apply_3d_multi_ext" %sound-effect-instance-apply-3d-multi-ext) :uint32
  (instance :uint64) (listeners :pointer) (listener-count :uint64) (emitter :pointer))

;;; CNA_Result cna_audio_listener_init(CNA_AudioListener* out_listener)
(defcfun ("cna_audio_listener_init" %audio-listener-init) :uint32
  (out-listener :pointer))

;;; CNA_Result cna_audio_emitter_init(CNA_AudioEmitter* out_emitter)
(defcfun ("cna_audio_emitter_init" %audio-emitter-init) :uint32
  (out-emitter :pointer))

;;; CNA_Result cna_dynamic_sound_effect_instance_create(CNA_Handle game, int32_t sample_rate, CNA_AudioChannels channels, CNA_Handle* out_instance)
(defcfun ("cna_dynamic_sound_effect_instance_create" %dynamic-sound-effect-instance-create) :uint32
  (game :uint64) (sample-rate :int32) (channels :uint32) (out-instance :pointer))

;;; CNA_Result cna_dynamic_sound_effect_instance_submit_buffer(CNA_Handle instance, const uint8_t* bytes, uint64_t byte_count, int32_t offset, int32_t count)
(defcfun ("cna_dynamic_sound_effect_instance_submit_buffer" %dynamic-sound-effect-instance-submit-buffer) :uint32
  (instance :uint64) (bytes :pointer) (byte-count :uint64) (offset :int32) (count :int32))

;;; CNA_Result cna_dynamic_sound_effect_instance_get_pending_buffer_count(CNA_Handle instance, int32_t* out_count)
(defcfun ("cna_dynamic_sound_effect_instance_get_pending_buffer_count" %dynamic-sound-effect-instance-get-pending-buffer-count) :uint32
  (instance :uint64) (out-count :pointer))

;;; CNA_Result cna_dynamic_sound_effect_instance_get_sample_duration_ticks(CNA_Handle instance, int32_t size_in_bytes, int64_t* out_ticks)
(defcfun ("cna_dynamic_sound_effect_instance_get_sample_duration_ticks" %dynamic-sound-effect-instance-get-sample-duration-ticks) :uint32
  (instance :uint64) (size-in-bytes :int32) (out-ticks :pointer))

;;; CNA_Result cna_dynamic_sound_effect_instance_get_sample_size_in_bytes(CNA_Handle instance, int64_t duration_ticks, int32_t* out_bytes)
(defcfun ("cna_dynamic_sound_effect_instance_get_sample_size_in_bytes" %dynamic-sound-effect-instance-get-sample-size-in-bytes) :uint32
  (instance :uint64) (duration-ticks :int64) (out-bytes :pointer))

;;; CNA_Result cna_dynamic_sound_effect_instance_subscribe_buffer_needed(CNA_Handle instance, CNA_AudioEventCallback callback, void* context, CNA_AudioEventRegistrationHandle* out_registration)
(defcfun ("cna_dynamic_sound_effect_instance_subscribe_buffer_needed" %dynamic-sound-effect-instance-subscribe-buffer-needed) :uint32
  (instance :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_audio_unsubscribe_ext(CNA_AudioEventRegistrationHandle registration)
(defcfun ("cna_audio_unsubscribe_ext" %audio-unsubscribe-ext) :uint32
  (registration :uint64))

;;; CNA_Result cna_microphone_get_count(CNA_Handle game, uint64_t* out_count)
(defcfun ("cna_microphone_get_count" %microphone-get-count) :uint32
  (game :uint64) (out-count :pointer))

;;; CNA_Result cna_microphone_get_default_index_ext(CNA_Handle game, uint64_t* out_index, CNA_Bool* out_available)
(defcfun ("cna_microphone_get_default_index_ext" %microphone-get-default-index-ext) :uint32
  (game :uint64) (out-index :pointer) (out-available :pointer))

;;; CNA_Result cna_microphone_get_name_size_at(CNA_Handle game, uint64_t index, uint64_t* out_bytes)
(defcfun ("cna_microphone_get_name_size_at" %microphone-get-name-size-at) :uint32
  (game :uint64) (index :uint64) (out-bytes :pointer))

;;; CNA_Result cna_microphone_copy_name_at(CNA_Handle game, uint64_t index, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_microphone_copy_name_at" %microphone-copy-name-at) :uint32
  (game :uint64) (index :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_microphone_get_buffer_duration_ticks_at(CNA_Handle game, uint64_t index, int64_t* out_ticks)
(defcfun ("cna_microphone_get_buffer_duration_ticks_at" %microphone-get-buffer-duration-ticks-at) :uint32
  (game :uint64) (index :uint64) (out-ticks :pointer))

;;; CNA_Result cna_microphone_set_buffer_duration_ticks_at(CNA_Handle game, uint64_t index, int64_t ticks)
(defcfun ("cna_microphone_set_buffer_duration_ticks_at" %microphone-set-buffer-duration-ticks-at) :uint32
  (game :uint64) (index :uint64) (ticks :int64))

;;; CNA_Result cna_microphone_get_is_headset_at(CNA_Handle game, uint64_t index, CNA_Bool* out_headset)
(defcfun ("cna_microphone_get_is_headset_at" %microphone-get-is-headset-at) :uint32
  (game :uint64) (index :uint64) (out-headset :pointer))

;;; CNA_Result cna_microphone_get_sample_rate_at(CNA_Handle game, uint64_t index, int32_t* out_sample_rate)
(defcfun ("cna_microphone_get_sample_rate_at" %microphone-get-sample-rate-at) :uint32
  (game :uint64) (index :uint64) (out-sample-rate :pointer))

;;; CNA_Result cna_microphone_get_state_at(CNA_Handle game, uint64_t index, CNA_MicrophoneState* out_state)
(defcfun ("cna_microphone_get_state_at" %microphone-get-state-at) :uint32
  (game :uint64) (index :uint64) (out-state :pointer))

;;; CNA_Result cna_microphone_start_at(CNA_Handle game, uint64_t index)
(defcfun ("cna_microphone_start_at" %microphone-start-at) :uint32
  (game :uint64) (index :uint64))

;;; CNA_Result cna_microphone_stop_at(CNA_Handle game, uint64_t index)
(defcfun ("cna_microphone_stop_at" %microphone-stop-at) :uint32
  (game :uint64) (index :uint64))

;;; CNA_Result cna_microphone_get_data_at(CNA_Handle game, uint64_t index, uint8_t* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_microphone_get_data_at" %microphone-get-data-at) :uint32
  (game :uint64) (index :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_microphone_get_sample_duration_ticks_at(CNA_Handle game, uint64_t index, int32_t size_in_bytes, int64_t* out_ticks)
(defcfun ("cna_microphone_get_sample_duration_ticks_at" %microphone-get-sample-duration-ticks-at) :uint32
  (game :uint64) (index :uint64) (size-in-bytes :int32) (out-ticks :pointer))

;;; CNA_Result cna_microphone_get_sample_size_in_bytes_at(CNA_Handle game, uint64_t index, int64_t duration_ticks, int32_t* out_bytes)
(defcfun ("cna_microphone_get_sample_size_in_bytes_at" %microphone-get-sample-size-in-bytes-at) :uint32
  (game :uint64) (index :uint64) (duration-ticks :int64) (out-bytes :pointer))

;;; CNA_Result cna_microphone_subscribe_buffer_ready_at(CNA_Handle game, uint64_t index, CNA_AudioEventCallback callback, void* context, CNA_AudioEventRegistrationHandle* out_registration)
(defcfun ("cna_microphone_subscribe_buffer_ready_at" %microphone-subscribe-buffer-ready-at) :uint32
  (game :uint64) (index :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_microphone_check_all_buffers_ext(CNA_Handle game)
(defcfun ("cna_microphone_check_all_buffers_ext" %microphone-check-all-buffers-ext) :uint32
  (game :uint64))

;;; CNA_Result cna_microphone_get_type_name_size(CNA_Handle game, uint64_t* out_bytes)
(defcfun ("cna_microphone_get_type_name_size" %microphone-get-type-name-size) :uint32
  (game :uint64) (out-bytes :pointer))

;;; CNA_Result cna_microphone_copy_type_name(CNA_Handle game, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_microphone_copy_type_name" %microphone-copy-type-name) :uint32
  (game :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_song_create(CNA_Handle game, CNA_StringView file_name, CNA_StringView name, CNA_SongHandle* out_song)
(defcfun ("cna_song_create" %song-create) :uint32
  (game :uint64) (file-name-0 :pointer) (file-name-1 :uint64) (name-0 :pointer) (name-1 :uint64) (out-song :pointer))

;;; CNA_Result cna_song_create_with_duration(CNA_Handle game, CNA_StringView file_name, CNA_StringView asset_name, int32_t duration_milliseconds, CNA_SongHandle* out_song)
(defcfun ("cna_song_create_with_duration" %song-create-with-duration) :uint32
  (game :uint64) (file-name-0 :pointer) (file-name-1 :uint64) (asset-name-0 :pointer) (asset-name-1 :uint64) (duration-milliseconds :int32) (out-song :pointer))

;;; CNA_Result cna_song_create_from_uri(CNA_Handle game, CNA_StringView name, CNA_StringView uri, CNA_SongHandle* out_song)
(defcfun ("cna_song_create_from_uri" %song-create-from-uri) :uint32
  (game :uint64) (name-0 :pointer) (name-1 :uint64) (uri-0 :pointer) (uri-1 :uint64) (out-song :pointer))

;;; CNA_Result cna_song_get_name_size(CNA_SongHandle song, uint64_t* out_bytes)
(defcfun ("cna_song_get_name_size" %song-get-name-size) :uint32
  (song :uint64) (out-bytes :pointer))

;;; CNA_Result cna_song_copy_name(CNA_SongHandle song, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_song_copy_name" %song-copy-name) :uint32
  (song :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_song_get_duration(CNA_SongHandle song, int64_t* out_ticks)
(defcfun ("cna_song_get_duration" %song-get-duration) :uint32
  (song :uint64) (out-ticks :pointer))

;;; CNA_Result cna_song_get_is_protected(CNA_SongHandle song, CNA_Bool* out_protected)
(defcfun ("cna_song_get_is_protected" %song-get-is-protected) :uint32
  (song :uint64) (out-protected :pointer))

;;; CNA_Result cna_song_get_is_rated(CNA_SongHandle song, CNA_Bool* out_rated)
(defcfun ("cna_song_get_is_rated" %song-get-is-rated) :uint32
  (song :uint64) (out-rated :pointer))

;;; CNA_Result cna_song_get_play_count(CNA_SongHandle song, int32_t* out_play_count)
(defcfun ("cna_song_get_play_count" %song-get-play-count) :uint32
  (song :uint64) (out-play-count :pointer))

;;; CNA_Result cna_song_get_rating(CNA_SongHandle song, int32_t* out_rating)
(defcfun ("cna_song_get_rating" %song-get-rating) :uint32
  (song :uint64) (out-rating :pointer))

;;; CNA_Result cna_song_get_track_number(CNA_SongHandle song, int32_t* out_track_number)
(defcfun ("cna_song_get_track_number" %song-get-track-number) :uint32
  (song :uint64) (out-track-number :pointer))

;;; CNA_Result cna_song_get_is_disposed(CNA_SongHandle song, CNA_Bool* out_disposed)
(defcfun ("cna_song_get_is_disposed" %song-get-is-disposed) :uint32
  (song :uint64) (out-disposed :pointer))

;;; CNA_Result cna_song_dispose(CNA_SongHandle song)
(defcfun ("cna_song_dispose" %song-dispose) :uint32
  (song :uint64))

;;; CNA_Result cna_song_destroy(CNA_SongHandle song)
(defcfun ("cna_song_destroy" %song-destroy) :uint32
  (song :uint64))

;;; CNA_Result cna_song_equals(CNA_SongHandle left, CNA_SongHandle right, CNA_Bool* out_equal)
(defcfun ("cna_song_equals" %song-equals) :uint32
  (left :uint64) (right :uint64) (out-equal :pointer))

;;; CNA_Result cna_song_get_hash_code(CNA_SongHandle song, int32_t* out_hash)
(defcfun ("cna_song_get_hash_code" %song-get-hash-code) :uint32
  (song :uint64) (out-hash :pointer))

;;; CNA_Result cna_song_get_type_name_size(CNA_SongHandle song, uint64_t* out_bytes)
(defcfun ("cna_song_get_type_name_size" %song-get-type-name-size) :uint32
  (song :uint64) (out-bytes :pointer))

;;; CNA_Result cna_song_copy_type_name(CNA_SongHandle song, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_song_copy_type_name" %song-copy-type-name) :uint32
  (song :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_song_collection_create(CNA_Handle game, const CNA_SongHandle* songs, uint64_t count, CNA_SongCollectionHandle* out_collection)
(defcfun ("cna_song_collection_create" %song-collection-create) :uint32
  (game :uint64) (songs :pointer) (count :uint64) (out-collection :pointer))

;;; CNA_Result cna_song_collection_get_at(CNA_SongCollectionHandle collection, int32_t index, CNA_SongHandle* out_song)
(defcfun ("cna_song_collection_get_at" %song-collection-get-at) :uint32
  (collection :uint64) (index :int32) (out-song :pointer))

;;; CNA_Result cna_song_collection_get_count(CNA_SongCollectionHandle collection, int32_t* out_count)
(defcfun ("cna_song_collection_get_count" %song-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_song_collection_get_is_disposed(CNA_SongCollectionHandle collection, CNA_Bool* out_disposed)
(defcfun ("cna_song_collection_get_is_disposed" %song-collection-get-is-disposed) :uint32
  (collection :uint64) (out-disposed :pointer))

;;; CNA_Result cna_song_collection_dispose(CNA_SongCollectionHandle collection)
(defcfun ("cna_song_collection_dispose" %song-collection-dispose) :uint32
  (collection :uint64))

;;; CNA_Result cna_song_collection_destroy(CNA_SongCollectionHandle collection)
(defcfun ("cna_song_collection_destroy" %song-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_song_collection_get_type_name_size(CNA_SongCollectionHandle collection, uint64_t* out_bytes)
(defcfun ("cna_song_collection_get_type_name_size" %song-collection-get-type-name-size) :uint32
  (collection :uint64) (out-bytes :pointer))

;;; CNA_Result cna_song_collection_copy_type_name(CNA_SongCollectionHandle collection, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_song_collection_copy_type_name" %song-collection-copy-type-name) :uint32
  (collection :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_visualization_data_init(CNA_VisualizationData* out_data)
(defcfun ("cna_visualization_data_init" %visualization-data-init) :uint32
  (out-data :pointer))

;;; CNA_Result cna_visualization_data_get_type_name_size(uint64_t* out_bytes)
(defcfun ("cna_visualization_data_get_type_name_size" %visualization-data-get-type-name-size) :uint32
  (out-bytes :pointer))

;;; CNA_Result cna_visualization_data_copy_type_name(char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_visualization_data_copy_type_name" %visualization-data-copy-type-name) :uint32
  (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_player_get_game_has_control(CNA_Handle game, CNA_Bool* out_has_control)
(defcfun ("cna_media_player_get_game_has_control" %media-player-get-game-has-control) :uint32
  (game :uint64) (out-has-control :pointer))

;;; CNA_Result cna_media_player_get_is_muted(CNA_Handle game, CNA_Bool* out_muted)
(defcfun ("cna_media_player_get_is_muted" %media-player-get-is-muted) :uint32
  (game :uint64) (out-muted :pointer))

;;; CNA_Result cna_media_player_set_is_muted(CNA_Handle game, CNA_Bool muted)
(defcfun ("cna_media_player_set_is_muted" %media-player-set-is-muted) :uint32
  (game :uint64) (muted :uint8))

;;; CNA_Result cna_media_player_get_is_repeating(CNA_Handle game, CNA_Bool* out_repeating)
(defcfun ("cna_media_player_get_is_repeating" %media-player-get-is-repeating) :uint32
  (game :uint64) (out-repeating :pointer))

;;; CNA_Result cna_media_player_set_is_repeating(CNA_Handle game, CNA_Bool repeating)
(defcfun ("cna_media_player_set_is_repeating" %media-player-set-is-repeating) :uint32
  (game :uint64) (repeating :uint8))

;;; CNA_Result cna_media_player_get_is_shuffled(CNA_Handle game, CNA_Bool* out_shuffled)
(defcfun ("cna_media_player_get_is_shuffled" %media-player-get-is-shuffled) :uint32
  (game :uint64) (out-shuffled :pointer))

;;; CNA_Result cna_media_player_set_is_shuffled(CNA_Handle game, CNA_Bool shuffled)
(defcfun ("cna_media_player_set_is_shuffled" %media-player-set-is-shuffled) :uint32
  (game :uint64) (shuffled :uint8))

;;; CNA_Result cna_media_player_get_play_position_ticks(CNA_Handle game, int64_t* out_ticks)
(defcfun ("cna_media_player_get_play_position_ticks" %media-player-get-play-position-ticks) :uint32
  (game :uint64) (out-ticks :pointer))

;;; CNA_Result cna_media_player_get_state(CNA_Handle game, CNA_MediaState* out_state)
(defcfun ("cna_media_player_get_state" %media-player-get-state) :uint32
  (game :uint64) (out-state :pointer))

;;; CNA_Result cna_media_player_get_volume(CNA_Handle game, float* out_volume)
(defcfun ("cna_media_player_get_volume" %media-player-get-volume) :uint32
  (game :uint64) (out-volume :pointer))

;;; CNA_Result cna_media_player_set_volume(CNA_Handle game, float volume)
(defcfun ("cna_media_player_set_volume" %media-player-set-volume) :uint32
  (game :uint64) (volume :float))

;;; CNA_Result cna_media_player_get_is_visualization_enabled(CNA_Handle game, CNA_Bool* out_enabled)
(defcfun ("cna_media_player_get_is_visualization_enabled" %media-player-get-is-visualization-enabled) :uint32
  (game :uint64) (out-enabled :pointer))

;;; CNA_Result cna_media_player_set_is_visualization_enabled(CNA_Handle game, CNA_Bool enabled)
(defcfun ("cna_media_player_set_is_visualization_enabled" %media-player-set-is-visualization-enabled) :uint32
  (game :uint64) (enabled :uint8))

;;; CNA_Result cna_media_player_get_visualization_data(CNA_Handle game, CNA_VisualizationData* data)
(defcfun ("cna_media_player_get_visualization_data" %media-player-get-visualization-data) :uint32
  (game :uint64) (data :pointer))

;;; CNA_Result cna_media_player_get_queue(CNA_Handle game, CNA_MediaQueueHandle* out_queue)
(defcfun ("cna_media_player_get_queue" %media-player-get-queue) :uint32
  (game :uint64) (out-queue :pointer))

;;; CNA_Result cna_media_player_play_song(CNA_Handle game, CNA_SongHandle song)
(defcfun ("cna_media_player_play_song" %media-player-play-song) :uint32
  (game :uint64) (song :uint64))

;;; CNA_Result cna_media_player_play_songs(CNA_Handle game, CNA_SongCollectionHandle songs)
(defcfun ("cna_media_player_play_songs" %media-player-play-songs) :uint32
  (game :uint64) (songs :uint64))

;;; CNA_Result cna_media_player_play_songs_from(CNA_Handle game, CNA_SongCollectionHandle songs, int32_t index)
(defcfun ("cna_media_player_play_songs_from" %media-player-play-songs-from) :uint32
  (game :uint64) (songs :uint64) (index :int32))

;;; CNA_Result cna_media_player_move_next(CNA_Handle game)
(defcfun ("cna_media_player_move_next" %media-player-move-next) :uint32
  (game :uint64))

;;; CNA_Result cna_media_player_move_previous(CNA_Handle game)
(defcfun ("cna_media_player_move_previous" %media-player-move-previous) :uint32
  (game :uint64))

;;; CNA_Result cna_media_player_pause(CNA_Handle game)
(defcfun ("cna_media_player_pause" %media-player-pause) :uint32
  (game :uint64))

;;; CNA_Result cna_media_player_resume(CNA_Handle game)
(defcfun ("cna_media_player_resume" %media-player-resume) :uint32
  (game :uint64))

;;; CNA_Result cna_media_player_stop(CNA_Handle game)
(defcfun ("cna_media_player_stop" %media-player-stop) :uint32
  (game :uint64))

;;; CNA_Result cna_media_player_subscribe_active_song_changed_ext(CNA_MediaPlayerEventCallback callback, void* context, CNA_MediaPlayerEventRegistrationHandle* out_registration)
(defcfun ("cna_media_player_subscribe_active_song_changed_ext" %media-player-subscribe-active-song-changed-ext) :uint32
  (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_media_player_subscribe_media_state_changed_ext(CNA_MediaPlayerEventCallback callback, void* context, CNA_MediaPlayerEventRegistrationHandle* out_registration)
(defcfun ("cna_media_player_subscribe_media_state_changed_ext" %media-player-subscribe-media-state-changed-ext) :uint32
  (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_media_player_unsubscribe_ext(CNA_MediaPlayerEventRegistrationHandle registration)
(defcfun ("cna_media_player_unsubscribe_ext" %media-player-unsubscribe-ext) :uint32
  (registration :uint64))

;;; CNA_Result cna_media_player_raise_active_song_changed_ext(CNA_Handle game)
(defcfun ("cna_media_player_raise_active_song_changed_ext" %media-player-raise-active-song-changed-ext) :uint32
  (game :uint64))

;;; CNA_Result cna_media_player_raise_media_state_changed_ext(CNA_Handle game)
(defcfun ("cna_media_player_raise_media_state_changed_ext" %media-player-raise-media-state-changed-ext) :uint32
  (game :uint64))

;;; CNA_Result cna_media_queue_get_count(CNA_MediaQueueHandle queue, int32_t* out_count)
(defcfun ("cna_media_queue_get_count" %media-queue-get-count) :uint32
  (queue :uint64) (out-count :pointer))

;;; CNA_Result cna_media_queue_get_active_song_index(CNA_MediaQueueHandle queue, int32_t* out_index)
(defcfun ("cna_media_queue_get_active_song_index" %media-queue-get-active-song-index) :uint32
  (queue :uint64) (out-index :pointer))

;;; CNA_Result cna_media_queue_set_active_song_index(CNA_MediaQueueHandle queue, int32_t index)
(defcfun ("cna_media_queue_set_active_song_index" %media-queue-set-active-song-index) :uint32
  (queue :uint64) (index :int32))

;;; CNA_Result cna_media_queue_get_active_song(CNA_MediaQueueHandle queue, CNA_SongHandle* out_song, CNA_Bool* out_available)
(defcfun ("cna_media_queue_get_active_song" %media-queue-get-active-song) :uint32
  (queue :uint64) (out-song :pointer) (out-available :pointer))

;;; CNA_Result cna_media_queue_get_at(CNA_MediaQueueHandle queue, int32_t index, CNA_SongHandle* out_song)
(defcfun ("cna_media_queue_get_at" %media-queue-get-at) :uint32
  (queue :uint64) (index :int32) (out-song :pointer))

;;; CNA_Result cna_media_queue_get_type_name_size(CNA_MediaQueueHandle queue, uint64_t* out_bytes)
(defcfun ("cna_media_queue_get_type_name_size" %media-queue-get-type-name-size) :uint32
  (queue :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_queue_copy_type_name(CNA_MediaQueueHandle queue, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_media_queue_copy_type_name" %media-queue-copy-type-name) :uint32
  (queue :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_set_app_name_ext(CNA_StringView app_name)
(defcfun ("cna_storage_set_app_name_ext" %storage-set-app-name-ext) :uint32
  (app-name-0 :pointer) (app-name-1 :uint64))

;;; CNA_Result cna_storage_get_root_size_ext(uint64_t* out_bytes)
(defcfun ("cna_storage_get_root_size_ext" %storage-get-root-size-ext) :uint32
  (out-bytes :pointer))

;;; CNA_Result cna_storage_copy_root_ext(char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_storage_copy_root_ext" %storage-copy-root-ext) :uint32
  (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_device_show_selector(CNA_StorageCompletionCallback callback, void* context, CNA_StorageDeviceHandle* out_device)
(defcfun ("cna_storage_device_show_selector" %storage-device-show-selector) :uint32
  (callback :pointer) (context :pointer) (out-device :pointer))

;;; CNA_Result cna_storage_device_show_selector_for_player(CNA_PlayerIndex player, CNA_StorageCompletionCallback callback, void* context, CNA_StorageDeviceHandle* out_device)
(defcfun ("cna_storage_device_show_selector_for_player" %storage-device-show-selector-for-player) :uint32
  (player :uint32) (callback :pointer) (context :pointer) (out-device :pointer))

;;; CNA_Result cna_storage_device_show_selector_with_space(int32_t size_in_bytes, int32_t directory_count, CNA_StorageCompletionCallback callback, void* context, CNA_StorageDeviceHandle* out_device)
(defcfun ("cna_storage_device_show_selector_with_space" %storage-device-show-selector-with-space) :uint32
  (size-in-bytes :int32) (directory-count :int32) (callback :pointer) (context :pointer) (out-device :pointer))

;;; CNA_Result cna_storage_device_show_selector_for_player_with_space(CNA_PlayerIndex player, int32_t size_in_bytes, int32_t directory_count, CNA_StorageCompletionCallback callback, void* context, CNA_StorageDeviceHandle* out_device)
(defcfun ("cna_storage_device_show_selector_for_player_with_space" %storage-device-show-selector-for-player-with-space) :uint32
  (player :uint32) (size-in-bytes :int32) (directory-count :int32) (callback :pointer) (context :pointer) (out-device :pointer))

;;; CNA_Result cna_storage_device_get_free_space(CNA_StorageDeviceHandle device, int64_t* out_free_space)
(defcfun ("cna_storage_device_get_free_space" %storage-device-get-free-space) :uint32
  (device :uint64) (out-free-space :pointer))

;;; CNA_Result cna_storage_device_get_is_connected(CNA_StorageDeviceHandle device, CNA_Bool* out_is_connected)
(defcfun ("cna_storage_device_get_is_connected" %storage-device-get-is-connected) :uint32
  (device :uint64) (out-is-connected :pointer))

;;; CNA_Result cna_storage_device_get_total_space(CNA_StorageDeviceHandle device, int64_t* out_total_space)
(defcfun ("cna_storage_device_get_total_space" %storage-device-get-total-space) :uint32
  (device :uint64) (out-total-space :pointer))

;;; CNA_Result cna_storage_device_delete_container(CNA_StorageDeviceHandle device, CNA_StringView title_name)
(defcfun ("cna_storage_device_delete_container" %storage-device-delete-container) :uint32
  (device :uint64) (title-name-0 :pointer) (title-name-1 :uint64))

;;; CNA_Result cna_storage_device_subscribe_device_changed(CNA_StorageCompletionCallback callback, void* context, CNA_Handle* out_registration)
(defcfun ("cna_storage_device_subscribe_device_changed" %storage-device-subscribe-device-changed) :uint32
  (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_storage_device_unsubscribe_device_changed(CNA_Handle registration)
(defcfun ("cna_storage_device_unsubscribe_device_changed" %storage-device-unsubscribe-device-changed) :uint32
  (registration :uint64))

;;; CNA_Result cna_storage_device_destroy(CNA_StorageDeviceHandle device)
(defcfun ("cna_storage_device_destroy" %storage-device-destroy) :uint32
  (device :uint64))

;;; CNA_Result cna_storage_container_open(CNA_StorageDeviceHandle device, CNA_StringView display_name, CNA_StorageCompletionCallback callback, void* context, CNA_StorageContainerHandle* out_container)
(defcfun ("cna_storage_container_open" %storage-container-open) :uint32
  (device :uint64) (display-name-0 :pointer) (display-name-1 :uint64) (callback :pointer) (context :pointer) (out-container :pointer))

;;; CNA_Result cna_storage_container_get_display_name_size(CNA_StorageContainerHandle container, uint64_t* out_bytes)
(defcfun ("cna_storage_container_get_display_name_size" %storage-container-get-display-name-size) :uint32
  (container :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_container_copy_display_name(CNA_StorageContainerHandle container, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_storage_container_copy_display_name" %storage-container-copy-display-name) :uint32
  (container :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_container_get_type_name_size(CNA_StorageContainerHandle container, uint64_t* out_bytes)
(defcfun ("cna_storage_container_get_type_name_size" %storage-container-get-type-name-size) :uint32
  (container :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_container_copy_type_name(CNA_StorageContainerHandle container, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_storage_container_copy_type_name" %storage-container-copy-type-name) :uint32
  (container :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_container_get_is_disposed(CNA_StorageContainerHandle container, CNA_Bool* out_is_disposed)
(defcfun ("cna_storage_container_get_is_disposed" %storage-container-get-is-disposed) :uint32
  (container :uint64) (out-is-disposed :pointer))

;;; CNA_Result cna_storage_container_get_storage_device(CNA_StorageContainerHandle container, CNA_StorageDeviceHandle* out_device)
(defcfun ("cna_storage_container_get_storage_device" %storage-container-get-storage-device) :uint32
  (container :uint64) (out-device :pointer))

;;; CNA_Result cna_storage_container_dispose(CNA_StorageContainerHandle container)
(defcfun ("cna_storage_container_dispose" %storage-container-dispose) :uint32
  (container :uint64))

;;; CNA_Result cna_storage_container_subscribe_disposing(CNA_StorageContainerHandle container, CNA_StorageCompletionCallback callback, void* context, CNA_Handle* out_registration)
(defcfun ("cna_storage_container_subscribe_disposing" %storage-container-subscribe-disposing) :uint32
  (container :uint64) (callback :pointer) (context :pointer) (out-registration :pointer))

;;; CNA_Result cna_storage_container_unsubscribe_disposing(CNA_Handle registration)
(defcfun ("cna_storage_container_unsubscribe_disposing" %storage-container-unsubscribe-disposing) :uint32
  (registration :uint64))

;;; CNA_Result cna_storage_container_create_directory(CNA_StorageContainerHandle container, CNA_StringView directory)
(defcfun ("cna_storage_container_create_directory" %storage-container-create-directory) :uint32
  (container :uint64) (directory-0 :pointer) (directory-1 :uint64))

;;; CNA_Result cna_storage_container_directory_exists(CNA_StorageContainerHandle container, CNA_StringView directory, CNA_Bool* out_exists)
(defcfun ("cna_storage_container_directory_exists" %storage-container-directory-exists) :uint32
  (container :uint64) (directory-0 :pointer) (directory-1 :uint64) (out-exists :pointer))

;;; CNA_Result cna_storage_container_delete_directory(CNA_StorageContainerHandle container, CNA_StringView directory)
(defcfun ("cna_storage_container_delete_directory" %storage-container-delete-directory) :uint32
  (container :uint64) (directory-0 :pointer) (directory-1 :uint64))

;;; CNA_Result cna_storage_container_file_exists(CNA_StorageContainerHandle container, CNA_StringView file, CNA_Bool* out_exists)
(defcfun ("cna_storage_container_file_exists" %storage-container-file-exists) :uint32
  (container :uint64) (file-0 :pointer) (file-1 :uint64) (out-exists :pointer))

;;; CNA_Result cna_storage_container_delete_file(CNA_StorageContainerHandle container, CNA_StringView file)
(defcfun ("cna_storage_container_delete_file" %storage-container-delete-file) :uint32
  (container :uint64) (file-0 :pointer) (file-1 :uint64))

;;; CNA_Result cna_storage_container_get_directory_name_count(CNA_StorageContainerHandle container, CNA_StringView search_pattern, uint64_t* out_count)
(defcfun ("cna_storage_container_get_directory_name_count" %storage-container-get-directory-name-count) :uint32
  (container :uint64) (search-pattern-0 :pointer) (search-pattern-1 :uint64) (out-count :pointer))

;;; CNA_Result cna_storage_container_copy_directory_name(CNA_StorageContainerHandle container, CNA_StringView search_pattern, uint64_t index, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_storage_container_copy_directory_name" %storage-container-copy-directory-name) :uint32
  (container :uint64) (search-pattern-0 :pointer) (search-pattern-1 :uint64) (index :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_container_get_file_name_count(CNA_StorageContainerHandle container, CNA_StringView search_pattern, uint64_t* out_count)
(defcfun ("cna_storage_container_get_file_name_count" %storage-container-get-file-name-count) :uint32
  (container :uint64) (search-pattern-0 :pointer) (search-pattern-1 :uint64) (out-count :pointer))

;;; CNA_Result cna_storage_container_copy_file_name(CNA_StorageContainerHandle container, CNA_StringView search_pattern, uint64_t index, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_storage_container_copy_file_name" %storage-container-copy-file-name) :uint32
  (container :uint64) (search-pattern-0 :pointer) (search-pattern-1 :uint64) (index :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_storage_container_create_file(CNA_StorageContainerHandle container, CNA_StringView file, CNA_StorageStreamHandle* out_stream)
(defcfun ("cna_storage_container_create_file" %storage-container-create-file) :uint32
  (container :uint64) (file-0 :pointer) (file-1 :uint64) (out-stream :pointer))

;;; CNA_Result cna_storage_container_open_file(CNA_StorageContainerHandle container, CNA_StringView file, CNA_FileMode file_mode, CNA_StorageStreamHandle* out_stream)
(defcfun ("cna_storage_container_open_file" %storage-container-open-file) :uint32
  (container :uint64) (file-0 :pointer) (file-1 :uint64) (file-mode :uint32) (out-stream :pointer))

;;; CNA_Result cna_storage_container_open_file_access(CNA_StorageContainerHandle container, CNA_StringView file, CNA_FileMode file_mode, CNA_FileAccess file_access, CNA_StorageStreamHandle* out_stream)
(defcfun ("cna_storage_container_open_file_access" %storage-container-open-file-access) :uint32
  (container :uint64) (file-0 :pointer) (file-1 :uint64) (file-mode :uint32) (file-access :uint32) (out-stream :pointer))

;;; CNA_Result cna_storage_container_open_file_share(CNA_StorageContainerHandle container, CNA_StringView file, CNA_FileMode file_mode, CNA_FileAccess file_access, CNA_FileShare file_share, CNA_StorageStreamHandle* out_stream)
(defcfun ("cna_storage_container_open_file_share" %storage-container-open-file-share) :uint32
  (container :uint64) (file-0 :pointer) (file-1 :uint64) (file-mode :uint32) (file-access :uint32) (file-share :uint32) (out-stream :pointer))

;;; CNA_Result cna_storage_container_destroy(CNA_StorageContainerHandle container)
(defcfun ("cna_storage_container_destroy" %storage-container-destroy) :uint32
  (container :uint64))

;;; CNA_Result cna_storage_stream_read(CNA_StorageStreamHandle stream, uint8_t* destination, uint64_t capacity, uint64_t* out_read)
(defcfun ("cna_storage_stream_read" %storage-stream-read) :uint32
  (stream :uint64) (destination :pointer) (capacity :uint64) (out-read :pointer))

;;; CNA_Result cna_storage_stream_write(CNA_StorageStreamHandle stream, const uint8_t* data, uint64_t count)
(defcfun ("cna_storage_stream_write" %storage-stream-write) :uint32
  (stream :uint64) (data :pointer) (count :uint64))

;;; CNA_Result cna_storage_stream_seek(CNA_StorageStreamHandle stream, int64_t offset, CNA_SeekOrigin origin, int64_t* out_position)
(defcfun ("cna_storage_stream_seek" %storage-stream-seek) :uint32
  (stream :uint64) (offset :int64) (origin :uint32) (out-position :pointer))

;;; CNA_Result cna_storage_stream_get_position(CNA_StorageStreamHandle stream, int64_t* out_position)
(defcfun ("cna_storage_stream_get_position" %storage-stream-get-position) :uint32
  (stream :uint64) (out-position :pointer))

;;; CNA_Result cna_storage_stream_get_length(CNA_StorageStreamHandle stream, int64_t* out_length)
(defcfun ("cna_storage_stream_get_length" %storage-stream-get-length) :uint32
  (stream :uint64) (out-length :pointer))

;;; CNA_Result cna_storage_stream_set_length(CNA_StorageStreamHandle stream, int64_t length)
(defcfun ("cna_storage_stream_set_length" %storage-stream-set-length) :uint32
  (stream :uint64) (length :int64))

;;; CNA_Result cna_storage_stream_get_can_read(CNA_StorageStreamHandle stream, CNA_Bool* out_can_read)
(defcfun ("cna_storage_stream_get_can_read" %storage-stream-get-can-read) :uint32
  (stream :uint64) (out-can-read :pointer))

;;; CNA_Result cna_storage_stream_get_can_write(CNA_StorageStreamHandle stream, CNA_Bool* out_can_write)
(defcfun ("cna_storage_stream_get_can_write" %storage-stream-get-can-write) :uint32
  (stream :uint64) (out-can-write :pointer))

;;; CNA_Result cna_storage_stream_get_can_seek(CNA_StorageStreamHandle stream, CNA_Bool* out_can_seek)
(defcfun ("cna_storage_stream_get_can_seek" %storage-stream-get-can-seek) :uint32
  (stream :uint64) (out-can-seek :pointer))

;;; CNA_Result cna_storage_stream_flush(CNA_StorageStreamHandle stream)
(defcfun ("cna_storage_stream_flush" %storage-stream-flush) :uint32
  (stream :uint64))

;;; CNA_Result cna_storage_stream_close(CNA_StorageStreamHandle stream)
(defcfun ("cna_storage_stream_close" %storage-stream-close) :uint32
  (stream :uint64))

;;; CNA_Result cna_model_bone_create_default(CNA_ModelBoneHandle* out_bone)
(defcfun ("cna_model_bone_create_default" %model-bone-create-default) :uint32
  (out-bone :pointer))

;;; CNA_Result cna_model_bone_create(int32_t index, CNA_StringView name, CNA_ModelBoneHandle* out_bone)
(defcfun ("cna_model_bone_create" %model-bone-create) :uint32
  (index :int32) (name-0 :pointer) (name-1 :uint64) (out-bone :pointer))

;;; CNA_Result cna_model_bone_destroy(CNA_ModelBoneHandle bone)
(defcfun ("cna_model_bone_destroy" %model-bone-destroy) :uint32
  (bone :uint64))

;;; CNA_Result cna_model_bone_get_name_byte_count(CNA_ModelBoneHandle bone, uint64_t* out_byte_count)
(defcfun ("cna_model_bone_get_name_byte_count" %model-bone-get-name-byte-count) :uint32
  (bone :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_model_bone_copy_name(CNA_ModelBoneHandle bone, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_model_bone_copy_name" %model-bone-copy-name) :uint32
  (bone :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_model_bone_get_index(CNA_ModelBoneHandle bone, int32_t* out_index)
(defcfun ("cna_model_bone_get_index" %model-bone-get-index) :uint32
  (bone :uint64) (out-index :pointer))

;;; CNA_Result cna_model_bone_get_transform(CNA_ModelBoneHandle bone, CNA_Matrix* out_transform)
(defcfun ("cna_model_bone_get_transform" %model-bone-get-transform) :uint32
  (bone :uint64) (out-transform :pointer))

;;; CNA_Result cna_model_bone_get_parent(CNA_ModelBoneHandle bone, CNA_Bool* out_has_parent, CNA_ModelBoneHandle* out_parent)
(defcfun ("cna_model_bone_get_parent" %model-bone-get-parent) :uint32
  (bone :uint64) (out-has-parent :pointer) (out-parent :pointer))

;;; CNA_Result cna_model_bone_get_children(CNA_ModelBoneHandle bone, CNA_ModelBoneCollectionHandle* out_children)
(defcfun ("cna_model_bone_get_children" %model-bone-get-children) :uint32
  (bone :uint64) (out-children :pointer))

;;; CNA_Result cna_model_bone_add_child(CNA_ModelBoneHandle bone, CNA_ModelBoneHandle child)
(defcfun ("cna_model_bone_add_child" %model-bone-add-child) :uint32
  (bone :uint64) (child :uint64))

;;; CNA_Result cna_model_bone_collection_create(CNA_ModelBoneCollectionHandle* out_collection)
(defcfun ("cna_model_bone_collection_create" %model-bone-collection-create) :uint32
  (out-collection :pointer))

;;; CNA_Result cna_model_bone_collection_destroy(CNA_ModelBoneCollectionHandle collection)
(defcfun ("cna_model_bone_collection_destroy" %model-bone-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_model_bone_collection_get_count(CNA_ModelBoneCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_model_bone_collection_get_count" %model-bone-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_model_bone_collection_get_at(CNA_ModelBoneCollectionHandle collection, uint64_t index, CNA_ModelBoneHandle* out_bone)
(defcfun ("cna_model_bone_collection_get_at" %model-bone-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-bone :pointer))

;;; CNA_Result cna_model_bone_collection_find(CNA_ModelBoneCollectionHandle collection, CNA_StringView name, CNA_Bool* out_found, CNA_ModelBoneHandle* out_bone)
(defcfun ("cna_model_bone_collection_find" %model-bone-collection-find) :uint32
  (collection :uint64) (name-0 :pointer) (name-1 :uint64) (out-found :pointer) (out-bone :pointer))

;;; CNA_Result cna_model_bone_collection_contains(CNA_ModelBoneCollectionHandle collection, CNA_ModelBoneHandle bone, CNA_Bool* out_contains)
(defcfun ("cna_model_bone_collection_contains" %model-bone-collection-contains) :uint32
  (collection :uint64) (bone :uint64) (out-contains :pointer))

;;; CNA_Result cna_model_mesh_part_create_default(CNA_ModelMeshPartHandle* out_part)
(defcfun ("cna_model_mesh_part_create_default" %model-mesh-part-create-default) :uint32
  (out-part :pointer))

;;; CNA_Result cna_model_mesh_part_create(CNA_VertexBufferHandle vertex_buffer, CNA_IndexBufferHandle index_buffer, int32_t num_vertices, int32_t primitive_count, int32_t start_index, int32_t vertex_offset, CNA_ModelMeshPartHandle* out_part)
(defcfun ("cna_model_mesh_part_create" %model-mesh-part-create) :uint32
  (vertex-buffer :uint64) (index-buffer :uint64) (num-vertices :int32) (primitive-count :int32) (start-index :int32) (vertex-offset :int32) (out-part :pointer))

;;; CNA_Result cna_model_mesh_part_destroy(CNA_ModelMeshPartHandle part)
(defcfun ("cna_model_mesh_part_destroy" %model-mesh-part-destroy) :uint32
  (part :uint64))

;;; CNA_Result cna_model_mesh_part_get_num_vertices(CNA_ModelMeshPartHandle part, int32_t* out_value)
(defcfun ("cna_model_mesh_part_get_num_vertices" %model-mesh-part-get-num-vertices) :uint32
  (part :uint64) (out-value :pointer))

;;; CNA_Result cna_model_mesh_part_set_num_vertices(CNA_ModelMeshPartHandle part, int32_t value)
(defcfun ("cna_model_mesh_part_set_num_vertices" %model-mesh-part-set-num-vertices) :uint32
  (part :uint64) (value :int32))

;;; CNA_Result cna_model_mesh_part_get_primitive_count(CNA_ModelMeshPartHandle part, int32_t* out_value)
(defcfun ("cna_model_mesh_part_get_primitive_count" %model-mesh-part-get-primitive-count) :uint32
  (part :uint64) (out-value :pointer))

;;; CNA_Result cna_model_mesh_part_set_primitive_count(CNA_ModelMeshPartHandle part, int32_t value)
(defcfun ("cna_model_mesh_part_set_primitive_count" %model-mesh-part-set-primitive-count) :uint32
  (part :uint64) (value :int32))

;;; CNA_Result cna_model_mesh_part_get_start_index(CNA_ModelMeshPartHandle part, int32_t* out_value)
(defcfun ("cna_model_mesh_part_get_start_index" %model-mesh-part-get-start-index) :uint32
  (part :uint64) (out-value :pointer))

;;; CNA_Result cna_model_mesh_part_set_start_index(CNA_ModelMeshPartHandle part, int32_t value)
(defcfun ("cna_model_mesh_part_set_start_index" %model-mesh-part-set-start-index) :uint32
  (part :uint64) (value :int32))

;;; CNA_Result cna_model_mesh_part_get_vertex_offset(CNA_ModelMeshPartHandle part, int32_t* out_value)
(defcfun ("cna_model_mesh_part_get_vertex_offset" %model-mesh-part-get-vertex-offset) :uint32
  (part :uint64) (out-value :pointer))

;;; CNA_Result cna_model_mesh_part_set_vertex_offset(CNA_ModelMeshPartHandle part, int32_t value)
(defcfun ("cna_model_mesh_part_set_vertex_offset" %model-mesh-part-set-vertex-offset) :uint32
  (part :uint64) (value :int32))

;;; CNA_Result cna_model_mesh_part_get_effect(CNA_ModelMeshPartHandle part, CNA_Bool* out_has_effect, CNA_EffectHandle* out_effect)
(defcfun ("cna_model_mesh_part_get_effect" %model-mesh-part-get-effect) :uint32
  (part :uint64) (out-has-effect :pointer) (out-effect :pointer))

;;; CNA_Result cna_model_mesh_part_set_effect(CNA_ModelMeshPartHandle part, CNA_EffectHandle effect)
(defcfun ("cna_model_mesh_part_set_effect" %model-mesh-part-set-effect) :uint32
  (part :uint64) (effect :uint64))

;;; CNA_Result cna_model_mesh_part_get_vertex_buffer(CNA_ModelMeshPartHandle part, CNA_Bool* out_has_buffer, CNA_VertexBufferHandle* out_buffer)
(defcfun ("cna_model_mesh_part_get_vertex_buffer" %model-mesh-part-get-vertex-buffer) :uint32
  (part :uint64) (out-has-buffer :pointer) (out-buffer :pointer))

;;; CNA_Result cna_model_mesh_part_set_vertex_buffer(CNA_ModelMeshPartHandle part, CNA_VertexBufferHandle vertex_buffer)
(defcfun ("cna_model_mesh_part_set_vertex_buffer" %model-mesh-part-set-vertex-buffer) :uint32
  (part :uint64) (vertex-buffer :uint64))

;;; CNA_Result cna_model_mesh_part_get_index_buffer(CNA_ModelMeshPartHandle part, CNA_Bool* out_has_buffer, CNA_IndexBufferHandle* out_buffer)
(defcfun ("cna_model_mesh_part_get_index_buffer" %model-mesh-part-get-index-buffer) :uint32
  (part :uint64) (out-has-buffer :pointer) (out-buffer :pointer))

;;; CNA_Result cna_model_mesh_part_set_index_buffer(CNA_ModelMeshPartHandle part, CNA_IndexBufferHandle index_buffer)
(defcfun ("cna_model_mesh_part_set_index_buffer" %model-mesh-part-set-index-buffer) :uint32
  (part :uint64) (index-buffer :uint64))

;;; CNA_Result cna_model_mesh_part_collection_create(const CNA_ModelMeshPartHandle* parts, uint64_t part_count, CNA_ModelMeshPartCollectionHandle* out_collection)
(defcfun ("cna_model_mesh_part_collection_create" %model-mesh-part-collection-create) :uint32
  (parts :pointer) (part-count :uint64) (out-collection :pointer))

;;; CNA_Result cna_model_mesh_part_collection_destroy(CNA_ModelMeshPartCollectionHandle collection)
(defcfun ("cna_model_mesh_part_collection_destroy" %model-mesh-part-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_model_mesh_part_collection_get_count(CNA_ModelMeshPartCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_model_mesh_part_collection_get_count" %model-mesh-part-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_model_mesh_part_collection_get_at(CNA_ModelMeshPartCollectionHandle collection, uint64_t index, CNA_ModelMeshPartHandle* out_part)
(defcfun ("cna_model_mesh_part_collection_get_at" %model-mesh-part-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-part :pointer))

;;; CNA_Result cna_model_mesh_create(CNA_Handle graphics_device, const CNA_ModelMeshPartHandle* parts, uint64_t part_count, CNA_ModelMeshHandle* out_mesh)
(defcfun ("cna_model_mesh_create" %model-mesh-create) :uint32
  (graphics-device :uint64) (parts :pointer) (part-count :uint64) (out-mesh :pointer))

;;; CNA_Result cna_model_mesh_create_named(CNA_Handle graphics_device, CNA_StringView name, const CNA_ModelMeshPartHandle* parts, uint64_t part_count, CNA_ModelMeshHandle* out_mesh)
(defcfun ("cna_model_mesh_create_named" %model-mesh-create-named) :uint32
  (graphics-device :uint64) (name-0 :pointer) (name-1 :uint64) (parts :pointer) (part-count :uint64) (out-mesh :pointer))

;;; CNA_Result cna_model_mesh_destroy(CNA_ModelMeshHandle mesh)
(defcfun ("cna_model_mesh_destroy" %model-mesh-destroy) :uint32
  (mesh :uint64))

;;; CNA_Result cna_model_mesh_get_bounding_sphere(CNA_ModelMeshHandle mesh, CNA_BoundingSphere* out_value)
(defcfun ("cna_model_mesh_get_bounding_sphere" %model-mesh-get-bounding-sphere) :uint32
  (mesh :uint64) (out-value :pointer))

;;; CNA_Result cna_model_mesh_get_mesh_parts(CNA_ModelMeshHandle mesh, CNA_ModelMeshPartCollectionHandle* out_parts)
(defcfun ("cna_model_mesh_get_mesh_parts" %model-mesh-get-mesh-parts) :uint32
  (mesh :uint64) (out-parts :pointer))

;;; CNA_Result cna_model_mesh_get_effects(CNA_ModelMeshHandle mesh, CNA_ModelEffectCollectionHandle* out_effects)
(defcfun ("cna_model_mesh_get_effects" %model-mesh-get-effects) :uint32
  (mesh :uint64) (out-effects :pointer))

;;; CNA_Result cna_model_mesh_get_name_byte_count(CNA_ModelMeshHandle mesh, uint64_t* out_byte_count)
(defcfun ("cna_model_mesh_get_name_byte_count" %model-mesh-get-name-byte-count) :uint32
  (mesh :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_model_mesh_copy_name(CNA_ModelMeshHandle mesh, char* destination, uint64_t capacity, uint64_t* out_byte_count)
(defcfun ("cna_model_mesh_copy_name" %model-mesh-copy-name) :uint32
  (mesh :uint64) (destination :pointer) (capacity :uint64) (out-byte-count :pointer))

;;; CNA_Result cna_model_mesh_get_parent_bone(CNA_ModelMeshHandle mesh, CNA_Bool* out_has_parent, CNA_ModelBoneHandle* out_parent)
(defcfun ("cna_model_mesh_get_parent_bone" %model-mesh-get-parent-bone) :uint32
  (mesh :uint64) (out-has-parent :pointer) (out-parent :pointer))

;;; CNA_Result cna_model_mesh_set_parent_bone(CNA_ModelMeshHandle mesh, CNA_ModelBoneHandle parent)
(defcfun ("cna_model_mesh_set_parent_bone" %model-mesh-set-parent-bone) :uint32
  (mesh :uint64) (parent :uint64))

;;; CNA_Result cna_model_mesh_collection_create(const CNA_ModelMeshHandle* meshes, uint64_t mesh_count, CNA_ModelMeshCollectionHandle* out_collection)
(defcfun ("cna_model_mesh_collection_create" %model-mesh-collection-create) :uint32
  (meshes :pointer) (mesh-count :uint64) (out-collection :pointer))

;;; CNA_Result cna_model_mesh_collection_destroy(CNA_ModelMeshCollectionHandle collection)
(defcfun ("cna_model_mesh_collection_destroy" %model-mesh-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_model_mesh_collection_get_count(CNA_ModelMeshCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_model_mesh_collection_get_count" %model-mesh-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_model_mesh_collection_get_at(CNA_ModelMeshCollectionHandle collection, uint64_t index, CNA_ModelMeshHandle* out_mesh)
(defcfun ("cna_model_mesh_collection_get_at" %model-mesh-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-mesh :pointer))

;;; CNA_Result cna_model_mesh_collection_find(CNA_ModelMeshCollectionHandle collection, CNA_StringView name, CNA_Bool* out_found, CNA_ModelMeshHandle* out_mesh)
(defcfun ("cna_model_mesh_collection_find" %model-mesh-collection-find) :uint32
  (collection :uint64) (name-0 :pointer) (name-1 :uint64) (out-found :pointer) (out-mesh :pointer))

;;; CNA_Result cna_model_mesh_collection_contains(CNA_ModelMeshCollectionHandle collection, CNA_ModelMeshHandle mesh, CNA_Bool* out_contains)
(defcfun ("cna_model_mesh_collection_contains" %model-mesh-collection-contains) :uint32
  (collection :uint64) (mesh :uint64) (out-contains :pointer))

;;; CNA_Result cna_model_effect_collection_destroy(CNA_ModelEffectCollectionHandle collection)
(defcfun ("cna_model_effect_collection_destroy" %model-effect-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_model_effect_collection_get_count(CNA_ModelEffectCollectionHandle collection, uint64_t* out_count)
(defcfun ("cna_model_effect_collection_get_count" %model-effect-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_model_effect_collection_get_at(CNA_ModelEffectCollectionHandle collection, uint64_t index, CNA_EffectHandle* out_effect)
(defcfun ("cna_model_effect_collection_get_at" %model-effect-collection-get-at) :uint32
  (collection :uint64) (index :uint64) (out-effect :pointer))

;;; CNA_Result cna_model_effect_collection_contains(CNA_ModelEffectCollectionHandle collection, CNA_EffectHandle effect, CNA_Bool* out_contains)
(defcfun ("cna_model_effect_collection_contains" %model-effect-collection-contains) :uint32
  (collection :uint64) (effect :uint64) (out-contains :pointer))

;;; CNA_Result cna_model_create_default(CNA_ModelHandle* out_model)
(defcfun ("cna_model_create_default" %model-create-default) :uint32
  (out-model :pointer))

;;; CNA_Result cna_model_create(CNA_Handle graphics_device, const CNA_ModelBoneHandle* bones, uint64_t bone_count, const CNA_ModelMeshHandle* meshes, uint64_t mesh_count, CNA_ModelHandle* out_model)
(defcfun ("cna_model_create" %model-create) :uint32
  (graphics-device :uint64) (bones :pointer) (bone-count :uint64) (meshes :pointer) (mesh-count :uint64) (out-model :pointer))

;;; CNA_Result cna_model_create_with_parents(CNA_Handle graphics_device, const CNA_ModelBoneHandle* bones, uint64_t bone_count, const CNA_ModelMeshHandle* meshes, uint64_t mesh_count, const CNA_ModelBoneHandle* mesh_parents, uint64_t mesh_parent_count, uint64_t root_bone_index, CNA_ModelHandle* out_model)
(defcfun ("cna_model_create_with_parents" %model-create-with-parents) :uint32
  (graphics-device :uint64) (bones :pointer) (bone-count :uint64) (meshes :pointer) (mesh-count :uint64) (mesh-parents :pointer) (mesh-parent-count :uint64) (root-bone-index :uint64) (out-model :pointer))

;;; CNA_Result cna_model_destroy(CNA_ModelHandle model)
(defcfun ("cna_model_destroy" %model-destroy) :uint32
  (model :uint64))

;;; CNA_Result cna_model_get_bones(CNA_ModelHandle model, CNA_ModelBoneCollectionHandle* out_bones)
(defcfun ("cna_model_get_bones" %model-get-bones) :uint32
  (model :uint64) (out-bones :pointer))

;;; CNA_Result cna_model_get_meshes(CNA_ModelHandle model, CNA_ModelMeshCollectionHandle* out_meshes)
(defcfun ("cna_model_get_meshes" %model-get-meshes) :uint32
  (model :uint64) (out-meshes :pointer))

;;; CNA_Result cna_model_get_root(CNA_ModelHandle model, CNA_Bool* out_has_root, CNA_ModelBoneHandle* out_root)
(defcfun ("cna_model_get_root" %model-get-root) :uint32
  (model :uint64) (out-has-root :pointer) (out-root :pointer))

;;; CNA_Result cna_model_get_bone_transform_count(CNA_ModelHandle model, uint64_t* out_count)
(defcfun ("cna_model_get_bone_transform_count" %model-get-bone-transform-count) :uint32
  (model :uint64) (out-count :pointer))

;;; CNA_Result cna_model_copy_absolute_bone_transforms(CNA_ModelHandle model, CNA_Matrix* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_model_copy_absolute_bone_transforms" %model-copy-absolute-bone-transforms) :uint32
  (model :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_model_copy_bone_transforms(CNA_ModelHandle model, CNA_Matrix* destination, uint64_t capacity, uint64_t* out_count)
(defcfun ("cna_model_copy_bone_transforms" %model-copy-bone-transforms) :uint32
  (model :uint64) (destination :pointer) (capacity :uint64) (out-count :pointer))

;;; CNA_Result cna_model_set_bone_transforms(CNA_ModelHandle model, const CNA_Matrix* source, uint64_t count)
(defcfun ("cna_model_set_bone_transforms" %model-set-bone-transforms) :uint32
  (model :uint64) (source :pointer) (count :uint64))

;;; CNA_Result cna_content_manager_load_model(CNA_Handle content_manager, CNA_StringView asset_name, CNA_ModelHandle* out_model)
(defcfun ("cna_content_manager_load_model" %content-manager-load-model) :uint32
  (content-manager :uint64) (asset-name-0 :pointer) (asset-name-1 :uint64) (out-model :pointer))

;;; CNA_Result cna_album_collection_copy_type_name(CNA_AlbumCollectionHandle collection, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_album_collection_copy_type_name" %album-collection-copy-type-name) :uint32
  (collection :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_collection_destroy(CNA_AlbumCollectionHandle collection)
(defcfun ("cna_album_collection_destroy" %album-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_album_collection_dispose(CNA_AlbumCollectionHandle collection)
(defcfun ("cna_album_collection_dispose" %album-collection-dispose) :uint32
  (collection :uint64))

;;; CNA_Result cna_album_collection_get_at(CNA_AlbumCollectionHandle collection, int32_t index, CNA_AlbumHandle* out_album)
(defcfun ("cna_album_collection_get_at" %album-collection-get-at) :uint32
  (collection :uint64) (index :int32) (out-album :pointer))

;;; CNA_Result cna_album_collection_get_count(CNA_AlbumCollectionHandle collection, int32_t* out_count)
(defcfun ("cna_album_collection_get_count" %album-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_album_collection_get_is_disposed(CNA_AlbumCollectionHandle collection, CNA_Bool* out_disposed)
(defcfun ("cna_album_collection_get_is_disposed" %album-collection-get-is-disposed) :uint32
  (collection :uint64) (out-disposed :pointer))

;;; CNA_Result cna_album_collection_get_type_name_size(CNA_AlbumCollectionHandle collection, uint64_t* out_bytes)
(defcfun ("cna_album_collection_get_type_name_size" %album-collection-get-type-name-size) :uint32
  (collection :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_copy_art(CNA_AlbumHandle album, uint8_t* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_album_copy_art" %album-copy-art) :uint32
  (album :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_copy_name(CNA_AlbumHandle album, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_album_copy_name" %album-copy-name) :uint32
  (album :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_copy_thumbnail(CNA_AlbumHandle album, uint8_t* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_album_copy_thumbnail" %album-copy-thumbnail) :uint32
  (album :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_copy_type_name(CNA_AlbumHandle album, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_album_copy_type_name" %album-copy-type-name) :uint32
  (album :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_destroy(CNA_AlbumHandle album)
(defcfun ("cna_album_destroy" %album-destroy) :uint32
  (album :uint64))

;;; CNA_Result cna_album_dispose(CNA_AlbumHandle album)
(defcfun ("cna_album_dispose" %album-dispose) :uint32
  (album :uint64))

;;; CNA_Result cna_album_equals(CNA_AlbumHandle left, CNA_AlbumHandle right, CNA_Bool* out_equal)
(defcfun ("cna_album_equals" %album-equals) :uint32
  (left :uint64) (right :uint64) (out-equal :pointer))

;;; CNA_Result cna_album_get_art_size(CNA_AlbumHandle album, uint64_t* out_bytes)
(defcfun ("cna_album_get_art_size" %album-get-art-size) :uint32
  (album :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_get_artist(CNA_AlbumHandle album, CNA_ArtistHandle* out_artist, CNA_Bool* out_available)
(defcfun ("cna_album_get_artist" %album-get-artist) :uint32
  (album :uint64) (out-artist :pointer) (out-available :pointer))

;;; CNA_Result cna_album_get_duration(CNA_AlbumHandle album, int64_t* out_ticks)
(defcfun ("cna_album_get_duration" %album-get-duration) :uint32
  (album :uint64) (out-ticks :pointer))

;;; CNA_Result cna_album_get_genre(CNA_AlbumHandle album, CNA_GenreHandle* out_genre, CNA_Bool* out_available)
(defcfun ("cna_album_get_genre" %album-get-genre) :uint32
  (album :uint64) (out-genre :pointer) (out-available :pointer))

;;; CNA_Result cna_album_get_has_art(CNA_AlbumHandle album, CNA_Bool* out_has_art)
(defcfun ("cna_album_get_has_art" %album-get-has-art) :uint32
  (album :uint64) (out-has-art :pointer))

;;; CNA_Result cna_album_get_hash_code(CNA_AlbumHandle album, int32_t* out_hash)
(defcfun ("cna_album_get_hash_code" %album-get-hash-code) :uint32
  (album :uint64) (out-hash :pointer))

;;; CNA_Result cna_album_get_is_disposed(CNA_AlbumHandle album, CNA_Bool* out_disposed)
(defcfun ("cna_album_get_is_disposed" %album-get-is-disposed) :uint32
  (album :uint64) (out-disposed :pointer))

;;; CNA_Result cna_album_get_name_size(CNA_AlbumHandle album, uint64_t* out_bytes)
(defcfun ("cna_album_get_name_size" %album-get-name-size) :uint32
  (album :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_get_songs(CNA_AlbumHandle album, CNA_SongCollectionHandle* out_songs)
(defcfun ("cna_album_get_songs" %album-get-songs) :uint32
  (album :uint64) (out-songs :pointer))

;;; CNA_Result cna_album_get_thumbnail_size(CNA_AlbumHandle album, uint64_t* out_bytes)
(defcfun ("cna_album_get_thumbnail_size" %album-get-thumbnail-size) :uint32
  (album :uint64) (out-bytes :pointer))

;;; CNA_Result cna_album_get_type_name_size(CNA_AlbumHandle album, uint64_t* out_bytes)
(defcfun ("cna_album_get_type_name_size" %album-get-type-name-size) :uint32
  (album :uint64) (out-bytes :pointer))

;;; CNA_Result cna_artist_collection_copy_type_name(CNA_ArtistCollectionHandle collection, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_artist_collection_copy_type_name" %artist-collection-copy-type-name) :uint32
  (collection :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_artist_collection_destroy(CNA_ArtistCollectionHandle collection)
(defcfun ("cna_artist_collection_destroy" %artist-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_artist_collection_dispose(CNA_ArtistCollectionHandle collection)
(defcfun ("cna_artist_collection_dispose" %artist-collection-dispose) :uint32
  (collection :uint64))

;;; CNA_Result cna_artist_collection_get_at(CNA_ArtistCollectionHandle collection, int32_t index, CNA_ArtistHandle* out_artist)
(defcfun ("cna_artist_collection_get_at" %artist-collection-get-at) :uint32
  (collection :uint64) (index :int32) (out-artist :pointer))

;;; CNA_Result cna_artist_collection_get_count(CNA_ArtistCollectionHandle collection, int32_t* out_count)
(defcfun ("cna_artist_collection_get_count" %artist-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_artist_collection_get_is_disposed(CNA_ArtistCollectionHandle collection, CNA_Bool* out_disposed)
(defcfun ("cna_artist_collection_get_is_disposed" %artist-collection-get-is-disposed) :uint32
  (collection :uint64) (out-disposed :pointer))

;;; CNA_Result cna_artist_collection_get_type_name_size(CNA_ArtistCollectionHandle collection, uint64_t* out_bytes)
(defcfun ("cna_artist_collection_get_type_name_size" %artist-collection-get-type-name-size) :uint32
  (collection :uint64) (out-bytes :pointer))

;;; CNA_Result cna_artist_copy_name(CNA_ArtistHandle artist, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_artist_copy_name" %artist-copy-name) :uint32
  (artist :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_artist_copy_type_name(CNA_ArtistHandle artist, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_artist_copy_type_name" %artist-copy-type-name) :uint32
  (artist :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_artist_destroy(CNA_ArtistHandle artist)
(defcfun ("cna_artist_destroy" %artist-destroy) :uint32
  (artist :uint64))

;;; CNA_Result cna_artist_dispose(CNA_ArtistHandle artist)
(defcfun ("cna_artist_dispose" %artist-dispose) :uint32
  (artist :uint64))

;;; CNA_Result cna_artist_equals(CNA_ArtistHandle left, CNA_ArtistHandle right, CNA_Bool* out_equal)
(defcfun ("cna_artist_equals" %artist-equals) :uint32
  (left :uint64) (right :uint64) (out-equal :pointer))

;;; CNA_Result cna_artist_get_albums(CNA_ArtistHandle artist, CNA_AlbumCollectionHandle* out_albums)
(defcfun ("cna_artist_get_albums" %artist-get-albums) :uint32
  (artist :uint64) (out-albums :pointer))

;;; CNA_Result cna_artist_get_hash_code(CNA_ArtistHandle artist, int32_t* out_hash)
(defcfun ("cna_artist_get_hash_code" %artist-get-hash-code) :uint32
  (artist :uint64) (out-hash :pointer))

;;; CNA_Result cna_artist_get_is_disposed(CNA_ArtistHandle artist, CNA_Bool* out_disposed)
(defcfun ("cna_artist_get_is_disposed" %artist-get-is-disposed) :uint32
  (artist :uint64) (out-disposed :pointer))

;;; CNA_Result cna_artist_get_name_size(CNA_ArtistHandle artist, uint64_t* out_bytes)
(defcfun ("cna_artist_get_name_size" %artist-get-name-size) :uint32
  (artist :uint64) (out-bytes :pointer))

;;; CNA_Result cna_artist_get_songs(CNA_ArtistHandle artist, CNA_SongCollectionHandle* out_songs)
(defcfun ("cna_artist_get_songs" %artist-get-songs) :uint32
  (artist :uint64) (out-songs :pointer))

;;; CNA_Result cna_artist_get_type_name_size(CNA_ArtistHandle artist, uint64_t* out_bytes)
(defcfun ("cna_artist_get_type_name_size" %artist-get-type-name-size) :uint32
  (artist :uint64) (out-bytes :pointer))

;;; CNA_Result cna_genre_collection_copy_type_name(CNA_GenreCollectionHandle collection, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_genre_collection_copy_type_name" %genre-collection-copy-type-name) :uint32
  (collection :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_genre_collection_destroy(CNA_GenreCollectionHandle collection)
(defcfun ("cna_genre_collection_destroy" %genre-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_genre_collection_dispose(CNA_GenreCollectionHandle collection)
(defcfun ("cna_genre_collection_dispose" %genre-collection-dispose) :uint32
  (collection :uint64))

;;; CNA_Result cna_genre_collection_get_at(CNA_GenreCollectionHandle collection, int32_t index, CNA_GenreHandle* out_genre)
(defcfun ("cna_genre_collection_get_at" %genre-collection-get-at) :uint32
  (collection :uint64) (index :int32) (out-genre :pointer))

;;; CNA_Result cna_genre_collection_get_count(CNA_GenreCollectionHandle collection, int32_t* out_count)
(defcfun ("cna_genre_collection_get_count" %genre-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_genre_collection_get_is_disposed(CNA_GenreCollectionHandle collection, CNA_Bool* out_disposed)
(defcfun ("cna_genre_collection_get_is_disposed" %genre-collection-get-is-disposed) :uint32
  (collection :uint64) (out-disposed :pointer))

;;; CNA_Result cna_genre_collection_get_type_name_size(CNA_GenreCollectionHandle collection, uint64_t* out_bytes)
(defcfun ("cna_genre_collection_get_type_name_size" %genre-collection-get-type-name-size) :uint32
  (collection :uint64) (out-bytes :pointer))

;;; CNA_Result cna_genre_copy_name(CNA_GenreHandle genre, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_genre_copy_name" %genre-copy-name) :uint32
  (genre :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_genre_copy_type_name(CNA_GenreHandle genre, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_genre_copy_type_name" %genre-copy-type-name) :uint32
  (genre :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_genre_destroy(CNA_GenreHandle genre)
(defcfun ("cna_genre_destroy" %genre-destroy) :uint32
  (genre :uint64))

;;; CNA_Result cna_genre_dispose(CNA_GenreHandle genre)
(defcfun ("cna_genre_dispose" %genre-dispose) :uint32
  (genre :uint64))

;;; CNA_Result cna_genre_equals(CNA_GenreHandle left, CNA_GenreHandle right, CNA_Bool* out_equal)
(defcfun ("cna_genre_equals" %genre-equals) :uint32
  (left :uint64) (right :uint64) (out-equal :pointer))

;;; CNA_Result cna_genre_get_albums(CNA_GenreHandle genre, CNA_AlbumCollectionHandle* out_albums)
(defcfun ("cna_genre_get_albums" %genre-get-albums) :uint32
  (genre :uint64) (out-albums :pointer))

;;; CNA_Result cna_genre_get_hash_code(CNA_GenreHandle genre, int32_t* out_hash)
(defcfun ("cna_genre_get_hash_code" %genre-get-hash-code) :uint32
  (genre :uint64) (out-hash :pointer))

;;; CNA_Result cna_genre_get_is_disposed(CNA_GenreHandle genre, CNA_Bool* out_disposed)
(defcfun ("cna_genre_get_is_disposed" %genre-get-is-disposed) :uint32
  (genre :uint64) (out-disposed :pointer))

;;; CNA_Result cna_genre_get_name_size(CNA_GenreHandle genre, uint64_t* out_bytes)
(defcfun ("cna_genre_get_name_size" %genre-get-name-size) :uint32
  (genre :uint64) (out-bytes :pointer))

;;; CNA_Result cna_genre_get_songs(CNA_GenreHandle genre, CNA_SongCollectionHandle* out_songs)
(defcfun ("cna_genre_get_songs" %genre-get-songs) :uint32
  (genre :uint64) (out-songs :pointer))

;;; CNA_Result cna_genre_get_type_name_size(CNA_GenreHandle genre, uint64_t* out_bytes)
(defcfun ("cna_genre_get_type_name_size" %genre-get-type-name-size) :uint32
  (genre :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_library_copy_media_source_name(CNA_MediaLibraryHandle library, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_media_library_copy_media_source_name" %media-library-copy-media-source-name) :uint32
  (library :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_library_copy_type_name(CNA_MediaLibraryHandle library, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_media_library_copy_type_name" %media-library-copy-type-name) :uint32
  (library :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_library_create(CNA_Handle game, CNA_MediaLibraryHandle* out_library)
(defcfun ("cna_media_library_create" %media-library-create) :uint32
  (game :uint64) (out-library :pointer))

;;; CNA_Result cna_media_library_create_from_source(CNA_Handle game, uint32_t source_index, CNA_MediaLibraryHandle* out_library)
(defcfun ("cna_media_library_create_from_source" %media-library-create-from-source) :uint32
  (game :uint64) (source-index :uint32) (out-library :pointer))

;;; CNA_Result cna_media_library_destroy(CNA_MediaLibraryHandle library)
(defcfun ("cna_media_library_destroy" %media-library-destroy) :uint32
  (library :uint64))

;;; CNA_Result cna_media_library_dispose(CNA_MediaLibraryHandle library)
(defcfun ("cna_media_library_dispose" %media-library-dispose) :uint32
  (library :uint64))

;;; CNA_Result cna_media_library_get_albums(CNA_MediaLibraryHandle library, CNA_AlbumCollectionHandle* out_albums)
(defcfun ("cna_media_library_get_albums" %media-library-get-albums) :uint32
  (library :uint64) (out-albums :pointer))

;;; CNA_Result cna_media_library_get_artists(CNA_MediaLibraryHandle library, CNA_ArtistCollectionHandle* out_artists)
(defcfun ("cna_media_library_get_artists" %media-library-get-artists) :uint32
  (library :uint64) (out-artists :pointer))

;;; CNA_Result cna_media_library_get_genres(CNA_MediaLibraryHandle library, CNA_GenreCollectionHandle* out_genres)
(defcfun ("cna_media_library_get_genres" %media-library-get-genres) :uint32
  (library :uint64) (out-genres :pointer))

;;; CNA_Result cna_media_library_get_is_disposed(CNA_MediaLibraryHandle library, CNA_Bool* out_disposed)
(defcfun ("cna_media_library_get_is_disposed" %media-library-get-is-disposed) :uint32
  (library :uint64) (out-disposed :pointer))

;;; CNA_Result cna_media_library_get_media_source_name_size(CNA_MediaLibraryHandle library, uint64_t* out_bytes)
(defcfun ("cna_media_library_get_media_source_name_size" %media-library-get-media-source-name-size) :uint32
  (library :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_library_get_media_source_type(CNA_MediaLibraryHandle library, CNA_MediaSourceType* out_type)
(defcfun ("cna_media_library_get_media_source_type" %media-library-get-media-source-type) :uint32
  (library :uint64) (out-type :pointer))

;;; CNA_Result cna_media_library_get_playlists(CNA_MediaLibraryHandle library, CNA_PlaylistCollectionHandle* out_playlists)
(defcfun ("cna_media_library_get_playlists" %media-library-get-playlists) :uint32
  (library :uint64) (out-playlists :pointer))

;;; CNA_Result cna_media_library_get_songs(CNA_MediaLibraryHandle library, CNA_SongCollectionHandle* out_songs)
(defcfun ("cna_media_library_get_songs" %media-library-get-songs) :uint32
  (library :uint64) (out-songs :pointer))

;;; CNA_Result cna_media_library_get_type_name_size(CNA_MediaLibraryHandle library, uint64_t* out_bytes)
(defcfun ("cna_media_library_get_type_name_size" %media-library-get-type-name-size) :uint32
  (library :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_source_copy_name_at(CNA_Handle game, uint32_t index, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_media_source_copy_name_at" %media-source-copy-name-at) :uint32
  (game :uint64) (index :uint32) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_source_copy_type_name_at(CNA_Handle game, uint32_t index, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_media_source_copy_type_name_at" %media-source-copy-type-name-at) :uint32
  (game :uint64) (index :uint32) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_media_source_get_available_count(CNA_Handle game, uint32_t* out_count)
(defcfun ("cna_media_source_get_available_count" %media-source-get-available-count) :uint32
  (game :uint64) (out-count :pointer))

;;; CNA_Result cna_media_source_get_name_size_at(CNA_Handle game, uint32_t index, uint64_t* out_bytes)
(defcfun ("cna_media_source_get_name_size_at" %media-source-get-name-size-at) :uint32
  (game :uint64) (index :uint32) (out-bytes :pointer))

;;; CNA_Result cna_media_source_get_type_at(CNA_Handle game, uint32_t index, CNA_MediaSourceType* out_type)
(defcfun ("cna_media_source_get_type_at" %media-source-get-type-at) :uint32
  (game :uint64) (index :uint32) (out-type :pointer))

;;; CNA_Result cna_media_source_get_type_name_size_at(CNA_Handle game, uint32_t index, uint64_t* out_bytes)
(defcfun ("cna_media_source_get_type_name_size_at" %media-source-get-type-name-size-at) :uint32
  (game :uint64) (index :uint32) (out-bytes :pointer))

;;; CNA_Result cna_playlist_collection_copy_type_name(CNA_PlaylistCollectionHandle collection, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_playlist_collection_copy_type_name" %playlist-collection-copy-type-name) :uint32
  (collection :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_playlist_collection_destroy(CNA_PlaylistCollectionHandle collection)
(defcfun ("cna_playlist_collection_destroy" %playlist-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_playlist_collection_dispose(CNA_PlaylistCollectionHandle collection)
(defcfun ("cna_playlist_collection_dispose" %playlist-collection-dispose) :uint32
  (collection :uint64))

;;; CNA_Result cna_playlist_collection_get_at(CNA_PlaylistCollectionHandle collection, int32_t index, CNA_PlaylistHandle* out_playlist)
(defcfun ("cna_playlist_collection_get_at" %playlist-collection-get-at) :uint32
  (collection :uint64) (index :int32) (out-playlist :pointer))

;;; CNA_Result cna_playlist_collection_get_count(CNA_PlaylistCollectionHandle collection, int32_t* out_count)
(defcfun ("cna_playlist_collection_get_count" %playlist-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_playlist_collection_get_is_disposed(CNA_PlaylistCollectionHandle collection, CNA_Bool* out_disposed)
(defcfun ("cna_playlist_collection_get_is_disposed" %playlist-collection-get-is-disposed) :uint32
  (collection :uint64) (out-disposed :pointer))

;;; CNA_Result cna_playlist_collection_get_type_name_size(CNA_PlaylistCollectionHandle collection, uint64_t* out_bytes)
(defcfun ("cna_playlist_collection_get_type_name_size" %playlist-collection-get-type-name-size) :uint32
  (collection :uint64) (out-bytes :pointer))

;;; CNA_Result cna_playlist_copy_name(CNA_PlaylistHandle playlist, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_playlist_copy_name" %playlist-copy-name) :uint32
  (playlist :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_playlist_copy_type_name(CNA_PlaylistHandle playlist, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_playlist_copy_type_name" %playlist-copy-type-name) :uint32
  (playlist :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_playlist_destroy(CNA_PlaylistHandle playlist)
(defcfun ("cna_playlist_destroy" %playlist-destroy) :uint32
  (playlist :uint64))

;;; CNA_Result cna_playlist_dispose(CNA_PlaylistHandle playlist)
(defcfun ("cna_playlist_dispose" %playlist-dispose) :uint32
  (playlist :uint64))

;;; CNA_Result cna_playlist_equals(CNA_PlaylistHandle left, CNA_PlaylistHandle right, CNA_Bool* out_equal)
(defcfun ("cna_playlist_equals" %playlist-equals) :uint32
  (left :uint64) (right :uint64) (out-equal :pointer))

;;; CNA_Result cna_playlist_get_duration(CNA_PlaylistHandle playlist, int64_t* out_ticks)
(defcfun ("cna_playlist_get_duration" %playlist-get-duration) :uint32
  (playlist :uint64) (out-ticks :pointer))

;;; CNA_Result cna_playlist_get_hash_code(CNA_PlaylistHandle playlist, int32_t* out_hash)
(defcfun ("cna_playlist_get_hash_code" %playlist-get-hash-code) :uint32
  (playlist :uint64) (out-hash :pointer))

;;; CNA_Result cna_playlist_get_is_disposed(CNA_PlaylistHandle playlist, CNA_Bool* out_disposed)
(defcfun ("cna_playlist_get_is_disposed" %playlist-get-is-disposed) :uint32
  (playlist :uint64) (out-disposed :pointer))

;;; CNA_Result cna_playlist_get_name_size(CNA_PlaylistHandle playlist, uint64_t* out_bytes)
(defcfun ("cna_playlist_get_name_size" %playlist-get-name-size) :uint32
  (playlist :uint64) (out-bytes :pointer))

;;; CNA_Result cna_playlist_get_songs(CNA_PlaylistHandle playlist, CNA_SongCollectionHandle* out_songs)
(defcfun ("cna_playlist_get_songs" %playlist-get-songs) :uint32
  (playlist :uint64) (out-songs :pointer))

;;; CNA_Result cna_playlist_get_type_name_size(CNA_PlaylistHandle playlist, uint64_t* out_bytes)
(defcfun ("cna_playlist_get_type_name_size" %playlist-get-type-name-size) :uint32
  (playlist :uint64) (out-bytes :pointer))

;;; CNA_Result cna_song_get_album(CNA_SongHandle song, CNA_AlbumHandle* out_album, CNA_Bool* out_available)
(defcfun ("cna_song_get_album" %song-get-album) :uint32
  (song :uint64) (out-album :pointer) (out-available :pointer))

;;; CNA_Result cna_song_get_artist(CNA_SongHandle song, CNA_ArtistHandle* out_artist, CNA_Bool* out_available)
(defcfun ("cna_song_get_artist" %song-get-artist) :uint32
  (song :uint64) (out-artist :pointer) (out-available :pointer))

;;; CNA_Result cna_song_get_genre(CNA_SongHandle song, CNA_GenreHandle* out_genre, CNA_Bool* out_available)
(defcfun ("cna_song_get_genre" %song-get-genre) :uint32
  (song :uint64) (out-genre :pointer) (out-available :pointer))

;;; CNA_Result cna_media_library_get_picture_from_token(CNA_MediaLibraryHandle library, CNA_StringView token, CNA_PictureHandle* out_picture, CNA_Bool* out_available)
(defcfun ("cna_media_library_get_picture_from_token" %media-library-get-picture-from-token) :uint32
  (library :uint64) (token-0 :pointer) (token-1 :uint64) (out-picture :pointer) (out-available :pointer))

;;; CNA_Result cna_media_library_get_pictures(CNA_MediaLibraryHandle library, CNA_PictureCollectionHandle* out_pictures)
(defcfun ("cna_media_library_get_pictures" %media-library-get-pictures) :uint32
  (library :uint64) (out-pictures :pointer))

;;; CNA_Result cna_media_library_get_root_picture_album(CNA_MediaLibraryHandle library, CNA_PictureAlbumHandle* out_album, CNA_Bool* out_available)
(defcfun ("cna_media_library_get_root_picture_album" %media-library-get-root-picture-album) :uint32
  (library :uint64) (out-album :pointer) (out-available :pointer))

;;; CNA_Result cna_media_library_get_saved_pictures(CNA_MediaLibraryHandle library, CNA_PictureCollectionHandle* out_pictures)
(defcfun ("cna_media_library_get_saved_pictures" %media-library-get-saved-pictures) :uint32
  (library :uint64) (out-pictures :pointer))

;;; CNA_Result cna_media_library_save_picture(CNA_MediaLibraryHandle library, CNA_StringView name, const uint8_t* image_data, uint64_t image_byte_count, CNA_PictureHandle* out_picture)
(defcfun ("cna_media_library_save_picture" %media-library-save-picture) :uint32
  (library :uint64) (name-0 :pointer) (name-1 :uint64) (image-data :pointer) (image-byte-count :uint64) (out-picture :pointer))

;;; CNA_Result cna_media_library_save_picture_from_stream(CNA_MediaLibraryHandle library, CNA_StringView name, CNA_Handle source, CNA_PictureHandle* out_picture)
(defcfun ("cna_media_library_save_picture_from_stream" %media-library-save-picture-from-stream) :uint32
  (library :uint64) (name-0 :pointer) (name-1 :uint64) (source :uint64) (out-picture :pointer))

;;; CNA_Result cna_picture_album_collection_copy_type_name(CNA_PictureAlbumCollectionHandle collection, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_album_collection_copy_type_name" %picture-album-collection-copy-type-name) :uint32
  (collection :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_album_collection_destroy(CNA_PictureAlbumCollectionHandle collection)
(defcfun ("cna_picture_album_collection_destroy" %picture-album-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_picture_album_collection_dispose(CNA_PictureAlbumCollectionHandle collection)
(defcfun ("cna_picture_album_collection_dispose" %picture-album-collection-dispose) :uint32
  (collection :uint64))

;;; CNA_Result cna_picture_album_collection_get_at(CNA_PictureAlbumCollectionHandle collection, int32_t index, CNA_PictureAlbumHandle* out_album)
(defcfun ("cna_picture_album_collection_get_at" %picture-album-collection-get-at) :uint32
  (collection :uint64) (index :int32) (out-album :pointer))

;;; CNA_Result cna_picture_album_collection_get_count(CNA_PictureAlbumCollectionHandle collection, int32_t* out_count)
(defcfun ("cna_picture_album_collection_get_count" %picture-album-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_picture_album_collection_get_is_disposed(CNA_PictureAlbumCollectionHandle collection, CNA_Bool* out_disposed)
(defcfun ("cna_picture_album_collection_get_is_disposed" %picture-album-collection-get-is-disposed) :uint32
  (collection :uint64) (out-disposed :pointer))

;;; CNA_Result cna_picture_album_collection_get_type_name_size(CNA_PictureAlbumCollectionHandle collection, uint64_t* out_bytes)
(defcfun ("cna_picture_album_collection_get_type_name_size" %picture-album-collection-get-type-name-size) :uint32
  (collection :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_album_copy_name(CNA_PictureAlbumHandle album, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_album_copy_name" %picture-album-copy-name) :uint32
  (album :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_album_copy_type_name(CNA_PictureAlbumHandle album, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_album_copy_type_name" %picture-album-copy-type-name) :uint32
  (album :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_album_destroy(CNA_PictureAlbumHandle album)
(defcfun ("cna_picture_album_destroy" %picture-album-destroy) :uint32
  (album :uint64))

;;; CNA_Result cna_picture_album_dispose(CNA_PictureAlbumHandle album)
(defcfun ("cna_picture_album_dispose" %picture-album-dispose) :uint32
  (album :uint64))

;;; CNA_Result cna_picture_album_equals(CNA_PictureAlbumHandle left, CNA_PictureAlbumHandle right, CNA_Bool* out_equal)
(defcfun ("cna_picture_album_equals" %picture-album-equals) :uint32
  (left :uint64) (right :uint64) (out-equal :pointer))

;;; CNA_Result cna_picture_album_get_albums(CNA_PictureAlbumHandle album, CNA_PictureAlbumCollectionHandle* out_albums)
(defcfun ("cna_picture_album_get_albums" %picture-album-get-albums) :uint32
  (album :uint64) (out-albums :pointer))

;;; CNA_Result cna_picture_album_get_hash_code(CNA_PictureAlbumHandle album, int32_t* out_hash)
(defcfun ("cna_picture_album_get_hash_code" %picture-album-get-hash-code) :uint32
  (album :uint64) (out-hash :pointer))

;;; CNA_Result cna_picture_album_get_is_disposed(CNA_PictureAlbumHandle album, CNA_Bool* out_disposed)
(defcfun ("cna_picture_album_get_is_disposed" %picture-album-get-is-disposed) :uint32
  (album :uint64) (out-disposed :pointer))

;;; CNA_Result cna_picture_album_get_name_size(CNA_PictureAlbumHandle album, uint64_t* out_bytes)
(defcfun ("cna_picture_album_get_name_size" %picture-album-get-name-size) :uint32
  (album :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_album_get_parent(CNA_PictureAlbumHandle album, CNA_PictureAlbumHandle* out_parent, CNA_Bool* out_available)
(defcfun ("cna_picture_album_get_parent" %picture-album-get-parent) :uint32
  (album :uint64) (out-parent :pointer) (out-available :pointer))

;;; CNA_Result cna_picture_album_get_pictures(CNA_PictureAlbumHandle album, CNA_PictureCollectionHandle* out_pictures)
(defcfun ("cna_picture_album_get_pictures" %picture-album-get-pictures) :uint32
  (album :uint64) (out-pictures :pointer))

;;; CNA_Result cna_picture_album_get_type_name_size(CNA_PictureAlbumHandle album, uint64_t* out_bytes)
(defcfun ("cna_picture_album_get_type_name_size" %picture-album-get-type-name-size) :uint32
  (album :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_collection_copy_type_name(CNA_PictureCollectionHandle collection, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_collection_copy_type_name" %picture-collection-copy-type-name) :uint32
  (collection :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_collection_destroy(CNA_PictureCollectionHandle collection)
(defcfun ("cna_picture_collection_destroy" %picture-collection-destroy) :uint32
  (collection :uint64))

;;; CNA_Result cna_picture_collection_dispose(CNA_PictureCollectionHandle collection)
(defcfun ("cna_picture_collection_dispose" %picture-collection-dispose) :uint32
  (collection :uint64))

;;; CNA_Result cna_picture_collection_get_at(CNA_PictureCollectionHandle collection, int32_t index, CNA_PictureHandle* out_picture)
(defcfun ("cna_picture_collection_get_at" %picture-collection-get-at) :uint32
  (collection :uint64) (index :int32) (out-picture :pointer))

;;; CNA_Result cna_picture_collection_get_count(CNA_PictureCollectionHandle collection, int32_t* out_count)
(defcfun ("cna_picture_collection_get_count" %picture-collection-get-count) :uint32
  (collection :uint64) (out-count :pointer))

;;; CNA_Result cna_picture_collection_get_is_disposed(CNA_PictureCollectionHandle collection, CNA_Bool* out_disposed)
(defcfun ("cna_picture_collection_get_is_disposed" %picture-collection-get-is-disposed) :uint32
  (collection :uint64) (out-disposed :pointer))

;;; CNA_Result cna_picture_collection_get_type_name_size(CNA_PictureCollectionHandle collection, uint64_t* out_bytes)
(defcfun ("cna_picture_collection_get_type_name_size" %picture-collection-get-type-name-size) :uint32
  (collection :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_copy_image(CNA_PictureHandle picture, uint8_t* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_copy_image" %picture-copy-image) :uint32
  (picture :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_copy_name(CNA_PictureHandle picture, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_copy_name" %picture-copy-name) :uint32
  (picture :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_copy_thumbnail(CNA_PictureHandle picture, uint8_t* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_copy_thumbnail" %picture-copy-thumbnail) :uint32
  (picture :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_copy_token_ext(CNA_PictureHandle picture, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_copy_token_ext" %picture-copy-token-ext) :uint32
  (picture :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_copy_type_name(CNA_PictureHandle picture, char* destination, uint64_t capacity, uint64_t* out_bytes)
(defcfun ("cna_picture_copy_type_name" %picture-copy-type-name) :uint32
  (picture :uint64) (destination :pointer) (capacity :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_destroy(CNA_PictureHandle picture)
(defcfun ("cna_picture_destroy" %picture-destroy) :uint32
  (picture :uint64))

;;; CNA_Result cna_picture_dispose(CNA_PictureHandle picture)
(defcfun ("cna_picture_dispose" %picture-dispose) :uint32
  (picture :uint64))

;;; CNA_Result cna_picture_equals(CNA_PictureHandle left, CNA_PictureHandle right, CNA_Bool* out_equal)
(defcfun ("cna_picture_equals" %picture-equals) :uint32
  (left :uint64) (right :uint64) (out-equal :pointer))

;;; CNA_Result cna_picture_get_album(CNA_PictureHandle picture, CNA_PictureAlbumHandle* out_album, CNA_Bool* out_available)
(defcfun ("cna_picture_get_album" %picture-get-album) :uint32
  (picture :uint64) (out-album :pointer) (out-available :pointer))

;;; CNA_Result cna_picture_get_date_unix_ticks(CNA_PictureHandle picture, int64_t* out_unix_ticks)
(defcfun ("cna_picture_get_date_unix_ticks" %picture-get-date-unix-ticks) :uint32
  (picture :uint64) (out-unix-ticks :pointer))

;;; CNA_Result cna_picture_get_hash_code(CNA_PictureHandle picture, int32_t* out_hash)
(defcfun ("cna_picture_get_hash_code" %picture-get-hash-code) :uint32
  (picture :uint64) (out-hash :pointer))

;;; CNA_Result cna_picture_get_height(CNA_PictureHandle picture, int32_t* out_height)
(defcfun ("cna_picture_get_height" %picture-get-height) :uint32
  (picture :uint64) (out-height :pointer))

;;; CNA_Result cna_picture_get_image_size(CNA_PictureHandle picture, uint64_t* out_bytes)
(defcfun ("cna_picture_get_image_size" %picture-get-image-size) :uint32
  (picture :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_get_is_disposed(CNA_PictureHandle picture, CNA_Bool* out_disposed)
(defcfun ("cna_picture_get_is_disposed" %picture-get-is-disposed) :uint32
  (picture :uint64) (out-disposed :pointer))

;;; CNA_Result cna_picture_get_name_size(CNA_PictureHandle picture, uint64_t* out_bytes)
(defcfun ("cna_picture_get_name_size" %picture-get-name-size) :uint32
  (picture :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_get_thumbnail_size(CNA_PictureHandle picture, uint64_t* out_bytes)
(defcfun ("cna_picture_get_thumbnail_size" %picture-get-thumbnail-size) :uint32
  (picture :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_get_token_size_ext(CNA_PictureHandle picture, uint64_t* out_bytes)
(defcfun ("cna_picture_get_token_size_ext" %picture-get-token-size-ext) :uint32
  (picture :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_get_type_name_size(CNA_PictureHandle picture, uint64_t* out_bytes)
(defcfun ("cna_picture_get_type_name_size" %picture-get-type-name-size) :uint32
  (picture :uint64) (out-bytes :pointer))

;;; CNA_Result cna_picture_get_width(CNA_PictureHandle picture, int32_t* out_width)
(defcfun ("cna_picture_get_width" %picture-get-width) :uint32
  (picture :uint64) (out-width :pointer))

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
    ("cna_game_window_get_title_size" %game-window-get-title-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_window_copy_title" %game-window-copy-title :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_window_get_allow_user_resizing" %game-window-get-allow-user-resizing :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_window_set_allow_user_resizing" %game-window-set-allow-user-resizing :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_game_window_get_client_bounds" %game-window-get-client-bounds :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_window_get_current_orientation" %game-window-get-current-orientation :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_window_get_screen_device_name_size" %game-window-get-screen-device-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_window_copy_screen_device_name" %game-window-copy-screen-device-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_window_begin_screen_device_change" %game-window-begin-screen-device-change :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_game_window_end_screen_device_change" %game-window-end-screen-device-change :uint32 (:uint64 :pointer :uint64 :int32 :int32) :thread :owner :ownership "none")
    ("cna_game_window_subscribe" %game-window-subscribe :uint32 (:uint64 :uint32 :pointer :pointer :pointer) :thread :owner :ownership "creates-owned:game-event-registration:child-of-game")
    ("cna_title_location_get_path_size" %title-location-get-path-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_title_location_copy_path" %title-location-copy-path :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_viewport" %graphics-device-get-viewport :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_clear_rgba" %graphics-device-clear-rgba :uint32 (:uint64 :float :float :float :float) :thread :owner :ownership "none")
    ("cna_presentation_parameters_init" %presentation-parameters-init :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_presentation_parameters_clone" %presentation-parameters-clone :uint32 (:pointer :pointer) :thread :any :ownership "none")
    ("cna_presentation_parameters_get_bounds" %presentation-parameters-get-bounds :uint32 (:pointer :pointer) :thread :any :ownership "none")
    ("cna_graphics_device_get_presentation_parameters" %graphics-device-get-presentation-parameters :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_presentation_parameters" %graphics-device-set-presentation-parameters :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_display_mode" %graphics-device-get-display-mode :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_status" %graphics-device-get-status :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_subscribe_event" %graphics-device-subscribe-event :uint32 (:uint64 :uint32 :pointer :pointer :pointer) :thread :owner :ownership "creates-owned:graphics-device-event-registration:child-of-game")
    ("cna_graphics_device_unsubscribe" %graphics-device-unsubscribe :uint32 (:uint64) :thread :owner :ownership "destroys:graphics-device-event-registration")
    ("cna_graphics_device_draw_instanced_primitives" %graphics-device-draw-instanced-primitives :uint32 (:uint64 :uint32 :int32 :int32 :int32 :int32 :int32 :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_create" %graphics-device-create :uint32 (:uint32 :uint32 :pointer :pointer) :thread :creates-affinity :ownership "creates-owned:graphics-device:rootless")
    ("cna_graphics_device_destroy" %graphics-device-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:graphics-device")
    ("cna_graphics_device_reset" %graphics-device-reset :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_reset_with_parameters" %graphics-device-reset-with-parameters :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_is_disposed" %graphics-device-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_get_count" %graphics-adapter-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_get_info" %graphics-adapter-get-info :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_copy_description" %graphics-adapter-copy-description :uint32 (:uint64 :uint32 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_copy_device_name" %graphics-adapter-copy-device-name :uint32 (:uint64 :uint32 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_get_current_display_mode" %graphics-adapter-get-current-display-mode :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_get_display_mode_count" %graphics-adapter-get-display-mode-count :uint32 (:uint64 :uint32 :uint8 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_copy_display_modes" %graphics-adapter-copy-display-modes :uint32 (:uint64 :uint32 :uint8 :uint32 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_set_device_preferences" %graphics-adapter-set-device-preferences :uint32 (:uint64 :uint32 :uint8 :uint8) :thread :owner :ownership "none")
    ("cna_graphics_adapter_is_profile_supported" %graphics-adapter-is-profile-supported :uint32 (:uint64 :uint32 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_query_render_target_format" %graphics-adapter-query-render-target-format :uint32 (:uint64 :uint32 :uint32 :uint32 :uint32 :int32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_adapter_query_backbuffer_format" %graphics-adapter-query-backbuffer-format :uint32 (:uint64 :uint32 :uint32 :uint32 :uint32 :int32 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_adapter_index" %graphics-device-get-adapter-index :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_graphics_profile" %graphics-device-get-graphics-profile :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_clear_options" %graphics-device-clear-options :uint32 (:uint64 :uint32 :uint32 :float :int32) :thread :owner :ownership "none")
    ("cna_graphics_device_present" %graphics-device-present :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_get_renderer_info" %graphics-device-get-renderer-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_copy_renderer_name" %graphics-device-copy-renderer-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_get_type_name_size" %graphics-device-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_copy_type_name" %graphics-device-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_information_init" %graphics-device-information-init :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_graphics_device_information_clone" %graphics-device-information-clone :uint32 (:pointer :pointer) :thread :any :ownership "none")
    ("cna_graphics_device_information_get_type_name_size" %graphics-device-information-get-type-name-size :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_graphics_device_information_copy_type_name" %graphics-device-information-copy-type-name :uint32 (:pointer :uint64 :pointer) :thread :any :ownership "none")
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
    ("cna_graphics_device_manager_get_graphics_profile" %graphics-device-manager-get-graphics-profile :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_graphics_profile" %graphics-device-manager-set-graphics-profile :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_prefer_multi_sampling" %graphics-device-manager-get-prefer-multi-sampling :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_prefer_multi_sampling" %graphics-device-manager-set-prefer-multi-sampling :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_preferred_back_buffer_format" %graphics-device-manager-get-preferred-back-buffer-format :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_preferred_back_buffer_format" %graphics-device-manager-set-preferred-back-buffer-format :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_preferred_depth_stencil_format" %graphics-device-manager-get-preferred-depth-stencil-format :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_preferred_depth_stencil_format" %graphics-device-manager-set-preferred-depth-stencil-format :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_supported_orientations" %graphics-device-manager-get-supported-orientations :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_supported_orientations" %graphics-device-manager-set-supported-orientations :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_synchronize_with_vertical_retrace" %graphics-device-manager-get-synchronize-with-vertical-retrace :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_set_synchronize_with_vertical_retrace" %graphics-device-manager-set-synchronize-with-vertical-retrace :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_graphics_device" %graphics-device-manager-get-graphics-device :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows-callback-scoped:graphics-device")
    ("cna_graphics_device_manager_subscribe" %graphics-device-manager-subscribe :uint32 (:uint64 :uint32 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_graphics_device_manager_create_device" %graphics-device-manager-create-device :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_begin_draw" %graphics-device-manager-begin-draw :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_end_draw" %graphics-device-manager-end-draw :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_get_type_name_size" %graphics-device-manager-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_copy_type_name" %graphics-device-manager-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_manager_subscribe_preparing_device_settings_ext" %graphics-device-manager-subscribe-preparing-device-settings-ext :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
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
    ("cna_texture2d_get_encoded_byte_count" %texture-2d-get-encoded-byte-count :uint32 (:uint64 :uint32 :uint32 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_texture2d_copy_encoded" %texture-2d-copy-encoded :uint32 (:uint64 :uint32 :uint32 :uint32 :pointer :uint64 :pointer) :thread :owner :ownership "none")
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
    ("cna_effect_get_type_name_byte_count" %effect-get-type-name-byte-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_effect_copy_type_name" %effect-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
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
    ("cna_effect_parameter_collection_add_create" %effect-parameter-collection-add-create :uint32 (:uint64 :pointer :pointer) :thread :any :ownership "owns")
    ("cna_sprite_font_create" %sprite-font-create :uint32 (:pointer :pointer) :thread :owner :ownership "creates-owned:sprite-font:child-of-game")
    ("cna_sprite_font_destroy" %sprite-font-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:sprite-font")
    ("cna_sprite_font_get_info" %sprite-font-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_font_copy_characters" %sprite-font-copy-characters :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_font_copy_glyphs" %sprite-font-copy-glyphs :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sprite_font_measure_utf8" %sprite-font-measure-utf-8 :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_create" %alpha-test-effect-create :uint32 (:uint64 :pointer) :thread :game :ownership "creates-owned:effect:child-of-game")
    ("cna_alpha_test_effect_get_alpha" %alpha-test-effect-get-alpha :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_get_alpha_function" %alpha-test-effect-get-alpha-function :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_get_diffuse_color" %alpha-test-effect-get-diffuse-color :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_get_reference_alpha" %alpha-test-effect-get-reference-alpha :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_get_texture" %alpha-test-effect-get-texture :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_get_vertex_color_enabled" %alpha-test-effect-get-vertex-color-enabled :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_set_alpha" %alpha-test-effect-set-alpha :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_set_alpha_function" %alpha-test-effect-set-alpha-function :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_set_diffuse_color" %alpha-test-effect-set-diffuse-color :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_set_reference_alpha" %alpha-test-effect-set-reference-alpha :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_set_texture" %alpha-test-effect-set-texture :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_alpha_test_effect_set_vertex_color_enabled" %alpha-test-effect-set-vertex-color-enabled :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_create" %dual-texture-effect-create :uint32 (:uint64 :pointer) :thread :game :ownership "creates-owned:effect:child-of-game")
    ("cna_dual_texture_effect_get_alpha" %dual-texture-effect-get-alpha :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_get_diffuse_color" %dual-texture-effect-get-diffuse-color :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_get_texture" %dual-texture-effect-get-texture :uint32 (:uint64 :uint32 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_get_vertex_color_enabled" %dual-texture-effect-get-vertex-color-enabled :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_set_alpha" %dual-texture-effect-set-alpha :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_set_diffuse_color" %dual-texture-effect-set-diffuse-color :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_set_texture" %dual-texture-effect-set-texture :uint32 (:uint64 :uint32 :uint64) :thread :owner :ownership "none")
    ("cna_dual_texture_effect_set_vertex_color_enabled" %dual-texture-effect-set-vertex-color-enabled :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_skinned_effect_copy_bone_transforms" %skinned-effect-copy-bone-transforms :uint32 (:uint64 :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_create" %skinned-effect-create :uint32 (:uint64 :pointer) :thread :game :ownership "creates-owned:effect:child-of-game")
    ("cna_skinned_effect_get_alpha" %skinned-effect-get-alpha :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_diffuse_color" %skinned-effect-get-diffuse-color :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_emissive_color" %skinned-effect-get-emissive-color :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_prefer_per_pixel_lighting" %skinned-effect-get-prefer-per-pixel-lighting :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_specular_color" %skinned-effect-get-specular-color :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_specular_power" %skinned-effect-get-specular-power :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_texture" %skinned-effect-get-texture :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_vertex_color_enabled" %skinned-effect-get-vertex-color-enabled :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_get_weights_per_vertex" %skinned-effect-get-weights-per-vertex :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_alpha" %skinned-effect-set-alpha :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_bone_transforms" %skinned-effect-set-bone-transforms :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_diffuse_color" %skinned-effect-set-diffuse-color :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_emissive_color" %skinned-effect-set-emissive-color :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_prefer_per_pixel_lighting" %skinned-effect-set-prefer-per-pixel-lighting :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_specular_color" %skinned-effect-set-specular-color :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_specular_power" %skinned-effect-set-specular-power :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_texture" %skinned-effect-set-texture :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_vertex_color_enabled" %skinned-effect-set-vertex-color-enabled :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_skinned_effect_set_weights_per_vertex" %skinned-effect-set-weights-per-vertex :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_render_target2d_create" %render-target-2d-create :uint32 (:uint64 :pointer :pointer) :thread :game :ownership "creates-owned:render-target-2d:child-of-game")
    ("cna_render_target_destroy" %render-target-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:render-target-2d")
    ("cna_render_target_get_info" %render-target-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_graphics_device_set_render_target2d" %graphics-device-set-render-target-2d :uint32 (:uint64 :uint64) :thread :game :ownership "none")
    ("cna_render_target_subscribe_content_lost" %render-target-subscribe-content-lost :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_render_target_unsubscribe_content_lost" %render-target-unsubscribe-content-lost :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_game_component_callbacks_init" %game-component-callbacks-init :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_game_component_create" %game-component-create :uint32 (:uint64 :pointer :pointer) :thread :game :ownership "creates-owned:game-component:child-of-game")
    ("cna_drawable_game_component_create" %drawable-game-component-create :uint32 (:uint64 :pointer :pointer) :thread :game :ownership "creates-owned:game-component:child-of-game")
    ("cna_game_component_destroy" %game-component-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:game-component")
    ("cna_game_component_get_is_drawable" %game-component-get-is-drawable :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_component_get_game" %game-component-get-game :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_component_get_enabled" %game-component-get-enabled :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_component_set_enabled" %game-component-set-enabled :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_game_component_get_update_order" %game-component-get-update-order :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_component_set_update_order" %game-component-set-update-order :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_drawable_game_component_get_draw_order" %drawable-game-component-get-draw-order :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_drawable_game_component_set_draw_order" %drawable-game-component-set-draw-order :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_drawable_game_component_get_visible" %drawable-game-component-get-visible :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_drawable_game_component_set_visible" %drawable-game-component-set-visible :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_drawable_game_component_get_graphics_device" %drawable-game-component-get-graphics-device :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows-callback-scoped:graphics-device")
    ("cna_game_component_initialize" %game-component-initialize :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_component_update" %game-component-update :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_drawable_game_component_draw" %drawable-game-component-draw :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_component_dispose" %game-component-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_component_subscribe" %game-component-subscribe :uint32 (:uint64 :uint32 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_game_component_unsubscribe" %game-component-unsubscribe :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_game_components_get_count" %game-components-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_components_get_at" %game-components-get-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_components_add" %game-components-add :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_game_components_insert" %game-components-insert :uint32 (:uint64 :uint64 :uint64) :thread :owner :ownership "none")
    ("cna_game_components_remove" %game-components-remove :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_components_remove_at" %game-components-remove-at :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_game_components_clear" %game-components-clear :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_game_components_contains" %game-components-contains :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_components_index_of" %game-components-index-of :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_game_components_subscribe_added" %game-components-subscribe-added :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_game_components_subscribe_removed" %game-components-subscribe-removed :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_game_services_contains_ext" %game-services-contains-ext :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_game_services_remove_ext" %game-services-remove-ext :uint32 (:uint64 :uint32) :thread :owner :ownership "none")
    ("cna_texture2d_create" %texture-2d-create :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:texture-2d:child-of-game")
    ("cna_texture2d_set_data" %texture-2d-set-data :uint32 (:uint64 :uint32 :pointer :pointer :uint64) :thread :owner :ownership "none")
    ("cna_texture2d_get_data" %texture-2d-get-data :uint32 (:uint64 :uint32 :pointer :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texturecube_create" %texturecube-create :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:texture-cube:child-of-game")
    ("cna_texturecube_destroy" %texturecube-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:texture-cube")
    ("cna_texturecube_get_info" %texturecube-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_texturecube_set_data" %texturecube-set-data :uint32 (:uint64 :pointer :pointer :uint64) :thread :owner :ownership "none")
    ("cna_texturecube_get_data" %texturecube-get-data :uint32 (:uint64 :pointer :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_create" %environment-map-effect-create :uint32 (:uint64 :pointer) :thread :game :ownership "creates-owned:effect:child-of-game")
    ("cna_environment_map_effect_get_alpha" %environment-map-effect-get-alpha :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_get_amount" %environment-map-effect-get-amount :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_get_diffuse_color" %environment-map-effect-get-diffuse-color :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_get_emissive_color" %environment-map-effect-get-emissive-color :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_get_environment_map" %environment-map-effect-get-environment-map :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_get_fresnel_factor" %environment-map-effect-get-fresnel-factor :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_get_specular" %environment-map-effect-get-specular :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_get_texture" %environment-map-effect-get-texture :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_alpha" %environment-map-effect-set-alpha :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_amount" %environment-map-effect-set-amount :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_diffuse_color" %environment-map-effect-set-diffuse-color :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_emissive_color" %environment-map-effect-set-emissive-color :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_environment_map" %environment-map-effect-set-environment-map :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_fresnel_factor" %environment-map-effect-set-fresnel-factor :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_specular" %environment-map-effect-set-specular :uint32 (:uint64 :double :float) :thread :owner :ownership "none")
    ("cna_environment_map_effect_set_texture" %environment-map-effect-set-texture :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_content_manager_create" %content-manager-create :uint32 (:uint64 :pointer :pointer) :thread :game :ownership "creates")
    ("cna_content_manager_destroy" %content-manager-destroy :uint32 (:uint64) :thread :game :ownership "destroys")
    ("cna_content_manager_register_builtin_loaders" %content-manager-register-builtin-loaders :uint32 (:uint64) :thread :game :ownership "none")
    ("cna_game_get_content_manager_ext" %game-get-content-manager-ext :uint32 (:uint64 :pointer) :thread :game :ownership "borrows")
    ("cna_content_manager_set_root_directory" %content-manager-set-root-directory :uint32 (:uint64 :pointer :uint64) :thread :game :ownership "none")
    ("cna_content_manager_get_root_directory_size" %content-manager-get-root-directory-size :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_content_manager_copy_root_directory" %content-manager-copy-root-directory :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "none")
    ("cna_content_manager_get_graphics_device" %content-manager-get-graphics-device :uint32 (:uint64 :pointer) :thread :game :ownership "borrows")
    ("cna_content_manager_get_has_service_provider" %content-manager-get-has-service-provider :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_content_manager_load_texture2d" %content-manager-load-texture-2d :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates")
    ("cna_content_manager_load_texture_cube" %content-manager-load-texture-cube :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates")
    ("cna_content_manager_load_sprite_font" %content-manager-load-sprite-font :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :game :ownership "creates")
    ("cna_content_manager_load_sound_effect" %content-manager-load-sound-effect :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates")
    ("cna_content_manager_load_effect" %content-manager-load-effect :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates")
    ("cna_content_manager_unload" %content-manager-unload :uint32 (:uint64) :thread :game :ownership "none")
    ("cna_render_target_cube_create" %render-target-cube-create :uint32 (:uint64 :pointer :pointer) :thread :game :ownership "creates")
    ("cna_graphics_device_set_render_target_cube" %graphics-device-set-render-target-cube :uint32 (:uint64 :uint64 :uint32) :thread :game :ownership "none")
    ("cna_graphics_device_set_render_targets" %graphics-device-set-render-targets :uint32 (:uint64 :pointer :uint64) :thread :game :ownership "none")
    ("cna_graphics_device_get_render_target_count" %graphics-device-get-render-target-count :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_graphics_device_copy_render_targets" %graphics-device-copy-render-targets :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "borrows")
    ("cna_audio_get_capabilities" %audio-get-capabilities :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_sound_effect_create_pcm16_range_ext" %sound-effect-create-pcm-16-range-ext :uint32 (:uint64 :pointer :pointer :uint64 :int32 :int32 :int32 :int32 :pointer) :thread :owner :ownership "creates-owned:sound-effect:child-of-game")
    ("cna_sound_effect_create_from_encoded_ext" %sound-effect-create-from-encoded-ext :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:sound-effect:child-of-game")
    ("cna_sound_effect_destroy" %sound-effect-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:sound-effect")
    ("cna_sound_effect_get_is_disposed" %sound-effect-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_get_duration_ticks" %sound-effect-get-duration-ticks :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_get_name_size" %sound-effect-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_copy_name" %sound-effect-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_set_name" %sound-effect-set-name :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_sound_effect_play" %sound-effect-play :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_play_with_settings" %sound-effect-play-with-settings :uint32 (:uint64 :float :float :float :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_get_sample_duration_ticks" %sound-effect-get-sample-duration-ticks :uint32 (:int32 :int32 :uint32 :pointer) :thread :any :ownership "none")
    ("cna_sound_effect_get_sample_size_in_bytes" %sound-effect-get-sample-size-in-bytes :uint32 (:int64 :int32 :uint32 :pointer) :thread :any :ownership "none")
    ("cna_sound_effect_get_master_volume" %sound-effect-get-master-volume :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_sound_effect_set_master_volume" %sound-effect-set-master-volume :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_sound_effect_get_distance_scale" %sound-effect-get-distance-scale :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_sound_effect_set_distance_scale" %sound-effect-set-distance-scale :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_sound_effect_get_doppler_scale" %sound-effect-get-doppler-scale :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_sound_effect_set_doppler_scale" %sound-effect-set-doppler-scale :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_sound_effect_get_speed_of_sound" %sound-effect-get-speed-of-sound :uint32 (:uint64 :pointer) :thread :game :ownership "none")
    ("cna_sound_effect_set_speed_of_sound" %sound-effect-set-speed-of-sound :uint32 (:uint64 :float) :thread :game :ownership "none")
    ("cna_sound_effect_create_instance" %sound-effect-create-instance :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:sound-effect-instance:child-of-sound-effect")
    ("cna_sound_effect_instance_destroy" %sound-effect-instance-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:sound-effect-instance")
    ("cna_sound_effect_instance_get_is_disposed" %sound-effect-instance-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_play" %sound-effect-instance-play :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_pause" %sound-effect-instance-pause :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_resume" %sound-effect-instance-resume :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_stop" %sound-effect-instance-stop :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_get_info" %sound-effect-instance-get-info :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_set_volume" %sound-effect-instance-set-volume :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_set_pitch" %sound-effect-instance-set-pitch :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_set_pan" %sound-effect-instance-set-pan :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_set_is_looped" %sound-effect-instance-set-is-looped :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_apply_3d" %sound-effect-instance-apply-3d :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_sound_effect_instance_apply_3d_multi_ext" %sound-effect-instance-apply-3d-multi-ext :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_audio_listener_init" %audio-listener-init :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_audio_emitter_init" %audio-emitter-init :uint32 (:pointer) :thread :any :ownership "none")
    ("cna_dynamic_sound_effect_instance_create" %dynamic-sound-effect-instance-create :uint32 (:uint64 :int32 :uint32 :pointer) :thread :owner :ownership "creates-owned:sound-effect-instance:child-of-game")
    ("cna_dynamic_sound_effect_instance_submit_buffer" %dynamic-sound-effect-instance-submit-buffer :uint32 (:uint64 :pointer :uint64 :int32 :int32) :thread :owner :ownership "none")
    ("cna_dynamic_sound_effect_instance_get_pending_buffer_count" %dynamic-sound-effect-instance-get-pending-buffer-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_dynamic_sound_effect_instance_get_sample_duration_ticks" %dynamic-sound-effect-instance-get-sample-duration-ticks :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "none")
    ("cna_dynamic_sound_effect_instance_get_sample_size_in_bytes" %dynamic-sound-effect-instance-get-sample-size-in-bytes :uint32 (:uint64 :int64 :pointer) :thread :owner :ownership "none")
    ("cna_dynamic_sound_effect_instance_subscribe_buffer_needed" %dynamic-sound-effect-instance-subscribe-buffer-needed :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_audio_unsubscribe_ext" %audio-unsubscribe-ext :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_microphone_get_count" %microphone-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_get_default_index_ext" %microphone-get-default-index-ext :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "none")
    ("cna_microphone_get_name_size_at" %microphone-get-name-size-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_copy_name_at" %microphone-copy-name-at :uint32 (:uint64 :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_get_buffer_duration_ticks_at" %microphone-get-buffer-duration-ticks-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_set_buffer_duration_ticks_at" %microphone-set-buffer-duration-ticks-at :uint32 (:uint64 :uint64 :int64) :thread :owner :ownership "none")
    ("cna_microphone_get_is_headset_at" %microphone-get-is-headset-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_get_sample_rate_at" %microphone-get-sample-rate-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_get_state_at" %microphone-get-state-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_start_at" %microphone-start-at :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_microphone_stop_at" %microphone-stop-at :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_microphone_get_data_at" %microphone-get-data-at :uint32 (:uint64 :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_get_sample_duration_ticks_at" %microphone-get-sample-duration-ticks-at :uint32 (:uint64 :uint64 :int32 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_get_sample_size_in_bytes_at" %microphone-get-sample-size-in-bytes-at :uint32 (:uint64 :uint64 :int64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_subscribe_buffer_ready_at" %microphone-subscribe-buffer-ready-at :uint32 (:uint64 :uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_microphone_check_all_buffers_ext" %microphone-check-all-buffers-ext :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_microphone_get_type_name_size" %microphone-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_microphone_copy_type_name" %microphone-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_create" %song-create :uint32 (:uint64 :pointer :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:song:child-of-game")
    ("cna_song_create_with_duration" %song-create-with-duration :uint32 (:uint64 :pointer :uint64 :pointer :uint64 :int32 :pointer) :thread :owner :ownership "creates-owned:song:child-of-game")
    ("cna_song_create_from_uri" %song-create-from-uri :uint32 (:uint64 :pointer :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:song:child-of-game")
    ("cna_song_get_name_size" %song-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_copy_name" %song-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_duration" %song-get-duration :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_is_protected" %song-get-is-protected :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_is_rated" %song-get-is-rated :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_play_count" %song-get-play-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_rating" %song-get-rating :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_track_number" %song-get-track-number :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_is_disposed" %song-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_dispose" %song-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_song_destroy" %song-destroy :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_song_equals" %song-equals :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_hash_code" %song-get-hash-code :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_type_name_size" %song-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_copy_type_name" %song-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_collection_create" %song-collection-create :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:song-collection:child-of-game")
    ("cna_song_collection_get_at" %song-collection-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "creates-owned:song:child-of-game")
    ("cna_song_collection_get_count" %song-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_collection_get_is_disposed" %song-collection-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_collection_dispose" %song-collection-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_song_collection_destroy" %song-collection-destroy :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_song_collection_get_type_name_size" %song-collection-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_collection_copy_type_name" %song-collection-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_visualization_data_init" %visualization-data-init :uint32 (:pointer) :thread :owner :ownership "none")
    ("cna_visualization_data_get_type_name_size" %visualization-data-get-type-name-size :uint32 (:pointer) :thread :owner :ownership "none")
    ("cna_visualization_data_copy_type_name" %visualization-data-copy-type-name :uint32 (:pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_get_game_has_control" %media-player-get-game-has-control :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_get_is_muted" %media-player-get-is-muted :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_set_is_muted" %media-player-set-is-muted :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_media_player_get_is_repeating" %media-player-get-is-repeating :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_set_is_repeating" %media-player-set-is-repeating :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_media_player_get_is_shuffled" %media-player-get-is-shuffled :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_set_is_shuffled" %media-player-set-is-shuffled :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_media_player_get_play_position_ticks" %media-player-get-play-position-ticks :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_get_state" %media-player-get-state :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_get_volume" %media-player-get-volume :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_set_volume" %media-player-set-volume :uint32 (:uint64 :float) :thread :owner :ownership "none")
    ("cna_media_player_get_is_visualization_enabled" %media-player-get-is-visualization-enabled :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_set_is_visualization_enabled" %media-player-set-is-visualization-enabled :uint32 (:uint64 :uint8) :thread :owner :ownership "none")
    ("cna_media_player_get_visualization_data" %media-player-get-visualization-data :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_get_queue" %media-player-get-queue :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_player_play_song" %media-player-play-song :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_media_player_play_songs" %media-player-play-songs :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_media_player_play_songs_from" %media-player-play-songs-from :uint32 (:uint64 :uint64 :int32) :thread :owner :ownership "none")
    ("cna_media_player_move_next" %media-player-move-next :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_player_move_previous" %media-player-move-previous :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_player_pause" %media-player-pause :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_player_resume" %media-player-resume :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_player_stop" %media-player-stop :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_player_subscribe_active_song_changed_ext" %media-player-subscribe-active-song-changed-ext :uint32 (:pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_media_player_subscribe_media_state_changed_ext" %media-player-subscribe-media-state-changed-ext :uint32 (:pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_media_player_unsubscribe_ext" %media-player-unsubscribe-ext :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_media_player_raise_active_song_changed_ext" %media-player-raise-active-song-changed-ext :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_player_raise_media_state_changed_ext" %media-player-raise-media-state-changed-ext :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_queue_get_count" %media-queue-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_queue_get_active_song_index" %media-queue-get-active-song-index :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_queue_set_active_song_index" %media-queue-set-active-song-index :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_media_queue_get_active_song" %media-queue-get-active-song :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:song:child-of-game")
    ("cna_media_queue_get_at" %media-queue-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "creates-owned:song:child-of-game")
    ("cna_media_queue_get_type_name_size" %media-queue-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_queue_copy_type_name" %media-queue-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_set_app_name_ext" %storage-set-app-name-ext :uint32 (:pointer :uint64) :thread :owner :ownership "none")
    ("cna_storage_get_root_size_ext" %storage-get-root-size-ext :uint32 (:pointer) :thread :owner :ownership "none")
    ("cna_storage_copy_root_ext" %storage-copy-root-ext :uint32 (:pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_device_show_selector" %storage-device-show-selector :uint32 (:pointer :pointer :pointer) :thread :owner :ownership "creates-owned:storage-device:rootless")
    ("cna_storage_device_show_selector_for_player" %storage-device-show-selector-for-player :uint32 (:uint32 :pointer :pointer :pointer) :thread :owner :ownership "creates-owned:storage-device:rootless")
    ("cna_storage_device_show_selector_with_space" %storage-device-show-selector-with-space :uint32 (:int32 :int32 :pointer :pointer :pointer) :thread :owner :ownership "creates-owned:storage-device:rootless")
    ("cna_storage_device_show_selector_for_player_with_space" %storage-device-show-selector-for-player-with-space :uint32 (:uint32 :int32 :int32 :pointer :pointer :pointer) :thread :owner :ownership "creates-owned:storage-device:rootless")
    ("cna_storage_device_get_free_space" %storage-device-get-free-space :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_device_get_is_connected" %storage-device-get-is-connected :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_device_get_total_space" %storage-device-get-total-space :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_device_delete_container" %storage-device-delete-container :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_storage_device_subscribe_device_changed" %storage-device-subscribe-device-changed :uint32 (:pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_storage_device_unsubscribe_device_changed" %storage-device-unsubscribe-device-changed :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_storage_device_destroy" %storage-device-destroy :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_storage_container_open" %storage-container-open :uint32 (:uint64 :pointer :uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates-owned:storage-container:child-of-storage-device")
    ("cna_storage_container_get_display_name_size" %storage-container-get-display-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_copy_display_name" %storage-container-copy-display-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_get_type_name_size" %storage-container-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_copy_type_name" %storage-container-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_get_is_disposed" %storage-container-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_get_storage_device" %storage-container-get-storage-device :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_dispose" %storage-container-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_storage_container_subscribe_disposing" %storage-container-subscribe-disposing :uint32 (:uint64 :pointer :pointer :pointer) :thread :owner :ownership "creates")
    ("cna_storage_container_unsubscribe_disposing" %storage-container-unsubscribe-disposing :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_storage_container_create_directory" %storage-container-create-directory :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_storage_container_directory_exists" %storage-container-directory-exists :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_delete_directory" %storage-container-delete-directory :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_storage_container_file_exists" %storage-container-file-exists :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_delete_file" %storage-container-delete-file :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_storage_container_get_directory_name_count" %storage-container-get-directory-name-count :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_copy_directory_name" %storage-container-copy-directory-name :uint32 (:uint64 :pointer :uint64 :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_get_file_name_count" %storage-container-get-file-name-count :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_copy_file_name" %storage-container-copy-file-name :uint32 (:uint64 :pointer :uint64 :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_container_create_file" %storage-container-create-file :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:storage-stream:child-of-storage-container")
    ("cna_storage_container_open_file" %storage-container-open-file :uint32 (:uint64 :pointer :uint64 :uint32 :pointer) :thread :owner :ownership "creates-owned:storage-stream:child-of-storage-container")
    ("cna_storage_container_open_file_access" %storage-container-open-file-access :uint32 (:uint64 :pointer :uint64 :uint32 :uint32 :pointer) :thread :owner :ownership "creates-owned:storage-stream:child-of-storage-container")
    ("cna_storage_container_open_file_share" %storage-container-open-file-share :uint32 (:uint64 :pointer :uint64 :uint32 :uint32 :uint32 :pointer) :thread :owner :ownership "creates-owned:storage-stream:child-of-storage-container")
    ("cna_storage_container_destroy" %storage-container-destroy :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_storage_stream_read" %storage-stream-read :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_stream_write" %storage-stream-write :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_storage_stream_seek" %storage-stream-seek :uint32 (:uint64 :int64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_storage_stream_get_position" %storage-stream-get-position :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_stream_get_length" %storage-stream-get-length :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_stream_set_length" %storage-stream-set-length :uint32 (:uint64 :int64) :thread :owner :ownership "none")
    ("cna_storage_stream_get_can_read" %storage-stream-get-can-read :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_stream_get_can_write" %storage-stream-get-can-write :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_stream_get_can_seek" %storage-stream-get-can-seek :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_storage_stream_flush" %storage-stream-flush :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_storage_stream_close" %storage-stream-close :uint32 (:uint64) :thread :owner :ownership "destroys")
    ("cna_model_bone_create_default" %model-bone-create-default :uint32 (:pointer) :thread :owner :ownership "creates-owned:model-bone:rootless")
    ("cna_model_bone_create" %model-bone-create :uint32 (:int32 :pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:model-bone:rootless")
    ("cna_model_bone_destroy" %model-bone-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model-bone")
    ("cna_model_bone_get_name_byte_count" %model-bone-get-name-byte-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_bone_copy_name" %model-bone-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_bone_get_index" %model-bone-get-index :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_bone_get_transform" %model-bone-get-transform :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_bone_get_parent" %model-bone-get-parent :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:model-bone:rootless")
    ("cna_model_bone_get_children" %model-bone-get-children :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:model-bone-collection:rootless")
    ("cna_model_bone_add_child" %model-bone-add-child :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_model_bone_collection_create" %model-bone-collection-create :uint32 (:pointer) :thread :owner :ownership "creates-owned:model-bone-collection:rootless")
    ("cna_model_bone_collection_destroy" %model-bone-collection-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model-bone-collection")
    ("cna_model_bone_collection_get_count" %model-bone-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_bone_collection_get_at" %model-bone-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "creates-owned:model-bone:rootless")
    ("cna_model_bone_collection_find" %model-bone-collection-find :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:model-bone:rootless")
    ("cna_model_bone_collection_contains" %model-bone-collection-contains :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_part_create_default" %model-mesh-part-create-default :uint32 (:pointer) :thread :owner :ownership "creates-owned:model-mesh-part:rootless")
    ("cna_model_mesh_part_create" %model-mesh-part-create :uint32 (:uint64 :uint64 :int32 :int32 :int32 :int32 :pointer) :thread :owner :ownership "creates-owned:model-mesh-part:rootless")
    ("cna_model_mesh_part_destroy" %model-mesh-part-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model-mesh-part")
    ("cna_model_mesh_part_get_num_vertices" %model-mesh-part-get-num-vertices :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_part_set_num_vertices" %model-mesh-part-set-num-vertices :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_model_mesh_part_get_primitive_count" %model-mesh-part-get-primitive-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_part_set_primitive_count" %model-mesh-part-set-primitive-count :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_model_mesh_part_get_start_index" %model-mesh-part-get-start-index :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_part_set_start_index" %model-mesh-part-set-start-index :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_model_mesh_part_get_vertex_offset" %model-mesh-part-get-vertex-offset :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_part_set_vertex_offset" %model-mesh-part-set-vertex-offset :uint32 (:uint64 :int32) :thread :owner :ownership "none")
    ("cna_model_mesh_part_get_effect" %model-mesh-part-get-effect :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_model_mesh_part_set_effect" %model-mesh-part-set-effect :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_model_mesh_part_get_vertex_buffer" %model-mesh-part-get-vertex-buffer :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_model_mesh_part_set_vertex_buffer" %model-mesh-part-set-vertex-buffer :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_model_mesh_part_get_index_buffer" %model-mesh-part-get-index-buffer :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_model_mesh_part_set_index_buffer" %model-mesh-part-set-index-buffer :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_model_mesh_part_collection_create" %model-mesh-part-collection-create :uint32 (:pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:model-mesh-part-collection:rootless")
    ("cna_model_mesh_part_collection_destroy" %model-mesh-part-collection-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model-mesh-part-collection")
    ("cna_model_mesh_part_collection_get_count" %model-mesh-part-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_part_collection_get_at" %model-mesh-part-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "creates-owned:model-mesh-part:rootless")
    ("cna_model_mesh_create" %model-mesh-create :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates-owned:model-mesh:rootless")
    ("cna_model_mesh_create_named" %model-mesh-create-named :uint32 (:uint64 :pointer :uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates-owned:model-mesh:rootless")
    ("cna_model_mesh_destroy" %model-mesh-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model-mesh")
    ("cna_model_mesh_get_bounding_sphere" %model-mesh-get-bounding-sphere :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_get_mesh_parts" %model-mesh-get-mesh-parts :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:model-mesh-part-collection:rootless")
    ("cna_model_mesh_get_effects" %model-mesh-get-effects :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:model-effect-collection:rootless")
    ("cna_model_mesh_get_name_byte_count" %model-mesh-get-name-byte-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_copy_name" %model-mesh-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_get_parent_bone" %model-mesh-get-parent-bone :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:model-bone:rootless")
    ("cna_model_mesh_set_parent_bone" %model-mesh-set-parent-bone :uint32 (:uint64 :uint64) :thread :owner :ownership "none")
    ("cna_model_mesh_collection_create" %model-mesh-collection-create :uint32 (:pointer :uint64 :pointer) :thread :owner :ownership "creates-owned:model-mesh-collection:rootless")
    ("cna_model_mesh_collection_destroy" %model-mesh-collection-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model-mesh-collection")
    ("cna_model_mesh_collection_get_count" %model-mesh-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_mesh_collection_get_at" %model-mesh-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "creates-owned:model-mesh:rootless")
    ("cna_model_mesh_collection_find" %model-mesh-collection-find :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:model-mesh:rootless")
    ("cna_model_mesh_collection_contains" %model-mesh-collection-contains :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_effect_collection_destroy" %model-effect-collection-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model-effect-collection")
    ("cna_model_effect_collection_get_count" %model-effect-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_effect_collection_get_at" %model-effect-collection-get-at :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_model_effect_collection_contains" %model-effect-collection-contains :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_create_default" %model-create-default :uint32 (:pointer) :thread :owner :ownership "creates-owned:model:rootless")
    ("cna_model_create" %model-create :uint32 (:uint64 :pointer :uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates-owned:model:rootless")
    ("cna_model_create_with_parents" %model-create-with-parents :uint32 (:uint64 :pointer :uint64 :pointer :uint64 :pointer :uint64 :uint64 :pointer) :thread :game :ownership "creates-owned:model:rootless")
    ("cna_model_destroy" %model-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:model")
    ("cna_model_get_bones" %model-get-bones :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:model-bone-collection:rootless")
    ("cna_model_get_meshes" %model-get-meshes :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:model-mesh-collection:rootless")
    ("cna_model_get_root" %model-get-root :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "creates-owned:model-bone:rootless")
    ("cna_model_get_bone_transform_count" %model-get-bone-transform-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_copy_absolute_bone_transforms" %model-copy-absolute-bone-transforms :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_copy_bone_transforms" %model-copy-bone-transforms :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_model_set_bone_transforms" %model-set-bone-transforms :uint32 (:uint64 :pointer :uint64) :thread :owner :ownership "none")
    ("cna_content_manager_load_model" %content-manager-load-model :uint32 (:uint64 :pointer :uint64 :pointer) :thread :game :ownership "creates-owned:model:child-of-game")
    ("cna_album_collection_copy_type_name" %album-collection-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_collection_destroy" %album-collection-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_album_collection_dispose" %album-collection-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_album_collection_get_at" %album-collection-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "borrows")
    ("cna_album_collection_get_count" %album-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_collection_get_is_disposed" %album-collection-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_collection_get_type_name_size" %album-collection-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_copy_art" %album-copy-art :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_copy_name" %album-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_copy_thumbnail" %album-copy-thumbnail :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_copy_type_name" %album-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_destroy" %album-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_album_dispose" %album-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_album_equals" %album-equals :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_art_size" %album-get-art-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_artist" %album-get-artist :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_album_get_duration" %album-get-duration :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_genre" %album-get-genre :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_album_get_has_art" %album-get-has-art :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_hash_code" %album-get-hash-code :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_is_disposed" %album-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_name_size" %album-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_songs" %album-get-songs :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_album_get_thumbnail_size" %album-get-thumbnail-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_album_get_type_name_size" %album-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_collection_copy_type_name" %artist-collection-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_collection_destroy" %artist-collection-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_artist_collection_dispose" %artist-collection-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_artist_collection_get_at" %artist-collection-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "borrows")
    ("cna_artist_collection_get_count" %artist-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_collection_get_is_disposed" %artist-collection-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_collection_get_type_name_size" %artist-collection-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_copy_name" %artist-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_copy_type_name" %artist-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_destroy" %artist-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_artist_dispose" %artist-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_artist_equals" %artist-equals :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_get_albums" %artist-get-albums :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_artist_get_hash_code" %artist-get-hash-code :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_get_is_disposed" %artist-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_get_name_size" %artist-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_artist_get_songs" %artist-get-songs :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_artist_get_type_name_size" %artist-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_collection_copy_type_name" %genre-collection-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_collection_destroy" %genre-collection-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_genre_collection_dispose" %genre-collection-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_genre_collection_get_at" %genre-collection-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "borrows")
    ("cna_genre_collection_get_count" %genre-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_collection_get_is_disposed" %genre-collection-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_collection_get_type_name_size" %genre-collection-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_copy_name" %genre-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_copy_type_name" %genre-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_destroy" %genre-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_genre_dispose" %genre-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_genre_equals" %genre-equals :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_get_albums" %genre-get-albums :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_genre_get_hash_code" %genre-get-hash-code :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_get_is_disposed" %genre-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_get_name_size" %genre-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_genre_get_songs" %genre-get-songs :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_genre_get_type_name_size" %genre-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_library_copy_media_source_name" %media-library-copy-media-source-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_library_copy_type_name" %media-library-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_library_create" %media-library-create :uint32 (:uint64 :pointer) :thread :owner :ownership "creates-owned:media-library:child-of-game")
    ("cna_media_library_create_from_source" %media-library-create-from-source :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "creates-owned:media-library:child-of-game")
    ("cna_media_library_destroy" %media-library-destroy :uint32 (:uint64) :thread :owner :ownership "destroys:media-library")
    ("cna_media_library_dispose" %media-library-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_media_library_get_albums" %media-library-get-albums :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_artists" %media-library-get-artists :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_genres" %media-library-get-genres :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_is_disposed" %media-library-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_library_get_media_source_name_size" %media-library-get-media-source-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_library_get_media_source_type" %media-library-get-media-source-type :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_library_get_playlists" %media-library-get-playlists :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_songs" %media-library-get-songs :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_type_name_size" %media-library-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_source_copy_name_at" %media-source-copy-name-at :uint32 (:uint64 :uint32 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_source_copy_type_name_at" %media-source-copy-type-name-at :uint32 (:uint64 :uint32 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_source_get_available_count" %media-source-get-available-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_media_source_get_name_size_at" %media-source-get-name-size-at :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_media_source_get_type_at" %media-source-get-type-at :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_media_source_get_type_name_size_at" %media-source-get-type-name-size-at :uint32 (:uint64 :uint32 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_collection_copy_type_name" %playlist-collection-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_collection_destroy" %playlist-collection-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_playlist_collection_dispose" %playlist-collection-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_playlist_collection_get_at" %playlist-collection-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "borrows")
    ("cna_playlist_collection_get_count" %playlist-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_collection_get_is_disposed" %playlist-collection-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_collection_get_type_name_size" %playlist-collection-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_copy_name" %playlist-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_copy_type_name" %playlist-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_destroy" %playlist-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_playlist_dispose" %playlist-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_playlist_equals" %playlist-equals :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_get_duration" %playlist-get-duration :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_get_hash_code" %playlist-get-hash-code :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_get_is_disposed" %playlist-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_get_name_size" %playlist-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_playlist_get_songs" %playlist-get-songs :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_playlist_get_type_name_size" %playlist-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_song_get_album" %song-get-album :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_song_get_artist" %song-get-artist :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_song_get_genre" %song-get-genre :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_picture_from_token" %media-library-get-picture-from-token :uint32 (:uint64 :pointer :uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_pictures" %media-library-get-pictures :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_root_picture_album" %media-library-get-root-picture-album :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_get_saved_pictures" %media-library-get-saved-pictures :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_save_picture" %media-library-save-picture :uint32 (:uint64 :pointer :uint64 :pointer :uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_media_library_save_picture_from_stream" %media-library-save-picture-from-stream :uint32 (:uint64 :pointer :uint64 :uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_picture_album_collection_copy_type_name" %picture-album-collection-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_collection_destroy" %picture-album-collection-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_picture_album_collection_dispose" %picture-album-collection-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_picture_album_collection_get_at" %picture-album-collection-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "borrows")
    ("cna_picture_album_collection_get_count" %picture-album-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_collection_get_is_disposed" %picture-album-collection-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_collection_get_type_name_size" %picture-album-collection-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_copy_name" %picture-album-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_copy_type_name" %picture-album-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_destroy" %picture-album-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_picture_album_dispose" %picture-album-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_picture_album_equals" %picture-album-equals :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_get_albums" %picture-album-get-albums :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_picture_album_get_hash_code" %picture-album-get-hash-code :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_get_is_disposed" %picture-album-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_get_name_size" %picture-album-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_album_get_parent" %picture-album-get-parent :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_picture_album_get_pictures" %picture-album-get-pictures :uint32 (:uint64 :pointer) :thread :owner :ownership "borrows")
    ("cna_picture_album_get_type_name_size" %picture-album-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_collection_copy_type_name" %picture-collection-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_collection_destroy" %picture-collection-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_picture_collection_dispose" %picture-collection-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_picture_collection_get_at" %picture-collection-get-at :uint32 (:uint64 :int32 :pointer) :thread :owner :ownership "borrows")
    ("cna_picture_collection_get_count" %picture-collection-get-count :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_collection_get_is_disposed" %picture-collection-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_collection_get_type_name_size" %picture-collection-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_copy_image" %picture-copy-image :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_copy_name" %picture-copy-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_copy_thumbnail" %picture-copy-thumbnail :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_copy_token_ext" %picture-copy-token-ext :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_copy_type_name" %picture-copy-type-name :uint32 (:uint64 :pointer :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_destroy" %picture-destroy :uint32 (:uint64) :thread :owner :ownership "releases")
    ("cna_picture_dispose" %picture-dispose :uint32 (:uint64) :thread :owner :ownership "none")
    ("cna_picture_equals" %picture-equals :uint32 (:uint64 :uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_album" %picture-get-album :uint32 (:uint64 :pointer :pointer) :thread :owner :ownership "borrows")
    ("cna_picture_get_date_unix_ticks" %picture-get-date-unix-ticks :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_hash_code" %picture-get-hash-code :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_height" %picture-get-height :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_image_size" %picture-get-image-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_is_disposed" %picture-get-is-disposed :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_name_size" %picture-get-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_thumbnail_size" %picture-get-thumbnail-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_token_size_ext" %picture-get-token-size-ext :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_type_name_size" %picture-get-type-name-size :uint32 (:uint64 :pointer) :thread :owner :ownership "none")
    ("cna_picture_get_width" %picture-get-width :uint32 (:uint64 :pointer) :thread :owner :ownership "none"))
  "Every native route this binding may call: C name, Lisp name, and bound CFFI shape.")

