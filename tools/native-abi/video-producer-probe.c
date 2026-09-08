/* video-producer-probe.c --- can a C caller obtain an XNA `Video' the way an XNA
 * program does?
 *
 *   cc -O1 -I "$CNA_HEADERS" -o build-probe/video-producer-probe \
 *      tools/native-abi/video-producer-probe.c -ldl
 *   video-producer-probe <library> <content-root> <asset-name>
 *
 * **This is the producer half of the Video question, and it is the half that
 * decides whether the namespace can be bound at all.** `video-player-probe'
 * establishes that CNA's `VideoPlayer' plays a `Video' and hands back real
 * decoded frames. That is worth nothing to a *binding* unless a program can get
 * a `Video' through the object model XNA actually publishes -- and XNA's `Video'
 * has no public constructor. Its only public producer is
 * `ContentManager.Load<Video>', through the private
 * `Microsoft.Xna.Framework.Content.VideoReader'.
 *
 * So the question this asks is not "does cna_video_create work" -- it does --
 * but "is there any route in this ABI that a `Load<Video>' can be built on".
 * It tries every one that could be:
 *
 *   1. a typed loader, the way Texture2D, Model, SpriteFont and the rest have
 *   2. `cna_content_manager_load_foreign_ext' against a real Video .xnb, which
 *      is the only route that reaches a reader from outside
 *   3. registering a caller-supplied reader under the canonical VideoReader
 *      name, which is what a binding would have to do to parse the payload
 *      itself
 *
 * A negative answer here is a *result*, not a failure of the probe: it says the
 * blocker is a missing C route and names which one.
 */
#define _POSIX_C_SOURCE 200809L

#include <dlfcn.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CNA/C/cna.h>

#define SYM(name, target) *(void **)(&(target)) = dlsym(lib, name)

static void *lib;

static CNA_Result (*game_create)(const CNA_GameCreateInfo *, CNA_Handle *);
static CNA_Result (*game_destroy)(CNA_Handle);
static CNA_Result (*game_run_one_frame)(CNA_Handle);
static CNA_Result (*game_request_exit)(CNA_Handle);
static CNA_Result (*game_get_device)(CNA_Handle, CNA_Handle *);

static CNA_Result (*cm_create)(CNA_Handle, const CNA_ContentManagerCreateInfo *, CNA_Handle *);
static CNA_Result (*cm_destroy)(CNA_Handle);
static CNA_Result (*cm_builtins)(CNA_Handle);
static CNA_Result (*cm_load_foreign)(CNA_Handle, CNA_StringView, void **);
static CNA_Result (*cm_load_texture2d)(CNA_Handle, CNA_StringView, CNA_Handle *);
static CNA_Result (*cm_unload)(CNA_Handle);
static CNA_Result (*reader_is_registered)(CNA_StringView, CNA_Bool *);
static CNA_Result (*reader_register)(CNA_StringView, const CNA_ContentTypeReaderCallbacks *,
                                     CNA_Handle *);
static CNA_Result (*reader_unregister)(CNA_Handle);
static uint32_t (*abi_version)(void);

static const char *content_root;
static const char *asset_name;

static void note(const char *what, const char *fmt, ...)
{
    char buffer[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buffer, sizeof buffer, fmt, ap);
    va_end(ap);
    printf("  %-46s %s\n", what, buffer);
    fflush(stdout);
}

/* The message behind the last result. An `IO' from `load_foreign_ext' covers a
 * missing file, a malformed asset and a reader that refused, and only the
 * message tells them apart -- which is the difference between "the fixture is
 * wrong" and "this route will never produce a Video". */
static void why(void)
{
    CNA_Result (*size_of)(uint64_t *) = NULL;
    CNA_Result (*copy)(char *, uint64_t, uint64_t *) = NULL;
    SYM("cna_error_get_last_message_size", size_of);
    SYM("cna_error_copy_last_message", copy);
    if (!size_of || !copy) return;
    uint64_t need = 0;
    if (size_of(&need) != CNA_RESULT_SUCCESS || need == 0) return;
    char *buffer = calloc(1, need + 1);
    uint64_t got = 0;
    if (copy(buffer, need, &got) == CNA_RESULT_SUCCESS)
        printf("  %-46s %s\n", "  because", buffer);
    fflush(stdout);
    free(buffer);
}

static CNA_StringView view(const char *text)
{
    CNA_StringView v;
    v.data = text;
    v.byte_length = strlen(text);
    return v;
}

/* Every route name a `Load<Video>' could plausibly hide behind. A binding must
 * not invent one, so the first thing to establish is that none is exported. */
static void survey_routes(void)
{
    static const char *candidates[] = {
        "cna_content_manager_load_video",
        "cna_content_manager_load_video_ext",
        "cna_content_manager_load_song",
        "cna_content_manager_load_media",
        "cna_video_create_from_content",
        "cna_video_create_from_asset",
        "cna_content_manager_load_video_with_metadata",
    };
    int found = 0;
    for (unsigned i = 0; i < sizeof candidates / sizeof *candidates; ++i) {
        void *symbol = dlsym(lib, candidates[i]);
        note(candidates[i], symbol ? "EXPORTED" : "absent");
        if (symbol) ++found;
    }
    note("content routes that produce a Video", "%d", found);

    /* For contrast: the typed loaders that do exist. A member is bindable when
     * its type is on this list and not when it is not. */
    static const char *typed[] = {
        "cna_content_manager_load_texture2d", "cna_content_manager_load_texture_cube",
        "cna_content_manager_load_sprite_font", "cna_content_manager_load_model",
        "cna_content_manager_load_effect", "cna_content_manager_load_sound_effect",
    };
    char line[512];
    line[0] = '\0';
    for (unsigned i = 0; i < sizeof typed / sizeof *typed; ++i) {
        if (dlsym(lib, typed[i])) {
            strncat(line, typed[i] + strlen("cna_content_manager_load_"),
                    sizeof line - strlen(line) - 2);
            strncat(line, " ", sizeof line - strlen(line) - 2);
        }
    }
    note("the typed loaders that do exist", "%s", line);
}

/* ------------------------------- a caller-supplied reader, to see how far one
 * can get. It records what it was able to read and returns a failure, because
 * the point is the measurement and not the object. */
struct reader_record {
    int created;
    int read_called;
    CNA_Result last;
};
static struct reader_record record;

static CNA_Result reader_create(void *context, void **out_reader_context)
{
    record.created = 1;
    *out_reader_context = context;
    return CNA_RESULT_SUCCESS;
}

static CNA_Result reader_read(void *reader_context, CNA_Handle reader,
                              void *existing_object, void **out_object)
{
    (void)reader_context; (void)existing_object;
    record.read_called = 1;

    /* What can a caller-supplied reader actually read out of the payload? XNA's
     * VideoReader needs ReadObject<string> then four ReadObject<int32> and one
     * ReadObject<float32>. Ask the ABI for each of those. */
    static const char *wanted[] = {
        "cna_content_reader_read_string", "cna_content_reader_read_int32",
        "cna_content_reader_read_single", "cna_content_reader_read_object",
        "cna_content_reader_read_7bit_encoded_int",
    };
    for (unsigned i = 0; i < sizeof wanted / sizeof *wanted; ++i)
        note(wanted[i], dlsym(lib, wanted[i]) ? "EXPORTED" : "absent");

    CNA_Result (*read_bytes)(CNA_Handle, int32_t, CNA_StringView, uint8_t *, uint64_t,
                             uint64_t *) = NULL;
    SYM("cna_content_reader_read_bytes_exact", read_bytes);
    if (read_bytes) {
        uint8_t buffer[64];
        uint64_t got = 0;
        const CNA_Result r = read_bytes(reader, 8, view("probe"), buffer, sizeof buffer, &got);
        note("read_bytes_exact(8) inside the reader", "result=%u got=%llu",
             (unsigned)r, (unsigned long long)got);
        record.last = r;
    }
    *out_object = NULL;
    return CNA_RESULT_NOT_SUPPORTED;   /* deliberately fail the load */
}

static void probe_registration(void)
{
    const CNA_StringView name = view("Microsoft.Xna.Framework.Content.VideoReader");
    CNA_Bool registered = CNA_FALSE;
    if (reader_is_registered) {
        const CNA_Result r = reader_is_registered(name, &registered);
        note("VideoReader already registered by CNA", "result=%u registered=%d",
             (unsigned)r, (int)registered);
    }
    if (!reader_register) { note("register route", "absent"); return; }

    CNA_ContentTypeReaderCallbacks callbacks;
    memset(&callbacks, 0, sizeof callbacks);
    callbacks.struct_size = (uint32_t)sizeof callbacks;
    callbacks.struct_version = 1;
    callbacks.target_type_name = view("Microsoft.Xna.Framework.Media.Video");
    callbacks.create = reader_create;
    callbacks.read = reader_read;
    callbacks.context = &record;

    CNA_Handle registration = CNA_INVALID_HANDLE;
    const CNA_Result r = reader_register(name, &callbacks, &registration);
    note("register a caller reader under that name", "result=%u", (unsigned)r);
    if (r == CNA_RESULT_SUCCESS && reader_unregister) reader_unregister(registration);
}

static void run(CNA_Handle game)
{
    CNA_Handle device = CNA_INVALID_HANDLE;
    if (game_get_device(game, &device) != CNA_RESULT_SUCCESS) {
        note("graphics device", "unavailable");
        return;
    }

    CNA_ContentManagerCreateInfo info;
    memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info;
    info.struct_version = 1;
    info.root_directory = view(content_root);

    CNA_Handle manager = CNA_INVALID_HANDLE;
    CNA_Result r = cm_create(device, &info, &manager);
    note("content manager create", "result=%u", (unsigned)r);
    if (r != CNA_RESULT_SUCCESS) return;
    if (cm_builtins) note("register builtin loaders", "result=%u", (unsigned)cm_builtins(manager));

    probe_registration();

    /* **Is the asset even found?** An `IO' result covers a missing file and a
     * reader that refused alike, so the manifest has to be read before the
     * refusal below can be attributed to anything. */
    CNA_Result (*refresh)(CNA_Handle) = NULL;
    CNA_Result (*entry_count)(CNA_Handle, uint64_t *) = NULL;
    SYM("cna_content_manager_refresh_content_manifest", refresh);
    SYM("cna_content_manager_get_manifest_entry_count", entry_count);
    if (refresh) note("refresh content manifest", "result=%u", (unsigned)refresh(manager));
    if (entry_count) {
        uint64_t count = 0;
        const CNA_Result cr = entry_count(manager, &count);
        note("assets discovered under the root", "result=%u count=%llu",
             (unsigned)cr, (unsigned long long)count);
    }

    /* The mechanism itself, proved on a name CNA does *not* own. If a
     * caller-supplied reader can be registered and reached at all, this is
     * where it shows -- and the Video refusal above is then about Video and not
     * about the route. */
    if (reader_register && cm_load_foreign) {
        CNA_ContentTypeReaderCallbacks own;
        memset(&own, 0, sizeof own);
        own.struct_size = (uint32_t)sizeof own;
        own.struct_version = 1;
        own.target_type_name = view("CnaLisp.Probe.Custom");
        own.create = reader_create;
        own.read = reader_read;
        own.context = &record;
        CNA_Handle registration = CNA_INVALID_HANDLE;
        const CNA_Result rr = reader_register(view("CnaLisp.Probe.CustomReader"), &own,
                                              &registration);
        note("register under a name CNA does not own", "result=%u", (unsigned)rr);
        if (rr == CNA_RESULT_SUCCESS) {
            void *object = NULL;
            const CNA_Result lr = cm_load_foreign(manager, view("custom"), &object);
            note("load_foreign_ext on an asset naming it", "result=%u read-callback-ran=%d",
                 (unsigned)lr, record.read_called);
            why();
            if (reader_unregister) reader_unregister(registration);
        }
    }

    if (cm_load_foreign) {
        void *missing = NULL;
        const CNA_Result mr = cm_load_foreign(manager, view("no-such-asset"), &missing);
        note("load_foreign_ext on a name with no file", "result=%u", (unsigned)mr);
        why();
    }

    if (cm_load_foreign) {
        void *object = NULL;
        r = cm_load_foreign(manager, view(asset_name), &object);
        note("load_foreign_ext on a Video .xnb", "result=%u object=%p",
             (unsigned)r, object);
        why();
        note("  what a caller could do with it", "%s",
             object ? "an opaque void*, not a CNA_VideoHandle" : "nothing was produced");
    }

    /* And for contrast, that the content manager is otherwise working: a
     * texture load from the same root fails with IO rather than with confusion. */
    if (cm_load_texture2d) {
        CNA_Handle texture = CNA_INVALID_HANDLE;
        r = cm_load_texture2d(manager, view(asset_name), &texture);
        note("the same asset asked for as a Texture2D", "result=%u", (unsigned)r);
    }

    if (cm_unload) note("content unload", "result=%u", (unsigned)cm_unload(manager));
    cm_destroy(manager);
}

static int ran;
static CNA_Handle the_game;

static CNA_Result on_update(CNA_Handle game, const CNA_GameTime *time,
                            void *context, CNA_CallbackError *error)
{
    (void)game; (void)time; (void)context; (void)error;
    if (ran) return CNA_RESULT_SUCCESS;
    ran = 1;
    run(the_game);
    game_request_exit(the_game);
    return CNA_RESULT_SUCCESS;
}

int main(int argc, char **argv)
{
    if (argc < 4) {
        fprintf(stderr, "usage: %s <library> <content-root> <asset-name>\n", argv[0]);
        return 2;
    }
    content_root = argv[2];
    asset_name = argv[3];

    lib = dlopen(argv[1], RTLD_NOW);
    if (!lib) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }

    SYM("cna_game_create", game_create);
    SYM("cna_game_destroy", game_destroy);
    SYM("cna_game_run_one_frame", game_run_one_frame);
    SYM("cna_game_request_exit", game_request_exit);
    SYM("cna_game_get_graphics_device", game_get_device);
    SYM("cna_content_manager_create", cm_create);
    SYM("cna_content_manager_destroy", cm_destroy);
    SYM("cna_content_manager_register_builtin_loaders", cm_builtins);
    SYM("cna_content_manager_load_foreign_ext", cm_load_foreign);
    SYM("cna_content_manager_load_texture2d", cm_load_texture2d);
    SYM("cna_content_manager_unload", cm_unload);
    SYM("cna_content_type_reader_manager_get_is_registered", reader_is_registered);
    SYM("cna_content_type_reader_manager_register", reader_register);
    SYM("cna_content_type_reader_manager_unregister", reader_unregister);
    SYM("cna_get_abi_version", abi_version);

    printf("[producer] library=%s abi=%u\n", argv[1], abi_version ? abi_version() : 0u);
    fflush(stdout);
    survey_routes();

    CNA_GameCallbacks callbacks;
    memset(&callbacks, 0, sizeof callbacks);
    callbacks.struct_size = (uint32_t)sizeof callbacks;
    callbacks.struct_version = 1;
    callbacks.update = on_update;

    CNA_GameCreateInfo info;
    memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info;
    info.struct_version = 1;
    info.target_elapsed_time_ticks = 166667;
    info.window_title = view("video-producer-probe");
    info.callbacks = &callbacks;

    CNA_Handle game = CNA_INVALID_HANDLE;
    const CNA_Result r = game_create(&info, &game);
    note("game create", "result=%u", (unsigned)r);
    if (r != CNA_RESULT_SUCCESS) return 1;
    the_game = game;
    for (int i = 0; i < 3 && !ran; ++i)
        if (game_run_one_frame(game) != CNA_RESULT_SUCCESS) break;
    game_destroy(game);
    return 0;
}
