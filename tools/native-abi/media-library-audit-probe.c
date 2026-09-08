/* media-library-audit-probe.c --- MediaLibrary semantics, not just route presence.
 *
 * The enumeration probe beside this one answers "can a library be non-empty".
 * This one answers the questions a closure actually rests on, because **route
 * coverage is not closure evidence**: a route that exists and answers something
 * says nothing about whether the object it answers is stable, whether two paths
 * to the same entity agree, or whether a library song carries the library
 * context the three missing `Song' members need.
 *
 *   media-library-audit-probe <library>
 *
 * Run it with XDG_CONFIG_HOME pointing at the fixture
 * tools/qualification/make-media-library-fixture.py generates.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <CNA/C/cna.h>

static void *lib;
#define SYM(n, t) *(void **)(&(t)) = dlsym(lib, n)
#define OK(call) ((call) == CNA_RESULT_SUCCESS)


static const char *text(CNA_Handle h, CNA_Result (*sz)(CNA_Handle, uint64_t *),
                        CNA_Result (*cp)(CNA_Handle, char *, uint64_t, uint64_t *),
                        char *buf, size_t cap) {
    uint64_t n = 0;
    buf[0] = '\0';
    if (!sz || !cp || !OK(sz(h, &n)) || n >= cap) return buf;
    /* The copy routes report the byte count and do NOT NUL-terminate -- the ABI
     * carries text as pointer-plus-length and "never uses a NUL terminator".
     * Terminating at the reported length is the caller's job; without it a short
     * name reads the tail of whatever was in the buffer before. */
    if (!OK(cp(h, buf, (uint64_t)cap, &n))) { buf[0] = '\0'; return buf; }
    buf[n < cap ? n : cap - 1] = '\0';
    return buf;
}

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
    CNA_Result (*ml_pictures)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_saved)(CNA_Handle, CNA_Handle *);
    CNA_Result (*ml_root_album)(CNA_Handle, CNA_Handle *, uint8_t *);
    CNA_Result (*ml_src_type)(CNA_Handle, uint32_t *);
    CNA_Result (*ml_src_sz)(CNA_Handle, uint64_t *);
    CNA_Result (*ml_src_cp)(CNA_Handle, char *, uint64_t, uint64_t *);
    CNA_Result (*song_at)(CNA_Handle, int32_t, CNA_Handle *);
    CNA_Result (*song_count)(CNA_Handle, int32_t *);
    CNA_Result (*song_artist)(CNA_Handle, CNA_Handle *, uint8_t *);
    CNA_Result (*song_album)(CNA_Handle, CNA_Handle *, uint8_t *);
    CNA_Result (*song_genre)(CNA_Handle, CNA_Handle *, uint8_t *);
    CNA_Result (*song_sz)(CNA_Handle, uint64_t *);
    CNA_Result (*song_cp)(CNA_Handle, char *, uint64_t, uint64_t *);
    CNA_Result (*album_at)(CNA_Handle, int32_t, CNA_Handle *);
    CNA_Result (*album_count)(CNA_Handle, int32_t *);
    CNA_Result (*album_songs)(CNA_Handle, CNA_Handle *);
    CNA_Result (*album_artist)(CNA_Handle, CNA_Handle *);
    CNA_Result (*album_sz)(CNA_Handle, uint64_t *);
    CNA_Result (*album_cp)(CNA_Handle, char *, uint64_t, uint64_t *);
    CNA_Result (*artist_sz)(CNA_Handle, uint64_t *);
    CNA_Result (*artist_cp)(CNA_Handle, char *, uint64_t, uint64_t *);
    CNA_Result (*genre_sz)(CNA_Handle, uint64_t *);
    CNA_Result (*genre_cp)(CNA_Handle, char *, uint64_t, uint64_t *);
    CNA_Result (*pa_pictures)(CNA_Handle, CNA_Handle *);
    CNA_Result (*pa_albums)(CNA_Handle, CNA_Handle *);
    CNA_Result (*pa_parent)(CNA_Handle, CNA_Handle *, uint8_t *);
    CNA_Result (*pic_count)(CNA_Handle, int32_t *);
    CNA_Result (*pac_count)(CNA_Handle, int32_t *);

    SYM("cna_get_abi_version", ver);
    SYM("cna_game_create", game_create);
    SYM("cna_game_destroy", game_destroy);
    SYM("cna_media_library_create", ml_create);
    SYM("cna_media_library_destroy", ml_destroy);
    SYM("cna_media_library_get_songs", ml_songs);
    SYM("cna_media_library_get_albums", ml_albums);
    SYM("cna_media_library_get_artists", ml_artists);
    SYM("cna_media_library_get_genres", ml_genres);
    SYM("cna_media_library_get_pictures", ml_pictures);
    SYM("cna_media_library_get_saved_pictures", ml_saved);
    SYM("cna_media_library_get_root_picture_album", ml_root_album);
    SYM("cna_media_library_get_media_source_type", ml_src_type);
    SYM("cna_media_library_get_media_source_name_size", ml_src_sz);
    SYM("cna_media_library_copy_media_source_name", ml_src_cp);
    SYM("cna_song_collection_get_at", song_at);
    SYM("cna_song_collection_get_count", song_count);
    SYM("cna_song_get_artist", song_artist);
    SYM("cna_song_get_album", song_album);
    SYM("cna_song_get_genre", song_genre);
    SYM("cna_song_get_name_size", song_sz);
    SYM("cna_song_copy_name", song_cp);
    SYM("cna_album_collection_get_at", album_at);
    SYM("cna_album_collection_get_count", album_count);
    SYM("cna_album_get_songs", album_songs);
    SYM("cna_album_get_artist", album_artist);
    SYM("cna_album_get_name_size", album_sz);
    SYM("cna_album_copy_name", album_cp);
    SYM("cna_artist_get_name_size", artist_sz);
    SYM("cna_artist_copy_name", artist_cp);
    SYM("cna_genre_get_name_size", genre_sz);
    SYM("cna_genre_copy_name", genre_cp);
    SYM("cna_picture_album_get_pictures", pa_pictures);
    SYM("cna_picture_album_get_albums", pa_albums);
    SYM("cna_picture_album_get_parent", pa_parent);
    SYM("cna_picture_collection_get_count", pic_count);
    SYM("cna_picture_album_collection_get_count", pac_count);

    printf("ABI %u\n", ver ? ver() : 0u);
    CNA_GameCreateInfo info; memset(&info, 0, sizeof info);
    info.struct_size = (uint32_t)sizeof info; info.struct_version = 1;
    info.is_fixed_time_step = CNA_TRUE;
    info.target_elapsed_time_ticks = INT64_C(166667);
    info.window_title.data = "ml-audit"; info.window_title.byte_length = 8;
    CNA_Handle game = CNA_INVALID_HANDLE, L = CNA_INVALID_HANDLE;
    if (!OK(game_create(&info, &game))) { printf("game_create failed\n"); return 1; }
    if (!OK(ml_create(game, &L)))       { printf("library create failed\n"); game_destroy(game); return 1; }

    char a[512], b[512];

    /* --- collection identity: is a property a stable object, as XNA's is? --- */
    CNA_Handle s1 = 0, s2 = 0;
    ml_songs(L, &s1); ml_songs(L, &s2);
    printf("IDENTITY  library.Songs twice        : %s (%llu vs %llu)\n",
           s1 == s2 ? "SAME handle" : "DIFFERENT handles",
           (unsigned long long)s1, (unsigned long long)s2);

    /* --- the three members this closure exists to close --- */
    int32_t n = 0; song_count(s1, &n);
    printf("songs in library                     : %d\n", n);
    for (int32_t i = 0; i < n; ++i) {
        CNA_Handle song = 0; if (!OK(song_at(s1, i, &song))) continue;
        printf("  song[%d] name=%-18s", i, text(song, song_sz, song_cp, a, sizeof a));
        CNA_Handle h = 0; uint8_t avail = 0;
        if (song_artist && OK(song_artist(song, &h, &avail)))
            printf(" artist=%s", avail ? text(h, artist_sz, artist_cp, b, sizeof b) : "<UNAVAILABLE>");
        h = 0; avail = 0;
        if (song_album && OK(song_album(song, &h, &avail)))
            printf(" album=%s", avail ? text(h, album_sz, album_cp, b, sizeof b) : "<UNAVAILABLE>");
        h = 0; avail = 0;
        if (song_genre && OK(song_genre(song, &h, &avail)))
            printf(" genre=%s", avail ? text(h, genre_sz, genre_cp, b, sizeof b) : "<UNAVAILABLE>");
        printf("\n");
    }

    /* --- do two paths to one entity agree? library.Albums[0].Songs[0] vs library.Songs[i] --- */
    CNA_Handle albums = 0; int32_t an = 0;
    ml_albums(L, &albums); album_count(albums, &an);
    printf("albums                               : %d\n", an);
    for (int32_t i = 0; i < an; ++i) {
        CNA_Handle al = 0; if (!OK(album_at(albums, i, &al))) continue;
        CNA_Handle asongs = 0; int32_t asn = 0;
        album_songs(al, &asongs); song_count(asongs, &asn);
        printf("  album[%d] name=%-20s songs=%d", i, text(al, album_sz, album_cp, a, sizeof a), asn);
        if (asn > 0) {
            CNA_Handle s = 0; song_at(asongs, 0, &s);
            CNA_Handle top = 0; int match = -1;
            for (int32_t k = 0; k < n; ++k) { song_at(s1, k, &top); if (top == s) { match = k; break; } }
            printf("  first song handle %s library.Songs[%d]",
                   match >= 0 ? "==" : "not found in", match);
        }
        printf("\n");
    }

    /* --- MediaSource --- */
    uint32_t st = 0; ml_src_type(L, &st);
    printf("MediaSource type=%u name=%s\n", st,
           text(L, ml_src_sz, ml_src_cp, a, sizeof a));

    /* --- picture album hierarchy and SavedPictures --- */
    CNA_Handle root = 0, pics = 0, saved = 0, subs = 0;
    int32_t pn = -1, sn = -1, subn = -1;
    uint8_t root_avail = 0;
    if (ml_root_album && OK(ml_root_album(L, &root, &root_avail)) && root_avail) {
        if (pa_pictures && OK(pa_pictures(root, &pics))) pic_count(pics, &pn);
        if (pa_albums && OK(pa_albums(root, &subs))) pac_count(subs, &subn);
        CNA_Handle parent = 0; uint8_t pav = 0;
        if (pa_parent) pa_parent(root, &parent, &pav);
        printf("RootPictureAlbum pictures=%d sub-albums=%d parent=%s\n",
               pn, subn, pav ? "present" : "<none, as a root should be>");
    } else printf("RootPictureAlbum            : unavailable\n");
    if (ml_saved && OK(ml_saved(L, &saved))) { pic_count(saved, &sn);
        printf("SavedPictures                        : %d\n", sn); }

    ml_destroy(L); game_destroy(game);
    return 0;
}
