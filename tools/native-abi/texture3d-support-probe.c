/* texture3d-support-probe.c --- can this renderer make a Texture3D at all?
 *
 * One question, asked directly, because it decides whether `Texture3D' is a
 * candidate for the selection. `cna_texture3d_create' is documented as creating
 * one "when the selected renderer supports volume storage" and as answering
 * `CNA_RESULT_NOT_SUPPORTED' otherwise, and the answer is a property of the
 * build rather than of the ABI version -- so it has to be asked of a library
 * rather than read out of a header.
 *
 *   texture3d-support-probe <library>
 *
 * It creates a caller-owned GraphicsDevice on adapter zero with the HiDef
 * profile -- the more capable of the two, so a refusal is not the profile's
 * doing -- and asks for the smallest possible volume texture.
 *
 * Measured 2026-09-07: NOT_SUPPORTED on HEADLESS and on SOFTWARE, on all three
 * admitted ABIs -- six combinations, one answer. `NEXT.md' records what that
 * rules out and why.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <CNA/C/cna.h>
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    void *lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!lib) { printf("dlopen: %s\n", dlerror()); return 1; }
    /* `void *' to function pointer is not an ISO C conversion, so each symbol
     * goes through the pointer-to-pointer pun the other probes here use. */
    CNA_Result (*create)(uint32_t, uint32_t, const CNA_PresentationParameters *, CNA_Handle *);
    CNA_Result (*destroy)(CNA_Handle);
    CNA_Result (*init)(CNA_PresentationParameters *);
    CNA_Result (*t3d)(CNA_Handle, const CNA_Texture3DCreateInfo *, CNA_Handle *);
    CNA_Result (*t3dx)(CNA_Handle);
    uint32_t (*ver)(void);
#define SYM(name, target) *(void **)(&(target)) = dlsym(lib, name)
    SYM("cna_graphics_device_create", create);
    SYM("cna_graphics_device_destroy", destroy);
    SYM("cna_presentation_parameters_init", init);
    SYM("cna_texture3d_create", t3d);
    SYM("cna_texture3d_destroy", t3dx);
    SYM("cna_get_abi_version", ver);
#undef SYM
    if (!create || !t3d) { printf("MISSING symbols\n"); return 1; }
    CNA_PresentationParameters pp; memset(&pp, 0, sizeof pp); init(&pp);
    pp.back_buffer_width = 32; pp.back_buffer_height = 16;
    CNA_Handle d = CNA_INVALID_HANDLE, t = CNA_INVALID_HANDLE;
    CNA_Result r = create(0u, CNA_GRAPHICS_PROFILE_HI_DEF, &pp, &d);
    printf("ABI %u  device create -> %u\n", ver(), (unsigned)r);
    if (r) return 0;
    CNA_Texture3DCreateInfo ci; memset(&ci, 0, sizeof ci);
    ci.struct_size = (uint32_t)sizeof ci; ci.struct_version = 1;
    ci.width = 4; ci.height = 4; ci.depth = 4;
    ci.mip_map = CNA_FALSE; ci.format = CNA_SURFACE_FORMAT_COLOR;
    r = t3d(d, &ci, &t);
    printf("texture3d_create -> %u %s\n", (unsigned)r,
           r == CNA_RESULT_NOT_SUPPORTED ? "(NOT_SUPPORTED)" : r ? "(other failure)" : "(SUCCESS)");
    if (!r) printf("texture3d_destroy -> %u\n", (unsigned)t3dx(t));
    destroy(d);
    return 0;
}
