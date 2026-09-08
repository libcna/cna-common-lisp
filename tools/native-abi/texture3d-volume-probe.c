/* texture3d-volume-probe.c --- does a renderer that *claims* volume storage keep
 * the voxels it was given?
 *
 * `texture3d-support-probe.c' asks one question -- can this library create a
 * Texture3D at all -- and on HEADLESS and SOFTWARE the answer is no. That was
 * read for months as "CNA cannot", and it is not what it says: it says *those two
 * renderers* cannot. EasyGL's `GraphicsCapability::Texture3D' is true on every
 * non-ES2 GL profile, so the question has to be asked again of a build that
 * claims the capability before `Texture3D' can be ruled in or out of the
 * selection.
 *
 *   texture3d-volume-probe <library> <stage>
 *
 * One stage per process, the way `owned-device-probe' does it and for the same
 * reason: a stage that faults must name itself rather than take the rest with it.
 * Every step prints a line and flushes, so the parent reads how far the child got
 * even after a signal.
 *
 * Stages:
 *   create       create a 4x3x2 Color volume and read its metadata back
 *   whole        SetData/GetData the whole of level 0, byte for byte
 *   box          SetData/GetData one sub-volume, and prove the rest did not move
 *   mip          a mipmapped 8x4x3 volume: level count, per-level dimensions,
 *                transfers at level 0, 1 and the last, and a refusal past it
 *   depth-levels a mipmapped 2x2x8 volume, where XNA's rule and EasyGL's differ
 *   bytes        the raw-byte upload route, read back as Color
 *   range        the guards: bad level, box outside the level, short array
 *   destroy      destroy the texture, then the device, and answer for both;
 *                then many volumes on one live device, which is the leak test
 *                this renderer can actually take
 *   guards-hidef XNA's constructor guards asked of CNA on the HiDef profile:
 *                zero extents, the profile's maximum volume extent, a format
 *                outside ValidVolumeFormats, and two that are inside it
 *   guards-reach the same on Reach, whose MaxVolumeExtent is 0 in XNA -- so
 *                every Texture3D is NotSupportedException there
 *   overlap      a second GraphicsDevice created **while the first is still
 *                alive**, then a third after the second is destroyed. Works
 *                everywhere, EasyGL included.
 *   churn        a device created after the last one was destroyed -- a *gap*
 *                with no device alive in it. **This stage is expected to fault
 *                on EasyGL** and is here to say so with a signal rather than to
 *                be believed. HEADLESS and SOFTWARE survive it.
 *
 *                Those two together are the rule, and the difference between
 *                them matters: EasyGL is not limited to one device per process,
 *                it cannot bring its video subsystem back up once the last
 *                device has taken it down. So a process that keeps one device
 *                alive throughout can create and destroy as many others as it
 *                likes, which is exactly what the Lisp lane does.
 *
 * The voxel pattern is deliberately nonuniform on every axis --
 *
 *     R = 16 + 40*x    G = 16 + 40*y    B = 16 + 40*z    A = 255
 *
 * -- so that a transposed axis, a reversed slice or a row/slice pitch mistake
 * cannot round-trip successfully by accident.
 */
#define _POSIX_C_SOURCE 200809L

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <CNA/C/cna.h>

/* Every symbol goes through the pointer-to-pointer pun the other probes here
 * use: `void *' to function pointer is not an ISO C conversion. */
#define SYM(name, target) *(void **)(&(target)) = dlsym(lib, name)

static CNA_Result (*device_create)(uint32_t, uint32_t, const CNA_PresentationParameters *, CNA_Handle *);
static CNA_Result (*device_destroy)(CNA_Handle);
static CNA_Result (*pp_init)(CNA_PresentationParameters *);
static CNA_Result (*t3d_create)(CNA_Handle, const CNA_Texture3DCreateInfo *, CNA_Handle *);
static CNA_Result (*t3d_destroy)(CNA_Handle);
static CNA_Result (*t3d_info)(CNA_Handle, CNA_Texture3DInfo *);
static CNA_Result (*t3d_set)(CNA_Handle, const CNA_Texture3DTransfer *, const CNA_Color *, uint64_t);
static CNA_Result (*t3d_get)(CNA_Handle, const CNA_Texture3DTransfer *, CNA_Color *, uint64_t, uint64_t *);
static CNA_Result (*t3d_set_bytes)(CNA_Handle, const CNA_Texture3DTransfer *, const uint8_t *, uint64_t);
static CNA_Result (*t3d_name_bytes)(CNA_Handle, uint64_t *);
static CNA_Result (*t3d_copy_name)(CNA_Handle, char *, uint64_t, uint64_t *);
static uint32_t (*abi_version)(void);

static int failures = 0;

static void ok(const char *what, int passed) {
    printf("  %-46s %s\n", what, passed ? "ok" : "FAIL");
    if (!passed) ++failures;
    fflush(stdout);
}

static void okr(const char *what, CNA_Result result) {
    printf("  %-46s %s (%u)\n", what, result == CNA_RESULT_SUCCESS ? "ok" : "FAIL",
           (unsigned)result);
    if (result != CNA_RESULT_SUCCESS) ++failures;
    fflush(stdout);
}

/* The pattern. Distinct on every axis and never zero, so a voxel left untouched
 * by a partial write is distinguishable from one written with the wrong value. */
static CNA_Color voxel(int x, int y, int z, int salt) {
    CNA_Color c;
    c.r = (uint8_t)(16 + 40 * x + salt);
    c.g = (uint8_t)(16 + 40 * y + salt);
    c.b = (uint8_t)(16 + 40 * z + salt);
    c.a = 255;
    return c;
}

static int same(CNA_Color a, CNA_Color b) {
    return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

static void transfer_init(CNA_Texture3DTransfer *t) {
    memset(t, 0, sizeof *t);
    t->struct_size = (uint32_t)sizeof *t;
    t->struct_version = 1;
}

static void box(CNA_Texture3DTransfer *t, int32_t level,
                int32_t left, int32_t top, int32_t front,
                int32_t right, int32_t bottom, int32_t back,
                uint64_t count) {
    transfer_init(t);
    t->level = level;
    t->left = left; t->top = top; t->front = front;
    t->right = right; t->bottom = bottom; t->back = back;
    t->start_index = 0;
    t->element_count = count;
}

static CNA_Handle make_device(void) {
    CNA_PresentationParameters pp;
    memset(&pp, 0, sizeof pp);
    pp_init(&pp);
    pp.back_buffer_width = 64;
    pp.back_buffer_height = 64;
    CNA_Handle device = CNA_INVALID_HANDLE;
    /* HiDef, because XNA's Reach profile has MaxVolumeExtent 0 and refuses every
     * Texture3D by contract -- a refusal under Reach would be XNA's answer and
     * not this renderer's. */
    CNA_Result r = device_create(0u, CNA_GRAPHICS_PROFILE_HI_DEF, &pp, &device);
    printf("  device create                                  %s (%u)\n",
           r == CNA_RESULT_SUCCESS ? "ok" : "FAIL", (unsigned)r);
    if (r != CNA_RESULT_SUCCESS) { ++failures; return CNA_INVALID_HANDLE; }
    return device;
}

static CNA_Handle make_volume(CNA_Handle device, uint32_t w, uint32_t h, uint32_t d,
                              int mip) {
    CNA_Texture3DCreateInfo ci;
    memset(&ci, 0, sizeof ci);
    ci.struct_size = (uint32_t)sizeof ci;
    ci.struct_version = 1;
    ci.width = w; ci.height = h; ci.depth = d;
    ci.mip_map = mip ? CNA_TRUE : CNA_FALSE;
    ci.format = CNA_SURFACE_FORMAT_COLOR;
    CNA_Handle texture = CNA_INVALID_HANDLE;
    CNA_Result r = t3d_create(device, &ci, &texture);
    printf("  texture3d_create %ux%ux%u mip=%d%*s%s (%u)\n", w, h, d, mip,
           (int)(46 - 33), "", r == CNA_RESULT_SUCCESS ? "ok" : "FAIL", (unsigned)r);
    if (r != CNA_RESULT_SUCCESS) { ++failures; return CNA_INVALID_HANDLE; }
    return texture;
}

static int read_info(CNA_Handle texture, CNA_Texture3DInfo *info) {
    memset(info, 0, sizeof *info);
    info->struct_size = (uint32_t)sizeof *info;
    info->struct_version = 1;
    CNA_Result r = t3d_info(texture, info);
    okr("texture3d_get_info", r);
    return r == CNA_RESULT_SUCCESS;
}

/* --- stages ------------------------------------------------------------- */

/* XNA's constructor guards, asked of CNA so the binding knows which of them it
 * has to apply itself. Every row is reported rather than asserted: what CNA
 * answers is the measurement, and `docs/texture3d-audit.md' says which answers
 * put the guard in the binding. */
static void probe_create(CNA_Handle device, const char *what,
                         uint32_t w, uint32_t h, uint32_t d, uint32_t format) {
    CNA_Texture3DCreateInfo ci;
    memset(&ci, 0, sizeof ci);
    ci.struct_size = (uint32_t)sizeof ci;
    ci.struct_version = 1;
    ci.width = w; ci.height = h; ci.depth = d;
    ci.mip_map = CNA_FALSE;
    ci.format = format;
    CNA_Handle t = CNA_INVALID_HANDLE;
    CNA_Result r = t3d_create(device, &ci, &t);
    printf("  %-44s -> %u %s\n", what, (unsigned)r,
           r == CNA_RESULT_SUCCESS ? "(created)"
           : r == CNA_RESULT_NOT_SUPPORTED ? "(NOT_SUPPORTED)" : "(refused)");
    fflush(stdout);
    if (r == CNA_RESULT_SUCCESS) t3d_destroy(t);
}

static void stage_guards(uint32_t profile) {
    CNA_PresentationParameters pp;
    memset(&pp, 0, sizeof pp);
    pp_init(&pp);
    pp.back_buffer_width = 64;
    pp.back_buffer_height = 64;
    CNA_Handle device = CNA_INVALID_HANDLE;
    CNA_Result r = device_create(0u, profile, &pp, &device);
    printf("  device create, profile %u                       %s (%u)\n",
           profile, r == CNA_RESULT_SUCCESS ? "ok" : "FAIL", (unsigned)r);
    fflush(stdout);
    if (r != CNA_RESULT_SUCCESS) { ++failures; return; }

    /* XNA: ArgumentOutOfRangeException on each of the three. */
    probe_create(device, "width 0", 0, 4, 4, CNA_SURFACE_FORMAT_COLOR);
    probe_create(device, "height 0", 4, 0, 4, CNA_SURFACE_FORMAT_COLOR);
    probe_create(device, "depth 0", 4, 4, 0, CNA_SURFACE_FORMAT_COLOR);
    /* XNA: HiDef MaxVolumeExtent is 256, so 257 is ProfileTooBig; Reach's is 0,
     * so every Texture3D is ProfileFeatureNotSupported there. */
    probe_create(device, "256 cubed (HiDef's exact maximum)", 256, 4, 4,
                 CNA_SURFACE_FORMAT_COLOR);
    probe_create(device, "257 wide (one past HiDef's maximum)", 257, 4, 4,
                 CNA_SURFACE_FORMAT_COLOR);
    /* XNA: HiDef ValidVolumeFormats excludes 4..8 -- Dxt1/3/5, NormalizedByte2/4
     * -- so Dxt1 (4) is ProfileFormatNotSupported even on HiDef. */
    probe_create(device, "Dxt1, not a valid volume format", 8, 8, 8, 4u);
    /* XNA: aspect ratio max(w,h,d)/min(w,h,d) over MaxTextureAspectRatio (2048). */
    probe_create(device, "1x1x64, an ordinary aspect ratio", 1, 1, 64,
                 CNA_SURFACE_FORMAT_COLOR);
    probe_create(device, "Bgr565, a valid volume format", 8, 8, 8, 3u);
    probe_create(device, "Rgba1010102, a valid volume format", 8, 8, 8, 12u);
    okr("graphics_device_destroy", device_destroy(device));
}


static void stage_create(void) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    CNA_Handle texture = make_volume(device, 4, 3, 2, 0);
    if (texture != CNA_INVALID_HANDLE) {
        CNA_Texture3DInfo info;
        if (read_info(texture, &info)) {
            ok("width is 4", info.width == 4);
            ok("height is 3", info.height == 3);
            ok("depth is 2", info.depth == 2);
            ok("level_count is 1 without mipMap", info.level_count == 1);
            ok("format is Color", info.format == CNA_SURFACE_FORMAT_COLOR);
        }
        uint64_t bytes = 0;
        if (t3d_name_bytes && t3d_name_bytes(texture, &bytes) == CNA_RESULT_SUCCESS) {
            char name[128];
            uint64_t written = 0;
            if (bytes < sizeof name
                && t3d_copy_name(texture, name, sizeof name, &written) == CNA_RESULT_SUCCESS) {
                name[written] = '\0';
                ok("type name is the XNA Texture3D name",
                   strcmp(name, CNA_TEXTURE_3D_TYPE_NAME) == 0);
            }
        }
        okr("texture3d_destroy", t3d_destroy(texture));
    }
    okr("graphics_device_destroy", device_destroy(device));
}

static void stage_whole(void) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    CNA_Handle texture = make_volume(device, 4, 3, 2, 0);
    if (texture != CNA_INVALID_HANDLE) {
        enum { W = 4, H = 3, D = 2, N = W * H * D };
        CNA_Color written[N], read[N];
        /* Row-major within a slice, slices in front-to-back order -- the layout
         * XNA's box transfer documents and the one a mistake here would break. */
        for (int z = 0; z < D; ++z)
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x)
                    written[(z * H + y) * W + x] = voxel(x, y, z, 0);

        CNA_Texture3DTransfer t;
        box(&t, 0, 0, 0, 0, W, H, D, N);
        okr("texture3d_set_data, whole level 0", t3d_set(texture, &t, written, N));

        memset(read, 0, sizeof read);
        uint64_t required = 0;
        box(&t, 0, 0, 0, 0, W, H, D, N);
        okr("texture3d_get_data, whole level 0", t3d_get(texture, &t, read, N, &required));
        ok("required element count is the voxel count", required == (uint64_t)N);

        int equal = 1;
        for (int i = 0; i < N; ++i) if (!same(written[i], read[i])) equal = 0;
        ok("every voxel round-tripped byte for byte", equal);
        if (!equal) {
            for (int i = 0; i < N; ++i)
                printf("      [%2d] wrote %3u,%3u,%3u,%3u  read %3u,%3u,%3u,%3u\n", i,
                       written[i].r, written[i].g, written[i].b, written[i].a,
                       read[i].r, read[i].g, read[i].b, read[i].a);
        }
        okr("texture3d_destroy", t3d_destroy(texture));
    }
    okr("graphics_device_destroy", device_destroy(device));
}

static void stage_box(void) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    CNA_Handle texture = make_volume(device, 4, 3, 2, 0);
    if (texture != CNA_INVALID_HANDLE) {
        enum { W = 4, H = 3, D = 2, N = W * H * D };
        CNA_Color base[N], read[N];
        for (int z = 0; z < D; ++z)
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x)
                    base[(z * H + y) * W + x] = voxel(x, y, z, 0);

        CNA_Texture3DTransfer t;
        box(&t, 0, 0, 0, 0, W, H, D, N);
        okr("seed the whole level", t3d_set(texture, &t, base, N));

        /* A sub-volume that touches neither origin nor far corner on any axis
         * where it can avoid it: x in [1,3), y in [1,3), z in [1,2). */
        enum { BX0 = 1, BY0 = 1, BZ0 = 1, BX1 = 3, BY1 = 3, BZ1 = 2 };
        enum { BW = BX1 - BX0, BH = BY1 - BY0, BD = BZ1 - BZ0, BN = BW * BH * BD };
        CNA_Color patch[BN];
        for (int z = 0; z < BD; ++z)
            for (int y = 0; y < BH; ++y)
                for (int x = 0; x < BW; ++x)
                    patch[(z * BH + y) * BW + x] = voxel(x, y, z, 100);

        box(&t, 0, BX0, BY0, BZ0, BX1, BY1, BZ1, BN);
        okr("texture3d_set_data, one sub-volume", t3d_set(texture, &t, patch, BN));

        CNA_Color back[BN];
        memset(back, 0, sizeof back);
        uint64_t required = 0;
        box(&t, 0, BX0, BY0, BZ0, BX1, BY1, BZ1, BN);
        okr("texture3d_get_data, the same sub-volume",
            t3d_get(texture, &t, back, BN, &required));
        ok("required element count is the box voxel count", required == (uint64_t)BN);
        int equal = 1;
        for (int i = 0; i < BN; ++i) if (!same(patch[i], back[i])) equal = 0;
        ok("the sub-volume round-tripped byte for byte", equal);

        /* And the whole level again: inside the box the patch, outside it the
         * seed, untouched. */
        memset(read, 0, sizeof read);
        box(&t, 0, 0, 0, 0, W, H, D, N);
        okr("texture3d_get_data, the whole level again",
            t3d_get(texture, &t, read, N, &required));
        int outside_intact = 1, inside_updated = 1;
        for (int z = 0; z < D; ++z)
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x) {
                    CNA_Color got = read[(z * H + y) * W + x];
                    int in = x >= BX0 && x < BX1 && y >= BY0 && y < BY1
                          && z >= BZ0 && z < BZ1;
                    if (in) {
                        CNA_Color want = voxel(x - BX0, y - BY0, z - BZ0, 100);
                        if (!same(got, want)) inside_updated = 0;
                    } else if (!same(got, base[(z * H + y) * W + x])) {
                        outside_intact = 0;
                    }
                }
        ok("voxels outside the box did not move", outside_intact);
        ok("voxels inside the box carry the patch", inside_updated);
        okr("texture3d_destroy", t3d_destroy(texture));
    }
    okr("graphics_device_destroy", device_destroy(device));
}

/* One mip level's transfer, at the dimensions the level is expected to have. */
static void mip_level(CNA_Handle texture, int level, int w, int h, int d) {
    int n = w * h * d;
    CNA_Color *written = malloc((size_t)n * sizeof *written);
    CNA_Color *read = malloc((size_t)n * sizeof *read);
    if (!written || !read) { free(written); free(read); return; }
    for (int z = 0; z < d; ++z)
        for (int y = 0; y < h; ++y)
            for (int x = 0; x < w; ++x)
                written[(z * h + y) * w + x] = voxel(x, y, z, 7 * level);

    char label[80];
    CNA_Texture3DTransfer t;
    box(&t, level, 0, 0, 0, w, h, d, (uint64_t)n);
    snprintf(label, sizeof label, "set_data level %d (%dx%dx%d)", level, w, h, d);
    okr(label, t3d_set(texture, &t, written, (uint64_t)n));

    memset(read, 0, (size_t)n * sizeof *read);
    uint64_t required = 0;
    box(&t, level, 0, 0, 0, w, h, d, (uint64_t)n);
    snprintf(label, sizeof label, "get_data level %d (%dx%dx%d)", level, w, h, d);
    okr(label, t3d_get(texture, &t, read, (uint64_t)n, &required));

    int equal = 1;
    for (int i = 0; i < n; ++i) if (!same(written[i], read[i])) equal = 0;
    snprintf(label, sizeof label, "level %d round-tripped byte for byte", level);
    ok(label, equal);
    free(written);
    free(read);
}

static void mip_stage(uint32_t w, uint32_t h, uint32_t d) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    CNA_Handle texture = make_volume(device, w, h, d, 1);
    if (texture != CNA_INVALID_HANDLE) {
        CNA_Texture3DInfo info;
        if (read_info(texture, &info)) {
            /* Reported rather than asserted: the two authorities disagree about
             * whether depth participates, and the number CNA answers is the
             * measurement this stage exists to take. */
            printf("  MEASURED level_count = %u for %ux%ux%u\n",
                   info.level_count, w, h, d);
            fflush(stdout);
            unsigned last = info.level_count - 1u;
            for (unsigned level = 0; level < info.level_count; ++level) {
                unsigned lw = w >> level, lh = h >> level, ld = d >> level;
                if (lw < 1) lw = 1;
                if (lh < 1) lh = 1;
                if (ld < 1) ld = 1;
                printf("  MEASURED level %u expected %ux%ux%u\n", level, lw, lh, ld);
                if (level == 0 || level == 1 || level == last)
                    mip_level(texture, (int)level, (int)lw, (int)lh, (int)ld);
            }
            /* One past the last level must be refused rather than written. */
            CNA_Color one = voxel(0, 0, 0, 0);
            CNA_Texture3DTransfer t;
            box(&t, (int32_t)info.level_count, 0, 0, 0, 1, 1, 1, 1);
            CNA_Result r = t3d_set(texture, &t, &one, 1);
            printf("  set_data at level %u (one past the last)   %s (%u)\n",
                   info.level_count, r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
            if (r == CNA_RESULT_SUCCESS) ++failures;
            fflush(stdout);
        }
        okr("texture3d_destroy", t3d_destroy(texture));
    }
    okr("graphics_device_destroy", device_destroy(device));
}

static void stage_bytes(void) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    CNA_Handle texture = make_volume(device, 4, 3, 2, 0);
    if (texture != CNA_INVALID_HANDLE) {
        enum { W = 4, H = 3, D = 2, N = W * H * D };
        uint8_t raw[N * 4];
        CNA_Color expected[N], read[N];
        for (int z = 0; z < D; ++z)
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x) {
                    int i = (z * H + y) * W + x;
                    CNA_Color c = voxel(x, y, z, 3);
                    expected[i] = c;
                    raw[i * 4 + 0] = c.r;
                    raw[i * 4 + 1] = c.g;
                    raw[i * 4 + 2] = c.b;
                    raw[i * 4 + 3] = c.a;
                }
        CNA_Texture3DTransfer t;
        box(&t, 0, 0, 0, 0, W, H, D, 0);   /* element_count is ignored by this route */
        okr("texture3d_set_data_bytes, whole level 0",
            t3d_set_bytes(texture, &t, raw, sizeof raw));

        memset(read, 0, sizeof read);
        uint64_t required = 0;
        box(&t, 0, 0, 0, 0, W, H, D, N);
        okr("texture3d_get_data after the byte upload",
            t3d_get(texture, &t, read, N, &required));
        int equal = 1;
        for (int i = 0; i < N; ++i) if (!same(expected[i], read[i])) equal = 0;
        ok("raw bytes land as the same voxels Color would", equal);

        /* A byte count that is not the region's exact size must be refused. */
        box(&t, 0, 0, 0, 0, W, H, D, 0);
        CNA_Result r = t3d_set_bytes(texture, &t, raw, sizeof raw - 1);
        printf("  set_data_bytes with one byte too few          %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;
        fflush(stdout);
        okr("texture3d_destroy", t3d_destroy(texture));
    }
    okr("graphics_device_destroy", device_destroy(device));
}

static void stage_range(void) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    CNA_Handle texture = make_volume(device, 4, 3, 2, 0);
    if (texture != CNA_INVALID_HANDLE) {
        enum { W = 4, H = 3, D = 2, N = W * H * D };
        CNA_Color data[N];
        for (int i = 0; i < N; ++i) data[i] = voxel(i % W, 0, 0, 0);
        CNA_Texture3DTransfer t;
        CNA_Result r;

        box(&t, 1, 0, 0, 0, W, H, D, N);           /* no level 1 exists */
        r = t3d_set(texture, &t, data, N);
        printf("  set_data at level 1 of a 1-level volume       %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;

        box(&t, 0, 0, 0, 0, W + 1, H, D, (W + 1) * H * D);   /* right past the edge */
        r = t3d_set(texture, &t, data, N);
        printf("  set_data with right past the level width      %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;

        box(&t, 0, 0, 0, 0, W, H, D + 1, W * H * (D + 1));   /* back past the depth */
        r = t3d_set(texture, &t, data, N);
        printf("  set_data with back past the level depth       %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;

        box(&t, 0, 0, 0, 0, W, H, D, N);
        r = t3d_set(texture, &t, data, N - 1);      /* array shorter than the box */
        printf("  set_data with a capacity below the box        %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;

        CNA_Color into[N];
        memset(into, 0xab, sizeof into);
        uint64_t required = 0;
        box(&t, 0, 0, 0, 0, W, H, D, N);
        r = t3d_get(texture, &t, into, N - 1, &required);
        printf("  get_data with a capacity below the box        %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;
        int untouched = 1;
        for (size_t i = 0; i < sizeof into; ++i)
            if (((const uint8_t *)into)[i] != 0xab) untouched = 0;
        ok("a refused get_data left the destination alone", untouched);
        printf("  required elements reported on refusal: %llu\n",
               (unsigned long long)required);
        fflush(stdout);

        okr("texture3d_destroy", t3d_destroy(texture));
    }
    okr("graphics_device_destroy", device_destroy(device));
}

static void stage_destroy(void) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    CNA_Handle texture = make_volume(device, 4, 3, 2, 0);
    if (texture != CNA_INVALID_HANDLE) {
        okr("texture3d_destroy", t3d_destroy(texture));
        CNA_Texture3DInfo info;
        memset(&info, 0, sizeof info);
        info.struct_size = (uint32_t)sizeof info;
        info.struct_version = 1;
        CNA_Result r = t3d_info(texture, &info);
        printf("  get_info on a destroyed handle                %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;
        r = t3d_destroy(texture);
        printf("  texture3d_destroy a second time               %s (%u)\n",
               r == CNA_RESULT_SUCCESS ? "FAIL" : "ok", (unsigned)r);
        if (r == CNA_RESULT_SUCCESS) ++failures;
    }
    okr("graphics_device_destroy", device_destroy(device));
}

/* Thirty-two volumes made and destroyed on one live device. A handle table that
 * leaked or a GL name that was never freed would show here, and this is the
 * teardown churn EasyGL can actually take -- see `stage_churn'. */
static void stage_volumes(void) {
    CNA_Handle device = make_device();
    if (device == CNA_INVALID_HANDLE) return;
    int cycles = 0;
    for (int i = 0; i < 32; ++i) {
        CNA_Texture3DCreateInfo ci;
        memset(&ci, 0, sizeof ci);
        ci.struct_size = (uint32_t)sizeof ci;
        ci.struct_version = 1;
        ci.width = 8; ci.height = 8; ci.depth = 8;
        ci.mip_map = CNA_TRUE;
        ci.format = CNA_SURFACE_FORMAT_COLOR;
        CNA_Handle t = CNA_INVALID_HANDLE;
        if (t3d_create(device, &ci, &t) != CNA_RESULT_SUCCESS) break;
        CNA_Color one = voxel(1, 2, 3, 0);
        CNA_Texture3DTransfer tr;
        box(&tr, 0, 0, 0, 0, 1, 1, 1, 1);
        if (t3d_set(t, &tr, &one, 1) != CNA_RESULT_SUCCESS) break;
        if (t3d_destroy(t) != CNA_RESULT_SUCCESS) break;
        ++cycles;
    }
    ok("32 mipmapped volumes made, written and destroyed", cycles == 32);
    okr("graphics_device_destroy", device_destroy(device));
}

/* A device created after the last one was destroyed. Reported rather than
 * asserted: on EasyGL this faults, and a fault is the measurement. The exit
 * status is what the matrix script reads. */
static void stage_churn(void) {
    for (int i = 0; i < 4; ++i) {
        printf("  cycle %d: creating a device with none alive\n", i);
        fflush(stdout);
        CNA_Handle d = make_device();
        if (d == CNA_INVALID_HANDLE) return;
        printf("  cycle %d: destroying it\n", i);
        fflush(stdout);
        okr("graphics_device_destroy", device_destroy(d));
    }
    printf("  four device cycles survived in one process\n");
    fflush(stdout);
}

/* The same churn with **one device kept alive throughout**. This is the shape
 * the Lisp lane uses, and the reason it can use the ordinary public API on a
 * renderer that cannot survive `stage_churn': the subsystem never comes down,
 * so nothing has to bring it back up. */
static void stage_overlap(void) {
    CNA_Handle keep = make_device();
    if (keep == CNA_INVALID_HANDLE) return;
    int cycles = 0;
    for (int i = 0; i < 4; ++i) {
        CNA_Handle d = make_device();
        if (d == CNA_INVALID_HANDLE) break;
        CNA_Handle t = make_volume(d, 4, 3, 2, 0);
        if (t == CNA_INVALID_HANDLE) break;
        if (t3d_destroy(t) != CNA_RESULT_SUCCESS) break;
        if (device_destroy(d) != CNA_RESULT_SUCCESS) break;
        ++cycles;
    }
    ok("four devices and volumes came and went beside a live one", cycles == 4);
    okr("the kept device is still usable", t3d_destroy(make_volume(keep, 2, 2, 2, 0)));
    okr("graphics_device_destroy (the kept one, last)", device_destroy(keep));
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: texture3d-volume-probe <library> <stage>\n");
        return 2;
    }
    void *lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!lib) { printf("dlopen: %s\n", dlerror()); return 1; }

    SYM("cna_graphics_device_create", device_create);
    SYM("cna_graphics_device_destroy", device_destroy);
    SYM("cna_presentation_parameters_init", pp_init);
    SYM("cna_texture3d_create", t3d_create);
    SYM("cna_texture3d_destroy", t3d_destroy);
    SYM("cna_texture3d_get_info", t3d_info);
    SYM("cna_texture3d_set_data", t3d_set);
    SYM("cna_texture3d_get_data", t3d_get);
    SYM("cna_texture3d_set_data_bytes", t3d_set_bytes);
    SYM("cna_texture3d_get_type_name_byte_count", t3d_name_bytes);
    SYM("cna_texture3d_copy_type_name", t3d_copy_name);
    SYM("cna_get_abi_version", abi_version);

    if (!device_create || !t3d_create || !t3d_set || !t3d_get || !t3d_info) {
        printf("MISSING symbols\n");
        return 1;
    }

    printf("ABI %u  stage %s\n", abi_version ? abi_version() : 0u, argv[2]);
    fflush(stdout);

    const char *stage = argv[2];
    if (strcmp(stage, "create") == 0) stage_create();
    else if (strcmp(stage, "whole") == 0) stage_whole();
    else if (strcmp(stage, "box") == 0) stage_box();
    else if (strcmp(stage, "mip") == 0) mip_stage(8, 4, 3);
    else if (strcmp(stage, "depth-levels") == 0) mip_stage(2, 2, 8);
    else if (strcmp(stage, "bytes") == 0) stage_bytes();
    else if (strcmp(stage, "range") == 0) stage_range();
    else if (strcmp(stage, "destroy") == 0) stage_destroy();
    else if (strcmp(stage, "volumes") == 0) stage_volumes();
    else if (strcmp(stage, "churn") == 0) stage_churn();
    else if (strcmp(stage, "overlap") == 0) stage_overlap();
    else if (strcmp(stage, "guards-hidef") == 0) stage_guards(CNA_GRAPHICS_PROFILE_HI_DEF);
    else if (strcmp(stage, "guards-reach") == 0) stage_guards(CNA_GRAPHICS_PROFILE_REACH);
    else { fprintf(stderr, "unknown stage %s\n", stage); return 2; }

    printf("STAGE %s: %d failure(s)\n", stage, failures);
    fflush(stdout);
    return failures == 0 ? 0 : 1;
}
