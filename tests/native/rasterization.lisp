;;;; rasterization.lisp --- whether drawing reaches pixels, and how we know.
;;;;
;;;; Every other native test in this suite proves *submission*: the lifecycle
;;;; ran, the handles were valid, CNA accepted the commands. None of them can
;;;; say anything about pixels, and the qualification has always said so.
;;;;
;;;; GraphicsDevice.GetBackBufferData is the member that can, and CNA is honest
;;;; about which renderers have it: the route answers CNA_RESULT_NOT_SUPPORTED
;;;; "when the active renderer has no honest back-buffer readback" rather than a
;;;; buffer of zeroes. So these tests do not skip. They branch on the renderer
;;;; that is actually present and assert the truth for it:
;;;;
;;;;   HEADLESS  -- the readback must be refused, and refused by name;
;;;;   SOFTWARE  -- the readback must answer the exact pixels that were cleared.
;;;;
;;;; Both are real assertions. Which one ran is printed by the runner, because a
;;;; suite that passed without ever reaching the second branch has proved
;;;; nothing about rasterisation and must not be read as though it had.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defparameter *rasterizing-renderers* '("SOFTWARE" "OPENGL33" "OPENGLES3" "SDL_RENDERER"
                                        "VULKAN" "SDL_GPU" "PORTABLEGL" "OPENGL4")
  "Renderer names whose back-buffer readback is expected to answer real pixels.

The list is a claim about CNA, so it is checked rather than trusted: a renderer
on it that refuses the readback fails the test, and one not on it that answers
pixels fails too.")

(defvar *rasterization-evidence* nil
  "What the last rasterization test observed, for the runner's summary.")

(defun rasterizing-renderer-p (name)
  (member name *rasterizing-renderers* :test #'string-equal))

(defclass readback-game (graphics-game)
  ((cleared :initarg :cleared :initform nil :accessor cleared)
   (pixels :initform nil :accessor pixels)
   (readback-condition :initform nil :accessor readback-condition)
   (read-p :initform nil :accessor read-p))
  (:documentation
   "A game that clears to a known colour and reads the back buffer straight back."))

(defmethod xna:draw ((game readback-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (read-p game)
    (setf (read-p game) t)
    (let ((device (xna:graphics-device game)))
      (gfx:clear device (cleared game))
      (handler-case
          (setf (pixels game)
                (gfx:get-back-buffer-data device :source (xna:make-rectangle 0 0 8 4)))
        (error (condition) (setf (readback-condition game) condition))))))

(defmacro with-readback-game ((variable colour) &body body)
  `(let ((,variable (make-instance 'readback-game :exit-after 2 :cleared ,colour)))
     (unwind-protect (progn (xna:run ,variable) ,@body)
       (progn
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (ignore-errors (xna:dispose ,variable))))))

(define-native-test the-back-buffer-says-what-the-renderer-can-prove
  (with-readback-game (game (xna:cornflower-blue))
    (let ((renderer (renderer game)))
      (is (stringp renderer))
      (is (read-p game) "the draw callback never ran")
      (cond
        ((rasterizing-renderer-p renderer)
         ;; A rasterising renderer must produce the pixels, and they must be the
         ;; ones that were cleared -- CornflowerBlue is (100, 149, 237, 255), and
         ;; a renderer that answered a plausible-looking grey or a zeroed buffer
         ;; would fail here rather than pass quietly.
         (setf *rasterization-evidence*
               (format nil "~a: back buffer read, ~d pixel(s)" renderer
                       (length (or (pixels game) #()))))
         (is (null (readback-condition game))
             "~a refused the readback: ~a" renderer (readback-condition game))
         (is (= 32 (length (pixels game)))
             "an 8x4 window is 32 pixels; got ~d" (length (or (pixels game) #())))
         (let ((expected (xna:cornflower-blue)))
           (loop for pixel across (pixels game)
                 for index from 0
                 do (is (xna:color-equal expected pixel)
                        "pixel ~d is (~d ~d ~d ~d), not CornflowerBlue"
                        index (xna:color-r pixel) (xna:color-g pixel)
                        (xna:color-b pixel) (xna:color-a pixel)))))
        (t
         ;; A renderer with no honest readback must refuse, and say so. A buffer
         ;; of zeroes here would be the one thing worse than the refusal, because
         ;; it would look like evidence.
         (setf *rasterization-evidence*
               (format nil "~a: no back-buffer readback, and it refused rather ~
                            than answering zeroes" renderer))
         (is (null (pixels game))
             "~a answered pixels; if it really rasterises, add it to ~
              *RASTERIZING-RENDERERS*" renderer)
         (is (typep (readback-condition game) 'xna:cna-not-supported-error)
             "~a should refuse the readback with CNA-NOT-SUPPORTED-ERROR; it ~
              signalled ~a" renderer (type-of (readback-condition game)))
         (is (search "renderer" (string-downcase
                                 (princ-to-string (readback-condition game))))
             "the refusal should say the renderer is why"))))))

(define-native-test a-back-buffer-window-is-refused-when-it-makes-no-sense
  ;; Argument checks are CNA-Lisp's own and happen before the renderer is asked,
  ;; so they hold under every renderer.
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (let ((device (xna:graphics-device game)))
      ;; Outside a callback the device is refused first, which is the earlier
      ;; check; inside one, the shape check is.
      (signals xna:cna-scope-error (gfx:get-back-buffer-data device)))))

(define-native-test a-partial-back-buffer-window-group-is-refused
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    (let ((device (xna:graphics-device game)))
      ;; :START-INDEX without :ELEMENT-COUNT is not one of XNA's three overloads.
      ;; The shape is checked before the device, so this is the usage error and
      ;; not the scope error.
      (signals xna:cna-usage-error (gfx:get-back-buffer-data device :start-index 0))
      (signals xna:cna-usage-error (gfx:get-back-buffer-data device :element-count 4)))))
