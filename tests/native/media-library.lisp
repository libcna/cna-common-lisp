;;;; media-library.lisp --- the MediaLibrary closure against a real CNA runtime.
;;;;
;;;; **The counts here are exact on purpose.** A lane that asserted "more than
;;;; zero" would pass against whatever music the machine running it happens to
;;;; hold, which is the non-determinism the whole XDG fixture exists to remove --
;;;; measured once at 48 pictures from a developer's own home directory. So the
;;;; expectations are two songs, two albums, two artists, one genre and two
;;;; pictures, and the *one* genre is the discriminating half: the fixture's WAV
;;;; carries no tags, so it contributes a path-derived artist and album but no
;;;; genre at all.
;;;;
;;;; **Route coverage is not closure evidence**, so most of this file is about
;;;; identity rather than about values: whether a property answers the same
;;;; object twice as XNA's field does, whether two paths to one entity agree, and
;;;; whether a collection's indexer answers a fresh facade as `SongCollection''s
;;;; already does. `docs/media-library-audit.md' is where those questions came
;;;; from.
;;;;
;;;; Without the fixture these tests record nothing and assert nothing about
;;;; contents: an ordinary suite run has no idea what is in the machine's music
;;;; folder, and inventing an expectation for it would be inventing a result.
;;;; `tools/qualification/media-library.sh' supplies the fixture and then
;;;; requires every kind of evidence below by name.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defvar *media-library-evidence* '()
  "What the media-library lane actually proved, level by level.")

(defun note-media-library (level description &rest arguments)
  (unless (assoc level *media-library-evidence*)
    (push (cons level (apply #'format nil description arguments))
          *media-library-evidence*)))

(defun media-library-proved-p (level)
  (assoc level *media-library-evidence*))

(defparameter *fixture-song* "Probe Track One"
  "The tagged song the fixture generator writes. Its presence is how these tests
know they are looking at the fixture rather than at somebody's music.

`DEFPARAMETER' rather than `DEFCONSTANT': SBCL compares a constant's old and new
values with `EQL', and two identical strings are not `EQL', so reloading the
system would raise `DEFCONSTANT-UNEQL' on a string constant that had not
changed.")

(defclass library-game (counting-game)
  ((library :initform nil :accessor game-library)
   (fixture :initform nil :accessor fixture-p)
   (observations :initform '() :accessor observations)
   (library-error :initform nil :accessor library-error))
  (:documentation
   "Opens a MEDIA-LIBRARY inside LoadContent and records what it found.

Inside, because `cna_media_library_create' takes a game handle and CNA lends that
only for the duration of a callback. The observations are values so the
assertions can run after the game has shut down."))

(defun observe-library (game key value)
  (push (cons key value) (observations game))
  value)

(defun observed-library (game key)
  (cdr (assoc key (observations game))))

(defmacro with-library-song ((variable collection index) &body body)
  "Take one SONG out of COLLECTION, use it, and dispose it.

**A song is owned where an album is borrowed, and that asymmetry is CNA's.**
`cna_album_collection_get_at' answers a *borrowed* album handle that the library
releases, but `cna_song_collection_get_at' answers an **owned** song that is a
child of the game and that the caller must release -- which is what
`%ADOPT-SONG-FROM-ROUTE' has always said of every route that hands back a song.
A test that walks a library's songs and forgets this leaves the game holding live
children and the next test cannot create a game at all."
  `(let ((,variable (media:item ,collection ,index)))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

(defmethod xna:load-content ((game library-game))
  (call-next-method)
  (handler-case
      (let ((library (make-instance 'media:media-library)))
        (setf (game-library game) library)
        (let* ((songs (media:songs library))
               (names (loop for i from 0 below (media:count-of songs)
                            collect (with-library-song (s songs i) (media:name s)))))
          (setf (fixture-p game) (and (member *fixture-song* names :test #'string=) t))
          (observe-library game :song-names names)
          ;; --- identity: XNA's properties are private fields ------------------
          (observe-library game :songs-eq (eq songs (media:songs library)))
          (observe-library game :albums-eq (eq (media:albums library) (media:albums library)))
          (observe-library game :artists-eq (eq (media:artists library) (media:artists library)))
          (observe-library game :genres-eq (eq (media:genres library) (media:genres library)))
          (observe-library game :playlists-eq
                           (eq (media:playlists library) (media:playlists library)))
          (observe-library game :pictures-eq
                           (eq (media:pictures library) (media:pictures library)))
          (observe-library game :saved-eq
                           (eq (media:saved-pictures library) (media:saved-pictures library)))
          (observe-library game :source-eq
                           (eq (media:media-source library) (media:media-source library)))
          (observe-library game :root-eq
                           (eq (media:root-picture-album library)
                               (media:root-picture-album library)))
          ;; --- counts ----------------------------------------------------------
          (observe-library game :counts
                           (list (media:count-of songs)
                                 (media:count-of (media:albums library))
                                 (media:count-of (media:artists library))
                                 (media:count-of (media:genres library))
                                 (media:count-of (media:playlists library))
                                 (media:count-of (media:pictures library))
                                 (media:count-of (media:saved-pictures library))))
          ;; --- the media source --------------------------------------------------
          (let ((source (media:media-source library)))
            (observe-library game :source-kind (media:media-source-type-of source))
            (observe-library game :source-name (media:name source))
            (observe-library game :available (length (media:available-media-sources))))
          ;; --- Song's three library members --------------------------------------
          (when (fixture-p game)
            (let ((index (position *fixture-song* names :test #'string=)))
              (with-library-song (tagged songs index)
                (observe-library game :song-artist
                                 (let ((a (media:artist tagged))) (and a (media:name a))))
                (observe-library game :song-album
                                 (let ((a (media:album tagged))) (and a (media:name a))))
                (observe-library game :song-genre
                                 (let ((a (media:genre tagged))) (and a (media:name a))))
                ;; The album reached from the song and the album reached from the
                ;; library are two borrowed handles, so EQ is false for them by
                ;; construction. They must still be the same album.
                (let* ((album (media:album tagged))
                       (albums (media:albums library))
                       (same (loop for i from 0 below (media:count-of albums)
                                   thereis (media:album-equal album (media:item albums i)))))
                  (observe-library game :album-two-paths same)
                  (observe-library game :album-artist
                                   (let ((a (media:artist album))) (and a (media:name a))))
                  (observe-library game :album-songs (media:count-of (media:songs album))))))
            ;; The indexer is fresh per read, and equal-but-not-EQ. Both songs are
            ;; released; they are owned children of the game.
            (with-library-song (first-read songs 0)
              (with-library-song (second-read songs 0)
                (observe-library game :item-not-eq (not (eq first-read second-read)))
                (observe-library game :item-equal
                                 (media:song-equal first-read second-read)))))
          ;; --- the picture tree ---------------------------------------------------
          (let ((root (media:root-picture-album library)))
            (observe-library game :root-name (and root (media:name root)))
            (when root
              (observe-library game :root-has-no-parent (null (media:parent root)))
              (observe-library game :root-pictures (media:count-of (media:pictures root)))
              (observe-library game :root-sub-albums (media:count-of (media:albums root)))
              (when (plusp (media:count-of (media:albums root)))
                (let ((child (media:item (media:albums root) 0)))
                  (observe-library game :child-name (media:name child))
                  (observe-library game :child-parent-is-root
                                   (let ((p (media:parent child)))
                                     (and p (media:picture-album-equal p root))))))
              (when (plusp (media:count-of (media:pictures root)))
                (let ((picture (media:item (media:pictures root) 0)))
                  (observe-library game :picture-size
                                   (list (media:width picture) (media:height picture)))
                  (observe-library game :picture-bytes
                                   (let ((b (media:image picture))) (and b (length b))))
                  (observe-library game :picture-album-back
                                   (let ((a (media:album picture)))
                                     (and a (media:picture-album-equal a root))))))))
          (observe-library game :unknown-token
                           (null (media:picture-from-token library "no-such-token-here")))))
    (error (condition) (setf (library-error game) condition))))

(defun %run-library-game ()
  "Run one LIBRARY-GAME to completion and answer it, library already released."
  (let ((game (make-instance 'library-game :exit-after 2)))
    (unwind-protect (xna:run game)
      (progn (when (game-library game) (ignore-errors (xna:dispose (game-library game))))
             (ignore-errors (xna:dispose game))))
    game))

;;; --- the tests ---------------------------------------------------------------

(define-native-test a-media-library-opens-and-releases-everything-it-lent
  "The library is an owned child of the game and every handle into it is borrowed.

CNA says the library owns every album, artist, genre, playlist, song and
collection reached through it, that each handle is borrowed, and that the object
dies \"once no handle into it is left\". So the closure's first claim is the
lifetime one: a library that lent out collections, entities and a picture tree is
still destroyable, and destroying it leaves the callback registry where it found
it."
  (let ((game (%run-library-game)))
    (is (null (library-error game)) "the library lane failed: ~a" (library-error game))
    (is-true (xna:disposed-p (game-library game))
             "the library was disposed after lending out every kind of view")
    (is (zerop (int:callback-registry-count))
        "the library cycle left ~d registry entry/entries"
        (int:callback-registry-count))
    (note-media-library
     :lifetime "a library that lent collections, entities and a picture tree was ~
                destroyed cleanly and left no registry entry")))

(define-native-test every-media-library-property-answers-one-object
  "XNA's nine collection properties are **private fields**, so each answers the
same object forever.

`MediaLibrary` holds `songs', `artists', `albums', `playlists', `genres',
`pictures', `savedPictures', `rootPictureAlbum' and `mediaSource', and
`get_Songs' fills its field on first read and answers it afterwards. CNA does
not: `cna_media_library_get_songs' called twice answers two handles, measured. So
this is the assertion that the projection caches rather than the assertion that
CNA does -- and it is nine claims rather than one because nine fields is what the
original has."
  (let ((game (%run-library-game)))
    (is (null (library-error game)) "the library lane failed: ~a" (library-error game))
    (dolist (key '(:songs-eq :albums-eq :artists-eq :genres-eq :playlists-eq
                   :pictures-eq :saved-eq :source-eq))
      (is-true (observed-library game key)
               "~(~a~): the property answered two different objects, where XNA's ~
                private field answers one" key))
    ;; RootPictureAlbum is EQ only when there is one at all; NIL is EQ to NIL.
    (is-true (observed-library game :root-eq)
             "root-picture-album answered two different objects")
    (note-media-library
     :identity "all nine MediaLibrary properties answered the same object twice, ~
                as XNA's private fields do, over CNA handles that differ per call")))

(define-native-test the-fixture-library-holds-exactly-what-the-fixture-put-in-it
  "Exact counts, and the one genre is the discriminating half.

Two songs, two albums, two artists, **one** genre, no playlists, two pictures and
no saved pictures. The genre is one rather than two because the fixture's WAV
carries no tags: CNA derives an artist and an album for it from the directory
names and leaves the genre absent. A lane asserting \"non-empty\" would pass
against a developer's own music folder -- measured once at 48 pictures -- which
is the whole reason the fixture exists."
  (let ((game (%run-library-game)))
    (is (null (library-error game)) "the library lane failed: ~a" (library-error game))
    (if (not (fixture-p game))
        (skip "no media-library fixture on this run; ~
               tools/qualification/media-library.sh supplies one")
        (progn
          (is (equal '(2 2 2 1 0 2 0) (observed-library game :counts))
              "songs/albums/artists/genres/playlists/pictures/saved were ~s, ~
               not the fixture's (2 2 2 1 0 2 0)"
              (observed-library game :counts))
          (is (eq :local-device (observed-library game :source-kind)))
          (is (string= "Local Device" (observed-library game :source-name)))
          (is (= 1 (observed-library game :available))
              "the device offers exactly one media source")
          (note-media-library
           :counts "songs 2, albums 2, artists 2, genres 1, playlists 0, pictures 2, ~
                    saved 0 -- exact, from the generated fixture")))))

(define-native-test a-library-song-answers-artist-album-and-genre
  "The three members this closure was chosen to close.

They were `missing' with the reason that `cna_song_get_artist' \"reports it
unavailable for a song created from a file path -- the only kind this closure can
make\". That was true until a library could make another kind. CNA says only a
song obtained from a media library has one; this is that song."
  (let ((game (%run-library-game)))
    (is (null (library-error game)) "the library lane failed: ~a" (library-error game))
    (if (not (fixture-p game))
        (skip "no media-library fixture on this run")
        (progn
          (is (string= "CNA-Lisp Probe Artist" (observed-library game :song-artist))
              "Song.Artist answered ~s" (observed-library game :song-artist))
          (is (string= "CNA-Lisp Probe Album" (observed-library game :song-album))
              "Song.Album answered ~s" (observed-library game :song-album))
          (is (string= "Probe Genre" (observed-library game :song-genre))
              "Song.Genre answered ~s" (observed-library game :song-genre))
          (note-media-library
           :song-members "a library song answered Artist, Album and Genre with the ~
                          fixture's own ID3 tags")))))

(define-native-test two-paths-to-one-album-agree
  "**Route coverage is not closure evidence**, and this is the difference.

The album reached through `Song.Album' and the album reached through
`MediaLibrary.Albums' are two borrowed handles, and `EQ' is false for them by
construction. They must still be the *same album*, which is what the equality
predicate is for -- and the album must agree about its own artist and its own
song count from either side."
  (let ((game (%run-library-game)))
    (is (null (library-error game)) "the library lane failed: ~a" (library-error game))
    (if (not (fixture-p game))
        (skip "no media-library fixture on this run")
        (progn
          (is-true (observed-library game :album-two-paths)
                   "the album reached from the song is not any of the albums the ~
                    library lists, so the two paths disagree")
          (is (string= "CNA-Lisp Probe Artist" (observed-library game :album-artist))
              "Album.Artist answered ~s" (observed-library game :album-artist))
          (is (= 1 (observed-library game :album-songs))
              "the tagged album holds one song")
          (is-true (observed-library game :item-not-eq)
                   "the indexer answered the same object twice; it must answer a fresh ~
                    facade, as SongCollection's does")
          (is-true (observed-library game :item-equal)
                   "two reads of one index are not equal, and they must be")
          (note-media-library
           :cross-path "Song.Album and MediaLibrary.Albums agreed on one album, and ~
                        the indexer answered fresh-but-equal facades")))))

(define-native-test the-picture-tree-has-a-root-and-the-root-has-no-parent
  "`PictureAlbum' is the only tree in this closure, and NIL is how its root is known.

XNA marks the root no other way, so the projection has to answer NIL for its
parent and a real album for a child's. The child must also point back at the
root, and a picture must point back at the album that holds it."
  (let ((game (%run-library-game)))
    (is (null (library-error game)) "the library lane failed: ~a" (library-error game))
    (if (not (fixture-p game))
        (skip "no media-library fixture on this run")
        (progn
          (is (string= "Pictures" (observed-library game :root-name)))
          (is-true (observed-library game :root-has-no-parent)
                   "the root reported a parent; NIL is the only thing that marks it")
          (is (= 1 (observed-library game :root-pictures)))
          (is (= 1 (observed-library game :root-sub-albums)))
          (is (string= "Nested" (observed-library game :child-name)))
          (is-true (observed-library game :child-parent-is-root)
                   "the sub-album's parent is not the root it came from")
          (is (equal '(64 64) (observed-library game :picture-size))
              "the fixture picture is 64x64; got ~s" (observed-library game :picture-size))
          (is (plusp (observed-library game :picture-bytes))
              "the picture answered no image bytes")
          (is-true (observed-library game :picture-album-back)
                   "the picture does not point back at the album that holds it")
          (note-media-library
           :picture-tree "root \"Pictures\" with no parent, one picture and one ~
                          sub-album \"Nested\" pointing back at it, and a 64x64 ~
                          picture whose album is the root")))))

(define-native-test an-empty-saved-collection-and-an-unknown-token-are-ordinary
  "Two absences that are answers rather than gaps, and CNA says so of each.

`SavedPictures' is empty because CNA does not create the \"Saved Pictures\"
directory until the first save, and an unknown token answers NIL because the
canonical lookup returns null for one. Reporting either as a failure would be
this binding inventing a condition the original does not raise."
  (let ((game (%run-library-game)))
    (is (null (library-error game)) "the library lane failed: ~a" (library-error game))
    (is-true (observed-library game :unknown-token)
             "an unknown picture token did not answer NIL")
    (when (fixture-p game)
      (is (zerop (nth 6 (observed-library game :counts)))
          "SavedPictures is empty until something is saved"))
    (note-media-library
     :ordinary-absences "an unknown token answered NIL and SavedPictures was empty, ~
                         both of which CNA documents as ordinary answers")))
