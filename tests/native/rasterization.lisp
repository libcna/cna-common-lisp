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

(defvar *rasterization-evidence* '()
  "What the rasterization tests actually proved, newest first.

A list of (KIND . DESCRIPTION). KIND is one of:

  :none      a renderer with no back-buffer readback; it refused, honestly
  :clear     GraphicsDevice.Clear reached the back buffer and read back
  :sprite    a SpriteBatch draw put the texture's own texels on the right pixels
  :primitive a DrawUserPrimitives triangle, through a BasicEffect pass, covered
             exactly the pixels its geometry covers

Kept apart on purpose. `Clear' reaching the back buffer says nothing about
whether `SpriteBatch.Draw' rasterises, and for a while the prose here claimed the
second on the strength of the first.")

(defun note-rasterization (kind description &rest arguments)
  (push (cons kind (apply #'format nil description arguments))
        *rasterization-evidence*))

(defun rasterization-proved-p (kind)
  (assoc kind *rasterization-evidence*))

(defun pixel-list (colour)
  (list (xna:color-r colour) (xna:color-g colour)
        (xna:color-b colour) (xna:color-a colour)))

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
         (note-rasterization :clear "~a: Clear reached the back buffer, ~d pixel(s) read"
                             renderer (length (or (pixels game) #())))
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
         (note-rasterization :none "~a: no back-buffer readback, and it refused ~
                                    rather than answering zeroes" renderer)
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

;;; --- does SpriteBatch reach pixels? ----------------------------------------------
;;;
;;; The clear test above proves `GraphicsDevice.Clear' reached the back buffer.
;;; It proves nothing whatever about `SpriteBatch.Draw', and for a while the
;;; prose in this repository claimed the second on the strength of the first.
;;; These two close that gap.
;;;
;;; Everything about the draw is chosen so that a disagreement can only be the
;;; rasteriser's:
;;;
;;;   * the texture is generated, not drawn -- every texel is stated in
;;;     tools/qualification/make-pixel-fixtures.py and is fully opaque;
;;;   * the destination rectangle is the texture's own size, so one texel is one
;;;     pixel and no filter can interpolate;
;;;   * PointClamp, so even that is not left to a default;
;;;   * BlendState.Opaque, so the source colour is what lands;
;;;   * Color.White as the tint, so nothing is multiplied;
;;;   * no rotation, no scale, no origin, no layer depth;
;;;   * integer placement, well away from any viewport edge;
;;;   * the sampled pixels are whole texels in from nothing -- the test reads the
;;;     corners of the destination rectangle and the pixels immediately outside
;;;     it, which is where an off-by-one would show.

(defclass sprite-pixel-game (graphics-game)
  ((fixture :initarg :fixture :accessor fixture)
   (destination :initarg :destination :accessor destination)
   (sprite-texture :initform nil :accessor sprite-texture)
   (samples :initform nil :accessor samples)
   (sample-error :initform nil :accessor sample-error)
   (sampled :initform nil :accessor sampled))
  (:documentation
   "Clears to a known colour, draws one known texture at one known rectangle, and
reads the back buffer straight back."))

(defmethod xna:load-content ((game sprite-pixel-game))
  (call-next-method)
  (setf (sprite-texture game)
        (gfx:texture-2d-from-png-file (xna:graphics-device game)
                                      (fixture-path (fixture game)))))

(defmethod xna:draw ((game sprite-pixel-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (sampled game)
    (setf (sampled game) t)
    (handler-case
        (let ((device (xna:graphics-device game)))
          (gfx:clear device (xna:cornflower-blue))
          (gfx:begin (batch game)
                     :sort-mode :deferred
                     :blend-state (gfx:blend-state-opaque)
                     :sampler-state (gfx:sampler-state-point-clamp)
                     :depth-stencil-state (gfx:depth-stencil-state-none)
                     :rasterizer-state (gfx:rasterizer-state-cull-none))
          (gfx:draw-texture (batch game) (sprite-texture game)
                            :destination (destination game)
                            :color (xna:white))
          (gfx:end (batch game))
          (let* ((viewport (gfx:viewport device))
                 (width (gfx:viewport-width viewport))
                 (pixels (gfx:get-back-buffer-data device)))
            (setf (samples game)
                  (lambda (x y) (aref pixels (+ x (* y width)))))))
      (error (condition) (setf (sample-error game) condition)))))

(defmacro with-sprite-pixel-game ((variable fixture destination) &body body)
  `(let ((,variable (make-instance 'sprite-pixel-game
                                   :exit-after 2 :fixture ,fixture
                                   :destination ,destination)))
     (unwind-protect
          (progn (xna:run ,variable)
                 (is (sampled ,variable) "the draw callback never ran")
                 ;; A renderer with no readback refuses here, and that refusal is
                 ;; the branch each test asserts rather than an error to re-raise.
                 (when (and (sample-error ,variable)
                            (rasterizing-renderer-p (renderer ,variable)))
                   (error (sample-error ,variable)))
                 ,@body)
       (progn
         (when (sprite-texture ,variable)
           (ignore-errors (xna:dispose (sprite-texture ,variable))))
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (ignore-errors (xna:dispose ,variable))))))

(define-native-test a-sprite-batch-draw-reaches-the-back-buffer
  (with-sprite-pixel-game (game "solid-magenta-8.png" (xna:make-rectangle 16 16 8 8))
    (let ((renderer (renderer game)))
      (if (not (rasterizing-renderer-p renderer))
          ;; No readback: the draw was still submitted and accepted, and the
          ;; refusal is what this renderer honestly has to say about pixels.
          (progn
            (is (null (samples game))
                "~a has no back-buffer readback but answered pixels" renderer)
            (is (typep (sample-error game) 'xna:cna-not-supported-error)
                "~a should refuse the readback with CNA-NOT-SUPPORTED-ERROR; it ~
                 signalled ~a" renderer (type-of (sample-error game))))
          (let ((magenta (xna:make-color 255 0 255 255))
                (background (xna:cornflower-blue)))
            (flet ((at (x y) (funcall (samples game) x y)))
              ;; Inside: the texture's own texels, not something like them.
              (dolist (point '((16 16) (17 20) (20 17) (23 23) (19 21)))
                (is (xna:color-equal magenta (at (first point) (second point)))
                    "(~d,~d) is ~a, not the texture's own (255 0 255 255)"
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              ;; Immediately outside, on all four sides: still the clear colour.
              ;; This is where an off-by-one in placement would show.
              (dolist (point '((15 16) (24 16) (16 15) (16 24) (15 15) (24 24)))
                (is (xna:color-equal background (at (first point) (second point)))
                    "(~d,~d) is ~a, not the CornflowerBlue that was cleared"
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              ;; And far away, to catch a draw that covered the whole target.
              (is (xna:color-equal background (at 0 0)))
              (is (xna:color-equal background (at 400 240)))
              (note-rasterization
               :sprite "~a: an 8x8 opaque texture drawn at (16,16) put its own ~
                        texels on exactly those pixels, and not one outside them"
               renderer)))))))

(define-native-test a-sprite-batch-draw-puts-each-texel-where-it-belongs
  ;; The solid texture proves something was drawn in the right rectangle. It
  ;; cannot tell a correct sampling from one that is flipped, transposed or off
  ;; by a texel, because every texel is the same. This one can: four 2x2
  ;; quadrants in four colours, drawn one-to-one.
  (with-sprite-pixel-game (game "quadrant-4.png" (xna:make-rectangle 16 16 4 4))
    (let ((renderer (renderer game)))
      (unless (rasterizing-renderer-p renderer)
        (is (typep (sample-error game) 'xna:cna-not-supported-error)
            "~a should refuse the readback rather than answering zeroes" renderer))
      (when (rasterizing-renderer-p renderer)
        (flet ((at (x y) (funcall (samples game) x y)))
          (dolist (row (list (list 16 16 (xna:make-color 255 0 0 255) "top-left red")
                             (list 19 16 (xna:make-color 0 255 0 255) "top-right green")
                             (list 16 19 (xna:make-color 0 0 255 255) "bottom-left blue")
                             (list 19 19 (xna:make-color 255 255 0 255)
                                   "bottom-right yellow")))
            (destructuring-bind (x y expected what) row
              (is (xna:color-equal expected (at x y))
                  "(~d,~d) should be the ~a texel; it is ~a"
                  x y what (pixel-list (at x y)))))
          (is (xna:color-equal (xna:cornflower-blue) (at 20 20))
              "the pixel past the sprite's bottom-right corner is not the clear colour")
          (note-rasterization
           :sprite "~a: a 4x4 four-quadrant texture landed with every quadrant on ~
                    its own pixels -- orientation and sampling are right, not only ~
                    placement"
           renderer))))))

;;; --- a primitive, rasterised ---------------------------------------------------------
;;;
;;; The third claim, and the one the buffer closure had to leave open: a
;;; *primitive* draw -- not a sprite -- reaching pixels. It needed an Effect,
;;; because CNA refuses a draw with none current, exactly as XNA's own
;;; `VerifyCanDraw' does.
;;;
;;; The geometry is chosen so nothing about it is approximate:
;;;
;;;   * BasicEffect's World, View and Projection are left at their defaults,
;;;     which CNA reports as identity, so the vertices *are* clip-space
;;;     coordinates and no matrix setter -- and therefore no optional shim -- is
;;;     involved in the proof;
;;;   * the triangle is a right triangle on half the viewport, wound so the
;;;     default CullCounterClockwise keeps it, and every sampled point is well
;;;     away from its edges, where a rasteriser's fill rule is entitled to
;;;     differ;
;;;   * VertexColorEnabled is on and lighting off, so the colour is the vertex
;;;     colour and not a shading result;
;;;   * the sampled points are read from a back buffer cleared to CornflowerBlue,
;;;     so "inside is red" and "outside is still the clear colour" are two
;;;     different assertions.

(defclass primitive-pixel-game (graphics-game)
  ((effect :initform nil :accessor primitive-effect)
   (samples :initform nil :accessor samples)
   (sample-error :initform nil :accessor sample-error)
   (sampled :initform nil :accessor sampled))
  (:documentation
   "Clears, applies a BasicEffect pass, draws one triangle in clip space and
reads the back buffer straight back."))

(defun clip-space-triangle ()
  "A right triangle over the lower-left half of clip space.

Wound clockwise in clip space, which is front-facing once the viewport transform
has flipped Y -- so the default CullCounterClockwise keeps it. Screen-space, on
an 800x480 viewport, the vertices land at (200,360), (200,120) and (600,360)."
  (vector (gfx:make-vertex-position-color (v3 -0.5 -0.5 0) (xna:make-color 255 0 0 255))
          (gfx:make-vertex-position-color (v3 -0.5 0.5 0) (xna:make-color 255 0 0 255))
          (gfx:make-vertex-position-color (v3 0.5 -0.5 0) (xna:make-color 255 0 0 255))))

(defmethod xna:draw ((game primitive-pixel-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (sampled game)
    (setf (sampled game) t)
    (handler-case
        (let ((device (xna:graphics-device game)))
          (gfx:clear device (xna:cornflower-blue))
          (let ((effect (make-instance 'gfx:basic-effect :graphics-device device)))
            (setf (primitive-effect game) effect
                  (gfx:effect-vertex-color-enabled effect) t
                  (gfx:effect-lighting-enabled effect) nil)
            (dolist (pass (gfx:collection-elements
                           (gfx:effect-technique-passes
                            (gfx:effect-current-technique effect))))
              (gfx:apply-effect-pass pass))
            (gfx:draw-user-primitives device :triangle-list (clip-space-triangle)
                                      :primitive-count 1))
          (let* ((viewport (gfx:viewport device))
                 (width (gfx:viewport-width viewport))
                 (pixels (gfx:get-back-buffer-data device)))
            (setf (samples game)
                  (lambda (x y) (aref pixels (+ x (* y width)))))))
      (error (condition) (setf (sample-error game) condition)))))

(define-native-test a-primitive-draw-through-an-effect-reaches-the-back-buffer
  (let ((game (make-instance 'primitive-pixel-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (sampled game) "the draw callback never ran")
           (let ((renderer (renderer game)))
             (if (not (rasterizing-renderer-p renderer))
                 (progn
                   (is (null (samples game))
                       "~a has no back-buffer readback but answered pixels" renderer)
                   (is (typep (sample-error game) 'xna:cna-not-supported-error)
                       "~a should refuse the readback with CNA-NOT-SUPPORTED-ERROR; ~
                        it signalled ~a"
                       renderer (type-of (sample-error game))))
                 (progn
                   (when (sample-error game) (error (sample-error game)))
                   (let ((red (xna:make-color 255 0 0 255))
                         (background (xna:cornflower-blue)))
                     (flet ((at (x y) (funcall (samples game) x y)))
                       ;; Well inside the triangle, on both sides of its middle.
                       (dolist (point '((260 340) (210 350) (300 250) (560 355)))
                         (is (xna:color-equal red (at (first point) (second point)))
                             "(~d,~d) should be inside the triangle; it is ~a"
                             (first point) (second point)
                             (pixel-list (at (first point) (second point)))))
                       ;; Outside it, on the other side of each of the three edges,
                       ;; and far away.
                       (dolist (point '((150 240) (300 100) (500 200) (700 400) (0 0)))
                         (is (xna:color-equal background
                                              (at (first point) (second point)))
                             "(~d,~d) should still be the CornflowerBlue that was ~
                              cleared; it is ~a"
                             (first point) (second point)
                             (pixel-list (at (first point) (second point)))))
                       (note-rasterization
                        :primitive "~a: a BasicEffect pass and one DrawUserPrimitives ~
                                    put a triangle's own vertex colour on the pixels ~
                                    its geometry covers, and on none outside it"
                        renderer)))))))
      (progn
        (when (primitive-effect game) (ignore-errors (xna:dispose (primitive-effect game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))
