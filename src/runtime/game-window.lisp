;;;; game-window.lisp --- Microsoft.Xna.Framework.GameWindow, and Game.Window.
;;;;
;;;; **A facade over the game, like `Game.Content` and the graphics device.** Every
;;;; CNA window route takes the *game* handle -- `cna_game_window_get_title_size`,
;;;; `..._get_client_bounds`, `..._subscribe` -- because CNA models the window as
;;;; something the game has rather than as an object with a handle of its own. So
;;;; this class holds no handle, is not disposed, and resolves the game's handle
;;;; per call.
;;;;
;;;; Unlike the graphics device it needs **no callback scope**: CNA takes an
;;;; "active owned or callback-borrowed game handle" here, so a program can read
;;;; the client bounds or set the title before the loop starts. That is XNA's
;;;; shape too, and it is the reason this is a separate facade rather than more
;;;; members on the device.
;;;;
;;;; `GameWindow` is **abstract** in XNA: a platform provides the concrete window
;;;; and the six protected `On*` methods are how that platform raises the three
;;;; events. Those six are not projected, for the reason every protected raiser in
;;;; this binding is not -- see `tools/api-compat/mapping-rules.json`.

(in-package #:microsoft.xna.framework)

(defparameter *game-window-event-values*
  (list (cons :client-size-changed
              cna-lisp.internal.ffi::+game-window-event-client-size-changed+)
        (cons :orientation-changed
              cna-lisp.internal.ffi::+game-window-event-orientation-changed+)
        (cons :screen-device-name-changed
              cna-lisp.internal.ffi::+game-window-event-screen-device-name-changed+))
  "GameWindow's three events.

CNA gives a window registration the same handle type and the same release route
as a game's -- its header says so: \"a window registration and a game registration
are the same kind of thing and one route releases both\" -- so the default
%UNSUBSCRIBE-NATIVELY serves this type unchanged.")

(defclass game-window (cna-lisp.internal:native-object)
  ((event-handlers :initform '() :accessor %event-handlers))
  (:default-initargs :ownership :parent-owned)
  (:documentation
   "Microsoft.Xna.Framework.GameWindow: the window a game runs in.

Reached through MICROSOFT.XNA.FRAMEWORK:WINDOW, which answers the same object
every time as XNA's property does. A facade over the game, holding no native
handle: every CNA window route takes the game's.

Abstract in XNA, and this is not a projection of a concrete platform window --
it is the members a program can reach, over the routes CNA has."))

(defun %window-game (window operation)
  "The game WINDOW is a facade over, checked and usable."
  (cna-lisp.internal:check-live window operation)
  (cna-lisp.internal:check-owner-thread
   (cna-lisp.internal:owner-thread-of window) operation :object-type 'game-window)
  (let ((game (cna-lisp.internal:owner-of window)))
    (unless game
      (error 'cna-invalid-object-error
             :operation operation :object-type 'game-window
             :format-control "this window has no game to be a window of."))
    (cna-lisp.internal:check-usable game operation)
    (cna-lisp.internal:handle-of game)))

(defmethod %check-disposable ((window game-window))
  "A game's window is released with its game, and has nothing of its own."
  (declare (ignorable window))
  (error 'cna-ownership-error
         :operation "dispose" :object-type 'game-window
         :format-control
         "a game's window is the game's, and there is no window handle here to release: ~
          every CNA window route takes the game's handle. Dispose the game instead. ~
          This window is untouched and remains usable."
         :format-arguments '()))

;;; --- the properties ---------------------------------------------------------

(defgeneric title (game-window)
  (:documentation "GameWindow.Title: the window's caption."))

(defgeneric (setf title) (value game-window)
  (:documentation
   "GameWindow.Title's setter.

XNA's setter calls the protected `SetTitle', which a platform window overrides;
CNA has one route and this uses it. MICROSOFT.XNA.FRAMEWORK:WINDOW-TITLE on the
*game* is a declared extension that reaches the same place in one call."))

(defmethod title ((window game-window))
  (let ((handle (%window-game window "title")))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out) (cna-lisp.internal.ffi::%game-window-get-title-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%game-window-copy-title handle buffer capacity out))
     "title")))

(defmethod (setf title) (value (window game-window))
  (check-type value string)
  (let ((handle (%window-game window "(setf title)")))
    (cna-lisp.internal:with-utf8-view (data length value)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-set-window-title handle data length)
       "(setf title)" :object-type 'game-window)))
  value)

(defgeneric allow-user-resizing (game-window)
  (:documentation "GameWindow.AllowUserResizing."))

(defgeneric (setf allow-user-resizing) (value game-window)
  (:documentation "GameWindow.AllowUserResizing's setter."))

(defmethod allow-user-resizing ((window game-window))
  (let ((handle (%window-game window "allow-user-resizing")))
    (cffi:with-foreign-object (out :uint8)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-window-get-allow-user-resizing handle out)
       "allow-user-resizing" :object-type 'game-window)
      (cna-lisp.internal.ffi:cna-true-p (cffi:mem-ref out :uint8)))))

(defmethod (setf allow-user-resizing) (value (window game-window))
  (let ((handle (%window-game window "(setf allow-user-resizing)")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-window-set-allow-user-resizing
      handle (cna-lisp.internal.ffi:cna-bool-of value))
     "(setf allow-user-resizing)" :object-type 'game-window))
  value)

(defgeneric client-bounds (game-window)
  (:documentation "GameWindow.ClientBounds: the window's client rectangle."))

(defmethod client-bounds ((window game-window))
  (let ((handle (%window-game window "client-bounds")))
    (cffi:with-foreign-object (bounds '(:struct cna-lisp.internal.ffi::cna-rectangle))
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-window-get-client-bounds handle bounds)
       "client-bounds" :object-type 'game-window)
      (macrolet ((slot (name)
                   `(cffi:foreign-slot-value
                     bounds '(:struct cna-lisp.internal.ffi::cna-rectangle) ',name)))
        (make-rectangle (slot cna-lisp.internal.ffi::x) (slot cna-lisp.internal.ffi::y)
                        (slot cna-lisp.internal.ffi::width)
                        (slot cna-lisp.internal.ffi::height))))))

(defgeneric current-orientation (game-window)
  (:documentation
   "GameWindow.CurrentOrientation: the orientation the window is displayed at.

A *list* of keywords, because DisplayOrientation carries the FlagsAttribute, and
the empty mask reads back as (:DEFAULT), which is that enum's named zero."))

(defmethod current-orientation ((window game-window))
  (let ((handle (%window-game window "current-orientation")))
    (cffi:with-foreign-object (out :uint32)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-window-get-current-orientation handle out)
       "current-orientation" :object-type 'game-window)
      (display-orientation-from-value (cffi:mem-ref out :uint32)))))

(defgeneric screen-device-name (game-window)
  (:documentation "GameWindow.ScreenDeviceName: the display the window is on."))

(defmethod screen-device-name ((window game-window))
  (let ((handle (%window-game window "screen-device-name")))
    (cna-lisp.internal:count-then-copy-string
     (lambda (out)
       (cna-lisp.internal.ffi::%game-window-get-screen-device-name-size handle out))
     (lambda (buffer capacity out)
       (cna-lisp.internal.ffi::%game-window-copy-screen-device-name
        handle buffer capacity out))
     "screen-device-name")))

;;; --- the screen-device change pair -------------------------------------------

(defgeneric begin-screen-device-change (game-window will-be-full-screen)
  (:documentation
   "GameWindow.BeginScreenDeviceChange(Boolean): start moving or resizing.

Paired with END-SCREEN-DEVICE-CHANGE, as XNA pairs them."))

(defmethod begin-screen-device-change ((window game-window) will-be-full-screen)
  (let ((handle (%window-game window "begin-screen-device-change")))
    (cna-lisp.internal:check-result
     (cna-lisp.internal.ffi::%game-window-begin-screen-device-change
      handle (cna-lisp.internal.ffi:cna-bool-of will-be-full-screen))
     "begin-screen-device-change" :object-type 'game-window))
  (values))

(defgeneric end-screen-device-change (game-window screen-device-name
                                      &key client-width client-height)
  (:documentation
   "GameWindow.EndScreenDeviceChange: both overloads, the keywords selecting one.

    (end-screen-device-change window name)
    (end-screen-device-change window name :client-width 800 :client-height 480)

XNA has `EndScreenDeviceChange(String)' and
`EndScreenDeviceChange(String, Int32, Int32)', and CNA has one route whose
documentation gives the first its meaning: a width or height \"less than one\"
keeps the current one. So the one-argument overload is this route with both left
out, rather than a second route or a remembered size. Either both extents or
neither, because XNA has no overload with one."))

(defmethod end-screen-device-change ((window game-window) screen-device-name
                                     &key (client-width nil width-p)
                                          (client-height nil height-p))
  (check-type screen-device-name string)
  (unless (eq width-p height-p)
    (error 'cna-argument-error
           :operation "end-screen-device-change"
           :parameter-name (if width-p "client-height" "client-width")
           :format-control
           "XNA has EndScreenDeviceChange(String) and EndScreenDeviceChange(String, Int32, ~
            Int32) and nothing between: give both :CLIENT-WIDTH and :CLIENT-HEIGHT or ~
            neither."))
  (when width-p
    (check-type client-width (integer 1))
    (check-type client-height (integer 1)))
  (let ((handle (%window-game window "end-screen-device-change")))
    (cna-lisp.internal:with-utf8-view (data length screen-device-name)
      (cna-lisp.internal:check-result
       (cna-lisp.internal.ffi::%game-window-end-screen-device-change
        handle data length (or client-width 0) (or client-height 0))
       "end-screen-device-change" :object-type 'game-window)))
  (values))

;;; --- the three events ---------------------------------------------------------

(defmethod %event-table ((object game-window)) *game-window-event-values*)

(defmethod %check-event-usable ((object game-window) operation)
  (%window-game object operation))

(defmethod %event-source-disposed-p ((object game-window))
  "The window is a facade over the game, so the game is what has been disposed."
  (let ((game (cna-lisp.internal:owner-of object)))
    (or (null game) (cna-lisp.internal:disposed-state-of game))))

(defmethod %subscribe-natively ((object game-window) value token registration)
  (cna-lisp.internal.ffi::%game-window-subscribe
   (%window-game object "add-event-handler") value
   (cna-lisp.internal.ffi:game-event-callback-pointer)
   (cffi:make-pointer token) registration))

(macrolet ((window-event (event add remove documentation)
             `(progn
                (%define-event-pair ,add ,remove ,documentation)
                (%define-event-methods game-window ,event ,add ,remove))))
  (window-event :client-size-changed add-client-size-changed-handler
                remove-client-size-changed-handler
    "GameWindow.ClientSizeChanged: the client area changed size.

HANDLER is called with the window. The new size is read from CLIENT-BOUNDS: the
event carries nothing, on both sides.")
  (window-event :orientation-changed add-orientation-changed-handler
                remove-orientation-changed-handler
    "GameWindow.OrientationChanged: the display orientation changed.")
  (window-event :screen-device-name-changed add-screen-device-name-changed-handler
                remove-screen-device-name-changed-handler
    "GameWindow.ScreenDeviceNameChanged: the window moved to another display."))

(defmethod print-object ((window game-window) stream)
  (print-unreadable-object (window stream :type t)
    (format stream "~:[live~;disposed~]"
            (cna-lisp.internal:disposed-state-of window))))

;;; --- Game.Window --------------------------------------------------------------

(defgeneric window (game)
  (:documentation
   "Game.Window: the window this game runs in.

The same object every time, as XNA's property is. A facade over the game, so it
is not disposed and disposing it is refused with a diagnosable condition.

Get-only, as XNA's is."))

(defmethod window ((game game))
  (or (%game-window game)
      (setf (%game-window game)
            (make-instance 'game-window
                           :ownership :parent-owned
                           :owner game
                           :owner-thread (cna-lisp.internal:owner-thread-of game)))))
