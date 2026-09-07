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

(defvar *audio-event-dispatcher* nil
  "Function of one integer token, called when CNA raises a subscribed audio event.

`CNA_AudioEventCallback' has `CNA_GameEventCallback''s exact shape --
`void (*)(void* context)' -- and answers nothing, so a handler's failure has the
same nowhere to go and is contained the same way. It is a **separate** callback
and a separate dispatcher rather than the game one reused, because the routes
that install it are audio's and the registration it produces is released by
`cna_audio_unsubscribe_ext' rather than by `cna_game_unsubscribe'.")

(defcallback audio-event-callback :void ((context :pointer))
  (let ((dispatcher *audio-event-dispatcher*))
    ;; No dispatcher means the registry was torn down under a live subscription.
    ;; There is nothing to report it to, so the only thing left is to do nothing.
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context))))))

(defvar *media-player-event-dispatcher* nil
  "Function of one integer token, called when CNA raises a media-player event.

`CNA_MediaPlayerEventCallback' has `CNA_GameEventCallback''s exact shape --
`void (*)(void* context)' -- and answers nothing, so a handler's failure has the
same nowhere to go and is contained the same way. It is a **third** callback and a
third dispatcher rather than either of the two above, because the routes that
install it are the media player's, its registration is released by
`cna_media_player_unsubscribe_ext', and -- unlike every other subscription in this
binding -- **the subscribe routes take no game handle at all**. The media player is
process-global in CNA exactly as it is static in XNA.")

(defcallback media-player-event-callback :void ((context :pointer))
  (let ((dispatcher *media-player-event-dispatcher*))
    ;; No dispatcher means the registry was torn down under a live subscription.
    ;; There is nothing to report it to, so the only thing left is to do nothing.
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context))))))

(defvar *storage-event-dispatcher* nil
  "Function of one integer token, called when CNA raises a storage event.

`CNA_StorageCompletionCallback' has `CNA_GameEventCallback''s exact shape --
`void (*)(void* context)' -- and answers nothing, so a handler's failure has the
same nowhere to go and is contained the same way. It is a **fourth** callback and
a fourth dispatcher because the routes that install it are storage's and its
registrations are released by two routes of storage's own.

CNA uses the one type for two unrelated things: the `DeviceChanged' and
`Disposing' event subscriptions, and the *completion* callback the four selector
routes and the container-open route take. The completion use never reaches this
dispatcher -- those callbacks fire before their route returns and this binding
calls the caller's function directly rather than through CNA, for the reason
`src/storage/storage-device.lisp' gives.")

(defcallback storage-event-callback :void ((context :pointer))
  (let ((dispatcher *storage-event-dispatcher*))
    ;; No dispatcher means the registry was torn down under a live subscription.
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

(defvar *graphics-device-event-dispatcher* nil
  "Function of one integer token, called when CNA raises one of the graphics
device's four payload-free events. Void-returning, like the others.")

(defcallback graphics-device-event-callback :void ((graphics-device :uint64)
                                                   (context :pointer))
  (declare (ignore graphics-device))
  (let ((dispatcher *graphics-device-event-dispatcher*))
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

(defun graphics-device-event-callback-pointer ()
  "The one top-level callback CNA is given for every device-event subscription.

`CNA_GraphicsDeviceEventCallback' has the same (handle, context) shape the
Disposing and ContentLost callbacks do, and the handle is ignored for the same
reason: the token already names the CLOS object, and the graphics device does not
keep a handle to be compared against anyway."
  (callback graphics-device-event-callback))

(defun resource-disposing-callback-pointer ()
  "The one top-level callback CNA is given for every Disposing subscription.

The resource handle CNA passes is ignored: the token already names the CLOS
object, and resolving a handle back to an object would be a second, weaker way
of doing what the registry does exactly."
  (callback resource-disposing-callback))

(defun game-event-callback-pointer ()
  "The one top-level callback CNA is given for every game event subscription."
  (callback game-event-callback))

(defun audio-event-callback-pointer ()
  "The one top-level callback CNA is given for every audio event subscription."
  (callback audio-event-callback))

(defun media-player-event-callback-pointer ()
  "The one top-level callback CNA is given for every media-player subscription."
  (callback media-player-event-callback))

(defun storage-event-callback-pointer ()
  "The one top-level callback CNA is given for every storage event subscription."
  (callback storage-event-callback))

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

(defvar *preparing-device-settings-dispatcher* nil
  "Function of (TOKEN INFORMATION-POINTER), called while device settings are
being prepared.

**The only callback in this binding whose argument is mutable**, and the whole
point of the route that installs it. CNA hands the handler a
`CNA_GraphicsDeviceInformation*' that is borrowed for the duration of the call
and whose fields are what the device is then created from; the older
`CNA_PreparingDeviceSettingsCallback' takes the same structure `const' and is
deliberately not bound, because a binding that could only observe would be
projecting a member XNA has for changing things.

The pointer is passed straight through rather than being read here. Reading it
into a CLOS object and writing the final state back is the dispatcher's job,
because the object the handlers see has to be one object for the whole callback
-- see `runtime/preparing-device-settings.lisp'.

Void-returning like every other event callback, so a handler's condition has
nowhere to go through C and is contained the same way. CNA's own header says the
same: \"a handler that cannot decide what to change simply changes nothing, and
there is no failure for it to report that device preparation could act on\".")

(defcallback preparing-device-settings-callback :void
    ((information :pointer) (context :pointer))
  (let ((dispatcher *preparing-device-settings-dispatcher*))
    ;; No dispatcher means the registry was torn down under a live subscription.
    (when dispatcher
      (ignore-errors (funcall dispatcher (pointer-address context) information)))))

(defun preparing-device-settings-callback-pointer ()
  "The one top-level callback CNA is given for every PreparingDeviceSettings
subscription. The token in the context names the manager and the handler set."
  (callback preparing-device-settings-callback))
