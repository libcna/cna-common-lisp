;;;; graphics-resource.lisp --- the base class Texture2D and SpriteBatch share.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass resource-game (counting-game)
  ((texture :initform nil :accessor game-texture)
   (batch :initform nil :accessor game-batch)
   (observed-name :initform nil :accessor observed-name)
   (observed-disposed :initform :unset :accessor observed-disposed)
   (disposing-seen :initform 0 :accessor disposing-seen)))

(defmethod xna:load-content ((game resource-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    (setf (game-batch game) (make-instance 'gfx:sprite-batch :graphics-device device)
          (game-texture game) (gfx:texture-2d-from-png-file
                               device (fixture-path "cna-lisp-mark.png"))))
  (setf (gfx:graphics-resource-name (game-texture game)) "the logo")
  (setf (observed-name game) (gfx:graphics-resource-name (game-texture game))
        (observed-disposed game) (gfx:graphics-resource-is-disposed (game-texture game)))
  (gfx:add-disposing-handler
   (game-texture game)
   (lambda (sender) (declare (ignore sender)) (incf (disposing-seen game)))))

(defmacro with-resource-game ((variable &rest initargs) &body body)
  "Children first, then the game: CNA refuses the other order and CNA-Lisp does
not cascade on the program's behalf."
  `(let ((,variable (make-instance 'resource-game ,@initargs)))
     (unwind-protect (progn ,@body)
       (progn
         (when (game-batch ,variable) (ignore-errors (xna:dispose (game-batch ,variable))))
         (when (game-texture ,variable)
           (ignore-errors (xna:dispose (game-texture ,variable))))
         (ignore-errors (xna:dispose ,variable))))))

(define-native-test a-texture-and-a-sprite-batch-are-graphics-resources
  (with-resource-game (game :exit-after 2)
    (xna:run game)
    (is (typep (game-texture game) 'gfx:graphics-resource))
    (is (typep (game-batch game) 'gfx:graphics-resource))
    (is (string= "the logo" (observed-name game))
        "the name round-trips through CNA")
    (is (eq nil (observed-disposed game))
        "and a live resource reports not disposed")))

(define-native-test the-disposing-event-is-raised-while-the-resource-is-disposed
  (let ((game nil))
    (with-resource-game (created :exit-after 2)
      (setf game created)
      (xna:run created)
      (is (= 0 (disposing-seen created)) "not raised while the resource is alive"))
    (is (= 1 (disposing-seen game))
        "raised once, inside the resource's own disposal")))

(define-native-test a-resource-reports-disposed-after-it-is-disposed
  (let ((texture nil))
    (with-resource-game (game :exit-after 2)
      (xna:run game)
      (setf texture (game-texture game))
      (is (not (gfx:graphics-resource-is-disposed texture)))
      (xna:dispose texture)
      (setf (game-texture game) nil)
      (is (gfx:graphics-resource-is-disposed texture)
          "IsDisposed answers the same question DISPOSED-P does")
      (is (xna:disposed-p texture)))))

(define-native-test a-resource-tag-holds-any-lisp-object
  ;; XNA's Tag is System.Object, arbitrary consumer data the framework never
  ;; reads. CNA's is a uint64 token that could only carry a pointer to a moving
  ;; Lisp object, so the tag lives on the Lisp side. See the file header of
  ;; src/graphics/graphics-resource.lisp.
  (with-resource-game (game :exit-after 2)
    (xna:run game)
    (let ((texture (game-texture game)))
      (is (null (gfx:tag texture)) "the default tag is NIL")
      (setf (gfx:tag texture) (list :anything "at" 'all))
      (is (equal (list :anything "at" 'all) (gfx:tag texture))))))

(define-native-test a-resource-answers-the-games-device
  (with-resource-game (game :exit-after 2)
    (xna:run game)
    (is (eq (xna:graphics-device game)
            (gfx:graphics-resource-graphics-device (game-texture game)))
        "there is one device, and one object for it")))
