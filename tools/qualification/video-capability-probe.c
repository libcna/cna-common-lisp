/* fp-video-probe.c --- is Video positively qualifiable on an admitted ABI?
 *
 *   cc -O0 -o build-probe/video-capability-probe tools/qualification/video-capability-probe.c -ldl
 *   build-probe/video-capability-probe <libcna_c_api.so> <video-file>
 *
 * Measurement only. `cna_video_create' answers CNA_RESULT_NOT_SUPPORTED when CNA
 * was built without its optional decoder, so the answer to "does the admitted
 * build have FFmpeg" is one call away. A file that exists but cannot be decoded
 * is documented as *not* an error: the metadata stays zero. So the discriminating
 * evidence is the metadata, not the result code alone.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <dlfcn.h>

typedef struct { const char* data; uint64_t byte_length; } StringView;
typedef uint32_t (*init_fn)(void*);
typedef uint32_t (*devcreate_fn)(uint32_t, uint32_t, void*, uint64_t*);
typedef uint32_t (*devdestroy_fn)(uint64_t);
typedef uint32_t (*vcreate_fn)(uint64_t, StringView, uint64_t*);
typedef uint32_t (*vint_fn)(uint64_t, int32_t*);
typedef uint32_t (*vflt_fn)(uint64_t, float*);
typedef uint32_t (*vi64_fn)(uint64_t, int64_t*);
typedef uint32_t (*vdestroy_fn)(uint64_t);

#define SYM(t,n) t n = (t)dlsym(h, #n); if (!n) { printf("[missing] %s\n", #n); return 3; }

int main(int argc, char** argv)
{
    if (argc < 3) { fprintf(stderr, "usage: %s <so> <video>\n", argv[0]); return 2; }
    void* h = dlopen(argv[1], RTLD_NOW);
    if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }

    SYM(init_fn,       cna_presentation_parameters_init)
    SYM(devcreate_fn,  cna_graphics_device_create)
    SYM(devdestroy_fn, cna_graphics_device_destroy)
    SYM(vcreate_fn,    cna_video_create)
    SYM(vint_fn,       cna_video_get_width)
    SYM(vint_fn,       cna_video_get_height)
    SYM(vflt_fn,       cna_video_get_frames_per_second)
    SYM(vi64_fn,       cna_video_get_duration)
    SYM(vdestroy_fn,   cna_video_destroy)

    unsigned char params[64]; memset(params, 0, sizeof params);
    uint32_t r = cna_presentation_parameters_init(params);
    uint64_t device = 0;
    r = cna_graphics_device_create(0, 0 /* Reach */, params, &device);
    printf("[device_create] result=%u handle=%llu\n", r, (unsigned long long)device);
    if (r != 0) return 1;

    StringView name = { argv[2], strlen(argv[2]) };
    uint64_t video = 0;
    r = cna_video_create(device, name, &video);
    printf("[video_create] result=%u  (3 == NOT_SUPPORTED means no decoder)\n", r);

    if (r == 0 && video != 0) {
        int32_t w = -1, ht = -1; float fps = -1; int64_t ticks = -1;
        cna_video_get_width(video, &w);
        cna_video_get_height(video, &ht);
        cna_video_get_frames_per_second(video, &fps);
        cna_video_get_duration(video, &ticks);
        printf("[metadata] width=%d height=%d fps=%.3f duration_ticks=%lld (%.3f s)\n",
               w, ht, fps, (long long)ticks, ticks / 10000000.0);
        printf("[verdict] %s\n",
               (w > 0 && ht > 0 && fps > 0)
                 ? "the file was DECODED -- real metadata came back"
                 : "handle only: metadata is zero, so nothing decoded it");
        cna_video_destroy(video);
    }
    cna_graphics_device_destroy(device);
    return 0;
}
