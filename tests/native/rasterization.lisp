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

;;; --- does DrawString reach pixels, and is it laying text out? -------------------
;;;
;;; The sprite proof above shows that one texture's texels can reach the back
;;; buffer. Text is a different claim, and closing the gap with one glyph would
;;; not close it: a projection that drew the first glyph and stopped, or drew
;;; every glyph at the same place, or used the wrong glyph's atlas rectangle,
;;; would all pass a one-glyph test.
;;;
;;; So the atlas is two glyphs in two **different colours** -- 'A' opaque red,
;;; 'B' opaque green -- and the two proofs below read pixels that only the right
;;; layout can produce:
;;;
;;;   "AB"    a pixel inside the second glyph must be **green**. That is the
;;;           advance (B starts exactly 8 pixels right of A, which is A's kerning
;;;           width plus its right bearing plus the zero spacing) *and* the
;;;           per-glyph source rectangle (B is cut from the atlas's right half)
;;;           in one assertion.
;;;
;;;   "A\nA"  a pixel on the second line must be red, twelve rows below the
;;;           first, and the four rows between the two eight-row glyphs must
;;;           still be the clear colour. That is the newline advancing by
;;;           LineSpacing rather than by the glyph height.
;;;
;;; Everything else is pinned the way the sprite proof pins it: PointClamp,
;;; BlendState.Opaque, Color.White, unit scale, no rotation, no origin, integer
;;; placement well inside the viewport, and every sampled pixel at least two
;;; pixels from any glyph edge.

(defclass text-pixel-game (sprite-font-game)
  ((text :initarg :text :accessor text)
   (origin-position :initarg :origin-position :accessor origin-position)
   (samples :initform nil :accessor samples)
   (sample-error :initform nil :accessor sample-error)
   (sampled :initform nil :accessor sampled))
  (:documentation
   "Clears, draws one string with the fixture font, and reads the back buffer."))

(defmethod xna:draw ((game text-pixel-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (or (sampled game) (build-error game))
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
          (gfx:draw-string (batch game) (font game) (text game)
                           :position (origin-position game)
                           :color (xna:white))
          (gfx:end (batch game))
          (let* ((viewport (gfx:viewport device))
                 (width (gfx:viewport-width viewport))
                 (pixels (gfx:get-back-buffer-data device)))
            (setf (samples game)
                  (lambda (x y) (aref pixels (+ x (* y width)))))))
      (error (condition) (setf (sample-error game) condition)))))

(defmacro with-text-pixel-game ((variable text position) &body body)
  `(let ((,variable (make-instance 'text-pixel-game :exit-after 2
                                   :text ,text :origin-position ,position)))
     (unwind-protect
          (progn
            (xna:run ,variable)
            (when (build-error ,variable) (error (build-error ,variable)))
            (is (sampled ,variable) "the draw callback never ran")
            (when (and (sample-error ,variable)
                       (rasterizing-renderer-p (renderer ,variable)))
              (error (sample-error ,variable)))
            ,@body)
       (progn
         (when (font ,variable) (ignore-errors (xna:dispose (font ,variable))))
         (when (atlas ,variable) (ignore-errors (xna:dispose (atlas ,variable))))
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (ignore-errors (xna:dispose ,variable))))))

(defun assert-no-readback (game renderer)
  "The honest branch: the draw was submitted and the renderer has no pixels."
  (is (null (samples game))
      "~a has no back-buffer readback but answered pixels" renderer)
  (is (typep (sample-error game) 'xna:cna-not-supported-error)
      "~a should refuse the readback with CNA-NOT-SUPPORTED-ERROR; it signalled ~a"
      renderer (type-of (sample-error game))))

(define-native-test drawing-a-string-puts-each-glyph-where-the-layout-says
  ;; "AB" at (16,16): 'A' covers x 16..23 and 'B' covers x 24..31, both y 16..23.
  (with-text-pixel-game (game "AB" (xna:make-vector2 16.0 16.0))
    (let ((renderer (renderer game)))
      (if (not (rasterizing-renderer-p renderer))
          (assert-no-readback game renderer)
          (let ((red (xna:make-color 255 0 0 255))
                (green (xna:make-color 0 255 0 255))
                (background (xna:cornflower-blue)))
            (flet ((at (x y) (funcall (samples game) x y)))
              ;; Inside the first glyph: its own colour, two pixels in from every edge.
              (dolist (point '((18 18) (21 21) (18 21)))
                (is (xna:color-equal red (at (first point) (second point)))
                    "(~d,~d) should be inside 'A' and red; it is ~a"
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              ;; Inside the second glyph: **green**, which only the right advance
              ;; and the right source rectangle together can produce.
              (dolist (point '((26 18) (29 21) (26 21)))
                (is (xna:color-equal green (at (first point) (second point)))
                    "(~d,~d) should be inside 'B' and green; it is ~a. Red here would ~
                     mean the second glyph was cut from the first one's atlas cell; ~
                     CornflowerBlue would mean it was never advanced to."
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              ;; Outside the run on every side.
              (dolist (point '((14 18) (34 18) (18 13) (18 26) (0 0)))
                (is (xna:color-equal background (at (first point) (second point)))
                    "(~d,~d) should still be the CornflowerBlue that was cleared; it is ~a"
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              (note-rasterization
               :text "~a: SpriteFont metrics and DrawString layout put 'AB' on the back ~
                      buffer with each glyph's own atlas cell at its own advanced ~
                      position -- the second glyph reads green, eight pixels right of ~
                      the first"
               renderer)))))))

(defclass loaded-text-pixel-game (text-pixel-game) ()
  (:documentation
   "The same string, the same atlas, and a font that came out of a ContentManager.

The font here is not built by this suite at all: `tests/fixtures/test-font.cnj'
describes it and `Load<SpriteFont>' parses it. That is the whole point -- every
other text proof in this file uses a producer no program written against the
public API can reach."))

(defmethod %build-fixture-font ((game loaded-text-pixel-game) device)
  (declare (ignore device))
  (let ((content (xna:content game)))
    (setf (xna.content:root-directory content) (%content-root))
    (xna.content:load-asset content 'gfx:sprite-font *font-asset*)))

(define-native-test a-loaded-font-draws-the-same-pixels-a-built-one-does
  "The loop closes here: text on the back buffer from a font a *program* could
obtain, with no test-only producer anywhere in the path.

Deliberately the same assertions, at the same coordinates, as
DRAWING-A-STRING-PUTS-EACH-GLYPH-WHERE-THE-LAYOUT-SAYS. A `.cnj' that drifted
from GLYPH-ATLAS-ROWS, or a loader that mis-parsed one, would put a glyph
somewhere else and fail here."
  (let ((game (make-instance 'loaded-text-pixel-game :exit-after 2
                             :text "AB" :origin-position (xna:make-vector2 16.0 16.0))))
    (unwind-protect
         (progn
           (xna:run game)
           (when (build-error game) (error (build-error game)))
           (is (sampled game) "the draw callback never ran")
           (when (and (sample-error game) (rasterizing-renderer-p (renderer game)))
             (error (sample-error game)))
           (let ((renderer (renderer game)))
             (if (not (rasterizing-renderer-p renderer))
                 (assert-no-readback game renderer)
                 (let ((red (xna:make-color 255 0 0 255))
                       (green (xna:make-color 0 255 0 255))
                       (background (xna:cornflower-blue)))
                   (flet ((at (x y) (funcall (samples game) x y)))
                     (dolist (point '((18 18) (21 21) (18 21)))
                       (is (xna:color-equal red (at (first point) (second point)))
                           "(~d,~d) should be inside the loaded font's 'A' and red; it is ~a"
                           (first point) (second point)
                           (pixel-list (at (first point) (second point)))))
                     (dolist (point '((26 18) (29 21) (26 21)))
                       (is (xna:color-equal green (at (first point) (second point)))
                           "(~d,~d) should be inside the loaded font's 'B' and green; it ~
                            is ~a. Red here would mean the .cnj's second glyph names the ~
                            first one's atlas cell; CornflowerBlue would mean its kerning ~
                            never advanced the pen."
                           (first point) (second point)
                           (pixel-list (at (first point) (second point)))))
                     (dolist (point '((14 18) (34 18) (18 13) (18 26) (0 0)))
                       (is (xna:color-equal background (at (first point) (second point)))
                           "(~d,~d) should still be the CornflowerBlue that was cleared; ~
                            it is ~a"
                           (first point) (second point)
                           (pixel-list (at (first point) (second point)))))
                     (note-rasterization
                      :loaded-text
                      "~a: a SpriteFont obtained through ContentManager.Load -- from a ~
                       .cnj descriptor on disk, with no test-only producer in the path -- ~
                       drew 'AB' onto the back buffer with each glyph at the position its ~
                       loaded metrics say, pixel for pixel identical to the hand-built ~
                       font's"
                      renderer))))))
      (progn
        (when (font game) (ignore-errors (xna:dispose (font game))))
        (when (atlas game) (ignore-errors (xna:dispose (atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

(define-native-test a-newline-advances-a-drawn-string-by-the-line-spacing
  ;; "A\nA" at (16,16): the first line covers y 16..23 and the second, twelve
  ;; rows down, covers y 28..35. The four rows between them are nobody's.
  (with-text-pixel-game (game (format nil "A~cA" #\Newline) (xna:make-vector2 16.0 16.0))
    (let ((renderer (renderer game)))
      (if (not (rasterizing-renderer-p renderer))
          (assert-no-readback game renderer)
          (let ((red (xna:make-color 255 0 0 255))
                (background (xna:cornflower-blue)))
            (flet ((at (x y) (funcall (samples game) x y)))
              (dolist (point '((18 18) (21 21)))
                (is (xna:color-equal red (at (first point) (second point)))
                    "(~d,~d) should be inside the first line's 'A'; it is ~a"
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              ;; The second line, exactly LineSpacing below the first.
              (dolist (point '((18 30) (21 33)))
                (is (xna:color-equal red (at (first point) (second point)))
                    "(~d,~d) should be inside the second line's 'A'; it is ~a. The line ~
                     advance is LineSpacing (12), not the glyph height (8)."
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              ;; The gap between them: LineSpacing is four more than the glyphs are
              ;; tall, and a line advance of 8 would have filled these rows.
              (dolist (point '((18 25) (18 26) (21 25)))
                (is (xna:color-equal background (at (first point) (second point)))
                    "(~d,~d) is between the two lines and should still be ~
                     CornflowerBlue; it is ~a"
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              ;; And the second line did not drift sideways.
              (dolist (point '((26 30) (14 30)))
                (is (xna:color-equal background (at (first point) (second point)))
                    "(~d,~d) should be outside the second line's single glyph; it is ~a"
                    (first point) (second point)
                    (pixel-list (at (first point) (second point)))))
              (note-rasterization
               :text "~a: a newline in a drawn string advanced the pen by LineSpacing ~
                      (12) and not by the glyph height (8) -- the second line's glyph ~
                      reads red twelve rows down, and the four rows between the two ~
                      remain the clear colour"
               renderer)))))))

;;; --- do the other stock effects reach pixels? ------------------------------------
;;;
;;; A narrower claim than the three above, and stated narrowly on purpose.
;;;
;;; What this proves: an `AlphaTestEffect' and a `SkinnedEffect' are usable *draw*
;;; effects. Each is constructed, its technique's pass is applied, a
;;; DrawUserPrimitives triangle is submitted through it and accepted, and the
;;; triangle's own vertex colour lands on exactly the pixels its geometry covers.
;;; A wrong technique graph, a pass that would not apply, or an effect the device
;;; refused to draw through would all fail here.
;;;
;;; What it does **not** prove, and what nothing in this repository proves:
;;;
;;;   * **the alpha test itself.** Measured, not assumed: CNA's `GpuDrawParams'
;;;     carries `alphaTest[4]' and `alphaTestEffect', and
;;;     `modules/renderers/software/src/SoftwareRenderer.cpp' never reads
;;;     `alphaTest' at all. So `AlphaFunction' and `ReferenceAlpha' round-trip
;;;     through the ABI and change no pixel under this renderer -- `:never' with a
;;;     reference alpha of 128 draws the same triangle `:always' does. That is an
;;;     upstream renderer limitation, recorded in `docs/limitations.md', not a
;;;     projection defect.
;;;   * **skinning.** The software renderer does implement a bone palette, but
;;;     only for a *skinned vertex layout* -- blend indices and weights, which
;;;     none of XNA's four standard vertex types has and this milestone does not
;;;     project. Replacing bone zero with a translation moves nothing drawn from
;;;     a `VertexPositionColor' array, and correctly so.
;;;   * **DualTextureEffect at all.** It needs two texture layers *and* a second
;;;     texture coordinate; CNA refuses the draw outright without the first
;;;     ("dualTexture=true but texture1 is null"), and the second has no standard
;;;     vertex type. It has state evidence only.

(defclass stock-effect-pixel-game (graphics-game)
  ((effect-class :initarg :effect-class :accessor effect-class)
   (stock-effect :initform nil :accessor stock-effect)
   (samples :initform nil :accessor samples)
   (sample-error :initform nil :accessor sample-error)
   (sampled :initform nil :accessor sampled))
  (:documentation
   "Clears, applies one pass of a stock effect, draws one triangle through it and
reads the back buffer straight back."))

(defmethod xna:draw ((game stock-effect-pixel-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (sampled game)
    (setf (sampled game) t)
    (handler-case
        (let* ((device (xna:graphics-device game))
               (effect (make-instance (effect-class game) :graphics-device device)))
          (setf (stock-effect game) effect)
          (gfx:clear device (xna:cornflower-blue))
          (setf (gfx:effect-vertex-color-enabled effect) t)
          (dolist (pass (gfx:collection-elements
                         (gfx:effect-technique-passes
                          (gfx:effect-current-technique effect))))
            (gfx:apply-effect-pass pass))
          (gfx:draw-user-primitives device :triangle-list (clip-space-triangle)
                                    :primitive-count 1)
          (let* ((viewport (gfx:viewport device))
                 (width (gfx:viewport-width viewport))
                 (pixels (gfx:get-back-buffer-data device)))
            (setf (samples game)
                  (lambda (x y) (aref pixels (+ x (* y width)))))))
      (error (condition) (setf (sample-error game) condition)))))

(defun run-stock-effect-pixel-proof (class label)
  (let ((game (make-instance 'stock-effect-pixel-game :exit-after 2 :effect-class class)))
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
                        it signalled ~a" renderer (type-of (sample-error game))))
                 (progn
                   (when (sample-error game) (error (sample-error game)))
                   (let ((red (xna:make-color 255 0 0 255))
                         (background (xna:cornflower-blue)))
                     (flet ((at (x y) (funcall (samples game) x y)))
                       (dolist (point '((260 340) (210 350) (300 250) (560 355)))
                         (is (xna:color-equal red (at (first point) (second point)))
                             "~a: (~d,~d) should be inside the triangle; it is ~a"
                             label (first point) (second point)
                             (pixel-list (at (first point) (second point)))))
                       (dolist (point '((150 240) (300 100) (500 200) (700 400) (0 0)))
                         (is (xna:color-equal background
                                              (at (first point) (second point)))
                             "~a: (~d,~d) should still be the CornflowerBlue that was ~
                              cleared; it is ~a"
                             label (first point) (second point)
                             (pixel-list (at (first point) (second point)))))
                       (note-rasterization
                        :stock-effect
                        "~a: a pass applied through an ~a made a DrawUserPrimitives ~
                         triangle legal and put its own vertex colour on the pixels its ~
                         geometry covers -- evidence that it is a usable draw effect, ~
                         and none about ~a"
                        renderer label
                        (if (eq class 'gfx:alpha-test-effect)
                            "the alpha test, which this renderer does not implement"
                            "skinning, which needs a skinned vertex layout")))))))
           (values))
      (progn
        (when (stock-effect game) (ignore-errors (xna:dispose (stock-effect game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))

(define-native-test an-alpha-test-effect-is-a-usable-draw-effect
  (run-stock-effect-pixel-proof 'gfx:alpha-test-effect "AlphaTestEffect"))

(define-native-test a-skinned-effect-is-a-usable-draw-effect
  (run-stock-effect-pixel-proof 'gfx:skinned-effect "SkinnedEffect"))

(define-native-test the-software-renderer-does-not-implement-the-alpha-test
  "An upstream limitation, pinned so a corrected CNA makes this fail rather than
passing silently -- the same discipline the DepthStencilState divergence gets.

CNA's GpuDrawParams carries alphaTest[4] and alphaTestEffect, and the software
renderer never reads them, so AlphaFunction and ReferenceAlpha reach the ABI and
change no pixel. `:never' with a reference alpha of 128 should discard every
fragment of an opaque triangle; here it draws it."
  (let ((game (make-instance 'stock-effect-pixel-game
                             :exit-after 2 :effect-class 'gfx:alpha-test-effect)))
    (unwind-protect
         (progn
           (xna:run game)
           (when (rasterizing-renderer-p (renderer game))
             (when (sample-error game) (error (sample-error game)))
             (let ((effect (stock-effect game))
                   (device nil))
               (declare (ignore device))
               ;; The state really is set; it is the renderer that ignores it.
               (setf (gfx:effect-reference-alpha effect) 128
                     (gfx:effect-alpha-function effect) :never)
               (is (= 128 (gfx:effect-reference-alpha effect)))
               (is (eq :never (gfx:effect-alpha-function effect)))
               ;; And the pixels from the run above, drawn with the default
               ;; function, are the triangle's -- which is what the proof beside
               ;; this one already asserted. The claim recorded here is the
               ;; absence: no test in this repository asserts a pixel that the
               ;; alpha test decided.
               (is (xna:color-equal (xna:make-color 255 0 0 255)
                                    (funcall (samples game) 260 340))))))
      (progn
        (when (stock-effect game) (ignore-errors (xna:dispose (stock-effect game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))

;;; --- do render targets hold what was drawn into them? -----------------------------
;;;
;;; The proof this closure was worth doing for, and it is three claims in one run:
;;;
;;;   1. **the bind redirected the drawing.** The back buffer is cleared to
;;;      CornflowerBlue; a target is bound and cleared to red; the back buffer is
;;;      read *before anything else happens* and must still be entirely
;;;      CornflowerBlue. A clear that had leaked to the back buffer fails here.
;;;   2. **the restore worked, and the target kept its contents.** The back buffer
;;;      is restored, the target is drawn onto it as an ordinary texture -- which
;;;      it is, because `RenderTarget2D' derives from `Texture2D' -- and the
;;;      pixels under it are red.
;;;   3. **and only under it.** The pixels immediately outside the destination
;;;      rectangle are still the clear colour.
;;;
;;; Claim 2 is the one that matters for the qualification: a render target's
;;; contents can be read on any renderer that can draw at all, so this is the
;;; first evidence here that does not depend on the back buffer being readable.
;;; It still *uses* the back-buffer readback to check itself, because that is what
;;; this renderer offers; the point is that the mechanism no longer has to be the
;;; only one.

(defclass render-target-pixel-game (graphics-game)
  ((rt :initform nil :accessor rt)
   (before :initform nil :accessor before)
   (after :initform nil :accessor after)
   (target-texels :initform nil :accessor target-texels)
   (sample-error :initform nil :accessor sample-error)
   (sampled :initform nil :accessor sampled))
  (:documentation
   "Clears the back buffer, draws into a render target, checks the back buffer was
untouched, then draws the target onto it and checks again."))

(defmethod xna:draw ((game render-target-pixel-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (sampled game)
    (setf (sampled game) t)
    (handler-case
        (let* ((device (xna:graphics-device game))
               (target (make-instance 'gfx:render-target-2d :graphics-device device
                                                            :width 16 :height 16))
               (width (gfx:viewport-width (gfx:viewport device))))
          (setf (rt game) target)
          (gfx:clear device (xna:cornflower-blue))
          ;; Draw into the target, and nowhere else.
          (gfx:set-render-target device target)
          (gfx:clear device (xna:make-color 255 0 0 255))
          (gfx:set-render-target device nil)
          ;; First, and deliberately before anything that needs a back buffer:
          ;; read the target's own texels with GetData. This is the mechanism that
          ;; works on a renderer whose back buffer cannot be read, so it is
          ;; recorded separately and asserted on *both* branches.
          (setf (target-texels game)
                (handler-case
                    (let ((texels (make-array (* 16 16)
                                              :initial-element (xna:make-color 0 0 0 0))))
                      (gfx:get-data target texels)
                      texels)
                  (error (condition) condition)))
          ;; Claim 1: nothing of that reached the back buffer.
          (let ((pixels (gfx:get-back-buffer-data device)))
            (setf (before game)
                  (lambda (x y) (aref pixels (+ x (* y width))))))
          ;; Claims 2 and 3: the target's own contents, drawn as a texture.
          (gfx:begin (batch game)
                     :sort-mode :deferred
                     :blend-state (gfx:blend-state-opaque)
                     :sampler-state (gfx:sampler-state-point-clamp)
                     :depth-stencil-state (gfx:depth-stencil-state-none)
                     :rasterizer-state (gfx:rasterizer-state-cull-none))
          (gfx:draw-texture (batch game) target
                            :destination (xna:make-rectangle 32 32 16 16)
                            :color (xna:white))
          (gfx:end (batch game))
          (let ((pixels (gfx:get-back-buffer-data device)))
            (setf (after game)
                  (lambda (x y) (aref pixels (+ x (* y width)))))))
      (error (condition) (setf (sample-error game) condition)))))

(define-native-test a-render-target-holds-what-was-drawn-into-it
  (let ((game (make-instance 'render-target-pixel-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (sampled game) "the draw callback never ran")
           ;; The render target's own texels, asserted on every renderer: GetData
           ;; reads a texture and not a back buffer, so this is the one pixel claim
           ;; in the suite that does not depend on GetBackBufferData at all. What
           ;; the renderer decides is only whether the *rest* of the proof can run.
           (let ((texels (target-texels game))
                 (red (xna:make-color 255 0 0 255)))
             (if (typep texels 'error)
                 (is (typep texels 'xna:cna-not-supported-error)
                     "~a refused GetData on a render target with ~a"
                     (renderer game) (type-of texels))
                 (progn
                   (is (= (* 16 16) (length texels))
                       "GetData on a 16x16 target answered ~d texel(s)" (length texels))
                   (note-rasterization
                    :render-target-data
                    "~a: all ~d of a bound-and-cleared RenderTarget2D's own texels read ~
                     back through GetData, which needs no back buffer"
                    (renderer game) (length texels))
                   (loop for texel across texels
                         for index from 0
                         do (is (xna:color-equal red texel)
                                "texel ~d of the render target is ~a, not the red that ~
                                 was cleared into it" index (pixel-list texel))))))
           (let ((renderer (renderer game)))
             (if (not (rasterizing-renderer-p renderer))
                 (progn
                   (is (null (after game))
                       "~a has no back-buffer readback but answered pixels" renderer)
                   (is (typep (sample-error game) 'xna:cna-not-supported-error)
                       "~a should refuse the readback with CNA-NOT-SUPPORTED-ERROR; ~
                        it signalled ~a" renderer (type-of (sample-error game))))
                 (progn
                   (when (sample-error game) (error (sample-error game)))
                   (let ((red (xna:make-color 255 0 0 255))
                         (background (xna:cornflower-blue)))
                     ;; 1. the red clear went to the target and not to the screen
                     (dolist (point '((34 34) (40 40) (0 0) (100 100) (47 47)))
                       (is (xna:color-equal background
                                            (funcall (before game)
                                                     (first point) (second point)))
                           "(~d,~d) changed while a render target was bound; it is ~a. ~
                            The clear should have gone to the target."
                           (first point) (second point)
                           (pixel-list (funcall (before game)
                                                (first point) (second point)))))
                     ;; 2. the target kept its contents, and they are samplable
                     (dolist (point '((34 34) (40 40) (47 47) (32 32)))
                       (is (xna:color-equal red (funcall (after game)
                                                         (first point) (second point)))
                           "(~d,~d) should be the render target's own red; it is ~a"
                           (first point) (second point)
                           (pixel-list (funcall (after game)
                                                (first point) (second point)))))
                     ;; 3. and nowhere else
                     (dolist (point '((31 32) (48 32) (32 31) (32 48) (0 0)))
                       (is (xna:color-equal background
                                            (funcall (after game)
                                                     (first point) (second point)))
                           "(~d,~d) is outside the destination and should still be ~
                            CornflowerBlue; it is ~a"
                           (first point) (second point)
                           (pixel-list (funcall (after game)
                                                (first point) (second point)))))
                     (note-rasterization
                      :render-target
                      "~a: a clear into a bound RenderTarget2D left the back buffer ~
                       untouched, and the target then drew onto the back buffer through ~
                       the texture path"
                      renderer)))))
           (values))
      (progn
        (when (rt game) (ignore-errors (xna:dispose (rt game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))
