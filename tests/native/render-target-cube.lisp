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
      ;; **XNA's answer, and it is a stored value rather than a default.**
      ;; RenderTargetBinding(RenderTarget2D) is `ldc.i4.0; stfld _cubeMapFace',
      ;; so the property answers CubeMapFace.PositiveX for a 2D binding. This
      ;; answered NIL until the frontier audit measured that NIL was a binding
      ;; preference and not a projection limit.
      (is (eq :positive-x (gfx:render-target-binding-cube-map-face flat))
          "a 2D binding answers XNA's PositiveX, not NIL; it answered ~a"
          (gfx:render-target-binding-cube-map-face flat))
      ;; And the face is not what tells the two kinds apart -- the target is,
      ;; in XNA as here. A cube binding of the same face is a different value.
      (let ((cube (gfx:make-render-target-binding (cube-target game) :positive-x)))
        (is (eq :positive-x (gfx:render-target-binding-cube-map-face cube)))
        (is (not (gfx:render-target-binding-equal flat cube))
            "same face, different targets: these are not the same binding")
        (is (typep (gfx:render-target-binding-target cube) 'gfx:render-target-cube))
        (is (not (typep (gfx:render-target-binding-target flat)
                        'gfx:render-target-cube))
            "which target it names is how a program tells a cube binding from a ~
             flat one, now that both answer a face"))
      (is (gfx:render-target-binding-equal
           flat (gfx:make-render-target-binding (flat-target game)))
          "two bindings of the same 2D target are the same value"))
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
      (is (eq :positive-x (gfx:render-target-binding-cube-map-face (first bound)))
          "a 2D binding read back from the device answers PositiveX, which is ~
           both XNA's answer and what CNA reports for a 2D target"))
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

;;; --- what the cross-check actually cross-checks ------------------------------
;;;
;;; GetRenderTargets answers the RENDER-TARGET-BINDING values this binding
;;; recorded, because CNA answers handles and the ABI has no route from a handle
;;; back to the object that owns it. That makes the cross-check the only thing
;;; standing between the record and a plausible answer that is wrong, so it has to
;;; be shown to catch each way the record can be wrong -- not merely to agree with
;;; itself on the happy path.
;;;
;;; The mutation is applied to the *record*, which is the half that can drift.
;;; CNA is left alone: the device really is bound to what it is bound to, and the
;;; question is whether a record that no longer describes it is noticed.

(defclass binding-cross-check-game (graphics-game)
  ((flat-a :initform nil :accessor flat-a)
   (flat-b :initform nil :accessor flat-b)
   (cube :initform nil :accessor cross-check-cube)
   (results :initform '() :accessor cross-check-results)
   (mrt-error :initform nil :accessor mrt-error)
   (cube-bind-error :initform nil :accessor cube-bind-error)
   (build-error :initform nil :accessor cross-check-build-error))
  (:documentation
   "Binds real targets, corrupts the remembered record, and records what
GetRenderTargets did about it."))

(defun %record-cross-check (game label device mutate)
  "Apply MUTATE to the remembered record, ask, and put the record back."
  (let ((saved (gfx::%bound-render-targets device))
        (outcome :accepted))
    (unwind-protect
         (progn
           (setf (gfx::%bound-render-targets device)
                 (funcall mutate (copy-list saved)))
           (handler-case (gfx:get-render-targets device)
             (xna:cna-internal-error () (setf outcome :refused))
             (error (condition) (setf outcome (type-of condition)))))
      (setf (gfx::%bound-render-targets device) saved))
    (push (cons label outcome) (cross-check-results game))
    outcome))

(defmethod xna:load-content ((game binding-cross-check-game))
  (call-next-method)
  (handler-case
      (let ((device (xna:graphics-device game)))
        (setf (flat-a game) (make-instance 'gfx:render-target-2d
                                           :graphics-device device :width 16 :height 16)
              (flat-b game) (make-instance 'gfx:render-target-2d
                                           :graphics-device device :width 16 :height 16)
              (cross-check-cube game) (make-instance 'gfx:render-target-cube
                                                     :graphics-device device :size 16))
        ;; One 2D target bound for real.
        (gfx:set-render-targets device (gfx:make-render-target-binding (flat-a game)))
        (%record-cross-check
         game :unmutated device #'identity)
        ;; A face the device does not have. A 2D binding's face is positive X
        ;; -- XNA's constructor stores it and CNA reports it, "meaningless for a
        ;; 2D target and must then be positive X" -- so a record claiming any
        ;; other face does not describe the device, on every renderer. Built
        ;; through the *private* constructor because the public one refuses a
        ;; face for a 2D target, which is XNA's shape and stays that way.
        (%record-cross-check
         game :wrong-face device
         (lambda (record)
           (declare (ignore record))
           (list (gfx::%make-render-target-binding (flat-a game) :negative-x))))
        ;; A record with one binding too many.
        (%record-cross-check
         game :too-many device
         (lambda (record)
           (append record (list (gfx:make-render-target-binding (flat-b game))))))
        ;; A record with none at all, while one is bound.
        (%record-cross-check game :too-few device
                             (lambda (record) (declare (ignore record)) '()))
        ;; A record naming a live target that is not the bound one.
        (%record-cross-check
         game :stale-target device
         (lambda (record)
           (declare (ignore record))
           (list (gfx:make-render-target-binding (flat-b game)))))
        ;; Two targets at once, if the renderer does multiple render targets, so
        ;; that a swapped pair has something to be swapped.
        (handler-case
            (progn
              (gfx:set-render-targets device
                                      (gfx:make-render-target-binding (flat-a game))
                                      (gfx:make-render-target-binding (flat-b game)))
              (%record-cross-check game :two-unmutated device #'identity)
              (%record-cross-check game :swapped device #'reverse))
          (error (condition) (setf (mrt-error game) condition)))
        (gfx:set-render-targets device)
        ;; And a cube face, on a renderer that binds one: there the face is the
        ;; half of the binding's identity the handle does not carry at all.
        (handler-case
            (progn
              (gfx:set-render-target device (cross-check-cube game) :positive-y)
              (%record-cross-check game :cube-unmutated device #'identity)
              (%record-cross-check
               game :cube-wrong-face device
               (lambda (record)
                 (declare (ignore record))
                 (list (gfx::%make-render-target-binding (cross-check-cube game)
                                                         :negative-z))))
              (gfx:set-render-target device nil))
          (error (condition) (setf (cube-bind-error game) condition)))
        (gfx:set-render-targets device))
    (error (condition) (setf (cross-check-build-error game) condition))))

(defun %cross-check-outcome (game label)
  (cdr (assoc label (cross-check-results game))))

(define-native-test the-render-target-cross-check-catches-a-record-that-drifted
  "Four ways a record can stop describing the device, and each one is refused."
  (let ((game (make-instance 'binding-cross-check-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (cross-check-build-error game))
               "the fixture failed: ~a" (cross-check-build-error game))
           (is (eq :accepted (%cross-check-outcome game :unmutated))
               "an untouched record was refused as ~a; every assertion below ~
                would then pass for the wrong reason"
               (%cross-check-outcome game :unmutated))
           (dolist (label '(:wrong-face :too-many :too-few :stale-target))
             (is (eq :refused (%cross-check-outcome game label))
                 "~a was answered as ~a rather than refused"
                 label (%cross-check-outcome game label)))
           ;; The two renderer-dependent halves. Each is checked when its
           ;; renderer offers it, and its absence is stated rather than passed
           ;; over -- a branch that silently did nothing would prove nothing.
           (if (mrt-error game)
               (is (typep (mrt-error game) 'xna:cna-error)
                   "a renderer that cannot bind two targets must refuse with a ~
                    CNA-ERROR, not with ~a" (type-of (mrt-error game)))
               (progn
                 (is (eq :accepted (%cross-check-outcome game :two-unmutated)))
                 (is (eq :refused (%cross-check-outcome game :swapped))
                     "a swapped pair was answered as ~a; the handles are both ~
                      still there, so only their order says anything"
                     (%cross-check-outcome game :swapped))))
           (if (cube-bind-error game)
               (is (typep (cube-bind-error game) 'xna:cna-error)
                   "a renderer that cannot bind a cube must refuse with a ~
                    CNA-ERROR, not with ~a" (type-of (cube-bind-error game)))
               (progn
                 (is (eq :accepted (%cross-check-outcome game :cube-unmutated)))
                 (is (eq :refused (%cross-check-outcome game :cube-wrong-face))
                     "a cube binding with the wrong face was answered as ~a; ~
                      the target handle is the same either way, so the face is ~
                      the only thing that distinguishes them"
                     (%cross-check-outcome game :cube-wrong-face)))))
      (progn
        (when (flat-a game) (ignore-errors (xna:dispose (flat-a game))))
        (when (flat-b game) (ignore-errors (xna:dispose (flat-b game))))
        (when (cross-check-cube game)
          (ignore-errors (xna:dispose (cross-check-cube game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))
