;;;; render-target-cube.lisp --- RenderTargetCube and RenderTargetBinding.
;;;;
;;;; **One renderer-dependent branch, and both sides are checked.** Creating a
;;;; cube render target works on every renderer measured; *binding* one does not.
;;;; HEADLESS accepts it, and SOFTWARE refuses with "this renderer does not
;;;; support RenderTargetCube" -- the exact inverse of the cube-face storage
;;;; asymmetry, where SOFTWARE has what HEADLESS lacks. So a test that only
;;;; accepted the refusal would pass against a HEADLESS run that had silently
;;;; stopped binding, and one that only accepted success could not run under
;;;; SOFTWARE at all.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass cube-target-game (graphics-game)
  ((cube-target :initform nil :accessor cube-target)
   (flat-target :initform nil :accessor flat-target)
   (build-error :initform nil :accessor build-error)
   (bind-error :initform nil :accessor bind-error)
   (observations :initform '() :accessor observations)
   (target-size :initarg :target-size :initform 32 :accessor target-size))
  (:documentation "Creates a RenderTargetCube and a RenderTarget2D, then binds."))

(defmethod xna:load-content ((game cube-target-game))
  (call-next-method)
  (handler-case
      (let ((device (xna:graphics-device game)))
        (setf (cube-target game)
              (make-instance 'gfx:render-target-cube
                             :graphics-device device :size (target-size game))
              (flat-target game)
              (make-instance 'gfx:render-target-2d
                             :graphics-device device :width 16 :height 16))
        (observe game :initial-targets (gfx:get-render-targets device))
        ;; Binding a cube is the renderer-dependent step; everything after it
        ;; must still run, so its failure is recorded rather than propagated.
        (handler-case
            (progn
              (gfx:set-render-target device (cube-target game) :positive-y)
              (observe game :cube-bound (gfx:get-render-targets device))
              (gfx:set-render-target device nil)
              (observe game :cube-unbound (gfx:get-render-targets device)))
          (error (condition) (setf (bind-error game) condition)))
        (gfx:set-render-targets device
                                (gfx:make-render-target-binding (flat-target game)))
        (observe game :flat-bound (gfx:get-render-targets device))
        (gfx:set-render-targets device)
        (observe game :all-unbound (gfx:get-render-targets device)))
    (error (condition) (setf (build-error game) condition))))

(defmacro with-cube-target-game ((game &rest initargs) &body body)
  `(let ((,game (make-instance 'cube-target-game :exit-after 2 ,@initargs)))
     (unwind-protect
          (progn (xna:run ,game)
                 (when (build-error ,game) (error (build-error ,game)))
                 ,@body)
       (progn
         (when (cube-target ,game) (ignore-errors (xna:dispose (cube-target ,game))))
         (when (flat-target ,game) (ignore-errors (xna:dispose (flat-target ,game))))
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (xna:dispose ,game)))))

;;; --- the type ----------------------------------------------------------------

(define-native-test a-render-target-cube-is-a-texture-cube
  "XNA derives RenderTargetCube from TextureCube, so a finished target is an
ordinary cube and not a wrapper around one."
  (with-cube-target-game (game)
    (let ((target (cube-target game)))
      (is (typep target 'gfx:texture-cube))
      (is (typep target 'gfx:texture))
      (is (not (typep target 'gfx:texture-2d))
          "a cube is not a Texture2D, any more than TextureCube is"))))

(define-native-test a-cube-target-reports-what-cna-granted-and-not-what-was-asked
  "Size, usage, depth format and sample count come back from
cna_render_target_get_info. A backend may grant less than was asked for, and
reporting the request would be how a program comes to believe it has
multisampling it has not got."
  (with-cube-target-game (game :target-size 32)
    (let ((target (cube-target game)))
      (is (= 32 (gfx:texture-cube-size target)))
      (is (typep (gfx:render-target-usage target) 'gfx:render-target-usage))
      (is (typep (gfx:depth-stencil-format target) 'gfx:depth-format))
      (is (integerp (gfx:multi-sample-count target)))
      (is (not (gfx:is-content-lost target))
          "a target that was never bound cannot have lost its contents"))))

(define-native-test a-cube-target-does-not-make-a-plain-cube-underneath-itself
  "RENDER-TARGET-CUBE inherits TEXTURE-CUBE's constructor, which would create a
plain cube first if the storage hook did not stop it -- the bug RENDER-TARGET-2D
already had. One native object, so one handle, and disposal is the target's own
route."
  (with-cube-target-game (game)
    (let ((cubes (remove-if-not (lambda (child) (typep child 'gfx:texture-cube))
                                (int:children-of game))))
      (is (= 1 (length cubes))
          "the game owns ~d cube(s); a second one is the plain cube the base ~
           class would have made" (length cubes))
      (is (eq (cube-target game) (first cubes))))))

;;; --- RenderTargetBinding, which is a value type ------------------------------

(define-native-test a-render-target-binding-is-a-value-and-checks-its-arguments
  "XNA derives RenderTargetBinding from System.ValueType, so it is a struct here.
Its two constructors take different things and neither accepts the other's: a
cube is bound one face at a time and a 2D target has no faces."
  (with-cube-target-game (game)
    (let ((binding (gfx:make-render-target-binding (cube-target game) :positive-z)))
      (is (gfx:render-target-binding-p binding))
      (is (eq (cube-target game) (gfx:render-target-binding-target binding)))
      (is (eq :positive-z (gfx:render-target-binding-cube-map-face binding)))
      (is (gfx:render-target-binding-equal
           binding (gfx:copy-render-target-binding binding))
          "a copy of a value must be equal to it"))
    (let ((flat (gfx:make-render-target-binding (flat-target game))))
      (is (null (gfx:render-target-binding-cube-map-face flat))))
    (signals xna:cna-argument-error
      (gfx:make-render-target-binding (cube-target game)))
    (signals xna:cna-argument-error
      (gfx:make-render-target-binding (flat-target game) :positive-x))))

;;; --- binding, and the renderer-dependent half --------------------------------

(define-native-test the-back-buffer-is-current-until-something-is-bound
  "GetRenderTargets answers an empty list for the back buffer, which is XNA's
empty array."
  (with-cube-target-game (game)
    (is (null (observed game :initial-targets)))))

(define-native-test set-render-targets-and-get-render-targets-round-trip
  "SetRenderTargets with one binding, then GetRenderTargets, then the empty call
that restores the back buffer. This is the RenderTarget2D path, which every
renderer measured supports."
  (with-cube-target-game (game)
    (let ((bound (observed game :flat-bound)))
      (is (= 1 (length bound)) "one target was bound and ~d came back" (length bound))
      (is (eq (flat-target game) (gfx:render-target-binding-target (first bound))))
      (is (null (gfx:render-target-binding-cube-map-face (first bound)))))
    (is (null (observed game :all-unbound))
        "SET-RENDER-TARGETS with no arguments is XNA's empty array and must ~
         restore the back buffer")))

(define-native-test binding-a-cube-face-works-or-says-the-renderer-cannot
  "The renderer-dependent one, with both branches checked.

HEADLESS binds a cube face and GetRenderTargets answers the target and the face.
SOFTWARE refuses with `this renderer does not support RenderTargetCube', which is
an honest answer and not a defect -- creating the target still worked, and the
refusal names the renderer's limit."
  (with-cube-target-game (game)
    (if (bind-error game)
        (progn
          (is (typep (bind-error game) 'xna:cna-error)
              "a renderer that cannot bind a cube must refuse with a CNA-ERROR, ~
               not with ~a" (type-of (bind-error game)))
          (is (search "RenderTargetCube" (princ-to-string (bind-error game)))
              "the refusal should name what is unsupported; it said ~a"
              (bind-error game)))
        (let ((bound (observed game :cube-bound)))
          (is (= 1 (length bound)) "one cube face was bound and ~d came back"
              (length bound))
          (is (eq (cube-target game) (gfx:render-target-binding-target (first bound))))
          (is (eq :positive-y (gfx:render-target-binding-cube-map-face (first bound)))
              "the bound face came back as ~a"
              (gfx:render-target-binding-cube-map-face (first bound)))
          (is (null (observed game :cube-unbound))
              "passing NIL must restore the back buffer, as SET-RENDER-TARGET's ~
               NIL does")))))
