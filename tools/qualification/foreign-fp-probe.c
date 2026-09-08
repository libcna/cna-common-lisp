/* fp-c-probe.c --- does an ordinary C caller see the same floating-point event?
 *
 *   cc -O0 -o build-probe/foreign-fp-probe tools/qualification/foreign-fp-probe.c -ldl
 *   build-probe/foreign-fp-probe <libcna_c_api.so> [trap-invalid]
 *
 * Runs exactly the sequence GraphicsAdapter.Adapters runs with no game and no
 * device alive: initialise presentation parameters, create the transient
 * enumeration device, ask for the adapter count, destroy it. Reports the
 * floating-point environment the way a C program sees it.
 *
 * With no argument it runs as C programs normally run: IEEE exceptions masked,
 * which is the C ecosystem's default and what CNA and Mesa are written against.
 * With "trap-invalid" it enables the FE_INVALID trap first, which is what SBCL
 * does to its own process -- so the two runs together say whether the event is a
 * CNA/Mesa defect or a caller-environment difference.
 */
#define _GNU_SOURCE
#include <fenv.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <stdint.h>

typedef uint32_t (*init_fn)(void *);
typedef uint32_t (*create_fn)(uint32_t, uint32_t, void *, uint64_t *);
typedef uint32_t (*count_fn)(uint64_t, uint64_t *);
typedef uint32_t (*destroy_fn)(uint64_t);

static void show(const char *label)
{
    int ex = fetestexcept(FE_ALL_EXCEPT);
    int en = fegetexcept();
    printf("[%s] accrued:%s%s%s%s%s trapping:%s%s%s%s%s rounding:%s\n", label,
           (ex & FE_INVALID)   ? " invalid"   : "",
           (ex & FE_DIVBYZERO) ? " divzero"   : "",
           (ex & FE_OVERFLOW)  ? " overflow"  : "",
           (ex & FE_UNDERFLOW) ? " underflow" : "",
           (ex & FE_INEXACT)   ? " inexact"   : "",
           (en & FE_INVALID)   ? " invalid"   : "",
           (en & FE_DIVBYZERO) ? " divzero"   : "",
           (en & FE_OVERFLOW)  ? " overflow"  : "",
           (en & FE_UNDERFLOW) ? " underflow" : "",
           (en & FE_INEXACT)   ? " inexact"   : "",
           fegetround() == FE_TONEAREST ? "nearest" : "other");
    fflush(stdout);
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: %s <so> [trap-invalid]\n", argv[0]); return 2; }
    int trap_invalid = (argc > 2 && strcmp(argv[2], "trap-invalid") == 0);

    void *h = dlopen(argv[1], RTLD_NOW);
    if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }

    init_fn    pp_init = (init_fn)   dlsym(h, "cna_presentation_parameters_init");
    create_fn  create  = (create_fn) dlsym(h, "cna_graphics_device_create");
    count_fn   count   = (count_fn)  dlsym(h, "cna_graphics_adapter_get_count");
    destroy_fn destroy = (destroy_fn)dlsym(h, "cna_graphics_device_destroy");
    if (!pp_init || !create || !count || !destroy) {
        fprintf(stderr, "dlsym: a route is missing\n"); return 2;
    }

    if (trap_invalid) {
        feenableexcept(FE_INVALID);
        printf("[mode] FE_INVALID trap enabled, as SBCL enables it\n");
    } else {
        printf("[mode] ordinary C: every IEEE exception masked\n");
    }
    show("before");

    unsigned char params[64];
    memset(params, 0, sizeof params);
    uint32_t r = pp_init(params);
    printf("[presentation_parameters_init] result=%u\n", r);
    show("after-pp-init");

    uint64_t device = 0;
    r = create(0, 1 /* HiDef */, params, &device);
    printf("[graphics_device_create] result=%u handle=%llu\n",
           r, (unsigned long long)device);
    show("after-device-create");

    if (r == 0 && device != 0) {
        uint64_t n = 0;
        r = count(device, &n);
        printf("[graphics_adapter_get_count] result=%u count=%llu\n",
               r, (unsigned long long)n);
        show("after-adapter-count");
        destroy(device);
        show("after-destroy");
    }
    printf("[done] the C caller reached the end\n");
    return 0;
}
