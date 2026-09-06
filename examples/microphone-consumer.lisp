;;;; microphone-consumer.lisp --- capture, using only CNA-Lisp's public API.
;;;;
;;;; **What this is for.** The microphone tests live inside the test system and
;;;; reach two private things: `%MICROPHONE-INDEX', to cross-check CNA's own
;;;; routes against the public answers, and `%RESET-MICROPHONE-CACHE', so that a
;;;; single image can observe a *first* enumeration more than once. Both are
;;;; legitimate for a test and neither is available to a program. This file is
;;;; the independent evidence that none of them is *needed*: it does a complete
;;;; capture session -- enumerate, identify the default, set a buffer duration,
;;;; start, read, subscribe, stop -- through nothing but the two exported
;;;; packages, and prints machine-readable lines a script can check.
;;;;
;;;; It is deliberately **not** in the template. Capture is a specialised
;;;; subsystem whose behaviour depends on the SDL audio driver, it wants its own
;;;; fresh process, and a person running the ordinary game template should not
;;;; find that it has opened their microphone. `tools/qualification/microphone.sh'
;;;; is where this runs, under a driver it chooses.
;;;;
;;;; **The audit this file has to pass** is in the script that runs it, and it is
;;;; mechanical: no `CNA-LISP.INTERNAL', no `CNA-LISP.INTERNAL.FFI', no `CFFI',
;;;; no handle, no result code, and no symbol with a `%' in it. If a capture
;;;; program needed any of those, the projection would be incomplete and this
;;;; would be how that was found.
;;;;
;;;; It captures for a bounded number of frames and exits. Every byte it reads is
;;;; discarded: it counts them and never looks at one, because what is being
;;;; demonstrated is the API and not the audio.
;;;;
;;;; **Expect its BufferReady count to be zero, and that is a finding rather than
;;;; a fault.** CNA raises the event once the *unread* capture backlog reaches
;;;; `BufferDuration', and this program calls `GetData' on every frame -- so the
;;;; backlog is drained long before it becomes due and the event never fires. A
;;;; program that polls does not need the event; a program that waits for the
;;;; event does not poll. The count is printed as data and no lane requires it to
;;;; be positive, because requiring it would be requiring this program to be
;;;; written the other way round. The suite's own BufferReady lane subscribes and
;;;; deliberately does not drain, which is what makes the event due there.

(defpackage #:cna-lisp-microphone-consumer
  (:use #:cl)
  (:local-nicknames (#:xna #:microsoft.xna.framework)
                    (#:audio #:microsoft.xna.framework.audio))
  (:export #:main))

(in-package #:cna-lisp-microphone-consumer)

(defconstant +frames+ 180
  "How many frames to capture over. At the default sixty a second that is three
seconds, which is long enough for a 100 ms buffer to become due many times and
short enough that a lane running this cannot hang a build.")

(defconstant +buffer-duration-ticks+ 1000000
  "100 milliseconds, in the 100-nanosecond ticks CNA-Lisp projects TimeSpan as.

XNA's setter accepts [100, 1000] milliseconds in steps of ten and refuses
anything else; 100 is the low end, which makes the BufferReady event due
soonest.")

(defun report (key control &rest arguments)
  "Print one machine-readable line: `MICROPHONE-CONSUMER <key> <text>'."
  (format t "~&MICROPHONE-CONSUMER ~a ~?~%" key control arguments)
  (finish-output))

(defun capture (game microphone)
  "Run a bounded capture session on MICROPHONE and answer (values BYTES EVENTS).

The buffer is sized from the microphone's *own* sample rate rather than from a
constant, through `GET-SAMPLE-SIZE-IN-BYTES' -- which is the member a real
capture program would use for exactly this, and using it here is part of the
point."
  (let* ((wanted (audio:get-sample-size-in-bytes microphone +buffer-duration-ticks+))
         (buffer (make-array (max wanted 2) :element-type '(unsigned-byte 8)
                                            :initial-element 0))
         (bytes 0)
         (events 0)
         (handler (lambda (sender)
                    (incf events)
                    ;; The sender is the microphone this handler was added to.
                    ;; A program may rely on that; this one only counts.
                    (declare (ignorable sender)))))
    (setf (audio:buffer-duration microphone) +buffer-duration-ticks+)
    (audio:add-buffer-ready-handler microphone handler)
    (unwind-protect
         (progn
           (audio:start microphone)
           (dotimes (frame +frames+)
             (xna:run-one-frame game)
             ;; A short read is ordinary success and so is a read of zero, so the
             ;; count is simply accumulated. Nothing looks at a byte.
             (incf bytes (audio:get-data microphone buffer)))
           (audio:stop microphone))
      (audio:remove-buffer-ready-handler microphone handler))
    (values bytes events)))

(defun main ()
  "Enumerate, capture, and print what happened. Answers an exit code."
  (let ((game (make-instance 'xna:game :window-title "cna-lisp microphone consumer")))
    (unwind-protect
         (let ((all (audio:microphone-all)))
           (report "count" "~d" (length all))
           (when (null all)
             ;; The no-device branch is an ordinary answer, not a failure: a
             ;; machine with no capture device enumerates none.
             (report "unavailable" "no capture device was enumerated")
             (return-from main 0))
           (dolist (microphone all)
             (report "device" "~s rate=~d headset=~a"
                     (audio:name microphone)
                     (audio:sample-rate microphone)
                     (if (audio:is-headset microphone) "yes" "no")))
           (let ((default (audio:microphone-default)))
             (report "default" "~s" (and default (audio:name default)))
             (report "default-in-all" "~a"
                     (if (member default all :test #'eq) "yes" "no"))
             (report "state-before" "~a" (audio:state default))
             (multiple-value-bind (bytes events) (capture game default)
               (report "state-after" "~a" (audio:state default))
               (report "buffer-duration" "~d" (audio:buffer-duration default))
               (report "frames" "~d" +frames+)
               (report "bytes" "~d" bytes)
               (report "events" "~d" events)
               ;; What the byte count *should* be near, from the device's own
               ;; rate: two bytes a frame of mono PCM16, sixty frames a second.
               (report "expected-bytes" "~d"
                       (audio:get-sample-size-in-bytes
                        default (round (* +frames+ 10000000) 60)))))
           (report "done" "the whole session used only the public API")
           0)
      (xna:dispose game))))
