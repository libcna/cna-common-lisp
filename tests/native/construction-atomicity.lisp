;;;; construction-atomicity.lisp --- a subclass's initializer is part of the
;;;; construction, and a failing one must leave nothing behind.
;;;;
;;;; The earlier failure-atomicity work looked at native create/destroy pairs
;;;; *inside* individual functions. That is not enough for CLOS, and the reason is
;;;; the method combination rather than anything about CNA.
;;;;
;;;; A native-backed class takes its handle in an `initialize-instance :after'
;;;; method. CLOS runs `:after' methods **least-specific-first**, so the last
;;;; initializer to run is the most derived one -- a consumer's. By then the
;;;; handle exists, the object is registered as a child of its owner, and the
;;;; base class's own `unwind-protect' has already returned. A subclass
;;;; initializer that signals therefore left CNA holding a resource the caller
;;;; never received, and nothing that could ever dispose it.
;;;;
;;;; **Every class here is subclassable.** Common Lisp has no `sealed', so this is
;;;; not a hypothetical for some of them and impossible for others: it applies to
;;;; every exported native-backed class, which is why the remedy is one
;;;; `initialize-instance :around' on the private base rather than one per class.
;;;;
;;;; Each test below builds a subclass whose `:after' signals, and then asserts
;;;; four things, of which the last is the one that used to fail:
;;;;
;;;;   * the caller sees the subclass's own condition, not a rollback's;
;;;;   * the owner is left owning no live child of that type;
;;;;   * the callback registry is the size it was;
;;;;   * **the game shuts down**, which it cannot do while a child handle lives.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(define-condition subclass-initializer-blew-up (error) ()
  (:report (lambda (condition stream)
             (declare (ignore condition))
             (format stream "boom, from a subclass initializer"))))

(defmacro define-exploding-subclass (name base)
  "A subclass of BASE whose own initializer signals, and nothing else.

Deliberately the most ordinary thing a consumer can write: no slots, no initargs,
one `:after' method that fails. The base class's initializer has completed by the
time this runs, which is the whole point."
  `(progn
     (defclass ,name (,base) ())
     (defmethod initialize-instance :after ((object ,name) &key)
       (declare (ignore object))
       (error 'subclass-initializer-blew-up))))

(define-exploding-subclass exploding-sprite-batch gfx:sprite-batch)
(define-exploding-subclass exploding-texture-2d gfx:texture-2d)
(define-exploding-subclass exploding-texture-cube gfx:texture-cube)
(define-exploding-subclass exploding-render-target-2d gfx:render-target-2d)
(define-exploding-subclass exploding-render-target-cube gfx:render-target-cube)
(define-exploding-subclass exploding-vertex-buffer gfx:vertex-buffer)
(define-exploding-subclass exploding-dynamic-vertex-buffer gfx:dynamic-vertex-buffer)
(define-exploding-subclass exploding-index-buffer gfx:index-buffer)
(define-exploding-subclass exploding-dynamic-index-buffer gfx:dynamic-index-buffer)
(define-exploding-subclass exploding-basic-effect gfx:basic-effect)
(define-exploding-subclass exploding-alpha-test-effect gfx:alpha-test-effect)
(define-exploding-subclass exploding-content-manager xna.content:content-manager)
(define-exploding-subclass exploding-graphics-device-manager xna:graphics-device-manager)
;; The caller-owned device. Its exploding subclass lives here with the others
;; rather than beside its own tests, so that the one table of families this file
;; keeps stays the one table -- and it is exercised from
;; tests/native/owned-graphics-device.lisp, which is where a device that needs no
;; game can be constructed.
(define-exploding-subclass exploding-graphics-device gfx:graphics-device)

(defun %exploding-constructions (device)
  "Every (LABEL CLASS . INITARGS) this file builds, against DEVICE.

One table rather than one test each, because the claim is the same for all of
them and a family left out of a list is easier to notice than a test that was
never written. The base class each entry explodes from is named in the label."
  (let ((declaration (gfx:vertex-position-color-vertex-declaration)))
    (list
     (list "SpriteBatch" 'exploding-sprite-batch :graphics-device device)
     (list "Texture2D" 'exploding-texture-2d
           :graphics-device device :width 8 :height 8)
     (list "TextureCube" 'exploding-texture-cube :graphics-device device :size 8)
     (list "RenderTarget2D" 'exploding-render-target-2d
           :graphics-device device :width 8 :height 8)
     (list "RenderTargetCube" 'exploding-render-target-cube
           :graphics-device device :size 8)
     (list "VertexBuffer" 'exploding-vertex-buffer
           :graphics-device device :vertex-declaration declaration :vertex-count 3)
     (list "DynamicVertexBuffer" 'exploding-dynamic-vertex-buffer
           :graphics-device device :vertex-declaration declaration :vertex-count 3)
     (list "IndexBuffer" 'exploding-index-buffer
           :graphics-device device :index-element-size :sixteen-bits :index-count 6)
     (list "DynamicIndexBuffer" 'exploding-dynamic-index-buffer
           :graphics-device device :index-element-size :sixteen-bits :index-count 6)
     (list "BasicEffect" 'exploding-basic-effect :graphics-device device)
     (list "AlphaTestEffect" 'exploding-alpha-test-effect :graphics-device device)
     (list "ContentManager" 'exploding-content-manager :graphics-device device))))

(defclass exploding-construction-game (graphics-game)
  ((findings :initform '() :accessor findings))
  (:documentation
   "Builds every exploding subclass inside LoadContent and records what happened.

Inside a callback because that is the only place CNA lends a graphics device.
Nothing is asserted here: an assertion is a condition, and a condition crossing
the C frame would be a different failure than the one being measured."))

(defun %live-children-of-type (game type)
  (count-if (lambda (child)
              (and (typep child type) (not (xna:disposed-p child))))
            (int:children-of game)))

(defmethod xna:load-content ((game exploding-construction-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    (dolist (entry (%exploding-constructions device))
      (destructuring-bind (label class . initargs) entry
        (let ((base (find-class class))
              (registry-before (int:callback-registry-count))
              (outcome :no-condition)
              (condition nil))
          (let* ((parent (first (sb-mop:class-direct-superclasses base)))
                 (type (class-name parent))
                 (before (%live-children-of-type game type)))
            (handler-case (apply #'make-instance class initargs)
              (subclass-initializer-blew-up (c)
                (setf outcome :exploded condition c))
              (error (c)
                ;; A renderer that refuses the resource outright never reaches
                ;; the subclass initializer; that is a different fact and is
                ;; recorded as one rather than counted as a pass.
                (setf outcome :refused-by-cna condition c)))
            (push (list label type outcome
                        before (%live-children-of-type game type)
                        registry-before (int:callback-registry-count)
                        (and condition (type-of condition)))
                  (findings game))))))
    (setf (findings game) (nreverse (findings game)))))

(define-native-test a-subclass-initializer-that-signals-leaves-nothing-behind
  "Twelve resource families, one ordinary consumer mistake, and no leak.

The teardown is the assertion that used to fail: CNA refuses to destroy a game
while any child handle is alive, so a single leaked resource makes DISPOSE signal
-- far from the MAKE-INSTANCE that leaked it, which is exactly how this class of
bug announces itself."
  (let ((game (make-instance 'exploding-construction-game :exit-after 2))
        (teardown-error nil))
    (unwind-protect
         (progn
           (xna:run game)
           (is (= 12 (length (findings game)))
               "the table built ~d families" (length (findings game)))
           (dolist (finding (findings game))
             (destructuring-bind (label type outcome before after
                                  registry-before registry-after condition-type)
                 finding
               (declare (ignore type))
               (is (member outcome '(:exploded :refused-by-cna))
                   "~a: the subclass initializer did not signal at all" label)
               (when (eq outcome :exploded)
                 (is (eq 'subclass-initializer-blew-up condition-type)
                     "~a: the caller saw ~a rather than the subclass's own condition"
                     label condition-type))
               (is (= before after)
                   "~a: the owner was left with ~d live child/children it never handed out"
                   label (- after before))
               (is (= registry-before registry-after)
                   "~a: the callback registry moved by ~d"
                   label (- registry-after registry-before)))))
      (progn
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (handler-case (xna:dispose game)
          (error (condition) (setf teardown-error condition)))
        (is (null teardown-error)
            "the game would not shut down after the failed constructions: ~a"
            teardown-error)))))

;;; --- Game itself, which is the one every consumer subclasses ----------------

(define-exploding-subclass exploding-game counting-game)

(define-native-test a-game-subclass-that-signals-leaves-no-live-native-game
  "The family this matters most for: a program's own Game class.

CNA allows exactly one live game per process, so a native game left behind by a
failed construction does not merely leak -- it makes every later game in the
image impossible. The proof is that the next one is not."
  (let ((registry-before (int:callback-registry-count)))
    (signals subclass-initializer-blew-up (make-instance 'exploding-game))
    (is (null (int:active-game))
        "a failed Game construction left ~a as the process's active game"
        (int:active-game))
    (is (= registry-before (int:callback-registry-count))
        "a failed Game construction left ~d callback registry entry/entries behind"
        (- (int:callback-registry-count) registry-before))
    ;; The evidence that the *native* game went back: a second one can be made.
    (let ((game (make-instance 'counting-game :exit-after 1)))
      (unwind-protect
           (progn (xna:run game)
                  (is (= 1 (updates game))))
        (xna:dispose game)))
    (is (= registry-before (int:callback-registry-count)))))

;;; --- GraphicsDeviceManager, which is constructed against a live game --------

(define-native-test a-manager-subclass-that-signals-leaves-nothing-behind
  "GraphicsDeviceManager is made against the game rather than the device, so its
construction is outside a callback and gets its own test. XNA's constructor
refuses a second manager on one game, and so does this -- which means a leaked
one would make the *next* manager impossible, and that is what is checked."
  (let ((game (make-instance 'counting-game :exit-after 1))
        (teardown-error nil))
    (unwind-protect
         (let ((registry-before (int:callback-registry-count)))
           (signals subclass-initializer-blew-up
             (make-instance 'exploding-graphics-device-manager :game game))
           (is (= 0 (%live-children-of-type game 'xna:graphics-device-manager))
               "the game was left owning a manager it never handed out")
           (is (= registry-before (int:callback-registry-count)))
           ;; XNA refuses a second manager on one game, so this succeeding is
           ;; evidence that the first one really did go away.
           (let ((manager (make-instance 'xna:graphics-device-manager :game game)))
             (is (typep manager 'xna:graphics-device-manager))
             (xna:dispose manager)))
      (progn
        (handler-case (xna:dispose game)
          (error (condition) (setf teardown-error condition)))
        (is (null teardown-error)
            "the game would not shut down: ~a" teardown-error)))))
