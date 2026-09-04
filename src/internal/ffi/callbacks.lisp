;;;; callbacks.lisp --- top-level CFFI callbacks CNA may invoke.
;;;;
;;;; Every callback CNA can reach is defined here, at top level, exactly once.
;;;; A moving Lisp object is never handed to C: the context pointer CNA carries
;;;; is a small integer token that the private registry resolves back to the
;;;; Lisp object. See docs/callbacks-and-threading.md.
;;;;
;;;; This file declares the callback shapes only. The bodies dispatch through
;;;; CNA-LISP.INTERNAL, which is defined later, so they are late-bound through
;;;; symbol lookup rather than compile-time references.

(in-package #:cna-lisp.internal.ffi)

(defvar *lifecycle-dispatcher* nil
  "Function of (KIND TOKEN GAME-HANDLE GAME-TIME-POINTER ERROR-POINTER) returning a
CNA result code. Installed by the runtime once the registry exists.")

(defvar *begin-draw-dispatcher* nil
  "Function of (TOKEN GAME-HANDLE SHOULD-DRAW-POINTER ERROR-POINTER) returning a
CNA result code.")

(defmacro define-lifecycle-callback (name kind)
  "Define one top-level CNA_GameLifecycleCallback that dispatches on KIND."
  `(defcallback ,name :uint32
       ((game :uint64) (game-time :pointer) (context :pointer) (out-error :pointer))
     (let ((dispatcher *lifecycle-dispatcher*))
       (if dispatcher
           (funcall dispatcher ,kind (pointer-address context) game game-time out-error)
           ;; No dispatcher can only mean the registry was torn down under a live
           ;; game. Refusing is the only honest answer; CNA turns it into
           ;; CNA_RESULT_CALLBACK and stops the loop.
           9))))

(define-lifecycle-callback game-initialize-callback :initialize)
(define-lifecycle-callback game-load-content-callback :load-content)
(define-lifecycle-callback game-begin-run-callback :begin-run)
(define-lifecycle-callback game-update-callback :update)
(define-lifecycle-callback game-draw-callback :draw)
(define-lifecycle-callback game-end-draw-callback :end-draw)
(define-lifecycle-callback game-end-run-callback :end-run)
(define-lifecycle-callback game-unload-content-callback :unload-content)
(define-lifecycle-callback game-exiting-callback :exiting)

(defcallback game-begin-draw-callback :uint32
    ((game :uint64) (game-time :pointer) (context :pointer)
     (out-should-draw :pointer) (out-error :pointer))
  (declare (ignore game-time))
  (let ((dispatcher *begin-draw-dispatcher*))
    (if dispatcher
        (funcall dispatcher (pointer-address context) game out-should-draw out-error)
        9)))

(defvar *game-event-dispatcher* nil
  "Function of one integer token, called when CNA raises a subscribed game event.

A CNA_GameEventCallback returns nothing, so there is no channel to report a
failure through: the dispatcher must contain whatever the handler signals and
answer normally. See docs/callbacks-and-threading.md.")

(defcallback game-event-callback :void ((context :pointer))
  (let ((dispatcher *game-event-dispatcher*))
    ;; No dispatcher means the registry was torn down under a live subscription.
    ;; There is nothing to report it to, so the only thing left is to do nothing.
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context))))))

(defvar *resource-disposing-dispatcher* nil
  "Function of one integer token, called when CNA raises a graphics resource's
Disposing event. Void-returning, like the game event dispatcher.")

(defcallback resource-disposing-callback :void ((resource :uint64) (context :pointer))
  (declare (ignore resource))
  (let ((dispatcher *resource-disposing-dispatcher*))
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context))))))

(defvar *buffer-content-lost-dispatcher* nil
  "Function of one integer token, called when CNA raises a buffer's ContentLost
event. Void-returning, like the other event dispatchers.")

(defcallback buffer-content-lost-callback :void ((buffer :uint64) (context :pointer))
  (declare (ignore buffer))
  (let ((dispatcher *buffer-content-lost-dispatcher*))
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context))))))

(defun buffer-content-lost-callback-pointer ()
  "The one top-level callback CNA is given for every ContentLost subscription.

The buffer handle CNA passes is ignored: the token already names the CLOS object,
and a handle would have to be looked up to reach the same place. Both the vertex
and the index route have the same shape -- (handle, context) returning void -- so
one callback serves both."
  (callback buffer-content-lost-callback))

(defun resource-disposing-callback-pointer ()
  "The one top-level callback CNA is given for every Disposing subscription.

The resource handle CNA passes is ignored: the token already names the CLOS
object, and resolving a handle back to an object would be a second, weaker way
of doing what the registry does exactly."
  (callback resource-disposing-callback))

(defun game-event-callback-pointer ()
  "The one top-level callback CNA is given for every game event subscription."
  (callback game-event-callback))

(defun lifecycle-callback-pointer (kind)
  "The top-level callback pointer CNA is given for KIND."
  (ecase kind
    (:initialize (callback game-initialize-callback))
    (:load-content (callback game-load-content-callback))
    (:begin-run (callback game-begin-run-callback))
    (:update (callback game-update-callback))
    (:draw (callback game-draw-callback))
    (:begin-draw (callback game-begin-draw-callback))
    (:end-draw (callback game-end-draw-callback))
    (:end-run (callback game-end-run-callback))
    (:unload-content (callback game-unload-content-callback))
    (:exiting (callback game-exiting-callback))))
