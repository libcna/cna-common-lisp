;;;; threads.lisp --- thread affinity for CNA native objects.
;;;;
;;;; CNA handles are thread-affine: a game and everything it owns belong to the
;;;; thread that created the game, and a handle used from another thread answers
;;;; a thread failure rather than misbehaving. CNA-Lisp records the owning thread
;;;; when a native object is created and refuses a wrong-thread operation
;;;; *before* it reaches the ABI, so the handle stays live and usable from its
;;;; own thread afterwards.
;;;;
;;;; Every implementation-specific piece of thread identity is confined to this
;;;; file, behind BORDEAUX-THREADS.

(in-package #:cna-lisp.internal)

(defun current-thread-token ()
  "An object identifying the calling thread, comparable with SAME-THREAD-P."
  (bordeaux-threads:current-thread))

(defun same-thread-p (token)
  "True when TOKEN names the calling thread."
  (eq token (bordeaux-threads:current-thread)))

(defun thread-name-of (token)
  (or (ignore-errors (bordeaux-threads:thread-name token)) "an unnamed thread"))

(defun check-owner-thread (owner-thread operation &key object-type)
  "Refuse OPERATION unless the calling thread is OWNER-THREAD.

The refusal is a CNA-THREAD-ERROR raised by CNA-Lisp, not by CNA: nothing is
handed to the ABI, so the native object is untouched and remains usable from the
thread that owns it."
  (unless (same-thread-p owner-thread)
    (error 'microsoft.xna.framework:cna-thread-error
           :operation operation
           :object-type object-type
           :format-control
           "~a is only legal on the thread that created the native object (~a); it was ~
            attempted on ~a. Nothing was passed to CNA, so the object is unchanged and ~
            still usable from its own thread."
           :format-arguments (list operation
                                   (thread-name-of owner-thread)
                                   (thread-name-of (bordeaux-threads:current-thread)))))
  t)
