# MediaLibrary: the pre-implementation audit

Measured 2026-09-08, before any of the closure was written, against all three
admitted CNA ABIs. It exists because **route coverage is not closure evidence**:
every route in `media_library.h` could be present and answer something, and the
closure could still be wrong about the thing that matters — whether the objects
those routes hand back are the objects XNA's contract says they are.

## 1. The routes, and what is the same across the admitted set

| | 0.21.0 | 0.22.0 | 0.23.0 |
| --- | --- | --- | --- |
| routes declared in `media_library.h` | 148 | 148 | 148 |
| header SHA-256 (first 16) | `8196739d886eaeef` | `8196739d886eaeef` | `8196739d886eaeef` |
| exported from the built library | 148/148 | 148/148 | 148/148 |

The header is **byte-identical** across the admitted set, and every route is
exported by every build. That is surface evidence only — the Storage closure
established that identical headers can still behave differently — so section 3
measures behaviour on each rather than inferring the older two from 0.23.0.

`cna_media_source_*` is the exception to "all of it is in `media_library.h`":
those six routes live in `media.h`, which this binding already binds for `Song`
and `SongCollection`. An audit that reads only `media_library.h` concludes that
`MediaSource.GetAvailableMediaSources()` has no route. It has four.

## 2. Member coverage: 142 of 142, no gaps

| Classification | Members |
| --- | ---: |
| mapped to one or more routes | 83 |
| equality predicate (`op_Equality` + both `Equals` overloads collapse to one) | 18 |
| not applicable — universal (`ToString`, `GetHashCode`, `Finalize`, `op_Inequality`) | 32 |
| not applicable — `GetEnumerator`, on the `SongCollection` precedent | 6 |
| enum fields (`MediaSourceType`) | 3 |
| **no route** | **0** |

**Nothing in this closure is blocked on a missing route.** That is not the same
as "every member will be complete": the sections below are where the risk is.

## 3. What the routes actually answer, measured

Fixture: `tools/qualification/make-media-library-fixture.py`, one tag-only MP3
and one real WAV under a generated XDG root. Identical on 0.21.0, 0.22.0 and
0.23.0 — every line below was produced three times.

    songs 2  albums 2  artists 2  genres 1  playlists 0  pictures 2
    song[0] Probe Track One  artist=CNA-Lisp Probe Artist  album=CNA-Lisp Probe Album  genre=Probe Genre
    song[1] probe-tone       artist=ml-fixture             album=Music                 genre=<UNAVAILABLE>
    RootPictureAlbum pictures=1 sub-albums=1 parent=<none>
    SavedPictures 0
    MediaSource type=0 name="Local Device"

### 3.1 The three missing `Song` members really do close

`Song.Artist`, `.Album` and `.Genre` are `missing` today, and the recorded reason
is that `cna_song_get_artist` "reports it unavailable for a song created from a
file path — the only kind this closure can make". That reason was correct and is
about to stop applying: `media_library.h` says outright that **"only a song
obtained from a media library has one"**, and a library song answers all three.
Measured above: the tagged song carries artist, album and genre.

**This is the closure's headline payoff and it is now evidence rather than
expectation.** It is also conditional — see 3.3.

### 3.2 XNA caches its collections; CNA hands back a fresh handle each call

`MediaLibrary` holds **private fields** for `songs`, `artists`, `albums`,
`playlists`, `genres`, `pictures`, `savedPictures`, `rootPictureAlbum` and
`mediaSource`, and `get_Songs` populates the field on first read and returns it
afterwards. The same shape repeats on every entity: `Album` caches `artist`,
`genre` and `songs`; `Artist` and `Genre` cache `songs` and `albums`; `Playlist`
caches `songs`; `PictureAlbum` caches `albums`, `parent` and `pictures`. **So in
XNA every one of these properties answers the same object every time.**

CNA does not: `cna_media_library_get_songs` called twice answers two different
handles, measured. The projection must therefore **cache the facade per owner**,
which is exactly what `Game.Content`, `Game.Window` and `Game.Components`
already do here — "answered by identity, because XNA's are fields". A facade
built per call would be two objects holding two identities for one entity, and
`(eq (songs library) (songs library))` would answer false where XNA answers true.

**Collection *items* are the opposite case and already have a precedent.**
`SongCollection.Item` is documented here as "a fresh object each time … so two
reads of one index are `SONG-EQUAL` and not `EQ`". The six new collections take
that same rule; nothing about item identity changes.

### 3.3 Untagged files get path-derived metadata, and that is a fixture hazard

The WAV has no ID3 tags, and CNA does not leave its artist and album empty — it
derives them from the directory structure: `artist=ml-fixture`, `album=Music`,
which are **the fixture's own directory names**. Genre stays unavailable.

So the *counts* (2/2/2/1) are stable, and two of the *names* are a function of
where the fixture happens to live. A test asserting `artist="ml-fixture"` would
pass here and fail from any other path. The qualification lane must assert the
tagged song's names and the collection counts, and must not assert the untagged
song's derived names.

### 3.4 Optional values are a three-parameter route family

Nine routes carry an `out_available` flag beside the out-parameter, and reading
one as a two-parameter route silently corrupts the call — that mistake was made
while writing this audit and produced a confident "RootPictureAlbum unavailable"
that was a probe defect, not a CNA answer:

    cna_song_get_artist / _album / _genre
    cna_album_get_artist / _genre
    cna_picture_get_album
    cna_picture_album_get_parent
    cna_media_library_get_root_picture_album
    cna_media_library_get_picture_from_token   (four parameters)

Each maps to an XNA member that can legitimately be absent. The projection
decision — `NIL` versus a condition — is per member and is not made here.

### 3.5 The picture tree, `SavedPictures`, and `MediaSource`

`RootPictureAlbum` answers a real tree: one picture at the root, one sub-album
for the nested directory, and **no parent for the root**, which is what a root
should report. `SavedPictures` is 0 and that is correct rather than a gap — CNA
deliberately does not create the "Saved Pictures" directory until `SavePicture`
is called, so an untouched library has none.

`MediaSource` answers `type=0` (`LocalDevice`) and `name="Local Device"`, but
**it has no handle of its own**: its two properties are read off the *library*
(`cna_media_library_get_media_source_type` and the name pair), and the
enumeration is index-based over `cna_media_source_*_at` with no object in
between. So `MediaSource` projects as a facade over its library rather than as an
independently constructible object, and `MediaLibrary(MediaSource)` is
`cna_media_library_create_from_source`, which takes an **index**, borrows the
source and copies its kind and name.

## 4. What this audit does not answer

* Whether a library `Song` can be **played**. The tagged MP3 indexes and does not
  decode; the WAV decodes. Playback of a library song is `MediaPlayer`'s surface,
  already complete, and is a fixture question rather than a route question.
* Item-level identity *across* collections — whether `library.Songs[0]` and
  `album.Songs[0]` denote one entity. The handles differ, as 3.2 predicts they
  would, and the equality predicates (`cna_*_equals`) are the intended answer.
  That is a test to write, not a fact established here.
