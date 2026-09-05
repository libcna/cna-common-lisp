;;;; game-window.lisp --- GameWindow, and Game.Window.
;;;;
;;;; The window is a facade over the game, like Game.Content and the graphics
;;;; device -- but unlike the device it needs **no callback scope**, because CNA
;;;; takes an "active owned or callback-borrowed game handle" for every window
;;;; route. So these tests read and write the window from outside the loop, which
;;;; is where a program most wants to: setting a title or a size before running.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass window-game (counting-game)
  ((client-size-changes :initform 0 :accessor client-size-changes)
   (registry-delta :initform nil :accessor window-registry-delta))
  (:documentation "A game whose window is subscribed to and read."))

(define-native-test a-games-window-is-the-same-object-every-time
  "Game.Window is a property in XNA and answers by identity here, as Game.Content
does -- and for the same reason: a facade built twice would be two objects
holding two sets of subscriptions over one window."
  (with-counting-game (game :exit-after 1)
    (is (typep (xna:window game) 'xna:game-window))
    (is (eq (xna:window game) (xna:window game)))))

(define-native-test the-window-answers-what-cna-knows-about-it
  "Every readable property, from **outside** the loop.

That is the point of the test as much as the values are: XNA's GameWindow is not
scoped to a callback and CNA's window routes are not either, so a program can ask
before it runs. The graphics device is the type that cannot."
  (with-counting-game (game :exit-after 1)
    (let ((window (xna:window game)))
      (is (stringp (xna:title window)) "the title came back as ~a" (xna:title window))
      (is (member (xna:allow-user-resizing window) '(t nil)))
      ;; The client bounds come back as a rectangle whatever the renderer is, and
      ;; under HEADLESS they are legitimately **0x0**: there is no window. That is
      ;; CNA answering what is true rather than refusing, and asserting a positive
      ;; extent here would be asserting that a headless run has a window.
      (let ((bounds (xna:client-bounds window)))
        (is (xna:rectangle-p bounds))
        (is (not (minusp (xna:rectangle-width bounds)))
            "the client bounds are ~a" bounds)
        (is (not (minusp (xna:rectangle-height bounds)))))
      (is (stringp (xna:screen-device-name window)))
      ;; A flags enum, so a list -- and never NIL, because DisplayOrientation has
      ;; a named zero that the empty mask reads back as.
      (is (listp (xna:current-orientation window))
          "the orientation came back as ~a" (xna:current-orientation window)))))

(define-native-test the-windows-title-and-resizing-round-trip
  "Both settable properties, set to something that is not the default so a getter
ignoring its setter cannot pass."
  (with-counting-game (game :exit-after 1 :window-title "before")
    (let ((window (xna:window game)))
      (setf (xna:title window) "a title this test chose")
      (is (string= "a title this test chose" (xna:title window)))
      ;; ...and the game's declared-extension shortcut reaches the same place.
      (is (string= "a title this test chose" (xna:window-title game))
          "WINDOW-TITLE on the game answered ~a" (xna:window-title game))
      (let ((original (xna:allow-user-resizing window)))
        (setf (xna:allow-user-resizing window) (not original))
        (is (eq (not original) (xna:allow-user-resizing window))
            "AllowUserResizing did not round-trip")
        (setf (xna:allow-user-resizing window) original)))))

(define-native-test the-window-raises-its-three-events
  "ClientSizeChanged, OrientationChanged and ScreenDeviceNameChanged, over
cna_game_window_subscribe.

CNA gives a window registration the same handle type and release route as a
game's, so the existing machinery serves it unchanged -- and the proof of that is
the teardown: a registration the game failed to release would leave a registry
entry behind and make the shutdown fail."
  (let ((game (make-instance 'window-game :exit-after 2))
        (teardown nil))
    (unwind-protect
         (let* ((window (xna:window game))
                (before (int:callback-registry-count))
                (handlers
                  (list (xna:add-client-size-changed-handler
                         window (lambda (w) (declare (ignore w))
                                  (incf (client-size-changes game))))
                        (xna:add-orientation-changed-handler
                         window (lambda (w) (declare (ignore w))))
                        (xna:add-screen-device-name-changed-handler
                         window (lambda (w) (declare (ignore w)))))))
           (is (every #'functionp handlers))
           (setf (window-registry-delta game) (- (int:callback-registry-count) before))
           (is (= 3 (window-registry-delta game))
               "three subscriptions added ~d registry entry/entries"
               (window-registry-delta game))
           (xna:remove-orientation-changed-handler window (second handlers))
           (is (= 2 (- (int:callback-registry-count) before))
               "removing one left ~d" (- (int:callback-registry-count) before))
           (xna:run game))
      (progn
        (handler-case (xna:dispose game)
          (error (condition) (setf teardown condition)))
        (is (null teardown)
            "the game would not shut down with live window subscriptions: ~a" teardown)
        (is (zerop (int:callback-registry-count))
            "teardown left ~d registry entry/entries" (int:callback-registry-count))))))

(define-native-test the-screen-device-change-pair-takes-both-xna-shapes
  "EndScreenDeviceChange's two overloads, and the shape XNA has not got.

The one-argument form is CNA's route with both extents left out, which its own
documentation gives meaning to: a width or height 'less than one' keeps the
current one. One extent of the two is refused, because XNA has no such overload."
  (with-counting-game (game :exit-after 1)
    (let* ((window (xna:window game))
           (name (xna:screen-device-name window)))
      (xna:begin-screen-device-change window nil)
      (xna:end-screen-device-change window name)
      (xna:begin-screen-device-change window nil)
      (xna:end-screen-device-change window name :client-width 640 :client-height 480)
      (signals xna:cna-argument-error
        (xna:end-screen-device-change window name :client-width 640))
      (signals xna:cna-argument-error
        (xna:end-screen-device-change window name :client-height 480)))))

(define-native-test a-games-window-refuses-to-be-disposed-and-stays-usable
  "The window is a facade with nothing of its own to release, so disposing it is
refused -- and, as with the graphics device, the refusal must cost the object
nothing."
  (with-counting-game (game :exit-after 1)
    (let ((window (xna:window game)))
      (signals xna:cna-ownership-error (xna:dispose window))
      (is-false (xna:disposed-p window)
                "the refused window was marked disposed anyway")
      (is (stringp (xna:title window))
          "the refused window could no longer be used"))))
