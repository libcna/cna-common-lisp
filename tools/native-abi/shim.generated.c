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

/* CNA_Result cna_effect_matrices_set_world(CNA_EffectHandle effect, CNA_Matrix value) */
CNA_Result cna_lisp_shim_cna_effect_matrices_set_world(void (*target)(void), CNA_EffectHandle effect, const CNA_Matrix *value)
{
    typedef CNA_Result (*target_t)(CNA_EffectHandle, CNA_Matrix);
    return ((target_t)target)(effect, *value);
}

/* CNA_Result cna_effect_matrices_set_view(CNA_EffectHandle effect, CNA_Matrix value) */
CNA_Result cna_lisp_shim_cna_effect_matrices_set_view(void (*target)(void), CNA_EffectHandle effect, const CNA_Matrix *value)
{
    typedef CNA_Result (*target_t)(CNA_EffectHandle, CNA_Matrix);
    return ((target_t)target)(effect, *value);
}

/* CNA_Result cna_effect_matrices_set_projection(CNA_EffectHandle effect, CNA_Matrix value) */
CNA_Result cna_lisp_shim_cna_effect_matrices_set_projection(void (*target)(void), CNA_EffectHandle effect, const CNA_Matrix *value)
{
    typedef CNA_Result (*target_t)(CNA_EffectHandle, CNA_Matrix);
    return ((target_t)target)(effect, *value);
}

int cna_lisp_shim_count(void) { return 4; }
