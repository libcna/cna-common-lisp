/* video-player-probe.c --- what does CNA's VideoPlayer actually do?
 *
 *   cc -O1 -I "$CNA_HEADERS" -o build-probe/video-player-probe \
 *      tools/native-abi/video-player-probe.c -ldl
 *   video-player-probe <library> <stage> <fixture-directory>
 *
 * **Measurement only, and of CNA and not of XNA.** Nothing here is evidence
 * about what `Microsoft.Xna.Framework.Media.VideoPlayer' does; the pinned IL is
 * the authority for that. What this answers is whether CNA's player can be
 * driven at all, and with what observable behaviour -- which is the question
 * that decides whether the namespace is worth importing.
 *
 * `video-capability-probe.c' already established that `cna_video_create'
 * succeeds and reports real metadata on every admitted ABI. That is one member
 * of two types. This probe is the rest.
 *
 * **One stage per process**, the way `texture3d-volume-probe' does it: a stage
 * that faults names itself instead of taking the others with it. Every step
 * prints and flushes, so the parent reads how far the child got even after a
 * signal.
 *
 * **Everything runs inside a lifecycle callback**, and that is forced rather
 * than stylistic: `cna_video_create' takes a graphics device, and a device
 * handle is callback-scoped -- `cna_game_get_graphics_device' says so and
 * answers CNA_RESULT_INVALID_STATE outside one. So the probe creates a game,
 * runs one frame, and does the whole stage inside that frame's update.
 *
 * **The clock is a wall clock.** CNA's player advances its position from
 * `std::chrono` and decodes on demand inside `GetTexture', so a stage that wants
 * playback to advance has to actually wait. Timing assertions here are bounded
 * windows and never exact microseconds.
 *
 * Stages:
 *   metadata   every fixture format: create, read back the five metadata fields
 *   state      the transport: initial state, Play, Pause, Resume, Stop, and the
 *              position and video presence at each
 *   frame      Play, wait, GetTexture, read the pixels back, check the pattern
 *   advance    two frames far enough apart to be different sections, by the
 *              frame generation and by the pixels
 *   lifetime   the borrowed frame handle: what an unrelated getter does to it,
 *              and what a second GetTexture does to the first
 *   identity   get_video after Play(A) then Play(B), and after Stop
 *   eof        a non-looped video played past its own duration
 *   loop       the same with looping on
 *   props      the property matrix, including volume's boundaries and NaN
 *   failure    the undecodable fixture: create, Play, and what is left behind
 *   dispose    dispose with playback active, and what the old handles do
 *   thread     the same operations from a thread that did not create the game
 */
#define _POSIX_C_SOURCE 200809L

#include <dlfcn.h>
#include <math.h>
#include <stdarg.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <CNA/C/cna.h>

#define SYM(name, target) *(void **)(&(target)) = dlsym(lib, name)

static CNA_Result (*game_create)(const CNA_GameCreateInfo *, CNA_Handle *);
static CNA_Result (*game_destroy)(CNA_Handle);
static CNA_Result (*game_run_one_frame)(CNA_Handle);
static CNA_Result (*game_request_exit)(CNA_Handle);
static CNA_Result (*game_get_device)(CNA_Handle, CNA_Handle *);

static CNA_Result (*v_create)(CNA_Handle, CNA_StringView, CNA_Handle *);
static CNA_Result (*v_create_meta)(CNA_Handle, CNA_StringView, int32_t, int32_t, int32_t,
                                   float, CNA_VideoSoundtrackType, CNA_Handle *);
static CNA_Result (*v_destroy)(CNA_Handle);
static CNA_Result (*v_width)(CNA_Handle, int32_t *);
static CNA_Result (*v_height)(CNA_Handle, int32_t *);
static CNA_Result (*v_fps)(CNA_Handle, float *);
static CNA_Result (*v_duration)(CNA_Handle, int64_t *);
static CNA_Result (*v_soundtrack)(CNA_Handle, CNA_VideoSoundtrackType *);
static CNA_Result (*v_has_device)(CNA_Handle, CNA_Bool *);
static CNA_Result (*v_name_size)(CNA_Handle, uint64_t *);
static CNA_Result (*v_copy_name)(CNA_Handle, char *, uint64_t, uint64_t *);

static CNA_Result (*p_create)(CNA_Handle, CNA_Handle *);
static CNA_Result (*p_destroy)(CNA_Handle);
static CNA_Result (*p_dispose)(CNA_Handle);
static CNA_Result (*p_play)(CNA_Handle, CNA_Handle);
static CNA_Result (*p_pause)(CNA_Handle);
static CNA_Result (*p_resume)(CNA_Handle);
static CNA_Result (*p_stop)(CNA_Handle);
static CNA_Result (*p_state)(CNA_Handle, CNA_MediaState *);
static CNA_Result (*p_position)(CNA_Handle, int64_t *);
static CNA_Result (*p_get_video)(CNA_Handle, CNA_Handle *, CNA_Bool *);
static CNA_Result (*p_get_texture)(CNA_Handle, CNA_Handle *, CNA_Bool *);
static CNA_Result (*p_get_frame)(CNA_Handle, CNA_VideoFrameEXT *);
static CNA_Result (*p_get_disposed)(CNA_Handle, CNA_Bool *);
static CNA_Result (*p_get_looped)(CNA_Handle, CNA_Bool *);
static CNA_Result (*p_set_looped)(CNA_Handle, CNA_Bool);
static CNA_Result (*p_get_muted)(CNA_Handle, CNA_Bool *);
static CNA_Result (*p_set_muted)(CNA_Handle, CNA_Bool);
static CNA_Result (*p_get_volume)(CNA_Handle, float *);
static CNA_Result (*p_set_volume)(CNA_Handle, float);

static CNA_Result (*t2d_get_data)(CNA_Handle, CNA_TextureDataType,
                                  const CNA_Texture2DTransfer *, void *, uint64_t, uint64_t *);
static CNA_Result (*tex_info)(CNA_Handle, CNA_TextureInfo *);
static CNA_Result (*res_disposed)(CNA_Handle, CNA_Bool *);
static uint32_t (*abi_version)(void);

static const char *stage;
static const char *fixtures;
static int failures;

static void note(const char *what, const char *fmt, ...)
{
    char buffer[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buffer, sizeof buffer, fmt, ap);
    va_end(ap);
    printf("  %-44s %s\n", what, buffer);
    fflush(stdout);
}

static void ok(const char *what, int passed)
{
    printf("  %-44s %s\n", what, passed ? "ok" : "FAIL");
    if (!passed) ++failures;
    fflush(stdout);
}

static const char *state_name(CNA_MediaState s)
{
    switch (s) {
    case CNA_MEDIA_STATE_STOPPED: return "Stopped";
    case CNA_MEDIA_STATE_PLAYING: return "Playing";
    case CNA_MEDIA_STATE_PAUSED:  return "Paused";
    default: return "?";
    }
}

static void nap(double seconds)
{
    struct timespec ts;
    ts.tv_sec = (time_t)seconds;
    ts.tv_nsec = (long)((seconds - (double)ts.tv_sec) * 1e9);
    nanosleep(&ts, NULL);
}

static double now_seconds(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static char *fixture_path(const char *name)
{
    static char buffer[4096];
    snprintf(buffer, sizeof buffer, "%s/%s", fixtures, name);
    return buffer;
}

static CNA_StringView view(const char *text)
{
    CNA_StringView v;
    v.data = text;
    v.byte_length = strlen(text);
    return v;
}

/* ---------------------------------------------------------------- the pattern
 *
 * The fixture's geometry, repeated here so the probe asserts against the
 * definition rather than against whatever came back. `make-video-fixture.py' is
 * the other copy and the two must agree.
 */
#define FW 64
#define FH 48
static const struct { const char *name; int r, g, b; int mx, my; } SECTION[4] = {
    { "red",    1, 0, 0,  7,  5 },
    { "green",  0, 1, 0, 56,  5 },
    { "blue",   0, 0, 1,  7, 41 },
    { "yellow", 1, 1, 0, 56, 41 },
};

/* Which section do these pixels look like?  -1 when nothing matches, which is
 * the answer that must never be silently turned into a section. */
static int classify(const CNA_Color *px, uint64_t count)
{
    if (count < (uint64_t)(FW * FH)) return -2;
    const CNA_Color field = px[4 * FW + 32];              /* top middle, always field */
    const CNA_Color centre = px[24 * FW + 32];            /* the black anchor */
    if (!(centre.r < 90 && centre.g < 90 && centre.b < 90)) return -3;
    for (int s = 0; s < 4; ++s) {
        const int wants_r = SECTION[s].r, wants_g = SECTION[s].g, wants_b = SECTION[s].b;
        const int has_r = field.r > 128, has_g = field.g > 128, has_b = field.b > 128;
        if (has_r != wants_r || has_g != wants_g || has_b != wants_b) continue;
        const CNA_Color marker = px[SECTION[s].my * FW + SECTION[s].mx];
        if (marker.r > 170 && marker.g > 170 && marker.b > 170) return s;
    }
    return -1;
}

/* Read the whole of a texture's level 0, and say how many texels that was. */
static CNA_Result read_pixels(CNA_Handle texture, CNA_Color *out, uint64_t capacity,
                              uint64_t *out_count)
{
    CNA_Texture2DTransfer t;
    memset(&t, 0, sizeof t);
    t.struct_size = (uint32_t)sizeof t;
    t.struct_version = 1;
    t.level = 0;
    t.has_rectangle = CNA_FALSE;
    t.start_index = 0;
    t.element_count = capacity;
    return t2d_get_data(texture, CNA_TEXTURE_DATA_COLOR, &t, out, capacity, out_count);
}

/* --------------------------------------------------------------- the stages */

struct context {
    CNA_Handle game;
    int ran;
};

static CNA_Handle make_video(CNA_Handle device, const char *name, CNA_Result *out)
{
    CNA_Handle video = CNA_INVALID_HANDLE;
    *out = v_create(device, view(fixture_path(name)), &video);
    return video;
}

static void stage_metadata(CNA_Handle device)
{
    static const char *names[] = { "fixture.wmv", "fixture.ogv", "fixture.mp4",
                                   "undecodable.wmv", "missing.wmv" };
    for (unsigned i = 0; i < sizeof names / sizeof *names; ++i) {
        CNA_Result r;
        CNA_Handle video = make_video(device, names[i], &r);
        if (r != CNA_RESULT_SUCCESS) {
            note(names[i], "create -> %u", (unsigned)r);
            continue;
        }
        int32_t w = -1, h = -1;
        float fps = -1.0f;
        int64_t ticks = -1;
        CNA_VideoSoundtrackType soundtrack = 99;
        CNA_Bool bound = CNA_FALSE;
        v_width(video, &w); v_height(video, &h); v_fps(video, &fps);
        v_duration(video, &ticks); v_soundtrack(video, &soundtrack);
        v_has_device(video, &bound);
        note(names[i], "%dx%d  %.3f fps  %.3f s  soundtrack=%u  device=%d",
             w, h, (double)fps, (double)ticks / 1e7, (unsigned)soundtrack, (int)bound);
        uint64_t need = 0;
        if (v_name_size && v_name_size(video, &need) == CNA_RESULT_SUCCESS) {
            char *buffer = calloc(1, need + 1);
            uint64_t got = 0;
            v_copy_name(video, buffer, need, &got);
            note("  file name", "%s", buffer);
            free(buffer);
        }
        v_destroy(video);
    }
}

static void stage_state(CNA_Handle game, CNA_Handle device)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, "fixture.wmv", &r);
    ok("video create", r == CNA_RESULT_SUCCESS);
    CNA_Handle player = CNA_INVALID_HANDLE;
    r = p_create(game, &player);
    ok("player create", r == CNA_RESULT_SUCCESS);
    if (r != CNA_RESULT_SUCCESS) return;

    CNA_MediaState s = 99;
    int64_t ticks = -1;
    CNA_Handle got = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_TRUE;
    p_state(player, &s);          note("initial State", "%s", state_name(s));
    p_position(player, &ticks);   note("initial PlayPosition", "%lld ticks", (long long)ticks);
    r = p_get_video(player, &got, &available);
    note("initial Video", "result=%u available=%d", (unsigned)r, (int)available);

    r = p_play(player, video);
    note("Play", "result=%u", (unsigned)r);
    p_state(player, &s);          note("State after Play", "%s", state_name(s));

    int64_t first = -1, second = -1;
    p_position(player, &first);
    const double t0 = now_seconds();
    nap(0.30);
    p_position(player, &second);
    const double waited = now_seconds() - t0;
    note("PlayPosition advance", "%lld -> %lld ticks over %.3f s",
         (long long)first, (long long)second, waited);
    ok("position advanced while playing", second > first);
    ok("advance is within a wall-clock window",
       (double)(second - first) / 1e7 > waited * 0.5 &&
       (double)(second - first) / 1e7 < waited * 1.5 + 0.05);

    r = p_pause(player);
    note("Pause", "result=%u", (unsigned)r);
    p_state(player, &s);          note("State after Pause", "%s", state_name(s));
    int64_t paused_a = -1, paused_b = -1;
    p_position(player, &paused_a);
    nap(0.20);
    p_position(player, &paused_b);
    note("paused PlayPosition", "%lld -> %lld", (long long)paused_a, (long long)paused_b);
    ok("position stable while paused", paused_a == paused_b);

    r = p_resume(player);
    note("Resume", "result=%u", (unsigned)r);
    p_state(player, &s);          note("State after Resume", "%s", state_name(s));
    nap(0.20);
    int64_t resumed = -1;
    p_position(player, &resumed);
    note("resumed PlayPosition", "%lld", (long long)resumed);
    ok("position continues after resume", resumed > paused_b);

    r = p_stop(player);
    note("Stop", "result=%u", (unsigned)r);
    p_state(player, &s);          note("State after Stop", "%s", state_name(s));
    p_position(player, &ticks);   note("PlayPosition after Stop", "%lld ticks", (long long)ticks);
    available = CNA_TRUE;
    p_get_video(player, &got, &available);
    note("Video after Stop", "available=%d", (int)available);

    /* The transport methods on a stopped player: XNA's guards are the question,
     * and what CNA does is what this records. */
    note("Pause when stopped", "result=%u", (unsigned)p_pause(player));
    p_state(player, &s); note("  State", "%s", state_name(s));
    note("Resume when stopped", "result=%u", (unsigned)p_resume(player));
    p_state(player, &s); note("  State", "%s", state_name(s));
    note("Stop when stopped", "result=%u", (unsigned)p_stop(player));

    p_destroy(player);
    v_destroy(video);
}

static void stage_frame(CNA_Handle game, CNA_Handle device, const char *fixture)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, fixture, &r);
    ok("video create", r == CNA_RESULT_SUCCESS);
    if (r != CNA_RESULT_SUCCESS) return;
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);

    CNA_Handle texture = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_FALSE;
    r = p_get_texture(player, &texture, &available);
    note("GetTexture before Play", "result=%u available=%d", (unsigned)r, (int)available);

    r = p_play(player, video);
    note("Play", "result=%u", (unsigned)r);
    if (r != CNA_RESULT_SUCCESS) { p_destroy(player); v_destroy(video); return; }

    available = CNA_FALSE;
    r = p_get_texture(player, &texture, &available);
    note("GetTexture after Play", "result=%u available=%d handle=%llu",
         (unsigned)r, (int)available, (unsigned long long)texture);
    ok("a frame texture exists", available == CNA_TRUE && texture != CNA_INVALID_HANDLE);
    if (available != CNA_TRUE) { p_destroy(player); v_destroy(video); return; }

    CNA_TextureInfo info;
    memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info;
    info.struct_version = 1;
    r = tex_info(texture, &info);
    note("frame texture info", "result=%u levels=%u format=%u",
         (unsigned)r, (unsigned)info.level_count, (unsigned)info.format);

    /* **A capacity of zero is refused rather than answered.** The route
     * documents `out_required_elements' as the count written for the region,
     * and a null destination is CNA_RESULT_INVALID_ARGUMENT with that left at
     * zero -- so it cannot be used to ask a Texture2D its size without reading
     * it. That matters beyond this probe: CNA has no width/height route for a
     * Texture2D at all, so the element count a full read reports is the only
     * measurement of a frame's size available anywhere. */
    uint64_t required = 0;
    r = read_pixels(texture, NULL, 0, &required);
    note("frame texel count, capacity 0", "result=%u required=%llu",
         (unsigned)r, (unsigned long long)required);

    CNA_Color *pixels = calloc(FW * FH, sizeof *pixels);
    uint64_t written = 0;
    r = read_pixels(texture, pixels, FW * FH, &written);
    note("pixel readback", "result=%u written=%llu (64x48 = %d)",
         (unsigned)r, (unsigned long long)written, FW * FH);
    ok("frame is the video's 64x48", written == (uint64_t)(FW * FH));
    if (r == CNA_RESULT_SUCCESS) {
        const int section = classify(pixels, written);
        note("classified section", "%d (%s)", section,
             section >= 0 ? SECTION[section].name :
             section == -1 ? "no section matched" :
             section == -3 ? "centre anchor missing" : "too few texels");
        ok("the first frame is section 0 (red)", section == 0);
        const CNA_Color f = pixels[4 * FW + 32];
        note("  field pixel (32,4)", "%u,%u,%u,%u", f.r, f.g, f.b, f.a);
        const CNA_Color m = pixels[5 * FW + 7];
        note("  marker pixel (7,5)", "%u,%u,%u,%u", m.r, m.g, m.b, m.a);
        const CNA_Color c = pixels[24 * FW + 32];
        note("  centre pixel (32,24)", "%u,%u,%u,%u", c.r, c.g, c.b, c.a);
    }
    free(pixels);
    p_destroy(player);
    v_destroy(video);
}

static void stage_advance(CNA_Handle game, CNA_Handle device, const char *fixture)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, fixture, &r);
    if (r != CNA_RESULT_SUCCESS) { ok("video create", 0); return; }
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);
    p_play(player, video);

    CNA_Color *pixels = calloc(FW * FH, sizeof *pixels);
    int seen[4] = { 0, 0, 0, 0 };
    uint64_t generations[8];
    int sections[8];
    int samples = 0;

    /* One sample in the middle of each half-second section. The fixture's four
     * sections are the whole reason two frames can be told apart for a reason
     * rather than by inequality. */
    for (int i = 0; i < 4 && samples < 8; ++i) {
        const double target = 0.25 + 0.5 * i;
        while (1) {
            int64_t ticks = 0;
            p_position(player, &ticks);
            if ((double)ticks / 1e7 >= target) break;
            nap(0.02);
        }
        CNA_VideoFrameEXT frame;
        memset(&frame, 0, sizeof frame);
        frame.struct_size = (uint32_t)sizeof frame;
        frame.struct_version = 1;
        CNA_Handle texture = CNA_INVALID_HANDLE;
        CNA_Bool available = CNA_FALSE;
        p_get_texture(player, &texture, &available);
        if (available != CNA_TRUE) { note("sample", "no frame at %.2f s", target); continue; }
        uint64_t written = 0;
        if (read_pixels(texture, pixels, FW * FH, &written) != CNA_RESULT_SUCCESS) continue;
        const int section = classify(pixels, written);
        /* get_frame_ext is asked *after* the pixels, because it is itself a call
         * on the player and would invalidate the handle just read. */
        uint64_t generation = 0;
        if (p_get_frame && p_get_frame(player, &frame) == CNA_RESULT_SUCCESS) {
            generation = frame.generation;
            note("sample", "t~%.2f s  section=%d (%s)  generation=%llu  pts=%.3f",
                 target, section,
                 section >= 0 ? SECTION[section].name : "unmatched",
                 (unsigned long long)generation, frame.presentation_time);
        } else {
            note("sample", "t~%.2f s  section=%d", target, section);
        }
        if (section >= 0) seen[section] = 1;
        generations[samples] = generation;
        sections[samples] = section;
        ++samples;
    }
    free(pixels);

    ok("four distinct sections were decoded",
       seen[0] && seen[1] && seen[2] && seen[3]);
    int monotonic = 1, differ = 0;
    for (int i = 1; i < samples; ++i) {
        if (generations[i] < generations[i - 1]) monotonic = 0;
        if (generations[i] != generations[i - 1]) differ = 1;
        if (sections[i] != sections[i - 1]) differ = 1;
    }
    ok("frame generation never went backwards", monotonic);
    ok("the frame actually advanced", differ);
    p_destroy(player);
    v_destroy(video);
}

static void stage_lifetime(CNA_Handle game, CNA_Handle device)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, "fixture.wmv", &r);
    if (r != CNA_RESULT_SUCCESS) { ok("video create", 0); return; }
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);
    p_play(player, video);
    nap(0.10);

    /* A real buffer, so that "usable" means the pixels came back and not merely
     * that the handle survived argument validation. The two failures are told
     * apart by their codes: INVALID_HANDLE is a dead handle, and anything else
     * is a live handle refusing for another reason. */
    CNA_Color *pixels = calloc(FW * FH, sizeof *pixels);
    uint64_t written = 0;

#define USABLE(handle) read_pixels((handle), pixels, FW * FH, &written)
#define VERDICT(code) ((code) == CNA_RESULT_SUCCESS ? "usable" : \
                       (code) == CNA_RESULT_INVALID_HANDLE ? "INVALID_HANDLE" : "other failure")

    CNA_Handle first = CNA_INVALID_HANDLE, second = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_FALSE;
    p_get_texture(player, &first, &available);
    note("texture1", "handle=%llu available=%d", (unsigned long long)first, (int)available);

    r = USABLE(first);
    note("texture1 straight away", "result=%u %s written=%llu",
         (unsigned)r, VERDICT(r), (unsigned long long)written);
    ok("a fresh frame handle reads its pixels", r == CNA_RESULT_SUCCESS);
    const int section_one = classify(pixels, written);

    /* One unrelated getter on the same player. The header says the handle is
     * valid only until the next call *on this player* -- this is whether that
     * means literally any call, or only another GetTexture. */
    CNA_MediaState s;
    p_state(player, &s);
    r = USABLE(first);
    note("texture1 after get_state", "result=%u %s", (unsigned)r, VERDICT(r));
    ok("an unrelated getter invalidates the frame handle",
       r == CNA_RESULT_INVALID_HANDLE);

    p_get_texture(player, &second, &available);
    note("texture2", "handle=%llu same-as-first=%d",
         (unsigned long long)second, (int)(second == first));
    r = USABLE(second);
    note("texture2 straight away", "result=%u %s", (unsigned)r, VERDICT(r));
    const int section_two = classify(pixels, written);
    note("sections", "texture1=%d texture2=%d", section_one, section_two);

    CNA_Handle third = CNA_INVALID_HANDLE;
    p_get_texture(player, &third, &available);
    r = USABLE(second);
    note("texture2 after a third GetTexture", "result=%u %s", (unsigned)r, VERDICT(r));
    ok("a later GetTexture invalidates the earlier handle",
       r == CNA_RESULT_INVALID_HANDLE);
    note("handles are distinct each time", "%llu %llu %llu",
         (unsigned long long)first, (unsigned long long)second,
         (unsigned long long)third);

    p_pause(player);
    r = USABLE(third);
    note("texture3 after Pause", "result=%u %s", (unsigned)r, VERDICT(r));
    p_resume(player);

    CNA_Handle fourth = CNA_INVALID_HANDLE;
    p_get_texture(player, &fourth, &available);
    p_stop(player);
    r = USABLE(fourth);
    note("a frame handle after Stop", "result=%u %s", (unsigned)r, VERDICT(r));

    CNA_Handle after_stop = CNA_INVALID_HANDLE;
    available = CNA_TRUE;
    r = p_get_texture(player, &after_stop, &available);
    note("GetTexture after Stop", "result=%u available=%d", (unsigned)r, (int)available);

#undef USABLE
#undef VERDICT
    free(pixels);
    p_destroy(player);
    v_destroy(video);
}

static void stage_identity(CNA_Handle game, CNA_Handle device)
{
    CNA_Result ra, rb;
    CNA_Handle a = make_video(device, "fixture.wmv", &ra);
    CNA_Handle b = make_video(device, "fixture.mp4", &rb);
    ok("both videos created", ra == CNA_RESULT_SUCCESS && rb == CNA_RESULT_SUCCESS);
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);

    CNA_Handle got = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_FALSE;
    p_play(player, a);
    p_get_video(player, &got, &available);
    note("after Play(A)", "available=%d same-as-A=%d", (int)available, (int)(got == a));
    ok("get_video is A", available == CNA_TRUE && got == a);

    got = CNA_INVALID_HANDLE;
    p_play(player, b);
    p_get_video(player, &got, &available);
    note("after Play(B)", "available=%d same-as-B=%d", (int)available, (int)(got == b));
    ok("get_video is B", available == CNA_TRUE && got == b);

    p_stop(player);
    available = CNA_TRUE;
    got = CNA_INVALID_HANDLE;
    p_get_video(player, &got, &available);
    note("after Stop", "available=%d", (int)available);

    /* Destroying a video the player is no longer playing must be allowed; the
     * header says destroy requires no player still playing it. */
    note("destroy B after Stop", "result=%u", (unsigned)v_destroy(b));
    note("destroy A", "result=%u", (unsigned)v_destroy(a));
    p_destroy(player);
}

static void stage_eof(CNA_Handle game, CNA_Handle device, int looped)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, "fixture.wmv", &r);
    if (r != CNA_RESULT_SUCCESS) { ok("video create", 0); return; }
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);
    if (looped) {
        note("set IsLooped", "result=%u", (unsigned)p_set_looped(player, CNA_TRUE));
        CNA_Bool back = CNA_FALSE;
        p_get_looped(player, &back);
        ok("IsLooped reads back true", back == CNA_TRUE);
    }
    p_play(player, video);

    /* The fixture is 2.000 s. Wait past it, sampling so the decoder is driven. */
    CNA_Color *pixels = calloc(FW * FH, sizeof *pixels);
    const double deadline = now_seconds() + 3.2;
    int last_section = -9;
    int restarted = 0;
    int seen_after_end = 0;
    while (now_seconds() < deadline) {
        nap(0.10);
        CNA_Handle texture = CNA_INVALID_HANDLE;
        CNA_Bool available = CNA_FALSE;
        if (p_get_texture(player, &texture, &available) != CNA_RESULT_SUCCESS) continue;
        if (available != CNA_TRUE) continue;
        uint64_t written = 0;
        if (read_pixels(texture, pixels, FW * FH, &written) != CNA_RESULT_SUCCESS) continue;
        const int section = classify(pixels, written);
        int64_t ticks = 0;
        p_position(player, &ticks);
        if ((double)ticks / 1e7 > 2.05) seen_after_end = 1;
        if (last_section == 3 && section == 0) restarted = 1;
        last_section = section;
    }
    free(pixels);

    CNA_MediaState s = 99;
    int64_t ticks = -1;
    CNA_Handle got = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_FALSE;
    p_state(player, &s);
    p_position(player, &ticks);
    p_get_video(player, &got, &available);
    note("after 3.2 s of a 2.0 s video", "State=%s position=%.3f s video=%d",
         state_name(s), (double)ticks / 1e7, (int)available);
    note("last section seen", "%d", last_section);
    note("crossed the duration boundary", "%d", seen_after_end);
    note("frame sequence restarted", "%d", restarted);

    CNA_Handle texture = CNA_INVALID_HANDLE;
    available = CNA_FALSE;
    r = p_get_texture(player, &texture, &available);
    note("GetTexture at that point", "result=%u available=%d", (unsigned)r, (int)available);

    if (looped) {
        ok("a looped player is still playing", s == CNA_MEDIA_STATE_PLAYING);
        ok("a looped player restarted the sequence", restarted);
    }

    /* Replay the same video afterwards. */
    r = p_play(player, video);
    note("replay the same Video", "result=%u", (unsigned)r);
    p_state(player, &s);
    note("State after replay", "%s", state_name(s));

    p_stop(player);
    p_destroy(player);
    v_destroy(video);
}

static void stage_props(CNA_Handle game, CNA_Handle device)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, "fixture.wmv", &r);
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);

    CNA_Bool flag = CNA_TRUE;
    float volume = -1.0f;
    p_get_disposed(player, &flag); note("initial IsDisposed", "%d", (int)flag);
    p_get_looped(player, &flag);   note("initial IsLooped", "%d", (int)flag);
    p_get_muted(player, &flag);    note("initial IsMuted", "%d", (int)flag);
    p_get_volume(player, &volume); note("initial Volume", "%.6f", (double)volume);

    static const float probes[] = { 0.0f, 1.0f, 0.5f, -0.001f, 1.001f, -5.0f, 5.0f };
    for (unsigned i = 0; i < sizeof probes / sizeof *probes; ++i) {
        r = p_set_volume(player, probes[i]);
        p_get_volume(player, &volume);
        note("Volume set", "%+.4f -> result=%u  reads back %.6f",
             (double)probes[i], (unsigned)r, (double)volume);
    }
    r = p_set_volume(player, NAN);
    p_get_volume(player, &volume);
    note("Volume set NaN", "result=%u  reads back %.6f (isnan=%d)",
         (unsigned)r, (double)volume, isnan(volume));
    r = p_set_volume(player, INFINITY);
    p_get_volume(player, &volume);
    note("Volume set +inf", "result=%u  reads back %.6f", (unsigned)r, (double)volume);
    r = p_set_volume(player, -INFINITY);
    p_get_volume(player, &volume);
    note("Volume set -inf", "result=%u  reads back %.6f", (unsigned)r, (double)volume);
    p_set_volume(player, 1.0f);

    p_set_muted(player, CNA_TRUE);  p_get_muted(player, &flag);
    note("IsMuted true", "reads back %d", (int)flag);
    p_set_looped(player, CNA_TRUE); p_get_looped(player, &flag);
    note("IsLooped true", "reads back %d", (int)flag);

    /* The same properties while playing, and after disposal. */
    if (r == CNA_RESULT_SUCCESS || 1) {
        p_play(player, video);
        p_get_volume(player, &volume); note("Volume while playing", "%.6f", (double)volume);
        p_get_muted(player, &flag);    note("IsMuted while playing", "%d", (int)flag);
        p_stop(player);
    }

    note("Dispose", "result=%u", (unsigned)p_dispose(player));
    p_get_disposed(player, &flag); note("IsDisposed after Dispose", "%d", (int)flag);
    note("State after Dispose", "result=%u", (unsigned)p_state(player, (CNA_MediaState[1]){0}));
    note("Volume after Dispose", "result=%u", (unsigned)p_get_volume(player, &volume));
    note("set Volume after Dispose", "result=%u", (unsigned)p_set_volume(player, 0.5f));
    note("Play after Dispose", "result=%u", (unsigned)p_play(player, video));
    CNA_Handle texture = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_FALSE;
    note("GetTexture after Dispose", "result=%u",
         (unsigned)p_get_texture(player, &texture, &available));
    note("Dispose twice", "result=%u", (unsigned)p_dispose(player));

    p_destroy(player);
    v_destroy(video);
}

static void stage_failure(CNA_Handle game, CNA_Handle device)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, "undecodable.wmv", &r);
    note("create undecodable", "result=%u handle=%llu", (unsigned)r, (unsigned long long)video);
    if (r != CNA_RESULT_SUCCESS) return;
    int32_t w = -1, h = -1;
    float fps = -1.0f;
    int64_t ticks = -1;
    v_width(video, &w); v_height(video, &h); v_fps(video, &fps); v_duration(video, &ticks);
    note("its metadata", "%dx%d %.3f fps %.3f s", w, h, (double)fps, (double)ticks / 1e7);
    ok("undecodable metadata is zeroed", w == 0 && h == 0);

    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);
    r = p_play(player, video);
    note("Play an undecodable video", "result=%u", (unsigned)r);
    CNA_MediaState s = 99;
    p_state(player, &s);
    note("State after that Play", "%s", state_name(s));
    CNA_Handle got = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_TRUE;
    p_get_video(player, &got, &available);
    note("Video after that Play", "available=%d", (int)available);
    CNA_Handle texture = CNA_INVALID_HANDLE;
    available = CNA_TRUE;
    note("GetTexture after that Play", "result=%u available=%d",
         (unsigned)p_get_texture(player, &texture, &available), (int)available);
    ok("a failed Play leaves the player stopped", s == CNA_MEDIA_STATE_STOPPED);

    /* A path that does not exist at all. */
    CNA_Handle missing = CNA_INVALID_HANDLE;
    r = v_create(device, view(fixture_path("no-such-file.wmv")), &missing);
    note("create a missing path", "result=%u", (unsigned)r);

    p_destroy(player);
    v_destroy(video);
}

static void stage_dispose(CNA_Handle game, CNA_Handle device)
{
    CNA_Result r;
    CNA_Handle video = make_video(device, "fixture.wmv", &r);
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);
    p_play(player, video);
    nap(0.15);
    CNA_Handle texture = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_FALSE;
    p_get_texture(player, &texture, &available);
    uint64_t count = 0;
    note("frame before Dispose", "available=%d readback=%u",
         (int)available, (unsigned)read_pixels(texture, NULL, 0, &count));

    note("Dispose while playing", "result=%u", (unsigned)p_dispose(player));
    CNA_Bool flag = CNA_FALSE;
    p_get_disposed(player, &flag);   note("IsDisposed", "%d", (int)flag);
    CNA_MediaState s = 99;
    note("State", "result=%u", (unsigned)p_state(player, &s));
    CNA_Handle got = CNA_INVALID_HANDLE;
    available = CNA_TRUE;
    note("Video", "result=%u available=%d",
         (unsigned)p_get_video(player, &got, &available), (int)available);
    note("the old frame handle", "readback result=%u",
         (unsigned)read_pixels(texture, NULL, 0, &count));

    /* The Video must have survived the player: a player references the video it
     * plays, it does not adopt it. */
    int32_t w = -1;
    r = v_width(video, &w);
    note("the Video after player Dispose", "get_width result=%u value=%d", (unsigned)r, w);
    ok("the Video outlived the player", r == CNA_RESULT_SUCCESS && w == FW);
    note("destroy the Video", "result=%u", (unsigned)v_destroy(video));
    p_destroy(player);
}

/* ------------------------------------------------------------- wrong thread */

struct thread_work {
    CNA_Handle player;
    CNA_Handle video;
    CNA_Result state, play, texture, dispose, volume;
};

static void *thread_body(void *raw)
{
    struct thread_work *w = raw;
    CNA_MediaState s;
    CNA_Handle texture = CNA_INVALID_HANDLE;
    CNA_Bool available = CNA_FALSE;
    float volume = 0.0f;
    w->state = p_state(w->player, &s);
    w->volume = p_get_volume(w->player, &volume);
    w->play = p_play(w->player, w->video);
    w->texture = p_get_texture(w->player, &texture, &available);
    w->dispose = p_dispose(w->player);
    return NULL;
}

static void stage_thread(CNA_Handle game, CNA_Handle device)
{
    CNA_Result r;
    struct thread_work work;
    memset(&work, 0, sizeof work);
    work.video = make_video(device, "fixture.wmv", &r);
    CNA_Handle player = CNA_INVALID_HANDLE;
    p_create(game, &player);
    work.player = player;

    pthread_t thread;
    pthread_create(&thread, NULL, thread_body, &work);
    pthread_join(thread, NULL);

    note("State from another thread", "result=%u", (unsigned)work.state);
    note("Volume from another thread", "result=%u", (unsigned)work.volume);
    note("Play from another thread", "result=%u", (unsigned)work.play);
    note("GetTexture from another thread", "result=%u", (unsigned)work.texture);
    note("Dispose from another thread", "result=%u", (unsigned)work.dispose);

    CNA_MediaState s = 99;
    p_state(player, &s);
    note("State on the owning thread afterwards", "%s", state_name(s));
    p_destroy(player);
    v_destroy(work.video);
}

/* ------------------------------------------------------------------ the game */

static CNA_Result run_stage(CNA_Handle game, const CNA_GameTime *time,
                            void *raw, CNA_CallbackError *error)
{
    struct context *ctx = raw;
    (void)game; (void)time; (void)error;
    if (ctx->ran) return CNA_RESULT_SUCCESS;
    ctx->ran = 1;

    CNA_Handle device = CNA_INVALID_HANDLE;
    const CNA_Result r = game_get_device(ctx->game, &device);
    printf("  %-44s result=%u handle=%llu\n", "graphics device (callback-scoped)",
           (unsigned)r, (unsigned long long)device);
    fflush(stdout);
    if (r != CNA_RESULT_SUCCESS) { ++failures; return CNA_RESULT_SUCCESS; }

    if      (!strcmp(stage, "metadata")) stage_metadata(device);
    else if (!strcmp(stage, "state"))    stage_state(ctx->game, device);
    else if (!strcmp(stage, "frame"))    stage_frame(ctx->game, device, "fixture.wmv");
    else if (!strcmp(stage, "frame-ogv"))stage_frame(ctx->game, device, "fixture.ogv");
    else if (!strcmp(stage, "frame-mp4"))stage_frame(ctx->game, device, "fixture.mp4");
    else if (!strcmp(stage, "advance"))  stage_advance(ctx->game, device, "fixture.wmv");
    else if (!strcmp(stage, "lifetime")) stage_lifetime(ctx->game, device);
    else if (!strcmp(stage, "identity")) stage_identity(ctx->game, device);
    else if (!strcmp(stage, "eof"))      stage_eof(ctx->game, device, 0);
    else if (!strcmp(stage, "loop"))     stage_eof(ctx->game, device, 1);
    else if (!strcmp(stage, "props"))    stage_props(ctx->game, device);
    else if (!strcmp(stage, "failure"))  stage_failure(ctx->game, device);
    else if (!strcmp(stage, "dispose"))  stage_dispose(ctx->game, device);
    else if (!strcmp(stage, "thread"))   stage_thread(ctx->game, device);
    else { fprintf(stderr, "unknown stage %s\n", stage); ++failures; }

    game_request_exit(ctx->game);
    return CNA_RESULT_SUCCESS;
}

int main(int argc, char **argv)
{
    if (argc < 4) {
        fprintf(stderr, "usage: %s <library> <stage> <fixture-directory>\n", argv[0]);
        return 2;
    }
    stage = argv[2];
    fixtures = argv[3];

    void *lib = dlopen(argv[1], RTLD_NOW);
    if (!lib) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }

    SYM("cna_game_create", game_create);
    SYM("cna_game_destroy", game_destroy);
    SYM("cna_game_run_one_frame", game_run_one_frame);
    SYM("cna_game_request_exit", game_request_exit);
    SYM("cna_game_get_graphics_device", game_get_device);
    SYM("cna_video_create", v_create);
    SYM("cna_video_create_with_metadata", v_create_meta);
    SYM("cna_video_destroy", v_destroy);
    SYM("cna_video_get_width", v_width);
    SYM("cna_video_get_height", v_height);
    SYM("cna_video_get_frames_per_second", v_fps);
    SYM("cna_video_get_duration", v_duration);
    SYM("cna_video_get_soundtrack_type", v_soundtrack);
    SYM("cna_video_get_has_graphics_device", v_has_device);
    SYM("cna_video_get_file_name_size", v_name_size);
    SYM("cna_video_copy_file_name", v_copy_name);
    SYM("cna_video_player_create", p_create);
    SYM("cna_video_player_destroy", p_destroy);
    SYM("cna_video_player_dispose", p_dispose);
    SYM("cna_video_player_play", p_play);
    SYM("cna_video_player_pause", p_pause);
    SYM("cna_video_player_resume", p_resume);
    SYM("cna_video_player_stop", p_stop);
    SYM("cna_video_player_get_state", p_state);
    SYM("cna_video_player_get_play_position_ticks", p_position);
    SYM("cna_video_player_get_video", p_get_video);
    SYM("cna_video_player_get_texture", p_get_texture);
    SYM("cna_video_player_get_frame_ext", p_get_frame);
    SYM("cna_video_player_get_is_disposed", p_get_disposed);
    SYM("cna_video_player_get_is_looped", p_get_looped);
    SYM("cna_video_player_set_is_looped", p_set_looped);
    SYM("cna_video_player_get_is_muted", p_get_muted);
    SYM("cna_video_player_set_is_muted", p_set_muted);
    SYM("cna_video_player_get_volume", p_get_volume);
    SYM("cna_video_player_set_volume", p_set_volume);
    SYM("cna_texture2d_get_data", t2d_get_data);
    SYM("cna_texture_get_info", tex_info);
    SYM("cna_graphics_resource_get_is_disposed", res_disposed);
    SYM("cna_get_abi_version", abi_version);

    if (!game_create || !v_create || !p_create || !p_play || !p_get_texture || !t2d_get_data) {
        fprintf(stderr, "the library is missing routes this probe needs\n");
        return 3;
    }

    printf("[%s] library=%s abi=%u\n", stage, argv[1],
           abi_version ? abi_version() : 0u);
    fflush(stdout);

    struct context ctx;
    memset(&ctx, 0, sizeof ctx);

    CNA_GameCallbacks callbacks;
    memset(&callbacks, 0, sizeof callbacks);
    callbacks.struct_size = (uint32_t)sizeof callbacks;
    callbacks.struct_version = 1;
    callbacks.update = run_stage;
    callbacks.context = &ctx;

    CNA_GameCreateInfo info;
    memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info;
    info.struct_version = 1;
    info.is_fixed_time_step = CNA_FALSE;
    /* Positive, because the header requires it: a zero target elapsed time is
       CNA_RESULT_INVALID_ARGUMENT and was this probe's first mistake. */
    info.target_elapsed_time_ticks = 166667;
    info.window_title = view("video-player-probe");
    info.callbacks = &callbacks;

    CNA_Handle game = CNA_INVALID_HANDLE;
    CNA_Result r = game_create(&info, &game);
    printf("  %-44s result=%u\n", "game create", (unsigned)r);
    fflush(stdout);
    if (r != CNA_RESULT_SUCCESS) return 1;
    ctx.game = game;

    for (int i = 0; i < 3 && !ctx.ran; ++i) {
        r = game_run_one_frame(game);
        if (r != CNA_RESULT_SUCCESS) {
            printf("  %-44s result=%u\n", "run_one_frame", (unsigned)r);
            fflush(stdout);
            break;
        }
    }
    game_destroy(game);

    printf("[%s] failures=%d\n", stage, failures);
    fflush(stdout);
    return failures == 0 ? 0 : 1;
}
