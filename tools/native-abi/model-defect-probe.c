/* model-defect-probe.c --- measure CNA's two loaded-Model defects, one per process.
 *
 * Both defects are memory faults rather than result codes, so an exception
 * barrier cannot contain them and they cannot be measured inside the test image.
 * This is the smallest program that reaches each of them through the C ABI
 * alone, with no binding in the path, and it runs exactly one stage per process
 * so that a crash names the stage that caused it.
 *
 *   model-defect-probe <library> <content-root> <asset> <stage>
 *
 * It prints one `STAGE ... ` line per step it completes and flushes each, so the
 * parent can read how far the child got even when the child dies of a signal.
 *
 * Stages:
 *   baseline          load the model, then tear down without touching it
 *   destroy           load, then cna_model_destroy  -- defect #1
 *   techniques        load, reach the published effect, cna_effect_get_techniques
 *   parameters        the same with cna_effect_get_parameters
 *   current-technique the same with cna_effect_get_current_technique
 *   clone             the same with cna_effect_clone
 *   world             a route that does NOT read adapterState, as a control
 *   replaced          replace the effect first, then the graph routes -- the remedy
 */
/* sigaction and siginfo_t are POSIX, and -std=c11 hides them. */
#define _POSIX_C_SOURCE 200809L

#include <dlfcn.h>
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

static CNA_Result (*p_cna_game_create)(const CNA_GameCreateInfo *, CNA_Handle *);
static CNA_Result (*p_cna_game_run_one_frame)(CNA_Handle);
static CNA_Result (*p_cna_game_destroy)(CNA_Handle);
static CNA_Result (*p_cna_game_get_content_manager_ext)(CNA_Handle, CNA_Handle *);
static CNA_Result (*p_cna_content_manager_set_root_directory)(CNA_Handle, CNA_StringView);
static CNA_Result (*p_cna_content_manager_load_model)(CNA_Handle, CNA_StringView, CNA_ModelHandle *);
static CNA_Result (*p_cna_content_manager_unload)(CNA_Handle);
static CNA_Result (*p_cna_model_destroy)(CNA_ModelHandle);
static CNA_Result (*p_cna_model_get_meshes)(CNA_ModelHandle, CNA_ModelMeshCollectionHandle *);
static CNA_Result (*p_cna_model_mesh_collection_get_at)(CNA_ModelMeshCollectionHandle, int32_t,
                                                     CNA_ModelMeshHandle *);
static CNA_Result (*p_cna_model_mesh_get_mesh_parts)(CNA_ModelMeshHandle,
                                                   CNA_ModelMeshPartCollectionHandle *);
static CNA_Result (*p_cna_model_mesh_part_collection_get_at)(CNA_ModelMeshPartCollectionHandle,
                                                           int32_t, CNA_ModelMeshPartHandle *);
static CNA_Result (*p_cna_model_mesh_part_get_effect)(CNA_ModelMeshPartHandle, CNA_Bool *,
                                                    CNA_EffectHandle *);
static CNA_Result (*p_cna_model_mesh_part_set_effect)(CNA_ModelMeshPartHandle, CNA_EffectHandle);
static CNA_Result (*p_cna_effect_get_techniques)(CNA_EffectHandle, CNA_EffectTechniqueCollectionHandle *);
static CNA_Result (*p_cna_effect_get_parameters)(CNA_EffectHandle, CNA_EffectParameterCollectionHandle *);
static CNA_Result (*p_cna_effect_get_current_technique)(CNA_EffectHandle, CNA_EffectTechniqueHandle *);
static CNA_Result (*p_cna_effect_clone)(CNA_EffectHandle, CNA_EffectHandle *);
static CNA_Result (*p_cna_effect_matrices_get_world)(CNA_EffectHandle, CNA_Matrix *);
static CNA_Result (*p_cna_basic_effect_get_texture)(CNA_EffectHandle, CNA_Bool *, CNA_Handle *);
static CNA_Result (*p_cna_basic_effect_set_texture)(CNA_EffectHandle, CNA_Handle);
static CNA_Result (*p_cna_effect_lights_get_directional_light)(CNA_EffectHandle, uint32_t, CNA_DirectionalLightHandle *);
static CNA_Result (*p_cna_basic_effect_create)(CNA_Handle, CNA_EffectHandle *);
static CNA_Result (*p_cna_effect_destroy)(CNA_EffectHandle);
static CNA_Result (*p_cna_game_get_graphics_device)(CNA_Handle, CNA_Handle *);

/* The faults these stages reach are null-pointer dereferences at a small fixed
 * offset, and the offset is the useful half of the evidence: it says which
 * member of the missing object was read. Print it from the handler and re-raise,
 * so the parent still sees a real SIGSEGV exit status rather than a tidy one. */
static void on_segv(int signo, siginfo_t *info, void *context) {
    char buffer[128];
    int n = snprintf(buffer, sizeof buffer,
                     "FAULT SIGSEGV at address 0x%lx\n",
                     (unsigned long)(uintptr_t)info->si_addr);
    if (n > 0) { ssize_t ignored = write(1, buffer, (size_t)n); (void)ignored; }
    signal(signo, SIG_DFL);
    raise(signo);
}

static CNA_StringView sv(const char *s) {
    CNA_StringView v;
    v.data = s;
    v.byte_length = (uint64_t)strlen(s);
    return v;
}

static void stage(const char *what, CNA_Result r) {
    printf("STAGE %-22s result=%u\n", what, (unsigned)r);
    fflush(stdout);
}

int main(int argc, char **argv) {
    if (argc != 5) {
        printf("usage: %s <library> <content-root> <asset> <stage>\n", argv[0]);
        return 91;
    }
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = on_segv;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);

    const char *want = argv[4];
    lib = dlopen(argv[1], RTLD_NOW);
    if (!lib) { printf("dlopen: %s\n", dlerror()); return 92; }

    SYM(cna_game_create); SYM(cna_game_run_one_frame); SYM(cna_game_destroy);
    SYM(cna_game_get_content_manager_ext); SYM(cna_content_manager_set_root_directory);
    SYM(cna_content_manager_load_model); SYM(cna_content_manager_unload);
    SYM(cna_model_destroy); SYM(cna_model_get_meshes); SYM(cna_model_mesh_collection_get_at);
    SYM(cna_model_mesh_get_mesh_parts); SYM(cna_model_mesh_part_collection_get_at);
    SYM(cna_model_mesh_part_get_effect); SYM(cna_model_mesh_part_set_effect);
    SYM(cna_effect_get_techniques); SYM(cna_effect_get_parameters);
    SYM(cna_effect_get_current_technique); SYM(cna_effect_clone);
    SYM(cna_effect_matrices_get_world); SYM(cna_basic_effect_create);
    SYM(cna_basic_effect_get_texture); SYM(cna_basic_effect_set_texture);
    SYM(cna_effect_lights_get_directional_light);
    SYM(cna_effect_destroy); SYM(cna_game_get_graphics_device);

    CNA_GameCreateInfo info;
    memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info;
    info.struct_version = 1;
    info.is_fixed_time_step = CNA_TRUE;
    info.target_elapsed_time_ticks = 166667;
    info.window_title = sv("model-defect-probe");

    CNA_Handle game = CNA_INVALID_HANDLE;
    CNA_Result r = p_cna_game_create(&info, &game);
    stage("game_create", r);
    if (r != CNA_RESULT_SUCCESS) return 1;

    r = p_cna_game_run_one_frame(game);
    stage("run_one_frame", r);

    CNA_Handle cm = CNA_INVALID_HANDLE;
    r = p_cna_game_get_content_manager_ext(game, &cm);
    stage("get_content_manager", r);
    if (r != CNA_RESULT_SUCCESS) return 2;

    r = p_cna_content_manager_set_root_directory(cm, sv(argv[2]));
    stage("set_root_directory", r);

    CNA_ModelHandle model = CNA_INVALID_HANDLE;
    r = p_cna_content_manager_load_model(cm, sv(argv[3]), &model);
    stage("load_model", r);
    if (r != CNA_RESULT_SUCCESS) { p_cna_game_destroy(game); return 3; }

    if (strcmp(want, "destroy") == 0) {
        r = p_cna_model_destroy(model);
        stage("model_destroy", r);
    } else if (strcmp(want, "baseline") != 0) {
        /* Reach the content-published effect through the graph. */
        CNA_ModelMeshCollectionHandle meshes = CNA_INVALID_HANDLE;
        r = p_cna_model_get_meshes(model, &meshes);
        stage("model_get_meshes", r);
        CNA_ModelMeshHandle mesh = CNA_INVALID_HANDLE;
        r = p_cna_model_mesh_collection_get_at(meshes, 0, &mesh);
        stage("mesh_at_0", r);
        CNA_ModelMeshPartCollectionHandle parts = CNA_INVALID_HANDLE;
        r = p_cna_model_mesh_get_mesh_parts(mesh, &parts);
        stage("mesh_get_parts", r);
        CNA_ModelMeshPartHandle part = CNA_INVALID_HANDLE;
        r = p_cna_model_mesh_part_collection_get_at(parts, 0, &part);
        stage("part_at_0", r);

        if (strcmp(want, "replaced") == 0) {
            CNA_Handle device = CNA_INVALID_HANDLE;
            r = p_cna_game_get_graphics_device(game, &device);
            stage("get_graphics_device", r);
            CNA_EffectHandle mine = CNA_INVALID_HANDLE;
            r = p_cna_basic_effect_create(device, &mine);
            stage("basic_effect_create", r);
            r = p_cna_model_mesh_part_set_effect(part, mine);
            stage("part_set_effect", r);
        }

        CNA_Bool has = CNA_FALSE;
        CNA_EffectHandle effect = CNA_INVALID_HANDLE;
        r = p_cna_model_mesh_part_get_effect(part, &has, &effect);
        printf("STAGE %-22s result=%u has_effect=%d\n", "part_get_effect",
               (unsigned)r, (int)has);
        fflush(stdout);

        if (strcmp(want, "basic-texture") == 0) {
            CNA_Bool hast = CNA_FALSE;
            CNA_Handle t = CNA_INVALID_HANDLE;
            r = p_cna_basic_effect_get_texture(effect, &hast, &t);
            stage("basic_get_texture", r);
        } else if (strcmp(want, "directional-light") == 0) {
            CNA_DirectionalLightHandle light = CNA_INVALID_HANDLE;
            r = p_cna_effect_lights_get_directional_light(effect, 0, &light);
            stage("lights_get_directional", r);
        } else if (strcmp(want, "world") == 0) {
            CNA_Matrix m;
            memset(&m, 0, sizeof m);
            r = p_cna_effect_matrices_get_world(effect, &m);
            stage("effect_get_world", r);
        } else {
            CNA_Handle out = CNA_INVALID_HANDLE;
            if (strcmp(want, "parameters") == 0) {
                r = p_cna_effect_get_parameters(effect, (CNA_EffectParameterCollectionHandle *)&out);
                stage("effect_get_parameters", r);
            } else if (strcmp(want, "current-technique") == 0) {
                r = p_cna_effect_get_current_technique(effect, (CNA_EffectTechniqueHandle *)&out);
                stage("effect_get_current_technique", r);
            } else if (strcmp(want, "clone") == 0) {
                r = p_cna_effect_clone(effect, (CNA_EffectHandle *)&out);
                stage("effect_clone", r);
            } else {
                r = p_cna_effect_get_techniques(effect, (CNA_EffectTechniqueCollectionHandle *)&out);
                stage("effect_get_techniques", r);
            }
            if (strcmp(want, "replaced") == 0) {
                /* Prove the whole graph is usable after the swap, not just one route. */
                CNA_Handle p = CNA_INVALID_HANDLE, t = CNA_INVALID_HANDLE;
                r = p_cna_effect_get_parameters(effect, (CNA_EffectParameterCollectionHandle *)&p);
                stage("replaced_get_parameters", r);
                r = p_cna_effect_get_current_technique(effect, (CNA_EffectTechniqueHandle *)&t);
                stage("replaced_get_current_technique", r);
            }
        }
    }

    r = p_cna_content_manager_unload(cm);
    stage("content_unload", r);
    r = p_cna_game_destroy(game);
    stage("game_destroy", r);
    printf("PROBE COMPLETED CLEANLY\n");
    fflush(stdout);
    return 0;
}
