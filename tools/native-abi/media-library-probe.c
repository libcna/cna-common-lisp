/* media-library-probe.c --- can a MediaLibrary be made to enumerate anything?
 *
 * One question, asked directly, because it decides whether `MediaLibrary' is a
 * candidate for the selection. `media_library.h' says opening "scans the
 * device's music and picture locations" and that "an empty library is an
 * ordinary result, not a failure" -- so a library that answers zero proves
 * nothing about whether the type is implementable, only that this machine has
 * no music where CNA looked.
 *
 *   media-library-probe <library>
 *
 * It creates a game, opens the default media library, and prints the count of
 * every collection the type exposes. Run it twice: once as the machine is, and
 * once with XDG_CONFIG_HOME pointing at the fixture
 * tools/qualification/make-media-library-fixture.py generates. SDL resolves the
 * user folders through $XDG_CONFIG_HOME/user-dirs.dirs, which is what makes the
 * second run deterministic -- CNA's own C-API suite builds its fixture exactly
 * that way and says so.
 *
 * Nothing here is a claim that the binding could project the type. It measures
 * one thing: whether positive enumeration evidence can be produced at all.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <CNA/C/cna.h>

static void *lib;
#define SYM(name, target) *(void **)(&(target)) = dlsym(lib, name)

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!lib) { printf("dlopen: %s\n", dlerror()); return 1; }

    uint32_t (*ver)(void);
    CNA_Result (*game_create)(const CNA_GameCreateInfo *, CNA_Handle *);
    CNA_Result (*game_destroy)(CNA_Handle);
    CNA_Result (*ml_create)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_destroy)(CNA_Handle);
    CNA_Result (*ml_songs)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_albums)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_artists)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_genres)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_playlists)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_pictures)(CNA_Handle, CNA_Handle *);
    CNA_Result (*song_count)(CNA_Handle, int32_t *);
    CNA_Result (*album_count)(CNA_Handle, int32_t *);
    CNA_Result (*artist_count)(CNA_Handle, int32_t *);
    CNA_Result (*genre_count)(CNA_Handle, int32_t *);
    CNA_Result (*playlist_count)(CNA_Handle, int32_t *);
    CNA_Result (*picture_count)(CNA_Handle, int32_t *);

    SYM("cna_get_abi_version", ver);
    SYM("cna_game_create", game_create);
    SYM("cna_game_destroy", game_destroy);
    SYM("cna_media_library_create", ml_create);
    SYM("cna_media_library_destroy", ml_destroy);
    SYM("cna_media_library_get_songs", ml_songs);
    SYM("cna_media_library_get_albums", ml_albums);
    SYM("cna_media_library_get_artists", ml_artists);
    SYM("cna_media_library_get_genres", ml_genres);
    SYM("cna_media_library_get_playlists", ml_playlists);
    SYM("cna_media_library_get_pictures", ml_pictures);
    SYM("cna_song_collection_get_count", song_count);
    SYM("cna_album_collection_get_count", album_count);
    SYM("cna_artist_collection_get_count", artist_count);
    SYM("cna_genre_collection_get_count", genre_count);
    SYM("cna_playlist_collection_get_count", playlist_count);
    SYM("cna_picture_collection_get_count", picture_count);

    if (!ml_create || !game_create) { printf("MISSING symbols\n"); return 1; }
    printf("ABI %u\n", ver ? ver() : 0u);

    /* No init helper exists for this struct; the binding fills it the same way.
     * 166667 ticks is the 60 Hz step CNA-Lisp's own default uses. */
    CNA_GameCreateInfo info; memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info;
    info.struct_version = 1;
    info.is_fixed_time_step = CNA_TRUE;
    info.target_elapsed_time_ticks = INT64_C(166667);
    info.window_title.data = "media-library-probe";
    info.window_title.byte_length = (uint64_t)strlen("media-library-probe");

    CNA_Handle game = CNA_INVALID_HANDLE;
    CNA_Result r = game_create(&info, &game);
    printf("game_create -> %u\n", (unsigned)r);
    if (r) return 0;

    CNA_Handle library = CNA_INVALID_HANDLE;
    r = ml_create(game, &library);
    printf("media_library_create -> %u%s\n", (unsigned)r,
           r == CNA_RESULT_NOT_SUPPORTED ? " (NOT_SUPPORTED)" : "");
    if (r) { game_destroy(game); return 0; }

    struct { const char *name; CNA_Result (*get)(CNA_Handle, CNA_Handle *);
             CNA_Result (*count)(CNA_Handle, int32_t *); } kinds[] = {
        { "songs",     ml_songs,     song_count     },
        { "albums",    ml_albums,    album_count    },
        { "artists",   ml_artists,   artist_count   },
        { "genres",    ml_genres,    genre_count    },
        { "playlists", ml_playlists, playlist_count },
        { "pictures",  ml_pictures,  picture_count  },
    };
    int total = 0;
    for (unsigned i = 0; i < sizeof kinds / sizeof kinds[0]; ++i) {
        CNA_Handle collection = CNA_INVALID_HANDLE;
        int32_t n = -1;
        if (!kinds[i].get || !kinds[i].count) { printf("  %-10s (route missing)\n", kinds[i].name); continue; }
        CNA_Result gr = kinds[i].get(library, &collection);
        if (gr) { printf("  %-10s get -> %u\n", kinds[i].name, (unsigned)gr); continue; }
        CNA_Result cr = kinds[i].count(collection, &n);
        if (cr) { printf("  %-10s count -> %u\n", kinds[i].name, (unsigned)cr); continue; }
        printf("  %-10s %d\n", kinds[i].name, (int)n);
        if (n > 0) total += n;
    }
    printf("TOTAL %d %s\n", total, total > 0 ? "(NON-EMPTY)" : "(EMPTY)");
    ml_destroy(library);
    game_destroy(game);
    return 0;
}
