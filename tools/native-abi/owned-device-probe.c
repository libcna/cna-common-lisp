/* owned-device-probe.c --- measure CNA's caller-created GraphicsDevice, one stage per process.
 *
 * `graphics_device.h' is byte-identical across ABI 0.21.0, 0.22.0 and 0.23.0, and
 * Storage already proved what that is worth: identical prose over different
 * behaviour. So every claim this binding makes about a caller-created device is
 * measured here, through the C ABI alone with no binding in the path, before any
 * Lisp is written.
 *
 *   owned-device-probe <library> <stage>
 *
 * One stage per process, because a stage that faults must not take the others
 * with it and must name itself when it does. Every step prints a `STAGE' line
 * and flushes, so the parent reads how far the child got even after a signal.
 *
 * Stages:
 *   create            create one device, read its properties, destroy it
 *   two-devices       A and B live at once, use both, destroy A, use B, destroy B
 *   game-then-device  a Game exists first; a standalone device joins it
 *   device-then-game  a standalone device exists first; a Game joins it
 *   resource          create a texture on an owned device and destroy both
 *   cross-device      a resource of device A used in a call on device B
 *   cross-game        a Game resource on an owned device and the reverse
 *   destroy-with-child   destroy a device that still has a live resource
 *   game-destroy-with-owned  cna_game_destroy while an owned device+resource live
 *   dispose-route     cna_graphics_device_dispose on an owned device
 *   double-destroy    destroy the same owned handle twice
 *   clear             clear an owned device outside any callback
 *   present           present an owned device outside any callback
 *   headless-ext      create with headless_ext = 1 rather than 0
 *   thread            touch an owned device from a second thread
 *   pixels            clear an owned device and read the back buffer back
 *   adapters          enumerate adapters with no device, then with an owned one
 *   churn             create and destroy a device many times over
 *   events            device Disposing and resource Disposing, and their order
 *   cross-game        (callback-scoped) a Game resource on an owned device and the reverse
 */
#define _POSIX_C_SOURCE 200809L

#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#include <CNA/C/cna.h>

static void *lib;
#define SYM(name) do { \
    *(void **)(&p_##name) = dlsym(lib, #name); \
    if (!p_##name) { printf("MISSING %s\n", #name); fflush(stdout); return 90; } \
} while (0)

static uint32_t (*p_cna_get_abi_version)(void);
static CNA_Result (*p_cna_graphics_device_create)(uint32_t, uint32_t,
                                                  const CNA_PresentationParameters *, CNA_Handle *);
static CNA_Result (*p_cna_graphics_device_destroy)(CNA_Handle);
static CNA_Result (*p_cna_graphics_device_dispose)(CNA_Handle);
static CNA_Result (*p_cna_presentation_parameters_init)(CNA_PresentationParameters *);
static CNA_Result (*p_cna_graphics_device_get_adapter_index)(CNA_Handle, uint32_t *);
static CNA_Result (*p_cna_graphics_device_get_graphics_profile)(CNA_Handle, uint32_t *);
static CNA_Result (*p_cna_graphics_device_get_is_disposed)(CNA_Handle, CNA_Bool *);
static CNA_Result (*p_cna_graphics_device_get_status)(CNA_Handle, CNA_GraphicsDeviceStatus *);
static CNA_Result (*p_cna_graphics_device_get_viewport)(CNA_Handle, CNA_Viewport *);
static CNA_Result (*p_cna_graphics_device_set_viewport)(CNA_Handle, CNA_Viewport);
static CNA_Result (*p_cna_graphics_device_get_tracked_resource_count)(CNA_Handle, uint64_t *);
static CNA_Result (*p_cna_graphics_device_clear_rgba)(CNA_Handle, float, float, float, float);
static CNA_Result (*p_cna_graphics_device_present)(CNA_Handle);
static CNA_Result (*p_cna_graphics_device_get_presentation_parameters)(CNA_Handle,
                                                                       CNA_PresentationParameters *);
static CNA_Result (*p_cna_graphics_adapter_get_count)(CNA_Handle, uint32_t *);
static CNA_Result (*p_cna_texture2d_create)(CNA_Handle, const CNA_Texture2DCreateInfo *, CNA_Handle *);
static CNA_Result (*p_cna_texture2d_destroy)(CNA_Handle);
static CNA_Result (*p_cna_graphics_device_set_texture)(CNA_Handle, CNA_ShaderStage, uint32_t,
                                                       CNA_Handle);
static CNA_Result (*p_cna_graphics_device_get_texture)(CNA_Handle, CNA_ShaderStage, uint32_t,
                                                       CNA_TextureSlotInfo *);
static CNA_Result (*p_cna_texture_get_info)(CNA_Handle, CNA_TextureInfo *);
static CNA_Result (*p_cna_graphics_resource_get_is_disposed)(CNA_Handle, CNA_Bool *);
static CNA_Result (*p_cna_game_create)(const CNA_GameCreateInfo *, CNA_Handle *);
static CNA_Result (*p_cna_game_run_one_frame)(CNA_Handle);
static CNA_Result (*p_cna_game_destroy)(CNA_Handle);
static CNA_Result (*p_cna_game_get_graphics_device)(CNA_Handle, CNA_Handle *);
static CNA_Result (*p_cna_graphics_device_get_backbuffer_data_window)(CNA_Handle,
        const CNA_BackBufferReadback *, CNA_Color *, uint64_t);
static CNA_Result (*p_cna_game_set_frame_hooks_ext)(CNA_Handle, const CNA_GameFrameHooks *);
static CNA_Result (*p_cna_graphics_device_subscribe_event)(CNA_Handle, CNA_GraphicsDeviceEvent,
        CNA_GraphicsDeviceEventCallback, void *, CNA_GraphicsDeviceEventRegistrationHandle *);
static CNA_Result (*p_cna_graphics_device_unsubscribe)(
        CNA_GraphicsDeviceEventRegistrationHandle);
static CNA_Result (*p_cna_graphics_resource_subscribe_disposing)(CNA_Handle,
        CNA_GraphicsResourceDisposingCallback, void *,
        CNA_GraphicsResourceEventRegistrationHandle *);
static CNA_Result (*p_cna_graphics_resource_unsubscribe_disposing)(
        CNA_GraphicsResourceEventRegistrationHandle);

static void on_segv(int signo, siginfo_t *info, void *context) {
    char buffer[128];
    int n = snprintf(buffer, sizeof buffer, "FAULT SIG%s at address 0x%lx\n",
                     signo == SIGSEGV ? "SEGV" : "BUS", (unsigned long)(uintptr_t)info->si_addr);
    (void)context;
    if (n > 0) { ssize_t w = write(1, buffer, (size_t)n); (void)w; }
    signal(signo, SIG_DFL);
    raise(signo);
}

/* `##__VA_ARGS__' is a GNU extension and -Wpedantic rejects it, so the
 * zero-argument case gets a macro of its own rather than a compiler dialect. */
#define STEP(...) do { printf("STAGE  " __VA_ARGS__); printf("\n"); fflush(stdout); } while (0)

/* CNA's result codes are what this probe reports; naming them here keeps the
 * output readable without pulling in a translation table the ABI does not have. */
static const char *rname(CNA_Result r) {
    switch (r) {
    case CNA_RESULT_SUCCESS: return "SUCCESS";
    case CNA_RESULT_INVALID_ARGUMENT: return "INVALID_ARGUMENT";
    case CNA_RESULT_INVALID_HANDLE: return "INVALID_HANDLE";
    case CNA_RESULT_NOT_SUPPORTED: return "NOT_SUPPORTED";
    case CNA_RESULT_INVALID_STATE: return "INVALID_STATE";
    case CNA_RESULT_OUT_OF_MEMORY: return "OUT_OF_MEMORY";
    case CNA_RESULT_IO: return "IO";
    case CNA_RESULT_PLATFORM: return "PLATFORM";
    case CNA_RESULT_THREAD: return "THREAD";
    case CNA_RESULT_CALLBACK: return "CALLBACK";
    case CNA_RESULT_OVERFLOW: return "OVERFLOW";
    case CNA_RESULT_ENCODING: return "ENCODING";
    case CNA_RESULT_INTERNAL: return "INTERNAL";
    case CNA_RESULT_SHUTTING_DOWN: return "SHUTTING_DOWN";
    case CNA_RESULT_BUFFER_TOO_SMALL: return "BUFFER_TOO_SMALL";
    default: return "OTHER";
    }
}
#define R(label, expr) do { \
    CNA_Result r_ = (expr); \
    printf("STAGE  %-34s -> %s (%u)\n", label, rname(r_), (unsigned)r_); \
    fflush(stdout); \
} while (0)
#define RV(label, expr, var) do { \
    CNA_Result r_ = (expr); \
    (var) = r_; \
    printf("STAGE  %-34s -> %s (%u)\n", label, rname(r_), (unsigned)r_); \
    fflush(stdout); \
} while (0)

static void defaults(CNA_PresentationParameters *pp, int headless_ext) {
    memset(pp, 0, sizeof *pp);
    if (p_cna_presentation_parameters_init && p_cna_presentation_parameters_init(pp) == CNA_RESULT_SUCCESS) {
        /* keep CNA's own defaults, only pin a size a software rasteriser can hold */
    } else {
        pp->struct_size = (uint32_t)sizeof *pp;
        pp->struct_version = 1;
    }
    pp->back_buffer_width = 64;
    pp->back_buffer_height = 32;
    pp->headless_ext = (CNA_Bool)(headless_ext ? CNA_TRUE : CNA_FALSE);
}

static CNA_Result make_device(int headless_ext, CNA_Handle *out) {
    CNA_PresentationParameters pp;
    defaults(&pp, headless_ext);
    *out = CNA_INVALID_HANDLE;
    return p_cna_graphics_device_create(0u, CNA_GRAPHICS_PROFILE_REACH, &pp, out);
}

static void report_device(const char *who, CNA_Handle d) {
    uint32_t adapter = 0xffffffffu, profile = 0xffffffffu;
    CNA_Bool disposed = 2;
    CNA_GraphicsDeviceStatus status = 0xffffffffu;
    CNA_Viewport vp; uint64_t tracked = 0;
    memset(&vp, 0, sizeof vp);
    CNA_Result ra = p_cna_graphics_device_get_adapter_index(d, &adapter);
    CNA_Result rp = p_cna_graphics_device_get_graphics_profile(d, &profile);
    CNA_Result rd = p_cna_graphics_device_get_is_disposed(d, &disposed);
    CNA_Result rs = p_cna_graphics_device_get_status(d, &status);
    CNA_Result rv = p_cna_graphics_device_get_viewport(d, &vp);
    CNA_Result rt = p_cna_graphics_device_get_tracked_resource_count(d, &tracked);
    printf("STAGE  %-10s adapter=%u(%s) profile=%u(%s) disposed=%d(%s) status=%u(%s)\n",
           who, adapter, rname(ra), profile, rname(rp), (int)disposed, rname(rd),
           (unsigned)status, rname(rs));
    printf("STAGE  %-10s viewport=%dx%d+%d+%d(%s) tracked=%llu(%s)\n",
           who, (int)vp.width, (int)vp.height, (int)vp.x, (int)vp.y, rname(rv),
           (unsigned long long)tracked, rname(rt));
    fflush(stdout);
}

static CNA_Result make_texture(CNA_Handle device, CNA_Handle *out) {
    CNA_Texture2DCreateInfo info;
    memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info;
    info.struct_version = 1;
    info.width = 4; info.height = 4;
    info.mip_map = CNA_FALSE;
    info.format = CNA_SURFACE_FORMAT_COLOR;
    *out = CNA_INVALID_HANDLE;
    return p_cna_texture2d_create(device, &info, out);
}

static CNA_Handle make_game_with(const CNA_GameCallbacks *callbacks) {
    CNA_GameCreateInfo ci;
    CNA_Handle game = CNA_INVALID_HANDLE;
    memset(&ci, 0, sizeof ci);
    ci.struct_size = (uint32_t)sizeof ci;
    ci.struct_version = 1;
    ci.is_fixed_time_step = CNA_TRUE;
    ci.target_elapsed_time_ticks = 166667;
    ci.window_title.data = "owned-device-probe";
    ci.window_title.byte_length = strlen("owned-device-probe");
    ci.callbacks = callbacks;
    CNA_Result r;
    RV("cna_game_create", p_cna_game_create(&ci, &game), r);
    if (r != CNA_RESULT_SUCCESS) return CNA_INVALID_HANDLE;
    return game;
}
static CNA_Handle make_game(void) { return make_game_with(NULL); }


/* The game lends its device only inside a callback, so the cross-game comparison
 * has to happen in one. Everything the hook measures is printed from the hook. */
static CNA_Handle hook_owned_device = CNA_INVALID_HANDLE;
static CNA_Handle hook_owned_texture = CNA_INVALID_HANDLE;
static int hook_ran = 0;
static CNA_Result cross_game_update(CNA_Handle game, const CNA_GameTime *gt,
                                    void *context, CNA_CallbackError *out_error) {
    CNA_Handle gdev = CNA_INVALID_HANDLE, gtex = CNA_INVALID_HANDLE;
    (void)gt; (void)context; (void)out_error;
    if (hook_ran++) return CNA_RESULT_SUCCESS;
    R("[in callback] game_get_graphics_device", p_cna_game_get_graphics_device(game, &gdev));
    STEP("[in callback] G=%llu  O=%llu  distinct=%d", (unsigned long long)gdev,
         (unsigned long long)hook_owned_device, gdev != hook_owned_device);
    report_device("G", gdev);
    report_device("O", hook_owned_device);
    R("[in callback] texture on the game device", make_texture(gdev, &gtex));
    R("[in callback] game tex  -> game dev",
      p_cna_graphics_device_set_texture(gdev, CNA_SHADER_STAGE_PIXEL, 0u, gtex));
    R("[in callback] owned tex -> game dev  <-- crossing",
      p_cna_graphics_device_set_texture(gdev, CNA_SHADER_STAGE_PIXEL, 1u, hook_owned_texture));
    R("[in callback] game tex  -> owned dev <-- crossing",
      p_cna_graphics_device_set_texture(hook_owned_device, CNA_SHADER_STAGE_PIXEL, 0u, gtex));
    R("[in callback] clear the game device",
      p_cna_graphics_device_clear_rgba(gdev, 0.f, 0.f, 0.f, 1.f));
    R("[in callback] clear the owned device",
      p_cna_graphics_device_clear_rgba(hook_owned_device, 1.f, 1.f, 1.f, 1.f));
    R("[in callback] destroy the game texture", p_cna_texture2d_destroy(gtex));
    return CNA_RESULT_SUCCESS;
}

struct thread_arg { CNA_Handle device; CNA_Result read, clear, destroy; };
static int event_tick = 0;
static void on_device_disposing(CNA_Handle d, void *context) {
    (void)context;
    printf("STAGE  EVENT %d: device Disposing, handle=%llu\n", ++event_tick,
           (unsigned long long)d);
    fflush(stdout);
}
static void on_resource_disposing(CNA_Handle r, void *context) {
    printf("STAGE  EVENT %d: resource Disposing, handle=%llu (%s)\n", ++event_tick,
           (unsigned long long)r, (const char *)context);
    fflush(stdout);
}

static void *other_thread(void *raw) {
    struct thread_arg *a = raw;
    uint32_t profile = 0;
    a->read = p_cna_graphics_device_get_graphics_profile(a->device, &profile);
    a->clear = p_cna_graphics_device_clear_rgba(a->device, 0.f, 0.f, 0.f, 1.f);
    a->destroy = p_cna_graphics_device_destroy(a->device);
    return NULL;
}

int main(int argc, char **argv) {
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = on_segv;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);

    if (argc != 3) { fprintf(stderr, "usage: %s <library> <stage>\n", argv[0]); return 2; }
    const char *stage = argv[2];

    lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!lib) { printf("DLOPEN %s\n", dlerror()); fflush(stdout); return 91; }

    SYM(cna_get_abi_version);
    SYM(cna_graphics_device_create);
    SYM(cna_graphics_device_destroy);
    SYM(cna_graphics_device_dispose);
    SYM(cna_presentation_parameters_init);
    SYM(cna_graphics_device_get_adapter_index);
    SYM(cna_graphics_device_get_graphics_profile);
    SYM(cna_graphics_device_get_is_disposed);
    SYM(cna_graphics_device_get_status);
    SYM(cna_graphics_device_get_viewport);
    SYM(cna_graphics_device_set_viewport);
    SYM(cna_graphics_device_get_tracked_resource_count);
    SYM(cna_graphics_device_clear_rgba);
    SYM(cna_graphics_device_present);
    SYM(cna_graphics_device_get_presentation_parameters);
    SYM(cna_graphics_adapter_get_count);
    SYM(cna_texture2d_create);
    SYM(cna_texture2d_destroy);
    SYM(cna_graphics_device_set_texture);
    SYM(cna_graphics_device_get_texture);
    SYM(cna_texture_get_info);
    SYM(cna_graphics_resource_get_is_disposed);
    SYM(cna_game_create);
    SYM(cna_game_run_one_frame);
    SYM(cna_game_destroy);
    SYM(cna_game_get_graphics_device);
    SYM(cna_graphics_device_get_backbuffer_data_window);
    SYM(cna_game_set_frame_hooks_ext);
    SYM(cna_graphics_device_subscribe_event);
    SYM(cna_graphics_device_unsubscribe);
    SYM(cna_graphics_resource_subscribe_disposing);
    SYM(cna_graphics_resource_unsubscribe_disposing);

    printf("ABI %u\n", p_cna_get_abi_version());
    fflush(stdout);

    CNA_Handle a = CNA_INVALID_HANDLE, b = CNA_INVALID_HANDLE, game = CNA_INVALID_HANDLE;
    CNA_Handle tex = CNA_INVALID_HANDLE, tex2 = CNA_INVALID_HANDLE, gdev = CNA_INVALID_HANDLE;
    CNA_Result r;

    if (!strcmp(stage, "create")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused; nothing else to do"); return 0; }
        report_device("A", a);
        CNA_PresentationParameters got; memset(&got, 0, sizeof got);
        got.struct_size = (uint32_t)sizeof got; got.struct_version = 1;
        R("get_presentation_parameters", p_cna_graphics_device_get_presentation_parameters(a, &got));
        STEP("pp back buffer = %dx%d headless_ext=%d full_screen=%d",
             (int)got.back_buffer_width, (int)got.back_buffer_height,
             (int)got.headless_ext, (int)got.is_full_screen);
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "headless-ext")) {
        RV("create A headless_ext=1", make_device(1, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        report_device("A", a);
        R("clear A", p_cna_graphics_device_clear_rgba(a, 0.f, .5f, 1.f, 1.f));
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "two-devices")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        RV("create B", make_device(0, &b), r);
        STEP("handles A=%llu B=%llu distinct=%d",
             (unsigned long long)a, (unsigned long long)b, a != b);
        report_device("A", a);
        report_device("B", b);
        R("clear A", p_cna_graphics_device_clear_rgba(a, 1.f, 0.f, 0.f, 1.f));
        R("clear B", p_cna_graphics_device_clear_rgba(b, 0.f, 1.f, 0.f, 1.f));
        R("destroy A", p_cna_graphics_device_destroy(a));
        STEP("--- A destroyed, B must survive ---");
        report_device("B", b);
        R("clear B after A gone", p_cna_graphics_device_clear_rgba(b, 0.f, 0.f, 1.f, 1.f));
        R("use of destroyed A", p_cna_graphics_device_clear_rgba(a, 1.f, 1.f, 1.f, 1.f));
        R("destroy B", p_cna_graphics_device_destroy(b));
    } else if (!strcmp(stage, "game-then-device")) {
        game = make_game();
        if (game == CNA_INVALID_HANDLE) return 0;
        R("run_one_frame", p_cna_game_run_one_frame(game));
        RV("game_get_graphics_device", p_cna_game_get_graphics_device(game, &gdev), r);
        STEP("game device handle = %llu", (unsigned long long)gdev);
        if (r == CNA_RESULT_SUCCESS) report_device("G", gdev);
        RV("create standalone A", make_device(0, &a), r);
        if (r == CNA_RESULT_SUCCESS) {
            STEP("handles G=%llu A=%llu distinct=%d",
                 (unsigned long long)gdev, (unsigned long long)a, gdev != a);
            report_device("A", a);
            R("clear A (no callback)", p_cna_graphics_device_clear_rgba(a, 1.f, 0.f, 0.f, 1.f));
            R("run_one_frame with A live", p_cna_game_run_one_frame(game));
            STEP("--- game device after A exists ---");
            if (gdev != CNA_INVALID_HANDLE) report_device("G", gdev);
            R("destroy A", p_cna_graphics_device_destroy(a));
            STEP("--- game device after A destroyed ---");
            if (gdev != CNA_INVALID_HANDLE) report_device("G", gdev);
            R("run_one_frame after A gone", p_cna_game_run_one_frame(game));
        }
        R("cna_game_destroy", p_cna_game_destroy(game));
    } else if (!strcmp(stage, "device-then-game")) {
        RV("create standalone A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        report_device("A", a);
        game = make_game();
        if (game != CNA_INVALID_HANDLE) {
            R("run_one_frame", p_cna_game_run_one_frame(game));
            R("game_get_graphics_device", p_cna_game_get_graphics_device(game, &gdev));
            STEP("handles A=%llu G=%llu distinct=%d",
                 (unsigned long long)a, (unsigned long long)gdev, a != gdev);
            STEP("--- A after the game exists ---");
            report_device("A", a);
            R("clear A", p_cna_graphics_device_clear_rgba(a, 1.f, 0.f, 0.f, 1.f));
            R("cna_game_destroy", p_cna_game_destroy(game));
            STEP("--- A after the game is gone ---");
            report_device("A", a);
            R("clear A after game gone", p_cna_graphics_device_clear_rgba(a, 0.f, 1.f, 0.f, 1.f));
        }
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "resource")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        report_device("A", a);
        RV("texture2d_create on A", make_texture(a, &tex), r);
        STEP("texture handle = %llu", (unsigned long long)tex);
        report_device("A", a);
        R("set_texture slot 0 on A", p_cna_graphics_device_set_texture(a, CNA_SHADER_STAGE_PIXEL, 0u, tex));
        R("texture2d_destroy", p_cna_texture2d_destroy(tex));
        report_device("A", a);
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "cross-device")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        RV("create B", make_device(0, &b), r);
        RV("texture on A", make_texture(a, &tex), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("no texture; cannot cross"); goto cross_out; }
        R("A's texture into A", p_cna_graphics_device_set_texture(a, CNA_SHADER_STAGE_PIXEL, 0u, tex));
        R("A's texture into B  <-- crossing", p_cna_graphics_device_set_texture(b, CNA_SHADER_STAGE_PIXEL, 0u, tex));
        /* A result code is not proof the binding took: ask B what is in the slot. */
        {
            CNA_TextureSlotInfo si;
            memset(&si, 0, sizeof si);
            si.struct_size = (uint32_t)sizeof si; si.struct_version = 1;
            R("read B slot 0 back",
              p_cna_graphics_device_get_texture(b, CNA_SHADER_STAGE_PIXEL, 0u, &si));
            STEP("B slot 0: bound=%d handle=%llu  (A's texture is %llu)",
                 (int)si.bound, (unsigned long long)si.texture, (unsigned long long)tex);
            memset(&si, 0, sizeof si);
            si.struct_size = (uint32_t)sizeof si; si.struct_version = 1;
            R("read A slot 0 back",
              p_cna_graphics_device_get_texture(a, CNA_SHADER_STAGE_PIXEL, 0u, &si));
            STEP("A slot 0: bound=%d handle=%llu", (int)si.bound,
                 (unsigned long long)si.texture);
        }
        RV("texture on B", make_texture(b, &tex2), r);
        if (r == CNA_RESULT_SUCCESS)
            R("B's texture into A  <-- crossing", p_cna_graphics_device_set_texture(a, CNA_SHADER_STAGE_PIXEL, 0u, tex2));
    cross_out:
        if (tex != CNA_INVALID_HANDLE) R("destroy A's texture", p_cna_texture2d_destroy(tex));
        if (tex2 != CNA_INVALID_HANDLE) R("destroy B's texture", p_cna_texture2d_destroy(tex2));
        R("destroy A", p_cna_graphics_device_destroy(a));
        R("destroy B", p_cna_graphics_device_destroy(b));
    } else if (!strcmp(stage, "adapters")) {
        /* The bootstrap question: creating an owned device needs an adapter
         * index, and every adapter route takes a device handle. If no handle
         * works, the two cannot both be first. */
        uint32_t count = 0xffffffffu;
        R("adapter_get_count(CNA_INVALID_HANDLE)",
          p_cna_graphics_adapter_get_count(CNA_INVALID_HANDLE, &count));
        STEP("count = %u", count);
        count = 0xffffffffu;
        R("adapter_get_count(0)", p_cna_graphics_adapter_get_count((CNA_Handle)0, &count));
        STEP("count = %u", count);
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        count = 0xffffffffu;
        R("adapter_get_count(owned device)", p_cna_graphics_adapter_get_count(a, &count));
        STEP("count = %u", count);
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "events")) {
        CNA_GraphicsDeviceEventRegistrationHandle dreg = CNA_INVALID_HANDLE;
        CNA_GraphicsResourceEventRegistrationHandle rreg1 = CNA_INVALID_HANDLE;
        CNA_GraphicsResourceEventRegistrationHandle rreg2 = CNA_INVALID_HANDLE;
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        R("subscribe device Disposing",
          p_cna_graphics_device_subscribe_event(a, CNA_GRAPHICS_DEVICE_EVENT_DISPOSING,
                                                on_device_disposing, NULL, &dreg));
        R("texture 1 on A", make_texture(a, &tex));
        R("texture 2 on A", make_texture(a, &tex2));
        R("subscribe texture 1 Disposing",
          p_cna_graphics_resource_subscribe_disposing(tex, on_resource_disposing,
                                                      (void *)"texture 1", &rreg1));
        R("subscribe texture 2 Disposing",
          p_cna_graphics_resource_subscribe_disposing(tex2, on_resource_disposing,
                                                      (void *)"texture 2", &rreg2));
        STEP("handles: device=%llu tex1=%llu tex2=%llu", (unsigned long long)a,
             (unsigned long long)tex, (unsigned long long)tex2);
        STEP("--- destroying texture 1 explicitly ---");
        R("texture2d_destroy(tex1)", p_cna_texture2d_destroy(tex));
        STEP("--- destroying the device, texture 2 still live ---");
        R("graphics_device_destroy(A)", p_cna_graphics_device_destroy(a));
        STEP("events so far: %d", event_tick);
        STEP("--- destroying texture 2 after its device is gone ---");
        R("texture2d_destroy(tex2)", p_cna_texture2d_destroy(tex2));
        STEP("events in total: %d", event_tick);
        R("unsubscribe device registration", p_cna_graphics_device_unsubscribe(dreg));
        R("unsubscribe texture 1 registration",
          p_cna_graphics_resource_unsubscribe_disposing(rreg1));
        R("unsubscribe texture 2 registration",
          p_cna_graphics_resource_unsubscribe_disposing(rreg2));
    } else if (!strcmp(stage, "churn")) {
        /* If a transient device is how a no-Game program enumerates adapters,
         * then creating and destroying one repeatedly has to be sound and not
         * ratchet anything. Twenty rounds, reporting only what changes. */
        uint32_t first_count = 0;
        for (int i = 0; i < 20; i++) {
            uint32_t count = 0;
            CNA_Handle d = CNA_INVALID_HANDLE;
            CNA_Result rc = make_device(0, &d);
            CNA_Result rq = p_cna_graphics_adapter_get_count(d, &count);
            CNA_Result rx = p_cna_graphics_device_destroy(d);
            if (i == 0) { first_count = count; STEP("round 0: handle=%llu count=%u",
                                                    (unsigned long long)d, count); }
            if (rc != CNA_RESULT_SUCCESS || rq != CNA_RESULT_SUCCESS ||
                rx != CNA_RESULT_SUCCESS || count != first_count) {
                STEP("round %d DIVERGED: create=%s query=%s destroy=%s count=%u",
                     i, rname(rc), rname(rq), rname(rx), count);
                return 1;
            }
        }
        STEP("20 rounds: create, enumerate (%u adapters) and destroy, all clean",
             first_count);
    } else if (!strcmp(stage, "pixels")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        /* CornflowerBlue, the colour every other pixel lane in this repository
         * uses, so a reader can compare this number with those. */
        R("clear to CornflowerBlue",
          p_cna_graphics_device_clear_rgba(a, 100.f/255.f, 149.f/255.f, 237.f/255.f, 1.f));
        CNA_BackBufferReadback rb;
        memset(&rb, 0, sizeof rb);
        rb.struct_size = (uint32_t)sizeof rb;
        rb.struct_version = 1;
        rb.has_source_rectangle = CNA_FALSE;
        rb.start_index = 0;
        rb.element_count = 64ull * 32ull;
        CNA_Color *pixels = calloc(64ull * 32ull, sizeof *pixels);
        RV("get_backbuffer_data_window",
           p_cna_graphics_device_get_backbuffer_data_window(a, &rb, pixels, 64ull * 32ull), r);
        if (r == CNA_RESULT_SUCCESS) {
            STEP("pixel[0]      = %u %u %u %u", pixels[0].r, pixels[0].g, pixels[0].b, pixels[0].a);
            STEP("pixel[centre] = %u %u %u %u", pixels[16*64+32].r, pixels[16*64+32].g,
                 pixels[16*64+32].b, pixels[16*64+32].a);
            STEP("pixel[last]   = %u %u %u %u", pixels[64*32-1].r, pixels[64*32-1].g,
                 pixels[64*32-1].b, pixels[64*32-1].a);
            uint64_t same = 0;
            for (uint64_t i = 0; i < 64ull*32ull; i++)
                if (pixels[i].r == pixels[0].r && pixels[i].g == pixels[0].g &&
                    pixels[i].b == pixels[0].b && pixels[i].a == pixels[0].a) same++;
            STEP("pixels equal to pixel[0]: %llu of %llu", (unsigned long long)same, 64ull*32ull);
        }
        free(pixels);
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "cross-game")) {
        RV("create standalone O", make_device(0, &hook_owned_device), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        R("texture on O", make_texture(hook_owned_device, &hook_owned_texture));
        CNA_GameCallbacks callbacks;
        memset(&callbacks, 0, sizeof callbacks);
        callbacks.struct_size = (uint32_t)sizeof callbacks;
        callbacks.struct_version = 1;
        callbacks.update = cross_game_update;
        game = make_game_with(&callbacks);
        if (game == CNA_INVALID_HANDLE) return 0;
        R("run_one_frame", p_cna_game_run_one_frame(game));
        STEP("hook ran %d time(s)", hook_ran);
        R("cna_game_destroy", p_cna_game_destroy(game));
        STEP("--- O after the game is gone ---");
        report_device("O", hook_owned_device);
        R("destroy O's texture", p_cna_texture2d_destroy(hook_owned_texture));
        R("destroy O", p_cna_graphics_device_destroy(hook_owned_device));
    } else if (!strcmp(stage, "cross-game-old")) {
        game = make_game();
        if (game == CNA_INVALID_HANDLE) return 0;
        R("run_one_frame", p_cna_game_run_one_frame(game));
        R("game_get_graphics_device", p_cna_game_get_graphics_device(game, &gdev));
        RV("create standalone A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { R("cna_game_destroy", p_cna_game_destroy(game)); return 0; }
        RV("texture on the game device", make_texture(gdev, &tex), r);
        RV("texture on A", make_texture(a, &tex2), r);
        if (tex != CNA_INVALID_HANDLE)
            R("game texture into A  <-- crossing", p_cna_graphics_device_set_texture(a, CNA_SHADER_STAGE_PIXEL, 0u, tex));
        if (tex2 != CNA_INVALID_HANDLE)
            R("A texture into game  <-- crossing", p_cna_graphics_device_set_texture(gdev, CNA_SHADER_STAGE_PIXEL, 0u, tex2));
        if (tex != CNA_INVALID_HANDLE) R("destroy game texture", p_cna_texture2d_destroy(tex));
        if (tex2 != CNA_INVALID_HANDLE) R("destroy A texture", p_cna_texture2d_destroy(tex2));
        R("destroy A", p_cna_graphics_device_destroy(a));
        R("cna_game_destroy", p_cna_game_destroy(game));
    } else if (!strcmp(stage, "destroy-with-child")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        RV("texture on A", make_texture(a, &tex), r);
        report_device("A", a);
        CNA_Bool rdisp = 2;
        R("resource_get_is_disposed BEFORE",
          p_cna_graphics_resource_get_is_disposed(tex, &rdisp));
        STEP("texture is_disposed BEFORE = %d", (int)rdisp);
        R("destroy A with a live texture", p_cna_graphics_device_destroy(a));
        STEP("--- the texture handle after its device died ---");
        rdisp = 2;
        R("resource_get_is_disposed AFTER",
          p_cna_graphics_resource_get_is_disposed(tex, &rdisp));
        STEP("texture is_disposed AFTER  = %d", (int)rdisp);
        CNA_TextureInfo ti; memset(&ti, 0, sizeof ti);
        ti.struct_size = (uint32_t)sizeof ti; ti.struct_version = 1;
        R("texture_get_info on the orphan", p_cna_texture_get_info(tex, &ti));
        STEP("orphan info: levels=%u format=%u", (unsigned)ti.level_count, (unsigned)ti.format);
        R("texture2d_destroy afterwards", p_cna_texture2d_destroy(tex));
        R("texture_get_info after that destroy", p_cna_texture_get_info(tex, &ti));
    } else if (!strcmp(stage, "game-destroy-with-owned")) {
        RV("create standalone A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        RV("texture on A", make_texture(a, &tex), r);
        game = make_game();
        if (game == CNA_INVALID_HANDLE) return 0;
        R("run_one_frame", p_cna_game_run_one_frame(game));
        STEP("--- game_destroy while A and its texture live ---");
        R("cna_game_destroy", p_cna_game_destroy(game));
        STEP("--- A afterwards ---");
        report_device("A", a);
        R("clear A", p_cna_graphics_device_clear_rgba(a, 1.f, 0.f, 0.f, 1.f));
        if (tex != CNA_INVALID_HANDLE) R("A's texture into A", p_cna_graphics_device_set_texture(a, CNA_SHADER_STAGE_PIXEL, 0u, tex));
        if (tex != CNA_INVALID_HANDLE) R("destroy A's texture", p_cna_texture2d_destroy(tex));
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "dispose-route")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        R("cna_graphics_device_dispose(A)", p_cna_graphics_device_dispose(a));
        report_device("A", a);
        R("clear A after dispose", p_cna_graphics_device_clear_rgba(a, 0.f, 0.f, 0.f, 1.f));
        R("destroy A after dispose", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "double-destroy")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        R("destroy A", p_cna_graphics_device_destroy(a));
        R("destroy A again", p_cna_graphics_device_destroy(a));
        R("get_is_disposed on the dead handle",
          p_cna_graphics_device_get_graphics_profile(a, (uint32_t[]){0}));
    } else if (!strcmp(stage, "clear")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        R("clear_rgba outside any callback", p_cna_graphics_device_clear_rgba(a, 0.f, .5f, 1.f, 1.f));
        CNA_Viewport vp; memset(&vp, 0, sizeof vp);
        vp.x = 0; vp.y = 0; vp.width = 32; vp.height = 16;
        vp.min_depth = 0.f; vp.max_depth = 1.f;
        R("set_viewport outside any callback", p_cna_graphics_device_set_viewport(a, vp));
        report_device("A", a);
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "present")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        R("present outside any callback", p_cna_graphics_device_present(a));
        R("destroy A", p_cna_graphics_device_destroy(a));
    } else if (!strcmp(stage, "thread")) {
        RV("create A", make_device(0, &a), r);
        if (r != CNA_RESULT_SUCCESS) { STEP("create refused"); return 0; }
        struct thread_arg arg = { a, 99, 99, 99 };
        pthread_t t;
        pthread_create(&t, NULL, other_thread, &arg);
        pthread_join(t, NULL);
        STEP("other thread: read -> %s (%u)", rname(arg.read), (unsigned)arg.read);
        STEP("other thread: clear -> %s (%u)", rname(arg.clear), (unsigned)arg.clear);
        STEP("other thread: destroy -> %s (%u)", rname(arg.destroy), (unsigned)arg.destroy);
        if (arg.destroy != CNA_RESULT_SUCCESS) R("destroy A on its own thread",
                                                 p_cna_graphics_device_destroy(a));
    } else {
        fprintf(stderr, "unknown stage %s\n", stage);
        return 2;
    }
    STEP("done");
    return 0;
}
