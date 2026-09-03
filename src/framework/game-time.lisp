;;;; game-time.lisp --- Microsoft.Xna.Framework.GameTime.
;;;;
;;;; GameTime is a class in XNA, not a struct, so it is a CLOS class here. Its
;;;; TimeSpan properties are projected as exact 100-nanosecond tick counts --
;;;; integers, not floats -- because that is what the value really is and what
;;;; the CNA C ABI carries. Convenience readers in seconds and milliseconds are
;;;; derived from the ticks and are CNA-Lisp additions, marked as such in
;;;; docs/common-lisp-mapping.md.

(in-package #:microsoft.xna.framework)

(defconstant +ticks-per-second+ 10000000
  "100-nanosecond ticks in one second, as System.TimeSpan counts them.")

(defclass game-time ()
  ((total-game-time-ticks :initarg :total-game-time-ticks :initform 0
                          :reader total-game-time-ticks)
   (elapsed-game-time-ticks :initarg :elapsed-game-time-ticks :initform 0
                            :reader elapsed-game-time-ticks)
   (is-running-slowly :initarg :is-running-slowly :initform nil
                      :reader is-running-slowly))
  (:documentation
   "A snapshot of the game loop's timing. Instances are produced by the runtime
and handed to UPDATE and DRAW; a consumer does not create them."))

(defun total-game-time (game-time)
  "GameTime.TotalGameTime, in 100-nanosecond ticks."
  (total-game-time-ticks game-time))

(defun elapsed-game-time (game-time)
  "GameTime.ElapsedGameTime, in 100-nanosecond ticks."
  (elapsed-game-time-ticks game-time))

(defun total-game-time-seconds (game-time)
  "GameTime.TotalGameTime as seconds. A CNA-Lisp convenience over the ticks."
  (/ (total-game-time-ticks game-time) (float +ticks-per-second+ 1.0d0)))

(defun elapsed-game-time-seconds (game-time)
  "GameTime.ElapsedGameTime as seconds. A CNA-Lisp convenience over the ticks."
  (/ (elapsed-game-time-ticks game-time) (float +ticks-per-second+ 1.0d0)))

(defmethod print-object ((game-time game-time) stream)
  (print-unreadable-object (game-time stream :type t)
    (format stream "total ~d elapsed ~d~:[~; running-slowly~]"
            (total-game-time-ticks game-time)
            (elapsed-game-time-ticks game-time)
            (is-running-slowly game-time))))
