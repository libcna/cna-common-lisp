/* shim.generated.c --- GENERATED FILE, DO NOT EDIT.
 *
 * Produced by tools/native-abi/generate.py.  This translation unit is compiled
 * against the canonical CNA headers by tools/native-abi/verify.sh; it is not
 * shipped prebuilt, is never linked against CNA, and is loaded only when
 * CNA_LISP_SHIM names a build of it.
 */
#include <CNA/C/cna.h>
#include <stddef.h>
#include <stdint.h>

/* CNA_Result cna_graphics_device_set_viewport(CNA_Handle graphics_device, CNA_Viewport viewport) */
CNA_Result cna_lisp_shim_cna_graphics_device_set_viewport(void (*target)(void), CNA_Handle graphics_device, const CNA_Viewport *viewport)
{
    typedef CNA_Result (*target_t)(CNA_Handle, CNA_Viewport);
    return ((target_t)target)(graphics_device, *viewport);
}

int cna_lisp_shim_count(void) { return 1; }
