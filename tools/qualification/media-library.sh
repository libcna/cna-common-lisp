#!/bin/sh
# The MediaLibrary closure, qualified against a generated library.
#
# **A media library is whatever the machine running the test happens to hold**,
# and that is the problem this lane exists to remove. `media_library.h' says
# opening one "scans the device's music and picture locations" and that an empty
# library is an ordinary result -- so a run that asserted "non-empty" would pass
# against a developer's own music folder and fail on a bare runner, and a run
# that asserted "empty" would do the opposite. Measured once on a developer
# machine: 48 pictures, none of them anybody's fixture.
#
# SDL resolves the user folders through `$XDG_CONFIG_HOME/user-dirs.dirs', so
# this lane generates a tree, points that variable at it, and then asserts
# **exact counts**. CNA's own C-API suite builds its fixture the same way and
# says in its CMake that doing so "keeps the test from ever reading or writing a
# real user directory", which is the other half of why this is right.
#
#   MEDIA_LIBRARY_LIFETIME    a library that lent collections, entities and a
#                             picture tree was destroyed cleanly and left the
#                             callback registry empty. The handles into a library
#                             are a reference count; this is the claim that they
#                             all went back.
#   MEDIA_LIBRARY_IDENTITY    all nine MediaLibrary properties answered the SAME
#                             object twice, as XNA's private fields do -- over
#                             CNA handles that differ on every call. This is the
#                             claim that the projection caches, not that CNA does.
#   MEDIA_LIBRARY_COUNTS      songs 2, albums 2, artists 2, genres 1, playlists 0,
#                             pictures 2, saved 0. **Exact, and the one genre is
#                             the discriminating half**: the fixture's WAV carries
#                             no tags, so it contributes a path-derived artist and
#                             album and no genre at all.
#   MEDIA_LIBRARY_SONG_MEMBERS
#                             a library song answered Artist, Album and Genre --
#                             the three members that were `missing' until this
#                             closure, whose recorded reason was that a file-path
#                             song was the only kind this binding could make.
#   MEDIA_LIBRARY_CROSS_PATH  Song.Album and MediaLibrary.Albums agreed on one
#                             album across two borrowed handles, and the indexer
#                             answered fresh-but-equal facades. **Route coverage
#                             is not closure evidence**; this is the difference.
#   MEDIA_LIBRARY_PICTURE_TREE
#                             a root with no parent, a sub-album pointing back at
#                             it, and a picture pointing back at its album. NIL is
#                             the only thing that marks the root.
#   MEDIA_LIBRARY_ORDINARY_ABSENCES
#                             an unknown token answered NIL and SavedPictures was
#                             empty, both of which CNA documents as ordinary
#                             answers rather than gaps.
#
# **Nothing here claims a library song can be PLAYED.** The fixture's tagged MP3
# indexes and does not decode; playback is MediaPlayer's surface and has a lane
# of its own. The WAV is there so the fixture holds one song that would decode,
# not because this lane plays it.
#
#   tools/qualification/media-library.sh
#
# CNA_NATIVE_LIBRARY selects a single library instead of the admitted three.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
sbcl=${SBCL:-sbcl}

mkdir -p "$root/build-probe"
cd "$root"

fixture="$root/build-probe/media-library-fixture"
rm -rf "$fixture"
python3 "$here/make-media-library-fixture.py" "$fixture" | sed 's/^/  /'
echo

kinds='lifetime identity counts song-members cross-path picture-tree ordinary-absences'

run_one () {
    label=$1
    library=$2
    log="$root/build-probe/media-library-$label.log"

    if [ ! -f "$library" ]; then
        echo "FAIL $label: $library does not exist" >&2
        return 1
    fi

    echo "== $label: $library =="
    SDL_AUDIODRIVER=dummy \
    XDG_CONFIG_HOME="$fixture/config" \
    CNA_NATIVE_LIBRARY="$library" \
    CNA_LISP_VALUEPROBE="${CNA_LISP_VALUEPROBE:-$root/build-probe/libcna-lisp-valueprobe.so}" \
    "$here/with-virtual-screen.sh" "$sbcl" --non-interactive \
        --load "$HOME/quicklisp/setup.lisp" \
        --eval '(push (truename ".") asdf:*central-registry*)' \
        --eval '(asdf:test-system "cna-common-lisp")' > "$log" 2>&1 || {
            echo "FAIL $label: the suite failed; last lines:" >&2
            tail -40 "$log" >&2
            return 1
        }

    grep '^media library : ' "$log" | sed 's/^/  /'

    missing=0
    for kind in $kinds; do
        if ! grep -q "^media library : $kind " "$log"; then
            echo "FAIL $label: the suite recorded no '$kind' evidence. Each kind is" >&2
            echo "     required by name: a library that opens says nothing about what" >&2
            echo "     it enumerates, and what it enumerates says nothing about whether" >&2
            echo "     two paths to one entity agree." >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || return 1
    echo "  all 7 kinds recorded"
    echo
}

failures=0
if [ -n "${CNA_NATIVE_LIBRARY:-}" ]; then
    run_one "requested" "$CNA_NATIVE_LIBRARY" || failures=$((failures + 1))
else
    for version in 0.21.0 0.22.0 0.23.0; do
        run_one "$version" "$HOME/deps/cna-c-abi-$version/libcna_c_api.so" \
            || failures=$((failures + 1))
    done
fi

if [ "$failures" -ne 0 ]; then
    echo "FAIL $failures lane(s) failed" >&2
    exit 1
fi

cat <<'EOF'
== what this run proved ==
  MEDIA_LIBRARY_LIFETIME           every borrowed handle went back and the
                                   registry was left empty
  MEDIA_LIBRARY_IDENTITY           nine properties, each answering one object
                                   over handles that differ per call
  MEDIA_LIBRARY_COUNTS             exact counts from a generated fixture, not a
                                   non-zero assertion against somebody's music
  MEDIA_LIBRARY_SONG_MEMBERS       Song.Artist, .Album and .Genre answered
  MEDIA_LIBRARY_CROSS_PATH         two paths to one album agreed; the indexer
                                   answered fresh-but-equal facades
  MEDIA_LIBRARY_PICTURE_TREE       a root with no parent, and both back-pointers
  MEDIA_LIBRARY_ORDINARY_ABSENCES  NIL and empty as answers, not as gaps

  Not proved, and not claimed: that a library song can be played. The fixture's
  tagged MP3 indexes and does not decode -- playback is MediaPlayer's surface
  and has its own lane. Nor is anything here a claim about a real device's
  music: the whole point of the fixture is that this lane never reads one.
EOF
