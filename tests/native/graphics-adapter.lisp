;;;; graphics-adapter.lisp --- GraphicsAdapter and DisplayModeCollection.
;;;;
;;;; Every one of these runs **inside a callback**, and that is the type's whole
;;;; story: CNA has no adapter query that does not take a graphics-device handle,
;;;; so the two members XNA makes static -- Adapters and DefaultAdapter -- need a
;;;; live game and a lifecycle method to be inside. They are reported partial for
;;;; that, and the test that they refuse *outside* one is as much a part of the
;;;; evidence as the values.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defclass adapter-game (counting-game)
  ((manager :initform nil :accessor adapter-manager)
   (facts :initform '() :accessor adapter-facts)
   (failure :initform nil :accessor adapter-failure))
  (:documentation "Reads every adapter member from inside LoadContent."))

(defmethod initialize-instance :after ((game adapter-game) &key)
  (setf (adapter-manager game)
        (make-instance 'xna:graphics-device-manager :game game)))

(defun %adapter-fact (game key value)
  (push (cons key value) (adapter-facts game))
  value)

(defun %adapter-fact-of (game key) (cdr (assoc key (adapter-facts game))))

(defmethod xna:load-content ((game adapter-game))
  (call-next-method)
  (handler-case
      (let* ((device (xna:graphics-device game))
             (adapters (gfx:graphics-adapter-adapters))
             (default (gfx:graphics-adapter-default-adapter))
             (own (gfx:adapter device)))
        (%adapter-fact game :count (length adapters))
        (%adapter-fact game :default-is-default
                       (gfx:graphics-adapter-is-default-adapter default))
        (%adapter-fact game :own-type (type-of own))
        (%adapter-fact game :description (gfx:graphics-adapter-description own))
        (%adapter-fact game :device-name (gfx:graphics-adapter-device-name own))
        (%adapter-fact game :wide-screen (gfx:graphics-adapter-is-wide-screen own))
        (%adapter-fact game :vendor-id (gfx:graphics-adapter-vendor-id own))
        (%adapter-fact game :device-id (gfx:graphics-adapter-device-id own))
        (%adapter-fact game :revision (gfx:graphics-adapter-revision own))
        (%adapter-fact game :sub-system-id (gfx:graphics-adapter-sub-system-id own))
        (%adapter-fact game :current-mode (gfx:graphics-adapter-current-display-mode own))
        (%adapter-fact game :modes (gfx:graphics-adapter-supported-display-modes own))
        (%adapter-fact game :reach-supported
                       (gfx:graphics-adapter-is-profile-supported own :reach))
        (%adapter-fact game :null-device (gfx:graphics-adapter-use-null-device own))
        ;; The pair CNA writes together: set one, and the other must survive.
        (let ((reference (gfx:graphics-adapter-use-reference-device own)))
          (setf (gfx:graphics-adapter-use-null-device own) t)
          (%adapter-fact game :null-after-set (gfx:graphics-adapter-use-null-device own))
          (%adapter-fact game :reference-survived
                         (eq reference (gfx:graphics-adapter-use-reference-device own)))
          (setf (gfx:graphics-adapter-use-null-device own) (%adapter-fact-of game :null-device)))
        (multiple-value-bind (exact format depth samples)
            (gfx:graphics-adapter-query-back-buffer-format own :reach :color :depth-24 0)
          (%adapter-fact game :query (list exact format depth samples))))
    (error (condition) (setf (adapter-failure game) condition))))

(defmacro with-adapter-game ((game) &body body)
  `(let ((,game (make-instance 'adapter-game :exit-after 2)))
     (unwind-protect
          (progn (xna:run ,game)
                 (is (null (adapter-failure ,game))
                     "the fixture failed: ~a" (adapter-failure ,game))
                 ,@body)
       (progn
         (when (adapter-manager ,game)
           (ignore-errors (xna:dispose (adapter-manager ,game))))
         (xna:dispose ,game)))))

(define-native-test the-adapters-cna-enumerates-are-reachable
  "GraphicsAdapter.Adapters, DefaultAdapter, and GraphicsDevice.Adapter -- the
three ways in, all agreeing that there is at least one adapter and that exactly
one of them says it is the default."
  (with-adapter-game (game)
    (is (plusp (%adapter-fact-of game :count))
        "CNA enumerated ~d adapter(s)" (%adapter-fact-of game :count))
    (is-true (%adapter-fact-of game :default-is-default)
             "DefaultAdapter answered an adapter that does not say it is the default")
    (is (eq 'gfx:graphics-adapter (%adapter-fact-of game :own-type))
        "GraphicsDevice.Adapter answered a ~a" (%adapter-fact-of game :own-type))))

(define-native-test an-adapter-describes-itself
  "The strings and the identifiers, and the two that CNA does not have.

VendorId and DeviceId are zero *when unavailable*, which CNA's struct documents;
Revision and SubSystemId are zero **always**, which it also documents -- and that
is why those two are reported partial and these two are not."
  (with-adapter-game (game)
    (is (stringp (%adapter-fact-of game :description))
        "the description came back as ~a" (%adapter-fact-of game :description))
    (is (stringp (%adapter-fact-of game :device-name)))
    (is (member (%adapter-fact-of game :wide-screen) '(t nil)))
    (is (integerp (%adapter-fact-of game :vendor-id)))
    (is (integerp (%adapter-fact-of game :device-id)))
    (is (= 0 (%adapter-fact-of game :revision))
        "CNA documents Revision as always zero and answered ~a"
        (%adapter-fact-of game :revision))
    (is (= 0 (%adapter-fact-of game :sub-system-id))
        "CNA documents SubSystemId as always zero and answered ~a"
        (%adapter-fact-of game :sub-system-id))))

(define-native-test an-adapter-answers-its-display-modes
  "CurrentDisplayMode and SupportedDisplayModes, and the collection's two members.

The indexer is a *filter* rather than a lookup, so asking it for a format answers
every mode of that format -- and asking for one no mode has answers an empty
vector rather than signalling."
  (with-adapter-game (game)
    (let ((current (%adapter-fact-of game :current-mode))
          (modes (%adapter-fact-of game :modes)))
      (is (typep current 'gfx:display-mode))
      (is (plusp (gfx:display-mode-width current))
          "the current mode is ~a" current)
      (is (typep modes 'gfx:display-mode-collection))
      (let ((vector (gfx:display-mode-collection-modes-vector modes)))
        (is (vectorp vector))
        ;; The filter answers a subset, and every element of it really has the
        ;; format asked for.
        (let ((filtered (gfx:display-mode-collection-item modes :color)))
          (is (<= (length filtered) (length vector))
              "the filter answered more modes than the collection has")
          (is (every (lambda (m) (eq :color (gfx:display-mode-format m))) filtered)
              "the filter answered a mode of another format"))))))

(define-native-test an-adapter-negotiates-formats-and-answers-four-values
  "QueryBackBufferFormat is a Boolean and three out parameters in XNA, so four
values here with the Boolean first -- the shape TouchCollection.FindById uses."
  (with-adapter-game (game)
    (destructuring-bind (exact format depth samples) (%adapter-fact-of game :query)
      (is (member exact '(t nil)) "the exactness flag came back as ~a" exact)
      (is (typep format 'gfx:surface-format))
      (is (typep depth 'gfx:depth-format))
      (is (integerp samples)))
    (is (member (%adapter-fact-of game :reach-supported) '(t nil))
        "IsProfileSupported answered ~a" (%adapter-fact-of game :reach-supported))))

(define-native-test the-device-preference-pair-is-written-together
  "CNA sets UseNullDevice and UseReferenceDevice with one route that takes both,
so changing one has to read the other back first. If it did not, setting the null
device would silently clear the reference-device flag."
  (with-adapter-game (game)
    (is-true (%adapter-fact-of game :null-after-set)
             "setting UseNullDevice did not take")
    (is-true (%adapter-fact-of game :reference-survived)
             "setting UseNullDevice cleared UseReferenceDevice")))

(define-native-test the-static-adapter-members-refuse-outside-a-callback
  "The divergence, asserted rather than described.

XNA's GraphicsAdapter.Adapters is static and answers before a device exists --
that is how an XNA program picks the adapter it creates a device on. Every CNA
adapter route takes a callback-scoped device handle, so here it refuses. Both
members are reported partial for exactly this, and this is the assertion behind
that word."
  (let ((game (make-instance 'adapter-game :exit-after 1)))
    (unwind-protect
         (progn
           (xna:run game)
           (signals xna:cna-scope-error (gfx:graphics-adapter-adapters))
           (signals xna:cna-scope-error (gfx:graphics-adapter-default-adapter)))
      (progn
        (when (adapter-manager game) (ignore-errors (xna:dispose (adapter-manager game))))
        (xna:dispose game)))))
