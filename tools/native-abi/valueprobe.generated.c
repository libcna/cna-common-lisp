/* valueprobe.generated.c --- GENERATED FILE, DO NOT EDIT.
 *
 * Produced by tools/native-abi/generate.py.  This translation unit is compiled
 * against the canonical CNA headers by tools/native-abi/verify.sh; it never
 * ships and is never linked into CNA-Lisp.
 */
#include <CNA/C/cna.h>
#include <stddef.h>
#include <stdint.h>

#include <string.h>

/* Each function below has exactly the prototype a real CNA route has for
   this aggregate.  CNA-Lisp calls it through the flattened CFFI shape the
   generator produced; if the flattening were wrong for this platform the
   bytes copied out would differ. */
void cna_lisp_valueprobe_cna_stringview(CNA_StringView value, unsigned char *out)
{
    memcpy(out, &value, sizeof(value));
}

void cna_lisp_valueprobe_cna_stringview_after(int32_t before, CNA_StringView value, int32_t after, unsigned char *out, int32_t *out_before, int32_t *out_after)
{
    memcpy(out, &value, sizeof(value));
    *out_before = before;
    *out_after = after;
}

void cna_lisp_valueprobe_cna_color(CNA_Color value, unsigned char *out)
{
    memcpy(out, &value, sizeof(value));
}

void cna_lisp_valueprobe_cna_color_after(int32_t before, CNA_Color value, int32_t after, unsigned char *out, int32_t *out_before, int32_t *out_after)
{
    memcpy(out, &value, sizeof(value));
    *out_before = before;
    *out_after = after;
}

void cna_lisp_valueprobe_cna_rectangle(CNA_Rectangle value, unsigned char *out)
{
    memcpy(out, &value, sizeof(value));
}

void cna_lisp_valueprobe_cna_rectangle_after(int32_t before, CNA_Rectangle value, int32_t after, unsigned char *out, int32_t *out_before, int32_t *out_after)
{
    memcpy(out, &value, sizeof(value));
    *out_before = before;
    *out_after = after;
}

int cna_lisp_valueprobe_count(void) { return 3; }
