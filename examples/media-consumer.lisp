;;;; media-consumer.lisp --- play a song, using only CNA-Lisp's public API.
;;;;
;;;; **What this is for.** The media tests reach the internal package twice, for
;;;; native cross-checks that are the point of those tests: whether CNA's
;;;; `game_has_control' route agrees with the literal XNA returns, and the two
;;;; `raise' routes that make the static events deterministic. Both are
;;;; legitimate for a test and neither is available to a program. This file is
;;;; the independent evidence that none of it is *needed*: it does a complete
;;;; playback session -- make songs, build a collection, subscribe to both static
;;;; events, play, watch the clock, work through the queue, stop, unsubscribe,
;;;; dispose -- through nothing but the two exported packages, and prints
;;;; machine-readable lines a script can check.
;;;;
;;;; It is deliberately **not** in the template. Playback depends on the SDL
;;;; audio driver, it wants its own fresh process, and someone running the
;;;; ordinary game template should not find that it has started playing audio.
;;;; `tools/qualification/media.sh' is where this runs, under a driver it
;;;; chooses.
;;;;
;;;; **The audit this file has to pass** is in the script that runs it, and it is
;;;; mechanical: no `CNA-LISP.INTERNAL', no `CFFI', no handle, no result code and
;;;; no private `%'-symbol. If a playback program needed any of those, the
;;;; projection would be incomplete and this would be how that was found.
;;;;
;;;; It plays for a bounded number of frames and exits. **Nothing is listened
;;;; to**: what is demonstrated is the API, and the device the script chooses has
;;;; no speaker behind it.

(defpackage #:cna-lisp-media-consumer
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework)
                    (#:media #:microsoft.xna.framework.media))
  (:export #:main))

(in-package #:cna-lisp-media-consumer)

(defconstant +frames+ 24
  "How many frames to play over: at the default sixty a second, four tenths of a
second.

**Deliberately shorter than the fixture**, which is one second long. A song that
reaches its end stops the player and resets the play position to zero, so a run
that lasts as long as the song observes a position of 0 and a state of
:STOPPED -- correct behaviour and useless evidence, and *flaky* evidence at that,
because whether the end is reached depends on how fast the frames ran. Twenty-four
frames leaves more than half the song in hand whichever way the timing falls.")

(defparameter *fixture* "tests/fixtures/test-tone.wav"
  "The one-second PCM16 file the suite already generates. A song is a *path* to
CNA rather than decoded audio, so any real file would do; using the generated one
keeps the promise that no sample audio is stored in this repository.")

(defun report (key control &rest arguments)
  "Print one machine-readable line: `MEDIA-CONSUMER <key> <text>'."
  (format t "~&MEDIA-CONSUMER ~a ~?~%" key control arguments)
  (finish-output))

(defun main ()
  "Play a song and a collection, and print what happened. Answers an exit code."
  (let ((game (make-instance 'xna:game :window-title "cna-lisp media consumer"))
        (active-events 0)
        (state-events 0)
        on-active on-state)
    (setf on-active (lambda () (incf active-events))
          on-state (lambda () (incf state-events)))
    (unwind-protect
         (let ((first (make-instance 'media:song :file-name *fixture*
                                                 :name "first"))
               (second (make-instance 'media:song :file-name *fixture*
                                                  :name "second")))
           (unwind-protect
                (let ((collection (make-instance 'media:song-collection
                                                 :songs (list first second)))
                      (queue (media:media-player-queue)))
                  (unwind-protect
                       (progn
                         (report "song" "~s duration=~d rated=~a"
                                 (media:name first) (media:duration first)
                                 (if (media:is-rated first) "yes" "no"))
                         (report "has-control" "~a"
                                 (if (media:media-player-game-has-control) "yes" "no"))
                         (report "state-before" "~a" (media:media-player-state))

                         ;; Both events, subscribed before anything plays.
                         (media:media-player-add-active-song-changed-handler on-active)
                         (media:media-player-add-media-state-changed-handler on-state)

                         ;; One song first, then the collection.
                         (media:media-player-play first)
                         (report "state-playing" "~a" (media:media-player-state))
                         (dotimes (frame +frames+) (xna:run-one-frame game))
                         (report "position" "~d" (media:media-player-play-position))
                         (report "frames" "~d" +frames+)

                         (media:media-player-pause)
                         (report "state-paused" "~a" (media:media-player-state))
                         (report "position-paused" "~d"
                                 (media:media-player-play-position))
                         (media:media-player-resume)
                         (media:media-player-stop)

                         (media:media-player-play collection)
                         (report "queue-count" "~d" (media:count-of queue))
                         (report "queue-index" "~d" (media:active-song-index queue))
                         (let ((active (media:active-song queue)))
                           (unwind-protect
                                (report "queue-active" "~s equal-to-first=~a"
                                        (and active (media:name active))
                                        (if (media:song-equal active first) "yes" "no"))
                             (when active (xna:dispose active))))
                         (media:media-player-move-next)
                         (report "after-move-next" "~d"
                                 (media:active-song-index queue))
                         (media:media-player-move-next)
                         (report "after-wrap" "~d" (media:active-song-index queue))
                         (media:media-player-stop)
                         (report "state-after" "~a" (media:media-player-state))
                         (report "events" "active=~d state=~d"
                                 active-events state-events)
                         (report "done" "the whole session used only the public API")
                         0)
                    (ignore-errors
                     (media:media-player-remove-active-song-changed-handler on-active))
                    (ignore-errors
                     (media:media-player-remove-media-state-changed-handler on-state))
                    (xna:dispose collection)))
             (xna:dispose first)
             (xna:dispose second)))
      (xna:dispose game))))
