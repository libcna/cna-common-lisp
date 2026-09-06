;;;; media.lisp --- the MediaPlayer closure against a real CNA C ABI library.
;;;;
;;;; **Nothing here is a claim that music was heard.** The device these tests
;;;; qualify against is SDL's `dummy' backend, which opens a playback device with
;;;; no speaker behind it. What that supports is a claim about *the transport
;;;; state machine, the play clock, the queue, object identity and the two static
;;;; events*, and nothing about audible output. `docs/qualification.md' names the
;;;; evidence levels; audible correctness is not among them and no assertion
;;;; below implies it.
;;;;
;;;; **Two branches and both assert**, the rule the audio, capture and rasterizer
;;;; lanes already follow:
;;;;
;;;;   a playback device opened   MEDIA_PLAYBACK and the lanes below it
;;;;   none opened                **MEDIA_UNAVAILABLE**: a `SONG' is still
;;;;                              created -- CNA's constructor only checks that
;;;;                              the file exists -- and the refusal arrives at
;;;;                              `MEDIA-PLAYER-PLAY', wrapped the way XNA wraps
;;;;                              it
;;;;
;;;; Neither branch is a skip. That asymmetry -- construction succeeds, playback
;;;; refuses -- is the same one `DynamicSoundEffectInstance' already has with
;;;; `SoundEffect', and it is asserted here rather than assumed.
;;;;
;;;; **The fixture is generated, not stored.** `tests/fixtures/test-tone.wav' is
;;;; the same one-second PCM16 file the SoundEffect closure already uses, and it
;;;; is produced by `tools/qualification/make-audio-fixtures.py' rather than being
;;;; sample audio anybody recorded.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

;;; --- what the media lanes prove, kept apart --------------------------------

(defvar *media-evidence* '()
  "What the media tests actually proved, newest first: (LEVEL . DESCRIPTION).

  :unavailable      no playback device opened; a SONG was still created and the
                    refusal arrived at PLAY, wrapped as XNA wraps it
  :playback         a device opened and the transport moved through
                    Playing -> Paused -> Playing -> Stopped
  :play-clock       the play position advanced at something like the wall clock
                    while frames ran, and stood still while paused
  :queue            the queue's count, active index and identity semantics hold
  :events           both static events reached handlers that take no arguments,
                    and stopped when their handlers were removed

Kept apart for the reason the audio and capture kinds are: a transport that
transitions says nothing about whether the play clock advances, and a clock that
advances says nothing about the events that announce it. **None is a claim that
music was heard**: the qualification's device is SDL's dummy backend.")

(defun note-media (level description &rest arguments)
  "Record LEVEL once."
  (unless (assoc level *media-evidence*)
    (push (cons level (apply #'format nil description arguments)) *media-evidence*)))

(defun media-proved-p (level)
  (assoc level *media-evidence*))

;;; --- fixtures ---------------------------------------------------------------

(defparameter +media-fixture+ "tests/fixtures/test-tone.wav"
  "The one-second PCM16 file the SoundEffect closure already generates.

A song is a *path* to CNA rather than decoded audio -- its constructor \"checks
only that the file exists; it does not open or decode it\" -- so any real file
would do. Using the one that is already generated keeps the promise that no
sample audio is stored in this repository.")

(defmacro with-media-game ((variable) &body body)
  "Run BODY with a live game, so the media surface has one to resolve.

The player is stopped and its queue left alone on the way out, so one test
cannot leave another playing."
  `(let ((,variable (make-instance 'xna:game :window-title "cna-lisp media tests")))
     (declare (ignorable ,variable))
     (unwind-protect (progn ,@body)
       (ignore-errors (media:media-player-stop))
       (%tear-down-audio-game ,variable))))

(defmacro with-song ((variable &rest initargs) &body body)
  "Build a SONG, run BODY, and dispose it however BODY ends."
  `(let ((,variable (make-instance 'media:song
                                   :file-name +media-fixture+
                                   :name "cna-lisp test tone"
                                   ,@initargs)))
     (unwind-protect (progn ,@body)
       (ignore-errors (xna:dispose ,variable)))))

(defun media-playback-available-p ()
  "Whether this environment can actually start playback.

**A measurement of the environment, not of the binding**, and needed for the same
reason `AUDIO-PLAYBACK-AVAILABLE-P' is: a song can be created with no device --
CNA's constructor only checks the file -- and only `Play' finds out. So the probe
is a real play attempt, and both of its outcomes are asserted somewhere."
  (with-song (song)
    (handler-case (progn (media:media-player-play song)
                         (media:media-player-stop)
                         t)
      (xna:cna-error () nil))))

;;; --- MediaState, against both authorities -----------------------------------

(test the-media-state-enumeration-is-the-contracts
  "The exact values of the pinned contract, which is also the pinned IL:
`Stopped' 0, `Playing' 1, `Paused' 2."
  (is (= 0 (media:media-state-value :stopped)))
  (is (= 1 (media:media-state-value :playing)))
  (is (= 2 (media:media-state-value :paused)))
  (is (eq :stopped (media:media-state-from-value 0)))
  (is (eq :playing (media:media-state-from-value 1)))
  (is (eq :paused (media:media-state-from-value 2)))
  (is (equal '(:stopped :playing :paused) (media:all-media-state)))
  ;; **It is not SoundState.** The two share every member name and agree on no
  ;; value, so nothing may be read across from one to the other.
  (is (/= (media:media-state-value :stopped)
          (audio:sound-state-value :stopped)))
  (is (/= (media:media-state-value :playing)
          (audio:sound-state-value :playing))))

(test the-media-state-enumeration-agrees-with-cna
  "Asserted rather than assumed, for the reason `BlendFunction' exists."
  (is (= (media:media-state-value :stopped)
         cna-lisp.internal.ffi::+media-state-stopped+))
  (is (= (media:media-state-value :playing)
         cna-lisp.internal.ffi::+media-state-playing+))
  (is (= (media:media-state-value :paused)
         cna-lisp.internal.ffi::+media-state-paused+)))

;;; --- VisualizationData, which needs nothing -------------------------------

(test visualization-data-allocates-two-buffers-of-cnas-own-size
  "The type owns nothing native, so this needs no game and no device.

The length is CNA's `CNA_VISUALIZATION_DATA_SIZE' rather than a number written
here, and both buffers start zeroed -- which is
`cna_visualization_data_init''s documented initial value."
  (let ((data (media:make-visualization-data)))
    (is (= cna-lisp.internal.ffi::+visualization-data-size+
           (length (media:frequencies data))))
    (is (= cna-lisp.internal.ffi::+visualization-data-size+
           (length (media:samples data))))
    (is (every #'zerop (media:frequencies data)))
    (is (every #'zerop (media:samples data)))
    (is (typep (media:frequencies data) 'media::visualization-sample-vector))
    ;; **The buffer is the object's own, not a copy**, which is what the type is
    ;; for: GetVisualizationData fills it in place and a caller reads it after.
    (is (eq (media:frequencies data) (media:frequencies data)))
    (is (not (eq (media:frequencies data) (media:samples data))))))

;;; --- the projection needs a game, and says so -------------------------------

(test media-with-no-game-signals-the-scope-condition
  "XNA's media API is static and takes no game; CNA's routes need one. With none,
the established projection-limit condition is raised -- the same one
`Keyboard.GetState' and the Audio and Microphone surfaces raise."
  (signals xna:cna-invalid-state-error (media:media-player-state))
  (signals xna:cna-invalid-state-error (media:media-player-volume))
  (signals xna:cna-invalid-state-error
    (make-instance 'media:song :file-name +media-fixture+ :name "x"))
  ;; **The queue itself needs none**, because the object holds nothing: XNA's
  ;; get_Queue is a static field read. Its *members* need one.
  (finishes (media:media-player-queue))
  (signals xna:cna-invalid-state-error
    (media:count-of (media:media-player-queue))))

;;; --- Song -------------------------------------------------------------------

(define-native-test a-song-is-a-path-and-its-metadata
  "CNA's constructor \"checks only that the file exists; it does not open or
decode it\", so the duration of a song made from a file is **zero** and its
library metadata is empty. That is CNA's documented behaviour, asserted rather
than worked around."
  (with-media-game (game)
    (with-song (song)
      (is (string= "cna-lisp test tone" (media:name song)))
      (is (zerop (media:duration song))
          "a file-created song has no duration: the constructor does not decode")
      (is (zerop (media:rating song)))
      (is (zerop (media:track-number song)))
      (is (null (media:is-rated song)) "Rating > 0 is false for a rating of zero")
      (is (integerp (media:play-count song)))
      (is (member (media:is-protected song) '(t nil)))
      (is (null (media:is-disposed song)))
      (is (string= "Microsoft.Xna.Framework.Media.Song" (xna:clr-type-name song))))))

(define-native-test a-song-with-a-duration-keeps-the-one-it-was-given
  "The second creation shape, which exists because CNA's `create' and
`create_with_duration' answer different durations for the same file."
  (with-media-game (game)
    (with-song (song :duration 25000000)
      (is (= 25000000 (media:duration song))
          "the duration the caller supplied is the one the song reports"))
    (signals xna:cna-argument-out-of-range-error
      (make-instance 'media:song :file-name +media-fixture+
                                 :name "bad" :duration -1))
    ;; A partial keyword set names no shape and is refused rather than defaulted.
    (signals xna:cna-usage-error
      (make-instance 'media:song :file-name +media-fixture+))
    (signals xna:cna-usage-error
      (make-instance 'media:song :name "no file"))))

(define-native-test a-song-refuses-every-member-after-disposal
  "**XNA's `ThrowIfDisposed()' and not CNA's behaviour.** CNA's disposed song
keeps answering -- its own header says every other member does -- and XNA's
getters all begin with a disposal test. XNA wins, and `IS-DISPOSED' is the one
member that still answers, because saying so is what it is for."
  (with-media-game (game)
    (let ((song (make-instance 'media:song :file-name +media-fixture+
                                           :name "doomed")))
      (is (null (media:is-disposed song)))
      (xna:dispose song)
      (is (xna:disposed-p song))
      (is (eq t (media:is-disposed song))
          "IS-DISPOSED still answers, and answers T")
      (dolist (reader '(media:name media:duration media:rating media:track-number
                        media:is-rated media:play-count media:is-protected))
        (signals xna:cna-disposed-error (funcall reader song)))
      ;; Disposing twice is a no-op, which is what CNA says and what XNA's
      ;; Dispose(bool) does with its already-disposed guard.
      (finishes (xna:dispose song)))))

(define-native-test songs-compare-by-value-and-not-by-identity
  "`Song' is `IEquatable<Song>' and CNA has `cna_song_equals'.

**EQ is not this comparison**, and that difference is XNA's: its queue and
collection indexers both end with `new Song(handle)', so two objects for one
underlying song are equal and are not identical."
  (with-media-game (game)
    (with-song (a)
      (with-song (b)
        (is (media:song-equal a a) "a song equals itself")
        (is (eq t (media:song-equal nil nil))
            "NIL equals NIL, which is op_Equality's own null handling")
        (is (null (media:song-equal a nil)))
        (is (null (media:song-equal nil a)))
        ;; Two songs over the same file: whether CNA calls them equal is CNA's
        ;; business and is recorded rather than asserted either way.
        (is (member (media:song-equal a b) '(t nil))
            "two independently created songs over one file compare somehow")))))

;;; --- SongCollection ---------------------------------------------------------

(define-native-test a-song-collection-indexes-and-counts
  "`Item' refuses an out-of-range index and answers a **fresh** object each time,
which is what XNA's own indexer does -- it ends with `newobj Song::.ctor'."
  (with-media-game (game)
    (with-song (a)
      (with-song (b)
        (let ((collection (make-instance 'media:song-collection :songs (list a b))))
          (unwind-protect
               (progn
                 (is (= 2 (media:count-of collection)))
                 (is (null (media:is-disposed collection)))
                 (is (string= "Microsoft.Xna.Framework.Media.SongCollection"
                              (xna:clr-type-name collection)))
                 (let ((first (media:item collection 0))
                       (again (media:item collection 0)))
                   (unwind-protect
                        (progn
                          (is (not (eq first again))
                              "the indexer answers a fresh object each time, as ~
                               XNA's own does")
                          (is (media:song-equal first again)
                              "and the two are equal, which is the comparison ~
                               that means anything here"))
                     (ignore-errors (xna:dispose first))
                     (ignore-errors (xna:dispose again))))
                 (signals xna:cna-argument-out-of-range-error
                   (media:item collection -1))
                 (signals xna:cna-argument-out-of-range-error
                   (media:item collection 2))
                 (let ((vector (media:songs-vector collection)))
                   (unwind-protect
                        (progn
                          (is (= 2 (length vector)))
                          (is (every (lambda (s) (typep s 'media:song)) vector)))
                     (map nil (lambda (s) (ignore-errors (xna:dispose s))) vector))))
            (ignore-errors (xna:dispose collection))))))))

(define-native-test a-song-collection-keeps-its-songs-alive
  "CNA states it: \"the canonical collection stores non-owning pointers, so C
retains the songs instead of letting a released handle leave a dangling element
behind. A caller may therefore release its own song handles immediately after
building a collection.\"

So a collection is still usable after every song it was built from is disposed,
and that is asserted rather than taken on trust."
  (with-media-game (game)
    (let* ((a (make-instance 'media:song :file-name +media-fixture+ :name "one"))
           (b (make-instance 'media:song :file-name +media-fixture+ :name "two"))
           (collection (make-instance 'media:song-collection :songs (list a b))))
      (unwind-protect
           (progn
             (xna:dispose a)
             (xna:dispose b)
             (is (= 2 (media:count-of collection))
                 "the collection still counts its songs after both were disposed")
             (let ((song (media:item collection 0)))
               (unwind-protect (is (stringp (media:name song)))
                 (ignore-errors (xna:dispose song)))))
        (ignore-errors (xna:dispose collection))))))

;;; --- the queue's identity ---------------------------------------------------

(define-native-test the-media-queue-is-one-object-forever
  "**XNA's own guarantee**: `MediaPlayer''s static constructor makes one
`MediaQueue' and `get_Queue' answers that static field. A projection that built a
fresh facade per call would pass every other test and fail this one."
  (with-media-game (game)
    (is (eq (media:media-player-queue) (media:media-player-queue)))
    (is (typep (media:media-player-queue) 'media:media-queue))
    (is (string= "Microsoft.Xna.Framework.Media.MediaQueue"
                 (xna:clr-type-name (media:media-player-queue))))))

(define-native-test an-empty-queue-answers-minus-one-without-asking
  "The IL seeds `ActiveSongIndex' with `ldc.i4.m1' and calls native only when
`Count' is nonzero, so an empty queue answers -1 whatever the runtime would have
said. `ActiveSong' is then NIL, and `PlayPosition' is zero for the same reason."
  (with-media-game (game)
    (media:media-player-stop)
    (let ((queue (media:media-player-queue)))
      (when (zerop (media:count-of queue))
        (is (= -1 (media:active-song-index queue)))
        (is (null (media:active-song queue)))
        (is (zerop (media:media-player-play-position)))))))

;;; --- the transport ----------------------------------------------------------

(define-native-test the-media-transport-obeys-the-guards-the-il-has
  "MEDIA_PLAYBACK, and the three guards that are XNA's and not CNA's.

    Pause   runs only when State == Playing
    Resume  runs only when State != Playing
    Stop    runs only when State != Stopped

So each is a **no-op** in the wrong state rather than an error or a transition,
and CNA accepts all three unconditionally -- which is why the guards are here.
Both branches of the device question assert."
  (with-media-game (game)
    (if (not (media-playback-available-p))
        (%note-media-unavailable)
        (with-song (song)
          (media:media-player-stop)
          (is (eq :stopped (media:media-player-state)))
          ;; The guards, on a stopped player: all three do nothing.
          (finishes (media:media-player-pause))
          (is (eq :stopped (media:media-player-state))
              "pausing a stopped player does nothing at all")
          (finishes (media:media-player-stop))
          (is (eq :stopped (media:media-player-state))
              "stopping a stopped player does nothing at all")
          ;; The state machine.
          (media:media-player-play song)
          (is (eq :playing (media:media-player-state)))
          (finishes (media:media-player-resume))
          (is (eq :playing (media:media-player-state))
              "resuming a playing player does nothing at all")
          (media:media-player-pause)
          (is (eq :paused (media:media-player-state)))
          (finishes (media:media-player-pause))
          (is (eq :paused (media:media-player-state))
              "pausing a paused player does nothing at all")
          (media:media-player-resume)
          (is (eq :playing (media:media-player-state)))
          (media:media-player-stop)
          (is (eq :stopped (media:media-player-state)))
          (note-media
           :playback
           "a playback device opened and the transport went :STOPPED -> ~
            :PLAYING -> :PAUSED -> :PLAYING -> :STOPPED, with each of XNA's ~
            three guards asserted as a no-op in the state it guards against. ~
            Nothing here is a claim that music was heard")))))

(defun %note-media-unavailable ()
  "The MEDIA_UNAVAILABLE assertion, which is a result and not a skip.

**A song is created anyway**, because CNA's constructor only checks that the file
exists, and the refusal arrives at `Play' -- wrapped, as XNA wraps a failed
`Play(Song)' in `InvalidOperationException(SongPlaybackFailed, inner)'. That
asymmetry is the same one `DynamicSoundEffectInstance' has with `SoundEffect'."
  (with-song (song)
    (is (stringp (media:name song))
        "a song is created with no playback device: CNA's constructor only ~
         checks that the file exists")
    (signals xna:cna-invalid-state-error (media:media-player-play song))
    (handler-case (media:media-player-play song)
      (xna:cna-invalid-state-error (condition)
        (is (not (null (xna:cna-error-cause condition)))
            "the refusal carries the mapped native failure as its cause, which ~
             is where XNA puts the inner exception")))
    (note-media
     :unavailable
     "no playback device opened. A SONG was created anyway -- CNA's constructor ~
      only checks that the file exists -- and the refusal arrived at PLAY, ~
      wrapped as XNA wraps it with the native failure as its cause")))

(define-native-test the-play-clock-advances-while-playing-and-stands-still-paused
  "The play-clock proof, with an explicit and justified tolerance.

An exact position would be a claim about this machine's scheduler, so the
assertion is a **window**: over a bounded run of frames the reported position
must advance by between a quarter and twice the wall-clock time that elapsed.
The lower bound is loose because a loaded machine can starve the mixer; the upper
bound is what catches a clock running fast or a position counted twice.

**And it must stand still while paused**, which is the half that makes it a clock
rather than a counter."
  (with-media-game (game)
    (if (not (media-playback-available-p))
        (%note-media-unavailable)
        (with-song (song)
          (media:media-player-play song)
          (let ((start (get-internal-real-time)))
            (dotimes (i 30) (xna:run-one-frame game))
            (let* ((position (media:media-player-play-position))
                   (elapsed (/ (float (- (get-internal-real-time) start) 1.0d0)
                               internal-time-units-per-second))
                   (expected (* elapsed 1d7)))
              (is (plusp position)
                  "the play position never moved in 30 frames, so no clock was ~
                   observed")
              (when (plusp position)
                (is (< (* 0.25d0 expected) position (* 2.0d0 expected))
                    "the position advanced to ~d ticks over ~,3fs, where the ~
                     wall clock implies about ~,0f. Outside a ~
                     quarter-to-double window it is not tracking playback."
                    position elapsed expected))
              ;; Paused, it must stand still.
              (media:media-player-pause)
              (let ((paused-at (media:media-player-play-position)))
                (dotimes (i 20) (xna:run-one-frame game))
                (is (= paused-at (media:media-player-play-position))
                    "the play position moved while the player was paused"))
              (media:media-player-stop)
              (note-media
               :play-clock
               "the play position advanced to ~d ticks (~,3fs) over ~d frames ~
                and stood still across 20 more while paused. Nothing here is a ~
                claim that music was heard: the device is SDL's dummy backend"
               position (/ position 1d7) 30)))))))

;;; --- the queue under playback -----------------------------------------------

(define-native-test playing-fills-the-queue-and-moves-through-it
  "MEDIA_QUEUE. `Play' clears the queue and enqueues, `MoveNext' and
`MovePrevious' **wrap** -- which is the managed layer's doing rather than the
runtime's -- and `ActiveSong' answers a fresh object equal to the entry."
  (with-media-game (game)
    (if (not (media-playback-available-p))
        (%note-media-unavailable)
        (with-song (a)
          (with-song (b)
            (let ((collection (make-instance 'media:song-collection
                                             :songs (list a b)))
                  (queue (media:media-player-queue)))
              (unwind-protect
                   (progn
                     (media:media-player-play collection)
                     (is (= 2 (media:count-of queue))
                         "Play(SongCollection) enqueued both songs")
                     (is (= 0 (media:active-song-index queue)))
                     (let ((active (media:active-song queue)))
                       (unwind-protect
                            (progn
                              (is (not (null active)))
                              (is (not (eq active a))
                                  "ActiveSong is a fresh object, as XNA's is")
                              (is (media:song-equal active a)
                                  "and it is equal to the entry it copies"))
                         (ignore-errors (xna:dispose active))))
                     (media:media-player-move-next)
                     (is (= 1 (media:active-song-index queue)))
                     (media:media-player-move-next)
                     (is (= 0 (media:active-song-index queue))
                         "MoveNext wraps to the first entry, which the managed ~
                          layer does rather than the runtime")
                     (media:media-player-move-previous)
                     (is (= 1 (media:active-song-index queue))
                         "MovePrevious wraps to the last entry")
                     ;; The setter clamps and does not refuse; the indexer does
                     ;; refuse. That asymmetry is the original's.
                     (setf (media:active-song-index queue) 99)
                     (is (= 1 (media:active-song-index queue))
                         "an index past the end clamps to the last entry")
                     (setf (media:active-song-index queue) -5)
                     (is (= 0 (media:active-song-index queue))
                         "and a negative one clamps to the first")
                     (signals xna:cna-argument-out-of-range-error
                       (media:item queue 99))
                     (media:media-player-stop)
                     (note-media
                      :queue
                      "Play enqueued a two-song collection, ActiveSong answered ~
                       a fresh object equal to its entry, MoveNext and ~
                       MovePrevious wrapped at both ends, and the active-index ~
                       setter clamped where the indexer refuses"))
                (ignore-errors (xna:dispose collection)))))))))

(define-native-test play-takes-exactly-xnas-three-overloads
  "`Play(Song)', `Play(SongCollection)' and `Play(SongCollection, Int32)' and
nothing else. **`(media-player-play song 2)' names no overload** and is refused:
XNA has no `Play(Song, Int32)', and a method that accepted and ignored the index
would give it one."
  (with-media-game (game)
    (if (not (media-playback-available-p))
        (%note-media-unavailable)
        (with-song (song)
          (let ((collection (make-instance 'media:song-collection
                                           :songs (list song))))
            (unwind-protect
                 (progn
                   (finishes (media:media-player-play song))
                   (finishes (media:media-player-play collection))
                   (finishes (media:media-player-play collection 0))
                   (signals xna:cna-usage-error (media:media-player-play song 0))
                   (signals xna:cna-argument-out-of-range-error
                     (media:media-player-play collection 1))
                   (signals xna:cna-argument-out-of-range-error
                     (media:media-player-play collection -1))
                   (signals xna:cna-argument-error (media:media-player-play 42))
                   (signals xna:cna-argument-error (media:media-player-play nil))
                   (media:media-player-stop)
                   ;; An empty collection is XNA's own refusal.
                   (let ((empty (make-instance 'media:song-collection :songs '())))
                     (unwind-protect
                          (signals xna:cna-argument-error
                            (media:media-player-play empty))
                       (ignore-errors (xna:dispose empty)))))
              (ignore-errors (xna:dispose collection))))))))

;;; --- the settings -----------------------------------------------------------

(define-native-test the-volume-setter-clamps-rather-than-refusing
  "The pinned IL is two ordered comparisons and no exception, so 2.0 sets 1.0 and
-1.0 sets 0.0. Measured, CNA clamps to the same bounds; the clamp is still
reproduced here, because a CNA that stopped clamping would otherwise change this
member's public behaviour silently."
  (with-media-game (game)
    (let ((original (media:media-player-volume)))
      (unwind-protect
           (progn
             (setf (media:media-player-volume) 0.5)
             (is (< (abs (- 0.5 (media:media-player-volume))) 1d-6))
             (setf (media:media-player-volume) 2.0)
             (is (< (abs (- 1.0 (media:media-player-volume))) 1d-6)
                 "a volume above one clamps to one rather than refusing")
             (setf (media:media-player-volume) -1.0)
             (is (< (abs (media:media-player-volume)) 1d-6)
                 "and one below zero clamps to zero")
             (signals xna:cna-argument-error
               (setf (media:media-player-volume) "loud")))
        (ignore-errors (setf (media:media-player-volume) original))))))

(define-native-test the-player-flags-round-trip
  "`IsMuted', `IsRepeating' and `IsShuffled': three booleans whose setters and
getters must agree, with or without a playback device.

**`IsVisualizationEnabled' is not among them, and that is a measurement.** It is
tested separately below because it is the one flag that **cannot be turned on
without a device**: measured on all three admitted ABIs with a driver SDL cannot
load, its setter succeeds and its getter still answers false. Lumping it in here
made this test fail on a machine with no sound card, which is an ordinary machine
rather than a broken one."
  (with-media-game (game)
    (dolist (pair (list (cons #'media:media-player-is-muted
                              (lambda (v) (setf (media:media-player-is-muted) v)))
                        (cons #'media:media-player-is-repeating
                              (lambda (v) (setf (media:media-player-is-repeating) v)))
                        (cons #'media:media-player-is-shuffled
                              (lambda (v) (setf (media:media-player-is-shuffled) v)))))
      (destructuring-bind (getter . setter) pair
        (let ((original (funcall getter)))
          (unwind-protect
               (progn
                 (funcall setter t)
                 (is (eq t (funcall getter)))
                 (funcall setter nil)
                 (is (null (funcall getter))))
            (ignore-errors (funcall setter original))))))))

(define-native-test visualization-can-only-be-enabled-where-there-is-a-device
  "**The one player flag whose setter can succeed and not take**, and both
branches assert.

Measured on all three admitted ABIs: with a playback device
`IsVisualizationEnabled' round-trips like the other three; with a driver SDL
cannot load its setter answers success and the getter still says false. Neither
is a failure -- visualization is computed from the mixer, and there is no mixer.
What must hold either way is that the setter does not *lie by raising*: it
reports success, and the getter is the truth."
  (with-media-game (game)
    (let ((original (media:media-player-is-visualization-enabled))
          (available (media-playback-available-p)))
      (unwind-protect
           (progn
             (finishes (setf (media:media-player-is-visualization-enabled) t))
             (if available
                 (is (eq t (media:media-player-is-visualization-enabled))
                     "with a playback device the flag round-trips")
                 (is (null (media:media-player-is-visualization-enabled))
                     "with no playback device the setter succeeds and the flag ~
                      stays false, which is CNA's answer and not a refusal"))
             (finishes (setf (media:media-player-is-visualization-enabled) nil))
             (is (null (media:media-player-is-visualization-enabled))
                 "turning it off always takes"))
        (ignore-errors
         (setf (media:media-player-is-visualization-enabled) original))))))

(define-native-test game-has-control-is-a-literal-and-cna-agrees
  "**It always answers true, and that is the pinned assembly's answer.**
`get_GameHasControl' is `ldc.i4.1; ret' -- a literal with no field behind it and
no native call. CNA has a real route and measured it agrees; the literal is still
what is projected, because agreement is not a reason to start asking."
  (with-media-game (game)
    (is (eq t (media:media-player-game-has-control)))
    (cffi:with-foreign-object (out :uint8)
      (let ((result (cna-lisp.internal.ffi::%media-player-get-game-has-control
                     (int:handle-of (int:active-game)) out)))
        (is (zerop result) "the native cross-check route must answer")
        (is (eq (eq t (media:media-player-game-has-control))
                (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))
            "CNA and the literal agree here, which is recorded rather than ~
             relied on")))))

(define-native-test visualization-data-is-untouched-while-visualization-is-off
  "The IL's own guard: after the null check `GetVisualizationData' tests
`IsVisualizationEnabled' and **returns without touching the buffers** when it is
false. So the caller's data keeps whatever it held, which is an answer rather
than a refusal."
  (with-media-game (game)
    (let ((original (media:media-player-is-visualization-enabled))
          (data (media:make-visualization-data)))
      (unwind-protect
           (progn
             (setf (media:media-player-is-visualization-enabled) nil)
             (fill (media:frequencies data) 0.25f0)
             (fill (media:samples data) 0.75f0)
             (finishes (media:media-player-get-visualization-data data))
             (is (every (lambda (v) (= v 0.25f0)) (media:frequencies data))
                 "the buffers must be untouched while visualization is off")
             (is (every (lambda (v) (= v 0.75f0)) (media:samples data)))
             ;; Enabled -- where a device lets it be enabled -- it fills them,
             ;; and it fills the caller's **own** object rather than replacing it.
             (setf (media:media-player-is-visualization-enabled) t)
             (let ((buffer (media:frequencies data)))
               (finishes (media:media-player-get-visualization-data data))
               (is (eq buffer (media:frequencies data))
                   "the object is filled in place, not replaced")
               (if (media:media-player-is-visualization-enabled)
                   (is (every (lambda (v) (typep v 'single-float)) buffer)
                       "and every element is still a binary32")
                   (is (every (lambda (v) (= v 0.25f0)) buffer)
                       "visualization could not be enabled here, so the buffers ~
                        are still untouched -- which is the same guard again")))
             (signals xna:cna-argument-error
               (media:media-player-get-visualization-data nil)))
        (ignore-errors
         (setf (media:media-player-is-visualization-enabled) original))))))

;;; --- the two static events --------------------------------------------------

(define-native-test the-static-events-reach-handlers-that-take-no-arguments
  "MEDIA_EVENTS, and the shape that is new in this binding.

Both events are **static**: XNA raises them with `handler(null, args)', so the
projected handler takes no arguments at all. CNA agrees the player is
process-global -- its two subscribe routes take **no game handle**, the only ones
in this ABI that do -- so a subscription is legal with no game alive, which is
asserted here before one is created.

The delivery is driven deterministically with CNA's own raise routes rather than
by waiting for playback to reach a boundary, because when an event becomes due is
neither framework's published contract and this binding claims none."
  (let ((before (int:callback-registry-count))
        (active 0)
        (state 0))
    (let ((on-active (lambda () (incf active)))
          (on-state (lambda () (incf state))))
      ;; **Subscribing with no game at all**, which the routes permit.
      (media:media-player-add-active-song-changed-handler on-active)
      (media:media-player-add-media-state-changed-handler on-state)
      (is (= (+ 2 before) (int:callback-registry-count))
          "each subscription rooted exactly one callback target")
      (unwind-protect
           (with-media-game (game)
             (let ((handle (int:handle-of (int:active-game))))
               (cna-lisp.internal:check-result
                (cna-lisp.internal.ffi::%media-player-raise-active-song-changed-ext
                 handle) "raise")
               (cna-lisp.internal:check-result
                (cna-lisp.internal.ffi::%media-player-raise-media-state-changed-ext
                 handle) "raise")
               (is (= 1 active) "the active-song handler ran exactly once")
               (is (= 1 state) "the media-state handler ran exactly once")))
        (is (eq t (media:media-player-remove-active-song-changed-handler on-active)))
        (is (eq t (media:media-player-remove-media-state-changed-handler on-state))))
      (is (= before (int:callback-registry-count))
          "removing both released their native registrations and forgot their ~
           tokens")
      (is (null (media:media-player-remove-active-song-changed-handler on-active))
          "removing again answers NIL, as Delegate.Remove does")
      ;; And nothing arrives afterwards.
      (with-media-game (game)
        (let ((seen active))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%media-player-raise-active-song-changed-ext
            (int:handle-of (int:active-game))) "raise")
          (is (= seen active)
              "no further callback may arrive after the handler is removed")))
      (note-media
       :events
       "both static events reached handlers that take no arguments -- the sender ~
        is null in XNA because the event is static -- subscribing needed no game ~
        because CNA's routes take none, removing released the native ~
        registrations, and nothing arrived afterwards"))))

(define-native-test a-condition-from-a-media-handler-uses-the-shared-rule
  "The media events use the common callback-condition rule and do not invent one:
a serious condition in a handler never unwinds through C, is preserved as the
original object, and is re-signalled at the next native call that returns to the
program outside every callback."
  (let ((marker (make-condition 'xna:cna-io-error :operation "media handler probe"))
        (handler nil))
    (setf handler (lambda () (error marker)))
    (media:media-player-add-media-state-changed-handler handler)
    (unwind-protect
         (with-media-game (game)
           (let ((signalled
                   (handler-case
                       (progn
                         (cna-lisp.internal.ffi::%media-player-raise-media-state-changed-ext
                          (int:handle-of (int:active-game)))
                         (xna:run-one-frame game)
                         nil)
                     (xna:cna-error (condition) condition))))
             (is (not (null signalled))
                 "the handler's condition never reached the program")
             (when signalled
               (is (or (eq signalled marker)
                       (eq marker (xna:cna-error-cause signalled)))
                   "the original condition object must arrive, either itself or ~
                    as the CAUSE of the native failure that outranked it; got ~s"
                   signalled))))
      (ignore-errors
       (media:media-player-remove-media-state-changed-handler handler)))))

(define-native-test a-refused-media-unsubscribe-keeps-its-registration
  "The rule the Dynamic closure fixed, asserted for this event family too:
`cna_media_player_unsubscribe_ext' validates before it mutates, so a call from
the wrong thread leaves the registration live and the local row must survive."
  (let ((before (int:callback-registry-count))
        (handler (lambda () nil)))
    (media:media-player-add-media-state-changed-handler handler)
    (let ((result (bordeaux-threads:join-thread
                   (bordeaux-threads:make-thread
                    (lambda ()
                      (handler-case
                          (progn (media:media-player-remove-media-state-changed-handler
                                  handler)
                                 :accepted)
                        (xna:cna-error (condition) (type-of condition))))
                    :name "cna-lisp media unsubscribe wrong-thread probe"))))
      (is (not (eq result :accepted))
          "the wrong-thread unsubscribe was accepted; CNA refuses it")
      (is (= (1+ before) (int:callback-registry-count))
          "and the refused removal kept the rooted token, because the native ~
           registration it did not release is still live"))
    (is (eq t (media:media-player-remove-media-state-changed-handler handler))
        "so the right thread still finds the subscription")
    (is (= before (int:callback-registry-count)))))
