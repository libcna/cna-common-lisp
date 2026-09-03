;;;; game.lisp --- Microsoft.Xna.Framework.Game.
;;;;
;;;; GAME is a public CLOS class designed to be subclassed, and the game loop is
;;;; a set of generic functions a subclass specialises. There is no public
;;;; callback table: a consumer writes methods, and the private runtime is what
;;;; knows that CNA calls C function pointers.
;;;;
;;;; The path from a native callback back to a method is:
;;;;
;;;;   CNA's void* context -> integer token -> callback registry -> this GAME
;;;;
;;;; and every one of those callbacks runs inside WITH-CONTAINED-CALLBACK, so a
;;;; condition signalled by a method never unwinds through a C frame. It is
;;;; preserved, reported to CNA as a callback failure, and re-signalled on the
;;;; Lisp side once RUN or TICK has returned.

(in-package #:microsoft.xna.framework)

(defconstant +default-target-elapsed-time-ticks+ 166667
  "XNA's default fixed step: 1/60 second, in 100-nanosecond ticks.")

(defgeneric graphics-device (object)
  (:documentation
   "Game.GraphicsDevice, and GraphicsDeviceManager.GraphicsDevice.

Both answer the same object, because in CNA they are the same device."))

(defclass game (cna-lisp.internal:native-object)
  ((graphics-device :initform nil
                    :documentation "The game's GRAPHICS-DEVICE facade.")
   (callback-token :initform nil :reader %callback-token)
   (window-title :initarg :window-title :initform "CNA-Lisp Game" :reader window-title)
   (running :initform nil :accessor %running-p)
   (content-loaded :initform nil :accessor %content-loaded-p)
   (event-handlers :initform '() :accessor %event-handlers
                   :documentation
                   "One entry per live event subscription: (EVENT FUNCTION TOKEN
. REGISTRATION-HANDLE). Kept on the game because XNA's -= takes the handler
itself, so the binding has to be able to find the registration from it."))
  (:documentation
   "Microsoft.Xna.Framework.Game.

Subclass it and specialise the lifecycle generic functions -- INITIALIZE,
LOAD-CONTENT, UPDATE, DRAW, UNLOAD-CONTENT and their neighbours. Creating an
instance creates the native CNA game; DISPOSE destroys it, after every resource
the game owns has been disposed.

CNA allows one active game per process, so a second live GAME is refused."))

;;; --- lifecycle generic functions ---------------------------------------
;;;
;;; Each has a default method that does what XNA's base implementation does for a
;;; game with no components: nothing, except that BEGIN-DRAW answers true. These
;;; are not stubs standing in for unimplemented work -- the component engine that
;;; would give them more to do is not part of this milestone, and is reported as
;;; missing rather than faked.

(defgeneric initialize (game)
  (:documentation "Game.Initialize(). Runs once, before content loads.")
  (:method ((game game)) (values)))

(defgeneric load-content (game)
  (:documentation "Game.LoadContent(). Runs once, after the graphics device exists.")
  (:method ((game game)) (values)))

(defgeneric unload-content (game)
  (:documentation "Game.UnloadContent(). Runs once, while shutting down content.")
  (:method ((game game)) (values)))

(defgeneric begin-run (game)
  (:documentation "Game.BeginRun(). Runs once, before the first frame of a run.")
  (:method ((game game)) (values)))

(defgeneric end-run (game)
  (:documentation "Game.EndRun(). Runs once, after the last frame of a run.")
  (:method ((game game)) (values)))

(defgeneric update (game game-time)
  (:documentation "Game.Update(GameTime). Runs once per frame.")
  (:method ((game game) game-time) (declare (ignore game-time)) (values)))

(defgeneric begin-draw (game)
  (:documentation
   "Game.BeginDraw(). Answer NIL to skip this frame's drawing; the default
answers true, exactly as the original's does.")
  (:method ((game game)) t))

(defgeneric draw (game game-time)
  (:documentation "Game.Draw(GameTime). Runs once per drawn frame.")
  (:method ((game game) game-time) (declare (ignore game-time)) (values)))

(defgeneric end-draw (game)
  (:documentation "Game.EndDraw(). Runs after DRAW, before the frame is presented.")
  (:method ((game game)) (values)))

(defgeneric on-exiting (game)
  (:documentation "Game.OnExiting(). Runs once as the game exits.")
  (:method ((game game)) (values)))

;;; --- native callback dispatch ------------------------------------------

(defun %game-time-from-pointer (pointer)
  (if (or (null pointer) (cffi:null-pointer-p pointer))
      nil
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     pointer '(:struct cna-lisp.internal.ffi::cna-game-time) ',name)))
        (make-instance 'game-time
                       :total-game-time-ticks (slot cna-lisp.internal.ffi::total-game-time-ticks)
                       :elapsed-game-time-ticks
                       (slot cna-lisp.internal.ffi::elapsed-game-time-ticks)
                       :is-running-slowly
                       (cna-lisp.internal.ffi:cna-true-p
                        (slot cna-lisp.internal.ffi::is-running-slowly))))))

(defun %resolve-game (token kind)
  (let ((game (cna-lisp.internal:callback-target token)))
    (unless game
      (error 'cna-callback-error
             :operation (string-downcase (symbol-name kind))
             :format-control
             "CNA invoked the ~(~a~) callback with context token ~d, which no live game ~
              claims. A registry entry is removed only after CNA can no longer call back, ~
              so this means a callback arrived after teardown."
             :format-arguments (list kind token)))
    game))

(defun %dispatch-lifecycle (kind token game-handle game-time-pointer out-error)
  "The one function every CNA lifecycle callback funnels through."
  (declare (ignore game-handle))
  (cna-lisp.internal:with-contained-callback
      (out-error :operation (format nil "~(~a~)" kind))
    (let ((game (%resolve-game token kind)))
      (ecase kind
        (:initialize (initialize game))
        (:load-content
         (setf (%content-loaded-p game) t)
         (load-content game))
        (:begin-run (begin-run game))
        (:update (update game (%game-time-from-pointer game-time-pointer)))
        (:draw (draw game (%game-time-from-pointer game-time-pointer)))
        (:end-draw (end-draw game))
        (:end-run (end-run game))
        (:unload-content
         (setf (%content-loaded-p game) nil)
         (unload-content game))
        (:exiting (on-exiting game))))))

(defun %dispatch-begin-draw (token game-handle out-should-draw out-error)
  (declare (ignore game-handle))
  (cna-lisp.internal:with-contained-callback (out-error :operation "begin-draw")
    (let* ((game (%resolve-game token :begin-draw))
           (should (begin-draw game)))
      (unless (cffi:null-pointer-p out-should-draw)
        (setf (cffi:mem-ref out-should-draw :uint8)
              (cna-lisp.internal.ffi:cna-bool-of should))))))

(setf cna-lisp.internal.ffi:*lifecycle-dispatcher* #'%dispatch-lifecycle
      cna-lisp.internal.ffi:*begin-draw-dispatcher* #'%dispatch-begin-draw)

;;; --- creation ----------------------------------------------------------

(defun %fill-game-callbacks (pointer token)
  (cffi:foreign-funcall "memset" :pointer pointer :int 0
                        :size cna-lisp.internal.ffi::+sizeof-cna-game-callbacks+ :void)
  (macrolet ((slot (name)
               `(cffi:foreign-slot-value
                 pointer '(:struct cna-lisp.internal.ffi::cna-game-callbacks) ',name)))
    (setf (slot cna-lisp.internal.ffi::struct-size)
          cna-lisp.internal.ffi::+sizeof-cna-game-callbacks+
          (slot cna-lisp.internal.ffi::struct-version) 1
          (slot cna-lisp.internal.ffi::load-content)
          (cna-lisp.internal.ffi:lifecycle-callback-pointer :load-content)
          (slot cna-lisp.internal.ffi::update)
          (cna-lisp.internal.ffi:lifecycle-callback-pointer :update)
          (slot cna-lisp.internal.ffi::draw)
          (cna-lisp.internal.ffi:lifecycle-callback-pointer :draw)
          (slot cna-lisp.internal.ffi::unload-content)
          (cna-lisp.internal.ffi:lifecycle-callback-pointer :unload-content)
          (slot cna-lisp.internal.ffi::exiting)
          (cna-lisp.internal.ffi:lifecycle-callback-pointer :exiting)
          (slot cna-lisp.internal.ffi::context) (cffi:make-pointer token))))

(defun %install-frame-hooks (handle token)
  (cffi:with-foreign-object (hooks '(:struct cna-lisp.internal.ffi::cna-game-frame-hooks))
    (cffi:foreign-funcall "memset" :pointer hooks :int 0
                          :size cna-lisp.internal.ffi::+sizeof-cna-game-frame-hooks+ :void)
    (macrolet ((slot (name)
                 `(cffi:foreign-slot-value
                   hooks '(:struct cna-lisp.internal.ffi::cna-game-frame-hooks) ',name)))
      (setf (slot cna-lisp.internal.ffi::struct-size)
            cna-lisp.internal.ffi::+sizeof-cna-game-frame-hooks+
            (slot cna-lisp.internal.ffi::struct-version) 1
            (slot cna-lisp.internal.ffi::initialize)
            (cna-lisp.internal.ffi:lifecycle-callback-pointer :initialize)
            (slot cna-lisp.internal.ffi::begin-run)
            (cna-lisp.internal.ffi:lifecycle-callback-pointer :begin-run)
            (slot cna-lisp.internal.ffi::end-run)
            (cna-lisp.internal.ffi:lifecycle-callback-pointer :end-run)
            (slot cna-lisp.internal.ffi::begin-draw)
            (cna-lisp.internal.ffi:lifecycle-callback-pointer :begin-draw)
            (slot cna-lisp.internal.ffi::end-draw)
            (cna-lisp.internal.ffi:lifecycle-callback-pointer :end-draw)
            (slot cna-lisp.internal.ffi::context) (cffi:make-pointer token)))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-set-frame-hooks-ext handle hooks)
     "install frame hooks" :object-type 'game)))

(defmethod initialize-instance :after
    ((game game) &key (fixed-time-step t)
                      (target-elapsed-time +default-target-elapsed-time-ticks+))
  (cna-lisp.internal:ensure-abi-admitted)
  (when (cna-lisp.internal:active-game)
    (error 'cna-invalid-state-error
           :operation "make-instance game" :object-type (type-of game)
           :format-control
           "a CNA game is already live in this process. CNA allows exactly one; dispose ~
            the existing game before creating another."))
  ;; Construction is transactional. Four things happen after the native game
  ;; exists -- the frame hooks, the device facade, the child registration and the
  ;; active-game slot -- and any of them can fail. Before this was one unwind, a
  ;; failure in the third left a live native game and a callback registry entry
  ;; behind, with no Lisp object anybody could dispose.
  (let ((token (cna-lisp.internal:register-callback-target game))
        (created nil)
        (committed nil))
    (setf (slot-value game 'callback-token) token)
    (unwind-protect
         (progn
    (cffi:with-foreign-object (callbacks '(:struct cna-lisp.internal.ffi::cna-game-callbacks))
           (%fill-game-callbacks callbacks token)
           (cna-lisp.internal:with-utf8-view (title-data title-length (window-title game))
             (cffi:with-foreign-object (info '(:struct cna-lisp.internal.ffi::cna-game-create-info))
               (cffi:foreign-funcall "memset" :pointer info :int 0
                                     :size cna-lisp.internal.ffi::+sizeof-cna-game-create-info+
                                     :void)
               (macrolet ((slot (name)
                            `(cffi:foreign-slot-value
                              info '(:struct cna-lisp.internal.ffi::cna-game-create-info) ',name)))
                 (setf (slot cna-lisp.internal.ffi::struct-size)
                       cna-lisp.internal.ffi::+sizeof-cna-game-create-info+
                       (slot cna-lisp.internal.ffi::struct-version) 1
                       (slot cna-lisp.internal.ffi::is-fixed-time-step)
                       (cna-lisp.internal.ffi:cna-bool-of fixed-time-step)
                       (slot cna-lisp.internal.ffi::target-elapsed-time-ticks) target-elapsed-time
                       (slot cna-lisp.internal.ffi::callbacks) callbacks)
                 (let ((view (cffi:foreign-slot-pointer
                              info '(:struct cna-lisp.internal.ffi::cna-game-create-info)
                              'cna-lisp.internal.ffi::window-title)))
                   (setf (cffi:foreign-slot-value
                          view '(:struct cna-lisp.internal.ffi::cna-string-view)
                          'cna-lisp.internal.ffi::data) title-data
                         (cffi:foreign-slot-value
                          view '(:struct cna-lisp.internal.ffi::cna-string-view)
                          'cna-lisp.internal.ffi::byte-length) title-length)))
               (cffi:with-foreign-object (out :uint64)
                 (cna-lisp.internal:check-result
                  (cna-lisp.internal.ffi::%game-create info out)
                  "make-instance game" :object-type (type-of game))
                 (setf (cna-lisp.internal:handle-of game) (cffi:mem-ref out :uint64))))))
           (setf created t)
           (%install-frame-hooks (cna-lisp.internal:handle-of game) token)
           (setf (slot-value game 'graphics-device)
                 (make-instance 'microsoft.xna.framework.graphics:graphics-device
                                :ownership :parent-owned
                                :owner game
                                :owner-thread (cna-lisp.internal:owner-thread-of game)))
           (cna-lisp.internal:register-child game (slot-value game 'graphics-device))
           (setf (cna-lisp.internal:active-game) game)
           (setf committed t))
      (unless committed
        ;; Destroy the native game if it was created, and stop CNA being able to
        ;; call back either way. A failure here must not mask the one that caused
        ;; the rollback.
        (when created
          (ignore-errors
           (cna-lisp.internal.ffi::%game-destroy (cna-lisp.internal:handle-of game))))
        (ignore-errors (cna-lisp.internal:release-callback-error-buffer))
        (cna-lisp.internal:take-pending-callback-condition)
        (cna-lisp.internal:unregister-callback-target token)
        (setf (slot-value game 'callback-token) nil
              (cna-lisp.internal:handle-of game) 0
              (cna-lisp.internal:disposed-state-of game) t)
        (when (eq (cna-lisp.internal:active-game) game)
          (setf (cna-lisp.internal:active-game) nil))))))

;;; --- running -----------------------------------------------------------

(defgeneric run (game)
  (:documentation
   "Game.Run(). Runs native frames until EXIT is called or a lifecycle method
fails. Legal only on the thread that created the game, and never from inside a
lifecycle method."))

(defmethod run ((game game))
  (cna-lisp.internal:check-usable game "run")
  (%refuse-reentry "run")
  (setf (%running-p game) t)
  (unwind-protect
       (cna-lisp.internal:call-native-frame
        (lambda () (cna-lisp.internal.ffi::%game-run (cna-lisp.internal:handle-of game)))
        "run" :object-type (type-of game))
    (setf (%running-p game) nil))
  (values))

(defgeneric run-one-frame (game)
  (:documentation
   "Game.RunOneFrame(): process host events and run exactly one frame."))

(defmethod run-one-frame ((game game))
  (cna-lisp.internal:check-usable game "run-one-frame")
  (%refuse-reentry "run-one-frame")
  (cna-lisp.internal:call-native-frame
   (lambda () (cna-lisp.internal.ffi::%game-run-one-frame (cna-lisp.internal:handle-of game)))
   "run-one-frame" :object-type (type-of game))
  (values))

(defgeneric tick (game)
  (:documentation
   "Game.Tick(): one update and, unless drawing was suppressed, one draw. Unlike
RUN-ONE-FRAME it does not process host events."))

(defmethod tick ((game game))
  (cna-lisp.internal:check-usable game "tick")
  (%refuse-reentry "tick")
  (cna-lisp.internal:call-native-frame
   (lambda () (cna-lisp.internal.ffi::%game-tick (cna-lisp.internal:handle-of game)))
   "tick" :object-type (type-of game))
  (values))

(defun %refuse-reentry (operation)
  (when (cna-lisp.internal:in-callback-scope-p)
    (error 'cna-scope-error
           :operation operation
           :format-control
           "~a cannot be called from inside a lifecycle method: it would re-enter the loop ~
            it is part of. CNA refuses it too; CNA-Lisp refuses it first, so nothing ~
            reaches the ABI."
           :format-arguments (list operation))))

(defgeneric exit (game)
  (:documentation "Game.Exit(): ask the loop to stop at its next safe point."))

(defmethod exit ((game game))
  (cna-lisp.internal:check-usable game "exit")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%game-request-exit (cna-lisp.internal:handle-of game))
   "exit" :object-type (type-of game))
  (values))

(defgeneric suppress-draw (game)
  (:documentation "Game.SuppressDraw(): skip the next frame's drawing."))

(defmethod suppress-draw ((game game))
  (cna-lisp.internal:check-usable game "suppress-draw")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%game-suppress-draw (cna-lisp.internal:handle-of game))
   "suppress-draw" :object-type (type-of game))
  (values))

(defgeneric reset-elapsed-time (game)
  (:documentation "Game.ResetElapsedTime(): forget the time since the last update."))

(defmethod reset-elapsed-time ((game game))
  (cna-lisp.internal:check-usable game "reset-elapsed-time")
  (cna-lisp.internal:check-result
   (cna-lisp.internal.ffi::%game-reset-elapsed-time (cna-lisp.internal:handle-of game))
   "reset-elapsed-time" :object-type (type-of game))
  (values))

;;; --- properties --------------------------------------------------------

(macrolet ((define-boolean-property (name getter setter doc)
             `(progn
                (defgeneric ,name (game) (:documentation ,doc))
                (defmethod ,name ((game game))
                  (cna-lisp.internal:check-usable game ,(string-downcase (symbol-name name)))
                  (cffi:with-foreign-object (out :uint8)
                    (cna-lisp.internal:check-result
                     (,getter (cna-lisp.internal:handle-of game) out)
                     ,(string-downcase (symbol-name name)) :object-type (type-of game))
                    (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8))))
                ,@(when setter
                    `((defgeneric (setf ,name) (value game))
                      (defmethod (setf ,name) (value (game game))
                        (cna-lisp.internal:check-usable
                         game ,(format nil "(setf ~(~a~))" name))
                        (cna-lisp.internal:check-result
                         (,setter (cna-lisp.internal:handle-of game)
                                  (cna-lisp.internal.ffi:cna-bool-of value))
                         ,(format nil "(setf ~(~a~))" name) :object-type (type-of game))
                        value)))))
           (define-integer-property (name getter setter doc)
             `(progn
                (defgeneric ,name (game) (:documentation ,doc))
                (defmethod ,name ((game game))
                  (cna-lisp.internal:check-usable game ,(string-downcase (symbol-name name)))
                  (cffi:with-foreign-object (out :int64)
                    (cna-lisp.internal:check-result
                     (,getter (cna-lisp.internal:handle-of game) out)
                     ,(string-downcase (symbol-name name)) :object-type (type-of game))
                    (cffi:mem-ref out :int64)))
                (defgeneric (setf ,name) (value game))
                (defmethod (setf ,name) (value (game game))
                  (cna-lisp.internal:check-usable game ,(format nil "(setf ~(~a~))" name))
                  (cna-lisp.internal:check-result
                   (,setter (cna-lisp.internal:handle-of game) value)
                   ,(format nil "(setf ~(~a~))" name) :object-type (type-of game))
                  value))))
  (define-boolean-property is-active cna-lisp.internal.ffi::%game-get-is-active nil
    "Game.IsActive: whether the game is the active application.")
  (define-boolean-property is-mouse-visible
      cna-lisp.internal.ffi::%game-get-is-mouse-visible
      cna-lisp.internal.ffi::%game-set-is-mouse-visible
    "Game.IsMouseVisible.")
  (define-boolean-property is-fixed-time-step
      cna-lisp.internal.ffi::%game-get-is-fixed-time-step
      cna-lisp.internal.ffi::%game-set-is-fixed-time-step
    "Game.IsFixedTimeStep.")
  (define-integer-property target-elapsed-time
      cna-lisp.internal.ffi::%game-get-target-elapsed-time-ticks
      cna-lisp.internal.ffi::%game-set-target-elapsed-time-ticks
    "Game.TargetElapsedTime, in 100-nanosecond ticks.")
  (define-integer-property inactive-sleep-time
      cna-lisp.internal.ffi::%game-get-inactive-sleep-time-ticks
      cna-lisp.internal.ffi::%game-set-inactive-sleep-time-ticks
    "Game.InactiveSleepTime, in 100-nanosecond ticks."))

(defgeneric (setf window-title) (title game)
  (:documentation "GameWindow.Title, reached through the game."))

(defmethod (setf window-title) (title (game game))
  (check-type title string)
  (cna-lisp.internal:check-usable game "(setf window-title)")
  (cna-lisp.internal:with-utf8-view (data length title)
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-set-window-title
      (cna-lisp.internal:handle-of game) data length)
     "(setf window-title)" :object-type (type-of game)))
  (setf (slot-value game 'window-title) title))

(defgeneric clr-type-name (object)
  (:documentation
   "The fully-qualified .NET type name CNA reports for this object.

A CNA-Lisp addition, not an XNA member: it is what makes a structural claim about
the projected type checkable against the runtime rather than asserted."))

(defmethod clr-type-name ((game game))
  (cna-lisp.internal:check-usable game "clr-type-name")
  (let ((handle (cna-lisp.internal:handle-of game)))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out) (cna-lisp.internal.ffi::%game-get-type-name-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%game-copy-type-name handle buffer capacity out))
     "clr-type-name")))

;;; --- disposal ----------------------------------------------------------

(defmethod graphics-device ((game game))
  (slot-value game 'graphics-device))

(defmethod cna-lisp.internal:destroy-native ((game game))
  ;; `cna_game_destroy' releases the handle even when it answers
  ;; CNA_RESULT_CALLBACK, and it answers that both when a *shutdown* callback
  ;; failed and when an earlier frame callback had already stopped the loop. Only
  ;; the first of those is news: the second was already signalled where it
  ;; happened, and re-signalling it here would mask the original condition behind
  ;; an unwind. So a callback result with no freshly contained condition is the
  ;; latched earlier failure, and disposal completes; a callback result carrying
  ;; one is a real shutdown failure and is signalled with the condition attached.
  (let ((code (cna-lisp.internal.ffi::%game-destroy (cna-lisp.internal:handle-of game))))
    (unwind-protect
         (if (= code cna-lisp.internal:+result-callback+)
             (let ((condition (cna-lisp.internal:take-pending-callback-condition)))
               (when condition
                 (cna-lisp.internal:check-result code "dispose"
                                                 :object-type (type-of game)
                                                 :callback-condition condition)))
             (cna-lisp.internal:check-result code "dispose" :object-type (type-of game)))
      (progn
        ;; The Disposed event is raised *inside* `cna_game_destroy', so the
        ;; subscriptions and the registry entries that root their handlers have
        ;; to survive that call and be released after it -- not before, which
        ;; would silently swallow the last event the game ever raises.
        (%release-game-event-handlers game)
        (cna-lisp.internal:release-callback-error-buffer)))))

(defmethod print-object ((game game) stream)
  (print-unreadable-object (game stream :type t :identity t)
    (format stream "~s~:[~; disposed~]" (window-title game)
            (cna-lisp.internal:disposed-state-of game))))

(defmethod dispose :around ((game game))
  "Destroy the native game, then stop CNA being able to call back into it.

The registry entry is what keeps this game reachable while CNA holds its context
pointer, so it is removed only after `cna_game_destroy' has returned -- the
shutdown callbacks run inside that call, and a game that could not be resolved
there would be a callback arriving after teardown."
  (let ((already-disposed (disposed-p game))
        (token (%callback-token game)))
    (if already-disposed
        (call-next-method)
        ;; The cleanup must happen even when the shutdown reported a failure:
        ;; CNA released the handle either way, so leaving the registry entry or
        ;; the active-game slot behind would mean a destroyed game that still
        ;; looks live to the next `make-instance'.
        (unwind-protect (call-next-method)
          (progn
            (when token (cna-lisp.internal:unregister-callback-target token))
            (setf (slot-value game 'callback-token) nil)
            (when (eq (cna-lisp.internal:active-game) game)
              (setf (cna-lisp.internal:active-game) nil))))))
  (values))
