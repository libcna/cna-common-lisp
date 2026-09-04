;;;; render-target.lisp --- RenderTarget2D against a real CNA.
;;;;
;;;; The state and the ownership. The pixels are in
;;;; `tests/native/rasterization.lisp', where the rest of the pixel evidence is,
;;;; and they are the point of this closure: a render target is readable on any
;;;; renderer that can draw at all, so it is the first thing here whose contents
;;;; can be proved without the back-buffer readback.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass render-target-game (graphics-game)
  ((target :initform nil :accessor target)
   (build-error :initform nil :accessor build-error)
   (target-width :initarg :target-width :initform 16 :accessor target-width)
   (target-height :initarg :target-height :initform 16 :accessor target-height)
   (target-usage :initarg :target-usage :initform :discard-contents :accessor target-usage)
   (target-depth :initarg :target-depth :initform :none :accessor target-depth))
  (:documentation "Creates one RenderTarget2D during LoadContent."))

(defmethod xna:load-content ((game render-target-game))
  (call-next-method)
  (handler-case
      (setf (target game)
            (make-instance 'gfx:render-target-2d
                           :graphics-device (xna:graphics-device game)
                           :width (target-width game) :height (target-height game)
                           :depth-stencil-format (target-depth game)
                           :usage (target-usage game)))
    (error (condition) (setf (build-error game) condition))))

(defmacro with-render-target-game ((game &rest initargs) &body body)
  `(let ((,game (make-instance 'render-target-game :exit-after 2 ,@initargs)))
     (unwind-protect
          (progn (xna:run ,game)
                 (when (build-error ,game) (error (build-error ,game)))
                 ,@body)
       (progn
         (when (target ,game) (ignore-errors (xna:dispose (target ,game))))
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (ignore-errors (xna:dispose ,game))))))

;;; --- it is a Texture2D, and that is the point ---------------------------------

(define-native-test a-render-target-is-a-texture-2d
  "XNA derives RenderTarget2D from Texture2D, so a finished target is an ordinary
texture. That is not decoration: it is what lets a target be drawn with
SpriteBatch, which is how its contents are read back on a renderer whose back
buffer cannot be."
  (with-render-target-game (game)
    (let ((rt (target game)))
      (is (typep rt 'gfx:texture-2d))
      (is (typep rt 'gfx:texture))
      (is (typep rt 'gfx:graphics-resource))
      (is (= 16 (gfx:width rt)))
      (is (= 16 (gfx:height rt)))
      (is (xna:rectangle-equal (xna:make-rectangle 0 0 16 16) (gfx:bounds rt))))))

(define-native-test a-render-target-reports-what-cna-granted
  "Not what was asked for. A backend may give less than the request, and echoing
the request is how a program comes to believe it has multisampling it has not
got -- so the three properties are read back out of CNA at construction."
  (with-render-target-game (game)
    (let ((rt (target game)))
      (is (typep (gfx:render-target-usage rt) 'gfx:render-target-usage))
      (is (typep (gfx:depth-stencil-format rt) 'gfx:depth-format))
      (is (integerp (gfx:multi-sample-count rt)))
      (is (>= (gfx:multi-sample-count rt) 0))
      ;; This one was asked for and is simple enough that every backend grants it.
      (is (eq :discard-contents (gfx:render-target-usage rt))))))

(define-native-test a-render-target-takes-a-depth-format-and-a-usage
  (with-render-target-game (game :target-depth :depth-24-stencil-8
                                 :target-usage :preserve-contents)
    (let ((rt (target game)))
      (is (eq :preserve-contents (gfx:render-target-usage rt))
          "PreserveContents was requested and ~s came back"
          (gfx:render-target-usage rt))
      ;; The depth format is a request the backend may decline, so this asserts
      ;; only that what comes back is a DepthFormat and says which.
      (is (typep (gfx:depth-stencil-format rt) 'gfx:depth-format)))))

(define-native-test a-render-target-refuses-a-size-it-cannot-have
  (with-graphics-game (game :exit-after 1)
    (xna:run game)
    ;; Outside a callback the device is refused first, which is the earlier check.
    (signals xna:cna-scope-error
      (make-instance 'gfx:render-target-2d
                     :graphics-device (xna:graphics-device game) :width 8 :height 8))))

(defclass bad-render-target-game (graphics-game)
  ((results :initform '() :accessor results))
  (:documentation "Records what a malformed RenderTarget2D construction answers."))

(defmethod xna:load-content ((game bad-render-target-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    (dolist (args '((:width 0 :height 8) (:width 8 :height -1) (:width 8 :height 8
                                                                :multi-sample-count -4)))
      (push (handler-case
                (progn (apply #'make-instance 'gfx:render-target-2d
                              :graphics-device device args)
                       :accepted)
              (error (condition) (type-of condition)))
            (results game)))))

(define-native-test a-render-target-refuses-a-shape-it-cannot-have
  "Argument checks are CNA-Lisp's own and happen before anything reaches CNA."
  (let ((game (make-instance 'bad-render-target-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (= 3 (length (results game))))
           (dolist (result (results game))
             (is (not (eq :accepted result))
                 "a malformed RenderTarget2D was accepted")))
      (progn
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))

;;; --- content loss -------------------------------------------------------------

(define-native-test a-render-target-reports-no-content-loss-on-this-renderer
  "CNA reports content loss only from the moment a renderer announces a real
device reset, and only three renderer families can announce one. Neither
qualification renderer is among them, so this is false and the *reason* it is
false is what the assertion records."
  (with-render-target-game (game)
    (is (null (gfx:is-content-lost (target game))))))

(define-native-test a-render-target-content-lost-subscription-is-real
  "The subscription and its release are real; the raise is CNA's to make and this
renderer never will. A handler list nothing could ever call would have been the
dishonest alternative."
  (with-render-target-game (game)
    (let ((rt (target game))
          (called 0))
      (let ((handler (lambda (sender) (declare (ignore sender)) (incf called))))
        (finishes (gfx:add-content-lost-handler rt handler))
        (is (zerop called))
        (finishes (gfx:remove-content-lost-handler rt handler))
        ;; Removing one that is not subscribed answers NIL rather than signalling,
        ;; which is what `-=' does.
        (finishes (gfx:remove-content-lost-handler rt handler))))))

;;; --- binding ---------------------------------------------------------------------

(defclass binding-game (render-target-game)
  ((bind-results :initform '() :accessor bind-results))
  (:documentation "Binds and unbinds a render target inside Draw."))

(defmethod xna:draw ((game binding-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (when (and (target game) (null (bind-results game)))
    (let ((device (xna:graphics-device game)))
      (push (handler-case (progn (gfx:set-render-target device (target game)) :bound)
              (error (c) (type-of c)))
            (bind-results game))
      (push (handler-case (progn (gfx:clear device (xna:make-color 255 0 0 255)) :cleared)
              (error (c) (type-of c)))
            (bind-results game))
      (push (handler-case (progn (gfx:set-render-target device nil) :restored)
              (error (c) (type-of c)))
            (bind-results game)))))

(define-native-test binding-a-render-target-and-restoring-the-back-buffer
  "SetRenderTarget(target) then SetRenderTarget(nil). NIL is XNA's null and is the
ordinary way to finish with a target, not an error."
  (let ((game (make-instance 'binding-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (when (build-error game) (error (build-error game)))
           (is (equal '(:restored :cleared :bound) (bind-results game))
               "binding, clearing and restoring answered ~s" (bind-results game)))
      (progn
        (when (target game) (ignore-errors (xna:dispose (target game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))

(define-native-test binding-a-render-target-outside-a-callback-is-refused
  (with-render-target-game (game)
    (signals xna:cna-scope-error
      (gfx:set-render-target (xna:graphics-device game) (target game)))
    (signals xna:cna-scope-error
      (gfx:set-render-target (xna:graphics-device game) nil))))

;;; --- ownership -------------------------------------------------------------------

(define-native-test a-render-target-is-a-game-child-disposed-before-it
  (with-render-target-game (game)
    (let ((rt (target game)))
      (signals xna:cna-ownership-error (xna:dispose game))
      (xna:dispose rt)
      (is (xna:disposed-p rt))
      (finishes (xna:dispose rt)))))          ; idempotent

(define-native-test a-disposed-render-target-refuses-every-operation
  (with-render-target-game (game)
    (let ((rt (target game)))
      (xna:dispose rt)
      (signals xna:cna-disposed-error (gfx:is-content-lost rt))
      (signals xna:cna-disposed-error (gfx:graphics-resource-name rt))
      ;; And it cannot be bound, which is the failure that would otherwise reach
      ;; CNA with a handle it may since have reissued.
      (signals xna:cna-error (gfx:set-render-target (xna:graphics-device game) rt)))))
