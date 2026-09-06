;;;; media-player.lisp --- Microsoft.Xna.Framework.Media.MediaPlayer.
;;;;
;;;; **A static class, and this binding has not had one with events before.**
;;;; `MediaPlayer' is `abstract sealed` in the pinned IL -- C#'s `static class` --
;;;; so it has no instances and every one of its twenty members is static. Its
;;;; state is five static fields: `shuffle', `repeat', the one `queue', and the
;;;; two event delegates.
;;;;
;;;; Static members project as `MEDIA-PLAYER-<member>', the naming rule
;;;; `Keyboard', `Mouse' and `GamePad' already follow. There is no class to
;;;; export and no object to pass.
;;;;
;;;; --- the two events are static, and their sender is null -------------------
;;;;
;;;; `OnActiveSongChanged' and `OnMediaStateChanged' both invoke
;;;; `handler(null, args)': the event is static, so there is no instance to be the
;;;; sender. Every other event in this binding passes its sender and nothing else;
;;;; **these pass nothing at all**, because a handler that took one always-null
;;;; argument would be one every handler had to write and ignore -- the same
;;;; reasoning that dropped the always-empty `EventArgs' everywhere else, applied
;;;; to the other argument.
;;;;
;;;; CNA agrees that the player is process-global, and says so in the strongest
;;;; way available to it: `cna_media_player_subscribe_active_song_changed_ext' and
;;;; its media-state sibling take a callback, a context and an out-registration
;;;; and **no game handle**. They are the only subscribe routes in this ABI that
;;;; do. So the subscription outlives any particular game, exactly as the static
;;;; delegate field does.
;;;;
;;;; The handler lists therefore need a home that is not an object slot, and they
;;;; get one: a private singleton the shared event machinery specialises on. That
;;;; keeps one mechanism for every CLR event in this binding -- the same
;;;; %SUBSCRIBE-EVENT, the same rooted-token discipline, the same
;;;; failed-unsubscribe rule -- rather than a second registry for the static case.
;;;;
;;;; --- what the IL guards, and CNA does not ---------------------------------
;;;;
;;;; Three of the transport members are **conditional in XNA and unconditional in
;;;; CNA**, and the guard is observable:
;;;;
;;;;   Pause     runs only when State == Playing; otherwise it does nothing
;;;;   Resume    runs only when State != Playing; otherwise it does nothing
;;;;   Stop      runs only when State != Stopped; otherwise it does nothing
;;;;
;;;; So pausing a stopped player is a no-op in the original rather than an error
;;;; or a state change, and the guards are reproduced here rather than left to
;;;; CNA -- which accepts all three unconditionally.

(in-package #:microsoft.xna.framework.media)

;;; --- the transport ----------------------------------------------------------

(defgeneric media-player-play (source &optional index)
  (:documentation
   "MediaPlayer.Play: play a song, or a collection from its start or an index.

    (media-player-play song)                  Play(Song)
    (media-player-play collection)            Play(SongCollection)
    (media-player-play collection 2)          Play(SongCollection, Int32)

Three overloads, told apart by **CLOS dispatch on the first argument's type and
by arity** -- not by keywords, because two of the three differ in a positional
parameter's type rather than in an optional. `(media-player-play song 2)' names
no overload and is refused: XNA has no `Play(Song, Int32)', and a method that
accepted and ignored the index would give it one.

The validation is the pinned IL's, in its order:

    song == null                 -> ArgumentNullException(\"song\")
    songCollection == null       -> ArgumentNullException(\"songCollection\")
    songCollection.Count == 0    -> ArgumentException(EmptySongCollections...)
    index outside [0, Count)     -> ArgumentOutOfRangeException(\"index\")

A song whose handle is not live makes XNA's `MediaQueue.Play' answer `E_FAIL' and
wrap it in `InvalidOperationException(SongPlaybackFailed)'; here a disposed song
is refused by the ordinary disposal check first, which is the same refusal
arriving one step earlier.

Every overload **clears the queue first**: CNA's `play_song' route says so, and
XNA's queue does the same.

Needs an active game."))

(defmethod media-player-play ((source song) &optional (index nil index-supplied))
  (let ((operation "media-player-play"))
    (when index-supplied
      (error 'xna:cna-usage-error
             :operation operation
             :format-control
             "MediaPlayer.Play has no Song-and-index overload: the three it has ~
              are Play(Song), Play(SongCollection) and Play(SongCollection, ~
              Int32). ~s was given with the index ~s."
             :format-arguments (list source index)))
    (cna-lisp.internal:check-usable source operation)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%media-player-play-song
      (%media-game-handle operation) (cna-lisp.internal:handle-of source))
     operation :object-type 'song)
    (values)))

(defmethod media-player-play ((source song-collection)
                              &optional (index nil index-supplied))
  (let ((operation "media-player-play"))
    (cna-lisp.internal:check-usable source operation)
    (let ((count (count-of source)))
      (when (zerop count)
        (error 'xna:cna-argument-error
               :operation operation :parameter-name "songs"
               :object-type 'song-collection
               :format-control
               "an empty SongCollection cannot be played, which is XNA's own ~
                refusal and not this binding's."))
      (when index-supplied
        (unless (and (integerp index) (<= 0 index) (< index count))
          (error 'xna:cna-argument-out-of-range-error
                 :operation operation :parameter-name "index"
                 :object-type 'song-collection
                 :format-control
                 "index must be a valid index into the ~d song~:p the ~
                  collection holds; ~s was given."
                 :format-arguments (list count index)))))
    (cna-lisp.internal:check-result
     (if index-supplied
         (cna-lisp.internal.ffi::%media-player-play-songs-from
          (%media-game-handle operation)
          (cna-lisp.internal:handle-of source) index)
         (cna-lisp.internal.ffi::%media-player-play-songs
          (%media-game-handle operation)
          (cna-lisp.internal:handle-of source)))
     operation :object-type 'song-collection)
    (values)))

(defmethod media-player-play (source &optional index)
  "Anything that is neither a SONG nor a SONG-COLLECTION.

A method on T rather than no method at all, so that a wrong argument is a
condition naming the three overloads rather than `NO-APPLICABLE-METHOD'."
  (declare (ignore index))
  (error 'xna:cna-argument-error
         :operation "media-player-play" :parameter-name "source"
         :format-control
         "MediaPlayer.Play takes a SONG or a SONG-COLLECTION; ~s is neither. ~
          XNA's three overloads are Play(Song), Play(SongCollection) and ~
          Play(SongCollection, Int32)."
         :format-arguments (list source)))

(defun media-player-pause ()
  "MediaPlayer.Pause: pause playback, **if it is playing**.

The pinned IL guards the native call: `if (State == Playing)'. So pausing a
player that is stopped or already paused does nothing at all -- it is not an
error and it does not change the state. CNA accepts the call unconditionally, so
the guard is here.

Needs an active game."
  (let ((operation "media-player-pause"))
    (when (eq (media-player-state) :playing)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%media-player-pause (%media-game-handle operation))
       operation))
    (values)))

(defun media-player-resume ()
  "MediaPlayer.Resume: resume playback, **if it is not already playing**.

`if (State != Playing)' in the pinned IL. Resuming a player that is already
playing does nothing. See `MEDIA-PLAYER-PAUSE'.

Needs an active game."
  (let ((operation "media-player-resume"))
    (unless (eq (media-player-state) :playing)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%media-player-resume (%media-game-handle operation))
       operation))
    (values)))

(defun media-player-stop ()
  "MediaPlayer.Stop: stop playback, **if it is not already stopped**.

`if (State != Stopped)' in the pinned IL -- spelled `brfalse', which takes the
zero branch, and `Stopped' is the zero of this enumeration. Stopping an
already-stopped player does nothing.

Needs an active game."
  (let ((operation "media-player-stop"))
    (unless (eq (media-player-state) :stopped)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%media-player-stop (%media-game-handle operation))
       operation))
    (values)))

(defun media-player-move-next ()
  "MediaPlayer.MoveNext: move to the next song, **wrapping to the first**.

`MediaQueue.MoveNext' in the pinned IL:

    if (Count <= 0)                    do nothing
    else if (ActiveSongIndex < Count-1) native MoveNext
    else                               ActiveSongIndex = 0

so the wrap is the *managed* layer's and not the runtime's, and an empty queue is
a no-op rather than a failure. Both are reproduced here.

Needs an active game."
  (let* ((operation "media-player-move-next")
         (queue (media-player-queue))
         (count (count-of queue)))
    (when (plusp count)
      (if (< (active-song-index queue) (1- count))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%media-player-move-next
            (%media-game-handle operation))
           operation)
          (setf (active-song-index queue) 0)))
    (values)))

(defun media-player-move-previous ()
  "MediaPlayer.MovePrevious: move to the previous song, **wrapping to the last**.

    if (Count <= 0)              do nothing
    else if (ActiveSongIndex > 0) native MovePrev
    else                         ActiveSongIndex = Count - 1

The mirror of `MEDIA-PLAYER-MOVE-NEXT', and the wrap is the managed layer's
there too.

Needs an active game."
  (let* ((operation "media-player-move-previous")
         (queue (media-player-queue))
         (count (count-of queue)))
    (when (plusp count)
      (if (plusp (active-song-index queue))
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%media-player-move-previous
            (%media-game-handle operation))
           operation)
          (setf (active-song-index queue) (1- count))))
    (values)))

;;; --- the properties ---------------------------------------------------------

(defun media-player-queue ()
  "MediaPlayer.Queue: the one queue the player works through.

**The same object every time**, which is XNA's own guarantee: its static
constructor makes one `MediaQueue' and `get_Queue' answers that field. A test
asserts it with `EQ'.

Unlike every other member here it needs no active game, because the object it
answers holds nothing -- the game is needed when a *member of the queue* is
called, not to hand the queue over."
  (%media-queue))

(defun media-player-state ()
  "MediaPlayer.State: `:STOPPED', `:PLAYING' or `:PAUSED'.

Asks the runtime on every read, as the pinned IL does. Translated **by name**
through the enumeration table rather than passed through as a number.

Needs an active game."
  (let ((operation "media-player-state"))
    (cffi:with-foreign-object (out :uint32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%media-player-get-state
        (%media-game-handle operation) out)
       operation)
      (media-state-from-value (cffi:mem-ref out :uint32)))))

(defun media-player-play-position ()
  "MediaPlayer.PlayPosition: how far into the active song playback has reached.

A tick count, because TimeSpan is a tick count throughout this binding.

**Zero when nothing is active**, without asking the runtime: `MediaQueue.get_PlayPosition'
starts with `new TimeSpan(0)' and only calls native when `ActiveSongIndex != -1'.

XNA builds its TimeSpan from a *millisecond* count -- `new TimeSpan(0,0,0,0,ms)'
-- so the position it reports is a whole number of milliseconds. CNA answers
ticks directly and at finer resolution; the value is passed through rather than
quantised, because quantising would throw away precision the caller asked for and
XNA's coarseness is an artefact of its native layer's units rather than a rule
its documentation states.

Needs an active game."
  (let ((operation "media-player-play-position"))
    (if (= -1 (active-song-index (media-player-queue)))
        0
        (cffi:with-foreign-object (out :int64)
          (cna-lisp.internal:check-result
           (cna-lisp.internal.ffi::%media-player-get-play-position-ticks
            (%media-game-handle operation) out)
           operation)
          (cffi:mem-ref out :int64)))))

(defmacro %define-player-flag (name getter setter documentation)
  "Define one boolean MediaPlayer property over its two CNA routes."
  `(progn
     (defun ,name ()
       ,documentation
       (let ((operation ,(string-downcase (symbol-name name))))
         (cffi:with-foreign-object (out :int32)
           (cna-lisp.internal:check-result
            (,getter (%media-game-handle operation) out) operation)
           (/= (cffi:mem-ref out :int32) cna-lisp.internal.ffi::+false+))))
     (defun (setf ,name) (value)
       ,documentation
       (let ((operation ,(string-downcase (symbol-name name))))
         (cna-lisp.internal:check-result
          (,setter (%media-game-handle operation)
                   (if value cna-lisp.internal.ffi::+true+
                       cna-lisp.internal.ffi::+false+))
          operation)
         value))))

(%define-player-flag media-player-is-muted
    cna-lisp.internal.ffi::%media-player-get-is-muted
    cna-lisp.internal.ffi::%media-player-set-is-muted
  "MediaPlayer.IsMuted: whether song playback is muted.

Both halves ask the runtime, which is the pinned IL's shape -- unlike
`IS-SHUFFLED' and `IS-REPEATING', whose getters read a managed field.

Needs an active game.")

(%define-player-flag media-player-is-visualization-enabled
    cna-lisp.internal.ffi::%media-player-get-is-visualization-enabled
    cna-lisp.internal.ffi::%media-player-set-is-visualization-enabled
  "MediaPlayer.IsVisualizationEnabled: whether the player computes visualization data.

Both halves ask the runtime. **It gates `MEDIA-PLAYER-GET-VISUALIZATION-DATA'**,
which does nothing at all while this is false -- see that function.

Needs an active game.")

(%define-player-flag media-player-is-shuffled
    cna-lisp.internal.ffi::%media-player-get-is-shuffled
    cna-lisp.internal.ffi::%media-player-set-is-shuffled
  "MediaPlayer.IsShuffled: whether the queue plays in a shuffled order.

XNA's getter reads a **static field** that its class constructor seeds from the
runtime and its setter writes after the native call succeeds; this asks the
runtime on every read instead. The difference is observable only if something
outside the program changes the flag, which nothing in this binding can do, and
asking is the answer that cannot go stale.

Needs an active game.")

(%define-player-flag media-player-is-repeating
    cna-lisp.internal.ffi::%media-player-get-is-repeating
    cna-lisp.internal.ffi::%media-player-set-is-repeating
  "MediaPlayer.IsRepeating: whether the queue repeats when it ends.

The mirror of `MEDIA-PLAYER-IS-SHUFFLED', with the same managed-field note.

Needs an active game.")

(defun media-player-volume ()
  "MediaPlayer.Volume: playback volume in [0, 1].

Asks the runtime on every read.

Needs an active game."
  (let ((operation "media-player-volume"))
    (cffi:with-foreign-object (out :float)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%media-player-get-volume
        (%media-game-handle operation) out)
       operation)
      (cffi:mem-ref out :float))))

(defun (setf media-player-volume) (value)
  "MediaPlayer.Volume's setter, which **clamps rather than refusing**.

The pinned IL is two ordered comparisons and no exception:

    if (value < 0) value = 0
    if (value > 1) value = 1

then the native call. So 2.0 sets the volume to 1.0 and -1.0 sets it to 0.0, and
neither is an error. Measured against all three admitted ABIs, CNA clamps to the
same bounds -- but the clamp is reproduced here rather than delegated, because a
CNA that stopped clamping would otherwise change this member's public behaviour
silently.

**NaN passes through**, and that is the IL's doing too: `blt' and `bgt' are
*ordered* comparisons, so a NaN fails both tests and reaches the native call
unclamped. Reproduced rather than tidied, for the reason `MathHelper.Clamp''s own
NaN behaviour is.

Answers the value that was set after clamping, which is what the getter will say."
  (let ((operation "media-player-volume"))
    (unless (realp value)
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "value"
             :format-control "the volume is a Single; ~s is not a real number."
             :format-arguments (list value)))
    (let* ((single (xna::f value))
           ;; Ordered comparisons, so a NaN takes neither branch -- which is what
           ;; `blt'/`bgt' do and is why this is not MIN/MAX.
           (clamped (cond ((< single 0.0f0) 0.0f0)
                          ((> single 1.0f0) 1.0f0)
                          (t single))))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%media-player-set-volume
        (%media-game-handle operation) clamped)
       operation)
      clamped)))

(defun media-player-game-has-control ()
  "MediaPlayer.GameHasControl: whether the game controls its own background music.

**It is always true, and that is the pinned assembly's answer rather than this
binding's.** `get_GameHasControl' is two instructions -- `ldc.i4.1; ret' -- a
literal with no field behind it and no native call.

CNA has a real route, `cna_media_player_get_game_has_control', and measured it
answers true as well, so the two agree here. The literal is still what is
projected: agreement is not a reason to start asking, any more than it was a
reason to skip an enumeration table, and a CNA that started answering false would
otherwise change a member XNA cannot change.

Needs no active game, because nothing is asked of one."
  t)

(defun media-player-get-visualization-data (data)
  "MediaPlayer.GetVisualizationData: fill DATA's two buffers from the player.

    (media-player-get-visualization-data data)

**It does nothing at all while `MEDIA-PLAYER-IS-VISUALIZATION-ENABLED' is
false**, which is the pinned IL's own guard: after the null check it tests the
property and returns without touching the buffers. So the caller's data keeps
whatever it held, and that is an answer rather than a refusal.

DATA is filled **in place** -- it is the object the caller keeps, exactly as in
XNA, where the two `float32[]' fields are handed to the native layer.

    visualizationData == null -> ArgumentNullException(\"visualizationData\")

Needs an active game."
  (let ((operation "media-player-get-visualization-data"))
    (unless (typep data 'visualization-data)
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "visualization-data"
             :object-type 'visualization-data
             :format-control
             "GetVisualizationData takes a VISUALIZATION-DATA to fill; ~s was ~
              given. XNA raises ArgumentNullException for a null one."
             :format-arguments (list data)))
    (when (media-player-is-visualization-enabled)
      (cffi:with-foreign-object (native '(:struct cna-lisp.internal.ffi::cna-visualization-data))
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%visualization-data-init native)
         operation :object-type 'visualization-data)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%media-player-get-visualization-data
          (%media-game-handle operation) native)
         operation :object-type 'visualization-data)
        (%copy-visualization-buffers native data)))
    (values)))

(defun %copy-visualization-buffers (native data)
  "Copy both native arrays into DATA's own vectors, element for element.

The vectors are filled in place because that is what XNA's caller keeps a
reference to. Only as many elements as the *caller's* buffer holds are written,
which is the bound `GetVisualizationData' itself passes -- it hands native
`frequencies.Length' rather than a constant."
  (let* ((base (cffi:foreign-slot-pointer
                native '(:struct cna-lisp.internal.ffi::cna-visualization-data)
                'cna-lisp.internal.ffi::frequencies))
         (samples (cffi:foreign-slot-pointer
                   native '(:struct cna-lisp.internal.ffi::cna-visualization-data)
                   'cna-lisp.internal.ffi::samples))
         (limit cna-lisp.internal.ffi::+visualization-data-size+))
    (let ((into (%visualization-frequencies data)))
      (dotimes (i (min limit (length into)))
        (setf (aref into i) (cffi:mem-aref base :float i))))
    (let ((into (%visualization-samples data)))
      (dotimes (i (min limit (length into)))
        (setf (aref into i) (cffi:mem-aref samples :float i))))))

;;; --- the two static events --------------------------------------------------
;;;
;;; The handler lists live on a private singleton so that the shared event
;;; machinery -- %SUBSCRIBE-EVENT, the rooted-token discipline, the
;;; failed-unsubscribe rule -- serves these two exactly as it serves every other
;;; CLR event here. The singleton is never exported and never handed to a caller:
;;; the public functions take a handler and nothing else, because the event is
;;; static and there is no object a program could name.

(defclass %media-player-events ()
  ((event-handlers :initform '()
                   :accessor microsoft.xna.framework::%event-handlers))
  (:documentation
   "Private holder for `MediaPlayer''s two static event handler lists.

XNA keeps them in two static delegate fields. The shared event machinery keys
everything on an object, so this is that object -- one per process, never
exported, and never passed to anything public."))

(defvar *media-player-events* nil
  "The one holder. Made on first use; nothing replaces it.")

(defun %media-player-events ()
  (or *media-player-events*
      (setf *media-player-events* (make-instance '%media-player-events))))

(defparameter *media-player-event-values*
  (list (cons :active-song-changed 0)
        (cons :media-state-changed 1))
  "The two events MediaPlayer raises.

The values are this binding's own tags rather than CNA constants: CNA names each
event by its own *route* rather than by an identity passed to a shared one, so
there is no constant to carry. They differ from each other because
%SUBSCRIBE-NATIVELY branches on them to choose the route.")

(defmethod xna::%event-table ((events %media-player-events))
  *media-player-event-values*)

(defmethod xna::%check-event-usable ((events %media-player-events) operation)
  "There is no object to check, and **no game to check either**.

Both subscribe routes take a callback, a context and an out-registration and no
game handle at all -- the only subscriptions in this ABI that do -- so a
subscription is legal with no game alive, exactly as adding to a static delegate
field is in XNA."
  (declare (ignore events operation))
  t)

(defmethod xna::%subscribe-natively ((events %media-player-events)
                                     value token registration)
  (declare (ignore events))
  (funcall (if (eql value 0)
               #'cna-lisp.internal.ffi::%media-player-subscribe-active-song-changed-ext
               #'cna-lisp.internal.ffi::%media-player-subscribe-media-state-changed-ext)
           (cna-lisp.internal.ffi:media-player-event-callback-pointer)
           (cffi:make-pointer token)
           registration))

(defmethod xna::%unsubscribe-natively ((events %media-player-events) registration)
  "Media-player registrations are released by their own route.

`cna_media_player_unsubscribe_ext' takes a registration from either of the two
media-player subscribe routes; neither `cna_game_unsubscribe' nor
`cna_audio_unsubscribe_ext' accepts one."
  (cna-lisp.internal.ffi::%media-player-unsubscribe-ext registration))

(defun %dispatch-media-player-event (token)
  "Invoke the handler TOKEN names, with **no arguments at all**.

Every other event in this binding passes its sender. These two have none: XNA's
raisers invoke `handler(null, args)' because the event is static, and a handler
that took one always-null argument would be one every handler had to write and
ignore."
  (let ((entry (cna-lisp.internal:callback-target token)))
    (when entry
      (destructuring-bind (sender . function) entry
        (declare (ignore sender))
        (cna-lisp.internal:with-event-dispatch (funcall function))))))

(setf cna-lisp.internal.ffi:*media-player-event-dispatcher*
      #'%dispatch-media-player-event)

(macrolet
    ((define-static-event (event add remove what)
       `(progn
          (defun ,add (handler)
            ,(format nil
                     "MediaPlayer.~a's `+=': call HANDLER when ~a.

    (~a (lambda () (refresh-the-now-playing-display)))

**HANDLER takes no arguments.** The event is static, so XNA's raiser invokes
`handler(null, args)' -- there is no instance to be the sender and the args are
`EventArgs.Empty' -- and a handler that had to accept and ignore two dead
arguments would be worse than one that accepts none.

It is called on the thread that advances the frame. A condition it signals cannot
be reported to CNA -- the callback answers `void' -- so it is contained there and
re-signalled by the first native call that returns to your program afterwards,
under the rule `src/internal/callback-conditions.lisp' owns for every callback in
this binding.

Needs no active game: CNA's subscribe route takes none, which is it agreeing that
the player is process-global."
                     (string-capitalize (substitute #\Space #\- (string event)) :start 0)
                     what (string-downcase (symbol-name add)))
            (xna::%subscribe-event (%media-player-events) ,event handler))
          (defun ,remove (handler)
            ,(format nil
                     "The `-=' of ~a. Answers true when it found a handler to
remove and NIL when it did not, which is what `Delegate.Remove' does silently."
                     (string-downcase (symbol-name add)))
            (xna::%unsubscribe-event (%media-player-events) ,event handler)))))
  (define-static-event :active-song-changed
      media-player-add-active-song-changed-handler
      media-player-remove-active-song-changed-handler
    "the queue moves to a different song")
  (define-static-event :media-state-changed
      media-player-add-media-state-changed-handler
      media-player-remove-media-state-changed-handler
    "playback starts, pauses, resumes or stops"))
