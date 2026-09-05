;;;; buffers.lisp --- vertex and index buffers against the real CNA C ABI.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass buffer-game (graphics-game)
  ((body :initarg :body :initform nil :accessor body)
   (body-error :initform nil :accessor body-error)
   (body-ran :initform nil :accessor body-ran)
   (created :initform '() :accessor created))
  (:documentation "Runs one closure inside DRAW, where the device is lent."))

(defmethod xna:draw ((game buffer-game) game-time)
  (declare (ignore game-time))
  (incf (draws game))
  (unless (body-ran game)
    (setf (body-ran game) t)
    (handler-case (funcall (body game) game)
      (error (condition) (setf (body-error game) condition)))))

(defun keep (game object)
  "Remember OBJECT so the fixture disposes it before the game, as CNA requires."
  (push object (created game))
  object)

(defmacro with-buffer-game ((game) &body body)
  `(let ((,game (make-instance 'buffer-game
                               :exit-after 2
                               :body (lambda (,game) ,@body))))
     (unwind-protect
          (progn
            (xna:run ,game)
            (is (body-ran ,game) "the device body never ran")
            (when (body-error ,game) (error (body-error ,game))))
       (progn
         (dolist (object (created ,game)) (ignore-errors (xna:dispose object)))
         (when (batch ,game) (ignore-errors (xna:dispose (batch ,game))))
         (when (texture ,game) (ignore-errors (xna:dispose (texture ,game))))
         (when (manager ,game) (ignore-errors (xna:dispose (manager ,game))))
         (ignore-errors (xna:dispose ,game))))))

(defun triangle-vertices ()
  "Three VertexPositionColor vertices, in a fixed order."
  (vector (gfx:make-vertex-position-color (v3 -0.5 -0.5 0) (xna:make-color 255 0 0 255))
          (gfx:make-vertex-position-color (v3 0.5 -0.5 0) (xna:make-color 0 255 0 255))
          (gfx:make-vertex-position-color (v3 0 0.5 0) (xna:make-color 0 0 255 255))))

;;; --- construction ------------------------------------------------------------------

(define-native-test a-vertex-buffer-reports-what-it-was-made-with
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (declaration (gfx:vertex-position-color-vertex-declaration))
           (buffer (keep game (make-instance 'gfx:vertex-buffer
                                             :graphics-device device
                                             :vertex-declaration declaration
                                             :vertex-count 3
                                             :buffer-usage :none))))
      (is (= 3 (gfx:vertex-count buffer)))
      (is (eq declaration (gfx:vertex-declaration buffer))
          "the buffer must answer the declaration object it was given")
      (is (eq :none (gfx:buffer-usage buffer)))
      ;; It is a GraphicsResource, with the whole inherited surface.
      (is (typep buffer 'gfx:graphics-resource))
      (is (null (gfx:graphics-resource-is-disposed buffer)))
      (setf (gfx:graphics-resource-name buffer) "the triangle")
      (is (equal "the triangle" (gfx:graphics-resource-name buffer))))))

(define-native-test a-vertex-buffer-finds-its-declaration-through-ivertextype
  ;; XNA's other constructor takes a Type and looks the declaration up through
  ;; IVertexType. :VERTEX-TYPE is that, and it must find the same declaration.
  (with-buffer-game (game)
    (let ((buffer (keep game (make-instance 'gfx:vertex-buffer
                                            :graphics-device (xna:graphics-device game)
                                            :vertex-type 'gfx:vertex-position-color
                                            :vertex-count 3))))
      (is (eq (gfx:vertex-position-color-vertex-declaration)
              (gfx:vertex-declaration buffer))))))

(define-native-test a-vertex-buffer-refuses-a-layout-it-cannot-find
  (with-buffer-game (game)
    (let ((device (xna:graphics-device game)))
      (signals xna:cna-usage-error
        (make-instance 'gfx:vertex-buffer :graphics-device device :vertex-count 3))
      (signals xna:cna-usage-error
        (make-instance 'gfx:vertex-buffer :graphics-device device :vertex-count 3
                       :vertex-type 'cons))
      (signals xna:cna-usage-error
        (make-instance 'gfx:vertex-buffer :graphics-device device :vertex-count 3
                       :vertex-type 'gfx:vertex-position-color
                       :vertex-declaration (gfx:vertex-position-color-vertex-declaration))))))

(define-native-test an-index-buffer-reports-what-it-was-made-with
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (sixteen (keep game (make-instance 'gfx:index-buffer
                                              :graphics-device device
                                              :index-element-size :sixteen-bits
                                              :index-count 6)))
           (thirty-two (keep game (make-instance 'gfx:index-buffer
                                                 :graphics-device device
                                                 :index-type '(unsigned-byte 32)
                                                 :index-count 6))))
      (is (= 6 (gfx:index-count sixteen)))
      (is (eq :sixteen-bits (gfx:index-element-size sixteen)))
      (is (eq :thirty-two-bits (gfx:index-element-size thirty-two))
          "the Type constructor's (unsigned-byte 32) is XNA's typeof(int)")
      (signals xna:cna-usage-error
        (make-instance 'gfx:index-buffer :graphics-device device :index-count 6
                       :index-type 'single-float)))))

;;; --- data round trips ----------------------------------------------------------------

(define-native-test a-vertex-buffer-round-trips-standard-vertices
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (vertices (triangle-vertices))
           (buffer (keep game (make-instance 'gfx:vertex-buffer
                                             :graphics-device device
                                             :vertex-type 'gfx:vertex-position-color
                                             :vertex-count 3))))
      (gfx:set-data buffer vertices)
      (let ((back (make-array 3 :initial-element
                              (gfx:make-vertex-position-color (v3 0 0 0) (xna:white)))))
        (gfx:get-data buffer back)
        (dotimes (index 3)
          (is (gfx:vertex-position-color-equal (aref vertices index) (aref back index))
              "vertex ~d did not survive the round trip" index))))))

(define-native-test a-vertex-buffer-round-trips-a-window
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (vertices (triangle-vertices))
           (buffer (keep game (make-instance 'gfx:vertex-buffer
                                             :graphics-device device
                                             :vertex-type 'gfx:vertex-position-color
                                             :vertex-count 3))))
      (gfx:set-data buffer vertices)
      ;; One vertex, from the middle of the buffer, into the middle of an array.
      (let ((back (make-array 3 :initial-element
                              (gfx:make-vertex-position-color (v3 0 0 0) (xna:white)))))
        (gfx:get-data buffer back :start-index 1 :element-count 1
                                  :offset-in-bytes 16)
        (is (gfx:vertex-position-color-equal (aref vertices 1) (aref back 1))
            "the second vertex, read from byte 16, is not the second vertex")))))

(define-native-test an-index-buffer-round-trips-both-widths
  (with-buffer-game (game)
    (let ((device (xna:graphics-device game)))
      (dolist (row (list (list :sixteen-bits '(unsigned-byte 16))
                         (list :thirty-two-bits '(unsigned-byte 32))))
        (destructuring-bind (size element-type) row
          (let ((buffer (keep game (make-instance 'gfx:index-buffer
                                                  :graphics-device device
                                                  :index-element-size size
                                                  :index-count 6)))
                (indices (make-array 6 :element-type element-type
                                       :initial-contents '(0 1 2 2 1 0))))
            (gfx:set-data buffer indices)
            (let ((back (make-array 6 :element-type element-type :initial-element 0)))
              (gfx:get-data buffer back)
              (is (equalp indices back)
                  "~a indices did not survive the round trip" size))))))))

(define-native-test an-index-array-of-the-wrong-width-is-refused
  ;; Reinterpreting sixteen-bit numbers as thirty-two-bit ones would change every
  ;; index, and CNA's transfer names the width it is given.
  (with-buffer-game (game)
    (let ((buffer (keep game (make-instance 'gfx:index-buffer
                                            :graphics-device (xna:graphics-device game)
                                            :index-element-size :sixteen-bits
                                            :index-count 3))))
      (signals xna:cna-usage-error
        (gfx:set-data buffer (make-array 3 :element-type '(unsigned-byte 32)
                                           :initial-element 0))))))

(define-native-test a-transfer-refuses-a-shape-xna-does-not-have
  (with-buffer-game (game)
    (let ((buffer (keep game (make-instance 'gfx:vertex-buffer
                                            :graphics-device (xna:graphics-device game)
                                            :vertex-type 'gfx:vertex-position-color
                                            :vertex-count 3))))
      ;; :START-INDEX and :ELEMENT-COUNT are one group.
      (signals xna:cna-usage-error
        (gfx:set-data buffer (triangle-vertices) :start-index 0))
      (signals xna:cna-usage-error
        (gfx:set-data buffer (triangle-vertices) :element-count 1))
      ;; :VERTEX-STRIDE belongs to the overload that also takes :OFFSET-IN-BYTES.
      (signals xna:cna-usage-error
        (gfx:set-data buffer (triangle-vertices) :vertex-stride 16))
      ;; :OPTIONS is the dynamic subclass's.
      (signals xna:cna-usage-error
        (gfx:set-data buffer (triangle-vertices) :options :discard))
      ;; And an element type with no proven layout is refused before anything is
      ;; written into native memory.
      (signals xna:cna-usage-error (gfx:set-data buffer (vector "not a vertex"))))))

(define-native-test a-disposed-buffer-refuses-every-operation
  (with-buffer-game (game)
    (let ((buffer (make-instance 'gfx:vertex-buffer
                                 :graphics-device (xna:graphics-device game)
                                 :vertex-type 'gfx:vertex-position-color
                                 :vertex-count 3)))
      (xna:dispose buffer)
      (is (eq t (xna:disposed-p buffer)))
      (signals xna:cna-disposed-error (gfx:set-data buffer (triangle-vertices)))
      (signals xna:cna-disposed-error
        (gfx:get-data buffer (make-array 3 :initial-element
                                         (gfx:make-vertex-position-color
                                          (v3 0 0 0) (xna:white))))))))

;;; --- the dynamic subclasses -----------------------------------------------------------

(define-native-test a-dynamic-buffer-takes-the-options-overload
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (buffer (keep game (make-instance 'gfx:dynamic-vertex-buffer
                                             :graphics-device device
                                             :vertex-type 'gfx:vertex-position-color
                                             :vertex-count 3
                                             :buffer-usage :write-only))))
      (is (typep buffer 'gfx:vertex-buffer)
          "DynamicVertexBuffer's contract base is VertexBuffer")
      (finishes (gfx:set-data buffer (triangle-vertices)
                              :start-index 0 :element-count 3 :options :discard))
      (finishes (gfx:set-data buffer (triangle-vertices)
                              :start-index 0 :element-count 3 :options :no-overwrite)))))

(define-native-test cna-never-reports-content-loss
  ;; The member is a real read of CNA's own field, not a literal. CNA documents
  ;; that field as currently always false, so this pins today's answer -- and a
  ;; CNA that starts reporting loss makes this fail and say so.
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (vertex (keep game (make-instance 'gfx:dynamic-vertex-buffer
                                             :graphics-device device
                                             :vertex-type 'gfx:vertex-position-color
                                             :vertex-count 3)))
           (index (keep game (make-instance 'gfx:dynamic-index-buffer
                                            :graphics-device device
                                            :index-element-size :sixteen-bits
                                            :index-count 3))))
      (is (null (gfx:is-content-lost vertex))
          "CNA reported content loss; the limitation in docs/limitations.md is out ~
           of date and this test should be replaced by one that exercises it")
      (is (null (gfx:is-content-lost index)))
      ;; A subscription is accepted, held and released even though nothing raises
      ;; it, which is what makes the release path testable at all.
      (let ((handler (lambda (buffer) (declare (ignore buffer)) nil)))
        (finishes (gfx:add-content-lost-handler vertex handler))
        (is (gfx:remove-content-lost-handler vertex handler))))))

;;; --- the device's buffer state ---------------------------------------------------------

(define-native-test the-device-remembers-what-was-bound
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (buffer (keep game (make-instance 'gfx:vertex-buffer
                                             :graphics-device device
                                             :vertex-type 'gfx:vertex-position-color
                                             :vertex-count 3)))
           (indices (keep game (make-instance 'gfx:index-buffer
                                              :graphics-device device
                                              :index-element-size :sixteen-bits
                                              :index-count 3))))
      (is (null (gfx:get-vertex-buffers device)))
      (is (null (gfx:indices device)))
      (gfx:set-vertex-buffer device buffer)
      (let ((bound (gfx:get-vertex-buffers device)))
        (is (= 1 (length bound)))
        (is (eq buffer (gfx:vertex-buffer-binding-vertex-buffer (first bound))))
        (is (= 0 (gfx:vertex-buffer-binding-vertex-offset (first bound)))))
      (setf (gfx:indices device) indices)
      (is (eq indices (gfx:indices device)))
      ;; NIL unbinds, as XNA's null does.
      (gfx:set-vertex-buffer device nil)
      (is (null (gfx:get-vertex-buffers device)))
      (setf (gfx:indices device) nil)
      (is (null (gfx:indices device))))))

(define-native-test a-vertex-buffer-binding-validates-as-xnas-constructor-does
  (with-buffer-game (game)
    (let ((buffer (keep game (make-instance 'gfx:vertex-buffer
                                            :graphics-device (xna:graphics-device game)
                                            :vertex-type 'gfx:vertex-position-color
                                            :vertex-count 3))))
      (let ((binding (gfx:make-vertex-buffer-binding buffer 1 2)))
        (is (eq buffer (gfx:vertex-buffer-binding-vertex-buffer binding)))
        (is (= 1 (gfx:vertex-buffer-binding-vertex-offset binding)))
        (is (= 2 (gfx:vertex-buffer-binding-instance-frequency binding))))
      ;; The offset bound is exclusive: an offset equal to the vertex count is
      ;; refused, which is what XNA's `bge.un' does.
      (signals xna:cna-argument-out-of-range-error
        (gfx:make-vertex-buffer-binding buffer 3))
      (signals xna:cna-argument-out-of-range-error
        (gfx:make-vertex-buffer-binding buffer -1))
      (signals xna:cna-argument-out-of-range-error
        (gfx:make-vertex-buffer-binding buffer 0 -1)))))

(define-native-test a-non-instanced-draw-is-refused-while-a-stream-is-instanced
  ;; XNA throws InvalidOperationException when instanceStreamMask is non-zero and
  ;; the draw is not the instanced one.
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (buffer (keep game (make-instance 'gfx:vertex-buffer
                                             :graphics-device device
                                             :vertex-type 'gfx:vertex-position-color
                                             :vertex-count 3))))
      (gfx:set-vertex-buffers device (list (gfx:make-vertex-buffer-binding buffer 0 1)))
      (signals xna:cna-invalid-state-error
        (gfx:draw-primitives device :triangle-list 0 1))
      (gfx:set-vertex-buffers device '())
      (is (null (gfx:get-vertex-buffers device))))))

(define-native-test a-draw-refuses-the-counts-xna-refuses
  (with-buffer-game (game)
    (let ((device (xna:graphics-device game)))
      ;; primitiveCount must be positive: XNA's MustDrawSomething.
      (signals xna:cna-argument-out-of-range-error
        (gfx:draw-primitives device :triangle-list 0 0))
      (signals xna:cna-argument-out-of-range-error
        (gfx:draw-primitives device :triangle-list 0 -1))
      ;; numVertices is checked before primitiveCount on the indexed draw.
      (signals xna:cna-argument-out-of-range-error
        (gfx:draw-indexed-primitives device :triangle-list 0 0 0 0 1))
      (signals xna:cna-argument-out-of-range-error
        (gfx:draw-indexed-primitives device :triangle-list 0 0 3 0 0))
      (signals type-error (gfx:draw-primitives device :no-such-mode 0 1)))))

(define-native-test a-user-primitive-draw-refuses-a-short-array
  (with-buffer-game (game)
    (let ((device (xna:graphics-device game))
          (vertices (triangle-vertices)))
      ;; Two triangles need six vertices and there are three.
      (signals xna:cna-argument-out-of-range-error
        (gfx:draw-user-primitives device :triangle-list vertices
                                  :vertex-offset 0 :primitive-count 2))
      ;; A sequence with no inferable declaration and no :VERTEX-DECLARATION.
      (signals xna:cna-usage-error
        (gfx:draw-user-primitives device :triangle-list (vector 1.0f0 2.0f0 3.0f0)
                                  :vertex-offset 0 :primitive-count 1))
      ;; :PRIMITIVE-COUNT and :VERTEX-OFFSET are both required, because every XNA
      ;; DrawUserPrimitives overload takes both positionally and neither has a
      ;; default. Each missing on its own is refused, and so is the pair.
      (signals xna:cna-usage-error
        (gfx:draw-user-primitives device :triangle-list vertices
                                  :vertex-offset 0))
      (signals xna:cna-usage-error
        (gfx:draw-user-primitives device :triangle-list vertices
                                  :primitive-count 1))
      (signals xna:cna-usage-error
        (gfx:draw-user-primitives device :triangle-list vertices)))))

;;; --- no draw happens without a current effect ---------------------------------------
;;;
;;; Every argument check above is CNA-Lisp's own and happens before the ABI is
;;; touched. Past them, CNA refuses the draw itself unless an effect pass has been
;;; applied, and that is XNA's own rule rather than a CNA limitation:
;;; `GraphicsDevice.VerifyCanDraw' requires a current Effect.
;;;
;;; This test covers all four draw entry points with nothing applied.
;;; tests/native/effects.lisp has the other half -- that applying a pass is what
;;; changes the answer -- and tests/native/rasterization.lisp has the pixels.

(define-native-test a-primitive-draw-needs-an-effect-and-says-so
  (with-buffer-game (game)
    (let* ((device (xna:graphics-device game))
           (vertices (triangle-vertices))
           (buffer (keep game (make-instance 'gfx:vertex-buffer
                                             :graphics-device device
                                             :vertex-type 'gfx:vertex-position-color
                                             :vertex-count 3))))
      (gfx:set-data buffer vertices)
      (gfx:set-vertex-buffer device buffer)
      (flet ((refusal (thunk what)
               (handler-case (progn (funcall thunk)
                                    (fail "~a was accepted with no effect applied" what))
                 (xna:cna-error (condition)
                   (let ((text (string-downcase (princ-to-string condition))))
                     (is (search "effect" text)
                         "~a was refused for a reason other than the missing effect: ~a"
                         what condition))
                   t))))
        ;; The buffer-backed draws.
        (is (refusal (lambda () (gfx:draw-primitives device :triangle-list 0 1))
                     "draw-primitives"))
        ;; And the user-primitive ones, which need no buffer at all.
        (is (refusal (lambda ()
                       (gfx:draw-user-primitives device :triangle-list vertices
                                                 :vertex-offset 0 :primitive-count 1))
                     "draw-user-primitives"))
        (is (refusal (lambda ()
                       (gfx:draw-user-indexed-primitives
                        device :triangle-list vertices
                        (make-array 3 :element-type '(unsigned-byte 16)
                                      :initial-contents '(0 1 2))
                        :vertex-offset 0 :num-vertices 3
                        :index-offset 0 :primitive-count 1))
                     "draw-user-indexed-primitives")))
      (gfx:set-vertex-buffer device nil))))

;;; --- the one draw that instancing is for --------------------------------------

(define-native-test the-instanced-draw-is-the-one-legal-under-an-instanced-stream
  "DrawInstancedPrimitives, over cna_graphics_device_draw_instanced_primitives.

Its parameter list is XNA's exactly. The claim that is renderer-independent, and
therefore the one asserted, is about **state**: every other draw refuses while a
vertex stream is bound with a non-zero instance frequency, and this one does not.
So the non-instanced draw must fail with the guard's own condition, and the
instanced one must get past the guard and reach CNA -- whatever CNA then says
about a backend that has no instancing, which under HEADLESS is an internal
failure rather than a refusal.

The argument checks are asserted exactly, because they never reach CNA at all.

This member was reported missing with the reason \"ABI 0.21.0 has **no instanced
draw route at all** -- searched, not assumed\". The route was there the whole
time. The claim was the mistake, not the search that should have preceded it."
  (let ((guarded nil) (instanced nil) (zero-vertices nil))
    (with-buffer-game (game)
      ;; Observations only: this body runs inside a native callback, so the
      ;; assertions are below, after control is back in Lisp.
      (let* ((device (xna:graphics-device game))
             (declaration (gfx:vertex-position-color-vertex-declaration))
             (vertices (keep game (make-instance 'gfx:vertex-buffer
                                                 :graphics-device device
                                                 :vertex-declaration declaration
                                                 :vertex-count 3)))
             (indices (keep game (make-instance 'gfx:index-buffer
                                                :graphics-device device
                                                :index-element-size :sixteen-bits
                                                :index-count 3))))
        (setf (gfx:indices device) indices)
        (gfx:set-vertex-buffers device
                                (list (gfx:make-vertex-buffer-binding vertices 0 1)))
        (flet ((outcome (thunk)
                 (handler-case (progn (funcall thunk) :accepted)
                   (error (condition) (cons (type-of condition)
                                            (princ-to-string condition))))))
          (setf guarded (outcome (lambda () (gfx:draw-indexed-primitives
                                             device :triangle-list 0 0 3 0 1)))
                instanced (outcome (lambda () (gfx:draw-instanced-primitives
                                               device :triangle-list 0 0 3 0 1 2)))
                zero-vertices (outcome (lambda () (gfx:draw-instanced-primitives
                                                   device :triangle-list 0 0 0 0 1 2)))))
        (gfx:set-vertex-buffers device '())))
    ;; The guard refuses the ordinary indexed draw, by name.
    (is (eq 'xna:cna-invalid-state-error (car guarded))
        "the non-instanced draw gave ~a under an instanced stream" (car guarded))
    (is (search "instance frequency" (cdr guarded))
        "the refusal did not name the instancing state: ~a" (cdr guarded))
    ;; ...and does not refuse this one. Whatever CNA answers, it is not the
    ;; guard, and that is the whole distinction between the two members.
    (unless (eq :accepted instanced)
      (is (not (search "instance frequency" (cdr instanced)))
          "the instanced draw was refused by the instancing guard: ~a"
          (cdr instanced)))
    ;; The argument check never reaches CNA, so it is exact on every renderer.
    (is (eq 'xna:cna-argument-out-of-range-error (car zero-vertices))
        "zero vertices gave ~a" (car zero-vertices))))
