/* abi-version-probe.c --- print the ABI version a CNA library implements.
 *
 * **Why this exists.** `tools/qualification/model-defect-matrix.sh' labels each
 * library it measures with the ABI that library actually implements, rather
 * than with whatever the path happens to be called, and it does that by running
 * `build-probe/abiver'. That binary had no source in this repository until the
 * 2026-09-07 partial-frontier audit tried to reproduce the matrix and found the
 * script depending on something nobody could build. This is that source.
 *
 * It reads the version out of the loaded library rather than out of a header,
 * which is the whole point: a path named `cna-c-abi-0.22.0' is a claim, and
 * `cna_get_abi_version' is the answer.
 *
 *   cc -O1 -o build-probe/abiver tools/native-abi/abi-version-probe.c -ldl
 *   build-probe/abiver /path/to/libcna_c_api.so
 *   => /path/to/libcna_c_api.so  0.23.0
 *
 * Expected outcomes: one line naming the library and its decoded version, exit
 * 0; exit 1 with a diagnostic if the library will not load or does not export
 * `cna_get_abi_version', which is itself a result -- a library without that
 * symbol is not a CNA C ABI library.
 */
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: abiver <library>\n");
        return 2;
    }
    void *library = dlopen(argv[1], RTLD_NOW);
    if (library == NULL) {
        fprintf(stderr, "%s\n", dlerror());
        return 1;
    }
    /* Through an object pointer, as model-defect-probe.c does: ISO C forbids
       casting dlsym's void* straight to a function pointer, and POSIX requires
       this spelling to work. */
    uint32_t (*get_version)(void);
    *(void **) (&get_version) = dlsym(library, "cna_get_abi_version");
    if (get_version == NULL) {
        fprintf(stderr, "%s exports no cna_get_abi_version\n", argv[1]);
        return 1;
    }
    /* CNA_ABI_VERSION_ENCODE packs major in the high sixteen bits and minor and
       patch in one byte each. */
    const uint32_t encoded = get_version();
    printf("%s  %u.%u.%u\n", argv[1],
           (encoded >> 16) & 0xffffu, (encoded >> 8) & 0xffu, encoded & 0xffu);
    return 0;
}
