;;;; media-library.lisp --- the media-library half of Microsoft.Xna.Framework.Media.
;;;;
;;;; `MediaLibrary' and the ten types reachable from it. The playback half --
;;;; `MediaPlayer', `Song', `SongCollection' -- is in the files beside this one
;;;; and needs no library; this is the half that says what music the device has.
;;;;
;;;; --- what makes a library non-empty, and why that was the whole question ---
;;;;
;;;; `media_library.h' says opening one "scans the device's music and picture
;;;; locations" and that "an empty library is an ordinary result, not a failure".
;;;; So a library that answers zero proves nothing, and for a long time this
;;;; closure was declined on the belief that CI could only ever qualify *empty*.
;;;; That was measuring the wrong thing. SDL resolves the user folders through
;;;; `$XDG_CONFIG_HOME/user-dirs.dirs', so pointing that at a generated tree
;;;; makes the library deterministic and non-empty on every admitted ABI --
;;;; songs 2, albums 2, artists 2, genres 1, pictures 2, measured three times
;;;; each. `docs/media-library-audit.md' is the audit; CNA's own C-API suite
;;;; builds its fixture the same way.
;;;;
;;;; --- the ownership shape, which is Model's and not SongCollection's --------
;;;;
;;;; **The library owns everything reached through it, and every handle into it
;;;; is borrowed.** CNA states both halves: "the library owns every album,
;;;; artist, genre, playlist, song and collection reached through it", and
;;;; `cna_album_destroy' "releases an album handle -- the album itself belongs to
;;;; its media library and is untouched". The library object dies "once no handle
;;;; into it is left", so the handles are a reference count and giving them back
;;;; is not optional.
;;;;
;;;; Every route that answers a collection or an entity makes a **new** handle:
;;;; `cna_media_library_get_songs' called twice answers two, measured. That is
;;;; exactly the shape `Model' already has -- "every route that answers a bone, a
;;;; mesh or a collection makes a new registry handle" -- so this file follows
;;;; `src/graphics/model.lisp' rather than `SongCollection', which is an owned
;;;; child of the game and a different thing entirely.
;;;;
;;;; --- and XNA caches, so the facades are answered by identity ---------------
;;;;
;;;; `MediaLibrary' holds **private fields** for `songs', `artists', `albums',
;;;; `playlists', `genres', `pictures', `savedPictures', `rootPictureAlbum' and
;;;; `mediaSource', and `get_Songs' fills its field on first read and answers it
;;;; forever after. Every entity does the same: `Album' caches `artist', `genre'
;;;; and `songs'; `Artist' and `Genre' cache `songs' and `albums'; `Playlist'
;;;; caches `songs'. So in the original **every one of these properties answers
;;;; the same object every time**, and a projection that built a facade per call
;;;; would answer `EQ' false where the original answers true.
;;;;
;;;; So each property is cached here, which also means **one handle per property
;;;; for the library's lifetime** rather than one per read. The two facts fit
;;;; together: caching is what XNA's semantics require and what keeps the handle
;;;; count bounded.
;;;;
;;;; Collection *items* are the opposite case and already have a precedent in
;;;; this binding: `SongCollection.Item' answers "a fresh object each time ... so
;;;; two reads of one index are SONG-EQUAL and not EQ". The four collections here
;;;; take the same rule.

(in-package #:microsoft.xna.framework.media)

;;; --- MediaSourceType --------------------------------------------------------

(xna::define-xna-enum media-source-type
  '((:local-device . 0)
    (:windows-media-connect . 4))
  :documentation
  "Microsoft.Xna.Framework.Media.MediaSourceType: what kind of thing a library is on.

Two members and **they are not consecutive**: the pinned contract gives
`LocalDevice' 0 and `WindowsMediaConnect' 4, with nothing between. A projection
that numbered them 0 and 1 would translate the second one into a value the
original does not have, which is why this table carries the exact values rather
than an ordinal.

Only `:LOCAL-DEVICE' is reachable here. CNA refuses any other kind when a library
is opened from a source -- `cna_media_library_create_from_source' answers
`CNA_RESULT_NOT_SUPPORTED' -- and says it is refusing it \"exactly as the
canonical constructor refuses it\", so the refusal is XNA's rather than CNA's.")

;;; --- the retain ledger ------------------------------------------------------

(defun %library-retain (library thunk)
  "Record one thing LIBRARY must undo, and answer THUNK.

Newest first, which is leaf first: a collection handle is taken before the
entities read out of it, and an entity before anything resolved through it. The
same ledger `Model' keeps, and for the same reason -- a destruction pass written
as a second copy of the construction walk leaks whatever the two disagree about."
  (push thunk (%library-native-parts library))
  thunk)

(defun %library-retain-handle (library handle destroyer)
  "Record a borrowed CNA handle LIBRARY must give back, and answer it."
  (%library-retain library (lambda () (funcall destroyer handle)))
  handle)

(defun %library-of (object)
  "The MEDIA-LIBRARY OBJECT was reached through."
  (slot-value object '%library))

;;; --- MediaLibrary -----------------------------------------------------------

(defclass media-library (cna-lisp.internal:native-object)
  ((%native-parts :initform '() :accessor %library-native-parts
                  :documentation
                  "Thunks giving every borrowed handle back, newest first.")
   ;; XNA's nine private fields, and they are fields here for the same reason:
   ;; each property answers one object forever.
   (%songs :initform nil) (%albums :initform nil) (%artists :initform nil)
   (%genres :initform nil) (%playlists :initform nil)
   (%media-source :initform nil))
  (:documentation
   "Microsoft.Xna.Framework.Media.MediaLibrary: the device's music and pictures.

    (let ((library (make-instance 'media-library)))
      (count-of (songs library)))

**Opening it scans**, and an empty library is an ordinary result rather than a
failure -- CNA says so and this binding does not turn it into a condition. What
is scanned is the platform's music and picture folders, which SDL resolves
through `$XDG_CONFIG_HOME/user-dirs.dirs'.

**Every collection it answers is the same object every time**, as XNA's fields
are: `(eq (songs library) (songs library))' is true. The objects *inside* a
collection are not -- `ITEM' answers a fresh facade per read, which is what
`SongCollection' already does.

**It is an owned child of the active game and must be disposed.** Everything
reached through it is released with it: the entities and collections hold
borrowed handles, and disposing the library gives every one back."))

(defmethod initialize-instance :after ((library media-library)
                                       &rest initargs &key source
                                       &allow-other-keys)
  (unless (getf initargs :handle)
    (let* ((operation "make-instance 'media-library")
           (game (%media-game operation))
           ;; **XNA's second constructor takes a `MediaSource'; CNA's route takes
           ;; an index into the enumeration.** So the source is resolved back to
           ;; its position here rather than the caller being asked for a number
           ;; the original never mentions. A source that is not one this device
           ;; offers is refused before any native call.
           (source-index
             (when source
               (unless (typep source 'media-source)
                 (error 'xna:cna-argument-error
                        :operation operation :parameter-name "source"
                        :object-type 'media-library
                        :format-control "source must be a MEDIA-SOURCE; ~s was given."
                        :format-arguments (list source)))
               (or (position source (available-media-sources)
                             :test (lambda (a b)
                                     (and (eq (media-source-type-of a)
                                              (media-source-type-of b))
                                          (equal (%media-source-name a)
                                                 (%media-source-name b)))))
                   (error 'xna:cna-argument-error
                          :operation operation :parameter-name "source"
                          :object-type 'media-library
                          :format-control
                          "~s is not one of the media sources this device offers."
                          :format-arguments (list source))))))
      (cffi:with-foreign-object (out :uint64)
        (cna-lisp.internal:check-result
         (if source-index
             (cna-lisp.internal.ffi::%media-library-create-from-source
              (cna-lisp.internal:handle-of game) source-index out)
             (cna-lisp.internal.ffi::%media-library-create
              (cna-lisp.internal:handle-of game) out))
         operation :object-type 'media-library)
        (let ((handle (cffi:mem-ref out :uint64)))
          (cna-lisp.internal:record-construction-undo
           library (lambda () (cna-lisp.internal.ffi::%media-library-destroy handle)))
          (setf (cna-lisp.internal:handle-of library) handle
                (slot-value library 'cna-lisp.internal::owner) game
                (slot-value library 'cna-lisp.internal::owner-thread)
                (cna-lisp.internal:owner-thread-of game))
          (cna-lisp.internal:register-child game library)
          (cna-lisp.internal:record-construction-undo
           library (lambda () (cna-lisp.internal:invalidate library))))))))

(defmethod cna-lisp.internal:destroy-native ((library media-library))
  "Give every borrowed handle back, then the library's own.

Leaf first, which is what the ledger's order already is. CNA destroys the library
object once no handle into it is left, so releasing the library handle before the
handles into it would be correct and would still leave this binding holding
handles it could never give back."
  (dolist (thunk (%library-native-parts library))
    (ignore-errors (funcall thunk)))
  (setf (%library-native-parts library) '())
  (let ((handle (cna-lisp.internal:handle-of library)))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%media-library-dispose handle)
     "dispose" :object-type 'media-library)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%media-library-destroy handle)
     "dispose" :object-type 'media-library)))

(defmethod print-object ((library media-library) stream)
  (print-unreadable-object (library stream :type t)
    (format stream "~:[live~;disposed~]"
            (cna-lisp.internal:disposed-state-of library))))

;;; --- the four library entities ----------------------------------------------
;;;
;;; `Album', `Artist', `Genre' and `Playlist' are one shape: a borrowed handle
;;; into a library, a name, some collections cached in fields, and an equality
;;; that XNA defines by handle. They are defined by a macro rather than four
;;; times over, because four hand-written copies of one shape is where the fifth
;;; divergence hides.

(defmacro %define-library-entity (name documentation &key extra-slots)
  (let ((class name))
    `(progn
       (defclass ,class (cna-lisp.internal:native-object)
         ((%library :initarg :library :initform nil)
          (%songs :initform nil)
          (%albums :initform nil)
          ,@extra-slots)
         (:documentation ,documentation))
       (defmethod print-object ((object ,class) stream)
         (print-unreadable-object (object stream :type t)
           (format stream "~s" (ignore-errors (name object))))))))

(%define-library-entity album
  "Microsoft.Xna.Framework.Media.Album: one album in a media library.

A **borrowed** view into its library: the album belongs to the library and is
released with it, so it has no `DISPOSE' of its own that destroys anything CNA
owns. `ARTIST', `GENRE' and `SONGS' each answer the same object every time, as
XNA's fields do."
  :extra-slots ((%artist :initform nil) (%genre :initform nil)))

(%define-library-entity artist
  "Microsoft.Xna.Framework.Media.Artist: one artist in a media library.

`SONGS' and `ALBUMS' each answer the same object every time, as XNA's fields do.")

(%define-library-entity genre
  "Microsoft.Xna.Framework.Media.Genre: one genre in a media library.

`SONGS' and `ALBUMS' each answer the same object every time, as XNA's fields do.")

(%define-library-entity playlist
  "Microsoft.Xna.Framework.Media.Playlist: one playlist in a media library.

`SONGS' answers the same object every time, as XNA's field does.")

;;; --- the four collections ---------------------------------------------------

(defmacro %define-library-collection (name element documentation)
  `(progn
     (defclass ,name (cna-lisp.internal:native-object)
       ((%library :initarg :library :initform nil))
       (:documentation ,documentation))
     (defmethod print-object ((collection ,name) stream)
       (print-unreadable-object (collection stream :type t)
         (format stream "~a ~(~a~)~:p" (ignore-errors (count-of collection))
                 ',element)))))

(%define-library-collection album-collection album
  "Microsoft.Xna.Framework.Media.AlbumCollection: an ordered, read-only list of albums.

`ITEM' answers a **fresh** `ALBUM' each time, which is what CNA's `get_at' route
does and what XNA's own indexer does. Compare with `ALBUM-EQUAL', not `EQ'.")

(%define-library-collection artist-collection artist
  "Microsoft.Xna.Framework.Media.ArtistCollection: an ordered, read-only list of artists.
`ITEM' answers a fresh `ARTIST' each time; compare with `ARTIST-EQUAL'.")

(%define-library-collection genre-collection genre
  "Microsoft.Xna.Framework.Media.GenreCollection: an ordered, read-only list of genres.
`ITEM' answers a fresh `GENRE' each time; compare with `GENRE-EQUAL'.")

(%define-library-collection playlist-collection playlist
  "Microsoft.Xna.Framework.Media.PlaylistCollection: an ordered, read-only list of playlists.
`ITEM' answers a fresh `PLAYLIST' each time; compare with `PLAYLIST-EQUAL'.")

;;; --- building a borrowed facade ---------------------------------------------

(defun %adopt-borrowed (class library handle)
  "Wrap a borrowed HANDLE from LIBRARY in a facade of CLASS.

The handle is recorded in the library's ledger, so it goes back when the library
is disposed and not before -- CNA keeps the library alive until every handle into
it is released, which makes forgetting one a leak that outlives the program's
last reference to the library."
  (let ((object (make-instance class :handle handle
                                     :ownership :parent-owned :owner library)))
    ;; `:HANDLE' rather than a constructor argument, and that is load-bearing for
    ;; `SONG-COLLECTION': its own initializer builds a *new* native collection
    ;; unless a handle is supplied, and a borrowed view must wrap the library's
    ;; rather than make one of its own.
    (setf (cna-lisp.internal:handle-of object) handle
          (slot-value object 'cna-lisp.internal::owner-thread)
          (cna-lisp.internal:owner-thread-of library))
    (when (slot-exists-p object '%library)
      (setf (slot-value object '%library) library))
    ;; The ledger *invalidates* the facade; it does not dispose it. Disposing
    ;; would call the native `_dispose' route on an object the library owns,
    ;; which is the one thing a borrowed view must never do.
    (%library-retain library (lambda () (cna-lisp.internal:invalidate object)))
    object))

(defmacro %with-library-handle ((variable library route &rest arguments) &body body)
  "Call ROUTE for a new borrowed handle, retain it, and bind it."
  (declare (ignore library))
  ;; LIBRARY is named by every caller for readability and is not referenced in
  ;; the expansion: the handle comes from ROUTE and is retained by the body.
  (let ((out (gensym "OUT")))
    `(cffi:with-foreign-object (,out :uint64)
       (cna-lisp.internal:check-result (,route ,@arguments ,out) "media-library")
       (let ((,variable (cffi:mem-ref ,out :uint64)))
         (declare (ignorable ,variable))
         ,@body))))

;;; --- names, and the equality XNA defines by handle ---------------------------

(defmacro %define-entity-name (class size-route copy-route)
  `(defmethod name ((object ,class))
     (cna-lisp.internal:check-usable object "name")
     (let ((handle (cna-lisp.internal:handle-of object)))
       (cna-lisp.internal:count-then-copy-string
        (lambda (out) (,size-route handle out))
        (lambda (buffer capacity out) (,copy-route handle buffer capacity out))
        "name"))))

(%define-entity-name album  cna-lisp.internal.ffi::%album-get-name-size
                            cna-lisp.internal.ffi::%album-copy-name)
(%define-entity-name artist cna-lisp.internal.ffi::%artist-get-name-size
                            cna-lisp.internal.ffi::%artist-copy-name)
(%define-entity-name genre  cna-lisp.internal.ffi::%genre-get-name-size
                            cna-lisp.internal.ffi::%genre-copy-name)
(%define-entity-name playlist cna-lisp.internal.ffi::%playlist-get-name-size
                              cna-lisp.internal.ffi::%playlist-copy-name)

(defmacro %define-entity-equal (name class route documentation)
  `(progn
     (defgeneric ,name (a b) (:documentation ,documentation))
     (defmethod ,name ((a ,class) (b ,class))
       (cna-lisp.internal:check-usable a ,(string-downcase (symbol-name name)))
       (cna-lisp.internal:check-usable b ,(string-downcase (symbol-name name)))
       (cffi:with-foreign-object (out :uint8)
         (cna-lisp.internal:check-result
          (,route (cna-lisp.internal:handle-of a) (cna-lisp.internal:handle-of b) out)
          ,(string-downcase (symbol-name name)))
         (not (zerop (cffi:mem-ref out :uint8)))))
     (defmethod ,name (a b) (declare (ignore a b)) nil)))

(%define-entity-equal album-equal album cna-lisp.internal.ffi::%album-equals
  "Whether two ALBUMs are the same album.

**One predicate for what XNA spells three ways.** `op_Equality',
`Equals(Object)' and `Equals(Album)' are one question in Common Lisp, and this is
it; `op_Inequality' is its negation and is not projected, which is the universal
rule for an operator here. XNA compares the album's native handle, and so does
`cna_album_equals'.

Two reads of one collection index answer two facades, so `EQ' is the wrong test
and this is the right one -- the same statement `SONG-EQUAL' makes.")

(%define-entity-equal artist-equal artist cna-lisp.internal.ffi::%artist-equals
  "Whether two ARTISTs are the same artist. See `ALBUM-EQUAL'.")
(%define-entity-equal genre-equal genre cna-lisp.internal.ffi::%genre-equals
  "Whether two GENREs are the same genre. See `ALBUM-EQUAL'.")
(%define-entity-equal playlist-equal playlist cna-lisp.internal.ffi::%playlist-equals
  "Whether two PLAYLISTs are the same playlist. See `ALBUM-EQUAL'.")

;;; --- cached collection properties -------------------------------------------
;;;
;;; Each fills its slot on first read and answers it afterwards, which is what
;;; XNA's private field does. The handle is taken **once**, for the library's
;;; life, rather than once per read -- which is the other half of why caching is
;;; right here and not merely convenient.

(defmacro %define-cached-view (reader owner-class slot get-route view-class destroy-route
                               documentation)
  "Define READER on OWNER-CLASS: a lazily built, permanently cached facade."
  `(defmethod ,reader ((object ,owner-class))
     ,documentation
     (cna-lisp.internal:check-usable object ,(string-downcase (symbol-name reader)))
     (or (slot-value object ',slot)
         (let ((library (if (typep object 'media-library) object (%library-of object))))
           (%with-library-handle (handle library ,get-route
                                  (cna-lisp.internal:handle-of object))
             (%library-retain-handle library handle #',destroy-route)
             (setf (slot-value object ',slot)
                   (%adopt-borrowed ',view-class library handle)))))))

;;; MediaLibrary's five music collections.

(defgeneric songs (object)
  (:documentation
   "The songs of a `MEDIA-LIBRARY', an `ALBUM', an `ARTIST', a `GENRE' or a
`PLAYLIST', as a `SONG-COLLECTION'.

**The same object every time**, because XNA's is a private field filled on first
read. `(eq (songs library) (songs library))' is true."))

(defgeneric albums (object)
  (:documentation
   "The albums of a `MEDIA-LIBRARY', an `ARTIST' or a `GENRE', as an
`ALBUM-COLLECTION'. The same object every time; see `SONGS'."))

(defgeneric artists (library)
  (:documentation "MediaLibrary.Artists. The same object every time; see `SONGS'."))
(defgeneric genres (library)
  (:documentation "MediaLibrary.Genres. The same object every time; see `SONGS'."))
(defgeneric playlists (library)
  (:documentation "MediaLibrary.Playlists. The same object every time; see `SONGS'."))

(%define-cached-view songs media-library %songs
  cna-lisp.internal.ffi::%media-library-get-songs song-collection
  cna-lisp.internal.ffi::%song-collection-destroy
  "MediaLibrary.Songs: every song in the library.")

(%define-cached-view albums media-library %albums
  cna-lisp.internal.ffi::%media-library-get-albums album-collection
  cna-lisp.internal.ffi::%album-collection-destroy
  "MediaLibrary.Albums: every album in the library.")

(%define-cached-view artists media-library %artists
  cna-lisp.internal.ffi::%media-library-get-artists artist-collection
  cna-lisp.internal.ffi::%artist-collection-destroy
  "MediaLibrary.Artists: every artist in the library.")

(%define-cached-view genres media-library %genres
  cna-lisp.internal.ffi::%media-library-get-genres genre-collection
  cna-lisp.internal.ffi::%genre-collection-destroy
  "MediaLibrary.Genres: every genre in the library.")

(%define-cached-view playlists media-library %playlists
  cna-lisp.internal.ffi::%media-library-get-playlists playlist-collection
  cna-lisp.internal.ffi::%playlist-collection-destroy
  "MediaLibrary.Playlists: every playlist in the library.")

;;; The entities' own cached views.

(%define-cached-view songs album %songs
  cna-lisp.internal.ffi::%album-get-songs song-collection
  cna-lisp.internal.ffi::%song-collection-destroy
  "Album.Songs: the album's songs, in track order.")

(%define-cached-view songs artist %songs
  cna-lisp.internal.ffi::%artist-get-songs song-collection
  cna-lisp.internal.ffi::%song-collection-destroy
  "Artist.Songs: every song by the artist.")

(%define-cached-view albums artist %albums
  cna-lisp.internal.ffi::%artist-get-albums album-collection
  cna-lisp.internal.ffi::%album-collection-destroy
  "Artist.Albums: every album by the artist.")

(%define-cached-view songs genre %songs
  cna-lisp.internal.ffi::%genre-get-songs song-collection
  cna-lisp.internal.ffi::%song-collection-destroy
  "Genre.Songs: every song in the genre.")

(%define-cached-view albums genre %albums
  cna-lisp.internal.ffi::%genre-get-albums album-collection
  cna-lisp.internal.ffi::%album-collection-destroy
  "Genre.Albums: every album in the genre.")

(%define-cached-view songs playlist %songs
  cna-lisp.internal.ffi::%playlist-get-songs song-collection
  cna-lisp.internal.ffi::%song-collection-destroy
  "Playlist.Songs: the playlist's songs, in order.")

;;; --- the optional entity properties -----------------------------------------
;;;
;;; `cna_album_get_artist', `cna_album_get_genre' and the three `cna_song_get_*'
;;; routes all take an `out_available' flag beside the handle: the entity may
;;; legitimately have none. XNA answers `null' there, so this answers NIL --
;;; absence is an ordinary value here rather than a condition, which is what the
;;; original does and what a caller can branch on.

(defmacro %define-optional-view (reader owner-class slot get-route view-class destroy-route
                                 documentation)
  `(defmethod ,reader ((object ,owner-class))
     ,documentation
     (cna-lisp.internal:check-usable object ,(string-downcase (symbol-name reader)))
     (or (slot-value object ',slot)
         (let ((library (if (typep object 'media-library) object (%library-of object))))
           (cffi:with-foreign-objects ((out :uint64) (available :uint8))
             (cna-lisp.internal:check-result
              (,get-route (cna-lisp.internal:handle-of object) out available)
              ,(string-downcase (symbol-name reader)))
             (when (zerop (cffi:mem-ref available :uint8))
               (return-from ,reader nil))
             (let ((handle (cffi:mem-ref out :uint64)))
               (%library-retain-handle library handle #',destroy-route)
               (setf (slot-value object ',slot)
                     (%adopt-borrowed ',view-class library handle))))))))

(defgeneric artist (object)
  (:documentation
   "The `ARTIST' of an `ALBUM' or a `SONG', or NIL when it has none.

**NIL is an ordinary answer, not a failure.** XNA answers null and CNA reports it
through an `out_available' flag beside the handle -- `cna_song_get_artist' says
only a song obtained from a media library has one, so a song built from a file
path answers NIL here."))

(defgeneric genre (object)
  (:documentation "The `GENRE' of an `ALBUM' or a `SONG', or NIL. See `ARTIST'."))

(defgeneric album (object)
  (:documentation "The `ALBUM' of a `SONG', or NIL. See `ARTIST'."))

(%define-optional-view artist album %artist
  cna-lisp.internal.ffi::%album-get-artist artist
  cna-lisp.internal.ffi::%artist-destroy
  "Album.Artist: the album's artist, or NIL.")

(%define-optional-view genre album %genre
  cna-lisp.internal.ffi::%album-get-genre genre
  cna-lisp.internal.ffi::%genre-destroy
  "Album.Genre: the album's genre, or NIL.")

;;; --- the three Song members this closure exists to close ---------------------
;;;
;;; They were `missing' until now, and the recorded reason was that
;;; `cna_song_get_artist' "reports it unavailable for a song created from a file
;;; path -- the only kind this closure can make". That was true and has stopped
;;; being the whole story: a song obtained from a library has a library context,
;;; and answers all three. Measured on every admitted ABI.
;;;
;;; A library song's facade carries the library it came from; a song built from a
;;; file has none, and answers NIL without asking CNA.

(defmethod artist ((song song))
  "Song.Artist: the artist of a library song, or NIL for one built from a file."
  (cna-lisp.internal:check-usable song "artist")
  (%song-library-view song 'artist '%song-artist
                      #'cna-lisp.internal.ffi::%song-get-artist
                      #'cna-lisp.internal.ffi::%artist-destroy))

(defmethod album ((song song))
  "Song.Album: the album of a library song, or NIL for one built from a file."
  (cna-lisp.internal:check-usable song "album")
  (%song-library-view song 'album '%song-album
                      #'cna-lisp.internal.ffi::%song-get-album
                      #'cna-lisp.internal.ffi::%album-destroy))

(defmethod genre ((song song))
  "Song.Genre: the genre of a library song, or NIL for one built from a file."
  (cna-lisp.internal:check-usable song "genre")
  (%song-library-view song 'genre '%song-genre
                      #'cna-lisp.internal.ffi::%song-get-genre
                      #'cna-lisp.internal.ffi::%genre-destroy))

(defun %song-library-view (song class slot get-route destroy-route)
  "One of SONG's three library views, cached as XNA's fields are."
  (or (slot-value song slot)
      (let ((library (%song-library song)))
        (cffi:with-foreign-objects ((out :uint64) (available :uint8))
          (cna-lisp.internal:check-result
           (funcall get-route (cna-lisp.internal:handle-of song) out available) "song view")
          (when (or (null library) (zerop (cffi:mem-ref available :uint8)))
            (return-from %song-library-view nil))
          (let ((handle (cffi:mem-ref out :uint64)))
            (%library-retain-handle library handle destroy-route)
            (setf (slot-value song slot)
                  (%adopt-borrowed class library handle)))))))

;;; --- the collections' count and indexer --------------------------------------

(defmacro %define-collection-access (class element count-route at-route destroy-route)
  `(progn
     (defmethod count-of ((collection ,class))
       (cna-lisp.internal:check-usable collection "count-of")
       (cffi:with-foreign-object (out :int32)
         (cna-lisp.internal:check-result
          (,count-route (cna-lisp.internal:handle-of collection) out) "count-of")
         (cffi:mem-ref out :int32)))
     (defmethod item ((collection ,class) index)
       (let ((operation "item"))
         (cna-lisp.internal:check-usable collection operation)
         (let ((count (count-of collection)))
           (unless (and (integerp index) (<= 0 index) (< index count))
             (error 'xna:cna-argument-out-of-range-error
                    :operation operation :parameter-name "index"
                    :object-type ',class
                    :format-control
                    "index must be a valid index into the ~d ~(~a~)~:p this ~
                     collection holds; ~s was given."
                    :format-arguments (list count ',element index))))
         ;; A **fresh** facade per read, over a fresh borrowed handle, which is
         ;; what CNA's `get_at' answers and what XNA's own indexer does. The
         ;; handle joins the library's ledger, so a loop over a collection costs
         ;; one handle per read until the library is disposed -- the same bargain
         ;; `Model' makes, and the reason `EQ' is not the comparison here.
         (let ((library (%library-of collection)))
           (%with-library-handle (handle library ,at-route
                                  (cna-lisp.internal:handle-of collection) index)
             (%library-retain-handle library handle #',destroy-route)
             (%adopt-borrowed ',element library handle)))))))

(%define-collection-access album-collection album
  cna-lisp.internal.ffi::%album-collection-get-count
  cna-lisp.internal.ffi::%album-collection-get-at
  cna-lisp.internal.ffi::%album-destroy)

(%define-collection-access artist-collection artist
  cna-lisp.internal.ffi::%artist-collection-get-count
  cna-lisp.internal.ffi::%artist-collection-get-at
  cna-lisp.internal.ffi::%artist-destroy)

(%define-collection-access genre-collection genre
  cna-lisp.internal.ffi::%genre-collection-get-count
  cna-lisp.internal.ffi::%genre-collection-get-at
  cna-lisp.internal.ffi::%genre-destroy)

(%define-collection-access playlist-collection playlist
  cna-lisp.internal.ffi::%playlist-collection-get-count
  cna-lisp.internal.ffi::%playlist-collection-get-at
  cna-lisp.internal.ffi::%playlist-destroy)

;;; --- durations, and the album's artwork --------------------------------------

(defmacro %define-tick-reader (reader class route documentation)
  `(defmethod ,reader ((object ,class))
     ,documentation
     (cna-lisp.internal:check-usable object ,(string-downcase (symbol-name reader)))
     (cffi:with-foreign-object (out :int64)
       (cna-lisp.internal:check-result
        (,route (cna-lisp.internal:handle-of object) out)
        ,(string-downcase (symbol-name reader)))
       (cffi:mem-ref out :int64))))

(%define-tick-reader duration album cna-lisp.internal.ffi::%album-get-duration
  "Album.Duration: the sum of the album's songs' durations, in 100-nanosecond ticks.

The same unit `SONG''s duration uses, and the same reason: `System.TimeSpan' is
not a projected type, so a tick count is the value rather than an object.")

(%define-tick-reader duration playlist cna-lisp.internal.ffi::%playlist-get-duration
  "Playlist.Duration: the sum of the playlist's songs' durations, in ticks.")

(defgeneric has-art (album)
  (:documentation
   "Album.HasArt: whether the album has cover art.

Ask this before `ALBUM-ART': XNA answers a null stream when there is none, and a
program that reads first and checks afterwards has to handle both anyway."))

(defmethod has-art ((album album))
  (cna-lisp.internal:check-usable album "has-art")
  (cffi:with-foreign-object (out :uint8)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%album-get-has-art (cna-lisp.internal:handle-of album) out)
     "has-art")
    (not (zerop (cffi:mem-ref out :uint8)))))

(defun %album-blob (album size-route copy-route operation)
  "The bytes of one of ALBUM's two images, or NIL when it has none."
  (cna-lisp.internal:check-usable album operation)
  (let ((handle (cna-lisp.internal:handle-of album)))
    (cffi:with-foreign-object (size :uint64)
      (cna-lisp.internal:check-result (funcall size-route handle size) operation)
      (let ((bytes (cffi:mem-ref size :uint64)))
        (when (zerop bytes) (return-from %album-blob nil))
        (let ((buffer (make-array bytes :element-type '(unsigned-byte 8))))
          (cffi:with-foreign-object (raw :uint8 bytes)
            (cffi:with-foreign-object (written :uint64)
              (cna-lisp.internal:check-result
               (funcall copy-route handle raw bytes written) operation)
              (dotimes (i (min bytes (cffi:mem-ref written :uint64)))
                (setf (aref buffer i) (cffi:mem-aref raw :uint8 i)))))
          buffer)))))

(defgeneric album-art (album)
  (:documentation
   "Album.GetAlbumArt(): the cover art as a byte vector, or NIL when there is none.

**A byte vector rather than a stream.** XNA answers a `System.Stream', which this
binding projects as a Common Lisp stream everywhere it can -- but CNA hands the
image over as a sized buffer rather than as anything streamable, so the honest
projection is the bytes themselves. `docs/limitations.md' records the difference;
a caller that wants a stream makes one with `FLEXI-STREAMS' or its own."))

(defgeneric album-thumbnail (album)
  (:documentation
   "Album.GetThumbnail(): the thumbnail as a byte vector, or NIL. See `ALBUM-ART'."))

(defmethod album-art ((album album))
  (%album-blob album #'cna-lisp.internal.ffi::%album-get-art-size
               #'cna-lisp.internal.ffi::%album-copy-art "album-art"))

(defmethod album-thumbnail ((album album))
  (%album-blob album #'cna-lisp.internal.ffi::%album-get-thumbnail-size
               #'cna-lisp.internal.ffi::%album-copy-thumbnail "album-thumbnail"))

;;; --- IsDisposed, on every type of the closure --------------------------------

(defmacro %define-library-is-disposed (class route)
  `(defmethod is-disposed ((object ,class))
     (or (and (cna-lisp.internal:disposed-state-of object) t)
         (cffi:with-foreign-object (out :uint8)
           (and (zerop (,route (cna-lisp.internal:handle-of object) out))
                (not (zerop (cffi:mem-ref out :uint8))))))))

(%define-library-is-disposed media-library cna-lisp.internal.ffi::%media-library-get-is-disposed)
(%define-library-is-disposed album cna-lisp.internal.ffi::%album-get-is-disposed)
(%define-library-is-disposed artist cna-lisp.internal.ffi::%artist-get-is-disposed)
(%define-library-is-disposed genre cna-lisp.internal.ffi::%genre-get-is-disposed)
(%define-library-is-disposed playlist cna-lisp.internal.ffi::%playlist-get-is-disposed)
(%define-library-is-disposed album-collection cna-lisp.internal.ffi::%album-collection-get-is-disposed)
(%define-library-is-disposed artist-collection cna-lisp.internal.ffi::%artist-collection-get-is-disposed)
(%define-library-is-disposed genre-collection cna-lisp.internal.ffi::%genre-collection-get-is-disposed)
(%define-library-is-disposed playlist-collection cna-lisp.internal.ffi::%playlist-collection-get-is-disposed)

;;; --- MediaSource -------------------------------------------------------------
;;;
;;; **It has no handle of its own.** CNA exposes a media source two ways and
;;; neither is an object: a library reports its own with
;;; `cna_media_library_get_media_source_type' and the name pair, and the
;;; available ones are enumerated by index over `cna_media_source_*_at' with
;;; nothing in between. So `MEDIA-SOURCE' here is a value holding the kind and
;;; the name -- which is all XNA's own type carries -- rather than a native
;;; object with a lifetime.

(defclass media-source ()
  ((%kind :initarg :kind :reader media-source-type-of)
   (%name :initarg :name :reader %media-source-name))
  (:documentation
   "Microsoft.Xna.Framework.Media.MediaSource: where a media library's contents live.

Two readable properties and nothing else: `MEDIA-SOURCE-TYPE-OF' and `NAME'. XNA
has no public constructor for it either -- a source comes from a library or from
`AVAILABLE-MEDIA-SOURCES'.

**It is not a native object.** CNA gives a source no handle: a library reports
its own kind and name directly, and the available ones are enumerated by index.
So this is a value, it needs no disposal, and two sources describing the same
device are `EQUAL' by their contents rather than by identity."))

(defmethod name ((source media-source))
  "MediaSource.Name: the source's display name."
  (%media-source-name source))

(defmethod print-object ((source media-source) stream)
  (print-unreadable-object (source stream :type t)
    (format stream "~s ~s" (media-source-type-of source) (%media-source-name source))))

(defgeneric media-source (library)
  (:documentation
   "MediaLibrary.MediaSource: the source this library was opened from.

**The same object every time**, as XNA's private field is."))

(defmethod media-source ((library media-library))
  (cna-lisp.internal:check-usable library "media-source")
  (or (slot-value library '%media-source)
      (setf (slot-value library '%media-source)
            (let ((handle (cna-lisp.internal:handle-of library)))
              (make-instance
               'media-source
               :kind (cffi:with-foreign-object (out :uint32)
                       (cna-lisp.internal:check-result
                        (cna-lisp.internal.ffi::%media-library-get-media-source-type handle out)
                        "media-source")
                       (media-source-type-from-value (cffi:mem-ref out :uint32)))
               :name (cna-lisp.internal:count-then-copy-string
                      (lambda (out)
                        (cna-lisp.internal.ffi::%media-library-get-media-source-name-size
                         handle out))
                      (lambda (buffer capacity out)
                        (cna-lisp.internal.ffi::%media-library-copy-media-source-name
                         handle buffer capacity out))
                      "media-source"))))))

(defun available-media-sources ()
  "MediaSource.GetAvailableMediaSources(): every source this device offers.

A fresh list each call, because XNA's static answers a fresh array. **Index-based
rather than handle-based**: CNA enumerates sources by position and hands back no
object, so there is nothing here to release and nothing to dispose."
  (let* ((operation "available-media-sources")
         (game (%media-game operation))
         (handle (cna-lisp.internal:handle-of game)))
    (cffi:with-foreign-object (count :uint32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%media-source-get-available-count handle count) operation)
      (loop for index from 0 below (cffi:mem-ref count :uint32)
            collect (make-instance
                     'media-source
                     :kind (cffi:with-foreign-object (out :uint32)
                             (cna-lisp.internal:check-result
                              (cna-lisp.internal.ffi::%media-source-get-type-at
                               handle index out) operation)
                             (media-source-type-from-value (cffi:mem-ref out :uint32)))
                     :name (cna-lisp.internal:count-then-copy-string
                            (lambda (out)
                              (cna-lisp.internal.ffi::%media-source-get-name-size-at
                               handle index out))
                            (lambda (buffer capacity out)
                              (cna-lisp.internal.ffi::%media-source-copy-name-at
                               handle index buffer capacity out))
                            operation))))))

;;; --- the .NET type names -----------------------------------------------------

(defmacro %define-library-type-name (class size-route copy-route)
  `(defmethod xna:clr-type-name ((object ,class))
     "The .NET type name CNA reports for this type."
     (cna-lisp.internal:check-usable object "clr-type-name")
     (let ((handle (cna-lisp.internal:handle-of object)))
       (cna-lisp.internal:count-then-copy-string
        (lambda (out) (,size-route handle out))
        (lambda (buffer capacity out) (,copy-route handle buffer capacity out))
        "clr-type-name"))))

(%define-library-type-name media-library
  cna-lisp.internal.ffi::%media-library-get-type-name-size
  cna-lisp.internal.ffi::%media-library-copy-type-name)
(%define-library-type-name album
  cna-lisp.internal.ffi::%album-get-type-name-size
  cna-lisp.internal.ffi::%album-copy-type-name)
(%define-library-type-name artist
  cna-lisp.internal.ffi::%artist-get-type-name-size
  cna-lisp.internal.ffi::%artist-copy-type-name)
(%define-library-type-name genre
  cna-lisp.internal.ffi::%genre-get-type-name-size
  cna-lisp.internal.ffi::%genre-copy-type-name)
(%define-library-type-name playlist
  cna-lisp.internal.ffi::%playlist-get-type-name-size
  cna-lisp.internal.ffi::%playlist-copy-type-name)
(%define-library-type-name album-collection
  cna-lisp.internal.ffi::%album-collection-get-type-name-size
  cna-lisp.internal.ffi::%album-collection-copy-type-name)
(%define-library-type-name artist-collection
  cna-lisp.internal.ffi::%artist-collection-get-type-name-size
  cna-lisp.internal.ffi::%artist-collection-copy-type-name)
(%define-library-type-name genre-collection
  cna-lisp.internal.ffi::%genre-collection-get-type-name-size
  cna-lisp.internal.ffi::%genre-collection-copy-type-name)
(%define-library-type-name playlist-collection
  cna-lisp.internal.ffi::%playlist-collection-get-type-name-size
  cna-lisp.internal.ffi::%playlist-collection-copy-type-name)
