;;;; song.lisp --- Microsoft.Xna.Framework.Media.Song and SongCollection.
;;;;
;;;; **A song is a file path and some metadata, not decoded audio.** CNA's
;;;; constructor "checks only that the file exists; it does not open or decode
;;;; it", and XNA's is the same shape: the managed object stores a name, a
;;;; duration, a rating and a track number, and everything else is asked of the
;;;; native layer when a caller reads it.
;;;;
;;;; Both types are ordinary NATIVE-OBJECTs and children of the active game --
;;;; `cna_song_create' takes a game handle and answers an owned song, and
;;;; `cna_song_destroy' releases it.
;;;;
;;;; --- disposal is two native calls, and XNA is why -------------------------
;;;;
;;;; CNA splits what XNA joins. `cna_song_dispose' "only marks the song disposed;
;;;; every other member keeps answering afterwards, and disposing twice is a
;;;; successful no-op", and `cna_song_destroy' releases the handle. XNA has one
;;;; `Dispose()' and **every getter begins with `ThrowIfDisposed()'** -- so after
;;;; disposal the original refuses and CNA answers.
;;;;
;;;; XNA wins, and it costs nothing to make it win: NATIVE-OBJECT already tracks
;;;; a disposed state and refuses on it, which is the same refusal
;;;; `ObjectDisposedException' is. So `DISPOSE' marks the Lisp object disposed,
;;;; calls `cna_song_dispose' so the *native* song agrees, and then releases the
;;;; handle -- in that order, because there is no finalizer here to release it
;;;; later and a handle nothing can reach is a leak the ownership tests report.
;;;;
;;;; --- three members are missing, and the reason is a whole other closure ----
;;;;
;;;; `Song.Artist', `Song.Album' and `Song.Genre' answer `Artist', `Album' and
;;;; `Genre', which are **media-library** entities: their CNA routes are in
;;;; `media_library.h', not `media.h', and `cna_song_get_album' and its two
;;;; siblings document that "only a song obtained from a media library has one. A
;;;; song a caller created from a file path has no library context, so this
;;;; reports `CNA_FALSE'".
;;;;
;;;; Measured against all three admitted ABIs: for a song made from a file --
;;;; the only kind this closure can produce -- all three report unavailable. So
;;;; selecting the four library types to satisfy three members would add
;;;; fifty-three members that nothing here could exercise. They are declared
;;;; missing under DEPENDENCY_NOT_SELECTED instead, which is exactly what
;;;; `EffectParameter.GetValueTexture3D' is declared under for `Texture3D'.

(in-package #:microsoft.xna.framework.media)

;;; --- resolving the one active game -----------------------------------------

(defun %media-game (operation)
  "The process's one active game, or a refusal naming what is missing.

The same resolution `Keyboard.GetState' and the whole Audio surface perform, and
it exists for the same reason: the XNA member takes no game and CNA's route needs
one. `docs/limitations.md' records it as one projection limit rather than three."
  (let ((game (cna-lisp.internal:active-game)))
    (unless game
      (error 'xna:cna-invalid-state-error
             :operation operation
             :format-control
             "~a needs a live game: XNA's media API is static and CNA reaches it ~
              through the active game, and there is none. Create a game before ~
              using the media surface. docs/limitations.md records this as a ~
              runtime projection limit."
             :format-arguments (list operation)))
    (cna-lisp.internal:check-usable game operation)
    game))

(defun %media-game-handle (operation)
  (cna-lisp.internal:handle-of (%media-game operation)))

;;; --- Song -------------------------------------------------------------------

(defclass song (cna-lisp.internal:native-object)
  ((name :documentation "The display name, read once at construction.")
   (duration :documentation "The duration in ticks, read once at construction.")
   (rating :documentation "The rating, read once at construction.")
   (track-number :documentation "The track number, read once at construction.")
   ;; **A song knows the library it came from, or knows it came from none.**
   ;; `ARTIST', `ALBUM' and `GENRE' answer library entities, whose handles are
   ;; borrowed and belong in that library's ledger; a song built from a file path
   ;; has no library context and answers NIL for all three. The three views are
   ;; cached because XNA's are private fields.
   (%library :initarg :library :initform nil :reader %song-library
             :documentation "The MEDIA-LIBRARY this song came from, or NIL.")
   (%song-artist :initform nil)
   (%song-album :initform nil)
   (%song-genre :initform nil))
  (:documentation
   "Microsoft.Xna.Framework.Media.Song: one playable audio file.

    (let ((song (make-instance 'song :file-name \"music/theme.wav\"
                                     :name \"Theme\")))
      (media-player-play song)
      ...
      (xna:dispose song))

**There is no public constructor in XNA** -- only the static `FromUri', which
this projects as `SONG-FROM-URI'. CNA offers three creation routes, and
`MAKE-INSTANCE' here is the projection of the two that take a local path; they
are a **binding extension** rather than an XNA member, declared as one in
`src/capabilities.lisp', because a program that cannot make a song cannot use
this closure at all and XNA's own way in is a `MediaLibrary' this closure does
not select.

Four of its members answer from slots filled at construction -- `NAME',
`DURATION', `RATING' and `TRACK-NUMBER' -- because in XNA all four are fields its
getters read. `IS-RATED' is `Rating > 0', computed. `PLAY-COUNT' and
`IS-PROTECTED' ask the device.

**Every member refuses after disposal**, which is XNA's `ThrowIfDisposed()' and
not CNA's behaviour: CNA's disposed song keeps answering. See the file header.

`Song' is `IEquatable<Song>' and CNA has `cna_song_equals', so `SONG-EQUAL'
compares two songs the way the original's `Equals' does. `EQ' is *not* that
comparison: the queue hands out a fresh object for the same underlying song every
time it is asked, exactly as XNA's `MediaQueue.get_Item' does with its
`new Song(handle)'."))

(defparameter *song-constructor-shapes*
  '((:from-file "file-name" "name")
    (:from-file-with-duration "file-name" "name" "duration"))
  "The two local-path creation shapes this binding offers.

Neither is an XNA constructor -- XNA has none -- so both are declared binding
extensions. They are two rather than one because CNA's `cna_song_create' and
`cna_song_create_with_duration' answer different durations for the same file, and
collapsing them would make the duration a value a caller could not supply.")

(defmethod initialize-instance :after ((song song) &rest initargs
                                       &key file-name name duration
                                       &allow-other-keys)
  (let ((operation "make-instance 'song"))
    ;; An adoption -- the queue and a collection both produce one -- brings its
    ;; handle with it and runs none of this.
    (unless (getf initargs :handle)
      (let ((shape (xna::%check-overload-keywords
                    operation
                    (loop for (key nil) on initargs by #'cddr
                          for text = (string-downcase (symbol-name key))
                          unless (member text '("handle" "ownership" "owner"
                                                "owner-generation" "owner-thread")
                                         :test #'string=)
                            collect text)
                    *song-constructor-shapes* :object-type 'song)))
        (%create-song song shape file-name name duration operation)))
    (%read-song-fields song operation)))

(defun %create-song (song shape file-name name duration operation)
  "Create the native song and adopt its handle into the construction ledger."
  (check-type file-name string)
  (check-type name string)
  (when (eq shape :from-file-with-duration)
    (unless (and (integerp duration) (<= 0 duration))
      (error 'xna:cna-argument-out-of-range-error
             :operation operation :parameter-name "duration" :object-type 'song
             :format-control
             "duration is a TimeSpan, which this binding projects as a whole ~
              number of 100-nanosecond ticks, and CNA's route takes whole ~
              milliseconds; ~s is not a non-negative tick count."
             :format-arguments (list duration))))
  (let ((game (%media-game operation)))
    (cna-lisp.internal:with-utf8-view (path-data path-length file-name)
      (cna-lisp.internal:with-utf8-view (name-data name-length name)
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (if (eq shape :from-file-with-duration)
               (cna-lisp.internal.ffi::%song-create-with-duration
                (cna-lisp.internal:handle-of game) path-data path-length
                name-data name-length (round duration 10000) out)
               (cna-lisp.internal.ffi::%song-create
                (cna-lisp.internal:handle-of game) path-data path-length
                name-data name-length out))
           operation :object-type 'song)
          (%adopt-song song game (cffi:mem-ref out :uint64)))))))

(defun %adopt-song (song game handle)
  "Take ownership of HANDLE, recording both halves in the construction ledger.

The same two-step `SoundEffect' uses: the handle's release is recorded before
anything else can fail, and the object's invalidation after it is registered as a
child, so a subclass initializer that signals afterwards gives everything back."
  (cna-lisp.internal:record-construction-undo
   song (lambda () (cna-lisp.internal.ffi::%song-destroy handle)))
  (setf (cna-lisp.internal:handle-of song) handle
        (slot-value song 'cna-lisp.internal::owner) game
        (slot-value song 'cna-lisp.internal::owner-thread)
        (cna-lisp.internal:owner-thread-of game))
  (cna-lisp.internal:register-child game song)
  (cna-lisp.internal:record-construction-undo
   song (lambda () (cna-lisp.internal:invalidate song)))
  song)

(defun %read-song-fields (song operation)
  "Read the four values XNA's constructor stores into its own fields.

XNA's `Song' keeps `name', `duration', `rating' and `trackNumber' and answers all
four from the object; only `PlayCount' and `IsProtected' go back to the native
layer on every read. Reproducing that means reading them once, here."
  (let ((handle (cna-lisp.internal:handle-of song)))
    (setf (slot-value song 'name)
          (cna-lisp.internal:count-then-copy-string
           (lambda (out) (cna-lisp.internal.ffi::%song-get-name-size handle out))
           (lambda (buffer capacity out)
             (cna-lisp.internal.ffi::%song-copy-name handle buffer capacity out))
           operation))
    (cffi:with-foreign-object (ticks :int64)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%song-get-duration handle ticks)
       operation :object-type 'song)
      (setf (slot-value song 'duration) (cffi:mem-ref ticks :int64)))
    (cffi:with-foreign-object (value :int32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%song-get-rating handle value)
       operation :object-type 'song)
      (setf (slot-value song 'rating) (cffi:mem-ref value :int32))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%song-get-track-number handle value)
       operation :object-type 'song)
      (setf (slot-value song 'track-number) (cffi:mem-ref value :int32)))))

(defmethod print-object ((song song) stream)
  (print-unreadable-object (song stream :type t)
    (if (cna-lisp.internal:disposed-state-of song)
        (format stream "disposed")
        (format stream "~s" (slot-value song 'name)))))

(defun song-from-uri (name uri)
  "Song.FromUri(String, Uri): a song named NAME at URI.

XNA's one static factory. `System.Uri' is not in the selection and has no
counterpart to project, so URI is an ordinary Lisp string holding a `file:' URI
or a plain path -- which is exactly what `cna_song_create_from_uri' takes, and
the same projection `TitleContainer' already makes for a path.

Answers a `SONG' owned by the active game, like every other way of making one."
  (check-type name string)
  (check-type uri string)
  (let* ((operation "song-from-uri")
         (game (%media-game operation)))
    (cna-lisp.internal:with-utf8-view (name-data name-length name)
      (cna-lisp.internal:with-utf8-view (uri-data uri-length uri)
        (cffi:with-foreign-object (out :uint64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%song-create-from-uri
            (cna-lisp.internal:handle-of game) name-data name-length
            uri-data uri-length out)
           operation :object-type 'song)
          (%adopt-song-handle game (cffi:mem-ref out :uint64) operation))))))

;;; --- Song's read-through members --------------------------------------------

(defmacro %define-song-field-reader (name slot documentation)
  "Define one reader over a slot XNA's constructor fills.

**Each one refuses after disposal**, and that is the whole reason these are
methods rather than `:reader' slot options: XNA's getters all begin with
`ThrowIfDisposed()', and a bare slot reader would answer a disposed song's stored
value -- which is what CNA does and what XNA does not. The refusal
NATIVE-OBJECT's own check raises is the same one `ObjectDisposedException' is."
  `(progn
     (defgeneric ,name (song) (:documentation ,documentation))
     (defmethod ,name ((song song))
       (cna-lisp.internal:check-usable song ,(string-downcase (symbol-name name)))
       (slot-value song ',slot))))

(%define-song-field-reader name name
  "Song.Name: the display name.

A **stored** value: XNA's constructor fills the `name' field and the getter
answers it. CNA's `cna_song_create' \"stores it verbatim, despite that
constructor's own documentation claiming the name defaults to the file name\" --
so an empty name stays empty, which this binding passes through rather than
substituting the path.

Refuses after disposal.")

(%define-song-field-reader duration duration
  "Song.Duration: how long the song plays, in 100-nanosecond ticks.

A **stored** value, filled at construction. **It is zero for a song made from a
file**, and that is CNA's documented behaviour rather than a defect here: its
constructor \"checks only that the file exists; it does not open or decode it\",
so there is nothing to measure a duration from. `MAKE-INSTANCE' with a
`:DURATION' is the shape that supplies one.

Refuses after disposal.")

(%define-song-field-reader rating rating
  "Song.Rating: the song's rating, or zero when it has none.

A **stored** value. `IS-RATED' is `Rating > 0' over it.

Refuses after disposal.")

(%define-song-field-reader track-number track-number
  "Song.TrackNumber: the song's position on its album, or zero when it has none.

A **stored** value; only a song from a media library has a meaningful one.

Refuses after disposal.")

(defgeneric is-rated (song)
  (:documentation
   "Song.IsRated: whether the song carries a rating.

`Rating > 0' -- computed, not stored and not asked of the native layer. The
pinned IL is `get_Rating(); ldc.i4.0; cgt', so a rating of zero is *not* rated
and a negative rating would not be either."))

(defgeneric play-count (song)
  (:documentation
   "Song.PlayCount: how many times the song has been played.

One of the two members that really asks the native layer on every read, rather
than answering a field the constructor filled."))

(defgeneric is-protected (song)
  (:documentation
   "Song.IsProtected: whether the song is DRM-restricted.

The other read-through member. XNA answers `false` without asking when the song
has no valid handle; here a song without a handle has been disposed, and disposal
refuses first."))

(defmethod is-rated ((song song))
  (cna-lisp.internal:check-usable song "is-rated")
  (> (rating song) 0))

(defmethod play-count ((song song))
  (let ((operation "play-count"))
    (cna-lisp.internal:check-usable song operation)
    (cffi:with-foreign-object (value :int32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%song-get-play-count
        (cna-lisp.internal:handle-of song) value)
       operation :object-type 'song)
      (cffi:mem-ref value :int32))))

(defmethod is-protected ((song song))
  (let ((operation "is-protected"))
    (cna-lisp.internal:check-usable song operation)
    ;; `CNA_Bool' is one byte; reading it as four reads three the route never
    ;; wrote. CNA-TRUE-P over a `:uint8' is the established shape.
    (cffi:with-foreign-object (value :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%song-get-is-protected
        (cna-lisp.internal:handle-of song) value)
       operation :object-type 'song)
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref value :uint8)))))

;;; --- disposal ---------------------------------------------------------------

(defmethod cna-lisp.internal:destroy-native ((song song))
  "Dispose the native song, then release the handle. **Both, in that order.**

CNA splits what XNA joins: `cna_song_dispose' marks the song disposed and
`cna_song_destroy' releases the handle. XNA's one `Dispose()' does the first and
its finalizer the second, and this binding has no finalizer that touches a native
resource -- so both happen here.

The dispose is not skippable. A song the player copied into its queue outlives
the caller's handle, and the canonical disposal is what marks *that* song
disposed; releasing only the handle would leave a live song nothing had disposed."
  (let ((handle (cna-lisp.internal:handle-of song)))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%song-dispose handle) "dispose" :object-type 'song)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%song-destroy handle) "dispose" :object-type 'song)))

;;; --- equality ---------------------------------------------------------------

(defgeneric is-disposed (object)
  (:documentation
   "Whether OBJECT has been disposed.

`Song.IsDisposed' and `SongCollection.IsDisposed'.

**It answers this binding's own disposed state, not `cna_song_get_is_disposed',
and the two can disagree by design.** The Lisp object is disposed the moment
`DISPOSE' runs; CNA's flag is set by the `cna_song_dispose' half of that. Reading
the managed state is what XNA does -- its `IsDisposed' is a field read -- and it
is the state every other member's refusal is decided by, so a getter that asked
CNA could disagree with the refusal standing beside it.

Unlike every other member of these two types, it does **not** refuse after
disposal: answering `T' is the whole point of it."))

(defmethod is-disposed ((song song))
  (cna-lisp.internal:disposed-state-of song))

(defun song-equal (first second)
  "Song.Equals(Song) and its `op_Equality': whether two songs are the same song.

**`EQ' is not this comparison**, and the difference is XNA's rather than this
binding's: `MediaQueue.get_Item' answers `new Song(handle)' on every read, so the
queue hands out a different object for the same underlying song each time it is
asked. Two such objects are `SONG-EQUAL' and are not `EQ'.

`NIL' stands for the null both sides accept: `(song-equal nil nil)' is true and a
song is never equal to `NIL', which is `op_Equality''s own null handling."
  (cond ((and (null first) (null second)) t)
        ((or (null first) (null second)) nil)
        ((eq first second) t)
        (t (let ((operation "song-equal"))
             (cna-lisp.internal:check-usable first operation)
             (cna-lisp.internal:check-usable second operation)
             (cffi:with-foreign-object (out :uint8)
               (cna-lisp.internal:check-result
                (cna-lisp.internal.ffi::%song-equals
                 (cna-lisp.internal:handle-of first)
                 (cna-lisp.internal:handle-of second) out)
                operation :object-type 'song)
               (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))))))

(defmethod xna:clr-type-name ((song song))
  "The .NET type name CNA reports for the song type."
  (cna-lisp.internal:check-usable song "clr-type-name")
  (let ((handle (cna-lisp.internal:handle-of song)))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out) (cna-lisp.internal.ffi::%song-get-type-name-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%song-copy-type-name handle buffer capacity out))
     "clr-type-name")))

;;; --- SongCollection ---------------------------------------------------------

(defclass song-collection (cna-lisp.internal:native-object)
  ((%library :initarg :library :initform nil :reader %song-collection-library
             :documentation
             "The MEDIA-LIBRARY this collection views, or NIL for one a program
built. `ITEM' passes it to every song it makes, which is how a library song comes
to answer ARTIST, ALBUM and GENRE and a program-built one does not."))
  (:documentation
   "Microsoft.Xna.Framework.Media.SongCollection: an ordered, read-only list of songs.

    (make-instance 'song-collection :songs (list first second))

**XNA has no public constructor for it either** -- a `SongCollection' comes from
a `MediaLibrary', an `Album', an `Artist' or a `Genre', and none of those is in
this closure. CNA's `cna_song_collection_create' takes an array of songs, so
`MAKE-INSTANCE' here is a declared binding extension for the same reason `SONG''s
is: without it `MediaPlayer.Play(SongCollection)' could not be called at all.

**The collection keeps its songs alive.** CNA's route says so -- \"the canonical
collection stores non-owning pointers, so C retains the songs instead of letting
a released handle leave a dangling element behind\" -- and a caller may therefore
dispose its own song objects immediately after building one.

`ITEM' answers a **fresh** `SONG' each time, which is what CNA's `get_at' route
does and what XNA's own indexer does. Use `SONG-EQUAL' to compare, not `EQ'."))

(defmethod initialize-instance :after ((collection song-collection)
                                       &rest initargs &key songs
                                       &allow-other-keys)
  (let ((operation "make-instance 'song-collection"))
    (unless (getf initargs :handle)
      (unless (and (listp songs) (every (lambda (s) (typep s 'song)) songs))
        (error 'xna:cna-argument-error
               :operation operation :parameter-name "songs"
               :object-type 'song-collection
               :format-control
               "songs must be a list of SONG objects; ~s was given."
               :format-arguments (list songs)))
      (dolist (s songs) (cna-lisp.internal:check-usable s operation))
      (let ((game (%media-game operation))
            (count (length songs)))
        (cffi:with-foreign-object (handles :uint64 (max count 1))
          (loop for s in songs
                for i from 0
                do (setf (cffi:mem-aref handles :uint64 i)
                         (cna-lisp.internal:handle-of s)))
          (cffi:with-foreign-object (out :uint64)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%song-collection-create
              (cna-lisp.internal:handle-of game)
              (if (zerop count) (cffi:null-pointer) handles)
              count out)
             operation :object-type 'song-collection)
            (%adopt-song-collection collection game (cffi:mem-ref out :uint64))))))))

(defun %adopt-song-collection (collection game handle)
  "Take ownership of HANDLE, recording both halves in the construction ledger."
  (cna-lisp.internal:record-construction-undo
   collection (lambda () (cna-lisp.internal.ffi::%song-collection-destroy handle)))
  (setf (cna-lisp.internal:handle-of collection) handle
        (slot-value collection 'cna-lisp.internal::owner) game
        (slot-value collection 'cna-lisp.internal::owner-thread)
        (cna-lisp.internal:owner-thread-of game))
  (cna-lisp.internal:register-child game collection)
  (cna-lisp.internal:record-construction-undo
   collection (lambda () (cna-lisp.internal:invalidate collection)))
  collection)

(defmethod cna-lisp.internal:destroy-native ((collection song-collection))
  "Dispose the native collection, then release the handle -- the same two calls
`SONG''s disposal makes, and for the same reason."
  (let ((handle (cna-lisp.internal:handle-of collection)))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%song-collection-dispose handle)
     "dispose" :object-type 'song-collection)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%song-collection-destroy handle)
     "dispose" :object-type 'song-collection)))

(defgeneric count-of (collection)
  (:documentation
   "The number of elements in COLLECTION.

`SongCollection.Count'. Named `COUNT-OF' rather than `COUNT' because `CL:COUNT'
is a standard sequence function this package does not shadow -- the media package
has no member whose name collides badly enough to be worth shadowing one, which
is the judgement `microsoft.xna.framework.audio' made the other way for
`POSITION'."))

(defgeneric item (collection index)
  (:documentation
   "The element of COLLECTION at INDEX.

`SongCollection.Item' and `MediaQueue.Item', which is why it is a generic
function on two types rather than a reader on one.

**A fresh object each time.** XNA's own indexers answer `new Song(handle)`, and
CNA's `get_at` routes answer a new handle, so two reads of the same index are
`SONG-EQUAL' and are not `EQ'. That is the original's behaviour and is reproduced
rather than improved on."))

(defgeneric songs-vector (collection)
  (:documentation
   "Every song in COLLECTION, as a fresh simple vector.

A CNA-Lisp addition rather than an XNA member. XNA's collection is
`IEnumerable<Song>' and a program walks it with `foreach'; Common Lisp has no
`IEnumerator<T>' to project, and `GetEnumerator' is therefore declared not
applicable. This is what a program uses instead, and it is a *vector* so that the
count is O(1) and the elements are indexable, which is what the original's
enumerator plus `Count' gives.

Each element is freshly made, for the reason `ITEM' gives."))

(defmethod count-of ((collection song-collection))
  (let ((operation "count-of"))
    (cna-lisp.internal:check-usable collection operation)
    (cffi:with-foreign-object (out :int32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%song-collection-get-count
        (cna-lisp.internal:handle-of collection) out)
       operation :object-type 'song-collection)
      (cffi:mem-ref out :int32))))

(defmethod item ((collection song-collection) index)
  (let ((operation "item"))
    (cna-lisp.internal:check-usable collection operation)
    (let ((count (count-of collection)))
      (unless (and (integerp index) (<= 0 index) (< index count))
        (error 'xna:cna-argument-out-of-range-error
               :operation operation :parameter-name "index"
               :object-type 'song-collection
               :format-control
               "index must be a valid index into the ~d song~:p this collection ~
                holds; ~s was given."
               :format-arguments (list count index))))
    (%adopt-song-from-route
     operation
     (lambda (out)
       (cna-lisp.internal.ffi::%song-collection-get-at
        (cna-lisp.internal:handle-of collection) index out))
     (%song-collection-library collection))))

(defmethod songs-vector ((collection song-collection))
  (let ((count (count-of collection)))
    (let ((result (make-array count)))
      (dotimes (i count result)
        (setf (aref result i) (item collection i))))))

(defun %adopt-song-handle (game handle operation &optional library)
  "Build the CLOS SONG over a handle CNA has already given us.

The rule `%ADOPT-LOADED-SOUND-EFFECT' states: **whoever receives a handle from
CNA records its destruction**, and this did not receive it -- its caller did. So
the object is made through the ordinary `:HANDLE' adoption initargs, which is
where NATIVE-OBJECT takes ownership, and the four stored fields are read
afterwards.

A failure while reading them gives the handle back: the object is live and owned
by then, so disposing it is the undo."
  (declare (ignore operation))
  (let ((song (make-instance 'song
                             :handle handle
                             :library library
                             :ownership :owned
                             :owner game
                             :owner-thread (cna-lisp.internal:owner-thread-of game))))
    (handler-bind ((serious-condition
                     (lambda (condition)
                       (declare (ignore condition))
                       (ignore-errors (xna:dispose song)))))
      (cna-lisp.internal:register-child game song)
      song)))

(defun %adopt-song-from-route (operation route &optional library)
  "Make a SONG over the handle ROUTE answers, owned by the active game.

Every route that hands back a song -- the collection's indexer and both of the
queue's -- answers an **owned** handle the caller must release, so each of them
produces an ordinary child of the game rather than a borrowed view."
  (let ((game (%media-game operation)))
    (cffi:with-foreign-object (out :uint64)
      (cna-lisp.internal:check-result (funcall route out)
                                      operation :object-type 'song)
      (%adopt-song-handle game (cffi:mem-ref out :uint64) operation library))))

(defmethod xna:clr-type-name ((collection song-collection))
  "The .NET type name CNA reports for the song-collection type."
  (cna-lisp.internal:check-usable collection "clr-type-name")
  (let ((handle (cna-lisp.internal:handle-of collection)))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%song-collection-get-type-name-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%song-collection-copy-type-name
        handle buffer capacity out))
     "clr-type-name")))

(defmethod is-disposed ((collection song-collection))
  (cna-lisp.internal:disposed-state-of collection))

(defmethod print-object ((collection song-collection) stream)
  (print-unreadable-object (collection stream :type t)
    (if (cna-lisp.internal:disposed-state-of collection)
        (format stream "disposed")
        (format stream "~d song~:p" (count-of collection)))))
