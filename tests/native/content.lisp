;;;; content.lisp --- ContentManager against a real CNA runtime.
;;;;
;;;; The loop this closes: before ContentManager existed, the only way to obtain a
;;;; SpriteFont was a test-only producer, and no program written against the
;;;; public API could draw text. These tests exercise the public path end to end --
;;;; a `.cnj' descriptor on disk, through `Load<SpriteFont>', to a font whose
;;;; measurements match the hand-built one glyph for glyph.
;;;;
;;;; `tests/fixtures/test-font.cnj' describes exactly the font
;;;; `tests/native/sprite-font.lisp' builds by hand over the same atlas, which is
;;;; what makes the cross-check below worth anything: the two paths are independent
;;;; and must agree.

(in-package #:cna-common-lisp.tests)
(in-suite native-tests)

(defparameter *font-asset* "test-font"
  "The .cnj SpriteFont in tests/fixtures, describing the same font
GLYPH-ATLAS-ROWS builds by hand over glyph-atlas-16x8.png.")

(defclass content-game (graphics-game)
  ((font :initform nil :accessor loaded-font)
   (atlas :initform nil :accessor loaded-atlas)
   (loaded-texture :initform nil :accessor loaded-texture)
   (asset :initarg :asset :initform *font-asset* :accessor asset)
   (load-error :initform nil :accessor load-error)
   (observations :initform '() :accessor observations))
  (:documentation
   "Loads assets through the game's own ContentManager during LoadContent."))

(defun %fixture-root ()
  (namestring (truename (fixture-path "test-font.cnj"))))

(defun %content-root ()
  "The directory the fixtures live in, as CNA's root directory."
  (let ((path (truename (fixture-path "test-font.cnj"))))
    (namestring (make-pathname :name nil :type nil :defaults path))))

(defun observe (game key value)
  "Record a fact from inside a callback, to be asserted outside it.

No FiveAM assertion runs inside a native callback: a failed assertion is a
condition, and a condition crossing the C frame is a different failure than the
one being tested."
  (push (cons key value) (observations game))
  value)

(defun observed (game key)
  (cdr (assoc key (observations game))))

(defmethod xna:load-content ((game content-game))
  (call-next-method)
  (handler-case
      (let ((content (xna:content game)))
        (setf (xna.content:root-directory content) (%content-root))
        (observe game :root (xna.content:root-directory content))
        ;; Counted here rather than outside the loop, because the fixture this
        ;; inherits from owns resources of its own: the claim is that a load adds
        ;; nothing when it fails, not that the game owns nothing at all.
        (observe game :children-before (length (int:children-of game)))
        (unwind-protect
             (multiple-value-bind (font atlas)
                 (xna.content:load-asset content 'gfx:sprite-font (asset game))
               (setf (loaded-font game) font
                     (loaded-atlas game) atlas))
          (observe game :children-after (length (int:children-of game)))))
    (error (condition) (setf (load-error game) condition))))

(defmacro with-content-game ((variable &rest initargs) &body body)
  "Run a CONTENT-GAME, then assert with the loaded assets still alive."
  `(let ((,variable (make-instance 'content-game :exit-after 2 ,@initargs)))
     (unwind-protect
          (progn (xna:run ,variable) ,@body)
       (progn
         (when (loaded-texture ,variable)
           (ignore-errors (xna:dispose (loaded-texture ,variable))))
         ;; The font before its atlas: CNA refuses the other order, and the
         ;; binding records that parenting so the refusal is diagnosable.
         (when (loaded-font ,variable) (ignore-errors (xna:dispose (loaded-font ,variable))))
         (when (loaded-atlas ,variable) (ignore-errors (xna:dispose (loaded-atlas ,variable))))
         ;; GRAPHICS-GAME owns a batch and a texture of its own; leaving either
         ;; alive makes DISPOSE refuse the game and strands it for every later
         ;; test, because CNA allows one active game per process.
         (when (batch ,variable) (ignore-errors (xna:dispose (batch ,variable))))
         (when (texture ,variable) (ignore-errors (xna:dispose (texture ,variable))))
         (when (manager ,variable) (ignore-errors (xna:dispose (manager ,variable))))
         (xna:dispose ,variable)))))

;;; --- the loop closes --------------------------------------------------------

(define-native-test a-sprite-font-loads-through-the-public-content-api
  "Load<SpriteFont> over a .cnj descriptor, with no test-only producer anywhere.

This is the member that makes SpriteFont reachable at all from a program written
against the public API."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((font (loaded-font game)))
      (is (typep font 'gfx:sprite-font))
      (is (typep (loaded-atlas game) 'gfx:texture-2d)
          "the loader must answer the atlas too; CNA hands back both handles")
      (is (= +glyph-atlas-line-spacing+ (gfx:line-spacing font)))
      (is (= 0.0f0 (gfx:spacing font)))
      (is (equalp #(65 66) (gfx:characters font))))))

(define-native-test a-loaded-font-and-a-built-font-agree-glyph-for-glyph
  "The descriptor on disk and GLYPH-ATLAS-ROWS describe the same font.

Two independent paths to the same table -- one through cna_sprite_font_create
with rows this suite states, one through cna_content_manager_load_sprite_font
parsing a .cnj -- so agreement is evidence about both. A descriptor that drifted
from the rows, or a loader that mis-parsed one, shows up here."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((font (loaded-font game))
          (rows (glyph-atlas-rows)))
      (loop for row in rows
            for index from 0
            do (destructuring-bind (unit bounds cropping kerning) row
                 (is (= unit (aref (gfx::%font-characters font) index)))
                 (is (xna:rectangle-equal bounds (aref (gfx::%font-glyphs font) index))
                     "glyph ~d's atlas rectangle loaded as ~a"
                     index (aref (gfx::%font-glyphs font) index))
                 (is (xna:rectangle-equal cropping (aref (gfx::%font-cropping font) index))
                     "glyph ~d's cropping loaded as ~a"
                     index (aref (gfx::%font-cropping font) index))
                 (is (xna:vector3-equal kerning (aref (gfx::%font-kerning font) index))
                     "glyph ~d's kerning loaded as ~a"
                     index (aref (gfx::%font-kerning font) index)))))))

(define-native-test a-loaded-font-measures-what-a-built-font-measures
  "MeasureString over the loaded table, against the arithmetic the built font
gives. Two glyphs eight wide with no bearings is sixteen by the line spacing."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((measured (gfx:measure-string (loaded-font game) "AB")))
      (is (= 16.0f0 (xna:vector2-x measured))
          "two 8-wide glyphs measured ~a wide" (xna:vector2-x measured))
      (is (= (coerce +glyph-atlas-line-spacing+ 'single-float) (xna:vector2-y measured))
          "one line measured ~a tall" (xna:vector2-y measured)))))

;;; --- the manager itself -----------------------------------------------------

(define-native-test a-games-content-manager-is-the-same-object-every-time
  "Game.Content is a field in XNA and answers by identity here."
  (with-content-game (game)
    (is (eq (xna:content game) (xna:content game)))))

(define-native-test the-root-directory-round-trips-through-cna
  "RootDirectory is set and read back through the ABI, not remembered here."
  (with-content-game (game)
    (is (string= (%content-root) (observed game :root))
        "root directory read back as ~s" (observed game :root))))

(define-native-test a-games-own-content-manager-refuses-to-be-disposed
  "CNA lends the game's manager as a borrowed handle that `is released with its
game' and refuses cna_content_manager_destroy on it. The binding refuses first,
with a condition that says why, rather than passing the refusal through."
  (with-content-game (game)
    (signals xna:cna-ownership-error (xna:dispose (xna:content game)))))

(define-native-test an-unknown-asset-fails-and-leaves-the-game-owning-nothing
  "A missing asset is an IO failure, and a failed load is all-or-nothing: the
game must not be left owning a font or an atlas the caller never received."
  (let ((game (make-instance 'content-game :exit-after 2 :asset "no-such-font")))
    (unwind-protect
         (progn
           (xna:run game)
           (is (typep (load-error game) 'xna:cna-io-error)
               "a missing asset gave ~a" (type-of (load-error game)))
           (is (null (loaded-font game)))
           (is (null (loaded-atlas game)))
           (is (= (observed game :children-before) (observed game :children-after))
               "a failed load changed the game's children from ~d to ~d"
               (observed game :children-before) (observed game :children-after)))
      (progn (when (batch game) (ignore-errors (xna:dispose (batch game))))
             (when (texture game) (ignore-errors (xna:dispose (texture game))))
             (when (manager game) (ignore-errors (xna:dispose (manager game))))
             (xna:dispose game)))))

(define-native-test an-asset-type-with-no-native-route-is-refused-by-name
  "CNA has one loader per asset type rather than a generic one, so the loadable
set is finite. Asking for something outside it says so and names the set."
  (with-content-game (game)
    (is (member 'gfx:sprite-font (xna.content:loadable-asset-types)))
    (is (member 'gfx:texture-2d (xna.content:loadable-asset-types)))
    (signals xna:cna-not-supported-error
      (xna.content:load-asset (xna:content game) 'xna:game "anything"))))

;;; --- Texture2D, and the dimensions CNA will not report ----------------------

(defclass texture-content-game (content-game) ())

(defmethod xna:load-content ((game texture-content-game))
  (call-next-method)
  (unless (load-error game)
    (handler-case
        (setf (loaded-texture game)
              (xna.content:load-asset (xna:content game) 'gfx:texture-2d
                                      "cna-lisp-mark.png"))
      (error (condition) (setf (load-error game) condition)))))

(define-native-test a-texture-loads-through-the-content-api
  "Load<Texture2D> over a loose image file."
  (let ((game (make-instance 'texture-content-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (load-error game)) "loading failed: ~a" (load-error game))
           (is (typep (loaded-texture game) 'gfx:texture-2d)))
      (progn
        (when (loaded-texture game) (ignore-errors (xna:dispose (loaded-texture game))))
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

(define-native-test a-loaded-textures-size-is-refused-rather-than-invented
  "ABI 0.21.0 has no route reporting a Texture2D's dimensions. A decoded texture
knows its size because this binding read the image header; a loaded one does not,
and says so instead of answering a plausible zero."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (let ((atlas (loaded-atlas game)))
      (signals xna:cna-not-supported-error (gfx:width atlas))
      (signals xna:cna-not-supported-error (gfx:height atlas))
      ;; and printing one must not signal, because printing never may
      (is (stringp (princ-to-string atlas))))))

;;; --- Unload -----------------------------------------------------------------

(define-native-test unload-drops-the-cache-and-not-what-was-handed-out
  "CNA: `independently owned resource handles returned by the manager are not
destroyed by this call'. So a font stays usable across an Unload, and disposing
it afterwards is still the caller's job."
  (with-content-game (game)
    (is (null (load-error game)) "loading failed: ~a" (load-error game))
    (xna.content:unload (xna:content game))
    (let ((measured (gfx:measure-string (loaded-font game) "AB")))
      (is (= 16.0f0 (xna:vector2-x measured))
          "the font stopped measuring after Unload: ~a" measured))))

;;; --- the cache XNA has and CNA does not -------------------------------------

(defclass twice-loading-game (content-game)
  ((second-font :initform nil :accessor second-font)
   (second-atlas :initform nil :accessor second-atlas))
  (:documentation "Loads the same asset name twice in one callback."))

(defmethod xna:load-content ((game twice-loading-game))
  (call-next-method)
  (unless (load-error game)
    (handler-case
        (multiple-value-bind (font atlas)
            (xna.content:load-asset (xna:content game) 'gfx:sprite-font (asset game))
          (setf (second-font game) font
                (second-atlas game) atlas))
      (error (condition) (setf (load-error game) condition)))))

(define-native-test loading-one-asset-twice-answers-two-objects-and-not-one
  "**A divergence from XNA, measured rather than assumed.** XNA's ContentManager
caches: `Load<T>(\"x\")' twice answers the same instance, and `Unload()' is what
releases it. CNA's ABI has one create-shaped route per asset type and no cache in
front of it, so each call builds a new native object.

Pinned here rather than left to be discovered, because the consequence is
ownership: a program that loads twice owns two fonts and two atlases and must
dispose all four. docs/limitations.md."
  (let ((game (make-instance 'twice-loading-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (null (load-error game)) "loading failed: ~a" (load-error game))
           (is (not (eq (loaded-font game) (second-font game)))
               "two loads answered the same object; CNA has grown a cache")
           (is (/= (int:handle-of (loaded-font game)) (int:handle-of (second-font game)))
               "two loads answered the same native handle"))
      (progn
        (when (second-font game) (ignore-errors (xna:dispose (second-font game))))
        (when (second-atlas game) (ignore-errors (xna:dispose (second-atlas game))))
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

;;; --- a refused disposal must cost the object nothing -------------------------
;;;
;;; DISPOSE invalidates through an UNWIND-PROTECT, so a refusal raised from inside
;;; the destruction still ran the invalidation on the way out: `Game.Content' came
;;; back marked disposed and holding no handle, over a native manager that was
;;; -- correctly -- never destroyed. The refusal now happens in %CHECK-DISPOSABLE,
;;; before anything is touched. These tests are what says so.

(defclass refused-dispose-game (content-game)
  ((refusal :initform nil :accessor refusal)
   (same-object :initform nil :accessor same-object)
   (still-works :initform nil :accessor still-works)
   (device-refusal :initform nil :accessor device-refusal)
   (device-still-works :initform nil :accessor device-still-works))
  (:documentation "Disposes the two parent-owned facades and then keeps using them."))

(defmethod xna:load-content ((game refused-dispose-game))
  (call-next-method)
  (let ((content (xna:content game)))
    (handler-case (xna:dispose content)
      (error (condition) (setf (refusal game) condition)))
    (setf (same-object game) (eq content (xna:content game)))
    ;; A legal operation, through the facade that was just refused. It has to
    ;; reach CNA -- reading the root directory back is a real ABI round trip.
    (handler-case
        (progn (setf (xna.content:root-directory content) (%content-root))
               (setf (still-works game)
                     (string= (%content-root) (xna.content:root-directory content))))
      (error (condition) (setf (still-works game) condition))))
  (let ((device (xna:graphics-device game)))
    (handler-case (xna:dispose device)
      (error (condition) (setf (device-refusal game) condition)))
    (handler-case (setf (device-still-works game) (gfx:renderer-name device))
      (error (condition) (setf (device-still-works game) condition)))))

(define-native-test a-refused-disposal-leaves-the-facade-completely-usable
  "Game.Content refuses to be disposed and is untouched by refusing.

The refusal is right -- CNA lends the game's manager and releases it with the
game. What must not happen is the object paying for it: a caller who wraps a
refusal in HANDLER-CASE, which is the reasonable thing to do, must be left with
the same working facade they started with."
  (let ((game (make-instance 'refused-dispose-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (typep (refusal game) 'xna:cna-ownership-error)
               "disposing Game.Content gave ~a" (type-of (refusal game)))
           (is-false (xna:disposed-p (xna:content game))
                     "the refused facade was marked disposed anyway")
           (is-true (same-object game)
                    "Game.Content answered a different object after the refusal")
           (is (eq t (still-works game))
               "the refused facade could no longer be used: ~a" (still-works game))
           ;; and the same for the other parent-owned facade
           (is (typep (device-refusal game) 'xna:cna-ownership-error)
               "disposing the graphics device gave ~a" (type-of (device-refusal game)))
           (is-false (xna:disposed-p (xna:graphics-device game))
                     "the refused device was marked disposed anyway")
           (is (stringp (device-still-works game))
               "the refused device could no longer be used: ~a" (device-still-works game)))
      (progn
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

;;; --- construction is all-or-nothing here too --------------------------------

(defclass constructing-game (content-game)
  ((no-device :initform nil :accessor no-device-error)
   (owned :initform nil :accessor owned-manager)
   (owned-root :initform nil :accessor owned-root)
   (owned-is-distinct :initform nil :accessor owned-is-distinct)
   (owned-child-count :initform nil :accessor owned-child-count)
   (facade-with-device :initform nil :accessor facade-with-device-error))
  (:documentation "Builds content managers the two legal ways, and one illegal way."))

(defmethod xna:load-content ((game constructing-game))
  (call-next-method)
  (let ((device (xna:graphics-device game)))
    ;; 1. no graphics device: refused at construction, not at first load.
    (handler-case (make-instance 'xna.content:content-manager)
      (error (condition) (setf (no-device-error game) condition)))
    ;; 2. the facade shape is not a public constructor either.
    (handler-case (make-instance 'xna.content:content-manager
                                 :ownership :parent-owned :owner game
                                 :graphics-device device)
      (error (condition) (setf (facade-with-device-error game) condition)))
    ;; 3. an owned one, built the declared way, and usable immediately.
    (let ((manager (make-instance 'xna.content:content-manager
                                  :graphics-device device
                                  :root-directory (%content-root))))
      (setf (owned-manager game) manager
            (owned-root game) (xna.content:root-directory manager)
            (owned-is-distinct game) (not (eq manager (xna:content game)))
            (owned-child-count game)
            (count manager (int:children-of game))))))

(define-native-test a-content-manager-refuses-to-exist-without-what-it-needs
  "`(make-instance 'content-manager)' used to answer a zombie: no handle, no
owner, and a failure deferred to whichever load happened first. There are two
ways a manager comes into existence and neither of them is \"partly\"."
  (let ((game (make-instance 'constructing-game :exit-after 2)))
    (unwind-protect
         (progn
           (xna:run game)
           (is (typep (no-device-error game) 'xna:cna-usage-error)
               "a manager with no device was built anyway, or gave ~a"
               (type-of (no-device-error game)))
           (is (typep (facade-with-device-error game) 'xna:cna-usage-error)
               "the facade shape accepted a graphics device: ~a"
               (type-of (facade-with-device-error game)))
           (let ((manager (owned-manager game)))
             (is (typep manager 'xna.content:content-manager))
             (is-false (xna:disposed-p manager))
             (is (string= (%content-root) (owned-root game))
                 "the owned manager's root directory read back as ~s" (owned-root game))
             (is-true (owned-is-distinct game)
                      "an owned manager and Game.Content answered the same object")
             (is (= 1 (owned-child-count game))
                 "the owned manager is registered as a child of the game ~d time(s)"
                 (owned-child-count game))))
      (progn
        (when (owned-manager game) (ignore-errors (xna:dispose (owned-manager game))))
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (xna:dispose game)))))

(define-native-test an-owned-content-manager-is-disposed-like-any-other-child
  "The other half of the ownership question: an owned manager *is* disposable,
and the game refuses to shut down while it is alive. Everything else the fixture
owns is released first, so the refusal can only be about the manager -- and the
condition has to name it."
  (let ((game (make-instance 'constructing-game :exit-after 2))
        (refused nil))
    (unwind-protect
         (progn
           (xna:run game)
           (when (loaded-font game) (xna:dispose (loaded-font game)))
           (when (loaded-atlas game) (xna:dispose (loaded-atlas game)))
           (when (batch game) (xna:dispose (batch game)))
           (when (texture game) (xna:dispose (texture game)))
           (when (manager game) (xna:dispose (manager game)))
           (handler-case (xna:dispose game)
             (xna:cna-ownership-error (condition) (setf refused condition)))
           (is-true refused
                    "the game shut down with an owned content manager still alive")
           (is (search "content-manager" (princ-to-string refused))
               "the refusal did not name the manager: ~a" refused)
           (xna:dispose (owned-manager game))
           (is-true (xna:disposed-p (owned-manager game)))
           ;; and now it shuts down
           (xna:dispose game)
           (is-true (xna:disposed-p game)))
      (progn
        (when (owned-manager game) (ignore-errors (xna:dispose (owned-manager game))))
        (when (loaded-font game) (ignore-errors (xna:dispose (loaded-font game))))
        (when (loaded-atlas game) (ignore-errors (xna:dispose (loaded-atlas game))))
        (when (batch game) (ignore-errors (xna:dispose (batch game))))
        (when (texture game) (ignore-errors (xna:dispose (texture game))))
        (when (manager game) (ignore-errors (xna:dispose (manager game))))
        (ignore-errors (xna:dispose game))))))
