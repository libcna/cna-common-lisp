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
  "Function of one integer token, called when CNA raises a ContentLost event.
Void-returning, like the other event dispatchers.")

(defcallback buffer-content-lost-callback :void ((resource :uint64) (context :pointer))
  (declare (ignore resource))
  (let ((dispatcher *buffer-content-lost-dispatcher*))
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context))))))

(defun content-lost-callback-pointer ()
  "The one top-level callback CNA is given for every ContentLost subscription.

The resource handle CNA passes is ignored: the token already names the CLOS
object, and a handle would have to be looked up to reach the same place. All
three routes that raise a ContentLost -- the vertex buffer's, the index buffer's
and the render target's -- have the same shape, (handle, context) returning void,
so one callback serves all of them."
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

;;; --- game components -------------------------------------------------------
;;;
;;; A component is the one place in this ABI where the consumer *provides*
;;; behaviour rather than consuming it: CNA's canonical component types are C++
;;; interfaces, C cannot implement an interface, so CNA takes a callback set and
;;; supplies the object that implements the interfaces and forwards to it.
;;;
;;; None of these returns a result code -- CNA's component handlers return void
;;; and its own header says so: "a handler that fails has nowhere to report it:
;;; return normally and record the failure in your own context". So a condition
;;; raised in a component's method is contained here and re-signalled on the Lisp
;;; side after the frame, which is the same containment every other callback in
;;; this binding gets and the reason none of them may unwind through C.

(defvar *component-dispatcher* nil
  "Function of (KIND TOKEN GAME-TIME-POINTER). Void-returning: a component
handler has no result code to answer with.")

(defmacro define-component-callback (name kind timed)
  `(defcallback ,name :void
       (,@(when timed '((game-time :pointer))) (context :pointer))
     (let ((dispatcher *component-dispatcher*))
       (when dispatcher
         (ignore-errors
          (funcall dispatcher ,kind (pointer-address context)
                   ,(if timed 'game-time '(null-pointer))))))))

(define-component-callback component-initialize-callback :initialize nil)
(define-component-callback component-update-callback :update t)
(define-component-callback component-draw-callback :draw t)
(define-component-callback component-load-content-callback :load-content nil)
(define-component-callback component-unload-content-callback :unload-content nil)
(define-component-callback component-dispose-callback :dispose nil)

(defun component-callback-pointers ()
  "The six handler pointers, in CNA_GameComponentCallbacks' own field order."
  (list (callback component-initialize-callback)
        (callback component-update-callback)
        (callback component-draw-callback)
        (callback component-load-content-callback)
        (callback component-unload-content-callback)
        (callback component-dispose-callback)))

(defvar *component-event-dispatcher* nil
  "Function of one integer token, called when CNA raises a component event.")

(defcallback component-event-callback :void ((context :pointer))
  (let ((dispatcher *component-event-dispatcher*))
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context))))))

(defun component-event-callback-pointer ()
  "The one top-level callback CNA is given for every component subscription.

A canonical component event carries nothing but its sender, so CNA's handler
takes only the context -- and the token in it already names the CLOS object."
  (callback component-event-callback))

(defvar *component-collection-dispatcher* nil
  "Function of (TOKEN COMPONENT-HANDLE), called when the game's component
collection gains or loses a component.")

(defcallback component-collection-callback :void
    ((component :uint64) (context :pointer))
  (let ((dispatcher *component-collection-dispatcher*))
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context) component)))))

(defun component-collection-callback-pointer ()
  "The one top-level callback for ComponentAdded and ComponentRemoved.

Unlike every other event in this binding, this one's argument is not empty:
`GameComponentCollectionEventArgs' carries the component. CNA passes the handle
directly rather than a description, so the handle is what reaches the dispatcher
and the dispatcher resolves it to the component object."
  (callback component-collection-callback))
