;;;; media-queue.lisp --- Microsoft.Xna.Framework.Media.MediaQueue.
;;;;
;;;; **The queue is stateless, and that is the pinned IL's answer rather than a
;;;; simplification.** `MediaQueue' declares no fields at all; its constructor is
;;;; `ldarg.0; call object..ctor; ret' and every one of its four public members
;;;; goes to the native layer on every read. So the CLOS facade holds nothing
;;;; either.
;;;;
;;;; **There is exactly one of it, and its identity is guaranteed.**
;;;; `MediaPlayer''s static constructor creates one `MediaQueue' and stores it in
;;;; a static field; `get_Queue' answers that field. So `MediaPlayer.Queue' is
;;;; reference-identical for the life of the process, and `MEDIA-PLAYER-QUEUE'
;;;; reproduces that with one process-global object.
;;;;
;;;; CNA agrees about the singleton and disagrees about the handle: it hands out a
;;;; **borrowed view** of "the process-wide media queue", and releasing that view
;;;; releases only the view. A facade that cached the view handle would be holding
;;;; a borrowed handle across game lifetimes, so instead every operation resolves
;;;; the view, uses it, and releases it. That is what a stateless facade over a
;;;; process-global thing costs, and it is cheap.

(in-package #:microsoft.xna.framework.media)

(defclass media-queue ()
  ()
  (:documentation
   "Microsoft.Xna.Framework.Media.MediaQueue: the songs the player is working through.

    (let ((queue (media-player-queue)))
      (count-of queue)
      (active-song queue))

**You do not make one.** XNA's constructor is `assembly'-private and only
`MediaPlayer''s static constructor calls it, so there is no `MAKE-INSTANCE' here
either: `MEDIA-PLAYER-QUEUE' answers the one that exists, and it answers **the
same object** every time.

It holds nothing. Every member asks the runtime, exactly as the original's do,
and the facade needs no handle of its own because CNA's queue handle is a
borrowed view of a process-global object rather than something to own.

Needs an active game, for the reason this package's header gives."))

(defvar *media-queue* nil
  "The one MEDIA-QUEUE facade this process hands out.

The projection of XNA's static `MediaPlayer::queue' field, which its static
constructor fills once and nothing ever replaces. Made on first use rather than
at load time, because making it needs nothing and asking for it should not.")

(defun %media-queue ()
  "The process's one queue facade, made on first use."
  (or *media-queue* (setf *media-queue* (make-instance 'media-queue))))

(defmacro %with-queue ((handle operation) &body body)
  "Bind HANDLE to a borrowed view of the process-wide queue for BODY.

The view is released however BODY ends. **It is not cached**: it is borrowed from
the active game, and a handle held across that game's disposal would be a handle
into something that no longer exists."
  (let ((out (gensym "OUT")) (game (gensym "GAME")))
    `(let ((,game (%media-game-handle ,operation)))
       (cffi:with-foreign-object (,out :uint64)
         (cna-lisp.internal:check-result
          (cna-lisp.internal.ffi::%media-player-get-queue ,game ,out)
          ,operation :object-type 'media-queue)
         (let ((,handle (cffi:mem-ref ,out :uint64)))
           ,@body)))))

(defgeneric active-song-index (queue)
  (:documentation
   "MediaQueue.ActiveSongIndex: which song is active, or -1 when none is.

**-1 without asking the runtime when the queue is empty.** The pinned IL seeds
the answer with `ldc.i4.m1' and only calls native `GetActiveSongIndex' when
`Count' is nonzero, so an empty queue answers -1 rather than whatever the runtime
would have said."))

(defgeneric (setf active-song-index) (index queue)
  (:documentation
   "MediaQueue.ActiveSongIndex's setter: move to a song by index.

**It clamps and does not refuse**, which is unusual for this binding and is what
the IL does: `value < 0' becomes 0, `value > Count - 1' becomes `Count - 1', and
only then does it call native `MoveTo'. So there is no out-of-range condition
here -- an index outside the queue is silently the nearest one inside it.

That asymmetry with `ITEM', which *does* refuse an out-of-range index, is the
original's and is reproduced rather than smoothed over."))

(defgeneric active-song (queue)
  (:documentation
   "MediaQueue.ActiveSong: the song being played, or NIL when none is.

`ActiveSongIndex == -1' answers null in XNA, and NIL here. Otherwise it is
`this[ActiveSongIndex]', and therefore a **fresh** object each time -- see
`ITEM'."))

(defmethod count-of ((queue media-queue))
  (let ((operation "count-of"))
    (%with-queue (handle operation)
      (cffi:with-foreign-object (out :int32)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%media-queue-get-count handle out)
         operation :object-type 'media-queue)
        (cffi:mem-ref out :int32)))))

(defmethod active-song-index ((queue media-queue))
  (let ((operation "active-song-index"))
    ;; The IL's own short circuit: an empty queue is -1 and the runtime is not
    ;; asked. Reproduced rather than delegated, because CNA's route answers for
    ;; an empty queue too and the two need not agree.
    (if (zerop (count-of queue))
        -1
        (%with-queue (handle operation)
          (cffi:with-foreign-object (out :int32)
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%media-queue-get-active-song-index handle out)
             operation :object-type 'media-queue)
            (cffi:mem-ref out :int32))))))

(defmethod (setf active-song-index) (index (queue media-queue))
  (let ((operation "active-song-index"))
    (unless (integerp index)
      (error 'xna:cna-argument-error
             :operation operation :parameter-name "index" :object-type 'media-queue
             :format-control "the active song index is an Int32; ~s is not one."
             :format-arguments (list index)))
    (let* ((count (count-of queue))
           ;; XNA clamps, in this order, and does not refuse.
           (clamped (min (max index 0) (max (1- count) 0))))
      (%with-queue (handle operation)
        (cna-lisp.internal:check-result
         (cna-lisp.internal.ffi::%media-queue-set-active-song-index handle clamped)
         operation :object-type 'media-queue))
      clamped)))

(defmethod item ((queue media-queue) index)
  (let ((operation "item"))
    (let ((count (count-of queue)))
      (unless (and (integerp index) (<= 0 index) (< index count))
        (error 'xna:cna-argument-out-of-range-error
               :operation operation :parameter-name "index"
               :object-type 'media-queue
               :format-control
               "index must be a valid index into the ~d song~:p the queue holds; ~
                ~s was given."
               :format-arguments (list count index))))
    (%with-queue (handle operation)
      (%adopt-song-from-route
       operation
       (lambda (out) (cna-lisp.internal.ffi::%media-queue-get-at handle index out))))))

(defmethod active-song ((queue media-queue))
  (let ((operation "active-song"))
    (if (= -1 (active-song-index queue))
        nil
        (%with-queue (handle operation)
          (cffi:with-foreign-objects ((out :uint64) (available :int32))
            (cna-lisp.internal:check-result
             (cna-lisp.internal.ffi::%media-queue-get-active-song handle out available)
             operation :object-type 'media-queue)
            ;; CNA reports availability separately and leaves the handle
            ;; untouched when there is none, so the flag is read first.
            (when (/= (cffi:mem-ref available :int32)
                      cna-lisp.internal.ffi::+false+)
              (%adopt-song-handle (%media-game operation)
                                  (cffi:mem-ref out :uint64) operation)))))))

(defmethod xna:clr-type-name ((queue media-queue))
  "The .NET type name CNA reports for the media-queue type."
  (let ((operation "clr-type-name"))
    (%with-queue (handle operation)
      (cna-lisp.internal:count-then-copy-string
       (lambda (out)
         (cna-lisp.internal.ffi::%media-queue-get-type-name-size handle out))
       (lambda (buffer capacity out)
         (cna-lisp.internal.ffi::%media-queue-copy-type-name
          handle buffer capacity out))
       operation))))

(defmethod print-object ((queue media-queue) stream)
  (print-unreadable-object (queue stream :type t)
    (format stream "the process queue")))
